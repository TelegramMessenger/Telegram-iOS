import Foundation
import UIKit
import Display

public enum MediaPickerCameraCellSubject {
    case chatAssets
    case sticker
    case avatar
    case other
    case noCamera
}

public enum MediaPickerCameraCellBranch: Equatable {
    case none
    case legacyAttachmentCamera
    case chatCamera
    case editorCamera
}

public func mediaPickerCameraCellBranch(flagOn: Bool, subject: MediaPickerCameraCellSubject, isIpad: Bool, isSimulator: Bool) -> MediaPickerCameraCellBranch {
    switch subject {
    case .chatAssets:
        return flagOn ? .chatCamera : .legacyAttachmentCamera
    case .sticker, .avatar:
        return (isIpad || isSimulator) ? .none : .editorCamera
    case .other, .noCamera:
        return .none
    }
}

public func mediaPickerRequestsCameraAccess(subject: MediaPickerCameraCellSubject) -> Bool {
    return subject != .noCamera
}

public func mediaPickerCameraCellPreviewSize(branch: MediaPickerCameraCellBranch, layoutWidth: CGFloat, screenWidth: CGFloat) -> CGSize {
    switch branch {
    case .chatCamera:
        return CGSize(width: screenWidth, height: floorToScreenPixels(screenWidth * 4.0 / 3.0))
    case .none, .legacyAttachmentCamera, .editorCamera:
        return CGSize(width: screenWidth, height: floorToScreenPixels(layoutWidth * 1.77778))
    }
}

public enum MediaPickerCameraCellCaptureAction: Equatable {
    case none
    case start
    case stop
}

public func mediaPickerChatCameraCellCaptureAction(isActive: Bool, hasLivePreview: Bool, isInvalidated: Bool, isInWindow: Bool, isHandedOff: Bool) -> MediaPickerCameraCellCaptureAction {
    if isHandedOff {
        return .none
    }
    if isActive && hasLivePreview && !isInvalidated && isInWindow {
        return .start
    }
    return .stop
}
