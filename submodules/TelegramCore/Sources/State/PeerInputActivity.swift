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
    case speakingInGroupCall(timestamp: Int32)
    case choosingSticker
    
    public var key: Int32 {
        switch self {
            case .typingText:
                return 0
            case .speakingInGroupCall:
                return 1
            case .uploadingFile:
                return 2
            case .recordingVoice:
                return 3
            case .uploadingPhoto:
                return 4
            case .uploadingVideo:
                return 5
            case .recordingInstantVideo:
                return 6
            case .uploadingInstantVideo:
                return 7
            case .playingGame:
                return 8
            case .choosingSticker:
                return 9
        }
    }
    
    public static func <(lhs: PeerInputActivity, rhs: PeerInputActivity) -> Bool {
        return lhs.key < rhs.key
    }
}

extension PeerInputActivity {
    init?(apiType: Api.SendMessageAction, timestamp: Int32) {
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
            case .speakingInGroupCallAction:
                self = .speakingInGroupCall(timestamp: timestamp)
            case .sendMessageChooseStickerAction:
                self = .choosingSticker
            case .sendMessageHistoryImportAction:
                return nil
        }
    }
}
