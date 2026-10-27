import Foundation
import AccountContext

public enum ChatCameraEntry: CaseIterable {
    case attachMenu
    case inlineCell
    case placeholder
    case storyReply
    case shortcut

    public var chatMediaV2Entry: ChatMediaV2Entry {
        switch self {
        case .attachMenu:
            return .attachMenuCamera
        case .inlineCell:
            return .inlineCameraCell
        case .placeholder:
            return .placeholderCamera
        case .storyReply:
            return .storyReplyCamera
        case .shortcut:
            return .shortcutCamera
        }
    }
}

public struct ChatCameraModes: Equatable {
    public let allowPhoto: Bool
    public let allowVideo: Bool
    public let hasAudio: Bool

    public init(allowPhoto: Bool, allowVideo: Bool, hasAudio: Bool) {
        self.allowPhoto = allowPhoto
        self.allowVideo = allowVideo
        self.hasAudio = hasAudio
    }
}

public func chatCameraModes(isPhotoBanned: Bool, isVideoBanned: Bool, hasActiveCall: Bool) -> ChatCameraModes? {
    let allowPhoto = !isPhotoBanned
    let allowVideo = !isVideoBanned && !hasActiveCall
    guard allowPhoto || allowVideo else {
        return nil
    }
    return ChatCameraModes(allowPhoto: allowPhoto, allowVideo: allowVideo, hasAudio: !hasActiveCall)
}

public struct ChatCameraSessionOptions: Equatable {
    public let isSingleShot: Bool
    public let mediaGrouping: Bool

    public init(isSingleShot: Bool, mediaGrouping: Bool) {
        self.isSingleShot = isSingleShot
        self.mediaGrouping = mediaGrouping
    }
}

public func chatCameraReviewHasCameraButton(isEditingMessage: Bool, isSingleShot: Bool) -> Bool {
    return !isEditingMessage && !isSingleShot
}

public func chatCameraSessionOptions(entry: ChatCameraEntry, isEditingMessage: Bool) -> ChatCameraSessionOptions {
    let isEditing: Bool
    switch entry {
    case .attachMenu, .inlineCell, .placeholder:
        isEditing = isEditingMessage
    case .storyReply, .shortcut:
        isEditing = false
    }
    return ChatCameraSessionOptions(
        isSingleShot: isEditing,
        mediaGrouping: !isEditing
    )
}

public func chatCameraHasSchedule(isScheduledMessages: Bool, isSecretChat: Bool, hasPaidMessageStars: Bool, isEditingMessage: Bool) -> Bool {
    return !isScheduledMessages && !isSecretChat && !hasPaidMessageStars && !isEditingMessage
}
