import SwiftUI

struct LoadingView: View {
    let label: String
    var body: some View {
        VStack(spacing: 8) {
            ProgressView()
            Text(label)
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
        .padding()
        .accountSwitcherSheet(presentation: .sheet, logoutAffordance: .suppressed)
    }
}
