import SwiftUI

struct ErrorView: View {
    @Environment(TDClient.self) private var client
    let message: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Something went wrong")
                .font(.headline)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.vertical, 8)
            if client.useTestDc {
                Text("TEST")
                    .font(.caption2.weight(.semibold))
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color.yellow.opacity(0.25), in: Capsule())
                    .foregroundStyle(.yellow)
                    .accessibilityIdentifier("dcTestBadge")
            }
            Text(message)
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
        .padding()
        .accountSwitcherSheet(presentation: .sheet, logoutAffordance: .suppressed)
    }
}
