import AppKit
import KeyboardShortcuts
import SnimachCore
import SwiftUI

enum SettingsTab: String, CaseIterable, Identifiable {
    case app
    case capture
    case shortcuts
    case about

    var id: String { rawValue }

    var title: String {
        switch self {
        case .app: return "App"
        case .capture: return "Capture"
        case .shortcuts: return "Shortcuts"
        case .about: return "About"
        }
    }

    var icon: String {
        switch self {
        case .app: return "app.badge"
        case .capture: return "photo"
        case .shortcuts: return "keyboard"
        case .about: return "info.circle"
        }
    }
}

final class SettingsSelection: ObservableObject {
    @Published var tab: SettingsTab = .app
}

private extension Color {
    static var brand: Color {
        Color(
            red: Brand.accentComponents.red,
            green: Brand.accentComponents.green,
            blue: Brand.accentComponents.blue
        )
    }
}

private struct SidebarSelection: View {
    let isSelected: Bool

    var body: some View {
        RoundedRectangle(cornerRadius: 7)
            .fill(Color.brand.opacity(isSelected ? 0.18 : 0))
            .padding(.horizontal, 8)
            .padding(.vertical, 2)
    }
}

struct SettingsView: View {
    @ObservedObject var launchAtLogin: LaunchAtLoginModel
    @ObservedObject var preferences: Preferences
    @ObservedObject var selection: SettingsSelection

    var body: some View {
        NavigationSplitView {
            VStack(spacing: 0) {
                VStack(spacing: 8) {
                    Image(nsImage: NSApp.applicationIconImage)
                        .resizable()
                        .frame(width: 56, height: 56)
                    Text(AppInfo.name)
                        .font(.headline)
                }
                .frame(maxWidth: .infinity)
                .padding(.top, 12)
                .padding(.bottom, 8)
                List {
                    ForEach(SettingsTab.allCases) { tab in
                        Button {
                            selection.tab = tab
                        } label: {
                            Label {
                                Text(tab.title)
                                    .foregroundStyle(.primary)
                            } icon: {
                                Image(systemName: tab.icon)
                                    .foregroundStyle(selection.tab == tab ? Color.brand : .secondary)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .listRowBackground(SidebarSelection(isSelected: selection.tab == tab))
                    }
                }
                .listStyle(.sidebar)
            }
            .frame(minWidth: 170)
        } detail: {
            switch selection.tab {
            case .app:
                AppSettingsView(launchAtLogin: launchAtLogin, preferences: preferences)
            case .capture:
                CaptureSettingsView(preferences: preferences)
            case .shortcuts:
                ShortcutsSettingsView()
            case .about:
                VStack {
                    Spacer(minLength: 0)
                    AboutView()
                    Spacer(minLength: 0)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .navigationTitle("About")
            }
        }
        .frame(width: 640, height: 420)
        .tint(Color.brand)
    }
}

private struct PaneHeader: View {
    let title: String

    var body: some View {
        Text(title)
            .font(.title2)
            .fontWeight(.semibold)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 20)
            .padding(.top, 16)
    }
}

private struct CaptureSettingsView: View {
    @ObservedObject var preferences: Preferences

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                PaneHeader(title: "Capture")
                Form {
                    Section {
                        Picker("After a capture", selection: $preferences.afterCapture) {
                            ForEach(AfterCapture.allCases) { choice in
                                Text(choice.label).tag(choice)
                            }
                        }
                        .pickerStyle(.radioGroup)
                        Toggle("Include the pointer in captures", isOn: $preferences.includesPointer)
                    } footer: {
                        Text("Preview opens a small card you can click to annotate. Editor opens at once. Clipboard only stays silent.")
                    }
                    Section {
                        Picker("Hide preview", selection: $preferences.previewHide) {
                            ForEach(PreviewHide.allCases) { choice in
                                Text(choice.label).tag(choice)
                            }
                        }
                        .pickerStyle(.segmented)
                    } footer: {
                        Text("Manual keeps the card up until you pick Open, Save, or X. Hovering always pauses the timer.")
                    }
                }
                .formStyle(.grouped)
                .scrollContentBackground(.hidden)
            }
        }
        .navigationTitle("Capture")
    }
}

private struct ShortcutsSettingsView: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                PaneHeader(title: "Shortcuts")
                Form {
                    Section {
                        ShortcutRow(title: "Capture area", name: .captureArea)
                        ShortcutRow(title: "Capture window", name: .captureWindow)
                        ShortcutRow(title: "Capture screen", name: .captureScreen)
                    } footer: {
                        Text("Area is the everyday one. Window grabs the frontmost window with its shadow. Screen grabs the display under the pointer.")
                    }
                }
                .formStyle(.grouped)
                .scrollContentBackground(.hidden)
            }
        }
        .navigationTitle("Shortcuts")
    }
}

private struct ShortcutRow: View {
    let title: String
    let name: KeyboardShortcuts.Name

    var body: some View {
        HStack {
            Text(title)
            Spacer(minLength: 12)
            KeyboardShortcuts.Recorder("", name: name)
                .frame(minWidth: 150, alignment: .trailing)
        }
    }
}

private struct AppSettingsView: View {
    @ObservedObject var launchAtLogin: LaunchAtLoginModel
    @ObservedObject var preferences: Preferences

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                PaneHeader(title: "App")
                Form {
                    Section {
                        HStack(alignment: .center, spacing: 10) {
                            Image(systemName: "folder")
                                .foregroundStyle(.secondary)
                                .font(.title3)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(preferences.saveFolder.lastPathComponent)
                                    .font(.body)
                                    .lineLimit(1)
                                Text(preferences.saveFolder.path)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                    .lineLimit(1)
                                    .truncationMode(.middle)
                            }
                            Spacer(minLength: 8)
                            Button("Choose…", action: chooseFolder)
                            Button("Reveal", action: revealFolder)
                        }
                        .padding(.vertical, 2)
                    } header: {
                        Text("Saving")
                    } footer: {
                        Text("Files are named by date and never overwrite. Saving also keeps a copy on the clipboard.")
                    }

                    Section {
                        Toggle("Launch at login", isOn: Binding(
                            get: { launchAtLogin.isEnabled },
                            set: { launchAtLogin.setEnabled($0) }
                        ))
                        if launchAtLogin.requiresApproval {
                            Text("Approve Snimach under System Settings > General > Login Items.")
                        }
                        if let failure = launchAtLogin.failure {
                            Text(failure)
                                .foregroundStyle(.red)
                        }
                    } header: {
                        Text("System")
                    } footer: {
                        Text("Snimach lives in the menu bar and stays out of the Dock.")
                    }
                }
                .formStyle(.grouped)
                .scrollContentBackground(.hidden)
            }
        }
        .navigationTitle("App")
    }

    private func chooseFolder() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.canCreateDirectories = true
        panel.allowsMultipleSelection = false
        panel.directoryURL = preferences.saveFolder
        panel.prompt = "Choose"
        guard panel.runModal() == .OK, let url = panel.url else { return }
        preferences.saveFolder = url
    }

    private func revealFolder() {
        let folder = preferences.saveFolder
        try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        NSWorkspace.shared.activateFileViewerSelecting([folder])
    }
}
