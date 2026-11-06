import AppKit
import SwiftUI

struct CompactSearchOverlay: View {
    @ObservedObject var viewModel: ClipboardViewModel
    @State private var query = ""

    private var suggestions: [ClipboardItem] {
        viewModel.suggestions(for: query)
    }

    var body: some View {
        VStack(spacing: 0) {
            SearchField(text: $query, shortcut: viewModel.compactSearchShortcutDisplay, autoFocus: true)
                .padding(.horizontal, 18)
                .padding(.top, 16)
                .padding(.bottom, 10)

            VStack(spacing: 0) {
                HStack {
                    Text("Suggestions")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(.secondary)

                    Spacer()
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 6)

                if suggestions.isEmpty {
                    emptySearchState
                } else {
                    ForEach(suggestions) { item in
                        Button {
                            viewModel.select(item)
                            PasteXWindowManager.shared.showDetail(viewModel: viewModel)
                        } label: {
                            HStack(spacing: 12) {
                                IconBadge(type: item.type, size: 24)

                                Text(item.title)
                                    .font(.system(size: 13.5, weight: .medium))
                                    .lineLimit(1)

                                Spacer()

                                if item.isPinned {
                                    Image(systemName: "pin.fill")
                                        .font(.system(size: 12, weight: .medium))
                                        .foregroundStyle(Color.accentColor)
                                }
                            }
                            .contentShape(Rectangle())
                            .padding(.horizontal, 20)
                            .frame(height: 38)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }

            Spacer(minLength: 0)

            footer
        }
        .glassPanel(cornerRadius: 18, material: .regularMaterial)
        .ignoresSafeArea()
        .onAppear {
            NSApp.activate(ignoringOtherApps: true)
        }
    }

    private var footer: some View {
        Button {
            PasteXWindowManager.shared.showClipboard(viewModel: viewModel)
        } label: {
            HStack {
                Text("Open PasteX")
                    .font(.system(size: 13.5, weight: .medium))

                Spacer()

                KeyboardShortcutBadge(viewModel.clipboardShortcutDisplay)
            }
            .padding(.horizontal, 20)
            .frame(height: 48)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .background(.primary.opacity(0.035))
    }

    private var emptySearchState: some View {
        VStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 22, weight: .medium))
                .foregroundStyle(.tertiary)

            Text("No suggestions")
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 28)
    }
}

#Preview {
    CompactSearchOverlay(viewModel: ClipboardViewModel(preferences: PreferencesViewModel()))
        .frame(width: 440, height: 280)
}
