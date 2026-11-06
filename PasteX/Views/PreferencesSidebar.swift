import SwiftUI

struct PreferencesSidebar: View {
    @Binding var selection: PreferencesSection

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            ForEach(PreferencesSection.allCases) { section in
                Button {
                    withAnimation(.spring(response: 0.24, dampingFraction: 0.86)) {
                        selection = section
                    }
                } label: {
                    HStack(spacing: 10) {
                        Image(systemName: section.symbolName)
                            .font(.system(size: 15, weight: .medium))
                            .frame(width: 20)

                        Text(section.rawValue)
                            .font(.system(size: 13.5, weight: .medium))

                        Spacer(minLength: 0)
                    }
                    .foregroundStyle(selection == section ? .primary : .secondary)
                    .padding(.horizontal, 12)
                    .frame(height: 38)
                    .contentShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                    .background {
                        if selection == section {
                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                .fill(.primary.opacity(0.08))
                        }
                    }
                }
                .buttonStyle(.plain)
            }

            Spacer()
        }
        .padding(10)
        .frame(width: 148)
        .background(.thinMaterial)
    }
}

#Preview {
    PreferencesSidebar(selection: .constant(.general))
        .frame(height: 360)
}
