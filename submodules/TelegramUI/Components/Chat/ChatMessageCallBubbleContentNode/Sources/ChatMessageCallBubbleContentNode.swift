import Foundation
import UIKit
import AsyncDisplayKit
import Display
import TelegramCore
import Postbox
import TelegramPresentationData
import AppBundle
import ChatMessageBubbleContentNode
import ChatMessageItemCommon
import ChatMessageDateAndStatusNode
import SwiftSignalKit
import AnimatedAvatarSetNode
import AvatarNode

private let titleFont: UIFont = Font.medium(16.0)
private let labelFont: UIFont = Font.regular(13.0)
private let avatarFont: UIFont = avatarPlaceholderFont(size: 8.0)

private let incomingGreenIcon = generateTintedImage(image: UIImage(bundleImageName: "Chat/Message/CallIncomingArrow"), color: UIColor(rgb: 0x36c033))
private let incomingRedIcon = generateTintedImage(image: UIImage(bundleImageName: "Chat/Message/CallIncomingArrow"), color: UIColor(rgb: 0xff4747))

private let outgoingGreenIcon = generateTintedImage(image: UIImage(bundleImageName: "Chat/Message/CallOutgoingArrow"), color: UIColor(rgb: 0x36c033))
private let outgoingRedIcon = generateTintedImage(image: UIImage(bundleImageName: "Chat/Message/CallOutgoingArrow"), color: UIColor(rgb: 0xff4747))

public class ChatMessageCallBubbleContentNode: ChatMessageBubbleContentNode {
    private let titleNode: TextNode
    private let labelNode: TextNode
    
    private var peopleAvatarsContext: AnimatedAvatarSetContext?
    private var peopleAvatarsNode: AnimatedAvatarSetNode?
    private var peopleTextNode: TextNode?

    private let iconNode: ASImageNode
    private let buttonNode: HighlightableButtonNode
    
    private var activeConferenceUpdateTimer: SwiftSignalKit.Timer?
    
    required public init() {
        self.titleNode = TextNode()
        self.labelNode = TextNode()
        
        self.iconNode = ASImageNode()
        self.iconNode.displayWithoutProcessing = true
        self.iconNode.displaysAsynchronously = false
        self.iconNode.isLayerBacked = true
        
        self.buttonNode = HighlightableButtonNode()
        self.buttonNode.isAccessibilityElement = false
        
        super.init()
                
        self.titleNode.isUserInteractionEnabled = false
        self.titleNode.contentMode = .topLeft
        self.titleNode.contentsScale = UIScreenScale
        self.titleNode.displaysAsynchronously = false
        self.addSubnode(self.titleNode)
        
        self.labelNode.isUserInteractionEnabled = false
        self.labelNode.contentMode = .topLeft
        self.labelNode.contentsScale = UIScreenScale
        self.labelNode.displaysAsynchronously = false
        self.addSubnode(self.labelNode)
        
        self.addSubnode(self.iconNode)
        
        self.addSubnode(self.buttonNode)
        self.buttonNode.addTarget(self, action: #selector(self.callButtonPressed), forControlEvents: .touchUpInside)
    }
    
    deinit {
        self.activeConferenceUpdateTimer?.invalidate()
    }
    
    override public func accessibilityActivate() -> Bool {
        self.callButtonPressed()
        return true
    }
    
    override public func didLoad() {
        super.didLoad()
        
        self.view.accessibilityElementsHidden = true
    }
    
    required public init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override public func asyncLayoutContent() -> (_ item: ChatMessageBubbleContentItem, _ layoutConstants: ChatMessageItemLayoutConstants, _ preparePosition: ChatMessageBubblePreparePosition, _ messageSelection: Bool?, _ constrainedSize: CGSize, _ avatarInset: CGFloat) -> (ChatMessageBubbleContentProperties, CGSize?, CGFloat, (CGSize, ChatMessageBubbleContentPosition) -> (CGFloat, (CGFloat) -> (CGSize, (ListViewItemUpdateAnimation, Bool, ListViewItemApply?) -> Void))) {
        let makeTitleLayout = TextNode.asyncLayout(self.titleNode)
        let makeLabelLayout = TextNode.asyncLayout(self.labelNode)
        let makePeopleTextLayout = TextNode.asyncLayout(self.peopleTextNode)
        
        return { item, layoutConstants, _, _, _, _ in
            let contentProperties = ChatMessageBubbleContentProperties(hidesSimpleAuthorHeader: false, headerSpacing: 0.0, hidesBackground: .never, forceFullCorners: false, forceAlignment: .none)
            return (contentProperties, nil, CGFloat.greatestFiniteMagnitude, { constrainedSize, position in
                let incoming = item.message.effectivelyIncoming(item.context.account.peerId)
                
                let horizontalInset = layoutConstants.text.bubbleInsets.left + layoutConstants.text.bubbleInsets.right
                let textConstrainedSize = CGSize(width: constrainedSize.width - horizontalInset, height: constrainedSize.height)

                let avatarsLeftInset: CGFloat = 5.0
                let avatarsRightInset: CGFloat = 5.0
                let peopleAvatarSize: CGFloat = 16.0
                let peopleAvatarSpacing: CGFloat = 10.0
                
                let messageTheme = incoming ? item.presentationData.theme.theme.chat.message.incoming : item.presentationData.theme.theme.chat.message.outgoing

                var peopleTextString: String?
                var peopleAvatars: [Peer] = []
                
                var titleString: String?
                var callDuration: Int32?
                var callSuccessful = true
                var isVideo = false
                var updateConferenceTimerEndTimeout: Int32?
                for media in item.message.media {
                    if let action = media as? TelegramMediaAction, case let .phoneCall(_, discardReason, duration, isVideoValue) = action.action {
                        isVideo = isVideoValue
                        callDuration = duration
                        if let discardReason = discardReason {
                            switch discardReason {
                                case .disconnect:
                                    callSuccessful = false
                                    if isVideo {
                                        titleString = item.presentationData.strings.Notification_VideoCallCanceled
                                    } else {
                                        titleString = item.presentationData.strings.Notification_CallCanceled
                                    }
                                case .missed, .busy:
                                    callSuccessful = false
                                    if incoming {
                                        if isVideo {
                                            titleString = item.presentationData.strings.Notification_VideoCallMissed
                                        } else {
                                            titleString = item.presentationData.strings.Notification_CallMissed
                                        }
                                    } else {
                                        if isVideo {
                                            titleString = item.presentationData.strings.Notification_VideoCallCanceled
                                        } else {
                                            titleString = item.presentationData.strings.Notification_CallCanceled
                                        }
                                    }
                                case .hangup:
                                    break
                            }
                        }
                        break
                    } else if let action = media as? TelegramMediaAction, case let .conferenceCall(conferenceCall) = action.action {
                        isVideo = conferenceCall.flags.contains(.isVideo)
                        callDuration = conferenceCall.duration

                        if conferenceCall.otherParticipants.count > 0 {
                            peopleTextString = item.presentationData.strings.Chat_CallMessage_GroupCallParticipantCount(Int32(conferenceCall.otherParticipants.count + 1))
                            if let peer = item.message.author {
                                peopleAvatars.append(peer)
                            }
                            for id in conferenceCall.otherParticipants {
                                if let peer = item.message.peers[id] {
                                    peopleAvatars.append(peer)
                                }
                            }
                        }

                        let missedTimeout: Int32
                        #if DEBUG && false
                        missedTimeout = 5
                        #else
                        missedTimeout = 30
                        #endif
                        
                        let currentTime = Int32(Date().timeIntervalSince1970)
                        if conferenceCall.flags.contains(.isMissed) {
                            titleString = item.presentationData.strings.Chat_CallMessage_DeclinedGroupCall
                        } else if conferenceCall.duration == nil && item.message.timestamp < currentTime - missedTimeout {
                            titleString = item.presentationData.strings.Chat_CallMessage_MissedGroupCall
                        } else {
                            if incoming {
                                titleString = item.presentationData.strings.Chat_CallMessage_IncomingGroupCall
                            } else {
                                titleString = item.presentationData.strings.Chat_CallMessage_OutgoingGroupCall
                            }
                            updateConferenceTimerEndTimeout = (item.message.timestamp + missedTimeout) - currentTime
                        }
                        break
                    }
                }
                
                if titleString == nil {
                    let baseString: String
                    if incoming {
                        if isVideo {
                            baseString = item.presentationData.strings.Notification_VideoCallIncoming
                        } else {
                            baseString = item.presentationData.strings.Notification_CallIncoming
                        }
                    } else {
                        if isVideo {
                            baseString = item.presentationData.strings.Notification_VideoCallOutgoing
                        } else {
                            baseString = item.presentationData.strings.Notification_CallOutgoing
                        }
                    }
                    
                    titleString = baseString
                }
                
                let attributedTitle = NSAttributedString(string: titleString ?? "", font: titleFont, textColor: messageTheme.primaryTextColor)
                
                var callIcon: UIImage?
                if callSuccessful {
                    if incoming {
                        callIcon = incomingGreenIcon
                    } else {
                        callIcon = outgoingGreenIcon
                    }
                } else {
                    if incoming {
                        callIcon = incomingRedIcon
                    } else {
                        callIcon = outgoingRedIcon
                    }
                }
                
                var buttonImage: UIImage?
                if incoming {
                    if isVideo {
                        buttonImage = PresentationResourcesChat.chatBubbleIncomingVideoCallButtonImage(item.presentationData.theme.theme)
                    } else {
                        buttonImage = PresentationResourcesChat.chatBubbleIncomingCallButtonImage(item.presentationData.theme.theme)
                    }
                } else {
                    if isVideo {
                        buttonImage = PresentationResourcesChat.chatBubbleOutgoingVideoCallButtonImage(item.presentationData.theme.theme)
                    } else {
                        buttonImage = PresentationResourcesChat.chatBubbleOutgoingCallButtonImage(item.presentationData.theme.theme)
                    }
                }
                
                let dateText = stringForMessageTimestampStatus(accountPeerId: item.context.account.peerId, message: item.message, dateTimeFormat: item.presentationData.dateTimeFormat, nameDisplayOrder: item.presentationData.nameDisplayOrder, strings: item.presentationData.strings, associatedData: item.associatedData)
                
                var statusText: String
                if let callDuration = callDuration, callDuration > 1 {
                    statusText = item.presentationData.strings.Notification_CallFormat(dateText, callDurationString(strings: item.presentationData.strings, value: callDuration)).string
                } else {
                    statusText = dateText
                }
                if peopleTextString != nil || !peopleAvatars.isEmpty {
                    statusText.append(",")
                }
                
                let attributedLabel = NSAttributedString(string: statusText, font: labelFont, textColor: messageTheme.fileDurationColor)

                let (titleLayout, titleApply) = makeTitleLayout(TextNodeLayoutArguments(attributedString: attributedTitle, backgroundColor: nil, maximumNumberOfLines: 0, truncationType: .end, constrainedSize: textConstrainedSize, alignment: .natural, cutout: nil, insets: UIEdgeInsets()))
                let (labelLayout, labelApply) = makeLabelLayout(TextNodeLayoutArguments(attributedString: attributedLabel, backgroundColor: nil, maximumNumberOfLines: 0, truncationType: .end, constrainedSize: textConstrainedSize, alignment: .natural, cutout: nil, insets: UIEdgeInsets()))

                var peopleTextLayoutAndApply: (TextNodeLayout, () -> TextNode)?
                if let peopleTextString  {
                    peopleTextLayoutAndApply = makePeopleTextLayout(TextNodeLayoutArguments(attributedString: NSAttributedString(string: peopleTextString, font: labelFont, textColor: messageTheme.fileDurationColor), backgroundColor: nil, maximumNumberOfLines: 0, truncationType: .end, constrainedSize: textConstrainedSize, alignment: .natural, cutout: nil, insets: UIEdgeInsets()))
                }
                
                let titleSize = titleLayout.size
                let labelSize = labelLayout.size
                
                var titleFrame = CGRect(origin: CGPoint(), size: titleSize)
                var labelFrame = CGRect(origin: CGPoint(x: 14.0, y: 0.0), size: labelSize)
                
                titleFrame = titleFrame.offsetBy(dx: layoutConstants.text.bubbleInsets.left, dy: layoutConstants.text.bubbleInsets.top + 4.0)
                labelFrame = labelFrame.offsetBy(dx: layoutConstants.text.bubbleInsets.left, dy: layoutConstants.text.bubbleInsets.top + titleSize.height + 4.0)
                
                var boundingSize: CGSize

                var labelsWidth: CGFloat = labelFrame.size.width
                var avatarsWidth: CGFloat = 0.0
                if !peopleAvatars.isEmpty {
                    avatarsWidth += avatarsLeftInset
                    avatarsWidth += 1.0 * peopleAvatarSize + CGFloat(min(3, peopleAvatars.count) - 1) * peopleAvatarSpacing
                    avatarsWidth += avatarsRightInset
                    labelsWidth += avatarsWidth
                }
                if let peopleTextLayoutAndApply {
                    labelsWidth += peopleTextLayoutAndApply.0.size.width
                }

                boundingSize = CGSize(width: max(titleFrame.size.width, labelsWidth + 14.0), height: 47.0)
                
                boundingSize.width += layoutConstants.text.bubbleInsets.left + layoutConstants.text.bubbleInsets.right
                boundingSize.height += layoutConstants.text.bubbleInsets.top + layoutConstants.text.bubbleInsets.bottom
                
                boundingSize.width += 54.0
                
                return (boundingSize.width, { boundingWidth in
                    return (boundingSize, { [weak self] animation, _, _ in
                        if let strongSelf = self {
                            strongSelf.item = item
                            
                            let _ = titleApply()
                            let _ = labelApply()
                            
                            strongSelf.titleNode.frame = titleFrame
                            strongSelf.labelNode.frame = labelFrame

                            if !peopleAvatars.isEmpty {
                                let peopleAvatarsContext: AnimatedAvatarSetContext
                                if let current = strongSelf.peopleAvatarsContext {
                                    peopleAvatarsContext = current
                                } else {
                                    peopleAvatarsContext = AnimatedAvatarSetContext()
                                    strongSelf.peopleAvatarsContext = peopleAvatarsContext
                                }
                                let peopleAvatarsNode: AnimatedAvatarSetNode
                                if let current = strongSelf.peopleAvatarsNode {
                                    peopleAvatarsNode = current
                                } else {
                                    peopleAvatarsNode = AnimatedAvatarSetNode()
                                    strongSelf.peopleAvatarsNode = peopleAvatarsNode
                                    strongSelf.addSubnode(peopleAvatarsNode)
                                }

                                let peopleAvatarsContent = peopleAvatarsContext.update(peers: peopleAvatars.prefix(3).map(EnginePeer.init), animated: false)
                                let peopleAvatarsSize = peopleAvatarsNode.update(context: item.context, content: peopleAvatarsContent, itemSize: CGSize(width: peopleAvatarSize, height: peopleAvatarSize), customSpacing: peopleAvatarSize - peopleAvatarSpacing, font: avatarFont, animated: false, synchronousLoad: false)
                                peopleAvatarsNode.frame = CGRect(origin: CGPoint(x: labelFrame.maxX + avatarsLeftInset, y: labelFrame.minY - 1.0), size: peopleAvatarsSize)
                            } else {
                                strongSelf.peopleAvatarsContext = nil
                                if let peopleAvatarsNode = strongSelf.peopleAvatarsNode {
                                    strongSelf.peopleAvatarsNode = nil
                                    peopleAvatarsNode.removeFromSupernode()
                                }
                            }

                            if let peopleTextLayoutAndApply {
                                let peopleTextNode = peopleTextLayoutAndApply.1()
                                if strongSelf.peopleTextNode !== peopleTextNode {
                                    strongSelf.peopleTextNode?.removeFromSupernode()
                                    strongSelf.peopleTextNode = peopleTextNode
                                    strongSelf.addSubnode(peopleTextNode)
                                }
                                peopleTextNode.frame = CGRect(origin: CGPoint(x: labelFrame.maxX + avatarsWidth, y: labelFrame.minY), size: peopleTextLayoutAndApply.0.size)
                            }
                            
                            if let callIcon = callIcon {
                                if strongSelf.iconNode.image != callIcon {
                                    strongSelf.iconNode.image = callIcon
                                }
                                strongSelf.iconNode.frame = CGRect(origin: CGPoint(x: titleFrame.minX + 1.0, y: labelFrame.minY + 4.0), size: callIcon.size)
                            }
                            
                            if let buttonImage = buttonImage {
                                strongSelf.buttonNode.setImage(buttonImage, for: [])
                                strongSelf.buttonNode.frame = CGRect(origin: CGPoint(x: boundingWidth - buttonImage.size.width - 8.0, y: 15.0), size: buttonImage.size)
                            }
                            
                            if let activeConferenceUpdateTimer = strongSelf.activeConferenceUpdateTimer {
                                activeConferenceUpdateTimer.invalidate()
                                strongSelf.activeConferenceUpdateTimer = nil
                            }
                            if let updateConferenceTimerEndTimeout, updateConferenceTimerEndTimeout >= 0 {
                                strongSelf.activeConferenceUpdateTimer?.invalidate()
                                strongSelf.activeConferenceUpdateTimer = SwiftSignalKit.Timer(timeout: Double(updateConferenceTimerEndTimeout) + 0.5, repeat: false, completion: { [weak strongSelf] in
                                    guard let strongSelf else {
                                        return
                                    }
                                    strongSelf.requestInlineUpdate?()
                                }, queue: .mainQueue())
                                strongSelf.activeConferenceUpdateTimer?.start()
                            }
                        }
                    })
                })
            })
        }
    }
    
    override public func animateInsertion(_ currentTimestamp: Double, duration: Double) {
        self.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.2)
    }
    
    override public func animateAdded(_ currentTimestamp: Double, duration: Double) {
        self.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.2)
    }
    
    override public func animateRemoved(_ currentTimestamp: Double, duration: Double) {
        self.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.2, removeOnCompletion: false)
    }
    
    @objc private func callButtonPressed() {
        if let item = self.item {
            var isVideo = false
            for media in item.message.media {
                if let action = media as? TelegramMediaAction, case let .phoneCall(_, _, _, isVideoValue) = action.action {
                    isVideo = isVideoValue
                } else if let action = media as? TelegramMediaAction, case .conferenceCall = action.action {
                    item.controllerInteraction.openConferenceCall(item.message)
                    return
                }
            }
            item.controllerInteraction.callPeer(item.message.id.peerId, isVideo)
        }
    }
    
    override public func tapActionAtPoint(_ point: CGPoint, gesture: TapLongTapOrDoubleTapGesture, isEstimating: Bool) -> ChatMessageBubbleContentTapAction {
        if self.buttonNode.frame.contains(point) {
            return ChatMessageBubbleContentTapAction(content: .ignore)
        } else if self.bounds.contains(point), let item = self.item {
            var isVideo = false
            for media in item.message.media {
                if let action = media as? TelegramMediaAction, case let .phoneCall(_, _, _, isVideoValue) = action.action {
                    isVideo = isVideoValue
                } else if let action = media as? TelegramMediaAction, case .conferenceCall = action.action {
                    return ChatMessageBubbleContentTapAction(content: .conferenceCall(message: item.message))
                }
            }
            return ChatMessageBubbleContentTapAction(content: .call(peerId: item.message.id.peerId, isVideo: isVideo))
        } else {
            return ChatMessageBubbleContentTapAction(content: .none)
        }
    }
}
