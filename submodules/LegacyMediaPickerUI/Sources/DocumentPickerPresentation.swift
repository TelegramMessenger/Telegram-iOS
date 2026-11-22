import Foundation
import UIKit
import QuartzCore

/// One system document picker shown by `legacyICloudFilePicker`, over a placeholder host controller that
/// covers the screen without drawing anything.
///
/// The host leaves only through the picker's delegate or its `viewDidDisappear`, but a picker can be cancelled
/// before it ever appears, with neither. UIKit holds the picker's presentation back until its remote view is
/// ready (up to 3 s), and a dismissal on the presenting controller meanwhile cancels it silently. The app lock
/// does exactly that when the app goes inactive with passcode auto-lock on (`AppLock` dismisses what the root
/// controller presents, so nothing shows above the lock), and the Face ID prompt of a Files app locked with Face
/// ID makes the app inactive while the picker is held back (#40). The host must then go away by itself, or it
/// keeps taking every touch and the app looks frozen. `isLost` tells that state apart.
final class DocumentPickerPresentation {
    /// How long UIKit may hold a document picker's presentation back (`_beginDelayingPresentation:` with 3 s),
    /// with a margin. A picker that is neither presented nor in a window before then may still appear.
    static let presentationDelayLimit: Double = 4.0

    private let now: () -> Double
    private weak var picker: UIViewController?
    private var requestTime: Double?
    private var didDisappear = false
    private(set) var isFinished = false

    init(now: @escaping () -> Double = { CACurrentMediaTime() }) {
        self.now = now
    }

    func presentationRequested(picker: UIViewController) {
        self.picker = picker
        self.requestTime = self.now()
    }

    /// The picker was on screen and went away. Its delegate may report the pick only after that, and the host
    /// is already leaving, so the picker no longer counts as lost.
    func pickerDidDisappear() {
        self.didDisappear = true
    }

    /// Records that the picker's outcome was delivered. Returns false when it already was, so the outcome is
    /// delivered once even if the delegate calls back after the host gave the picker up.
    func finish() -> Bool {
        if self.isFinished {
            return false
        }
        self.isFinished = true
        return true
    }

    /// The picker was asked for, has neither finished nor disappeared, and was either released (its presentation
    /// was cancelled: UIKit holds a picker it will still present) or is neither presented nor in a window past
    /// the time UIKit may hold its presentation back.
    var isLost: Bool {
        guard let requestTime = self.requestTime, !self.isFinished, !self.didDisappear else {
            return false
        }
        guard let picker = self.picker else {
            return true
        }
        if picker.presentingViewController != nil || picker.viewIfLoaded?.window != nil {
            return false
        }
        return self.now() >= requestTime + DocumentPickerPresentation.presentationDelayLimit
    }
}
