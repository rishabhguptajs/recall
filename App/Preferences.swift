import Foundation

/// User settings stored in UserDefaults.
enum Preferences {
    private static let defaults = UserDefaults.standard
    private static let foldersKey = "indexedFolders"

    static var home: URL { FileManager.default.homeDirectoryForCurrentUser }

    /// Where macOS saves screenshots (`defaults read com.apple.screencapture location`), falling back to Desktop.
    static var screenshotFolder: URL {
        if let custom = defaults.string(forKey: "screenshotFolderOverride"), !custom.isEmpty {
            return URL(fileURLWithPath: (custom as NSString).expandingTildeInPath, isDirectory: true)
        }
        if let raw = UserDefaults(suiteName: "com.apple.screencapture")?.string(forKey: "location"), !raw.isEmpty {
            let url = URL(fileURLWithPath: (raw as NSString).expandingTildeInPath, isDirectory: true)
            var isDir: ObjCBool = false
            if FileManager.default.fileExists(atPath: url.path, isDirectory: &isDir), isDir.boolValue { return url }
        }
        return home.appendingPathComponent("Desktop", isDirectory: true)
    }

    static var defaultFolders: [URL] {
        var urls = ["Desktop", "Documents", "Downloads"].map { home.appendingPathComponent($0, isDirectory: true) }
        let shots = screenshotFolder.standardizedFileURL
        if !urls.contains(where: { $0.standardizedFileURL == shots }) { urls.append(shots) }
        return urls
    }

    static var indexedFolders: [URL] {
        get {
            guard let paths = defaults.stringArray(forKey: foldersKey) else { return defaultFolders }
            return paths.map { URL(fileURLWithPath: $0, isDirectory: true) }
        }
        set {
            defaults.set(newValue.map(\.path), forKey: foldersKey)
            NotificationCenter.default.post(name: .indexedFoldersChanged, object: nil)
        }
    }

    /// The folders actually indexed and watched. Free covers the default folders; extra folders
    /// need Pro. The saved list is never trimmed, so activating Pro brings extra folders back.
    static var activeFolders: [URL] {
        let all = indexedFolders
        guard !Pro.isActive else { return all }
        let defaults = Set(defaultFolders.map { $0.standardizedFileURL.path })
        return all.filter { defaults.contains($0.standardizedFileURL.path) }
    }

    static func isDefaultFolder(_ url: URL) -> Bool {
        defaultFolders.contains { $0.standardizedFileURL.path == url.standardizedFileURL.path }
    }
}

extension Preferences {
    static var clipboardEnabled: Bool {
        get { defaults.object(forKey: "clipboardEnabled") as? Bool ?? true }
        set { defaults.set(newValue, forKey: "clipboardEnabled") }
    }

    /// Days of clipboard history to keep.
    static var clipboardRetentionDays: Int {
        get { (defaults.object(forKey: "clipboardRetentionDays") as? Int) ?? 30 }
        set { defaults.set(max(1, newValue), forKey: "clipboardRetentionDays") }
    }
}

extension Notification.Name {
    static let indexedFoldersChanged = Notification.Name("indexedFoldersChanged")
}
