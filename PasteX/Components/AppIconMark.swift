import SwiftUI

struct AppIconMark: View {
    var size: CGFloat = 64

    var body: some View {
        Image("PasteXIcon")
            .resizable()
            .interpolation(.high)
            .antialiased(true)
            .scaledToFit()
            .frame(width: size, height: size)
            .accessibilityHidden(true)
    }
}

#Preview {
    AppIconMark()
        .padding()
}
