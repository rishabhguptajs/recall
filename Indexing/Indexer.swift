import CryptoKit
import Foundation

/// Background indexer: scans folders, extracts text, chunks it and stores it.
/// Runs at utility priority with small pauses between files so the Mac stays responsive.
actor Indexer {
    static let shared = Indexer()

    private let db = AppDatabase.shared
    private var paused = false
    private var scanning = false

    func setPaused(_ value: Bool) {
        paused = value
        Task { @MainActor in IndexStatus.shared.isPaused = value }
    }

    // MARK: - Full scan

    func fullScan() async {
        guard !scanning else { return }
        scanning = true
        defer { scanning = false }

        await updateStatus { $0.isIndexing = true; $0.phase = "Scanning"; $0.done = 0; $0.total = 0 }

        // Folders are handled one at a time, so a folder waiting on a macOS permission
        // prompt doesn't hold up the others.
        var denied: [URL] = []
        var seen = Set<String>()
        var done = 0
        var total = 0
        for folder in Preferences.indexedFolders {
            await updateStatus { $0.phase = "Scanning \(folder.lastPathComponent)" }
            // Listing runs off the actor: it can block on a macOS permission prompt, and the
            // watcher's changes must still get through meanwhile.
            let access = await Task.detached(priority: .utility) { FileScanner.checkAccess(folder) }.value
            switch access {
            case .permissionDenied?:
                denied.append(folder)
                let deniedFolders = denied
                await updateStatus { $0.deniedFolders = deniedFolders }
                continue
            case .missing?: continue
            case nil: break
            }
            let listed = await Task.detached(priority: .utility) { () -> [FileScanner.Candidate] in
                var found: [FileScanner.Candidate] = []
                FileScanner.enumerate(folder) { found.append($0) }
                return found
            }.value
            var candidates = listed.filter { seen.insert($0.url.path).inserted }
            // Newest first, so recent files become searchable soonest.
            candidates.sort { $0.modifiedAt > $1.modifiedAt }
            total += candidates.count
            let newTotal = total
            await updateStatus { $0.phase = "Indexing"; $0.total = newTotal }

            for (i, c) in candidates.enumerated() {
                await waitWhilePaused()
                await index(c)
                done += 1
                if i % 20 == 0 || i == candidates.count - 1 {
                    let d = done
                    let count = db.itemCount()
                    await updateStatus { $0.done = d; $0.itemCount = count }
                }
            }

            // Remove items whose files disappeared (or are now ignored).
            let stale = ((try? db.paths(under: folder.path)) ?? []).filter { !seen.contains($0) }
            for path in stale { try? db.deleteItem(path: path) }
        }
        let deniedFolders = denied
        await updateStatus { $0.deniedFolders = deniedFolders }

        let count = db.itemCount()
        await updateStatus { $0.isIndexing = false; $0.phase = ""; $0.itemCount = count }
    }

    // MARK: - Single files

    /// Indexes one file if it changed. Returns true if the index was updated.
    @discardableResult
    func index(_ c: FileScanner.Candidate) async -> Bool {
        let path = c.url.path
        let mtime = c.modifiedAt.timeIntervalSince1970
        let existing = try? db.stamp(path: path)
        if let s = existing, abs(s.modifiedAt - mtime) < 0.001, s.size == c.size { return false }
        guard let extractor = Extractors.extractor(for: c.url) else { return false }

        // Unreadable files are still indexed by name.
        var extracted = (try? extractor.extract(c.url)) ?? Extracted(text: "", kind: Self.kind(for: c.url))
        if extracted.text.count > Extractors.maxTextLength {
            extracted.text = String(extracted.text.prefix(Extractors.maxTextLength))
        }
        let hash = Self.sha256(extracted.text + "|" + c.url.lastPathComponent)
        if let s = existing, s.hash == hash {
            try? db.touch(path: path, modifiedAt: c.modifiedAt, size: c.size)
            return false
        }

        let source: ItemSource = extracted.kind == "image" && ScreenshotDetector.isScreenshot(c.url) ? .screenshot : .file
        let fields = AppDatabase.ItemFields(
            source: source, path: path, title: c.url.lastPathComponent, kind: extracted.kind,
            createdAt: c.createdAt, modifiedAt: c.modifiedAt, size: c.size, contentHash: hash,
            thumbnailPath: extracted.thumbnailPath, metadataJSON: nil)
        do {
            try db.upsert(fields, chunks: Chunker.chunks(extracted.text))
        } catch {
            NSLog("Recall: failed to index \(path): \(error)")
            return false
        }
        try? await Task.sleep(nanoseconds: 2_000_000) // throttle
        return true
    }

    func remove(path: String) {
        try? db.deleteItem(path: path)
    }

    /// Handles paths reported by the folder watcher: index new/changed files, drop deleted ones.
    /// Returns true if anything in the index changed.
    @discardableResult
    func handleChanges(_ paths: [String]) async -> Bool {
        let roots = Preferences.indexedFolders.map { $0.path.hasSuffix("/") ? $0.path : $0.path + "/" }
        var changed = false
        for path in Set(paths) {
            guard let root = roots.first(where: { path.hasPrefix($0) }),
                  !FileScanner.isIgnored(path: path, under: root) else { continue }
            let url = URL(fileURLWithPath: path)
            if FileManager.default.fileExists(atPath: path) {
                if let c = FileScanner.candidate(for: url) {
                    await waitWhilePaused()
                    if await index(c) { changed = true }
                }
            } else {
                // A deleted file, or a deleted folder (drop everything under it).
                let under = (try? db.paths(under: path)) ?? []
                if (try? db.stamp(path: path)) != nil || !under.isEmpty {
                    try? db.deleteItem(path: path)
                    for p in under { try? db.deleteItem(path: p) }
                    changed = true
                }
            }
        }
        if changed {
            let count = db.itemCount()
            await updateStatus { $0.itemCount = count }
        }
        return changed
    }

    // MARK: - Helpers

    private func waitWhilePaused() async {
        while paused { try? await Task.sleep(nanoseconds: 500_000_000) }
    }

    private func updateStatus(_ change: @escaping @MainActor (IndexStatus) -> Void) async {
        await MainActor.run { change(IndexStatus.shared) }
    }

    static func kind(for url: URL) -> String {
        switch url.pathExtension.lowercased() {
        case "pdf": "pdf"
        case "docx", "doc", "rtf", "rtfd", "odt", "pages": "document"
        case "png", "jpg", "jpeg", "heic", "heif", "tiff", "tif", "gif", "bmp", "webp": "image"
        default: "text"
        }
    }

    static func sha256(_ s: String) -> String {
        SHA256.hash(data: Data(s.utf8)).map { String(format: "%02x", $0) }.joined()
    }
}
