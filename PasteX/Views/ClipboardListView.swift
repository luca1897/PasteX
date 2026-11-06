import SwiftUI

struct ClipboardListView: View {
    @ObservedObject var viewModel: ClipboardViewModel
    var showsInlinePreview = false
    var onOpenItem: ((ClipboardItem) -> Void)?
    var onCopied: (ClipboardItem) -> Void = { _ in }

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView(.vertical, showsIndicators: false) {
                LazyVStack(spacing: 16) {
                    if viewModel.filteredItems.isEmpty {
                        emptyState
                            .padding(.top, 80)
                    } else {
                        ForEach(viewModel.sections) { section in
                            VStack(spacing: 0) {
                                SectionHeader(title: section.title)

                                LazyVStack(spacing: 0) {
                                    ForEach(section.items) { item in
                                        ClipboardRowView(
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

                                        if item.id != section.items.last?.id {
                                            Divider()
                                        }
                                    }
                                }
                                .background(.primary.opacity(0.035), in: RoundedRectangle(cornerRadius: 13, style: .continuous))
                                .overlay {
                                    RoundedRectangle(cornerRadius: 13, style: .continuous)
                                        .stroke(.primary.opacity(0.06), lineWidth: 1)
                                }
                            }
                            .transition(.opacity.combined(with: .move(edge: .top)))
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

    private var emptyState: some View {
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
                    .frame(maxWidth: viewModel.showFirstRunOnboarding && viewModel.items.isEmpty ? 330 : 280)
            }

            if viewModel.showFirstRunOnboarding && viewModel.items.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    OnboardingHint(symbolName: "keyboard", text: "Open PasteX with your global shortcut.")
                    OnboardingHint(symbolName: "return", text: "Press Enter to copy the selected clip.")
                    OnboardingHint(symbolName: "sparkles", text: "Use smart actions for URLs, colors, JSON, and email.")
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 12)
                .background(.primary.opacity(0.035), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
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

        return viewModel.showFirstRunOnboarding ? "Welcome to PasteX" : "Clipboard history is empty"
    }

    private var emptyStateMessage: String {
        if !viewModel.items.isEmpty {
            return "Try a different search term."
        }

        return viewModel.showFirstRunOnboarding
            ? "PasteX is ready to collect local clipboard history. Copy text, URLs, code, colors, or images in any app to begin."
            : "Copy something in any app to start collecting clips."
    }
}

private struct OnboardingHint: View {
    var symbolName: String
    var text: String

    var body: some View {
        HStack(spacing: 9) {
            Image(systemName: symbolName)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(Color.accentColor)
                .frame(width: 16)

            Text(text)
                .font(.system(size: 12.5))
                .foregroundStyle(.secondary)
        }
    }
}

#Preview {
    ClipboardListView(viewModel: ClipboardViewModel(preferences: PreferencesViewModel()))
        .frame(width: 520, height: 640)
}
