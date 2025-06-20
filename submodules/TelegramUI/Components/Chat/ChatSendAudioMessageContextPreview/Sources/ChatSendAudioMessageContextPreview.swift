import Foundation
import UIKit
import AsyncDisplayKit
import TelegramPresentationData
import ChatPresentationInterfaceState
import AccountContext
import ChatSendMessageActionUI
import SwiftSignalKit
import ComponentFlow
import Display
import Postbox
import TelegramCore
import WallpaperBackgroundNode
import AudioWaveform
import ChatMessageItemView
import ChatMessageItemCommon
import ChatMessageBubbleContentNode
import ChatMessageMediaBubbleContentNode
import ChatControllerInteraction
import TelegramUIPreferences
import ChatHistoryEntry
import MosaicLayout

public final class ChatSendContactMessageContextPreview: UIView, ChatSendMessageContextScreenMediaPreview {
    private let context: AccountContext
    private let presentationData: PresentationData
    private let wallpaperBackgroundNode: WallpaperBackgroundNode?
    private let contactPeers: [ContactListPeer]
    
    private var messageNodes: [ListViewItemNode]?
    private let messagesContainer: UIView
    
    public var isReady: Signal<Bool, NoError> {
        return .single(true)
    }

    public var view: UIView {
        return self
    }
    
    public var globalClippingRect: CGRect? {
        return nil
    }

    public var layoutType: ChatSendMessageContextScreenMediaPreviewLayoutType {
        return .message
    }
    
    public init(context: AccountContext, presentationData: PresentationData, wallpaperBackgroundNode: WallpaperBackgroundNode?, contactPeers: [ContactListPeer]) {
        self.context = context
        self.presentationData = presentationData
        self.wallpaperBackgroundNode = wallpaperBackgroundNode
        self.contactPeers = contactPeers
        
        self.messagesContainer = UIView()
        self.messagesContainer.layer.sublayerTransform = CATransform3DMakeScale(-1.0, -1.0, 1.0)
        
        super.init(frame: CGRect())
        
        self.addSubview(self.messagesContainer)
    }
    
    required public init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    deinit {
    }
    
    public func animateIn(transition: ComponentTransition) {
        transition.animateAlpha(view: self.messagesContainer, from: 0.0, to: 1.0)
        transition.animateScale(view: self.messagesContainer, from: 0.001, to: 1.0)
    }

    public func animateOut(transition: ComponentTransition) {
        transition.setAlpha(view: self.messagesContainer, alpha: 0.0)
        transition.setScale(view: self.messagesContainer, scale: 0.001)
    }

    public func animateOutOnSend(transition: ComponentTransition) {
        transition.setAlpha(view: self.messagesContainer, alpha: 0.0)
    }

    public func update(containerSize: CGSize, transition: ComponentTransition) -> CGSize {
        var contactsMedia: [TelegramMediaContact] = []
        for peer in self.contactPeers {
            switch peer {
            case let .peer(contact, _, _):
                guard let contact = contact as? TelegramUser, let phoneNumber = contact.phone else {
                    continue
                }
                let contactData = DeviceContactExtendedData(basicData: DeviceContactBasicData(firstName: contact.firstName ?? "", lastName: contact.lastName ?? "", phoneNumbers: [DeviceContactPhoneNumberData(label: "_$!<Mobile>!$_", value: phoneNumber)]), middleName: "", prefix: "", suffix: "", organization: "", jobTitle: "", department: "", emailAddresses: [], urls: [], addresses: [], birthdayDate: nil, socialProfiles: [], instantMessagingProfiles: [], note: "")
                
                let phone = contactData.basicData.phoneNumbers[0].value
                contactsMedia.append(TelegramMediaContact(firstName: contactData.basicData.firstName, lastName: contactData.basicData.lastName, phoneNumber: phone, peerId: contact.id, vCardData: nil))
            case let .deviceContact(_, basicData):
                guard !basicData.phoneNumbers.isEmpty else {
                    continue
                }
                let contactData = DeviceContactExtendedData(basicData: basicData, middleName: "", prefix: "", suffix: "", organization: "", jobTitle: "", department: "", emailAddresses: [], urls: [], addresses: [], birthdayDate: nil, socialProfiles: [], instantMessagingProfiles: [], note: "")
                
                let phone = contactData.basicData.phoneNumbers[0].value
                contactsMedia.append(TelegramMediaContact(firstName: contactData.basicData.firstName, lastName: contactData.basicData.lastName, phoneNumber: phone, peerId: nil, vCardData: nil))
            }
        }
        
        var items: [ListViewItem] = []
        for contactMedia in contactsMedia {
            let message = Message(stableId: 1, stableVersion: 0, id: MessageId(peerId: self.context.account.peerId, namespace: 0, id: 1), globallyUniqueId: nil, groupingKey: nil, groupInfo: nil, threadId: nil, timestamp: 0, flags: [.Incoming], tags: [], globalTags: [], localTags: [], customTags: [], forwardInfo: nil, author: nil, text: "", attributes: [], media: [contactMedia], peers: SimpleDictionary(), associatedMessages: SimpleDictionary(), associatedMessageIds: [], associatedMedia: [:], associatedThreadInfo: nil, associatedStories: [:])
            
            let item = self.context.sharedContext.makeChatMessagePreviewItem(
                context: self.context,
                messages: [message],
                theme: presentationData.theme,
                strings: presentationData.strings,
                wallpaper: presentationData.chatWallpaper,
                fontSize: presentationData.chatFontSize,
                chatBubbleCorners: presentationData.chatBubbleCorners,
                dateTimeFormat: presentationData.dateTimeFormat,
                nameOrder: presentationData.nameDisplayOrder,
                forcedResourceStatus: FileMediaResourceStatus(mediaStatus: .fetchStatus(.Local), fetchStatus: .Local),
                tapMessage: nil,
                clickThroughMessage: nil,
                backgroundNode: self.wallpaperBackgroundNode,
                availableReactions: nil,
                accountPeer: nil,
                isCentered: false,
                isPreview: true,
                isStandalone: true
            )
            items.append(item)
        }
        
        let params = ListViewItemLayoutParams(width: containerSize.width, leftInset: 0.0, rightInset: 0.0, availableHeight: containerSize.height)
        if let messageNodes = self.messageNodes {
            for i in 0 ..< items.count {
                let itemNode = messageNodes[i]
                items[i].updateNode(async: { $0() }, node: {
                    return itemNode
                }, params: params, previousItem: i == 0 ? nil : items[i - 1], nextItem: i == (items.count - 1) ? nil : items[i + 1], animation: .None, completion: { (layout, apply) in
                    let nodeFrame = CGRect(origin: CGPoint(x: itemNode.frame.minX, y: itemNode.frame.minY), size: CGSize(width: containerSize.width, height: layout.size.height))
                    
                    itemNode.contentSize = layout.contentSize
                    itemNode.insets = layout.insets
                    itemNode.frame = nodeFrame
                    itemNode.isUserInteractionEnabled = false
                    
                    apply(ListViewItemApply(isOnScreen: true))
                })
            }
        } else {
            var messageNodes: [ListViewItemNode] = []
            for i in 0 ..< items.count {
                var itemNode: ListViewItemNode?
                items[i].nodeConfiguredForParams(async: { $0() }, params: params, synchronousLoads: false, previousItem: i == 0 ? nil : items[i - 1], nextItem: i == (items.count - 1) ? nil : items[i + 1], completion: { node, apply in
                    itemNode = node
                    apply().1(ListViewItemApply(isOnScreen: true))
                })
                itemNode!.isUserInteractionEnabled = false
                messageNodes.append(itemNode!)
                self.messagesContainer.addSubview(itemNode!.view)
            }
            self.messageNodes = messageNodes
        }
        
        var contentSize = CGSize()
        for messageNode in self.messageNodes ?? [] {
            guard let messageNode = messageNode as? ChatMessageItemView else {
                continue
            }
            if !contentSize.height.isZero {
                contentSize.height += 2.0
            }
            let contentFrame = messageNode.contentFrame()
            contentSize.height += contentFrame.height
            contentSize.width = max(contentSize.width, contentFrame.width)
        }
        
        var contentOffsetY: CGFloat = 0.0
        for messageNode in self.messageNodes ?? [] {
            guard let messageNode = messageNode as? ChatMessageItemView else {
                continue
            }
            if !contentOffsetY.isZero {
                contentOffsetY += 2.0
            }
            let contentFrame = messageNode.contentFrame()
            messageNode.frame = CGRect(origin: CGPoint(x: contentFrame.minX + contentSize.width - contentFrame.width + 6.0, y: 3.0 + contentOffsetY), size: CGSize(width: contentFrame.width, height: contentFrame.height))
            contentOffsetY += contentFrame.height
        }
        
        self.messagesContainer.frame = CGRect(origin: CGPoint(x: 6.0, y: 3.0), size: CGSize(width: contentSize.width, height: contentSize.height))
        
        return CGSize(width: contentSize.width - 4.0, height: contentSize.height + 2.0)
    }
}

public final class ChatSendAudioMessageContextPreview: UIView, ChatSendMessageContextScreenMediaPreview {
    private let context: AccountContext
    private let presentationData: PresentationData
    private let wallpaperBackgroundNode: WallpaperBackgroundNode?
    private let waveform: AudioWaveform
    
    private var messageNodes: [ListViewItemNode]?
    private let messagesContainer: UIView
    
    public var isReady: Signal<Bool, NoError> {
        return .single(true)
    }

    public var view: UIView {
        return self
    }
    
    public var globalClippingRect: CGRect? {
        return nil
    }

    public var layoutType: ChatSendMessageContextScreenMediaPreviewLayoutType {
        return .message
    }
    
    public init(context: AccountContext, presentationData: PresentationData, wallpaperBackgroundNode: WallpaperBackgroundNode?, waveform: AudioWaveform) {
        self.context = context
        self.presentationData = presentationData
        self.wallpaperBackgroundNode = wallpaperBackgroundNode
        self.waveform = waveform
        
        self.messagesContainer = UIView()
        self.messagesContainer.layer.sublayerTransform = CATransform3DMakeScale(-1.0, -1.0, 1.0)
        
        super.init(frame: CGRect())
        
        self.addSubview(self.messagesContainer)
    }
    
    required public init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    deinit {
    }
    
    public func animateIn(transition: ComponentTransition) {
        transition.animateAlpha(view: self.messagesContainer, from: 0.0, to: 1.0)
        transition.animateScale(view: self.messagesContainer, from: 0.001, to: 1.0)
    }

    public func animateOut(transition: ComponentTransition) {
        transition.setAlpha(view: self.messagesContainer, alpha: 0.0)
        transition.setScale(view: self.messagesContainer, scale: 0.001)
    }

    public func animateOutOnSend(transition: ComponentTransition) {
        transition.setAlpha(view: self.messagesContainer, alpha: 0.0)
    }

    public func update(containerSize: CGSize, transition: ComponentTransition) -> CGSize {
        let voiceAttributes: [TelegramMediaFileAttribute] = [.Audio(isVoice: true, duration: 23, title: nil, performer: nil, waveform: self.waveform.makeBitstream())]
        let voiceMedia = TelegramMediaFile(fileId: MediaId(namespace: 0, id: 0), partialReference: nil, resource: LocalFileMediaResource(fileId: 0), previewRepresentations: [], videoThumbnails: [], immediateThumbnailData: nil, mimeType: "audio/ogg", size: 0, attributes: voiceAttributes, alternativeRepresentations: [])
        
        let message = Message(stableId: 1, stableVersion: 0, id: MessageId(peerId: self.context.account.peerId, namespace: 0, id: 1), globallyUniqueId: nil, groupingKey: nil, groupInfo: nil, threadId: nil, timestamp: 0, flags: [.Incoming], tags: [], globalTags: [], localTags: [], customTags: [], forwardInfo: nil, author: nil, text: "", attributes: [], media: [voiceMedia], peers: SimpleDictionary(), associatedMessages: SimpleDictionary(), associatedMessageIds: [], associatedMedia: [:], associatedThreadInfo: nil, associatedStories: [:])
        
        let item = self.context.sharedContext.makeChatMessagePreviewItem(
            context: self.context,
            messages: [message],
            theme: presentationData.theme,
            strings: presentationData.strings,
            wallpaper: presentationData.chatWallpaper,
            fontSize: presentationData.chatFontSize,
            chatBubbleCorners: presentationData.chatBubbleCorners,
            dateTimeFormat: presentationData.dateTimeFormat,
            nameOrder: presentationData.nameDisplayOrder,
            forcedResourceStatus: FileMediaResourceStatus(mediaStatus: .fetchStatus(.Local), fetchStatus: .Local),
            tapMessage: nil,
            clickThroughMessage: nil,
            backgroundNode: self.wallpaperBackgroundNode,
            availableReactions: nil,
            accountPeer: nil,
            isCentered: false,
            isPreview: true,
            isStandalone: true
        )
        let items = [item]
        
        let params = ListViewItemLayoutParams(width: containerSize.width, leftInset: 0.0, rightInset: 0.0, availableHeight: containerSize.height)
        if let messageNodes = self.messageNodes {
            for i in 0 ..< items.count {
                let itemNode = messageNodes[i]
                items[i].updateNode(async: { $0() }, node: {
                    return itemNode
                }, params: params, previousItem: i == 0 ? nil : items[i - 1], nextItem: i == (items.count - 1) ? nil : items[i + 1], animation: .None, completion: { (layout, apply) in
                    let nodeFrame = CGRect(origin: itemNode.frame.origin, size: CGSize(width: containerSize.width, height: layout.size.height))
                    
                    itemNode.contentSize = layout.contentSize
                    itemNode.insets = layout.insets
                    itemNode.frame = nodeFrame
                    itemNode.isUserInteractionEnabled = false
                    
                    apply(ListViewItemApply(isOnScreen: true))
                })
            }
        } else {
            var messageNodes: [ListViewItemNode] = []
            for i in 0 ..< items.count {
                var itemNode: ListViewItemNode?
                items[i].nodeConfiguredForParams(async: { $0() }, params: params, synchronousLoads: false, previousItem: i == 0 ? nil : items[i - 1], nextItem: i == (items.count - 1) ? nil : items[i + 1], completion: { node, apply in
                    itemNode = node
                    apply().1(ListViewItemApply(isOnScreen: true))
                })
                itemNode!.isUserInteractionEnabled = false
                messageNodes.append(itemNode!)
                self.messagesContainer.addSubview(itemNode!.view)
            }
            self.messageNodes = messageNodes
        }
        
        guard let messageNode = self.messageNodes?.first as? ChatMessageItemView else {
            return CGSize(width: 10.0, height: 10.0)
        }
        let contentFrame = messageNode.contentFrame()
        
        self.messagesContainer.frame = CGRect(origin: CGPoint(x: 6.0, y: 3.0), size: CGSize(width: contentFrame.width, height: contentFrame.height))
        
        return CGSize(width: contentFrame.width - 4.0, height: contentFrame.height + 2.0)
    }
}

public final class ChatSendGroupMediaMessageContextPreview: UIView, ChatSendMessageContextScreenMediaPreview {
    private let context: AccountContext
    private let presentationData: PresentationData
    private let wallpaperBackgroundNode: WallpaperBackgroundNode?
    private let messages: [Message]
    
    private var chatPresentationData: ChatPresentationData?
    
    private var messageNodes: [EngineMessage.Id: ChatMessageMediaBubbleContentNode] = [:]
    private let messagesContainer: UIView
    
    public var isReady: Signal<Bool, NoError> {
        return .single(true)
    }

    public var view: UIView {
        return self
    }
    
    public var globalClippingRect: CGRect? {
        return nil
    }

    public var layoutType: ChatSendMessageContextScreenMediaPreviewLayoutType {
        return .media
    }
    
    public init(context: AccountContext, presentationData: PresentationData, wallpaperBackgroundNode: WallpaperBackgroundNode?, messages: [EngineMessage]) {
        self.context = context
        self.presentationData = presentationData
        self.wallpaperBackgroundNode = wallpaperBackgroundNode
        self.messages = messages.map { message in
            return message._asMessage().withUpdatedTimestamp(0)
        }
        
        self.messagesContainer = UIView()
        
        super.init(frame: CGRect())
        
        self.addSubview(self.messagesContainer)
    }
    
    required public init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    deinit {
    }
    
    public func animateIn(transition: ComponentTransition) {
        transition.animateAlpha(view: self.messagesContainer, from: 0.0, to: 1.0)
        transition.animateScale(view: self.messagesContainer, from: 0.001, to: 1.0)
    }

    public func animateOut(transition: ComponentTransition) {
        transition.setAlpha(view: self.messagesContainer, alpha: 0.0)
        transition.setScale(view: self.messagesContainer, scale: 0.001)
    }

    public func animateOutOnSend(transition: ComponentTransition) {
        transition.setAlpha(view: self.messagesContainer, alpha: 0.0)
    }

    public func update(containerSize: CGSize, transition: ComponentTransition) -> CGSize {
        let presentationData = self.context.sharedContext.currentPresentationData.with { $0 }
        
        let chatPresentationData: ChatPresentationData
        if let current = self.chatPresentationData {
            chatPresentationData = current
        } else {
            chatPresentationData = ChatPresentationData(
                theme: ChatPresentationThemeData(
                    theme: presentationData.theme,
                    wallpaper: presentationData.chatWallpaper
                ),
                fontSize: presentationData.chatFontSize,
                strings: presentationData.strings,
                dateTimeFormat: presentationData.dateTimeFormat,
                nameDisplayOrder: presentationData.nameDisplayOrder,
                disableAnimations: false,
                largeEmoji: false,
                chatBubbleCorners: presentationData.chatBubbleCorners
            )
            self.chatPresentationData = chatPresentationData
        }
        
        let controllerInteraction = ChatControllerInteraction(openMessage: { _, _ in
            return false }, openPeer: { _, _, _, _ in }, openPeerMention: { _, _ in }, openMessageContextMenu: { _, _, _, _, _, _ in }, openMessageReactionContextMenu: { _, _, _, _ in
            }, updateMessageReaction: { _, _, _, _ in }, activateMessagePinch: { _ in
            }, openMessageContextActions: { _, _, _, _ in }, navigateToMessage: { _, _, _ in }, navigateToMessageStandalone: { _ in
            }, navigateToThreadMessage: { _, _, _ in
            }, tapMessage: { _ in
        }, clickThroughMessage: { _, _ in
        }, toggleMessagesSelection: { _, _ in }, sendCurrentMessage: { _, _ in }, sendMessage: { _ in }, sendSticker: { _, _, _, _, _, _, _, _, _ in return false }, sendEmoji: { _, _, _ in }, sendGif: { _, _, _, _, _ in return false }, sendBotContextResultAsGif: { _, _, _, _, _, _ in
            return false
        }, requestMessageActionCallback: { _, _, _, _, _ in }, requestMessageActionUrlAuth: { _, _ in }, activateSwitchInline: { _, _, _ in }, openUrl: { _ in }, shareCurrentLocation: {}, shareAccountContact: {}, sendBotCommand: { _, _ in }, openInstantPage: { _, _ in  }, openWallpaper: { _ in  }, openTheme: { _ in  }, openHashtag: { _, _ in }, updateInputState: { _ in }, updateInputMode: { _ in }, openMessageShareMenu: { _ in
        }, presentController: { _, _ in
        }, presentControllerInCurrent: { _, _ in
        }, navigationController: {
            return nil
        }, chatControllerNode: {
            return nil
        }, presentGlobalOverlayController: { _, _ in }, callPeer: { _, _ in }, openConferenceCall: { _ in
        }, longTap: { _, _ in }, todoItemLongTap: { _, _ in }, openCheckoutOrReceipt: { _, _ in }, openSearch: { }, setupReply: { _ in
        }, canSetupReply: { _ in
            return .none
        }, canSendMessages: {
            return false
        }, navigateToFirstDateMessage: { _, _ in
        }, requestRedeliveryOfFailedMessages: { _ in
        }, addContact: { _ in
        }, rateCall: { _, _, _ in
        }, requestSelectMessagePollOptions: { _, _ in
        }, requestOpenMessagePollResults: { _, _ in
        }, openAppStorePage: {
        }, displayMessageTooltip: { _, _, _, _, _ in
        }, seekToTimecode: { _, _, _ in
        }, scheduleCurrentMessage: { _ in
        }, sendScheduledMessagesNow: { _ in
        }, editScheduledMessagesTime: { _ in
        }, performTextSelectionAction: { _, _, _, _ in
        }, displayImportedMessageTooltip: { _ in
        }, displaySwipeToReplyHint: {
        }, dismissReplyMarkupMessage: { _ in
        }, openMessagePollResults: { _, _ in
        }, openPollCreation: { _ in
        }, displayPollSolution: { _, _ in
        }, displayPsa: { _, _ in
        }, displayDiceTooltip: { _ in
        }, animateDiceSuccess: { _, _ in
        }, displayPremiumStickerTooltip: { _, _ in
        }, displayEmojiPackTooltip: { _, _ in
        }, openPeerContextMenu: { _, _, _, _, _ in
        }, openMessageReplies: { _, _, _ in
        }, openReplyThreadOriginalMessage: { _ in
        }, openMessageStats: { _ in
        }, editMessageMedia: { _, _ in
        }, copyText: { _ in
        }, displayUndo: { _ in
        }, isAnimatingMessage: { _ in
            return false
        }, getMessageTransitionNode: {
            return nil
        }, updateChoosingSticker: { _ in
        }, commitEmojiInteraction: { _, _, _, _ in
        }, openLargeEmojiInfo: { _, _, _ in
        }, openJoinLink: { _ in
        }, openWebView: { _, _, _, _ in
        }, activateAdAction: { _, _, _, _ in
        }, adContextAction: { _, _, _ in
        }, removeAd: { _ in
        }, openRequestedPeerSelection: { _, _, _, _ in
        }, saveMediaToFiles: { _ in
        }, openNoAdsDemo: {
        }, openAdsInfo: {
        }, displayGiveawayParticipationStatus: { _ in
        }, openPremiumStatusInfo: { _, _, _, _ in
        }, openRecommendedChannelContextMenu: { _, _, _ in
        }, openGroupBoostInfo: { _, _ in
        }, openStickerEditor: {
        }, openAgeRestrictedMessageMedia: { _, _ in
        }, playMessageEffect: { _ in
        }, editMessageFactCheck: { _ in
        }, sendGift: { _ in
        }, openUniqueGift: { _ in
        }, openMessageFeeException: {
        }, requestMessageUpdate: { _, _ in
        }, cancelInteractiveKeyboardGestures: {
        }, dismissTextInput: {
        }, scrollToMessageId: { _ in
        }, navigateToStory: { _, _ in
        }, attemptedNavigationToPrivateQuote: { _ in
        }, forceUpdateWarpContents: {
        }, playShakeAnimation: {
        }, displayQuickShare: { _, _ ,_ in
        }, updateChatLocationThread: { _, _ in
        }, requestToggleTodoMessageItem: { _, _, _ in
        }, displayTodoToggleUnavailable: { _ in
        }, openStarsPurchase: { _ in
        }, automaticMediaDownloadSettings: MediaAutoDownloadSettings.defaultSettings,
        pollActionState: ChatInterfacePollActionState(), stickerSettings: ChatInterfaceStickerSettings(), presentationContext: ChatPresentationContext(context: self.context, backgroundNode: self.wallpaperBackgroundNode))
        
        let associatedData = ChatMessageItemAssociatedData(
            automaticDownloadPeerType: .channel,
            automaticDownloadPeerId: nil,
            automaticDownloadNetworkType: .cellular,
            isRecentActions: false,
            availableReactions: nil,
            availableMessageEffects: nil,
            savedMessageTags: nil,
            defaultReaction: nil,
            isPremium: false,
            accountPeer: nil
        )
        
        let entryAttributes = ChatMessageEntryAttributes(rank: nil, isContact: false, contentTypeHint: .generic, updatingMedia: nil, isPlaying: false, isCentered: false, authorStoryStats: nil)
        
        let items = self.messages.map { message -> ChatMessageBubbleContentItem in
            return ChatMessageBubbleContentItem(
                context: self.context,
                controllerInteraction: controllerInteraction,
                message: message,
                topMessage: message,
                content: .message(message: message, read: true, selection: .none, attributes: entryAttributes, location: nil),
                read: true,
                chatLocation: .peer(id: self.context.account.peerId),
                presentationData: chatPresentationData,
                associatedData: associatedData,
                attributes: entryAttributes,
                isItemPinned: false,
                isItemEdited: false
            )
        }
        
        let layoutConstants = chatMessageItemLayoutConstants(
            (ChatMessageItemLayoutConstants.compact, ChatMessageItemLayoutConstants.regular),
            params: ListViewItemLayoutParams(
                width: containerSize.width,
                leftInset: 0.0,
                rightInset: 0.0,
                availableHeight: 10000.0
            ),
            presentationData: chatPresentationData
        )
        
        if items.count == 1 {
            let messageNode: ChatMessageMediaBubbleContentNode
            if let current = self.messageNodes[items[0].message.id] {
                messageNode = current
            } else {
                messageNode = ChatMessageMediaBubbleContentNode()
                self.messageNodes[items[0].message.id] = messageNode
                self.messagesContainer.addSubview(messageNode.view)
            }
            
            let makeMessageLayout = messageNode.asyncLayoutContent()
            
            let (_, _, _, continueMessageLayout) = makeMessageLayout(
                items[0],
                layoutConstants,
                ChatMessageBubblePreparePosition.linear(
                    top: ChatMessageBubbleRelativePosition.None(.None(.None)),
                    bottom: ChatMessageBubbleRelativePosition.None(.None(.None))
                ),
                nil,
                CGSize(width: containerSize.width, height: 10000.0),
                0.0
            )
            
            let (finalizedWidth, finalizeMessageLayout) = continueMessageLayout(
                CGSize(width: containerSize.width, height: 10000.0),
                ChatMessageBubbleContentPosition.linear(
                    top: ChatMessageBubbleRelativePosition.None(.None(.None)),
                    bottom: ChatMessageBubbleRelativePosition.None(.None(.None))
                )
            )
            let _ = finalizedWidth
            
            let (finalizedSize, apply) = finalizeMessageLayout(finalizedWidth)
            apply(.None, true, nil)
            
            let contentFrameInset = UIEdgeInsets(top: -2.0, left: -2.0, bottom: -2.0, right: -2.0)
            
            let contentFrame = CGRect(origin: CGPoint(x: contentFrameInset.left, y: contentFrameInset.top), size: finalizedSize)
            messageNode.frame = contentFrame
            
            let messagesContainerFrame = CGRect(origin: CGPoint(x: 0.0, y: 0.0), size: CGSize(width: contentFrame.width + contentFrameInset.left + contentFrameInset.right, height: contentFrame.height + contentFrameInset.top + contentFrameInset.bottom))
            
            self.messagesContainer.frame = messagesContainerFrame
            return messagesContainerFrame.size
        } else {
            var contentPropertiesAndLayouts: [(
                CGSize?,
                ChatMessageBubbleContentProperties,
                ChatMessageBubblePreparePosition,
                (CGSize, ChatMessageBubbleContentPosition) -> (CGFloat, (CGFloat) -> (CGSize, (ListViewItemUpdateAnimation, Bool, ListViewItemApply?) -> Void)),
                ChatMessageMediaBubbleContentNode
            )] = []
            
            let bottomPosition: ChatMessageBubbleRelativePosition = ChatMessageBubbleRelativePosition.None(.None(.None))
            
            var firstNodeTopPosition: ChatMessageBubbleRelativePosition = ChatMessageBubbleRelativePosition.None(.None(.None))
            if "".isEmpty {
                firstNodeTopPosition = ChatMessageBubbleRelativePosition.None(.None(.None))
            }
            var lastNodeTopPosition = ChatMessageBubbleRelativePosition.None(.None(.None))
            if "".isEmpty {
                lastNodeTopPosition = ChatMessageBubbleRelativePosition.None(.None(.None))
            }
            
            let contentFrameInset = UIEdgeInsets(top: -2.0, left: -2.0, bottom: -2.0, right: -2.0)
            
            var maximumNodeWidth: CGFloat = containerSize.width + contentFrameInset.left + contentFrameInset.right
            let maximumContentWidth = maximumNodeWidth
            
            for i in 0 ..< items.count {
                let messageNode: ChatMessageMediaBubbleContentNode
                if let current = self.messageNodes[items[i].message.id] {
                    messageNode = current
                } else {
                    messageNode = ChatMessageMediaBubbleContentNode()
                    self.messageNodes[items[i].message.id] = messageNode
                    self.messagesContainer.addSubview(messageNode.view)
                }
                
                let prepareLayout = messageNode.asyncLayoutContent()
                
                let prepareContentPosition: ChatMessageBubblePreparePosition = .mosaic(top: .None(.None(.Incoming)), bottom: i == (items.count - 1 - 1) ? bottomPosition : .None(.None(.Incoming)), index: i)
                
                let (properties, unboundSize, maxNodeWidth, nodeLayout) = prepareLayout(items[i], layoutConstants, prepareContentPosition, nil, CGSize(width: maximumContentWidth, height: CGFloat.greatestFiniteMagnitude), 0.0)
                maximumNodeWidth = min(maximumNodeWidth, maxNodeWidth)
                
                contentPropertiesAndLayouts.append((unboundSize, properties, prepareContentPosition, nodeLayout, messageNode))
            }
            
            let maxSize = layoutConstants.image.maxDimensions.fittedToWidthOrSmaller(maximumContentWidth)
            let (innerFramesAndPositions, innerSize) = chatMessageBubbleMosaicLayout(maxSize: maxSize, itemSizes: contentPropertiesAndLayouts.map { item in
                guard let size = item.0, size.width > 0.0, size.height > 0 else {
                    return CGSize(width: 256.0, height: 256.0)
                }
                return size
            })
            
            let framesAndPositions = innerFramesAndPositions
            
            let size = CGSize(width: innerSize.width, height: innerSize.height)
            
            var contentNodePropertiesAndFinalize: [(
                ChatMessageBubbleContentProperties,
                ChatMessageBubbleContentPosition?,
                (CGFloat) -> (CGSize, (ListViewItemUpdateAnimation, Bool, ListViewItemApply?) -> Void),
                ChatMessageMediaBubbleContentNode
            )] = []
            
            var maxContentWidth = 0.0
            for i in 0 ..< contentPropertiesAndLayouts.count {
                let (_, contentNodeProperties, _, contentNodeLayout, messageNode) = contentPropertiesAndLayouts[i]
                
                let mosaicIndex = i
                
                let position = framesAndPositions[mosaicIndex].1
                
                let topLeft: ChatMessageBubbleContentMosaicNeighbor
                let topRight: ChatMessageBubbleContentMosaicNeighbor
                let bottomLeft: ChatMessageBubbleContentMosaicNeighbor
                let bottomRight: ChatMessageBubbleContentMosaicNeighbor
                
                switch firstNodeTopPosition {
                case .Neighbour:
                    topLeft = .merged
                    topRight = .merged
                case .BubbleNeighbour:
                    topLeft = .mergedBubble
                    topRight = .mergedBubble
                case let .None(status):
                    if position.contains(.top) && position.contains(.left) {
                        switch status {
                        case .Left, .Both:
                            topLeft = .mergedBubble
                        case .Right:
                            topLeft = .none(tail: false)
                        case .None:
                            topLeft = .none(tail: false)
                        }
                    } else {
                        topLeft = .merged
                    }
                    
                    if position.contains(.top) && position.contains(.right) {
                        switch status {
                        case .Left:
                            topRight = .none(tail: false)
                        case .Right, .Both:
                            topRight = .mergedBubble
                        case .None:
                            topRight = .none(tail: false)
                        }
                    } else {
                        topRight = .merged
                    }
                }
                
                let lastMosaicBottomPosition: ChatMessageBubbleRelativePosition = lastNodeTopPosition
                
                if position.contains(.bottom), case .Neighbour = lastMosaicBottomPosition {
                    bottomLeft = .merged
                    bottomRight = .merged
                } else {
                    let switchValue = lastNodeTopPosition

                    switch switchValue {
                    case .Neighbour:
                        bottomLeft = .merged
                        bottomRight = .merged
                    case .BubbleNeighbour:
                        bottomLeft = .mergedBubble
                        bottomRight = .mergedBubble
                    case let .None(status):
                        if position.contains(.bottom) && position.contains(.left) {
                            switch status {
                            case .Left, .Both:
                                bottomLeft = .mergedBubble
                            case .Right:
                                bottomLeft = .none(tail: false)
                            case let .None(tailStatus):
                                if case .Incoming = tailStatus {
                                    bottomLeft = .none(tail: true)
                                } else {
                                    bottomLeft = .none(tail: false)
                                }
                            }
                        } else {
                            bottomLeft = .merged
                        }
                        
                        if position.contains(.bottom) && position.contains(.right) {
                            switch status {
                            case .Left:
                                bottomRight = .none(tail: false)
                            case .Right, .Both:
                                bottomRight = .mergedBubble
                            case let .None(tailStatus):
                                if case .Outgoing = tailStatus {
                                    bottomRight = .none(tail: true)
                                } else {
                                    bottomRight = .none(tail: false)
                                }
                            }
                        } else {
                            bottomRight = .merged
                        }
                    }
                }
                
                let (_, contentNodeFinalize) = contentNodeLayout(framesAndPositions[mosaicIndex].0.size, .mosaic(position: ChatMessageBubbleContentMosaicPosition(topLeft: topLeft, topRight: topRight, bottomLeft: bottomLeft, bottomRight: bottomRight), wide: position.isWide))
                
                contentNodePropertiesAndFinalize.append((contentNodeProperties, nil, contentNodeFinalize, messageNode))
                
                maxContentWidth = max(maxContentWidth, size.width)
            }
            
            for i in 0 ..< contentNodePropertiesAndFinalize.count {
                let (_, _, finalize, messageNode) = contentNodePropertiesAndFinalize[i]
                
                let mosaicIndex = i
                
                let (_, apply) = finalize(maxContentWidth)
                let contentNodeFrame = framesAndPositions[mosaicIndex].0.offsetBy(dx: 0.0, dy: 0.0)
                apply(.None, true, nil)
                
                messageNode.frame = contentNodeFrame
            }
            
            let messagesContainerFrame = CGRect(origin: CGPoint(x: 0.0, y: 0.0), size: CGSize(width: size.width, height: size.height))
            
            self.messagesContainer.frame = messagesContainerFrame
            // 4.0 is a magic number to compensate for offset in other types of content
            return CGSize(width: messagesContainerFrame.width, height: messagesContainerFrame.height - 4.0)
        }
    }
}
