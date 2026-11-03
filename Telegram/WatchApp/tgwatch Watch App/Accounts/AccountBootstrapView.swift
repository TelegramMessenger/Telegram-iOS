import SwiftUI

/// Rendered by `TgwatchApp` whenever there is no active client (fresh install,
/// or just after the last account was removed). On appear it asks the manager
/// to provision a Production account — a no-op if one already exists — which
/// flips `activeClient` and routes the app into `ContentView` → QR login. It
/// only shows persistent UI in the rare persist-failure case, where it surfaces
/// the error and a retry. There is no "welcome"/onboarding step.
struct AccountBootstrapView: View {
    @Environment(AccountManager.self) private var manager

    var body: some View {
        AccountBootstrapContent(
            errorMessage: manager.lastError,
            onRetry: { manager.ensureAccountExists() }
        )
        .task { manager.ensureAccountExists() }
    }
}

/// Pure presentational body for `AccountBootstrapView`. Shows a loading state
/// while provisioning succeeds (the common case — it flashes briefly, then the
/// app swaps to `ContentView`), or an error + retry when account persistence
/// failed.
struct AccountBootstrapContent: View {
    let errorMessage: String?
    let onRetry: () -> Void

    var body: some View {
        if let errorMessage {
            VStack(spacing: 16) {
                Text(errorMessage)
                    .font(.footnote)
                    .foregroundStyle(.red)
                    .multilineTextAlignment(.center)
                    .accessibilityIdentifier("accountBootstrapError")
                Text("Try again")
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(Color.gray.opacity(0.25), in: Capsule())
                    .contentShape(Capsule())
                    .onTapGesture { onRetry() }
                    .accessibilityIdentifier("accountBootstrapRetry")
            }
            .padding()
        } else {
            LoadingView(label: "Preparing…")
        }
    }
}

#if DEBUG
#Preview("Loading") {
    AccountBootstrapContent(errorMessage: nil, onRetry: {})
        .background(Color.black)
        .environment(\.colorScheme, .dark)
}

#Preview("Error") {
    AccountBootstrapContent(errorMessage: "Couldn't save account list.", onRetry: {})
        .background(Color.black)
        .environment(\.colorScheme, .dark)
}
#endif
