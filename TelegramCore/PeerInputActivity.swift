import Foundation

public enum PeerInputActivity: Comparable {
    case typingText
    case uploadingFile(progress: Int32)
    case recordingVoice
    case playingGame
    
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
            case .playingGame:
                return 3
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
                self = .uploadingFile(progress: progress)
            case let .sendMessageUploadVideoAction(progress):
                self = .uploadingFile(progress: progress)
        }
    }
}
