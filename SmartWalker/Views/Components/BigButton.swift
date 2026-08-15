import SwiftUI

/// A large, high-contrast, accessible button for the main user mode.
struct BigButton: View {
    let title: String
    var systemImage: String? = nil
    var background: Color = Theme.accent
    var foreground: Color = .black
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 14) {
                if let systemImage {
                    Image(systemName: systemImage)
                        .font(.system(size: 28, weight: .bold))
                }
                Text(title)
                    .font(Theme.body)
                    .minimumScaleFactor(0.7)
                    .lineLimit(2)
            }
            .frame(maxWidth: .infinity, minHeight: Theme.buttonMinHeight)
            .padding(.horizontal, 16)
            .background(background)
            .foregroundStyle(foreground)
            .clipShape(RoundedRectangle(cornerRadius: Theme.corner, style: .continuous))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text(title))
        .accessibilityAddTraits(.isButton)
    }
}
