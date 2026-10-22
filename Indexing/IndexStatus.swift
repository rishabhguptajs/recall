import Foundation

/// Indexing progress shown in the menu-bar menu and Settings.
@MainActor
final class IndexStatus: ObservableObject {
    static let shared = IndexStatus()

    @Published var isIndexing = false
    @Published var isPaused = false
    @Published var phase = ""
    @Published var done = 0
    @Published var total = 0
    @Published var itemCount = 0
    @Published var embeddedCount = 0
    @Published var deniedFolders: [URL] = []

    var summary: String {
        if isPaused { return "Indexing paused · \(itemCount) items" }
        if isIndexing {
            return total > 0 ? "\(phase) \(done)/\(total)…" : "\(phase)…"
        }
        return "\(itemCount) items indexed"
    }
}
