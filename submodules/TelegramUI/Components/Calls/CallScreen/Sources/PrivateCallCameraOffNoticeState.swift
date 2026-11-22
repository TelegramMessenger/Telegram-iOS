import Foundation

/// When the call screen shows its camera-off notice, "Tap here to turn on your camera", which comes up (with the remote
/// camera tone) when the other party turns on their video while the local camera is off, its tail pointing at the
/// video button.
///
/// It stays until dismissed: by its close button, by tapping it or the video button (both turn on the camera), all
/// `dismiss()`, by the local video turning on, or by the remote video going away. Only the remote video starting again
/// brings it back. The call screen keeps its controls visible while it is up.
public struct PrivateCallCameraOffNoticeState: Equatable {
    public private(set) var isVisible: Bool = false
    private var hadRemoteVideo: Bool = false

    public init() {
    }

    public mutating func update(hasRemoteVideo: Bool, hasLocalVideo: Bool) {
        if hasRemoteVideo && !self.hadRemoteVideo && !hasLocalVideo {
            self.isVisible = true
        }
        if !hasRemoteVideo || hasLocalVideo {
            self.isVisible = false
        }
        self.hadRemoteVideo = hasRemoteVideo
    }

    public mutating func dismiss() {
        self.isVisible = false
    }
}
