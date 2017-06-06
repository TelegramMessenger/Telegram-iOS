import Foundation
import AsyncDisplayKit
import Display
import SwiftSignalKit
import Postbox
import TelegramCore

private let titleFont = Font.regular(13.0)
private let titleBoldFont = Font.bold(13.0)

func serviceMessageString(theme: PresentationTheme, strings: PresentationStrings, message: Message, accountPeerId: PeerId) -> NSAttributedString? {
    var attributedString: NSAttributedString?
    
    let theme = theme.chat.serviceMessage
    
    let bodyAttributes = MarkdownAttributeSet(font: titleFont, textColor: theme.serviceMessagePrimaryTextColor, additionalAttributes: [:])
    let linkAttributes = MarkdownAttributeSet(font: titleBoldFont, textColor: theme.serviceMessagePrimaryTextColor, additionalAttributes: [:])
    
    for media in message.media {
        if let action = media as? TelegramMediaAction {
            let authorName = message.author?.displayTitle ?? ""
            
            var isChannel = false
            if message.id.peerId.namespace == Namespaces.Peer.CloudChannel, let peer = message.peers[message.id.peerId] as? TelegramChannel, case .broadcast = peer.info {
                isChannel = true
            }
            
            switch action.action {
            case .groupCreated:
                if isChannel {
                    attributedString = NSAttributedString(string: strings.Notification_CreatedChannel, font: titleFont, textColor: theme.serviceMessagePrimaryTextColor)
                } else {
                    attributedString = NSAttributedString(string: strings.Notification_CreatedGroup, font: titleFont, textColor: theme.serviceMessagePrimaryTextColor)
                }
            case let .addedMembers(peerIds):
                if peerIds.first == message.author?.id {
                    attributedString = addAttributesToStringWithRanges(strings.Notification_JoinedChat(authorName), body: bodyAttributes, argumentAttributes: [0: linkAttributes])
                } else {
                    attributedString = addAttributesToStringWithRanges(strings.Notification_Invited(authorName, peerDisplayTitles(peerIds, message.peers)), body: bodyAttributes, argumentAttributes: [0: linkAttributes, 1: linkAttributes])
                }
            case let .removedMembers(peerIds):
                if peerIds.first == message.author?.id {
                    attributedString = addAttributesToStringWithRanges(strings.Notification_LeftChat(authorName), body: bodyAttributes, argumentAttributes: [0: linkAttributes])
                } else {
                    attributedString = addAttributesToStringWithRanges(strings.Notification_Kicked(authorName, peerDisplayTitles(peerIds, message.peers)), body: bodyAttributes, argumentAttributes: [0: linkAttributes, 1: linkAttributes])
                }
            case let .photoUpdated(image):
                if authorName.isEmpty || isChannel {
                    if isChannel {
                        if image != nil {
                            attributedString = NSAttributedString(string: strings.Channel_MessagePhotoUpdated, font: titleFont, textColor: theme.serviceMessagePrimaryTextColor)
                        } else {
                            attributedString = NSAttributedString(string: strings.Channel_MessagePhotoRemoved, font: titleFont, textColor: theme.serviceMessagePrimaryTextColor)
                        }
                    } else {
                        if image != nil {
                            attributedString = NSAttributedString(string: strings.Group_MessagePhotoUpdated, font: titleFont, textColor: theme.serviceMessagePrimaryTextColor)
                        } else {
                            attributedString = NSAttributedString(string: strings.Group_MessagePhotoRemoved, font: titleFont, textColor: theme.serviceMessagePrimaryTextColor)
                        }
                    }
                } else {
                    if image != nil {
                        attributedString = addAttributesToStringWithRanges(strings.Notification_ChangedGroupPhoto(authorName), body: bodyAttributes, argumentAttributes: [0: linkAttributes])
                    } else {
                        attributedString = addAttributesToStringWithRanges(strings.Notification_RemovedGroupPhoto(authorName), body: bodyAttributes, argumentAttributes: [0: linkAttributes])
                    }
                }
            case let .titleUpdated(title):
                if authorName.isEmpty || isChannel {
                    if isChannel {
                        attributedString = NSAttributedString(string: strings.Channel_MessageTitleUpdated(title).0, font: titleFont, textColor: theme.serviceMessagePrimaryTextColor)
                    } else {
                        attributedString = NSAttributedString(string: strings.Group_MessageTitleUpdated(title).0, font: titleFont, textColor: theme.serviceMessagePrimaryTextColor)
                    }
                } else {
                    attributedString = addAttributesToStringWithRanges(strings.Notification_ChangedGroupName(authorName, title), body: bodyAttributes, argumentAttributes: [0: linkAttributes])
                }
            case .pinnedMessageUpdated:
                enum PinnnedMediaType {
                    case text(String)
                    case photo
                    case video
                    case round
                    case audio
                    case file
                    case gif
                    case sticker
                    case location
                    case contact
                    case deleted
                }
                
                var pinnedMessage: Message?
                for attribute in message.attributes {
                    if let attribute = attribute as? ReplyMessageAttribute, let message = message.associatedMessages[attribute.messageId] {
                        pinnedMessage = message
                    }
                }
                
                var type: PinnnedMediaType
                if let pinnedMessage = pinnedMessage {
                    type = .text(pinnedMessage.text)
                    inner: for media in pinnedMessage.media {
                        if let _ = media as? TelegramMediaImage {
                            type = .photo
                        } else if let file = media as? TelegramMediaFile {
                            type = .file
                            if file.isAnimated {
                                type = .gif
                            } else {
                                for attribute in file.attributes {
                                    switch attribute {
                                    case let .Video(_, _, flags):
                                        if flags.contains(.instantRoundVideo) {
                                            type = .round
                                        } else {
                                            type = .video
                                        }
                                        break inner
                                    case let .Audio(isVoice, _, performer, title, _):
                                        if isVoice {
                                            type = .audio
                                        } else {
                                            let descriptionString: String
                                            if let title = title, let performer = performer, !title.isEmpty, !performer.isEmpty {
                                                descriptionString = title + " — " + performer
                                            } else if let title = title, !title.isEmpty {
                                                descriptionString = title
                                            } else if let performer = performer, !performer.isEmpty {
                                                descriptionString = performer
                                            } else if let fileName = file.fileName {
                                                descriptionString = fileName
                                            } else {
                                                descriptionString = strings.Message_Audio
                                            }
                                            type = .text(descriptionString)
                                        }
                                        break inner
                                    case .Sticker:
                                        type = .sticker
                                        break inner
                                    case .Animated:
                                        break
                                    default:
                                        break
                                    }
                                }
                            }
                        } else if let _ = media as? TelegramMediaMap {
                            type = .location
                        } else if let _ = media as? TelegramMediaContact {
                            type = .contact
                        }
                    }
                } else {
                    type = .deleted
                }
                
                switch type {
                case let .text(text):
                    attributedString = addAttributesToStringWithRanges(strings.Notification_PinnedTextMessage(authorName, text), body: bodyAttributes, argumentAttributes: [0: linkAttributes])
                case .photo:
                    attributedString = addAttributesToStringWithRanges(strings.Notification_PinnedPhotoMessage(authorName), body: bodyAttributes, argumentAttributes: [0: linkAttributes])
                case .video:
                    attributedString = addAttributesToStringWithRanges(strings.Notification_PinnedVideoMessage(authorName), body: bodyAttributes, argumentAttributes: [0: linkAttributes])
                case .round:
                    attributedString = addAttributesToStringWithRanges(strings.Notification_PinnedRoundMessage(authorName), body: bodyAttributes, argumentAttributes: [0: linkAttributes])
                case .audio:
                    attributedString = addAttributesToStringWithRanges(strings.Notification_PinnedAudioMessage(authorName), body: bodyAttributes, argumentAttributes: [0: linkAttributes])
                case .file:
                    attributedString = addAttributesToStringWithRanges(strings.Notification_PinnedDocumentMessage(authorName), body: bodyAttributes, argumentAttributes: [0: linkAttributes])
                case .gif:
                    attributedString = addAttributesToStringWithRanges(strings.Notification_PinnedAnimationMessage(authorName), body: bodyAttributes, argumentAttributes: [0: linkAttributes])
                case .sticker:
                    attributedString = addAttributesToStringWithRanges(strings.Notification_PinnedStickerMessage(authorName), body: bodyAttributes, argumentAttributes: [0: linkAttributes])
                case .location:
                    attributedString = addAttributesToStringWithRanges(strings.Notification_PinnedLocationMessage(authorName), body: bodyAttributes, argumentAttributes: [0: linkAttributes])
                case .contact:
                    attributedString = addAttributesToStringWithRanges(strings.Notification_PinnedContactMessage(authorName), body: bodyAttributes, argumentAttributes: [0: linkAttributes])
                case .deleted:
                    attributedString = addAttributesToStringWithRanges(strings.Notification_PinnedDeletedMessage(authorName), body: bodyAttributes, argumentAttributes: [0: linkAttributes])
                }
            case .joinedByLink:
                attributedString = addAttributesToStringWithRanges(strings.Notification_JoinedGroupByLink(authorName), body: bodyAttributes, argumentAttributes: [0: linkAttributes])
            case .channelMigratedFromGroup, .groupMigratedToChannel:
                attributedString = NSAttributedString(string: strings.Notification_ChannelMigratedFrom, font: titleFont, textColor: theme.serviceMessagePrimaryTextColor)
            case let .messageAutoremoveTimeoutUpdated(timeout):
                if timeout > 0 {
                    let timeValue = timeIntervalString(strings: strings, value: timeout)
                    
                    let string: String
                    if message.author?.id == accountPeerId {
                        string = strings.Notification_MessageLifetimeChangedOutgoing(timeValue).0
                    } else {
                        let authorString: String
                        if let author = messageMainPeer(message) {
                            authorString = author.compactDisplayTitle
                        } else {
                            authorString = ""
                        }
                        string = strings.Notification_MessageLifetimeChanged(authorString, timeValue).0
                    }
                    attributedString = NSAttributedString(string: string, font: titleFont, textColor: theme.serviceMessagePrimaryTextColor)
                } else {
                    let string: String
                    if message.author?.id == accountPeerId {
                        string = strings.Notification_MessageLifetimeRemovedOutgoing
                    } else {
                        let authorString: String
                        if let author = messageMainPeer(message) {
                            authorString = author.compactDisplayTitle
                        } else {
                            authorString = ""
                        }
                        string = strings.Notification_MessageLifetimeRemoved(authorString).0
                    }
                    attributedString = NSAttributedString(string: string, font: titleFont, textColor: theme.serviceMessagePrimaryTextColor)
                }
            case .historyCleared:
                break
            case .historyScreenshot:
                attributedString = NSAttributedString(string: strings.Notification_SecretChatScreenshot, font: titleFont, textColor: theme.serviceMessagePrimaryTextColor)
            case let .gameScore(gameId: _, score):
                var gameTitle: String?
                inner: for attribute in message.attributes {
                    if let attribute = attribute as? ReplyMessageAttribute, let message = message.associatedMessages[attribute.messageId] {
                        for media in message.media {
                            if let game = media as? TelegramMediaGame {
                                gameTitle = game.title
                                break inner
                            }
                        }
                    }
                }
                
                var baseString: String
                if message.author?.id == accountPeerId {
                    if let _ = gameTitle {
                        baseString = strings.ServiceMessage_GameScoreSelfExtended(score)
                    } else {
                        baseString = strings.ServiceMessage_GameScoreSelfSimple(score)
                    }
                } else {
                    if let _ = gameTitle {
                        baseString = strings.ServiceMessage_GameScoreExtended(score)
                    } else {
                        baseString = strings.ServiceMessage_GameScoreSimple(score)
                    }
                }
                let baseStringValue = baseString as NSString
                var ranges: [(Int, NSRange)] = []
                if baseStringValue.range(of: "{name}").location != NSNotFound {
                    ranges.append((0, baseStringValue.range(of: "{name}")))
                }
                if baseStringValue.range(of: "{game}").location != NSNotFound {
                    ranges.append((1, baseStringValue.range(of: "{game}")))
                }
                ranges.sort(by: { $0.1.location < $1.1.location })
                
                attributedString = addAttributesToStringWithRanges(formatWithArgumentRanges(baseString, ranges, [authorName, gameTitle ?? ""]), body: bodyAttributes, argumentAttributes: [0: linkAttributes, 1: linkAttributes])
            case .phoneCall:
                break
            default:
                attributedString = nil
            }
            
            break
        }
    }
    
    return attributedString
}

class ChatMessageActionItemNode: ChatMessageItemView {
    let labelNode: TextNode
    let backgroundNode: ASImageNode
    
    private let fetchDisposable = MetaDisposable()
    
    private var appliedItem: ChatMessageItem?
    
    required init() {
        self.labelNode = TextNode()
        self.labelNode.isLayerBacked = true
        self.labelNode.displaysAsynchronously = true
        
        self.backgroundNode = ASImageNode()
        self.backgroundNode.isLayerBacked = true
        self.backgroundNode.displayWithoutProcessing = true
        self.backgroundNode.displaysAsynchronously = false
        
        super.init(layerBacked: false)
        
        self.addSubnode(self.backgroundNode)
        self.addSubnode(self.labelNode)
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    deinit {
        self.fetchDisposable.dispose()
    }
    
    override func setupItem(_ item: ChatMessageItem) {
        super.setupItem(item)
    }
    
    override func asyncLayout() -> (_ item: ChatMessageItem, _ width: CGFloat, _ mergedTop: Bool, _ mergedBottom: Bool, _ dateHeaderAtBottom: Bool) -> (ListViewItemNodeLayout, (ListViewItemUpdateAnimation) -> Void) {
        let labelLayout = TextNode.asyncLayout(self.labelNode)
        let layoutConstants = self.layoutConstants
        
        let currentItem = self.appliedItem
        
        return { item, width, mergedTop, mergedBottom, dateHeaderAtBottom in
            var updatedBackgroundImage: UIImage?
            
            if item.theme !== currentItem?.theme {
                updatedBackgroundImage = PresentationResourcesChat.chatServiceBubbleFillImage(item.theme)
            }
            
            let attributedString = serviceMessageString(theme: item.theme, strings: item.strings, message: item.message, accountPeerId: item.account.peerId)
            
            let (size, apply) = labelLayout(attributedString, nil, 1, .end, CGSize(width: width - 32.0, height: CGFloat.greatestFiniteMagnitude), .natural, nil, UIEdgeInsets())
            
            let backgroundSize = CGSize(width: size.size.width + 8.0 + 8.0, height: 20.0)
            var layoutInsets = UIEdgeInsets(top: 4.0, left: 0.0, bottom: 4.0, right: 0.0)
            if dateHeaderAtBottom {
                layoutInsets.top += layoutConstants.timestampHeaderHeight
            }
            
            return (ListViewItemNodeLayout(contentSize: CGSize(width: width, height: 20.0), insets: layoutInsets), { [weak self] animation in
                if let strongSelf = self {
                    strongSelf.appliedItem = item
                    
                    if let updatedBackgroundImage = updatedBackgroundImage {
                        strongSelf.backgroundNode.image = updatedBackgroundImage
                    }
                    
                    let _ = apply()
                    
                    strongSelf.backgroundNode.frame = CGRect(origin: CGPoint(x: floorToScreenPixels((width - backgroundSize.width) / 2.0), y: 0.0), size: backgroundSize)
                    strongSelf.labelNode.frame = CGRect(origin: CGPoint(x: strongSelf.backgroundNode.frame.origin.x + 8.0, y: floorToScreenPixels((backgroundSize.height - size.size.height) / 2.0) - 1.0), size: size.size)
                }
            })
        }
    }
    
    override func animateInsertion(_ currentTimestamp: Double, duration: Double, short: Bool) {
        super.animateInsertion(currentTimestamp, duration: duration, short: short)
        
        self.backgroundNode.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.2)
        self.labelNode.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.2)
    }
    
    override func animateAdded(_ currentTimestamp: Double, duration: Double) {
        super.animateAdded(currentTimestamp, duration: duration)
        
        self.backgroundNode.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.2)
        self.labelNode.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.2)
    }
}
