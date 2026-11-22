import SwiftUI

struct ClosedView: View {
    var body: some View {
        VStack(spacing: 8) {
            Text("Logged out")
                .font(.headline)
            Text("Relaunch the app to sign in again.")
                .font(.footnote)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding()
        .accountSwitcherSheet(presentation: .sheet, logoutAffordance: .suppressed)
    }
}
