import Foundation
import UIKit
import Display

public func chatMediaEditorLocksPortrait(isPainting: Bool, isEditingCover: Bool) -> Bool {
    return isPainting || isEditingCover
}

public func chatMediaEditorSupportedOrientations(locksPortrait: Bool) -> ViewControllerSupportedOrientations {
    if locksPortrait {
        return ViewControllerSupportedOrientations(regularSize: .all, compactSize: .portrait)
    }
    return ViewControllerSupportedOrientations(regularSize: .all, compactSize: .allButUpsideDown)
}

public func chatMediaEditorCaptionIsVisible(toolbarSide: ChatMediaEditorToolbarSide?, isToolActive: Bool, isInterfaceHidden: Bool) -> Bool {
    return toolbarSide == nil && !isToolActive && !isInterfaceHidden
}

public func chatMediaEditorLocksOrientation(isTracking: Bool) -> Bool {
    return isTracking
}

public func chatMediaEditorLockedOrientationMask(_ orientation: UIInterfaceOrientation?) -> UIInterfaceOrientationMask? {
    switch orientation {
    case .portrait:
        return .portrait
    case .portraitUpsideDown:
        return .portraitUpsideDown
    case .landscapeLeft:
        return .landscapeLeft
    case .landscapeRight:
        return .landscapeRight
    default:
        return nil
    }
}

public struct ChatMediaEditorTrackingSet: Equatable {
    public private(set) var sources: Set<String> = Set()

    public init() {
    }

    public var isTracking: Bool {
        return !self.sources.isEmpty
    }

    public mutating func update(_ tracking: Bool, source: String) {
        if tracking {
            self.sources.insert(source)
        } else {
            self.sources.remove(source)
        }
    }
}

extension ChatMediaEditorScreen.Node {
    func setInteractionTracking(_ tracking: Bool, source: String) {
        self.interactionTracking.update(tracking, source: source)
        guard let controller = self.controller else {
            return
        }
        let locks = chatMediaEditorLocksOrientation(isTracking: self.interactionTracking.isTracking)
        if locks && !controller.lockOrientation {
            controller.lockedOrientation = chatMediaEditorLockedOrientationMask(self.validLayout?.metrics.orientation)
        }
        controller.lockOrientation = locks
    }

    func updatePortraitLock() {
        let locksPortrait = chatMediaEditorLocksPortrait(isPainting: self.activeTool == .paint, isEditingCover: self.activeTool == .cover)
        self.controller?.supportedOrientations = chatMediaEditorSupportedOrientations(locksPortrait: locksPortrait)
    }
}
