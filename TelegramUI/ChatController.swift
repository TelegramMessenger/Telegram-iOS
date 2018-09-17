import Foundation
import UIKit
import Postbox
import SwiftSignalKit
import Display
import AsyncDisplayKit
import TelegramCore
import SafariServices
import MobileCoreServices

public enum ChatControllerPeekActions {
    case standard
    case remove(() -> Void)
}

public enum ChatControllerPresentationMode: Equatable {
    case standard(previewing: Bool)
    case overlay
    case inline
}

public final class ChatControllerOverlayPresentationData {
    public let expandData: (ASDisplayNode?, () -> Void)
    public init(expandData: (ASDisplayNode?, () -> Void)) {
        self.expandData = expandData
    }
}

private enum ChatLocationInfoData {
    case peer(Promise<PeerView>)
    case group(Promise<ChatListTopPeersView>)
}

private enum ChatRecordingActivity {
    case voice
    case instantVideo
    case none
}

public enum NavigateToMessageLocation {
    case id(MessageId)
    case index(MessageIndex)
    
    var messageId: MessageId {
        switch self {
            case let .id(id):
                return id
            case let .index(index):
                return index.id
        }
    }
}

private func isTopmostChatController(_ controller: ChatController) -> Bool {
    if let _ = controller.navigationController {
        var hasOther = false
        controller.window?.forEachController({ c in
            if c is ChatController {
                hasOther = true
            }
        })
        if hasOther {
            return false
        }
    }
    return true
}

public final class ChatController: TelegramController, UIViewControllerPreviewingDelegate, UIDropInteractionDelegate {
    private var validLayout: ContainerViewLayout?
    
    public var peekActions: ChatControllerPeekActions = .standard
    private var didSetup3dTouch: Bool = false
    
    private let account: Account
    public let chatLocation: ChatLocation
    private let messageId: MessageId?
    private let botStart: ChatControllerInitialBotStart?
    
    private let peerDisposable = MetaDisposable()
    private let navigationActionDisposable = MetaDisposable()
    private var networkStateDisposable: Disposable?
    
    private let messageIndexDisposable = MetaDisposable()
    
    private let _chatLocationInfoReady = Promise<Bool>()
    private var didSetChatLocationInfoReady = false
    private let chatLocationInfoData: ChatLocationInfoData
    
    private var presentationInterfaceState: ChatPresentationInterfaceState
    
    private var chatTitleView: ChatTitleView?
    private var leftNavigationButton: ChatNavigationButton?
    private var rightNavigationButton: ChatNavigationButton?
    private var chatInfoNavigationButton: ChatNavigationButton?
    
    private var peerView: PeerView?
    
    private var historyStateDisposable: Disposable?
    
    private let galleryHiddenMesageAndMediaDisposable = MetaDisposable()
    private let temporaryHiddenGalleryMediaDisposable = MetaDisposable()
    
    private var controllerInteraction: ChatControllerInteraction?
    private var interfaceInteraction: ChatPanelInterfaceInteraction?
    
    private let messageContextDisposable = MetaDisposable()
    private let controllerNavigationDisposable = MetaDisposable()
    private let sentMessageEventsDisposable = MetaDisposable()
    private let messageActionCallbackDisposable = MetaDisposable()
    private let editMessageDisposable = MetaDisposable()
    private let enqueueMediaMessageDisposable = MetaDisposable()
    private var resolvePeerByNameDisposable: MetaDisposable?
    private var shareStatusDisposable: MetaDisposable?
    
    private let editingMessage = ValuePromise<Float?>(nil, ignoreRepeated: true)
    private let startingBot = ValuePromise<Bool>(false, ignoreRepeated: true)
    private let unblockingPeer = ValuePromise<Bool>(false, ignoreRepeated: true)
    private let searching = ValuePromise<Bool>(false, ignoreRepeated: true)
    private let loadingMessage = ValuePromise<Bool>(false, ignoreRepeated: true)
    
    private let botCallbackAlertMessage = Promise<String?>(nil)
    private var botCallbackAlertMessageDisposable: Disposable?
    
    private var resolveUrlDisposable: MetaDisposable?
    
    private var contextQueryStates: [ChatPresentationInputQueryKind: (ChatPresentationInputQuery, Disposable)] = [:]
    private var searchQuerySuggestionState: (ChatPresentationInputQuery?, Disposable)?
    private var urlPreviewQueryState: (String?, Disposable)?
    private var editingUrlPreviewQueryState: (String?, Disposable)?
    private var searchState: (String, SearchMessagesLocation)?
    
    private var recordingModeFeedback: HapticFeedback?
    private var audioRecorderValue: ManagedAudioRecorder?
    private var audioRecorderFeedback: HapticFeedback?
    private var audioRecorder = Promise<ManagedAudioRecorder?>()
    private var audioRecorderDisposable: Disposable?
    
    private var videoRecorderValue: InstantVideoController?
    private var tempVideoRecorderValue: InstantVideoController?
    private var videoRecorder = Promise<InstantVideoController?>()
    private var videoRecorderDisposable: Disposable?
    
    private var buttonKeyboardMessageDisposable: Disposable?
    private var cachedDataDisposable: Disposable?
    private var chatUnreadCountDisposable: Disposable?
    private var chatUnreadMentionCountDisposable: Disposable?
    private var peerInputActivitiesDisposable: Disposable?
    
    private var recentlyUsedInlineBotsValue: [Peer] = []
    private var recentlyUsedInlineBotsDisposable: Disposable?
    
    private var unpinMessageDisposable: MetaDisposable?
    
    private let typingActivityPromise = Promise<Bool>(false)
    private var inputActivityDisposable: Disposable?
    private var recordingActivityValue: ChatRecordingActivity = .none
    private let recordingActivityPromise = ValuePromise<ChatRecordingActivity>(.none, ignoreRepeated: true)
    private var recordingActivityDisposable: Disposable?
    
    private var searchDisposable: MetaDisposable?
    
    private var historyNavigationStack = ChatHistoryNavigationStack()
    
    let canReadHistory = ValuePromise<Bool>(true, ignoreRepeated: true)
    
    private var canReadHistoryValue = false
    private var canReadHistoryDisposable: Disposable?
    
    private var presentationData: PresentationData
    private var presentationDataDisposable: Disposable?
    
    private var automaticMediaDownloadSettings: AutomaticMediaDownloadSettings
    private var automaticMediaDownloadSettingsDisposable: Disposable?
    
    private var applicationInForegroundDisposable: Disposable?
    
    private var checkedPeerChatServiceActions = false
    
    private var raiseToListen: RaiseToListenManager?
    
    private weak var silentPostTooltipController: TooltipController?
    private weak var mediaRecordingModeTooltipController: TooltipController?
    
    private var screenCaptureEventsDisposable: Disposable?
    private let chatAdditionalDataDisposable = MetaDisposable()
    
    private var beginMediaRecordingRequestId: Int = 0
    
    var purposefulAction: (() -> Void)?
    
    public init(account: Account, chatLocation: ChatLocation, messageId: MessageId? = nil, botStart: ChatControllerInitialBotStart? = nil, mode: ChatControllerPresentationMode = .standard(previewing: false)) {
        self.account = account
        self.chatLocation = chatLocation
        self.messageId = messageId
        self.botStart = botStart
        
        var locationBroadcastPanelSource: LocationBroadcastPanelSource
        
        switch chatLocation {
            case let .peer(peerId):
                locationBroadcastPanelSource = .peer(peerId)
                self.chatLocationInfoData = .peer(Promise())
            case .group:
                locationBroadcastPanelSource = .none
                self.chatLocationInfoData = .group(Promise())
        }
        
        self.presentationData = (account.applicationContext as! TelegramApplicationContext).currentPresentationData.with { $0 }
        self.automaticMediaDownloadSettings = (account.applicationContext as! TelegramApplicationContext).currentAutomaticMediaDownloadSettings.with { $0 }
        
        self.presentationInterfaceState = ChatPresentationInterfaceState(chatWallpaper: self.presentationData.chatWallpaper, theme: self.presentationData.theme, strings: self.presentationData.strings, fontSize: self.presentationData.fontSize, accountPeerId: account.peerId, mode: mode, chatLocation: chatLocation)
        
        var enableMediaAccessoryPanel = false
        if case .standard = mode {
            enableMediaAccessoryPanel = true
        } else {
            locationBroadcastPanelSource = .none
        }
        let navigationBarPresentationData: NavigationBarPresentationData?
        switch mode {
            case .inline:
                navigationBarPresentationData = nil
            default:
                navigationBarPresentationData = NavigationBarPresentationData(presentationData: self.presentationData)
        }
        super.init(account: account, navigationBarPresentationData: navigationBarPresentationData, enableMediaAccessoryPanel: enableMediaAccessoryPanel, locationBroadcastPanelSource: locationBroadcastPanelSource)
        
        self.navigationItem.backBarButtonItem = UIBarButtonItem(title: self.presentationData.strings.Common_Back, style: .plain, target: nil, action: nil)
        
        self.ready.set(.never())
        
        self.scrollToTop = { [weak self] in
            guard let strongSelf = self, strongSelf.isNodeLoaded else {
                return
            }
            strongSelf.chatDisplayNode.scrollToTop()
        }
        
        self.attemptNavigation = { [weak self] action in
            guard let strongSelf = self else {
                return true
            }
            if let _ = strongSelf.presentationInterfaceState.inputTextPanelState.mediaRecordingState {
                strongSelf.present(standardTextAlertController(theme: AlertControllerTheme(presentationTheme: strongSelf.presentationData.theme), title: nil, text: strongSelf.presentationData.strings.Conversation_DiscardVoiceMessageDescription, actions: [TextAlertAction(type: .genericAction, title: strongSelf.presentationData.strings.Common_Cancel, action: {}), TextAlertAction(type: .defaultAction, title: strongSelf.presentationData.strings.Common_OK, action: {
                    self?.stopMediaRecorder()
                    action()
                })]), in: .window(.root))
                
                return false
            }
            return true
        }
        
        let controllerInteraction = ChatControllerInteraction(openMessage: { [weak self] message in
            guard let strongSelf = self, strongSelf.isNodeLoaded, let message = strongSelf.chatDisplayNode.historyNode.messageInCurrentHistoryView(message.id) else {
                return false
            }
            strongSelf.commitPurposefulAction()
            
            var openMessageByAction: Bool = false

            for media in message.media {
                if let action = media as? TelegramMediaAction {
                    switch action.action {
                        case .pinnedMessageUpdated:
                            for attribute in message.attributes {
                                if let attribute = attribute as? ReplyMessageAttribute {
                                    strongSelf.navigateToMessage(from: message.id, to: .id(attribute.messageId))
                                    break
                                }
                            }
                        case let .photoUpdated(image):
                            openMessageByAction = image != nil
                        default:
                            break
                    }
                    if !openMessageByAction {
                        return true
                    }
                }
            }
            return openChatMessage(account: account, message: message, standalone: false, reverseMessageGalleryOrder: false, navigationController: strongSelf.navigationController as? NavigationController, dismissInput: {
                self?.chatDisplayNode.dismissInput()
            }, present: { c, a in
                self?.present(c, in: .window(.root), with: a)
            }, transitionNode: { messageId, media in
                var selectedNode: (ASDisplayNode, () -> UIView?)?
                if let strongSelf = self {
                    strongSelf.chatDisplayNode.historyNode.forEachItemNode { itemNode in
                        if let itemNode = itemNode as? ChatMessageItemView {
                            if let result = itemNode.transitionNode(id: messageId, media: media) {
                                selectedNode = result
                            }
                        }
                    }
                }
                return selectedNode
            }, addToTransitionSurface: { view in
                guard let strongSelf = self else {
                    return
                }
                strongSelf.chatDisplayNode.historyNode.view.superview?.insertSubview(view, aboveSubview: strongSelf.chatDisplayNode.historyNode.view)
            }, openUrl: { url in
                self?.openUrl(url, concealed: false)
            }, openPeer: { peer, navigation in
                self?.openPeer(peerId: peer.id, navigation: navigation, fromMessage: nil)
            }, callPeer: { peerId in
                self?.controllerInteraction?.callPeer(peerId)
            }, enqueueMessage: { message in
                self?.sendMessages([message])
            }, sendSticker: canSendMessagesToChat(strongSelf.presentationInterfaceState) ? { fileReference in
                self?.controllerInteraction?.sendSticker(fileReference)
            } : nil, setupTemporaryHiddenMedia: { signal, centralIndex, galleryMedia in
                if let strongSelf = self {
                    strongSelf.temporaryHiddenGalleryMediaDisposable.set((signal |> deliverOnMainQueue).start(next: { entry in
                        if let strongSelf = self, let controllerInteraction = strongSelf.controllerInteraction {
                            var messageIdAndMedia: [MessageId: [Media]] = [:]
                            
                            if let entry = entry, entry.index == centralIndex {
                                messageIdAndMedia[message.id] = [galleryMedia]
                            }
                            
                            controllerInteraction.hiddenMedia = messageIdAndMedia
                            
                            strongSelf.chatDisplayNode.historyNode.forEachItemNode { itemNode in
                                if let itemNode = itemNode as? ChatMessageItemView {
                                    itemNode.updateHiddenMedia()
                                }
                            }
                        }
                    }))
                }
            }, chatAvatarHiddenMedia: { signal, media in
                if let strongSelf = self {
                    strongSelf.temporaryHiddenGalleryMediaDisposable.set((signal |> deliverOnMainQueue).start(next: { messageId in
                        if let strongSelf = self, let controllerInteraction = strongSelf.controllerInteraction {
                            var messageIdAndMedia: [MessageId: [Media]] = [:]
                            
                            if let messageId = messageId {
                                messageIdAndMedia[messageId] = [media]
                            }
                            
                            controllerInteraction.hiddenMedia = messageIdAndMedia
                            
                            strongSelf.chatDisplayNode.historyNode.forEachItemNode { itemNode in
                                if let itemNode = itemNode as? ChatMessageItemView {
                                    itemNode.updateHiddenMedia()
                                }
                            }
                        }
                    }))
                }
            })
        }, openPeer: { [weak self] id, navigation, fromMessage in
            self?.openPeer(peerId: id, navigation: navigation, fromMessage: fromMessage)
        }, openPeerMention: { [weak self] name in
            self?.openPeerMention(name)
        }, openMessageContextMenu: { [weak self] message, node, frame in
            guard let strongSelf = self, strongSelf.isNodeLoaded else {
                return
            }
            if let messages = strongSelf.chatDisplayNode.historyNode.messageGroupInCurrentHistoryView(message.id) {
                var updatedMessages = messages
                for i in 0 ..< updatedMessages.count {
                    if updatedMessages[i].id == message.id {
                        let message = updatedMessages.remove(at: i)
                        updatedMessages.insert(message, at: 0)
                        break
                    }
                }
                let _ = contextMenuForChatPresentationIntefaceState(chatPresentationInterfaceState: strongSelf.presentationInterfaceState, account: strongSelf.account, messages: updatedMessages, interfaceInteraction: strongSelf.interfaceInteraction, debugStreamSingleVideo: { id in
                    self?.debugStreamSingleVideo(id)
                }).start(next: { actions in
                    guard let strongSelf = self, !actions.isEmpty else {
                        return
                    }
                    var contextMenuController: ContextMenuController?
                    var contextActions: [ContextMenuAction] = []
                    var sheetActions: [ChatMessageContextMenuSheetAction] = []
                    for action in actions {
                        switch action {
                            case let .context(contextAction):
                                contextActions.append(contextAction)
                            case let .sheet(sheetAction):
                                sheetActions.append(sheetAction)
                        }
                    }
                    
                    var hasActions = false
                    for media in updatedMessages[0].media {
                        if media is TelegramMediaAction {
                            hasActions = true
                            break
                        }
                    }
                    
                    if !contextActions.isEmpty {
                        contextMenuController = ContextMenuController(actions: contextActions, catchTapsOutside: true, hasHapticFeedback: hasActions)
                    }
                    
                    contextMenuController?.dismissed = {
                        if let strongSelf = self {
                            strongSelf.chatDisplayNode.displayMessageActionSheet(stableId: nil, sheetActions: nil, displayContextMenuController: nil)
                        }
                    }
                    
                    if hasActions {
                        if let contextMenuController = contextMenuController {
                            strongSelf.present(contextMenuController, in: .window(.root), with: ContextMenuControllerPresentationArguments(sourceNodeAndRect: {
                                guard let strongSelf = self else {
                                    return nil
                                }
                                return (node, frame, strongSelf.displayNode, strongSelf.displayNode.bounds)
                            }))
                        }
                    } else {
                        strongSelf.chatDisplayNode.displayMessageActionSheet(stableId: updatedMessages[0].stableId, sheetActions: sheetActions, displayContextMenuController: contextMenuController.flatMap { ($0, node, frame) })
                    }
                })
            }
        }, navigateToMessage: { [weak self] fromId, id in
            self?.navigateToMessage(from: fromId, to: .id(id))
        }, clickThroughMessage: { [weak self] in
            self?.chatDisplayNode.dismissInput()
        }, toggleMessagesSelection: { [weak self] ids, value in
            guard let strongSelf = self, strongSelf.isNodeLoaded else {
                return
            }
            strongSelf.updateChatPresentationInterfaceState(animated: true, interactive: true, { $0.updatedInterfaceState { $0.withToggledSelectedMessages(ids, value: value) } })
        }, sendMessage: { [weak self] text in
            guard let strongSelf = self, canSendMessagesToChat(strongSelf.presentationInterfaceState) else {
                return
            }
            strongSelf.chatDisplayNode.setupSendActionOnViewUpdate({
                if let strongSelf = self {
                    strongSelf.updateChatPresentationInterfaceState(animated: true, interactive: false, {
                        $0.updatedInterfaceState { $0.withUpdatedReplyMessageId(nil) }
                    })
                }
            })
            var attributes: [MessageAttribute] = []
            let entities = generateTextEntities(text, enabledTypes: .all)
            if !entities.isEmpty {
                attributes.append(TextEntitiesMessageAttribute(entities: entities))
            }
            strongSelf.sendMessages([.message(text: text, attributes: attributes, mediaReference: nil, replyToMessageId: strongSelf.presentationInterfaceState.interfaceState.replyMessageId, localGroupingKey: nil)])
        }, sendSticker: { [weak self] fileReference in
            if let strongSelf = self {
                strongSelf.chatDisplayNode.setupSendActionOnViewUpdate({
                    if let strongSelf = self {
                        strongSelf.updateChatPresentationInterfaceState(animated: true, interactive: false, {
                            $0.updatedInterfaceState {
                                $0.withUpdatedReplyMessageId(nil)
                            }.updatedInputMode { current in
                                if case let .media(mode, maybeExpanded) = current, maybeExpanded != nil {
                                    return .media(mode: mode, expanded: nil)
                                }
                                return current
                            }
                        })
                    }
                })
                strongSelf.sendMessages([.message(text: "", attributes: [], mediaReference: fileReference.abstract, replyToMessageId: strongSelf.presentationInterfaceState.interfaceState.replyMessageId, localGroupingKey: nil)])
            }
        }, sendGif: { [weak self] fileReference in
            if let strongSelf = self {
                strongSelf.chatDisplayNode.setupSendActionOnViewUpdate({
                    if let strongSelf = self {
                        strongSelf.updateChatPresentationInterfaceState(animated: true, interactive: false, {
                            $0.updatedInterfaceState { $0.withUpdatedReplyMessageId(nil) }.updatedInputMode { current in
                                if case let .media(mode, maybeExpanded) = current, let expanded = maybeExpanded, case .content = expanded  {
                                    return .media(mode: mode, expanded: nil)
                                }
                                return current
                            }
                        })
                    }
                })
                strongSelf.sendMessages([.message(text: "", attributes: [], mediaReference: fileReference.abstract, replyToMessageId: strongSelf.presentationInterfaceState.interfaceState.replyMessageId, localGroupingKey: nil)])
            }
        }, requestMessageActionCallback: { [weak self] messageId, data, isGame in
            if let strongSelf = self {
                if let message = strongSelf.chatDisplayNode.historyNode.messageInCurrentHistoryView(messageId) {
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
                    
                    strongSelf.messageActionCallbackDisposable.set(((requestMessageActionCallback(account: strongSelf.account, messageId: messageId, isGame: isGame, data: data) |> afterDisposed {
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
                    }) |> deliverOnMainQueue).start(next: { result in
                        if let strongSelf = self {
                            switch result {
                                case .none:
                                    break
                                case let .alert(text):
                                    strongSelf.present(standardTextAlertController(theme: AlertControllerTheme(presentationTheme: strongSelf.presentationData.theme), title: nil, text: text, actions: [TextAlertAction(type: .defaultAction, title: strongSelf.presentationData.strings.Common_OK, action: {})]), in: .window(.root))
                                case let .toast(text):
                                    let message: Signal<String?, NoError> = .single(text)
                                    let noMessage: Signal<String?, NoError> = .single(nil)
                                    let delayedNoMessage: Signal<String?, NoError> = noMessage |> delay(1.0, queue: Queue.mainQueue())
                                    strongSelf.botCallbackAlertMessage.set(message |> then(delayedNoMessage))
                                case let .url(url):
                                    if isGame {
                                        strongSelf.chatDisplayNode.dismissInput()
                                        (strongSelf.navigationController as? NavigationController)?.pushViewController(GameController(account: strongSelf.account, url: url, message: message))
                                    } else {
                                        strongSelf.openUrl(url, concealed: false)
                                    }
                            }
                        }
                    }))
                }
            }
        }, activateSwitchInline: { [weak self] peerId, inputString in
            guard let strongSelf = self else {
                return
            }
            if let botStart = strongSelf.botStart, case let .automatic(returnToPeerId) = botStart.behavior {
                strongSelf.openPeer(peerId: returnToPeerId, navigation: .chat(textInputState: ChatTextInputState(inputText: NSAttributedString(string: inputString)), messageId: nil), fromMessage: nil)
            } else {
                strongSelf.openPeer(peerId: peerId, navigation: .chat(textInputState: ChatTextInputState(inputText: NSAttributedString(string: inputString)), messageId: nil), fromMessage: nil)
            }
        }, openUrl: { [weak self] url, concealed, _ in
            if let strongSelf = self {
                strongSelf.openUrl(url, concealed: concealed)
            }
        }, shareCurrentLocation: { [weak self] in
            if let strongSelf = self {
                strongSelf.present(standardTextAlertController(theme: AlertControllerTheme(presentationTheme: strongSelf.presentationData.theme), title: strongSelf.presentationData.strings.Conversation_ShareBotLocationConfirmationTitle, text: strongSelf.presentationData.strings.Conversation_ShareBotLocationConfirmation, actions: [TextAlertAction(type: .genericAction, title: strongSelf.presentationData.strings.Common_Cancel, action: {}), TextAlertAction(type: .defaultAction, title: strongSelf.presentationData.strings.Common_OK, action: {
                    if let strongSelf = self, let locationManager = strongSelf.account.telegramApplicationContext.locationManager {
                        let _ = (currentLocationManagerCoordinate(manager: locationManager, timeout: 5.0)
                        |> deliverOnMainQueue).start(next: { coordinate in
                            if let strongSelf = self {
                                if let coordinate = coordinate {
                                    strongSelf.sendMessages([.message(text: "", attributes: [], mediaReference: .standalone(media: TelegramMediaMap(latitude: coordinate.latitude, longitude: coordinate.longitude, geoPlace: nil, venue: nil, liveBroadcastingTimeout: nil)), replyToMessageId: nil, localGroupingKey: nil)])
                                } else {
                                    strongSelf.present(standardTextAlertController(theme: AlertControllerTheme(presentationTheme: strongSelf.presentationData.theme), title: nil, text: strongSelf.presentationData.strings.Login_UnknownError, actions: [TextAlertAction(type: .genericAction, title: strongSelf.presentationData.strings.Common_Cancel, action: {})]), in: .window(.root))
                                }
                            }
                        })
                    }
                })]), in: .window(.root))
            }
        }, shareAccountContact: { [weak self] in
            if let strongSelf = self {
                strongSelf.present(standardTextAlertController(theme: AlertControllerTheme(presentationTheme: strongSelf.presentationData.theme), title: strongSelf.presentationData.strings.Conversation_ShareBotContactConfirmationTitle, text: strongSelf.presentationData.strings.Conversation_ShareBotContactConfirmation, actions: [TextAlertAction(type: .genericAction, title: strongSelf.presentationData.strings.Common_Cancel, action: {}), TextAlertAction(type: .defaultAction, title: strongSelf.presentationData.strings.Common_OK, action: {
                    if let strongSelf = self {
                        let _ = (strongSelf.account.postbox.loadedPeerWithId(strongSelf.account.peerId)
                        |> deliverOnMainQueue).start(next: { peer in
                            if let peer = peer as? TelegramUser, let phone = peer.phone, !phone.isEmpty {
                                strongSelf.sendMessages([.message(text: "", attributes: [], mediaReference: .standalone(media: TelegramMediaContact(firstName: peer.firstName ?? "", lastName: peer.lastName ?? "", phoneNumber: phone, peerId: peer.id, vCardData: nil)), replyToMessageId: nil, localGroupingKey: nil)])
                            }
                        })
                    }
                })]), in: .window(.root))
            }
        }, sendBotCommand: { [weak self] messageId, command in
            if let strongSelf = self, canSendMessagesToChat(strongSelf.presentationInterfaceState) {
                strongSelf.chatDisplayNode.setupSendActionOnViewUpdate({})
                var postAsReply = false
                if !command.contains("@") {
                    switch strongSelf.chatLocation {
                        case let .peer(peerId):
                            if (peerId.namespace == Namespaces.Peer.CloudChannel || peerId.namespace == Namespaces.Peer.CloudGroup) {
                                postAsReply = true
                            }
                        case .group:
                            postAsReply = true
                    }
                }
                
                strongSelf.chatDisplayNode.setupSendActionOnViewUpdate({
                    if let strongSelf = self {
                        strongSelf.updateChatPresentationInterfaceState(animated: true, interactive: false, {
                            $0.updatedInterfaceState { $0.withUpdatedReplyMessageId(nil).withUpdatedComposeInputState(ChatTextInputState(inputText: NSAttributedString(string: ""))).withUpdatedComposeDisableUrlPreview(nil) }
                        })
                    }
                })
                var attributes: [MessageAttribute] = []
                let entities = generateTextEntities(command, enabledTypes: .all)
                if !entities.isEmpty {
                    attributes.append(TextEntitiesMessageAttribute(entities: entities))
                }
                strongSelf.sendMessages([.message(text: command, attributes: attributes, mediaReference: nil, replyToMessageId: (postAsReply && messageId != nil) ? messageId! : nil, localGroupingKey: nil)])
            }
        }, openInstantPage: { [weak self] message in
            if let strongSelf = self, strongSelf.isNodeLoaded, let navigationController = strongSelf.navigationController as? NavigationController, let message = strongSelf.chatDisplayNode.historyNode.messageInCurrentHistoryView(message.id) {
                openChatInstantPage(account: strongSelf.account, message: message, navigationController: navigationController)
            }
        }, openHashtag: { [weak self] peerName, hashtag in
            guard let strongSelf = self else {
                return
            }
            if strongSelf.resolvePeerByNameDisposable == nil {
                strongSelf.resolvePeerByNameDisposable = MetaDisposable()
            }
            let resolveSignal: Signal<Peer?, NoError>
            if let peerName = peerName {
                resolveSignal = resolvePeerByName(account: strongSelf.account, name: peerName)
                |> mapToSignal { peerId -> Signal<Peer?, NoError> in
                    if let peerId = peerId {
                        return account.postbox.loadedPeerWithId(peerId)
                        |> map(Optional.init)
                    } else {
                        return .single(nil)
                    }
                }
            } else if case let .peer(peerId) = strongSelf.chatLocation {
                resolveSignal = account.postbox.loadedPeerWithId(peerId)
                |> map(Optional.init)
            } else {
                resolveSignal = .single(nil)
            }
            strongSelf.resolvePeerByNameDisposable?.set((resolveSignal
            |> deliverOnMainQueue).start(next: { peer in
                if let strongSelf = self, !hashtag.isEmpty {
                    let searchController = HashtagSearchController(account: strongSelf.account, peer: peer, query: hashtag)
                    (strongSelf.navigationController as? NavigationController)?.pushViewController(searchController)
                }
            }))
        }, updateInputState: { [weak self] f in
            if let strongSelf = self {
                strongSelf.updateChatPresentationInterfaceState(animated: true, interactive: true, {
                    return $0.updatedInterfaceState {
                        let updatedState: ChatTextInputState
                        if canSendMessagesToChat(strongSelf.presentationInterfaceState) {
                            updatedState = f($0.effectiveInputState)
                        } else {
                            updatedState = ChatTextInputState()
                        }
                        return $0.withUpdatedEffectiveInputState(updatedState)
                    }
                })
            }
        }, updateInputMode: { [weak self] f in
            self?.updateChatPresentationInterfaceState(animated: true, interactive: true, {
                return $0.updatedInputMode(f)
            })
        }, openMessageShareMenu: { [weak self] id in
            if let strongSelf = self, let messages = strongSelf.chatDisplayNode.historyNode.messageGroupInCurrentHistoryView(id) {
                let shareController = ShareController(account: strongSelf.account, subject: .messages(messages))
                strongSelf.chatDisplayNode.dismissInput()
                strongSelf.present(shareController, in: .window(.root))
            }
        }, presentController: { [weak self] controller, arguments in
            self?.present(controller, in: .window(.root), with: arguments)
        }, navigationController: { [weak self] in
            return self?.navigationController as? NavigationController
        }, presentGlobalOverlayController: { [weak self] controller, arguments in
            self?.presentInGlobalOverlay(controller, with: arguments)
        }, callPeer: { [weak self] peerId in
            if let strongSelf = self {
                strongSelf.commitPurposefulAction()
                
                func getUserPeer(postbox: Postbox, peerId: PeerId) -> Signal<Peer?, NoError> {
                    return postbox.transaction { transaction -> Peer? in
                        guard let peer = transaction.getPeer(peerId) else {
                            return nil
                        }
                        if let peer = peer as? TelegramSecretChat {
                            return transaction.getPeer(peer.regularPeerId)
                        } else {
                            return peer
                        }
                    }
                }
                
                let _ = (getUserPeer(postbox: strongSelf.account.postbox, peerId: peerId)
                    |> deliverOnMainQueue).start(next: { peer in
                        guard let peer = peer else {
                            return
                        }
                        
                        if let cachedUserData = strongSelf.peerView?.cachedData as? CachedUserData, cachedUserData.callsPrivate {
                            let presentationData = account.telegramApplicationContext.currentPresentationData.with { $0 }
                            
                            strongSelf.present(standardTextAlertController(theme: AlertControllerTheme(presentationTheme: presentationData.theme), title: presentationData.strings.Call_ConnectionErrorTitle, text: presentationData.strings.Call_PrivacyErrorMessage(peer.compactDisplayTitle).0, actions: [TextAlertAction(type: .defaultAction, title: presentationData.strings.Common_OK, action: {})]), in: .window(.root))
                            return
                        }
                        
                        let callResult = account.telegramApplicationContext.callManager?.requestCall(peerId: peer.id, endCurrentIfAny: false)
                        if let callResult = callResult, case let .alreadyInProgress(currentPeerId) = callResult {
                            if currentPeerId == peer.id {
                                account.telegramApplicationContext.navigateToCurrentCall?()
                            } else {
                                let presentationData = account.telegramApplicationContext.currentPresentationData.with { $0 }
                                let _ = (account.postbox.transaction { transaction -> (Peer?, Peer?) in
                                    return (transaction.getPeer(peer.id), transaction.getPeer(currentPeerId))
                                    } |> deliverOnMainQueue).start(next: { peer, current in
                                        if let peer = peer, let current = current {
                                            strongSelf.present(standardTextAlertController(theme: AlertControllerTheme(presentationTheme: presentationData.theme), title: presentationData.strings.Call_CallInProgressTitle, text: presentationData.strings.Call_CallInProgressMessage(current.compactDisplayTitle, peer.compactDisplayTitle).0, actions: [TextAlertAction(type: .defaultAction, title: presentationData.strings.Common_Cancel, action: {}), TextAlertAction(type: .genericAction, title: presentationData.strings.Common_OK, action: {
                                                let _ = account.telegramApplicationContext.callManager?.requestCall(peerId: peer.id, endCurrentIfAny: true)
                                            })]), in: .window(.root))
                                        }
                                    })
                            }
                        }
                    })
            }
        }, longTap: { [weak self] action in
            if let strongSelf = self {
                switch action {
                    case let .url(url):
                        var cleanUrl = url
                        var canAddToReadingList = true
                        let canOpenIn = true
                        let mailtoString = "mailto:"
                        let telString = "tel:"
                        var openText = strongSelf.presentationData.strings.Conversation_LinkDialogOpen
                        if cleanUrl.hasPrefix(mailtoString) {
                            canAddToReadingList = false
                            cleanUrl = String(cleanUrl[cleanUrl.index(cleanUrl.startIndex, offsetBy: mailtoString.distance(from: mailtoString.startIndex, to: mailtoString.endIndex))...])
                        } else if cleanUrl.hasPrefix(telString) {
                            canAddToReadingList = false
                            cleanUrl = String(cleanUrl[cleanUrl.index(cleanUrl.startIndex, offsetBy: telString.distance(from: telString.startIndex, to: telString.endIndex))...])
                            openText = strongSelf.presentationData.strings.Conversation_Call
                        } else if canOpenIn {
                            openText = strongSelf.presentationData.strings.Conversation_FileOpenIn
                        }
                        let actionSheet = ActionSheetController(presentationTheme: strongSelf.presentationData.theme)
                        
                        var items: [ActionSheetItem] = []
                        items.append(ActionSheetTextItem(title: cleanUrl))
                        items.append(ActionSheetButtonItem(title: openText, color: .accent, action: { [weak actionSheet] in
                            actionSheet?.dismissAnimated()
                            if let strongSelf = self {
                                if canOpenIn {
                                    strongSelf.openUrlIn(url)
                                } else {
                                    strongSelf.openUrl(url, concealed: false)
                                }
                            }
                        }))
                        items.append(ActionSheetButtonItem(title: canAddToReadingList ? strongSelf.presentationData.strings.ShareMenu_CopyShareLink : strongSelf.presentationData.strings.Conversation_ContextMenuCopy, color: .accent, action: { [weak actionSheet] in
                            actionSheet?.dismissAnimated()
                            UIPasteboard.general.string = cleanUrl
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
                            ActionSheetButtonItem(title: strongSelf.presentationData.strings.Common_Cancel, color: .accent, action: { [weak actionSheet] in
                                actionSheet?.dismissAnimated()
                            })
                        ])])
                        strongSelf.chatDisplayNode.dismissInput()
                        strongSelf.present(actionSheet, in: .window(.root))
                    case let .peerMention(peerId, mention):
                        let actionSheet = ActionSheetController(presentationTheme: strongSelf.presentationData.theme)
                        var items: [ActionSheetItem] = []
                        if !mention.isEmpty {
                            items.append(ActionSheetTextItem(title: mention))
                        }
                        items.append(ActionSheetButtonItem(title: strongSelf.presentationData.strings.Conversation_LinkDialogOpen, color: .accent, action: { [weak actionSheet] in
                            actionSheet?.dismissAnimated()
                            if let strongSelf = self {
                                strongSelf.openPeer(peerId: peerId, navigation: .chat(textInputState: nil, messageId: nil), fromMessage: nil)
                            }
                        }))
                        if !mention.isEmpty {
                            items.append(ActionSheetButtonItem(title: strongSelf.presentationData.strings.Conversation_LinkDialogCopy, color: .accent, action: { [weak actionSheet] in
                                actionSheet?.dismissAnimated()
                                UIPasteboard.general.string = mention
                            }))
                        }
                        actionSheet.setItemGroups([ActionSheetItemGroup(items:items), ActionSheetItemGroup(items: [
                            ActionSheetButtonItem(title: strongSelf.presentationData.strings.Common_Cancel, color: .accent, action: { [weak actionSheet] in
                                actionSheet?.dismissAnimated()
                            })
                        ])])
                        strongSelf.chatDisplayNode.dismissInput()
                        strongSelf.present(actionSheet, in: .window(.root))
                    case let .mention(mention):
                        let actionSheet = ActionSheetController(presentationTheme: strongSelf.presentationData.theme)
                        actionSheet.setItemGroups([ActionSheetItemGroup(items: [
                            ActionSheetTextItem(title: mention),
                            ActionSheetButtonItem(title: strongSelf.presentationData.strings.Conversation_LinkDialogOpen, color: .accent, action: { [weak actionSheet] in
                                actionSheet?.dismissAnimated()
                                if let strongSelf = self {
                                    strongSelf.openPeerMention(mention)
                                }
                            }),
                            ActionSheetButtonItem(title: strongSelf.presentationData.strings.Conversation_LinkDialogCopy, color: .accent, action: { [weak actionSheet] in
                                actionSheet?.dismissAnimated()
                                    UIPasteboard.general.string = mention
                            })
                        ]), ActionSheetItemGroup(items: [
                            ActionSheetButtonItem(title: strongSelf.presentationData.strings.Common_Cancel, color: .accent, action: { [weak actionSheet] in
                                actionSheet?.dismissAnimated()
                            })
                        ])])
                        strongSelf.chatDisplayNode.dismissInput()
                        strongSelf.present(actionSheet, in: .window(.root))
                    case let .command(command):
                        let actionSheet = ActionSheetController(presentationTheme: strongSelf.presentationData.theme)
                        var items: [ActionSheetItem] = []
                        items.append(ActionSheetTextItem(title: command))
                        if canSendMessagesToChat(strongSelf.presentationInterfaceState) {
                            items.append(ActionSheetButtonItem(title: strongSelf.presentationData.strings.ShareMenu_Send, color: .accent, action: { [weak actionSheet] in
                                actionSheet?.dismissAnimated()
                                if let strongSelf = self {
                                    strongSelf.sendMessages([.message(text: command, attributes: [], mediaReference: nil, replyToMessageId: nil, localGroupingKey: nil)])
                                }
                            }))
                        }
                        items.append(ActionSheetButtonItem(title: strongSelf.presentationData.strings.Conversation_LinkDialogCopy, color: .accent, action: { [weak actionSheet] in
                            actionSheet?.dismissAnimated()
                            UIPasteboard.general.string = command
                        }))
                        actionSheet.setItemGroups([ActionSheetItemGroup(items: items), ActionSheetItemGroup(items: [
                            ActionSheetButtonItem(title: strongSelf.presentationData.strings.Common_Cancel, color: .accent, action: { [weak actionSheet] in
                                actionSheet?.dismissAnimated()
                            })
                        ])])
                        strongSelf.chatDisplayNode.dismissInput()
                        strongSelf.present(actionSheet, in: .window(.root))
                    case let .hashtag(hashtag):
                        let actionSheet = ActionSheetController(presentationTheme: strongSelf.presentationData.theme)
                        actionSheet.setItemGroups([ActionSheetItemGroup(items: [
                            ActionSheetTextItem(title: hashtag),
                            ActionSheetButtonItem(title: strongSelf.presentationData.strings.Conversation_LinkDialogOpen, color: .accent, action: { [weak actionSheet] in
                                actionSheet?.dismissAnimated()
                                if let strongSelf = self {
                                    let peerSignal: Signal<Peer?, NoError>
                                    if case let .peer(peerId) = strongSelf.chatLocation {
                                        peerSignal = strongSelf.account.postbox.loadedPeerWithId(peerId)
                                        |> map(Optional.init)
                                    } else {
                                        peerSignal = .single(nil)
                                    }
                                    let _ = (peerSignal
                                    |> deliverOnMainQueue).start(next: { peer in
                                        if let strongSelf = self {
                                            let searchController = HashtagSearchController(account: strongSelf.account, peer: peer, query: hashtag)
                                            (strongSelf.navigationController as? NavigationController)?.pushViewController(searchController)
                                        }
                                    })
                                }
                            }),
                            ActionSheetButtonItem(title: strongSelf.presentationData.strings.Conversation_LinkDialogCopy, color: .accent, action: { [weak actionSheet] in
                                actionSheet?.dismissAnimated()
                                UIPasteboard.general.string = hashtag
                            })
                        ]), ActionSheetItemGroup(items: [
                            ActionSheetButtonItem(title: strongSelf.presentationData.strings.Common_Cancel, color: .accent, action: { [weak actionSheet] in
                                actionSheet?.dismissAnimated()
                            })
                        ])])
                        strongSelf.chatDisplayNode.dismissInput()
                        strongSelf.present(actionSheet, in: .window(.root))
                }
            }
        }, openCheckoutOrReceipt: { [weak self] messageId in
            if let strongSelf = self {
                strongSelf.commitPurposefulAction()
                if let message = strongSelf.chatDisplayNode.historyNode.messageInCurrentHistoryView(messageId) {
                    for media in message.media {
                        if let invoice = media as? TelegramMediaInvoice {
                            strongSelf.chatDisplayNode.dismissInput()
                            if let receiptMessageId = invoice.receiptMessageId {
                                strongSelf.present(BotReceiptController(account: strongSelf.account, invoice: invoice, messageId: receiptMessageId), in: .window(.root), with: ViewControllerPresentationArguments(presentationAnimation: .modalSheet))
                            } else {
                                strongSelf.present(BotCheckoutController(account: strongSelf.account, invoice: invoice, messageId: messageId), in: .window(.root), with: ViewControllerPresentationArguments(presentationAnimation: .modalSheet))
                            }
                        }
                    }
                }
            }
        }, openSearch: {
        }, setupReply: { [weak self] messageId in
            self?.interfaceInteraction?.setupReplyMessage(messageId)
        }, canSetupReply: { [weak self] message in
            if !message.flags.contains(.Incoming) {
                if !message.flags.intersection([.Failed, .Sending, .Unsent]).isEmpty {
                    return false
                }
            }
            if let strongSelf = self {
                return canReplyInChat(strongSelf.presentationInterfaceState)
            }
            return false
        }, navigateToFirstDateMessage: { [weak self] timestamp in
            guard let strongSelf = self else {
                return
            }
            switch strongSelf.chatLocation {
                case let .peer(peerId):
                    strongSelf.navigateToMessage(from: nil, to: .index(MessageIndex(id: MessageId(peerId: peerId, namespace: 0, id: 0), timestamp: timestamp - Int32(NSTimeZone.local.secondsFromGMT()))), scrollPosition: .bottom(0.0), rememberInStack: false, animated: true, completion: nil)
                default:
                    break
            }
        }, requestMessageUpdate: { [weak self] id in
            if let strongSelf = self {
                strongSelf.chatDisplayNode.historyNode.requestMessageUpdate(id)
            }
        }, cancelInteractiveKeyboardGestures: { [weak self] in
            (self?.view.window as? WindowHost)?.cancelInteractiveKeyboardGestures()
            self?.chatDisplayNode.cancelInteractiveKeyboardGestures()
        }, automaticMediaDownloadSettings: self.automaticMediaDownloadSettings)
        
        self.controllerInteraction = controllerInteraction
        
        self.chatTitleView = ChatTitleView(account: self.account, theme: self.presentationData.theme, strings: self.presentationData.strings, timeFormat: self.presentationData.timeFormat)
        self.navigationItem.titleView = self.chatTitleView
        self.chatTitleView?.pressed = { [weak self] in
            if let strongSelf = self {
                if strongSelf.chatLocation == .peer(strongSelf.account.peerId) {
                    (strongSelf.navigationController as? NavigationController)?.pushViewController(PeerMediaCollectionController(account: strongSelf.account, peerId: strongSelf.account.peerId))
                } else {
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
        }
        
        let chatInfoButtonItem: UIBarButtonItem
        switch chatLocation {
            case .peer:
                chatInfoButtonItem = UIBarButtonItem(customDisplayNode: ChatAvatarNavigationNode())!
            case .group:
                chatInfoButtonItem = UIBarButtonItem(customDisplayNode: ChatMultipleAvatarsNavigationNode())!
        }
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
        
        switch chatLocation {
            case let .peer(peerId):
                if case let .peer(peerView) = self.chatLocationInfoData {
                    peerView.set(account.viewTracker.peerView(peerId))
                    self.peerDisposable.set((peerView.get()
                        |> deliverOnMainQueue).start(next: { [weak self] peerView in
                            if let strongSelf = self {
                                if let peer = peerViewMainPeer(peerView) {
                                    strongSelf.chatTitleView?.titleContent = .peer(peerView)
                                    (strongSelf.chatInfoNavigationButton?.buttonItem.customDisplayNode as? ChatAvatarNavigationNode)?.avatarNode.setPeer(account: strongSelf.account, peer: peer)
                                }
                                var wasGroupChannel: Bool?
                                if let previousPeerView = strongSelf.peerView, let info = (previousPeerView.peers[previousPeerView.peerId] as? TelegramChannel)?.info {
                                    if case .group = info {
                                        wasGroupChannel = true
                                    } else {
                                        wasGroupChannel = false
                                    }
                                }
                                var isGroupChannel: Bool?
                                if let info = (peerView.peers[peerView.peerId] as? TelegramChannel)?.info {
                                    if case .group = info {
                                        isGroupChannel = true
                                    } else {
                                        isGroupChannel = false
                                    }
                                }
                                strongSelf.peerView = peerView
                                if wasGroupChannel != isGroupChannel {
                                    if let isGroupChannel = isGroupChannel, isGroupChannel {
                                        let (recentDisposable, _) = strongSelf.account.telegramApplicationContext.peerChannelMemberCategoriesContextsManager.recent(postbox: strongSelf.account.postbox, network: strongSelf.account.network, peerId: peerView.peerId, updated: { _ in })
                                        let (adminsDisposable, _) = strongSelf.account.telegramApplicationContext.peerChannelMemberCategoriesContextsManager.admins(postbox: strongSelf.account.postbox, network: strongSelf.account.network, peerId: peerView.peerId, updated: { _ in })
                                        let disposable = DisposableSet()
                                        disposable.add(recentDisposable)
                                        disposable.add(adminsDisposable)
                                        strongSelf.chatAdditionalDataDisposable.set(disposable)
                                    } else {
                                        strongSelf.chatAdditionalDataDisposable.set(nil)
                                    }
                                }
                                if strongSelf.isNodeLoaded {
                                    strongSelf.chatDisplayNode.peerView = peerView
                                }
                                var peerIsMuted = false
                                if let notificationSettings = peerView.notificationSettings as? TelegramPeerNotificationSettings {
                                    if case .muted = notificationSettings.muteState {
                                        peerIsMuted = true
                                    }
                                }
                                var renderedPeer: RenderedPeer?
                                var isContact: Bool = false
                                if let peer = peerView.peers[peerView.peerId] {
                                    isContact = peerView.peerIsContact
                                    var peers = SimpleDictionary<PeerId, Peer>()
                                    peers[peer.id] = peer
                                    if let associatedPeerId = peer.associatedPeerId, let associatedPeer = peerView.peers[associatedPeerId] {
                                        peers[associatedPeer.id] = associatedPeer
                                    }
                                    renderedPeer = RenderedPeer(peerId: peer.id, peers: peers)
                                }
                                
                                var animated = false
                                if let peer = strongSelf.presentationInterfaceState.renderedPeer?.peer as? TelegramSecretChat, let updated = renderedPeer?.peer as? TelegramSecretChat, peer.embeddedState != updated.embeddedState {
                                    animated = true
                                }
                                strongSelf.updateChatPresentationInterfaceState(animated: animated, interactive: false, {
                                    return $0.updatedPeer { _ in return renderedPeer
                                    }.updatedIsContact(isContact).updatedPeerIsMuted(peerIsMuted)
                                })
                                if !strongSelf.didSetChatLocationInfoReady {
                                    strongSelf.didSetChatLocationInfoReady = true
                                    strongSelf._chatLocationInfoReady.set(.single(true))
                                }
                            }
                        }))
                }
            case let .group(groupId):
                if case let .group(topPeersView) = self.chatLocationInfoData {
                    let key: PostboxViewKey = .chatListTopPeers(groupId: groupId)
                    topPeersView.set(account.postbox.combinedView(keys: [key])
                        |> mapToSignal { view -> Signal<ChatListTopPeersView, NoError> in
                            if let entry = view.views[key] as? ChatListTopPeersView {
                                return .single(entry)
                            }
                            return .complete()
                        })
                    self.peerDisposable.set((topPeersView.get()
                        |> deliverOnMainQueue).start(next: { [weak self] topPeersView in
                            if let strongSelf = self {
                                strongSelf.chatTitleView?.titleContent = .group(topPeersView.peers)
                            (strongSelf.chatInfoNavigationButton?.buttonItem.customDisplayNode as? ChatMultipleAvatarsNavigationNode)?.setPeers(account: strongSelf.account, peers: topPeersView.peers, animated: strongSelf.didSetChatLocationInfoReady)
                            
                                if !strongSelf.didSetChatLocationInfoReady {
                                    strongSelf.didSetChatLocationInfoReady = true
                                    strongSelf._chatLocationInfoReady.set(.single(true))
                                }
                            }
                        }))
                }
        }
        
        self.botCallbackAlertMessageDisposable = (self.botCallbackAlertMessage.get()
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
                    strongSelf.lockOrientation = audioRecorder != nil
                    
                    strongSelf.updateChatPresentationInterfaceState(animated: true, interactive: true, {
                        $0.updatedInputTextPanelState { panelState in
                            if let audioRecorder = audioRecorder {
                                if panelState.mediaRecordingState == nil {
                                    return panelState.withUpdatedMediaRecordingState(.audio(recorder: audioRecorder, isLocked: false))
                                }
                            } else {
                                return panelState.withUpdatedMediaRecordingState(nil)
                            }
                            return panelState
                        }
                    })
                    
                    if let audioRecorder = audioRecorder {
                        if !audioRecorder.beginWithTone {
                            strongSelf.audioRecorderFeedback?.tap()
                        }
                        audioRecorder.start()
                    }
                }
            }
        })
        
        self.videoRecorderDisposable = (self.videoRecorder.get()
        |> deliverOnMainQueue).start(next: { [weak self] videoRecorder in
            if let strongSelf = self {
                if strongSelf.videoRecorderValue !== videoRecorder {
                    let previousVideoRecorderValue = strongSelf.videoRecorderValue
                    strongSelf.videoRecorderValue = videoRecorder
                    
                    strongSelf.updateChatPresentationInterfaceState(animated: true, interactive: true, {
                        $0.updatedInputTextPanelState { panelState in
                            if let videoRecorder = videoRecorder {
                                if panelState.mediaRecordingState == nil {
                                    return panelState.withUpdatedMediaRecordingState(.video(status: .recording(videoRecorder.audioStatus), isLocked: false))
                                }
                            } else {
                                return panelState.withUpdatedMediaRecordingState(nil)
                            }
                            return panelState
                        }
                    })
                    
                    if let videoRecorder = videoRecorder {
                        videoRecorder.onDismiss = {
                            if let strongSelf = self {
                                strongSelf.videoRecorder.set(.single(nil))
                            }
                        }
                        videoRecorder.onStop = {
                            if let strongSelf = self {
                                strongSelf.updateChatPresentationInterfaceState(animated: true, interactive: true, {
                                    $0.updatedInputTextPanelState { panelState in
                                        return panelState.withUpdatedMediaRecordingState(.video(status: .editing, isLocked: false))
                                    }
                                })
                            }
                        }
                        strongSelf.present(videoRecorder, in: .window(.root))
                    }
                    
                    if let previousVideoRecorderValue = previousVideoRecorderValue {
                        previousVideoRecorderValue.dismissVideo()
                    }
                }
            }
        })
        
        if let botStart = botStart, case .automatic = botStart.behavior {
            self.startBot(botStart.payload)
        }
        
        self.inputActivityDisposable = (self.typingActivityPromise.get()
        |> deliverOnMainQueue).start(next: { [weak self] value in
            if let strongSelf = self, case let .peer(peerId) = strongSelf.chatLocation {
                strongSelf.account.updateLocalInputActivity(peerId: peerId, activity: .typingText, isPresent: value)
            }
        })
        
        self.recordingActivityDisposable = (self.recordingActivityPromise.get()
            |> deliverOnMainQueue).start(next: { [weak self] value in
                if let strongSelf = self, case let .peer(peerId) = strongSelf.chatLocation {
                    switch value {
                        case .voice:
                            strongSelf.account.updateLocalInputActivity(peerId: peerId, activity: .recordingVoice, isPresent: true)
                            strongSelf.account.updateLocalInputActivity(peerId: peerId, activity: .recordingInstantVideo, isPresent: false)
                        case .instantVideo:
                            strongSelf.account.updateLocalInputActivity(peerId: peerId, activity: .recordingVoice, isPresent: false)
                            strongSelf.account.updateLocalInputActivity(peerId: peerId, activity: .recordingInstantVideo, isPresent: true)
                        case .none:
                            strongSelf.account.updateLocalInputActivity(peerId: peerId, activity: .recordingVoice, isPresent: false)
                            strongSelf.account.updateLocalInputActivity(peerId: peerId, activity: .recordingInstantVideo, isPresent: false)
                    }
                }
            })
        
        self.presentationDataDisposable = (account.telegramApplicationContext.presentationData
            |> deliverOnMainQueue).start(next: { [weak self] presentationData in
                if let strongSelf = self {
                    let previousTheme = strongSelf.presentationData.theme
                    let previousStrings = strongSelf.presentationData.strings
                    let previousChatWallpaper = strongSelf.presentationData.chatWallpaper
                    
                    strongSelf.presentationData = presentationData
                    
                    if previousTheme !== presentationData.theme || previousStrings !== presentationData.strings || presentationData.chatWallpaper != previousChatWallpaper {
                        strongSelf.themeAndStringsUpdated()
                    }
                }
            })
        
        self.automaticMediaDownloadSettingsDisposable = (account.telegramApplicationContext.automaticMediaDownloadSettings
            |> deliverOnMainQueue).start(next: { [weak self] downloadSettings in
                if let strongSelf = self, strongSelf.automaticMediaDownloadSettings != downloadSettings {
                    strongSelf.automaticMediaDownloadSettings = downloadSettings
                    strongSelf.controllerInteraction?.automaticMediaDownloadSettings = downloadSettings
                    if strongSelf.isNodeLoaded {
                        strongSelf.chatDisplayNode.updateAutomaticMediaDownloadSettings()
                    }
                }
            })
        
        self.applicationInForegroundDisposable = (account.telegramApplicationContext.applicationBindings.applicationInForeground
            |> distinctUntilChanged
            |> deliverOn(Queue.mainQueue())).start(next: { [weak self] value in
                if let strongSelf = self, strongSelf.isNodeLoaded {
                    if !value {
                        strongSelf.saveInterfaceState()
                        strongSelf.raiseToListen?.applicationResignedActive()
                        
                        strongSelf.stopMediaRecorder()
                    }
                }
            })
        
        self.canReadHistoryDisposable = (combineLatest((self.account.applicationContext as! TelegramApplicationContext).applicationBindings.applicationInForeground, self.canReadHistory.get()) |> map { a, b in
            return a && b
        } |> deliverOnMainQueue).start(next: { [weak self] value in
            if let strongSelf = self, strongSelf.canReadHistoryValue != value {
                strongSelf.canReadHistoryValue = value
                strongSelf.raiseToListen?.enabled = value
            }
        })
        
        self.networkStateDisposable = (account.networkState |> deliverOnMainQueue).start(next: { [weak self] state in
            if let strongSelf = self {
                strongSelf.chatTitleView?.networkState = state
            }
        })
        
        if case let .peer(peerId) = self.chatLocation, peerId.namespace == Namespaces.Peer.SecretChat {
            self.screenCaptureEventsDisposable = screenCaptureEvents().start(next: { [weak self] _ in
                if let strongSelf = self, strongSelf.canReadHistoryValue, strongSelf.traceVisibility() {
                    let _ = addSecretChatMessageScreenshot(account: account, peerId: peerId).start()
                }
            })
        }
    }
    
    required public init(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    deinit {
        self.historyStateDisposable?.dispose()
        self.messageIndexDisposable.dispose()
        self.navigationActionDisposable.dispose()
        self.galleryHiddenMesageAndMediaDisposable.dispose()
        self.temporaryHiddenGalleryMediaDisposable.dispose()
        self.peerDisposable.dispose()
        self.messageContextDisposable.dispose()
        self.controllerNavigationDisposable.dispose()
        self.sentMessageEventsDisposable.dispose()
        self.messageActionCallbackDisposable.dispose()
        self.editMessageDisposable.dispose()
        self.enqueueMediaMessageDisposable.dispose()
        self.resolvePeerByNameDisposable?.dispose()
        self.shareStatusDisposable?.dispose()
        self.botCallbackAlertMessageDisposable?.dispose()
        for (_, info) in self.contextQueryStates {
            info.1.dispose()
        }
        self.urlPreviewQueryState?.1.dispose()
        self.audioRecorderDisposable?.dispose()
        self.videoRecorderDisposable?.dispose()
        self.buttonKeyboardMessageDisposable?.dispose()
        self.cachedDataDisposable?.dispose()
        self.resolveUrlDisposable?.dispose()
        self.chatUnreadCountDisposable?.dispose()
        self.chatUnreadMentionCountDisposable?.dispose()
        self.peerInputActivitiesDisposable?.dispose()
        self.recentlyUsedInlineBotsDisposable?.dispose()
        self.unpinMessageDisposable?.dispose()
        self.inputActivityDisposable?.dispose()
        self.recordingActivityDisposable?.dispose()
        self.presentationDataDisposable?.dispose()
        self.searchDisposable?.dispose()
        self.applicationInForegroundDisposable?.dispose()
        self.canReadHistoryDisposable?.dispose()
        self.networkStateDisposable?.dispose()
        self.screenCaptureEventsDisposable?.dispose()
        self.chatAdditionalDataDisposable.dispose()
        self.shareStatusDisposable?.dispose()
    }
    
    public func updatePresentationMode(_ mode: ChatControllerPresentationMode) {
        self.updateChatPresentationInterfaceState(animated: false, interactive: false, {
            return $0.updatedMode(mode)
        })
    }
    
    var chatDisplayNode: ChatControllerNode {
        get {
            return super.displayNode as! ChatControllerNode
        }
    }
    
    private func themeAndStringsUpdated() {
        self.navigationItem.backBarButtonItem = UIBarButtonItem(title: self.presentationData.strings.Common_Back, style: .plain, target: nil, action: nil)
        self.statusBar.statusBarStyle = self.presentationData.theme.rootController.statusBar.style.style
        self.navigationBar?.updatePresentationData(NavigationBarPresentationData(presentationData: self.presentationData))
        self.chatTitleView?.updateThemeAndStrings(theme: self.presentationData.theme, strings: self.presentationData.strings)
        self.updateChatPresentationInterfaceState(animated: false, interactive: false, { state in
            var state = state
            state = state.updatedTheme(self.presentationData.theme)
            state = state.updatedStrings(self.presentationData.strings)
            state = state.updatedChatWallpaper(self.presentationData.chatWallpaper)
            return state
        })
    }
    
    override public func loadDisplayNode() {
        self.displayNode = ChatControllerNode(account: self.account, chatLocation: self.chatLocation, messageId: self.messageId, controllerInteraction: self.controllerInteraction!, chatPresentationInterfaceState: self.presentationInterfaceState, automaticMediaDownloadSettings: self.automaticMediaDownloadSettings, navigationBar: self.navigationBar)
        
        self.chatDisplayNode.peerView = self.peerView
        
        let initialData = self.chatDisplayNode.historyNode.initialData
            |> take(1)
            |> beforeNext { [weak self] combinedInitialData in
                if let strongSelf = self, let combinedInitialData = combinedInitialData {
                    if let interfaceState = combinedInitialData.initialData?.chatInterfaceState as? ChatInterfaceState {
                        var pinnedMessageId: MessageId?
                        var peerIsBlocked: Bool = false
                        var canReport: Bool = false
                        var callsAvailable: Bool = false
                        var callsPrivate: Bool = false
                        if let cachedData = combinedInitialData.cachedData as? CachedChannelData {
                            pinnedMessageId = cachedData.pinnedMessageId
                            canReport = cachedData.reportStatus == .canReport
                        } else if let cachedData = combinedInitialData.cachedData as? CachedUserData {
                            peerIsBlocked = cachedData.isBlocked
                            canReport = cachedData.reportStatus == .canReport
                            callsAvailable = cachedData.callsAvailable
                            callsPrivate = cachedData.callsPrivate
                        } else if let cachedData = combinedInitialData.cachedData as? CachedGroupData {
                            canReport = cachedData.reportStatus == .canReport
                        } else if let cachedData = combinedInitialData.cachedData as? CachedSecretChatData {
                            canReport = cachedData.reportStatus == .canReport
                        }
                        var pinnedMessage: Message?
                        if let pinnedMessageId = pinnedMessageId {
                            if let cachedDataMessages = combinedInitialData.cachedDataMessages {
                                pinnedMessage = cachedDataMessages[pinnedMessageId]
                            }
                        }
                        strongSelf.updateChatPresentationInterfaceState(animated: false, interactive: false, { updated in
                            var updated = updated
                        
                            updated = updated.updatedInterfaceState({ _ in return interfaceState })
                            
                            updated = updated.updatedKeyboardButtonsMessage(combinedInitialData.buttonKeyboardMessage)
                            updated = updated.updatedPinnedMessageId(pinnedMessageId)
                            updated = updated.updatedPinnedMessage(pinnedMessage)
                            updated = updated.updatedPeerIsBlocked(peerIsBlocked)
                            updated = updated.updatedCanReportPeer(canReport)
                            updated = updated.updatedCallsAvailable(callsAvailable)
                            updated = updated.updatedCallsPrivate(callsPrivate)
                            updated = updated.updatedTitlePanelContext({ context in
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
                            if let editMessage = interfaceState.editMessage, let message = combinedInitialData.initialData?.associatedMessages[editMessage.messageId] {
                                updated = updatedChatEditInterfaceMessagetState(state: updated, message: message)
                            }
                            return updated
                        })
                    }
                    if let readStateData = combinedInitialData.readStateData {
                        if case let .peer(peerId) = strongSelf.chatLocation, let peerReadStateData = readStateData[peerId], let notificationSettings = peerReadStateData.notificationSettings {
                            var globalRemainingUnreadChatCount = peerReadStateData.totalUnreadChatCount
                            if !notificationSettings.isRemovedFromTotalUnreadCount && peerReadStateData.unreadCount > 0 {
                                globalRemainingUnreadChatCount -= 1
                            }
                            if globalRemainingUnreadChatCount > 0 {
                                strongSelf.navigationItem.badge = "\(globalRemainingUnreadChatCount)"
                            } else {
                                strongSelf.navigationItem.badge = ""
                            }
                        }
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
        
        self.cachedDataDisposable = self.chatDisplayNode.historyNode.cachedPeerDataAndMessages.start(next: { [weak self] cachedData, messages in
            if let strongSelf = self {
                var pinnedMessageId: MessageId?
                var peerIsBlocked: Bool = false
                var canReport: Bool = false
                var callsAvailable: Bool = false
                var callsPrivate: Bool = false
                if let cachedData = cachedData as? CachedChannelData {
                    pinnedMessageId = cachedData.pinnedMessageId
                    canReport = cachedData.reportStatus == .canReport
                } else if let cachedData = cachedData as? CachedUserData {
                    peerIsBlocked = cachedData.isBlocked
                    canReport = cachedData.reportStatus == .canReport
                    callsAvailable = cachedData.callsAvailable
                    callsPrivate = cachedData.callsPrivate
                } else if let cachedData = cachedData as? CachedGroupData {
                    canReport = cachedData.reportStatus == .canReport
                } else if let cachedData = cachedData as? CachedSecretChatData {
                    canReport = cachedData.reportStatus == .canReport
                }
                
                var pinnedMessage: Message?
                if let pinnedMessageId = pinnedMessageId {
                    pinnedMessage = messages?[pinnedMessageId]
                }
                
                var pinnedMessageUpdated = false
                if let current = strongSelf.presentationInterfaceState.pinnedMessage, let updated = pinnedMessage {
                    if current.id != updated.id || current.stableVersion != updated.stableVersion {
                        pinnedMessageUpdated = true
                    }
                } else if (strongSelf.presentationInterfaceState.pinnedMessage != nil) != (pinnedMessage != nil) {
                    pinnedMessageUpdated = true
                }
                
                if strongSelf.presentationInterfaceState.pinnedMessageId != pinnedMessageId || strongSelf.presentationInterfaceState.peerIsBlocked != peerIsBlocked || strongSelf.presentationInterfaceState.canReportPeer != canReport || pinnedMessageUpdated {
                    strongSelf.updateChatPresentationInterfaceState(animated: true, interactive: true, { state in
                        return state.updatedPinnedMessageId(pinnedMessageId).updatedPinnedMessage(pinnedMessage).updatedPeerIsBlocked(peerIsBlocked).updatedCanReportPeer(canReport).updatedCallsAvailable(callsAvailable).updatedCallsPrivate(callsPrivate).updatedTitlePanelContext({ context in
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
                strongSelf.updateChatPresentationInterfaceState(animated: true, interactive: strongSelf.isViewLoaded && strongSelf.view.window != nil, {
                    $0.updatedChatHistoryState(state)
                })
            }
        })
        
        self.ready.set(combineLatest(self.chatDisplayNode.historyNode.historyState.get(), self._chatLocationInfoReady.get(), initialData) |> map { _, chatLocationInfoReady, _ in
            return chatLocationInfoReady
        })
        
        self.chatDisplayNode.historyNode.contentPositionChanged = { [weak self] offset in
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
                
                strongSelf.chatDisplayNode.navigateButtons.displayDownButton = !offsetAlpha.isZero
            }
        }
        
        self.chatDisplayNode.historyNode.scrolledToIndex = { [weak self] toIndex in
            if let strongSelf = self, case let .message(index) = toIndex {
                if let controllerInteraction = strongSelf.controllerInteraction {
                    if let message = strongSelf.chatDisplayNode.historyNode.messageInCurrentHistoryView(index.id) {
                        let highlightedState = ChatInterfaceHighlightedState(messageStableId: message.stableId)
                        controllerInteraction.highlightedState = highlightedState
                        strongSelf.updateItemNodesHighlightedStates(animated: true)
                        
                        strongSelf.messageContextDisposable.set((Signal<Void, NoError>.complete() |> delay(0.7, queue: Queue.mainQueue())).start(completed: {
                            if let strongSelf = self, let controllerInteraction = strongSelf.controllerInteraction {
                                if controllerInteraction.highlightedState == highlightedState {
                                    controllerInteraction.highlightedState = nil
                                    strongSelf.updateItemNodesHighlightedStates(animated: true)
                                }
                            }
                        }))
                    }
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
                if let strongSelf = self, let validLayout = strongSelf.validLayout {
                    var mappedTransition: (ChatHistoryListViewTransition, ListViewUpdateSizeAndInsets?)?
                    
                    strongSelf.chatDisplayNode.containerLayoutUpdated(validLayout, navigationBarHeight: strongSelf.navigationHeight, transition: .animated(duration: 0.4, curve: .spring), listViewTransaction: { updateSizeAndInsets, _, _ in
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
                        
                        let scrollToItem = ListViewScrollToItem(index: 0, position: .top(0.0), animated: true, curve: .Spring(duration: 0.4), directionHint: .Up)
                        
                        var stationaryItemRange: (Int, Int)?
                        if let maxInsertedItem = maxInsertedItem {
                            stationaryItemRange = (maxInsertedItem + 1, Int.max)
                        }
                        
                        mappedTransition = (ChatHistoryListViewTransition(historyView: transition.historyView, deleteItems: deleteItems, insertItems: insertItems, updateItems: transition.updateItems, options: options, scrollToItem: scrollToItem, stationaryItemRange: stationaryItemRange, initialData: transition.initialData, keyboardButtonsMessage: transition.keyboardButtonsMessage, cachedData: transition.cachedData, cachedDataMessages: transition.cachedDataMessages, readStateData: transition.readStateData, scrolledToIndex: transition.scrolledToIndex, animateIn: false), updateSizeAndInsets)
                    })
                    
                    if let mappedTransition = mappedTransition {
                        return mappedTransition
                    }
                }
                return (transition, nil)
            }
        }
        
        self.chatDisplayNode.sendMessages = { [weak self] messages in
            if let strongSelf = self, case let .peer(peerId) = strongSelf.chatLocation {
                strongSelf.commitPurposefulAction()
                
                let _ = (enqueueMessages(account: strongSelf.account, peerId: peerId, messages: strongSelf.transformEnqueueMessages(messages)) |> deliverOnMainQueue).start(next: { _ in
                    if let strongSelf = self {
                        strongSelf.chatDisplayNode.historyNode.scrollToEndOfHistory()
                    }
                })
            }
        }
        
        self.chatDisplayNode.requestUpdateChatInterfaceState = { [weak self] animated, f in
            self?.updateChatPresentationInterfaceState(animated: animated,  interactive: true, { $0.updatedInterfaceState(f) })
        }
        
        self.chatDisplayNode.requestUpdateInterfaceState = { [weak self] transition, interactive, f in
            self?.updateChatPresentationInterfaceState(transition: transition, interactive: interactive, f)
        }
        
        self.chatDisplayNode.displayAttachmentMenu = { [weak self] in
            guard let strongSelf = self else {
                return
            }
            if case .peer = strongSelf.chatLocation, let messageId = strongSelf.presentationInterfaceState.interfaceState.editMessage?.messageId {
                let _ = (strongSelf.account.postbox.transaction { transaction -> Message? in
                    return transaction.getMessage(messageId)
                } |> deliverOnMainQueue).start(next: { message in
                    guard let strongSelf = self, let editMessageState = strongSelf.presentationInterfaceState.editMessageState, case let .media(options) = editMessageState.content else {
                        return
                    }
                    strongSelf.presentAttachmentMenu(editMediaOptions: options)
                })
            } else {
                strongSelf.presentAttachmentMenu(editMediaOptions: nil)
            }
        }
        
        let postbox = self.account.postbox
        self.chatDisplayNode.displayPasteMenu = { [weak self] images in
            let _ = (postbox.transaction { transaction -> GeneratedMediaStoreSettings in
                let entry = transaction.getPreferencesEntry(key: ApplicationSpecificPreferencesKeys.generatedMediaStoreSettings) as? GeneratedMediaStoreSettings
                return entry ?? GeneratedMediaStoreSettings.defaultSettings
                }
            |> deliverOnMainQueue).start(next: { [weak self] settings in
                if let strongSelf = self, let peer = strongSelf.presentationInterfaceState.renderedPeer?.peer {
                    let controller = legacyPasteMenu(account: strongSelf.account, peer: peer, saveEditedPhotos: settings.storeEditedPhotos, allowGrouping: true, theme: strongSelf.presentationData.theme, strings: strongSelf.presentationData.strings, images: images, sendMessagesWithSignals: { signals in
                        self?.enqueueMediaMessages(signals: signals)
                    })
                    strongSelf.chatDisplayNode.dismissInput()
                    strongSelf.present(controller, in: .window(.root))
                }
            })
        }
        
        self.chatDisplayNode.updateTypingActivity = { [weak self] value in
            if let strongSelf = self, strongSelf.presentationInterfaceState.interfaceState.editMessage == nil {
                if value {
                    strongSelf.typingActivityPromise.set(Signal<Bool, NoError>.single(true)
                    |> then(
                        Signal<Bool, NoError>.single(false)
                        |> delay(4.0, queue: Queue.mainQueue())
                    ))
                } else {
                    strongSelf.typingActivityPromise.set(.single(false))
                }
            }
        }
        
        self.chatDisplayNode.dismissUrlPreview = { [weak self] in
            if let strongSelf = self {
                if let _ = strongSelf.presentationInterfaceState.interfaceState.editMessage {
                    if let (link, _) = strongSelf.presentationInterfaceState.editingUrlPreview {
                        strongSelf.updateChatPresentationInterfaceState(animated: true, interactive: true, {
                            $0.updatedInterfaceState {
                                $0.withUpdatedEditMessage($0.editMessage.flatMap { $0.withUpdatedDisableUrlPreview(link) })
                            }
                        })
                    }
                } else {
                    if let (link, _) = strongSelf.presentationInterfaceState.urlPreview {
                        strongSelf.updateChatPresentationInterfaceState(animated: true, interactive: true, {
                            $0.updatedInterfaceState {
                                $0.withUpdatedComposeDisableUrlPreview(link)
                            }
                        })
                    }
                }
            }
        }
        
        self.chatDisplayNode.navigateButtons.downPressed = { [weak self] in
            if let strongSelf = self, strongSelf.isNodeLoaded {
                if let messageId = strongSelf.historyNavigationStack.removeLast() {
                    strongSelf.navigateToMessage(from: nil, to: .id(messageId.id), rememberInStack: false)
                } else {
                    strongSelf.chatDisplayNode.historyNode.scrollToEndOfHistory()
                }
            }
        }
        
        self.chatDisplayNode.navigateButtons.mentionsPressed = { [weak self] in
            if let strongSelf = self, strongSelf.isNodeLoaded, case let .peer(peerId) = strongSelf.chatLocation {
                let signal = earliestUnseenPersonalMentionMessage(postbox: strongSelf.account.postbox, network: strongSelf.account.network, peerId: peerId)
                strongSelf.navigationActionDisposable.set((signal |> deliverOnMainQueue).start(next: { result in
                    if let strongSelf = self {
                        switch result {
                            case let .result(messageId):
                                if let messageId = messageId {
                                    strongSelf.navigateToMessage(from: nil, to: .id(messageId))
                                }
                            case .loading:
                                break
                        }
                    }
                }))
            }
        }
        
        let interfaceInteraction = ChatPanelInterfaceInteraction(setupReplyMessage: { [weak self] messageId in
            if let strongSelf = self, strongSelf.isNodeLoaded, canSendMessagesToChat(strongSelf.presentationInterfaceState) {
                if let message = strongSelf.chatDisplayNode.historyNode.messageInCurrentHistoryView(messageId) {
                    strongSelf.updateChatPresentationInterfaceState(animated: true, interactive: true, { $0.updatedInterfaceState({ $0.withUpdatedReplyMessageId(message.id) }).updatedSearch(nil) })
                    strongSelf.chatDisplayNode.ensureInputViewFocused()
                }
            }
        }, setupEditMessage: { [weak self] messageId in
            if let strongSelf = self, strongSelf.isNodeLoaded {
                guard let messageId = messageId else {
                    strongSelf.updateChatPresentationInterfaceState(animated: true, interactive: true, { state in
                        var state = state
                        state = state.updatedInterfaceState {
                            $0.withUpdatedEditMessage(nil)
                        }
                        state = state.updatedEditMessageState(nil)
                        return state
                    })
                    strongSelf.editMessageDisposable.set(nil)
                    
                    return
                }
                if let message = strongSelf.chatDisplayNode.historyNode.messageInCurrentHistoryView(messageId) {
                    strongSelf.updateChatPresentationInterfaceState(animated: true, interactive: true, { state in
                        var updated = state.updatedInterfaceState {
                            var entities: [MessageTextEntity] = []
                            for attribute in message.attributes {
                                if let attribute = attribute as? TextEntitiesMessageAttribute {
                                    entities = attribute.entities
                                    break
                                }
                            }
                            return $0.withUpdatedEditMessage(ChatEditMessageState(messageId: messageId, inputState: ChatTextInputState(inputText: chatInputStateStringWithAppliedEntities(message.text, entities: entities)), disableUrlPreview: nil))
                        }
                        
                        updated = updatedChatEditInterfaceMessagetState(state: updated, message: message)
                        updated = updated.updatedInputMode({ _ in
                            return .text
                        })
                        
                        return updated
                    })
                }
            }
        }, beginMessageSelection: { [weak self] messageIds in
            if let strongSelf = self, strongSelf.isNodeLoaded {
                strongSelf.updateChatPresentationInterfaceState(animated: true, interactive: true,{ $0.updatedInterfaceState { $0.withUpdatedSelectedMessages(messageIds) } })
            }
        }, deleteSelectedMessages: { [weak self] in
            if let strongSelf = self {
                if let messageIds = strongSelf.presentationInterfaceState.interfaceState.selectionState?.selectedIds, !messageIds.isEmpty {
                    strongSelf.messageContextDisposable.set((chatAvailableMessageActions(postbox: strongSelf.account.postbox, accountPeerId: strongSelf.account.peerId, messageIds: messageIds)
                    |> deliverOnMainQueue).start(next: { actions in
                        if let strongSelf = self, !actions.options.isEmpty {
                            if let banAuthor = actions.banAuthor {
                                strongSelf.presentBanMessageOptions(author: banAuthor, messageIds: messageIds, options: actions.options)
                            } else {
                                strongSelf.presentDeleteMessageOptions(messageIds: messageIds, options: actions.options)
                            }
                        }
                    }))
                }
            }
        }, reportSelectedMessages: { [weak self] in
            if let strongSelf = self, let messageIds = strongSelf.presentationInterfaceState.interfaceState.selectionState?.selectedIds, !messageIds.isEmpty {
                strongSelf.present(peerReportOptionsController(account: strongSelf.account, subject: .messages(Array(messageIds).sorted()), present: { c, a in
                    self?.present(c, in: .window(.root), with: a)
                }), in: .window(.root))
            }
        }, reportMessages: { [weak self] messages in
            if let strongSelf = self, !messages.isEmpty {
                strongSelf.present(peerReportOptionsController(account: strongSelf.account, subject: .messages(messages.map({ $0.id }).sorted()), present: { c, a in
                    self?.present(c, in: .window(.root), with: a)
                }), in: .window(.root))
            }
        }, deleteMessages: { [weak self] messages in
            if let strongSelf = self, !messages.isEmpty {
                let messageIds = Set(messages.map { $0.id })
                strongSelf.messageContextDisposable.set((chatAvailableMessageActions(postbox: strongSelf.account.postbox, accountPeerId: strongSelf.account.peerId, messageIds: messageIds)
                |> deliverOnMainQueue).start(next: { actions in
                    if let strongSelf = self, !actions.options.isEmpty {
                        if let banAuthor = actions.banAuthor {
                            strongSelf.presentBanMessageOptions(author: banAuthor, messageIds: messageIds, options: actions.options)
                        } else {
                            var isAction = false
                            if messages.count == 1 {
                                for media in messages[0].media {
                                    if media is TelegramMediaAction {
                                        isAction = true
                                    }
                                }
                            }
                            if isAction && (actions.options == .deleteGlobally || actions.options == .deleteLocally) {
                                let _ = deleteMessagesInteractively(postbox: strongSelf.account.postbox, messageIds: Array(messageIds), type: actions.options == .deleteLocally ? .forLocalPeer : .forEveryone).start()
                            } else {
                                strongSelf.presentDeleteMessageOptions(messageIds: messageIds, options: actions.options)
                            }
                        }
                    }
                }))
            }
        }, forwardSelectedMessages: { [weak self] in
            if let strongSelf = self {
                if let forwardMessageIdsSet = strongSelf.presentationInterfaceState.interfaceState.selectionState?.selectedIds {
                    let forwardMessageIds = Array(forwardMessageIdsSet).sorted()
                    strongSelf.forwardMessages(messageIds: forwardMessageIds)
                }
            }
        }, forwardMessages: { [weak self] messages in
            if let strongSelf = self, !messages.isEmpty {
                let forwardMessageIds = messages.map { $0.id }.sorted()
                strongSelf.forwardMessages(messageIds: forwardMessageIds)
            }
        }, shareSelectedMessages: { [weak self] in
            if let strongSelf = self, let selectedIds = strongSelf.presentationInterfaceState.interfaceState.selectionState?.selectedIds, !selectedIds.isEmpty {
                let _ = (strongSelf.account.postbox.transaction { transaction -> [Message] in
                    var messages: [Message] = []
                    for id in selectedIds {
                        if let message = transaction.getMessage(id) {
                            messages.append(message)
                        }
                    }
                    return messages
                } |> deliverOnMainQueue).start(next: { messages in
                    if let strongSelf = self, !messages.isEmpty {
                        strongSelf.updateChatPresentationInterfaceState(animated: true, interactive: true, { $0.updatedInterfaceState({ $0.withoutSelectionState() }) })
                        
                        let shareController = ShareController(account: strongSelf.account, subject: .messages(messages.sorted(by: { lhs, rhs in
                            return MessageIndex(lhs) < MessageIndex(rhs)
                        })), externalShare: true, immediateExternalShare: true)
                        strongSelf.chatDisplayNode.dismissInput()
                        strongSelf.present(shareController, in: .window(.root))
                    }
                })
            }
        }, updateTextInputStateAndMode: { [weak self] f in
            if let strongSelf = self {
                strongSelf.updateChatPresentationInterfaceState(animated: true, interactive: true, { state in
                    let (updatedState, updatedMode) = f(state.interfaceState.effectiveInputState, state.inputMode)
                    return state.updatedInterfaceState { interfaceState in
                        
                        return interfaceState.withUpdatedEffectiveInputState(updatedState)
                        }.updatedInputMode({ _ in updatedMode })
                })
            }
        }, updateInputModeAndDismissedButtonKeyboardMessageId: { [weak self] f in
            if let strongSelf = self {
                strongSelf.updateChatPresentationInterfaceState(animated: true, interactive: true, {
                    let (updatedInputMode, updatedClosedButtonKeyboardMessageId) = f($0)
                    return $0.updatedInputMode({ _ in return updatedInputMode }).updatedInterfaceState({ $0.withUpdatedMessageActionsState({ $0.withUpdatedClosedButtonKeyboardMessageId(updatedClosedButtonKeyboardMessageId) }) })
                })
            }
        }, editMessage: { [weak self] in
            if let strongSelf = self, let editMessage = strongSelf.presentationInterfaceState.interfaceState.editMessage {
                var disableUrlPreview = false
                if let (link, _) = strongSelf.presentationInterfaceState.editingUrlPreview {
                    if editMessage.disableUrlPreview == link {
                        disableUrlPreview = true
                    }
                }
                
                let editingMessage = strongSelf.editingMessage
                let text = trimChatInputText(editMessage.inputState.inputText)
                let entities = generateTextEntities(text.string, enabledTypes: .all, currentEntities: generateChatInputTextEntities(text))
                var entitiesAttribute: TextEntitiesMessageAttribute?
                if !entities.isEmpty {
                    entitiesAttribute = TextEntitiesMessageAttribute(entities: entities)
                }
                
                let media: RequestEditMessageMedia
                if let editMediaReference = strongSelf.presentationInterfaceState.editMessageState?.mediaReference {
                    media = .update(editMediaReference)
                } else {
                    media = .keep
                }
                
                strongSelf.editMessageDisposable.set((requestEditMessage(account: strongSelf.account, messageId: editMessage.messageId, text: text.string, media: media
                    , entities: entitiesAttribute, disableUrlPreview: disableUrlPreview) |> deliverOnMainQueue |> afterDisposed({
                        editingMessage.set(nil)
                    })).start(next: { result in
                    guard let strongSelf = self else {
                        return
                    }
                    switch result {
                        case let .progress(value):
                            editingMessage.set(value)
                        case .done:
                            editingMessage.set(nil)
                            strongSelf.updateChatPresentationInterfaceState(animated: true, interactive: true, { state in
                                var state = state
                                state = state.updatedInterfaceState({ $0.withUpdatedEditMessage(nil) })
                                state = state.updatedEditMessageState(nil)
                                return state
                            })
                    }
                }, error: { error in
                    guard let strongSelf = self else {
                        return
                    }
                    
                    editingMessage.set(nil)
                    
                    let text: String
                    switch error {
                        case .generic:
                            text = strongSelf.presentationData.strings.Channel_EditMessageErrorGeneric
                        case .restricted:
                            text = strongSelf.presentationData.strings.Group_ErrorSendRestrictedMedia
                    }
                    strongSelf.present(standardTextAlertController(theme: AlertControllerTheme(presentationTheme: strongSelf.presentationData.theme), title: nil, text: text, actions: [TextAlertAction(type: .defaultAction, title: strongSelf.presentationData.strings.Common_OK, action: {
                    })]), in: .window(.root))
                }))
            }
        }, beginMessageSearch: { [weak self] domain, query in
            if let strongSelf = self {
                strongSelf.updateChatPresentationInterfaceState(animated: true, interactive: true, { current in
                    return current.updatedTitlePanelContext {
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
                    }.updatedSearch(current.search == nil ? ChatSearchData(domain: domain).withUpdatedQuery(query) : current.search?.withUpdatedDomain(domain).withUpdatedQuery(query))
                })
            }
        }, dismissMessageSearch: { [weak self] in
            if let strongSelf = self {
                strongSelf.updateChatPresentationInterfaceState(animated: true, interactive: true, { current in
                    return current.updatedSearch(nil)
                })
            }
        }, updateMessageSearch: { [weak self] query in
            if let strongSelf = self {
                strongSelf.updateChatPresentationInterfaceState(animated: true, interactive: true, { current in
                    if let data = current.search {
                        return current.updatedSearch(data.withUpdatedQuery(query))
                    } else {
                        return current
                    }
                })
            }
        }, navigateMessageSearch: { [weak self] action in
            if let strongSelf = self {
                var navigateIndex: MessageIndex?
                strongSelf.updateChatPresentationInterfaceState(animated: true, interactive: true, { current in
                    if let data = current.search, let resultsState = data.resultsState {
                        if let currentId = resultsState.currentId, let index = resultsState.messageIndices.index(where: { $0.id == currentId }) {
                            var updatedIndex: Int?
                            switch action {
                                case .earlier:
                                    if index != 0 {
                                        updatedIndex = index - 1
                                    }
                                case .later:
                                    if index != resultsState.messageIndices.count - 1 {
                                        updatedIndex = index + 1
                                    }
                            }
                            if let updatedIndex = updatedIndex {
                                navigateIndex = resultsState.messageIndices[updatedIndex]
                                return current.updatedSearch(data.withUpdatedResultsState(ChatSearchResultsState(messageIndices: resultsState.messageIndices, currentId: resultsState.messageIndices[updatedIndex].id)))
                            }
                        }
                    }
                    return current
                })
                if let navigateIndex = navigateIndex {
                    switch strongSelf.chatLocation {
                        case .peer:
                            strongSelf.navigateToMessage(from: nil, to: .id(navigateIndex.id))
                        case .group:
                            strongSelf.navigateToMessage(from: nil, to: .index(navigateIndex))
                    }
                }
            }
        }, openCalendarSearch: { [weak self] in
            if let strongSelf = self, case let .peer(peerId) = strongSelf.chatLocation {
                strongSelf.chatDisplayNode.dismissInput()
                
                let controller = ChatDateSelectionSheet(theme: strongSelf.presentationData.theme, strings: strongSelf.presentationData.strings, completion: { timestamp in
                    if let strongSelf = self {
                        strongSelf.loadingMessage.set(true)
                        strongSelf.messageIndexDisposable.set((searchMessageIdByTimestamp(account: strongSelf.account, peerId: peerId, timestamp: timestamp) |> deliverOnMainQueue).start(next: { messageId in
                            if let strongSelf = self {
                                strongSelf.loadingMessage.set(false)
                                if let messageId = messageId {
                                    strongSelf.navigateToMessage(from: nil, to: .id(messageId))
                                }
                            }
                        }))
                    }
                })
                strongSelf.present(controller, in: .window(.root))
            }
        }, toggleMembersSearch: { [weak self] value in
            if let strongSelf = self {
                strongSelf.updateChatPresentationInterfaceState(animated: true, interactive: true, { state in
                    if value {
                        return state.updatedSearch(ChatSearchData(query: "", domain: .members, domainSuggestionContext: .none, resultsState: nil))
                    } else if let search = state.search {
                        switch search.domain {
                            case .everything:
                                return state
                            case .members:
                                return state.updatedSearch(ChatSearchData(query: "", domain: .everything, domainSuggestionContext: .none, resultsState: nil))
                            case .member:
                                return state.updatedSearch(ChatSearchData(query: "", domain: .members, domainSuggestionContext: .none, resultsState: nil))
                        }
                    } else {
                        return state
                    }
                })
            }
        }, navigateToMessage: { [weak self] messageId in
            self?.navigateToMessage(from: nil, to: .id(messageId))
        }, openPeerInfo: { [weak self] in
            self?.navigationButtonAction(.openChatInfo)
        }, togglePeerNotifications: { [weak self] in
            if let strongSelf = self, case let .peer(peerId) = strongSelf.chatLocation {
                let _ = togglePeerMuted(account: strongSelf.account, peerId: peerId).start()
            }
        }, sendContextResult: { [weak self] results, result in
            self?.enqueueChatContextResult(results, result)
        }, sendBotCommand: { [weak self] botPeer, command in
            if let strongSelf = self, canSendMessagesToChat(strongSelf.presentationInterfaceState) {
                if let peer = strongSelf.presentationInterfaceState.renderedPeer?.peer, let addressName = botPeer.addressName {
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
                                $0.updatedInterfaceState { $0.withUpdatedReplyMessageId(nil).withUpdatedComposeInputState(ChatTextInputState(inputText: NSAttributedString(string: ""))).withUpdatedComposeDisableUrlPreview(nil) }
                            })
                        }
                    })
                    var attributes: [MessageAttribute] = []
                    let entities = generateTextEntities(messageText, enabledTypes: .all)
                    if !entities.isEmpty {
                        attributes.append(TextEntitiesMessageAttribute(entities: entities))
                    }
                    strongSelf.sendMessages([.message(text: messageText, attributes: attributes, mediaReference: nil, replyToMessageId: replyMessageId, localGroupingKey: nil)])
                }
            }
        }, sendBotStart: { [weak self] payload in
            if let strongSelf = self, canSendMessagesToChat(strongSelf.presentationInterfaceState) {
                strongSelf.startBot(payload)
            }
        }, botSwitchChatWithPayload: { [weak self] peerId, payload in
            if let strongSelf = self, case let .peer(currentPeerId) = strongSelf.chatLocation {
                strongSelf.openPeer(peerId: peerId, navigation: .withBotStartPayload(ChatControllerInitialBotStart(payload: payload, behavior: .automatic(returnToPeerId: currentPeerId))), fromMessage: nil)
            }
        }, beginMediaRecording: { [weak self] isVideo in
            guard let strongSelf = self else {
                return
            }
            let requestId = strongSelf.beginMediaRecordingRequestId
            let begin: () -> Void = {
                guard let strongSelf = self, strongSelf.beginMediaRecordingRequestId == requestId else {
                    return
                }
                let hasOngoingCall: Signal<Bool, NoError>
                if let signal = strongSelf.account.telegramApplicationContext.hasOngoingCall {
                    hasOngoingCall = signal
                } else {
                    hasOngoingCall = .single(false)
                }
                let _ = (hasOngoingCall
                |> deliverOnMainQueue).start(next: { hasOngoingCall in
                    guard let strongSelf = self, strongSelf.beginMediaRecordingRequestId == requestId else {
                        return
                    }
                    if hasOngoingCall {
                        strongSelf.present(standardTextAlertController(theme: AlertControllerTheme(presentationTheme: strongSelf.presentationData.theme), title: strongSelf.presentationData.strings.Call_CallInProgressTitle, text: strongSelf.presentationData.strings.Call_RecordingDisabledMessage, actions: [TextAlertAction(type: .defaultAction, title: strongSelf.presentationData.strings.Common_OK, action: {
                        })]), in: .window(.root))
                    } else {
                        if isVideo {
                            strongSelf.requestVideoRecorder()
                        } else {
                            strongSelf.requestAudioRecorder(beginWithTone: false)
                        }
                    }
                })
            }
            DeviceAccess.authorizeAccess(to: .microphone(isVideo ? .video : .audio), presentationData: strongSelf.presentationData, present: { c, a in
                self?.present(c, in: .window(.root), with: a)
            }, openSettings: {
                self?.account.telegramApplicationContext.applicationBindings.openSettings()
            }, { granted in
                guard let strongSelf = self, granted else {
                    return
                }
                if isVideo {
                    DeviceAccess.authorizeAccess(to: .camera, presentationData: strongSelf.presentationData, present: { c, a in
                        self?.present(c, in: .window(.root), with: a)
                    }, openSettings: {
                        self?.account.telegramApplicationContext.applicationBindings.openSettings()
                    }, { granted in
                        if granted {
                            begin()
                        }
                    })
                } else {
                    begin()
                }
            })
        }, finishMediaRecording: { [weak self] action in
            guard let strongSelf = self else {
                return
            }
            strongSelf.beginMediaRecordingRequestId += 1
            strongSelf.dismissMediaRecorder(action)
        }, stopMediaRecording: { [weak self] in
            guard let strongSelf = self else {
                return
            }
            strongSelf.beginMediaRecordingRequestId += 1
            self?.stopMediaRecorder()
        }, lockMediaRecording: { [weak self] in
            self?.lockMediaRecorder()
        }, deleteRecordedMedia: { [weak self] in
            self?.deleteMediaRecording()
        }, sendRecordedMedia: { [weak self] in
            self?.sendMediaRecording()
        }, displayRestrictedInfo: { [weak self] subject in
            if let strongSelf = self, let peer = strongSelf.presentationInterfaceState.renderedPeer?.peer, let bannedRights = (peer as? TelegramChannel)?.bannedRights {
                let banDescription: String
                switch subject {
                    case .stickers:
                        banDescription = strongSelf.presentationInterfaceState.strings.Group_ErrorSendRestrictedStickers
                    case .mediaRecording:
                        if bannedRights.untilDate != 0 && bannedRights.untilDate != Int32.max {
                            banDescription = strongSelf.presentationInterfaceState.strings.Conversation_RestrictedMediaTimed(stringForFullDate(timestamp: bannedRights.untilDate, strings: strongSelf.presentationInterfaceState.strings, timeFormat: .regular)).0
                        } else {
                            banDescription = strongSelf.presentationInterfaceState.strings.Conversation_RestrictedMedia
                        }
                }
                if strongSelf.recordingModeFeedback == nil {
                    strongSelf.recordingModeFeedback = HapticFeedback()
                    strongSelf.recordingModeFeedback?.prepareError()
                }
                
                strongSelf.recordingModeFeedback?.error()
                
                let rect: CGRect?
                switch subject {
                    case .stickers:
                        rect = strongSelf.chatDisplayNode.frameForStickersButton()
                    case .mediaRecording:
                        rect = strongSelf.chatDisplayNode.frameForInputActionButton()
                }
                
                if let tooltipController = strongSelf.mediaRecordingModeTooltipController {
                    tooltipController.text = banDescription
                } else if let rect = rect {
                    let tooltipController = TooltipController(text: banDescription)
                    strongSelf.mediaRecordingModeTooltipController = tooltipController
                    tooltipController.dismissed = { [weak tooltipController] in
                        if let strongSelf = self, let tooltipController = tooltipController, strongSelf.mediaRecordingModeTooltipController === tooltipController {
                            strongSelf.mediaRecordingModeTooltipController = nil
                        }
                    }
                    strongSelf.present(tooltipController, in: .window(.root), with: TooltipControllerPresentationArguments(sourceNodeAndRect: {
                        if let strongSelf = self {
                            return (strongSelf.chatDisplayNode, rect)
                        }
                        return nil
                    }))
                }
            }
        }, switchMediaRecordingMode: { [weak self] in
            if let strongSelf = self {
                if strongSelf.recordingModeFeedback == nil {
                    strongSelf.recordingModeFeedback = HapticFeedback()
                    strongSelf.recordingModeFeedback?.prepareImpact()
                }
                
                strongSelf.recordingModeFeedback?.impact()
                var updatedMode: ChatTextInputMediaRecordingButtonMode?
                
                strongSelf.updateChatPresentationInterfaceState(interactive: true, {
                    return $0.updatedInterfaceState { current in
                        let mode: ChatTextInputMediaRecordingButtonMode
                        switch current.mediaRecordingMode {
                            case .audio:
                                mode = .video
                            case .video:
                                mode = .audio
                        }
                        updatedMode = mode
                        return current.withUpdatedMediaRecordingMode(mode)
                    }
                })
                
                if let updatedMode = updatedMode, updatedMode == .video {
                    let _ = ApplicationSpecificNotice.incrementChatMediaMediaRecordingTips(postbox: strongSelf.account.postbox, count: 3).start()
                }
                
                strongSelf.displayMediaRecordingTip()
            }
        }, setupMessageAutoremoveTimeout: { [weak self] in
            if let strongSelf = self, case let .peer(peerId) = strongSelf.chatLocation, peerId.namespace == Namespaces.Peer.SecretChat {
                strongSelf.chatDisplayNode.dismissInput()
                
                if let peer = strongSelf.presentationInterfaceState.renderedPeer?.peer as? TelegramSecretChat {
                    let controller = ChatSecretAutoremoveTimerActionSheetController(theme: strongSelf.presentationData.theme, strings: strongSelf.presentationData.strings, currentValue: peer.messageAutoremoveTimeout == nil ? 0 : peer.messageAutoremoveTimeout!, applyValue: { value in
                        if let strongSelf = self {
                            let _ = setSecretChatMessageAutoremoveTimeoutInteractively(account: strongSelf.account, peerId: peer.id, timeout: value == 0 ? nil : value).start()
                        }
                    })
                    strongSelf.present(controller, in: .window(.root))
                }
            }
        }, sendSticker: { [weak self] file in
            if let strongSelf = self, canSendMessagesToChat(strongSelf.presentationInterfaceState) {
                strongSelf.chatDisplayNode.setupSendActionOnViewUpdate({
                    if let strongSelf = self {
                        strongSelf.updateChatPresentationInterfaceState(animated: true, interactive: false, {
                            $0.updatedInterfaceState {
                                $0.withUpdatedReplyMessageId(nil).withUpdatedComposeInputState(ChatTextInputState(inputText: NSAttributedString(string: ""))).withUpdatedComposeDisableUrlPreview(nil)
                                
                                }.updatedInputMode { current in
                                if case let .media(mode, maybeExpanded) = current, maybeExpanded != nil {
                                    return .media(mode: mode, expanded: nil)
                                }
                                return current
                            }
                        })
                    }
                })
                strongSelf.sendMessages([.message(text: "", attributes: [], mediaReference: file.abstract, replyToMessageId: strongSelf.presentationInterfaceState.interfaceState.replyMessageId, localGroupingKey: nil)])
            }
        }, unblockPeer: { [weak self] in
            self?.unblockPeer()
        }, pinMessage: { [weak self] messageId in
            if let strongSelf = self, case let .peer(currentPeerId) = strongSelf.chatLocation {
                if let peer = strongSelf.presentationInterfaceState.renderedPeer?.peer {
                    if let channel = peer as? TelegramChannel {
                        var canManagePin = false
                        if case .broadcast = channel.info {
                            canManagePin = channel.hasAdminRights([.canEditMessages])
                        } else {
                            canManagePin = channel.hasAdminRights([.canPinMessages])
                        }
                        
                        if canManagePin {
                            let pinAction: (Bool) -> Void = { notify in
                                if let strongSelf = self {
                                    let disposable: MetaDisposable
                                    if let current = strongSelf.unpinMessageDisposable {
                                        disposable = current
                                    } else {
                                        disposable = MetaDisposable()
                                        strongSelf.unpinMessageDisposable = disposable
                                    }
                                    disposable.set(requestUpdatePinnedMessage(account: strongSelf.account, peerId: currentPeerId, update: .pin(id: messageId, silent: !notify)).start())
                                }
                            }
                            if case .broadcast = channel.info {
                                pinAction(true)
                            } else {
                                strongSelf.present(standardTextAlertController(theme: AlertControllerTheme(presentationTheme: strongSelf.presentationData.theme), title: nil, text: strongSelf.presentationData.strings.Conversation_PinMessageAlertGroup, actions: [TextAlertAction(type: .genericAction, title: strongSelf.presentationData.strings.Conversation_PinMessageAlert_OnlyPin, action: {
                                    pinAction(false)
                                }), TextAlertAction(type: .defaultAction, title: strongSelf.presentationData.strings.Common_Yes, action: {
                                    pinAction(true)
                                })]), in: .window(.root))
                            }
                        } else {
                            if let pinnedMessageId = strongSelf.presentationInterfaceState.pinnedMessage?.id {
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
                if let peer = strongSelf.presentationInterfaceState.renderedPeer?.peer {
                    if let channel = peer as? TelegramChannel {
                        var canManagePin = false
                        if case .broadcast = channel.info {
                            canManagePin = channel.hasAdminRights([.canEditMessages])
                        } else {
                            canManagePin = channel.hasAdminRights([.canPinMessages])
                        }
                        
                        if canManagePin {
                            strongSelf.present(standardTextAlertController(theme: AlertControllerTheme(presentationTheme: strongSelf.presentationData.theme), title: nil, text: strongSelf.presentationData.strings.Conversation_UnpinMessageAlert, actions: [TextAlertAction(type: .genericAction, title: strongSelf.presentationData.strings.Common_No, action: {}), TextAlertAction(type: .genericAction, title: strongSelf.presentationData.strings.Common_Yes, action: {
                                if let strongSelf = self {
                                    let disposable: MetaDisposable
                                    if let current = strongSelf.unpinMessageDisposable {
                                        disposable = current
                                    } else {
                                        disposable = MetaDisposable()
                                        strongSelf.unpinMessageDisposable = disposable
                                    }
                                    disposable.set(requestUpdatePinnedMessage(account: strongSelf.account, peerId: peer.id, update: .clear).start())
                                }
                            })]), in: .window(.root))
                        } else {
                            if let pinnedMessage = strongSelf.presentationInterfaceState.pinnedMessage {
                                strongSelf.updateChatPresentationInterfaceState(animated: true, interactive: true, {
                                    return $0.updatedInterfaceState({ $0.withUpdatedMessageActionsState({ $0.withUpdatedClosedPinnedMessageId(pinnedMessage.id) }) })
                                })
                            }
                        }
                    }
                }
            }
        }, reportPeer: { [weak self] in
            self?.reportPeer()
            }, presentPeerContact: { [weak self] in
            self?.addPeerContact()
        }, dismissReportPeer: { [weak self] in
            self?.dismissReportPeer()
        }, deleteChat: { [weak self] in
            self?.deleteChat(reportChatSpam: false)
        }, beginCall: { [weak self] in
            if let strongSelf = self, case let .peer(peerId) = strongSelf.chatLocation {
                strongSelf.controllerInteraction?.callPeer(peerId)
            }
        }, toggleMessageStickerStarred: { [weak self] messageId in
            if let strongSelf = self, let message = strongSelf.chatDisplayNode.historyNode.messageInCurrentHistoryView(messageId) {
                var stickerFile: TelegramMediaFile?
                for media in message.media {
                    if let file = media as? TelegramMediaFile, file.isSticker {
                        stickerFile = file
                    }
                }
                if let stickerFile = stickerFile {
                    let postbox = strongSelf.account.postbox
                    let network = strongSelf.account.network
                    let _ = (strongSelf.account.postbox.transaction { transaction -> Signal<Void, NoError> in
                        if getIsStickerSaved(transaction: transaction, fileId: stickerFile.fileId) {
                            removeSavedSticker(transaction: transaction, mediaId: stickerFile.fileId)
                            return .complete()
                        } else {
                            return addSavedSticker(postbox: postbox, network: network, file: stickerFile)
                                |> `catch` { _ -> Signal<Void, NoError> in
                                    return .complete()
                                }
                        }
                    } |> switchToLatest).start()
                }
            }
        }, presentController: { [weak self] controller, arguments in
            self?.present(controller, in: .window(.root), with: arguments)
        }, getNavigationController: { [weak self] in
            return self?.navigationController as? NavigationController
        }, presentGlobalOverlayController: { [weak self] controller, arguments in
            self?.presentInGlobalOverlay(controller, with: arguments)
        }, navigateFeed: { [weak self] in
            if let strongSelf = self {
                strongSelf.chatDisplayNode.historyNode.scrollToNextMessage()
            }
        }, openGrouping: { [weak self] in
            if let strongSelf = self, case let .group(groupId) = strongSelf.chatLocation {
                (strongSelf.navigationController as? NavigationController)?.pushViewController(FeedGroupingController(account: strongSelf.account, groupId: groupId))
            }
        }, toggleSilentPost: { [weak self] in
            if let strongSelf = self {
                var value: Bool = false
                strongSelf.updateChatPresentationInterfaceState(interactive: true, {
                    $0.updatedInterfaceState {
                        value = !$0.silentPosting
                        return $0.withUpdatedSilentPosting(value)
                    }
                })
                
                var rect: CGRect? = strongSelf.chatDisplayNode.frameForInputPanelAccessoryButton(.silentPost(true))
                if rect == nil {
                    rect = strongSelf.chatDisplayNode.frameForInputPanelAccessoryButton(.silentPost(false))
                }
                
                let text: String
                if !value {
                    text = strongSelf.presentationData.strings.Conversation_SilentBroadcastTooltipOn
                } else {
                    text = strongSelf.presentationData.strings.Conversation_SilentBroadcastTooltipOff
                }
                
                if let tooltipController = strongSelf.silentPostTooltipController {
                    tooltipController.text = text
                } else if let rect = rect {
                    let tooltipController = TooltipController(text: text)
                    strongSelf.silentPostTooltipController = tooltipController
                    tooltipController.dismissed = { [weak tooltipController] in
                        if let strongSelf = self, let tooltipController = tooltipController, strongSelf.silentPostTooltipController === tooltipController {
                            strongSelf.silentPostTooltipController = nil
                        }
                    }
                    strongSelf.present(tooltipController, in: .window(.root), with: TooltipControllerPresentationArguments(sourceNodeAndRect: {
                        if let strongSelf = self {
                            return (strongSelf.chatDisplayNode, rect)
                        }
                        return nil
                    }))
                }
            }
        }, statuses: ChatPanelInterfaceInteractionStatuses(editingMessage: self.editingMessage.get(), startingBot: self.startingBot.get(), unblockingPeer: self.unblockingPeer.get(), searching: self.searching.get(), loadingMessage: self.loadingMessage.get()))
        
        switch self.chatLocation {
            case let .peer(peerId):
                let unreadCountsKey: PostboxViewKey = .unreadCounts(items: [.peer(peerId), .total(.filtered, .messages)])
                let notificationSettingsKey: PostboxViewKey = .peerNotificationSettings(peerIds: Set([peerId]))
                self.chatUnreadCountDisposable = (self.account.postbox.combinedView(keys: [unreadCountsKey, notificationSettingsKey])
                |> deliverOnMainQueue).start(next: { [weak self] views in
                    if let strongSelf = self {
                        var unreadCount: Int32 = 0
                        var totalChatCount: Int32 = 0
                        
                        if let view = views.views[unreadCountsKey] as? UnreadMessageCountsView {
                            if let count = view.count(for: .peer(peerId)) {
                                unreadCount = count
                            }
                            if let count = view.count(for: .total(.filtered, .chats)) {
                                totalChatCount = count
                            }
                        }
                        
                        strongSelf.chatDisplayNode.navigateButtons.unreadCount = unreadCount
                        
                        if let view = views.views[notificationSettingsKey] as? PeerNotificationSettingsView, let notificationSettings = view.notificationSettings[peerId] {
                            var globalRemainingUnreadChatCount = totalChatCount
                            if !notificationSettings.isRemovedFromTotalUnreadCount && unreadCount > 0 {
                                globalRemainingUnreadChatCount -= 1
                            }
                            
                            if globalRemainingUnreadChatCount > 0 {
                                strongSelf.navigationItem.badge = "\(globalRemainingUnreadChatCount)"
                            } else {
                                strongSelf.navigationItem.badge = ""
                            }
                        }
                    }
                })
            
                self.chatUnreadMentionCountDisposable = (self.account.viewTracker.unseenPersonalMessagesCount(peerId: peerId) |> deliverOnMainQueue).start(next: { [weak self] count in
                    if let strongSelf = self {
                        strongSelf.chatDisplayNode.navigateButtons.mentionCount = count
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
                            return postbox.transaction { transaction -> [(Peer, PeerInputActivity)] in
                                var result: [(Peer, PeerInputActivity)] = []
                                var peerCache: [PeerId: Peer] = [:]
                                for (peerId, activity) in activities {
                                    if let peer = transaction.getPeer(peerId) {
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
                            strongSelf.chatTitleView?.inputActivities = (peerId, activities)
                        }
                    })
                
                self.sentMessageEventsDisposable.set(self.account.pendingMessageManager.deliveredMessageEvents(peerId: peerId).start(next: { [weak self] _ in
                    if let strongSelf = self {
                        let inAppNotificationSettings: InAppNotificationSettings = strongSelf.account.telegramApplicationContext.currentInAppNotificationSettings.with { $0 }
                        
                        if inAppNotificationSettings.playSounds {
                            serviceSoundManager.playMessageDeliveredSound()
                        }
                    }
                }))
            case let .group(groupId):
                let unreadCountsKey: PostboxViewKey = .unreadCounts(items: [.group(groupId), .total(.filtered, .messages)])
                self.chatUnreadCountDisposable = (self.account.postbox.combinedView(keys: [unreadCountsKey]) |> deliverOnMainQueue).start(next: { [weak self] views in
                    if let strongSelf = self {
                        var unreadCount: Int32 = 0
                        var totalCount: Int32 = 0
                        
                        if let view = views.views[unreadCountsKey] as? UnreadMessageCountsView {
                            if let count = view.count(for: .group(groupId)) {
                                unreadCount = count
                            }
                            if let count = view.count(for: .total(.filtered, .messages)) {
                                totalCount = count
                            }
                        }
                        
                        strongSelf.chatDisplayNode.navigateButtons.unreadCount = unreadCount
                    }
                })
        }
        
        self.interfaceInteraction = interfaceInteraction
        self.chatDisplayNode.interfaceInteraction = interfaceInteraction
        
        self.galleryHiddenMesageAndMediaDisposable.set(self.account.telegramApplicationContext.mediaManager.galleryHiddenMediaManager.hiddenIds().start(next: { [weak self] ids in
            if let strongSelf = self, let controllerInteraction = strongSelf.controllerInteraction {
                var messageIdAndMedia: [MessageId: [Media]] = [:]
                
                for id in ids {
                    if case let .chat(messageId, media) = id {
                        messageIdAndMedia[messageId] = [media]
                    }
                }
                
                //if controllerInteraction.hiddenMedia != messageIdAndMedia {
                    controllerInteraction.hiddenMedia = messageIdAndMedia
                    
                    strongSelf.chatDisplayNode.historyNode.forEachItemNode { itemNode in
                        if let itemNode = itemNode as? ChatMessageItemView {
                            itemNode.updateHiddenMedia()
                        }
                    }
                //}
            }
        }))
        
        self.chatDisplayNode.dismissAsOverlay = { [weak self] in
            if let strongSelf = self {
                strongSelf.chatDisplayNode.animateDismissAsOverlay(completion: {
                    self?.presentingViewController?.dismiss(animated: false, completion: nil)
                })
            }
        }
        
        self.displayNodeDidLoad()
    }
    
    override public func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
    }
    
    override public func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        self.chatDisplayNode.historyNode.preloadPages = true
        self.chatDisplayNode.historyNode.canReadHistory.set(combineLatest((self.account.applicationContext as! TelegramApplicationContext).applicationBindings.applicationInForeground, self.canReadHistory.get()) |> map { a, b in
            return a && b
        })
        
        self.chatDisplayNode.loadInputPanels(theme: self.presentationInterfaceState.theme, strings: self.presentationInterfaceState.strings)
        
        self.recentlyUsedInlineBotsDisposable = (recentlyUsedInlineBots(postbox: self.account.postbox) |> deliverOnMainQueue).start(next: { [weak self] peers in
            self?.recentlyUsedInlineBotsValue = peers.filter({ $0.1 >= 0.14 }).map({ $0.0 })
        })
        
        if case .standard(false) = self.presentationInterfaceState.mode, self.raiseToListen == nil {
            self.raiseToListen = RaiseToListenManager(shouldActivate: { [weak self] in
                if let strongSelf = self, strongSelf.isNodeLoaded && strongSelf.canReadHistoryValue, strongSelf.presentationInterfaceState.interfaceState.editMessage == nil, strongSelf.playlistStateAndType == nil {
                    if strongSelf.presentationInterfaceState.inputTextPanelState.mediaRecordingState != nil {
                        return false
                    }
                    
                    if !strongSelf.traceVisibility() {
                        return false
                    }
                    
                    if !isTopmostChatController(strongSelf) {
                        return false
                    }
                    
                    if strongSelf.firstLoadedMessageToListen() != nil || strongSelf.chatDisplayNode.isTextInputPanelActive {
                        if strongSelf.account.telegramApplicationContext.immediateHasOngoingCall {
                            return false
                        }
                        
                        if case let .media(_, expanded) = strongSelf.presentationInterfaceState.inputMode, expanded != nil {
                            return false
                        }
                        
                        if !strongSelf.account.telegramApplicationContext.currentMediaInputSettings.with { $0.enableRaiseToSpeak } {
                            return false
                        }
                        
                        return true
                    }
                }
                return false
            }, activate: { [weak self] in
                self?.activateRaiseGesture()
            }, deactivate: { [weak self] in
                self?.deactivateRaiseGesture()
            })
            self.raiseToListen?.enabled = self.canReadHistoryValue
            self.tempVoicePlaylistEnded = { [weak self] in
                if let strongSelf = self, let raiseToListen = strongSelf.raiseToListen {
                    raiseToListen.activateBasedOnProximity()
                }
            }
            self.tempVoicePlaylistItemChanged = { [weak self] previousItem, currentItem in
                guard let strongSelf = self, case let .peer(peerId) = strongSelf.chatLocation else {
                    return
                }
                if let currentItem = currentItem?.id as? PeerMessagesMediaPlaylistItemId, let previousItem = previousItem?.id as? PeerMessagesMediaPlaylistItemId, previousItem.messageId.peerId == peerId, currentItem.messageId.peerId == peerId, currentItem.messageId != previousItem.messageId {
                    strongSelf.navigateToMessage(from: nil, to: .id(currentItem.messageId), scrollPosition: .center(.bottom), rememberInStack: false, animated: true, completion: nil)
                }
            }
        }
        
        if let arguments = self.presentationArguments as? ChatControllerOverlayPresentationData {
            //TODO clear arguments
            self.chatDisplayNode.animateInAsOverlay(from: arguments.expandData.0, completion: {
                arguments.expandData.1()
            })
        }
        
        if !self.didSetup3dTouch {
            self.didSetup3dTouch = true
            if #available(iOSApplicationExtension 9.0, *) {
                self.registerForPreviewing(with: self, sourceView: self.chatDisplayNode.historyNodeContainer.view, theme: PeekControllerTheme(presentationTheme: self.presentationData.theme), onlyNative: true)
                if case .peer = self.chatLocation, let buttonView = (self.chatInfoNavigationButton?.buttonItem.customDisplayNode as? ChatAvatarNavigationNode)?.avatarNode.view {
                    self.registerForPreviewing(with: self, sourceView: buttonView, theme: PeekControllerTheme(presentationTheme: self.presentationData.theme), onlyNative: true)
                }
                self.registerForPreviewing(with: self, sourceView: self.chatDisplayNode.historyNodeContainer.view, theme: PeekControllerTheme(presentationTheme: self.presentationData.theme), onlyNative: true)
            }
            
            if #available(iOSApplicationExtension 11.0, *) {
                let dropInteraction = UIDropInteraction(delegate: self)
                self.chatDisplayNode.view.addInteraction(dropInteraction)
            }
        }
        
        if !self.checkedPeerChatServiceActions {
            self.checkedPeerChatServiceActions = true
            if case let .peer(peerId) = self.chatLocation {
                let _ = checkPeerChatServiceActions(postbox: self.account.postbox, peerId: peerId).start()
            }
            
            if self.chatDisplayNode.frameForInputActionButton() != nil, self.presentationInterfaceState.interfaceState.mediaRecordingMode == .audio {
                let _ = (ApplicationSpecificNotice.getChatMediaMediaRecordingTips(postbox: self.account.postbox)
                |> deliverOnMainQueue).start(next: { [weak self] counter in
                    guard let strongSelf = self else {
                        return
                    }
                    var displayTip = false
                    if counter == 0 {
                        displayTip = true
                    } else if counter < 3 && arc4random_uniform(4) == 1 {
                        displayTip = true
                    }
                    if displayTip {
                        let _ = ApplicationSpecificNotice.incrementChatMediaMediaRecordingTips(postbox: strongSelf.account.postbox).start()
                        strongSelf.displayMediaRecordingTip()
                    }
                })
            }
        }
    }
    
    override public func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        
        self.chatDisplayNode.historyNode.canReadHistory.set(.single(false))
        self.saveInterfaceState()
        
        self.silentPostTooltipController?.dismiss()
        self.mediaRecordingModeTooltipController?.dismiss()
    }
    
    private func saveInterfaceState() {
        if case let .peer(peerId) = self.chatLocation {
            let timestamp = Int32(Date().timeIntervalSince1970)
            let scrollState = self.chatDisplayNode.historyNode.immediateScrollState()
            let interfaceState = self.presentationInterfaceState.interfaceState.withUpdatedTimestamp(timestamp).withUpdatedHistoryScrollState(scrollState)
            let _ = updatePeerChatInterfaceState(account: account, peerId: peerId, state: interfaceState).start()
        }
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
        
        self.validLayout = layout
        
        self.chatDisplayNode.containerLayoutUpdated(layout, navigationBarHeight: self.navigationHeight, transition: transition, listViewTransaction: { updateSizeAndInsets, additionalScrollDistance, scrollToTop in
            self.chatDisplayNode.historyNode.updateLayout(transition: transition, updateSizeAndInsets: updateSizeAndInsets, additionalScrollDistance: additionalScrollDistance, scrollToTop: scrollToTop)
        })
    }
    
    func updateChatPresentationInterfaceState(animated: Bool = true, interactive: Bool, _ f: (ChatPresentationInterfaceState) -> ChatPresentationInterfaceState) {
        self.updateChatPresentationInterfaceState(transition: animated ? .animated(duration: 0.4, curve: .spring) : .immediate, interactive: interactive, f)
    }
    
    func updateChatPresentationInterfaceState(transition: ContainedViewLayoutTransition, interactive: Bool, _ f: (ChatPresentationInterfaceState) -> ChatPresentationInterfaceState) {
        var temporaryChatPresentationInterfaceState = f(self.presentationInterfaceState)
        
        if self.presentationInterfaceState.keyboardButtonsMessage?.visibleButtonKeyboardMarkup != temporaryChatPresentationInterfaceState.keyboardButtonsMessage?.visibleButtonKeyboardMarkup {
            if let keyboardButtonsMessage = temporaryChatPresentationInterfaceState.keyboardButtonsMessage, let _ = keyboardButtonsMessage.visibleButtonKeyboardMarkup {
                if self.presentationInterfaceState.interfaceState.editMessage == nil && self.presentationInterfaceState.interfaceState.composeInputState.inputText.length == 0 && keyboardButtonsMessage.id != temporaryChatPresentationInterfaceState.interfaceState.messageActionsState.closedButtonKeyboardMessageId && temporaryChatPresentationInterfaceState.botStartPayload == nil {
                    temporaryChatPresentationInterfaceState = temporaryChatPresentationInterfaceState.updatedInputMode({ _ in
                        return .inputButtons
                    })
                }
                
                if case let .peer(peerId) = self.chatLocation, peerId.namespace == Namespaces.Peer.CloudChannel || peerId.namespace == Namespaces.Peer.CloudGroup {
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
        
        let contextQueryUpdates = contextQueryResultStateForChatInterfacePresentationState(updatedChatPresentationInterfaceState, account: self.account, currentQueryStates: &self.contextQueryStates)
        
        for (kind, update) in contextQueryUpdates {
            switch update {
                case .remove:
                    if let (_, disposable) = self.contextQueryStates[kind] {
                        disposable.dispose()
                        self.contextQueryStates.removeValue(forKey: kind)
                        
                        updatedChatPresentationInterfaceState = updatedChatPresentationInterfaceState.updatedInputQueryResult(queryKind: kind, { _ in
                            return nil
                        })
                    }
                case let .update(query, signal):
                    let currentQueryAndDisposable = self.contextQueryStates[kind]
                    currentQueryAndDisposable?.1.dispose()
                    
                    var inScope = true
                    var inScopeResult: ((ChatPresentationInputQueryResult?) -> ChatPresentationInputQueryResult?)?
                    self.contextQueryStates[kind] = (query, (signal |> deliverOnMainQueue).start(next: { [weak self] result in
                        if let strongSelf = self {
                            if Thread.isMainThread && inScope {
                                inScope = false
                                inScopeResult = result
                            } else {
                                strongSelf.updateChatPresentationInterfaceState(animated: true, interactive: false, {
                                    $0.updatedInputQueryResult(queryKind: kind, { previousResult in
                                        return result(previousResult)
                                    })
                                })
                            }
                        }
                    }))
                    inScope = false
                    if let inScopeResult = inScopeResult {
                        updatedChatPresentationInterfaceState = updatedChatPresentationInterfaceState.updatedInputQueryResult(queryKind: kind, { previousResult in
                            return inScopeResult(previousResult)
                        })
                    }
                
                    if case let .peer(peerId) = self.chatLocation, peerId.namespace == Namespaces.Peer.SecretChat {
                        if case .contextRequest = query {
                            let _ = (ApplicationSpecificNotice.getSecretChatInlineBotUsage(postbox: self.account.postbox)
                            |> deliverOnMainQueue).start(next: { [weak self] value in
                                if let strongSelf = self, !value {
                                    let _ = ApplicationSpecificNotice.setSecretChatInlineBotUsage(postbox: strongSelf.account.postbox).start()
                                    strongSelf.present(standardTextAlertController(theme: AlertControllerTheme(presentationTheme: strongSelf.presentationData.theme), title: nil, text: strongSelf.presentationData.strings.Conversation_SecretChatContextBotAlert, actions: [TextAlertAction(type: .defaultAction, title: strongSelf.presentationData.strings.Common_OK, action: {})]), in: .window(.root))
                                }
                            })
                        }
                    }
            }
        }
        
        if let (updatedSearchQuerySuggestionState, updatedSearchQuerySuggestionSignal) = searchQuerySuggestionResultStateForChatInterfacePresentationState(updatedChatPresentationInterfaceState, account: self.account, currentQuery: self.searchQuerySuggestionState?.0) {
            self.searchQuerySuggestionState?.1.dispose()
            var inScope = true
            var inScopeResult: ((ChatPresentationInputQueryResult?) -> ChatPresentationInputQueryResult?)?
            self.searchQuerySuggestionState = (updatedSearchQuerySuggestionState, (updatedSearchQuerySuggestionSignal |> deliverOnMainQueue).start(next: { [weak self] result in
                if let strongSelf = self {
                    if Thread.isMainThread && inScope {
                        inScope = false
                        inScopeResult = result
                    } else {
                        strongSelf.updateChatPresentationInterfaceState(animated: true, interactive: false, {
                            $0.updatedSearchQuerySuggestionResult { previousResult in
                                return result(previousResult)
                            }
                        })
                    }
                }
            }))
            inScope = false
            if let inScopeResult = inScopeResult {
                updatedChatPresentationInterfaceState = updatedChatPresentationInterfaceState.updatedSearchQuerySuggestionResult { previousResult in
                    return inScopeResult(previousResult)
                }
            }
        }
        
        if let (updatedUrlPreviewUrl, updatedUrlPreviewSignal) = urlPreviewStateForInputText(updatedChatPresentationInterfaceState.interfaceState.composeInputState.inputText.string, account: self.account, currentQuery: self.urlPreviewQueryState?.0) {
            self.urlPreviewQueryState?.1.dispose()
            var inScope = true
            var inScopeResult: ((TelegramMediaWebpage?) -> TelegramMediaWebpage?)?
            let linkPreviews: Signal<Bool, NoError>
            if case let .peer(peerId) = self.chatLocation, peerId.namespace == Namespaces.Peer.SecretChat {
                linkPreviews = interactiveChatLinkPreviewsEnabled(postbox: self.account.postbox, displayAlert: { [weak self] f in
                    if let strongSelf = self {
                        strongSelf.present(standardTextAlertController(theme: AlertControllerTheme(presentationTheme: strongSelf.presentationData.theme), title: nil, text: strongSelf.presentationData.strings.Conversation_SecretLinkPreviewAlert, actions: [
                            TextAlertAction(type: .defaultAction, title: strongSelf.presentationData.strings.Common_Yes, action: {
                            f.f(true)
                        }), TextAlertAction(type: .genericAction, title: strongSelf.presentationData.strings.Common_No, action: {
                            f.f(false)
                        })]), in: .window(.root))
                    }
                })
            } else {
                if let bannedRights = (self.presentationInterfaceState.renderedPeer?.peer as? TelegramChannel)?.bannedRights, bannedRights.flags.contains(.banEmbedLinks) {
                    linkPreviews = .single(false)
                } else {
                    linkPreviews = .single(true)
                }
            }
            self.urlPreviewQueryState = (updatedUrlPreviewUrl, (combineLatest(updatedUrlPreviewSignal, linkPreviews) |> deliverOnMainQueue).start(next: { [weak self] (result, enabled) in
                var result = result
                if !enabled {
                    result = { _ in return nil }
                }
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
        
        let isEditingMedia: Bool = updatedChatPresentationInterfaceState.editMessageState?.content != .plaintext
        let editingUrlPreviewText: String? = isEditingMedia ? nil : updatedChatPresentationInterfaceState.interfaceState.editMessage?.inputState.inputText.string
        if let (updatedEditingUrlPreviewUrl, updatedEditingUrlPreviewSignal) = urlPreviewStateForInputText(editingUrlPreviewText, account: self.account, currentQuery: self.editingUrlPreviewQueryState?.0) {
            self.editingUrlPreviewQueryState?.1.dispose()
            var inScope = true
            var inScopeResult: ((TelegramMediaWebpage?) -> TelegramMediaWebpage?)?
            self.editingUrlPreviewQueryState = (updatedEditingUrlPreviewUrl, (updatedEditingUrlPreviewSignal |> deliverOnMainQueue).start(next: { [weak self] result in
                if let strongSelf = self {
                    if Thread.isMainThread && inScope {
                        inScope = false
                        inScopeResult = result
                    } else {
                        strongSelf.updateChatPresentationInterfaceState(animated: true, interactive: false, {
                            if let updatedEditingUrlPreviewUrl = updatedEditingUrlPreviewUrl, let webpage = result($0.editingUrlPreview?.1) {
                                return $0.updatedEditingUrlPreview((updatedEditingUrlPreviewUrl, webpage))
                            } else {
                                return $0.updatedEditingUrlPreview(nil)
                            }
                        })
                    }
                }
            }))
            inScope = false
            if let inScopeResult = inScopeResult {
                if let updatedEditingUrlPreviewUrl = updatedEditingUrlPreviewUrl, let webpage = inScopeResult(updatedChatPresentationInterfaceState.editingUrlPreview?.1) {
                    updatedChatPresentationInterfaceState = updatedChatPresentationInterfaceState.updatedEditingUrlPreview((updatedEditingUrlPreviewUrl, webpage))
                } else {
                    updatedChatPresentationInterfaceState = updatedChatPresentationInterfaceState.updatedEditingUrlPreview(nil)
                }
            }
        }
        
        if let updated = self.updateSearch(updatedChatPresentationInterfaceState) {
            updatedChatPresentationInterfaceState = updated
        }
        
        let recordingActivityValue: ChatRecordingActivity
        if let mediaRecordingState = updatedChatPresentationInterfaceState.inputTextPanelState.mediaRecordingState {
            switch mediaRecordingState {
                case .audio:
                    recordingActivityValue = .voice
                case .video(ChatVideoRecordingStatus.recording, _):
                    recordingActivityValue = .instantVideo
                default:
                    recordingActivityValue = .none
            }
        } else {
            recordingActivityValue = .none
        }
        if recordingActivityValue != self.recordingActivityValue {
            self.recordingActivityValue = recordingActivityValue
            self.recordingActivityPromise.set(recordingActivityValue)
        }
        
        self.presentationInterfaceState = updatedChatPresentationInterfaceState
        if self.isNodeLoaded {
            self.chatDisplayNode.updateChatPresentationInterfaceState(updatedChatPresentationInterfaceState, transition: transition, interactive: interactive)
        }
        
        if let button = leftNavigationButtonForChatInterfaceState(updatedChatPresentationInterfaceState, strings: updatedChatPresentationInterfaceState.strings, currentButton: self.leftNavigationButton, target: self, selector: #selector(self.leftNavigationButtonAction))  {
            if self.leftNavigationButton != button {
                self.navigationItem.setLeftBarButton(button.buttonItem, animated: transition.isAnimated)
                self.leftNavigationButton = button
            }
        } else if let _ = self.leftNavigationButton {
            self.navigationItem.setLeftBarButton(nil, animated: transition.isAnimated)
            self.leftNavigationButton = nil
        }
        
        if let button = rightNavigationButtonForChatInterfaceState(updatedChatPresentationInterfaceState, strings: updatedChatPresentationInterfaceState.strings, currentButton: self.rightNavigationButton, target: self, selector: #selector(self.rightNavigationButtonAction), chatInfoNavigationButton: self.chatInfoNavigationButton) {
            if self.rightNavigationButton != button {
                self.navigationItem.setRightBarButton(button.buttonItem, animated: transition.isAnimated)
                self.rightNavigationButton = button
            }
        } else if let _ = self.rightNavigationButton {
            self.navigationItem.setRightBarButton(nil, animated: transition.isAnimated)
            self.rightNavigationButton = nil
        }
        
        if let controllerInteraction = self.controllerInteraction {
            if updatedChatPresentationInterfaceState.interfaceState.selectionState != controllerInteraction.selectionState {
                controllerInteraction.selectionState = updatedChatPresentationInterfaceState.interfaceState.selectionState
                self.updateItemNodesSelectionStates(animated: transition.isAnimated)
            }
        }
        
        switch updatedChatPresentationInterfaceState.mode {
            case .standard:
                self.statusBar.statusBarStyle = self.presentationData.theme.rootController.statusBar.style.style
                    self.deferScreenEdgeGestures = []
            case .overlay:
                self.statusBar.statusBarStyle = .Hide
                self.deferScreenEdgeGestures = [.top]
            case .inline:
                self.statusBar.statusBarStyle = .Ignore
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
                if case let .peer(peerId) = self.chatLocation {
                    let actionSheet = ActionSheetController(presentationTheme: self.presentationData.theme)
                    actionSheet.setItemGroups([ActionSheetItemGroup(items: [
                        ActionSheetButtonItem(title: self.presentationData.strings.Conversation_ClearAll, color: .destructive, action: { [weak self, weak actionSheet] in
                            actionSheet?.dismissAnimated()
                            if let strongSelf = self {
                                strongSelf.updateChatPresentationInterfaceState(animated: true, interactive: true, { $0.updatedInterfaceState { $0.withoutSelectionState() } })
                                let _ = clearHistoryInteractively(postbox: strongSelf.account.postbox, peerId: peerId).start()
                            }
                        })
                    ]), ActionSheetItemGroup(items: [
                        ActionSheetButtonItem(title: self.presentationData.strings.Common_Cancel, color: .accent, action: { [weak actionSheet] in
                            actionSheet?.dismissAnimated()
                        })
                    ])])
                    self.chatDisplayNode.dismissInput()
                    self.present(actionSheet, in: .window(.root))
                }
            case .openChatInfo:
                switch self.chatLocationInfoData {
                    case let .peer(peerView):
                        self.navigationActionDisposable.set((peerView.get()
                            |> take(1)
                            |> deliverOnMainQueue).start(next: { [weak self] peerView in
                                if let strongSelf = self, let peer = peerView.peers[peerView.peerId], peer.restrictionText == nil {
                                    if let infoController = peerInfoController(account: strongSelf.account, peer: peer) {
                                        (strongSelf.navigationController as? NavigationController)?.pushViewController(infoController)
                                    }
                                }
                        }))
                    case .group:
                        if case let .group(groupId) = self.chatLocation {
                            (self.navigationController as? NavigationController)?.pushViewController(ChatListController(account: self.account, groupId: groupId, controlsHistoryPreload: false))
                        }
                }
            case .search:
                self.interfaceInteraction?.beginMessageSearch(.everything, "")
        }
    }
    
    private func editMessageMediaWithMessages(_ messages: [EnqueueMessage]) {
        if let message = messages.first, case let .message(desc) = message, let mediaReference = desc.mediaReference {
            self.updateChatPresentationInterfaceState(animated: true, interactive: true, { state in
                var state = state
                if let editMessageState = state.editMessageState, case let .media(options) = editMessageState.content, !options.isEmpty {
                    state = state.updatedEditMessageState(ChatEditInterfaceMessageState(content: editMessageState.content, mediaReference: mediaReference))
                }
                if !desc.text.isEmpty {
                    state = state.updatedInterfaceState { state in
                        if let editMessage = state.editMessage {
                            return state.withUpdatedEditMessage(ChatEditMessageState(messageId: editMessage.messageId, inputState: ChatTextInputState(inputText: NSAttributedString(string: desc.text)), disableUrlPreview: editMessage.disableUrlPreview))
                        }
                        return state
                    }
                }
                return state
            })
        }
    }
    
    private func editMessageMediaWithLegacySignals(_ signals: [Any]) {
        guard case .peer = self.chatLocation else {
            return
        }
        
        let _ = (legacyAssetPickerEnqueueMessages(account: self.account, signals: signals)
        |> deliverOnMainQueue).start(next: { [weak self] messages in
            self?.editMessageMediaWithMessages(messages)
        })
    }
    
    private func presentAttachmentMenu(editMediaOptions: MessageMediaEditingOptions?) {
        let _ = (self.account.postbox.transaction { transaction -> GeneratedMediaStoreSettings in
            let entry = transaction.getPreferencesEntry(key: ApplicationSpecificPreferencesKeys.generatedMediaStoreSettings) as? GeneratedMediaStoreSettings
            return entry ?? GeneratedMediaStoreSettings.defaultSettings
        }
        |> deliverOnMainQueue).start(next: { [weak self] settings in
            guard let strongSelf = self, let peer = strongSelf.presentationInterfaceState.renderedPeer?.peer else {
                return
            }
            strongSelf.chatDisplayNode.dismissInput()
        
            if editMediaOptions == nil, let bannedRights = (peer as? TelegramChannel)?.bannedRights, bannedRights.flags.contains(.banSendMedia) {
                let banDescription: String
                if bannedRights.untilDate != 0 && bannedRights.untilDate != Int32.max {
                    banDescription = strongSelf.presentationInterfaceState.strings.Conversation_RestrictedMediaTimed(stringForFullDate(timestamp: bannedRights.untilDate, strings: strongSelf.presentationInterfaceState.strings, timeFormat: .regular)).0
                } else {
                    banDescription = strongSelf.presentationInterfaceState.strings.Conversation_RestrictedMedia
                }
                
                let actionSheet = ActionSheetController(presentationTheme: strongSelf.presentationData.theme)
                actionSheet.setItemGroups([ActionSheetItemGroup(items: [
                    ActionSheetTextItem(title: banDescription),
                    ActionSheetButtonItem(title: strongSelf.presentationData.strings.Conversation_Location, color: .accent, action: { [weak actionSheet] in
                        actionSheet?.dismissAnimated()
                        self?.presentMapPicker(editingMessage: false)
                    }),
                    ActionSheetButtonItem(title: strongSelf.presentationData.strings.Conversation_Contact, color: .accent, action: { [weak actionSheet] in
                        actionSheet?.dismissAnimated()
                        self?.presentContactPicker()
                    })
                ]), ActionSheetItemGroup(items: [
                    ActionSheetButtonItem(title: strongSelf.presentationData.strings.Common_Cancel, color: .accent, action: { [weak actionSheet] in
                        actionSheet?.dismissAnimated()
                    })
                ])])
                strongSelf.present(actionSheet, in: .window(.root))
                
                return
            }
        
            let legacyController = LegacyController(presentation: .custom, theme: strongSelf.presentationData.theme, initialLayout: strongSelf.validLayout)
            legacyController.statusBar.statusBarStyle = .Ignore
            legacyController.controllerLoaded = { [weak legacyController] in
                legacyController?.view.disablesInteractiveTransitionGestureRecognizer = true
            }
        
            let emptyController = LegacyEmptyController(context: legacyController.context)!
            let navigationController = makeLegacyNavigationController(rootController: emptyController)
            navigationController.setNavigationBarHidden(true, animated: false)
            legacyController.bind(controller: navigationController)
        
            legacyController.enableSizeClassSignal = true
            let controller = legacyAttachmentMenu(account: strongSelf.account, peer: peer, editMediaOptions: editMediaOptions, saveEditedPhotos: settings.storeEditedPhotos, allowGrouping: true, theme: strongSelf.presentationData.theme, strings: strongSelf.presentationData.strings, parentController: legacyController, recentlyUsedInlineBots: strongSelf.recentlyUsedInlineBotsValue, openGallery: {
                self?.presentMediaPicker(fileMode: false, editingMedia: editMediaOptions != nil, completion: { signals in
                    if editMediaOptions != nil {
                        self?.editMessageMediaWithLegacySignals(signals)
                    } else {
                        self?.enqueueMediaMessages(signals: signals)
                    }
                })
            }, openCamera: { cameraView, menuController in
                if let strongSelf = self, let peer = strongSelf.presentationInterfaceState.renderedPeer?.peer {
                    presentedLegacyCamera(account: strongSelf.account, peer: peer, cameraView: cameraView, menuController: menuController, parentController: strongSelf, editingMedia: editMediaOptions != nil, saveCapturedPhotos: settings.storeEditedPhotos, mediaGrouping: true, sendMessagesWithSignals: { signals in
                        if editMediaOptions != nil {
                            self?.editMessageMediaWithLegacySignals(signals!)
                        } else {
                            self?.enqueueMediaMessages(signals: signals)
                        }
                    })
                }
            }, openFileGallery: {
                self?.presentFileMediaPickerOptions(editingMessage: editMediaOptions != nil)
            }, openMap: {
                self?.presentMapPicker(editingMessage: editMediaOptions != nil)
            }, openContacts: {
                self?.presentContactPicker()
            }, sendMessagesWithSignals: { [weak self] signals in
                if editMediaOptions != nil {
                    self?.editMessageMediaWithLegacySignals(signals!)
                } else {
                    self?.enqueueMediaMessages(signals: signals)
                }
            }, selectRecentlyUsedInlineBot: { [weak self] peer in
                if let strongSelf = self, let addressName = peer.addressName {
                    strongSelf.updateChatPresentationInterfaceState(animated: true, interactive: false, {
                        $0.updatedInterfaceState({ $0.withUpdatedComposeInputState(ChatTextInputState(inputText: NSAttributedString(string: "@" + addressName + " "))) }).updatedInputMode({ _ in
                            return .text
                        })
                    })
                }
            })
            controller.didDismiss = { [weak legacyController] _ in
                legacyController?.dismiss()
            }
            controller.customRemoveFromParentViewController = { [weak legacyController] in
                legacyController?.dismiss()
            }
        
            strongSelf.present(legacyController, in: .window(.root))
            controller.present(in: emptyController, sourceView: nil, animated: true)
        })
    }
    
    private func presentFileMediaPickerOptions(editingMessage: Bool) {
        let actionSheet = ActionSheetController(presentationTheme: self.presentationData.theme)
        actionSheet.setItemGroups([ActionSheetItemGroup(items: [
            ActionSheetButtonItem(title: self.presentationData.strings.Conversation_FilePhotoOrVideo, action: { [weak self, weak actionSheet] in
                actionSheet?.dismissAnimated()
                if let strongSelf = self {
                    strongSelf.presentMediaPicker(fileMode: true, editingMedia: editingMessage, completion: { signals in
                        if editingMessage {
                            self?.editMessageMediaWithLegacySignals(signals)
                        } else {
                            self?.enqueueMediaMessages(signals: signals)
                        }
                    })
                }
            }),
            ActionSheetButtonItem(title: self.presentationData.strings.Conversation_FileICloudDrive, action: { [weak self, weak actionSheet] in
                actionSheet?.dismissAnimated()
                if let strongSelf = self {
                    strongSelf.present(legacyICloudFileController(theme: strongSelf.presentationData.theme, completion: { urls in
                        if let strongSelf = self, !urls.isEmpty {
                            var signals: [Signal<ICloudFileDescription?, NoError>] = []
                            for url in urls {
                                signals.append(iCloudFileDescription(url))
                            }
                            strongSelf.enqueueMediaMessageDisposable.set((combineLatest(signals)
                            |> deliverOnMainQueue).start(next: { results in
                                if let strongSelf = self {
                                    let replyMessageId = strongSelf.presentationInterfaceState.interfaceState.replyMessageId
                                    
                                    var messages: [EnqueueMessage] = []
                                    for item in results {
                                        if let item = item {
                                            let fileId = arc4random64()
                                            let file = TelegramMediaFile(fileId: MediaId(namespace: Namespaces.Media.LocalFile, id: fileId), partialReference: nil, resource: ICloudFileResource(urlData: item.urlData), previewRepresentations: [], mimeType: guessMimeTypeByFileExtension((item.fileName as NSString).pathExtension), size: item.fileSize, attributes: [.FileName(fileName: item.fileName)])
                                            let message: EnqueueMessage = .message(text: "", attributes: [], mediaReference: .standalone(media: file), replyToMessageId: replyMessageId, localGroupingKey: nil)
                                            messages.append(message)
                                        }
                                    }
                                    
                                    if !messages.isEmpty {
                                        if editingMessage {
                                            strongSelf.editMessageMediaWithMessages(messages)
                                            
                                        } else {
                                        strongSelf.chatDisplayNode.setupSendActionOnViewUpdate({
                                                if let strongSelf = self {
                                                    strongSelf.updateChatPresentationInterfaceState(animated: true, interactive: false, {
                                                        $0.updatedInterfaceState { $0.withUpdatedReplyMessageId(nil) }
                                                    })
                                                }
                                            })
                                            strongSelf.sendMessages(messages)
                                        }
                                    }
                                }
                            }))
                        }
                    }), in: .window(.root))
                }
            })
        ]), ActionSheetItemGroup(items: [
            ActionSheetButtonItem(title: self.presentationData.strings.Common_Cancel, color: .accent, action: { [weak actionSheet] in
                actionSheet?.dismissAnimated()
            })
        ])])
        self.chatDisplayNode.dismissInput()
        self.present(actionSheet, in: .window(.root))
    }
    
    private func presentMediaPicker(fileMode: Bool, editingMedia: Bool, completion: @escaping ([Any]) -> Void) {
        let _ = (self.account.postbox.transaction { transaction -> GeneratedMediaStoreSettings in
            let entry = transaction.getPreferencesEntry(key: ApplicationSpecificPreferencesKeys.generatedMediaStoreSettings) as? GeneratedMediaStoreSettings
            return entry ?? GeneratedMediaStoreSettings.defaultSettings
        }
        |> deliverOnMainQueue).start(next: { [weak self] settings in
            guard let strongSelf = self, let peer = strongSelf.presentationInterfaceState.renderedPeer?.peer else {
                return
            }
            let _ = legacyAssetPicker(applicationContext: strongSelf.account.telegramApplicationContext, presentationData: strongSelf.presentationData, editingMedia: editingMedia, fileMode: fileMode, peer: peer, saveEditedPhotos: settings.storeEditedPhotos, allowGrouping: true).start(next: { generator in
                if let strongSelf = self {
                    let legacyController = LegacyController(presentation: .modal(animateIn: true), theme: strongSelf.presentationData.theme, initialLayout: strongSelf.validLayout)
                    legacyController.statusBar.statusBarStyle = strongSelf.presentationData.theme.rootController.statusBar.style.style
                    legacyController.controllerLoaded = { [weak legacyController] in
                        legacyController?.view.disablesInteractiveTransitionGestureRecognizer = true
                    }
                    let controller = generator(legacyController.context)
                    legacyController.bind(controller: controller)
                    legacyController.deferScreenEdgeGestures = [.top]
                    
                    configureLegacyAssetPicker(controller, account: strongSelf.account, peer: peer)
                    controller.descriptionGenerator = legacyAssetPickerItemGenerator()
                    controller.completionBlock = { [weak legacyController] signals in
                        if let legacyController = legacyController {
                            legacyController.dismiss()
                            completion(signals!)
                        }
                    }
                    controller.dismissalBlock = { [weak legacyController] in
                        if let legacyController = legacyController {
                            legacyController.dismiss()
                        }
                    }
                    strongSelf.chatDisplayNode.dismissInput()
                    strongSelf.present(legacyController, in: .window(.root))
                }
            })
        })
    }
    
    private func presentMapPicker(editingMessage: Bool) {
        guard let peer = self.presentationInterfaceState.renderedPeer?.peer else {
            return
        }
        let selfPeerId: PeerId
        if let peer = peer as? TelegramChannel, case .broadcast = peer.info {
            selfPeerId = peer.id
        } else {
            selfPeerId = self.account.peerId
        }
        let _ = (self.account.postbox.transaction { transaction -> Peer? in
            return transaction.getPeer(selfPeerId)
        }
        |> deliverOnMainQueue).start(next: { [weak self] selfPeer in
            guard let strongSelf = self, let selfPeer = selfPeer else {
                return
            }
            
            strongSelf.chatDisplayNode.dismissInput()
            strongSelf.present(legacyLocationPickerController(account: strongSelf.account, selfPeer: selfPeer, peer: peer, sendLocation: { coordinate, venue in
                guard let strongSelf = self else {
                    return
                }
                let replyMessageId = strongSelf.presentationInterfaceState.interfaceState.replyMessageId
                let message: EnqueueMessage = .message(text: "", attributes: [], mediaReference: .standalone(media: TelegramMediaMap(latitude: coordinate.latitude, longitude: coordinate.longitude, geoPlace: nil, venue: venue, liveBroadcastingTimeout: nil)), replyToMessageId: replyMessageId, localGroupingKey: nil)
                
                if editingMessage {
                    strongSelf.editMessageMediaWithMessages([message])
                } else {
                    strongSelf.chatDisplayNode.setupSendActionOnViewUpdate({
                        if let strongSelf = self {
                            strongSelf.updateChatPresentationInterfaceState(animated: true, interactive: false, {
                                $0.updatedInterfaceState { $0.withUpdatedReplyMessageId(nil) }
                            })
                        }
                    })
                    strongSelf.sendMessages([message])
                }
            }, sendLiveLocation: { [weak self] coordinate, period in
                guard let strongSelf = self else {
                    return
                }
                let replyMessageId = strongSelf.presentationInterfaceState.interfaceState.replyMessageId
                let message: EnqueueMessage = .message(text: "", attributes: [], mediaReference: .standalone(media: TelegramMediaMap(latitude: coordinate.latitude, longitude: coordinate.longitude, geoPlace: nil, venue: nil, liveBroadcastingTimeout: period)), replyToMessageId: replyMessageId, localGroupingKey: nil)
                if editingMessage {
                    strongSelf.editMessageMediaWithMessages([message])
                } else {
                    strongSelf.chatDisplayNode.setupSendActionOnViewUpdate({
                        if let strongSelf = self {
                            strongSelf.updateChatPresentationInterfaceState(animated: true, interactive: false, {
                                $0.updatedInterfaceState { $0.withUpdatedReplyMessageId(nil) }
                            })
                        }
                    })
                    strongSelf.sendMessages([message])
                }
            }, theme: strongSelf.presentationData.theme), in: .window(.root))
        })
    }
    
    private func presentContactPicker() {
        let contactsController = ContactSelectionController(account: self.account, title: { $0.Contacts_Title }, displayDeviceContacts: true)
        self.chatDisplayNode.dismissInput()
        self.present(contactsController, in: .window(.root), with: ViewControllerPresentationArguments(presentationAnimation: .modalSheet))
        self.controllerNavigationDisposable.set((contactsController.result |> deliverOnMainQueue).start(next: { [weak self] peer in
            if let strongSelf = self, let peer = peer {
                let dataSignal: Signal<(Peer?,  DeviceContactExtendedData?), NoError>
                switch peer {
                    case let .peer(contact, _):
                        guard let contact = contact as? TelegramUser, let phoneNumber = contact.phone else {
                            return
                        }
                        let contactData = DeviceContactExtendedData(basicData: DeviceContactBasicData(firstName: contact.firstName ?? "", lastName: contact.lastName ?? "", phoneNumbers: [DeviceContactPhoneNumberData(label: "_$!<Home>!$_", value: phoneNumber)]), middleName: "", prefix: "", suffix: "", organization: "", jobTitle: "", department: "", emailAddresses: [], urls: [], addresses: [], birthdayDate: nil, socialProfiles: [], instantMessagingProfiles: [])
                        let account = strongSelf.account
                        dataSignal = strongSelf.account.telegramApplicationContext.contactDataManager.basicData()
                        |> take(1)
                        |> mapToSignal { basicData -> Signal<(Peer?,  DeviceContactExtendedData?), NoError> in
                            var stableId: String?
                            let queryPhoneNumber = formatPhoneNumber(phoneNumber)
                            outer: for (id, data) in basicData {
                                for phoneNumber in data.phoneNumbers {
                                    if formatPhoneNumber(phoneNumber.value) == queryPhoneNumber {
                                        stableId = id
                                        break outer
                                    }
                                }
                            }
                            
                            if let stableId = stableId {
                                return account.telegramApplicationContext.contactDataManager.extendedData(stableId: stableId)
                                |> take(1)
                                |> map { extendedData -> (Peer?,  DeviceContactExtendedData?) in
                                    return (contact, extendedData)
                                }
                            } else {
                                return .single((contact, contactData))
                            }
                        }
                    case let .deviceContact(id, _):
                        dataSignal = strongSelf.account.telegramApplicationContext.contactDataManager.extendedData(stableId: id)
                        |> take(1)
                        |> map { extendedData -> (Peer?,  DeviceContactExtendedData?) in
                            return (nil, extendedData)
                        }
                }
                strongSelf.controllerNavigationDisposable.set((dataSignal
                |> deliverOnMainQueue).start(next: { peerAndContactData in
                    if let strongSelf = self, let contactData = peerAndContactData.1, contactData.basicData.phoneNumbers.count != 0 {
                        if contactData.isPrimitive {
                            let phone = contactData.basicData.phoneNumbers[0].value
                            let media = TelegramMediaContact(firstName: contactData.basicData.firstName, lastName: contactData.basicData.lastName, phoneNumber: phone, peerId: peerAndContactData.0?.id, vCardData: nil)
                            let replyMessageId = strongSelf.presentationInterfaceState.interfaceState.replyMessageId
                            strongSelf.chatDisplayNode.setupSendActionOnViewUpdate({
                                if let strongSelf = self {
                                    strongSelf.updateChatPresentationInterfaceState(animated: true, interactive: false, {
                                        $0.updatedInterfaceState { $0.withUpdatedReplyMessageId(nil) }
                                    })
                                }
                            })
                            let message = EnqueueMessage.message(text: "", attributes: [], mediaReference: .standalone(media: media), replyToMessageId: replyMessageId, localGroupingKey: nil)
                            strongSelf.sendMessages([message])
                        } else {
                            strongSelf.present(deviceContactInfoController(account: strongSelf.account, subject: .filter(peer: peerAndContactData.0, contactId: nil, contactData: contactData, completion: { peer, contactData in
                                guard let strongSelf = self, !contactData.basicData.phoneNumbers.isEmpty else {
                                    return
                                }
                                let phone = contactData.basicData.phoneNumbers[0].value
                                if let vCardData = contactData.serializedVCard() {
                                    let media = TelegramMediaContact(firstName: contactData.basicData.firstName, lastName: contactData.basicData.lastName, phoneNumber: phone, peerId: peer?.id, vCardData: vCardData)
                                    let replyMessageId = strongSelf.presentationInterfaceState.interfaceState.replyMessageId
                                    strongSelf.chatDisplayNode.setupSendActionOnViewUpdate({
                                        if let strongSelf = self {
                                            strongSelf.updateChatPresentationInterfaceState(animated: true, interactive: false, {
                                                $0.updatedInterfaceState { $0.withUpdatedReplyMessageId(nil) }
                                            })
                                        }
                                    })
                                    let message = EnqueueMessage.message(text: "", attributes: [], mediaReference: .standalone(media: media), replyToMessageId: replyMessageId, localGroupingKey: nil)
                                    strongSelf.sendMessages([message])
                                }
                            })), in: .window(.root), with: ViewControllerPresentationArguments(presentationAnimation: .modalSheet))
                        }
                    }
                }))
            }
        }))
    }
    
    private func transformEnqueueMessages(_ messages: [EnqueueMessage]) -> [EnqueueMessage] {
        let silentPosting = self.presentationInterfaceState.interfaceState.silentPosting
        return messages.map { message in
            if silentPosting {
                return message.withUpdatedAttributes { attributes in
                    var attributes = attributes
                    for i in 0 ..< attributes.count {
                        if attributes[i] is NotificationInfoMessageAttribute {
                            attributes.remove(at: i)
                            break
                        }
                    }
                    attributes.append(NotificationInfoMessageAttribute(flags: .muted))
                    return attributes
                }
            } else {
                return message
            }
        }
    }
    
    private func sendMessages(_ messages: [EnqueueMessage]) {
        if case let .peer(peerId) = self.chatLocation {
            self.commitPurposefulAction()
            
            let _ = (enqueueMessages(account: self.account, peerId: peerId, messages: self.transformEnqueueMessages(messages))
            |> deliverOnMainQueue).start(next: { [weak self] _ in
                self?.chatDisplayNode.historyNode.scrollToEndOfHistory()
            })
        }
    }
    
    private func enqueueMediaMessages(signals: [Any]?) {
        if case let .peer(peerId) = self.chatLocation {
            self.enqueueMediaMessageDisposable.set((legacyAssetPickerEnqueueMessages(account: self.account, signals: signals!) |> deliverOnMainQueue).start(next: { [weak self] messages in
                if let strongSelf = self {
                    let replyMessageId = strongSelf.presentationInterfaceState.interfaceState.replyMessageId
                    strongSelf.chatDisplayNode.setupSendActionOnViewUpdate({
                        if let strongSelf = self {
                            strongSelf.updateChatPresentationInterfaceState(animated: true, interactive: false, {
                                $0.updatedInterfaceState { $0.withUpdatedReplyMessageId(nil) }
                            })
                        }
                    })
                    strongSelf.sendMessages(messages.map { $0.withUpdatedReplyToMessageId(replyMessageId) })
                }
            }))
        }
    }
    
    private func enqueueChatContextResult(_ results: ChatContextResultCollection, _ result: ChatContextResult) {
        guard case let .peer(peerId) = self.chatLocation else {
            return
        }
        if let message = outgoingMessageWithChatContextResult(to: peerId, results: results, result: result), canSendMessagesToChat(self.presentationInterfaceState) {
            let replyMessageId = self.presentationInterfaceState.interfaceState.replyMessageId
            self.chatDisplayNode.setupSendActionOnViewUpdate({ [weak self] in
                if let strongSelf = self {
                    strongSelf.updateChatPresentationInterfaceState(animated: true, interactive: false, {
                        $0.updatedInterfaceState { $0.withUpdatedReplyMessageId(nil).withUpdatedComposeInputState(ChatTextInputState(inputText: NSAttributedString(string: ""))).withUpdatedComposeDisableUrlPreview(nil) }
                    })
                }
            })
            self.sendMessages([message.withUpdatedReplyToMessageId(replyMessageId)])
        }
    }
    
    private func firstLoadedMessageToListen() -> Message? {
        var messageToListen: Message?
        self.chatDisplayNode.historyNode.forEachMessageInCurrentHistoryView { message in
            if message.flags.contains(.Incoming) && message.tags.contains(.voiceOrInstantVideo) {
                for attribute in message.attributes {
                    if let attribute = attribute as? ConsumableContentMessageAttribute, !attribute.consumed {
                        messageToListen = message
                        return false
                    }
                }
            }
            return true
        }
        return messageToListen
    }
    
    private func activateRaiseGesture() {
        if let messageToListen = self.firstLoadedMessageToListen() {
            let _ = self.controllerInteraction?.openMessage(messageToListen)
        } else {
            self.requestAudioRecorder(beginWithTone: true)
        }
    }
    
    private func deactivateRaiseGesture() {
        self.dismissMediaRecorder(.preview)
    }
    
    private func requestAudioRecorder(beginWithTone: Bool) {
        if self.audioRecorderValue == nil {
            if let applicationContext = self.account.applicationContext as? TelegramApplicationContext {
                if self.audioRecorderFeedback == nil {
                    self.audioRecorderFeedback = HapticFeedback()
                    self.audioRecorderFeedback?.prepareTap()
                }
                self.audioRecorder.set(applicationContext.mediaManager.audioRecorder(beginWithTone: beginWithTone, applicationBindings: applicationContext.applicationBindings, beganWithTone: { _ in
                }))
            }
        }
    }
    
    private func requestVideoRecorder() {
        guard case let .peer(peerId) = self.chatLocation else {
            return
        }
        
        if self.videoRecorderValue == nil {
            if let currentInputPanelFrame = self.chatDisplayNode.currentInputPanelFrame() {
                self.videoRecorder.set(.single(legacyInstantVideoController(theme: self.presentationData.theme, panelFrame: currentInputPanelFrame, account: self.account, peerId: peerId, send: { [weak self] message in
                    if let strongSelf = self {
                        let replyMessageId = strongSelf.presentationInterfaceState.interfaceState.replyMessageId
                        strongSelf.chatDisplayNode.setupSendActionOnViewUpdate({
                            if let strongSelf = self {
                                strongSelf.updateChatPresentationInterfaceState(animated: true, interactive: false, {
                                    $0.updatedInterfaceState { $0.withUpdatedReplyMessageId(nil) }
                                })
                            }
                        })
                        let updatedMessage = message.withUpdatedReplyToMessageId(replyMessageId)
                        strongSelf.sendMessages([updatedMessage])
                    }
                })))
            }
        }
    }
    
    private func dismissMediaRecorder(_ action: ChatFinishMediaRecordingAction) {
        if let audioRecorderValue = self.audioRecorderValue {
            audioRecorderValue.stop()
            switch action {
                case .dismiss:
                    break
                case .preview:
                    let _ = (audioRecorderValue.takenRecordedData() |> deliverOnMainQueue).start(next: { [weak self] data in
                        if let strongSelf = self, let data = data {
                            if data.duration < 0.5 {
                                strongSelf.audioRecorderFeedback?.error()
                                strongSelf.audioRecorderFeedback = nil
                            } else if let waveform = data.waveform {
                                var randomId: Int64 = 0
                                arc4random_buf(&randomId, 8)
                                
                                let resource = LocalFileMediaResource(fileId: randomId, size: data.compressedData.count)
                                
                                strongSelf.account.postbox.mediaBox.storeResourceData(resource.id, data: data.compressedData)
                                
                                strongSelf.updateChatPresentationInterfaceState(animated: true, interactive: true, {
                                    $0.updatedRecordedMediaPreview(ChatRecordedMediaPreview(resource: resource, duration: Int32(data.duration), fileSize: Int32(data.compressedData.count), waveform: AudioWaveform(bitstream: waveform, bitsPerSample: 5)))
                                })
                                strongSelf.audioRecorderFeedback = nil
                            }
                        }
                    })
                case .send:
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
                                
                                strongSelf.chatDisplayNode.setupSendActionOnViewUpdate({
                                    if let strongSelf = self {
                                        strongSelf.updateChatPresentationInterfaceState(animated: true, interactive: false, {
                                            $0.updatedInterfaceState { $0.withUpdatedReplyMessageId(nil) }
                                        })
                                    }
                                })
                                
                                strongSelf.sendMessages([.message(text: "", attributes: [], mediaReference: .standalone(media: TelegramMediaFile(fileId: MediaId(namespace: Namespaces.Media.LocalFile, id: randomId), partialReference: nil, resource: resource, previewRepresentations: [], mimeType: "audio/ogg", size: data.compressedData.count, attributes: [.Audio(isVoice: true, duration: Int(data.duration), title: nil, performer: nil, waveform: waveformBuffer)])), replyToMessageId: strongSelf.presentationInterfaceState.interfaceState.replyMessageId, localGroupingKey: nil)])
                                
                                strongSelf.audioRecorderFeedback?.tap()
                                strongSelf.audioRecorderFeedback = nil
                            }
                        }
                    })
            }
            self.audioRecorder.set(.single(nil))
        } else if let videoRecorderValue = self.videoRecorderValue {
            if case .send = action {
                videoRecorderValue.completeVideo()
                //self.tempVideoRecorderValue = videoRecorderValue
                self.videoRecorder.set(.single(nil))
            } else {
                self.videoRecorder.set(.single(nil))
            }
        }
    }
    
    private func stopMediaRecorder() {
        if let audioRecorderValue = self.audioRecorderValue {
            if let _ = self.presentationInterfaceState.inputTextPanelState.mediaRecordingState {
                self.dismissMediaRecorder(.preview)
            } else {
                audioRecorderValue.stop()
                self.audioRecorder.set(.single(nil))
            }
        } else if let videoRecorderValue = self.videoRecorderValue {
            if videoRecorderValue.stopVideo() {
                self.updateChatPresentationInterfaceState(animated: true, interactive: true, {
                    $0.updatedInputTextPanelState { panelState in
                        return panelState.withUpdatedMediaRecordingState(.video(status: .editing, isLocked: false))
                    }
                })
            } else {
                self.videoRecorder.set(.single(nil))
            }
        }
    }
    
    private func lockMediaRecorder() {
        if self.presentationInterfaceState.inputTextPanelState.mediaRecordingState != nil {
            self.updateChatPresentationInterfaceState(animated: true, interactive: true, {
                return $0.updatedInputTextPanelState { panelState in
                    return panelState.withUpdatedMediaRecordingState(panelState.mediaRecordingState?.withLocked(true))
                }
            })
        }
        
        self.videoRecorderValue?.lockVideo()
    }
    
    private func deleteMediaRecording() {
        self.updateChatPresentationInterfaceState(animated: true, interactive: true, {
            $0.updatedRecordedMediaPreview(nil)
        })
    }
    
    private func sendMediaRecording() {
        if let recordedMediaPreview = self.presentationInterfaceState.recordedMediaPreview {
            let waveformBuffer = MemoryBuffer(data: recordedMediaPreview.waveform.samples)
            
            self.chatDisplayNode.setupSendActionOnViewUpdate({ [weak self] in
                if let strongSelf = self {
                    strongSelf.updateChatPresentationInterfaceState(animated: true, interactive: false, {
                        $0.updatedRecordedMediaPreview(nil).updatedInterfaceState { $0.withUpdatedReplyMessageId(nil) }
                    })
                }
            })
            
            var randomId: Int64 = 0
            arc4random_buf(&randomId, 8)
            
            self.sendMessages([.message(text: "", attributes: [], mediaReference: .standalone(media: TelegramMediaFile(fileId: MediaId(namespace: Namespaces.Media.LocalFile, id: randomId), partialReference: nil, resource: recordedMediaPreview.resource, previewRepresentations: [], mimeType: "audio/ogg", size: Int(recordedMediaPreview.fileSize), attributes: [.Audio(isVoice: true, duration: Int(recordedMediaPreview.duration), title: nil, performer: nil, waveform: waveformBuffer)])), replyToMessageId: self.presentationInterfaceState.interfaceState.replyMessageId, localGroupingKey: nil)])
        }
    }
    
    private func updateSearch(_ interfaceState: ChatPresentationInterfaceState) -> ChatPresentationInterfaceState? {
        var queryAndLocation: (String, SearchMessagesLocation)?
        if let search = interfaceState.search {
            switch search.domain {
                case .everything:
                    switch self.chatLocation {
                        case let .peer(peerId):
                            queryAndLocation = (search.query, .peer(peerId: peerId, fromId: nil, tags: nil))
                        case let .group(groupId):
                            queryAndLocation = (search.query, .group(groupId))
                    }
                case .members:
                    queryAndLocation = nil
                case let .member(peer):
                    switch self.chatLocation {
                        case let .peer(peerId):
                            queryAndLocation = (search.query, .peer(peerId: peerId, fromId: peer.id, tags: nil))
                        case .group:
                            queryAndLocation = nil
                    }
            }
        }
        
        if queryAndLocation?.0 != self.searchState?.0 || queryAndLocation?.1 != self.searchState?.1 {
            self.searchState = queryAndLocation
            if let (query, location) = queryAndLocation {
                var queryIsEmpty = false
                if query.isEmpty {
                    if case let .peer(_, fromId, _) = location {
                        if fromId == nil {
                            queryIsEmpty = true
                        }
                    } else {
                        queryIsEmpty = true
                    }
                }
                
                if queryIsEmpty {
                    self.searching.set(false)
                    self.searchDisposable?.set(nil)
                    if let data = interfaceState.search {
                        return interfaceState.updatedSearch(data.withUpdatedResultsState(nil))
                    }
                } else {
                    self.searching.set(true)
                    let searchDisposable: MetaDisposable
                    if let current = self.searchDisposable {
                        searchDisposable = current
                    } else {
                        searchDisposable = MetaDisposable()
                        self.searchDisposable = searchDisposable
                    }
                    searchDisposable.set((searchMessages(account: self.account, location: location, query: query) |> map {$0.0}
                    |> delay(0.2, queue: Queue.mainQueue())
                    |> deliverOnMainQueue).start(next: { [weak self] results in
                        if let strongSelf = self {
                            var navigateIndex: MessageIndex?
                            strongSelf.updateChatPresentationInterfaceState(animated: true, interactive: true, { current in
                                if let data = current.search {
                                    let messageIndices = results.map({ MessageIndex($0) }).sorted()
                                    var currentIndex = messageIndices.last
                                    if let previousResultId = data.resultsState?.currentId {
                                        for index in messageIndices {
                                            if index.id >= previousResultId {
                                                currentIndex = index
                                                break
                                            }
                                        }
                                    }
                                    navigateIndex = currentIndex
                                    return current.updatedSearch(data.withUpdatedResultsState(ChatSearchResultsState(messageIndices: messageIndices, currentId: currentIndex?.id)))
                                } else {
                                    return current
                                }
                            })
                            if let navigateIndex = navigateIndex {
                                switch strongSelf.chatLocation {
                                    case .peer:
                                        strongSelf.navigateToMessage(from: nil, to: .id(navigateIndex.id))
                                    case .group:
                                        strongSelf.navigateToMessage(from: nil, to: .index(navigateIndex))
                                }
                            }
                        }
                    }, completed: { [weak self] in
                        if let strongSelf = self {
                            strongSelf.searching.set(false)
                        }
                    }))
                }
            } else {
                self.searching.set(false)
                self.searchDisposable?.set(nil)
                
                if let data = interfaceState.search {
                    return interfaceState.updatedSearch(data.withUpdatedResultsState(nil))
                }
            }
        }
        return nil
    }
    
    public func navigateToMessage(messageLocation: NavigateToMessageLocation, animated: Bool, completion: (() -> Void)? = nil) {
        self.navigateToMessage(from: nil, to: messageLocation, rememberInStack: false, animated: animated, completion: completion)
    }
    
    private func navigateToMessage(from fromId: MessageId?, to messageLocation: NavigateToMessageLocation, scrollPosition: ListViewScrollPosition = .center(.bottom), rememberInStack: Bool = true, animated: Bool = true, completion: (() -> Void)? = nil) {
        if self.isNodeLoaded {
            var fromIndex: MessageIndex?
            
            if let fromId = fromId, let message = self.chatDisplayNode.historyNode.messageInCurrentHistoryView(fromId) {
                fromIndex = MessageIndex(message)
            } else {
                if let message = self.chatDisplayNode.historyNode.anchorMessageInCurrentHistoryView() {
                    fromIndex = MessageIndex(message)
                }
            }
            
            if case let .peer(peerId) = self.chatLocation, messageLocation.messageId.peerId == peerId {
                if let fromIndex = fromIndex {
                    if let _ = fromId, rememberInStack {
                        self.historyNavigationStack.add(fromIndex)
                    }
                    
                    if let message = self.chatDisplayNode.historyNode.messageInCurrentHistoryView(messageLocation.messageId) {
                        self.loadingMessage.set(false)
                        self.messageIndexDisposable.set(nil)
                        self.chatDisplayNode.historyNode.scrollToMessage(from: fromIndex, to: MessageIndex(message), animated: animated, scrollPosition: scrollPosition)
                        completion?()
                    } else {
                        self.loadingMessage.set(true)
                        let searchLocation: ChatHistoryInitialSearchLocation
                        switch messageLocation {
                            case let .id(id):
                                searchLocation = .id(id)
                            case let .index(index):
                                searchLocation = .index(index)
                        }
                        let historyView = chatHistoryViewForLocation(.InitialSearch(location: searchLocation, count: 50), account: self.account, chatLocation: self.chatLocation, fixedCombinedReadStates: nil, tagMask: nil, additionalData: [])
                        let signal = historyView
                        |> mapToSignal { historyView -> Signal<MessageIndex?, NoError> in
                            switch historyView {
                                case .Loading:
                                    return .complete()
                                case let .HistoryView(view, _, _, _, _):
                                    for entry in view.entries {
                                        if case let .MessageEntry(message, _, _, _) = entry {
                                            if message.id == messageLocation.messageId {
                                                return .single(MessageIndex(message))
                                            }
                                        }
                                    }
                                    if case let .index(index) = searchLocation {
                                        return .single(index)
                                    }
                                    return .single(nil)
                            }
                        }
                        |> take(1)
                        self.messageIndexDisposable.set((signal
                        |> deliverOnMainQueue).start(next: { [weak self] index in
                            if let strongSelf = self, let index = index {
                                strongSelf.chatDisplayNode.historyNode.scrollToMessage(from: fromIndex, to: index, animated: animated, scrollPosition: scrollPosition)
                                completion?()
                            }
                        }, completed: { [weak self] in
                            if let strongSelf = self {
                                strongSelf.loadingMessage.set(false)
                            }
                        }))
                    }
                } else {
                    completion?()
                }
            } else {
                if let fromIndex = fromIndex {
                    if let _ = fromId, rememberInStack {
                        self.historyNavigationStack.add(fromIndex)
                    }
                    
                    self.loadingMessage.set(true)
                    let searchLocation: ChatHistoryInitialSearchLocation
                    switch messageLocation {
                        case let .id(id):
                            searchLocation = .id(id)
                        case let .index(index):
                            searchLocation = .index(index)
                    }
                    let historyView = chatHistoryViewForLocation(.InitialSearch(location: searchLocation, count: 50), account: self.account, chatLocation: self.chatLocation, fixedCombinedReadStates: nil, tagMask: nil, additionalData: [])
                    let signal = historyView
                        |> mapToSignal { historyView -> Signal<MessageIndex?, NoError> in
                            switch historyView {
                                case .Loading:
                                    return .complete()
                                case let .HistoryView(view, _, _, _, _):
                                    for entry in view.entries {
                                        if case let .MessageEntry(message, _, _, _) = entry {
                                            if message.id == messageLocation.messageId {
                                                return .single(MessageIndex(message))
                                            }
                                        }
                                    }
                                    return .single(nil)
                            }
                        }
                        |> take(1)
                    self.messageIndexDisposable.set((signal |> deliverOnMainQueue).start(next: { [weak self] index in
                        if let strongSelf = self {
                            if let index = index {
                                strongSelf.chatDisplayNode.historyNode.scrollToMessage(from: fromIndex, to: index, animated: animated, scrollPosition: scrollPosition)
                                completion?()
                            } else {
                                (strongSelf.navigationController as? NavigationController)?.pushViewController(ChatController(account: strongSelf.account, chatLocation: .peer(messageLocation.messageId.peerId), messageId: messageLocation.messageId))
                                completion?()
                            }
                        }
                    }, completed: { [weak self] in
                        if let strongSelf = self {
                            strongSelf.loadingMessage.set(false)
                        }
                    }))
                }
            }
        } else {
            completion?()
        }
    }
    
    private func forwardMessages(messageIds: [MessageId]) {
        let controller = PeerSelectionController(account: self.account, filter: .onlyWriteable)
        controller.peerSelected = { [weak self, weak controller] peerId in
            guard let strongSelf = self, let strongController = controller else {
                return
            }
            
            if case .peer(peerId) = strongSelf.chatLocation {
                strongSelf.updateChatPresentationInterfaceState(animated: false, interactive: true, { $0.updatedInterfaceState({ $0.withUpdatedForwardMessageIds(messageIds).withoutSelectionState() }) })
                strongController.dismiss()
            } else if peerId == strongSelf.account.peerId {
                let _ = (enqueueMessages(account: strongSelf.account, peerId: peerId, messages: messageIds.map { id -> EnqueueMessage in
                    return .forward(source: id, grouping: .auto)
                })
                |> deliverOnMainQueue).start(next: { messageIds in
                    if let strongSelf = self {
                        let signals: [Signal<Bool, NoError>] = messageIds.compactMap({ id -> Signal<Bool, NoError>? in
                            guard let id = id else {
                                return nil
                            }
                            return strongSelf.account.pendingMessageManager.pendingMessageStatus(id)
                            |> mapToSignal { status -> Signal<Bool, NoError> in
                                if status != nil {
                                    return .never()
                                } else {
                                    return .single(true)
                                }
                            }
                            |> take(1)
                        })
                        if strongSelf.shareStatusDisposable == nil {
                            strongSelf.shareStatusDisposable = MetaDisposable()
                        }
                        strongSelf.shareStatusDisposable?.set((combineLatest(signals)
                            |> deliverOnMainQueue).start(completed: {
                                guard let strongSelf = self else {
                                    return
                                }
                                strongSelf.present(OverlayStatusController(theme: strongSelf.presentationData.theme, type: .success), in: .window(.root))
                            }))
                    }
                })
                strongSelf.updateChatPresentationInterfaceState(animated: false, interactive: true, { $0.updatedInterfaceState({ $0.withoutSelectionState() }) })
                strongController.dismiss()
            } else {
                let _ = (strongSelf.account.postbox.transaction({ transaction -> Void in
                    transaction.updatePeerChatInterfaceState(peerId, update: { currentState in
                        if let currentState = currentState as? ChatInterfaceState {
                            return currentState.withUpdatedForwardMessageIds(messageIds)
                        } else {
                            return ChatInterfaceState().withUpdatedForwardMessageIds(messageIds)
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
                        
                        (strongSelf.navigationController as? NavigationController)?.replaceTopController(ChatController(account: strongSelf.account, chatLocation: .peer(peerId)), animated: false, ready: ready)
                    }
                })
            }
        }
        self.chatDisplayNode.dismissInput()
        self.present(controller, in: .window(.root))
    }
    
    private func openPeer(peerId: PeerId?, navigation: ChatControllerInteractionNavigateToPeer, fromMessage: Message?) {
        if case let .peer(currentPeerId) = self.chatLocation, peerId == currentPeerId {
            switch navigation {
                case .info:
                    self.navigationButtonAction(.openChatInfo)
                case let .chat(textInputState, _):
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
                switch self.chatLocation {
                    case .peer:
                        switch navigation {
                            case .info:
                                let peerSignal: Signal<Peer?, NoError>
                                if let fromMessage = fromMessage {
                                    peerSignal = loadedPeerFromMessage(account: self.account, peerId: peerId, messageId: fromMessage.id)
                                } else {
                                    peerSignal = self.account.postbox.loadedPeerWithId(peerId) |> map(Optional.init)
                                }
                                self.navigationActionDisposable.set((peerSignal |> take(1) |> deliverOnMainQueue).start(next: { [weak self] peer in
                                    if let strongSelf = self, let peer = peer {
                                        if let infoController = peerInfoController(account: strongSelf.account, peer: peer) {
                                            (strongSelf.navigationController as? NavigationController)?.pushViewController(infoController)
                                        }
                                    }
                                }))
                            case let .chat(textInputState, messageId):
                                if let textInputState = textInputState {
                                    let _ = (self.account.postbox.transaction({ transaction -> Void in
                                        transaction.updatePeerChatInterfaceState(peerId, update: { currentState in
                                            if let currentState = currentState as? ChatInterfaceState {
                                                return currentState.withUpdatedComposeInputState(textInputState)
                                            } else {
                                                return ChatInterfaceState().withUpdatedComposeInputState(textInputState)
                                            }
                                        })
                                    })
                                    |> deliverOnMainQueue).start(completed: { [weak self] in
                                        if let strongSelf = self {
                                            (strongSelf.navigationController as? NavigationController)?.pushViewController(ChatController(account: strongSelf.account, chatLocation: .peer(peerId), messageId: nil))
                                        }
                                    })
                                } else {
                                    (self.navigationController as? NavigationController)?.pushViewController(ChatController(account: self.account, chatLocation: .peer(peerId), messageId: nil))
                                }
                            case let .withBotStartPayload(botStart):
                                (self.navigationController as? NavigationController)?.pushViewController(ChatController(account: self.account, chatLocation: .peer(peerId), messageId: nil, botStart: botStart))
                        }
                    case .group:
                        (self.navigationController as? NavigationController)?.pushViewController(ChatController(account: self.account, chatLocation: .peer(peerId), messageId: fromMessage?.id, botStart: nil))
                }
            } else {
                switch navigation {
                    case .info:
                        break
                    case let .chat(textInputState, _):
                        if let textInputState = textInputState {
                            let controller = PeerSelectionController(account: self.account)
                            controller.peerSelected = { [weak self, weak controller] peerId in
                                if let strongSelf = self, let strongController = controller {
                                    if case let .peer(currentPeerId) = strongSelf.chatLocation, peerId == currentPeerId {
                                        strongSelf.updateChatPresentationInterfaceState(animated: true, interactive: true, {
                                            return ($0.updatedInterfaceState {
                                                return $0.withUpdatedComposeInputState(textInputState)
                                            }).updatedInputMode({ _ in
                                                return .text
                                            })
                                        })
                                        strongController.dismiss()
                                    } else {
                                        let _ = (strongSelf.account.postbox.transaction({ transaction -> Void in
                                            transaction.updatePeerChatInterfaceState(peerId, update: { currentState in
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
                                                
                                                (strongSelf.navigationController as? NavigationController)?.replaceTopController(ChatController(account: strongSelf.account, chatLocation: .peer(peerId)), animated: false, ready: ready)
                                            }
                                        })
                                    }
                                }
                            }
                            self.chatDisplayNode.dismissInput()
                            self.present(controller, in: .window(.root))
                        }
                    case let .withBotStartPayload(_):
                        break
                }
            }
        }
    }
    
    private func openPeerMention(_ name: String) {
        let disposable: MetaDisposable
        if let resolvePeerByNameDisposable = self.resolvePeerByNameDisposable {
            disposable = resolvePeerByNameDisposable
        } else {
            disposable = MetaDisposable()
            self.resolvePeerByNameDisposable = disposable
        }
        disposable.set((resolvePeerByName(account: self.account, name: name, ageLimit: 10) |> take(1) |> deliverOnMainQueue).start(next: { [weak self] peerId in
            if let strongSelf = self {
                if let peerId = peerId {
                    (strongSelf.navigationController as? NavigationController)?.pushViewController(ChatController(account: strongSelf.account, chatLocation: .peer(peerId), messageId: nil))
                }
            }
        }))
    }
    
    private func unblockPeer() {
        guard case let .peer(peerId) = self.chatLocation else {
            return
        }
        let unblockingPeer = self.unblockingPeer
        unblockingPeer.set(true)
        
        var restartBot = false
        if let user = self.presentationInterfaceState.renderedPeer?.peer as? TelegramUser, user.botInfo != nil {
            restartBot = true
        }
        self.editMessageDisposable.set((requestUpdatePeerIsBlocked(account: self.account, peerId: peerId, isBlocked: false)
        |> afterDisposed({ [weak self] in
            Queue.mainQueue().async {
                unblockingPeer.set(false)
                if let strongSelf = self, restartBot {
                    let _ = enqueueMessages(account: strongSelf.account, peerId: peerId, messages: [.message(text: "/start", attributes: [], mediaReference: nil, replyToMessageId: nil, localGroupingKey: nil)]).start()
                }
            }
        })).start())
    }
    
    private func reportPeer() {
        if let peer = self.presentationInterfaceState.renderedPeer?.peer {
            let title: String
            var infoString: String?
            if let _ = peer as? TelegramGroup {
                title = self.presentationData.strings.Conversation_ReportSpam
            } else if let _ = peer as? TelegramChannel {
                title = self.presentationData.strings.Conversation_ReportSpam
            } else {
                title = self.presentationData.strings.Conversation_ReportSpam
                infoString = self.presentationData.strings.Conversation_ReportSpamConfirmation
            }
            let actionSheet = ActionSheetController(presentationTheme: self.presentationData.theme)
            
            var items: [ActionSheetItem] = []
            if let infoString = infoString {
                items.append(ActionSheetTextItem(title: infoString))
            }
            items.append(ActionSheetButtonItem(title: title, color: .destructive, action: { [weak self, weak actionSheet] in
                actionSheet?.dismissAnimated()
                if let strongSelf = self {
                    strongSelf.deleteChat(reportChatSpam: true)
                }
            }))
            actionSheet.setItemGroups([ActionSheetItemGroup(items: items), ActionSheetItemGroup(items: [
                ActionSheetButtonItem(title: self.presentationData.strings.Common_Cancel, color: .accent, action: { [weak actionSheet] in
                    actionSheet?.dismissAnimated()
                })
            ])])
            self.chatDisplayNode.dismissInput()
            self.present(actionSheet, in: .window(.root))
        }
    }
    
    private func addPeerContact() {
        if let peer = self.presentationInterfaceState.renderedPeer?.peer as? TelegramUser, let phone = peer.phone, !phone.isEmpty, let contactData = DeviceContactExtendedData(peer: peer) {
            self.present(addContactOptionsController(account: self.account, peer: peer, contactData: contactData), in: .window(.root))
        }
    }
    
    private func dismissReportPeer() {
        guard case let .peer(peerId) = self.chatLocation else {
            return
        }
        self.editMessageDisposable.set((TelegramCore.dismissReportPeer(account: self.account, peerId: peerId) |> afterDisposed({
            Queue.mainQueue().async {
            }
        })).start())
    }
    
    private func deleteChat(reportChatSpam: Bool) {
        guard case let .peer(peerId) = self.chatLocation else {
            return
        }
        self.chatDisplayNode.historyNode.disconnect()
        let _ = removePeerChat(postbox: self.account.postbox, peerId: peerId, reportChatSpam: reportChatSpam).start()
        (self.navigationController as? NavigationController)?.popToRoot(animated: true)
        
        let _ = requestUpdatePeerIsBlocked(account: self.account, peerId: peerId, isBlocked: true).start()
    }
    
    private func startBot(_ payload: String?) {
        guard case let .peer(peerId) = self.chatLocation else {
            return
        }
        
        let startingBot = self.startingBot
        startingBot.set(true)
        self.editMessageDisposable.set((requestStartBot(account: self.account, botPeerId: peerId, payload: payload) |> deliverOnMainQueue |> afterDisposed({
            startingBot.set(false)
        })).start(completed: { [weak self] in
            if let strongSelf = self {
                strongSelf.updateChatPresentationInterfaceState(animated: true, interactive: true, { $0.updatedBotStartPayload(nil) })
            }
        }))
    }
    
    private func openUrl(_ url: String, concealed: Bool) {
        let openImpl: () -> Void = { [weak self] in
            guard let strongSelf = self else {
                return
            }
        
            let disposable: MetaDisposable
            if let current = strongSelf.resolveUrlDisposable {
                disposable = current
            } else {
                disposable = MetaDisposable()
                strongSelf.resolveUrlDisposable = disposable
            }
            disposable.set((resolveUrl(account: strongSelf.account, url: url)
            |> deliverOnMainQueue).start(next: { [weak self] result in
                guard let strongSelf = self else {
                    return
                }
                openResolvedUrl(result, account: strongSelf.account, navigationController: strongSelf.navigationController as? NavigationController, openPeer: { peerId, navigation in
                    guard let strongSelf = self else {
                        return
                    }
                    switch navigation {
                        case let .chat(_, messageId):
                            if case .peer(peerId) = strongSelf.chatLocation {
                                if let messageId = messageId {
                                    strongSelf.navigateToMessage(from: nil, to: .id(messageId))
                                }
                            } else if let navigationController = strongSelf.navigationController as? NavigationController {
                                navigateToChatController(navigationController: navigationController, account: strongSelf.account, chatLocation: .peer(peerId), messageId: messageId, keepStack: .always)
                            }
                        case .info:
                            strongSelf.navigationActionDisposable.set((strongSelf.account.postbox.loadedPeerWithId(peerId)
                                |> take(1)
                                |> deliverOnMainQueue).start(next: { [weak self] peer in
                                    if let strongSelf = self, peer.restrictionText == nil {
                                        if let infoController = peerInfoController(account: strongSelf.account, peer: peer) {
                                            (strongSelf.navigationController as? NavigationController)?.pushViewController(infoController)
                                        }
                                    }
                                }))
                        case let .withBotStartPayload(startPayload):
                            if case .peer(peerId) = strongSelf.chatLocation {
                                strongSelf.updateChatPresentationInterfaceState(animated: true, interactive: true, {
                                    $0.updatedBotStartPayload(startPayload.payload)
                                })
                            } else if let navigationController = strongSelf.navigationController as? NavigationController {
                                navigateToChatController(navigationController: navigationController, account: strongSelf.account, chatLocation: .peer(peerId), botStart: startPayload)
                            }
                    }
                }, present: { c, a in
                    self?.present(c, in: .window(.root), with: a)
                }, dismissInput: {
                    self?.chatDisplayNode.dismissInput()
                })
            }))
        }
        
        var parsedUrlValue: URL?
        if let parsed = URL(string: url) {
            parsedUrlValue = parsed
        } else if let encoded = (url as NSString).addingPercentEscapes(using: String.Encoding.utf8.rawValue), let parsed = URL(string: encoded) {
            parsedUrlValue = parsed
        }
        
        if concealed, let parsedUrlValue = parsedUrlValue, (parsedUrlValue.scheme == "http" || parsedUrlValue.scheme == "https"), !isConcealedUrlWhitelisted(parsedUrlValue) {
            self.present(standardTextAlertController(theme: AlertControllerTheme(presentationTheme: self.presentationData.theme), title: nil, text: self.presentationData.strings.Generic_OpenHiddenLinkAlert(url).0, actions: [TextAlertAction(type: .genericAction, title: self.presentationData.strings.Common_No, action: {}), TextAlertAction(type: .defaultAction, title: self.presentationData.strings.Common_Yes, action: {
                openImpl()
            })]), in: .window(.root))
        } else {
            openImpl()
        }
    }
    
    private func openUrlIn(_ url: String) {
        if let applicationContext = self.account.applicationContext as? TelegramApplicationContext {
            let actionSheet = OpenInActionSheetController(postbox: self.account.postbox, applicationContext: applicationContext, theme: self.presentationData.theme, strings: self.presentationData.strings, item: .url(url: url), openUrl: { [weak self] url in
                if let strongSelf = self, let applicationContext = strongSelf.account.applicationContext as? TelegramApplicationContext, let navigationController = strongSelf.navigationController as? NavigationController {
                    openExternalUrl(account: strongSelf.account, url: url, presentationData: strongSelf.presentationData, applicationContext: applicationContext, navigationController: navigationController, dismissInput: {
                        self?.chatDisplayNode.dismissInput()
                    })
                }
            })
            self.chatDisplayNode.dismissInput()
            self.present(actionSheet, in: .window(.root))
        }
    }
    
    @available(iOSApplicationExtension 9.0, *)
    public func previewingContext(_ previewingContext: UIViewControllerPreviewing, viewControllerForLocation location: CGPoint) -> UIViewController? {
        if previewingContext.sourceView === (self.chatInfoNavigationButton?.buttonItem.customDisplayNode as? ChatAvatarNavigationNode)?.avatarNode.view {
            if let peer = self.presentationInterfaceState.renderedPeer?.peer, peer.smallProfileImage != nil {
                let galleryController = AvatarGalleryController(account: self.account, peer: peer, remoteEntries: nil, replaceRootController: { controller, ready in
                }, synchronousLoad: true)
                galleryController.setHintWillBePresentedInPreviewingContext(true)
                galleryController.containerLayoutUpdated(ContainerViewLayout(size: CGSize(width: self.view.bounds.size.width, height: self.view.bounds.size.height), metrics: LayoutMetrics(), intrinsicInsets: UIEdgeInsets(), safeInsets: UIEdgeInsets(), statusBarHeight: nil, inputHeight: nil, standardInputHeight: 216.0, inputHeightIsInteractivellyChanging: false), transition: .immediate)
                return galleryController
            }
        } else {
            let historyPoint = previewingContext.sourceView.convert(location, to: self.chatDisplayNode.historyNode.view)
            var result: (Message, ChatMessagePeekPreviewContent)?
            self.chatDisplayNode.historyNode.forEachItemNode { itemNode in
                if let itemNode = itemNode as? ChatMessageItemView {
                    if itemNode.frame.contains(historyPoint) {
                        if let value = itemNode.peekPreviewContent(at: self.chatDisplayNode.historyNode.view.convert(historyPoint, to: itemNode.view)) {
                            result = value
                        }
                    }
                }
            }
            if let (message, content) = result {
                switch content {
                    case let .media(media):
                        var selectedTransitionNode: (ASDisplayNode, () -> UIView?)?
                        self.chatDisplayNode.historyNode.forEachItemNode { itemNode in
                            if let itemNode = itemNode as? ChatMessageItemView {
                                if let result = itemNode.transitionNode(id: message.id, media: media) {
                                    selectedTransitionNode = result
                                }
                            }
                        }
                        
                        if let selectedTransitionNode = selectedTransitionNode {
                            if let previewData = chatMessagePreviewControllerData(account: self.account, message: message, standalone: false, reverseMessageGalleryOrder: false, navigationController: self.navigationController as? NavigationController) {
                                switch previewData {
                                    case let .gallery(gallery):
                                        gallery.setHintWillBePresentedInPreviewingContext(true)
                                        let rect = selectedTransitionNode.0.view.convert(selectedTransitionNode.0.bounds, to: previewingContext.sourceView)
                                        previewingContext.sourceRect = rect.insetBy(dx: -2.0, dy: -2.0)
                                        gallery.containerLayoutUpdated(ContainerViewLayout(size: CGSize(width: self.view.bounds.size.width, height: self.view.bounds.size.height), metrics: LayoutMetrics(), intrinsicInsets: UIEdgeInsets(), safeInsets: UIEdgeInsets(), statusBarHeight: nil, inputHeight: nil, standardInputHeight: 216.0, inputHeightIsInteractivellyChanging: false), transition: .immediate)
                                        return gallery
                                    case let .instantPage(gallery, centralIndex, galleryMedia):
                                        break
                                }
                            }
                        }
                    case let .url(node, rect, string):
                        let targetRect = node.view.convert(rect, to: previewingContext.sourceView)
                        previewingContext.sourceRect = CGRect(origin: CGPoint(x: floor(targetRect.midX), y: floor(targetRect.midY)), size: CGSize(width: 1.0, height: 1.0))
                        if let parsedUrl = URL(string: string) {
                            if parsedUrl.scheme == "http" || parsedUrl.scheme == "https" {
                                let controller = SFSafariViewController(url: parsedUrl)
                                if #available(iOSApplicationExtension 10.0, *) {
                                    controller.preferredBarTintColor = self.presentationData.theme.rootController.navigationBar.backgroundColor
                                    controller.preferredControlTintColor = self.presentationData.theme.rootController.navigationBar.accentTextColor
                                }
                                return controller
                            }
                        }
                }
            }
        }
        return nil
    }
    
    public func previewingContext(_ previewingContext: UIViewControllerPreviewing, commit viewControllerToCommit: UIViewController) {
        if let gallery = viewControllerToCommit as? AvatarGalleryController {
            self.chatDisplayNode.dismissInput()
            gallery.setHintWillBePresentedInPreviewingContext(false)
            self.present(gallery, in: .window(.root), with: AvatarGalleryControllerPresentationArguments(animated: false, transitionArguments: { _ in
                return nil
            }))
        } else if let gallery = viewControllerToCommit as? GalleryController {
            self.chatDisplayNode.dismissInput()
            gallery.setHintWillBePresentedInPreviewingContext(false)
            
            self.present(gallery, in: .window(.root), with: GalleryControllerPresentationArguments(animated: false, transitionArguments: { [weak self] messageId, media in
                if let strongSelf = self {
                    var selectedTransitionNode: (ASDisplayNode, () -> UIView?)?
                    strongSelf.chatDisplayNode.historyNode.forEachItemNode { itemNode in
                        if let itemNode = itemNode as? ChatMessageItemView {
                            if let result = itemNode.transitionNode(id: messageId, media: media) {
                                selectedTransitionNode = result
                            }
                        }
                    }
                    if let selectedTransitionNode = selectedTransitionNode {
                        return GalleryTransitionArguments(transitionNode: selectedTransitionNode, addToTransitionSurface: { view in
                            if let strongSelf = self {
                                strongSelf.chatDisplayNode.historyNode.view.superview?.insertSubview(view, aboveSubview: strongSelf.chatDisplayNode.historyNode.view)
                            }
                        })
                    }
                }
                return nil
            }))
        } else if let gallery = viewControllerToCommit as? InstantPageGalleryController {
            
        }
        
        if #available(iOSApplicationExtension 9.0, *) {
            if let safariController = viewControllerToCommit as? SFSafariViewController {
                if let window = self.navigationController?.view.window {
                    window.rootViewController?.present(safariController, animated: true)
                }
            }
        }
    }
    
    @available(iOSApplicationExtension 9.0, *)
    override public var previewActionItems: [UIPreviewActionItem] {
        struct PreviewActionsData {
            let notificationSettings: PeerNotificationSettings?
            let peer: Peer?
        }
        let chatLocation = self.chatLocation
        let data = Atomic<PreviewActionsData?>(value: nil)
        let semaphore = DispatchSemaphore(value: 0)
        let _ = self.account.postbox.transaction({ transaction -> Void in
            switch chatLocation {
                case let .peer(peerId):
                    let _ = data.swap(PreviewActionsData(notificationSettings: transaction.getPeerNotificationSettings(peerId), peer: transaction.getPeer(peerId)))
                case .group:
                    let _ = data.swap(PreviewActionsData(notificationSettings: nil, peer: nil))
            }
            semaphore.signal()
        }).start()
        semaphore.wait()
        
        return data.with { [weak self] data -> [UIPreviewActionItem] in
            var items: [UIPreviewActionItem] = []
            if let data = data, let strongSelf = self {
                let presentationData = strongSelf.account.telegramApplicationContext.currentPresentationData.with { $0 }
                
                switch strongSelf.peekActions {
                    case .standard:
                        if let peer = data.peer {
                            if let _ = data.peer as? TelegramUser {
                                items.append(UIPreviewAction(title: "👍", style: .default, handler: { _, _ in
                                    if let strongSelf = self {
                                        let _ = enqueueMessages(account: strongSelf.account, peerId: peer.id, messages: strongSelf.transformEnqueueMessages([.message(text: "👍", attributes: [], mediaReference: nil, replyToMessageId: nil, localGroupingKey: nil)])).start()
                                    }
                                }))
                            }
                        
                            if let notificationSettings = data.notificationSettings as? TelegramPeerNotificationSettings {
                                if case .muted = notificationSettings.muteState {
                                    items.append(UIPreviewAction(title: presentationData.strings.Conversation_Unmute, style: .default, handler: { _, _ in
                                        if let strongSelf = self {
                                            let _ = togglePeerMuted(account: strongSelf.account, peerId: peer.id).start()
                                        }
                                    }))
                                } else {
                                    let muteInterval: Int32
                                    if let _ = data.peer as? TelegramChannel {
                                        muteInterval = Int32.max
                                    } else {
                                        muteInterval = 1 * 60 * 60
                                    }
                                    let title: String
                                    if muteInterval == Int32.max {
                                        title = presentationData.strings.Conversation_Mute
                                    } else {
                                        title = muteForIntervalString(strings: presentationData.strings, value: muteInterval)
                                    }
                                    
                                    items.append(UIPreviewAction(title: title, style: .default, handler: { _, _ in
                                        if let strongSelf = self {
                                            let _ = updatePeerMuteSetting(account: strongSelf.account, peerId: peer.id, muteInterval: muteInterval).start()
                                        }
                                    }))
                                }
                            }
                        }
                    case let .remove(action):
                        items.append(UIPreviewAction(title: presentationData.strings.Common_Delete, style: .destructive, handler: { _, _ in
                            action()
                        }))
                }
            }
            return items
        }
    }
    
    private func debugStreamSingleVideo(_ id: MessageId) {
        let gallery = GalleryController(account: self.account, source: .peerMessagesAtId(id), streamSingleVideo: true, replaceRootController: { [weak self] controller, ready in
            if let strongSelf = self {
                (strongSelf.navigationController as? NavigationController)?.replaceTopController(controller, animated: false, ready: ready)
            }
            }, baseNavigationController: self.navigationController as? NavigationController)
        
        self.chatDisplayNode.dismissInput()
        self.present(gallery, in: .window(.root), with: GalleryControllerPresentationArguments(transitionArguments: { [weak self] messageId, media in
            if let strongSelf = self {
                var transitionNode: (ASDisplayNode, () -> UIView?)?
                strongSelf.chatDisplayNode.historyNode.forEachItemNode { itemNode in
                    if let itemNode = itemNode as? ChatMessageItemView {
                        if let result = itemNode.transitionNode(id: messageId, media: media) {
                            transitionNode = result
                        }
                    }
                }
                if let transitionNode = transitionNode {
                    return GalleryTransitionArguments(transitionNode: transitionNode, addToTransitionSurface: { view in
                        if let strongSelf = self {
                            strongSelf.chatDisplayNode.historyNode.view.superview?.insertSubview(view, aboveSubview: strongSelf.chatDisplayNode.historyNode.view)
                        }
                    })
                }
            }
            return nil
        }))
    }
    
    private func presentBanMessageOptions(author: Peer, messageIds: Set<MessageId>, options: ChatAvailableMessageActionOptions) {
        if case let .peer(peerId) = self.chatLocation {
            self.navigationActionDisposable.set((fetchChannelParticipant(account: self.account, peerId: peerId, participantId: author.id)
            |> deliverOnMainQueue).start(next: { [weak self] participant in
                if let strongSelf = self {
                    var canBan = true
                    if let participant = participant {
                        switch participant {
                            case .creator:
                                canBan = false
                            case let .member(_, _, adminInfo, _):
                                if let adminInfo = adminInfo, !adminInfo.rights.flags.isEmpty {
                                    canBan = false
                                }
                        }
                    }
                    if canBan {
                        let actionSheet = ActionSheetController(presentationTheme: strongSelf.presentationData.theme)
                        var items: [ActionSheetItem] = []
                        
                        var actions = Set<Int>([0])
                        
                        let toggleCheck: (Int, Int) -> Void = { [weak actionSheet] category, itemIndex in
                            if actions.contains(category) {
                                actions.remove(category)
                            } else {
                                actions.insert(category)
                            }
                            actionSheet?.updateItem(groupIndex: 0, itemIndex: itemIndex, { item in
                                if let item = item as? ActionSheetCheckboxItem {
                                    return ActionSheetCheckboxItem(title: item.title, label: item.label, value: !item.value, action: item.action)
                                }
                                return item
                            })
                        }
                        
                        var itemIndex = 0
                        for categoryId in [0, 1, 2, 3] as [Int] {
                            var title = ""
                            if categoryId == 0 {
                                title = strongSelf.presentationData.strings.Conversation_Moderate_Delete
                            } else if categoryId == 1 {
                                title = strongSelf.presentationData.strings.Conversation_Moderate_Ban
                            } else if categoryId == 2 {
                                title = strongSelf.presentationData.strings.Conversation_Moderate_Report
                            } else if categoryId == 3 {
                                title = strongSelf.presentationData.strings.Conversation_Moderate_DeleteAllMessages(author.displayTitle).0
                            }
                            let index = itemIndex
                            items.append(ActionSheetCheckboxItem(title: title, label: "", value: actions.contains(categoryId), action: { value in
                                toggleCheck(categoryId, index)
                            }))
                            itemIndex += 1
                        }
                        
                        items.append(ActionSheetButtonItem(title: strongSelf.presentationData.strings.Common_Done, action: { [weak self, weak actionSheet] in
                            actionSheet?.dismissAnimated()
                            if let strongSelf = self {
                                strongSelf.updateChatPresentationInterfaceState(animated: true, interactive: true, { $0.updatedInterfaceState { $0.withoutSelectionState() } })
                                if actions.contains(3) {
                                    let _ = strongSelf.account.postbox.transaction({ transaction -> Void in
                                        transaction.removeAllMessagesWithAuthor(peerId, authorId: author.id)
                                    }).start()
                                    let _ = clearAuthorHistory(account: strongSelf.account, peerId: peerId, memberId: author.id).start()
                                } else if actions.contains(0) {
                                    let _ = deleteMessagesInteractively(postbox: strongSelf.account.postbox, messageIds: Array(messageIds), type: .forEveryone).start()
                                }
                                if actions.contains(1) {
                                    let _ = removePeerMember(account: strongSelf.account, peerId: peerId, memberId: author.id).start()
                                }
                            }
                        }))
                        
                        actionSheet.setItemGroups([ActionSheetItemGroup(items: items), ActionSheetItemGroup(items: [
                            ActionSheetButtonItem(title: strongSelf.presentationData.strings.Common_Cancel, color: .accent, action: { [weak actionSheet] in
                                actionSheet?.dismissAnimated()
                            })
                        ])])
                        strongSelf.present(actionSheet, in: .window(.root))
                    } else {
                        strongSelf.presentDeleteMessageOptions(messageIds: messageIds, options: options)
                    }
                }
            }))
        }
    }
    
    private func presentDeleteMessageOptions(messageIds: Set<MessageId>, options: ChatAvailableMessageActionOptions) {
        let actionSheet = ActionSheetController(presentationTheme: self.presentationData.theme)
        var items: [ActionSheetItem] = []
        var personalPeerName: String?
        var isChannel = false
        if let user = self.presentationInterfaceState.renderedPeer?.peer as? TelegramUser {
            personalPeerName = user.compactDisplayTitle
        } else if let peer = self.presentationInterfaceState.renderedPeer?.peer as? TelegramSecretChat, let associatedPeerId = peer.associatedPeerId, let user = self.presentationInterfaceState.renderedPeer?.peers[associatedPeerId] as? TelegramUser {
            personalPeerName = user.compactDisplayTitle
        } else if let channel = self.presentationInterfaceState.renderedPeer?.peer as? TelegramChannel, case .broadcast = channel.info {
            isChannel = true
        }
        
        if options.contains(.deleteGlobally) {
            let globalTitle: String
            if isChannel {
                globalTitle = self.presentationData.strings.Conversation_DeleteMessagesForEveryone
            } else if let personalPeerName = personalPeerName {
                globalTitle = self.presentationData.strings.Conversation_DeleteMessagesFor(personalPeerName).0
            } else {
                globalTitle = self.presentationData.strings.Conversation_DeleteMessagesForEveryone
            }
            items.append(ActionSheetButtonItem(title: globalTitle, color: .destructive, action: { [weak self, weak actionSheet] in
                actionSheet?.dismissAnimated()
                if let strongSelf = self {
                    strongSelf.updateChatPresentationInterfaceState(animated: true, interactive: true, { $0.updatedInterfaceState { $0.withoutSelectionState() } })
                    let _ = deleteMessagesInteractively(postbox: strongSelf.account.postbox, messageIds: Array(messageIds), type: .forEveryone).start()
                }
            }))
        }
        if options.contains(.deleteLocally) {
            var localOptionText = self.presentationData.strings.Conversation_DeleteMessagesForMe
            if case .peer(self.account.peerId) = self.chatLocation {
                if messageIds.count == 1 {
                    localOptionText = self.presentationData.strings.Conversation_Moderate_Delete
                } else {
                    localOptionText = self.presentationData.strings.Conversation_DeleteManyMessages
                }
            }
            items.append(ActionSheetButtonItem(title: localOptionText, color: .destructive, action: { [weak self, weak actionSheet] in
                actionSheet?.dismissAnimated()
                if let strongSelf = self {
                    strongSelf.updateChatPresentationInterfaceState(animated: true, interactive: true, { $0.updatedInterfaceState { $0.withoutSelectionState() } })
                    let _ = deleteMessagesInteractively(postbox: strongSelf.account.postbox, messageIds: Array(messageIds), type: .forLocalPeer).start()
                }
            }))
        }
        actionSheet.setItemGroups([ActionSheetItemGroup(items: items), ActionSheetItemGroup(items: [
            ActionSheetButtonItem(title: self.presentationData.strings.Common_Cancel, color: .accent, action: { [weak actionSheet] in
                actionSheet?.dismissAnimated()
            })
        ])])
        self.chatDisplayNode.dismissInput()
        self.present(actionSheet, in: .window(.root))
    }
    
    @available(iOSApplicationExtension 11.0, *)
    public func dropInteraction(_ interaction: UIDropInteraction, canHandle session: UIDropSession) -> Bool {
        return session.hasItemsConforming(toTypeIdentifiers: [kUTTypeImage as String])
    }
    
    @available(iOSApplicationExtension 11.0, *)
    public func dropInteraction(_ interaction: UIDropInteraction, sessionDidUpdate session: UIDropSession) -> UIDropProposal {
        if !canSendMessagesToChat(self.presentationInterfaceState) {
            return UIDropProposal(operation: .cancel)
        }
        
        //let dropLocation = session.location(in: self.chatDisplayNode.view)
        self.chatDisplayNode.updateDropInteraction(isActive: true)
        
        let operation: UIDropOperation
        operation = .copy
        return UIDropProposal(operation: operation)
    }
    
    @available(iOSApplicationExtension 11.0, *)
    public func dropInteraction(_ interaction: UIDropInteraction, performDrop session: UIDropSession) {
        session.loadObjects(ofClass: UIImage.self) { [weak self] imageItems in
            guard let strongSelf = self else {
                return
            }
            let images = imageItems as! [UIImage]
            
            strongSelf.chatDisplayNode.updateDropInteraction(isActive: false)
            
            strongSelf.chatDisplayNode.displayPasteMenu(images)
        }
    }
    
    @available(iOSApplicationExtension 11.0, *)
    public func dropInteraction(_ interaction: UIDropInteraction, sessionDidExit session: UIDropSession) {
        self.chatDisplayNode.updateDropInteraction(isActive: false)
    }
    
    @available(iOSApplicationExtension 11.0, *)
    public func dropInteraction(_ interaction: UIDropInteraction, sessionDidEnd session: UIDropSession) {
        self.chatDisplayNode.updateDropInteraction(isActive: false)
    }
    
    public func beginMessageSearch(_ query: String) {
        self.interfaceInteraction?.beginMessageSearch(.everything, query)
    }
    
    private func displayMediaRecordingTip() {
        let rect: CGRect? = self.chatDisplayNode.frameForInputActionButton()
        
        let updatedMode: ChatTextInputMediaRecordingButtonMode = self.presentationInterfaceState.interfaceState.mediaRecordingMode
        
        let text: String
        if updatedMode == .audio {
            text = self.presentationData.strings.Conversation_HoldForAudio
        } else {
            text = self.presentationData.strings.Conversation_HoldForVideo
        }
        
        if let tooltipController = self.mediaRecordingModeTooltipController {
            tooltipController.text = text
        } else if let rect = rect {
            let tooltipController = TooltipController(text: text)
            self.mediaRecordingModeTooltipController = tooltipController
            tooltipController.dismissed = { [weak self, weak tooltipController] in
                if let strongSelf = self, let tooltipController = tooltipController, strongSelf.mediaRecordingModeTooltipController === tooltipController {
                    strongSelf.mediaRecordingModeTooltipController = nil
                }
            }
            self.present(tooltipController, in: .window(.root), with: TooltipControllerPresentationArguments(sourceNodeAndRect: { [weak self] in
                if let strongSelf = self {
                    return (strongSelf.chatDisplayNode, rect)
                }
                return nil
            }))
        }
    }
    
    private func commitPurposefulAction() {
        self.purposefulAction?()
    }
}
