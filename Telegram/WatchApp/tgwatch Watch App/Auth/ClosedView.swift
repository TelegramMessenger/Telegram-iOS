import SwiftUI

struct ClosedView: View {
    var body: some View {
        VStack(spacing: 8) {
            Text(L("Watch.Auth.LoggedOut"))
                .font(.headline)
            Text(L("Watch.Auth.RelaunchToSignIn"))
                .font(.footnote)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding()
        .accountSwitcherSheet(presentation: .sheet, logoutAffordance: .suppressed)
    }
}
