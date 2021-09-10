import Foundation
import TelegramApi

public struct EmojiInteraction: Equatable {
    public let animation: Int
    
    public init(animation: Int) {
        self.animation = animation
    }
    
    public init?(apiDataJson: Api.DataJSON) {
        if case let .dataJSON(string) = apiDataJson, let data = string.data(using: .utf8) {
            do {
                let decodedData = try JSONSerialization.jsonObject(with: data, options: [])
                guard let item = decodedData as? [String: Any] else {
                    return nil
                }
                guard let animation = item["animation"] as? Int else {
                    return nil
                }
                self.animation = animation
            } catch {
                return nil
            }
        } else {
            return nil
        }
    }
    
    public var apiDataJson: Api.DataJSON {
        let dict = ["animation": animation]
        if let data = try? JSONSerialization.data(withJSONObject: dict, options: []), let dataString = String(data: data, encoding: .utf8) {
            return .dataJSON(data: dataString)
        } else {
            return .dataJSON(data: "")
        }
    }
}

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
    case interactingWithEmoji(emoticon: String, interaction: EmojiInteraction?)
    case seeingEmojiInteraction(emoticon: String)
    
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
            case .interactingWithEmoji:
                return 10
            case .seeingEmojiInteraction:
                return 11
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
            case let .sendMessageEmojiInteraction(emoticon, interaction):
                self = .interactingWithEmoji(emoticon: emoticon, interaction: EmojiInteraction(apiDataJson: interaction))
            case let .sendMessageEmojiInteractionSeen(emoticon):
                self = .seeingEmojiInteraction(emoticon: emoticon)
        }
    }
}
