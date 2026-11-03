import SwiftUI

struct DaySeparatorView: View {
    let label: DayLabel

    var body: some View {
        HStack {
            Spacer()
            Text(label.label)
                .font(.caption2)
                .foregroundStyle(.secondary)
                .padding(.horizontal, 8)
                .padding(.vertical, 2)
                .background(Capsule().fill(Color.gray.opacity(0.2)))
            Spacer()
        }
        .padding(.vertical, 2)
        .accessibilityIdentifier("day.\(label.key)")
    }
}
