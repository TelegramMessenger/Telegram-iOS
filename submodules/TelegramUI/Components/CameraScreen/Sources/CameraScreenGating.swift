import Foundation
import CoreGraphics

public enum CameraScreenModeKind: Equatable {
    case story
    case sticker
    case avatar
    case chat
}

public enum CameraScreenCaptureKind: Equatable {
    case photo
    case video
    case live
}

public enum CameraScreenFlashKind: Equatable {
    case off
    case on
    case auto
}

public enum CameraScreenAccessStatus: Equatable {
    case notDetermined
    case allowed
    case denied
}

public struct CameraScreenStoryControls: Equatable {
    public var dualCamera: Bool
    public var collage: Bool
    public var liveStream: Bool
    public var storyGallery: Bool
    public var tooltips: Bool
    public var storyPrivacy: Bool
    public var recentGalleryAsset: Bool

    public init(dualCamera: Bool, collage: Bool, liveStream: Bool, storyGallery: Bool, tooltips: Bool, storyPrivacy: Bool, recentGalleryAsset: Bool) {
        self.dualCamera = dualCamera
        self.collage = collage
        self.liveStream = liveStream
        self.storyGallery = storyGallery
        self.tooltips = tooltips
        self.storyPrivacy = storyPrivacy
        self.recentGalleryAsset = recentGalleryAsset
    }
}

public struct ChatCameraRecordingCaptureModes: Equatable {
    public enum Mode: Equatable {
        case photo
        case video
    }

    public var beforeRecording: Mode?
    public var afterRecording: Mode?

    public init(beforeRecording: Mode?, afterRecording: Mode?) {
        self.beforeRecording = beforeRecording
        self.afterRecording = afterRecording
    }
}

private let storyPreviewAspectRatio: CGFloat = 1.77778
private let storyMaxRecordingDuration: Double = 59.0
private let storyRecordingProgressDuration: Double = 60.0
private let chatMaxZoomScale: Float = 8.0

public func cameraScreenStoryControls(mode: CameraScreenModeKind) -> CameraScreenStoryControls {
    switch mode {
    case .story:
        return CameraScreenStoryControls(dualCamera: true, collage: true, liveStream: true, storyGallery: true, tooltips: true, storyPrivacy: true, recentGalleryAsset: true)
    case .sticker, .avatar:
        return CameraScreenStoryControls(dualCamera: false, collage: false, liveStream: false, storyGallery: false, tooltips: true, storyPrivacy: true, recentGalleryAsset: true)
    case .chat:
        return CameraScreenStoryControls(dualCamera: false, collage: false, liveStream: false, storyGallery: false, tooltips: false, storyPrivacy: false, recentGalleryAsset: false)
    }
}

public func cameraScreenUsesModalPresentation(mode: CameraScreenModeKind) -> Bool {
    switch mode {
    case .story:
        return false
    case .sticker, .avatar, .chat:
        return true
    }
}

public func cameraScreenInvalidatesCameraOnDismiss(mode: CameraScreenModeKind, hasHolder: Bool) -> Bool {
    switch mode {
    case .story:
        return true
    case .chat:
        return !hasHolder
    case .sticker, .avatar:
        return false
    }
}

public func cameraScreenPreviewAspectRatio(mode: CameraScreenModeKind, captureKind: CameraScreenCaptureKind, isTablet: Bool) -> CGFloat {
    if case .chat = mode, case .photo = captureKind, !isTablet {
        return 4.0 / 3.0
    }
    return storyPreviewAspectRatio
}

public func cameraScreenHoldMinimumPressDuration(mode: CameraScreenModeKind) -> Double {
    if case .chat = mode {
        return 0.25
    }
    return 0.3
}

public func cameraScreenRequiresMicrophone(mode: CameraScreenModeKind) -> Bool {
    if case .chat = mode {
        return false
    }
    return true
}

public func cameraScreenHasAllRequiredAccess(mode: CameraScreenModeKind, camera: CameraScreenAccessStatus, microphone: CameraScreenAccessStatus) -> Bool {
    switch camera {
    case .notDetermined:
        return true
    case .allowed:
        if !cameraScreenRequiresMicrophone(mode: mode) {
            return true
        }
        switch microphone {
        case .notDetermined, .allowed:
            return true
        case .denied:
            return false
        }
    case .denied:
        return false
    }
}

public func cameraScreenCanSetupCamera(mode: CameraScreenModeKind, camera: CameraScreenAccessStatus, microphone: CameraScreenAccessStatus) -> Bool {
    guard case .allowed = camera else {
        return false
    }
    if !cameraScreenRequiresMicrophone(mode: mode) {
        return true
    }
    return microphone == .allowed
}

public func cameraScreenRequestsMicrophone(mode: CameraScreenModeKind, allowVideo: Bool, hasAudio: Bool) -> Bool {
    if case .chat = mode {
        return allowVideo && hasAudio
    }
    return true
}

public func cameraScreenPushesAudioSessionOnActivation(mode: CameraScreenModeKind) -> Bool {
    if case .chat = mode {
        return false
    }
    return true
}

public func chatCameraNeedsAudioSession(captureKind: CameraScreenCaptureKind, isRecording: Bool, allowVideo: Bool, hasAudio: Bool) -> Bool {
    guard allowVideo && hasAudio else {
        return false
    }
    return chatCameraEffectiveCaptureKind(captureKind: captureKind, isRecording: isRecording) == .video
}

public func chatCameraEffectiveCaptureKind(captureKind: CameraScreenCaptureKind, isRecording: Bool) -> CameraScreenCaptureKind {
    if isRecording {
        return .video
    }
    return captureKind
}

public func cameraScreenMaxRecordingDuration(mode: CameraScreenModeKind) -> Double? {
    if case .chat = mode {
        return nil
    }
    return storyMaxRecordingDuration
}

public func cameraScreenShouldStopRecording(mode: CameraScreenModeKind, duration: Double) -> Bool {
    guard let maxDuration = cameraScreenMaxRecordingDuration(mode: mode) else {
        return false
    }
    return duration > maxDuration
}

public func cameraScreenHoldRecordingProgress(mode: CameraScreenModeKind, duration: Double) -> Float {
    if case .chat = mode {
        return 0.0
    }
    return min(1.0, Float(duration / storyRecordingProgressDuration))
}

public func cameraScreenTimecode(mode: CameraScreenModeKind, duration: Double) -> String {
    let duration = Int(duration)
    if case .chat = mode {
        if duration >= 3600 {
            return String(format: "%d:%02d:%02d", duration / 3600, (duration / 60) % 60, duration % 60)
        } else {
            return String(format: "%02d:%02d", duration / 60, duration % 60)
        }
    }
    return String(format: "%02d:%02d", (duration / 60) % 60, duration % 60)
}

public func cameraScreenAvailableModes(mode: CameraScreenModeKind, allowPhoto: Bool, allowVideo: Bool, canLivestream: Bool, isTablet: Bool) -> [CameraScreenCaptureKind] {
    if case .chat = mode {
        var result: [CameraScreenCaptureKind] = []
        if allowPhoto {
            result.append(.photo)
        }
        if allowVideo {
            result.append(.video)
        }
        return result
    }
    var result: [CameraScreenCaptureKind] = [.photo, .video]
    if !isTablet && canLivestream {
        result.append(.live)
    }
    return result
}

public func cameraScreenShowsModeControl(mode: CameraScreenModeKind, availableModes: [CameraScreenCaptureKind]) -> Bool {
    switch mode {
    case .sticker:
        return false
    case .chat:
        return availableModes.count > 1
    case .story, .avatar:
        return true
    }
}

public func chatCameraInitialMode(allowPhoto: Bool, allowVideo: Bool) -> CameraScreenCaptureKind {
    if !allowPhoto && allowVideo {
        return .video
    }
    return .photo
}

public func cameraScreenAllowsHoldToRecord(mode: CameraScreenModeKind, allowVideo: Bool) -> Bool {
    switch mode {
    case .sticker:
        return false
    case .chat:
        return allowVideo
    case .story, .avatar:
        return true
    }
}

public func chatCameraRecordingCaptureModes(captureKind: CameraScreenCaptureKind) -> ChatCameraRecordingCaptureModes {
    if case .photo = captureKind {
        return ChatCameraRecordingCaptureModes(beforeRecording: .video, afterRecording: .photo)
    }
    return ChatCameraRecordingCaptureModes(beforeRecording: nil, afterRecording: nil)
}

public func cameraScreenNextFlashMode(mode: CameraScreenModeKind, current: CameraScreenFlashKind, captureKind: CameraScreenCaptureKind) -> CameraScreenFlashKind {
    if case .chat = mode {
        if case .off = current {
            return .auto
        }
        return .off
    }
    switch current {
    case .off:
        return .on
    case .on:
        return captureKind == .video ? .off : .auto
    case .auto:
        return .off
    }
}

public func cameraScreenFlashModeAfterModeSwitch(mode: CameraScreenModeKind, current: CameraScreenFlashKind, to captureKind: CameraScreenCaptureKind) -> CameraScreenFlashKind? {
    if case .chat = mode {
        if case .on = current {
            return .auto
        }
        return nil
    }
    if case .video = captureKind, case .auto = current {
        return .on
    }
    return nil
}

public func chatCameraZoomLevels(backLevels: [Float], isFront: Bool) -> [Float] {
    if isFront {
        return [1.0]
    }
    return backLevels
}

public func chatCameraHoldZoomScale(startScale: Float, travel: Float, levels: [Float]) -> Float {
    return chatCameraClampedZoomScale(levels: levels, scale: startScale + max(0.0, travel))
}

public func chatCameraExposureValue(current: CGFloat, translation: CGFloat) -> CGFloat {
    return max(-1.0, min(1.0, current + translation / 750.0))
}

public func chatCameraExposureBias(value: CGFloat) -> CGFloat {
    return -value
}

public func chatCameraExposureSliderOffset(value: CGFloat) -> CGFloat {
    return value * (144.0 - 25.0) / 2.0
}

public func chatCameraClampedZoomScale(levels: [Float], scale: Float) -> Float {
    let minimum = levels.min() ?? 1.0
    return max(minimum, min(chatMaxZoomScale, scale))
}

public func chatCameraSelectedZoomLevel(levels: [Float], scale: Float) -> Float {
    let sorted = levels.sorted()
    var result = sorted.first ?? 1.0
    for level in sorted where level <= scale + 0.001 {
        result = level
    }
    return result
}

public func chatCameraZoomLabel(level: Float, selected: Bool, scale: Float) -> String {
    let value = selected ? scale : level
    let rounded = (value * 10.0).rounded() / 10.0
    let text: String
    if rounded == rounded.rounded() {
        text = "\(Int(rounded))"
    } else {
        text = String(format: "%.1f", rounded)
    }
    return selected ? "\(text)×" : text
}

public func chatCameraUnseenQRCodes(_ codes: [String], seen: Set<String>) -> [String] {
    var result: [String] = []
    for code in codes {
        if !seen.contains(code) && !result.contains(code) {
            result.append(code)
        }
    }
    return result
}

public func captureControlsLockReferenceFrameWithoutGallery(isChat: Bool, isTablet: Bool, isSticker: Bool, controlsHeight: CGFloat, sideInset: CGFloat) -> CGRect {
    if !isChat || isTablet || isSticker {
        return .zero
    }
    let size = CGSize(width: 48.0, height: 48.0)
    return CGRect(origin: CGPoint(x: sideInset, y: floor((controlsHeight - size.height) / 2.0)), size: size)
}

public func cameraScreenTransitionsAfterVideoRecording(mode: CameraScreenModeKind, isCollageEnabled: Bool) -> Bool {
    if case .chat = mode {
        return false
    }
    return !isCollageEnabled
}

public let cameraScreenDocumentFrameDimAlpha: CGFloat = 0.7

public func cameraScreenDocumentFrameDimRects(containerSize: CGSize) -> (top: CGRect, bottom: CGRect) {
    let bandHeight = containerSize.width * 704.0 / 1000.0
    let topEdge = (containerSize.height - bandHeight) / 2.0
    let bottomEdge = (containerSize.height + bandHeight) / 2.0
    return (
        top: CGRect(x: 0.0, y: 0.0, width: containerSize.width, height: max(0.0, topEdge)),
        bottom: CGRect(x: 0.0, y: bottomEdge, width: containerSize.width, height: max(0.0, containerSize.height - bottomEdge))
    )
}

public func chatCameraInitialFrontPosition(storedFront: Bool, prefersFront: Bool, fixesPosition: Bool) -> Bool {
    if fixesPosition {
        return prefersFront
    }
    return prefersFront || storedFront
}

public func chatCameraPersistsPosition(fixesPosition: Bool) -> Bool {
    return !fixesPosition
}

public func chatCameraUnmirrorsResult(isFront: Bool, mirrorsFrontResult: Bool) -> Bool {
    return isFront && !mirrorsFrontResult
}

public enum CameraScreenChatTrailingButton: Equatable {
    case flip
    case done
}

public func cameraScreenChatTrailingButton(mode: CameraScreenModeKind, isTablet: Bool, batchCount: Int) -> CameraScreenChatTrailingButton? {
    guard case .chat = mode, !isTablet else {
        return nil
    }
    return batchCount > 0 ? .done : .flip
}

public func cameraScreenShowsBottomCloseButton(mode: CameraScreenModeKind, isTablet: Bool) -> Bool {
    return cameraScreenChatTrailingButton(mode: mode, isTablet: isTablet, batchCount: 0) != nil
}

public func cameraScreenShowsTopCancelButton(mode: CameraScreenModeKind, isTablet: Bool) -> Bool {
    return !cameraScreenShowsBottomCloseButton(mode: mode, isTablet: isTablet)
}

public func cameraScreenShowsTopFlipButton(mode: CameraScreenModeKind, isTablet: Bool, batchCount: Int) -> Bool {
    return cameraScreenChatTrailingButton(mode: mode, isTablet: isTablet, batchCount: batchCount) == .done
}

public func cameraScreenPreviewCornerRadius(mode: CameraScreenModeKind) -> CGFloat {
    switch mode {
    case .chat:
        return 0.0
    case .story, .sticker, .avatar:
        return 30.0
    }
}

public func cameraScreenPlaceholderCornerRadius(mode: CameraScreenModeKind) -> CGFloat {
    switch mode {
    case .chat:
        return 0.0
    case .story, .sticker, .avatar:
        return 11.0
    }
}

public func cameraScreenDismissMovesOnlyViewfinder(mode: CameraScreenModeKind) -> Bool {
    if case .chat = mode {
        return true
    }
    return false
}

public let cameraScreenDismissInterfaceMaxBlurRadius: CGFloat = 10.0
private let cameraScreenModalDismissDistanceFraction: CGFloat = 0.3
private let cameraScreenModalDismissVelocity: CGFloat = 1000.0

public struct CameraScreenDismissInterfaceAppearance: Equatable {
    public var alpha: CGFloat
    public var blurRadius: CGFloat

    public init(alpha: CGFloat, blurRadius: CGFloat) {
        self.alpha = alpha
        self.blurRadius = blurRadius
    }

    public static let visible = CameraScreenDismissInterfaceAppearance(alpha: 1.0, blurRadius: 0.0)
    public static let hidden = CameraScreenDismissInterfaceAppearance(alpha: 0.0, blurRadius: cameraScreenDismissInterfaceMaxBlurRadius)
}

public let cameraScreenDismissInterfaceAnimationDuration: Double = 0.25

public func cameraScreenDismissInterfaceAppearance(isDismissing: Bool) -> CameraScreenDismissInterfaceAppearance {
    return isDismissing ? .hidden : .visible
}

public func cameraScreenTopFlashTrailingOffset(mode: CameraScreenModeKind, isTablet: Bool) -> CGFloat {
    return cameraScreenShowsBottomCloseButton(mode: mode, isTablet: isTablet) ? 0.0 : 50.0
}

public func cameraScreenModalDismissCompletes(translation: CGFloat, velocity: CGFloat, height: CGFloat) -> Bool {
    guard height > 0.0 else {
        return true
    }
    return abs(translation / height) > cameraScreenModalDismissDistanceFraction || abs(velocity) > cameraScreenModalDismissVelocity
}

public let cameraScreenModeControlUnderlayAlpha: CGFloat = 0.11
public let cameraScreenBottomButtonSize: CGFloat = 48.0

public let cameraScreenEditorHandoffBlurRadius: CGFloat = 8.0
public let cameraScreenGalleryThumbnailInset: CGFloat = 0.0
public let cameraScreenEditorHandoffAdoptTimeout: Double = 0.6
public let cameraScreenEditorReturnContentDelay: Double = 0.1

public func cameraScreenEditorHandoffAvailable(mode: CameraScreenModeKind, isTablet: Bool, isRecording: Bool, isCollageComplete: Bool, isTransitioning: Bool) -> Bool {
    switch mode {
    case .story, .chat:
        break
    case .sticker, .avatar:
        return false
    }
    return !isTablet && !isRecording && !isCollageComplete && !isTransitioning
}

public struct CameraScreenCounterTransform: Equatable {
    public var scale: CGFloat
    public var translation: CGPoint

    public init(scale: CGFloat, translation: CGPoint) {
        self.scale = scale
        self.translation = translation
    }

    public static let identity = CameraScreenCounterTransform(scale: 1.0, translation: .zero)
}

public struct CameraScreenContainerScale: Equatable {
    public var scale: CGFloat
    public var offset: CGPoint
    public var center: CGPoint

    public init(scale: CGFloat, offset: CGPoint, center: CGPoint) {
        self.scale = scale
        self.offset = offset
        self.center = center
    }

    public func counterTransform(at point: CGPoint) -> CameraScreenCounterTransform {
        guard self.scale > 0.0 else {
            return .identity
        }
        let k = 1.0 / self.scale
        return CameraScreenCounterTransform(
            scale: k,
            translation: CGPoint(
                x: (point.x - self.center.x) * (k - 1.0) - self.offset.x,
                y: (point.y - self.center.y) * (k - 1.0) - self.offset.y
            )
        )
    }
}
