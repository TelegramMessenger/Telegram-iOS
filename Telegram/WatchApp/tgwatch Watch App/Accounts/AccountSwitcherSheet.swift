import SwiftUI

/// Where `AccountsListView` should appear from. Sheets layer on top of the
/// current view; `.push` requires the caller to own a `NavigationStack`.
enum AccountSwitcherPresentation {
    case sheet
    case push
}

/// Whether "Log out current" should appear in the action sheet. The chat
/// list passes `.allowed` (authState == .ready); every auth view passes
/// `.suppressed` because there's no signed-in session to log out from.
enum AccountSwitcherLogoutAffordance {
    case allowed
    case suppressed
}

private struct AccountSwitcherSheetModifier: ViewModifier {
    let presentation: AccountSwitcherPresentation
    let logoutAffordance: AccountSwitcherLogoutAffordance

    @Environment(AccountManager.self) private var manager
    @State private var showActionSheet = false
    @State private var showLogoutConfirm = false
    @State private var showAccountsList = false

    func body(content: Content) -> some View {
        // `.simultaneousGesture(LongPressGesture(...))` instead of
        // `.onLongPressGesture { ... }` so taps on interactive children
        // (e.g. `SecureField` in `PasswordEntryView`, the row buttons in
        // `ChatListView`'s List) keep working. The `.onLongPressGesture`
        // form swallows tap delivery to descendants; the simultaneous
        // form lets both gestures fire independently.
        content
            .simultaneousGesture(
                LongPressGesture(minimumDuration: 0.6)
                    .onEnded { _ in showActionSheet = true }
            )
            .confirmationDialog(
                "Accounts",
                isPresented: $showActionSheet,
                titleVisibility: .hidden
            ) {
                Button("Switch account…") {
                    showAccountsList = true
                }
                if logoutAffordance == .allowed {
                    Button("Log out current", role: .destructive) {
                        showLogoutConfirm = true
                    }
                }
                Button("Cancel", role: .cancel) {}
            }
            .confirmationDialog(
                "Log out?",
                isPresented: $showLogoutConfirm,
                titleVisibility: .visible
            ) {
                Button("Log out", role: .destructive) {
                    Task { await manager.removeActive() }
                }
                Button("Cancel", role: .cancel) {}
            }
            .modifier(
                AccountsListPresenter(
                    presentation: presentation,
                    isPresented: $showAccountsList
                )
            )
    }
}

/// Inner modifier whose job is to pick `.sheet` vs. `.navigationDestination`.
/// Splitting it out keeps `AccountSwitcherSheetModifier.body` readable.
private struct AccountsListPresenter: ViewModifier {
    let presentation: AccountSwitcherPresentation
    @Binding var isPresented: Bool

    func body(content: Content) -> some View {
        switch presentation {
        case .sheet:
            content.sheet(isPresented: $isPresented) {
                NavigationStack {
                    AccountsListView()
                }
            }
        case .push:
            content.navigationDestination(isPresented: $isPresented) {
                AccountsListView()
            }
        }
    }
}

extension View {
    /// Adds the multi-account long-press affordance. Pass `.suppressed` for
    /// `logoutAffordance` on any view where no signed-in session exists yet.
    func accountSwitcherSheet(
        presentation: AccountSwitcherPresentation,
        logoutAffordance: AccountSwitcherLogoutAffordance
    ) -> some View {
        modifier(AccountSwitcherSheetModifier(
            presentation: presentation,
            logoutAffordance: logoutAffordance
        ))
    }
}
