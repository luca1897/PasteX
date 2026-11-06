import SwiftUI

struct SectionHeader: View {
    var title: String

    var body: some View {
        Text(title)
            .font(.system(size: 13, weight: .medium))
            .foregroundStyle(.primary.opacity(0.78))
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 2)
            .padding(.top, 10)
            .padding(.bottom, 6)
    }
}

#Preview {
    SectionHeader(title: "Pinned")
        .padding()
}
