import UIKit

private weak var registeredMainWindow: UIWindow?

/// Registers the window the app lays out in, so `mainWindowScreenBounds` can answer for the screen it is on.
func registerMainWindowForScreenBounds(_ window: UIWindow) {
    registeredMainWindow = window
}

/// The bounds of the screen the app's main window is on: what "the whole screen" means for content that spans it,
/// such as a context menu's content area.
///
/// `UIScreen.main` names the device's main screen, which is not always the one the app is on. On iPhone Duo with
/// the phone unfolded it stays the 466x678 cover screen while the window is on the 669x951 inner screen (measured
/// on the simulator), so a rect taken from it is ~200pt short in both directions. Falls back to `UIScreen.main`
/// before a window is registered and outside the app (extensions, tests).
public var mainWindowScreenBounds: CGRect {
    if let screen = registeredMainWindow?.screen {
        return screen.bounds
    }
    return UIScreen.main.bounds
}

/// The screen the app's main window is on (see `mainWindowScreenBounds`): the one whose brightness a screen that lights
/// the user's face or shows a code to scan should raise. Falls back to `UIScreen.main` as `mainWindowScreenBounds` does.
public var mainWindowScreen: UIScreen {
    return registeredMainWindow?.screen ?? UIScreen.main
}
