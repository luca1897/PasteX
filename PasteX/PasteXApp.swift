import AppKit
import Carbon.HIToolbox
import SwiftUI

@main
struct PasteXApp: App {
    @StateObject private var clipboardViewModel: ClipboardViewModel
    @StateObject private var preferencesViewModel: PreferencesViewModel

    init() {
        SingleInstanceGuard.exitIfAnotherInstanceIsRunning()
        PasteXApp.configureApplicationIcon()

        let preferencesViewModel = PreferencesViewModel()
        let clipboardViewModel = ClipboardViewModel(
            preferences: preferencesViewModel
        )
        _clipboardViewModel = StateObject(wrappedValue: clipboardViewModel)
        _preferencesViewModel = StateObject(wrappedValue: preferencesViewModel)

        let registerShortcuts = { [weak preferencesViewModel, weak clipboardViewModel] in
            guard let preferencesViewModel, let clipboardViewModel else { return }

            let registrations = GlobalHotKeyManager.shared.registerShortcuts(
                clipboardShortcut: preferencesViewModel.clipboardShortcut,
                searchShortcut: preferencesViewModel.compactSearchShortcut,
                openClipboard: {
                    PasteXWindowManager.shared.showClipboard(viewModel: clipboardViewModel)
                },
                openSearch: {
                    PasteXWindowManager.shared.showSearch(viewModel: clipboardViewModel)
                }
            )
            preferencesViewModel.updateHotKeyRegistrationStatus(registrations)
        }

        preferencesViewModel.onGlobalShortcutsChanged = registerShortcuts
        preferencesViewModel.onClearHistory = { [weak clipboardViewModel] keepingPinned in
            clipboardViewModel?.clearHistory(keepingPinned: keepingPinned)
        }
        registerShortcuts()
    }

    private static func configureApplicationIcon() {
        if let icon = NSImage(named: "PasteXIcon") {
            NSApplication.shared.applicationIconImage = icon
        }
    }

    var body: some Scene {
        MenuBarExtra("PasteX", systemImage: "clipboard") {
            PasteXMenu(viewModel: clipboardViewModel)
        }
        .menuBarExtraStyle(.menu)
        .commands {
            PasteXWindowCommands(viewModel: clipboardViewModel)
        }

        Settings {
            PreferencesWindow(viewModel: preferencesViewModel)
                .frame(width: 560, height: 420)
        }
        .windowResizability(.contentSize)
    }
}

private enum SingleInstanceGuard {
    static func exitIfAnotherInstanceIsRunning() {
        guard let bundleIdentifier = Bundle.main.bundleIdentifier else { return }

        let currentProcessID = ProcessInfo.processInfo.processIdentifier
        let otherInstances = NSRunningApplication
            .runningApplications(withBundleIdentifier: bundleIdentifier)
            .filter { $0.processIdentifier != currentProcessID && !$0.isTerminated }

        guard let existingInstance = otherInstances.first else { return }
        existingInstance.activate(options: [.activateAllWindows])
        exit(0)
    }
}

private struct PasteXMenu: View {
    @ObservedObject var viewModel: ClipboardViewModel

    var body: some View {
        Button("Open PasteX") {
            PasteXWindowManager.shared.showClipboard(viewModel: viewModel)
        }
        .pasteXKeyboardShortcut(viewModel.clipboardShortcut)

        Button("Compact Search") {
            PasteXWindowManager.shared.showSearch(viewModel: viewModel)
        }
        .pasteXKeyboardShortcut(viewModel.compactSearchShortcut)

        Divider()

        if viewModel.items.isEmpty {
            Text("No recent clips")
        } else {
            Section("Recent Clips") {
                ForEach(Array(viewModel.items.prefix(5))) { item in
                    Menu {
                        Button("Copy") {
                            viewModel.select(item)
                            viewModel.copyToPasteboard(item)
                        }

                        Button("Preview") {
                            viewModel.select(item)
                            PasteXWindowManager.shared.showDetail(viewModel: viewModel)
                        }

                        Button(item.isPinned ? "Unpin" : "Pin") {
                            viewModel.togglePin(item)
                        }

                        Divider()

                        Button("Delete", role: .destructive) {
                            viewModel.delete(item)
                        }
                    } label: {
                        Label(item.menuTitle, systemImage: item.menuSymbolName)
                    }
                }
            }
        }

        Divider()

        Button("Clear History", role: .destructive) {
            viewModel.confirmAndClearHistory()
        }
        .disabled(viewModel.items.isEmpty)

        Divider()

        SettingsLink {
            Text("PasteX Settings...")
        }
        .keyboardShortcut(",", modifiers: .command)

        Divider()

        Button("Quit PasteX") {
            NSApp.terminate(nil)
        }
        .keyboardShortcut("q", modifiers: .command)
    }
}

private extension View {
    @ViewBuilder
    func pasteXKeyboardShortcut(_ shortcut: GlobalShortcut) -> some View {
        if let keyEquivalent = shortcut.keyEquivalent {
            keyboardShortcut(keyEquivalent, modifiers: shortcut.eventModifiers)
        } else {
            self
        }
    }
}

private extension GlobalShortcut {
    var keyEquivalent: KeyEquivalent? {
        switch keyLabel {
        case "Space":
            return .space
        case "↩":
            return .return
        case "⌫":
            return .delete
        default:
            guard let character = keyLabel.lowercased().first else { return nil }
            return KeyEquivalent(character)
        }
    }

    var eventModifiers: SwiftUI.EventModifiers {
        var eventModifiers = SwiftUI.EventModifiers()

        if modifiers & UInt32(controlKey) != 0 {
            eventModifiers.insert(SwiftUI.EventModifiers.control)
        }

        if modifiers & UInt32(optionKey) != 0 {
            eventModifiers.insert(SwiftUI.EventModifiers.option)
        }

        if modifiers & UInt32(shiftKey) != 0 {
            eventModifiers.insert(SwiftUI.EventModifiers.shift)
        }

        if modifiers & UInt32(cmdKey) != 0 {
            eventModifiers.insert(SwiftUI.EventModifiers.command)
        }

        return eventModifiers
    }
}

private extension ClipboardItem {
    var menuTitle: String {
        let source = title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? preview : title
        let compactSource = source.replacingOccurrences(of: "\n", with: " ")

        guard compactSource.count > 42 else {
            return compactSource
        }

        return String(compactSource.prefix(39)) + "..."
    }

    var menuSymbolName: String {
        isPinned ? "pin.fill" : type.symbolName
    }
}

private struct PasteXWindowCommands: Commands {
    @ObservedObject var viewModel: ClipboardViewModel

    var body: some Commands {
        CommandMenu("Clipboard") {
            Button("Open Clipboard Window") {
                PasteXWindowManager.shared.showClipboard(viewModel: viewModel)
            }

            Button("Open Compact Search") {
                PasteXWindowManager.shared.showSearch(viewModel: viewModel)
            }

            Button("Open Preview Panel") {
                PasteXWindowManager.shared.showDetail(viewModel: viewModel)
            }
            .keyboardShortcut("p", modifiers: [.command, .shift])
        }

        CommandGroup(replacing: .appSettings) {
            SettingsLink {
                Text("PasteX Settings...")
            }
                .keyboardShortcut(",", modifiers: .command)
        }
    }
}
