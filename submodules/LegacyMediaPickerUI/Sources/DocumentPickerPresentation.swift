import Foundation
import UIKit

/// One system document picker shown by `legacyICloudFilePicker`, over a placeholder host controller that
/// covers the screen without drawing anything.
///
/// The host leaves only through the picker's delegate or its `viewDidDisappear`, but the system can drop the
/// picker without either: with "Unlock with Face ID" on for the Files app, the app resigns active for the
/// Face ID prompt and the picker never appears (#40). The host must then go away by itself, or it keeps
/// taking every touch and the app looks frozen. `isLost` tells that state apart.
final class DocumentPickerPresentation {
    private weak var picker: UIViewController?
    private var isRequested = false
    private var didDisappear = false
    private(set) var isFinished = false

    func presentationRequested(picker: UIViewController) {
        self.picker = picker
        self.isRequested = true
    }

    /// Records that the picker's outcome was delivered. Returns false when it already was, so the outcome is
    /// delivered once even if the delegate calls back after the host gave the picker up.
    /// The picker was on screen and went away. Its delegate may report the pick only after that, and the host
    /// is already leaving, so the picker no longer counts as lost.
    func pickerDidDisappear() {
        self.didDisappear = true
    }

    func finish() -> Bool {
        if self.isFinished {
            return false
        }
        self.isFinished = true
        return true
    }

    /// The picker was asked for, has neither finished nor disappeared, and is neither presented nor in a window.
    var isLost: Bool {
        guard self.isRequested, !self.isFinished, !self.didDisappear else {
            return false
        }
        guard let picker = self.picker else {
            return true
        }
        return picker.presentingViewController == nil && picker.viewIfLoaded?.window == nil
    }
}
