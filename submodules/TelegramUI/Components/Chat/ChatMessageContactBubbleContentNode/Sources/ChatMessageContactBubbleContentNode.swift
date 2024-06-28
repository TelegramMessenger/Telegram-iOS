import Foundation
import UIKit
import AsyncDisplayKit
import Display
import SwiftSignalKit
import Postbox
import TelegramCore
import TelegramPresentationData
import AvatarNode
import AccountContext
import PhoneNumberFormat
import ChatMessageDateAndStatusNode
import ChatMessageBubbleContentNode
import ChatMessageItemCommon
import ChatMessageAttachedContentButtonNode
import ChatControllerInteraction
import MessageInlineBlockBackgroundView

private let avatarFont = avatarPlaceholderFont(size: 16.0)

private let titleFont = Font.semibold(14.0)
private let textFont = Font.regular(14.0)

public class ChatMessageContactBubbleContentNode: ChatMessageBubbleContentNode {
    private var backgroundView: MessageInlineBlockBackgroundView?
    private var actionButtonSeparator: SimpleLayer?
    
    private let avatarNode: AvatarNode
    private let dateAndStatusNode: ChatMessageDateAndStatusNode
    private let titleNode: TextNode
    private let textNode: TextNode
    
    private var contact: TelegramMediaContact?
    private var contactInfo : String?
    
    private let addButtonNode: ChatMessageAttachedContentButtonNode
    private let messageButtonNode: ChatMessageAttachedContentButtonNode
    
    required public init() {
        self.avatarNode = AvatarNode(font: avatarFont)
        self.dateAndStatusNode = ChatMessageDateAndStatusNode()
        self.titleNode = TextNode()
        self.textNode = TextNode()
        self.addButtonNode = ChatMessageAttachedContentButtonNode()
        self.messageButtonNode = ChatMessageAttachedContentButtonNode()
        
        super.init()
        
        self.addSubnode(self.avatarNode)
        self.addSubnode(self.titleNode)
        self.addSubnode(self.textNode)
        self.addSubnode(self.addButtonNode)
        self.addSubnode(self.messageButtonNode)
        
        self.addButtonNode.addTarget(self, action: #selector(self.addButtonPressed), forControlEvents: .touchUpInside)
        self.messageButtonNode.addTarget(self, action: #selector(self.messageButtonPressed), forControlEvents: .touchUpInside)
        
        self.dateAndStatusNode.reactionSelected = { [weak self] _, value, sourceView in
            guard let strongSelf = self, let item = strongSelf.item else {
                return
            }
            item.controllerInteraction.updateMessageReaction(item.topMessage, .reaction(value), false, sourceView)
        }
        
        self.dateAndStatusNode.openReactionPreview = { [weak self] gesture, sourceView, value in
            guard let strongSelf = self, let item = strongSelf.item else {
                gesture?.cancel()
                return
            }
            
            item.controllerInteraction.openMessageReactionContextMenu(item.topMessage, sourceView, gesture, value)
        }
    }
    
    override public func accessibilityActivate() -> Bool {
        self.addButtonPressed()
        return true
    }
    
    required public init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override public func didLoad() {
        super.didLoad()
        
        let tapRecognizer = UITapGestureRecognizer(target: self, action: #selector(self.contactTap(_:)))
        self.view.addGestureRecognizer(tapRecognizer)
    }
    
    override public func asyncLayoutContent() -> (_ item: ChatMessageBubbleContentItem, _ layoutConstants: ChatMessageItemLayoutConstants, _ preparePosition: ChatMessageBubblePreparePosition, _ messageSelection: Bool?, _ constrainedSize: CGSize, _ avatarInset: CGFloat) -> (ChatMessageBubbleContentProperties, CGSize?, CGFloat, (CGSize, ChatMessageBubbleContentPosition) -> (CGFloat, (CGFloat) -> (CGSize, (ListViewItemUpdateAnimation, Bool, ListViewItemApply?) -> Void))) {
        let statusLayout = self.dateAndStatusNode.asyncLayout()
        let makeTitleLayout = TextNode.asyncLayout(self.titleNode)
        let makeTextLayout = TextNode.asyncLayout(self.textNode)
        let makeMessageButtonLayout = ChatMessageAttachedContentButtonNode.asyncLayout(self.messageButtonNode)
        let makeAddButtonLayout = ChatMessageAttachedContentButtonNode.asyncLayout(self.addButtonNode)
        
        let previousContact = self.contact
        let previousContactInfo = self.contactInfo
        
        return { item, layoutConstants, _, _, constrainedSize, _ in
            var selectedContact: TelegramMediaContact?
            for media in item.message.media {
                if let media = media as? TelegramMediaContact {
                    selectedContact = media;
                }
            }
            
            var incoming = item.message.effectivelyIncoming(item.context.account.peerId)
            if let subject = item.associatedData.subject, case let .messageOptions(_, _, info) = subject, case .forward = info {
                incoming = false
            }
            
            
            var contactPeer: Peer?
            if let peerId = selectedContact?.peerId, let peer = item.message.peers[peerId] {
                contactPeer = peer
            }
            
            let nameColors = contactPeer?.nameColor.flatMap { item.context.peerNameColors.get($0, dark: item.presentationData.theme.theme.overallDarkAppearance) }
            
            let messageTheme = incoming ? item.presentationData.theme.theme.chat.message.incoming : item.presentationData.theme.theme.chat.message.outgoing
            let mainColor: UIColor
            var secondaryColor: UIColor?
            var tertiaryColor: UIColor?
            if !incoming {
                mainColor = messageTheme.accentTextColor
                if let _ = nameColors?.secondary {
                    secondaryColor = .clear
                }
                if let _ = nameColors?.tertiary {
                    tertiaryColor = .clear
                }
            } else {
                var authorNameColor: UIColor?
                authorNameColor = nameColors?.main
                secondaryColor = nameColors?.secondary
                tertiaryColor = nameColors?.tertiary
                
                if let authorNameColor {
                    mainColor = authorNameColor
                } else {
                    mainColor = messageTheme.accentTextColor
                }
            }
            
            var titleString: NSAttributedString?
            var textString: NSAttributedString?
            var updatedContactInfo: String?
            
            var canMessage = false
            var canAdd = false
            
            var displayName: String = ""
            if let selectedContact = selectedContact {
                if !selectedContact.firstName.isEmpty && !selectedContact.lastName.isEmpty {
                    displayName = "\(selectedContact.firstName) \(selectedContact.lastName)"
                } else if !selectedContact.firstName.isEmpty {
                    displayName = selectedContact.firstName
                } else {
                    displayName = selectedContact.lastName
                }
                if displayName.isEmpty {
                    displayName = item.presentationData.strings.Message_Contact
                }
                
                if selectedContact.peerId != nil {
                    canMessage = true
                }
                
                let info: String
                if let previousContact = previousContact, previousContact.isEqual(to: selectedContact), let contactInfo = previousContactInfo {
                    info = contactInfo
                } else {
                    if let vCard = selectedContact.vCardData, let vCardData = vCard.data(using: .utf8), let contactData = DeviceContactExtendedData(vcard: vCardData) {
                        if displayName.isEmpty && !contactData.organization.isEmpty {
                            displayName = contactData.organization
                        }
                        
                        let infoLineLimit = 5
                        var infoComponents: [String] = []
                        if !contactData.basicData.phoneNumbers.isEmpty {
                            for phone in contactData.basicData.phoneNumbers {
                                if infoComponents.count < infoLineLimit {
                                    infoComponents.append(formatPhoneNumber(context: item.context, number: phone.value))
                                }
                            }
                        } else {
                             infoComponents.append(formatPhoneNumber(context: item.context, number: selectedContact.phoneNumber))
                        }
                        if infoComponents.count < infoLineLimit {
                            for email in contactData.emailAddresses {
                                if infoComponents.count < infoLineLimit {
                                    infoComponents.append(email.value)
                                }
                            }
                        }
                        if infoComponents.count < infoLineLimit {
                            if !contactData.organization.isEmpty && displayName != contactData.organization {
                                infoComponents.append(contactData.organization)
                            }
                        }
                        info = infoComponents.joined(separator: "\n")
                    } else {
                        info = formatPhoneNumber(context: item.context, number: selectedContact.phoneNumber)
                    }
                }
                
                canAdd = !item.associatedData.deviceContactsNumbers.contains(selectedContact.phoneNumber)
                    
                updatedContactInfo = info
                
                titleString = NSAttributedString(string: displayName, font: titleFont, textColor: mainColor)
                textString = NSAttributedString(string: info, font: textFont, textColor: messageTheme.primaryTextColor)
            } else {
                updatedContactInfo = nil
            }
            
            let contentProperties = ChatMessageBubbleContentProperties(hidesSimpleAuthorHeader: false, headerSpacing: 0.0, hidesBackground: .never, forceFullCorners: false, forceAlignment: .none)
            
            return (contentProperties, nil, CGFloat.greatestFiniteMagnitude, { constrainedSize, position in
                let avatarSize = CGSize(width: 40.0, height: 40.0)
                
                let sideInsets = layoutConstants.text.bubbleInsets.right * 2.0
                
                let maxTextWidth = max(1.0, constrainedSize.width - avatarSize.width - 7.0 - sideInsets)
                let (titleLayout, titleApply) = makeTitleLayout(TextNodeLayoutArguments(attributedString: titleString, backgroundColor: nil, maximumNumberOfLines: 1, truncationType: .end, constrainedSize: CGSize(width: maxTextWidth, height: CGFloat.greatestFiniteMagnitude), alignment: .natural, cutout: nil, insets: UIEdgeInsets()))
                let (textLayout, textApply) = makeTextLayout(TextNodeLayoutArguments(attributedString: textString, backgroundColor: nil, maximumNumberOfLines: 5, truncationType: .end, constrainedSize: CGSize(width: maxTextWidth, height: CGFloat.greatestFiniteMagnitude), alignment: .natural, cutout: nil, insets: UIEdgeInsets()))
                
                var edited = false
                if item.attributes.updatingMedia != nil {
                    edited = true
                }
                var viewCount: Int?
                var dateReplies = 0
                var dateReactionsAndPeers = mergedMessageReactionsAndPeers(accountPeerId: item.context.account.peerId, accountPeer: item.associatedData.accountPeer, message: item.message)
                if item.message.isRestricted(platform: "ios", contentSettings: item.context.currentContentSettings.with { $0 }) {
                    dateReactionsAndPeers = ([], [])
                }
                for attribute in item.message.attributes {
                    if let attribute = attribute as? EditedMessageAttribute {
                        edited = !attribute.isHidden
                    } else if let attribute = attribute as? ViewCountMessageAttribute {
                        viewCount = attribute.count
                    } else if let attribute = attribute as? ReplyThreadMessageAttribute, case .peer = item.chatLocation {
                        if let channel = item.message.peers[item.message.id.peerId] as? TelegramChannel, case .group = channel.info {
                            dateReplies = Int(attribute.count)
                        }
                    }
                }
                
                let dateText = stringForMessageTimestampStatus(accountPeerId: item.context.account.peerId, message: item.message, dateTimeFormat: item.presentationData.dateTimeFormat, nameDisplayOrder: item.presentationData.nameDisplayOrder, strings: item.presentationData.strings, associatedData: item.associatedData)
                
                let statusType: ChatMessageDateAndStatusType?
                if case .customChatContents = item.associatedData.subject {
                    statusType = nil
                } else if item.message.timestamp == 0 {
                    statusType = nil
                } else {
                    switch position {
                    case .linear(_, .None), .linear(_, .Neighbour(true, _, _)):
                        if incoming {
                            statusType = .BubbleIncoming
                        } else {
                            if item.message.flags.contains(.Failed) {
                                statusType = .BubbleOutgoing(.Failed)
                            } else if (item.message.flags.isSending && !item.message.isSentOrAcknowledged) || item.attributes.updatingMedia != nil {
                                statusType = .BubbleOutgoing(.Sending)
                            } else {
                                statusType = .BubbleOutgoing(.Sent(read: item.read))
                            }
                        }
                    default:
                        statusType = nil
                    }
                }
                
                var statusSuggestedWidthAndContinue: (CGFloat, (CGFloat) -> (CGSize, (ListViewItemUpdateAnimation) -> Void))?
                let messageEffect = item.message.messageEffect(availableMessageEffects: item.associatedData.availableMessageEffects)
                if let statusType = statusType {
                    var isReplyThread = false
                    if case .replyThread = item.chatLocation {
                        isReplyThread = true
                    }
                    
                    statusSuggestedWidthAndContinue = statusLayout(ChatMessageDateAndStatusNode.Arguments(
                        context: item.context,
                        presentationData: item.presentationData,
                        edited: edited,
                        impressionCount: viewCount,
                        dateText: dateText,
                        type: statusType,
                        layoutInput: .trailingContent(contentWidth: 1000.0, reactionSettings: shouldDisplayInlineDateReactions(message: item.message, isPremium: item.associatedData.isPremium, forceInline: item.associatedData.forceInlineReactions) ? ChatMessageDateAndStatusNode.TrailingReactionSettings(displayInline: true, preferAdditionalInset: false) : nil),
                        constrainedSize: CGSize(width: constrainedSize.width - sideInsets, height: .greatestFiniteMagnitude),
                        availableReactions: item.associatedData.availableReactions,
                        savedMessageTags: item.associatedData.savedMessageTags,
                        reactions: dateReactionsAndPeers.reactions,
                        reactionPeers: dateReactionsAndPeers.peers,
                        displayAllReactionPeers: item.message.id.peerId.namespace == Namespaces.Peer.CloudUser,
                        areReactionsTags: item.topMessage.areReactionsTags(accountPeerId: item.context.account.peerId),
                        messageEffect: messageEffect,
                        replyCount: dateReplies,
                        isPinned: item.message.tags.contains(.pinned) && !item.associatedData.isInPinnedListMode && isReplyThread,
                        hasAutoremove: item.message.isSelfExpiring,
                        canViewReactionList: canViewMessageReactionList(message: item.topMessage),
                        animationCache: item.controllerInteraction.presentationContext.animationCache,
                        animationRenderer: item.controllerInteraction.presentationContext.animationRenderer
                    ))
                }
                
                let avatarPlaceholderColor: UIColor
                if incoming {
                    avatarPlaceholderColor = item.presentationData.theme.theme.chat.message.incoming.mediaPlaceholderColor
                } else {
                    avatarPlaceholderColor = item.presentationData.theme.theme.chat.message.outgoing.mediaPlaceholderColor
                }
                
                let (messageButtonWidth, messageContinueLayout) = makeMessageButtonLayout(constrainedSize.width, 10.0, nil, false, item.presentationData.strings.Conversation_ContactMessage.uppercased(), mainColor, false, false)
                
                let addTitle: String
                if !canMessage && !canAdd  {
                    addTitle = item.presentationData.strings.Conversation_ViewContactDetails
                } else {
                    if canMessage {
                        addTitle = item.presentationData.strings.Conversation_ContactAddContact
                    } else {
                        addTitle = item.presentationData.strings.Conversation_ContactAddContactLong
                    }
                }
                let (addButtonWidth, addContinueLayout) = makeAddButtonLayout(constrainedSize.width, 10.0, nil, false, addTitle.uppercased(), mainColor, false, false)
                
                
                let showAddButton = !(!canAdd && canMessage)
                let showMessageButton = canMessage
                let buttonCount = (showAddButton ? 1 : 0) + (showMessageButton ? 1 : 0)
                
                let maxButtonWidth = max(messageButtonWidth, addButtonWidth)
                var maxContentWidth: CGFloat = avatarSize.width + 7.0
                if let statusSuggestedWidthAndContinue = statusSuggestedWidthAndContinue {
                    maxContentWidth = max(maxContentWidth, statusSuggestedWidthAndContinue.0)
                }
                maxContentWidth = max(maxContentWidth, 7.0 + avatarSize.width + 7.0 + titleLayout.size.width + 7.0)
                maxContentWidth = max(maxContentWidth, 7.0 + avatarSize.width + 7.0 + textLayout.size.width + 7.0)
                maxContentWidth = max(maxContentWidth, maxButtonWidth * CGFloat(buttonCount))
                maxContentWidth = max(maxContentWidth, 220.0)
                
                let contentWidth = maxContentWidth + layoutConstants.text.bubbleInsets.right * 2.0
                
                return (contentWidth, { boundingWidth in
                    let baseAvatarFrame = CGRect(origin: CGPoint(x: layoutConstants.text.bubbleInsets.right, y: layoutConstants.text.bubbleInsets.top), size: avatarSize)
                    
                    let lineWidth: CGFloat = 3.0
                    
                    var buttonCount = 1
                    if canMessage && canAdd {
                        buttonCount += 1
                    }
                    var buttonWidth = floor((boundingWidth - layoutConstants.text.bubbleInsets.right * 2.0 - lineWidth))
                    if buttonCount > 1 {
                        buttonWidth /= CGFloat(buttonCount)
                    }
                    
                    let (messageButtonSize, messageButtonApply) = messageContinueLayout(buttonWidth, 33.0)
                    let (addButtonSize, addButtonApply) = addContinueLayout(buttonWidth, 33.0)
                  
                    let buttonSpacing: CGFloat = 4.0
                    
                    let statusSizeAndApply = statusSuggestedWidthAndContinue?.1(boundingWidth - sideInsets)
                    
                    var layoutSize = CGSize(width: contentWidth, height: 64.0 + textLayout.size.height + addButtonSize.height + buttonSpacing)
                    if let statusSizeAndApply = statusSizeAndApply {
                        layoutSize.height += statusSizeAndApply.0.height - 4.0
                    }
                    let messageButtonFrame = CGRect(origin: CGPoint(x: layoutConstants.text.bubbleInsets.right + lineWidth, y: layoutSize.height - 24.0 - messageButtonSize.height), size: messageButtonSize)
                    let addButtonFrame = CGRect(origin: CGPoint(x: layoutConstants.text.bubbleInsets.right + lineWidth + (canMessage ? buttonWidth : 0.0), y: layoutSize.height - 24.0 - addButtonSize.height), size: addButtonSize)
                    let avatarFrame = baseAvatarFrame.offsetBy(dx: 9.0, dy: 14.0)
                    
                    var customLetters: [String] = []
                    if let selectedContact = selectedContact, selectedContact.peerId == nil {
                        let firstName = selectedContact.firstName
                        let lastName = selectedContact.lastName
                        if !firstName.isEmpty && !lastName.isEmpty {
                            customLetters = [String(firstName[..<firstName.index(after: firstName.startIndex)]).uppercased(), String(lastName[..<lastName.index(after: lastName.startIndex)]).uppercased()]
                        } else if !firstName.isEmpty {
                            customLetters = [String(firstName[..<firstName.index(after: firstName.startIndex)]).uppercased()]
                        } else if !lastName.isEmpty {
                            customLetters = [String(lastName[..<lastName.index(after: lastName.startIndex)]).uppercased()]
                        } else if !displayName.isEmpty {
                            customLetters = [String(displayName[..<displayName.index(after: displayName.startIndex)]).uppercased()]
                        }
                    }
                    
                    return (layoutSize, { [weak self] animation, synchronousLoads, _ in
                        if let strongSelf = self {
                            strongSelf.item = item
                            strongSelf.contact = selectedContact
                            strongSelf.contactInfo = updatedContactInfo
                            
                            strongSelf.avatarNode.frame = avatarFrame
                            
                            let _ = titleApply()
                            let _ = textApply()
                            let _ = messageButtonApply(animation)
                            let _ = addButtonApply(animation)
                            
                            strongSelf.titleNode.frame = CGRect(origin: CGPoint(x: avatarFrame.maxX + 7.0, y: avatarFrame.minY + 1.0), size: titleLayout.size)
                            strongSelf.textNode.frame = CGRect(origin: CGPoint(x: avatarFrame.maxX + 7.0, y: avatarFrame.minY + 20.0), size: textLayout.size)
                            
                            strongSelf.addButtonNode.frame = addButtonFrame
                            strongSelf.addButtonNode.isHidden = !canAdd && canMessage
                            strongSelf.messageButtonNode.frame = messageButtonFrame
                            strongSelf.messageButtonNode.isHidden = !canMessage
                            
                            let backgroundInsets = layoutConstants.text.bubbleInsets
                            let backgroundFrame = CGRect(origin: CGPoint(x: backgroundInsets.left, y: backgroundInsets.top + 5.0), size: CGSize(width: boundingWidth - layoutConstants.text.bubbleInsets.right * 2.0, height: layoutSize.height - 34.0))
                            
                            if let statusSizeAndApply = statusSizeAndApply {
                                strongSelf.dateAndStatusNode.frame = CGRect(origin: CGPoint(x: layoutConstants.text.bubbleInsets.left, y: backgroundFrame.maxY + 3.0), size: statusSizeAndApply.0)
                                if strongSelf.dateAndStatusNode.supernode == nil {
                                    strongSelf.addSubnode(strongSelf.dateAndStatusNode)
                                    statusSizeAndApply.1(.None)
                                } else {
                                    statusSizeAndApply.1(animation)
                                }
                            } else if strongSelf.dateAndStatusNode.supernode != nil {
                                strongSelf.dateAndStatusNode.removeFromSupernode()
                            }
                            
                            if let _ = titleString {
                                if strongSelf.titleNode.supernode == nil {
                                    strongSelf.addSubnode(strongSelf.titleNode)
                                }
                                if strongSelf.textNode.supernode == nil {
                                    strongSelf.addSubnode(strongSelf.textNode)
                                }
                            } else {
                                if strongSelf.titleNode.supernode != nil {
                                    strongSelf.titleNode.removeFromSupernode()
                                }
                                if strongSelf.textNode.supernode != nil {
                                    strongSelf.textNode.removeFromSupernode()
                                }
                            }
                            
                            if let peerId = selectedContact?.peerId, let peer = item.message.peers[peerId] {
                                strongSelf.avatarNode.setPeer(context: item.context, theme: item.presentationData.theme.theme, peer: EnginePeer(peer), emptyColor: avatarPlaceholderColor, synchronousLoad: synchronousLoads)
                            } else {
                                strongSelf.avatarNode.setCustomLetters(customLetters)
                            }
                            
                            if let forwardInfo = item.message.forwardInfo, forwardInfo.flags.contains(.isImported) {
                                strongSelf.dateAndStatusNode.pressed = {
                                    guard let strongSelf = self, let item = strongSelf.item else {
                                        return
                                    }
                                    item.controllerInteraction.displayImportedMessageTooltip(strongSelf.dateAndStatusNode)
                                }
                            } else if messageEffect != nil {
                                strongSelf.dateAndStatusNode.pressed = {
                                    guard let strongSelf = self, let item = strongSelf.item else {
                                        return
                                    }
                                    item.controllerInteraction.playMessageEffect(item.message)
                                }
                            } else {
                                strongSelf.dateAndStatusNode.pressed = nil
                            }
                            
                            var pattern: MessageInlineBlockBackgroundView.Pattern?
                            if let contactPeer, let backgroundEmojiId = contactPeer.backgroundEmojiId {
                                pattern = MessageInlineBlockBackgroundView.Pattern(
                                    context: item.context,
                                    fileId: backgroundEmojiId,
                                    file: item.message.associatedMedia[MediaId(
                                        namespace: Namespaces.Media.CloudFile,
                                        id: backgroundEmojiId
                                    )] as? TelegramMediaFile
                                )
                            }
                            
                            let patternTopRightPosition = CGPoint()
                            
                            let backgroundView: MessageInlineBlockBackgroundView
                            if let current = strongSelf.backgroundView {
                                backgroundView = current
                                animation.animator.updateFrame(layer: backgroundView.layer, frame: backgroundFrame, completion: nil)
                                backgroundView.update(size: backgroundFrame.size, isTransparent: false, primaryColor: mainColor, secondaryColor: secondaryColor, thirdColor: tertiaryColor, backgroundColor: nil, pattern: pattern, patternTopRightPosition: patternTopRightPosition, animation: animation)
                            } else {
                                backgroundView = MessageInlineBlockBackgroundView()
                                strongSelf.backgroundView = backgroundView
                                backgroundView.frame = backgroundFrame
                                strongSelf.view.insertSubview(backgroundView, at: 0)
                                backgroundView.update(size: backgroundFrame.size, isTransparent: false, primaryColor: mainColor, secondaryColor: secondaryColor, thirdColor: tertiaryColor, backgroundColor: nil, pattern: pattern, patternTopRightPosition: patternTopRightPosition, animation: .None)
                            }
                            
                            let separatorFrame = CGRect(origin: CGPoint(x: backgroundFrame.minX + 9.0, y: backgroundFrame.maxY - 36.0), size: CGSize(width: backgroundFrame.width - 18.0, height: UIScreenPixel))
                            
                            let actionButtonSeparator: SimpleLayer
                            if let current = strongSelf.actionButtonSeparator {
                                actionButtonSeparator = current
                                animation.animator.updateFrame(layer: actionButtonSeparator, frame: separatorFrame, completion: nil)
                            } else {
                                actionButtonSeparator = SimpleLayer()
                                strongSelf.actionButtonSeparator = actionButtonSeparator
                                strongSelf.layer.addSublayer(actionButtonSeparator)
                                actionButtonSeparator.frame = separatorFrame
                            }
                            
                            actionButtonSeparator.backgroundColor = mainColor.withMultipliedAlpha(0.2).cgColor
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
    
    override public func tapActionAtPoint(_ point: CGPoint, gesture: TapLongTapOrDoubleTapGesture, isEstimating: Bool) -> ChatMessageBubbleContentTapAction {
        if self.messageButtonNode.frame.contains(point) {
            return ChatMessageBubbleContentTapAction(content: .ignore)
        }
        if self.addButtonNode.frame.contains(point) {
            return ChatMessageBubbleContentTapAction(content: .ignore)
        }
        if self.dateAndStatusNode.supernode != nil, let _ = self.dateAndStatusNode.hitTest(self.view.convert(point, to: self.dateAndStatusNode.view), with: nil) {
            return ChatMessageBubbleContentTapAction(content: .ignore)
        }
        return ChatMessageBubbleContentTapAction(content: .none)
    }
    
    @objc private func contactTap(_ recognizer: UITapGestureRecognizer) {
        if case .ended = recognizer.state {
            if let item = self.item {
                var selectedContact: TelegramMediaContact?
                for media in item.message.media {
                    if let media = media as? TelegramMediaContact {
                        selectedContact = media
                    }
                }
                if let peerId = selectedContact?.peerId, let peer = item.message.peers[peerId] {
                    item.controllerInteraction.openPeer(EnginePeer(peer), .info(nil), nil, .default)
                } else {
                    let _ = item.controllerInteraction.openMessage(item.message, OpenMessageParams(mode: .default))
                }
            }
        }
    }
    
    @objc private func addButtonPressed() {
        if let item = self.item {
            let _ = item.controllerInteraction.openMessage(item.message, OpenMessageParams(mode: .default))
        }
    }
    
    @objc private func messageButtonPressed() {
        if let item = self.item {
            var selectedContact: TelegramMediaContact?
            for media in item.message.media {
                if let media = media as? TelegramMediaContact {
                    selectedContact = media
                }
            }
            if let peerId = selectedContact?.peerId, let peer = item.message.peers[peerId] {
                item.controllerInteraction.openPeer(EnginePeer(peer), .chat(textInputState: nil, subject: nil, peekData: nil), nil, .default)
            }
        }
    }
    
    override public func reactionTargetView(value: MessageReaction.Reaction) -> UIView? {
        if !self.dateAndStatusNode.isHidden {
            return self.dateAndStatusNode.reactionView(value: value)
        }
        return nil
    }
    
    override public func messageEffectTargetView() -> UIView? {
        if !self.dateAndStatusNode.isHidden {
            return self.dateAndStatusNode.messageEffectTargetView()
        }
        return nil
    }
    
    override public func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        if self.dateAndStatusNode.supernode != nil, let result = self.dateAndStatusNode.hitTest(self.view.convert(point, to: self.dateAndStatusNode.view), with: event) {
            return result
        }
        return super.hitTest(point, with: event)
    }
}
