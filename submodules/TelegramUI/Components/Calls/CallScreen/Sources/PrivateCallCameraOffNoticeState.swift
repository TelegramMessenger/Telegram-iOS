import Foundation

/// When the call screen shows the "Your camera is off" notice, the prompt to turn on video that comes up (with the
/// remote camera tone) when the other party turns on their video.
///
/// It stays until dismissed: by its close button or the camera button (`dismiss()`), by the local video turning on,
/// or by the remote video going away. Only the remote video starting again brings it back. The call screen keeps its
/// controls visible while it is up.
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
