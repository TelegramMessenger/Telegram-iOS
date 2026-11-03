import UIKit

public extension UIApplication {
    /// Replacement for `UIApplication.windows`, which iOS 15 deprecated in favour of reading the
    /// windows off a relevant `UIWindowScene`.
    ///
    /// Collects the windows of every connected window scene. Within a scene the ordering matches what
    /// the old property returned, so for the single-scene case — which is what the app runs in outside
    /// of external-display setups — `first` / `last` / `reversed()` keep their previous meaning.
    var allWindowSceneWindows: [UIWindow] {
        // `connectedScenes` is an unordered Set, while the old `windows` property was ordered
        // back-to-front by window level. Prefer the foreground-active scene so that callers taking
        // `first`/`last`/`reversed()` see the scene the user is actually looking at (iPad
        // multi-window, Stage Manager and external displays all produce several window scenes),
        // and sort by level to restore the documented ordering.
        var windowScenes: [UIWindowScene] = []
        for scene in self.connectedScenes {
            guard let windowScene = scene as? UIWindowScene else {
                continue
            }
            windowScenes.append(windowScene)
        }
        let foregroundScenes = windowScenes.filter { $0.activationState == .foregroundActive }
        let effectiveScenes = foregroundScenes.isEmpty ? windowScenes : foregroundScenes

        var result: [UIWindow] = []
        for windowScene in effectiveScenes {
            result.append(contentsOf: windowScene.windows.sorted(by: { $0.windowLevel < $1.windowLevel }))
        }
        return result
    }
}
