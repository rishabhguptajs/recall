import AppKit
import Combine
import SwiftUI

final class SearchModel: ObservableObject {
    @Published var query = ""
    @Published private(set) var results: [SearchResult] = []
    @Published var selection = 0
    /// Tab filter; a /s /c /f token typed in the query takes precedence.
    @Published var filter: ItemSource?
    /// Bumped each time the panel opens so the field grabs focus.
    @Published var focusToken = 0

    private var cancellables: Set<AnyCancellable> = []
    private var generation = 0
    private let queue = DispatchQueue(label: "recall.search", qos: .userInitiated)

    init() {
        $query
            .removeDuplicates()
            .debounce(for: .milliseconds(150), scheduler: DispatchQueue.main)
            .sink { [weak self] in self?.run($0) }
            .store(in: &cancellables)
        $filter
            .dropFirst()
            .sink { [weak self] f in
                guard let self else { return }
                self.run(self.query, filter: f)
            }
            .store(in: &cancellables)
    }

    var selected: SearchResult? { results.indices.contains(selection) ? results[selection] : nil }

    func move(_ delta: Int) {
        guard !results.isEmpty else { return }
        selection = max(0, min(results.count - 1, selection + delta))
    }

    /// Re-runs the current query (e.g. after the index changed).
    func refresh() { run(query) }

    private func run(_ text: String, filter: ItemSource?? = nil) {
        generation += 1
        let gen = generation
        let source = filter ?? self.filter
        queue.async { [weak self] in
            let found = SearchEngine.shared.search(text, filter: source)
            DispatchQueue.main.async {
                guard let self, gen == self.generation else { return }
                self.results = found
                self.selection = 0
            }
        }
    }
}

struct SearchView: View {
    @ObservedObject var model: SearchModel
    var onOpen: (SearchResult) -> Void
    @FocusState private var fieldFocused: Bool

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 10) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 20, weight: .medium))
                    .foregroundStyle(.secondary)
                TextField("Search your Mac…", text: $model.query)
                    .textFieldStyle(.plain)
                    .font(.system(size: 24))
                    .focused($fieldFocused)
            }
            .padding(.horizontal, 18)
            .padding(.top, 16)
            .padding(.bottom, 10)
            FilterTabs(selection: $model.filter)
                .padding(.horizontal, 14)
                .padding(.bottom, 8)
            Divider()
            if model.results.isEmpty {
                Spacer()
                Text(model.query.isEmpty ? "Type to search files, screenshots and clipboard" : "No results")
                    .foregroundStyle(.secondary)
                Spacer()
            } else {
                resultsList
            }
        }
        .frame(width: SearchPanel.size.width, height: SearchPanel.size.height)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 14))
        .onChange(of: model.focusToken) { fieldFocused = true }
        .onAppear { fieldFocused = true }
    }

    private var resultsList: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 2) {
                    ForEach(Array(model.results.enumerated()), id: \.element.id) { index, result in
                        ResultRow(result: result, isSelected: index == model.selection)
                            .id(result.id)
                            .contentShape(Rectangle())
                            .onTapGesture(count: 2) { onOpen(result) }
                            .onTapGesture { model.selection = index }
                    }
                }
                .padding(6)
            }
            .onChange(of: model.selection) {
                if let r = model.selected { proxy.scrollTo(r.id) }
            }
        }
    }
}

struct ResultRow: View {
    let result: SearchResult
    let isSelected: Bool

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(nsImage: IconCache.icon(for: result))
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 36, height: 36)
                .clipShape(RoundedRectangle(cornerRadius: 4))
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text(result.title).font(.system(size: 14, weight: .semibold)).lineLimit(1)
                    SourceBadge(source: result.source)
                    Spacer(minLength: 8)
                    Text(Self.relative(result.date)).font(.system(size: 11)).foregroundStyle(.secondary)
                }
                Text(Highlight.attributed(result.snippet))
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .background(isSelected ? Color.accentColor.opacity(0.22) : .clear, in: RoundedRectangle(cornerRadius: 8))
    }

    private static let formatter: RelativeDateTimeFormatter = {
        let f = RelativeDateTimeFormatter()
        f.unitsStyle = .short
        return f
    }()

    static func relative(_ date: Date) -> String { formatter.localizedString(for: date, relativeTo: Date()) }
}

struct SourceBadge: View {
    let source: ItemSource

    var body: some View {
        Text(source.label)
            .font(.system(size: 10, weight: .medium))
            .padding(.horizontal, 6)
            .padding(.vertical, 1)
            .background(color.opacity(0.18), in: Capsule())
            .foregroundStyle(color)
    }

    private var color: Color {
        switch source {
        case .file: .blue
        case .screenshot: .purple
        case .clipboard: .orange
        }
    }
}

struct FilterTabs: View {
    @Binding var selection: ItemSource?

    private let tabs: [(String, ItemSource?)] = [("All", nil), ("Files", .file), ("Screenshots", .screenshot), ("Clipboard", .clipboard)]

    var body: some View {
        HStack(spacing: 4) {
            ForEach(tabs, id: \.0) { label, source in
                Button { selection = source } label: {
                    Text(label)
                        .font(.system(size: 12, weight: selection == source ? .semibold : .regular))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(selection == source ? Color.accentColor.opacity(0.22) : .clear, in: Capsule())
                        .contentShape(Capsule())
                }
                .buttonStyle(.plain)
            }
            Spacer()
            Text("↑↓ select · ↩ open · ⌘↩ reveal · ⌘C copy · ⌘Y preview")
                .font(.system(size: 10))
                .foregroundStyle(.tertiary)
        }
    }
}

enum Highlight {
    /// Turns "\u{2}word\u{3}" markers into bold, primary-coloured runs.
    static func attributed(_ marked: String) -> AttributedString {
        var out = AttributedString()
        var buffer = ""
        var bold = false
        func flush() {
            guard !buffer.isEmpty else { return }
            var part = AttributedString(buffer)
            if bold {
                part.font = .system(size: 12, weight: .bold)
                part.foregroundColor = .primary
            }
            out += part
            buffer = ""
        }
        for ch in marked {
            switch ch {
            case "\u{2}": flush(); bold = true
            case "\u{3}": flush(); bold = false
            case "\n", "\r", "\t": buffer.append(" ")
            default: buffer.append(ch)
            }
        }
        flush()
        return out
    }
}

enum IconCache {
    private static let cache = NSCache<NSString, NSImage>()

    static func icon(for r: SearchResult) -> NSImage {
        let key = (r.thumbnailPath ?? r.path ?? "\(r.source.rawValue)-\(r.kind)") as NSString
        if let img = cache.object(forKey: key) { return img }
        let img: NSImage
        if let thumb = r.thumbnailPath, let t = NSImage(contentsOfFile: thumb) {
            img = t
        } else if let path = r.path {
            img = NSWorkspace.shared.icon(forFile: path)
        } else {
            let name = r.kind == "url" ? "link" : (r.kind == "image" ? "photo" : "doc.on.clipboard")
            img = NSImage(systemSymbolName: name, accessibilityDescription: nil) ?? NSImage()
        }
        cache.setObject(img, forKey: key)
        return img
    }
}
