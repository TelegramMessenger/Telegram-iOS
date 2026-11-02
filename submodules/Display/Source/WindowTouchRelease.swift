import Foundation
import UIKit
import UIKit.UIGestureRecognizerSubclass

/// The main window's recognizers let go of the touches they hold as the window's scene deactivates (#127).
///
/// After going to the Home Screen and back, a chat could not be scrolled until it was left (iOS 27.2 device). A swipe
/// Home begins as a touch in the app: the strip under a chat's composer is the chat's list. If the system takes that
/// touch and the app never hears it end, every recognizer it reached keeps holding it, and UIKit resets a touch's
/// recognizers only once all of them are done. One left `.possible` on a finger that never moves (the list's two-finger
/// selection pan, the back swipe) keeps the others from being reset, the list's pan among them, and a recognizer that
/// failed or ended takes no new touch until it is reset: no finger scrolls the chat until its views leave the window.
/// Reproduced on the simulator by withholding a touch's end from the window; that a device withholds it is suspected,
/// not observed (the simulator resets the recognizers itself as the app resigns).
///
/// So as the scene deactivates, every recognizer in the window still holding a touch is toggled off and back on (one
/// recognizing is cancelled, one still deciding fails), all of them off before any is back on, and the touches'
/// recognizers can be reset. Again as the scene activates, unless a finger came down on the way back, whose gesture is
/// kept. A recognizer the app turned off stays off; the window's own (the system's gates) are left alone. The touch
/// itself cannot be asked: once UIKit has processed its end, it no longer lists the recognizers still holding it.
public final class WindowTouchRelease {
    /// Debug Settings ▸ "Chat: CoreList scroll trace" (the chat's backend sets it): a line at every scene change, with
    /// the recognizers let go of, so that a device trace shows whether a touch was ever stuck.
    public static var trace: ((String) -> Void)?

    private let holders: () -> [UIGestureRecognizer]
    private var touchDowns = 0
    /// The touch-downs so far when the scene last deactivated, until it activates again.
    private var touchDownsAtDeactivation: Int?

    /// `holders`: the recognizers holding touches, `WindowTouchRelease.holders(in:)` of the window.
    init(holders: @escaping () -> [UIGestureRecognizer]) {
        self.holders = holders
    }

    /// Every event the window sends.
    func update(with event: UIEvent) {
        guard event.type == .touches, let touches = event.allTouches else {
            return
        }
        for touch in touches where touch.phase == .began {
            self.touchBegan()
        }
    }

    func touchBegan() {
        self.touchDowns &+= 1
    }

    func sceneWillDeactivate() {
        self.touchDownsAtDeactivation = self.touchDowns
        self.release(reason: "deactivate")
    }

    func sceneDidActivate() {
        guard let touchDownsAtDeactivation = self.touchDownsAtDeactivation else {
            return
        }
        self.touchDownsAtDeactivation = nil
        if touchDownsAtDeactivation != self.touchDowns {
            WindowTouchRelease.trace?("TOUCH-RELEASE activate kept touchDowns=\(self.touchDowns &- touchDownsAtDeactivation)")
            return
        }
        self.release(reason: "activate")
    }

    /// The enabled recognizers under `view` holding touches, but those on a window.
    static func holders(in view: UIView) -> [UIGestureRecognizer] {
        var result: [UIGestureRecognizer] = []
        var stack: [UIView] = [view]
        while let view = stack.popLast() {
            if !(view is UIWindow), let recognizers = view.gestureRecognizers {
                for recognizer in recognizers where recognizer.isEnabled && recognizer.numberOfTouches != 0 {
                    result.append(recognizer)
                }
            }
            stack.append(contentsOf: view.subviews)
        }
        return result
    }

    private func release(reason: String) {
        let recognizers = self.holders()
        if let trace = WindowTouchRelease.trace {
            var line = "TOUCH-RELEASE \(reason) recognizers=\(recognizers.count)"
            if !recognizers.isEmpty {
                line += " " + recognizers.map { "\(type(of: $0)):\(WindowTouchRelease.traceName($0.state))/\($0.numberOfTouches)" }.joined(separator: ",")
            }
            trace(line)
        }
        for recognizer in recognizers {
            recognizer.isEnabled = false
        }
        for recognizer in recognizers {
            recognizer.isEnabled = true
        }
    }

    private static func traceName(_ state: UIGestureRecognizer.State) -> String {
        switch state {
        case .possible:
            return "possible"
        case .began:
            return "began"
        case .changed:
            return "changed"
        case .ended:
            return "ended"
        case .cancelled:
            return "cancelled"
        case .failed:
            return "failed"
        @unknown default:
            return "unknown"
        }
    }
}
