import Foundation
import UIKit
import AsyncDisplayKit
import TelegramCore
import Display
import SwiftSignalKit
import TelegramPresentationData
import ChatTitleActivityNode
import LocalizedPeerData

final class ChatListInputActivitiesNode: ASDisplayNode {
    private let activityNode: ChatTitleActivityNode
    
    override init() {
        self.activityNode = ChatTitleActivityNode()
        
        super.init()
        
        self.addSubnode(self.activityNode)
    }
    
    func asyncLayout() -> (CGSize, ChatListPresentationData, UIColor, EnginePeer.Id?, [(EnginePeer, PeerInputActivity)]) -> (CGSize, () -> Void) {
        return { [weak self] boundingSize, presentationData, color, peerId, activities in
            let strings = presentationData.strings
            
            let textFont = Font.regular(floor(presentationData.fontSize.itemListBaseFontSize * 15.0 / 17.0))
            
            var state = ChatTitleActivityNodeState.none
            
            if !activities.isEmpty {
                var commonKey: Int32? = activities[0].1.key
                for i in 1 ..< activities.count {
                    if activities[i].1.key != commonKey {
                        commonKey = nil
                        break
                    }
                }
                
                let lightColor = color.withAlphaComponent(0.85)
                
                if activities.count == 1 {
                    if activities[0].0.id == peerId {
                        let text: String
                        switch activities[0].1 {
                            case .uploadingVideo:
                                text = strings.Activity_UploadingVideo
                            case .uploadingInstantVideo:
                                text = strings.Activity_UploadingVideoMessage
                            case .uploadingPhoto:
                                text = strings.Activity_UploadingPhoto
                            case .uploadingFile:
                                text = strings.Activity_UploadingDocument
                            case .recordingVoice:
                                text = strings.Activity_RecordingAudio
                            case .recordingInstantVideo:
                                text = strings.Activity_RecordingVideoMessage
                            case .playingGame:
                                text = strings.Activity_PlayingGame
                            case .typingText:
                                text = strings.DialogList_Typing
                            case .choosingSticker:
                                text = strings.Activity_ChoosingSticker
                            case let .interactingWithEmoji(emoticon, _, _):
                                text = strings.Activity_TappingInteractiveEmoji(emoticon).string
                            case .speakingInGroupCall, .seeingEmojiInteraction:
                                text = ""
                        }
                        let string = NSAttributedString(string: text, font: textFont, textColor: color)
                        
                        switch activities[0].1 {
                            case .typingText:
                                state = .typingText(string, lightColor)
                            case .recordingVoice:
                                state = .recordingVoice(string, lightColor)
                            case .recordingInstantVideo:
                                state = .recordingVideo(string, lightColor)
                            case .uploadingFile, .uploadingInstantVideo, .uploadingPhoto, .uploadingVideo:
                                state = .uploading(string, lightColor)
                            case .playingGame:
                                state = .playingGame(string, lightColor)
                            case .speakingInGroupCall:
                                state = .typingText(string, lightColor)
                            case .choosingSticker:
                                state = .choosingSticker(string, lightColor)
                            case .interactingWithEmoji:
                                state = .interactingWithEmoji(string, lightColor)
                            case .seeingEmojiInteraction:
                                state = .none
                        }
                    } else {
                        let text: String
                        if let _ = commonKey {
                            let peerTitle = activities[0].0.compactDisplayTitle
                            switch activities[0].1 {
                                case .uploadingVideo:
                                    text = strings.DialogList_SingleUploadingVideoSuffix(peerTitle).string
                                case .uploadingInstantVideo:
                                    text = strings.DialogList_SingleUploadingVideoSuffix(peerTitle).string
                                case .uploadingPhoto:
                                    text = strings.DialogList_SingleUploadingPhotoSuffix(peerTitle).string
                                case .uploadingFile:
                                    text = strings.DialogList_SingleUploadingFileSuffix(peerTitle).string
                                case .recordingVoice:
                                    text = strings.DialogList_SingleRecordingAudioSuffix(peerTitle).string
                                case .recordingInstantVideo:
                                    text = strings.DialogList_SingleRecordingVideoMessageSuffix(peerTitle).string
                                case .playingGame:
                                    text = strings.DialogList_SinglePlayingGameSuffix(peerTitle).string
                                case .typingText:
                                    text = strings.DialogList_SingleTypingSuffix(peerTitle).string
                                case .choosingSticker:
                                    text = strings.DialogList_SingleChoosingStickerSuffix(peerTitle).string
                                case .speakingInGroupCall, .seeingEmojiInteraction, .interactingWithEmoji:
                                    text = ""
                            }
                        } else {
                            text = activities[0].0.compactDisplayTitle
                        }
                        let string = NSAttributedString(string: text, font: textFont, textColor: color)
                        
                        switch activities[0].1 {
                            case .typingText:
                                state = .typingText(string, lightColor)
                            case .recordingVoice:
                                state = .recordingVoice(string, lightColor)
                            case .recordingInstantVideo:
                                state = .recordingVideo(string, lightColor)
                            case .uploadingFile, .uploadingInstantVideo, .uploadingPhoto, .uploadingVideo:
                                state = .uploading(string, lightColor)
                            case .playingGame:
                                state = .playingGame(string, lightColor)
                            case .speakingInGroupCall:
                                state = .typingText(string, lightColor)
                            case .choosingSticker:
                                state = .choosingSticker(string, lightColor)
                            case .seeingEmojiInteraction, .interactingWithEmoji:
                                state = .none
                        }
                    }
                } else {
                    let string: NSAttributedString
                    if activities.count > 1 {
                        let peerTitle = activities[0].0.compactDisplayTitle
                        if activities.count == 2 {
                            let secondPeerTitle = activities[1].0.compactDisplayTitle
                            string = NSAttributedString(string: strings.DialogList_MultipleTypingPair(peerTitle, secondPeerTitle).string, font: textFont, textColor: color)
                        } else {
                            string = NSAttributedString(string: strings.DialogList_MultipleTyping(peerTitle, strings.DialogList_MultipleTypingSuffix(activities.count - 1).string).string, font: textFont, textColor: color)
                        }
                    } else {
                        string = NSAttributedString(string: strings.DialogList_MultipleTypingSuffix(activities.count).string, font: textFont, textColor: color)
                    }
                    state = .typingText(string, lightColor)
                }
            }
            
            return (boundingSize, {
                if let strongSelf = self {
                    let _ = strongSelf.activityNode.transitionToState(state, animation: .none)
                    let size = strongSelf.activityNode.updateLayout(CGSize(width: boundingSize.width - 12.0, height: boundingSize.height), alignment: .left)
                    strongSelf.activityNode.frame = CGRect(origin: CGPoint(x: -3.0, y: 1.0), size: size)
                }
            })
        }
    }
}
