import SwiftUI
import WatchKit

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
        // Long press anywhere opens the switcher; how it is attached differs
        // between watchOS 26 and 11 (see `longPressContent`).
        longPressContent(content)
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

    @ViewBuilder
    private func longPressContent(_ content: Content) -> some View {
        if #available(watchOS 26.0, *) {
            content.simultaneousGesture(
                LongPressGesture(minimumDuration: 0.6)
                    .onEnded { _ in showActionSheet = true }
            )
        } else {
            // watchOS-11 (measured on the 11.5 simulator):
            //   - `.simultaneousGesture(LongPressGesture)` on the content stops the
            //     ScrollView from scrolling, and never fires over a `Button`.
            //   - `.onLongPressGesture` on the content keeps scroll and taps
            //     working, but a `Button` still takes the touch: a long press on a
            //     chat row fires the row's tap.
            // So the content gets `.onLongPressGesture` (covers everything that
            // is not a button), and buttons that cover the screen (chat rows)
            // pick the action up from the environment through
            // `accountSwitcherRowButtonStyle()`.
            content
                .onLongPressGesture(minimumDuration: 0.6) { showActionSheet = true }
                .environment(\.accountSwitcherLongPress, AccountSwitcherLongPressAction {
                    showActionSheet = true
                })
        }
    }
}

/// The account switcher's long-press action, published to the content on
/// watchOS < 26 only (where the content-level gesture cannot see through
/// buttons). `nil` everywhere else.
struct AccountSwitcherLongPressAction {
    let perform: () -> Void
}

private struct AccountSwitcherLongPressKey: EnvironmentKey {
    static let defaultValue: AccountSwitcherLongPressAction? = nil
}

extension EnvironmentValues {
    var accountSwitcherLongPress: AccountSwitcherLongPressAction? {
        get { self[AccountSwitcherLongPressKey.self] }
        set { self[AccountSwitcherLongPressKey.self] = newValue }
    }
}

/// A plain button whose tap and long press are peer gestures on the label, so
/// both fire on watchOS 11 (a `Button` with an attached long press fires its
/// tap instead). The long press opens the account switcher when one is in
/// the environment.
///
/// A primitive style draws no pressed state, so the row takes one from the
/// long press's `onPressingChanged`: it reports touch-down at once, and the
/// end of the touch on release, on reaching the minimum duration, or when the
/// finger moves off (a scroll).
private struct AccountSwitcherRowButtonStyle: PrimitiveButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        AccountSwitcherRowButton(configuration: configuration)
    }
}

private struct AccountSwitcherRowButton: View {
    let configuration: PrimitiveButtonStyleConfiguration
    @Environment(\.accountSwitcherLongPress) private var longPress
    @State private var isPressed = false

    var body: some View {
        configuration.label
            .contentShape(Rectangle())
            .scaleEffect(isPressed ? 0.96 : 1)
            .opacity(isPressed ? 0.7 : 1)
            .animation(.easeOut(duration: 0.12), value: isPressed)
            .onTapGesture { configuration.trigger() }
            .onLongPressGesture(minimumDuration: 0.6) {
                guard let longPress else { return }
                WKInterfaceDevice.current().play(.click)
                longPress.perform()
            } onPressingChanged: { pressing in
                isPressed = pressing
            }
            .accessibilityAddTraits(.isButton)
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

    /// `.buttonStyle(.plain)` for a button that fills much of an
    /// `accountSwitcherSheet` screen (a chat row). On watchOS < 26 it also
    /// opens the account switcher on long press, which the content-level
    /// gesture cannot do over a button there.
    @ViewBuilder
    func accountSwitcherRowButtonStyle() -> some View {
        if #available(watchOS 26.0, *) {
            buttonStyle(.plain)
        } else {
            buttonStyle(AccountSwitcherRowButtonStyle())
        }
    }
}
