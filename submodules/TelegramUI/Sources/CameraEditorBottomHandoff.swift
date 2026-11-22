import Foundation
import UIKit
import CameraScreen
import MediaEditorBottomControls

func mediaEditorBottomControlsHandoff(_ handoff: CameraScreenEditorBottomHandoff) -> MediaEditorBottomControlsHandoff {
    let slot: (CameraScreenEditorHandoffSlot?) -> MediaEditorBottomControlsHandoff.Slot? = { slot in
        return slot.map { MediaEditorBottomControlsHandoff.Slot(frame: $0.frame, hasGlass: $0.hasGlass, contentViews: $0.contentViews) }
    }
    return MediaEditorBottomControlsHandoff(left: slot(handoff.left), middle: slot(handoff.middle), right: slot(handoff.right), didAdopt: handoff.didAdopt)
}

func mediaEditorBottomControlsHandBack(_ targets: CameraScreenEditorReturnTargets) -> MediaEditorBottomControlsHandBack {
    let target: (CGRect?) -> MediaEditorBottomControlsHandBack.Target? = { frame in
        return frame.map { MediaEditorBottomControlsHandBack.Target(frame: $0, hasGlass: true) }
    }
    return MediaEditorBottomControlsHandBack(left: target(targets.left), middle: target(targets.middle), right: target(targets.right))
}
