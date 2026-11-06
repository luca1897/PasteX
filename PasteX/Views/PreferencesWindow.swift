import AppKit
import Carbon.HIToolbox
import SwiftUI

struct PreferencesWindow: View {
    @ObservedObject var viewModel: PreferencesViewModel
    @State private var showingClearHistoryAlert = false

    var body: some View {
        HStack(spacing: 0) {
            PreferencesSidebar(selection: $viewModel.selectedSection)

            Divider()

            VStack(alignment: .leading, spacing: 0) {
                Text(viewModel.selectedSection.rawValue)
                    .font(.system(size: 20, weight: .semibold))
                    .padding(.horizontal, 24)
                    .padding(.top, 24)
                    .padding(.bottom, 16)

                Group {
                    switch viewModel.selectedSection {
                    case .general:
                        generalSection
                    case .history:
                        historySection
                    case .pinned:
                        pinnedSection
                    case .shortcuts:
                        shortcutsSection
                    case .advanced:
                        advancedSection
                    case .about:
                        aboutSection
                    }
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 24)

                Spacer(minLength: 0)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
        .background(WindowConfigurator(role: .preferences))
        .background(.regularMaterial)
        .onAppear {
            viewModel.refreshLaunchAtLoginStatus()
        }
        .alert("Clear Clipboard History?", isPresented: $showingClearHistoryAlert) {
            Button("Cancel", role: .cancel) {}
            Button("Keep Pinned", role: .destructive) {
                viewModel.clearHistory(keepingPinned: true)
            }
            Button("Delete All", role: .destructive) {
                viewModel.clearHistory(keepingPinned: false)
            }
        } message: {
            Text("Choose whether pinned items should be kept or deleted too.")
        }
    }

    private var generalSection: some View {
        VStack(spacing: 0) {
            SettingsToggleRow(
                title: "Launch at login",
                subtitle: viewModel.launchAtLoginStatusMessage,
                isOn: $viewModel.launchAtLogin
            )
            SettingsToggleRow(title: "Show in menu bar", isOn: $viewModel.showInMenuBar)
            SettingsToggleRow(
                title: "Inline preview",
                subtitle: "Open PasteX with list and detail in one window.",
                isOn: $viewModel.preferInlinePreview
            )

            SettingsValueRow(title: "Default view") {
                Picker("", selection: $viewModel.clipboardDisplayMode) {
                    ForEach(ClipboardDisplayMode.allCases) { mode in
                        Label(mode.title, systemImage: mode.symbolName)
                            .tag(mode)
                    }
                }
                .pickerStyle(.segmented)
                .labelsHidden()
                .frame(width: 132)
            }

            SettingsValueRow(title: "History limit") {
                Stepper(value: $viewModel.historyLimit, in: 50...2_000, step: 50) {
                    Text("\(viewModel.historyLimit)")
                        .monospacedDigit()
                        .frame(width: 52, alignment: .trailing)
                }
                .frame(width: 116)
            }

            SettingsToggleRow(
                title: "Ignore sensitive content",
                subtitle: "Passwords, credit cards, etc.",
                isOn: $viewModel.ignoreSensitiveContent
            )

            SettingsValueRow(title: "Clear history") {
                Button("Clear...") {
                    showingClearHistoryAlert = true
                }
                .controlSize(.small)
            }
        }
        .settingsCard()
    }

    private var historySection: some View {
        VStack(spacing: 0) {
            SettingsValueRow(title: "Retain clips") {
                Picker("", selection: $viewModel.retention) {
                    ForEach(viewModel.retentionOptions, id: \.self) { option in
                        Text(option).tag(option)
                    }
                }
                .labelsHidden()
                .frame(width: 126)
            }

            SettingsValueRow(title: "Max items") {
                Stepper(value: $viewModel.maxItems, in: 100...3_000, step: 100) {
                    Text("\(viewModel.maxItems)")
                        .monospacedDigit()
                        .frame(width: 52, alignment: .trailing)
                }
                .frame(width: 116)
            }

            SettingsToggleRow(title: "Include images", isOn: $viewModel.includeImages)
            SettingsToggleRow(title: "Include files", isOn: $viewModel.includeFiles)
        }
        .settingsCard()
    }

    private var pinnedSection: some View {
        VStack(spacing: 0) {
            SettingsToggleRow(
                title: "Protect pinned items from automatic cleanup",
                subtitle: "Manual clearing always asks what to do with pinned items.",
                isOn: $viewModel.keepPinnedWhenClearing
            )
            SettingsToggleRow(title: "Show pinned section first", isOn: $viewModel.showPinnedFirst)

            SettingsValueRow(title: "Pinned item limit") {
                Stepper(value: $viewModel.pinnedLimit, in: 10...200, step: 10) {
                    Text("\(viewModel.pinnedLimit)")
                        .monospacedDigit()
                        .frame(width: 42, alignment: .trailing)
                }
                .frame(width: 104)
            }
        }
        .settingsCard()
    }

    private var shortcutsSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Text("Window shortcuts")
                        .font(.system(size: 13, weight: .semibold))

                    Text("Native app commands available while PasteX is active")
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                }

                Spacer()

                KeyboardShortcutBadge(viewModel.clipboardShortcut.displayText)
            }
            .padding(14)
            .subtleControlBackground(cornerRadius: 12)

            if let shortcutStatusMessage = viewModel.shortcutStatusMessage {
                Text(shortcutStatusMessage)
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 2)
            }

            VStack(spacing: 0) {
                ForEach(viewModel.shortcuts) { shortcut in
                    ShortcutRow(
                        shortcut: shortcut,
                        isRecording: viewModel.recordingShortcutID == shortcut.id,
                        onRecord: {
                            viewModel.startRecordingShortcut(shortcut.id)
                        },
                        onCancel: {
                            viewModel.cancelRecordingShortcut()
                        },
                        onShortcut: { newShortcut in
                            viewModel.updateShortcut(newShortcut, for: shortcut.id)
                        }
                    )

                    if shortcut.id != viewModel.shortcuts.last?.id {
                        Divider()
                            .padding(.leading, 14)
                    }
                }
            }
            .settingsCard()

            Button("Reset Shortcuts") {
                viewModel.resetGlobalShortcuts()
            }
            .controlSize(.small)
        }
    }

    private var advancedSection: some View {
        VStack(spacing: 0) {
            SettingsToggleRow(title: "Reduce motion", isOn: $viewModel.reduceMotion)
        }
        .settingsCard()
    }

    private var aboutSection: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(spacing: 16) {
                AppIconMark(size: 68)

                VStack(alignment: .leading, spacing: 5) {
                    Text("PasteX")
                        .font(.system(size: 22, weight: .semibold))

                    Text("Version 1.0")
                        .font(.system(size: 13))
                        .foregroundStyle(.secondary)
                }

                Spacer()
            }

            Text("A native macOS clipboard manager built with SwiftUI, SQLite history, global shortcuts, and local clipboard capture.")
                .font(.system(size: 13))
                .foregroundStyle(.secondary)
                .lineSpacing(4)
        }
        .padding(18)
        .settingsCard()
    }
}

private struct SettingsToggleRow: View {
    var title: String
    var subtitle: String?
    @Binding var isOn: Bool

    var body: some View {
        SettingsValueRow(title: title, subtitle: subtitle) {
            Toggle("", isOn: $isOn)
                .labelsHidden()
        }
    }
}

private struct SettingsValueRow<Accessory: View>: View {
    var title: String
    var subtitle: String?
    @ViewBuilder var accessory: Accessory

    var body: some View {
        HStack(spacing: 18) {
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.system(size: 13.5))

                if let subtitle {
                    Text(subtitle)
                        .font(.system(size: 11.5))
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            accessory
        }
        .frame(minHeight: subtitle == nil ? 52 : 64)
        .padding(.horizontal, 14)
        .overlay(alignment: .bottom) {
            Divider()
                .padding(.leading, 14)
                .opacity(0.55)
        }
    }
}

private struct ShortcutRow: View {
    var shortcut: ShortcutSetting
    var isRecording: Bool
    var onRecord: () -> Void
    var onCancel: () -> Void
    var onShortcut: (GlobalShortcut) -> Void

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 3) {
                Text(shortcut.title)
                    .font(.system(size: 13.5))

                Text(shortcut.subtitle)
                    .font(.system(size: 11.5))
                    .foregroundStyle(.secondary)
            }

            Spacer()

            if isRecording {
                ShortcutRecorderView(onShortcut: onShortcut, onCancel: onCancel)
                    .frame(width: 118, height: 30)
            } else {
                Button {
                    onRecord()
                } label: {
                    KeyboardShortcutBadge(shortcut.keys)
                }
                .buttonStyle(.plain)
                .disabled(!shortcut.isEditable)
                .help(shortcut.isEditable ? "Record shortcut" : "Fixed shortcut")
            }
        }
        .padding(.horizontal, 14)
        .frame(height: 58)
        .contentShape(Rectangle())
    }
}

private struct ShortcutRecorderView: NSViewRepresentable {
    var onShortcut: (GlobalShortcut) -> Void
    var onCancel: () -> Void

    func makeNSView(context: Context) -> RecorderView {
        let view = RecorderView()
        view.onShortcut = onShortcut
        view.onCancel = onCancel
        return view
    }

    func updateNSView(_ nsView: RecorderView, context: Context) {
        nsView.onShortcut = onShortcut
        nsView.onCancel = onCancel

        DispatchQueue.main.async {
            nsView.window?.makeFirstResponder(nsView)
        }
    }

    final class RecorderView: NSView {
        var onShortcut: ((GlobalShortcut) -> Void)?
        var onCancel: (() -> Void)?

        override var acceptsFirstResponder: Bool { true }

        override func draw(_ dirtyRect: NSRect) {
            super.draw(dirtyRect)

            let path = NSBezierPath(roundedRect: bounds, xRadius: 7, yRadius: 7)
            NSColor.controlAccentColor.withAlphaComponent(0.14).setFill()
            path.fill()

            NSColor.controlAccentColor.withAlphaComponent(0.45).setStroke()
            path.lineWidth = 1
            path.stroke()

            let text = "Press keys"
            let attributes: [NSAttributedString.Key: Any] = [
                .font: NSFont.systemFont(ofSize: 12, weight: .medium),
                .foregroundColor: NSColor.secondaryLabelColor
            ]
            let attributedText = NSAttributedString(string: text, attributes: attributes)
            let textSize = attributedText.size()
            attributedText.draw(
                at: NSPoint(
                    x: bounds.midX - textSize.width / 2,
                    y: bounds.midY - textSize.height / 2
                )
            )
        }

        override func keyDown(with event: NSEvent) {
            if event.keyCode == UInt16(kVK_Escape) {
                onCancel?()
                return
            }

            guard let shortcut = GlobalShortcut(event: event) else {
                NSSound.beep()
                return
            }

            onShortcut?(shortcut)
        }
    }
}

private extension View {
    func settingsCard() -> some View {
        background(.primary.opacity(0.035), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(.primary.opacity(0.06), lineWidth: 1)
            }
    }
}

#Preview {
    let preferences = PreferencesViewModel()
    PreferencesWindow(
        viewModel: preferences
    )
        .frame(width: 560, height: 420)
}
