import AppKit
import Carbon.HIToolbox
import SwiftUI

struct MainClipboardWindow: View {
    @ObservedObject var viewModel: ClipboardViewModel
    var layout: ClipboardWindowLayout = .compact
    var presentationID = UUID()
    @State private var isShowingCopiedToast = false
    @State private var copiedToastToken = UUID()
    @State private var copiedItemTitle = ""
    @State private var inlinePreviewItemID: ClipboardItem.ID?

    var body: some View {
        windowContent
        .frame(width: targetWindowSize.width, height: targetWindowSize.height, alignment: .topLeading)
        .glassPanel(cornerRadius: 22, material: .regularMaterial)
        .overlay(alignment: .topLeading) {
            WindowDragArea()
                .frame(width: 462, height: 36)
                .padding(.leading, 44)
        }
        .overlay(alignment: .topLeading) {
            WindowCloseButton()
                .padding(.top, 16)
                .padding(.leading, 18)
        }
        .overlay(alignment: .bottom) {
            if isShowingCopiedToast {
                CopiedToast(title: copiedItemTitle)
                    .padding(.bottom, 68)
                    .transition(.scale(scale: 0.96).combined(with: .opacity))
            }
        }
        .background(MainWindowKeyboardMonitor { event in
            handleKeyDown(event)
        })
        .background(WindowContentSizeController(contentSize: targetWindowSize).frame(width: 0, height: 0))
        .ignoresSafeArea()
        .onAppear {
            NSApp.activate(ignoringOtherApps: true)
            inlinePreviewItemID = nil
        }
        .onChange(of: presentationID) { _, _ in
            inlinePreviewItemID = nil
        }
        .onChange(of: viewModel.selectedItemID) { _, selectedItemID in
            guard layout == .inlinePreview, inlinePreviewItemID != nil else { return }
            inlinePreviewItemID = selectedItemID
        }
    }

    @ViewBuilder
    private var windowContent: some View {
        switch layout {
        case .compact:
            listColumn
        case .inlinePreview:
            HStack(spacing: 0) {
                listColumn
                    .frame(width: 520)

                if inlinePreviewItemID != nil {
                    Divider()
                        .opacity(0.58)

                    inlinePreviewPane
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        }
    }

    private var targetWindowSize: NSSize {
        switch layout {
        case .compact:
            return ClipboardWindowLayout.compact.windowSize
        case .inlinePreview:
            return inlinePreviewItemID == nil
                ? ClipboardWindowLayout.compact.windowSize
                : ClipboardWindowLayout.inlinePreview.windowSize
        }
    }

    private var inlinePreviewPane: some View {
        ZStack {
            Rectangle()
                .fill(.primary.opacity(0.018))

            ClipboardDetailView(viewModel: viewModel, isEmbedded: true)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .clipShape(Rectangle())
    }

    private var listColumn: some View {
        VStack(spacing: 0) {
            SearchField(text: $viewModel.searchText, shortcut: viewModel.compactSearchShortcutDisplay, autoFocus: true)
                .padding(.horizontal, 20)
                .padding(.top, 36)
                .padding(.bottom, 14)

            Group {
                switch viewModel.displayMode {
                case .list:
                    ClipboardListView(
                        viewModel: viewModel,
                        showsInlinePreview: layout == .inlinePreview,
                        onOpenItem: openItem
                    ) { item in
                        showCopiedToast(for: item)
                    }
                case .board:
                    ClipboardBoardView(
                        viewModel: viewModel,
                        showsInlinePreview: layout == .inlinePreview,
                        onOpenItem: openItem
                    ) { item in
                        showCopiedToast(for: item)
                    }
                }
            }
            .padding(.horizontal, 18)

            Spacer(minLength: 0)

            bottomToolbar
        }
    }

    private var bottomToolbar: some View {
        VStack(spacing: 0) {
            Divider()
                .opacity(0.58)

            HStack(spacing: 14) {
                Label(viewModel.itemCountDescription, systemImage: "clipboard")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(.secondary)

                Spacer()

                DisplayModeControl(
                    selection: viewModel.displayMode,
                    onSelect: viewModel.setDisplayMode
                )

                Button {
                    viewModel.toggleSelectedPin()
                } label: {
                    Image(systemName: viewModel.selectedItem?.isPinned == true ? "pin.fill" : "pin")
                }
                .help(viewModel.selectedItem?.isPinned == true ? "Unpin selected item" : "Pin selected item")

                Button(role: .destructive) {
                    viewModel.deleteSelectedItem()
                } label: {
                    Image(systemName: "trash")
                }
                .help("Delete selected item")

                Menu {
                    Button("Open Compact Search") {
                        PasteXWindowManager.shared.showSearch(viewModel: viewModel)
                    }

                    Button(layout == .inlinePreview ? "Hide Inline Preview" : "Show Inline Preview") {
                        PasteXWindowManager.shared.showClipboard(
                            viewModel: viewModel,
                            layout: layout == .inlinePreview ? .compact : .inlinePreview
                        )
                    }

                    Button(viewModel.displayMode == .list ? "Use Board View" : "Use List View") {
                        viewModel.toggleDisplayMode()
                    }

                    Button("Open Preview Panel") {
                        PasteXWindowManager.shared.showDetail(viewModel: viewModel)
                    }

                    Divider()

                    Button("Load Demo Items") {
                        viewModel.seedDemoData()
                    }

                    Button("Clear History") {
                        viewModel.confirmAndClearHistory()
                    }
                    .disabled(viewModel.items.isEmpty)
                } label: {
                    Image(systemName: "ellipsis")
                }
                .menuStyle(.button)
                .menuIndicator(.hidden)
                .help("More actions")
            }
            .buttonStyle(.borderless)
            .font(.system(size: 16, weight: .medium))
            .padding(.horizontal, 22)
            .frame(height: 52)
        }
    }

    private func showCopiedToast(for item: ClipboardItem) {
        let token = UUID()
        copiedToastToken = token
        copiedItemTitle = item.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? item.preview : item.title

        withAnimation(.spring(response: 0.24, dampingFraction: 0.86)) {
            isShowingCopiedToast = true
        }

        Task {
            try? await Task.sleep(nanoseconds: 1_350_000_000)

            await MainActor.run {
                guard copiedToastToken == token else { return }

                withAnimation(.easeOut(duration: 0.18)) {
                    isShowingCopiedToast = false
                }
            }
        }
    }

    private func handleKeyDown(_ event: NSEvent) -> Bool {
        if let shortcutNumber = recentCopyShortcutNumber(from: event) {
            guard let item = viewModel.copyRecentItemToPasteboard(number: shortcutNumber) else { return false }
            showCopiedToast(for: item)
            return true
        }

        switch Int(event.keyCode) {
        case kVK_DownArrow:
            viewModel.selectNextItem()
            return true
        case kVK_UpArrow:
            viewModel.selectPreviousItem()
            return true
        case kVK_Return, kVK_ANSI_KeypadEnter:
            if let item = viewModel.copySelectedToPasteboard() {
                showCopiedToast(for: item)
            }
            return true
        case kVK_Space:
            guard !isEditingText(event) else { return false }
            guard layout != .inlinePreview else { return true }
            PasteXWindowManager.shared.showDetail(viewModel: viewModel)
            return true
        case kVK_Delete:
            guard event.modifierFlags.contains(.command) else { return false }
            viewModel.deleteSelectedItem()
            return true
        case kVK_ANSI_P:
            guard event.modifierFlags.contains(.command) else { return false }
            viewModel.toggleSelectedPin()
            return true
        default:
            return false
        }
    }

    private func recentCopyShortcutNumber(from event: NSEvent) -> Int? {
        let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
        guard flags.contains(.command) else { return nil }
        guard !flags.contains(.control), !flags.contains(.option), !flags.contains(.shift) else { return nil }

        switch Int(event.keyCode) {
        case kVK_ANSI_1, 83:
            return 1
        case kVK_ANSI_2, 84:
            return 2
        case kVK_ANSI_3, 85:
            return 3
        case kVK_ANSI_4, 86:
            return 4
        case kVK_ANSI_5, 87:
            return 5
        case kVK_ANSI_6, 88:
            return 6
        case kVK_ANSI_7, 89:
            return 7
        case kVK_ANSI_8, 91:
            return 8
        case kVK_ANSI_9, 92:
            return 9
        default:
            return nil
        }
    }

    private func isEditingText(_ event: NSEvent) -> Bool {
        event.window?.firstResponder is NSTextView
    }

    private func openItem(_ item: ClipboardItem) {
        guard layout == .inlinePreview else {
            viewModel.select(item)
            PasteXWindowManager.shared.showDetail(viewModel: viewModel)
            return
        }

        viewModel.select(item)
        inlinePreviewItemID = inlinePreviewItemID == item.id ? nil : item.id
    }
}

private struct DisplayModeControl: View {
    var selection: ClipboardDisplayMode
    var onSelect: (ClipboardDisplayMode) -> Void

    var body: some View {
        HStack(spacing: 2) {
            ForEach(ClipboardDisplayMode.allCases) { mode in
                Button {
                    onSelect(mode)
                } label: {
                    Image(systemName: mode.symbolName)
                        .font(.system(size: 12.5, weight: .semibold))
                        .foregroundStyle(selection == mode ? .primary : .secondary)
                        .frame(width: 28, height: 26)
                        .background {
                            if selection == mode {
                                RoundedRectangle(cornerRadius: 7, style: .continuous)
                                    .fill(.primary.opacity(0.08))
                            }
                        }
                }
                .buttonStyle(.plain)
                .help("\(mode.title) view")
            }
        }
        .padding(3)
        .background(.primary.opacity(0.035), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .stroke(.primary.opacity(0.055), lineWidth: 1)
        }
    }
}

private struct WindowContentSizeController: NSViewRepresentable {
    var contentSize: NSSize

    func makeNSView(context: Context) -> NSView {
        NSView(frame: .zero)
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        let targetSize = contentSize

        DispatchQueue.main.async {
            guard let window = nsView.window else { return }

            let currentSize = window.contentLayoutRect.size
            guard currentSize.isMeaningfullyDifferent(from: targetSize) else { return }

            let targetFrameSize = window.frameRect(forContentRect: NSRect(origin: .zero, size: targetSize)).size
            var frame = window.frame
            let oldMaxY = frame.maxY

            frame.size = targetFrameSize
            frame.origin.y = oldMaxY - targetFrameSize.height
            frame.origin = clampedOrigin(for: frame, on: window.screen)

            window.setFrame(frame, display: true, animate: false)
        }
    }

    private func clampedOrigin(for frame: NSRect, on screen: NSScreen?) -> NSPoint {
        let inset: CGFloat = 12
        let visibleFrame = (screen ?? NSScreen.main)?.visibleFrame ?? frame
        let minX = visibleFrame.minX + inset
        let maxX = max(minX, visibleFrame.maxX - frame.width - inset)
        let minY = visibleFrame.minY + inset
        let maxY = max(minY, visibleFrame.maxY - frame.height - inset)

        return NSPoint(
            x: min(max(frame.minX, minX), maxX),
            y: min(max(frame.minY, minY), maxY)
        )
    }
}

private extension CGSize {
    func isMeaningfullyDifferent(from other: CGSize) -> Bool {
        abs(width - other.width) > 0.5 || abs(height - other.height) > 0.5
    }
}

private struct CopiedToast: View {
    var title: String

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(Color.accentColor)

            VStack(alignment: .leading, spacing: 1) {
                Text("Copied to clipboard")
                    .font(.system(size: 13.5, weight: .semibold))
                    .foregroundStyle(.primary)

                Text(title)
                    .font(.system(size: 11.5))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
        }
        .padding(.horizontal, 14)
        .frame(maxWidth: 320, minHeight: 48)
        .background(.regularMaterial, in: Capsule())
        .overlay {
            Capsule()
                .stroke(.white.opacity(0.22), lineWidth: 1)
        }
        .shadow(color: .black.opacity(0.18), radius: 20, x: 0, y: 10)
    }
}

private struct MainWindowKeyboardMonitor: NSViewRepresentable {
    var handle: (NSEvent) -> Bool

    func makeNSView(context: Context) -> MonitorView {
        let view = MonitorView()
        view.handle = handle
        return view
    }

    func updateNSView(_ nsView: MonitorView, context: Context) {
        nsView.handle = handle
    }

    final class MonitorView: NSView {
        var handle: ((NSEvent) -> Bool)?
        private var monitor: Any?

        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()
            installMonitorIfNeeded()
        }

        deinit {
            if let monitor {
                NSEvent.removeMonitor(monitor)
            }
        }

        private func installMonitorIfNeeded() {
            guard monitor == nil else { return }

            monitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
                guard
                    let self,
                    let window,
                    event.window === window,
                    window.isKeyWindow
                else {
                    return event
                }

                return self.handle?(event) == true ? nil : event
            }
        }
    }
}

#Preview {
    MainClipboardWindow(viewModel: ClipboardViewModel(preferences: PreferencesViewModel()))
        .frame(width: 520, height: 760)
}
