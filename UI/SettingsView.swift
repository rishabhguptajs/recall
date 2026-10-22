import AppKit
import KeyboardShortcuts
import ServiceManagement
import SwiftUI

extension Notification.Name {
    static let clipboardSettingsChanged = Notification.Name("clipboardSettingsChanged")
    static let clearAllData = Notification.Name("clearAllData")
    static let showSettingsTab = Notification.Name("showSettingsTab")
}

final class SettingsWindowController {
    private var window: NSWindow?

    func show() {
        if window == nil {
            let w = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 560, height: 560),
                             styleMask: [.titled, .closable], backing: .buffered, defer: false)
            w.title = "Recall Settings"
            w.isReleasedWhenClosed = false
            w.contentView = NSHostingView(rootView: SettingsView())
            w.center()
            window = w
        }
        NSApp.activate(ignoringOtherApps: true)
        window?.makeKeyAndOrderFront(nil)
    }
}

enum SettingsTab: String, CaseIterable {
    case general = "General", folders = "Folders", clipboard = "Clipboard", data = "Data"
}

struct SettingsView: View {
    @State private var tab: SettingsTab = .general

    var body: some View {
        VStack(spacing: 14) {
            Picker("", selection: $tab) {
                ForEach(SettingsTab.allCases, id: \.self) { Text($0.rawValue).tag($0) }
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .frame(width: 380)
            Group {
                switch tab {
                case .general: GeneralSettings()
                case .folders: FolderSettings()
                case .clipboard: ClipboardSettings()
                case .data: DataSettings()
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        }
        .padding(20)
        .frame(width: 560, height: 560)
        .background(Color(nsColor: .windowBackgroundColor))
        .onReceive(NotificationCenter.default.publisher(for: .showSettingsTab)) { note in
            if let t = note.object as? String, let v = SettingsTab(rawValue: t) { tab = v }
        }
    }
}

// MARK: - General

struct GeneralSettings: View {
    @State private var launchAtLogin = SMAppService.mainApp.status == .enabled
    @State private var loginError: String?

    var body: some View {
        Form {
            KeyboardShortcuts.Recorder("Search shortcut:", name: .toggleSearch)
            Toggle("Open Recall at login", isOn: $launchAtLogin)
                .onChange(of: launchAtLogin) { setLaunchAtLogin(launchAtLogin) }
            if let loginError {
                Text(loginError).font(.caption).foregroundStyle(.orange)
            }
            Section {
                Text("In the search panel: type to search, ↑↓ to move, ↩ to open, ⌘↩ to show in Finder, ⌘C to copy, ⌘Y (or Space after using the arrows) for Quick Look. Type /f, /s or /c to search only files, screenshots or clipboard.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
    }

    private func setLaunchAtLogin(_ on: Bool) {
        do {
            if on { try SMAppService.mainApp.register() } else { try SMAppService.mainApp.unregister() }
            loginError = SMAppService.mainApp.status == .requiresApproval
                ? "macOS needs your OK: System Settings → General → Login Items → turn on Recall."
                : nil
        } catch {
            loginError = "Couldn't change this: \(error.localizedDescription)"
            launchAtLogin = SMAppService.mainApp.status == .enabled
        }
    }
}

// MARK: - Folders

struct FolderSettings: View {
    @State private var folders = Preferences.indexedFolders
    @State private var selection: URL?
    @ObservedObject private var status = IndexStatus.shared

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Recall indexes these folders and keeps them up to date. Hidden folders, .git, node_modules, Library and files over 50 MB are skipped.")
                .font(.callout).foregroundStyle(.secondary)
            List(folders, id: \.self, selection: $selection) { url in
                HStack {
                    Image(nsImage: NSWorkspace.shared.icon(forFile: url.path)).resizable().frame(width: 18, height: 18)
                    Text(url.path.replacingOccurrences(of: Preferences.home.path, with: "~"))
                    Spacer()
                    if status.deniedFolders.contains(where: { $0.path == url.path }) {
                        Label("No access", systemImage: "exclamationmark.triangle.fill")
                            .font(.caption).foregroundStyle(.orange)
                    }
                }
            }
            .frame(height: 230)
            HStack {
                Button("Add Folder…", action: addFolder)
                Button("Remove") {
                    guard let s = selection else { return }
                    folders.removeAll { $0 == s }
                    save()
                }
                .disabled(selection == nil)
                Spacer()
                Button("Reset to Defaults") {
                    folders = Preferences.defaultFolders
                    save()
                }
            }
            if !status.deniedFolders.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Some folders can't be read").font(.headline)
                    Text("macOS blocked access. To fix it: open System Settings → Privacy & Security → Files and Folders → Recall, and turn on the folders listed above (or add Recall under Full Disk Access). Then quit and reopen Recall.")
                        .font(.callout).foregroundStyle(.secondary)
                    Button("Open Privacy Settings") {
                        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_FilesAndFolders") {
                            NSWorkspace.shared.open(url)
                        }
                    }
                }
                .padding(10)
                .background(Color.orange.opacity(0.1), in: RoundedRectangle(cornerRadius: 8))
            }
        }
    }

    private func addFolder() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = true
        panel.prompt = "Index"
        guard panel.runModal() == .OK else { return }
        for url in panel.urls where !folders.contains(url) { folders.append(url) }
        save()
    }

    private func save() { Preferences.indexedFolders = folders }
}

// MARK: - Clipboard

struct ClipboardSettings: View {
    @State private var enabled = Preferences.clipboardEnabled
    @State private var days = Preferences.clipboardRetentionDays
    @State private var confirmClear = false

    var body: some View {
        Form {
            Toggle("Keep clipboard history", isOn: $enabled)
                .onChange(of: enabled) {
                    Preferences.clipboardEnabled = enabled
                    NotificationCenter.default.post(name: .clipboardSettingsChanged, object: nil)
                }
            Picker("Keep items for", selection: $days) {
                Text("1 day").tag(1)
                Text("7 days").tag(7)
                Text("30 days").tag(30)
                Text("90 days").tag(90)
                Text("1 year").tag(365)
            }
            .disabled(!enabled)
            .onChange(of: days) {
                Preferences.clipboardRetentionDays = days
                DispatchQueue.global(qos: .utility).async { ClipboardStore.applyRetention(days: days) }
            }
            Text("Text, links and images you copy are stored on this Mac only. Items that password managers mark as concealed are never stored.")
                .font(.callout).foregroundStyle(.secondary)
            Button("Clear Clipboard History…") { confirmClear = true }
                .confirmationDialog("Delete all clipboard history?", isPresented: $confirmClear) {
                    Button("Delete", role: .destructive) {
                        DispatchQueue.global(qos: .utility).async {
                            ClipboardStore.deleteAll()
                            VectorIndex.shared.reload()
                        }
                    }
                }
        }
        .formStyle(.grouped)
    }
}

// MARK: - Data

struct DataSettings: View {
    @ObservedObject private var status = IndexStatus.shared
    @State private var confirmClear = false

    var body: some View {
        Form {
            LabeledContent("Indexed items", value: "\(status.itemCount)")
            LabeledContent("Meaning-search vectors", value: "\(status.embeddedCount)")
            LabeledContent("Status", value: status.summary)
            if status.isIndexing && status.total > 0 {
                ProgressView(value: Double(status.done), total: Double(max(status.total, 1)))
            }
            Button(status.isPaused ? "Resume Indexing" : "Pause Indexing") {
                let paused = !status.isPaused
                Task {
                    await Indexer.shared.setPaused(paused)
                    await EmbeddingWorker.shared.setPaused(paused)
                }
            }
            Section {
                Text("Everything Recall stores (the search index, thumbnails and clipboard history) lives in ~/Library/Application Support/Recall. Nothing is ever sent off this Mac.")
                    .font(.callout).foregroundStyle(.secondary)
                Button("Clear All Data…", role: .destructive) { confirmClear = true }
                    .confirmationDialog("Clear all Recall data?", isPresented: $confirmClear) {
                        Button("Clear All Data", role: .destructive) {
                            NotificationCenter.default.post(name: .clearAllData, object: nil)
                        }
                    } message: {
                        Text("This deletes the search index, thumbnails and clipboard history. Your files are not touched; they will be indexed again.")
                    }
            }
        }
        .formStyle(.grouped)
    }
}
