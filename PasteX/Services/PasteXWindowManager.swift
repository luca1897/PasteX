import AppKit
import SwiftUI

@MainActor
final class PasteXWindowManager {
    static let shared = PasteXWindowManager()

    private var clipboardWindow: ManagedPasteXWindow?
    private var detailWindow: ManagedPasteXWindow?
    private var searchWindow: ManagedPasteXWindow?
    private var clipboardPresentationID = UUID()

    private init() {}

    func showClipboard(viewModel: ClipboardViewModel, layout: ClipboardWindowLayout? = nil) {
        searchWindow?.hide()
        let resolvedLayout = layout ?? viewModel.preferredClipboardWindowLayout

        if let layout {
            viewModel.setPreferredClipboardWindowLayout(layout)
        }

        clipboardPresentationID = UUID()

        show(
            window: &clipboardWindow,
            title: "PasteX",
            size: resolvedLayout.initialWindowSize,
            contentFrameSize: resolvedLayout.windowSize,
            content: MainClipboardWindow(
                viewModel: viewModel,
                layout: resolvedLayout,
                presentationID: clipboardPresentationID
            )
        )
    }

    func showDetail(viewModel: ClipboardViewModel) {
        let anchorFrame = clipboardWindow?.visibleFrame

        show(
            window: &detailWindow,
            title: "PasteX Inspector",
            size: NSSize(width: 440, height: 600),
            content: ClipboardDetailView(viewModel: viewModel),
            anchorFrame: anchorFrame
        )
    }

    func showSearch(viewModel: ClipboardViewModel) {
        clipboardWindow?.hide()

        show(
            window: &searchWindow,
            title: "PasteX Search",
            size: NSSize(width: 440, height: 280),
            content: CompactSearchOverlay(viewModel: viewModel)
        )
    }

    private func show<Content: View>(
        window managedWindow: inout ManagedPasteXWindow?,
        title: String,
        size: NSSize,
        contentFrameSize: NSSize? = nil,
        content: Content,
        anchorFrame: NSRect? = nil
    ) {
        let rootSize = contentFrameSize ?? size
        let rootView = AnyView(content.frame(width: rootSize.width, height: rootSize.height, alignment: .topLeading))

        if let managedWindow {
            managedWindow.update(rootView: rootView, size: size)
            managedWindow.show(anchorFrame: anchorFrame)
            return
        }

        let panel = PasteXFloatingPanel(
            contentRect: NSRect(origin: .zero, size: size),
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        panel.title = title
        panel.contentViewController = makeHostingController(rootView: rootView)

        let newWindow = ManagedPasteXWindow(panel: panel)
        managedWindow = newWindow
        newWindow.show(anchorFrame: anchorFrame)
    }

    private func makeHostingController(rootView: AnyView) -> NSHostingController<AnyView> {
        let hostingController = NSHostingController(rootView: rootView)
        hostingController.view.wantsLayer = true
        hostingController.view.layer?.backgroundColor = NSColor.clear.cgColor
        return hostingController
    }
}

enum ClipboardWindowLayout: Equatable {
    case compact
    case inlinePreview

    var windowSize: NSSize {
        switch self {
        case .compact:
            NSSize(width: 520, height: 760)
        case .inlinePreview:
            NSSize(width: 960, height: 760)
        }
    }

    var initialWindowSize: NSSize {
        switch self {
        case .compact:
            windowSize
        case .inlinePreview:
            ClipboardWindowLayout.compact.windowSize
        }
    }
}

private final class PasteXFloatingPanel: NSPanel {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }
}

@MainActor
private final class ManagedPasteXWindow: NSObject, NSWindowDelegate {
    private let panel: PasteXFloatingPanel

    var visibleFrame: NSRect? {
        panel.isVisible ? panel.frame : nil
    }

    init(panel: PasteXFloatingPanel) {
        self.panel = panel
        super.init()

        panel.delegate = self
        panel.isReleasedWhenClosed = false
        panel.backgroundColor = .clear
        panel.isOpaque = false
        panel.hasShadow = false
        panel.hidesOnDeactivate = false
        panel.level = .floating
        panel.isMovableByWindowBackground = true
        panel.collectionBehavior = [.fullScreenAuxiliary, .moveToActiveSpace]
    }

    func update(rootView: AnyView, size: NSSize) {
        if let hostingController = panel.contentViewController as? NSHostingController<AnyView> {
            hostingController.rootView = rootView
        } else {
            let hostingController = NSHostingController(rootView: rootView)
            hostingController.view.wantsLayer = true
            hostingController.view.layer?.backgroundColor = NSColor.clear.cgColor
            panel.contentViewController = hostingController
        }

        panel.setContentSize(size)
    }

    func show(anchorFrame: NSRect? = nil) {
        if let anchorFrame {
            panel.setFrameOrigin(inspectorOrigin(anchorFrame: anchorFrame))
        } else {
            panel.center()
        }

        NSApp.activate(ignoringOtherApps: true)
        panel.makeKeyAndOrderFront(nil)
    }

    func hide() {
        panel.orderOut(nil)
    }

    private func inspectorOrigin(anchorFrame: NSRect) -> NSPoint {
        let gap: CGFloat = 14
        let inset: CGFloat = 12
        let panelSize = panel.frame.size
        let screenFrame = screenFrame(containing: anchorFrame)

        let preferredRightX = anchorFrame.maxX + gap
        let fallbackLeftX = anchorFrame.minX - gap - panelSize.width
        let minX = screenFrame.minX + inset
        let maxX = max(minX, screenFrame.maxX - panelSize.width - inset)
        let centeredX = screenFrame.midX - panelSize.width / 2
        let unclampedX: CGFloat

        if preferredRightX <= maxX {
            unclampedX = preferredRightX
        } else if fallbackLeftX >= minX {
            unclampedX = fallbackLeftX
        } else {
            unclampedX = centeredX
        }

        let centeredY = anchorFrame.midY - panelSize.height / 2
        let minY = screenFrame.minY + inset
        let maxY = max(minY, screenFrame.maxY - panelSize.height - inset)
        let x = clamped(unclampedX, min: minX, max: maxX)
        let y = clamped(centeredY, min: minY, max: maxY)

        return NSPoint(x: x, y: y)
    }

    private func screenFrame(containing rect: NSRect) -> NSRect {
        let center = NSPoint(x: rect.midX, y: rect.midY)

        if let screen = NSScreen.screens.first(where: { $0.visibleFrame.contains(center) || $0.frame.contains(center) }) {
            return screen.visibleFrame
        }

        if let screen = NSScreen.screens.first(where: { $0.visibleFrame.intersects(rect) || $0.frame.intersects(rect) }) {
            return screen.visibleFrame
        }

        return NSScreen.main?.visibleFrame ?? rect
    }

    private func clamped(_ value: CGFloat, min minValue: CGFloat, max maxValue: CGFloat) -> CGFloat {
        Swift.min(Swift.max(value, minValue), maxValue)
    }
}
