import Foundation

/// Walks indexed folders, applying the ignore rules.
enum FileScanner {
    static let ignoredDirectoryNames: Set<String> = [
        ".git", "node_modules", ".build", "DerivedData", "Library", "venv", ".venv", "__pycache__",
        "Pods", ".Trash",
    ]
    static let maxFileSize: Int64 = 50 * 1024 * 1024

    struct Candidate {
        let url: URL
        let modifiedAt: Date
        let createdAt: Date
        let size: Int64
    }

    enum FolderError: Error { case permissionDenied, missing }

    private static let keys: [URLResourceKey] = [
        .isRegularFileKey, .isDirectoryKey, .isPackageKey, .contentModificationDateKey,
        .creationDateKey, .fileSizeKey, .isHiddenKey,
    ]

    /// Checks that a folder can be read (triggers the macOS permission prompt for Desktop/Documents/Downloads).
    static func checkAccess(_ folder: URL) -> FolderError? {
        var isDir: ObjCBool = false
        guard FileManager.default.fileExists(atPath: folder.path, isDirectory: &isDir), isDir.boolValue else { return .missing }
        do {
            _ = try FileManager.default.contentsOfDirectory(atPath: folder.path)
            return nil
        } catch {
            return .permissionDenied
        }
    }

    /// True if a path should never be indexed (inside an ignored or hidden directory).
    static func isIgnored(path: String, under root: String) -> Bool {
        guard path.hasPrefix(root) else { return true }
        let relative = path.dropFirst(root.count).split(separator: "/")
        for comp in relative.dropLast() {
            if comp.hasPrefix(".") || ignoredDirectoryNames.contains(String(comp)) { return true }
        }
        if let name = relative.last, name.hasPrefix(".") { return true }
        return false
    }

    static func candidate(for url: URL) -> Candidate? {
        guard let v = try? url.resourceValues(forKeys: Set(keys)) else { return nil }
        let supported = Extractors.supportedExtensions.contains(url.pathExtension.lowercased())
        guard supported, v.isHidden != true else { return nil }
        // Packages like .pages/.rtfd are directories; plain directories are not candidates.
        if v.isDirectory == true && v.isPackage != true { return nil }
        let size = Int64(v.fileSize ?? 0)
        guard size <= maxFileSize else { return nil }
        return Candidate(url: url, modifiedAt: v.contentModificationDate ?? Date(),
                         createdAt: v.creationDate ?? v.contentModificationDate ?? Date(), size: size)
    }

    static func enumerate(_ folder: URL, _ body: (Candidate) -> Void) {
        guard let e = FileManager.default.enumerator(
            at: folder, includingPropertiesForKeys: keys,
            options: [.skipsHiddenFiles, .skipsPackageDescendants],
            errorHandler: { _, _ in true }
        ) else { return }
        for case let url as URL in e {
            autoreleasepool {
                if let v = try? url.resourceValues(forKeys: [.isDirectoryKey, .isPackageKey]),
                   v.isDirectory == true, v.isPackage != true {
                    if ignoredDirectoryNames.contains(url.lastPathComponent) { e.skipDescendants() }
                    return
                }
                if let c = candidate(for: url) { body(c) }
            }
        }
    }
}
