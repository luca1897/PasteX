import AppKit
import SwiftUI

struct ClipboardRowView: View {
    var item: ClipboardItem
    var isSelected: Bool
    var shortcutNumber: Int?
    var onCopy: () -> Void
    var onPreview: () -> Void
    var onTogglePin: () -> Void
    var onDelete: () -> Void

    @State private var isHovering = false
    private var detectedColor: SmartColor? {
        SmartClipboardDetector.detectColors(in: item.content).first
    }
    private var subtitleText: String? {
        item.type == .color ? nil : item.subtitle
    }
    private var inlineColorPreview: SmartColor? {
        item.type == .color ? nil : detectedColor
    }

    var body: some View {
        HStack(spacing: 14) {
            HStack(spacing: 14) {
                rowIcon

                VStack(alignment: .leading, spacing: 4) {
                    Text(item.title)
                        .font(.system(size: 15, weight: .medium))
                        .foregroundStyle(.primary)
                        .lineLimit(2)

                    if let subtitle = subtitleText {
                        Text(subtitle)
                            .font(.system(size: 12))
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                }

                Spacer(minLength: 8)

                if let inlineColorPreview {
                    InlineColorPreview(color: inlineColorPreview)
                }

                if let shortcutNumber {
                    KeyboardShortcutBadge("⌘\(shortcutNumber)")
                }

                Text(item.timeString)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.secondary)
            }
            .contentShape(Rectangle())
            .gesture(rowTapGesture)
            .frame(maxWidth: .infinity, alignment: .leading)

            HStack(spacing: 10) {
                Button(action: onCopy) {
                    Image(systemName: "doc.on.doc")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(.secondary)
                        .frame(width: 18, height: 18)
                }
                .buttonStyle(.plain)
                .help("Copy")

                Button(action: onTogglePin) {
                    Image(systemName: item.isPinned ? "pin.fill" : "pin")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(item.isPinned ? Color.accentColor : .secondary)
                        .frame(width: 18, height: 18)
                }
                .buttonStyle(.plain)
                .help(item.isPinned ? "Unpin" : "Pin")

                Button(role: .destructive, action: onDelete) {
                    Image(systemName: "trash")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(.secondary)
                        .frame(width: 18, height: 18)
                }
                .buttonStyle(.plain)
                .help("Remove")
            }
            .opacity(isHovering || isSelected || item.isPinned ? 1 : 0.72)
        }
        .padding(.horizontal, 12)
        .frame(height: 68)
        .contentShape(Rectangle())
        .background(selectionBackground)
        .onHover { hovering in
            withAnimation(.spring(response: 0.2, dampingFraction: 0.86)) {
                isHovering = hovering
            }
        }
        .scaleEffect(isHovering ? 1.006 : 1)
    }

    private var rowTapGesture: some Gesture {
        TapGesture()
            .onEnded { onPreview() }
    }

    @ViewBuilder
    private var rowIcon: some View {
        if item.type == .color, let color = detectedColor {
            RoundedRectangle(cornerRadius: 9, style: .continuous)
                .fill(color.color)
                .overlay(alignment: .bottomTrailing) {
                    Image(systemName: "eyedropper.halffull")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(.white)
                        .shadow(color: .black.opacity(0.45), radius: 4, x: 0, y: 1)
                        .padding(7)
                }
                .frame(width: 44, height: 44)
        } else if item.type == .image, let data = item.payloadData, let image = NSImage(data: data) {
            Image(nsImage: image)
                .resizable()
                .scaledToFill()
                .frame(width: 44, height: 44)
                .clipShape(RoundedRectangle(cornerRadius: 9, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 9, style: .continuous)
                        .stroke(.primary.opacity(0.08), lineWidth: 1)
                }
        } else if item.type == .image {
            RoundedRectangle(cornerRadius: 9, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            Color(red: 0.16, green: 0.38, blue: 0.72),
                            Color(red: 0.31, green: 0.64, blue: 0.58),
                            Color(red: 0.90, green: 0.70, blue: 0.42)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .overlay(alignment: .bottomLeading) {
                    Image(systemName: "photo")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.88))
                        .padding(7)
                }
                .frame(width: 44, height: 44)
        } else {
            IconBadge(type: item.type, size: 44)
        }
    }

    @ViewBuilder
    private var selectionBackground: some View {
        if isSelected {
            RoundedRectangle(cornerRadius: 11, style: .continuous)
                .fill(Color.accentColor.opacity(0.14))
                .padding(.vertical, 5)
                .padding(.horizontal, 5)
        } else if isHovering {
            RoundedRectangle(cornerRadius: 11, style: .continuous)
                .fill(.primary.opacity(0.035))
                .padding(.vertical, 5)
                .padding(.horizontal, 5)
        }
    }
}

private struct InlineColorPreview: View {
    var color: SmartColor

    var body: some View {
        HStack(spacing: 6) {
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .fill(color.color)
                .frame(width: 32, height: 20)

            Text(color.hexRGB)
                .font(.system(size: 11.5, weight: .semibold, design: .monospaced))
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
        .padding(.horizontal, 7)
        .frame(height: 30)
        .background(.primary.opacity(0.04), in: RoundedRectangle(cornerRadius: 9, style: .continuous))
        .help(color.rgbaString)
    }
}

#Preview {
    ClipboardRowView(
        item: MockClipboardData.items()[3],
        isSelected: true,
        shortcutNumber: 1,
        onCopy: {},
        onPreview: {},
        onTogglePin: {},
        onDelete: {}
    )
    .frame(width: 480)
    .padding()
}
