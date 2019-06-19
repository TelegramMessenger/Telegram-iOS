import Foundation
import TelegramApi

public enum PeerInputActivity: Comparable {
    case typingText
    case uploadingFile(progress: Int32)
    case recordingVoice
    case uploadingPhoto(progress: Int32)
    case uploadingVideo(progress: Int32)
    case playingGame
    case recordingInstantVideo
    case uploadingInstantVideo(progress: Int32)
    
    public static func ==(lhs: PeerInputActivity, rhs: PeerInputActivity) -> Bool {
        switch lhs {
            case .typingText:
                if case .typingText = rhs {
                    return true
                } else {
                    return false
                }
            case let .uploadingFile(progress):
                if case .uploadingFile(progress) = rhs {
                    return true
                } else {
                    return false
                }
            case .recordingVoice:
                if case .recordingVoice = rhs {
                    return true
                } else {
                    return false
                }
            case .playingGame:
                if case .playingGame = rhs {
                    return true
                } else {
                    return false
                }
            case .uploadingPhoto(let progress):
                if case .uploadingPhoto(progress) = rhs {
                    return true
                } else {
                    return false
                }
            case .uploadingVideo(let progress):
                if case .uploadingVideo(progress) = rhs {
                    return true
                } else {
                    return false
                }
            case .recordingInstantVideo:
                if case .recordingInstantVideo = rhs {
                    return true
                } else {
                    return false
                }
            case .uploadingInstantVideo(let progress):
                if case .uploadingInstantVideo(progress) = rhs {
                    return true
                } else {
                    return false
                }
        }
    }
    
    public var key: Int32 {
        switch self {
            case .typingText:
                return 0
            case .uploadingFile:
                return 1
            case .recordingVoice:
                return 2
            case .uploadingPhoto:
                return 3
            case .uploadingVideo:
                return 4
            case .recordingInstantVideo:
                return 5
            case .uploadingInstantVideo:
                return 6
            case .playingGame:
                return 7
        }
    }
    
    public static func <(lhs: PeerInputActivity, rhs: PeerInputActivity) -> Bool {
        return lhs.key < rhs.key
    }
}

extension PeerInputActivity {
    init?(apiType: Api.SendMessageAction) {
        switch apiType {
            case .sendMessageCancelAction, .sendMessageChooseContactAction, .sendMessageGeoLocationAction, .sendMessageRecordVideoAction:
                return nil
            case .sendMessageGamePlayAction:
                self = .playingGame
            case .sendMessageRecordAudioAction, .sendMessageUploadAudioAction:
                self = .recordingVoice
            case .sendMessageTypingAction:
                self = .typingText
            case let .sendMessageUploadDocumentAction(progress):
                self = .uploadingFile(progress: progress)
            case let .sendMessageUploadPhotoAction(progress):
                self = .uploadingPhoto(progress: progress)
            case let .sendMessageUploadVideoAction(progress):
                self = .uploadingVideo(progress: progress)
            case .sendMessageRecordRoundAction:
                self = .recordingInstantVideo
            case let .sendMessageUploadRoundAction(progress):
                self = .uploadingInstantVideo(progress: progress)
        }
    }
}
