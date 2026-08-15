import SwiftUI

/// A labelled card showing one piece of status (location, destination, instruction).
struct StatusCard: View {
    let label: String
    let value: String
    var valueColor: Color = Theme.primaryText
    var systemImage: String? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                if let systemImage {
                    Image(systemName: systemImage).foregroundStyle(Theme.accent)
                }
                Text(label.uppercased())
                    .font(Theme.label)
                    .foregroundStyle(Theme.secondaryText)
            }
            Text(value)
                .font(Theme.title)
                .foregroundStyle(valueColor)
                .minimumScaleFactor(0.6)
                .lineLimit(3)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(20)
        .background(Theme.surface)
        .clipShape(RoundedRectangle(cornerRadius: Theme.corner, style: .continuous))
        .accessibilityElement(children: .combine)
        .accessibilityLabel(Text("\(label): \(value)"))
    }
}
