import Foundation
import UIKit
import AsyncDisplayKit
import Display
import Postbox
import TelegramCore
import SwiftSignalKit
import TelegramPresentationData
import AccountContext
import SearchBarNode
import SearchUI
import ContactListUI
import ChatListUI
import SegmentedControlNode
import AttachmentTextInputPanelNode
import ChatPresentationInterfaceState
import ChatSendMessageActionUI
import ChatTextLinkEditUI
import AnimationCache
import MultiAnimationRenderer
import AnimatedStickerNode
import TelegramAnimatedStickerNode
import SolidRoundedButtonNode
import ContextUI
import TextFormat
import ForwardAccessoryPanelNode
import CounterControllerTitleView

final class PeerSelectionControllerNode: ASDisplayNode {
    private let context: AccountContext
    private weak var controller: PeerSelectionControllerImpl?
    private let present: (ViewController, Any?) -> Void
    private let presentInGlobalOverlay: (ViewController, Any?) -> Void
    private let dismiss: () -> Void
    private let filter: ChatListNodePeersFilter
    private let forumPeerId: (id: EnginePeer.Id, isMonoforum: Bool)?
    private let hasGlobalSearch: Bool
    private let forwardedMessageIds: [EngineMessage.Id]
    private let hasTypeHeaders: Bool
    private let requestPeerType: [ReplyMarkupButtonRequestPeerType]?
    
    private var presentationInterfaceState: ChatPresentationInterfaceState
    private let  presentationInterfaceStatePromise = ValuePromise<ChatPresentationInterfaceState>()
    
    private var interfaceInteraction: ChatPanelInterfaceInteraction?
    
    var inProgress: Bool = false
    
    var navigationBar: NavigationBar?
    
    private let requirementsBackgroundNode: NavigationBackgroundNode?
    private let requirementsSeparatorNode: ASDisplayNode?
    private let requirementsTextNode: ImmediateTextNode?

    private let emptyAnimationNode: AnimatedStickerNode
    private var emptyAnimationSize = CGSize()
    private let emptyTitleNode: ImmediateTextNode
    private let emptyTextNode: ImmediateTextNode
    private let emptyButtonNode: SolidRoundedButtonNode
    
    private let toolbarBackgroundNode: NavigationBackgroundNode?
    private let toolbarSeparatorNode: ASDisplayNode?
    private let segmentedControlNode: SegmentedControlNode?
    
    private var textInputPanelNode: AttachmentTextInputPanelNode?
    private var forwardAccessoryPanelNode: ForwardAccessoryPanelNode?
    
    var contactListNode: ContactListNode?
    let chatListNode: ChatListNode?
    let mainContainerNode: ChatListContainerNode?
        
    private var contactListActive = false
    
    private var searchDisplayController: SearchDisplayController?
    
    private var containerLayout: (ContainerViewLayout, CGFloat, CGFloat)?
    
    var contentOffsetChanged: ((ListViewVisibleContentOffset) -> Void)?
    var contentScrollingEnded: ((ListView) -> Bool)?
    
    var requestActivateSearch: (() -> Void)?
    var requestDeactivateSearch: (() -> Void)?
    var requestOpenPeer: ((EnginePeer, Int64?) -> Void)?
    var requestOpenDisabledPeer: ((EnginePeer, Int64?, ChatListDisabledPeerReason) -> Void)?
    var requestOpenPeerFromSearch: ((EnginePeer, Int64?) -> Void)?
    var requestOpenMessageFromSearch: ((EnginePeer, Int64?, EngineMessage.Id) -> Void)?
    var requestSend: (([EnginePeer], [EnginePeer.Id: EnginePeer], NSAttributedString, AttachmentTextInputPanelSendMode, ChatInterfaceForwardOptionsState?, ChatSendMessageActionSheetController.SendParameters?) -> Void)?
    
    private var presentationData: PresentationData {
        didSet {
            self.presentationDataPromise.set(.single(self.presentationData))
        }
    }
    private var presentationDataPromise = Promise<PresentationData>()
    
    private let animationCache: AnimationCache
    private let animationRenderer: MultiAnimationRenderer
    
    private var countPanelNode: PeersCountPanelNode?
    
    private var readyValue = Promise<Bool>()
    var ready: Signal<Bool, NoError> {
        return self.readyValue.get()
    }
    
    private var isEmpty = false
    
    private var updatedPresentationData: (initial: PresentationData, signal: Signal<PresentationData, NoError>) {
        return (self.presentationData, self.presentationDataPromise.get())
    }
    
    init(context: AccountContext, controller: PeerSelectionControllerImpl, presentationData: PresentationData, filter: ChatListNodePeersFilter, forumPeerId: (id: EnginePeer.Id, isMonoforum: Bool)?, hasFilters: Bool, hasChatListSelector: Bool, hasContactSelector: Bool, hasGlobalSearch: Bool, forwardedMessageIds: [EngineMessage.Id], hasTypeHeaders: Bool, requestPeerType: [ReplyMarkupButtonRequestPeerType]?, hasCreation: Bool, createNewGroup: (() -> Void)?, present: @escaping (ViewController, Any?) -> Void, presentInGlobalOverlay: @escaping (ViewController, Any?) -> Void, dismiss: @escaping () -> Void) {
        self.context = context
        self.controller = controller
        self.present = present
        self.presentInGlobalOverlay = presentInGlobalOverlay
        self.dismiss = dismiss
        self.filter = filter
        self.forumPeerId = forumPeerId
        self.hasGlobalSearch = hasGlobalSearch
        self.forwardedMessageIds = forwardedMessageIds
        self.hasTypeHeaders = hasTypeHeaders
        self.requestPeerType = requestPeerType
        
        self.presentationData = presentationData
        
        self.animationCache = context.animationCache
        self.animationRenderer = context.animationRenderer
        
        self.presentationInterfaceState = ChatPresentationInterfaceState(chatWallpaper: .builtin(WallpaperSettings()), theme: self.presentationData.theme, strings: self.presentationData.strings, dateTimeFormat: self.presentationData.dateTimeFormat, nameDisplayOrder: self.presentationData.nameDisplayOrder, limitsConfiguration: self.context.currentLimitsConfiguration.with { $0 }, fontSize: self.presentationData.chatFontSize, bubbleCorners: self.presentationData.chatBubbleCorners, accountPeerId: self.context.account.peerId, mode: .standard(.default), chatLocation: .peer(id: PeerId(0)), subject: nil, peerNearbyData: nil, greetingData: nil, pendingUnpinnedAllMessages: false, activeGroupCallInfo: nil, hasActiveGroupCall: false, importState: nil, threadData: nil, isGeneralThreadClosed: nil, replyMessage: nil, accountPeerColor: nil, businessIntro: nil)
        
        self.presentationInterfaceState = self.presentationInterfaceState.updatedInterfaceState { $0.withUpdatedForwardMessageIds(forwardedMessageIds) }
        self.presentationInterfaceStatePromise.set(self.presentationInterfaceState)
        
        if let _ = self.requestPeerType {
            self.requirementsBackgroundNode = NavigationBackgroundNode(color: self.presentationData.theme.rootController.navigationBar.blurredBackgroundColor)
            self.requirementsSeparatorNode = ASDisplayNode()
            self.requirementsSeparatorNode?.backgroundColor = self.presentationData.theme.rootController.navigationBar.separatorColor
            self.requirementsTextNode = ImmediateTextNode()
            self.requirementsTextNode?.maximumNumberOfLines = 0
            self.requirementsTextNode?.lineSpacing = 0.1
        } else {
            self.requirementsBackgroundNode = nil
            self.requirementsSeparatorNode = nil
            self.requirementsTextNode = nil
        }
        
        self.emptyTitleNode = ImmediateTextNode()
        self.emptyTitleNode.displaysAsynchronously = false
        self.emptyTitleNode.maximumNumberOfLines = 0
        self.emptyTitleNode.isHidden = true
        self.emptyTitleNode.textAlignment = .center
        self.emptyTitleNode.lineSpacing = 0.25
        
        self.emptyTextNode = ImmediateTextNode()
        self.emptyTextNode.displaysAsynchronously = false
        self.emptyTextNode.maximumNumberOfLines = 0
        self.emptyTextNode.isHidden = true
        self.emptyTextNode.lineSpacing = 0.25
        
        self.emptyAnimationNode = DefaultAnimatedStickerNodeImpl()
        self.emptyAnimationNode.setup(source: AnimatedStickerNodeLocalFileSource(name: "ChatListNoResults"), width: 256, height: 256, playbackMode: .once, mode: .direct(cachePathPrefix: nil))
        self.emptyAnimationNode.isHidden = true
        self.emptyAnimationSize = CGSize(width: 120.0, height: 120.0)
        
        self.emptyButtonNode = SolidRoundedButtonNode(theme: SolidRoundedButtonTheme(theme: self.presentationData.theme), cornerRadius: 11.0, gloss: true)
        self.emptyButtonNode.isHidden = true
        self.emptyButtonNode.pressed = {
            createNewGroup?()
        }
        
        if hasChatListSelector && hasContactSelector {
            self.toolbarBackgroundNode = NavigationBackgroundNode(color: self.presentationData.theme.rootController.navigationBar.blurredBackgroundColor)
            
            self.toolbarSeparatorNode = ASDisplayNode()
            self.toolbarSeparatorNode?.backgroundColor = self.presentationData.theme.rootController.navigationBar.separatorColor
            
            let items = [
                self.presentationData.strings.DialogList_TabTitle,
                self.presentationData.strings.Contacts_TabTitle
            ]
            self.segmentedControlNode = SegmentedControlNode(theme: SegmentedControlTheme(theme: self.presentationData.theme), items: items.map { SegmentedControlItem(title: $0) }, selectedIndex: 0)
        } else {
            self.toolbarBackgroundNode = nil
            self.toolbarSeparatorNode = nil
            self.segmentedControlNode = nil
        }
        
        var chatListCategories: [ChatListNodeAdditionalCategory] = []
        
        if let _ = createNewGroup {
            chatListCategories.append(ChatListNodeAdditionalCategory(id: 0, icon: PresentationResourcesItemList.createGroupIcon(self.presentationData.theme), smallIcon: nil, title: self.presentationData.strings.PeerSelection_ImportIntoNewGroup, appearance: .action))
        }
        
        let chatListLocation: ChatListControllerLocation
        if let (forumPeerId, isMonoforum) = self.forumPeerId {
            if isMonoforum {
                chatListLocation = .savedMessagesChats(peerId: forumPeerId)
            } else {
                chatListLocation = .forum(peerId: forumPeerId)
            }
        } else {
            chatListLocation = .chatList(groupId: .root)
        }
        
        let chatListMode: ChatListNodeMode
        if let requestPeerType = self.requestPeerType {
            chatListMode = .peerType(type: requestPeerType, hasCreate: hasCreation)
        } else {
            chatListMode = .peers(filter: filter, isSelecting: false, additionalCategories: chatListCategories, chatListFilters: nil, displayAutoremoveTimeout: false, displayPresence: false)
        }
       
        if hasFilters {
            self.mainContainerNode = ChatListContainerNode(context: context, controller: nil, location: chatListLocation, chatListMode: chatListMode, previewing: false, controlsHistoryPreload: false, isInlineMode: false, presentationData: presentationData, animationCache: self.animationCache, animationRenderer: self.animationRenderer, filterBecameEmpty: { _ in
            }, filterEmptyAction: { _ in
            }, secondaryEmptyAction: {
            }, openArchiveSettings: {
            })
            self.chatListNode = nil
        } else {
            self.mainContainerNode = nil
            self.chatListNode = ChatListNode(context: context, location: chatListLocation, previewing: false, fillPreloadItems: false, mode: chatListMode, theme: self.presentationData.theme, fontSize: presentationData.listsFontSize, strings: presentationData.strings, dateTimeFormat: presentationData.dateTimeFormat, nameSortOrder: presentationData.nameSortOrder, nameDisplayOrder: presentationData.nameDisplayOrder, animationCache: self.animationCache, animationRenderer: self.animationRenderer, disableAnimations: true, isInlineMode: false, autoSetReady: true, isMainTab: false)
            if let multipleSelectionLimit = controller.multipleSelectionLimit {
                self.chatListNode?.selectionLimit = multipleSelectionLimit
            }
        }
    
        super.init()
        
        self.setViewBlock({
            return UITracingLayerView()
        })
        
        self.chatListNode?.additionalCategorySelected = { _ in
            createNewGroup?()
        }
                
        self.backgroundColor = self.presentationData.theme.chatList.backgroundColor
        
        self.chatListNode?.selectionCountChanged = { [weak self] count in
            self?.textInputPanelNode?.updateSendButtonEnabled(count > 0, animated: true)
        }
        self.chatListNode?.accessibilityPageScrolledString = { row, count in
            return presentationData.strings.VoiceOver_ScrollStatus(row, count).string
        }
        
        self.chatListNode?.activateSearch = { [weak self] in
            self?.requestActivateSearch?()
        }
        self.mainContainerNode?.activateSearch = { [weak self] in
            self?.requestActivateSearch?()
        }
        
        self.chatListNode?.peerSelected = { [weak self] peer, threadId, _, _, _ in
            guard let self else {
                return
            }
            
            if let (peerId, isMonoforum) = self.forumPeerId, isMonoforum {
                let _ = (self.context.engine.data.get(
                    TelegramEngine.EngineData.Item.Peer.Peer(id: peerId)
                )
                |> deliverOnMainQueue).startStandalone(next: { [weak self] mainPeer in
                    guard let self, let mainPeer else {
                        return
                    }
                    self.chatListNode?.clearHighlightAnimated(true)
                    self.requestOpenPeer?(mainPeer, peer.id.toInt64())
                })
            } else {
                self.chatListNode?.clearHighlightAnimated(true)
                self.requestOpenPeer?(peer, threadId)
            }
        }
        self.mainContainerNode?.peerSelected = { [weak self] peer, threadId, _, _, _ in
            guard let self else {
                return
            }
            
            if let (peerId, isMonoforum) = self.forumPeerId, isMonoforum {
                let _ = (self.context.engine.data.get(
                    TelegramEngine.EngineData.Item.Peer.Peer(id: peerId)
                )
                |> deliverOnMainQueue).startStandalone(next: { [weak self] mainPeer in
                    guard let self, let mainPeer else {
                        return
                    }
                    self.chatListNode?.clearHighlightAnimated(true)
                    self.requestOpenPeer?(mainPeer, peer.id.toInt64())
                })
            } else {
                self.chatListNode?.clearHighlightAnimated(true)
                self.requestOpenPeer?(peer, threadId)
            }
        }
        
        self.chatListNode?.disabledPeerSelected = { [weak self] peer, threadId, reason in
            self?.requestOpenDisabledPeer?(peer, threadId, reason)
        }
        self.mainContainerNode?.disabledPeerSelected = { [weak self] peer, threadId, reason in
            self?.requestOpenDisabledPeer?(peer, threadId, reason)
        }
        
        self.chatListNode?.contentOffsetChanged = { [weak self] offset in
            guard let strongSelf = self else {
                return
            }
            if strongSelf.chatListNode?.supernode != nil {
                strongSelf.contentOffsetChanged?(offset)
            }
        }
           
        self.mainContainerNode?.contentOffsetChanged = { [weak self] offset, _ in
            guard let strongSelf = self else {
                return
            }
            if strongSelf.chatListNode?.supernode != nil {
                strongSelf.contentOffsetChanged?(offset)
            }
        }
        
        self.chatListNode?.contentScrollingEnded = { [weak self] listView in
            return self?.contentScrollingEnded?(listView) ?? false
        }
        
        self.chatListNode?.isEmptyUpdated = { [weak self] state, _, _ in
            guard let strongSelf = self else {
                return
            }
            if case .empty(false, _) = state, let (layout, navigationBarHeight, actualNavigationBarHeight) = strongSelf.containerLayout {
                strongSelf.isEmpty = true
                strongSelf.controller?.navigationBar?.setContentNode(nil, animated: false)
                strongSelf.containerLayoutUpdated(layout, navigationBarHeight: navigationBarHeight, actualNavigationBarHeight: actualNavigationBarHeight, transition: .immediate)
            }
        }
        
        if let mainContainerNode = self.mainContainerNode {
            mainContainerNode.displayFilterLimit = { [weak self] in
                guard let strongSelf = self else {
                    return
                }
                var replaceImpl: ((ViewController) -> Void)?
                let controller = context.sharedContext.makePremiumLimitController(context: context, subject: .folders, count: strongSelf.controller?.tabContainerNode?.filtersCount ?? 0, forceDark: false, cancel: {}, action: {
                    let controller = context.sharedContext.makePremiumIntroController(context: context, source: .folders, forceDark: false, dismissed: nil)
                    replaceImpl?(controller)
                    return true
                })
                replaceImpl = { [weak controller] c in
                    controller?.replace(with: c)
                }
                strongSelf.controller?.push(controller)
            }
            self.addSubnode(mainContainerNode)
        }
        if let chatListNode = self.chatListNode {
            self.addSubnode(chatListNode)
        }
                
        if hasChatListSelector && hasContactSelector {
            self.segmentedControlNode!.selectedIndexChanged = { [weak self] index in
                self?.indexChanged(index)
            }
            
            self.addSubnode(self.toolbarBackgroundNode!)
            self.addSubnode(self.toolbarSeparatorNode!)
            self.addSubnode(self.segmentedControlNode!)
        }
        
        if let requirementsBackgroundNode = self.requirementsBackgroundNode, let requirementsSeparatorNode = self.requirementsSeparatorNode, let requirementsTextNode = self.requirementsTextNode {
            self.chatListNode?.addSubnode(requirementsBackgroundNode)
            self.chatListNode?.addSubnode(requirementsSeparatorNode)
            self.chatListNode?.addSubnode(requirementsTextNode)
            
            self.addSubnode(self.emptyAnimationNode)
            self.addSubnode(self.emptyTitleNode)
            self.addSubnode(self.emptyTextNode)
            self.addSubnode(self.emptyButtonNode)
        }
        
        if !hasChatListSelector && hasContactSelector {
            self.indexChanged(1)
        }
             
        self.interfaceInteraction = ChatPanelInterfaceInteraction(setupReplyMessage: { _, _ in
        }, setupEditMessage: { _, _ in
        }, beginMessageSelection: { _, _ in
        }, cancelMessageSelection: { _ in
        }, deleteSelectedMessages: {
        }, reportSelectedMessages: {
        }, reportMessages: { _, _ in
        }, blockMessageAuthor: { _, _ in
        }, deleteMessages: { _, _, f in
            f(.default)
        }, forwardSelectedMessages: {
        }, forwardCurrentForwardMessages: {
        }, forwardMessages: { _ in
        }, updateForwardOptionsState: { [weak self] f in
            if let strongSelf = self {
                strongSelf.updateChatPresentationInterfaceState(animated: true, { $0.updatedInterfaceState({ $0.withUpdatedForwardOptionsState(f($0.forwardOptionsState ?? ChatInterfaceForwardOptionsState(hideNames: false, hideCaptions: false, unhideNamesOnCaptionChange: false))) }) })
            }
        }, presentForwardOptions: { [weak self] sourceNode in
            guard let strongSelf = self else  {
                return
            }

            let presentationData = strongSelf.presentationData
            
            let peerIds = strongSelf.selectedPeers.0.map { $0.id }
            
            let forwardOptions: Signal<ChatControllerSubject.ForwardOptions, NoError>
            forwardOptions = strongSelf.presentationInterfaceStatePromise.get()
            |> map { state -> ChatControllerSubject.ForwardOptions in
                return ChatControllerSubject.ForwardOptions(hideNames: state.interfaceState.forwardOptionsState?.hideNames ?? false, hideCaptions: state.interfaceState.forwardOptionsState?.hideCaptions ?? false)
            }
            |> distinctUntilChanged
            
            let chatController = strongSelf.context.sharedContext.makeChatController(
                context: strongSelf.context,
                chatLocation: .peer(id: strongSelf.context.account.peerId),
                subject: .messageOptions(peerIds: peerIds, ids: strongSelf.presentationInterfaceState.interfaceState.forwardMessageIds ?? [], info: .forward(ChatControllerSubject.MessageOptionsInfo.Forward(options: forwardOptions))),
                botStart: nil,
                mode: .standard(.previewing),
                params: nil
            )
            chatController.canReadHistory.set(false)
            
            let messageIds = strongSelf.presentationInterfaceState.interfaceState.forwardMessageIds ?? []
            let messagesCount: Signal<Int, NoError>
            if messageIds.count > 1 {
                messagesCount = .single(messageIds.count)
                |> then(
                    chatController.presentationInterfaceStateSignal
                    |> map { state -> Int in
                        guard let state = state as? ChatPresentationInterfaceState else {
                            return 1
                        }
                        return state.interfaceState.selectionState?.selectedIds.count ?? 1
                    }
                )
            } else {
                messagesCount = .single(1)
            }
            
            let accountPeerId = strongSelf.context.account.peerId
            let items = combineLatest(forwardOptions, strongSelf.context.account.postbox.messagesAtIds(messageIds), messagesCount)
            |> map { forwardOptions, messages, messagesCount -> [ContextMenuItem] in
                var items: [ContextMenuItem] = []
                
                var hasCaptions = false
                var uniquePeerIds = Set<PeerId>()
                
                var hasOther = false
                var hasNotOwnMessages = false
                for message in messages {
                    if let author = message.effectiveAuthor {
                        if !uniquePeerIds.contains(author.id) {
                            uniquePeerIds.insert(author.id)
                        }
                        if message.id.peerId == accountPeerId && message.forwardInfo == nil {
                        } else {
                            hasNotOwnMessages = true
                        }
                    }
                    
                    var isDice = false
                    var isMusic = false
                    for media in message.media {
                        if let media = media as? TelegramMediaFile, media.isMusic {
                            isMusic = true
                        } else if media is TelegramMediaDice {
                            isDice = true
                        } else {
                            if !message.text.isEmpty {
                                if media is TelegramMediaImage || media is TelegramMediaFile {
                                    hasCaptions = true
                                }
                            }
                        }
                    }
                    if !isDice && !isMusic {
                        hasOther = true
                    }
                }
                
                let canHideNames = hasNotOwnMessages && hasOther
                
                let hideNames = forwardOptions.hideNames
                let hideCaptions = forwardOptions.hideCaptions
                
                if !"".isEmpty { // check if seecret chat
                } else {
                    if canHideNames {
                        items.append(.action(ContextMenuActionItem(text: uniquePeerIds.count == 1 ? presentationData.strings.Conversation_ForwardOptions_ShowSendersName : presentationData.strings.Conversation_ForwardOptions_ShowSendersNames, icon: { theme in
                            if hideNames {
                                return nil
                            } else {
                                return generateTintedImage(image: UIImage(bundleImageName: "Chat/Context Menu/Check"), color: theme.contextMenu.primaryColor)
                            }
                        }, action: { [weak self] _, f in
                            self?.interfaceInteraction?.updateForwardOptionsState({ current in
                                var updated = current
                                updated.hideNames = false
                                updated.hideCaptions = false
                                updated.unhideNamesOnCaptionChange = false
                                return updated
                            })
                        })))
                        
                        items.append(.action(ContextMenuActionItem(text: uniquePeerIds.count == 1 ? presentationData.strings.Conversation_ForwardOptions_HideSendersName : presentationData.strings.Conversation_ForwardOptions_HideSendersNames, icon: { theme in
                            if hideNames {
                                return generateTintedImage(image: UIImage(bundleImageName: "Chat/Context Menu/Check"), color: theme.contextMenu.primaryColor)
                            } else {
                                return nil
                            }
                        }, action: { _, f in
                            self?.interfaceInteraction?.updateForwardOptionsState({ current in
                                var updated = current
                                updated.hideNames = true
                                updated.unhideNamesOnCaptionChange = false
                                return updated
                            })
                        })))
                        
                        items.append(.separator)
                    }
                    
                    if hasCaptions {
                        items.append(.action(ContextMenuActionItem(text: presentationData.strings.Conversation_ForwardOptions_ShowCaption, icon: { theme in
                            if hideCaptions {
                                return nil
                            } else {
                                return generateTintedImage(image: UIImage(bundleImageName: "Chat/Context Menu/Check"), color: theme.contextMenu.primaryColor)
                            }
                        }, action: { [weak self] _, f in
                            self?.interfaceInteraction?.updateForwardOptionsState({ current in
                                var updated = current
                                updated.hideCaptions = false
                                if updated.unhideNamesOnCaptionChange {
                                    updated.unhideNamesOnCaptionChange = false
                                    updated.hideNames = false
                                }
                                return updated
                            })
                        })))
                        
                        items.append(.action(ContextMenuActionItem(text: presentationData.strings.Conversation_ForwardOptions_HideCaption, icon: { theme in
                            if hideCaptions {
                                return generateTintedImage(image: UIImage(bundleImageName: "Chat/Context Menu/Check"), color: theme.contextMenu.primaryColor)
                            } else {
                                return nil
                            }
                        }, action: { _, f in
                            self?.interfaceInteraction?.updateForwardOptionsState({ current in
                                var updated = current
                                updated.hideCaptions = true
                                if !updated.hideNames {
                                    updated.hideNames = true
                                    updated.unhideNamesOnCaptionChange = true
                                }
                                return updated
                            })
                        })))
                        
                        items.append(.separator)
                    }
                }
                
                items.append(.action(ContextMenuActionItem(text: messagesCount == 1 ? presentationData.strings.Conversation_ForwardOptions_SendMessage : presentationData.strings.Conversation_ForwardOptions_SendMessages, icon: { theme in return generateTintedImage(image: UIImage(bundleImageName: "Chat/Context Menu/Resend"), color: theme.contextMenu.primaryColor) }, action: { [weak self, weak chatController] c, f in
                    guard let strongSelf = self else {
                        return
                    }
                    if let selectedMessageIds = chatController?.selectedMessageIds {
                        var forwardMessageIds = strongSelf.presentationInterfaceState.interfaceState.forwardMessageIds ?? []
                        forwardMessageIds = forwardMessageIds.filter { selectedMessageIds.contains($0) }
                        strongSelf.updateChatPresentationInterfaceState(animated: true, { $0.updatedInterfaceState({ $0.withUpdatedForwardMessageIds(forwardMessageIds) }) })
                    }
                    strongSelf.textInputPanelNode?.sendMessage(.generic, nil)

                    f(.default)
                })))
                
                return items
            }

            let contextController = ContextController(presentationData: strongSelf.presentationData, source: .controller(ContextControllerContentSourceImpl(controller: chatController, sourceNode: sourceNode, passthroughTouches: true)), items: items |> map { ContextController.Items(content: .list($0)) })
            contextController.dismissedForCancel = { [weak chatController] in
                if let selectedMessageIds = chatController?.selectedMessageIds {
                    var forwardMessageIds = strongSelf.presentationInterfaceState.interfaceState.forwardMessageIds ?? []
                    forwardMessageIds = forwardMessageIds.filter { selectedMessageIds.contains($0) }
                    strongSelf.updateChatPresentationInterfaceState(animated: true, { $0.updatedInterfaceState({ $0.withUpdatedForwardMessageIds(forwardMessageIds) }) })
                }
            }
            contextController.immediateItemsTransitionAnimation = true
            strongSelf.controller?.presentInGlobalOverlay(contextController)
        }, presentReplyOptions: { _ in
        }, presentLinkOptions: { _ in
        }, shareSelectedMessages: {
        }, updateTextInputStateAndMode: { [weak self] f in
            if let strongSelf = self {
                strongSelf.updateChatPresentationInterfaceState(animated: true, { state in
                    let (updatedState, updatedMode) = f(state.interfaceState.effectiveInputState, state.inputMode)
                    return state.updatedInterfaceState { interfaceState in
                        return interfaceState.withUpdatedEffectiveInputState(updatedState)
                    }.updatedInputMode({ _ in updatedMode })
                })
            }
        }, updateInputModeAndDismissedButtonKeyboardMessageId: { [weak self] f in
            if let strongSelf = self {
                strongSelf.updateChatPresentationInterfaceState(animated: true, {
                    let (updatedInputMode, updatedClosedButtonKeyboardMessageId) = f($0)
                    return $0.updatedInputMode({ _ in return updatedInputMode }).updatedInterfaceState({
                        $0.withUpdatedMessageActionsState({ value in
                            var value = value
                            value.closedButtonKeyboardMessageId = updatedClosedButtonKeyboardMessageId
                            return value
                        })
                    })
                })
            }
        }, openStickers: {
        }, editMessage: {
        }, beginMessageSearch: { _, _ in
        }, dismissMessageSearch: {
        }, updateMessageSearch: { _ in
        }, openSearchResults: {
        }, navigateMessageSearch: { _ in
        }, openCalendarSearch: {
        }, toggleMembersSearch: { _ in
        }, navigateToMessage: { _, _, _, _ in
        }, navigateToChat: { _ in
        }, navigateToProfile: { _ in
        }, openPeerInfo: {
        }, togglePeerNotifications: {
        }, sendContextResult: { _, _, _, _ in
            return false
        }, sendBotCommand: { _, _ in
        }, sendShortcut: { _ in
        }, openEditShortcuts: {
        }, sendBotStart: { _ in
        }, botSwitchChatWithPayload: { _, _ in
        }, beginMediaRecording: { _ in
        }, finishMediaRecording: { _ in
        }, stopMediaRecording: {
        }, lockMediaRecording: {
        }, resumeMediaRecording: {
        }, deleteRecordedMedia: {
        }, sendRecordedMedia: { _, _ in
        }, displayRestrictedInfo: { _, _ in
        }, displayVideoUnmuteTip: { _ in
        }, switchMediaRecordingMode: {
        }, setupMessageAutoremoveTimeout: {
        }, sendSticker: { _, _, _, _, _, _ in
            return false
        }, unblockPeer: {
        }, pinMessage: { _, _ in
        }, unpinMessage: { _, _, _ in
        }, unpinAllMessages: {
        }, openPinnedList: { _ in
        }, shareAccountContact: {
        }, reportPeer: {
        }, presentPeerContact: {
        }, dismissReportPeer: {
        }, deleteChat: {
        }, beginCall: { _ in
        }, toggleMessageStickerStarred: { _ in
        }, presentController: { _, _ in
        }, presentControllerInCurrent: { _, _ in
        }, getNavigationController: {
            return nil
        }, presentGlobalOverlayController: { _, _ in
        }, navigateFeed: {
        }, openGrouping: {
        }, toggleSilentPost: {
        }, requestUnvoteInMessage: { _ in
        }, requestStopPollInMessage: { _ in
        }, updateInputLanguage: { _ in
        }, unarchiveChat: {
        }, openLinkEditing: { [weak self] in
            if let strongSelf = self {
                var selectionRange: Range<Int>?
                var text: NSAttributedString?
                var inputMode: ChatInputMode?
                
                strongSelf.updateChatPresentationInterfaceState(animated: true, { state in
                    selectionRange = state.interfaceState.effectiveInputState.selectionRange
                    if let selectionRange = selectionRange {
                        text = state.interfaceState.effectiveInputState.inputText.attributedSubstring(from: NSRange(location: selectionRange.startIndex, length: selectionRange.count))
                    }
                    inputMode = state.inputMode
                    return state
                })
                
                var link: String?
                if let text {
                    text.enumerateAttributes(in: NSMakeRange(0, text.length)) { attributes, _, _ in
                        if let linkAttribute = attributes[ChatTextInputAttributes.textUrl] as? ChatTextInputTextUrlAttribute {
                            link = linkAttribute.url
                        }
                    }
                }
                
                let controller = chatTextLinkEditController(sharedContext: strongSelf.context.sharedContext, updatedPresentationData: (presentationData, .never()), account: strongSelf.context.account, text: text?.string ?? "", link: link, apply: { [weak self] link in
                    if let strongSelf = self, let inputMode = inputMode, let selectionRange = selectionRange {
                        if let link = link {
                            strongSelf.updateChatPresentationInterfaceState(animated: true, { state in
                                return state.updatedInterfaceState({
                                    $0.withUpdatedEffectiveInputState(chatTextInputAddLinkAttribute($0.effectiveInputState, selectionRange: selectionRange, url: link))
                                })
                            })
                        }
                        if let textInputPanelNode = strongSelf.textInputPanelNode {
                            textInputPanelNode.ensureFocused()
                        }
                        strongSelf.updateChatPresentationInterfaceState(animated: true, { state in
                            return state.updatedInputMode({ _ in return inputMode }).updatedInterfaceState({
                                $0.withUpdatedEffectiveInputState(ChatTextInputState(inputText: $0.effectiveInputState.inputText, selectionRange: selectionRange.endIndex ..< selectionRange.endIndex))
                            })
                        })
                    }
                })
                strongSelf.present(controller, nil)
            }
        }, displaySlowmodeTooltip: { _, _ in
        }, displaySendMessageOptions: { [weak self] node, gesture in
            guard let strongSelf = self else {
                return
            }
            
            let _ = (ChatSendMessageContextScreen.initialData(context: strongSelf.context, currentMessageEffectId: nil)
            |> deliverOnMainQueue).start(next: { initialData in
                guard let strongSelf = self, let textInputPanelNode = strongSelf.textInputPanelNode else {
                    return
                }
                textInputPanelNode.loadTextInputNodeIfNeeded()
                guard let textInputNode = textInputPanelNode.textInputNode else {
                    return
                }
                
                var hasEntityKeyboard = false
                if case .media = strongSelf.presentationInterfaceState.inputMode {
                    hasEntityKeyboard = true
                }
                
                let controller = makeChatSendMessageActionSheetController(
                    initialData: initialData,
                    context: strongSelf.context,
                    peerId: strongSelf.presentationInterfaceState.chatLocation.peerId,
                    params: .sendMessage(SendMessageActionSheetControllerParams.SendMessage(
                        isScheduledMessages: false,
                        mediaPreview: nil,
                        mediaCaptionIsAbove: nil,
                        messageEffect: nil,
                        attachment: false,
                        canSendWhenOnline: false,
                        forwardMessageIds: strongSelf.presentationInterfaceState.interfaceState.forwardMessageIds ?? [],
                        canMakePaidContent: false,
                        currentPrice: nil,
                        hasTimers: false,
                        sendPaidMessageStars: nil,
                        isMonoforum: false
                    )),
                    hasEntityKeyboard: hasEntityKeyboard,
                    gesture: gesture,
                    sourceSendButton: node,
                    textInputView: textInputNode.textView,
                    emojiViewProvider: textInputPanelNode.emojiViewProvider,
                    completion: {
                    },
                    sendMessage: { [weak textInputPanelNode] mode, messageEffect in
                        switch mode {
                        case .generic:
                            textInputPanelNode?.sendMessage(.generic, messageEffect)
                        case .silently:
                            textInputPanelNode?.sendMessage(.silent, messageEffect)
                        case .whenOnline:
                            textInputPanelNode?.sendMessage(.whenOnline, messageEffect)
                        }
                    },
                    schedule: { [weak textInputPanelNode] messageEffect in
                        textInputPanelNode?.sendMessage(.schedule, messageEffect)
                    },
                    editPrice: { _ in },
                    openPremiumPaywall: { [weak controller] c in
                        guard let controller else {
                            return
                        }
                        controller.push(c)
                    }
                )
                strongSelf.presentInGlobalOverlay(controller, nil)
            })
        }, openScheduledMessages: {
        }, openPeersNearby: {
        }, displaySearchResultsTooltip: { _, _ in
        }, unarchivePeer: {
        }, scrollToTop: {
        }, viewReplies: { _, _ in
        }, activatePinnedListPreview: { _, _ in
        }, joinGroupCall: { _ in
        }, presentInviteMembers: {
        }, presentGigagroupHelp: {
        }, openSuggestPost: {
        }, editMessageMedia: { _, _ in
        }, updateShowCommands: { _ in
        }, updateShowSendAsPeers: { _ in
        }, openInviteRequests: {
        }, openSendAsPeer: { _, _ in
        }, presentChatRequestAdminInfo: {
        }, displayCopyProtectionTip: { _, _ in
        }, openWebView: { _, _, _, _ in
        }, updateShowWebView: { _ in
        }, insertText: { _ in
        }, backwardsDeleteText: {
        }, restartTopic: {
        }, toggleTranslation: { _ in
        }, changeTranslationLanguage: { _ in
        }, addDoNotTranslateLanguage: { _ in
        }, hideTranslationPanel: {
        }, openPremiumGift: {
        }, openPremiumRequiredForMessaging: {
        }, openStarsPurchase: { _ in
        }, openMessagePayment: {
        }, openBoostToUnrestrict: {
        }, updateRecordingTrimRange: { _, _, _, _ in
        }, dismissAllTooltips: {
        }, updateHistoryFilter: { _ in
        }, updateChatLocationThread: { _, _ in
        }, toggleChatSidebarMode: {
        }, updateDisplayHistoryFilterAsList: { _ in
        }, requestLayout: { _ in
        }, chatController: {
            return nil
        }, statuses: nil)
        
        if let chatListNode = self.chatListNode {
            self.readyValue.set(chatListNode.ready)
        }
    }
    
    func updatePresentationData(_ presentationData: PresentationData) {
        self.presentationData = presentationData
        self.updateThemeAndStrings()
        self.mainContainerNode?.updatePresentationData(presentationData)
    }
    
    private func updateChatPresentationInterfaceState(animated: Bool = true, _ f: (ChatPresentationInterfaceState) -> ChatPresentationInterfaceState, completion: @escaping (ContainedViewLayoutTransition) -> Void = { _ in }) {
        self.updateChatPresentationInterfaceState(transition: animated ? .animated(duration: 0.4, curve: .spring) : .immediate, f, completion: completion)
    }
    
    private func updateChatPresentationInterfaceState(transition: ContainedViewLayoutTransition, _ f: (ChatPresentationInterfaceState) -> ChatPresentationInterfaceState, completion externalCompletion: @escaping (ContainedViewLayoutTransition) -> Void = { _ in }) {
        let presentationInterfaceState = f(self.presentationInterfaceState)
        let updateInputTextState = self.presentationInterfaceState.interfaceState.effectiveInputState != presentationInterfaceState.interfaceState.effectiveInputState
        
        self.presentationInterfaceState = presentationInterfaceState
        self.presentationInterfaceStatePromise.set(presentationInterfaceState)
        
        if let textInputPanelNode = self.textInputPanelNode, updateInputTextState {
            textInputPanelNode.updateInputTextState(presentationInterfaceState.interfaceState.effectiveInputState, animated: transition.isAnimated)
        }
        
        if let (layout, navigationBarHeight, actualNavigationBarHeight) = self.containerLayout {
            self.containerLayoutUpdated(layout, navigationBarHeight: navigationBarHeight, actualNavigationBarHeight: actualNavigationBarHeight, transition: transition)
        }
    }
    
    private var selectedPeers: ([EnginePeer], [EnginePeer.Id: EnginePeer]) {
        if self.contactListActive {
            let selectedContactPeers = self.contactListNode?.selectedPeers ?? []

            var selectedPeers: [EnginePeer] = []
            var selectedPeerMap: [EnginePeer.Id: EnginePeer] = [:]
            for contactPeer in selectedContactPeers {
                if case let .peer(peer, _, _) = contactPeer {
                    selectedPeers.append(EnginePeer(peer))
                    selectedPeerMap[peer.id] = EnginePeer(peer)
                }
            }
            return (selectedPeers, selectedPeerMap)
        } else {
            var selectedPeerIds: [EnginePeer.Id] = []
            var selectedPeerMap: [EnginePeer.Id: EnginePeer] = [:]
            if let mainContainerNode = self.mainContainerNode {
                mainContainerNode.currentItemNode.updateState { state in
                    selectedPeerIds = Array(state.selectedPeerIds)
                    selectedPeerMap = state.selectedPeerMap
                    return state
                }
            }
            if let chatListNode = self.chatListNode {
                chatListNode.updateState { state in
                    selectedPeerIds = Array(state.selectedPeerIds)
                    selectedPeerMap = state.selectedPeerMap
                    return state
                }
            }
            var selectedPeers: [EnginePeer] = []
            for peerId in selectedPeerIds {
                if let peer = selectedPeerMap[peerId] {
                    selectedPeers.append(peer)
                }
            }
            return (selectedPeers, selectedPeerMap)
        }
    }
    
    func beginSelection() {
        guard let controller = self.controller else {
            return
        }
        if controller.immediatelyActivateMultipleSelection {
            let countPanelNode = PeersCountPanelNode(theme: self.presentationData.theme, strings: self.presentationData.strings, action: { [weak self] in
                guard let self else {
                    return
                }
                let (selectedPeers, selectedPeerMap) = self.selectedPeers
                if !self.isEmpty {
                    self.requestSend?(selectedPeers, selectedPeerMap, NSAttributedString(), .generic, nil, nil)
                }
            })
            self.addSubnode(countPanelNode)
            self.countPanelNode = countPanelNode
            
            if let (layout, navigationBarHeight, actualNavigationBarHeight) = self.containerLayout {
                self.containerLayoutUpdated(layout, navigationBarHeight: navigationBarHeight, actualNavigationBarHeight: actualNavigationBarHeight, transition: .immediate)
            }
        } else {
            if let _ = self.textInputPanelNode {
            } else {
                let forwardAccessoryPanelNode = ForwardAccessoryPanelNode(context: self.context, messageIds: self.forwardedMessageIds, theme: self.presentationData.theme, strings: self.presentationData.strings, fontSize: self.presentationData.chatFontSize, nameDisplayOrder: self.presentationData.nameDisplayOrder, forwardOptionsState: self.presentationInterfaceState.interfaceState.forwardOptionsState, animationCache: nil, animationRenderer: nil)
                forwardAccessoryPanelNode.interfaceInteraction = self.interfaceInteraction
                self.addSubnode(forwardAccessoryPanelNode)
                self.forwardAccessoryPanelNode = forwardAccessoryPanelNode
                
                let textInputPanelNode = AttachmentTextInputPanelNode(context: self.context, presentationInterfaceState: self.presentationInterfaceState, presentController: { [weak self] c in self?.present(c, nil) }, makeEntityInputView: {
                    return nil
                })
                textInputPanelNode.interfaceInteraction = self.interfaceInteraction
                textInputPanelNode.sendMessage = { [weak self] mode, messageEffect in
                    guard let strongSelf = self else {
                        return
                    }
                    
                    let effectiveInputText = strongSelf.presentationInterfaceState.interfaceState.composeInputState.inputText
                    let forwardOptionsState = strongSelf.presentationInterfaceState.interfaceState.forwardOptionsState
                    
                    let (selectedPeers, selectedPeerMap) = strongSelf.selectedPeers
                    if !selectedPeers.isEmpty {
                        strongSelf.requestSend?(selectedPeers, selectedPeerMap, effectiveInputText, mode, forwardOptionsState, messageEffect)
                    }
                }
                self.addSubnode(textInputPanelNode)
                self.textInputPanelNode = textInputPanelNode
                
                if let (layout, navigationBarHeight, actualNavigationBarHeight) = self.containerLayout {
                    self.containerLayoutUpdated(layout, navigationBarHeight: navigationBarHeight, actualNavigationBarHeight: actualNavigationBarHeight, transition: .animated(duration: 0.3, curve: .spring))
                }
            }
        }
        
        if self.contactListActive {
            self.contactListNode?.multipleSelection = true
            self.contactListNode?.updateSelectionState({ _ in
                return ContactListNodeGroupSelectionState()
            })
        } else {
            if let mainContainerNode = self.mainContainerNode {
                mainContainerNode.currentItemNode.selectionCountChanged = { [weak self] count in
                    self?.textInputPanelNode?.updateSendButtonEnabled(count > 0, animated: true)
                }
                mainContainerNode.currentItemNode.updateState({ state in
                    var state = state
                    state.editing = true
                    return state
                })
            } else if let chatListNode = self.chatListNode {
                chatListNode.selectionCountChanged = { [weak self] count in
                    if let self {
                        if let _ = self.controller?.multipleSelectionLimit {
                            self.countPanelNode?.buttonTitle = self.presentationData.strings.Premium_Gift_ContactSelection_Proceed
                        } else {
                            self.countPanelNode?.buttonTitle = self.presentationData.strings.ShareMenu_Send
                        }
                        self.countPanelNode?.count = count
                        
                        if let titleView = self.controller?.titleView, let maxCount = self.controller?.multipleSelectionLimit {
                            titleView.title = CounterControllerTitle(title: titleView.title.title, counter: "\(count)/\(maxCount)")
                        }
                        
                        if let (layout, navigationBarHeight, actualNavigationBarHeight) = self.containerLayout {
                            self.containerLayoutUpdated(layout, navigationBarHeight: navigationBarHeight, actualNavigationBarHeight: actualNavigationBarHeight, transition: .animated(duration: 0.3, curve: .spring))
                        }
                    }
                }
                chatListNode.updateState { state in
                    var state = state
                    state.editing = true
                    return state
                }
            }
        }
    }
    
    private func updateThemeAndStrings() {
        self.backgroundColor = self.presentationData.theme.chatList.backgroundColor
        self.searchDisplayController?.updatePresentationData(self.presentationData)
        self.chatListNode?.updateThemeAndStrings(theme: self.presentationData.theme, fontSize: self.presentationData.listsFontSize, strings: self.presentationData.strings, dateTimeFormat: self.presentationData.dateTimeFormat, nameSortOrder: self.presentationData.nameSortOrder, nameDisplayOrder: self.presentationData.nameDisplayOrder, disableAnimations: true)
        
        self.updateChatPresentationInterfaceState({ $0.updatedTheme(self.presentationData.theme) })
        
        self.requirementsBackgroundNode?.updateColor(color: self.presentationData.theme.rootController.navigationBar.blurredBackgroundColor, transition: .immediate)
        self.toolbarBackgroundNode?.updateColor(color: self.presentationData.theme.rootController.navigationBar.blurredBackgroundColor, transition: .immediate)
        self.toolbarSeparatorNode?.backgroundColor = self.presentationData.theme.rootController.navigationBar.separatorColor
        self.segmentedControlNode?.updateTheme(SegmentedControlTheme(theme: self.presentationData.theme))
        
        if let (layout, navigationBarHeight, actualNavigationBarHeight) = self.containerLayout {
            self.containerLayoutUpdated(layout, navigationBarHeight: navigationBarHeight, actualNavigationBarHeight: actualNavigationBarHeight, transition: .immediate)
        }
    }
    
    func containerLayoutUpdated(_ layout: ContainerViewLayout, navigationBarHeight: CGFloat, actualNavigationBarHeight: CGFloat, transition: ContainedViewLayoutTransition) {
        self.containerLayout = (layout, navigationBarHeight, actualNavigationBarHeight)
        
        let cleanInsets = layout.insets(options: [])
        var insets = layout.insets(options: [.input])
        
        var toolbarHeight: CGFloat = cleanInsets.bottom
        var textPanelHeight: CGFloat?
        var accessoryHeight: CGFloat = 0.0
        
        if let forwardAccessoryPanelNode = self.forwardAccessoryPanelNode {
            let size = forwardAccessoryPanelNode.calculateSizeThatFits(CGSize(width: layout.size.width - layout.safeInsets.left - layout.safeInsets.right, height: layout.size.height))
            accessoryHeight = size.height
        }
        
        if let textInputPanelNode = self.textInputPanelNode {
            var panelTransition = transition
            if textInputPanelNode.frame.width.isZero {
                panelTransition = .immediate
            }
            var panelHeight = textInputPanelNode.updateLayout(width: layout.size.width, leftInset: layout.safeInsets.left, rightInset: layout.safeInsets.right, bottomInset: layout.intrinsicInsets.bottom, additionalSideInsets: UIEdgeInsets(), maxHeight: layout.size.height / 2.0, isSecondary: false, transition: panelTransition, interfaceState: self.presentationInterfaceState, metrics: layout.metrics, isMediaInputExpanded: false)
            if self.searchDisplayController == nil {
                panelHeight += insets.bottom
            } else {
                panelHeight += cleanInsets.bottom
            }
            textPanelHeight = panelHeight
            
            let panelFrame = CGRect(x: 0.0, y: layout.size.height - panelHeight, width: layout.size.width, height: panelHeight)
            if textInputPanelNode.frame.width.isZero {
                var initialPanelFrame = panelFrame
                initialPanelFrame.origin.y = layout.size.height + accessoryHeight
                textInputPanelNode.frame = initialPanelFrame
            }
            transition.updateFrame(node: textInputPanelNode, frame: panelFrame)
        }
        
        if let forwardAccessoryPanelNode = self.forwardAccessoryPanelNode {
            let size = forwardAccessoryPanelNode.calculateSizeThatFits(CGSize(width: layout.size.width - layout.safeInsets.left - layout.safeInsets.right, height: layout.size.height))
            forwardAccessoryPanelNode.updateState(size: size, inset: layout.safeInsets.left, interfaceState: self.presentationInterfaceState)
            forwardAccessoryPanelNode.updateThemeAndStrings(theme: self.presentationData.theme, strings: self.presentationData.strings, forwardOptionsState: self.presentationInterfaceState.interfaceState.forwardOptionsState)
            let panelFrame = CGRect(x: 0.0, y: layout.size.height - (textPanelHeight ?? 0.0) - size.height, width: size.width, height: size.height)
            
            accessoryHeight = size.height
            if forwardAccessoryPanelNode.frame.width.isZero {
                var initialPanelFrame = panelFrame
                initialPanelFrame.origin.y = layout.size.height
                forwardAccessoryPanelNode.frame = initialPanelFrame
            }
            transition.updateFrame(node: forwardAccessoryPanelNode, frame: panelFrame)
        }
        
        if let countPanelNode = self.countPanelNode {
            let countPanelHeight = countPanelNode.updateLayout(width: layout.size.width, sideInset: layout.safeInsets.left, bottomInset: layout.intrinsicInsets.bottom, transition: transition)
            if countPanelNode.count == 0 {
                transition.updateFrame(node: countPanelNode, frame: CGRect(origin: CGPoint(x: 0.0, y: layout.size.height), size: CGSize(width: layout.size.width, height: countPanelHeight)))
            } else {
                toolbarHeight = countPanelHeight
                transition.updateFrame(node: countPanelNode, frame: CGRect(origin: CGPoint(x: 0.0, y: layout.size.height - countPanelHeight), size: CGSize(width: layout.size.width, height: countPanelHeight)))
            }
        } else if let segmentedControlNode = self.segmentedControlNode, let toolbarBackgroundNode = self.toolbarBackgroundNode, let toolbarSeparatorNode = self.toolbarSeparatorNode {
            if let textPanelHeight = textPanelHeight {
                toolbarHeight = textPanelHeight + accessoryHeight
            } else {
                toolbarHeight += 44.0
            }
            transition.updateFrame(node: toolbarBackgroundNode, frame: CGRect(origin: CGPoint(x: 0.0, y: layout.size.height - toolbarHeight), size: CGSize(width: layout.size.width, height: toolbarHeight)))
            toolbarBackgroundNode.update(size: toolbarBackgroundNode.bounds.size, transition: transition)
            transition.updateFrame(node: toolbarSeparatorNode, frame: CGRect(origin: CGPoint(x: 0.0, y: layout.size.height - toolbarHeight), size: CGSize(width: layout.size.width, height: UIScreenPixel)))
            
            let controlSize = segmentedControlNode.updateLayout(.sizeToFit(maximumWidth: layout.size.width, minimumWidth: 200.0, height: 32.0), transition: transition)
            let controlOrigin = layout.size.height - (textPanelHeight == nil ? toolbarHeight : 0.0) + floor((44.0 - controlSize.height) / 2.0)
            transition.updateFrame(node: segmentedControlNode, frame: CGRect(origin: CGPoint(x: floor((layout.size.width - controlSize.width) / 2.0), y: controlOrigin), size: controlSize))
        }
                
        insets.top += navigationBarHeight
        insets.bottom = max(insets.bottom, toolbarHeight)
        insets.left += layout.safeInsets.left
        insets.right += layout.safeInsets.right
        
        var headerInsets = layout.insets(options: [.input])
        headerInsets.top += actualNavigationBarHeight
        headerInsets.bottom = max(headerInsets.bottom, cleanInsets.bottom)
        headerInsets.left += layout.safeInsets.left
        headerInsets.right += layout.safeInsets.right
        
        if let chatListNode = self.chatListNode {
            chatListNode.bounds = CGRect(x: 0.0, y: 0.0, width: layout.size.width, height: layout.size.height)
            chatListNode.position = CGPoint(x: layout.size.width / 2.0, y: layout.size.height / 2.0)
        }
        
        if let mainContainerNode = self.mainContainerNode {
            transition.updateFrame(node: mainContainerNode, frame: CGRect(origin: CGPoint(), size: layout.size))
            mainContainerNode.update(layout: layout, navigationBarHeight: navigationBarHeight, visualNavigationHeight: actualNavigationBarHeight, originalNavigationHeight: navigationBarHeight, cleanNavigationBarHeight: navigationBarHeight, insets: insets, isReorderingFilters: false, isEditing: false, inlineNavigationLocation: nil, inlineNavigationTransitionFraction: 0.0, storiesInset: 0.0, transition: transition)
        }
        
        if let requestPeerTypes = self.requestPeerType, let requestPeerType = requestPeerTypes.first {
            if self.isEmpty {
                self.chatListNode?.isHidden = true
                self.requirementsBackgroundNode?.isHidden = true
                self.requirementsTextNode?.isHidden = true
                self.requirementsSeparatorNode?.isHidden = true
                self.navigationBar?.updateBackgroundAlpha(0.0, transition: .immediate)
                
                var emptyTitle: String
                var emptyText: String
                var emptyButtonText: String
                switch requestPeerType {
                case let .user(user):
                    if let isBot = user.isBot, isBot {
                        emptyTitle = self.presentationData.strings.RequestPeer_BotsAllEmpty
                        emptyText = ""
                    } else {
                        emptyTitle = self.presentationData.strings.RequestPeer_UsersAllEmpty
                        if let text = stringForRequestPeerType(strings: self.presentationData.strings, peerType: requestPeerType, offset: false) {
                            emptyTitle = self.presentationData.strings.RequestPeer_UsersEmpty
                            emptyText = text
                        } else {
                            emptyText = ""
                        }
                    }
                    emptyButtonText = ""
                case .group:
                    emptyTitle = self.presentationData.strings.RequestPeer_GroupsAllEmpty
                    if let text = stringForRequestPeerType(strings: self.presentationData.strings, peerType: requestPeerType, offset: false) {
                        emptyTitle = self.presentationData.strings.RequestPeer_GroupsEmpty
                        emptyText = text
                    } else {
                        emptyText = ""
                    }
                    emptyButtonText = self.presentationData.strings.RequestPeer_CreateNewGroup
                case .channel:
                    emptyTitle = self.presentationData.strings.RequestPeer_ChannelsEmpty
                    if let text = stringForRequestPeerType(strings: self.presentationData.strings, peerType: requestPeerType, offset: false) {
                        emptyTitle = self.presentationData.strings.RequestPeer_ChannelsEmpty
                        emptyText = text
                    } else {
                        emptyText = ""
                    }
                    emptyButtonText = self.presentationData.strings.RequestPeer_CreateNewGroup
                }
                
                self.emptyTitleNode.attributedText = NSAttributedString(string: emptyTitle, font: Font.semibold(15.0), textColor: self.presentationData.theme.list.itemPrimaryTextColor)
                self.emptyTextNode.attributedText = NSAttributedString(string: emptyText, font: Font.regular(15.0), textColor: self.presentationData.theme.list.itemPrimaryTextColor)
                
                let padding: CGFloat = 44.0
                let emptyTitleSize = self.emptyTitleNode.updateLayout(CGSize(width: layout.size.width - insets.left * 2.0 - padding * 2.0, height: CGFloat.greatestFiniteMagnitude))
                let emptyTextSize = self.emptyTextNode.updateLayout(CGSize(width: layout.size.width - insets.left * 2.0 - padding * 2.0, height: CGFloat.greatestFiniteMagnitude))
                
                let emptyAnimationHeight = self.emptyAnimationSize.height
                let emptyAnimationSpacing: CGFloat = 12.0
                let emptyTextSpacing: CGFloat = 17.0
                var emptyButtonSpacing: CGFloat = 15.0
                var emptyButtonHeight: CGFloat = 50.0
                if emptyButtonText.isEmpty {
                    emptyButtonSpacing = 0.0
                    emptyButtonHeight = 0.0
                }
                let emptyTotalHeight = emptyAnimationHeight + emptyAnimationSpacing + emptyTitleSize.height + emptyTextSize.height + emptyTextSpacing + emptyButtonSpacing + emptyButtonHeight
                let emptyAnimationY = floorToScreenPixels((layout.size.height - emptyTotalHeight) / 2.0)
                
                if !emptyButtonText.isEmpty {
                    let buttonPadding: CGFloat = 30.0
                    self.emptyButtonNode.title = emptyButtonText
                    self.emptyButtonNode.isHidden = false
                    let emptyButtonWidth = layout.size.width - insets.left - insets.right - buttonPadding * 2.0
                    let _ = self.emptyButtonNode.updateLayout(width: emptyButtonWidth, transition: transition)
                    transition.updateFrame(node: self.emptyButtonNode, frame: CGRect(origin: CGPoint(x: floorToScreenPixels((layout.size.width - emptyButtonWidth) / 2.0), y: emptyAnimationY + emptyAnimationHeight + emptyAnimationSpacing + emptyTitleSize.height + emptyTextSpacing + emptyTextSize.height + emptyButtonSpacing), size: CGSize(width: emptyButtonWidth, height: emptyButtonHeight)))
                } else {
                    self.emptyButtonNode.isHidden = true
                }
                
                let textTransition = ContainedViewLayoutTransition.immediate
                textTransition.updateFrame(node: self.emptyAnimationNode, frame: CGRect(origin: CGPoint(x: floorToScreenPixels((layout.size.width - self.emptyAnimationSize.width) / 2.0), y: emptyAnimationY), size: self.emptyAnimationSize))
                textTransition.updateFrame(node: self.emptyTitleNode, frame: CGRect(origin: CGPoint(x: floorToScreenPixels((layout.size.width - emptyTitleSize.width) / 2.0), y: emptyAnimationY + emptyAnimationHeight + emptyAnimationSpacing), size: emptyTitleSize))
                textTransition.updateFrame(node: self.emptyTextNode, frame: CGRect(origin: CGPoint(x: floorToScreenPixels((layout.size.width - emptyTextSize.width) / 2.0), y: emptyAnimationY + emptyAnimationHeight + emptyAnimationSpacing + emptyTitleSize.height + emptyTextSpacing), size: emptyTextSize))
                self.emptyAnimationNode.updateLayout(size: self.emptyAnimationSize)
                
                self.emptyAnimationNode.isHidden = false
                self.emptyTitleNode.isHidden = false
                self.emptyTextNode.isHidden = false
                self.emptyAnimationNode.visibility = true
            } else if let requirementsBackgroundNode = self.requirementsBackgroundNode, let requirementsSeparatorNode = self.requirementsSeparatorNode, let requirementsTextNode = self.requirementsTextNode, let requirementsText = stringForRequestPeerType(strings: self.presentationData.strings, peerType: requestPeerType, offset: true) {
                let requirements = NSMutableAttributedString(string: self.presentationData.strings.RequestPeer_Requirements + "\n", font: Font.semibold(13.0), textColor: self.presentationData.theme.list.itemSecondaryTextColor)
                requirements.append(NSAttributedString(string: requirementsText, font: Font.regular(13.0), textColor: self.presentationData.theme.list.itemSecondaryTextColor))
                
                requirementsTextNode.attributedText = requirements
                let sideInset: CGFloat = 16.0
                let verticalInset: CGFloat = 11.0
                let requirementsSize = requirementsTextNode.updateLayout(CGSize(width: layout.size.width - insets.left - insets.right - sideInset * 2.0, height: .greatestFiniteMagnitude))
                
                let requirementsBackgroundFrame = CGRect(origin: CGPoint(x: 0.0, y: actualNavigationBarHeight), size: CGSize(width: layout.size.width, height: requirementsSize.height + verticalInset * 2.0))
                insets.top += requirementsBackgroundFrame.height
                
                requirementsBackgroundNode.update(size: requirementsBackgroundFrame.size, transition: transition)
                transition.updateFrame(node: requirementsBackgroundNode, frame: requirementsBackgroundFrame)
                
                transition.updateFrame(node: requirementsSeparatorNode, frame: CGRect(origin: CGPoint(x: 0.0, y: requirementsBackgroundFrame.maxY - UIScreenPixel), size: CGSize(width: layout.size.width, height: UIScreenPixel)))
                
                requirementsTextNode.frame = CGRect(origin: CGPoint(x: insets.left + sideInset, y: requirementsBackgroundFrame.minY + verticalInset), size: requirementsSize)
            }
        }
        
        let (duration, curve) = listViewAnimationDurationAndCurve(transition: transition)
        let updateSizeAndInsets = ListViewUpdateSizeAndInsets(size: layout.size, insets: insets, headerInsets: headerInsets, duration: duration, curve: curve)
        
        if let chatListNode = self.chatListNode {
            chatListNode.updateLayout(transition: transition, updateSizeAndInsets: updateSizeAndInsets, visibleTopInset: updateSizeAndInsets.insets.top, originalTopInset: updateSizeAndInsets.insets.top, storiesInset: 0.0, inlineNavigationLocation: nil, inlineNavigationTransitionFraction: 0.0)
        }
        
        if let contactListNode = self.contactListNode {
            contactListNode.bounds = CGRect(x: 0.0, y: 0.0, width: layout.size.width, height: layout.size.height)
            contactListNode.position = CGPoint(x: layout.size.width / 2.0, y: layout.size.height / 2.0)
            
            contactListNode.containerLayoutUpdated(ContainerViewLayout(size: layout.size, metrics: layout.metrics, deviceMetrics: layout.deviceMetrics, intrinsicInsets: insets, safeInsets: layout.safeInsets, additionalInsets: layout.additionalInsets, statusBarHeight: layout.statusBarHeight, inputHeight: layout.inputHeight, inputHeightIsInteractivellyChanging: layout.inputHeightIsInteractivellyChanging, inVoiceOver: layout.inVoiceOver), headerInsets: headerInsets, storiesInset: 0.0, transition: transition)
        }
        
        if let searchDisplayController = self.searchDisplayController {
            searchDisplayController.containerLayoutUpdated(layout, navigationBarHeight: navigationBarHeight, transition: transition)
        }
    }
    
    func activateSearch(placeholderNode: SearchBarPlaceholderNode) {
        guard let (containerLayout, navigationBarHeight, _) = self.containerLayout, let navigationBar = self.navigationBar else {
            return
        }
        
        self.navigationBar?.setSecondaryContentNode(nil, animated: true)
        
        if self.chatListNode?.supernode != nil || self.mainContainerNode?.supernode != nil {
            self.chatListNode?.accessibilityElementsHidden = true
            self.mainContainerNode?.accessibilityElementsHidden = true
            
            let chatListLocation: ChatListControllerLocation
            if let (forumPeerId, isMonoforum) = self.forumPeerId {
                if isMonoforum {
                    chatListLocation = .savedMessagesChats(peerId: forumPeerId)
                } else {
                    chatListLocation = .forum(peerId: forumPeerId)
                }
            } else {
                chatListLocation = .chatList(groupId: EngineChatList.Group(.root))
            }
            
            self.searchDisplayController = SearchDisplayController(
                presentationData: self.presentationData,
                contentNode: ChatListSearchContainerNode(
                    context: self.context,
                    animationCache: self.animationCache,
                    animationRenderer: self.animationRenderer,
                    updatedPresentationData: self.updatedPresentationData,
                    filter: self.filter,
                    requestPeerType: self.requestPeerType,
                    location: chatListLocation,
                    displaySearchFilters: false,
                    hasDownloads: false,
                    openPeer: { [weak self] peer, chatPeer, threadId, _ in
                        guard let strongSelf = self else {
                            return
                        }
                        var updated = false
                        var count = 0
                        
                        let chatListNode: ChatListNode?
                        if let mainContainerNode = strongSelf.mainContainerNode {
                            chatListNode = mainContainerNode.currentItemNode
                        } else {
                            chatListNode = strongSelf.chatListNode
                        }
                        
                        chatListNode?.updateState { state in
                            if state.editing {
                                updated = true
                                var state = state
                                var foundPeers = state.foundPeers
                                var selectedPeerMap = state.selectedPeerMap
                                selectedPeerMap[peer.id] = peer
                                if case .secretChat = peer, let chatPeer = chatPeer {
                                    selectedPeerMap[chatPeer.id] = chatPeer
                                }
                                var exists = false
                                for foundPeer in foundPeers {
                                    if peer.id == foundPeer.0.id {
                                        exists = true
                                        break
                                    }
                                }
                                if !exists {
                                    foundPeers.insert((peer, chatPeer), at: 0)
                                }
                                if state.selectedPeerIds.contains(peer.id) {
                                    state.selectedPeerIds.remove(peer.id)
                                } else {
                                    state.selectedPeerIds.insert(peer.id)
                                }
                                state.foundPeers = foundPeers
                                state.selectedPeerMap = selectedPeerMap
                                count = state.selectedPeerIds.count
                                return state
                            } else {
                                return state
                            }
                        }
                        if updated {
                            strongSelf.textInputPanelNode?.updateSendButtonEnabled(count > 0, animated: true)
                            strongSelf.requestDeactivateSearch?()
                            if let (layout, navigationBarHeight, actualNavigationBarHeight) = strongSelf.containerLayout {
                                strongSelf.containerLayoutUpdated(layout, navigationBarHeight: navigationBarHeight, actualNavigationBarHeight: actualNavigationBarHeight, transition: .immediate)
                            }
                        } else if let requestOpenPeerFromSearch = strongSelf.requestOpenPeerFromSearch {
                            requestOpenPeerFromSearch(peer, threadId)
                        }
                    },
                    openDisabledPeer: { [weak self] peer, threadId, reason in
                        self?.requestOpenDisabledPeer?(peer, threadId, reason)
                    },
                    openRecentPeerOptions: { _ in
                    },
                    openMessage: { [weak self] peer, threadId, messageId, _ in
                        if let requestOpenMessageFromSearch = self?.requestOpenMessageFromSearch {
                            requestOpenMessageFromSearch(peer, threadId, messageId)
                        }
                    },
                    addContact: nil,
                    peerContextAction: nil,
                    present: { [weak self] c, a in
                        self?.present(c, a)
                    },
                    presentInGlobalOverlay: { _, _ in
                    },
                    navigationController: nil,
                    parentController: { [weak self] in
                        return self?.controller
                    }
                ), cancel: { [weak self] in
                    if let requestDeactivateSearch = self?.requestDeactivateSearch {
                        requestDeactivateSearch()
                    }
                }
            )
            
            self.searchDisplayController?.containerLayoutUpdated(containerLayout, navigationBarHeight: navigationBarHeight, transition: .immediate)
            self.searchDisplayController?.activate(insertSubnode: { [weak self, weak placeholderNode] subnode, isSearchBar in
                if let strongSelf = self, let strongPlaceholderNode = placeholderNode {
                    if isSearchBar {
                        strongPlaceholderNode.supernode?.insertSubnode(subnode, aboveSubnode: strongPlaceholderNode)
                    } else {
                        strongSelf.insertSubnode(subnode, belowSubnode: navigationBar)
                    }
                }
            }, placeholder: placeholderNode)
            
        } else if let contactListNode = self.contactListNode, contactListNode.supernode != nil {
            contactListNode.accessibilityElementsHidden = true
            
            var categories: ContactsSearchCategories = [.cloudContacts]
            if self.hasGlobalSearch {
                categories.insert(.global)
            }
            self.searchDisplayController = SearchDisplayController(presentationData: self.presentationData, contentNode: ContactsSearchContainerNode(context: self.context, updatedPresentationData: self.updatedPresentationData, onlyWriteable: true, categories: categories, addContact: nil, openPeer: { [weak self] peer, _ in
                if let strongSelf = self {
                    var updated = false
                    var count = 0
                    strongSelf.contactListNode?.updateSelectionState { state -> ContactListNodeGroupSelectionState? in
                        if let state = state {
                            updated = true
                            var foundPeers = state.foundPeers
                            var selectedPeerMap = state.selectedPeerMap
                            selectedPeerMap[peer.id] = peer
                            var exists = false
                            for foundPeer in foundPeers {
                                if peer.id == foundPeer.id {
                                    exists = true
                                    break
                                }
                            }
                            if !exists {
                                foundPeers.insert(peer, at: 0)
                            }
                            let updatedState = state.withToggledPeerId(peer.id).withFoundPeers(foundPeers).withSelectedPeerMap(selectedPeerMap)
                            count = updatedState.selectedPeerIndices.count
                            return updatedState
                        } else {
                            return nil
                        }
                    }
                    
                    if updated {
                        strongSelf.textInputPanelNode?.updateSendButtonEnabled(count > 0, animated: true)
                        strongSelf.requestDeactivateSearch?()
                    } else {
                        switch peer {
                            case let .peer(peer, _, _):
                                let _ = (strongSelf.context.engine.data.get(TelegramEngine.EngineData.Item.Peer.Peer(id: peer.id))
                                |> deliverOnMainQueue).start(next: { peer in
                                    if let strongSelf = self, let peer = peer {
                                        strongSelf.requestOpenPeerFromSearch?(peer, nil)
                                    }
                                })
                            case .deviceContact:
                                break
                        }
                    }
                }
            }, openDisabledPeer: { [weak self] peer, reason in
                guard let self else {
                    return
                }
                self.requestOpenDisabledPeer?(peer, nil, reason)
            }, contextAction: nil), cancel: { [weak self] in
                if let requestDeactivateSearch = self?.requestDeactivateSearch {
                    requestDeactivateSearch()
                }
            })
            
            self.searchDisplayController?.containerLayoutUpdated(containerLayout, navigationBarHeight: navigationBarHeight, transition: .immediate)
            self.searchDisplayController?.activate(insertSubnode: { [weak self, weak placeholderNode] subnode, isSearchBar in
                if let strongSelf = self, let strongPlaceholderNode = placeholderNode {
                    if isSearchBar {
                        strongPlaceholderNode.supernode?.insertSubnode(subnode, aboveSubnode: strongPlaceholderNode)
                    } else {
                        strongSelf.insertSubnode(subnode, belowSubnode: navigationBar)
                    }
                }
            }, placeholder: placeholderNode)
        }
    }
    
    func deactivateSearch(placeholderNode: SearchBarPlaceholderNode) {
        if let searchDisplayController = self.searchDisplayController {
            if self.chatListNode?.supernode != nil || self.mainContainerNode?.supernode != nil {
                self.chatListNode?.accessibilityElementsHidden = false
                self.mainContainerNode?.accessibilityElementsHidden = false
                
                self.navigationBar?.setSecondaryContentNode(self.controller?.tabContainerNode, animated: true)
                self.controller?.setDisplayNavigationBar(true, transition: .animated(duration: 0.5, curve: .spring))
                
                searchDisplayController.deactivate(placeholder: placeholderNode)
                self.searchDisplayController = nil
            } else if let contactListNode = self.contactListNode, contactListNode.supernode != nil {
                contactListNode.accessibilityElementsHidden = false
                
                self.controller?.setDisplayNavigationBar(true, transition: .animated(duration: 0.5, curve: .spring))
                searchDisplayController.deactivate(placeholder: placeholderNode)
                self.searchDisplayController = nil
            }
        }
    }
    
    func scrollToTop() {
        if self.mainContainerNode?.supernode != nil {
            self.mainContainerNode?.scrollToTop(animated: true, adjustForTempInset: false)
        } else if self.chatListNode?.supernode != nil {
            self.chatListNode?.scrollToPosition(.top(adjustForTempInset: false))
        } else if let contactListNode = self.contactListNode, contactListNode.supernode != nil {
            //contactListNode.scrollToTop()
        }
    }
    
    private func indexChanged(_ index: Int) {
        let contactListActive = index == 1
        if contactListActive != self.contactListActive {
            self.contactListActive = contactListActive
            if contactListActive {
                if let contactListNode = self.contactListNode {
                    self.navigationBar?.setSecondaryContentNode(nil, animated: false)
                    if let chatListNode = self.chatListNode, chatListNode.supernode != nil {
                        self.insertSubnode(contactListNode, aboveSubnode: chatListNode)
                        chatListNode.removeFromSupernode()
                    } else if let mainContainerNode = self.mainContainerNode, mainContainerNode.supernode != nil {
                        self.insertSubnode(contactListNode, aboveSubnode: mainContainerNode)
                        mainContainerNode.removeFromSupernode()
                    }
                    self.recursivelyEnsureDisplaySynchronously(true)
                    contactListNode.enableUpdates = true
                    
                    if let (layout, _, _) = self.containerLayout {
                        self.controller?.containerLayoutUpdated(layout, transition: .immediate)
                    }
                } else {
                    let contactListNode = ContactListNode(context: self.context, updatedPresentationData: self.updatedPresentationData, presentation: .single(.natural(options: [], includeChatList: false, topPeers: .none)), onlyWriteable: self.filter.contains(.onlyWriteable), isGroupInvitation: false)
                    self.contactListNode = contactListNode
                    contactListNode.enableUpdates = true
                    contactListNode.selectionStateUpdated = { [weak self] selectionState in
                        if let strongSelf = self {
                            strongSelf.textInputPanelNode?.updateSendButtonEnabled((selectionState?.selectedPeerIndices.count ?? 0) > 0, animated: true)
                        }
                    }
                    contactListNode.activateSearch = { [weak self] in
                        self?.requestActivateSearch?()
                    }
                    contactListNode.openPeer = { [weak self] peer, _, _, _ in
                        if case let .peer(peer, _, _) = peer {
                            self?.contactListNode?.listNode.clearHighlightAnimated(true)
                            self?.requestOpenPeer?(EnginePeer(peer), nil)
                        }
                    }
                    contactListNode.openDisabledPeer = { [weak self] peer, reason in
                        guard let self else {
                            return
                        }
                        self.requestOpenDisabledPeer?(peer, nil, reason)
                    }
                    contactListNode.suppressPermissionWarning = { [weak self] in
                        if let strongSelf = self {
                            strongSelf.context.sharedContext.presentContactsWarningSuppression(context: strongSelf.context, present: { c, a in
                                strongSelf.present(c, a)
                            })
                        }
                    }
                    contactListNode.contentOffsetChanged = { [weak self] offset in
                        guard let strongSelf = self else {
                            return
                        }
                        if strongSelf.contactListNode?.supernode != nil {
                            strongSelf.contentOffsetChanged?(offset)
                        }
                    }
                    
                    contactListNode.contentScrollingEnded = { [weak self] listView in
                        return self?.contentScrollingEnded?(listView) ?? false
                    }
                    
                    if let (layout, navigationHeight, actualNavigationHeight) = self.containerLayout {
                        self.containerLayoutUpdated(layout, navigationBarHeight: navigationHeight, actualNavigationBarHeight: actualNavigationHeight, transition: .immediate)
                        
                        let _ = (contactListNode.ready |> deliverOnMainQueue).start(next: { [weak self] _ in
                            if let strongSelf = self {
                                strongSelf.navigationBar?.setSecondaryContentNode(nil, animated: false)
                                if let contactListNode = strongSelf.contactListNode {
                                    if let chatListNode = strongSelf.chatListNode, chatListNode.supernode != nil {
                                        strongSelf.insertSubnode(contactListNode, aboveSubnode: chatListNode)
                                        chatListNode.removeFromSupernode()
                                    } else if let mainContainerNode = strongSelf.mainContainerNode, mainContainerNode.supernode != nil {
                                        strongSelf.insertSubnode(contactListNode, aboveSubnode: mainContainerNode)
                                        mainContainerNode.removeFromSupernode()
                                    }
                                }
                                strongSelf.recursivelyEnsureDisplaySynchronously(true)
                                
                                if let (layout, _, _) = strongSelf.containerLayout {
                                    strongSelf.controller?.containerLayoutUpdated(layout, transition: .immediate)
                                }
                            }
                        })
                    } else {
                        self.navigationBar?.setSecondaryContentNode(nil, animated: false)
                        if let chatListNode = self.chatListNode {
                            self.insertSubnode(contactListNode, aboveSubnode: chatListNode)
                            chatListNode.removeFromSupernode()
                        } else if let mainContainerNode = self.mainContainerNode {
                            self.insertSubnode(contactListNode, aboveSubnode: mainContainerNode)
                            mainContainerNode.removeFromSupernode()
                        }
                        self.recursivelyEnsureDisplaySynchronously(true)
                        
                        if let (layout, _, _) = self.containerLayout {
                            self.controller?.containerLayoutUpdated(layout, transition: .immediate)
                        }
                    }
                }
            } else if let contactListNode = self.contactListNode {
                self.navigationBar?.setSecondaryContentNode(self.controller?.tabContainerNode, animated: false)
                contactListNode.enableUpdates = false
                
                if let mainContainerNode = self.mainContainerNode {
                    self.insertSubnode(mainContainerNode, aboveSubnode: contactListNode)
                }
                if let chatListNode = self.chatListNode {
                    self.insertSubnode(chatListNode, aboveSubnode: contactListNode)
                }
                contactListNode.removeFromSupernode()
                
                if let (layout, _, _) = self.containerLayout {
                    self.controller?.containerLayoutUpdated(layout, transition: .immediate)
                }
            }
        }
    }
}

public func stringForAdminRights(strings: PresentationStrings, adminRights: TelegramChatAdminRights, isChannel: Bool) -> String {
    var rights: [String] = []
    func append(_ string: String) {
        rights.append("•  \(string)")
    }
    
    if isChannel {
        if adminRights.rights.contains(.canChangeInfo) {
            append(strings.RequestPeer_Requirement_Channel_Rights_Info)
        }
        if adminRights.rights.contains(.canPostMessages) {
            append(strings.RequestPeer_Requirement_Channel_Rights_Send)
        }
        if adminRights.rights.contains(.canDeleteMessages) {
            append(strings.RequestPeer_Requirement_Channel_Rights_Delete)
        }
        if adminRights.rights.contains(.canEditMessages) {
            append(strings.RequestPeer_Requirement_Channel_Rights_Edit)
        }
        if adminRights.rights.contains(.canInviteUsers) {
            append(strings.RequestPeer_Requirement_Channel_Rights_Invite)
        }
        if adminRights.rights.contains(.canPinMessages) {
            append(strings.RequestPeer_Requirement_Channel_Rights_Pin)
        }
        if adminRights.rights.contains(.canManageTopics) {
            append(strings.RequestPeer_Requirement_Channel_Rights_Topics)
        }
        if adminRights.rights.contains(.canManageCalls) {
            append(strings.RequestPeer_Requirement_Channel_Rights_VideoChats)
        }
        if adminRights.rights.contains(.canBeAnonymous) {
            append(strings.RequestPeer_Requirement_Channel_Rights_Anonymous)
        }
        if adminRights.rights.contains(.canAddAdmins) {
            append(strings.RequestPeer_Requirement_Channel_Rights_AddAdmins)
        }
    } else {
        if adminRights.rights.contains(.canChangeInfo) {
            append(strings.RequestPeer_Requirement_Group_Rights_Info)
        }
        if adminRights.rights.contains(.canPostMessages) {
            append(strings.RequestPeer_Requirement_Group_Rights_Send)
        }
        if adminRights.rights.contains(.canDeleteMessages) {
            append(strings.RequestPeer_Requirement_Group_Rights_Delete)
        }
        if adminRights.rights.contains(.canEditMessages) {
            append(strings.RequestPeer_Requirement_Group_Rights_Edit)
        }
        if adminRights.rights.contains(.canBanUsers) {
            append(strings.RequestPeer_Requirement_Group_Rights_Ban)
        }
        if adminRights.rights.contains(.canInviteUsers) {
            append(strings.RequestPeer_Requirement_Group_Rights_Invite)
        }
        if adminRights.rights.contains(.canPinMessages) {
            append(strings.RequestPeer_Requirement_Group_Rights_Pin)
        }
        if adminRights.rights.contains(.canManageTopics) {
            append(strings.RequestPeer_Requirement_Group_Rights_Topics)
        }
        if adminRights.rights.contains(.canManageCalls) {
            append(strings.RequestPeer_Requirement_Group_Rights_VideoChats)
        }
        if adminRights.rights.contains(.canBeAnonymous) {
            append(strings.RequestPeer_Requirement_Group_Rights_Anonymous)
        }
        if adminRights.rights.contains(.canAddAdmins) {
            append(strings.RequestPeer_Requirement_Group_Rights_AddAdmins)
        }
    }
    if !rights.isEmpty {
        return String(rights.joined(separator: "\n"))
    } else {
        return ""
    }
}

private func stringForRequestPeerType(strings: PresentationStrings, peerType: ReplyMarkupButtonRequestPeerType, offset: Bool) -> String? {
    var lines: [String] = []
    
    func append(_ string: String) {
        if offset {
            lines.append("  •  \(string)")
        } else {
            lines.append("•  \(string)")
        }
    }
    
    switch peerType {
    case let .user(user):
        if let isPremium = user.isPremium {
            if isPremium {
                append(strings.RequestPeer_Requirement_UserPremiumOn)
            } else {
                append(strings.RequestPeer_Requirement_UserPremiumOff)
            }
        }
    case let .group(group):
        if group.isCreator {
            append(strings.RequestPeer_Requirement_Group_CreatorOn)
        }
        if let hasUsername = group.hasUsername {
            if hasUsername {
                append(strings.RequestPeer_Requirement_Group_HasUsernameOn)
            } else {
                append(strings.RequestPeer_Requirement_Group_HasUsernameOff)
            }
        }
        if let isForum = group.isForum {
            if isForum {
                append(strings.RequestPeer_Requirement_Group_ForumOn)
            } else {
                append(strings.RequestPeer_Requirement_Group_ForumOff)
            }
        }
        if group.botParticipant {
            append(strings.RequestPeer_Requirement_Group_ParticipantOn)
        }
        if let adminRights = group.userAdminRights, !group.isCreator {
            var rights: [String] = []
            if adminRights.rights.contains(.canChangeInfo) {
                rights.append(strings.RequestPeer_Requirement_Group_Rights_Info)
            }
            if adminRights.rights.contains(.canPostMessages) {
                rights.append(strings.RequestPeer_Requirement_Group_Rights_Send)
            }
            if adminRights.rights.contains(.canDeleteMessages) {
                rights.append(strings.RequestPeer_Requirement_Group_Rights_Delete)
            }
            if adminRights.rights.contains(.canEditMessages) {
                rights.append(strings.RequestPeer_Requirement_Group_Rights_Edit)
            }
            if adminRights.rights.contains(.canBanUsers) {
                rights.append(strings.RequestPeer_Requirement_Group_Rights_Ban)
            }
            if adminRights.rights.contains(.canInviteUsers) {
                rights.append(strings.RequestPeer_Requirement_Group_Rights_Invite)
            }
            if adminRights.rights.contains(.canPinMessages) {
                rights.append(strings.RequestPeer_Requirement_Group_Rights_Pin)
            }
            if adminRights.rights.contains(.canManageTopics) {
                rights.append(strings.RequestPeer_Requirement_Group_Rights_Topics)
            }
            if adminRights.rights.contains(.canManageCalls) {
                rights.append(strings.RequestPeer_Requirement_Group_Rights_VideoChats)
            }
            if adminRights.rights.contains(.canBeAnonymous) {
                rights.append(strings.RequestPeer_Requirement_Group_Rights_Anonymous)
            }
            if adminRights.rights.contains(.canAddAdmins) {
                rights.append(strings.RequestPeer_Requirement_Group_Rights_AddAdmins)
            }
            if !rights.isEmpty {
                let rightsString = strings.RequestPeer_Requirement_Group_Rights(String(rights.joined(separator: ", "))).string
                append(rightsString)
            }
        }
    case let .channel(channel):
        if channel.isCreator {
            append(strings.RequestPeer_Requirement_Channel_CreatorOn)
        }
        if let hasUsername = channel.hasUsername {
            if hasUsername {
                append(strings.RequestPeer_Requirement_Channel_HasUsernameOn)
            } else {
                append(strings.RequestPeer_Requirement_Channel_HasUsernameOff)
            }
        }
        if let adminRights = channel.userAdminRights, !channel.isCreator {
            var rights: [String] = []
            if adminRights.rights.contains(.canChangeInfo) {
                rights.append(strings.RequestPeer_Requirement_Channel_Rights_Info)
            }
            if adminRights.rights.contains(.canPostMessages) {
                rights.append(strings.RequestPeer_Requirement_Channel_Rights_Send)
            }
            if adminRights.rights.contains(.canDeleteMessages) {
                rights.append(strings.RequestPeer_Requirement_Channel_Rights_Delete)
            }
            if adminRights.rights.contains(.canEditMessages) {
                rights.append(strings.RequestPeer_Requirement_Channel_Rights_Edit)
            }
            if adminRights.rights.contains(.canInviteUsers) {
                rights.append(strings.RequestPeer_Requirement_Channel_Rights_Invite)
            }
            if adminRights.rights.contains(.canPinMessages) {
                rights.append(strings.RequestPeer_Requirement_Channel_Rights_Pin)
            }
            if adminRights.rights.contains(.canManageTopics) {
                rights.append(strings.RequestPeer_Requirement_Channel_Rights_Topics)
            }
            if adminRights.rights.contains(.canManageCalls) {
                rights.append(strings.RequestPeer_Requirement_Channel_Rights_VideoChats)
            }
            if adminRights.rights.contains(.canBeAnonymous) {
                rights.append(strings.RequestPeer_Requirement_Channel_Rights_Anonymous)
            }
            if adminRights.rights.contains(.canAddAdmins) {
                rights.append(strings.RequestPeer_Requirement_Channel_Rights_AddAdmins)
            }
            if !rights.isEmpty {
                let rightsString = strings.RequestPeer_Requirement_Group_Rights(String(rights.joined(separator: ", "))).string
                append(rightsString)
            }
        }
    }
    if lines.isEmpty {
        return nil
    } else {
        return String(lines.joined(separator: "\n"))
    }
}

private final class ContextControllerContentSourceImpl: ContextControllerContentSource {
    let controller: ViewController
    weak var sourceNode: ASDisplayNode?
    let sourceRect: CGRect?
    
    let navigationController: NavigationController? = nil
    
    let passthroughTouches: Bool
    
    init(controller: ViewController, sourceNode: ASDisplayNode?, sourceRect: CGRect? = nil, passthroughTouches: Bool) {
        self.controller = controller
        self.sourceNode = sourceNode
        self.sourceRect = sourceRect
        self.passthroughTouches = passthroughTouches
    }
    
    func transitionInfo() -> ContextControllerTakeControllerInfo? {
        let sourceNode = self.sourceNode
        let sourceRect = self.sourceRect
        return ContextControllerTakeControllerInfo(contentAreaInScreenSpace: CGRect(origin: CGPoint(), size: CGSize(width: 10.0, height: 10.0)), sourceNode: { [weak sourceNode] in
            if let sourceNode = sourceNode {
                return (sourceNode.view, sourceRect ?? sourceNode.bounds)
            } else {
                return nil
            }
        })
    }
    
    func animatedIn() {
    }
}

private final class PeersCountPanelNode: ASDisplayNode {
    private let theme: PresentationTheme
    private let strings: PresentationStrings
    
    private let separatorNode: ASDisplayNode
    private let button: SolidRoundedButtonNode
    
    private var validLayout: (CGFloat, CGFloat, CGFloat)?
    
    var buttonTitle: String = ""
    var count: Int = 0 {
        didSet {
            if self.count != oldValue && self.count > 0 {
                self.button.title = self.buttonTitle
                self.button.badge = "\(self.count)"
                
                if let (width, sideInset, bottomInset) = self.validLayout {
                    let _ = self.updateLayout(width: width, sideInset: sideInset, bottomInset: bottomInset, transition: .immediate)
                }
            }
        }
    }
    
    init(theme: PresentationTheme, strings: PresentationStrings, action: @escaping () -> Void) {
        self.theme = theme
        self.strings = strings

        self.separatorNode = ASDisplayNode()
        self.separatorNode.backgroundColor = theme.rootController.navigationBar.separatorColor
        
        self.button = SolidRoundedButtonNode(theme: SolidRoundedButtonTheme(theme: theme), height: 48.0, cornerRadius: 10.0)
        
        super.init()
        
        self.backgroundColor = theme.rootController.navigationBar.opaqueBackgroundColor
        
        self.addSubnode(self.button)
        self.addSubnode(self.separatorNode)
        
        self.button.pressed = {
            action()
        }
    }
    
    func updateLayout(width: CGFloat, sideInset: CGFloat, bottomInset: CGFloat, transition: ContainedViewLayoutTransition) -> CGFloat {
        self.validLayout = (width, sideInset, bottomInset)
        let topInset: CGFloat = 9.0
        var bottomInset = bottomInset
        bottomInset += topInset - (bottomInset.isZero ? 0.0 : 4.0)
        
        let buttonInset: CGFloat = 16.0 + sideInset
        let buttonWidth = width - buttonInset * 2.0
        let buttonHeight = self.button.updateLayout(width: buttonWidth, transition: transition)
        transition.updateFrame(node: self.button, frame: CGRect(x: buttonInset, y: topInset, width: buttonWidth, height: buttonHeight))
        
        transition.updateFrame(node: self.separatorNode, frame: CGRect(origin: CGPoint(x: 0.0, y: 0.0), size: CGSize(width: width, height: UIScreenPixel)))
        
        return topInset + buttonHeight + bottomInset
    }
}
