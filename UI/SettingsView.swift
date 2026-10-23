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

    /// Opens Settings, optionally on a given tab (works whether or not the window exists yet).
    func show(tab: SettingsTab? = nil) {
        if window == nil {
            let w = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 560, height: 560),
                             styleMask: [.titled, .closable], backing: .buffered, defer: false)
            w.title = "Recall Settings"
            w.isReleasedWhenClosed = false
            w.contentView = NSHostingView(rootView: SettingsView(initialTab: tab ?? .general))
            w.center()
            window = w
        } else if let tab {
            NotificationCenter.default.post(name: .showSettingsTab, object: tab.rawValue)
        }
        NSApp.activate(ignoringOtherApps: true)
        window?.makeKeyAndOrderFront(nil)
    }
}

enum SettingsTab: String, CaseIterable {
    case general = "General", folders = "Folders", clipboard = "Clipboard", data = "Data", license = "License"
}

struct SettingsView: View {
    @State private var tab: SettingsTab

    init(initialTab: SettingsTab = .general) {
        _tab = State(initialValue: initialTab)
    }

    var body: some View {
        VStack(spacing: 14) {
            Picker("", selection: $tab) {
                ForEach(SettingsTab.allCases, id: \.self) { Text($0.rawValue).tag($0) }
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .frame(width: 460)
            Group {
                switch tab {
                case .general: GeneralSettings()
                case .folders: FolderSettings()
                case .clipboard: ClipboardSettings()
                case .data: DataSettings()
                case .license: LicenseSettings()
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
    @ObservedObject private var updates = Updates.shared
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
                Toggle("Check for updates automatically", isOn: $updates.automaticChecks)
                HStack {
                    Text("Version \(Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "?")")
                        .foregroundStyle(.secondary)
                    Spacer()
                    Button("Check Now") { updates.checkNow() }
                }
                Text("Update checks download a short list of versions from raegent.com. The request carries only Recall’s version number, nothing about your files, searches or clipboard. Recall installs only updates signed by its developer.")
                    .font(.caption).foregroundStyle(.secondary)
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
    @ObservedObject private var license = LicenseManager.shared

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Recall indexes these folders and keeps them up to date. Hidden folders, .git, node_modules, Library and files over 50 MB are skipped.")
                .font(.callout).foregroundStyle(.secondary)
            List(folders, id: \.self, selection: $selection) { url in
                HStack {
                    Image(nsImage: NSWorkspace.shared.icon(forFile: url.path)).resizable().frame(width: 18, height: 18)
                    Text(url.path.replacingOccurrences(of: Preferences.home.path, with: "~"))
                    Spacer()
                    if !license.isPro && !Preferences.isDefaultFolder(url) {
                        Text("Pro").font(.caption.bold()).foregroundStyle(.secondary)
                            .help("Extra folders are indexed with Recall Pro")
                    }
                    if status.deniedFolders.contains(where: { $0.path == url.path }) {
                        Label("No access", systemImage: "exclamationmark.triangle.fill")
                            .font(.caption).foregroundStyle(.orange)
                    }
                }
            }
            .frame(height: 230)
            if !license.isPro {
                Text("Recall Free indexes Desktop, Documents, Downloads and your screenshot folder. Adding other folders needs Pro.")
                    .font(.callout).foregroundStyle(.secondary)
            }
            HStack {
                Button(license.isPro ? "Add Folder…" : "Add Folder… (Pro)", action: addFolder)
                    .disabled(!license.isPro)
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
    @ObservedObject private var license = LicenseManager.shared

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
                Text(license.isPro ? "90 days" : "90 days (Pro)").tag(90).selectionDisabled(!license.isPro)
                Text(license.isPro ? "1 year" : "1 year (Pro)").tag(365).selectionDisabled(!license.isPro)
            }
            .disabled(!enabled)
            .onChange(of: days) {
                Preferences.clipboardRetentionDays = days
                DispatchQueue.global(qos: .utility).async { ClipboardStore.applyRetention(days: days) }
            }
            Text("Text, links and images you copy are stored on this Mac only. Items that password managers mark as concealed are never stored.")
                .font(.callout).foregroundStyle(.secondary)
            if !license.isPro {
                Text("Recall Free searches the last \(Pro.freeClipboardDays) days of clipboard history. Older items are kept (for as long as you chose above) and become searchable with Pro.")
                    .font(.callout).foregroundStyle(.secondary)
            }
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
                Text("Everything Recall stores (the search index, thumbnails and clipboard history) lives in ~/Library/Application Support/Recall. None of it is ever sent off this Mac.")
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

// MARK: - License

struct LicenseSettings: View {
    @ObservedObject private var license = LicenseManager.shared
    @State private var keyInput = ""
    @State private var message: String?
    @State private var confirmDeactivate = false

    var body: some View {
        Form {
            if let token = license.token {
                LabeledContent("Status") { Label("Recall Pro", systemImage: "checkmark.seal.fill").foregroundStyle(.green) }
                LabeledContent("License key", value: Self.masked(license.key ?? ""))
                LabeledContent("Last verified", value: token.issuedAt.formatted(date: .abbreviated, time: .omitted))
                Button("Deactivate This Mac…") { confirmDeactivate = true }
                    .disabled(license.busy)
                    .confirmationDialog("Deactivate Recall Pro on this Mac?", isPresented: $confirmDeactivate) {
                        Button("Deactivate", role: .destructive) { run { try await license.deactivate() } }
                    } message: {
                        Text("This frees the slot so you can use your key on another Mac. Nothing is deleted; Pro items are hidden until you activate again.")
                    }
            } else {
                if license.trialActive {
                    LabeledContent("Status") {
                        Label("Pro trial: \(license.trialDaysLeft) \(license.trialDaysLeft == 1 ? "day" : "days") left", systemImage: "clock.fill")
                            .foregroundStyle(.green)
                    }
                } else {
                    LabeledContent("Status", value: license.trialEnd == nil ? "Recall Free" : "Recall Free (trial ended)")
                }
                Section {
                    Text(license.trialActive
                         ? "You have every Pro feature for the next \(license.trialDaysLeft) \(license.trialDaysLeft == 1 ? "day" : "days"). After that Recall goes back to Free; nothing is deleted, Pro items are only hidden until you activate. Paste a key below any time to keep Pro."
                         : "Pro adds screenshot text search, your full clipboard history, longer retention and extra folders.")
                        .font(.callout)
                    TextField("License key", text: $keyInput, prompt: Text("Paste the key from your purchase email"))
                        .font(.system(.body, design: .monospaced))
                        .onSubmit(activate)
                    HStack {
                        Button("Activate", action: activate)
                            .keyboardShortcut(.defaultAction)
                            .disabled(keyInput.trimmingCharacters(in: .whitespaces).isEmpty || license.busy)
                        if license.busy { ProgressView().controlSize(.small) }
                    }
                }
            }
            if let message {
                Text(message).font(.callout).foregroundStyle(.orange)
            }
            Section("Privacy") {
                Text("Recall contacts its license server in three cases: to start and keep track of your 14-day trial (while it runs, and once when it has ended), when you activate or deactivate, and about once a month while Pro is active to re-check the key with Dodo Payments, where it was bought. Requests carry an anonymous ID for this Mac (a one-way hash) and, for a license, the key: no files, searches, clipboard or usage data. The server remembers the ID so the trial can't be restarted. After the trial, Recall Free doesn't contact the server. If you're offline, Pro keeps working.")
                    .font(.callout).foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
    }

    private func activate() {
        let key = keyInput
        run {
            try await license.activate(key: key)
            keyInput = ""
        }
    }

    private func run(_ action: @escaping @MainActor () async throws -> Void) {
        message = nil
        Task { @MainActor in
            do { try await action() } catch { message = error.localizedDescription }
        }
    }

    /// First and last few characters: enough to recognise the key without showing all of it.
    static func masked(_ key: String) -> String {
        guard key.count > 12 else { return key }
        return String(key.prefix(6)) + "…" + String(key.suffix(4))
    }
}
