import Foundation
import CoreGraphics
import UIKit

public enum SuggestedAvatarSubject: Equatable {
    case photo
    case video
}

public func suggestedAvatarSubject(hasVideoRepresentation: Bool) -> SuggestedAvatarSubject {
    return hasVideoRepresentation ? .video : .photo
}

public func suggestedAvatarVideoCover(coverImage: UIImage?, thumbnail: UIImage?) -> UIImage? {
    return coverImage ?? thumbnail
}

public func videoChatAvatarCanDelete(hasPhotos: Bool, fromGallery: Bool) -> Bool {
    return hasPhotos && !fromGallery
}

public func videoChatAvatarUploadProgress(_ status: PeerInfoAvatarUploadStatus) -> CGFloat? {
    switch status {
    case let .progress(value):
        return CGFloat(value)
    case .done:
        return nil
    }
}

public enum AvatarVideoUploadPhase: Equatable {
    case export(Float)
    case upload(Float)
}

public func avatarVideoSplitProgress(_ phase: AvatarVideoUploadPhase) -> Float {
    switch phase {
    case let .export(value):
        return value * 0.25
    case let .upload(value):
        return 0.25 + value * 0.75
    }
}

public struct SetPhotoOptions {
    public let forceDark: Bool
    public let allowsEmojiAvatar: Bool
    public let splitsVideoExportProgress: Bool

    public init(forceDark: Bool, allowsEmojiAvatar: Bool, splitsVideoExportProgress: Bool = false) {
        self.forceDark = forceDark
        self.allowsEmojiAvatar = allowsEmojiAvatar
        self.splitsVideoExportProgress = splitsVideoExportProgress
    }
}
