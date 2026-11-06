import AppKit
import SwiftUI

struct ClipboardBoardView: View {
    @ObservedObject var viewModel: ClipboardViewModel
    var showsInlinePreview = false
    var onOpenItem: ((ClipboardItem) -> Void)?
    var onCopied: (ClipboardItem) -> Void = { _ in }

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView(.vertical, showsIndicators: false) {
                LazyVStack(alignment: .leading, spacing: 18) {
                    if viewModel.filteredItems.isEmpty {
                        boardEmptyState
                            .padding(.top, 82)
                    } else {
                        ForEach(viewModel.sections) { section in
                            VStack(alignment: .leading, spacing: 10) {
                                SectionHeader(title: section.title)

                                HStack(alignment: .top, spacing: 12) {
                                    boardColumn(items: columnItems(in: section.items, column: 0))
                                    boardColumn(items: columnItems(in: section.items, column: 1))
                                }
                            }
                        }
                    }
                }
                .padding(.bottom, 18)
            }
            .onChange(of: viewModel.selectedItemID) { _, selectedItemID in
                guard let selectedItemID else { return }
                withAnimation(.spring(response: 0.28, dampingFraction: 0.9)) {
                    proxy.scrollTo(selectedItemID, anchor: .center)
                }
            }
        }
        .animation(.spring(response: 0.28, dampingFraction: 0.9), value: viewModel.searchText)
        .animation(.spring(response: 0.28, dampingFraction: 0.9), value: viewModel.items)
    }

    private func boardColumn(items: [ClipboardItem]) -> some View {
        LazyVStack(spacing: 12) {
            ForEach(items) { item in
                ClipboardBoardCardView(
                    item: item,
                    isSelected: item.id == viewModel.selectedItemID,
                    shortcutNumber: viewModel.shortcutNumber(for: item),
                    onCopy: {
                        viewModel.select(item)
                        viewModel.copyToPasteboard(item)
                        onCopied(item)
                    },
                    onPreview: {
                        if let onOpenItem {
                            onOpenItem(item)
                        } else {
                            viewModel.select(item)

                            if !showsInlinePreview {
                                PasteXWindowManager.shared.showDetail(viewModel: viewModel)
                            }
                        }
                    },
                    onTogglePin: {
                        viewModel.togglePin(item)
                    },
                    onDelete: {
                        viewModel.delete(item)
                    }
                )
                .id(item.id)
            }
        }
        .frame(maxWidth: .infinity)
    }

    private func columnItems(in items: [ClipboardItem], column: Int) -> [ClipboardItem] {
        items.enumerated().compactMap { index, item in
            index % 2 == column ? item : nil
        }
    }

    private var boardEmptyState: some View {
        VStack(spacing: viewModel.showFirstRunOnboarding && viewModel.items.isEmpty ? 18 : 14) {
            AppIconMark(size: viewModel.showFirstRunOnboarding && viewModel.items.isEmpty ? 58 : 52)

            VStack(spacing: 5) {
                Text(emptyStateTitle)
                    .font(.system(size: 16, weight: .semibold))

                Text(emptyStateMessage)
                    .font(.system(size: 13))
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .lineSpacing(3)
                    .frame(maxWidth: 320)
            }

            if viewModel.items.isEmpty {
                Button("Load Demo Items") {
                    viewModel.seedDemoData()
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 28)
    }

    private var emptyStateTitle: String {
        if !viewModel.items.isEmpty {
            return "No matching clips"
        }

        return viewModel.showFirstRunOnboarding ? "Welcome to PasteX" : "Clipboard board is empty"
    }

    private var emptyStateMessage: String {
        if !viewModel.items.isEmpty {
            return "Try a different search term."
        }

        return "Copy text, URLs, code, colors, or images in any app to start filling the board."
    }
}

private struct ClipboardBoardCardView: View {
    var item: ClipboardItem
    var isSelected: Bool
    var shortcutNumber: Int?
    var onCopy: () -> Void
    var onPreview: () -> Void
    var onTogglePin: () -> Void
    var onDelete: () -> Void

    @State private var isHovering = false

    private var detectedColor: SmartColor? {
        SmartClipboardDetector.primaryColorCandidate(in: item.content)
            ?? SmartClipboardDetector.detectColors(in: item.content).first
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 9) {
            cardHeader
            previewContent
            Spacer(minLength: 0)
            cardFooter
        }
        .padding(10)
        .frame(maxWidth: .infinity, minHeight: cardHeight, maxHeight: cardHeight, alignment: .topLeading)
        .contentShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .background(cardBackground)
        .overlay(cardBorder)
        .overlay(alignment: .topTrailing) {
            cardActions
                .padding(8)
        }
        .onTapGesture(perform: onPreview)
        .onHover { hovering in
            withAnimation(.spring(response: 0.2, dampingFraction: 0.86)) {
                isHovering = hovering
            }
        }
        .scaleEffect(isHovering ? 1.008 : 1)
    }

    private var cardHeader: some View {
        HStack(spacing: 5) {
            Text(item.type.displayName)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.secondary)

            Text(shortRelativeDate)
                .font(.system(size: 10.5, weight: .medium))
                .foregroundStyle(.tertiary)

            Spacer(minLength: 0)

            if let shortcutNumber {
                KeyboardShortcutBadge("⌘\(shortcutNumber)")
            }

            if item.isPinned {
                Image(systemName: "pin.fill")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(Color.accentColor)
            }
        }
        .padding(.trailing, isHovering || isSelected ? 74 : 0)
    }

    @ViewBuilder
    private var previewContent: some View {
        switch item.type {
        case .image:
            imagePreview
        case .url:
            urlPreview
        case .code:
            codePreview
        case .json:
            jsonPreview
        case .email:
            emailPreview
        case .color:
            colorPreview
        case .file:
            filePreview
        case .text:
            textPreview
        }
    }

    private var imagePreview: some View {
        Group {
            if let data = item.payloadData, let image = NSImage(data: data) {
                Image(nsImage: image)
                    .resizable()
                    .scaledToFill()
            } else {
                LinearGradient(
                    colors: [
                        Color(red: 0.18, green: 0.38, blue: 0.74),
                        Color(red: 0.25, green: 0.62, blue: 0.55),
                        Color(red: 0.92, green: 0.72, blue: 0.45)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .overlay {
                    Image(systemName: "photo")
                        .font(.system(size: 26, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.84))
                }
            }
        }
        .frame(height: 120)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(.primary.opacity(0.08), lineWidth: 1)
        }
    }

    private var urlPreview: some View {
        VStack(alignment: .leading, spacing: 8) {
            ZStack(alignment: .bottomLeading) {
                LinearGradient(
                    colors: [
                        item.type.tint.opacity(0.22),
                        Color.accentColor.opacity(0.12),
                        .white.opacity(0.10)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )

                HStack(spacing: 7) {
                    Image(systemName: "globe")
                        .font(.system(size: 14, weight: .semibold))

                    Text(urlHost)
                        .font(.system(size: 11.5, weight: .medium))
                        .lineLimit(1)
                }
                .foregroundStyle(.primary.opacity(0.78))
                .padding(9)
            }
            .frame(height: 70)
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))

            Text(item.title)
                .font(.system(size: 13.5, weight: .semibold))
                .lineLimit(2)
        }
    }

    private var codePreview: some View {
        codeBlock(text: item.preview, tint: item.type.tint)
    }

    private var jsonPreview: some View {
        codeBlock(text: item.preview, tint: item.type.tint)
    }

    private func codeBlock(text: String, tint: Color) -> some View {
        Text(compactMultiline(text))
            .font(.system(size: 11.5, weight: .regular, design: .monospaced))
            .foregroundStyle(.primary)
            .lineSpacing(3)
            .lineLimit(7)
            .frame(maxWidth: .infinity, alignment: .topLeading)
            .padding(10)
            .background(tint.opacity(0.12), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay(alignment: .topTrailing) {
                Image(systemName: item.type.symbolName)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(tint)
                    .padding(8)
            }
    }

    private var emailPreview: some View {
        VStack(alignment: .leading, spacing: 8) {
            IconBadge(type: .email, size: 34)

            Text(item.title)
                .font(.system(size: 13.5, weight: .semibold))
                .lineLimit(2)

            Text(item.preview)
                .font(.system(size: 11.5))
                .foregroundStyle(.secondary)
                .lineSpacing(2)
                .lineLimit(4)
        }
    }

    private var colorPreview: some View {
        let color = detectedColor

        return VStack(alignment: .leading, spacing: 9) {
            RoundedRectangle(cornerRadius: 13, style: .continuous)
                .fill(color?.color ?? item.type.tint)
                .frame(height: 72)
                .overlay(alignment: .bottomLeading) {
                    Text(color?.hexRGB ?? item.title)
                        .font(.system(size: 12, weight: .semibold, design: .monospaced))
                        .foregroundStyle(.white)
                        .shadow(color: .black.opacity(0.35), radius: 4, x: 0, y: 1)
                        .padding(10)
                }

            if let color {
                Text(color.rgbaString)
                    .font(.system(size: 11.5, weight: .medium, design: .monospaced))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
        }
    }

    private var textPreview: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(item.title)
                .font(.system(size: 14, weight: .semibold))
                .lineLimit(3)

            Text(item.preview)
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
                .lineSpacing(3)
                .lineLimit(5)
        }
    }

    private var filePreview: some View {
        VStack(alignment: .leading, spacing: 8) {
            IconBadge(type: .file, size: 36)

            Text(item.title)
                .font(.system(size: 13.5, weight: .semibold))
                .lineLimit(2)

            Text(item.preview)
                .font(.system(size: 11.5))
                .foregroundStyle(.secondary)
                .lineLimit(3)
        }
    }

    private var cardFooter: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(item.type.tint)
                .frame(width: 6, height: 6)

            Text(item.sourceApp)
                .font(.system(size: 10.5, weight: .medium))
                .foregroundStyle(.tertiary)
                .lineLimit(1)
        }
    }

    private var cardActions: some View {
        HStack(spacing: 6) {
            Button(action: onCopy) {
                Image(systemName: "doc.on.doc")
            }
            .help("Copy")

            Button(action: onTogglePin) {
                Image(systemName: item.isPinned ? "pin.fill" : "pin")
            }
            .help(item.isPinned ? "Unpin" : "Pin")

            Button(role: .destructive, action: onDelete) {
                Image(systemName: "trash")
            }
            .help("Remove")
        }
        .font(.system(size: 11.5, weight: .semibold))
        .buttonStyle(.plain)
        .foregroundStyle(.secondary)
        .padding(.horizontal, 7)
        .frame(height: 28)
        .background(.regularMaterial, in: Capsule())
        .overlay {
            Capsule()
                .stroke(.primary.opacity(0.06), lineWidth: 1)
        }
        .opacity(isHovering || isSelected ? 1 : 0)
        .allowsHitTesting(isHovering || isSelected)
    }

    private var cardBackground: some View {
        RoundedRectangle(cornerRadius: 16, style: .continuous)
            .fill(.primary.opacity(isSelected ? 0.075 : 0.045))
    }

    private var cardBorder: some View {
        RoundedRectangle(cornerRadius: 16, style: .continuous)
            .stroke(isSelected ? Color.accentColor.opacity(0.34) : .primary.opacity(0.065), lineWidth: 1)
    }

    private var cardHeight: CGFloat {
        switch item.type {
        case .image:
            return 192
        case .url:
            return 172
        case .code, .json:
            return 178
        case .email:
            return 168
        case .color:
            return 154
        case .file:
            return 156
        case .text:
            return 150
        }
    }

    private var shortRelativeDate: String {
        let seconds = max(0, Date().timeIntervalSince(item.createdAt))

        switch seconds {
        case 0..<60:
            return "now"
        case 60..<3_600:
            return "\(Int(seconds / 60))m"
        case 3_600..<86_400:
            return "\(Int(seconds / 3_600))h"
        case 86_400..<604_800:
            return "\(Int(seconds / 86_400))d"
        default:
            return "\(Int(seconds / 604_800))w"
        }
    }

    private var urlHost: String {
        guard let host = URLComponents(string: item.content)?.host else {
            return item.subtitle ?? item.preview
        }

        return host.replacingOccurrences(of: "www.", with: "")
    }

    private func compactMultiline(_ text: String) -> String {
        text
            .split(separator: "\n", omittingEmptySubsequences: false)
            .prefix(8)
            .joined(separator: "\n")
    }
}

#Preview {
    ClipboardBoardView(viewModel: ClipboardViewModel(preferences: PreferencesViewModel()))
        .frame(width: 484, height: 640)
        .padding()
}
