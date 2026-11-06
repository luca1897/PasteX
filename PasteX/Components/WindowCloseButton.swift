import AppKit
import SwiftUI

struct WindowCloseButton: View {
    @State private var window: NSWindow?
    @State private var isHovering = false

    var body: some View {
        Button {
            (window ?? NSApp.keyWindow)?.orderOut(nil)
        } label: {
            ZStack {
                Circle()
                    .fill(Color(red: 1.0, green: 0.36, blue: 0.32))

                Image(systemName: "xmark")
                    .font(.system(size: 7, weight: .bold))
                    .foregroundStyle(.black.opacity(0.58))
                    .opacity(isHovering ? 1 : 0)
            }
            .frame(width: 13, height: 13)
            .overlay {
                Circle()
                    .stroke(.black.opacity(0.12), lineWidth: 0.5)
            }
            .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .help("Close")
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.12)) {
                isHovering = hovering
            }
        }
        .background(WindowReader(window: $window).frame(width: 0, height: 0))
    }
}

struct WindowDragArea: NSViewRepresentable {
    func makeNSView(context: Context) -> DragView {
        DragView()
    }

    func updateNSView(_ nsView: DragView, context: Context) {}

    final class DragView: NSView {
        override var mouseDownCanMoveWindow: Bool { false }

        override func mouseDown(with event: NSEvent) {
            window?.performDrag(with: event)
        }
    }
}

private struct WindowReader: NSViewRepresentable {
    @Binding var window: NSWindow?

    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        DispatchQueue.main.async {
            window = view.window
        }
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        DispatchQueue.main.async {
            window = nsView.window
        }
    }
}
