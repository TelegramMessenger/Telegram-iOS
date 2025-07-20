import Foundation
import UIKit
import AsyncDisplayKit
import TelegramCore
import Postbox
import SwiftSignalKit
import Display
import TelegramPresentationData
import TelegramUIPreferences
import SafariServices
import AccountContext
import TemporaryCachedPeerDataManager
import AlertUI
import PresentationDataUtils
import OpenInExternalAppUI
import InstantPageUI
import HashtagSearchUI
import StickerPackPreviewUI
import JoinLinkPreviewUI
import LanguageLinkPreviewUI
import PeerInfoUI
import InviteLinksUI
import UndoUI
import TelegramCallsUI
import WallpaperBackgroundNode
import BotPaymentsUI
import ContextUI
import Pasteboard
import ChatControllerInteraction
import ChatPresentationInterfaceState
import ChatMessageItemView
import ChatLoadingNode

private final class ChatRecentActionsListOpaqueState {
    let entries: [ChatRecentActionsEntry]
    let canLoadEarlier: Bool
    
    init(entries: [ChatRecentActionsEntry], canLoadEarlier: Bool) {
        self.entries = entries
        self.canLoadEarlier = canLoadEarlier
    }
}

final class ChatRecentActionsControllerNode: ViewControllerTracingNode {
    private let context: AccountContext
    private let peer: Peer
    private var presentationData: PresentationData
    
    private let pushController: (ViewController) -> Void
    private let presentController: (ViewController, PresentationContextType,  Any?) -> Void
    private let getNavigationController: () -> NavigationController?
    var isEmptyUpdated: (Bool) -> Void = { _ in }
    
    private var controllerInteraction: ChatControllerInteraction!
    
    private let galleryHiddenMesageAndMediaDisposable = MetaDisposable()
    private let temporaryHiddenGalleryMediaDisposable = MetaDisposable()
    
    private var chatPresentationData: ChatPresentationData
    private var chatPresentationDataPromise: Promise<ChatPresentationData>
    
    private var automaticMediaDownloadSettings: MediaAutoDownloadSettings
    
    private var containerLayout: (ContainerViewLayout, CGFloat)?
    private var visibleAreaInset = UIEdgeInsets()
    
    private let backgroundNode: WallpaperBackgroundNode
    private let panelBackgroundNode: NavigationBackgroundNode
    private let panelSeparatorNode: ASDisplayNode
    private let panelButtonNode: HighlightableButtonNode
    private let panelInfoButtonNode: HighlightableButtonNode
    
    fileprivate let listNode: ListView
    private let loadingNode: ChatLoadingNode
    private let emptyNode: ChatRecentActionsEmptyNode
    
    private let navigationActionDisposable = MetaDisposable()
    
    private var expandedDeletedMessages = Set<EngineMessage.Id>() {
        didSet {
            self.expandedDeletedMessagesPromise.set(self.expandedDeletedMessages)
        }
    }
    private let expandedDeletedMessagesPromise = ValuePromise<Set<EngineMessage.Id>>(Set())
    
    private var isLoading: Bool = false {
        didSet {
            if self.isLoading != oldValue {
                self.loadingNode.isHidden = !self.isLoading
            }
        }
    }
    
    private(set) var filter: ChannelAdminEventLogFilter = ChannelAdminEventLogFilter()
    private let eventLogContext: ChannelAdminEventLogContext
    
    private var enqueuedTransitions: [(ChatRecentActionsHistoryTransition, Bool)] = []
    private var searchResultsState: (String, [MessageIndex])?
    
    private var historyDisposable: Disposable?
    private let resolvePeerByNameDisposable = MetaDisposable()
    private var adminsDisposable: Disposable?
    private var adminsState: ChannelMemberListState?
    private let banDisposables = DisposableDict<PeerId>()
    private let reportFalsePositiveDisposables = DisposableDict<MessageId>()
    
    private weak var antiSpamTooltipController: UndoOverlayController?
    
    private weak var controller: ChatRecentActionsController?
    
    init(context: AccountContext, controller: ChatRecentActionsController, peer: Peer, presentationData: PresentationData, pushController: @escaping (ViewController) -> Void, presentController: @escaping (ViewController, PresentationContextType, Any?) -> Void, getNavigationController: @escaping () -> NavigationController?) {
        self.context = context
        self.controller = controller
        self.peer = peer
        self.presentationData = presentationData
        self.pushController = pushController
        self.presentController = presentController
        self.getNavigationController = getNavigationController
        
        self.automaticMediaDownloadSettings = context.sharedContext.currentAutomaticMediaDownloadSettings
        
        self.backgroundNode = createWallpaperBackgroundNode(context: context, forChatDisplay: true)
        self.backgroundNode.isUserInteractionEnabled = false
        
        self.panelBackgroundNode = NavigationBackgroundNode(color: self.presentationData.theme.chat.inputPanel.panelBackgroundColor)
        self.panelSeparatorNode = ASDisplayNode()
        self.panelSeparatorNode.backgroundColor = self.presentationData.theme.chat.inputPanel.panelSeparatorColor
        self.panelButtonNode = HighlightableButtonNode()
        self.panelButtonNode.setTitle(self.presentationData.strings.Channel_AdminLog_Settings, with: Font.regular(17.0), with: self.presentationData.theme.chat.inputPanel.panelControlAccentColor, for: [])
        self.panelInfoButtonNode = HighlightableButtonNode()
        
        self.listNode = ListView()
        self.listNode.dynamicBounceEnabled = false
        self.listNode.transform = CATransform3DMakeRotation(CGFloat(Double.pi), 0.0, 0.0, 1.0)
        self.listNode.accessibilityPageScrolledString = { row, count in
            return presentationData.strings.VoiceOver_ScrollStatus(row, count).string
        }
        
        self.loadingNode = ChatLoadingNode(context: context, theme: self.presentationData.theme, chatWallpaper: self.presentationData.chatWallpaper, bubbleCorners: self.presentationData.chatBubbleCorners)
        self.emptyNode = ChatRecentActionsEmptyNode(theme: self.presentationData.theme, chatWallpaper: self.presentationData.chatWallpaper, chatBubbleCorners: self.presentationData.chatBubbleCorners, hasIcon: true)
        self.emptyNode.alpha = 0.0
                
        self.chatPresentationData = ChatPresentationData(theme: ChatPresentationThemeData(theme: presentationData.theme, wallpaper: presentationData.chatWallpaper), fontSize: presentationData.chatFontSize, strings: presentationData.strings, dateTimeFormat: presentationData.dateTimeFormat, nameDisplayOrder: presentationData.nameDisplayOrder, disableAnimations: true, largeEmoji: presentationData.largeEmoji, chatBubbleCorners: presentationData.chatBubbleCorners)
        self.chatPresentationDataPromise = Promise()
        
        self.eventLogContext = self.context.engine.peers.channelAdminEventLog(peerId: self.peer.id)
        
        super.init()
                
        self.addSubnode(self.backgroundNode)
        self.addSubnode(self.listNode)
        self.addSubnode(self.loadingNode)
        self.addSubnode(self.emptyNode)
        self.addSubnode(self.panelBackgroundNode)
        self.addSubnode(self.panelSeparatorNode)
        self.addSubnode(self.panelButtonNode)
        self.addSubnode(self.panelInfoButtonNode)
        
        self.panelButtonNode.addTarget(self, action: #selector(self.settingsButtonPressed), forControlEvents: .touchUpInside)
        self.panelInfoButtonNode.addTarget(self, action: #selector(self.infoButtonPressed), forControlEvents: .touchUpInside)
        
        let (adminsDisposable, _) = self.context.peerChannelMemberCategoriesContextsManager.admins(engine: self.context.engine, postbox: self.context.account.postbox, network: self.context.account.network, accountPeerId: context.account.peerId, peerId: self.peer.id, searchQuery: nil, updated: { [weak self] state in
            self?.adminsState = state
        })
        self.adminsDisposable = adminsDisposable
        
        let controllerInteraction = ChatControllerInteraction(openMessage: { [weak self] message, _ in
            if let strongSelf = self, let navigationController = strongSelf.getNavigationController() {
                guard let state = strongSelf.listNode.opaqueTransactionState as? ChatRecentActionsListOpaqueState else {
                    return false
                }
                for entry in state.entries {
                    if entry.entry.headerStableId == message.stableId {
                        if case let .deleteMessage(message) = entry.entry.event.action {
                            if strongSelf.expandedDeletedMessages.contains(message.id) {
                                strongSelf.expandedDeletedMessages.remove(message.id)
                            } else {
                                strongSelf.expandedDeletedMessages.insert(message.id)
                            }
                            return true
                        }
                    }
                    if entry.entry.stableId == message.stableId {
                        switch entry.entry.event.action {
                            case let .changeStickerPack(_, new):
                                if let new = new {
                                    strongSelf.presentController(StickerPackScreen(context: strongSelf.context, mainStickerPack: new, stickerPacks: [new], parentNavigationController: strongSelf.getNavigationController()), .window(.root), nil)
                                    return true
                                }
                            case let .editExportedInvitation(_, invite), let .revokeExportedInvitation(invite), let .deleteExportedInvitation(invite), let .participantJoinedViaInvite(invite, _), let .participantJoinByRequest(invite, _):
                                if let inviteLink = invite.link {
                                    if invite.isPermanent {
                                        if !inviteLink.hasSuffix("...") {
                                            let actionSheet = ActionSheetController(presentationData: strongSelf.presentationData)
                                            
                                            var items: [ActionSheetItem] = []
                                            items.append(ActionSheetTextItem(title: inviteLink))
                                            items.append(ActionSheetButtonItem(title: strongSelf.presentationData.strings.InviteLink_ContextRevoke, color: .destructive, action: { [weak actionSheet] in
                                                actionSheet?.dismissAnimated()
                                                if let strongSelf = self {
                                                    let _ = (strongSelf.context.engine.peers.revokePeerExportedInvitation(peerId: peer.id, link: inviteLink)
                                                    |> deliverOnMainQueue).startStandalone(completed: { [weak self] in
                                                        self?.eventLogContext.reload()
                                                    })
                                                }
                                            }))
                                            actionSheet.setItemGroups([ActionSheetItemGroup(items: items), ActionSheetItemGroup(items: [
                                                ActionSheetButtonItem(title: strongSelf.presentationData.strings.Common_Cancel, color: .accent, font: .bold, action: { [weak actionSheet] in
                                                    actionSheet?.dismissAnimated()
                                                })
                                            ])])
                                            strongSelf.presentController(actionSheet, .window(.root), nil)
                                        }
                                    } else {
                                        let controller = InviteLinkViewController(
                                            context: strongSelf.context,
                                            updatedPresentationData: strongSelf.controller?.updatedPresentationData,
                                            peerId: peer.id,
                                            invite: invite,
                                            invitationsContext: nil,
                                            revokedInvitationsContext: nil,
                                            importersContext: nil
                                        )
                                        strongSelf.pushController(controller)
                                    }
                                    return true
                                }
                            case .changeHistoryTTL:
                                if strongSelf.peer.canSetupAutoremoveTimeout(accountPeerId: strongSelf.context.account.peerId) {
                                    strongSelf.presentAutoremoveSetup()
                                    return true
                                }
                            default:
                                break
                        }
                        
                        break
                    }
                }
                let gallerySource = GalleryControllerItemSource.standaloneMessage(message, nil)
                return context.sharedContext.openChatMessage(OpenChatMessageParams(context: context, chatLocation: nil, chatFilterTag: nil, chatLocationContextHolder: nil, message: message, standalone: true, reverseMessageGalleryOrder: false, navigationController: navigationController, dismissInput: {
                    //self?.chatDisplayNode.dismissInput()
                }, present: { c, a, _ in
                    self?.presentController(c, .window(.root), a)
                }, transitionNode: { messageId, media, adjustRect in
                    var selectedNode: (ASDisplayNode, CGRect, () -> (UIView?, UIView?))?
                    if let strongSelf = self {
                        strongSelf.listNode.forEachItemNode { itemNode in
                            if let itemNode = itemNode as? ChatMessageItemView {
                                if let result = itemNode.transitionNode(id: messageId, media: media, adjustRect: adjustRect) {
                                    selectedNode = result
                                }
                            }
                        }
                    }
                    return selectedNode
                }, addToTransitionSurface: { view in
                    if let strongSelf = self {
                        strongSelf.listNode.view.superview?.insertSubview(view, aboveSubview: strongSelf.listNode.view)
                    }
                }, openUrl: { url in
                    self?.openUrl(url)
                }, openPeer: { peer, navigation in
                    self?.openPeer(peer: EnginePeer(peer))
                }, callPeer: { peerId, isVideo in
                    self?.controllerInteraction?.callPeer(peerId, isVideo)
                }, openConferenceCall: { message in
                    self?.controllerInteraction?.openConferenceCall(message)
                }, enqueueMessage: { _ in
                }, sendSticker: nil, sendEmoji: nil, setupTemporaryHiddenMedia: { _, _, _ in }, chatAvatarHiddenMedia: {  signal, media in
                    if let strongSelf = self {
                        strongSelf.temporaryHiddenGalleryMediaDisposable.set((signal |> deliverOnMainQueue).startStrict(next: { messageId in
                            if let strongSelf = self, let controllerInteraction = strongSelf.controllerInteraction {
                                var messageIdAndMedia: [MessageId: [Media]] = [:]
                                
                                if let messageId = messageId {
                                    messageIdAndMedia[messageId] = [media]
                                }
                                
                                controllerInteraction.hiddenMedia = messageIdAndMedia
                                
                                strongSelf.listNode.forEachItemNode { itemNode in
                                    if let itemNode = itemNode as? ChatMessageItemView {
                                        itemNode.updateHiddenMedia()
                                    }
                                }
                            }
                        }))
                    }
                }, gallerySource: gallerySource))
            }
            return false
        }, openPeer: { [weak self] peer, _, message, _ in
            if peer.id != context.account.peerId {
                self?.openPeer(peer: peer)
            }
        }, openPeerMention: { [weak self] name, _ in
            self?.openPeerMention(name)
        }, openMessageContextMenu: { [weak self] message, selectAll, node, frame, anyRecognizer, location in
            let recognizer: TapLongTapOrDoubleTapGestureRecognizer? = anyRecognizer as? TapLongTapOrDoubleTapGestureRecognizer
            let gesture: ContextGesture? = anyRecognizer as? ContextGesture
            self?.openMessageContextMenu(message: message, selectAll: selectAll, node: node, frame: frame, recognizer: recognizer, gesture: gesture, location: location)
        }, openMessageReactionContextMenu: { _, _, _, _ in
        }, updateMessageReaction: { _, _, _, _ in
        }, activateMessagePinch: { _ in
        }, openMessageContextActions: { _, _, _, _ in
        }, navigateToMessage: { [weak self] fromId, toId, params in
            guard let self else {
                return
            }
        
            context.sharedContext.navigateToChat(accountId: self.context.account.id, peerId: toId.peerId, messageId: toId)
        }, navigateToMessageStandalone: { _ in
        }, navigateToThreadMessage: { [weak self] peerId, threadId, _ in
            if let context = self?.context, let navigationController = self?.getNavigationController() {
                let _ = context.sharedContext.navigateToForumThread(context: context, peerId: peerId, threadId: threadId, messageId: nil, navigationController: navigationController, activateInput: nil, scrollToEndIfExists: false, keepStack: .always, animated: true).startStandalone()
            }
        }, tapMessage: nil, clickThroughMessage: { _, _ in }, toggleMessagesSelection: { _, _ in }, sendCurrentMessage: { _, _ in }, sendMessage: { _ in }, sendSticker: { _, _, _, _, _, _, _, _, _ in return false }, sendEmoji: { _, _, _ in }, sendGif: { _, _, _, _, _ in return false }, sendBotContextResultAsGif: { _, _, _, _, _, _ in return false
        }, requestMessageActionCallback: { [weak self] message, _, _, _, _ in
            guard let self else {
                return
            }
            if self.expandedDeletedMessages.contains(message.id) {
                self.expandedDeletedMessages.remove(message.id)
            } else {
                self.expandedDeletedMessages.insert(message.id)
            }
        }, requestMessageActionUrlAuth: { _, _ in }, activateSwitchInline: { _, _, _ in }, openUrl: { [weak self] url in
            self?.openUrl(url.url, progress: url.progress)
        }, shareCurrentLocation: {}, shareAccountContact: {}, sendBotCommand: { _, _ in }, openInstantPage: { [weak self] message, associatedData in
            if let strongSelf = self, let navigationController = strongSelf.getNavigationController() {
                if let controller = strongSelf.context.sharedContext.makeInstantPageController(context: strongSelf.context, message: message, sourcePeerType: associatedData?.automaticDownloadPeerType) {
                    navigationController.pushViewController(controller)
                }
            }
        }, openWallpaper: { [weak self] message in
            if let strongSelf = self{
                strongSelf.context.sharedContext.openChatWallpaper(context: strongSelf.context, message: message, present: { [weak self] c, a in
                    self?.pushController(c)
                })
            }
        }, openTheme: { _ in      
        }, openHashtag: { [weak self] peerName, hashtag in
            guard let strongSelf = self else {
                return
            }
            let resolveSignal: Signal<Peer?, NoError>
            if let peerName = peerName {
                resolveSignal = strongSelf.context.engine.peers.resolvePeerByName(name: peerName, referrer: nil)
                |> mapToSignal { result -> Signal<EnginePeer?, NoError> in
                    guard case let .result(result) = result else {
                        return .complete()
                    }
                    return .single(result)
                }
                |> mapToSignal { peer -> Signal<Peer?, NoError> in
                    return .single(peer?._asPeer())
                }
            } else {
                resolveSignal = context.account.postbox.loadedPeerWithId(strongSelf.peer.id)
                |> map(Optional.init)
            }
            strongSelf.resolvePeerByNameDisposable.set((resolveSignal
            |> deliverOnMainQueue).startStrict(next: { peer in
                if let strongSelf = self, !hashtag.isEmpty {
                    let searchController = HashtagSearchController(context: strongSelf.context, peer: peer.flatMap(EnginePeer.init), query: hashtag)
                    strongSelf.pushController(searchController)
                }
            }))
            }, updateInputState: { _ in }, updateInputMode: { _ in }, openMessageShareMenu: { _ in
        }, presentController: { _, _ in
        }, presentControllerInCurrent: { _, _ in
        }, navigationController: { [weak self] in
            return self?.getNavigationController()
        }, chatControllerNode: { [weak self] in
            return self
        }, presentGlobalOverlayController: { _, _ in }, callPeer: { _, _ in }, openConferenceCall: { _ in
        }, longTap: { [weak self] action, params in
            if let strongSelf = self {
                switch action {
                    case let .url(url):
                        var cleanUrl = url
                        let canOpenIn = availableOpenInOptions(context: strongSelf.context, item: .url(url: url)).count > 1
                        var canAddToReadingList = true
                        let mailtoString = "mailto:"
                        let telString = "tel:"
                        var openText = strongSelf.presentationData.strings.Conversation_LinkDialogOpen
                        
                        var isEmail = false
                        var isPhoneNumber = false
                        if cleanUrl.hasPrefix(mailtoString) {
                            canAddToReadingList = false
                            cleanUrl = String(cleanUrl[cleanUrl.index(cleanUrl.startIndex, offsetBy: mailtoString.distance(from: mailtoString.startIndex, to: mailtoString.endIndex))...])
                            isEmail = true
                        } else if cleanUrl.hasPrefix(telString) {
                            canAddToReadingList = false
                            cleanUrl = String(cleanUrl[cleanUrl.index(cleanUrl.startIndex, offsetBy: telString.distance(from: telString.startIndex, to: telString.endIndex))...])
                            openText = strongSelf.presentationData.strings.Conversation_Call
                            isPhoneNumber = true
                        } else if canOpenIn {
                            openText = strongSelf.presentationData.strings.Conversation_FileOpenIn
                        }
                        let actionSheet = ActionSheetController(presentationData: strongSelf.presentationData)
                        
                        var items: [ActionSheetItem] = []
                        items.append(ActionSheetTextItem(title: cleanUrl))
                        items.append(ActionSheetButtonItem(title: openText, color: .accent, action: { [weak actionSheet] in
                            actionSheet?.dismissAnimated()
                            if let strongSelf = self {
                                strongSelf.openUrl(url)
                            }
                        }))
                        items.append(ActionSheetButtonItem(title: canAddToReadingList ? strongSelf.presentationData.strings.ShareMenu_CopyShareLink : strongSelf.presentationData.strings.Conversation_ContextMenuCopy, color: .accent, action: { [weak actionSheet, weak self] in
                            actionSheet?.dismissAnimated()
                            UIPasteboard.general.string = cleanUrl
                            
                            let content: UndoOverlayContent
                            if isPhoneNumber {
                                content = .copy(text: presentationData.strings.Conversation_PhoneCopied)
                            } else if isEmail {
                                content = .copy(text: presentationData.strings.Conversation_EmailCopied)
                            } else if canAddToReadingList {
                                content = .linkCopied(title: nil, text: presentationData.strings.Conversation_LinkCopied)
                            } else {
                                content = .copy(text: presentationData.strings.Conversation_TextCopied)
                            }
                            self?.presentController(UndoOverlayController(presentationData: presentationData, content: content, elevatedLayout: false, animateInAsReplacement: false, action: { _ in return false }), .current, nil)
                        }))
                        if canAddToReadingList {
                            items.append(ActionSheetButtonItem(title: strongSelf.presentationData.strings.Conversation_AddToReadingList, color: .accent, action: { [weak actionSheet] in
                                actionSheet?.dismissAnimated()
                                if let link = URL(string: url) {
                                    let _ = try? SSReadingList.default()?.addItem(with: link, title: nil, previewText: nil)
                                }
                            }))
                        }
                        actionSheet.setItemGroups([ActionSheetItemGroup(items: items), ActionSheetItemGroup(items: [
                            ActionSheetButtonItem(title: strongSelf.presentationData.strings.Common_Cancel, color: .accent, font: .bold, action: { [weak actionSheet] in
                                actionSheet?.dismissAnimated()
                            })
                        ])])
                        strongSelf.presentController(actionSheet, .window(.root), nil)
                    case let .phone(number):
                        let _ = number
                        break
                    case let .peerMention(peerId, mention):
                        let actionSheet = ActionSheetController(presentationData: strongSelf.presentationData)
                        var items: [ActionSheetItem] = []
                        if !mention.isEmpty {
                            items.append(ActionSheetTextItem(title: mention))
                        }
                        items.append(ActionSheetButtonItem(title: strongSelf.presentationData.strings.Conversation_LinkDialogOpen, color: .accent, action: { [weak actionSheet] in
                            actionSheet?.dismissAnimated()
                            if let strongSelf = self {
                                let _ = (strongSelf.context.engine.data.get(TelegramEngine.EngineData.Item.Peer.Peer(id: peerId))
                                |> deliverOnMainQueue).startStandalone(next: { peer in
                                    if let strongSelf = self, let peer = peer {
                                        strongSelf.openPeer(peer: peer)
                                    }
                                })
                            }
                        }))
                        if !mention.isEmpty {
                            items.append(ActionSheetButtonItem(title: strongSelf.presentationData.strings.Conversation_LinkDialogCopy, color: .accent, action: { [weak actionSheet, weak self] in
                                actionSheet?.dismissAnimated()
                                UIPasteboard.general.string = mention
                                
                                let content: UndoOverlayContent = .copy(text: presentationData.strings.Conversation_UsernameCopied)
                                self?.presentController(UndoOverlayController(presentationData: presentationData, content: content, elevatedLayout: false, animateInAsReplacement: false, action: { _ in return false }), .current, nil)
                            }))
                        }
                        actionSheet.setItemGroups([ActionSheetItemGroup(items: items), ActionSheetItemGroup(items: [
                            ActionSheetButtonItem(title: strongSelf.presentationData.strings.Common_Cancel, color: .accent, font: .bold, action: { [weak actionSheet] in
                                actionSheet?.dismissAnimated()
                            })
                        ])])
                        strongSelf.presentController(actionSheet, .window(.root), nil)
                    case let .mention(mention):
                        let actionSheet = ActionSheetController(presentationData: strongSelf.presentationData)
                        actionSheet.setItemGroups([ActionSheetItemGroup(items: [
                            ActionSheetTextItem(title: mention),
                            ActionSheetButtonItem(title: strongSelf.presentationData.strings.Conversation_LinkDialogOpen, color: .accent, action: { [weak actionSheet] in
                                actionSheet?.dismissAnimated()
                                if let strongSelf = self {
                                    strongSelf.openPeerMention(mention)
                                }
                            }),
                            ActionSheetButtonItem(title: strongSelf.presentationData.strings.Conversation_LinkDialogCopy, color: .accent, action: { [weak actionSheet, weak self] in
                                actionSheet?.dismissAnimated()
                                UIPasteboard.general.string = mention
                                
                                let content: UndoOverlayContent = .copy(text: presentationData.strings.Conversation_TextCopied)
                                self?.presentController(UndoOverlayController(presentationData: presentationData, content: content, elevatedLayout: false, animateInAsReplacement: false, action: { _ in return false }), .current, nil)
                            })
                            ]), ActionSheetItemGroup(items: [
                                ActionSheetButtonItem(title: strongSelf.presentationData.strings.Common_Cancel, color: .accent, font: .bold, action: { [weak actionSheet] in
                                    actionSheet?.dismissAnimated()
                                })
                            ])])
                        strongSelf.presentController(actionSheet, .window(.root), nil)
                    case let .command(command):
                        let actionSheet = ActionSheetController(presentationData: strongSelf.presentationData)
                        actionSheet.setItemGroups([ActionSheetItemGroup(items: [
                            ActionSheetTextItem(title: command),
                            ActionSheetButtonItem(title: strongSelf.presentationData.strings.Conversation_LinkDialogCopy, color: .accent, action: { [weak actionSheet, weak self] in
                                actionSheet?.dismissAnimated()
                                UIPasteboard.general.string = command
                                
                                let content: UndoOverlayContent = .copy(text: presentationData.strings.Conversation_TextCopied)
                                self?.presentController(UndoOverlayController(presentationData: presentationData, content: content, elevatedLayout: false, animateInAsReplacement: false, action: { _ in return false }), .current, nil)
                            })
                            ]), ActionSheetItemGroup(items: [
                                ActionSheetButtonItem(title: strongSelf.presentationData.strings.Common_Cancel, color: .accent, font: .bold, action: { [weak actionSheet] in
                                    actionSheet?.dismissAnimated()
                                })
                            ])])
                        strongSelf.presentController(actionSheet, .window(.root), nil)
                    case let .hashtag(hashtag):
                        let actionSheet = ActionSheetController(presentationData:  strongSelf.presentationData)
                        actionSheet.setItemGroups([ActionSheetItemGroup(items: [
                            ActionSheetTextItem(title: hashtag),
                            ActionSheetButtonItem(title: strongSelf.presentationData.strings.Conversation_LinkDialogOpen, color: .accent, action: { [weak actionSheet] in
                                actionSheet?.dismissAnimated()
                                if let strongSelf = self {
                                    let searchController = HashtagSearchController(context: strongSelf.context, peer: EnginePeer(strongSelf.peer), query: hashtag)
                                    strongSelf.pushController(searchController)
                                }
                            }),
                            ActionSheetButtonItem(title: strongSelf.presentationData.strings.Conversation_LinkDialogCopy, color: .accent, action: { [weak actionSheet, weak self] in
                                actionSheet?.dismissAnimated()
                                UIPasteboard.general.string = hashtag
                                
                                let content: UndoOverlayContent = .copy(text: presentationData.strings.Conversation_HashtagCopied)
                                self?.presentController(UndoOverlayController(presentationData: presentationData, content: content, elevatedLayout: false, animateInAsReplacement: false, action: { _ in return false }), .current, nil)
                            })
                            ]), ActionSheetItemGroup(items: [
                                ActionSheetButtonItem(title: strongSelf.presentationData.strings.Common_Cancel, color: .accent, font: .bold, action: { [weak actionSheet] in
                                    actionSheet?.dismissAnimated()
                                })
                            ])])
                        strongSelf.presentController(actionSheet, .window(.root), nil)
                    case let .timecode(timecode, text):
                        guard let message = params?.message else {
                            return
                        }
                        let actionSheet = ActionSheetController(presentationData: strongSelf.presentationData)
                        actionSheet.setItemGroups([ActionSheetItemGroup(items: [
                            ActionSheetTextItem(title: text),
                            ActionSheetButtonItem(title: strongSelf.presentationData.strings.Conversation_LinkDialogOpen, color: .accent, action: { [weak actionSheet] in
                                actionSheet?.dismissAnimated()
                                if let strongSelf = self {
                                    strongSelf.controllerInteraction?.seekToTimecode(message, timecode, true)
                                }
                            }),
                            ActionSheetButtonItem(title: strongSelf.presentationData.strings.Conversation_LinkDialogCopy, color: .accent, action: { [weak actionSheet, weak self] in
                                actionSheet?.dismissAnimated()
                                UIPasteboard.general.string = text
                                
                                let content: UndoOverlayContent = .copy(text: presentationData.strings.Conversation_TextCopied)
                                self?.presentController(UndoOverlayController(presentationData: presentationData, content: content, elevatedLayout: false, animateInAsReplacement: false, action: { _ in return false }), .current, nil)
                            })
                            ]), ActionSheetItemGroup(items: [
                                ActionSheetButtonItem(title: strongSelf.presentationData.strings.Common_Cancel, color: .accent, font: .bold, action: { [weak actionSheet] in
                                    actionSheet?.dismissAnimated()
                                })
                            ])])
                        strongSelf.presentController(actionSheet, .window(.root), nil)
                    case .bankCard:
                        break
                }
            }
        }, todoItemLongTap: { _, _ in
        }, openCheckoutOrReceipt: { _, _ in
        }, openSearch: {
        }, setupReply: { _ in
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
        }, openAppStorePage: { [weak self] in
            if let strongSelf = self {
                strongSelf.context.sharedContext.applicationBindings.openAppStorePage()
            }
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
        }, automaticMediaDownloadSettings: self.automaticMediaDownloadSettings,
        pollActionState: ChatInterfacePollActionState(), stickerSettings: ChatInterfaceStickerSettings(), presentationContext: ChatPresentationContext(context: context, backgroundNode: self.backgroundNode))
        self.controllerInteraction = controllerInteraction
        
        self.listNode.displayedItemRangeChanged = { [weak self] displayedRange, opaqueTransactionState in
            if let strongSelf = self {
                if let state = (opaqueTransactionState as? ChatRecentActionsListOpaqueState), state.canLoadEarlier {
                    if let visible = displayedRange.visibleRange {
                        let indexRange = (state.entries.count - 1 - visible.lastIndex, state.entries.count - 1 - visible.firstIndex)
                        if indexRange.0 < 5 {
                            strongSelf.eventLogContext.loadMoreEntries()
                        }
                    }
                }
            }
        }
        
        self.eventLogContext.loadMoreEntries()
        
        let historyViewUpdate = self.eventLogContext.get()
        |> map { (entries, hasEarlier, type, hasEntries) in
            return (entries.filter { entry in
                if case let .participantToggleAdmin(prev, new) = entry.event.action, case .creator = prev.participant, case .member = new.participant {
                    return false
                }
                return true
            }, hasEarlier, type, hasEntries)
        }
        
        let previousView = Atomic<[ChatRecentActionsEntry]?>(value: nil)
        let previousExpandedDeletedMessages = Atomic<Set<EngineMessage.Id>>(value: Set())
        let previousDeletedHeaderMessages = Atomic<Set<EngineMessage.Id>>(value: Set())
        
        let chatThemes = self.context.engine.themes.getChatThemes(accountManager: self.context.sharedContext.accountManager)
        let availableReactions: Signal<AvailableReactions?, NoError> = self.context.availableReactions
        
        let historyViewTransition = combineLatest(
            historyViewUpdate,
            self.chatPresentationDataPromise.get(),
            chatThemes,
            availableReactions,
            self.expandedDeletedMessagesPromise.get()
        )
        |> mapToQueue { [weak self] update, chatPresentationData, chatThemes, availableReactions, expandedDeletedMessages -> Signal<ChatRecentActionsHistoryTransition, NoError> in
            
            var deletedHeaderMessages = previousDeletedHeaderMessages.with { $0 }
            let processedView = chatRecentActionsEntries(entries: update.0, presentationData: chatPresentationData, expandedDeletedMessages: expandedDeletedMessages, currentDeletedHeaderMessages: &deletedHeaderMessages)
            let _ = previousDeletedHeaderMessages.swap(deletedHeaderMessages)
            
            let previous = previousView.swap(processedView)
            let previousExpandedDeletedMessages = previousExpandedDeletedMessages.swap(expandedDeletedMessages)
            
            var updateType = update.2
            if previousExpandedDeletedMessages.count != expandedDeletedMessages.count {
                updateType = .generic
            }
            
            let toggledDeletedMessageIds = previousExpandedDeletedMessages.symmetricDifference(expandedDeletedMessages)
            
            var searchResultsState: (String, [MessageIndex])?
            if update.3, let query = self?.filter.query {
                searchResultsState = (query, processedView.compactMap { entry in
                    return entry.entry.event.action.messageId.flatMap { MessageIndex(id: $0, timestamp: entry.entry.event.date) }
                })
            } else {
                searchResultsState = nil
            }
            
            return .single(chatRecentActionsHistoryPreparedTransition(from: previous ?? [], to: processedView, type: updateType, canLoadEarlier: update.1, displayingResults: update.3, context: context, peer: peer, controllerInteraction: controllerInteraction, chatThemes: chatThemes, availableReactions: availableReactions, searchResultsState: searchResultsState, toggledDeletedMessageIds: toggledDeletedMessageIds))
        }
        
        let appliedTransition = historyViewTransition |> deliverOnMainQueue |> mapToQueue { [weak self] transition -> Signal<Void, NoError> in
            if let strongSelf = self {
                strongSelf.enqueueTransition(transition: transition, firstTime: false)
            }
            return .complete()
        }
        
        self.historyDisposable = appliedTransition.startStrict()
        
        let mediaManager = self.context.sharedContext.mediaManager
        self.galleryHiddenMesageAndMediaDisposable.set(mediaManager.galleryHiddenMediaManager.hiddenIds().startStrict(next: { [weak self] ids in
            if let strongSelf = self, let controllerInteraction = strongSelf.controllerInteraction {
                var messageIdAndMedia: [MessageId: [Media]] = [:]
                
                for id in ids {
                    if case let .chat(accountId, messageId, media) = id, accountId == strongSelf.context.account.id {
                        messageIdAndMedia[messageId] = [media]
                    }
                }
                
                controllerInteraction.hiddenMedia = messageIdAndMedia
                
                strongSelf.listNode.forEachItemNode { itemNode in
                    if let itemNode = itemNode as? ChatMessageItemView {
                        itemNode.updateHiddenMedia()
                    }
                }
            }
        }))
    }
    
    deinit {
        self.historyDisposable?.dispose()
        self.navigationActionDisposable.dispose()
        self.galleryHiddenMesageAndMediaDisposable.dispose()
        self.temporaryHiddenGalleryMediaDisposable.dispose()
        self.resolvePeerByNameDisposable.dispose()
        self.adminsDisposable?.dispose()
        self.banDisposables.dispose()
        self.reportFalsePositiveDisposables.dispose()
    }
    
    func updatePresentationData(_ presentationData: PresentationData) {
        self.presentationData = presentationData
        
        self.chatPresentationData = ChatPresentationData(theme: ChatPresentationThemeData(theme: presentationData.theme, wallpaper: presentationData.chatWallpaper), fontSize: presentationData.chatFontSize, strings: presentationData.strings, dateTimeFormat: presentationData.dateTimeFormat, nameDisplayOrder: presentationData.nameDisplayOrder, disableAnimations: true, largeEmoji: presentationData.largeEmoji, chatBubbleCorners: presentationData.chatBubbleCorners)
        self.chatPresentationDataPromise.set(.single(self.chatPresentationData))
        
        self.backgroundNode.update(wallpaper: presentationData.chatWallpaper, animated: false)
        self.backgroundNode.updateBubbleTheme(bubbleTheme: presentationData.theme, bubbleCorners: presentationData.chatBubbleCorners)
        
        self.panelBackgroundNode.updateColor(color: presentationData.theme.chat.inputPanel.panelBackgroundColor, transition: .immediate)
        self.panelSeparatorNode.backgroundColor = presentationData.theme.chat.inputPanel.panelSeparatorColor
        self.panelButtonNode.setTitle(presentationData.strings.Channel_AdminLog_Settings, with: Font.regular(17.0), with: presentationData.theme.chat.inputPanel.panelControlAccentColor, for: [])
        self.panelInfoButtonNode.setImage(generateTintedImage(image: UIImage(bundleImageName: "Chat/Recent Actions/Info"), color: presentationData.theme.chat.inputPanel.panelControlAccentColor), for: .normal)
    }
    
    func containerLayoutUpdated(_ layout: ContainerViewLayout, navigationBarHeight: CGFloat, transition: ContainedViewLayoutTransition) {
        let isFirstLayout = self.containerLayout == nil
        
        self.containerLayout = (layout, navigationBarHeight)
        
        var insets = layout.insets(options: [.input])
        insets.top += navigationBarHeight
        
        let cleanInsets = layout.insets(options: [])
        
        transition.updateFrame(node: self.backgroundNode, frame: CGRect(origin: CGPoint(), size: layout.size))
        self.backgroundNode.updateLayout(size: self.backgroundNode.bounds.size, displayMode: .aspectFill, transition: transition)
        
        let intrinsicPanelHeight: CGFloat = 47.0
        var panelHeight = intrinsicPanelHeight + cleanInsets.bottom
        var panelOffset: CGFloat = panelHeight
        if insets.bottom > cleanInsets.bottom {
            panelHeight = intrinsicPanelHeight
            panelOffset = insets.bottom + panelHeight
        }
        transition.updateFrame(node: self.panelBackgroundNode, frame: CGRect(origin: CGPoint(x: 0.0, y: layout.size.height - panelOffset), size: CGSize(width: layout.size.width, height: panelHeight)))
        self.panelBackgroundNode.update(size: self.panelBackgroundNode.bounds.size, transition: transition)
        transition.updateFrame(node: self.panelSeparatorNode, frame: CGRect(origin: CGPoint(x: 0.0, y: layout.size.height - panelOffset), size: CGSize(width: layout.size.width, height: UIScreenPixel)))
        
        let infoButtonSize = CGSize(width: 56.0, height: intrinsicPanelHeight)
        transition.updateFrame(node: self.panelButtonNode, frame: CGRect(origin: CGPoint(x: insets.left + infoButtonSize.width, y: layout.size.height - panelOffset), size: CGSize(width: layout.size.width - insets.left - insets.right - infoButtonSize.width * 2.0, height: intrinsicPanelHeight)))
        
        transition.updateFrame(node: self.panelInfoButtonNode, frame: CGRect(origin: CGPoint(x: layout.size.width - insets.right - infoButtonSize.width, y: layout.size.height - panelOffset), size: infoButtonSize))
        
        self.visibleAreaInset = UIEdgeInsets(top: 0.0, left: 0.0, bottom: panelHeight, right: 0.0)
        
        transition.updateBounds(node: self.listNode, bounds: CGRect(origin: CGPoint(), size: layout.size))
        transition.updatePosition(node: self.listNode, position: CGRect(origin: CGPoint(), size: layout.size).center)
        
        transition.updateFrame(node: self.loadingNode, frame: CGRect(origin: CGPoint(), size: layout.size))
        self.loadingNode.updateLayout(size: layout.size, insets: insets, transition: transition)
        
        let emptyFrame = CGRect(origin: CGPoint(x: 0.0, y: navigationBarHeight), size: CGSize(width: layout.size.width, height: layout.size.height - navigationBarHeight - panelHeight))
        transition.updateFrame(node: self.emptyNode, frame: emptyFrame)
        self.emptyNode.update(rect: emptyFrame, within: layout.size)
        self.emptyNode.updateLayout(presentationData: self.chatPresentationData, backgroundNode: self.backgroundNode, size: emptyFrame.size, transition: transition)
        
        let contentBottomInset: CGFloat = panelOffset + 4.0
        let listInsets = UIEdgeInsets(top: contentBottomInset, left: layout.safeInsets.right, bottom: insets.top, right: layout.safeInsets.left)
        
        let (duration, curve) = listViewAnimationDurationAndCurve(transition: transition)
        let updateSizeAndInsets = ListViewUpdateSizeAndInsets(size: layout.size, insets: listInsets, duration: duration, curve: curve)
        
        self.listNode.transaction(deleteIndices: [], insertIndicesAndItems: [], updateIndicesAndItems: [], options: [.Synchronous, .LowLatency], scrollToItem: nil, additionalScrollDistance: 0.0, updateSizeAndInsets: updateSizeAndInsets, stationaryItemRange: nil, updateOpaqueState: nil, completion: { _ in })
        
        if isFirstLayout {
            self.dequeueTransitions()
        }
    }
    
    private func enqueueTransition(transition: ChatRecentActionsHistoryTransition, firstTime: Bool) {
        self.enqueuedTransitions.append((transition, firstTime))
        if self.containerLayout != nil {
            self.dequeueTransitions()
        }
    }
    
    private func dequeueTransitions() {
        while true {
            if let (transition, firstTime) = self.enqueuedTransitions.first {
                self.enqueuedTransitions.remove(at: 0)
                
                var options = ListViewDeleteAndInsertOptions()
                if firstTime {
                    options.insert(.LowLatency)
                } else {
                    switch transition.type {
                        case .initial:
                            options.insert(.LowLatency)
                        case .generic:
                            options.insert(.AnimateInsertion)
                        case .load:
                            break
                    }
                }
                if transition.synchronous {
                    options.insert(.InvertOffsetDirection)
                }
                
                let displayingResults = transition.displayingResults
                let isEmpty = transition.isEmpty
                let displayEmptyNode = isEmpty && displayingResults
                
                self.searchResultsState = transition.searchResultsState
            
                self.listNode.transaction(deleteIndices: transition.deletions, insertIndicesAndItems: transition.insertions, updateIndicesAndItems: transition.updates, options: options, updateSizeAndInsets: nil, updateOpaqueState: ChatRecentActionsListOpaqueState(entries: transition.filteredEntries, canLoadEarlier: transition.canLoadEarlier), completion: { [weak self] _ in
                    if let strongSelf = self {
                        if displayEmptyNode != strongSelf.listNode.isHidden {
                            strongSelf.listNode.isHidden = displayEmptyNode
                            strongSelf.backgroundColor = !displayEmptyNode ? strongSelf.presentationData.theme.list.plainBackgroundColor : nil
                            
                            strongSelf.emptyNode.alpha = displayEmptyNode ? 1.0 : 0.0
                            strongSelf.emptyNode.layer.animateAlpha(from: displayEmptyNode ? 0.0 : 1.0, to: displayEmptyNode ? 1.0 : 0.0, duration: 0.25)
                            
                            let hasFilter: Bool = strongSelf.filter.events != .all || strongSelf.filter.query != nil
                            
                            var isSupergroup: Bool = false
                            if let peer = strongSelf.peer as? TelegramChannel {
                                switch peer.info {
                                case .group:
                                    isSupergroup = true
                                default:
                                    break
                                }
                            }
                            
                            if displayEmptyNode {
                                var text: String = ""
                                if let query = strongSelf.filter.query, hasFilter {
                                    text = strongSelf.presentationData.strings.Channel_AdminLog_EmptyFilterQueryText(query).string
                                } else {
                                    text = isSupergroup ? strongSelf.presentationData.strings.Group_AdminLog_EmptyText : strongSelf.presentationData.strings.Broadcast_AdminLog_EmptyText
                                }
                                strongSelf.emptyNode.setup(title: hasFilter ? strongSelf.presentationData.strings.Channel_AdminLog_EmptyFilterTitle : strongSelf.presentationData.strings.Channel_AdminLog_EmptyTitle, text: text)
                            }
                        }
                        let isLoading = !displayingResults
                        if !isLoading && strongSelf.isLoading {
                            strongSelf.listNode.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.25)
                        }
                        strongSelf.isLoading = isLoading
                        
                        var isEmpty = false
                        if strongSelf.filter.isEmpty && (transition.isEmpty || isLoading) {
                            isEmpty = true
                        }
                        strongSelf.isEmptyUpdated(isEmpty)
                        
                        strongSelf.updateItemNodesSearchTextHighlightStates()
                    }
                })
            } else {
                break
            }
        }
    }
    
    @objc func settingsButtonPressed() {
        self.controller?.openFilterSetup()
    }
    
    @objc func infoButtonPressed() {
        guard let controller = self.controller else {
            return
        }
        let text: String
        if let channel = self.peer as? TelegramChannel, case .broadcast = channel.info {
            text = self.presentationData.strings.Channel_AdminLog_InfoPanelChannelAlertText
        } else {
            text = self.presentationData.strings.Channel_AdminLog_InfoPanelAlertText
        }
        controller.present(textAlertController(context: self.context, updatedPresentationData: controller.updatedPresentationData, title: self.presentationData.strings.Channel_AdminLog_InfoPanelAlertTitle, text: text, actions: [TextAlertAction(type: .defaultAction, title: self.presentationData.strings.Common_OK, action: {})]), in: .window(.root))
        
    }
    
    func updateSearchQuery(_ query: String) {
        self.filter = self.filter.withQuery(query.isEmpty ? nil : query)
        self.eventLogContext.setFilter(self.filter)
        
        self.updateItemNodesSearchTextHighlightStates()
    }
    
    func updateItemNodesSearchTextHighlightStates() {
        var searchString: String?
        var resultsMessageIndices: [MessageIndex]? = nil
        if let (query, indices) = self.searchResultsState {
            searchString = query
            resultsMessageIndices = indices
        }
        if searchString != self.controllerInteraction?.searchTextHighightState?.0 || resultsMessageIndices != self.controllerInteraction?.searchTextHighightState?.1 {
            var searchTextHighightState: (String, [MessageIndex])?
            if let searchString = searchString, let resultsMessageIndices = resultsMessageIndices {
                searchTextHighightState = (searchString, resultsMessageIndices)
            }
            self.controllerInteraction?.searchTextHighightState = searchTextHighightState
            self.listNode.forEachItemNode { itemNode in
                if let itemNode = itemNode as? ChatMessageItemView {
                    itemNode.updateSearchTextHighlightState()
                }
            }
        }
    }
    
    func updateFilter(events: AdminLogEventsFlags, adminPeerIds: [PeerId]?) {
        self.filter = self.filter.withEvents(events).withAdminPeerIds(adminPeerIds)
        self.eventLogContext.setFilter(self.filter)
    }
    
    private func openPeer(peer: EnginePeer, peekData: ChatPeekTimeout? = nil) {
        let antiSpamBotConfiguration = AntiSpamBotConfiguration.with(appConfiguration: context.currentAppConfiguration.with { $0 })
        if peer.id == antiSpamBotConfiguration.antiSpamBotId {
            self.dismissAllTooltips()
            
            self.presentController(UndoOverlayController(presentationData: self.presentationData, content: .universal(animation: "anim_antispam", scale: 0.066, colors: [:], title: self.presentationData.strings.Group_AdminLog_AntiSpamTitle, text: self.presentationData.strings.Group_AdminLog_AntiSpamText, customUndoText: nil, timeout: nil), elevatedLayout: true, action: { [weak self] action in
                if let strongSelf = self {
                    if case .info = action {
                        let _ = strongSelf.getNavigationController()?.popViewController(animated: true)
                        return true
                    }
                }
                return false
            }), .window(.root), nil)
        } else {
            let peerSignal: Signal<Peer?, NoError> = .single(peer._asPeer())
            self.navigationActionDisposable.set((peerSignal |> take(1) |> deliverOnMainQueue).startStrict(next: { [weak self] peer in
                if let strongSelf = self, let peer = peer {
                    if peer is TelegramChannel, let navigationController = strongSelf.getNavigationController() {
                        strongSelf.context.sharedContext.navigateToChatController(NavigateToChatControllerParams(navigationController: navigationController, context: strongSelf.context, chatLocation: .peer(EnginePeer(peer)), peekData: peekData, animated: true))
                    } else {
                        if let infoController = strongSelf.context.sharedContext.makePeerInfoController(context: strongSelf.context, updatedPresentationData: nil, peer: peer, mode: .generic, avatarInitiallyExpanded: false, fromChat: false, requestsContext: nil) {
                            strongSelf.pushController(infoController)
                        }
                    }
                }
            }))
        }
    }
    
    private func openPeerMention(_ name: String) {
        self.navigationActionDisposable.set((self.context.engine.peers.resolvePeerByName(name: name, referrer: nil, ageLimit: 10)
        |> mapToSignal { result -> Signal<EnginePeer?, NoError> in
            guard case let .result(result) = result else {
                return .complete()
            }
            return .single(result)
        }
        |> deliverOnMainQueue).startStrict(next: { [weak self] peer in
            if let strongSelf = self {
                if let peer = peer {
                    if let infoController = strongSelf.context.sharedContext.makePeerInfoController(context: strongSelf.context, updatedPresentationData: nil, peer: peer._asPeer(), mode: .generic, avatarInitiallyExpanded: false, fromChat: false, requestsContext: nil) {
                        strongSelf.pushController(infoController)
                    }
                }
            }
        }))
    }
    
    private func openMessageContextMenu(message: Message, selectAll: Bool, node: ASDisplayNode, frame: CGRect, recognizer: TapLongTapOrDoubleTapGestureRecognizer? = nil, gesture: ContextGesture? = nil, location: CGPoint? = nil) {
        guard let controller = self.controller else {
            return
        }
        self.dismissAllTooltips()
        
        let context = self.context
        let source: ContextContentSource
        if let location = location {
            source = .location(ChatMessageContextLocationContentSource(controller: controller, location: node.view.convert(node.bounds, to: nil).origin.offsetBy(dx: location.x, dy: location.y)))
        } else {
            source = .extracted(ChatRecentActionsMessageContextExtractedContentSource(controllerNode: self, message: message, selectAll: selectAll))
        }
        
        var actions: [ContextMenuItem] = []
        if !message.text.isEmpty {
            actions.append(
                .action(ContextMenuActionItem(text: self.presentationData.strings.Conversation_ContextMenuCopy, icon: { theme in return generateTintedImage(image: UIImage(bundleImageName: "Chat/Context Menu/Copy"), color: theme.contextMenu.primaryColor) }, action: { [weak self] _, f in
                    f(.default)
                    
                    if let strongSelf = self {
                        var messageEntities: [MessageTextEntity]?
                        var restrictedText: String?
                        for attribute in message.attributes {
                            if let attribute = attribute as? TextEntitiesMessageAttribute {
                                messageEntities = attribute.entities
                            }
                            if let attribute = attribute as? RestrictedContentMessageAttribute {
                                restrictedText = attribute.platformText(platform: "ios", contentSettings: context.currentContentSettings.with { $0 }) ?? ""
                            }
                        }
                        
                        if let restrictedText = restrictedText {
                            storeMessageTextInPasteboard(restrictedText, entities: nil)
                        } else {
                            storeMessageTextInPasteboard(message.text, entities: messageEntities)
                        }
                        
                        Queue.mainQueue().after(0.2, {
                            let content: UndoOverlayContent = .copy(text: strongSelf.presentationData.strings.Conversation_TextCopied)
                            strongSelf.presentController(UndoOverlayController(presentationData: strongSelf.presentationData, content: content, elevatedLayout: false, animateInAsReplacement: false, action: { _ in return false }), .current, nil)
                        })
                    }
                }))
            )
        }
        
        if let author = message.author, let adminsState = self.adminsState {
            var canBan = author.id != self.context.account.peerId
            if let channel = self.peer as? TelegramChannel {
                if !channel.hasPermission(.banMembers) {
                    canBan = false
                }
                if case .broadcast = channel.info {
                    canBan = false
                }
            }
            for member in adminsState.list {
                if member.peer.id == author.id {
                    canBan = member.participant.canBeBannedBy(peerId: self.context.account.peerId)
                }
            }
            
            if canBan {
                actions.append(
                    .action(ContextMenuActionItem(text: self.presentationData.strings.Conversation_ContextMenuBan, icon: { theme in return generateTintedImage(image: UIImage(bundleImageName: "Chat/Context Menu/Restrict"), color: theme.contextMenu.primaryColor) }, action: { [weak self] _, f in
                        if let strongSelf = self {
                            f(.default)
                            strongSelf.banDisposables.set((strongSelf.context.engine.peers.fetchChannelParticipant(peerId: strongSelf.peer.id, participantId: author.id)
                            |> deliverOnMainQueue).startStrict(next: { participant in
                                if let strongSelf = self {
                                    strongSelf.presentController(channelBannedMemberController(context: strongSelf.context, peerId: strongSelf.peer.id, memberId: author.id, initialParticipant: participant, updated: { _ in }, upgradedToSupergroup: { _, f in f() }), .window(.root), ViewControllerPresentationArguments(presentationAnimation: .modalSheet))
                                }
                            }), forKey: author.id)
                        }
                    }))
                )
                actions.append(
                    .action(ContextMenuActionItem(text: self.presentationData.strings.Conversation_ContextMenuBanFull, textColor: .destructive, icon: { theme in return generateTintedImage(image: UIImage(bundleImageName: "Chat/Context Menu/Ban"), color: theme.contextMenu.destructiveColor) }, action: { [weak self] _, f in
                        if let strongSelf = self {
                            f(.default)
                            strongSelf.banDisposables.set((strongSelf.context.engine.peers.fetchChannelParticipant(peerId: strongSelf.peer.id, participantId: author.id)
                            |> deliverOnMainQueue).startStrict(next: { participant in
                                if let strongSelf = self {
                                    let initialUserBannedRights = participant?.banInfo?.rights
                                    strongSelf.banDisposables.set(strongSelf.context.engine.peers.removePeerMember(peerId: strongSelf.peer.id, memberId: author.id).startStandalone(), forKey: author.id)
                                    
                                    strongSelf.presentController(UndoOverlayController(
                                        presentationData: strongSelf.presentationData,
                                        content: .actionSucceeded(title: nil, text: "**\(EnginePeer(author).compactDisplayTitle)** was banned.", cancel: strongSelf.presentationData.strings.Undo_Undo, destructive: false),
                                        elevatedLayout: false,
                                        action: { [weak self] action in
                                            guard let self else {
                                                return true
                                            }
                                            switch action {
                                            case .commit:
                                                break
                                            case .undo:
                                                let _ = self.context.engine.peers.updateChannelMemberBannedRights(peerId: self.peer.id, memberId: author.id, rights: initialUserBannedRights).startStandalone()
                                            default:
                                                break
                                            }
                                            return true
                                        }
                                    ), .current, nil)
                                }
                            }), forKey: author.id)
                        }
                    }))
                )
            }
        }
        
        let configuration = AntiSpamBotConfiguration.with(appConfiguration: context.currentAppConfiguration.with { $0 })
        for peer in message.peers {
            if peer.0 == configuration.antiSpamBotId {
                if !actions.isEmpty {
                    actions.insert(.separator, at: 0)
                }
                actions.insert(
                    .action(ContextMenuActionItem(text: self.presentationData.strings.Conversation_ContextMenuReportFalsePositive, icon: { theme in return generateTintedImage(image: UIImage(bundleImageName: "Chat/Context Menu/AntiSpam"), color: theme.contextMenu.primaryColor) }, action: { [weak self] _, f in
                        f(.default)
                        
                        if let strongSelf = self {
                            strongSelf.reportFalsePositiveDisposables.set((strongSelf.context.engine.peers.reportAntiSpamFalsePositive(peerId: message.id.peerId, messageId: message.id)
                            |> deliverOnMainQueue).startStrict(), forKey: message.id)
                            
                            Queue.mainQueue().after(0.2, {
                                strongSelf.presentController(UndoOverlayController(presentationData: strongSelf.presentationData, content: .universal(animation: "anim_antispam", scale: 0.066, colors: [:], title: nil, text: strongSelf.presentationData.strings.Group_AdminLog_AntiSpamFalsePositiveReportedText, customUndoText: nil, timeout: nil), elevatedLayout: false, animateInAsReplacement: false, action: { _ in return false }), .current, nil)
                            })
                        }
                    })), at: 0
                )
                
                break
            }
        }
        
        guard !actions.isEmpty else {
            return
        }
        
        let contextController = ContextController(presentationData: self.presentationData, source: source, items: .single(ContextController.Items(content: .list(actions))), recognizer: recognizer, gesture: gesture)
        controller.window?.presentInGlobalOverlay(contextController)
    }
    
    private func updateItemNodesHighlightedStates(animated: Bool) {
        self.listNode.forEachItemNode { itemNode in
            if let itemNode = itemNode as? ChatMessageItemView {
                itemNode.updateHighlightedState(animated: animated)
            }
        }
    }
    
    private func openUrl(_ url: String, progress: Promise<Bool>? = nil) {
        self.navigationActionDisposable.set((self.context.sharedContext.resolveUrl(context: self.context, peerId: nil, url: url, skipUrlAuth: true) |> deliverOnMainQueue).startStrict(next: { [weak self] result in
            if let strongSelf = self {
                switch result {
                    case let .externalUrl(url):
                        if let navigationController = strongSelf.getNavigationController() {
                            strongSelf.context.sharedContext.openExternalUrl(context: strongSelf.context, urlContext: .generic, url: url, forceExternal: false, presentationData: strongSelf.presentationData, navigationController: navigationController, dismissInput: {
                                self?.view.endEditing(true)
                            })
                        }
                    case .urlAuth:
                        break
                    case let .peer(peer, _):
                        if let peer = peer {
                            strongSelf.openPeer(peer: EnginePeer(peer))
                        }
                    case .inaccessiblePeer:
                        strongSelf.controllerInteraction.presentController(textAlertController(context: strongSelf.context, updatedPresentationData: strongSelf.controller?.updatedPresentationData, title: nil, text: strongSelf.presentationData.strings.Conversation_ErrorInaccessibleMessage, actions: [TextAlertAction(type: .defaultAction, title: strongSelf.presentationData.strings.Common_OK, action: {})]), nil)
                    case .botStart:
                        break
                    case .groupBotStart:
                        break
                    case .gameStart:
                        break
                    case .story:
                        break
                    case let .channelMessage(peer, messageId, timecode):
                        if let navigationController = strongSelf.getNavigationController() {
                            strongSelf.context.sharedContext.navigateToChatController(NavigateToChatControllerParams(navigationController: navigationController, context: strongSelf.context, chatLocation: .peer(EnginePeer(peer)), subject: .message(id: .id(messageId), highlight: ChatControllerSubject.MessageHighlight(quote: nil), timecode: timecode, setupReply: false)))
                        }
                   case let .replyThreadMessage(replyThreadMessage, messageId):
                        if let navigationController = strongSelf.getNavigationController() {
                            strongSelf.context.sharedContext.navigateToChatController(NavigateToChatControllerParams(navigationController: navigationController, context: strongSelf.context, chatLocation: .replyThread(replyThreadMessage), subject: .message(id: .id(messageId), highlight: ChatControllerSubject.MessageHighlight(quote: nil), timecode: nil, setupReply: false)))
                        }
                    case let .replyThread(messageId):
                        if let navigationController = strongSelf.getNavigationController() {
                            let _ = strongSelf.context.sharedContext.navigateToForumThread(context: strongSelf.context, peerId: messageId.peerId, threadId: Int64(messageId.id), messageId: nil, navigationController: navigationController, activateInput: nil, scrollToEndIfExists: false, keepStack: .always, animated: true).startStandalone()
                        }
                    case let .stickerPack(name, type):
                        let _ = type
                        let packReference: StickerPackReference = .name(name)
                        strongSelf.presentController(StickerPackScreen(context: strongSelf.context, mainStickerPack: packReference, stickerPacks: [packReference], parentNavigationController: strongSelf.getNavigationController()), .window(.root), nil)
                    case let .invoice(slug, invoice):
                        if let invoice {
                            let inputData = Promise<BotCheckoutController.InputData?>()
                            inputData.set(BotCheckoutController.InputData.fetch(context: strongSelf.context, source: .slug(slug))
                            |> map(Optional.init)
                            |> `catch` { _ -> Signal<BotCheckoutController.InputData?, NoError> in
                                return .single(nil)
                            })
                            strongSelf.controllerInteraction.presentController(BotCheckoutController(context: strongSelf.context, invoice: invoice, source: .slug(slug), inputData: inputData, completed: { currencyValue, receiptMessageId in
                                guard let strongSelf = self else {
                                    return
                                }
                                let _ = strongSelf
                                /*strongSelf.present(UndoOverlayController(presentationData: strongSelf.presentationData, content: .paymentSent(currencyValue: currencyValue, itemTitle: invoice.title), elevatedLayout: false, action: { action in
                                 guard let strongSelf = self, let receiptMessageId = receiptMessageId else {
                                 return false
                                 }
                                 
                                 if case .info = action {
                                 strongSelf.present(BotReceiptController(context: strongSelf.context, messageId: receiptMessageId), in: .window(.root), with: ViewControllerPresentationArguments(presentationAnimation: .modalSheet))
                                 return true
                                 }
                                 return false
                                 }), in: .current)*/
                            }), ViewControllerPresentationArguments(presentationAnimation: .modalSheet))
                        } else {
                            strongSelf.controllerInteraction.presentController(textAlertController(context: strongSelf.context, updatedPresentationData: strongSelf.controller?.updatedPresentationData, title: nil, text: strongSelf.presentationData.strings.Chat_ErrorInvoiceNotFound, actions: [TextAlertAction(type: .defaultAction, title: strongSelf.presentationData.strings.Common_OK, action: {})]), nil)
                        }
                    case .chatFolder:
                        break
                    case let .instantView(webPage, anchor):
                        let browserController = strongSelf.context.sharedContext.makeInstantPageController(context: strongSelf.context, webPage: webPage, anchor: anchor, sourceLocation: InstantPageSourceLocation(userLocation: .peer(strongSelf.peer.id), peerType: .channel))
                        strongSelf.pushController(browserController)
                    case let .join(link):
                        let context = strongSelf.context
                        let navigationController = strongSelf.getNavigationController()
                        let openPeer: (EnginePeer, ChatPeekTimeout?) -> Void = { [weak self] peer, peekData in
                            self?.openPeer(peer: peer, peekData: peekData)
                        }
                    
                        if let progress {
                            let progressSignal = Signal<Never, NoError> { subscriber in
                                progress.set(.single(true))
                                return ActionDisposable {
                                    Queue.mainQueue().async() {
                                        progress.set(.single(false))
                                    }
                                }
                            }
                            |> runOn(Queue.mainQueue())
                            |> delay(0.1, queue: Queue.mainQueue())
                            let progressDisposable = progressSignal.startStrict()
                            
                            var signal = context.engine.peers.joinLinkInformation(link)
                            signal = signal
                            |> afterDisposed {
                                Queue.mainQueue().async {
                                    progressDisposable.dispose()
                                }
                            }
                                                        
                            let _ = (signal
                            |> deliverOnMainQueue).startStandalone(next: { [weak navigationController] resolvedState in
                                switch resolvedState {
                                case let .alreadyJoined(peer):
                                    openPeer(peer, nil)
                                case let .peek(peer, deadline):
                                    openPeer(peer, ChatPeekTimeout(deadline: deadline, linkData: link))
                                case let .invite(invite):
                                    if let subscriptionPricing = invite.subscriptionPricing, let subscriptionFormId = invite.subscriptionFormId, let starsContext = context.starsContext {
                                        let inputData = Promise<BotCheckoutController.InputData?>()
                                        var photo: [TelegramMediaImageRepresentation] = []
                                        if let photoRepresentation = invite.photoRepresentation {
                                            photo.append(photoRepresentation)
                                        }
                                        let channel = TelegramChannel(id: PeerId(namespace: Namespaces.Peer.CloudChannel, id: PeerId.Id._internalFromInt64Value(0)), accessHash: .genericPublic(0), title: invite.title, username: nil, photo: photo, creationDate: 0, version: 0, participationStatus: .left, info: .broadcast(TelegramChannelBroadcastInfo(flags: [])), flags: [], restrictionInfo: nil, adminRights: nil, bannedRights: nil, defaultBannedRights: nil, usernames: [], storiesHidden: nil, nameColor: invite.nameColor, backgroundEmojiId: nil, profileColor: nil, profileBackgroundEmojiId: nil, emojiStatus: nil, approximateBoostLevel: nil, subscriptionUntilDate: nil, verificationIconFileId: nil, sendPaidMessageStars: nil, linkedMonoforumId: nil)
                                        let invoice = TelegramMediaInvoice(title: "", description: "", photo: nil, receiptMessageId: nil, currency: "XTR", totalAmount: subscriptionPricing.amount.value, startParam: "", extendedMedia: nil, subscriptionPeriod: nil, flags: [], version: 0)
                                        
                                        inputData.set(.single(BotCheckoutController.InputData(
                                            form: BotPaymentForm(
                                                id: subscriptionFormId,
                                                canSaveCredentials: false,
                                                passwordMissing: false,
                                                invoice: BotPaymentInvoice(isTest: false, requestedFields: [], currency: "XTR", prices: [BotPaymentPrice(label: "", amount: subscriptionPricing.amount.value)], tip: nil, termsInfo: nil, subscriptionPeriod: subscriptionPricing.period),
                                                paymentBotId: channel.id,
                                                providerId: nil,
                                                url: nil,
                                                nativeProvider: nil,
                                                savedInfo: nil,
                                                savedCredentials: [],
                                                additionalPaymentMethods: []
                                            ),
                                            validatedFormInfo: nil,
                                            botPeer: EnginePeer(channel)
                                        )))
                                        
                                        let starsInputData = combineLatest(
                                            inputData.get(),
                                            starsContext.state
                                        )
                                        |> map { data, state -> (StarsContext.State, BotPaymentForm, EnginePeer?, EnginePeer?)? in
                                            if let data, let state {
                                                return (state, data.form, data.botPeer, nil)
                                            } else {
                                                return nil
                                            }
                                        }
                                        let _ = (starsInputData
                                        |> SwiftSignalKit.filter { $0 != nil }
                                        |> take(1)
                                        |> deliverOnMainQueue).start(next: { _ in
                                            let controller = context.sharedContext.makeStarsSubscriptionTransferScreen(context: context, starsContext: starsContext, invoice: invoice, link: link, inputData: starsInputData, navigateToPeer: { peer in
                                                openPeer(peer, nil)
                                            })
                                            navigationController?.pushViewController(controller)
                                        })
                                    } else {
                                        let joinLinkPreviewController = JoinLinkPreviewController(context: context, link: link, navigateToPeer: { peer, peekData in
                                            openPeer(peer, peekData)
                                        }, parentNavigationController: navigationController, resolvedState: resolvedState)
                                        if joinLinkPreviewController.navigationPresentation == .flatModal {
                                            strongSelf.pushController(joinLinkPreviewController)
                                        } else {
                                            strongSelf.presentController(joinLinkPreviewController, .window(.root), nil)
                                        }
                                    }
                                default:
                                    let joinLinkPreviewController = JoinLinkPreviewController(context: context, link: link, navigateToPeer: { peer, peekData in
                                        openPeer(peer, peekData)
                                    }, parentNavigationController: navigationController, resolvedState: resolvedState)
                                    if joinLinkPreviewController.navigationPresentation == .flatModal {
                                        strongSelf.pushController(joinLinkPreviewController)
                                    } else {
                                        strongSelf.presentController(joinLinkPreviewController, .window(.root), nil)
                                    }
                                }
                            })
                        } else {
                            let joinLinkPreviewController = JoinLinkPreviewController(context: context, link: link, navigateToPeer: { peer, peekData in
                                openPeer(peer, peekData)
                            }, parentNavigationController: navigationController, resolvedState: nil)
                            if joinLinkPreviewController.navigationPresentation == .flatModal {
                                strongSelf.pushController(joinLinkPreviewController)
                            } else {
                                strongSelf.presentController(joinLinkPreviewController, .window(.root), nil)
                            }
                        }
                    case let .joinCall(link):
                        let context = strongSelf.context
                        let navigationController = strongSelf.getNavigationController()
                    
                        let progressSignal = Signal<Never, NoError> { subscriber in
                            progress?.set(.single(true))
                            return ActionDisposable {
                                Queue.mainQueue().async() {
                                    progress?.set(.single(false))
                                }
                            }
                        }
                        |> runOn(Queue.mainQueue())
                        |> delay(0.1, queue: Queue.mainQueue())
                        let progressDisposable = progressSignal.startStrict()
                        
                        var signal = context.engine.peers.joinCallLinkInformation(link)
                        signal = signal
                        |> afterDisposed {
                            Queue.mainQueue().async {
                                progressDisposable.dispose()
                            }
                        }
                                                    
                        let _ = (signal
                        |> deliverOnMainQueue).startStandalone(next: { [weak navigationController] resolvedCallLink in
                            let _ = (context.engine.calls.getGroupCallPersistentSettings(callId: resolvedCallLink.id)
                            |> deliverOnMainQueue).startStandalone(next: { value in
                                let value: PresentationGroupCallPersistentSettings = value?.get(PresentationGroupCallPersistentSettings.self) ?? PresentationGroupCallPersistentSettings.default
                                
                                navigationController?.pushViewController(context.sharedContext.makeJoinSubjectScreen(context: context, mode: JoinSubjectScreenMode.groupCall(JoinSubjectScreenMode.GroupCall(
                                    id: resolvedCallLink.id,
                                    accessHash: resolvedCallLink.accessHash,
                                    slug: link,
                                    inviter: resolvedCallLink.inviter,
                                    members: resolvedCallLink.members,
                                    totalMemberCount: resolvedCallLink.totalMemberCount,
                                    info: resolvedCallLink,
                                    enableMicrophoneByDefault: value.isMicrophoneEnabledByDefault
                                ))))
                            })
                        })
                    case let .localization(identifier):
                        strongSelf.presentController(LanguageLinkPreviewController(context: strongSelf.context, identifier: identifier), .window(.root), nil)
                    case .proxy, .confirmationCode, .cancelAccountReset, .share:
                        strongSelf.context.sharedContext.openResolvedUrl(result, context: strongSelf.context, urlContext: .generic, navigationController: strongSelf.getNavigationController(), forceExternal: false, forceUpdate: false, openPeer: { peer, _ in
                            if let strongSelf = self {
                                strongSelf.openPeer(peer: peer)
                            }
                        }, 
                        sendFile: nil,
                        sendSticker: nil,
                        sendEmoji: nil,
                        requestMessageActionUrlAuth: nil,
                        joinVoiceChat: nil,
                        present: { c, a in
                            self?.presentController(c, .window(.root), a)
                        }, dismissInput: {
                            self?.view.endEditing(true)
                        }, contentContext: nil, progress: nil, completion: nil)
                    case .wallpaper:
                        break
                    case .theme:
                        break
                    case .settings:
                        break
                    case .premiumOffer:
                        break
                    case .starsTopup:
                        break
                    case let .joinVoiceChat(peerId, invite):
                        strongSelf.presentController(VoiceChatJoinScreen(context: strongSelf.context, peerId: peerId, invite: invite, join: { call in
                        }), .window(.root), nil)
                    case .importStickers:
                        break
                    case .startAttach:
                        break
                    case .boost:
                        break
                    case .premiumGiftCode:
                        break
                    case .premiumMultiGift:
                        break
                    case .collectible:
                        break
                    case .messageLink:
                        break
                    case .stars:
                        break
                    case .shareStory:
                        break
                }
            }
        }))
    }
    
    private func presentAutoremoveSetup() {
        /*let controller = ChatTimerScreen(context: self.context, updatedPresentationData: self.controller?.updatedPresentationData, peerId: self.peer.id, style: .default, mode: .autoremove, currentTime: currentValue, dismissByTapOutside: true, completion: { [weak self] value in
            guard let strongSelf = self else {
                return
            }
            
            let _ = (strongSelf.context.engine.peers.setChatMessageAutoremoveTimeoutInteractively(peerId: strongSelf.peer.id, timeout: value == 0 ? nil : value)
            |> deliverOnMainQueue).start(completed: {
                guard let strongSelf = self else {
                    return
                }
                
                var isOn: Bool = true
                var text: String?
                if value != 0 {
                    text = strongSelf.presentationData.strings.Conversation_AutoremoveChanged("\(timeIntervalString(strings: strongSelf.presentationData.strings, value: value))").string
                } else {
                    isOn = false
                    text = strongSelf.presentationData.strings.Conversation_AutoremoveOff
                }
                if let text = text {
                    strongSelf.present(UndoOverlayController(presentationData: strongSelf.presentationData, content: .autoDelete(isOn: isOn, title: nil, text: text, customUndoText: nil), elevatedLayout: false, action: { _ in return false }), in: .current)
                }
            })
        })
        self.view.endEditing(true)
        self.present(controller, in: .window(.root))*/
    }
    
    private func dismissAllTooltips() {
        self.antiSpamTooltipController?.dismiss()
        
        self.controller?.window?.forEachController({ controller in
            if let controller = controller as? UndoOverlayController {
                controller.dismissWithCommitAction()
            }
        })
        self.controller?.forEachController({ controller in
            if let controller = controller as? UndoOverlayController {
                controller.dismissWithCommitAction()
            }
            return true
        })
    }
    
    func frameForVisibleArea() -> CGRect {
        let rect = CGRect(origin: CGPoint(x: self.visibleAreaInset.left, y: self.visibleAreaInset.top), size: CGSize(width: self.bounds.size.width - self.visibleAreaInset.left - self.visibleAreaInset.right, height: self.bounds.size.height - self.visibleAreaInset.top - self.visibleAreaInset.bottom))
        
        return rect
    }
}

final class ChatRecentActionsMessageContextExtractedContentSource: ContextExtractedContentSource {
    let keepInPlace: Bool = false
    let ignoreContentTouches: Bool = false
    let blurBackground: Bool = true
    
    private weak var controllerNode: ChatRecentActionsControllerNode?
    private let message: Message
    private let selectAll: Bool
    
    var shouldBeDismissed: Signal<Bool, NoError> {
        return .single(false)
    }
    
    init(controllerNode: ChatRecentActionsControllerNode, message: Message, selectAll: Bool) {
        self.controllerNode = controllerNode
        self.message = message
        self.selectAll = selectAll
    }
    
    func takeView() -> ContextControllerTakeViewInfo? {
        guard let controllerNode = self.controllerNode else {
            return nil
        }
        
        var result: ContextControllerTakeViewInfo?
        controllerNode.listNode.forEachItemNode { itemNode in
            guard let itemNode = itemNode as? ChatMessageItemView else {
                return
            }
            guard let item = itemNode.item else {
                return
            }
            if item.content.contains(where: { $0.0.stableId == self.message.stableId }), let contentNode = itemNode.getMessageContextSourceNode(stableId: self.selectAll ? nil : self.message.stableId) {
                result = ContextControllerTakeViewInfo(containingItem: .node(contentNode), contentAreaInScreenSpace: controllerNode.convert(controllerNode.frameForVisibleArea(), to: nil))
            }
        }
        return result
    }
    
    func putBack() -> ContextControllerPutBackViewInfo? {
        guard let controllerNode = self.controllerNode else {
            return nil
        }
        
        var result: ContextControllerPutBackViewInfo?
        controllerNode.listNode.forEachItemNode { itemNode in
            guard let itemNode = itemNode as? ChatMessageItemView else {
                return
            }
            guard let item = itemNode.item else {
                return
            }
            if item.content.contains(where: { $0.0.stableId == self.message.stableId }) {
                result = ContextControllerPutBackViewInfo(contentAreaInScreenSpace: controllerNode.convert(controllerNode.frameForVisibleArea(), to: nil))
            }
        }
        return result
    }
}

final class ChatMessageContextLocationContentSource: ContextLocationContentSource {
    private let controller: ViewController
    private let location: CGPoint
    
    init(controller: ViewController, location: CGPoint) {
        self.controller = controller
        self.location = location
    }
    
    func transitionInfo() -> ContextControllerLocationViewInfo? {
        return ContextControllerLocationViewInfo(location: self.location, contentAreaInScreenSpace: UIScreen.main.bounds)
    }
}

extension AdminLogEventAction {
    var messageId: MessageId? {
        switch self {
        case let .editMessage(_, new):
            return new.id
        case let .deleteMessage(message):
            return message.id
        case let .pollStopped(message):
            return message.id
        case let .sendMessage(message):
            return message.id
        default:
            return nil
        }
    }
}
