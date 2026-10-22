import Foundation

/// User settings stored in UserDefaults.
enum Preferences {
    private static let defaults = UserDefaults.standard
    private static let foldersKey = "indexedFolders"

    static var home: URL { FileManager.default.homeDirectoryForCurrentUser }

    /// Where macOS saves screenshots (`defaults read com.apple.screencapture location`), falling back to Desktop.
    static var screenshotFolder: URL {
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
            defaults.set(newValue.map { $0.standardizedFileURL.path }, forKey: foldersKey)
            NotificationCenter.default.post(name: .indexedFoldersChanged, object: nil)
        }
    }
}

extension Notification.Name {
    static let indexedFoldersChanged = Notification.Name("indexedFoldersChanged")
}
