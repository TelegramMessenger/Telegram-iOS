import Foundation
import UIKit
import Postbox
import SwiftSignalKit
import Display
import AsyncDisplayKit
import TelegramCore

public class ChatController: TelegramController {
    private var containerLayout = ContainerViewLayout()
    
    private let account: Account
    public let peerId: PeerId
    private let messageId: MessageId?
    private let botStart: ChatControllerInitialBotStart?
    
    private let peerDisposable = MetaDisposable()
    private let navigationActionDisposable = MetaDisposable()
    
    private let messageIndexDisposable = MetaDisposable()
    
    private let _peerReady = Promise<Bool>()
    private var didSetPeerReady = false
    private let peerView = Promise<PeerView>()
    
    private var presentationInterfaceState = ChatPresentationInterfaceState()
    
    private var chatTitleView: ChatTitleView?
    private var leftNavigationButton: ChatNavigationButton?
    private var rightNavigationButton: ChatNavigationButton?
    private var chatInfoNavigationButton: ChatNavigationButton?
    
    private var historyStateDisposable: Disposable?
    
    private let galleryHiddenMesageAndMediaDisposable = MetaDisposable()
    private weak var secretMediaPreviewController: SecretMediaPreviewController?
    
    private var controllerInteraction: ChatControllerInteraction?
    private var interfaceInteraction: ChatPanelInterfaceInteraction?
    
    private let messageContextDisposable = MetaDisposable()
    private let controllerNavigationDisposable = MetaDisposable()
    private let sentMessageEventsDisposable = MetaDisposable()
    private let messageActionCallbackDisposable = MetaDisposable()
    private let editMessageDisposable = MetaDisposable()
    private let enqueueMediaMessageDisposable = MetaDisposable()
    private var resolvePeerByNameDisposable: MetaDisposable?
    
    private let editingMessage = ValuePromise<Bool>(false, ignoreRepeated: true)
    private let startingBot = ValuePromise<Bool>(false, ignoreRepeated: true)
    private let unblockingPeer = ValuePromise<Bool>(false, ignoreRepeated: true)
    
    private let botCallbackAlertMessage = Promise<String?>(nil)
    private var botCallbackAlertMessageDisposable: Disposable?
    
    private var resolveUrlDisposable: MetaDisposable?
    
    private var contextQueryState: (ChatPresentationInputQuery?, Disposable)?
    private var urlPreviewQueryState: (String?, Disposable)?
    
    private var audioRecorderValue: ManagedAudioRecorder?
    private var audioRecorderFeedback: HapticFeedback?
    private var audioRecorder = Promise<ManagedAudioRecorder?>()
    private var audioRecorderDisposable: Disposable?
    
    private var buttonKeyboardMessageDisposable: Disposable?
    private var cachedDataDisposable: Disposable?
    private var chatUnreadCountDisposable: Disposable?
    private var peerInputActivitiesDisposable: Disposable?
    
    private var recentlyUsedInlineBotsValue: [Peer] = []
    private var recentlyUsedInlineBotsDisposable: Disposable?
    
    private var unpinMessageDisposable: MetaDisposable?
    
    private let typingActivityPromise = Promise<Bool>()
    private var typingActivityDisposable: Disposable?
    
    private var historyNavigationStack = ChatHistoryNavigationStack()
    
    public init(account: Account, peerId: PeerId, messageId: MessageId? = nil, botStart: ChatControllerInitialBotStart? = nil) {
        self.account = account
        self.peerId = peerId
        self.messageId = messageId
        self.botStart = botStart
        
        /*if #available(iOSApplicationExtension 10.0, *) {
            kdebug_signpost(1, 0, 0, 0, 0)
        }*/
        
        super.init(account: account)
        
        self.navigationItem.backBarButtonItem = UIBarButtonItem(title: "Back", style: .plain, target: nil, action: nil)
        
        self.ready.set(.never())
        
        self.scrollToTop = { [weak self] in
            if let strongSelf = self, strongSelf.isNodeLoaded {
                strongSelf.chatDisplayNode.historyNode.scrollToStartOfHistory()
            }
        }
        
        let controllerInteraction = ChatControllerInteraction(openMessage: { [weak self] id in
            if let strongSelf = self, strongSelf.isNodeLoaded {
                var galleryMedia: Media?
                if let message = strongSelf.chatDisplayNode.historyNode.messageInCurrentHistoryView(id) {
                    for media in message.media {
                        if let file = media as? TelegramMediaFile {
                            galleryMedia = file
                        } else if let image = media as? TelegramMediaImage {
                            galleryMedia = image
                        } else if let webpage = media as? TelegramMediaWebpage, case let .Loaded(content) = webpage.content {
                            if let file = content.file {
                                galleryMedia = file
                            } else if let image = content.image {
                                galleryMedia = image
                            }
                        }
                    }
                }
                
                if let galleryMedia = galleryMedia {
                    if let file = galleryMedia as? TelegramMediaFile, file.isSticker {
                        for attribute in file.attributes {
                            if case let .Sticker(_, reference) = attribute {
                                if let reference = reference {
                                    strongSelf.present(StickerPackPreviewController(account: strongSelf.account, stickerPack: reference), in: .window)
                                }
                                break
                            }
                        }
                    } else if let file = galleryMedia as? TelegramMediaFile, file.isMusic || file.isVoice {
                        if let applicationContext = strongSelf.account.applicationContext as? TelegramApplicationContext {
                            let player = ManagedAudioPlaylistPlayer(postbox: strongSelf.account.postbox, playlist: peerMessageHistoryAudioPlaylist(account: strongSelf.account, messageId: id))
                            applicationContext.mediaManager.setPlaylistPlayer(player)
                            player.control(.navigation(.next))
                        }
                    } else {
                        let gallery = GalleryController(account: strongSelf.account, messageId: id)
                        
                        strongSelf.galleryHiddenMesageAndMediaDisposable.set(gallery.hiddenMedia.start(next: { [weak strongSelf] messageIdAndMedia in
                            if let strongSelf = strongSelf {
                                if let messageIdAndMedia = messageIdAndMedia {
                                    strongSelf.controllerInteraction?.hiddenMedia = [messageIdAndMedia.0: [messageIdAndMedia.1]]
                                } else {
                                    strongSelf.controllerInteraction?.hiddenMedia = [:]
                                }
                                strongSelf.chatDisplayNode.historyNode.forEachItemNode { itemNode in
                                    if let itemNode = itemNode as? ChatMessageItemView {
                                        itemNode.updateHiddenMedia()
                                    }
                                }
                            }
                        }))
                        
                        strongSelf.chatDisplayNode.dismissInput()
                        strongSelf.present(gallery, in: .window, with: GalleryControllerPresentationArguments(transitionArguments: { [weak self] messageId, media in
                            if let strongSelf = self {
                                var transitionNode: ASDisplayNode?
                                strongSelf.chatDisplayNode.historyNode.forEachItemNode { itemNode in
                                    if let itemNode = itemNode as? ChatMessageItemView {
                                        if let result = itemNode.transitionNode(id: messageId, media: media) {
                                            transitionNode = result
                                        }
                                    }
                                }
                                if let transitionNode = transitionNode {
                                    return GalleryTransitionArguments(transitionNode: transitionNode, transitionContainerNode: strongSelf.chatDisplayNode, transitionBackgroundNode: strongSelf.chatDisplayNode.historyNode)
                                }
                            }
                            return nil
                        }))
                    }
                }
            }
        }, openSecretMessagePreview: { [weak self] messageId in
            if let strongSelf = self {
                var galleryMedia: Media?
                if let message = strongSelf.chatDisplayNode.historyNode.messageInCurrentHistoryView(messageId) {
                    for media in message.media {
                        if let file = media as? TelegramMediaFile, file.isVideo {
                            galleryMedia = file
                        } else if let image = media as? TelegramMediaImage {
                            galleryMedia = image
                        }
                    }
                }
                if let _ = galleryMedia {
                    let gallery = SecretMediaPreviewController(account: strongSelf.account, messageId: messageId)
                    strongSelf.secretMediaPreviewController = gallery
                    strongSelf.present(gallery, in: .window)
                }
            }
        }, closeSecretMessagePreview: { [weak self] in
            if let strongSelf = self {
                strongSelf.secretMediaPreviewController?.dismiss()
                strongSelf.secretMediaPreviewController = nil
            }
        }, openPeer: { [weak self] id, navigation, fromMessageId in
            if let strongSelf = self {
                strongSelf.openPeer(peerId: id, navigation: navigation, fromMessageId: fromMessageId)
            }
        }, openPeerMention: { [weak self] name in
            if let strongSelf = self {
                let disposable: MetaDisposable
                if let resolvePeerByNameDisposable = strongSelf.resolvePeerByNameDisposable {
                    disposable = resolvePeerByNameDisposable
                } else {
                    disposable = MetaDisposable()
                    strongSelf.resolvePeerByNameDisposable = disposable
                }
                disposable.set((resolvePeerByName(account: strongSelf.account, name: name, ageLimit: 10) |> take(1) |> deliverOnMainQueue).start(next: { peerId in
                    if let strongSelf = self {
                        if let peerId = peerId {
                            (strongSelf.navigationController as? NavigationController)?.pushViewController(ChatController(account: strongSelf.account, peerId: peerId, messageId: nil))
                        }
                    }
                }))
            }
        }, openMessageContextMenu: { [weak self] id, node, frame in
            if let strongSelf = self, strongSelf.isNodeLoaded {
                if let message = strongSelf.chatDisplayNode.historyNode.messageInCurrentHistoryView(id) {
                    if let contextMenuController = contextMenuForChatPresentationIntefaceState(strongSelf.presentationInterfaceState, account: strongSelf.account, message: message, interfaceInteraction: strongSelf.interfaceInteraction) {
                        if let controllerInteraction = strongSelf.controllerInteraction {
                            controllerInteraction.highlightedState = ChatInterfaceHighlightedState(messageStableId: message.stableId)
                            strongSelf.updateItemNodesHighlightedStates(animated: true)
                        }
                        
                        contextMenuController.dismissed = {
                            if let strongSelf = self, let controllerInteraction = strongSelf.controllerInteraction {
                                if controllerInteraction.highlightedState?.messageStableId == message.stableId {
                                    controllerInteraction.highlightedState = nil
                                    strongSelf.updateItemNodesHighlightedStates(animated: true)
                                }
                            }
                        }
                        
                        strongSelf.present(contextMenuController, in: .window, with: ContextMenuControllerPresentationArguments(sourceNodeAndRect: { [weak node] in
                            if let node = node {
                                return (node, frame)
                            } else {
                                return nil
                            }
                        }))
                    }
                }
            }
        }, navigateToMessage: { [weak self] fromId, id in
            self?.navigateToMessage(from: fromId, to: id)
        }, clickThroughMessage: { [weak self] in
            self?.chatDisplayNode.dismissInput()
        }, toggleMessageSelection: { [weak self] id in
            if let strongSelf = self, strongSelf.isNodeLoaded {
                if let _ = strongSelf.chatDisplayNode.historyNode.messageInCurrentHistoryView(id) {
                    strongSelf.updateChatPresentationInterfaceState(animated: false, interactive: true, { $0.updatedInterfaceState { $0.withToggledSelectedMessage(id) } })
                }
            }
        }, sendMessage: { [weak self] text in
            if let strongSelf = self {
                strongSelf.chatDisplayNode.setupSendActionOnViewUpdate({
                    if let strongSelf = self {
                        strongSelf.updateChatPresentationInterfaceState(animated: true, interactive: false, {
                            $0.updatedInterfaceState { $0.withUpdatedReplyMessageId(nil) }
                        })
                    }
                })
                var attributes: [MessageAttribute] = []
                let entities = generateTextEntities(text)
                if !entities.isEmpty {
                    attributes.append(TextEntitiesMessageAttribute(entities: entities))
                }
                let _ = enqueueMessages(account: strongSelf.account, peerId: strongSelf.peerId, messages: [.message(text: text, attributes: attributes, media: nil, replyToMessageId: strongSelf.presentationInterfaceState.interfaceState.replyMessageId)]).start()
            }
        }, sendSticker: { [weak self] file in
            if let strongSelf = self {
                strongSelf.chatDisplayNode.setupSendActionOnViewUpdate({
                    if let strongSelf = self {
                        strongSelf.updateChatPresentationInterfaceState(animated: true, interactive: false, {
                            $0.updatedInterfaceState { $0.withUpdatedReplyMessageId(nil) }
                        })
                    }
                })
                let _ = enqueueMessages(account: strongSelf.account, peerId: strongSelf.peerId, messages: [.message(text: "", attributes: [], media: file, replyToMessageId: strongSelf.presentationInterfaceState.interfaceState.replyMessageId)]).start()
            }
        }, requestMessageActionCallback: { [weak self] messageId, data, isGame in
            if let strongSelf = self {
                strongSelf.updateChatPresentationInterfaceState(animated: true, interactive: true, {
                    return $0.updatedTitlePanelContext {
                        if !$0.contains(where: {
                            switch $0 {
                                case .requestInProgress:
                                    return true
                                default:
                                    return false
                            }
                        }) {
                            var updatedContexts = $0
                            updatedContexts.append(.requestInProgress)
                            return updatedContexts.sorted()
                        }
                        return $0
                    }
                })
                
                strongSelf.messageActionCallbackDisposable.set((requestMessageActionCallback(account: strongSelf.account, messageId: messageId, isGame: isGame, data: data) |> afterDisposed {
                    Queue.mainQueue().async {
                        if let strongSelf = self {
                            strongSelf.updateChatPresentationInterfaceState(animated: true, interactive: true, {
                                return $0.updatedTitlePanelContext {
                                    if let index = $0.index(where: {
                                        switch $0 {
                                            case .requestInProgress:
                                                return true
                                            default:
                                                return false
                                        }
                                    }) {
                                        var updatedContexts = $0
                                        updatedContexts.remove(at: index)
                                        return updatedContexts
                                    }
                                    return $0
                                }
                            })
                        }
                    }
                }).start(next: { result in
                    if let strongSelf = self {
                        switch result {
                            case .none:
                                break
                            case let .alert(text):
                                let message: Signal<String?, NoError> = .single(text)
                                let noMessage: Signal<String?, NoError> = .single(nil)
                                let delayedNoMessage: Signal<String?, NoError> = noMessage |> delay(1.0, queue: Queue.mainQueue())
                                strongSelf.botCallbackAlertMessage.set(message |> then(delayedNoMessage))
                            case let .url(url):
                                strongSelf.openUrl(url)
                        }
                    }
                }))
            }
        }, openUrl: { [weak self] url in
            if let strongSelf = self {
                strongSelf.openUrl(url)
            }
        }, shareCurrentLocation: { [weak self] in
            if let strongSelf = self {
                
            }
        }, shareAccountContact: { [weak self] in
            if let strongSelf = self {
                
            }
        }, sendBotCommand: { [weak self] messageId, command in
            if let strongSelf = self {
                strongSelf.chatDisplayNode.setupSendActionOnViewUpdate({})
                var postAsReply = false
                if !command.contains("@") && (strongSelf.peerId.namespace == Namespaces.Peer.CloudChannel || strongSelf.peerId.namespace == Namespaces.Peer.CloudGroup) {
                    postAsReply = true
                }
                strongSelf.chatDisplayNode.setupSendActionOnViewUpdate({
                    if let strongSelf = self {
                        strongSelf.updateChatPresentationInterfaceState(animated: true, interactive: false, {
                            $0.updatedInterfaceState { $0.withUpdatedReplyMessageId(nil).withUpdatedComposeInputState(ChatTextInputState(inputText: "")).withUpdatedComposeDisableUrlPreview(nil) }
                        })
                    }
                })
                var attributes: [MessageAttribute] = []
                let entities = generateTextEntities(command)
                if !entities.isEmpty {
                    attributes.append(TextEntitiesMessageAttribute(entities: entities))
                }
                let _ = enqueueMessages(account: strongSelf.account, peerId: strongSelf.peerId, messages: [.message(text: command, attributes: attributes, media: nil, replyToMessageId: (postAsReply && messageId != nil) ? messageId! : nil)]).start()
            }
        }, openInstantPage: { [weak self] messageId in
            if let strongSelf = self, strongSelf.isNodeLoaded {
                if let message = strongSelf.chatDisplayNode.historyNode.messageInCurrentHistoryView(messageId) {
                    for media in message.media {
                        if let webpage = media as? TelegramMediaWebpage, case let .Loaded(content) = webpage.content {
                            if let _ = content.instantPage {
                                let pageController = InstantPageController(account: strongSelf.account, webPage: webpage)
                                (strongSelf.navigationController as? NavigationController)?.pushViewController(pageController)
                            }
                            break
                        }
                    }
                }
            }
        }, openHashtag: { [weak self] peerName, hashtag in
            if let strongSelf = self, !hashtag.isEmpty {
                let searchController = HashtagSearchController(account: strongSelf.account, peerName: peerName, query: hashtag)
                (strongSelf.navigationController as? NavigationController)?.pushViewController(searchController)
            }
        }, updateInputState: { [weak self] f in
            if let strongSelf = self {
                strongSelf.updateChatPresentationInterfaceState(animated: true, interactive: true, {
                    return $0.updatedInterfaceState {
                        return $0.withUpdatedEffectiveInputState(f($0.effectiveInputState))
                    }
                })
            }
        })
        
        self.controllerInteraction = controllerInteraction
        
        self.chatTitleView = ChatTitleView(frame: CGRect())
        self.navigationItem.titleView = self.chatTitleView
        self.chatTitleView?.pressed = { [weak self] in
            if let strongSelf = self {
                strongSelf.updateChatPresentationInterfaceState(animated: true, interactive: true, {
                    return $0.updatedTitlePanelContext {
                        if let index = $0.index(where: {
                            switch $0 {
                                case .chatInfo:
                                    return true
                                default:
                                    return false
                            }
                        }) {
                            var updatedContexts = $0
                            updatedContexts.remove(at: index)
                            return updatedContexts
                        } else {
                            var updatedContexts = $0
                            updatedContexts.append(.chatInfo)
                            return updatedContexts.sorted()
                        }
                    }
                })
            }
        }
        
        let chatInfoButtonItem = UIBarButtonItem(customDisplayNode: ChatAvatarNavigationNode())!
        chatInfoButtonItem.target = self
        chatInfoButtonItem.action = #selector(self.rightNavigationButtonAction)
        self.chatInfoNavigationButton = ChatNavigationButton(action: .openChatInfo, buttonItem: chatInfoButtonItem)
        
        self.updateChatPresentationInterfaceState(animated: false, interactive: false, { state in
            if let botStart = botStart, case .interactive = botStart.behavior {
                return state.updatedBotStartPayload(botStart.payload)
            } else {
                return state
            }
        })
        
        self.peerView.set(account.viewTracker.peerView(peerId))
        
        peerDisposable.set((self.peerView.get()
            |> deliverOnMainQueue).start(next: { [weak self] peerView in
                if let strongSelf = self {
                    if let peer = peerViewMainPeer(peerView) {
                        strongSelf.chatTitleView?.peerView = peerView
                        (strongSelf.chatInfoNavigationButton?.buttonItem.customDisplayNode as? ChatAvatarNavigationNode)?.avatarNode.setPeer(account: strongSelf.account, peer: peer)
                    }
                    strongSelf.updateChatPresentationInterfaceState(animated: false, interactive: false, { return $0.updatedPeer { _ in return peerView.peers[peerId] } })
                    if !strongSelf.didSetPeerReady {
                        strongSelf.didSetPeerReady = true
                        strongSelf._peerReady.set(.single(true))
                    }
                }
            }))
        
        botCallbackAlertMessageDisposable = (self.botCallbackAlertMessage.get()
            |> deliverOnMainQueue).start(next: { [weak self] message in
                if let strongSelf = self {
                    strongSelf.updateChatPresentationInterfaceState(animated: true, interactive: false, {
                        return $0.updatedTitlePanelContext {
                            if let message = message {
                                if let index = $0.index(where: {
                                    switch $0 {
                                        case .toastAlert:
                                            return true
                                        default:
                                            return false
                                    }
                                }) {
                                    if $0[index] != ChatTitlePanelContext.toastAlert(message) {
                                        var updatedContexts = $0
                                        updatedContexts[index] = .toastAlert(message)
                                        return updatedContexts
                                    } else {
                                        return $0
                                    }
                                } else {
                                    var updatedContexts = $0
                                    updatedContexts.append(.toastAlert(message))
                                    return updatedContexts.sorted()
                                }
                            } else {
                                if let index = $0.index(where: {
                                    switch $0 {
                                        case .toastAlert:
                                            return true
                                        default:
                                            return false
                                    }
                                }) {
                                    var updatedContexts = $0
                                    updatedContexts.remove(at: index)
                                    return updatedContexts
                                } else {
                                    return $0
                                }
                            }
                        }
                    })
                }
            })
        
        self.audioRecorderDisposable = (self.audioRecorder.get() |> deliverOnMainQueue).start(next: { [weak self] audioRecorder in
            if let strongSelf = self {
                if strongSelf.audioRecorderValue !== audioRecorder {
                    strongSelf.audioRecorderValue = audioRecorder
                    
                    strongSelf.updateChatPresentationInterfaceState(animated: true, interactive: true, {
                        $0.updatedInputTextPanelState { panelState in
                            if let audioRecorder = audioRecorder {
                                if panelState.audioRecordingState == nil {
                                    return panelState.withUpdatedAudioRecordingState(ChatTextInputPanelAudioRecordingState(recorder: audioRecorder))
                                }
                            } else {
                                return panelState.withUpdatedAudioRecordingState(nil)
                            }
                            return panelState
                        }
                    })
                    
                    if let audioRecorder = audioRecorder {
                        audioRecorder.start()
                    }
                }
            }
        })
        
        if let botStart = botStart, case .automatic = botStart.behavior {
            self.startBot(botStart.payload)
        }
        
        self.typingActivityDisposable = (self.typingActivityPromise.get()
            |> deliverOnMainQueue).start(next: { [weak self] value in
                if let strongSelf = self {
                    strongSelf.account.updateLocalInputActivity(peerId: strongSelf.peerId, activity: .typingText, isPresent: value)
                }
            })
    }
    
    required public init(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    deinit {
        self.historyStateDisposable?.dispose()
        self.messageIndexDisposable.dispose()
        self.navigationActionDisposable.dispose()
        self.galleryHiddenMesageAndMediaDisposable.dispose()
        self.peerDisposable.dispose()
        self.messageContextDisposable.dispose()
        self.controllerNavigationDisposable.dispose()
        self.sentMessageEventsDisposable.dispose()
        self.messageActionCallbackDisposable.dispose()
        self.editMessageDisposable.dispose()
        self.enqueueMediaMessageDisposable.dispose()
        self.resolvePeerByNameDisposable?.dispose()
        self.botCallbackAlertMessageDisposable?.dispose()
        self.contextQueryState?.1.dispose()
        self.urlPreviewQueryState?.1.dispose()
        self.audioRecorderDisposable?.dispose()
        self.buttonKeyboardMessageDisposable?.dispose()
        self.cachedDataDisposable?.dispose()
        self.resolveUrlDisposable?.dispose()
        self.chatUnreadCountDisposable?.dispose()
        self.peerInputActivitiesDisposable?.dispose()
        self.recentlyUsedInlineBotsDisposable?.dispose()
        self.unpinMessageDisposable?.dispose()
        self.typingActivityDisposable?.dispose()
    }
    
    var chatDisplayNode: ChatControllerNode {
        get {
            return super.displayNode as! ChatControllerNode
        }
    }
    
    override public func loadDisplayNode() {
        self.displayNode = ChatControllerNode(account: self.account, peerId: self.peerId, messageId: self.messageId, controllerInteraction: self.controllerInteraction!)
        
        let initialData = self.chatDisplayNode.historyNode.initialData
            |> take(1)
            |> beforeNext { [weak self] combinedInitialData in
                if let strongSelf = self, let combinedInitialData = combinedInitialData {
                    if let interfaceState = combinedInitialData.initialData?.chatInterfaceState as? ChatInterfaceState {
                        var pinnedMessageId: MessageId?
                        var peerIsBlocked: Bool = false
                        var canReport: Bool = false
                        if let cachedData = combinedInitialData.cachedData as? CachedChannelData {
                            pinnedMessageId = cachedData.pinnedMessageId
                            canReport = cachedData.reportStatus == .canReport
                        } else if let cachedData = combinedInitialData.cachedData as? CachedUserData {
                            peerIsBlocked = cachedData.isBlocked
                            canReport = cachedData.reportStatus == .canReport
                        } else if let cachedData = combinedInitialData.cachedData as? CachedGroupData {
                            canReport = cachedData.reportStatus == .canReport
                        }
                        strongSelf.updateChatPresentationInterfaceState(animated: false, interactive: false, { $0.updatedInterfaceState({ _ in return interfaceState }).updatedKeyboardButtonsMessage(combinedInitialData.buttonKeyboardMessage).updatedPinnedMessageId(pinnedMessageId).updatedPeerIsBlocked(peerIsBlocked).updatedCanReportPeer(canReport).updatedTitlePanelContext({ context in
                                if pinnedMessageId != nil {
                                    if !context.contains(where: {
                                        switch $0 {
                                            case .pinnedMessage:
                                                return true
                                            default:
                                                return false
                                        }
                                    }) {
                                        var updatedContexts = context
                                        updatedContexts.append(.pinnedMessage)
                                        return updatedContexts.sorted()
                                    } else {
                                        return context
                                    }
                                } else {
                                    if let index = context.index(where: {
                                        switch $0 {
                                            case .pinnedMessage:
                                                return true
                                            default:
                                                return false
                                        }
                                    }) {
                                        var updatedContexts = context
                                        updatedContexts.remove(at: index)
                                        return updatedContexts
                                    } else {
                                        return context
                                    }
                                }
                            })
                        })
                    }
                }
            }
        
        self.buttonKeyboardMessageDisposable = self.chatDisplayNode.historyNode.buttonKeyboardMessage.start(next: { [weak self] message in
            if let strongSelf = self {
                var buttonKeyboardMessageUpdated = false
                if let currentButtonKeyboardMessage = strongSelf.presentationInterfaceState.keyboardButtonsMessage, let message = message {
                    if currentButtonKeyboardMessage.id != message.id || currentButtonKeyboardMessage.stableVersion != message.stableVersion {
                        buttonKeyboardMessageUpdated = true
                    }
                } else if (strongSelf.presentationInterfaceState.keyboardButtonsMessage != nil) != (message != nil) {
                    buttonKeyboardMessageUpdated = true
                }
                if buttonKeyboardMessageUpdated {
                    strongSelf.updateChatPresentationInterfaceState(animated: true, interactive: true, { $0.updatedKeyboardButtonsMessage(message) })
                }
            }
        })
        
        self.cachedDataDisposable = self.chatDisplayNode.historyNode.cachedPeerData.start(next: { [weak self] cachedData in
            if let strongSelf = self {
                var pinnedMessageId: MessageId?
                var peerIsBlocked: Bool = false
                var canReport: Bool = false
                if let cachedData = cachedData as? CachedChannelData {
                    pinnedMessageId = cachedData.pinnedMessageId
                    canReport = cachedData.reportStatus == .canReport
                } else if let cachedData = cachedData as? CachedUserData {
                    peerIsBlocked = cachedData.isBlocked
                    canReport = cachedData.reportStatus == .canReport
                } else if let cachedData = cachedData as? CachedGroupData {
                    canReport = cachedData.reportStatus == .canReport
                }
                if strongSelf.presentationInterfaceState.pinnedMessageId != pinnedMessageId || strongSelf.presentationInterfaceState.peerIsBlocked != peerIsBlocked || strongSelf.presentationInterfaceState.canReportPeer != canReport {
                    strongSelf.updateChatPresentationInterfaceState(animated: true, interactive: true, { state in
                        return state.updatedPinnedMessageId(pinnedMessageId).updatedPeerIsBlocked(peerIsBlocked).updatedCanReportPeer(canReport).updatedTitlePanelContext({ context in
                            if pinnedMessageId != nil {
                                if !context.contains(where: {
                                    switch $0 {
                                        case .pinnedMessage:
                                            return true
                                        default:
                                            return false
                                    }
                                }) {
                                    var updatedContexts = context
                                    updatedContexts.append(.pinnedMessage)
                                    return updatedContexts.sorted()
                                } else {
                                    return context
                                }
                            } else {
                                if let index = context.index(where: {
                                    switch $0 {
                                        case .pinnedMessage:
                                            return true
                                        default:
                                            return false
                                    }
                                }) {
                                    var updatedContexts = context
                                    updatedContexts.remove(at: index)
                                    return updatedContexts
                                } else {
                                    return context
                                }
                            }
                        })
                    })
                }
            }
        })
        
        self.historyStateDisposable = self.chatDisplayNode.historyNode.historyState.get().start(next: { [weak self] state in
            if let strongSelf = self {
                strongSelf.updateChatPresentationInterfaceState(animated: true, interactive: true, {
                    $0.updatedChatHistoryState(state)
                })
            }
        })
        
        self.ready.set(combineLatest(self.chatDisplayNode.historyNode.historyState.get(), self._peerReady.get(), initialData) |> map { _, peerReady, _ in
            return peerReady
        })
        
        self.chatDisplayNode.historyNode.visibleContentOffsetChanged = { [weak self] offset in
            if let strongSelf = self {
                let offsetAlpha: CGFloat
                switch offset {
                    case let .known(offset):
                        if offset < 40.0 {
                            offsetAlpha = 0.0
                        } else {
                            offsetAlpha = 1.0
                        }
                    case .unknown:
                        offsetAlpha = 1.0
                    case .none:
                        offsetAlpha = 0.0
                }
                
                if !strongSelf.chatDisplayNode.navigateToLatestButton.alpha.isEqual(to: offsetAlpha) {
                    UIView.animate(withDuration: 0.2, delay: 0.0, options: [.beginFromCurrentState], animations: {
                        strongSelf.chatDisplayNode.navigateToLatestButton.alpha = offsetAlpha
                    }, completion: nil)
                }
            }
        }
        
        self.chatDisplayNode.historyNode.maxVisibleMessageIndexUpdated = { [weak self] index in
            if let strongSelf = self, !strongSelf.historyNavigationStack.isEmpty {
                strongSelf.historyNavigationStack.filterOutIndicesLessThan(index)
            }
        }
        
        self.chatDisplayNode.requestLayout = { [weak self] transition in
            self?.requestLayout(transition: transition)
        }
        
        self.chatDisplayNode.setupSendActionOnViewUpdate = { [weak self] f in
            self?.chatDisplayNode.historyNode.layoutActionOnViewTransition = { [weak self] transition in
                f()
                if let strongSelf = self {
                    var mappedTransition: (ChatHistoryListViewTransition, ListViewUpdateSizeAndInsets?)?
                    
                    strongSelf.chatDisplayNode.containerLayoutUpdated(strongSelf.containerLayout, navigationBarHeight: strongSelf.navigationBar.frame.maxY, transition: .animated(duration: 0.4, curve: .spring), listViewTransaction: { updateSizeAndInsets in
                        var options = transition.options
                        let _ = options.insert(.Synchronous)
                        let _ = options.insert(.LowLatency)
                        options.remove(.AnimateInsertion)
                        options.insert(.RequestItemInsertionAnimations)
                        
                        let deleteItems = transition.deleteItems.map({ item in
                            return ListViewDeleteItem(index: item.index, directionHint: nil)
                        })
                        
                        var maxInsertedItem: Int?
                        var insertItems: [ListViewInsertItem] = []
                        for i in 0 ..< transition.insertItems.count {
                            let item = transition.insertItems[i]
                            if item.directionHint == .Down && (maxInsertedItem == nil || maxInsertedItem! < item.index) {
                                maxInsertedItem = item.index
                            }
                            insertItems.append(ListViewInsertItem(index: item.index, previousIndex: item.previousIndex, item: item.item, directionHint: item.directionHint == .Down ? .Up : nil))
                        }
                        
                        let scrollToItem = ListViewScrollToItem(index: 0, position: .Top, animated: true, curve: .Spring(duration: 0.4), directionHint: .Up)
                        
                        var stationaryItemRange: (Int, Int)?
                        if let maxInsertedItem = maxInsertedItem {
                            stationaryItemRange = (maxInsertedItem + 1, Int.max)
                        }
                        
                        mappedTransition = (ChatHistoryListViewTransition(historyView: transition.historyView, deleteItems: deleteItems, insertItems: insertItems, updateItems: transition.updateItems, options: options, scrollToItem: scrollToItem, stationaryItemRange: stationaryItemRange, initialData: transition.initialData, keyboardButtonsMessage: transition.keyboardButtonsMessage, cachedData: transition.cachedData), updateSizeAndInsets)
                    })
                    
                    if let mappedTransition = mappedTransition {
                        return mappedTransition
                    }
                }
                return (transition, nil)
            }
        }
        
        self.chatDisplayNode.requestUpdateChatInterfaceState = { [weak self] animated, f in
            self?.updateChatPresentationInterfaceState(animated: animated,  interactive: true, { $0.updatedInterfaceState(f) })
        }
        
        self.chatDisplayNode.displayAttachmentMenu = { [weak self] in
            if let strongSelf = self {
                if true {
                    strongSelf.chatDisplayNode.dismissInput()
                    
                    let emptyController = LegacyEmptyController()
                    let navigationController = makeLegacyNavigationController(rootController: emptyController)
                    navigationController.setNavigationBarHidden(true, animated: false)
                    
                    let legacyController = LegacyController(legacyController: navigationController, presentation: .custom)
                    
                    var presentOverlayController: ((UIViewController) -> (() -> Void))?
                    let controller = legacyAttachmentMenu(parentController: legacyController, recentlyUsedInlineBots: strongSelf.recentlyUsedInlineBotsValue, presentOverlayController: { controller in
                        if let presentOverlayController = presentOverlayController {
                            return presentOverlayController(controller)
                        } else {
                            return {
                            }
                        }
                    }, openGallery: {
                        self?.presentMediaPicker(fileMode: false)
                    }, openCamera: { cameraView, menuController in
                        if let strongSelf = self {
                            presentedLegacyCamera(cameraView: cameraView, menuController: menuController, parentController: strongSelf, sendMessagesWithSignals: { signals in
                                self?.enqueueMediaMessages(signals: signals)
                            })
                        }
                    }, openFileGallery: {
                        self?.presentMediaPicker(fileMode: true)
                    }, openMap: {
                        
                    }, openContacts: {
                        if let strongSelf = self {
                            let contactsController = ContactSelectionController(account: strongSelf.account, title: "Select Contact")
                            strongSelf.present(contactsController, in: .window, with: ViewControllerPresentationArguments(presentationAnimation: .modalSheet))
                            strongSelf.controllerNavigationDisposable.set((contactsController.result |> deliverOnMainQueue).start(next: { peerId in
                                if let strongSelf = self, let peerId = peerId {
                                    let peer = strongSelf.account.postbox.loadedPeerWithId(peerId)
                                        |> take(1)
                                    strongSelf.controllerNavigationDisposable.set((peer |> deliverOnMainQueue).start(next: { peer in
                                        if let strongSelf = self, let user = peer as? TelegramUser, let phone = user.phone, !phone.isEmpty {
                                            let media = TelegramMediaContact(firstName: user.firstName ?? "", lastName: user.lastName ?? "", phoneNumber: phone, peerId: user.id)
                                            let replyMessageId = strongSelf.presentationInterfaceState.interfaceState.replyMessageId
                                            strongSelf.chatDisplayNode.setupSendActionOnViewUpdate({
                                                if let strongSelf = self {
                                                    strongSelf.updateChatPresentationInterfaceState(animated: true, interactive: false, {
                                                        $0.updatedInterfaceState { $0.withUpdatedReplyMessageId(nil) }
                                                    })
                                                }
                                            })
                                            let message = EnqueueMessage.message(text: "", attributes: [], media: media, replyToMessageId: replyMessageId)
                                            let _ = enqueueMessages(account: strongSelf.account, peerId: strongSelf.peerId, messages: [message]).start()
                                        }
                                    }))
                                }
                            }))
                        }
                    }, sendMessagesWithSignals: { [weak self] signals in
                        self?.enqueueMediaMessages(signals: signals)
                    }, selectRecentlyUsedInlineBot: { [weak self] peer in
                        if let strongSelf = self, let addressName = peer.addressName {
                            strongSelf.updateChatPresentationInterfaceState(animated: true, interactive: false, {
                                $0.updatedInterfaceState({ $0.withUpdatedComposeInputState(ChatTextInputState(inputText: "@" + addressName + " ")) }).updatedInputMode({ _ in
                                    return .text
                                })
                            })
                        }
                    })
                    controller.applicationInterface = legacyController.applicationInterface
                    controller.didDismiss = { [weak legacyController] _ in
                        legacyController?.dismiss()
                    }
                    
                    strongSelf.present(legacyController, in: .window)
                    controller.present(in: emptyController, sourceView: nil, animated: true)
                    
                    presentOverlayController = { [weak legacyController] controller in
                        if let legacyController = legacyController {
                            let childController = LegacyController(legacyController: controller, presentation: .custom)
                            legacyController.present(childController, in: .window)
                            return { [weak childController] in
                                childController?.dismiss()
                            }
                        } else {
                            return {
                            }
                        }
                    }
                    
                    return
                }
            }
        }
        
        self.chatDisplayNode.updateTypingActivity = { [weak self] in
            if let strongSelf = self {
                strongSelf.typingActivityPromise.set(Signal<Bool, NoError>.single(true) |> then(Signal<Bool, NoError>.single(false) |> delay(4.0, queue: Queue.mainQueue())))
            }
        }
        
        self.chatDisplayNode.dismissUrlPreview = { [weak self] in
            if let strongSelf = self {
                if let (link, _) = strongSelf.presentationInterfaceState.urlPreview {
                    strongSelf.updateChatPresentationInterfaceState(animated: true, interactive: true, {
                        $0.updatedInterfaceState {
                            $0.withUpdatedComposeDisableUrlPreview(link)
                        }
                    })
                }
            }
        }
        
        self.chatDisplayNode.navigateToLatestButton.tapped = { [weak self] in
            if let strongSelf = self, strongSelf.isNodeLoaded {
                if let messageId = strongSelf.historyNavigationStack.removeLast() {
                    strongSelf.navigateToMessage(from: nil, to: messageId.id, rememberInStack: false)
                } else {
                    strongSelf.chatDisplayNode.historyNode.scrollToEndOfHistory()
                }
            }
        }
        
        let interfaceInteraction = ChatPanelInterfaceInteraction(setupReplyMessage: { [weak self] messageId in
            if let strongSelf = self, strongSelf.isNodeLoaded {
                if let message = strongSelf.chatDisplayNode.historyNode.messageInCurrentHistoryView(messageId) {
                    strongSelf.updateChatPresentationInterfaceState(animated: true, interactive: true, { $0.updatedInterfaceState { $0.withUpdatedReplyMessageId(message.id) } })
                    strongSelf.chatDisplayNode.ensureInputViewFocused()
                }
            }
        }, setupEditMessage: { [weak self] messageId in
            if let strongSelf = self, strongSelf.isNodeLoaded {
                if let message = strongSelf.chatDisplayNode.historyNode.messageInCurrentHistoryView(messageId) {
                    strongSelf.updateChatPresentationInterfaceState(animated: true, interactive: true, { $0.updatedInterfaceState { $0.withUpdatedEditMessage(ChatEditMessageState(messageId: messageId, inputState: ChatTextInputState(inputText: message.text))) } })
                    strongSelf.chatDisplayNode.ensureInputViewFocused()
                }
            }
        }, beginMessageSelection: { [weak self] messageId in
            if let strongSelf = self, strongSelf.isNodeLoaded {
                if let message = strongSelf.chatDisplayNode.historyNode.messageInCurrentHistoryView(messageId) {
                    strongSelf.updateChatPresentationInterfaceState(animated: true, interactive: true,{ $0.updatedInterfaceState { $0.withUpdatedSelectedMessage(message.id) } })
                }
            }
        }, deleteSelectedMessages: { [weak self] in
            if let strongSelf = self {
                if let messageIds = strongSelf.presentationInterfaceState.interfaceState.selectionState?.selectedIds, !messageIds.isEmpty {
                    strongSelf.messageContextDisposable.set((chatDeleteMessagesOptions(account: strongSelf.account, messageIds: messageIds) |> deliverOnMainQueue).start(next: { options in
                        if let strongSelf = self, !options.isEmpty {
                            let actionSheet = ActionSheetController()
                            var items: [ActionSheetItem] = []
                            var personalPeerName: String?
                            var isChannel = false
                            if let user = strongSelf.presentationInterfaceState.peer as? TelegramUser {
                                personalPeerName = user.compactDisplayTitle
                            } else if let channel = strongSelf.presentationInterfaceState.peer as? TelegramChannel, case .broadcast = channel.info {
                                isChannel = true
                            }
                            
                            if options.contains(.globally) {
                                let globalTitle: String
                                if isChannel {
                                    globalTitle = "Delete"
                                } else if let personalPeerName = personalPeerName {
                                    globalTitle = "Delete for me and \(personalPeerName)"
                                } else {
                                    globalTitle = "Delete for everyone"
                                }
                                items.append(ActionSheetButtonItem(title: globalTitle, color: .destructive, action: { [weak actionSheet] in
                                    actionSheet?.dismissAnimated()
                                    if let strongSelf = self {
                                        strongSelf.updateChatPresentationInterfaceState(animated: true, interactive: true, { $0.updatedInterfaceState { $0.withoutSelectionState() } })
                                        let _ = deleteMessagesInteractively(postbox: strongSelf.account.postbox, messageIds: Array(messageIds), type: .forEveryone).start()
                                    }
                                }))
                            }
                            if options.contains(.locally) {
                                items.append(ActionSheetButtonItem(title: "Delete for me", color: .destructive, action: { [weak actionSheet] in
                                    actionSheet?.dismissAnimated()
                                    if let strongSelf = self {
                                        strongSelf.updateChatPresentationInterfaceState(animated: true, interactive: true, { $0.updatedInterfaceState { $0.withoutSelectionState() } })
                                        let _ = deleteMessagesInteractively(postbox: strongSelf.account.postbox, messageIds: Array(messageIds), type: .forLocalPeer).start()
                                    }
                                }))
                            }
                            actionSheet.setItemGroups([ActionSheetItemGroup(items: items), ActionSheetItemGroup(items: [
                                    ActionSheetButtonItem(title: "Cancel", color: .accent, action: { [weak actionSheet] in
                                        actionSheet?.dismissAnimated()
                                })
                            ])])
                            strongSelf.present(actionSheet, in: .window)
                        }
                    }))
                }
            }
        }, forwardSelectedMessages: { [weak self] in
            if let strongSelf = self {
                //let controller = ShareRecipientsActionSheetController()
                //strongSelf.present(controller, in: .window)
                
                if let forwardMessageIdsSet = strongSelf.presentationInterfaceState.interfaceState.selectionState?.selectedIds {
                    let forwardMessageIds = Array(forwardMessageIdsSet).sorted()
                    
                    let controller = PeerSelectionController(account: strongSelf.account)
                    controller.peerSelected = { [weak controller] peerId in
                        if let strongSelf = self, let strongController = controller {
                            if peerId == strongSelf.peerId {
                                strongSelf.updateChatPresentationInterfaceState(animated: false, interactive: true, { $0.updatedInterfaceState({ $0.withUpdatedForwardMessageIds(forwardMessageIds).withoutSelectionState() }) })
                                strongController.dismiss()
                            } else {
                                let _ = (strongSelf.account.postbox.modify({ modifier -> Void in
                                    modifier.updatePeerChatInterfaceState(peerId, update: { currentState in
                                        if let currentState = currentState as? ChatInterfaceState {
                                            return currentState.withUpdatedForwardMessageIds(forwardMessageIds)
                                        } else {
                                            return ChatInterfaceState().withUpdatedForwardMessageIds(forwardMessageIds)
                                        }
                                    })
                                }) |> deliverOnMainQueue).start(completed: {
                                    if let strongSelf = self {
                                        strongSelf.updateChatPresentationInterfaceState(animated: false, interactive: true, { $0.updatedInterfaceState({ $0.withoutSelectionState() }) })
                                        
                                        let ready = ValuePromise<Bool>()
                                        
                                        strongSelf.controllerNavigationDisposable.set((ready.get() |> take(1) |> deliverOnMainQueue).start(next: { _ in
                                            if let strongController = controller {
                                                strongController.dismiss()
                                            }
                                        }))
                                        
                                        (strongSelf.navigationController as? NavigationController)?.replaceTopController(ChatController(account: strongSelf.account, peerId: peerId), animated: false, ready: ready)
                                    }
                                })
                            }
                        }
                    }
                    strongSelf.present(controller, in: .window)
                }
            }
        }, updateTextInputState: { [weak self] f in
            if let strongSelf = self {
                strongSelf.updateChatPresentationInterfaceState(animated: true, interactive: true, { $0.updatedInterfaceState { $0.withUpdatedEffectiveInputState(f($0.effectiveInputState)) } })
            }
        }, updateInputModeAndDismissedButtonKeyboardMessageId: { [weak self] f in
            if let strongSelf = self {
                strongSelf.updateChatPresentationInterfaceState(animated: true, interactive: true, {
                    let (updatedInputMode, updatedClosedButtonKeyboardMessageId) = f($0)
                    return $0.updatedInputMode({ _ in return updatedInputMode }).updatedInterfaceState({ $0.withUpdatedMessageActionsState({ $0.withUpdatedClosedButtonKeyboardMessageId(updatedClosedButtonKeyboardMessageId) }) })
                })
            }
        }, editMessage: { [weak self] messageId, text in
            if let strongSelf = self {
                let editingMessage = strongSelf.editingMessage
                editingMessage.set(true)
                strongSelf.editMessageDisposable.set((requestEditMessage(account: strongSelf.account, messageId: messageId, text: text) |> deliverOnMainQueue |> afterDisposed({
                        editingMessage.set(false)
                    })).start(completed: {
                    if let strongSelf = self {
                        strongSelf.updateChatPresentationInterfaceState(animated: true, interactive: true, { $0.updatedInterfaceState({ $0.withUpdatedEditMessage(nil) }) })
                    }
                }))
            }
        }, beginMessageSearch: { [weak self] in
            if let strongSelf = self {
                
            }
        }, navigateToMessage: { [weak self] messageId in
            self?.navigateToMessage(from: nil, to: messageId)
        }, openPeerInfo: { [weak self] in
            self?.navigationButtonAction(.openChatInfo)
        }, togglePeerNotifications: {
            
        }, sendContextResult: { [weak self] results, result in
            self?.enqueueChatContextResult(results, result)
        }, sendBotCommand: { [weak self] botPeer, command in
            if let strongSelf = self {
                if let peer = strongSelf.presentationInterfaceState.peer, let addressName = botPeer.addressName {
                    let messageText: String
                    if peer is TelegramUser {
                        messageText = command
                    } else {
                        messageText = command + "@" + addressName
                    }
                    let replyMessageId = strongSelf.presentationInterfaceState.interfaceState.replyMessageId
                    strongSelf.chatDisplayNode.setupSendActionOnViewUpdate({
                        if let strongSelf = self {
                            strongSelf.updateChatPresentationInterfaceState(animated: true, interactive: false, {
                                $0.updatedInterfaceState { $0.withUpdatedReplyMessageId(nil).withUpdatedComposeInputState(ChatTextInputState(inputText: "")).withUpdatedComposeDisableUrlPreview(nil) }
                            })
                        }
                    })
                    var attributes: [MessageAttribute] = []
                    let entities = generateTextEntities(messageText)
                    if !entities.isEmpty {
                        attributes.append(TextEntitiesMessageAttribute(entities: entities))
                    }
                    let _ = enqueueMessages(account: strongSelf.account, peerId: strongSelf.peerId, messages: [.message(text: messageText, attributes: attributes, media: nil, replyToMessageId: replyMessageId)]).start()
                }
            }
        }, sendBotStart: { [weak self] payload in
            if let strongSelf = self {
                strongSelf.startBot(payload)
            }
        }, botSwitchChatWithPayload: { [weak self] peerId, payload in
            if let strongSelf = self {
                strongSelf.openPeer(peerId: peerId, navigation: .withBotStartPayload(ChatControllerInitialBotStart(payload: payload, behavior: .automatic(returnToPeerId: strongSelf.peerId))), fromMessageId: nil)
            }
        }, beginAudioRecording: { [weak self] in
            self?.requestAudioRecorder()
        }, finishAudioRecording: { [weak self] sendAudio in
            self?.dismissAudioRecorder(sendAudio: sendAudio)
        }, setupMessageAutoremoveTimeout: { [weak self] in
            if let strongSelf = self, strongSelf.peerId.namespace == Namespaces.Peer.SecretChat {
                strongSelf.chatDisplayNode.dismissInput()
                
                if let peer = strongSelf.presentationInterfaceState.peer as? TelegramSecretChat {
                    let controller = ChatSecretAutoremoveTimerActionSheetController(currentValue: peer.messageAutoremoveTimeout == nil ? 0 : peer.messageAutoremoveTimeout!, applyValue: { value in
                        if let strongSelf = self {
                            let _ = setSecretChatMessageAutoremoveTimeoutInteractively(account: strongSelf.account, peerId: strongSelf.peerId, timeout: value == 0 ? nil : value).start()
                        }
                    })
                    strongSelf.present(controller, in: .window)
                }
            }
        }, sendSticker: { [weak self] file in
            if let strongSelf = self {
                strongSelf.chatDisplayNode.setupSendActionOnViewUpdate({
                    if let strongSelf = self {
                        strongSelf.updateChatPresentationInterfaceState(animated: true, interactive: false, {
                            $0.updatedInterfaceState { $0.withUpdatedReplyMessageId(nil).withUpdatedComposeInputState(ChatTextInputState(inputText: "")).withUpdatedComposeDisableUrlPreview(nil) }
                        })
                    }
                })
                let _ = enqueueMessages(account: strongSelf.account, peerId: strongSelf.peerId, messages: [.message(text: "", attributes: [], media: file, replyToMessageId: strongSelf.presentationInterfaceState.interfaceState.replyMessageId)]).start()
            }
        }, unblockPeer: { [weak self] in
            self?.unblockPeer()
        }, pinMessage: { [weak self] messageId in
            if let strongSelf = self {
                if let peer = strongSelf.presentationInterfaceState.peer {
                    if let channel = peer as? TelegramChannel {
                        switch channel.role {
                            case .creator, .moderator, .editor:
                                let pinAction: (Bool) -> Void = { notify in
                                    if let strongSelf = self {
                                        let disposable: MetaDisposable
                                        if let current = strongSelf.unpinMessageDisposable {
                                            disposable = current
                                        } else {
                                            disposable = MetaDisposable()
                                            strongSelf.unpinMessageDisposable = disposable
                                        }
                                        disposable.set(requestUpdatePinnedMessage(account: strongSelf.account, peerId: strongSelf.peerId, update: .pin(id: messageId, silent: !notify)).start())
                                    }
                                }
                                strongSelf.present(standardTextAlertController(title: nil, text: "Pin this message and notify all members of the group?", actions: [TextAlertAction(type: .genericAction, title: "Only Pin", action: {
                                    pinAction(false)
                                }), TextAlertAction(type: .defaultAction, title: "Yes", action: {
                                    pinAction(true)
                                })]), in: .window)
                            case .member:
                                if let pinnedMessageId = strongSelf.presentationInterfaceState.pinnedMessageId {
                                    strongSelf.updateChatPresentationInterfaceState(animated: true, interactive: true, {
                                        return $0.updatedInterfaceState({ $0.withUpdatedMessageActionsState({ $0.withUpdatedClosedPinnedMessageId(pinnedMessageId) }) })
                                    })
                                }
                        }
                    }
                }
            }
        }, unpinMessage: { [weak self] in
            if let strongSelf = self {
                if let peer = strongSelf.presentationInterfaceState.peer {
                    if let channel = peer as? TelegramChannel {
                        switch channel.role {
                            case .creator, .moderator, .editor:
                                strongSelf.present(standardTextAlertController(title: nil, text: "Would you like to unpin this Message?", actions: [TextAlertAction(type: .genericAction, title: "No", action: {}), TextAlertAction(type: .genericAction, title: "Yes", action: {
                                    if let strongSelf = self {
                                        let disposable: MetaDisposable
                                        if let current = strongSelf.unpinMessageDisposable {
                                            disposable = current
                                        } else {
                                            disposable = MetaDisposable()
                                            strongSelf.unpinMessageDisposable = disposable
                                        }
                                        disposable.set(requestUpdatePinnedMessage(account: strongSelf.account, peerId: strongSelf.peerId, update: .clear).start())
                                    }
                                })]), in: .window)
                            case .member:
                                if let pinnedMessageId = strongSelf.presentationInterfaceState.pinnedMessageId {
                                    strongSelf.updateChatPresentationInterfaceState(animated: true, interactive: true, {
                                        return $0.updatedInterfaceState({ $0.withUpdatedMessageActionsState({ $0.withUpdatedClosedPinnedMessageId(pinnedMessageId) }) })
                                    })
                                }
                        }
                    }
                }
            }
        }, reportPeer: { [weak self] in
            self?.reportPeer()
        }, dismissReportPeer: { [weak self] in
            self?.dismissReportPeer()
        }, deleteChat: { [weak self] in
            self?.deleteChat(reportChatSpam: false)
        }, statuses: ChatPanelInterfaceInteractionStatuses(editingMessage: self.editingMessage.get(), startingBot: self.startingBot.get(), unblockingPeer: self.unblockingPeer.get()))
        
        self.chatUnreadCountDisposable = (self.account.postbox.unreadMessageCountsView(items: [.peer(self.peerId)]) |> deliverOnMainQueue).start(next: { [weak self] items in
            if let strongSelf = self {
                var unreadCount: Int32 = 0
                if let count = items.count(for: .peer(strongSelf.peerId)) {
                    unreadCount = count
                }
                if unreadCount != 0 {
                    strongSelf.chatDisplayNode.navigateToLatestButton.badge = "\(unreadCount)"
                } else {
                    strongSelf.chatDisplayNode.navigateToLatestButton.badge = ""
                }
            }
        })
        
        let postbox = self.account.postbox
        let previousPeerCache = Atomic<[PeerId: Peer]>(value: [:])
        self.peerInputActivitiesDisposable = (self.account.peerInputActivities(peerId: peerId)
            |> mapToSignal { activities -> Signal<[(Peer, PeerInputActivity)], NoError> in
                var foundAllPeers = true
                var cachedResult: [(Peer, PeerInputActivity)] = []
                previousPeerCache.with { dict -> Void in
                    for (peerId, activity) in activities {
                        if let peer = dict[peerId] {
                            cachedResult.append((peer, activity))
                        } else {
                            foundAllPeers = false
                            break
                        }
                    }
                }
                if foundAllPeers {
                    return .single(cachedResult)
                } else {
                    return postbox.modify { modifier -> [(Peer, PeerInputActivity)] in
                        var result: [(Peer, PeerInputActivity)] = []
                        var peerCache: [PeerId: Peer] = [:]
                        for (peerId, activity) in activities {
                            if let peer = modifier.getPeer(peerId) {
                                result.append((peer, activity))
                                peerCache[peerId] = peer
                            }
                        }
                        let _ = previousPeerCache.swap(peerCache)
                        return result
                    }
                }
            }
            |> deliverOnMainQueue).start(next: { [weak self] activities in
                if let strongSelf = self {
                    strongSelf.chatTitleView?.inputActivities = (strongSelf.peerId, activities)
                }
            })
        
        self.interfaceInteraction = interfaceInteraction
        self.chatDisplayNode.interfaceInteraction = interfaceInteraction
        
        self.displayNodeDidLoad()
        
        self.sentMessageEventsDisposable.set(self.account.pendingMessageManager.deliveredMessageEvents(peerId: self.peerId).start(next: { _ in
            serviceSoundManager.playMessageDeliveredSound()
        }))
    }
    
    override public func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
    }
    
    override public func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        self.chatDisplayNode.historyNode.preloadPages = true
        self.chatDisplayNode.historyNode.canReadHistory.set((self.account.applicationContext as! TelegramApplicationContext).applicationInForeground)
        
        self.chatDisplayNode.loadInputPanels()
        
        self.recentlyUsedInlineBotsDisposable = (recentlyUsedInlineBots(postbox: self.account.postbox) |> deliverOnMainQueue).start(next: { [weak self] peers in
            self?.recentlyUsedInlineBotsValue = peers
        })
    }
    
    override public func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        
        self.chatDisplayNode.historyNode.canReadHistory.set(.single(false))
        let timestamp = Int32(Date().timeIntervalSince1970)
        let interfaceState = self.presentationInterfaceState.interfaceState.withUpdatedTimestamp(timestamp)
        let _ = updatePeerChatInterfaceState(account: account, peerId: self.peerId, state: interfaceState).start()
    }
    
    override public func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        
        self.updateChatPresentationInterfaceState(animated: false, interactive: false, {
            $0.updatedTitlePanelContext {
                if let index = $0.index(where: {
                    switch $0 {
                        case .chatInfo:
                            return true
                        default:
                            return false
                    }
                }) {
                    var updatedContexts = $0
                    updatedContexts.remove(at: index)
                    return updatedContexts
                } else {
                    return $0
                }
            }
        })
    }
    
    override public func containerLayoutUpdated(_ layout: ContainerViewLayout, transition: ContainedViewLayoutTransition) {
        super.containerLayoutUpdated(layout, transition: transition)
        
        self.containerLayout = layout
        
        self.chatDisplayNode.containerLayoutUpdated(layout, navigationBarHeight: self.navigationHeight, transition: transition,  listViewTransaction: { updateSizeAndInsets in
            self.chatDisplayNode.historyNode.updateLayout(transition: transition, updateSizeAndInsets: updateSizeAndInsets)
        })
    }
    
    func updateChatPresentationInterfaceState(animated: Bool = true, interactive: Bool, _ f: (ChatPresentationInterfaceState) -> ChatPresentationInterfaceState) {
        var temporaryChatPresentationInterfaceState = f(self.presentationInterfaceState)
        
        if self.presentationInterfaceState.keyboardButtonsMessage?.visibleButtonKeyboardMarkup != temporaryChatPresentationInterfaceState.keyboardButtonsMessage?.visibleButtonKeyboardMarkup {
            if let keyboardButtonsMessage = temporaryChatPresentationInterfaceState.keyboardButtonsMessage, let _ = keyboardButtonsMessage.visibleButtonKeyboardMarkup {
                if self.presentationInterfaceState.interfaceState.editMessage == nil && self.presentationInterfaceState.interfaceState.composeInputState.inputText.isEmpty && keyboardButtonsMessage.id != temporaryChatPresentationInterfaceState.interfaceState.messageActionsState.closedButtonKeyboardMessageId && temporaryChatPresentationInterfaceState.botStartPayload == nil {
                    temporaryChatPresentationInterfaceState = temporaryChatPresentationInterfaceState.updatedInputMode({ _ in
                        return .inputButtons
                    })
                }
                
                if self.peerId.namespace == Namespaces.Peer.CloudChannel || self.peerId.namespace == Namespaces.Peer.CloudGroup {
                    if temporaryChatPresentationInterfaceState.interfaceState.replyMessageId == nil && temporaryChatPresentationInterfaceState.interfaceState.messageActionsState.processedSetupReplyMessageId != keyboardButtonsMessage.id  {
                        temporaryChatPresentationInterfaceState = temporaryChatPresentationInterfaceState.updatedInterfaceState({ $0.withUpdatedReplyMessageId(keyboardButtonsMessage.id).withUpdatedMessageActionsState({ $0.withUpdatedProcessedSetupReplyMessageId(keyboardButtonsMessage.id) }) })
                    }
                }
            } else {
                temporaryChatPresentationInterfaceState = temporaryChatPresentationInterfaceState.updatedInputMode({ mode in
                    if case .inputButtons = mode {
                        return .text
                    } else {
                        return mode
                    }
                })
            }
        }
        
        if let keyboardButtonsMessage = temporaryChatPresentationInterfaceState.keyboardButtonsMessage, keyboardButtonsMessage.requestsSetupReply {
            if temporaryChatPresentationInterfaceState.interfaceState.replyMessageId == nil && temporaryChatPresentationInterfaceState.interfaceState.messageActionsState.processedSetupReplyMessageId != keyboardButtonsMessage.id  {
                temporaryChatPresentationInterfaceState = temporaryChatPresentationInterfaceState.updatedInterfaceState({ $0.withUpdatedReplyMessageId(keyboardButtonsMessage.id).withUpdatedMessageActionsState({ $0.withUpdatedProcessedSetupReplyMessageId(keyboardButtonsMessage.id) }) })
            }
        }
        
        let inputTextPanelState = inputTextPanelStateForChatPresentationInterfaceState(temporaryChatPresentationInterfaceState, account: self.account)
        var updatedChatPresentationInterfaceState = temporaryChatPresentationInterfaceState.updatedInputTextPanelState({ _ in return inputTextPanelState })
        
        if let (updatedContextQueryState, updatedContextQuerySignal) = contextQueryResultStateForChatInterfacePresentationState(updatedChatPresentationInterfaceState, account: self.account, currentQuery: self.contextQueryState?.0) {
            self.contextQueryState?.1.dispose()
            var inScope = true
            var inScopeResult: ((ChatPresentationInputQueryResult?) -> ChatPresentationInputQueryResult?)?
            self.contextQueryState = (updatedContextQueryState, (updatedContextQuerySignal |> deliverOnMainQueue).start(next: { [weak self] result in
                if let strongSelf = self {
                    if Thread.isMainThread && inScope {
                        inScope = false
                        inScopeResult = result
                    } else {
                        strongSelf.updateChatPresentationInterfaceState(animated: true, interactive: false, {
                            $0.updatedInputQueryResult { previousResult in
                                return result(previousResult)
                            }
                        })
                    }
                }
            }))
            inScope = false
            if let inScopeResult = inScopeResult {
                updatedChatPresentationInterfaceState = updatedChatPresentationInterfaceState.updatedInputQueryResult { previousResult in
                    return inScopeResult(previousResult)
                }
            }
        }
        
        if let (updatedUrlPreviewUrl, updatedUrlPreviewSignal) = urlPreviewStateForChatInterfacePresentationState(updatedChatPresentationInterfaceState, account: self.account, currentQuery: self.urlPreviewQueryState?.0) {
            self.urlPreviewQueryState?.1.dispose()
            var inScope = true
            var inScopeResult: ((TelegramMediaWebpage?) -> TelegramMediaWebpage?)?
            self.urlPreviewQueryState = (updatedUrlPreviewUrl, (updatedUrlPreviewSignal |> deliverOnMainQueue).start(next: { [weak self] result in
                if let strongSelf = self {
                    if Thread.isMainThread && inScope {
                        inScope = false
                        inScopeResult = result
                    } else {
                        strongSelf.updateChatPresentationInterfaceState(animated: true, interactive: false, {
                            if let updatedUrlPreviewUrl = updatedUrlPreviewUrl, let webpage = result($0.urlPreview?.1) {
                                return $0.updatedUrlPreview((updatedUrlPreviewUrl, webpage))
                            } else {
                                return $0.updatedUrlPreview(nil)
                            }
                        })
                    }
                }
            }))
            inScope = false
            if let inScopeResult = inScopeResult {
                if let updatedUrlPreviewUrl = updatedUrlPreviewUrl, let webpage = inScopeResult(updatedChatPresentationInterfaceState.urlPreview?.1) {
                    updatedChatPresentationInterfaceState = updatedChatPresentationInterfaceState.updatedUrlPreview((updatedUrlPreviewUrl, webpage))
                } else {
                    updatedChatPresentationInterfaceState = updatedChatPresentationInterfaceState.updatedUrlPreview(nil)
                }
            }
        }
        
        self.presentationInterfaceState = updatedChatPresentationInterfaceState
        if self.isNodeLoaded {
            self.chatDisplayNode.updateChatPresentationInterfaceState(updatedChatPresentationInterfaceState, animated: animated, interactive: interactive)
        }
        
        if let button = leftNavigationButtonForChatInterfaceState(updatedChatPresentationInterfaceState.interfaceState, currentButton: self.leftNavigationButton, target: self, selector: #selector(self.leftNavigationButtonAction)) {
            self.navigationItem.setLeftBarButton(button.buttonItem, animated: true)
            self.leftNavigationButton = button
        } else if let _ = self.leftNavigationButton {
            self.navigationItem.setLeftBarButton(nil, animated: true)
            self.leftNavigationButton = nil
        }
        
        if let button = rightNavigationButtonForChatInterfaceState(updatedChatPresentationInterfaceState.interfaceState, currentButton: self.rightNavigationButton, target: self, selector: #selector(self.rightNavigationButtonAction), chatInfoNavigationButton: self.chatInfoNavigationButton) {
            self.navigationItem.setRightBarButton(button.buttonItem, animated: true)
            self.rightNavigationButton = button
        } else if let _ = self.rightNavigationButton {
            self.navigationItem.setRightBarButton(nil, animated: true)
            self.rightNavigationButton = nil
        }
        
        if let controllerInteraction = self.controllerInteraction {
            if updatedChatPresentationInterfaceState.interfaceState.selectionState != controllerInteraction.selectionState {
                let animated = controllerInteraction.selectionState == nil || updatedChatPresentationInterfaceState.interfaceState.selectionState == nil
                controllerInteraction.selectionState = updatedChatPresentationInterfaceState.interfaceState.selectionState
                self.updateItemNodesSelectionStates(animated: animated)
            }
        }
    }
    
    private func updateItemNodesSelectionStates(animated: Bool) {
        self.chatDisplayNode.historyNode.forEachItemNode { itemNode in
            if let itemNode = itemNode as? ChatMessageItemView {
                itemNode.updateSelectionState(animated: animated)
            }
        }
    }
    
    private func updateItemNodesHighlightedStates(animated: Bool) {
        self.chatDisplayNode.historyNode.forEachItemNode { itemNode in
            if let itemNode = itemNode as? ChatMessageItemView {
                itemNode.updateHighlightedState(animated: animated)
            }
        }
    }
    
    @objc func leftNavigationButtonAction() {
        if let button = self.leftNavigationButton {
            self.navigationButtonAction(button.action)
        }
    }
    
    @objc func rightNavigationButtonAction() {
        if let button = self.rightNavigationButton {
            self.navigationButtonAction(button.action)
        }
    }
    
    private func navigationButtonAction(_ action: ChatNavigationButtonAction) {
        switch action {
            case .cancelMessageSelection:
                self.updateChatPresentationInterfaceState(animated: true, interactive: true, { $0.updatedInterfaceState { $0.withoutSelectionState() } })
            case .clearHistory:
                let actionSheet = ActionSheetController()
                actionSheet.setItemGroups([ActionSheetItemGroup(items: [
                    ActionSheetButtonItem(title: "Delete All Messages", color: .destructive, action: { [weak self, weak actionSheet] in
                        actionSheet?.dismissAnimated()
                        if let strongSelf = self {
                            strongSelf.updateChatPresentationInterfaceState(animated: true, interactive: true, { $0.updatedInterfaceState { $0.withoutSelectionState() } })
                            let _ = clearHistoryInteractively(postbox: strongSelf.account.postbox, peerId: strongSelf.peerId).start()
                        }
                    })
                ]), ActionSheetItemGroup(items: [
                    ActionSheetButtonItem(title: "Cancel", color: .accent, action: { [weak actionSheet] in
                        actionSheet?.dismissAnimated()
                    })
                ])])
                self.present(actionSheet, in: .window)
            case .openChatInfo:
                self.navigationActionDisposable.set((self.peerView.get()
                    |> take(1)
                    |> deliverOnMainQueue).start(next: { [weak self] peerView in
                        if let strongSelf = self, let peer = peerView.peers[peerView.peerId] {
                            if let infoController = peerInfoController(account: strongSelf.account, peer: peer) {
                                (strongSelf.navigationController as? NavigationController)?.pushViewController(infoController)
                            }
                        }
                }))
                break
        }
    }
    
    private func presentMediaPicker(fileMode: Bool) {
        let _ = legacyAssetPicker(fileMode: fileMode).start(next: { [weak self] generator in
            if let strongSelf = self {
                var presentOverlayController: ((UIViewController) -> (() -> Void))?
                let controller = generator({ controller in
                    return presentOverlayController!(controller)
                })
                let legacyController = LegacyController(legacyController: controller, presentation: .modal)
                
                presentOverlayController = { [weak legacyController] controller in
                    if let legacyController = legacyController {
                        let childController = LegacyController(legacyController: controller, presentation: .custom)
                        legacyController.present(childController, in: .window)
                        return { [weak childController] in
                            childController?.dismiss()
                        }
                    } else {
                        return {
                        }
                    }
                }
                
                configureLegacyAssetPicker(controller)
                controller.descriptionGenerator = legacyAssetPickerItemGenerator()
                controller.completionBlock = { [weak self, weak legacyController] signals in
                    if let strongSelf = self, let legacyController = legacyController {
                        legacyController.dismiss()
                        strongSelf.enqueueMediaMessages(signals: signals)
                    }
                }
                controller.dismissalBlock = { [weak legacyController] in
                    if let legacyController = legacyController {
                        legacyController.dismiss()
                    }
                }
                strongSelf.present(legacyController, in: .window)
            }
        })
    }
    
    private func enqueueMediaMessages(signals: [Any]?) {
        self.enqueueMediaMessageDisposable.set((legacyAssetPickerEnqueueMessages(account: self.account, peerId: self.peerId, signals: signals!) |> deliverOnMainQueue).start(next: { [weak self] messages in
            if let strongSelf = self {
                let replyMessageId = strongSelf.presentationInterfaceState.interfaceState.replyMessageId
                strongSelf.chatDisplayNode.setupSendActionOnViewUpdate({
                    if let strongSelf = self {
                        strongSelf.updateChatPresentationInterfaceState(animated: true, interactive: false, {
                            $0.updatedInterfaceState { $0.withUpdatedReplyMessageId(nil) }
                        })
                    }
                })
                let _ = enqueueMessages(account: strongSelf.account, peerId: strongSelf.peerId, messages: messages.map { $0.withUpdatedReplyToMessageId(replyMessageId) }).start()
            }
        }))
    }
    
    private func enqueueChatContextResult(_ results: ChatContextResultCollection, _ result: ChatContextResult) {
        if let message = outgoingMessageWithChatContextResult(results, result) {
            let replyMessageId = self.presentationInterfaceState.interfaceState.replyMessageId
            self.chatDisplayNode.setupSendActionOnViewUpdate({ [weak self] in
                if let strongSelf = self {
                    strongSelf.updateChatPresentationInterfaceState(animated: true, interactive: false, {
                        $0.updatedInterfaceState { $0.withUpdatedReplyMessageId(nil).withUpdatedComposeInputState(ChatTextInputState(inputText: "")).withUpdatedComposeDisableUrlPreview(nil) }
                    })
                }
            })
            enqueueMessages(account: self.account, peerId: self.peerId, messages: [message.withUpdatedReplyToMessageId(replyMessageId)]).start()
        }
    }
    
    private func requestAudioRecorder() {
        if self.audioRecorderValue == nil {
            if let applicationContext = self.account.applicationContext as? TelegramApplicationContext {
                if self.audioRecorderFeedback == nil {
                    //self.audioRecorderFeedback = HapticFeedback()
                    self.audioRecorderFeedback?.prepareTap()
                }
                self.audioRecorder.set(applicationContext.mediaManager.audioRecorder())
            }
        }
    }
    
    private func dismissAudioRecorder(sendAudio: Bool) {
        if let audioRecorderValue = self.audioRecorderValue {
            audioRecorderValue.stop()
            if sendAudio {
                let _ = (audioRecorderValue.takenRecordedData() |> deliverOnMainQueue).start(next: { [weak self] data in
                    if let strongSelf = self, let data = data {
                        if data.duration < 0.5 {
                            strongSelf.audioRecorderFeedback?.error()
                            strongSelf.audioRecorderFeedback = nil
                        } else {
                            var randomId: Int64 = 0
                            arc4random_buf(&randomId, 8)
                            
                            let resource = LocalFileMediaResource(fileId: randomId)
                            
                            strongSelf.account.postbox.mediaBox.storeResourceData(resource.id, data: data.compressedData)
                            
                            var waveformBuffer: MemoryBuffer?
                            if let waveform = data.waveform {
                                waveformBuffer = MemoryBuffer(data: waveform)
                            }
                            
                            enqueueMessages(account: strongSelf.account, peerId: strongSelf.peerId, messages: [.message(text: "", attributes: [], media: TelegramMediaFile(fileId: MediaId(namespace: Namespaces.Media.LocalFile, id: randomId), resource: resource, previewRepresentations: [], mimeType: "audio/ogg", size: data.compressedData.count, attributes: [.Audio(isVoice: true, duration: Int(data.duration), title: nil, performer: nil, waveform: waveformBuffer)]), replyToMessageId: nil)]).start()
                            
                            strongSelf.audioRecorderFeedback?.success()
                            strongSelf.audioRecorderFeedback = nil
                        }
                    }
                })
            }
        }
        self.audioRecorder.set(.single(nil))
    }
    
    private func navigateToMessage(from fromId: MessageId?, to toId: MessageId, rememberInStack: Bool = true) {
        if self.isNodeLoaded {
            if toId.peerId == self.peerId {
                var fromIndex: MessageIndex?
                
                if let fromId = fromId, let message = self.chatDisplayNode.historyNode.messageInCurrentHistoryView(fromId) {
                    fromIndex = MessageIndex(message)
                } else {
                    if let message = self.chatDisplayNode.historyNode.anchorMessageInCurrentHistoryView() {
                        fromIndex = MessageIndex(message)
                    }
                }
                
                if let fromIndex = fromIndex {
                    if let _ = fromId, rememberInStack {
                        self.historyNavigationStack.add(fromIndex)
                    }
                    
                    if let message = self.chatDisplayNode.historyNode.messageInCurrentHistoryView(toId) {
                        self.chatDisplayNode.historyNode.scrollToMessage(from: fromIndex, to: MessageIndex(message))
                    } else {
                        self.messageIndexDisposable.set((self.account.postbox.messageIndexAtId(toId) |> deliverOnMainQueue).start(next: { [weak self] index in
                            if let strongSelf = self, let index = index {
                                strongSelf.chatDisplayNode.historyNode.scrollToMessage(from: fromIndex, to: index)
                            }
                        }))
                    }
                }
            } else {
                (self.navigationController as? NavigationController)?.pushViewController(ChatController(account: self.account, peerId: toId.peerId, messageId: toId))
            }
        }
    }
    
    private func openPeer(peerId: PeerId?, navigation: ChatControllerInteractionNavigateToPeer, fromMessageId: MessageId?) {
        if peerId == self.peerId {
            switch navigation {
                case .info:
                    self.navigationButtonAction(.openChatInfo)
                case let .chat(textInputState):
                    if let textInputState = textInputState {
                        self.updateChatPresentationInterfaceState(animated: true, interactive: true, {
                            return ($0.updatedInterfaceState {
                                return $0.withUpdatedComposeInputState(textInputState)
                            }).updatedInputMode({ _ in
                                return .text
                            })
                        })
                    }
                case let .withBotStartPayload(botStart):
                    self.updateChatPresentationInterfaceState(animated: true, interactive: true, {
                        $0.updatedBotStartPayload(botStart.payload)
                    })
            }
        } else {
            if let peerId = peerId {
                switch navigation {
                    case .info:
                        let peerSignal: Signal<Peer?, NoError>
                        if let fromMessageId = fromMessageId {
                            peerSignal = loadedPeerFromMessage(account: self.account, peerId: peerId, messageId: fromMessageId)
                        } else {
                            peerSignal = self.account.postbox.loadedPeerWithId(peerId) |> map { Optional($0) }
                        }
                        self.navigationActionDisposable.set((peerSignal |> take(1) |> deliverOnMainQueue).start(next: { [weak self] peer in
                            if let strongSelf = self, let peer = peer {
                                if let infoController = peerInfoController(account: strongSelf.account, peer: peer) {
                                    (strongSelf.navigationController as? NavigationController)?.pushViewController(infoController)
                                }
                            }
                        }))
                    case let .chat(textInputState):
                        if let textInputState = textInputState {
                            let _ = (self.account.postbox.modify({ modifier -> Void in
                                modifier.updatePeerChatInterfaceState(peerId, update: { currentState in
                                    if let currentState = currentState as? ChatInterfaceState {
                                        return currentState.withUpdatedComposeInputState(textInputState)
                                    } else {
                                        return ChatInterfaceState().withUpdatedComposeInputState(textInputState)
                                    }
                                })
                            })).start(completed: { [weak self] in
                                if let strongSelf = self {
                                    (strongSelf.navigationController as? NavigationController)?.pushViewController(ChatController(account: strongSelf.account, peerId: peerId, messageId: nil))
                                }
                            })
                        } else {
                            (self.navigationController as? NavigationController)?.pushViewController(ChatController(account: self.account, peerId: peerId, messageId: nil))
                        }
                    case let .withBotStartPayload(botStart):
                        (self.navigationController as? NavigationController)?.pushViewController(ChatController(account: self.account, peerId: peerId, messageId: nil, botStart: botStart))
                }
            } else {
                switch navigation {
                    case .info:
                        break
                    case let .chat(textInputState):
                        if let textInputState = textInputState {
                            let controller = PeerSelectionController(account: self.account)
                            controller.peerSelected = { [weak self, weak controller] peerId in
                                if let strongSelf = self, let strongController = controller {
                                    if peerId == strongSelf.peerId {
                                        strongSelf.updateChatPresentationInterfaceState(animated: true, interactive: true, {
                                            return ($0.updatedInterfaceState {
                                                return $0.withUpdatedComposeInputState(textInputState)
                                            }).updatedInputMode({ _ in
                                                return .text
                                            })
                                        })
                                        strongController.dismiss()
                                    } else {
                                        let _ = (strongSelf.account.postbox.modify({ modifier -> Void in
                                            modifier.updatePeerChatInterfaceState(peerId, update: { currentState in
                                                if let currentState = currentState as? ChatInterfaceState {
                                                    return currentState.withUpdatedComposeInputState(textInputState)
                                                } else {
                                                    return ChatInterfaceState().withUpdatedComposeInputState(textInputState)
                                                }
                                            })
                                        }) |> deliverOnMainQueue).start(completed: {
                                            if let strongSelf = self {
                                                strongSelf.updateChatPresentationInterfaceState(animated: false, interactive: true, { $0.updatedInterfaceState({ $0.withoutSelectionState() }) })
                                                
                                                let ready = ValuePromise<Bool>()
                                                
                                                strongSelf.controllerNavigationDisposable.set((ready.get() |> take(1) |> deliverOnMainQueue).start(next: { _ in
                                                    if let strongController = controller {
                                                        strongController.dismiss()
                                                    }
                                                }))
                                                
                                                (strongSelf.navigationController as? NavigationController)?.replaceTopController(ChatController(account: strongSelf.account, peerId: peerId), animated: false, ready: ready)
                                            }
                                        })
                                    }
                                }
                            }
                            self.present(controller, in: .window)
                        }
                    case let .withBotStartPayload(_):
                        break
                }
            }
        }
    }
    
    private func unblockPeer() {
        let unblockingPeer = self.unblockingPeer
        unblockingPeer.set(true)
        self.editMessageDisposable.set((requestUpdatePeerIsBlocked(account: self.account, peerId: self.peerId, isBlocked: false) |> afterDisposed({
            Queue.mainQueue().async {
                unblockingPeer.set(false)
            }
        })).start())
    }
    
    private func reportPeer() {
        if let peer = self.presentationInterfaceState.peer {
            let title: String
            if let _ = peer as? TelegramGroup {
                title = "Report spam and leave group"
            } else if let peer = peer as? TelegramChannel {
                if case .group = peer.info {
                    title = "Report spam and leave group"
                } else {
                    title = "Report spam and leave channel"
                }
            } else {
                title = "Report spam and delete chat"
            }
            let actionSheet = ActionSheetController()
            actionSheet.setItemGroups([ActionSheetItemGroup(items: [
                ActionSheetButtonItem(title: title, color: .destructive, action: { [weak self, weak actionSheet] in
                    actionSheet?.dismissAnimated()
                    if let strongSelf = self {
                        strongSelf.deleteChat(reportChatSpam: true)
                    }
                })
                ]), ActionSheetItemGroup(items: [
                    ActionSheetButtonItem(title: "Cancel", color: .accent, action: { [weak actionSheet] in
                        actionSheet?.dismissAnimated()
                    })
                ])])
            self.present(actionSheet, in: .window)
        }
    }
    
    private func dismissReportPeer() {
        self.editMessageDisposable.set((TelegramCore.dismissReportPeer(account: self.account, peerId: self.peerId) |> afterDisposed({
            Queue.mainQueue().async {
            }
        })).start())
    }
    
    private func deleteChat(reportChatSpam: Bool) {
        self.chatDisplayNode.historyNode.disconnect()
        let _ = removePeerChat(postbox: self.account.postbox, peerId: self.peerId, reportChatSpam: reportChatSpam).start()
        (self.navigationController as? NavigationController)?.popToRoot(animated: true)
    }
    
    private func startBot(_ payload: String?) {
        let startingBot = self.startingBot
        startingBot.set(true)
        self.editMessageDisposable.set((requestStartBot(account: self.account, botPeerId: self.peerId, payload: payload) |> deliverOnMainQueue |> afterDisposed({
            startingBot.set(false)
        })).start(completed: { [weak self] in
            if let strongSelf = self {
                strongSelf.updateChatPresentationInterfaceState(animated: true, interactive: true, { $0.updatedBotStartPayload(nil) })
            }
        }))
    }
    
    private func openUrl(_ url: String) {
        let disposable: MetaDisposable
        if let current = self.resolveUrlDisposable {
            disposable = current
        } else {
            disposable = MetaDisposable()
            self.resolveUrlDisposable = disposable
        }
        disposable.set((resolveUrl(account: self.account, url: url) |> deliverOnMainQueue).start(next: { [weak self] result in
            if let strongSelf = self {
                switch result {
                    case let .externalUrl(url):
                        if let applicationContext = strongSelf.account.applicationContext as? TelegramApplicationContext {
                            applicationContext.openUrl(url)
                        }
                    case let .peer(peerId):
                        strongSelf.openPeer(peerId: peerId, navigation: .chat(textInputState: nil), fromMessageId: nil)
                    case let .botStart(peerId, payload):
                        strongSelf.openPeer(peerId: peerId, navigation: .withBotStartPayload(ChatControllerInitialBotStart(payload: payload, behavior: .interactive)), fromMessageId: nil)
                    case let .groupBotStart(peerId, payload):
                        break
                    case let .channelMessage(peerId, messageId):
                        (strongSelf.navigationController as? NavigationController)?.pushViewController(ChatController(account: strongSelf.account, peerId: peerId, messageId: messageId))
                }
            }
        }))
    }
}
