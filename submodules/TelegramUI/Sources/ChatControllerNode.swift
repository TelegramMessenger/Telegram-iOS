import Foundation
import UIKit
import AsyncDisplayKit
import Postbox
import SwiftSignalKit
import Display
import TelegramCore
import TelegramPresentationData
import TelegramUIPreferences
import TextFormat
import AccountContext
import TelegramNotices
import TelegramUniversalVideoContent
import ChatInterfaceState
import FastBlur
import ConfettiEffect
import WallpaperBackgroundNode
import GridMessageSelectionNode
import SparseItemGrid
import ChatPresentationInterfaceState
import ChatInputPanelContainer
import PremiumUI
import ChatTitleView
import ChatInputNode
import ChatEntityKeyboardInputNode
import ChatControllerInteraction
import ChatAvatarNavigationNode
import AccessoryPanelNode
import ForwardAccessoryPanelNode
import ChatOverscrollControl
import ChatInputPanelNode
import ChatInputContextPanelNode
import TextSelectionNode
import ReplyAccessoryPanelNode
import ChatMessageItemView
import ChatMessageSelectionNode
import ManagedDiceAnimationNode
import ChatMessageTransitionNode
import ChatLoadingNode
import ChatRecentActionsController
import UIKitRuntimeUtils
import ChatInlineSearchResultsListComponent
import ComponentDisplayAdapters
import ComponentFlow
import ChatEmptyNode
import SpaceWarpView
import ChatSideTopicsPanel

final class VideoNavigationControllerDropContentItem: NavigationControllerDropContentItem {
    let itemNode: OverlayMediaItemNode
    
    init(itemNode: OverlayMediaItemNode) {
        self.itemNode = itemNode
    }
}

private final class ChatControllerNodeView: UITracingLayerView, WindowInputAccessoryHeightProvider {
    weak var node: ChatControllerNode?
    var inputAccessoryHeight: (() -> CGFloat)?
    var hitTestImpl: ((CGPoint, UIEvent?) -> UIView?)?
    
    func getWindowInputAccessoryHeight() -> CGFloat {
        return self.inputAccessoryHeight?() ?? 0.0
    }
    
    override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        if let result = self.hitTestImpl?(point, event) {
            return result
        }
        guard let result = super.hitTest(point, with: event) else {
            return nil
        }
        if let node = self.node {
            if result === node.historyNodeContainer.view {
                if node.historyNode.alpha == 0.0 {
                    return nil
                }
            }
        }
        return result
    }
}

private final class ScrollContainerNode: ASScrollNode {
    override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        if super.hitTest(point, with: event) == self.view {
            return nil
        }
        
        return super.hitTest(point, with: event)
    }
}

private struct ChatControllerNodeDerivedLayoutState {
    var inputContextPanelsFrame: CGRect
    var inputContextPanelsOverMainPanelFrame: CGRect
    var inputNodeHeight: CGFloat?
    var inputNodeAdditionalHeight: CGFloat?
    var upperInputPositionBound: CGFloat?
}

class ChatNodeContainer: ASDisplayNode {
    var contentNode: ASDisplayNode {
        return self
    }
    
    override init() {
        super.init()
    }
}

class HistoryNodeContainer: ASDisplayNode {
    var isSecret: Bool {
        didSet {
            if self.isSecret != oldValue {
                setLayerDisableScreenshots(self.layer, self.isSecret)
            }
        }
    }
    
    var contentNode: ASDisplayNode {
        return self
    }
    
    init(isSecret: Bool) {
        self.isSecret = isSecret
        
        super.init()
        
        if self.isSecret {
            setLayerDisableScreenshots(self.layer, self.isSecret)
        }
    }
}

private final class PendingSwitchToChatLocation {
    let historyNode: ChatHistoryListNodeImpl
    let animationDirection: ChatControllerAnimateInnerChatSwitchDirection?
    
    init(
        historyNode: ChatHistoryListNodeImpl,
        animationDirection: ChatControllerAnimateInnerChatSwitchDirection?
    ) {
        self.historyNode = historyNode
        self.animationDirection = animationDirection
    }
}

class ChatControllerNode: ASDisplayNode, ASScrollViewDelegate {
    let context: AccountContext
    private(set) var chatLocation: ChatLocation
    private var chatLocationContextHolder: Atomic<ChatLocationContextHolder?>
    let controllerInteraction: ChatControllerInteraction
    private weak var controller: ChatControllerImpl?
    
    let navigationBar: NavigationBar?
    let statusBar: StatusBar?
    
    private var backgroundEffectNode: ASDisplayNode?
    private var containerBackgroundNode: ASImageNode?
    private var scrollContainerNode: ScrollContainerNode?
    private var containerNode: ASDisplayNode?
    private var overlayNavigationBar: ChatOverlayNavigationBar?
    
    var overlayTitle: String? {
        didSet {
            self.overlayNavigationBar?.title = self.overlayTitle
        }
    }
    
    let wrappingNode: SpaceWarpNode
    let contentContainerNode: ChatNodeContainer
    let contentDimNode: ASDisplayNode
    let backgroundNode: WallpaperBackgroundNode
    var historyNode: ChatHistoryListNodeImpl
    var blurredHistoryNode: ASImageNode?
    let historyNodeContainer: HistoryNodeContainer
    private(set) var loadingNode: ChatLoadingNode
    
    private var isLoadingValue: Bool = false
    private var isLoadingEarlier: Bool = false
    private(set) var loadingPlaceholderNode: ChatLoadingPlaceholderNode?
    
    var alwaysShowSearchResultsAsList: Bool = false
    var includeSavedPeersInSearchResults: Bool = false
    var showListEmptyResults: Bool = false
    
    private var skippedShowSearchResultsAsListAnimationOnce: Bool = false
    var inlineSearchResults: ComponentView<Empty>?
    private var inlineSearchResultsReadyDisposable: Disposable?
    private var inlineSearchResultsReady: Bool = false
    
    var isScrollingLockedAtTop: Bool = false
    
    private var emptyNode: ChatEmptyNode?
    private(set) var emptyType: ChatHistoryNodeLoadState.EmptyType?
    private var didDisplayEmptyGreeting = false
    private var validEmptyNodeLayout: (CGSize, UIEdgeInsets, CGFloat, CGFloat)?
    var restrictedNode: ChatRecentActionsEmptyNode?
    
    private(set) var validLayout: (ContainerViewLayout, CGFloat)?
    private var visibleAreaInset = UIEdgeInsets()
    private var currentListViewLayout: (size: CGSize, insets: UIEdgeInsets, scrollIndicatorInsets: UIEdgeInsets)?
    
    private(set) var searchNavigationNode: ChatSearchNavigationContentNode?
    
    private var navigationModalFrame: NavigationModalFrame?
    
    let inputPanelContainerNode: ChatInputPanelContainer
    private let inputPanelOverlayNode: SparseNode
    private let inputPanelClippingNode: SparseNode
    let inputPanelBackgroundNode: NavigationBackgroundNode
    
    private var navigationBarBackgroundContent: WallpaperBubbleBackgroundNode?
    private var inputPanelBackgroundContent: WallpaperBubbleBackgroundNode?
    
    private var intrinsicInputPanelBackgroundNodeSize: CGSize?
    private let inputPanelBackgroundSeparatorNode: ASDisplayNode
    private var inputPanelBottomBackgroundSeparatorBaseOffset: CGFloat = 0.0
    private let inputPanelBottomBackgroundSeparatorNode: ASDisplayNode
    private var plainInputSeparatorAlpha: CGFloat?
    private var usePlainInputSeparator: Bool
    
    private var chatImportStatusPanel: ChatImportStatusPanel?
    
    private(set) var adPanelNode: ChatAdPanelNode?
    private(set) var feePanelNode: ChatFeePanelNode?
    
    private let titleAccessoryPanelContainer: ChatControllerTitlePanelNodeContainer
    private var titleTopicsAccessoryPanelNode: ChatTopicListTitleAccessoryPanelNode?
    private var titleAccessoryPanelNode: ChatTitleAccessoryPanelNode?
    
    private var chatTranslationPanel: ChatTranslationPanelNode?
    
    private var leftPanelContainer: ChatControllerTitlePanelNodeContainer
    private var leftPanel: (component: AnyComponentWithIdentity<ChatSidePanelEnvironment>, view: ComponentView<ChatSidePanelEnvironment>)?
    
    private(set) var inputPanelNode: ChatInputPanelNode?
    private(set) var inputPanelOverscrollNode: ChatInputPanelOverscrollNode?
    private weak var currentDismissedInputPanelNode: ChatInputPanelNode?
    private(set) var secondaryInputPanelNode: ChatInputPanelNode?
    private(set) var accessoryPanelNode: AccessoryPanelNode?
    private var inputContextPanelNode: ChatInputContextPanelNode?
    let inputContextPanelContainer: ChatControllerTitlePanelNodeContainer
    private let inputContextOverTextPanelContainer: ChatControllerTitlePanelNodeContainer
    private var overlayContextPanelNode: ChatInputContextPanelNode?
    
    private(set) var inputNode: ChatInputNode?
    private var disappearingNode: ChatInputNode?
    
    private(set) var textInputPanelNode: ChatTextInputPanelNode?
    
    private var inputMediaNodeData: ChatEntityKeyboardInputNode.InputData?
    private var inputMediaNodeDataPromise = Promise<ChatEntityKeyboardInputNode.InputData>()
    private var didInitializeInputMediaNodeDataPromise: Bool = false
    private var inputMediaNodeDataDisposable: Disposable?
    private var inputMediaNodeStateContext = ChatEntityKeyboardInputNode.StateContext()
        
    let navigateButtons: ChatHistoryNavigationButtons
    
    private var ignoreUpdateHeight = false
    private var overrideUpdateTextInputHeightTransition: ContainedViewLayoutTransition?
    
    private var animateInAsOverlayCompletion: (() -> Void)?
    private var dismissAsOverlayCompletion: (() -> Void)?
    private var dismissedAsOverlay = false
    private var scheduledAnimateInAsOverlayFromNode: ASDisplayNode?
    private var dismissAsOverlayLayout: ContainerViewLayout?
    
    lazy var hapticFeedback = { HapticFeedback() }()
    private var scrollViewDismissStatus = false
    
    var chatPresentationInterfaceState: ChatPresentationInterfaceState
    var automaticMediaDownloadSettings: MediaAutoDownloadSettings
    
    var interactiveEmojis: InteractiveEmojiConfiguration?
    private var interactiveEmojisDisposable: Disposable?
    
    private let selectedMessagesPromise = Promise<Set<MessageId>?>(nil)
    var selectedMessages: Set<MessageId>? {
        didSet {
            if self.selectedMessages != oldValue {
                self.selectedMessagesPromise.set(.single(self.selectedMessages))
            }
        }
    }
    
    private let updatingMessageMediaPromise = Promise<[MessageId: ChatUpdatingMessageMedia]>([:])
    var updatingMessageMedia: [MessageId: ChatUpdatingMessageMedia] = [:] {
        didSet {
            if self.updatingMessageMedia != oldValue {
                self.updatingMessageMediaPromise.set(.single(self.updatingMessageMedia))
            }
        }
    }
    
    var requestUpdateChatInterfaceState: (ContainedViewLayoutTransition, Bool, (ChatInterfaceState) -> ChatInterfaceState) -> Void = { _, _, _ in }
    var requestUpdateInterfaceState: (ContainedViewLayoutTransition, Bool, (ChatPresentationInterfaceState) -> ChatPresentationInterfaceState) -> Void = { _, _, _ in }
    var sendMessages: ([EnqueueMessage], Bool?, Int32?, Bool, Bool) -> Void = { _, _, _, _, _ in }
    var displayAttachmentMenu: () -> Void = { }
    var paste: (ChatTextInputPanelPasteData) -> Void = { _ in }
    var updateTypingActivity: (Bool) -> Void = { _ in }
    var dismissUrlPreview: () -> Void = { }
    var setupSendActionOnViewUpdate: (@escaping () -> Void, Int64?) -> Void = { _, _ in }
    var requestLayout: (ContainedViewLayoutTransition) -> Void = { _ in }
    var dismissAsOverlay: () -> Void = { }
    
    var interfaceInteraction: ChatPanelInterfaceInteraction?
        
    private var expandedInputDimNode: ASDisplayNode?
    
    private var dropDimNode: ASDisplayNode?

    var messageTransitionNode: ChatMessageTransitionNodeImpl

    private let presentationContextMarker = ASDisplayNode()
    
    private var containerLayoutAndNavigationBarHeight: (ContainerViewLayout, CGFloat)?
    
    private var scheduledLayoutTransitionRequestId: Int = 0
    private var scheduledLayoutTransitionRequest: (Int, ContainedViewLayoutTransition)?
    
    private var panRecognizer: WindowPanRecognizer?
    private let keyboardGestureRecognizerDelegate = WindowKeyboardGestureRecognizerDelegate()
    private var upperInputPositionBound: CGFloat?
    private var keyboardGestureBeginLocation: CGPoint?
    private var keyboardGestureAccessoryHeight: CGFloat?
    
    private var derivedLayoutState: ChatControllerNodeDerivedLayoutState?
    
    private var loadMoreSearchResultsDisposable: Disposable?
    
    let adMessagesContext: AdMessagesHistoryContext?
    
    private var pendingSwitchToChatLocation: PendingSwitchToChatLocation?
    
    private func updateIsLoading(isLoading: Bool, earlier: Bool, animated: Bool) {
        var useLoadingPlaceholder = self.chatLocation.peerId?.namespace != Namespaces.Peer.CloudUser && self.chatLocation.peerId?.namespace != Namespaces.Peer.SecretChat
        if case let .replyThread(message) = self.chatLocation, message.peerId == self.context.account.peerId {
            useLoadingPlaceholder = true
        }
        
        let updated = isLoading != self.isLoadingValue || (isLoading && earlier && !self.isLoadingEarlier)
        
        if updated {
            let updatedIsLoading = self.isLoadingValue != isLoading
            self.isLoadingValue = isLoading
            
            let updatedIsEarlier = self.isLoadingEarlier != earlier && !updatedIsLoading
            self.isLoadingEarlier = earlier
            
            if isLoading {
                if useLoadingPlaceholder {
                    let loadingPlaceholderNode: ChatLoadingPlaceholderNode
                    if let current = self.loadingPlaceholderNode {
                        loadingPlaceholderNode = current
                        
                        if updatedIsEarlier {
                            loadingPlaceholderNode.setup(self.historyNode, updating: true)
                        }
                    } else {
                        loadingPlaceholderNode = ChatLoadingPlaceholderNode(context: self.context, theme: self.chatPresentationInterfaceState.theme, chatWallpaper: self.chatPresentationInterfaceState.chatWallpaper, bubbleCorners: self.chatPresentationInterfaceState.bubbleCorners, backgroundNode: self.backgroundNode)
                        loadingPlaceholderNode.updatePresentationInterfaceState(self.chatPresentationInterfaceState)
                        self.backgroundNode.supernode?.insertSubnode(loadingPlaceholderNode, aboveSubnode: self.backgroundNode)
                        
                        self.loadingPlaceholderNode = loadingPlaceholderNode
                     
                        loadingPlaceholderNode.setup(self.historyNode, updating: false)
                        
                        let contentBounds = self.loadingNode.frame
                        loadingPlaceholderNode.frame = contentBounds
                        if let loadingPlaceholderNode = self.loadingPlaceholderNode, let validLayout = self.validLayout {
                            loadingPlaceholderNode.updateLayout(size: contentBounds.size, insets: self.visibleAreaInset, metrics: validLayout.0.metrics, transition: .immediate)
                            loadingPlaceholderNode.update(rect: contentBounds, within: contentBounds.size, transition: .immediate)
                        }
                    }
                    loadingPlaceholderNode.alpha = 1.0
                    loadingPlaceholderNode.isHidden = false
                } else {
                    self.historyNodeContainer.supernode?.insertSubnode(self.loadingNode, belowSubnode: self.historyNodeContainer)
                    self.loadingNode.isHidden = false
                    self.loadingNode.layer.removeAllAnimations()
                    self.loadingNode.alpha = 1.0
                    if animated {
                        self.loadingNode.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.3)
                    }
                }
            } else {
                if useLoadingPlaceholder {
                    if let loadingPlaceholderNode = self.loadingPlaceholderNode {
                        if animated {
                            loadingPlaceholderNode.animateOut(self.historyNode, completion: { [weak self] in
                                if let strongSelf = self {
                                    strongSelf.loadingPlaceholderNode?.removeFromSupernode()
                                    strongSelf.loadingPlaceholderNode = nil
                                }
                            })
                        } else {
                            self.loadingPlaceholderNode = nil
                            loadingPlaceholderNode.removeFromSupernode()
                            self.backgroundNode.updateIsLooping(false)
                        }
                    }
                } else {
                    self.loadingNode.alpha = 0.0
                    if animated {
                        self.loadingNode.layer.animateScale(from: 1.0, to: 0.1, duration: 0.3, removeOnCompletion: false)
                        self.loadingNode.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.3, completion: { [weak self] completed in
                            if let strongSelf = self {
                                strongSelf.loadingNode.layer.removeAllAnimations()
                                if completed {
                                    strongSelf.loadingNode.isHidden = true
                                }
                            }
                        })
                    } else {
                        self.loadingNode.isHidden = true
                    }
                }
            }
        }
    }
    
    private var lastSendTimestamp = 0.0
    
    private var openStickersBeginWithEmoji: Bool = false
    private var openStickersDisposable: Disposable?
    private var displayVideoUnmuteTipDisposable: Disposable?
    
    private var onLayoutCompletions: [(ContainedViewLayoutTransition) -> Void] = []

    init(context: AccountContext, chatLocation: ChatLocation, chatLocationContextHolder: Atomic<ChatLocationContextHolder?>, subject: ChatControllerSubject?, controllerInteraction: ChatControllerInteraction, chatPresentationInterfaceState: ChatPresentationInterfaceState, automaticMediaDownloadSettings: MediaAutoDownloadSettings, navigationBar: NavigationBar?, statusBar: StatusBar?, backgroundNode: WallpaperBackgroundNode, controller: ChatControllerImpl?) {
        self.context = context
        self.chatLocation = chatLocation
        self.chatLocationContextHolder = chatLocationContextHolder
        self.controllerInteraction = controllerInteraction
        self.chatPresentationInterfaceState = chatPresentationInterfaceState
        self.automaticMediaDownloadSettings = automaticMediaDownloadSettings
        self.navigationBar = navigationBar
        self.statusBar = statusBar
        self.controller = controller
        
        self.backgroundNode = backgroundNode
        
        self.wrappingNode = SpaceWarpNodeImpl()
        
        self.contentContainerNode = ChatNodeContainer()
        self.contentDimNode = ASDisplayNode()
        self.contentDimNode.isUserInteractionEnabled = false
        self.contentDimNode.backgroundColor = UIColor(white: 0.0, alpha: 0.2)
        self.contentDimNode.alpha = 0.0
        
        self.titleAccessoryPanelContainer = ChatControllerTitlePanelNodeContainer()
        self.titleAccessoryPanelContainer.clipsToBounds = true
        
        self.leftPanelContainer = ChatControllerTitlePanelNodeContainer()
        
        setLayerDisableScreenshots(self.titleAccessoryPanelContainer.layer, chatLocation.peerId?.namespace == Namespaces.Peer.SecretChat)
        
        self.inputContextPanelContainer = ChatControllerTitlePanelNodeContainer()
        self.inputContextOverTextPanelContainer = ChatControllerTitlePanelNodeContainer()
        
        var source: ChatHistoryListSource
        if case let .messageOptions(_, messageIds, info) = subject {
            switch info {
            case let .forward(forward):
                let messages = combineLatest(context.account.postbox.messagesAtIds(messageIds), context.account.postbox.loadedPeerWithId(context.account.peerId), forward.options)
                |> map { messages, accountPeer, options -> ([Message], Int32, Bool) in
                    var messages = messages
                    let forwardedMessageIds = Set(messages.map { $0.id })
                    messages.sort(by: { lhsMessage, rhsMessage in
                        return lhsMessage.index > rhsMessage.index
                    })
                    messages = messages.map { message in
                        var flags = message.flags
                        flags.remove(.Incoming)
                        flags.remove(.IsIncomingMask)
                        
                        var hideNames = options.hideNames
                        if message.id.peerId == accountPeer.id && message.forwardInfo == nil {
                            hideNames = true
                        }
                        
                        var attributes = message.attributes
                        attributes = attributes.filter({ attribute in
                            if attribute is EditedMessageAttribute {
                                return false
                            }
                            if let attribute = attribute as? ReplyMessageAttribute {
                                if attribute.quote != nil {
                                } else {
                                    if !forwardedMessageIds.contains(attribute.messageId) || hideNames {
                                        return false
                                    }
                                }
                            }
                            if attribute is ReplyMarkupMessageAttribute {
                                return false
                            }
                            if attribute is ReplyThreadMessageAttribute {
                                return false
                            }
                            if attribute is ViewCountMessageAttribute {
                                return false
                            }
                            if attribute is ForwardCountMessageAttribute {
                                return false
                            }
                            if attribute is ReactionsMessageAttribute {
                                return false
                            }
                            return true
                        })
                        
                        var messageText = message.text
                        var messageMedia = message.media
                        var hasDice = false
                        
                        if hideNames || options.hideCaptions {
                            for media in message.media {
                                if options.hideCaptions {
                                    if media is TelegramMediaImage || media is TelegramMediaFile {
                                        messageText = ""
                                        break
                                    }
                                }
                                if let poll = media as? TelegramMediaPoll {
                                    var updatedMedia = message.media.filter { !($0 is TelegramMediaPoll) }
                                    updatedMedia.append(TelegramMediaPoll(pollId: poll.pollId, publicity: poll.publicity, kind: poll.kind, text: poll.text, textEntities: poll.textEntities, options: poll.options, correctAnswers: poll.correctAnswers, results: TelegramMediaPollResults(voters: nil, totalVoters: nil, recentVoters: [], solution: nil), isClosed: false, deadlineTimeout: nil))
                                    messageMedia = updatedMedia
                                }
                                if let _ = media as? TelegramMediaDice {
                                    hasDice = true
                                }
                            }
                        }
                        
                        var forwardInfo: MessageForwardInfo?
                        if let existingForwardInfo = message.forwardInfo {
                            forwardInfo = MessageForwardInfo(author: existingForwardInfo.author, source: existingForwardInfo.source, sourceMessageId: nil, date: 0, authorSignature: nil, psaType: nil, flags: [])
                        }
                        else {
                            forwardInfo = MessageForwardInfo(author: message.author, source: nil, sourceMessageId: nil, date: 0, authorSignature: nil, psaType: nil, flags: [])
                        }
                        if hideNames && !hasDice {
                            forwardInfo = nil
                        }
                        
                        return message.withUpdatedFlags(flags).withUpdatedText(messageText).withUpdatedMedia(messageMedia).withUpdatedTimestamp(Int32(context.account.network.context.globalTime())).withUpdatedAttributes(attributes).withUpdatedAuthor(accountPeer).withUpdatedForwardInfo(forwardInfo)
                    }
                    
                    return (messages, Int32(messages.count), false)
                }
                source = .custom(messages: messages, messageId: MessageId(peerId: PeerId(0), namespace: 0, id: 0), quote: nil, loadMore: nil)
            case let .reply(reply):
                let messages = combineLatest(context.account.postbox.messagesAtIds(messageIds), context.account.postbox.loadedPeerWithId(context.account.peerId))
                |> map { messages, accountPeer -> ([Message], Int32, Bool) in
                    var messages = messages
                    messages.sort(by: { lhsMessage, rhsMessage in
                        return lhsMessage.timestamp > rhsMessage.timestamp
                    })
                    messages = messages.map { message in
                        return message
                    }
                    
                    return (messages, Int32(messages.count), false)
                }
                source = .custom(messages: messages, messageId: messageIds.first ?? MessageId(peerId: PeerId(0), namespace: 0, id: 0), quote: reply.quote.flatMap { quote in ChatHistoryListSource.Quote(text: quote.text, offset: quote.offset) }, loadMore: nil)
            case let .link(link):
                let messages = link.options
                |> mapToSignal { options -> Signal<(ChatControllerSubject.LinkOptions, Peer, Message?, [StoryId: CodableEntry]), NoError> in
                    let stories: Signal<[StoryId: CodableEntry], NoError>
                    if case let .Loaded(content) = options.webpage.content, let story = content.story {
                        stories = context.account.postbox.transaction { transaction -> [StoryId: CodableEntry] in
                            var result: [StoryId: CodableEntry] = [:]
                            if let storyValue = transaction.getStory(id: story.storyId) {
                                result[story.storyId] = storyValue
                            }
                            return result
                        }
                    } else {
                        stories = .single([:])
                    }
                    
                    if let replyMessageId = options.replyMessageId {
                        return combineLatest(
                            context.account.postbox.messagesAtIds([replyMessageId]),
                            context.account.postbox.loadedPeerWithId(context.account.peerId),
                            stories
                        )
                        |> map { messages, peer, stories -> (ChatControllerSubject.LinkOptions, Peer, Message?, [StoryId: CodableEntry]) in
                            return (options, peer, messages.first, stories)
                        }
                    } else {
                        return combineLatest(
                            context.account.postbox.loadedPeerWithId(context.account.peerId),
                            stories
                        )
                        |> map { peer, stories -> (ChatControllerSubject.LinkOptions, Peer, Message?, [StoryId: CodableEntry]) in
                            return (options, peer, nil, stories)
                        }
                    }
                }
                |> map { options, accountPeer, replyMessage, stories -> ([Message], Int32, Bool) in
                    var peers = SimpleDictionary<PeerId, Peer>()
                    peers[accountPeer.id] = accountPeer
                    
                    let author: Peer
                    if link.isCentered {
                        author = TelegramUser(id: EnginePeer.Id(namespace: Namespaces.Peer.CloudUser, id: EnginePeer.Id.Id._internalFromInt64Value(0)), accessHash: nil, firstName: "FirstName", lastName: nil, username: nil, phone: nil, photo: [], botInfo: nil, restrictionInfo: nil, flags: [], emojiStatus: nil, usernames: [], storiesHidden: nil, nameColor: .blue, backgroundEmojiId: nil, profileColor: nil, profileBackgroundEmojiId: nil, subscriberCount: nil, verificationIconFileId: nil)
                    } else {
                        author = accountPeer
                    }
                    
                    var associatedMessages = SimpleDictionary<MessageId, Message>()
                    
                    var media: [Media] = []
                    if case let .Loaded(content) = options.webpage.content {
                        media.append(TelegramMediaWebpage(webpageId: options.webpage.webpageId, content: .Loaded(content)))
                    }
                    
                    let associatedStories: [StoryId: CodableEntry] = stories
                    
                    var attributes: [MessageAttribute] = []
                    
                    attributes.append(TextEntitiesMessageAttribute(entities: options.messageEntities))
                    attributes.append(WebpagePreviewMessageAttribute(leadingPreview: !options.linkBelowText, forceLargeMedia: options.largeMedia, isManuallyAdded: true, isSafe: false))
                    
                    if let replyMessage {
                        associatedMessages[replyMessage.id] = replyMessage
                        
                        var mappedQuote: EngineMessageReplyQuote?
                        if let quote = options.replyQuote {
                            mappedQuote = EngineMessageReplyQuote(text: quote, offset: nil, entities: [], media: nil)
                        }
                        
                        attributes.append(ReplyMessageAttribute(messageId: replyMessage.id, threadMessageId: nil, quote: mappedQuote, isQuote: mappedQuote != nil))
                    }
                    
                    let message = Message(
                        stableId: 1,
                        stableVersion: 1,
                        id: MessageId(peerId: accountPeer.id, namespace: 0, id: 1),
                        globallyUniqueId: nil,
                        groupingKey: nil,
                        groupInfo: nil,
                        threadId: nil,
                        timestamp: Int32(Date().timeIntervalSince1970),
                        flags: [],
                        tags: [],
                        globalTags: [],
                        localTags: [],
                        customTags: [],
                        forwardInfo: nil,
                        author: author,
                        text: options.messageText,
                        attributes: attributes,
                        media: media,
                        peers: peers,
                        associatedMessages: associatedMessages,
                        associatedMessageIds: [],
                        associatedMedia: [:],
                        associatedThreadInfo: nil,
                        associatedStories: associatedStories
                    )
                    
                    return ([message], 1, false)
                }
                source = .custom(messages: messages, messageId: MessageId(peerId: PeerId(0), namespace: 0, id: 0), quote: nil, loadMore: nil)
            }
        } else if case .customChatContents = chatLocation {
            if case let .customChatContents(customChatContents) = subject {
                source = .customView(historyView: customChatContents.historyView)
            } else {
                source = .custom(messages: .single(([], 0, false)), messageId: nil, quote: nil, loadMore: nil)
            }
        } else {
            source = .default
        }
        
        var historyNodeRotated = true
        var isChatPreview = false
        switch chatPresentationInterfaceState.mode {
        case let .standard(standardMode):
            if case .embedded(true) = standardMode {
                historyNodeRotated = false
            } else if case .previewing = standardMode {
                isChatPreview = true
            }
        default:
            break
        }
        
        self.controllerInteraction.chatIsRotated = historyNodeRotated
        
        var displayAdPeer: PeerId?
        if !isChatPreview {
            switch subject {
            case .none, .message:
                if case let .peer(peerId) = chatLocation {
                    displayAdPeer = peerId
                }
            default:
                break
            }
        }
        if let displayAdPeer {
            self.adMessagesContext = context.engine.messages.adMessages(peerId: displayAdPeer)
        } else {
            self.adMessagesContext = nil
        }

        var getMessageTransitionNode: (() -> ChatMessageTransitionNodeImpl?)?
        self.historyNode = ChatHistoryListNodeImpl(context: context, updatedPresentationData: controller?.updatedPresentationData ?? (context.sharedContext.currentPresentationData.with({ $0 }), context.sharedContext.presentationData), chatLocation: chatLocation, chatLocationContextHolder: chatLocationContextHolder, adMessagesContext: self.adMessagesContext, tag: nil, source: source, subject: subject, controllerInteraction: controllerInteraction, selectedMessages: self.selectedMessagesPromise.get(), rotated: historyNodeRotated, isChatPreview: isChatPreview, messageTransitionNode: {
            return getMessageTransitionNode?()
        })

        self.historyNodeContainer = HistoryNodeContainer(isSecret: chatLocation.peerId?.namespace == Namespaces.Peer.SecretChat)
        
        self.historyNodeContainer.contentNode.addSubnode(self.historyNode)

        var getContentAreaInScreenSpaceImpl: (() -> CGRect)?
        var onTransitionEventImpl: ((ContainedViewLayoutTransition) -> Void)?
        self.messageTransitionNode = ChatMessageTransitionNodeImpl(listNode: self.historyNode, getContentAreaInScreenSpace: {
            return getContentAreaInScreenSpaceImpl?() ?? CGRect()
        }, onTransitionEvent: { transition in
            onTransitionEventImpl?(transition)
        })
        
        self.loadingNode = ChatLoadingNode(context: context, theme: self.chatPresentationInterfaceState.theme, chatWallpaper: self.chatPresentationInterfaceState.chatWallpaper, bubbleCorners: self.chatPresentationInterfaceState.bubbleCorners)
                
        self.inputPanelContainerNode = ChatInputPanelContainer()
        self.inputPanelOverlayNode = SparseNode()
        self.inputPanelClippingNode = SparseNode()
        
        if case let .color(color) = self.chatPresentationInterfaceState.chatWallpaper, UIColor(rgb: color).isEqual(self.chatPresentationInterfaceState.theme.chat.inputPanel.panelBackgroundColorNoWallpaper) {
            self.inputPanelBackgroundNode = NavigationBackgroundNode(color: self.chatPresentationInterfaceState.theme.chat.inputPanel.panelBackgroundColorNoWallpaper)
            self.usePlainInputSeparator = true
        } else {
            self.inputPanelBackgroundNode = NavigationBackgroundNode(color: self.chatPresentationInterfaceState.theme.chat.inputPanel.panelBackgroundColor)
            self.usePlainInputSeparator = false
            self.plainInputSeparatorAlpha = nil
        }
        //self.inputPanelBackgroundNode.isUserInteractionEnabled = false
        
        self.inputPanelBackgroundSeparatorNode = ASDisplayNode()
        self.inputPanelBackgroundSeparatorNode.backgroundColor = self.chatPresentationInterfaceState.theme.chat.inputPanel.panelSeparatorColor
        self.inputPanelBackgroundSeparatorNode.isLayerBacked = true
        
        self.inputPanelBottomBackgroundSeparatorNode = ASDisplayNode()
        self.inputPanelBottomBackgroundSeparatorNode.backgroundColor = self.chatPresentationInterfaceState.theme.chat.inputMediaPanel.panelSeparatorColor
        self.inputPanelBottomBackgroundSeparatorNode.isLayerBacked = true
        
        self.navigateButtons = ChatHistoryNavigationButtons(theme: self.chatPresentationInterfaceState.theme, dateTimeFormat: self.chatPresentationInterfaceState.dateTimeFormat, backgroundNode: self.backgroundNode, isChatRotated: historyNodeRotated)
        self.navigateButtons.accessibilityElementsHidden = true
        
        super.init()

        getContentAreaInScreenSpaceImpl = { [weak self] in
            guard let strongSelf = self else {
                return CGRect()
            }

            return strongSelf.view.convert(strongSelf.frameForVisibleArea(), to: nil)
        }

        onTransitionEventImpl = { [weak self] transition in
            guard let strongSelf = self else {
                return
            }
            if (strongSelf.context.sharedContext.currentPresentationData.with({ $0 })).reduceMotion {
                return
            }
            if strongSelf.context.sharedContext.energyUsageSettings.fullTranslucency {
                strongSelf.backgroundNode.animateEvent(transition: transition, extendAnimation: false)
            }
        }

        getMessageTransitionNode = { [weak self] in
            return self?.messageTransitionNode
        }
        
        self.controller?.presentationContext.topLevelSubview = { [weak self] in
            guard let strongSelf = self else {
                return nil
            }
            return strongSelf.presentationContextMarker.view
        }
        
        self.setViewBlock({
            return ChatControllerNodeView()
        })
        
        (self.view as? ChatControllerNodeView)?.node = self
        
        (self.view as? ChatControllerNodeView)?.inputAccessoryHeight = { [weak self] in
            if let strongSelf = self {
                return strongSelf.getWindowInputAccessoryHeight()
            } else {
                return 0.0
            }
        }
        
        (self.view as? ChatControllerNodeView)?.hitTestImpl = { [weak self] point, event in
            return self?.hitTest(point, with: event)
        }
        
        assert(Queue.mainQueue().isCurrent())
                
        self.setupHistoryNode()
        
        self.interactiveEmojisDisposable = (self.context.account.postbox.preferencesView(keys: [PreferencesKeys.appConfiguration])
        |> map { preferencesView -> InteractiveEmojiConfiguration in
            let appConfiguration: AppConfiguration = preferencesView.values[PreferencesKeys.appConfiguration]?.get(AppConfiguration.self) ?? .defaultValue
            return InteractiveEmojiConfiguration.with(appConfiguration: appConfiguration)
        }
        |> deliverOnMainQueue).startStrict(next: { [weak self] emojis in
            if let strongSelf = self {
                strongSelf.interactiveEmojis = emojis
            }
        })
    
        self.addSubnode(self.wrappingNode)
        self.wrappingNode.contentNode.addSubnode(self.contentContainerNode)
        self.contentContainerNode.contentNode.addSubnode(self.backgroundNode)
        self.contentContainerNode.contentNode.addSubnode(self.historyNodeContainer)
        self.contentContainerNode.contentNode.addSubnode(self.leftPanelContainer)
        
        if let navigationBar = self.navigationBar {
            self.contentContainerNode.contentNode.addSubnode(navigationBar)
        }
        
        self.inputPanelContainerNode.expansionUpdated = { [weak self] transition in
            guard let strongSelf = self else {
                return
            }

            if transition.isAnimated {
                strongSelf.scheduleLayoutTransitionRequest(transition)
            } else {
                strongSelf.requestLayout(transition)
            }
        }
        
        self.wrappingNode.contentNode.addSubnode(self.inputContextPanelContainer)
        self.wrappingNode.contentNode.addSubnode(self.inputPanelContainerNode)
        self.wrappingNode.contentNode.addSubnode(self.inputContextOverTextPanelContainer)
        
        self.inputPanelContainerNode.addSubnode(self.inputPanelClippingNode)
        self.inputPanelContainerNode.addSubnode(self.inputPanelOverlayNode)
        self.inputPanelClippingNode.addSubnode(self.inputPanelBackgroundNode)
        self.inputPanelClippingNode.addSubnode(self.inputPanelBackgroundSeparatorNode)
        self.inputPanelBackgroundNode.addSubnode(self.inputPanelBottomBackgroundSeparatorNode)

        self.wrappingNode.contentNode.addSubnode(self.messageTransitionNode)
        self.contentContainerNode.contentNode.addSubnode(self.navigateButtons)
        self.wrappingNode.contentNode.addSubnode(self.presentationContextMarker)
        self.contentContainerNode.contentNode.addSubnode(self.contentDimNode)

        self.navigationBar?.additionalContentNode.addSubnode(self.titleAccessoryPanelContainer)
        
        self.textInputPanelNode = ChatTextInputPanelNode(context: context, presentationInterfaceState: chatPresentationInterfaceState, presentationContext: ChatPresentationContext(context: context, backgroundNode: backgroundNode), presentController: { [weak self] controller in
            self?.interfaceInteraction?.presentController(controller, nil)
        })
        self.textInputPanelNode?.storedInputLanguage = chatPresentationInterfaceState.interfaceState.inputLanguage
        self.textInputPanelNode?.updateHeight = { [weak self] animated in
            if let strongSelf = self, let _ = strongSelf.inputPanelNode as? ChatTextInputPanelNode, !strongSelf.ignoreUpdateHeight {
                if strongSelf.scheduledLayoutTransitionRequest == nil {
                    let transition: ContainedViewLayoutTransition
                    if !animated {
                        transition = .immediate
                    } else if let overrideUpdateTextInputHeightTransition = strongSelf.overrideUpdateTextInputHeightTransition {
                        transition = overrideUpdateTextInputHeightTransition
                    } else {
                        transition = .animated(duration: 0.1, curve: .easeInOut)
                    }
                    strongSelf.scheduleLayoutTransitionRequest(transition)
                }
            }
        }
        
        self.textInputPanelNode?.sendMessage = { [weak self] in
            if let self, let controller = self.controller {
                if case .scheduledMessages = self.chatPresentationInterfaceState.subject, self.chatPresentationInterfaceState.editMessageState == nil {
                    self.controllerInteraction.scheduleCurrentMessage(nil)
                } else {
                    if let _ = self.chatPresentationInterfaceState.sendPaidMessageStars {
                        var count: Int32
                        if let forwardedCount = self.chatPresentationInterfaceState.interfaceState.forwardMessageIds?.count, forwardedCount > 0 {
                            count = Int32(forwardedCount)
                            if self.chatPresentationInterfaceState.interfaceState.effectiveInputState.inputText.length > 0 {
                                count += 1
                            }
                        } else {
                            count = Int32(ceil(CGFloat(self.chatPresentationInterfaceState.interfaceState.effectiveInputState.inputText.length) / 4096.0))
                        }
                        controller.presentPaidMessageAlertIfNeeded(count: count, completion: { [weak self] postpone in
                            self?.sendCurrentMessage(postpone: postpone)
                        })
                    } else {
                        self.sendCurrentMessage()
                    }
                }
            }
        }
        
        self.textInputPanelNode?.paste = { [weak self] data in
            self?.paste(data)
        }
        self.textInputPanelNode?.displayAttachmentMenu = { [weak self] in
            self?.displayAttachmentMenu()
        }
        self.textInputPanelNode?.updateActivity = { [weak self] in
            self?.updateTypingActivity(true)
        }
        self.textInputPanelNode?.toggleExpandMediaInput = { [weak self] in
            guard let strongSelf = self else {
                return
            }
            strongSelf.inputPanelContainerNode.toggleIfEnabled()
        }
        
        self.textInputPanelNode?.switchToTextInputIfNeeded = { [weak self] in
            guard let strongSelf = self, let interfaceInteraction = strongSelf.interfaceInteraction else {
                return
            }
            
            if let inputNode = strongSelf.inputNode as? ChatEntityKeyboardInputNode, !inputNode.canSwitchToTextInputAutomatically {
                return
            }
            
            interfaceInteraction.updateInputModeAndDismissedButtonKeyboardMessageId({ state in
                switch state.inputMode {
                case .media:
                    return (.text, state.keyboardButtonsMessage?.id)
                default:
                    return (state.inputMode, state.keyboardButtonsMessage?.id)
                }
            })
        }
        
        self.inputMediaNodeDataDisposable = (self.inputMediaNodeDataPromise.get()
        |> deliverOnMainQueue).startStrict(next: { [weak self] value in
            guard let strongSelf = self else {
                return
            }
            strongSelf.inputMediaNodeData = value
        })
    }
    
    deinit {
        self.interactiveEmojisDisposable?.dispose()
        self.openStickersDisposable?.dispose()
        self.displayVideoUnmuteTipDisposable?.dispose()
        self.inputMediaNodeDataDisposable?.dispose()
        self.inlineSearchResultsReadyDisposable?.dispose()
        self.loadMoreSearchResultsDisposable?.dispose()
    }
    
    override func didLoad() {
        super.didLoad()
        
        let recognizer = WindowPanRecognizer(target: nil, action: nil)
        recognizer.cancelsTouchesInView = false
        recognizer.delaysTouchesBegan = false
        recognizer.delaysTouchesEnded = false
        recognizer.delegate = self.keyboardGestureRecognizerDelegate
        recognizer.began = { [weak self] point in
            guard let strongSelf = self else {
                return
            }
            strongSelf.panGestureBegan(location: point)
        }
        recognizer.moved = { [weak self] point in
            guard let strongSelf = self else {
                return
            }
            strongSelf.panGestureMoved(location: point)
        }
        recognizer.ended = { [weak self] point, velocity in
            guard let strongSelf = self else {
                return
            }
            strongSelf.panGestureEnded(location: point, velocity: velocity)
        }
        self.panRecognizer = recognizer
        self.view.addGestureRecognizer(recognizer)
        
        self.view.disablesInteractiveTransitionGestureRecognizerNow = { [weak self] in
            guard let strongSelf = self else {
                return false
            }
            if let _ = strongSelf.chatPresentationInterfaceState.inputTextPanelState.mediaRecordingState {
                return true
            }
            var hasChatThemeScreen = false
            strongSelf.controller?.window?.forEachController { c in
                if c is ChatThemeScreen {
                    hasChatThemeScreen = true
                }
            }
            if hasChatThemeScreen {
                return true
            }
            
            return false
        }
    }
    
    private func updateIsEmpty(_ emptyType: ChatHistoryNodeLoadState.EmptyType?, wasLoading: Bool, animated: Bool) {
        self.emptyType = emptyType
        if let emptyType = emptyType, self.emptyNode == nil {
            let emptyNode = ChatEmptyNode(context: self.context, interaction: self.interfaceInteraction)
            emptyNode.isHidden = self.restrictedNode != nil
            self.emptyNode = emptyNode
            
            if let inlineSearchResultsView = self.inlineSearchResults?.view {
                self.contentContainerNode.contentNode.view.insertSubview(emptyNode.view, belowSubview: inlineSearchResultsView)
            } else {
                self.contentContainerNode.contentNode.insertSubnode(emptyNode, aboveSubnode: self.historyNodeContainer)
            }
            
            if let (size, insets, leftInset, rightInset) = self.validEmptyNodeLayout {
                let mappedType: ChatEmptyNode.Subject.EmptyType
                switch emptyType {
                case .generic:
                    mappedType = .generic
                case .joined:
                    mappedType = .joined
                case .clearedHistory:
                    mappedType = .clearedHistory
                case .topic:
                    mappedType = .topic
                case .botInfo:
                    mappedType = .botInfo
                }
                emptyNode.updateLayout(interfaceState: self.chatPresentationInterfaceState, subject: .emptyChat(mappedType), loadingNode: wasLoading && self.loadingNode.supernode != nil ? self.loadingNode : nil, backgroundNode: self.backgroundNode, size: size, insets: insets, leftInset: leftInset, rightInset: rightInset, transition: .immediate)
                emptyNode.frame = CGRect(origin: CGPoint(), size: size)
            }
            if animated {
                emptyNode.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.2)
            }
        } else if let emptyNode = self.emptyNode {
            self.emptyNode = nil
            if animated {
                emptyNode.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.2, removeOnCompletion: false, completion: { [weak emptyNode] _ in
                    emptyNode?.removeFromSupernode()
                })
            } else {
                emptyNode.removeFromSupernode()
            }
        }
    }
    
    private var isInFocus: Bool = false
    func inFocusUpdated(isInFocus: Bool) {
        self.isInFocus = isInFocus
        
        if let inputNode = self.inputNode as? ChatEntityKeyboardInputNode {
            inputNode.simulateUpdateLayout(isVisible: isInFocus)
        }
    }
    
    func preferredContentSizeForLayout(_ layout: ContainerViewLayout) -> CGSize? {
        var height = self.historyNode.scroller.contentSize.height
        height += 3.0
        height = min(height, layout.size.height)
        return CGSize(width: layout.size.width, height: height)
    }
    
    func forceUpdateWarpContents() {
        guard let (layout, _) = self.validLayout else {
            return
        }
        self.wrappingNode.update(size: layout.size, cornerRadius: layout.deviceMetrics.screenCornerRadius, transition: .immediate)
    }
    
    func containerLayoutUpdated(_ layout: ContainerViewLayout, navigationBarHeight: CGFloat, transition protoTransition: ContainedViewLayoutTransition, listViewTransaction: (ListViewUpdateSizeAndInsets, CGFloat, Bool, @escaping () -> Void) -> Void, updateExtraNavigationBarBackgroundHeight: (CGFloat, CGFloat, CGSize?, ContainedViewLayoutTransition) -> Void) {
        let transition: ContainedViewLayoutTransition
        if let _ = self.scheduledAnimateInAsOverlayFromNode {
            transition = .immediate
        } else {
            transition = protoTransition
        }
        
        transition.updateFrame(node: self.wrappingNode, frame: CGRect(origin: CGPoint(), size: layout.size))
        self.wrappingNode.update(size: layout.size, cornerRadius: layout.deviceMetrics.screenCornerRadius, transition: ComponentTransition(transition))
        
        if let statusBar = self.statusBar {
            switch self.chatPresentationInterfaceState.mode {
            case .standard:
                if self.inputPanelContainerNode.expansionFraction > 0.3 {
                    statusBar.updateStatusBarStyle(.White, animated: true)
                } else {
                    statusBar.updateStatusBarStyle(self.chatPresentationInterfaceState.theme.rootController.statusBarStyle.style, animated: true)
                }
                self.controller?.deferScreenEdgeGestures = []
            case .overlay:
                self.controller?.deferScreenEdgeGestures = [.top]
            case .inline:
                statusBar.statusBarStyle = .Ignore
            }
        }
        
        let isSecret = self.chatPresentationInterfaceState.copyProtectionEnabled || self.chatLocation.peerId?.namespace == Namespaces.Peer.SecretChat || self.chatLocation.peerId?.isVerificationCodes == true
        if self.historyNodeContainer.isSecret != isSecret {
            self.historyNodeContainer.isSecret = isSecret
            setLayerDisableScreenshots(self.titleAccessoryPanelContainer.layer, isSecret)
        }

        var previousListBottomInset: CGFloat?
        if !self.historyNode.frame.isEmpty {
            previousListBottomInset = self.historyNode.insets.top
        }

        self.messageTransitionNode.frame = CGRect(origin: CGPoint(), size: layout.size)
        self.contentContainerNode.frame = CGRect(origin: CGPoint(), size: layout.size)
        
        let isOverlay: Bool
        switch self.chatPresentationInterfaceState.mode {
        case .overlay:
            isOverlay = true
        default:
            isOverlay = false
        }
        
        let visibleRootModalDismissProgress: CGFloat
        if isOverlay {
            visibleRootModalDismissProgress = 1.0
        } else {
            visibleRootModalDismissProgress = 1.0 - self.inputPanelContainerNode.expansionFraction
        }
        if !isOverlay && self.inputPanelContainerNode.expansionFraction != 0.0 {
            let navigationModalFrame: NavigationModalFrame
            var animateFromFraction: CGFloat?
            if let current = self.navigationModalFrame {
                navigationModalFrame = current
            } else {
                animateFromFraction = 1.0
                navigationModalFrame = NavigationModalFrame()
                self.navigationModalFrame = navigationModalFrame
                self.wrappingNode.contentNode.insertSubnode(navigationModalFrame, aboveSubnode: self.contentContainerNode)
            }
            if transition.isAnimated, let animateFromFraction = animateFromFraction, animateFromFraction != 1.0 - self.inputPanelContainerNode.expansionFraction {
                navigationModalFrame.update(layout: layout, transition: .immediate)
                navigationModalFrame.updateDismissal(transition: .immediate, progress: animateFromFraction, additionalProgress: 0.0, completion: {})
            }
            navigationModalFrame.update(layout: layout, transition: transition)
            navigationModalFrame.updateDismissal(transition: transition, progress: 1.0 - self.inputPanelContainerNode.expansionFraction, additionalProgress: 0.0, completion: {})
            
            self.inputPanelClippingNode.clipsToBounds = true
            transition.updateCornerRadius(node: self.inputPanelClippingNode, cornerRadius: self.inputPanelContainerNode.expansionFraction * 10.0)
        } else {
            if let navigationModalFrame = self.navigationModalFrame {
                self.navigationModalFrame = nil
                navigationModalFrame.updateDismissal(transition: transition, progress: 1.0, additionalProgress: 0.0, completion: { [weak navigationModalFrame] in
                    navigationModalFrame?.removeFromSupernode()
                })
            }
            self.inputPanelClippingNode.clipsToBounds = true
            transition.updateCornerRadius(node: self.inputPanelClippingNode, cornerRadius: 0.0, completion: { [weak self] completed in
                guard let strongSelf = self, completed else {
                    return
                }
                //strongSelf.inputPanelClippingNode.clipsToBounds = false
                let _ = strongSelf
                let _ = completed
            })
        }
        
        transition.updateAlpha(node: self.contentDimNode, alpha: self.inputPanelContainerNode.expansionFraction)
        
        var topInset: CGFloat = 0.0
        if let statusBarHeight = layout.statusBarHeight {
            topInset += statusBarHeight
        }
        
        let maxScale: CGFloat
        let maxOffset: CGFloat
        maxScale = (layout.size.width - 16.0 * 2.0) / layout.size.width
        maxOffset = (topInset - (layout.size.height - layout.size.height * maxScale) / 2.0)
        
        let scale = 1.0 * visibleRootModalDismissProgress + (1.0 - visibleRootModalDismissProgress) * maxScale
        let offset = (1.0 - visibleRootModalDismissProgress) * maxOffset
        transition.updateSublayerTransformScaleAndOffset(node: self.contentContainerNode, scale: scale, offset: CGPoint(x: 0.0, y: offset), beginWithCurrentState: true)
        
        if let navigationModalFrame = self.navigationModalFrame {
            navigationModalFrame.update(layout: layout, transition: transition)
        }
        
        self.scheduledLayoutTransitionRequest = nil
        if case .overlay = self.chatPresentationInterfaceState.mode {
            if self.backgroundEffectNode == nil {
                let backgroundEffectNode = ASDisplayNode()
                backgroundEffectNode.backgroundColor = self.chatPresentationInterfaceState.theme.chatList.backgroundColor.withAlphaComponent(0.8)
                self.wrappingNode.contentNode.insertSubnode(backgroundEffectNode, at: 0)
                self.backgroundEffectNode = backgroundEffectNode
                backgroundEffectNode.view.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(self.backgroundEffectTap(_:))))
            }
            if self.scrollContainerNode == nil {
                let scrollContainerNode = ScrollContainerNode()
                scrollContainerNode.view.delaysContentTouches = false
                scrollContainerNode.view.delegate = self.wrappedScrollViewDelegate
                scrollContainerNode.view.alwaysBounceVertical = true
                if #available(iOSApplicationExtension 11.0, iOS 11.0, *) {
                    scrollContainerNode.view.contentInsetAdjustmentBehavior = .never
                }
                self.wrappingNode.contentNode.insertSubnode(scrollContainerNode, aboveSubnode: self.backgroundEffectNode!)
                self.scrollContainerNode = scrollContainerNode
            }
            if self.containerBackgroundNode == nil {
                let containerBackgroundNode = ASImageNode()
                containerBackgroundNode.displaysAsynchronously = false
                containerBackgroundNode.displayWithoutProcessing = true
                containerBackgroundNode.image = PresentationResourcesRootController.inAppNotificationBackground(self.chatPresentationInterfaceState.theme)
                self.scrollContainerNode?.addSubnode(containerBackgroundNode)
                self.containerBackgroundNode = containerBackgroundNode
            }
            if self.containerNode == nil {
                let containerNode = ASDisplayNode()
                containerNode.clipsToBounds = true
                containerNode.cornerRadius = 15.0
                containerNode.addSubnode(self.backgroundNode)
                containerNode.addSubnode(self.historyNodeContainer)
                self.contentContainerNode.isHidden = true
                if let restrictedNode = self.restrictedNode {
                    containerNode.addSubnode(restrictedNode)
                }
                self.containerNode = containerNode
                self.scrollContainerNode?.addSubnode(containerNode)
                self.navigationBar?.isHidden = true
            }
            if self.overlayNavigationBar == nil {
                let overlayNavigationBar = ChatOverlayNavigationBar(theme: self.chatPresentationInterfaceState.theme, strings: self.chatPresentationInterfaceState.strings, nameDisplayOrder: self.chatPresentationInterfaceState.nameDisplayOrder, tapped: { [weak self] in
                    if let strongSelf = self {
                        strongSelf.dismissAsOverlay()
                        if case let .peer(id) = strongSelf.chatPresentationInterfaceState.chatLocation {
                            strongSelf.interfaceInteraction?.navigateToChat(id)
                        }
                    }
                }, close: { [weak self] in
                    self?.dismissAsOverlay()
                })
                overlayNavigationBar.title = self.overlayTitle
                self.overlayNavigationBar = overlayNavigationBar
                self.containerNode?.addSubnode(overlayNavigationBar)
            }
        } else {
            if let backgroundEffectNode = self.backgroundEffectNode {
                backgroundEffectNode.removeFromSupernode()
                self.backgroundEffectNode = nil
            }
            if let scrollContainerNode = self.scrollContainerNode {
                scrollContainerNode.removeFromSupernode()
                self.scrollContainerNode = nil
            }
            if let containerNode = self.containerNode {
                self.containerNode = nil
                containerNode.removeFromSupernode()
                self.contentContainerNode.contentNode.insertSubnode(self.backgroundNode, at: 0)
                self.contentContainerNode.contentNode.insertSubnode(self.historyNodeContainer, aboveSubnode: self.backgroundNode)
                if let restrictedNode = self.restrictedNode {
                    self.contentContainerNode.contentNode.insertSubnode(restrictedNode, aboveSubnode: self.historyNodeContainer)
                }
                self.navigationBar?.isHidden = false
            }
            if let overlayNavigationBar = self.overlayNavigationBar {
                overlayNavigationBar.removeFromSupernode()
                self.overlayNavigationBar = nil
            }
        }
        
        var dismissedInputByDragging = false
        if let (validLayout, _) = self.validLayout {
            var wasDraggingKeyboard = false
            if validLayout.inputHeight != nil && validLayout.inputHeightIsInteractivellyChanging {
                wasDraggingKeyboard = true
            }
            var wasDraggingInputNode = false
            if let derivedLayoutState = self.derivedLayoutState, let inputNodeHeight = derivedLayoutState.inputNodeHeight, !inputNodeHeight.isZero, let upperInputPositionBound = derivedLayoutState.upperInputPositionBound {
                let normalizedHeight = max(0.0, layout.size.height - upperInputPositionBound)
                if normalizedHeight < inputNodeHeight {
                    wasDraggingInputNode = true
                }
            }
            if wasDraggingKeyboard || wasDraggingInputNode {
                var isDraggingKeyboard = wasDraggingKeyboard
                if layout.inputHeight == 0.0 && validLayout.inputHeightIsInteractivellyChanging && !layout.inputHeightIsInteractivellyChanging {
                    isDraggingKeyboard = false
                }
                var isDraggingInputNode = false
                if self.upperInputPositionBound != nil {
                    isDraggingInputNode = true
                }
                if !isDraggingKeyboard && !isDraggingInputNode {
                    dismissedInputByDragging = true
                }
            }
        }
        
        self.validLayout = (layout, navigationBarHeight)
        
        let cleanInsets = layout.intrinsicInsets
        
        var previousInputHeight: CGFloat = 0.0
        if let (previousLayout, _) = self.containerLayoutAndNavigationBarHeight {
            previousInputHeight = previousLayout.insets(options: [.input]).bottom
        }
        if let inputNode = self.inputNode {
            previousInputHeight = inputNode.bounds.size.height
        }
        var previousInputPanelOrigin = CGPoint(x: 0.0, y: layout.size.height - previousInputHeight)
        if let inputPanelNode = self.inputPanelNode {
            previousInputPanelOrigin.y -= inputPanelNode.bounds.size.height
        }
        if let secondaryInputPanelNode = self.secondaryInputPanelNode {
            previousInputPanelOrigin.y -= secondaryInputPanelNode.bounds.size.height
        }
        self.containerLayoutAndNavigationBarHeight = (layout, navigationBarHeight)

        var dismissedTitleTopicsAccessoryPanelNode: ChatTopicListTitleAccessoryPanelNode?
        var immediatelyLayoutTitleTopicsAccessoryPanelNodeAndAnimateAppearance = false
        var titleTopicsAccessoryPanelHeight: CGFloat?
        var titleTopicsAccessoryPanelBackgroundHeight: CGFloat?
        var titleTopicsAccessoryPanelHitTestSlop: CGFloat?
        if let titleTopicsAccessoryPanelNode = titleTopicsPanelForChatPresentationInterfaceState(self.chatPresentationInterfaceState, context: self.context, currentPanel: self.titleTopicsAccessoryPanelNode, controllerInteraction: self.controllerInteraction, interfaceInteraction: self.interfaceInteraction, force: false) {
            if self.titleTopicsAccessoryPanelNode != titleTopicsAccessoryPanelNode {
                dismissedTitleTopicsAccessoryPanelNode = self.titleTopicsAccessoryPanelNode
                self.titleTopicsAccessoryPanelNode = titleTopicsAccessoryPanelNode
                immediatelyLayoutTitleTopicsAccessoryPanelNodeAndAnimateAppearance = true
                self.titleAccessoryPanelContainer.addSubnode(titleTopicsAccessoryPanelNode)
                
                titleTopicsAccessoryPanelNode.clipsToBounds = true
            }
            
            let layoutResult = titleTopicsAccessoryPanelNode.updateLayout(width: layout.size.width, leftInset: layout.safeInsets.left, rightInset: layout.safeInsets.right, transition: immediatelyLayoutTitleTopicsAccessoryPanelNodeAndAnimateAppearance ? .immediate : transition, interfaceState: self.chatPresentationInterfaceState)
            titleTopicsAccessoryPanelHeight = layoutResult.insetHeight
            titleTopicsAccessoryPanelBackgroundHeight = layoutResult.backgroundHeight
            titleTopicsAccessoryPanelHitTestSlop = layoutResult.hitTestSlop
        } else if let titleTopicsAccessoryPanelNode = self.titleTopicsAccessoryPanelNode {
            dismissedTitleTopicsAccessoryPanelNode = titleTopicsAccessoryPanelNode
            self.titleTopicsAccessoryPanelNode = nil
        }
        
        var defaultLeftPanelWidth: CGFloat = 72.0
        defaultLeftPanelWidth += layout.safeInsets.left
        let leftPanelLeftInset = defaultLeftPanelWidth - 72.0
        
        var leftPanelSize: CGSize?
        var dismissedLeftPanel: (component: AnyComponentWithIdentity<ChatSidePanelEnvironment>, view: ComponentView<ChatSidePanelEnvironment>)?
        var immediatelyLayoutLeftPanelNodeAndAnimateAppearance = false
        if let leftPanelComponent = sidePanelForChatPresentationInterfaceState(self.chatPresentationInterfaceState, context: self.context, currentPanel: self.leftPanel?.component, controllerInteraction: self.controllerInteraction, interfaceInteraction: self.interfaceInteraction, force: false) {
            if self.leftPanel?.component.id != leftPanelComponent.id {
                dismissedLeftPanel = self.leftPanel
                self.leftPanel = (leftPanelComponent, ComponentView())
                immediatelyLayoutLeftPanelNodeAndAnimateAppearance = true
            } else if let leftPanel = self.leftPanel {
                self.leftPanel = (leftPanelComponent, leftPanel.view)
            }
            
            leftPanelSize = CGSize(width: defaultLeftPanelWidth, height: layout.size.height)
        } else if let leftPanel = self.leftPanel {
            dismissedLeftPanel = leftPanel
            self.leftPanel = nil
        }
        
        var dismissedTitleAccessoryPanelNode: ChatTitleAccessoryPanelNode?
        var immediatelyLayoutTitleAccessoryPanelNodeAndAnimateAppearance = false
        var titleAccessoryPanelHeight: CGFloat?
        var titleAccessoryPanelBackgroundHeight: CGFloat?
        var titleAccessoryPanelHitTestSlop: CGFloat?
        
        if let titleAccessoryPanelNode = titlePanelForChatPresentationInterfaceState(self.chatPresentationInterfaceState, context: self.context, currentPanel: self.titleAccessoryPanelNode, controllerInteraction: self.controllerInteraction, interfaceInteraction: self.interfaceInteraction, force: false) {
            if self.titleAccessoryPanelNode != titleAccessoryPanelNode {
                dismissedTitleAccessoryPanelNode = self.titleAccessoryPanelNode
                self.titleAccessoryPanelNode = titleAccessoryPanelNode
                immediatelyLayoutTitleAccessoryPanelNodeAndAnimateAppearance = true
                self.titleAccessoryPanelContainer.addSubnode(titleAccessoryPanelNode)
                
                titleAccessoryPanelNode.clipsToBounds = true
            }
            
            let layoutResult = titleAccessoryPanelNode.updateLayout(width: layout.size.width, leftInset: leftPanelSize?.width ?? layout.safeInsets.left, rightInset: layout.safeInsets.right, transition: immediatelyLayoutTitleAccessoryPanelNodeAndAnimateAppearance ? .immediate : transition, interfaceState: self.chatPresentationInterfaceState)
            titleAccessoryPanelHeight = layoutResult.insetHeight
            titleAccessoryPanelBackgroundHeight = layoutResult.backgroundHeight
            titleAccessoryPanelHitTestSlop = layoutResult.hitTestSlop
            if immediatelyLayoutTitleAccessoryPanelNodeAndAnimateAppearance {
                if transition.isAnimated {
                    titleAccessoryPanelNode.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.2)
                }
                titleAccessoryPanelNode.subnodeTransform = CATransform3DMakeTranslation(0.0, -layoutResult.backgroundHeight, 0.0)
                transition.updateSublayerTransformOffset(layer: titleAccessoryPanelNode.layer, offset: CGPoint())
            }
        } else if let titleAccessoryPanelNode = self.titleAccessoryPanelNode {
            dismissedTitleAccessoryPanelNode = titleAccessoryPanelNode
            self.titleAccessoryPanelNode = nil
        }
        
        var dismissedTranslationPanelNode: ChatTranslationPanelNode?
        var immediatelyLayoutTranslationPanelNodeAndAnimateAppearance = false
        var translationPanelHeight: CGFloat?
        
        var hasTranslationPanel = false
        if let _ = self.chatPresentationInterfaceState.translationState, self.emptyType == nil {
            if case .overlay = self.chatPresentationInterfaceState.mode {
            } else if self.chatPresentationInterfaceState.renderedPeer?.peer?.restrictionText(platform: "ios", contentSettings: self.context.currentContentSettings.with { $0 }) != nil {
            } else if self.chatPresentationInterfaceState.search != nil {
            } else {
                hasTranslationPanel = true
            }
        }
        
        /*#if DEBUG
        if "".isEmpty {
            hasTranslationPanel = true
        }
        #endif*/
        
        if hasTranslationPanel {
            let translationPanelNode: ChatTranslationPanelNode
            if let current = self.chatTranslationPanel {
                translationPanelNode = current
            } else {
                translationPanelNode = ChatTranslationPanelNode(context: self.context)
            }
            translationPanelNode.interfaceInteraction = self.interfaceInteraction
            
            if self.chatTranslationPanel != translationPanelNode {
                dismissedTranslationPanelNode = self.chatTranslationPanel
                self.chatTranslationPanel = translationPanelNode
                immediatelyLayoutTranslationPanelNodeAndAnimateAppearance = true
                self.titleAccessoryPanelContainer.addSubnode(translationPanelNode)
                
                translationPanelNode.clipsToBounds = true
            }
            
            let height = translationPanelNode.updateLayout(width: layout.size.width, leftInset: leftPanelSize?.width ?? layout.safeInsets.left, rightInset: layout.safeInsets.right, leftDisplayInset: leftPanelSize?.width ?? 0.0, transition: immediatelyLayoutTitleAccessoryPanelNodeAndAnimateAppearance ? .immediate : transition, interfaceState: self.chatPresentationInterfaceState)
            translationPanelHeight = height
            if immediatelyLayoutTranslationPanelNodeAndAnimateAppearance {
                translationPanelNode.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.2)
                translationPanelNode.subnodeTransform = CATransform3DMakeTranslation(0.0, -height, 0.0)
                transition.updateSublayerTransformOffset(layer: translationPanelNode.layer, offset: CGPoint())
            }
        } else if let chatTranslationPanel = self.chatTranslationPanel {
            dismissedTranslationPanelNode = chatTranslationPanel
            self.chatTranslationPanel = nil
        }
        
        var dismissedImportStatusPanelNode: ChatImportStatusPanel?
        var importStatusPanelHeight: CGFloat?
        if let importState = self.chatPresentationInterfaceState.importState {
            let importStatusPanelNode: ChatImportStatusPanel
            if let current = self.chatImportStatusPanel {
                importStatusPanelNode = current
            } else {
                importStatusPanelNode = ChatImportStatusPanel()
            }
            
            if self.chatImportStatusPanel != importStatusPanelNode {
                 dismissedImportStatusPanelNode = self.chatImportStatusPanel
                self.chatImportStatusPanel = importStatusPanelNode
                self.contentContainerNode.contentNode.addSubnode(importStatusPanelNode)
            }
            
            importStatusPanelHeight = importStatusPanelNode.update(context: self.context, progress: CGFloat(importState.progress), presentationData: ChatPresentationData(theme: ChatPresentationThemeData(theme: self.chatPresentationInterfaceState.theme, wallpaper: self.chatPresentationInterfaceState.chatWallpaper), fontSize: self.chatPresentationInterfaceState.fontSize, strings: self.chatPresentationInterfaceState.strings, dateTimeFormat: self.chatPresentationInterfaceState.dateTimeFormat, nameDisplayOrder: self.chatPresentationInterfaceState.nameDisplayOrder, disableAnimations: false, largeEmoji: false, chatBubbleCorners: PresentationChatBubbleCorners(mainRadius: 0.0, auxiliaryRadius: 0.0, mergeBubbleCorners: false)), width: layout.size.width)
        } else if let importStatusPanelNode = self.chatImportStatusPanel {
            dismissedImportStatusPanelNode = importStatusPanelNode
            self.chatImportStatusPanel = nil
        }
        
        var dismissedAdPanelNode: ChatAdPanelNode?
        var adPanelHeight: CGFloat?
        
        var displayAdPanel = false
        if let _ = self.chatPresentationInterfaceState.adMessage {
            if let chatHistoryState = self.chatPresentationInterfaceState.chatHistoryState, case .loaded(false, _) = chatHistoryState {
                if let user = chatPresentationInterfaceState.renderedPeer?.peer as? TelegramUser, user.botInfo != nil && !self.chatPresentationInterfaceState.peerIsBlocked && self.chatPresentationInterfaceState.hasAtLeast3Messages {
                    displayAdPanel = true
                }
            }
        }
        
        if displayAdPanel {
            var animateAppearance = false
            let adPanelNode: ChatAdPanelNode
            if let current = self.adPanelNode {
                adPanelNode = current
            } else {
                adPanelNode = ChatAdPanelNode(context: self.context, animationCache: self.controllerInteraction.presentationContext.animationCache, animationRenderer: self.controllerInteraction.presentationContext.animationRenderer)
                adPanelNode.controllerInteraction = self.controllerInteraction
                adPanelNode.clipsToBounds = true
                animateAppearance = true
            }
            
            if self.adPanelNode != adPanelNode {
                dismissedAdPanelNode = self.adPanelNode
                self.adPanelNode = adPanelNode
                self.titleAccessoryPanelContainer.addSubnode(adPanelNode)
            }
            
            let height = adPanelNode.updateLayout(width: layout.size.width, leftInset: leftPanelSize?.width ?? layout.safeInsets.left, rightInset: layout.safeInsets.right, transition: transition, interfaceState: self.chatPresentationInterfaceState)
            if let adMessage = self.chatPresentationInterfaceState.adMessage, let opaqueId = adMessage.adAttribute?.opaqueId {
                self.historyNode.markAdAsSeen(opaqueId: opaqueId)
            }
            
            adPanelHeight = height
            if transition.isAnimated && animateAppearance {
                adPanelNode.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.2)
                adPanelNode.subnodeTransform = CATransform3DMakeTranslation(0.0, -height, 0.0)
                transition.updateSublayerTransformOffset(layer: adPanelNode.layer, offset: CGPoint())
            }
        } else if let adPanelNode = self.adPanelNode {
            dismissedAdPanelNode = adPanelNode
            self.adPanelNode = nil
        }
        
        var dismissedFeePanelNode: ChatFeePanelNode?
        var feePanelHeight: CGFloat?
        
        var displayFeePanel = false
        if let user = self.chatPresentationInterfaceState.renderedPeer?.peer as? TelegramUser, user.botInfo == nil, let chatHistoryState = self.chatPresentationInterfaceState.chatHistoryState, case .loaded(false, _) = chatHistoryState {
            if !self.chatPresentationInterfaceState.peerIsBlocked, let paidMessageStars = self.chatPresentationInterfaceState.contactStatus?.peerStatusSettings?.paidMessageStars, paidMessageStars.value > 0 {
                displayFeePanel = true
            }
        }
        if displayFeePanel {
            var animateAppearance = false
            let feePanelNode: ChatFeePanelNode
            if let current = self.feePanelNode {
                feePanelNode = current
            } else {
                feePanelNode = ChatFeePanelNode(context: self.context)
                feePanelNode.controllerInteraction = self.controllerInteraction
                feePanelNode.clipsToBounds = true
                animateAppearance = true
            }
            
            if self.feePanelNode != feePanelNode {
                dismissedFeePanelNode = self.feePanelNode
                self.feePanelNode = feePanelNode
                self.titleAccessoryPanelContainer.addSubnode(feePanelNode)
            }
            
            let height = feePanelNode.updateLayout(width: layout.size.width, leftInset: layout.safeInsets.left, rightInset: layout.safeInsets.right, transition: transition, interfaceState: self.chatPresentationInterfaceState)
            
            feePanelHeight = height
            if transition.isAnimated && animateAppearance {
                feePanelNode.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.2)
                feePanelNode.subnodeTransform = CATransform3DMakeTranslation(0.0, -height, 0.0)
                transition.updateSublayerTransformOffset(layer: feePanelNode.layer, offset: CGPoint())
            }
        } else if let feePanelNode = self.feePanelNode {
            dismissedFeePanelNode = feePanelNode
            self.feePanelNode = nil
        }
        
        self.controllerInteraction.isSidePanelOpen = self.leftPanel != nil
        
        var inputPanelNodeBaseHeight: CGFloat = 0.0
        if let inputPanelNode = self.inputPanelNode {
            inputPanelNodeBaseHeight += inputPanelNode.minimalHeight(interfaceState: self.chatPresentationInterfaceState, metrics: layout.metrics)
        }
        if let secondaryInputPanelNode = self.secondaryInputPanelNode {
            inputPanelNodeBaseHeight += secondaryInputPanelNode.minimalHeight(interfaceState: self.chatPresentationInterfaceState, metrics: layout.metrics)
        }
        
        let previewing: Bool
        if case .standard(.previewing) = self.chatPresentationInterfaceState.mode {
            previewing = true
        } else {
            previewing = false
        }
        
        let inputNodeForState = inputNodeForChatPresentationIntefaceState(self.chatPresentationInterfaceState, context: self.context, currentNode: self.inputNode, interfaceInteraction: self.interfaceInteraction, controllerInteraction: self.controllerInteraction, inputPanelNode: self.inputPanelNode, makeMediaInputNode: {
            return self.makeMediaInputNode()
        })
        
        var insets: UIEdgeInsets
        var inputPanelBottomInsetTerm: CGFloat = 0.0
        if let inputNodeForState = inputNodeForState {
            if !self.inputPanelContainerNode.stableIsExpanded && inputNodeForState.adjustLayoutForHiddenInput {
                inputNodeForState.hideInput = false
                inputNodeForState.adjustLayoutForHiddenInput = false
            }
            
            insets = layout.insets(options: [])
            inputPanelBottomInsetTerm = max(insets.bottom, layout.standardInputHeight)
        } else {
            insets = layout.insets(options: [.input])
        }

        switch self.chatPresentationInterfaceState.mode {
        case .standard(.embedded):
            break
        case .overlay:
            insets.top = 44.0
        default:
            insets.top += navigationBarHeight
        }
        
        var inputPanelSize: CGSize?
        var immediatelyLayoutInputPanelAndAnimateAppearance = false
        var secondaryInputPanelSize: CGSize?
        var immediatelyLayoutSecondaryInputPanelAndAnimateAppearance = false
        var inputPanelNodeHandlesTransition = false
        
        var dismissedInputPanelNode: ChatInputPanelNode?
        var dismissedSecondaryInputPanelNode: ChatInputPanelNode?
        var dismissedAccessoryPanelNode: AccessoryPanelNode?
        var dismissedInputContextPanelNode: ChatInputContextPanelNode?
        var dismissedOverlayContextPanelNode: ChatInputContextPanelNode?
        
        let inputPanelNodes = inputPanelForChatPresentationIntefaceState(self.chatPresentationInterfaceState, context: self.context, currentPanel: self.inputPanelNode, currentSecondaryPanel: self.secondaryInputPanelNode, textInputPanelNode: self.textInputPanelNode, interfaceInteraction: self.interfaceInteraction)
        
        let inputPanelBottomInset = max(insets.bottom, inputPanelBottomInsetTerm)
        
        if let inputPanelNode = inputPanelNodes.primary, !previewing {
            if inputPanelNode !== self.inputPanelNode {
                if let inputTextPanelNode = self.inputPanelNode as? ChatTextInputPanelNode {
                    if inputTextPanelNode.isFocused {
                        self.context.sharedContext.mainWindow?.simulateKeyboardDismiss(transition: .animated(duration: 0.5, curve: .spring))
                    }
                    let _ = inputTextPanelNode.updateLayout(width: layout.size.width, leftInset: layout.safeInsets.left, rightInset: layout.safeInsets.right, bottomInset: layout.intrinsicInsets.bottom, additionalSideInsets: layout.additionalInsets, maxHeight: layout.size.height - insets.top - inputPanelBottomInset, isSecondary: false, transition: transition, interfaceState: self.chatPresentationInterfaceState, metrics: layout.metrics, isMediaInputExpanded: self.inputPanelContainerNode.expansionFraction == 1.0)
                }
                if let prevInputPanelNode = self.inputPanelNode, inputPanelNode.canHandleTransition(from: prevInputPanelNode) {
                    inputPanelNodeHandlesTransition = true
                    inputPanelNode.removeFromSupernode()
                    inputPanelNode.prevInputPanelNode = prevInputPanelNode
                    inputPanelNode.addSubnode(prevInputPanelNode)
                    
                    prevInputPanelNode.viewForOverlayContent?.removeFromSuperview()
                } else {
                    dismissedInputPanelNode = self.inputPanelNode
                }
                let inputPanelHeight = inputPanelNode.updateLayout(width: layout.size.width, leftInset: layout.safeInsets.left, rightInset: layout.safeInsets.right, bottomInset: layout.intrinsicInsets.bottom, additionalSideInsets: layout.additionalInsets, maxHeight: layout.size.height - insets.top - inputPanelBottomInset, isSecondary: false, transition: inputPanelNode.supernode !== self ? .immediate : transition, interfaceState: self.chatPresentationInterfaceState, metrics: layout.metrics, isMediaInputExpanded: self.inputPanelContainerNode.expansionFraction == 1.0)
                inputPanelSize = CGSize(width: layout.size.width, height: inputPanelHeight)
                self.inputPanelNode = inputPanelNode
                if inputPanelNode.supernode !== self {
                    immediatelyLayoutInputPanelAndAnimateAppearance = true
                    self.inputPanelClippingNode.insertSubnode(inputPanelNode, aboveSubnode: self.inputPanelBackgroundNode)
                }
                if let viewForOverlayContent = inputPanelNode.viewForOverlayContent, viewForOverlayContent.superview == nil {
                    self.inputPanelOverlayNode.view.addSubview(viewForOverlayContent)
                }
            } else {
                let inputPanelHeight = inputPanelNode.updateLayout(width: layout.size.width, leftInset: layout.safeInsets.left, rightInset: layout.safeInsets.right, bottomInset: layout.intrinsicInsets.bottom, additionalSideInsets: layout.additionalInsets, maxHeight: layout.size.height - insets.top - inputPanelBottomInset - 120.0, isSecondary: false, transition: transition, interfaceState: self.chatPresentationInterfaceState, metrics: layout.metrics, isMediaInputExpanded: self.inputPanelContainerNode.expansionFraction == 1.0)
                inputPanelSize = CGSize(width: layout.size.width, height: inputPanelHeight)
            }
        } else {
            dismissedInputPanelNode = self.inputPanelNode
            self.inputPanelNode = nil
        }
        
        if let secondaryInputPanelNode = inputPanelNodes.secondary, !previewing {
            if secondaryInputPanelNode !== self.secondaryInputPanelNode {
                dismissedSecondaryInputPanelNode = self.secondaryInputPanelNode
                let inputPanelHeight = secondaryInputPanelNode.updateLayout(width: layout.size.width, leftInset: layout.safeInsets.left, rightInset: layout.safeInsets.right, bottomInset: layout.intrinsicInsets.bottom, additionalSideInsets: layout.additionalInsets, maxHeight: layout.size.height - insets.top - inputPanelBottomInset, isSecondary: true, transition: .immediate, interfaceState: self.chatPresentationInterfaceState, metrics: layout.metrics, isMediaInputExpanded: self.inputPanelContainerNode.expansionFraction == 1.0)
                secondaryInputPanelSize = CGSize(width: layout.size.width, height: inputPanelHeight)
                self.secondaryInputPanelNode = secondaryInputPanelNode
                if secondaryInputPanelNode.supernode == nil {
                    immediatelyLayoutSecondaryInputPanelAndAnimateAppearance = true
                    self.inputPanelClippingNode.insertSubnode(secondaryInputPanelNode, aboveSubnode: self.inputPanelBackgroundNode)
                }
                if let viewForOverlayContent = secondaryInputPanelNode.viewForOverlayContent, viewForOverlayContent.superview == nil {
                    self.inputPanelOverlayNode.view.addSubview(viewForOverlayContent)
                }
            } else {
                let inputPanelHeight = secondaryInputPanelNode.updateLayout(width: layout.size.width, leftInset: layout.safeInsets.left, rightInset: layout.safeInsets.right, bottomInset: layout.intrinsicInsets.bottom, additionalSideInsets: layout.additionalInsets, maxHeight: layout.size.height - insets.top - inputPanelBottomInset, isSecondary: true, transition: transition, interfaceState: self.chatPresentationInterfaceState, metrics: layout.metrics, isMediaInputExpanded: self.inputPanelContainerNode.expansionFraction == 1.0)
                secondaryInputPanelSize = CGSize(width: layout.size.width, height: inputPanelHeight)
            }
        } else {
            dismissedSecondaryInputPanelNode = self.secondaryInputPanelNode
            self.secondaryInputPanelNode = nil
        }
        
        var accessoryPanelSize: CGSize?
        var immediatelyLayoutAccessoryPanelAndAnimateAppearance = false
        if let accessoryPanelNode = accessoryPanelForChatPresentationIntefaceState(self.chatPresentationInterfaceState, context: self.context, currentPanel: self.accessoryPanelNode, chatControllerInteraction: self.controllerInteraction, interfaceInteraction: self.interfaceInteraction) {
            accessoryPanelSize = accessoryPanelNode.measure(CGSize(width: layout.size.width, height: layout.size.height))
            
            accessoryPanelNode.updateState(size: layout.size, inset: layout.safeInsets.left, interfaceState: self.chatPresentationInterfaceState)
            
            if accessoryPanelNode !== self.accessoryPanelNode {
                dismissedAccessoryPanelNode = self.accessoryPanelNode
                self.accessoryPanelNode = accessoryPanelNode
                
                if let inputPanelNode = self.inputPanelNode {
                    self.inputPanelClippingNode.insertSubnode(accessoryPanelNode, belowSubnode: inputPanelNode)
                } else {
                    self.inputPanelClippingNode.insertSubnode(accessoryPanelNode, aboveSubnode: self.inputPanelBackgroundNode)
                }
                accessoryPanelNode.animateIn()
                
                accessoryPanelNode.dismiss = { [weak self, weak accessoryPanelNode] in
                    if let strongSelf = self, let accessoryPanelNode = accessoryPanelNode, strongSelf.accessoryPanelNode === accessoryPanelNode {
                        if let _ = accessoryPanelNode as? ReplyAccessoryPanelNode {
                            strongSelf.requestUpdateChatInterfaceState(.animated(duration: 0.4, curve: .spring), false, { $0.withUpdatedReplyMessageSubject(nil) })
                        } else if let _ = accessoryPanelNode as? ForwardAccessoryPanelNode {
                            strongSelf.requestUpdateChatInterfaceState(.animated(duration: 0.4, curve: .spring), false, { $0.withUpdatedForwardMessageIds(nil).withUpdatedForwardOptionsState(nil) })
                        } else if let _ = accessoryPanelNode as? EditAccessoryPanelNode {
                            strongSelf.interfaceInteraction?.setupEditMessage(nil, { _ in })
                        } else if let _ = accessoryPanelNode as? WebpagePreviewAccessoryPanelNode {
                            strongSelf.dismissUrlPreview()
                        }
                    }
                }
                
                immediatelyLayoutAccessoryPanelAndAnimateAppearance = true
            }
        } else if let accessoryPanelNode = self.accessoryPanelNode {
            dismissedAccessoryPanelNode = accessoryPanelNode
            self.accessoryPanelNode = nil
        }
        
        var maximumInputNodeHeight = layout.size.height - max(layout.statusBarHeight ?? 0.0, layout.safeInsets.top) - 10.0
        if let inputPanelSize = inputPanelSize {
            if let inputNode = self.inputNode, inputNode.hideInput, !inputNode.adjustLayoutForHiddenInput {
                maximumInputNodeHeight -= inputPanelNodeBaseHeight
            } else {
                maximumInputNodeHeight -= inputPanelSize.height
            }
        }
        if let secondaryInputPanelSize = secondaryInputPanelSize {
            maximumInputNodeHeight -= secondaryInputPanelSize.height
        }
        if let accessoryPanelSize = accessoryPanelSize {
            maximumInputNodeHeight -= accessoryPanelSize.height
        }
        
        var dismissedInputNode: ChatInputNode?
        var dismissedInputNodeInputBackgroundExtension: CGFloat = 0.0
        var dismissedInputNodeExternalTopPanelContainer: UIView?
        var immediatelyLayoutInputNodeAndAnimateAppearance = false
        var inputNodeHeightAndOverflow: (CGFloat, CGFloat)?
        if let inputNode = inputNodeForState {
            if self.inputNode != inputNode {
                inputNode.topBackgroundExtensionUpdated = { [weak self] transition in
                    self?.updateInputPanelBackgroundExtension(transition: transition)
                }
                inputNode.hideInputUpdated = { [weak self] transition in
                    guard let strongSelf = self else {
                        return
                    }
                    let applyAutocorrection = strongSelf.inputNode?.hideInput ?? false
                    
                    strongSelf.updateInputPanelBackgroundExpansion(transition: transition)
                    
                    if applyAutocorrection, let textInputPanelNode = strongSelf.textInputPanelNode {
                        if let textInputNode = textInputPanelNode.textInputNode, textInputNode.isFirstResponder() {
                            Keyboard.applyAutocorrection(textView: textInputNode.textView)
                        }
                    }
                }
                
                dismissedInputNode = self.inputNode
                if let inputNode = self.inputNode {
                    dismissedInputNodeInputBackgroundExtension = inputNode.topBackgroundExtension
                }
                dismissedInputNodeExternalTopPanelContainer = self.inputNode?.externalTopPanelContainer
                self.inputNode = inputNode
                inputNode.alpha = 1.0
                inputNode.layer.removeAnimation(forKey: "opacity")
                immediatelyLayoutInputNodeAndAnimateAppearance = true
                
                self.inputPanelClippingNode.insertSubnode(inputNode, belowSubnode: self.inputPanelBackgroundNode)
                
                if let externalTopPanelContainer = inputNode.externalTopPanelContainer {
                    if let inputPanelNode = self.inputPanelNode, inputPanelNode.supernode != nil {
                        self.inputPanelClippingNode.view.insertSubview(externalTopPanelContainer, belowSubview: inputPanelNode.view)
                    } else {
                        self.inputPanelClippingNode.view.addSubview(externalTopPanelContainer)
                    }
                }
            }
            
            if inputNode.hideInput, inputNode.adjustLayoutForHiddenInput, let inputPanelSize = inputPanelSize {
                maximumInputNodeHeight += inputPanelSize.height
            }
            
            let inputHeight = layout.standardInputHeight + self.inputPanelContainerNode.expansionFraction * (maximumInputNodeHeight - layout.standardInputHeight)
            
            let heightAndOverflow = inputNode.updateLayout(width: layout.size.width, leftInset: layout.safeInsets.left, rightInset: layout.safeInsets.right, bottomInset: cleanInsets.bottom, standardInputHeight: inputHeight, inputHeight: layout.inputHeight ?? 0.0, maximumHeight: maximumInputNodeHeight, inputPanelHeight: inputPanelNodeBaseHeight, transition: immediatelyLayoutInputNodeAndAnimateAppearance ? .immediate : transition, interfaceState: self.chatPresentationInterfaceState, layoutMetrics: layout.metrics, deviceMetrics: layout.deviceMetrics, isVisible: self.isInFocus, isExpanded: self.inputPanelContainerNode.stableIsExpanded)
            
            let boundedHeight = inputNode.followsDefaultHeight ? min(heightAndOverflow.0, layout.standardInputHeight) : heightAndOverflow.0
            
            inputNodeHeightAndOverflow = (
                boundedHeight,
                inputNode.followsDefaultHeight ? max(0.0, inputHeight - boundedHeight) : 0.0
            )
        } else if let inputNode = self.inputNode {
            dismissedInputNode = inputNode
            dismissedInputNodeInputBackgroundExtension = inputNode.topBackgroundExtension
            dismissedInputNodeExternalTopPanelContainer = inputNode.externalTopPanelContainer
            self.inputNode = nil
        }
        
        var effectiveInputNodeHeight: CGFloat?
        if let inputNodeHeightAndOverflow = inputNodeHeightAndOverflow {
            if let upperInputPositionBound = self.upperInputPositionBound {
                effectiveInputNodeHeight = max(0.0, min(layout.size.height - max(0.0, upperInputPositionBound), inputNodeHeightAndOverflow.0))
            } else {
                effectiveInputNodeHeight = inputNodeHeightAndOverflow.0
            }
        }
        
        var bottomOverflowOffset: CGFloat = 0.0
        if let effectiveInputNodeHeight = effectiveInputNodeHeight, let inputNodeHeightAndOverflow = inputNodeHeightAndOverflow {
            insets.bottom = max(effectiveInputNodeHeight, insets.bottom)
            bottomOverflowOffset = inputNodeHeightAndOverflow.1
        }
        
        var wrappingInsets = UIEdgeInsets()
        if case .overlay = self.chatPresentationInterfaceState.mode {
            let containerWidth = horizontalContainerFillingSizeForLayout(layout: layout, sideInset: 8.0 + layout.safeInsets.left)
            wrappingInsets.left = floor((layout.size.width - containerWidth) / 2.0)
            wrappingInsets.right = wrappingInsets.left
            
            wrappingInsets.top = 8.0
            if let statusBarHeight = layout.statusBarHeight, CGFloat(40.0).isLess(than: statusBarHeight) {
                wrappingInsets.top += statusBarHeight
            }
        }
                
        transition.updateFrame(node: self.titleAccessoryPanelContainer, frame: CGRect(origin: CGPoint(x: 0.0, y: insets.top), size: CGSize(width: layout.size.width, height: 200.0)))
        self.titleAccessoryPanelContainer.hitTestExcludeInsets = UIEdgeInsets(top: 0.0, left: leftPanelSize?.width ?? 0.0, bottom: 0.0, right: 0.0)
        
        transition.updateFrame(node: self.inputContextPanelContainer, frame: CGRect(origin: CGPoint(x: 0.0, y: 0.0), size: CGSize(width: layout.size.width, height: layout.size.height)))
        transition.updateFrame(node: self.inputContextOverTextPanelContainer, frame: CGRect(origin: CGPoint(x: 0.0, y: 0.0), size: CGSize(width: layout.size.width, height: layout.size.height)))
        
        var extraNavigationBarHeight: CGFloat = 0.0
        var extraNavigationBarHitTestSlop: CGFloat = 0.0

        var titlePanelsContentOffset: CGFloat = 0.0

        let sidePanelTopInset: CGFloat = insets.top

        var titleTopicsAccessoryPanelFrame: CGRect?
        if let _ = self.titleTopicsAccessoryPanelNode, let panelHeight = titleTopicsAccessoryPanelHeight {
            titleTopicsAccessoryPanelFrame = CGRect(origin: CGPoint(x: 0.0, y: titlePanelsContentOffset), size: CGSize(width: layout.size.width, height: panelHeight))
            insets.top += panelHeight
            extraNavigationBarHeight += titleTopicsAccessoryPanelBackgroundHeight ?? 0.0
            extraNavigationBarHitTestSlop = titleTopicsAccessoryPanelHitTestSlop ?? 0.0
            titlePanelsContentOffset += panelHeight
        }

        var titleAccessoryPanelFrame: CGRect?
        let titleAccessoryPanelBaseY = titlePanelsContentOffset
        if let _ = self.titleAccessoryPanelNode, let panelHeight = titleAccessoryPanelHeight {
            titleAccessoryPanelFrame = CGRect(origin: CGPoint(x: 0.0, y: titlePanelsContentOffset), size: CGSize(width: layout.size.width, height: panelHeight))
            insets.top += panelHeight
            extraNavigationBarHeight += titleAccessoryPanelBackgroundHeight ?? 0.0
            extraNavigationBarHitTestSlop = titleAccessoryPanelHitTestSlop ?? 0.0
            titlePanelsContentOffset += panelHeight
        }
        
        var translationPanelFrame: CGRect?
        if let _ = self.chatTranslationPanel, let panelHeight = translationPanelHeight {
            translationPanelFrame = CGRect(origin: CGPoint(x: 0.0, y: extraNavigationBarHeight), size: CGSize(width: layout.size.width, height: panelHeight))
            insets.top += panelHeight
            extraNavigationBarHeight += panelHeight
        }

        var importStatusPanelFrame: CGRect?
        if let _ = self.chatImportStatusPanel, let panelHeight = importStatusPanelHeight {
            importStatusPanelFrame = CGRect(origin: CGPoint(x: 0.0, y: insets.top), size: CGSize(width: layout.size.width, height: panelHeight))
            insets.top += panelHeight
        }
        
        var adPanelFrame: CGRect?
        if let _ = self.adPanelNode, let panelHeight = adPanelHeight {
            adPanelFrame = CGRect(origin: CGPoint(x: 0.0, y: extraNavigationBarHeight), size: CGSize(width: layout.size.width, height: panelHeight))
            insets.top += panelHeight
            extraNavigationBarHeight += panelHeight
        }
        
        var feePanelFrame: CGRect?
        if let _ = self.feePanelNode, let panelHeight = feePanelHeight {
            feePanelFrame = CGRect(origin: CGPoint(x: 0.0, y: extraNavigationBarHeight), size: CGSize(width: layout.size.width, height: panelHeight))
            insets.top += panelHeight
            extraNavigationBarHeight += panelHeight
        }
        
        var extraNavigationBarLeftCutout: CGSize?
        if let leftPanelSize {
            extraNavigationBarLeftCutout = CGSize(width: leftPanelSize.width, height: navigationBarHeight)
        } else {
            extraNavigationBarLeftCutout = CGSize(width: 0.0, height: navigationBarHeight)
        }

        updateExtraNavigationBarBackgroundHeight(extraNavigationBarHeight, extraNavigationBarHitTestSlop, extraNavigationBarLeftCutout, transition)
        
        let contentBounds = CGRect(x: 0.0, y: 0.0, width: layout.size.width - wrappingInsets.left - wrappingInsets.right, height: layout.size.height - wrappingInsets.top - wrappingInsets.bottom)
        
        if let backgroundEffectNode = self.backgroundEffectNode {
            transition.updateFrame(node: backgroundEffectNode, frame: CGRect(origin: CGPoint(), size: layout.size))
        }
        
        var wallpaperBounds = CGRect(x: 0.0, y: 0.0, width: layout.size.width - wrappingInsets.left - wrappingInsets.right, height: layout.size.height)
        
        transition.updateFrame(node: self.backgroundNode, frame: wallpaperBounds)
        
        var displayMode: WallpaperDisplayMode = .aspectFill
        if case .regular = layout.metrics.widthClass, layout.size.height == layout.deviceMetrics.screenSize.width {
            displayMode = .aspectFit
        } else if case .compact = layout.metrics.widthClass {
            if layout.size.width < layout.size.height && layout.size.height < layout.deviceMetrics.screenSize.height {
                wallpaperBounds.size = layout.deviceMetrics.screenSize
            } else if layout.size.width > layout.size.height && layout.size.height < layout.deviceMetrics.screenSize.width {
                wallpaperBounds.size = layout.deviceMetrics.screenSize
            }
        }
        self.backgroundNode.updateLayout(size: wallpaperBounds.size, displayMode: displayMode, transition: transition)

        transition.updateBounds(node: self.historyNodeContainer, bounds: contentBounds)
        transition.updatePosition(node: self.historyNodeContainer, position: contentBounds.center)
        
        if let pendingSwitchToChatLocation = self.pendingSwitchToChatLocation {
            self.pendingSwitchToChatLocation = nil
            
            let previousHistoryNode = self.historyNode
            self.historyNode = pendingSwitchToChatLocation.historyNode
            
            self.historyNode.position = previousHistoryNode.position
            self.historyNode.bounds = previousHistoryNode.bounds
            self.historyNode.transform = previousHistoryNode.transform
            
            self.historyNode.messageTransitionNode = { [weak self] in
                guard let self else {
                    return nil
                }
                return self.messageTransitionNode
            }
            
            transition.updateBounds(node: self.historyNode, bounds: CGRect(origin: CGPoint(), size: contentBounds.size))
            transition.updatePosition(node: self.historyNode, position: CGPoint(x: contentBounds.size.width / 2.0, y: contentBounds.size.height / 2.0))
            
            previousHistoryNode.supernode?.insertSubnode(self.historyNode, aboveSubnode: previousHistoryNode)
            
            let messageTransitionNode = ChatMessageTransitionNodeImpl(listNode: self.historyNode, getContentAreaInScreenSpace: { [weak self] in
                guard let self else {
                    return CGRect()
                }
                return self.view.convert(self.frameForVisibleArea(), to: nil)
            }, onTransitionEvent: { [weak self] transition in
                guard let self else {
                    return
                }
                if (self.context.sharedContext.currentPresentationData.with({ $0 })).reduceMotion {
                    return
                }
                if self.context.sharedContext.energyUsageSettings.fullTranslucency {
                    self.backgroundNode.animateEvent(transition: transition, extendAnimation: false)
                }
            })
            
            let previousMessageTransitionNode = self.messageTransitionNode
            self.messageTransitionNode = messageTransitionNode
            
            messageTransitionNode.position = previousMessageTransitionNode.position
            messageTransitionNode.bounds = previousMessageTransitionNode.bounds
            messageTransitionNode.transform = previousMessageTransitionNode.transform
            
            self.wrappingNode.contentNode.insertSubnode(self.messageTransitionNode, aboveSubnode: previousMessageTransitionNode)
            
            self.emptyType = nil
            self.isLoadingValue = false
            self.isLoadingEarlier = false
            
            let previousLoadingNode = self.loadingNode
            self.backgroundNode.updateIsLooping(false)
            self.loadingNode = ChatLoadingNode(context: self.context, theme: self.chatPresentationInterfaceState.theme, chatWallpaper: self.chatPresentationInterfaceState.chatWallpaper, bubbleCorners: self.chatPresentationInterfaceState.bubbleCorners)
            self.loadingNode.frame = previousLoadingNode.frame
            self.loadingNode.isHidden = previousLoadingNode.isHidden
            self.loadingNode.alpha = previousLoadingNode.alpha
            previousLoadingNode.supernode?.insertSubnode(self.loadingNode, aboveSubnode: previousLoadingNode)
            
            let previousLoadingPlaceholderNode = self.loadingPlaceholderNode
            self.loadingPlaceholderNode = nil
            
            let previousEmptyNode = self.emptyNode
            self.emptyNode = nil
            
            self.setupHistoryNode()
            self.historyNode.loadStateUpdated?(self.historyNode.loadState ?? .messages, false)
            
            if let animationDirection = pendingSwitchToChatLocation.animationDirection {
                var offsetMultiplier = CGPoint()
                switch animationDirection {
                case .up:
                    offsetMultiplier.y = -1.0
                case .down:
                    offsetMultiplier.y = 1.0
                case .left:
                    offsetMultiplier.x = -1.0
                case .right:
                    offsetMultiplier.x = 1.0
                }
                
                previousHistoryNode.clipsToBounds = true
                self.historyNode.clipsToBounds = true
                
                transition.animatePosition(layer: self.historyNode.layer, from: CGPoint(x: offsetMultiplier.x * layout.size.width, y: offsetMultiplier.y * layout.size.height), to: CGPoint(), removeOnCompletion: true, additive: true, completion: { [weak self] _ in
                    guard let self else {
                        return
                    }
                    self.historyNode.clipsToBounds = false
                })
                transition.animatePosition(layer: previousHistoryNode.layer, from: CGPoint(), to: CGPoint(x: -offsetMultiplier.x * layout.size.width, y: -offsetMultiplier.y * layout.size.height), removeOnCompletion: false, additive: true, completion: { [weak previousHistoryNode] _ in
                    previousHistoryNode?.removeFromSupernode()
                })
                
                transition.animatePosition(layer: self.messageTransitionNode.layer, from: CGPoint(x: offsetMultiplier.x * layout.size.width, y: offsetMultiplier.y * layout.size.height), to: CGPoint(), removeOnCompletion: true, additive: true)
                transition.animatePosition(layer: previousMessageTransitionNode.layer, from: CGPoint(), to: CGPoint(x: -offsetMultiplier.x * layout.size.width, y: -offsetMultiplier.y * layout.size.height), removeOnCompletion: false, additive: true, completion: { [weak previousMessageTransitionNode] _ in
                    previousMessageTransitionNode?.removeFromSupernode()
                })
                
                transition.animatePosition(layer: self.loadingNode.layer, from: CGPoint(x: offsetMultiplier.x * layout.size.width, y: offsetMultiplier.y * layout.size.height), to: CGPoint(), removeOnCompletion: true, additive: true)
                transition.animatePosition(layer: previousLoadingNode.layer, from: CGPoint(), to: CGPoint(x: -offsetMultiplier.x * layout.size.width, y: -offsetMultiplier.y * layout.size.height), removeOnCompletion: false, additive: true, completion: { [weak previousLoadingNode] _ in
                    previousLoadingNode?.removeFromSupernode()
                })
                
                if let loadingPlaceholderNode = self.loadingPlaceholderNode {
                    transition.animatePosition(layer: loadingPlaceholderNode.layer, from: CGPoint(x: offsetMultiplier.x * layout.size.width, y: offsetMultiplier.y * layout.size.height), to: CGPoint(), removeOnCompletion: true, additive: true)
                }
                if let previousLoadingPlaceholderNode {
                    transition.animatePosition(layer: previousLoadingPlaceholderNode.layer, from: CGPoint(), to: CGPoint(x: -offsetMultiplier.x * layout.size.width, y: -offsetMultiplier.y * layout.size.height), removeOnCompletion: false, additive: true, completion: { [weak previousLoadingPlaceholderNode] _ in
                        previousLoadingPlaceholderNode?.removeFromSupernode()
                    })
                }
                
                if let emptyNode = self.emptyNode {
                    transition.animatePosition(layer: emptyNode.layer, from: CGPoint(x: offsetMultiplier.x * layout.size.width, y: offsetMultiplier.y * layout.size.height), to: CGPoint(), removeOnCompletion: true, additive: true)
                }
                if let previousEmptyNode {
                    transition.animatePosition(layer: previousEmptyNode.layer, from: CGPoint(), to: CGPoint(x: -offsetMultiplier.x * layout.size.width, y: -offsetMultiplier.y * layout.size.height), removeOnCompletion: false, additive: true, completion: { [weak previousEmptyNode] _ in
                        previousEmptyNode?.removeFromSupernode()
                    })
                }
            } else {
                previousHistoryNode.removeFromSupernode()
                previousMessageTransitionNode.removeFromSupernode()
                previousLoadingNode.removeFromSupernode()
                previousLoadingPlaceholderNode?.removeFromSupernode()
                previousEmptyNode?.removeFromSupernode()
            }
        } else {
            transition.updateBounds(node: self.historyNode, bounds: CGRect(origin: CGPoint(), size: contentBounds.size))
            transition.updatePosition(node: self.historyNode, position: CGPoint(x: contentBounds.size.width / 2.0, y: contentBounds.size.height / 2.0))
        }
        
        if immediatelyLayoutLeftPanelNodeAndAnimateAppearance || dismissedLeftPanel != nil || immediatelyLayoutTitleTopicsAccessoryPanelNodeAndAnimateAppearance || dismissedTitleTopicsAccessoryPanelNode != nil {
            self.historyNode.resetScrolledToItem()
        }
        
        if let blurredHistoryNode = self.blurredHistoryNode {
            transition.updateFrame(node: blurredHistoryNode, frame: contentBounds)
        }
        
        var isSelectionEnabled = true
        if previewing {
            isSelectionEnabled = false
        } else if case .pinnedMessages = self.chatPresentationInterfaceState.subject {
            isSelectionEnabled = false
        } else if self.chatPresentationInterfaceState.inputTextPanelState.mediaRecordingState != nil {
            isSelectionEnabled = false
        } else if case .customChatContents = self.chatLocation {
            isSelectionEnabled = false
        }
        self.historyNode.isSelectionGestureEnabled = isSelectionEnabled
        
        transition.updateFrame(node: self.loadingNode, frame: contentBounds)
        if let loadingPlaceholderNode = self.loadingPlaceholderNode {
            transition.updateFrame(node: loadingPlaceholderNode, frame: contentBounds)
        }
        
        if let restrictedNode = self.restrictedNode {
            transition.updateFrame(node: restrictedNode, frame: contentBounds)
            restrictedNode.update(rect: contentBounds, within: contentBounds.size, transition: transition)
            restrictedNode.updateLayout(presentationData: ChatPresentationData(theme: ChatPresentationThemeData(theme: self.chatPresentationInterfaceState.theme, wallpaper: self.chatPresentationInterfaceState.chatWallpaper), fontSize: self.chatPresentationInterfaceState.fontSize, strings: self.chatPresentationInterfaceState.strings, dateTimeFormat: self.chatPresentationInterfaceState.dateTimeFormat, nameDisplayOrder: self.chatPresentationInterfaceState.nameDisplayOrder, disableAnimations: false, largeEmoji: false, chatBubbleCorners: PresentationChatBubbleCorners(mainRadius: 0.0, auxiliaryRadius: 0.0, mergeBubbleCorners: false)), backgroundNode: self.backgroundNode, size: contentBounds.size, transition: transition)
        }
        
        let (duration, curve) = listViewAnimationDurationAndCurve(transition: transition)
        
        var immediatelyLayoutInputContextPanelAndAnimateAppearance = false
        if let inputContextPanelNode = inputContextPanelForChatPresentationIntefaceState(self.chatPresentationInterfaceState, context: self.context, currentPanel: self.inputContextPanelNode, controllerInteraction: self.controllerInteraction, interfaceInteraction: self.interfaceInteraction, chatPresentationContext: self.controllerInteraction.presentationContext) {
            if inputContextPanelNode !== self.inputContextPanelNode {
                dismissedInputContextPanelNode = self.inputContextPanelNode
                self.inputContextPanelNode = inputContextPanelNode
                switch inputContextPanelNode.placement {
                case .overPanels:
                    self.inputContextPanelContainer.addSubnode(inputContextPanelNode)
                case .overTextInput:
                    inputContextPanelNode.view.disablesInteractiveKeyboardGestureRecognizer = true
                    self.inputContextOverTextPanelContainer.addSubnode(inputContextPanelNode)
                }
                immediatelyLayoutInputContextPanelAndAnimateAppearance = true
            }
        } else if let inputContextPanelNode = self.inputContextPanelNode {
            dismissedInputContextPanelNode = inputContextPanelNode
            self.inputContextPanelNode = nil
        }
        
        var immediatelyLayoutOverlayContextPanelAndAnimateAppearance = false
        if let overlayContextPanelNode = chatOverlayContextPanelForChatPresentationIntefaceState(self.chatPresentationInterfaceState, context: self.context, currentPanel: self.overlayContextPanelNode, interfaceInteraction: self.interfaceInteraction, chatPresentationContext: self.controllerInteraction.presentationContext) {
            if overlayContextPanelNode !== self.overlayContextPanelNode {
                dismissedOverlayContextPanelNode = self.overlayContextPanelNode
                self.overlayContextPanelNode = overlayContextPanelNode
                
                self.contentContainerNode.contentNode.addSubnode(overlayContextPanelNode)
                immediatelyLayoutOverlayContextPanelAndAnimateAppearance = true
            }
        } else if let overlayContextPanelNode = self.overlayContextPanelNode {
            dismissedOverlayContextPanelNode = overlayContextPanelNode
            self.overlayContextPanelNode = nil
        }
        
        var inputPanelsHeight: CGFloat = 0.0
        
        var inputPanelFrame: CGRect?
        var secondaryInputPanelFrame: CGRect?
        
        var inputPanelHideOffset: CGFloat = 0.0
        if let inputNode = self.inputNode, inputNode.hideInput {
            if let inputPanelSize = inputPanelSize {
                inputPanelHideOffset += -inputPanelSize.height
            }
            if let accessoryPanelSize = accessoryPanelSize {
                inputPanelHideOffset += -accessoryPanelSize.height
            }
        }
        
        if self.inputPanelNode != nil {
            inputPanelFrame = CGRect(origin: CGPoint(x: 0.0, y: layout.size.height - insets.bottom - bottomOverflowOffset - inputPanelsHeight - inputPanelSize!.height), size: CGSize(width: layout.size.width, height: inputPanelSize!.height))
            inputPanelFrame = inputPanelFrame!.offsetBy(dx: 0.0, dy: inputPanelHideOffset)
            if self.dismissedAsOverlay {
                inputPanelFrame!.origin.y = layout.size.height
            }
            if let inputNode = self.inputNode, inputNode.hideInput, !inputNode.adjustLayoutForHiddenInput {
                inputPanelsHeight += inputPanelNodeBaseHeight
            } else {
                inputPanelsHeight += inputPanelSize!.height
            }
        }
        
        if self.secondaryInputPanelNode != nil {
            secondaryInputPanelFrame = CGRect(origin: CGPoint(x: 0.0, y: layout.size.height - insets.bottom - bottomOverflowOffset - inputPanelsHeight - secondaryInputPanelSize!.height), size: CGSize(width: layout.size.width, height: secondaryInputPanelSize!.height))
            if self.dismissedAsOverlay {
                secondaryInputPanelFrame!.origin.y = layout.size.height
            }
            inputPanelsHeight += secondaryInputPanelSize!.height
        }
        
        var accessoryPanelFrame: CGRect?
        if self.accessoryPanelNode != nil {
            assert(accessoryPanelSize != nil)
            accessoryPanelFrame = CGRect(origin: CGPoint(x: 0.0, y: layout.size.height - bottomOverflowOffset - insets.bottom - inputPanelsHeight - accessoryPanelSize!.height), size: CGSize(width: layout.size.width, height: accessoryPanelSize!.height))
            accessoryPanelFrame = accessoryPanelFrame!.offsetBy(dx: 0.0, dy: inputPanelHideOffset)
            if self.dismissedAsOverlay {
                accessoryPanelFrame!.origin.y = layout.size.height
            }
            if let inputNode = self.inputNode, inputNode.hideInput {
            } else {
                inputPanelsHeight += accessoryPanelSize!.height
            }
        }
        
        if self.dismissedAsOverlay {
            inputPanelsHeight = 0.0
        }
        
        if let inputNode = self.inputNode {
            if inputNode.hideInput && inputNode.adjustLayoutForHiddenInput {
                inputPanelsHeight = 0.0
            }
        }
        
        let inputBackgroundInset: CGFloat
        if cleanInsets.bottom < insets.bottom {
            if case .regular = layout.metrics.widthClass, insets.bottom < 88.0 {
                inputBackgroundInset = insets.bottom
            } else {
                inputBackgroundInset = 0.0
            }
        } else {
            inputBackgroundInset = cleanInsets.bottom
        }
        
        var inputBackgroundFrame = CGRect(origin: CGPoint(x: 0.0, y: layout.size.height - insets.bottom - bottomOverflowOffset - inputPanelsHeight), size: CGSize(width: layout.size.width, height: inputPanelsHeight + inputBackgroundInset))
        if self.dismissedAsOverlay {
            inputBackgroundFrame.origin.y = layout.size.height
        }
        if case .standard(.embedded) = self.chatPresentationInterfaceState.mode {
            if self.inputPanelNode == nil {
                inputBackgroundFrame.origin.y = layout.size.height
            }
        }
        
        let additionalScrollDistance: CGFloat = 0.0
        var scrollToTop = false
        if dismissedInputByDragging {
            if !self.historyNode.trackingOffset.isZero {
                if self.historyNode.beganTrackingAtTopOrigin {
                    scrollToTop = true
                }
            }
        }
        
        var contentBottomInset: CGFloat = inputPanelsHeight + 4.0
        
        if let scrollContainerNode = self.scrollContainerNode {
            transition.updateFrame(node: scrollContainerNode, frame: CGRect(origin: CGPoint(), size: layout.size))
        }
        
        var containerInsets = insets
        if let dismissAsOverlayLayout = self.dismissAsOverlayLayout {
            if let inputNodeHeightAndOverflow = inputNodeHeightAndOverflow {
                containerInsets = dismissAsOverlayLayout.insets(options: [])
                containerInsets.bottom = max(inputNodeHeightAndOverflow.0 + inputNodeHeightAndOverflow.1, insets.bottom)
            } else {
                containerInsets = dismissAsOverlayLayout.insets(options: [.input])
            }
        }
        
        let visibleAreaInset = UIEdgeInsets(top: containerInsets.top, left: 0.0, bottom: containerInsets.bottom + inputPanelsHeight, right: 0.0)
        self.visibleAreaInset = visibleAreaInset
        
        var loadingNodeInsets = visibleAreaInset
        loadingNodeInsets.left = layout.safeInsets.left
        loadingNodeInsets.right = layout.safeInsets.right
        if let leftPanelSize {
            loadingNodeInsets.left += leftPanelSize.width
        }
        self.loadingNode.updateLayout(size: contentBounds.size, insets: loadingNodeInsets, transition: transition)
        
        if let loadingPlaceholderNode = self.loadingPlaceholderNode {
            loadingPlaceholderNode.updateLayout(size: contentBounds.size, insets: loadingNodeInsets, metrics: layout.metrics, transition: transition)
            loadingPlaceholderNode.update(rect: contentBounds, within: contentBounds.size, transition: transition)
        }
        
        if let containerNode = self.containerNode {
            contentBottomInset += 8.0
            let containerNodeFrame = CGRect(origin: CGPoint(x: wrappingInsets.left, y: wrappingInsets.top), size: CGSize(width: contentBounds.size.width, height: contentBounds.size.height - containerInsets.bottom - inputPanelsHeight - 8.0))
            transition.updateFrame(node: containerNode, frame: containerNodeFrame)
            
            if let containerBackgroundNode = self.containerBackgroundNode {
                transition.updateFrame(node: containerBackgroundNode, frame: CGRect(origin: CGPoint(x: containerNodeFrame.minX - 8.0 * 2.0, y: containerNodeFrame.minY - 8.0 * 2.0), size: CGSize(width: containerNodeFrame.size.width + 8.0 * 4.0, height: containerNodeFrame.size.height + 8.0 * 2.0 + 20.0)))
            }
        }
        
        if let overlayNavigationBar = self.overlayNavigationBar {
            let barFrame = CGRect(origin: CGPoint(), size: CGSize(width: contentBounds.size.width, height: 44.0))
            transition.updateFrame(node: overlayNavigationBar, frame: barFrame)
            overlayNavigationBar.updateLayout(size: barFrame.size, transition: transition)
        }
        
        var listInsets = UIEdgeInsets(top: containerInsets.bottom + contentBottomInset, left: containerInsets.right, bottom: containerInsets.top + 6.0, right: containerInsets.left)
        let listScrollIndicatorInsets = UIEdgeInsets(top: containerInsets.bottom + inputPanelsHeight, left: containerInsets.right, bottom: containerInsets.top, right: containerInsets.left)
        
        var childContentInsets: UIEdgeInsets = containerInsets
        childContentInsets.bottom += inputPanelsHeight
        
        if case .standard = self.chatPresentationInterfaceState.mode {
            listInsets.left += layout.safeInsets.left
            listInsets.right += layout.safeInsets.right
            
            childContentInsets.left += layout.safeInsets.left
            childContentInsets.right += layout.safeInsets.right
            
            if case .regular = layout.metrics.widthClass, case .regular = layout.metrics.heightClass {
                listInsets.left += 6.0
                listInsets.right += 6.0
                listInsets.top += 6.0
            }
        }
        
        if !self.historyNode.rotated {
            let current = listInsets
            listInsets.top = current.bottom
            listInsets.bottom = current.top
            listInsets.top += 8.0
        }
        
        if let leftPanelSize {
            listInsets.left += leftPanelSize.width
        }
        
        var emptyNodeInsets = insets
        emptyNodeInsets.bottom += inputPanelsHeight
        self.validEmptyNodeLayout = (contentBounds.size, emptyNodeInsets, listInsets.left, listInsets.right)
        if let emptyNode = self.emptyNode, let emptyType = self.emptyType {
            let mappedType: ChatEmptyNode.Subject.EmptyType
            switch emptyType {
            case .generic:
                mappedType = .generic
            case .joined:
                mappedType = .joined
            case .clearedHistory:
                mappedType = .clearedHistory
            case .topic:
                mappedType = .topic
            case .botInfo:
                mappedType = .botInfo
            }
            emptyNode.updateLayout(interfaceState: self.chatPresentationInterfaceState, subject: .emptyChat(mappedType), loadingNode: nil, backgroundNode: self.backgroundNode, size: contentBounds.size, insets: emptyNodeInsets, leftInset: listInsets.left, rightInset: listInsets.right, transition: transition)
            transition.updateFrame(node: emptyNode, frame: contentBounds)
            emptyNode.update(rect: contentBounds, within: contentBounds.size, transition: transition)
        }
        
        var displayTopDimNode = false
        let ensureTopInsetForOverlayHighlightedItems: CGFloat? = nil
        var expandTopDimNode = false
        if case let .media(_, expanded, _) = self.chatPresentationInterfaceState.inputMode, expanded != nil {
            displayTopDimNode = true
            expandTopDimNode = true
        }
        
        if displayTopDimNode {
            var topInset = listInsets.bottom + UIScreenPixel
            if let titleAccessoryPanelHeight = titleAccessoryPanelHeight {
                if expandTopDimNode {
                    topInset -= titleAccessoryPanelHeight
                } else {
                    topInset -= UIScreenPixel
                }
            }
            
            let inputPanelOrigin = layout.size.height - insets.bottom - bottomOverflowOffset - inputPanelsHeight
            
            if expandTopDimNode {
                let exandedFrame = CGRect(origin: CGPoint(x: 0.0, y: inputPanelOrigin - layout.size.height), size: CGSize(width: layout.size.width, height: layout.size.height))
                let expandedInputDimNode: ASDisplayNode
                if let current = self.expandedInputDimNode {
                    expandedInputDimNode = current
                    transition.updateFrame(node: expandedInputDimNode, frame: exandedFrame)
                } else {
                    expandedInputDimNode = ASDisplayNode()
                    expandedInputDimNode.backgroundColor = UIColor(white: 0.0, alpha: 0.5)
                    expandedInputDimNode.alpha = 0.0
                    self.expandedInputDimNode = expandedInputDimNode
                    self.contentContainerNode.contentNode.insertSubnode(expandedInputDimNode, aboveSubnode: self.historyNodeContainer)
                    transition.updateAlpha(node: expandedInputDimNode, alpha: 1.0)
                    expandedInputDimNode.frame = exandedFrame
                    transition.animatePositionAdditive(node: expandedInputDimNode, offset: CGPoint(x: 0.0, y: previousInputPanelOrigin.y - inputPanelOrigin))
                }
            } else {
                if let expandedInputDimNode = self.expandedInputDimNode {
                    self.expandedInputDimNode = nil
                    transition.animatePositionAdditive(node: expandedInputDimNode, offset: CGPoint(x: 0.0, y: previousInputPanelOrigin.y - inputPanelOrigin))
                    transition.updateAlpha(node: expandedInputDimNode, alpha: 0.0, completion: { [weak expandedInputDimNode] _ in
                        expandedInputDimNode?.removeFromSupernode()
                    })
                }
            }
        } else {
            if let expandedInputDimNode = self.expandedInputDimNode {
                self.expandedInputDimNode = nil
                let inputPanelOrigin = layout.size.height - insets.bottom - bottomOverflowOffset - inputPanelsHeight
                let exandedFrame = CGRect(origin: CGPoint(x: 0.0, y: inputPanelOrigin - layout.size.height), size: CGSize(width: layout.size.width, height: layout.size.height))
                transition.updateFrame(node: expandedInputDimNode, frame: exandedFrame)
                transition.updateAlpha(node: expandedInputDimNode, alpha: 0.0, completion: { [weak expandedInputDimNode] _ in
                    expandedInputDimNode?.removeFromSupernode()
                })
            }
        }
        
        var childrenLayout = layout
        if self.historyNode.rotated {
            childrenLayout.intrinsicInsets = UIEdgeInsets(top: listInsets.bottom, left: listInsets.right, bottom: listInsets.top, right: listInsets.left)
        } else {
            childrenLayout.intrinsicInsets = UIEdgeInsets(top: listInsets.top, left: listInsets.left, bottom: listInsets.bottom, right: listInsets.right)
        }
        self.controller?.presentationContext.containerLayoutUpdated(childrenLayout, transition: transition)
        self.controller?.galleryPresentationContext.containerLayoutUpdated(layout, transition: transition)
        
        var customListAnimationTransition: ControlledTransition?
        if case let .animated(duration, curve) = transition {
            if immediatelyLayoutLeftPanelNodeAndAnimateAppearance || dismissedLeftPanel != nil {
                customListAnimationTransition = ControlledTransition(duration: duration, curve: curve, interactive: false)
            }
        }
        
        self.currentListViewLayout = (contentBounds.size, insets: listInsets, scrollIndicatorInsets: listScrollIndicatorInsets)
        listViewTransaction(ListViewUpdateSizeAndInsets(size: contentBounds.size, insets: listInsets, scrollIndicatorInsets: listScrollIndicatorInsets, duration: duration, curve: curve, ensureTopInsetForOverlayHighlightedItems: ensureTopInsetForOverlayHighlightedItems, customAnimationTransition: customListAnimationTransition), additionalScrollDistance, scrollToTop, { [weak self] in
            if let strongSelf = self {
                strongSelf.notifyTransitionCompletionListeners(transition: transition)
            }
        })
        
        if self.isScrollingLockedAtTop {
            switch self.historyNode.visibleContentOffset() {
            case let .known(value) where value <= CGFloat.ulpOfOne:
                break
            case .none:
                break
            default:
                self.historyNode.scrollToEndOfHistory()
            }
        }
        self.historyNode.scrollEnabled = !self.isScrollingLockedAtTop
        
        let navigateButtonsSize = self.navigateButtons.updateLayout(transition: transition)
        var navigateButtonsFrame = CGRect(origin: CGPoint(x: layout.size.width - layout.safeInsets.right - navigateButtonsSize.width - 6.0, y: layout.size.height - containerInsets.bottom - inputPanelsHeight - navigateButtonsSize.height - 6.0), size: navigateButtonsSize)
        if case .overlay = self.chatPresentationInterfaceState.mode {
            navigateButtonsFrame = navigateButtonsFrame.offsetBy(dx: -8.0, dy: -8.0)
        }
        
        var apparentInputPanelFrame = inputPanelFrame
        let apparentSecondaryInputPanelFrame = secondaryInputPanelFrame
        var apparentInputBackgroundFrame = inputBackgroundFrame
        var apparentNavigateButtonsFrame = navigateButtonsFrame
        if case let .media(_, maybeExpanded, _) = self.chatPresentationInterfaceState.inputMode, let expanded = maybeExpanded, case .search = expanded, let inputPanelFrame = inputPanelFrame {
            let verticalOffset = -inputPanelFrame.height - 34.0
            apparentInputPanelFrame = inputPanelFrame.offsetBy(dx: 0.0, dy: verticalOffset)
            apparentInputBackgroundFrame.size.height -= verticalOffset
            apparentInputBackgroundFrame.origin.y += verticalOffset
            apparentNavigateButtonsFrame.origin.y += verticalOffset
        }
        
        if layout.additionalInsets.right > 0.0 {
            apparentNavigateButtonsFrame.origin.y -= 16.0
        }
        
        if !self.historyNode.rotated {
            apparentNavigateButtonsFrame = CGRect(origin: CGPoint(x: layout.size.width - layout.safeInsets.right - navigateButtonsSize.width - 6.0, y: insets.top + 6.0), size: navigateButtonsSize)
        }
        
        var isInputExpansionEnabled = false
        if case .media = self.chatPresentationInterfaceState.inputMode {
            isInputExpansionEnabled = true
        }
        
        let previousInputPanelBackgroundFrame = self.inputPanelBackgroundNode.frame
        transition.updateFrame(node: self.inputPanelContainerNode, frame: CGRect(origin: CGPoint(), size: layout.size))
        self.inputPanelContainerNode.update(size: layout.size, scrollableDistance: max(0.0, maximumInputNodeHeight - layout.standardInputHeight), isExpansionEnabled: isInputExpansionEnabled, transition: transition)
        transition.updatePosition(node: self.inputPanelClippingNode, position: CGRect(origin: apparentInputBackgroundFrame.origin, size: layout.size).center, beginWithCurrentState: true)
        transition.updateBounds(node: self.inputPanelClippingNode, bounds: CGRect(origin: CGPoint(x: 0.0, y: apparentInputBackgroundFrame.origin.y), size: layout.size), beginWithCurrentState: true)
        transition.updatePosition(node: self.inputPanelOverlayNode, position: CGRect(origin: apparentInputBackgroundFrame.origin, size: layout.size).center, beginWithCurrentState: true)
        transition.updateBounds(node: self.inputPanelOverlayNode, bounds: CGRect(origin: CGPoint(x: 0.0, y: apparentInputBackgroundFrame.origin.y), size: layout.size), beginWithCurrentState: true)
        transition.updateFrame(node: self.inputPanelBackgroundNode, frame: apparentInputBackgroundFrame, beginWithCurrentState: true)
        
        let leftPanelContainerFrame = CGRect(origin: CGPoint(x: 0.0, y: 0.0), size: CGSize(width: 0.0, height: layout.size.height))
        transition.updateFrame(node: self.leftPanelContainer, frame: leftPanelContainerFrame)
        if let leftPanel = self.leftPanel, let leftPanelSize {
            let leftPanelSize = leftPanel.view.update(
                transition: immediatelyLayoutLeftPanelNodeAndAnimateAppearance ? .immediate :ComponentTransition(transition),
                component: leftPanel.component.component,
                environment: {
                    ChatSidePanelEnvironment(insets: UIEdgeInsets(
                        top: 0.0,
                        left: leftPanelLeftInset,
                        bottom: 0.0,
                        right: 0.0
                    ))
                },
                containerSize: CGSize(width: leftPanelSize.width, height: leftPanelSize.height - sidePanelTopInset - (containerInsets.bottom + inputPanelsHeight))
            )
            
            let leftPanelFrame = CGRect(origin: CGPoint(x: 0.0, y: sidePanelTopInset), size: leftPanelSize)
            if let leftPanelView = leftPanel.view.view {
                if leftPanelView.superview == nil {
                    self.leftPanelContainer.view.addSubview(leftPanelView)
                }
                if immediatelyLayoutLeftPanelNodeAndAnimateAppearance {
                    leftPanelView.frame = leftPanelFrame.offsetBy(dx: -leftPanelSize.width, dy: 0.0)
                    
                    if self.titleTopicsAccessoryPanelNode != nil || dismissedTitleTopicsAccessoryPanelNode != nil {
                        if let leftPanelView = leftPanelView as? ChatSideTopicsPanel.View {
                            leftPanelView.updateGlobalOffset(globalOffset: -leftPanelSize.width, transition: ComponentTransition(transition))
                        }
                    }
                }
                transition.updateFrame(view: leftPanelView, frame: leftPanelFrame)
                if let leftPanelView = leftPanelView as? ChatSideTopicsPanel.View {
                    leftPanelView.updateGlobalOffset(globalOffset: 0.0, transition: ComponentTransition(transition))
                }
            }
        }
        if let dismissedLeftPanel, let dismissedLeftPanelView = dismissedLeftPanel.view.view {
            let dismissedLeftPanelSize = dismissedLeftPanel.view.update(
                transition: ComponentTransition(transition),
                component: dismissedLeftPanel.component.component,
                environment: {
                    ChatSidePanelEnvironment(insets: UIEdgeInsets(
                        top: 0.0,
                        left: leftPanelLeftInset,
                        bottom: 0.0,
                        right: 0.0
                    ))
                },
                containerSize: CGSize(width: defaultLeftPanelWidth, height: layout.size.height - sidePanelTopInset - (containerInsets.bottom + inputPanelsHeight))
            )
            transition.updateFrame(view: dismissedLeftPanelView, frame: CGRect(origin: CGPoint(x: -dismissedLeftPanelSize.width, y: sidePanelTopInset), size: dismissedLeftPanelSize), completion: { [weak dismissedLeftPanelView] _ in
                dismissedLeftPanelView?.removeFromSuperview()
            })
            if let dismissedLeftPanelView = dismissedLeftPanelView as? ChatSideTopicsPanel.View {
                if self.titleTopicsAccessoryPanelNode != nil {
                    dismissedLeftPanelView.updateGlobalOffset(globalOffset: -dismissedLeftPanelSize.width, transition: ComponentTransition(transition))
                }
            }
        }

        if let navigationBarBackgroundContent = self.navigationBarBackgroundContent {
            transition.updateFrame(node: navigationBarBackgroundContent, frame: CGRect(origin: .zero, size: CGSize(width: layout.size.width, height: navigationBarHeight + (titleAccessoryPanelBackgroundHeight ?? 0.0) + (translationPanelHeight ?? 0.0))), beginWithCurrentState: true)
            navigationBarBackgroundContent.update(rect: CGRect(origin: .zero, size: CGSize(width: layout.size.width, height: navigationBarHeight + (titleAccessoryPanelBackgroundHeight ?? 0.0) + (translationPanelHeight ?? 0.0))), within: layout.size, transition: transition)
        }
        
        if let inputPanelBackgroundContent = self.inputPanelBackgroundContent {
            var extensionValue: CGFloat = 0.0
            if let inputNode = self.inputNode {
                extensionValue = inputNode.topBackgroundExtension
            }
            let apparentInputBackgroundFrame = CGRect(origin: apparentInputBackgroundFrame.origin, size: CGSize(width: apparentInputBackgroundFrame.width, height: apparentInputBackgroundFrame.height + extensionValue))
            var transition = transition
            var delay: Double = 0.0
            if apparentInputBackgroundFrame.height > inputPanelBackgroundContent.frame.height {
                transition = .immediate
            } else if case let .animated(_, curve) = transition, case .spring = curve {
                delay = 0.3
            }
            
            transition.updateFrame(node: inputPanelBackgroundContent, frame: CGRect(origin: .zero, size: apparentInputBackgroundFrame.size), beginWithCurrentState: true, delay: delay)
            inputPanelBackgroundContent.update(rect: apparentInputBackgroundFrame, within: layout.size, delay: delay, transition: transition)
        }
        
        transition.updateFrame(node: self.contentDimNode, frame: CGRect(origin: CGPoint(x: 0.0, y: 0.0), size: CGSize(width: layout.size.width, height: apparentInputBackgroundFrame.origin.y)))
        
        let intrinsicInputPanelBackgroundNodeSize = CGSize(width: apparentInputBackgroundFrame.size.width, height: apparentInputBackgroundFrame.size.height)
        self.intrinsicInputPanelBackgroundNodeSize = intrinsicInputPanelBackgroundNodeSize
        var inputPanelBackgroundExtension: CGFloat = 0.0
        if let inputNode = self.inputNode {
            inputPanelBackgroundExtension = inputNode.topBackgroundExtension
        } else {
            inputPanelBackgroundExtension = dismissedInputNodeInputBackgroundExtension
        }
        
        var inputPanelUpdateTransition = transition
        if immediatelyLayoutInputNodeAndAnimateAppearance {
            inputPanelUpdateTransition = .immediate
        }
        
        self.inputPanelBackgroundNode.update(size: CGSize(width: intrinsicInputPanelBackgroundNodeSize.width, height: intrinsicInputPanelBackgroundNodeSize.height + inputPanelBackgroundExtension), transition: inputPanelUpdateTransition, beginWithCurrentState: true)
        self.inputPanelBottomBackgroundSeparatorBaseOffset = intrinsicInputPanelBackgroundNodeSize.height
        inputPanelUpdateTransition.updateFrame(node: self.inputPanelBottomBackgroundSeparatorNode, frame: CGRect(origin: CGPoint(x: 0.0, y: intrinsicInputPanelBackgroundNodeSize.height + inputPanelBackgroundExtension), size: CGSize(width: intrinsicInputPanelBackgroundNodeSize.width, height: UIScreenPixel)), beginWithCurrentState: true)
        
        transition.updateFrame(node: self.inputPanelBackgroundSeparatorNode, frame: CGRect(origin: CGPoint(x: 0.0, y: apparentInputBackgroundFrame.origin.y), size: CGSize(width: apparentInputBackgroundFrame.size.width, height: UIScreenPixel)))
        transition.updateFrame(node: self.navigateButtons, frame: apparentNavigateButtonsFrame)
        self.navigateButtons.update(rect: apparentNavigateButtonsFrame, within: layout.size, transition: transition)

        if let titleTopicsAccessoryPanelNode = self.titleTopicsAccessoryPanelNode, let titleTopicsAccessoryPanelFrame, (immediatelyLayoutTitleTopicsAccessoryPanelNodeAndAnimateAppearance || !titleTopicsAccessoryPanelNode.frame.equalTo(titleTopicsAccessoryPanelFrame)) {
            if immediatelyLayoutTitleTopicsAccessoryPanelNodeAndAnimateAppearance {
                titleTopicsAccessoryPanelNode.frame = titleTopicsAccessoryPanelFrame.offsetBy(dx: 0.0, dy: -titleTopicsAccessoryPanelFrame.height)
                if self.leftPanel != nil || dismissedLeftPanel != nil {
                    titleTopicsAccessoryPanelNode.updateGlobalOffset(globalOffset: -titleTopicsAccessoryPanelFrame.height, transition: .immediate)
                }
                
                ComponentTransition(transition).setFrame(view: titleTopicsAccessoryPanelNode.view, frame: titleTopicsAccessoryPanelFrame)
                titleTopicsAccessoryPanelNode.updateGlobalOffset(globalOffset: 0.0, transition: ComponentTransition(transition))
            } else {
                let previousFrame = titleTopicsAccessoryPanelNode.frame
                titleTopicsAccessoryPanelNode.frame = titleTopicsAccessoryPanelFrame
                if transition.isAnimated && previousFrame.width != titleTopicsAccessoryPanelFrame.width {
                } else {
                    transition.animatePositionAdditive(node: titleTopicsAccessoryPanelNode, offset: CGPoint(x: 0.0, y: -titleTopicsAccessoryPanelFrame.height))
                }
            }
        }
    
        if let titleAccessoryPanelNode = self.titleAccessoryPanelNode, let titleAccessoryPanelFrame, !titleAccessoryPanelNode.frame.equalTo(titleAccessoryPanelFrame) {
            let previousFrame = titleAccessoryPanelNode.frame
            titleAccessoryPanelNode.frame = titleAccessoryPanelFrame
            if transition.isAnimated && previousFrame.width != titleAccessoryPanelFrame.width {
            } else if immediatelyLayoutAccessoryPanelAndAnimateAppearance {
                transition.animatePositionAdditive(node: titleAccessoryPanelNode, offset: CGPoint(x: 0.0, y: -titleAccessoryPanelFrame.height))
            } else if previousFrame.minY != titleAccessoryPanelFrame.minY {
                transition.animatePositionAdditive(node: titleAccessoryPanelNode, offset: CGPoint(x: 0.0, y: previousFrame.minY - titleAccessoryPanelFrame.minY))
            }
        }
        
        if let chatTranslationPanel = self.chatTranslationPanel, let translationPanelFrame, !chatTranslationPanel.frame.equalTo(translationPanelFrame) {
            let previousFrame = chatTranslationPanel.frame
            chatTranslationPanel.frame = translationPanelFrame
            if transition.isAnimated && previousFrame.width != translationPanelFrame.width {
            } else if immediatelyLayoutTranslationPanelNodeAndAnimateAppearance {
                transition.animatePositionAdditive(node: chatTranslationPanel, offset: CGPoint(x: 0.0, y: -translationPanelFrame.height))
            } else if previousFrame.minY != translationPanelFrame.minY {
                transition.animatePositionAdditive(node: chatTranslationPanel, offset: CGPoint(x: 0.0, y: previousFrame.minY - translationPanelFrame.minY))
            }
        }
        
        if let chatImportStatusPanel = self.chatImportStatusPanel, let importStatusPanelFrame, !chatImportStatusPanel.frame.equalTo(importStatusPanelFrame) {
            chatImportStatusPanel.frame = importStatusPanelFrame
        }
        
        if let adPanelNode = self.adPanelNode, let adPanelFrame, !adPanelNode.frame.equalTo(adPanelFrame) {
            adPanelNode.frame = adPanelFrame
        }
        
        if let feePanelNode = self.feePanelNode, let feePanelFrame, !feePanelNode.frame.equalTo(feePanelFrame) {
            feePanelNode.frame = feePanelFrame
        }
        
        if let secondaryInputPanelNode = self.secondaryInputPanelNode, let apparentSecondaryInputPanelFrame = apparentSecondaryInputPanelFrame, !secondaryInputPanelNode.frame.equalTo(apparentSecondaryInputPanelFrame) {
            if immediatelyLayoutSecondaryInputPanelAndAnimateAppearance {
                secondaryInputPanelNode.frame = apparentSecondaryInputPanelFrame.offsetBy(dx: 0.0, dy: apparentSecondaryInputPanelFrame.height + previousInputPanelBackgroundFrame.maxY - apparentSecondaryInputPanelFrame.maxY)
                secondaryInputPanelNode.alpha = 0.0
            }
            
            transition.updateFrame(node: secondaryInputPanelNode, frame: apparentSecondaryInputPanelFrame)
            transition.updateAlpha(node: secondaryInputPanelNode, alpha: 1.0)
            
            if let viewForOverlayContent = secondaryInputPanelNode.viewForOverlayContent {
                if inputPanelNodeHandlesTransition {
                    viewForOverlayContent.frame = apparentSecondaryInputPanelFrame
                } else {
                    transition.updateFrame(view: viewForOverlayContent, frame: apparentSecondaryInputPanelFrame)
                }
            }
        }
        
        if let accessoryPanelNode = self.accessoryPanelNode, let accessoryPanelFrame = accessoryPanelFrame, !accessoryPanelNode.frame.equalTo(accessoryPanelFrame) {
            if immediatelyLayoutAccessoryPanelAndAnimateAppearance {
                var startAccessoryPanelFrame = accessoryPanelFrame
                startAccessoryPanelFrame.origin.y = previousInputPanelOrigin.y
                accessoryPanelNode.frame = startAccessoryPanelFrame
                accessoryPanelNode.alpha = 0.0
            }
            
            transition.updateFrame(node: accessoryPanelNode, frame: accessoryPanelFrame)
            transition.updateAlpha(node: accessoryPanelNode, alpha: 1.0)
        }
        
        let inputContextPanelsFrame = CGRect(origin: CGPoint(x: 0.0, y: insets.top), size: CGSize(width: layout.size.width, height: max(0.0, layout.size.height - insets.bottom - inputPanelsHeight - insets.top)))
        let inputContextPanelsOverMainPanelFrame = CGRect(origin: CGPoint(x: 0.0, y: insets.top), size: CGSize(width: layout.size.width, height: max(0.0, layout.size.height - insets.bottom - (inputPanelSize == nil ? CGFloat(0.0) : inputPanelSize!.height) - insets.top)))
        
        if let inputContextPanelNode = self.inputContextPanelNode {
            let panelFrame = inputContextPanelNode.placement == .overTextInput ? inputContextPanelsOverMainPanelFrame : inputContextPanelsFrame
            if immediatelyLayoutInputContextPanelAndAnimateAppearance {
                /*var startPanelFrame = panelFrame
                if let derivedLayoutState = self.derivedLayoutState {
                    let referenceFrame = inputContextPanelNode.placement == .overTextInput ? derivedLayoutState.inputContextPanelsOverMainPanelFrame : derivedLayoutState.inputContextPanelsFrame
                    startPanelFrame.origin.y = referenceFrame.maxY - panelFrame.height
                }*/
                inputContextPanelNode.frame = panelFrame
                inputContextPanelNode.updateLayout(size: panelFrame.size, leftInset: layout.safeInsets.left, rightInset: layout.safeInsets.right, bottomInset: 0.0, transition: .immediate, interfaceState: self.chatPresentationInterfaceState)
            }
            
            if !inputContextPanelNode.frame.equalTo(panelFrame) || inputContextPanelNode.theme !== self.chatPresentationInterfaceState.theme {
                transition.updateFrame(node: inputContextPanelNode, frame: panelFrame)
                inputContextPanelNode.updateLayout(size: panelFrame.size, leftInset: layout.safeInsets.left, rightInset: layout.safeInsets.right, bottomInset: 0.0, transition: transition, interfaceState: self.chatPresentationInterfaceState)
            }
        }
        
        if let overlayContextPanelNode = self.overlayContextPanelNode {
            let panelFrame = overlayContextPanelNode.placement == .overTextInput ? inputContextPanelsOverMainPanelFrame : inputContextPanelsFrame
            if immediatelyLayoutOverlayContextPanelAndAnimateAppearance {
                overlayContextPanelNode.frame = panelFrame
                overlayContextPanelNode.updateLayout(size: panelFrame.size, leftInset: layout.safeInsets.left, rightInset: layout.safeInsets.right, bottomInset: 0.0, transition: .immediate, interfaceState: self.chatPresentationInterfaceState)
            } else if !overlayContextPanelNode.frame.equalTo(panelFrame) {
                transition.updateFrame(node: overlayContextPanelNode, frame: panelFrame)
                overlayContextPanelNode.updateLayout(size: panelFrame.size, leftInset: layout.safeInsets.left, rightInset: layout.safeInsets.right, bottomInset: 0.0, transition: transition, interfaceState: self.chatPresentationInterfaceState)
            }
        }
        
        if let inputNode = self.inputNode, let effectiveInputNodeHeight = effectiveInputNodeHeight, let inputNodeHeightAndOverflow = inputNodeHeightAndOverflow {
            let inputNodeHeight = effectiveInputNodeHeight + inputNodeHeightAndOverflow.1
            let inputNodeFrame = CGRect(origin: CGPoint(x: 0.0, y: layout.size.height - inputNodeHeight), size: CGSize(width: layout.size.width, height: inputNodeHeight))
            if immediatelyLayoutInputNodeAndAnimateAppearance {
                var adjustedForPreviousInputHeightFrame = inputNodeFrame
                var heightDifference = inputNodeHeight - previousInputHeight
                var externalTopPanelContainerOffset: CGFloat = 0.0
                if previousInputHeight.isLessThanOrEqualTo(cleanInsets.bottom) {
                    heightDifference = inputNodeHeight - inputPanelBackgroundExtension
                    externalTopPanelContainerOffset = inputPanelBackgroundExtension
                }
                adjustedForPreviousInputHeightFrame.origin.y += heightDifference
                inputNode.frame = adjustedForPreviousInputHeightFrame
                transition.updateFrame(node: inputNode, frame: inputNodeFrame)
                
                inputNode.updateAbsoluteRect(inputNodeFrame, within: layout.size, transition: transition)
                
                if let externalTopPanelContainer = inputNode.externalTopPanelContainer {
                    externalTopPanelContainer.frame = CGRect(origin: adjustedForPreviousInputHeightFrame.offsetBy(dx: 0.0, dy:  externalTopPanelContainerOffset).origin, size: CGSize(width: adjustedForPreviousInputHeightFrame.width, height: 0.0))
                    transition.updateFrame(view: externalTopPanelContainer, frame: CGRect(origin: inputNodeFrame.origin, size: CGSize(width: inputNodeFrame.width, height: 0.0)))
                }
            } else {
                transition.updateFrame(node: inputNode, frame: inputNodeFrame)
                if let externalTopPanelContainer = inputNode.externalTopPanelContainer {
                    transition.updateFrame(view: externalTopPanelContainer, frame: CGRect(origin: inputNodeFrame.origin, size: CGSize(width: inputNodeFrame.width, height: 0.0)))
                }
            }
        }

        if let dismissedTitleTopicsAccessoryPanelNode {
            var dismissedTopPanelFrame = dismissedTitleTopicsAccessoryPanelNode.frame
            dismissedTopPanelFrame.origin.y = -dismissedTopPanelFrame.size.height
            transition.updateFrame(node: dismissedTitleTopicsAccessoryPanelNode, frame: dismissedTopPanelFrame, completion: { [weak dismissedTitleTopicsAccessoryPanelNode] _ in
                dismissedTitleTopicsAccessoryPanelNode?.removeFromSupernode()
            })
            if self.leftPanel != nil {
                dismissedTitleTopicsAccessoryPanelNode.updateGlobalOffset(globalOffset: -dismissedTopPanelFrame.height, transition: ComponentTransition(transition))
            }
        }
        
        if let dismissedTitleAccessoryPanelNode {
            var dismissedPanelFrame = dismissedTitleAccessoryPanelNode.frame
            transition.updateSublayerTransformOffset(layer: dismissedTitleAccessoryPanelNode.layer, offset: CGPoint(x: 0.0, y: -dismissedPanelFrame.height))
            dismissedPanelFrame.origin.y = titleAccessoryPanelBaseY
            dismissedTitleAccessoryPanelNode.clipsToBounds = true
            dismissedPanelFrame.size.height = 0.0
            if transition.isAnimated {
                dismissedTitleAccessoryPanelNode.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.2, removeOnCompletion: false)
            }
            transition.updateFrame(node: dismissedTitleAccessoryPanelNode, frame: dismissedPanelFrame, completion: { [weak dismissedTitleAccessoryPanelNode] _ in
                dismissedTitleAccessoryPanelNode?.removeFromSupernode()
            })
        }
        
        if let dismissedTranslationPanelNode {
            var dismissedPanelFrame = dismissedTranslationPanelNode.frame
            dismissedPanelFrame.origin.y = -dismissedPanelFrame.size.height
            transition.updateAlpha(node: dismissedTranslationPanelNode, alpha: 0.0, completion: { [weak dismissedTranslationPanelNode] _ in
                dismissedTranslationPanelNode?.removeFromSupernode()
            })
            dismissedTranslationPanelNode.animateOut()
        }
        
        if let dismissedImportStatusPanelNode {
            var dismissedPanelFrame = dismissedImportStatusPanelNode.frame
            dismissedPanelFrame.origin.y = -dismissedPanelFrame.size.height
            transition.updateFrame(node: dismissedImportStatusPanelNode, frame: dismissedPanelFrame, completion: { [weak dismissedImportStatusPanelNode] _ in
                dismissedImportStatusPanelNode?.removeFromSupernode()
            })
        }
        
        if let dismissedAdPanelNode {
            var dismissedPanelFrame = dismissedAdPanelNode.frame
            dismissedPanelFrame.origin.y = -dismissedPanelFrame.size.height
            transition.updateAlpha(node: dismissedAdPanelNode, alpha: 0.0)
            transition.updateFrame(node: dismissedAdPanelNode, frame: dismissedPanelFrame, completion: { [weak dismissedAdPanelNode] _ in
                dismissedAdPanelNode?.removeFromSupernode()
            })
        }
        
        if let dismissedFeePanelNode {
            var dismissedPanelFrame = dismissedFeePanelNode.frame
            dismissedPanelFrame.origin.y = -dismissedPanelFrame.size.height
            transition.updateAlpha(node: dismissedFeePanelNode, alpha: 0.0)
            transition.updateFrame(node: dismissedFeePanelNode, frame: dismissedPanelFrame, completion: { [weak dismissedFeePanelNode] _ in
                dismissedFeePanelNode?.removeFromSupernode()
            })
        }
        
        if let inputPanelNode = self.inputPanelNode, let apparentInputPanelFrame = apparentInputPanelFrame, !inputPanelNode.frame.equalTo(apparentInputPanelFrame) {
            if immediatelyLayoutInputPanelAndAnimateAppearance {
                inputPanelNode.frame = apparentInputPanelFrame.offsetBy(dx: 0.0, dy: apparentInputPanelFrame.height + previousInputPanelBackgroundFrame.maxY - apparentInputBackgroundFrame.maxY)
                inputPanelNode.alpha = 0.0
            }
            if !transition.isAnimated {
                inputPanelNode.layer.removeAllAnimations()
                if let currentDismissedInputPanelNode = self.currentDismissedInputPanelNode, inputPanelNode is ChatSearchInputPanelNode {
                    currentDismissedInputPanelNode.layer.removeAllAnimations()
                }
            }
            if inputPanelNodeHandlesTransition {
                inputPanelNode.frame = apparentInputPanelFrame
                inputPanelNode.alpha = 1.0
                inputPanelNode.updateAbsoluteRect(apparentInputPanelFrame, within: layout.size, transition: .immediate)
            } else {
                transition.updateFrame(node: inputPanelNode, frame: apparentInputPanelFrame)
                transition.updateAlpha(node: inputPanelNode, alpha: 1.0)
                inputPanelNode.updateAbsoluteRect(apparentInputPanelFrame, within: layout.size, transition: transition)
            }
            
            if let viewForOverlayContent = inputPanelNode.viewForOverlayContent {
                if inputPanelNodeHandlesTransition {
                    viewForOverlayContent.frame = apparentInputPanelFrame
                } else {
                    transition.updateFrame(view: viewForOverlayContent, frame: apparentInputPanelFrame)
                }
            }
        }
        
        if let dismissedInputPanelNode = dismissedInputPanelNode, dismissedInputPanelNode !== self.secondaryInputPanelNode {
            var frameCompleted = false
            var alphaCompleted = false
            self.currentDismissedInputPanelNode = dismissedInputPanelNode
            let completed = { [weak self, weak dismissedInputPanelNode] in
                guard let strongSelf = self, let dismissedInputPanelNode = dismissedInputPanelNode else {
                    return
                }
                if strongSelf.currentDismissedInputPanelNode === dismissedInputPanelNode {
                    strongSelf.currentDismissedInputPanelNode = nil
                }
                if strongSelf.inputPanelNode === dismissedInputPanelNode {
                    return
                }
                if frameCompleted && alphaCompleted {
                    dismissedInputPanelNode.removeFromSupernode()
                }
            }
            let transitionTargetY = layout.size.height - insets.bottom
            transition.updateFrame(node: dismissedInputPanelNode, frame: CGRect(origin: CGPoint(x: 0.0, y: transitionTargetY), size: dismissedInputPanelNode.frame.size), completion: { _ in
                frameCompleted = true
                completed()
            })
            
            transition.updateAlpha(node: dismissedInputPanelNode, alpha: 0.0, completion: { _ in
                alphaCompleted = true
                completed()
            })
            
            dismissedInputPanelNode.viewForOverlayContent?.removeFromSuperview()
        }
        
        if let dismissedSecondaryInputPanelNode = dismissedSecondaryInputPanelNode, dismissedSecondaryInputPanelNode !== self.inputPanelNode {
            var frameCompleted = false
            var alphaCompleted = false
            let completed = { [weak self, weak dismissedSecondaryInputPanelNode] in
                if let strongSelf = self, let dismissedSecondaryInputPanelNode = dismissedSecondaryInputPanelNode, strongSelf.secondaryInputPanelNode === dismissedSecondaryInputPanelNode {
                    return
                }
                if frameCompleted && alphaCompleted {
                    dismissedSecondaryInputPanelNode?.removeFromSupernode()
                }
            }
            let transitionTargetY = layout.size.height - insets.bottom
            transition.updateFrame(node: dismissedSecondaryInputPanelNode, frame: CGRect(origin: CGPoint(x: 0.0, y: transitionTargetY), size: dismissedSecondaryInputPanelNode.frame.size), completion: { _ in
                frameCompleted = true
                completed()
            })
            
            transition.updateAlpha(node: dismissedSecondaryInputPanelNode, alpha: 0.0, completion: { _ in
                alphaCompleted = true
                completed()
            })
            
            dismissedSecondaryInputPanelNode.viewForOverlayContent?.removeFromSuperview()
        }
        
        if let dismissedAccessoryPanelNode = dismissedAccessoryPanelNode {
            var frameCompleted = false
            var alphaCompleted = false
            let completed = { [weak dismissedAccessoryPanelNode] in
                if frameCompleted && alphaCompleted {
                    dismissedAccessoryPanelNode?.removeFromSupernode()
                }
            }
            var transitionTargetY = layout.size.height - insets.bottom
            if let inputPanelFrame = inputPanelFrame {
                transitionTargetY = inputPanelFrame.minY
            }

            dismissedAccessoryPanelNode.animateOut()
            dismissedAccessoryPanelNode.originalFrameBeforeDismissed = dismissedAccessoryPanelNode.frame

            transition.updateFrame(node: dismissedAccessoryPanelNode, frame: CGRect(origin: CGPoint(x: 0.0, y: transitionTargetY), size: dismissedAccessoryPanelNode.frame.size), completion: { _ in
                frameCompleted = true
                completed()
            })
            
            transition.updateAlpha(node: dismissedAccessoryPanelNode, alpha: 0.0, completion: { _ in
                alphaCompleted = true
                completed()
            })
        }
        
        if let dismissedInputContextPanelNode = dismissedInputContextPanelNode {
            var frameCompleted = false
            var animationCompleted = false
            let completed = { [weak dismissedInputContextPanelNode] in
                if let dismissedInputContextPanelNode = dismissedInputContextPanelNode, frameCompleted, animationCompleted {
                    dismissedInputContextPanelNode.removeFromSupernode()
                }
            }
            let panelFrame = dismissedInputContextPanelNode.placement == .overTextInput ? inputContextPanelsOverMainPanelFrame : inputContextPanelsFrame
            if !dismissedInputContextPanelNode.frame.equalTo(panelFrame) {
                dismissedInputContextPanelNode.updateLayout(size: panelFrame.size, leftInset: layout.safeInsets.left, rightInset: layout.safeInsets.right, bottomInset: 0.0, transition: transition, interfaceState: self.chatPresentationInterfaceState)
                transition.updateFrame(node: dismissedInputContextPanelNode, frame: panelFrame, completion: { _ in
                    frameCompleted = true
                    completed()
                })
            } else {
                frameCompleted = true
            }
            
            dismissedInputContextPanelNode.animateOut(completion: {
                animationCompleted = true
                completed()
            })
        }
        
        if let dismissedOverlayContextPanelNode = dismissedOverlayContextPanelNode {
            var frameCompleted = false
            var animationCompleted = false
            let completed = { [weak dismissedOverlayContextPanelNode] in
                if let dismissedOverlayContextPanelNode = dismissedOverlayContextPanelNode, frameCompleted, animationCompleted {
                    dismissedOverlayContextPanelNode.removeFromSupernode()
                }
            }
            let panelFrame = inputContextPanelsFrame
            if false && !dismissedOverlayContextPanelNode.frame.equalTo(panelFrame) {
                transition.updateFrame(node: dismissedOverlayContextPanelNode, frame: panelFrame, completion: { _ in
                    frameCompleted = true
                    completed()
                })
            } else {
                frameCompleted = true
            }
            
            dismissedOverlayContextPanelNode.animateOut(completion: {
                animationCompleted = true
                completed()
            })
        }
        
        if let disappearingNode = self.disappearingNode {
            let targetY: CGFloat
            if cleanInsets.bottom.isLess(than: insets.bottom) {
                targetY = layout.size.height - insets.bottom
            } else {
                targetY = layout.size.height
            }
            transition.updateFrame(node: disappearingNode, frame: CGRect(origin: CGPoint(x: 0.0, y: targetY), size: CGSize(width: layout.size.width, height: max(insets.bottom, disappearingNode.bounds.size.height))))
        }
        if let dismissedInputNode = dismissedInputNode {
            self.disappearingNode = dismissedInputNode
            let targetY: CGFloat
            if cleanInsets.bottom.isLess(than: insets.bottom) {
                targetY = layout.size.height - insets.bottom
            } else {
                targetY = layout.size.height
            }
            
            if let dismissedInputNodeExternalTopPanelContainer = dismissedInputNodeExternalTopPanelContainer {
                transition.updateFrame(view: dismissedInputNodeExternalTopPanelContainer, frame: CGRect(origin: CGPoint(x: 0.0, y: targetY), size: CGSize(width: layout.size.width, height: 0.0)), force: true, completion: { [weak self, weak dismissedInputNodeExternalTopPanelContainer] completed in
                    if let strongSelf = self, let dismissedInputNodeExternalTopPanelContainer = dismissedInputNodeExternalTopPanelContainer {
                        if strongSelf.inputNode?.externalTopPanelContainer !== dismissedInputNodeExternalTopPanelContainer {
                            dismissedInputNodeExternalTopPanelContainer.alpha = 0.0
                            dismissedInputNodeExternalTopPanelContainer.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.2, completion: { [weak dismissedInputNodeExternalTopPanelContainer] completed in
                                if completed, let strongSelf = self, let dismissedInputNodeExternalTopPanelContainer = dismissedInputNodeExternalTopPanelContainer {
                                    if strongSelf.inputNode?.externalTopPanelContainer !== dismissedInputNodeExternalTopPanelContainer {
                                        dismissedInputNodeExternalTopPanelContainer.removeFromSuperview()
                                    }
                                }
                            })
                        }
                    }
                })
            }
            
            transition.updateFrame(node: dismissedInputNode, frame: CGRect(origin: CGPoint(x: 0.0, y: targetY), size: CGSize(width: layout.size.width, height: max(insets.bottom, dismissedInputNode.bounds.size.height))), force: true, completion: { [weak self, weak dismissedInputNode] completed in
                if let dismissedInputNode = dismissedInputNode {
                    if let strongSelf = self {
                        if strongSelf.disappearingNode === dismissedInputNode {
                            strongSelf.disappearingNode = nil
                        }
                        if strongSelf.inputNode !== dismissedInputNode {
                            dismissedInputNode.alpha = 0.0
                            dismissedInputNode.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.2, completion: { [weak dismissedInputNode] completed in
                                if completed, let strongSelf = self, let dismissedInputNode = dismissedInputNode {
                                    if strongSelf.inputNode !== dismissedInputNode {
                                        dismissedInputNode.removeFromSupernode()
                                    }
                                }
                            })
                        }
                    } else {
                        dismissedInputNode.removeFromSupernode()
                    }
                }
            })
        }
        
        if let dismissAsOverlayCompletion = self.dismissAsOverlayCompletion {
            self.dismissAsOverlayCompletion = nil
            transition.updateBounds(node: self.navigateButtons, bounds: self.navigateButtons.bounds, force: true, completion: { _ in
                dismissAsOverlayCompletion()
            })
        }
        
        if let scheduledAnimateInAsOverlayFromNode = self.scheduledAnimateInAsOverlayFromNode {
            self.scheduledAnimateInAsOverlayFromNode = nil
            self.bounds = CGRect(origin: CGPoint(), size: self.bounds.size)
            let animatedTransition: ContainedViewLayoutTransition
            if case .animated = protoTransition {
                animatedTransition = protoTransition
            } else {
                animatedTransition = .animated(duration: 0.4, curve: .spring)
            }
            self.performAnimateInAsOverlay(from: scheduledAnimateInAsOverlayFromNode, transition: animatedTransition)
        }
        
        self.updatePlainInputSeparator(transition: transition)
        
        var displayInlineSearch = false
        if self.chatPresentationInterfaceState.displayHistoryFilterAsList {
            if self.chatPresentationInterfaceState.historyFilter != nil || self.chatPresentationInterfaceState.search?.resultsState != nil {
                displayInlineSearch = true
            }
            if self.alwaysShowSearchResultsAsList {
                displayInlineSearch = true
            }
            if case .peer(self.context.account.peerId) = self.chatPresentationInterfaceState.chatLocation {
                displayInlineSearch = true
            }
        }
        if self.chatLocation.threadId == nil, let channel = self.chatPresentationInterfaceState.renderedPeer?.peer as? TelegramChannel, channel.isMonoForum, let linkedMonoforumId = channel.linkedMonoforumId, let mainChannel = self.chatPresentationInterfaceState.renderedPeer?.peers[linkedMonoforumId] as? TelegramChannel, mainChannel.hasPermission(.sendSomething) {
            if self.chatPresentationInterfaceState.search != nil {
                displayInlineSearch = true
            }
        }
        
        var showNavigateButtons = true
        if let _ = chatPresentationInterfaceState.inputTextPanelState.mediaRecordingState {
            showNavigateButtons = false
        }
        if chatPresentationInterfaceState.displayHistoryFilterAsList {
            showNavigateButtons = false
        }
        
        if displayInlineSearch {
            let peerId = self.chatPresentationInterfaceState.chatLocation.peerId
            
            let inlineSearchResults: ComponentView<Empty>
            var inlineSearchResultsTransition = ComponentTransition(transition)
            if let current = self.inlineSearchResults {
                inlineSearchResults = current
            } else {
                inlineSearchResultsTransition = inlineSearchResultsTransition.withAnimation(.none)
                inlineSearchResults = ComponentView()
                self.inlineSearchResults = inlineSearchResults
            }
            
            let mappedContents: ChatInlineSearchResultsListComponent.Contents
            if let _ = self.chatPresentationInterfaceState.search?.resultsState {
                mappedContents = .search(query: self.chatPresentationInterfaceState.search?.query ?? "", includeSavedPeers: self.alwaysShowSearchResultsAsList && self.includeSavedPeersInSearchResults)
            } else if let historyFilter = self.chatPresentationInterfaceState.historyFilter {
                mappedContents = .tag(historyFilter.customTag)
            } else if let search = self.chatPresentationInterfaceState.search, self.alwaysShowSearchResultsAsList {
                if !search.query.isEmpty {
                    mappedContents = .search(query: search.query, includeSavedPeers: self.alwaysShowSearchResultsAsList && self.includeSavedPeersInSearchResults)
                } else {
                    mappedContents = .empty
                }
            } else if self.chatLocation.threadId == nil, let channel = self.chatPresentationInterfaceState.renderedPeer?.peer as? TelegramChannel, channel.isMonoForum, let linkedMonoforumId = channel.linkedMonoforumId, let mainChannel = self.chatPresentationInterfaceState.renderedPeer?.peers[linkedMonoforumId] as? TelegramChannel, mainChannel.hasPermission(.sendSomething) {
                mappedContents = .monoforumChats(query: self.chatPresentationInterfaceState.search?.query ?? "")
            } else if case .peer(self.context.account.peerId) = self.chatPresentationInterfaceState.chatLocation {
                mappedContents = .tag(MemoryBuffer())
            } else {
                mappedContents = .empty
            }
            
            if case .empty = mappedContents {
            } else {
                showNavigateButtons = false
            }
            
            let context = self.context
            let chatLocation = self.chatLocation
            
            let _ = inlineSearchResults.update(
                transition: inlineSearchResultsTransition,
                component: AnyComponent(ChatInlineSearchResultsListComponent(
                    context: self.context,
                    presentation: ChatInlineSearchResultsListComponent.Presentation(
                        theme: self.chatPresentationInterfaceState.theme,
                        strings: self.chatPresentationInterfaceState.strings,
                        chatListFontSize: self.chatPresentationInterfaceState.fontSize,
                        dateTimeFormat: self.chatPresentationInterfaceState.dateTimeFormat,
                        nameSortOrder: self.chatPresentationInterfaceState.nameDisplayOrder,
                        nameDisplayOrder: self.chatPresentationInterfaceState.nameDisplayOrder
                    ),
                    peerId: peerId,
                    contents: mappedContents,
                    insets: childContentInsets,
                    inputHeight: layout.inputHeight ?? 0.0,
                    showEmptyResults: self.showListEmptyResults,
                    messageSelected: { [weak self] message in
                        guard let self else {
                            return
                        }
                        
                        if case let .customChatContents(contents) = self.chatPresentationInterfaceState.subject, case .hashTagSearch = contents.kind {
                            self.controller?.navigateToMessage(
                                from: message.id,
                                to: .index(message.index),
                                scrollPosition: .center(.bottom),
                                rememberInStack: false,
                                forceInCurrentChat: false,
                                forceNew: true,
                                animated: true
                            )
                        } else if let historyFilter = self.chatPresentationInterfaceState.historyFilter, let reaction = ReactionsMessageAttribute.reactionFromMessageTag(tag: historyFilter.customTag), let peerId = self.chatLocation.peerId, historyFilter.isActive {
                            let _ = (self.context.engine.messages.searchMessages(
                                location: .peer(peerId: peerId, fromId: nil, tags: nil, reactions: [reaction], threadId: self.chatLocation.threadId, minDate: nil, maxDate: nil),
                                query: "",
                                state: nil,
                                centerId: message.id
                            )
                            |> take(1)
                            |> deliverOnMainQueue).startStandalone(next: { [weak self] results, searchState in
                                guard let self else {
                                    return
                                }
                                
                                let messageIndices = results.messages.map({ $0.index }).sorted()
                                var currentIndex = messageIndices.last
                                for index in messageIndices {
                                    if index.id >= message.id {
                                        currentIndex = index
                                        break
                                    }
                                }
                                
                                self.controller?.updateChatPresentationInterfaceState(animated: false, interactive: false, { state in
                                    guard var filter = state.historyFilter, let reaction = ReactionsMessageAttribute.reactionFromMessageTag(tag: filter.customTag) else {
                                        return state
                                    }
                                    filter.isActive = false
                                    return state.updatedHistoryFilter(filter).updatedSearch(ChatSearchData(
                                        query: "",
                                        domain: .tag(reaction),
                                        domainSuggestionContext: .none,
                                        resultsState: ChatSearchResultsState(
                                            messageIndices: messageIndices,
                                            currentId: currentIndex?.id,
                                            state: searchState,
                                            totalCount: results.totalCount,
                                            completed: results.completed
                                        )
                                    ))
                                })
                                
                                let _ = (self.historyNode.isReady
                                |> filter { $0 }
                                |> take(1)
                                |> deliverOnMainQueue).startStandalone(next: { [weak self] _ in
                                    guard let self else {
                                        return
                                    }
                                    
                                    self.controller?.navigateToMessage(
                                        from: nil,
                                        to: .index(message.index),
                                        scrollPosition: .center(.bottom),
                                        rememberInStack: false,
                                        forceInCurrentChat: true,
                                        animated: true
                                    )
                                    self.controller?.alwaysShowSearchResultsAsList = false
                                    self.alwaysShowSearchResultsAsList = false
                                    self.controller?.updateChatPresentationInterfaceState(animated: true, interactive: true, { state in
                                        return state.updatedDisplayHistoryFilterAsList(false)
                                    })
                                })
                            })
                        } else {
                            self.controller?.navigateToMessage(
                                from: nil,
                                to: .index(message.index),
                                scrollPosition: .center(.bottom),
                                rememberInStack: false,
                                forceInCurrentChat: true,
                                animated: true
                            )
                            self.controller?.alwaysShowSearchResultsAsList = false
                            self.alwaysShowSearchResultsAsList = false
                            self.controller?.updateChatPresentationInterfaceState(animated: true, interactive: true, { state in
                                var state = state
                                state = state.updatedDisplayHistoryFilterAsList(false)
                                if let channel = state.renderedPeer?.peer as? TelegramChannel, channel.isMonoForum, let linkedMonoforumId = channel.linkedMonoforumId, let mainChannel = self.chatPresentationInterfaceState.renderedPeer?.peers[linkedMonoforumId] as? TelegramChannel, mainChannel.hasPermission(.sendSomething) {
                                    state = state.updatedSearch(nil)
                                }
                                return state
                            })
                        }
                    },
                    peerSelected: { [weak self] peer in
                        guard let self else {
                            return
                        }
                        
                        if let channel = self.chatPresentationInterfaceState.renderedPeer?.peer as? TelegramChannel, channel.isMonoForum {
                            self.interfaceInteraction?.updateChatLocationThread(peer.id.toInt64(), nil)
                            
                            self.controller?.updateChatPresentationInterfaceState(animated: true, interactive: true, { current in
                                return current.updatedSearch(nil)
                            })
                        } else {
                            guard let navigationController = self.controller?.navigationController as? NavigationController else {
                                return
                            }
                            self.context.sharedContext.navigateToChatController(NavigateToChatControllerParams(
                                navigationController: navigationController,
                                context: self.context,
                                chatLocation: .replyThread(ChatReplyThreadMessage(
                                    peerId: self.context.account.peerId,
                                    threadId: peer.id.toInt64(),
                                    channelMessageId: nil,
                                    isChannelPost: false,
                                    isForumPost: false,
                                    isMonoforumPost: false,
                                    maxMessage: nil,
                                    maxReadIncomingMessageId: nil,
                                    maxReadOutgoingMessageId: nil,
                                    unreadCount: 0,
                                    initialFilledHoles: IndexSet(),
                                    initialAnchor: .automatic,
                                    isNotAvailable: false
                                )),
                                subject: nil,
                                keepStack: .always
                            ))
                        }
                    },
                    loadTagMessages: { tag, index in
                        let input: ChatHistoryLocationInput
                        if let index {
                            input = ChatHistoryLocationInput(
                                content: .Navigation(
                                    index: .message(index),
                                    anchorIndex: .message(index),
                                    count: 45,
                                    highlight: false
                                ),
                                id: 0
                            )
                        } else {
                            input = ChatHistoryLocationInput(
                                content: .Initial(count: 45),
                                id: 0
                            )
                        }
                        
                        return chatHistoryViewForLocation(
                            input,
                            ignoreMessagesInTimestampRange: nil,
                            ignoreMessageIds: Set(),
                            context: context,
                            chatLocation: chatLocation,
                            chatLocationContextHolder: Atomic(value: nil),
                            scheduled: false,
                            fixedCombinedReadStates: nil,
                            tag: tag.length == 0 ? nil : .customTag(tag, nil),
                            appendMessagesFromTheSameGroup: false,
                            additionalData: []
                        )
                        |> mapToSignal { viewUpdate -> Signal<MessageHistoryView, NoError> in
                            switch viewUpdate {
                            case .Loading:
                                return .complete()
                            case let .HistoryView(view, _, _, _, _, _, _):
                                return .single(view)
                            }
                        }
                    },
                    getSearchResult: { [weak self] in
                        guard let self, let controller = self.controller else {
                            return nil
                        }
                        return controller.searchResult.get()
                        |> map { result in
                            return result?.0
                        }
                    },
                    getSavedPeers: { [weak self] query in
                        guard let self else {
                            return nil
                        }
                        let strings = self.chatPresentationInterfaceState.strings
                        let foundLocalPeers = context.engine.messages.searchLocalSavedMessagesPeers(query: query.lowercased(), indexNameMapping: [
                            context.account.peerId: [
                                PeerIndexNameRepresentation.title(title: strings.DialogList_MyNotes.lowercased(), addressNames: []),
                                PeerIndexNameRepresentation.title(title: "my notes".lowercased(), addressNames: [])
                            ],
                            PeerId(namespace: Namespaces.Peer.CloudUser, id: PeerId.Id._internalFromInt64Value(2666000)): [
                                PeerIndexNameRepresentation.title(title: strings.ChatList_AuthorHidden.lowercased(), addressNames: [])
                            ]
                        ])
                        |> map { peers -> [(EnginePeer, MessageIndex?)] in
                            return peers.map { peer in
                                return (peer, nil)
                            }
                        }
                        return foundLocalPeers
                    },
                    getChats: { [weak self] query in
                        guard let self else {
                            return nil
                        }
                        guard let peer = self.chatPresentationInterfaceState.renderedPeer?.peer else {
                            return nil
                        }
                        if !peer.isForumOrMonoForum {
                            return nil
                        }
                        
                        let threadListSignal: Signal<EngineChatList, NoError> = context.sharedContext.subscribeChatListData(context: self.context, location: peer.isMonoForum ? .savedMessagesChats(peerId: peer.id) : .forum(peerId: peer.id))
                        
                        return threadListSignal |> map(Optional.init)
                    },
                    loadMoreSearchResults: { [weak self] in
                        guard let self, let controller = self.controller else {
                            return
                        }
                        
                        if case let .customChatContents(contents) = self.chatPresentationInterfaceState.subject {
                            contents.loadMore()
                        } else {
                            guard let currentSearchState = controller.searchState, let currentResultsState = controller.presentationInterfaceState.search?.resultsState else {
                                return
                            }
                            
                            self.loadMoreSearchResultsDisposable?.dispose()
                            self.loadMoreSearchResultsDisposable = (self.context.engine.messages.searchMessages(location: currentSearchState.location, query: currentSearchState.query, state: currentResultsState.state)
                            |> deliverOnMainQueue).startStrict(next: { [weak self] results, updatedState in
                                guard let self, let controller = self.controller else {
                                    return
                                }
                                
                                controller.searchResult.set(.single((results, updatedState, currentSearchState.location)))
                                
                                var navigateIndex: MessageIndex?
                                controller.updateChatPresentationInterfaceState(animated: true, interactive: true, { current in
                                    if let data = current.search {
                                        let messageIndices = results.messages.map({ $0.index }).sorted()
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
                                        return current.updatedSearch(data.withUpdatedResultsState(ChatSearchResultsState(messageIndices: messageIndices, currentId: currentIndex?.id, state: updatedState, totalCount: results.totalCount, completed: results.completed)))
                                    } else {
                                        return current
                                    }
                                })
                                if let navigateIndex = navigateIndex {
                                    switch controller.chatLocation {
                                    case .peer, .replyThread, .customChatContents:
                                        controller.navigateToMessage(from: nil, to: .index(navigateIndex), forceInCurrentChat: true)
                                    }
                                }
                                controller.updateItemNodesSearchTextHighlightStates()
                            })
                        }
                    }
                )),
                environment: {},
                containerSize: layout.size
            )
            if let inlineSearchResultsView = inlineSearchResults.view as? ChatInlineSearchResultsListComponent.View {
                var animateIn = false
                if inlineSearchResultsView.superview == nil {
                    animateIn = true
                    if !self.alwaysShowSearchResultsAsList || self.skippedShowSearchResultsAsListAnimationOnce {
                        inlineSearchResultsView.alpha = 0.0
                    }
                    self.skippedShowSearchResultsAsListAnimationOnce = true
                    inlineSearchResultsView.layer.allowsGroupOpacity = true
                    if let emptyNode = self.emptyNode {
                        self.contentContainerNode.contentNode.view.insertSubview(inlineSearchResultsView, aboveSubview: emptyNode.view)
                    } else {
                        self.contentContainerNode.contentNode.view.insertSubview(inlineSearchResultsView, aboveSubview: self.historyNodeContainer.view)
                    }
                }
                inlineSearchResultsTransition.setFrame(view: inlineSearchResultsView, frame: CGRect(origin: CGPoint(), size: layout.size))
                
                if animateIn {
                    self.inlineSearchResultsReadyDisposable = (inlineSearchResultsView.isReady
                    |> filter { $0 }
                    |> take(1)
                    |> deliverOnMainQueue).startStrict(next: { [weak self] _ in
                        guard let self else {
                            return
                        }
                        guard let inlineSearchResultsView = self.inlineSearchResults?.view as? ChatInlineSearchResultsListComponent.View else {
                            return
                        }
                        if inlineSearchResultsView.alpha == 0.0 {
                            inlineSearchResultsView.alpha = 1.0
                        
                            inlineSearchResultsView.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.2)
                            inlineSearchResultsView.animateIn()
                            
                            transition.updateSublayerTransformScale(node: self.historyNodeContainer, scale: CGPoint(x: 0.95, y: 0.95))
                        }
                    })
                }
            }
            
            if self.alwaysShowSearchResultsAsList {
                transition.updateAlpha(node: self.historyNode, alpha: 0.0)
                transition.updateAlpha(node: self.backgroundNode, alpha: 0.0)
            } else {
                transition.updateAlpha(node: self.historyNode, alpha: 1.0)
                transition.updateAlpha(node: self.backgroundNode, alpha: 1.0)
            }
        } else {
            if let inlineSearchResults = self.inlineSearchResults {
                self.inlineSearchResults = nil
                if let inlineSearchResultsView = inlineSearchResults.view as? ChatInlineSearchResultsListComponent.View {
                    transition.updateAlpha(layer: inlineSearchResultsView.layer, alpha: 0.0, completion: { [weak inlineSearchResultsView] _ in
                        inlineSearchResultsView?.removeFromSuperview()
                    })
                    inlineSearchResultsView.animateOut()
                }
                transition.updateSublayerTransformScale(node: self.historyNodeContainer, scale: CGPoint(x: 1.0, y: 1.0))
            }
            if let inlineSearchResultsReadyDisposable = self.inlineSearchResultsReadyDisposable {
                self.inlineSearchResultsReadyDisposable = nil
                inlineSearchResultsReadyDisposable.dispose()
            }
            self.inlineSearchResultsReady = false
            
            transition.updateAlpha(node: self.historyNode, alpha: 1.0)
            transition.updateAlpha(node: self.backgroundNode, alpha: 1.0)
        }
        
        transition.updateAlpha(node: self.navigateButtons, alpha: showNavigateButtons ? 1.0 : 0.0)

        let listBottomInset = self.historyNode.insets.top
        if let previousListBottomInset = previousListBottomInset, listBottomInset != previousListBottomInset {
            if abs(listBottomInset - previousListBottomInset) > 80.0 {
                if (self.context.sharedContext.currentPresentationData.with({ $0 })).reduceMotion {
                    return
                }
                if self.context.sharedContext.energyUsageSettings.fullTranslucency {
                    self.backgroundNode.animateEvent(transition: transition, extendAnimation: false)
                }
            }
            //self.historyNode.didScrollWithOffset?(listBottomInset - previousListBottomInset, transition, nil)
        }

        self.derivedLayoutState = ChatControllerNodeDerivedLayoutState(inputContextPanelsFrame: inputContextPanelsFrame, inputContextPanelsOverMainPanelFrame: inputContextPanelsOverMainPanelFrame, inputNodeHeight: inputNodeHeightAndOverflow?.0, inputNodeAdditionalHeight: inputNodeHeightAndOverflow?.1, upperInputPositionBound: inputNodeHeightAndOverflow?.0 != nil ? self.upperInputPositionBound : nil)
        
        //self.notifyTransitionCompletionListeners(transition: transition)
    }
    
    private func updateInputPanelBackgroundExtension(transition: ContainedViewLayoutTransition) {
        guard let intrinsicInputPanelBackgroundNodeSize = self.intrinsicInputPanelBackgroundNodeSize else {
            return
        }
        
        var extensionValue: CGFloat = 0.0
        if let inputNode = self.inputNode {
            extensionValue = inputNode.topBackgroundExtension
        }
        
        self.inputPanelBackgroundNode.update(size: CGSize(width: intrinsicInputPanelBackgroundNodeSize.width, height: intrinsicInputPanelBackgroundNodeSize.height + extensionValue), transition: transition)
        transition.updateFrame(node: self.inputPanelBottomBackgroundSeparatorNode, frame: CGRect(origin: CGPoint(x: 0.0, y: self.inputPanelBottomBackgroundSeparatorBaseOffset + extensionValue), size: CGSize(width: self.inputPanelBottomBackgroundSeparatorNode.bounds.width, height: UIScreenPixel)), beginWithCurrentState: true)
        
        if let inputPanelBackgroundContent = self.inputPanelBackgroundContent, let (layout, _) = self.validLayout {
            var inputPanelBackgroundFrame = self.inputPanelBackgroundNode.frame
            inputPanelBackgroundFrame.size.height = intrinsicInputPanelBackgroundNodeSize.height + extensionValue
            
            transition.updateFrame(node: inputPanelBackgroundContent, frame: CGRect(origin: .zero, size: inputPanelBackgroundFrame.size))
            inputPanelBackgroundContent.update(rect: inputPanelBackgroundFrame, within: layout.size, transition: transition)
        }
    }
    
    private var storedHideInputExpanded: Bool?
    
    private func updateInputPanelBackgroundExpansion(transition: ContainedViewLayoutTransition) {
        if let inputNode = self.inputNode {
            if inputNode.hideInput && inputNode.adjustLayoutForHiddenInput {
                self.storedHideInputExpanded = self.inputPanelContainerNode.expansionFraction == 1.0
                self.inputPanelContainerNode.expand()
            } else {
                if let storedHideInputExpanded = self.storedHideInputExpanded {
                    self.storedHideInputExpanded = nil
                    if !storedHideInputExpanded {
                        self.inputPanelContainerNode.collapse()
                    }
                }
            }
        }
        
        self.requestLayout(transition)
    }
    
    private func notifyTransitionCompletionListeners(transition: ContainedViewLayoutTransition) {
        if !self.onLayoutCompletions.isEmpty {
            let onLayoutCompletions = self.onLayoutCompletions
            self.onLayoutCompletions = []
            for completion in onLayoutCompletions {
                completion(transition)
            }
        }
    }
    
    private func chatPresentationInterfaceStateRequiresInputFocus(_ state: ChatPresentationInterfaceState) -> Bool {
        switch state.inputMode {
        case .text:
            if state.interfaceState.selectionState != nil {
                return false
            } else {
                return true
            }
        case .media:
            return true
        default:
            return false
        }
    }
        
    private let emptyInputView = EmptyInputView()
    private func chatPresentationInterfaceStateInputView(_ state: ChatPresentationInterfaceState) -> UIView? {
        switch state.inputMode {
        case .text:
            return nil
        case .media:
            return self.emptyInputView
        default:
            return nil
        }
    }
    
    func updateChatPresentationInterfaceState(_ chatPresentationInterfaceState: ChatPresentationInterfaceState, transition: ContainedViewLayoutTransition, interactive: Bool, completion: @escaping (ContainedViewLayoutTransition) -> Void) {
        self.selectedMessages = chatPresentationInterfaceState.interfaceState.selectionState?.selectedIds
        
        var textStateUpdated = false
        if let textInputPanelNode = self.textInputPanelNode {
            let wasEmpty = self.chatPresentationInterfaceState.interfaceState.effectiveInputState.inputText.length != 0
            let isEmpty = chatPresentationInterfaceState.interfaceState.effectiveInputState.inputText.length != 0
            if wasEmpty != isEmpty {
                textStateUpdated = true
            }
            
            self.chatPresentationInterfaceState = self.chatPresentationInterfaceState.updatedInterfaceState { $0.withUpdatedEffectiveInputState(textInputPanelNode.inputTextState) }
        }
        
        let presentationReadyUpdated = self.chatPresentationInterfaceState.presentationReady != chatPresentationInterfaceState.presentationReady
        
        if (self.chatPresentationInterfaceState != chatPresentationInterfaceState && chatPresentationInterfaceState.presentationReady) || textStateUpdated {
            self.onLayoutCompletions.append(completion)
            
            let themeUpdated = presentationReadyUpdated || (self.chatPresentationInterfaceState.theme !== chatPresentationInterfaceState.theme)
            
            self.backgroundNode.update(wallpaper: chatPresentationInterfaceState.chatWallpaper, animated: true)
            
            self.historyNode.verticalScrollIndicatorColor = UIColor(white: 0.5, alpha: 0.8)
            self.loadingPlaceholderNode?.updatePresentationInterfaceState(chatPresentationInterfaceState)
            
            var updatedInputFocus = self.chatPresentationInterfaceStateRequiresInputFocus(self.chatPresentationInterfaceState) != self.chatPresentationInterfaceStateRequiresInputFocus(chatPresentationInterfaceState)
            if self.chatPresentationInterfaceStateInputView(self.chatPresentationInterfaceState) !== self.chatPresentationInterfaceStateInputView(chatPresentationInterfaceState) {
                updatedInputFocus = true
            }
            
            let updateInputTextState = self.chatPresentationInterfaceState.interfaceState.effectiveInputState != chatPresentationInterfaceState.interfaceState.effectiveInputState
            self.chatPresentationInterfaceState = chatPresentationInterfaceState
            
            self.navigateButtons.update(theme: chatPresentationInterfaceState.theme, dateTimeFormat: chatPresentationInterfaceState.dateTimeFormat, backgroundNode: self.backgroundNode)
            
            if themeUpdated {
                if case let .color(color) = self.chatPresentationInterfaceState.chatWallpaper, UIColor(rgb: color).isEqual(self.chatPresentationInterfaceState.theme.chat.inputPanel.panelBackgroundColorNoWallpaper) {
                    self.inputPanelBackgroundNode.updateColor(color: self.chatPresentationInterfaceState.theme.chat.inputPanel.panelBackgroundColorNoWallpaper, transition: .immediate)
                    self.usePlainInputSeparator = true
                } else {
                    self.inputPanelBackgroundNode.updateColor(color: self.chatPresentationInterfaceState.theme.chat.inputPanel.panelBackgroundColor, transition: .immediate)
                    self.usePlainInputSeparator = false
                    self.plainInputSeparatorAlpha = nil
                }
                                
                self.updatePlainInputSeparator(transition: .immediate)
                self.inputPanelBackgroundSeparatorNode.backgroundColor = self.chatPresentationInterfaceState.theme.chat.inputPanel.panelSeparatorColor
                self.inputPanelBottomBackgroundSeparatorNode.backgroundColor = self.chatPresentationInterfaceState.theme.chat.inputMediaPanel.panelSeparatorColor

                self.backgroundNode.updateBubbleTheme(bubbleTheme: chatPresentationInterfaceState.theme, bubbleCorners: chatPresentationInterfaceState.bubbleCorners)
                
                if self.backgroundNode.hasExtraBubbleBackground() {
                    if self.navigationBarBackgroundContent == nil {
                        if let navigationBarBackgroundContent = self.backgroundNode.makeBubbleBackground(for: .free),
                           let inputPanelBackgroundContent = self.backgroundNode.makeBubbleBackground(for: .free) {
                            self.navigationBarBackgroundContent = navigationBarBackgroundContent
                            self.inputPanelBackgroundContent = inputPanelBackgroundContent
                            
                            navigationBarBackgroundContent.allowsGroupOpacity = true
                            navigationBarBackgroundContent.implicitContentUpdate = false
                            navigationBarBackgroundContent.alpha = 0.3
                            self.navigationBar?.insertSubnode(navigationBarBackgroundContent, at: 1)
                            
                            inputPanelBackgroundContent.allowsGroupOpacity = true
                            inputPanelBackgroundContent.implicitContentUpdate = false
                            inputPanelBackgroundContent.alpha = 0.3
                            self.inputPanelBackgroundNode.addSubnode(inputPanelBackgroundContent)
                        }
                    }
                } else {
                    self.navigationBarBackgroundContent?.removeFromSupernode()
                    self.navigationBarBackgroundContent = nil
                    self.inputPanelBackgroundContent?.removeFromSupernode()
                    self.inputPanelBackgroundContent = nil
                }
            }
            
            let keepSendButtonEnabled = chatPresentationInterfaceState.interfaceState.forwardMessageIds != nil || chatPresentationInterfaceState.interfaceState.editMessage != nil
            var extendedSearchLayout = false
            loop: for (_, result) in chatPresentationInterfaceState.inputQueryResults {
                if case let .contextRequestResult(peer, _) = result, peer != nil {
                    extendedSearchLayout = true
                    break loop
                }
            }
            
            if let textInputPanelNode = self.textInputPanelNode, updateInputTextState {
                let previous = self.overrideUpdateTextInputHeightTransition
                self.overrideUpdateTextInputHeightTransition = transition
                textInputPanelNode.updateInputTextState(chatPresentationInterfaceState.interfaceState.effectiveInputState, keepSendButtonEnabled: keepSendButtonEnabled, extendedSearchLayout: extendedSearchLayout, accessoryItems: chatPresentationInterfaceState.inputTextPanelState.accessoryItems, animated: transition.isAnimated)
                self.overrideUpdateTextInputHeightTransition = previous
            } else {
                self.textInputPanelNode?.updateKeepSendButtonEnabled(keepSendButtonEnabled: keepSendButtonEnabled, extendedSearchLayout: extendedSearchLayout, animated: transition.isAnimated)
            }
            
            var restrictionText: String?
            if let peer = chatPresentationInterfaceState.renderedPeer?.peer, let restrictionTextValue = peer.restrictionText(platform: "ios", contentSettings: self.context.currentContentSettings.with { $0 }), !restrictionTextValue.isEmpty {
                restrictionText = restrictionTextValue
            } else if chatPresentationInterfaceState.isNotAccessible {
                if case .replyThread = self.chatLocation {
                    restrictionText = chatPresentationInterfaceState.strings.CommentsGroup_ErrorAccessDenied
                } else if let peer = chatPresentationInterfaceState.renderedPeer?.peer as? TelegramChannel, case .broadcast = peer.info {
                    restrictionText = chatPresentationInterfaceState.strings.Channel_ErrorAccessDenied
                } else {
                    restrictionText = chatPresentationInterfaceState.strings.Group_ErrorAccessDenied
                }
            }
            
            if let restrictionText = restrictionText {
                if self.restrictedNode == nil {
                    let restrictedNode = ChatRecentActionsEmptyNode(theme: chatPresentationInterfaceState.theme, chatWallpaper: chatPresentationInterfaceState.chatWallpaper, chatBubbleCorners: chatPresentationInterfaceState.bubbleCorners, hasIcon: false)
                    self.historyNodeContainer.supernode?.insertSubnode(restrictedNode, aboveSubnode: self.historyNodeContainer)
                    self.restrictedNode = restrictedNode
                }
                self.restrictedNode?.setup(title: "", text: processedPeerRestrictionText(restrictionText))
                self.historyNodeContainer.isHidden = true
                self.navigateButtons.isHidden = true
                self.loadingNode.isHidden = true
                self.loadingPlaceholderNode?.isHidden = true
                self.emptyNode?.isHidden = true
                self.updateIsLoading(isLoading: false, earlier: false, animated: false)
            } else if let restrictedNode = self.restrictedNode {
                self.restrictedNode = nil
                restrictedNode.removeFromSupernode()
                self.historyNodeContainer.isHidden = false
                self.navigateButtons.isHidden = false
                self.loadingNode.isHidden = false
                self.emptyNode?.isHidden = false
            }
            
            if let openStickersDisposable = self.openStickersDisposable {
                if case .media = chatPresentationInterfaceState.inputMode {
                } else {
                    openStickersDisposable.dispose()
                    self.openStickersDisposable = nil
                }
            }
            
            let layoutTransition: ContainedViewLayoutTransition = transition
            
            let transitionIsAnimated: Bool
            if case .immediate = transition {
                transitionIsAnimated = false
            } else {
                transitionIsAnimated = true
            }
            
            if let _ = self.chatPresentationInterfaceState.search, let interfaceInteraction = self.interfaceInteraction {
                var activate = false
                if self.searchNavigationNode == nil {
                    if !self.chatPresentationInterfaceState.hasSearchTags {
                        activate = true
                    }
                    self.searchNavigationNode = ChatSearchNavigationContentNode(context: self.context, theme: self.chatPresentationInterfaceState.theme, strings: self.chatPresentationInterfaceState.strings, chatLocation: self.chatPresentationInterfaceState.chatLocation, interaction: interfaceInteraction, presentationInterfaceState: self.chatPresentationInterfaceState)
                }
                if let navigationBar = self.navigationBar {
                    navigationBar.setContentNode(self.searchNavigationNode, animated: transitionIsAnimated)
                } else {
                    self.controller?.customNavigationBarContentNode = self.searchNavigationNode
                }
                self.searchNavigationNode?.update(presentationInterfaceState: self.chatPresentationInterfaceState)
                
                if case let .customChatContents(contents) = self.chatPresentationInterfaceState.subject, case .hashTagSearch = contents.kind {
                    activate = false
                }
                if activate {
                    self.searchNavigationNode?.activate()
                }
            } else if let _ = self.searchNavigationNode {
                self.searchNavigationNode = nil
                self.controller?.customNavigationBarContentNode = nil
                self.navigationBar?.setContentNode(nil, animated: transitionIsAnimated)
            }
            
            var waitForKeyboardLayout = false
            if let textView = self.textInputPanelNode?.textInputNode?.textView {
                let updatedInputView = self.chatPresentationInterfaceStateInputView(chatPresentationInterfaceState)
                if textView.inputView !== updatedInputView {
                    textView.inputView = updatedInputView
                    if textView.isFirstResponder {
                        if self.chatPresentationInterfaceStateRequiresInputFocus(chatPresentationInterfaceState), let validLayout = self.validLayout {
                            if case .compact = validLayout.0.metrics.widthClass {
                                waitForKeyboardLayout = true
                            } else if let inputHeight = validLayout.0.inputHeight, inputHeight > 100.0 {
                                waitForKeyboardLayout = true
                            }
                        }
                        textView.reloadInputViews()
                    }
                }
            }
            
            if updatedInputFocus {
                if !self.ignoreUpdateHeight && !waitForKeyboardLayout {
                    self.scheduleLayoutTransitionRequest(layoutTransition)
                }
                
                if self.chatPresentationInterfaceStateRequiresInputFocus(chatPresentationInterfaceState) {
                    self.ensureInputViewFocused()
                } else {
                    if let inputPanelNode = self.inputPanelNode as? ChatTextInputPanelNode {
                        if inputPanelNode.isFocused {
                            inputPanelNode.skipPresentationInterfaceStateUpdate = true
                            self.context.sharedContext.mainWindow?.simulateKeyboardDismiss(transition: .animated(duration: 0.5, curve: .spring))
                            inputPanelNode.skipPresentationInterfaceStateUpdate = false
                        }
                    }
                }
            } else {
                if !self.ignoreUpdateHeight {
                    if interactive {
                        if let scheduledLayoutTransitionRequest = self.scheduledLayoutTransitionRequest {
                            switch scheduledLayoutTransitionRequest.1 {
                                case .immediate:
                                    self.scheduleLayoutTransitionRequest(layoutTransition)
                                default:
                                    break
                            }
                        } else {
                            self.scheduleLayoutTransitionRequest(layoutTransition)
                        }
                    } else {
                        if let scheduledLayoutTransitionRequest = self.scheduledLayoutTransitionRequest {
                            switch scheduledLayoutTransitionRequest.1 {
                                case .immediate:
                                    self.requestLayout(layoutTransition)
                                case .animated:
                                    self.scheduleLayoutTransitionRequest(scheduledLayoutTransitionRequest.1)
                            }
                        } else {
                            self.requestLayout(layoutTransition)
                        }
                    }
                }
            }
        } else {
            completion(.immediate)
        }
    }
    
    func updateAutomaticMediaDownloadSettings(_ settings: MediaAutoDownloadSettings) {
        self.historyNode.forEachItemNode { itemNode in
            if let itemNode = itemNode as? ChatMessageItemView {
                itemNode.updateAutomaticMediaDownloadSettings()
            }
        }
        self.historyNode.prefetchManager.updateAutoDownloadSettings(settings)
    }
    
    func updateStickerSettings(_ settings: ChatInterfaceStickerSettings, forceStopAnimations: Bool) {
        self.historyNode.forEachItemNode { itemNode in
            if let itemNode = itemNode as? ChatMessageItemView {
                itemNode.updateStickerSettings(forceStopAnimations: forceStopAnimations)
            }
        }
    }
    
    var isInputViewFocused: Bool {
        if let inputPanelNode = self.inputPanelNode as? ChatTextInputPanelNode {
            return inputPanelNode.isFocused
        } else {
            return false
        }
    }
    
    @discardableResult func ensureInputViewFocused() -> Bool {
        if let inputPanelNode = self.inputPanelNode as? ChatTextInputPanelNode {
            inputPanelNode.ensureFocused()
            return true
        } else {
            return false
        }
    }
    
    @objc func tapGesture(_ recognizer: UITapGestureRecognizer) {
        if recognizer.state == .ended {
            if case .standard(.previewing) = self.chatPresentationInterfaceState.mode {
                self.controller?.animateFromPreviewing()
            } else {
                self.dismissInput(view: self.view, location: recognizer.location(in: self.contentContainerNode.view))
            }
        }
    }
    
    func dismissInput(view: UIView? = nil, location: CGPoint? = nil) {
        if let _ = self.chatPresentationInterfaceState.inputTextPanelState.mediaRecordingState {
            return
        }
        
        if let view, let location {
            if context.sharedContext.immediateExperimentalUISettings.rippleEffect {
                self.wrappingNode.triggerRipple(at: self.contentContainerNode.view.convert(location, from: view))
            }
        }
        
        switch self.chatPresentationInterfaceState.inputMode {
        case .none:
            break
        case .inputButtons:
            if let peer = self.chatPresentationInterfaceState.renderedPeer?.peer as? TelegramUser, peer.botInfo != nil, self.chatPresentationInterfaceState.keyboardButtonsMessage?.visibleButtonKeyboardMarkup?.flags.contains(.persistent) == true {
            } else {
                self.interfaceInteraction?.updateInputModeAndDismissedButtonKeyboardMessageId({ state in
                    return (.none, state.keyboardButtonsMessage?.id ?? state.interfaceState.messageActionsState.closedButtonKeyboardMessageId)
                })
            }
        default:
            self.interfaceInteraction?.updateInputModeAndDismissedButtonKeyboardMessageId({ state in
                return (.none, state.interfaceState.messageActionsState.closedButtonKeyboardMessageId)
            })
        }
        self.searchNavigationNode?.deactivate()
        
        self.view.window?.endEditing(true)
    }
    
    func dismissTextInput() {
        self.view.window?.endEditing(true)
    }
    
    func collapseInput() {
        if self.inputPanelContainerNode.expansionFraction != 0.0 {
            self.inputPanelContainerNode.collapse()
            if let inputNode = self.inputNode {
                inputNode.hideInput = false
                inputNode.adjustLayoutForHiddenInput = false
                if let inputNode = inputNode as? ChatEntityKeyboardInputNode {
                    inputNode.markInputCollapsed()
                }
            }
        }
    }
    
    private func scheduleLayoutTransitionRequest(_ transition: ContainedViewLayoutTransition) {
        let requestId = self.scheduledLayoutTransitionRequestId
        self.scheduledLayoutTransitionRequestId += 1
        self.scheduledLayoutTransitionRequest = (requestId, transition)
        (self.view as? UITracingLayerView)?.schedule(layout: { [weak self] in
            if let strongSelf = self {
                if let (currentRequestId, currentRequestTransition) = strongSelf.scheduledLayoutTransitionRequest, currentRequestId == requestId {
                    strongSelf.scheduledLayoutTransitionRequest = nil
                    strongSelf.requestLayout(currentRequestTransition)
                }
            }
        })
        self.setNeedsLayout()
    }
    
    private func makeMediaInputNode() -> ChatInputNode? {
        guard let inputMediaNodeData = self.inputMediaNodeData else {
            return nil
        }
        
        var peerId: PeerId?
        if case let .peer(id) = self.chatPresentationInterfaceState.chatLocation {
            peerId = id
        }
        
        guard let interfaceInteraction = self.interfaceInteraction else {
            return nil
        }
        
        let inputNode = ChatEntityKeyboardInputNode(
            context: self.context,
            currentInputData: inputMediaNodeData,
            updatedInputData: self.inputMediaNodeDataPromise.get(),
            defaultToEmojiTab: !self.chatPresentationInterfaceState.interfaceState.effectiveInputState.inputText.string.isEmpty || self.chatPresentationInterfaceState.interfaceState.forwardMessageIds != nil || self.openStickersBeginWithEmoji,
            interaction: ChatEntityKeyboardInputNode.Interaction(chatControllerInteraction: self.controllerInteraction, panelInteraction: interfaceInteraction),
            chatPeerId: peerId,
            stateContext: self.inputMediaNodeStateContext
        )
        self.openStickersBeginWithEmoji = false
        
        return inputNode
    }
    
    func loadInputPanels(theme: PresentationTheme, strings: PresentationStrings, fontSize: PresentationFontSize) {
        if !self.didInitializeInputMediaNodeDataPromise {
            self.didInitializeInputMediaNodeDataPromise = true
                        
            self.inputMediaNodeDataPromise.set(
                ChatEntityKeyboardInputNode.inputData(
                    context: self.context,
                    chatPeerId: self.chatLocation.peerId,
                    areCustomEmojiEnabled: self.chatPresentationInterfaceState.customEmojiAvailable,
                    hasEdit: true,
                    sendGif: { [weak self] fileReference, sourceView, sourceRect, silentPosting, schedule in
                        if let self {
                            return self.controllerInteraction.sendGif(fileReference, sourceView, sourceRect, silentPosting, schedule)
                        } else {
                            return false
                        }
                    }
                )
            )
        }
        
        self.textInputPanelNode?.loadTextInputNodeIfNeeded()
    }
    
    func currentInputPanelFrame() -> CGRect? {
        return self.inputPanelNode?.frame
    }
    
    func sendButtonFrame() -> CGRect? {
        if let mediaPreviewNode = self.inputPanelNode as? ChatRecordingPreviewInputPanelNode {
            return mediaPreviewNode.convert(mediaPreviewNode.sendButton.frame, to: self)
        } else if let frame = self.textInputPanelNode?.actionButtons.frame {
            return self.textInputPanelNode?.convert(frame, to: self)
        } else {
            return nil
        }
    }
    
    func textInputView() -> UITextView? {
        return self.textInputPanelNode?.textInputNode?.textView
    }
    
    func updateRecordedMediaDeleted(_ isDeleted: Bool) {
        self.textInputPanelNode?.isMediaDeleted = isDeleted
    }
    
    func frameForVisibleArea() -> CGRect {
        var rect = CGRect(origin: CGPoint(x: self.visibleAreaInset.left, y: self.visibleAreaInset.top), size: CGSize(width: self.bounds.size.width - self.visibleAreaInset.left - self.visibleAreaInset.right, height: self.bounds.size.height - self.visibleAreaInset.top - self.visibleAreaInset.bottom))
        if let inputContextPanelNode = self.inputContextPanelNode, let topItemFrame = inputContextPanelNode.topItemFrame {
            rect.size.height = topItemFrame.minY
        }
        if let containerNode = self.containerNode {
            return containerNode.view.convert(rect, to: self.view)
        } else {
            return rect
        }
    }
    
    func frameForInputPanelAccessoryButton(_ item: ChatTextInputAccessoryItem) -> CGRect? {
        if let textInputPanelNode = self.textInputPanelNode, self.inputPanelNode === textInputPanelNode {
            return textInputPanelNode.frameForAccessoryButton(item).flatMap {
                return $0.offsetBy(dx: textInputPanelNode.frame.minX, dy: textInputPanelNode.frame.minY)
            }
        }
        return nil
    }
    
    func frameForInputActionButton() -> CGRect? {
        if let textInputPanelNode = self.textInputPanelNode, self.inputPanelNode === textInputPanelNode {
            return textInputPanelNode.frameForInputActionButton().flatMap {
                return $0.offsetBy(dx: textInputPanelNode.frame.minX, dy: textInputPanelNode.frame.minY)
            }
        } else if let recordingPreviewPanelNode = self.inputPanelNode as? ChatRecordingPreviewInputPanelNode {
            return recordingPreviewPanelNode.frameForInputActionButton().flatMap {
                return $0.offsetBy(dx: recordingPreviewPanelNode.frame.minX, dy: recordingPreviewPanelNode.frame.minY)
            }
        }
        return nil
    }
    
    func frameForAttachmentButton() -> CGRect? {
        if let textInputPanelNode = self.textInputPanelNode, self.inputPanelNode === textInputPanelNode {
            return textInputPanelNode.frameForAttachmentButton().flatMap {
                return $0.offsetBy(dx: textInputPanelNode.frame.minX, dy: textInputPanelNode.frame.minY)
            }
        }
        return nil
    }
    
    func frameForMenuButton() -> CGRect? {
        if let textInputPanelNode = self.textInputPanelNode, self.inputPanelNode === textInputPanelNode {
            return textInputPanelNode.frameForMenuButton().flatMap {
                return $0.offsetBy(dx: textInputPanelNode.frame.minX, dy: textInputPanelNode.frame.minY)
            }
        }
        return nil
    }
    
    func frameForStickersButton() -> CGRect? {
        if let textInputPanelNode = self.textInputPanelNode, self.inputPanelNode === textInputPanelNode {
            return textInputPanelNode.frameForStickersButton().flatMap {
                return $0.offsetBy(dx: textInputPanelNode.frame.minX, dy: textInputPanelNode.frame.minY)
            }
        }
        return nil
    }
    
    func frameForEmojiButton() -> CGRect? {
        if let textInputPanelNode = self.textInputPanelNode, self.inputPanelNode === textInputPanelNode {
            return textInputPanelNode.frameForEmojiButton().flatMap {
                return $0.offsetBy(dx: textInputPanelNode.frame.minX, dy: textInputPanelNode.frame.minY)
            }
        }
        return nil
    }
    
    func frameForGiftButton() -> CGRect? {
        if let textInputPanelNode = self.textInputPanelNode, self.inputPanelNode === textInputPanelNode {
            return textInputPanelNode.frameForGiftButton().flatMap {
                return $0.offsetBy(dx: textInputPanelNode.frame.minX, dy: textInputPanelNode.frame.minY)
            }
        }
        return nil
    }
    
    var isTextInputPanelActive: Bool {
        return self.inputPanelNode is ChatTextInputPanelNode
    }
    
    var currentTextInputLanguage: String? {
        return self.textInputPanelNode?.effectiveInputLanguage
    }
    
    func getWindowInputAccessoryHeight() -> CGFloat {
        var height = self.inputPanelBackgroundNode.bounds.size.height
        if case .overlay = self.chatPresentationInterfaceState.mode {
            height += 8.0
        }
        return height
    }
    
    func animateInAsOverlay(from fromNode: ASDisplayNode?, completion: @escaping () -> Void) {
        if let inputPanelNode = self.inputPanelNode as? ChatTextInputPanelNode, let fromNode = fromNode {
            if inputPanelNode.isFocused {
                self.performAnimateInAsOverlay(from: fromNode, transition: .animated(duration: 0.4, curve: .spring))
                completion()
            } else {
                self.animateInAsOverlayCompletion = completion
                self.bounds = CGRect(origin: CGPoint(x: -self.bounds.size.width * 2.0, y: 0.0), size: self.bounds.size)
                self.scheduledAnimateInAsOverlayFromNode = fromNode
                self.scheduleLayoutTransitionRequest(.immediate)
                inputPanelNode.ensureFocused()
            }
        } else {
            self.performAnimateInAsOverlay(from: fromNode, transition: .animated(duration: 0.4, curve: .spring))
            completion()
        }
    }
    
    private func performAnimateInAsOverlay(from fromNode: ASDisplayNode?, transition: ContainedViewLayoutTransition) {
        if let containerBackgroundNode = self.containerBackgroundNode, let fromNode = fromNode {
            let fromFrame = fromNode.view.convert(fromNode.bounds, to: self.view)
            containerBackgroundNode.supernode?.insertSubnode(fromNode, aboveSubnode: containerBackgroundNode)
            fromNode.frame = fromFrame
            
            fromNode.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.3, removeOnCompletion: false, completion: { [weak fromNode] _ in
                fromNode?.removeFromSupernode()
            })
            
            transition.animateFrame(node: containerBackgroundNode, from: CGRect(origin: fromFrame.origin.offsetBy(dx: -8.0, dy: -8.0), size: CGSize(width: fromFrame.size.width + 8.0 * 2.0, height: fromFrame.size.height + 8.0 + 20.0)))
            containerBackgroundNode.layer.animateSpring(from: 0.99 as NSNumber, to: 1.0 as NSNumber, keyPath: "transform.scale", duration: 0.5, initialVelocity: 1.0, damping: 10.0, removeOnCompletion: true, additive: false, completion: nil)
            
            if let containerNode = self.containerNode {
                containerNode.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.2)
                transition.animateFrame(node: containerNode, from: fromFrame)
                transition.animatePositionAdditive(node: self.backgroundNode, offset: CGPoint(x: 0.0, y: -containerNode.bounds.size.height))
                transition.animatePositionAdditive(node: self.historyNodeContainer, offset: CGPoint(x: 0.0, y: -containerNode.bounds.size.height))
                
                transition.updateFrame(node: fromNode, frame: CGRect(origin: containerNode.frame.origin, size: fromNode.frame.size))
            }
            
            self.backgroundEffectNode?.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.3)
            
            let inputPanelsOffset = self.bounds.size.height - self.inputPanelBackgroundNode.frame.minY
            transition.animateFrame(node: self.inputPanelBackgroundNode, from: self.inputPanelBackgroundNode.frame.offsetBy(dx: 0.0, dy: inputPanelsOffset))
            transition.animateFrame(node: self.inputPanelBackgroundSeparatorNode, from: self.inputPanelBackgroundSeparatorNode.frame.offsetBy(dx: 0.0, dy: inputPanelsOffset))
            if let inputPanelNode = self.inputPanelNode {
                transition.animateFrame(node: inputPanelNode, from: inputPanelNode.frame.offsetBy(dx: 0.0, dy: inputPanelsOffset))
            }
            if let accessoryPanelNode = self.accessoryPanelNode {
                transition.animateFrame(node: accessoryPanelNode, from: accessoryPanelNode.frame.offsetBy(dx: 0.0, dy: inputPanelsOffset))
            }
            
            if let _ = self.scrollContainerNode {
                containerBackgroundNode.layer.animateSpring(from: 0.99 as NSNumber, to: 1.0 as NSNumber, keyPath: "transform.scale", duration: 0.8, initialVelocity: 100.0, damping: 80.0, removeOnCompletion: true, additive: false, completion: nil)
                self.containerNode?.layer.animateSpring(from: 0.99 as NSNumber, to: 1.0 as NSNumber, keyPath: "transform.scale", duration: 0.8, initialVelocity: 100.0, damping: 80.0, removeOnCompletion: true, additive: false, completion: nil)
            }
            
            self.navigateButtons.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.3)
        } else {
            self.backgroundEffectNode?.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.3)
            if let containerNode = self.containerNode {
                containerNode.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.2)
            }
        }
        
        if let animateInAsOverlayCompletion = self.animateInAsOverlayCompletion {
            self.animateInAsOverlayCompletion = nil
            animateInAsOverlayCompletion()
        }
    }
    
    func animateDismissAsOverlay(completion: @escaping () -> Void) {
        if let containerNode = self.containerNode {
            self.dismissedAsOverlay = true
            self.dismissAsOverlayLayout = self.validLayout?.0
            
            self.backgroundEffectNode?.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.27, removeOnCompletion: false)
            
            self.containerBackgroundNode?.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.27, removeOnCompletion: false)
            self.containerBackgroundNode?.layer.animateScale(from: 1.0, to: 0.6, duration: 0.29, removeOnCompletion: false)
            
            containerNode.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.27, removeOnCompletion: false)
            containerNode.layer.animateScale(from: 1.0, to: 0.6, duration: 0.29, removeOnCompletion: false)
            
            self.navigateButtons.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.25, removeOnCompletion: false)
            
            self.dismissAsOverlayCompletion = completion
            self.scheduleLayoutTransitionRequest(.animated(duration: 0.4, curve: .spring))
            self.dismissInput()
        } else {
            completion()
        }
    }
    
    func scrollViewDidEndDragging(_ scrollView: UIScrollView, willDecelerate decelerate: Bool) {
        if let scrollContainerNode = self.scrollContainerNode, scrollView === scrollContainerNode.view {
            if abs(scrollView.contentOffset.y) > 50.0 {
                scrollView.isScrollEnabled = false
                self.dismissAsOverlay()
            }
        }
    }
    
    func scrollViewWillBeginDragging(_ scrollView: UIScrollView) {
        if let scrollContainerNode = self.scrollContainerNode, scrollView === scrollContainerNode.view {
            self.hapticFeedback.prepareImpact()
        }
    }
    
    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        if let scrollContainerNode = self.scrollContainerNode, scrollView === scrollContainerNode.view {
            let dismissStatus = abs(scrollView.contentOffset.y) > 50.0
            if dismissStatus != self.scrollViewDismissStatus {
                self.scrollViewDismissStatus = dismissStatus
                if !self.dismissedAsOverlay {
                    self.hapticFeedback.impact()
                }
            }
        }
    }
        
    override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        switch self.chatPresentationInterfaceState.mode {
        case .standard(.previewing):
            if let subject = self.controller?.subject, case let .messageOptions(_, _, info) = subject, case .reply = info {
                if let controller = self.controller {
                    if let result = controller.presentationContext.hitTest(view: self.view, point: point, with: event) {
                        return result
                    }
                }
                
                if let result = self.historyNode.view.hitTest(self.view.convert(point, to: self.historyNode.view), with: event), let node = result.asyncdisplaykit_node {
                    if node is TextSelectionNode {
                        return result
                    }
                }
            } else if let subject = self.controller?.subject, case let .messageOptions(_, _, info) = subject, case .link = info {
                if let controller = self.controller {
                    if let result = controller.presentationContext.hitTest(view: self.view, point: point, with: event) {
                        return result
                    }
                }
                
                if let result = self.historyNode.view.hitTest(self.view.convert(point, to: self.historyNode.view), with: event), let node = result.asyncdisplaykit_node {
                    if let textNode = node as? TextAccessibilityOverlayNode {
                        let _ = textNode
                        return result
                    } else if let _ = node as? LinkHighlightingNode {
                        return result
                    }
                }
            }
            if let navigationBar = self.navigationBar, let result = navigationBar.view.hitTest(self.view.convert(point, to: navigationBar.view), with: nil) {
                return result
            }
            if let result = self.historyNode.view.hitTest(self.view.convert(point, to: self.historyNode.view), with: event), let node = result.asyncdisplaykit_node, node is ChatMessageSelectionNode || node is GridMessageSelectionNode {
                return result
            }
            if let result = self.navigateButtons.hitTest(self.view.convert(point, to: self.navigateButtons.view), with: event) {
                return result
            }
            if self.bounds.contains(point) {
                return self.historyNode.view
            }
        default:
            break
        }
        
        var maybeDismissOverlayContent = true
        if let inputNode = self.inputNode, inputNode.bounds.contains(self.view.convert(point, to: inputNode.view)) {
            if let externalTopPanelContainer = inputNode.externalTopPanelContainer {
                if externalTopPanelContainer.hitTest(self.view.convert(point, to: externalTopPanelContainer), with: nil) != nil {
                    maybeDismissOverlayContent = true
                } else {
                    maybeDismissOverlayContent = false
                }
            } else {
                maybeDismissOverlayContent = false
            }
        }
        
        if let inputPanelNode = self.inputPanelNode, let viewForOverlayContent = inputPanelNode.viewForOverlayContent {
            if let result = viewForOverlayContent.hitTest(self.view.convert(point, to: viewForOverlayContent), with: event) {
                return result
            }
            if maybeDismissOverlayContent {
                viewForOverlayContent.maybeDismissContent(point: self.view.convert(point, to: viewForOverlayContent))
            }
        }
        
        if let secondaryInputPanelNode = self.secondaryInputPanelNode, let viewForOverlayContent = secondaryInputPanelNode.viewForOverlayContent {
            if let result = viewForOverlayContent.hitTest(self.view.convert(point, to: viewForOverlayContent), with: event) {
                return result
            }
            if maybeDismissOverlayContent {
                viewForOverlayContent.maybeDismissContent(point: self.view.convert(point, to: viewForOverlayContent))
            }
        }
        
        return nil
    }
    
    @objc func topDimNodeTapGesture(_ recognizer: UITapGestureRecognizer) {
        if case .ended = recognizer.state {
            self.interfaceInteraction?.updateInputModeAndDismissedButtonKeyboardMessageId { state in
                if case let .media(mode, expanded, focused) = state.inputMode, expanded != nil {
                    return (.media(mode: mode, expanded: nil, focused: focused), nil)
                } else {
                    return (state.inputMode, nil)
                }
            }
        }
    }
    
    func scrollToTop() {
        if case let .media(_, maybeExpanded, _) = self.chatPresentationInterfaceState.inputMode, maybeExpanded != nil {
            self.interfaceInteraction?.updateInputModeAndDismissedButtonKeyboardMessageId { state in
                if case let .media(mode, expanded, focused) = state.inputMode, expanded != nil {
                    return (.media(mode: mode, expanded: expanded, focused: focused), nil)
                } else {
                    return (state.inputMode, nil)
                }
            }
        } else {
            if let inlineSearchResultsView = self.inlineSearchResults?.view as? ChatInlineSearchResultsListComponent.View {
                inlineSearchResultsView.scrollToTop()
            } else {
                self.historyNode.scrollScreenToTop()
            }
        }
    }
    
    @objc func backgroundEffectTap(_ recognizer: UITapGestureRecognizer) {
        if case .ended = recognizer.state {
            self.dismissAsOverlay()
        }
    }
    
    func updateDropInteraction(isActive: Bool) {
        if isActive {
            if self.dropDimNode == nil {
                let dropDimNode = ASDisplayNode()
                dropDimNode.backgroundColor = self.chatPresentationInterfaceState.theme.chatList.backgroundColor.withAlphaComponent(0.35)
                self.dropDimNode = dropDimNode
                self.contentContainerNode.contentNode.addSubnode(dropDimNode)
                if let (layout, _) = self.validLayout {
                    dropDimNode.frame = CGRect(origin: CGPoint(), size: layout.size)
                    dropDimNode.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.25)
                }
            }
        } else if let dropDimNode = self.dropDimNode {
            self.dropDimNode = nil
            dropDimNode.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.3, removeOnCompletion: false, completion: { [weak dropDimNode] _ in
                dropDimNode?.removeFromSupernode()
            })
        }
    }
    
    private func updateLayoutInternal(transition: ContainedViewLayoutTransition) {
        if let (layout, navigationHeight) = self.validLayout {
            self.containerLayoutUpdated(layout, navigationBarHeight: navigationHeight, transition: transition, listViewTransaction: { updateSizeAndInsets, additionalScrollDistance, scrollToTop, completion in
                self.historyNode.updateLayout(transition: transition, updateSizeAndInsets: updateSizeAndInsets, additionalScrollDistance: additionalScrollDistance, scrollToTop: scrollToTop, completion: completion)
            }, updateExtraNavigationBarBackgroundHeight: { _, _, _, _ in
            })
        }
    }
    
    private func panGestureBegan(location: CGPoint) {
        guard let derivedLayoutState = self.derivedLayoutState, let (validLayout, _) = self.validLayout else {
            return
        }
        if self.upperInputPositionBound != nil {
            return
        }
        if let inputHeight = validLayout.inputHeight {
            if !inputHeight.isZero {
                return
            }
        }
        
        let keyboardGestureBeginLocation = location
        let accessoryHeight = self.getWindowInputAccessoryHeight()
        if let inputHeight = derivedLayoutState.inputNodeHeight, !inputHeight.isZero, keyboardGestureBeginLocation.y < validLayout.size.height - inputHeight - accessoryHeight, !self.inputPanelContainerNode.stableIsExpanded {
            var enableGesture = true
            if let view = self.view.hitTest(location, with: nil) {
                if doesViewTreeDisableInteractiveTransitionGestureRecognizer(view) {
                    enableGesture = false
                }
            }
            
            if let peer = self.chatPresentationInterfaceState.renderedPeer?.peer as? TelegramUser, peer.botInfo != nil, case .inputButtons = self.chatPresentationInterfaceState.inputMode, self.chatPresentationInterfaceState.keyboardButtonsMessage?.visibleButtonKeyboardMarkup?.flags.contains(.persistent) == true {
                enableGesture = false
            }
            
            if enableGesture {
                self.keyboardGestureBeginLocation = keyboardGestureBeginLocation
                self.keyboardGestureAccessoryHeight = accessoryHeight
            }
        }
    }
    
    private func panGestureMoved(location: CGPoint) {
        if let keyboardGestureBeginLocation = self.keyboardGestureBeginLocation {
            let currentLocation = location
            let deltaY = keyboardGestureBeginLocation.y - location.y
            if deltaY * deltaY >= 3.0 * 3.0 || self.upperInputPositionBound != nil {
                self.upperInputPositionBound = currentLocation.y + (self.keyboardGestureAccessoryHeight ?? 0.0)
                self.updateLayoutInternal(transition: .immediate)
            }
        }
    }
    
    private func panGestureEnded(location: CGPoint, velocity: CGPoint?) {
        guard let derivedLayoutState = self.derivedLayoutState, let (validLayout, _) = self.validLayout else {
            return
        }
        if self.keyboardGestureBeginLocation == nil {
            return
        }
        
        self.keyboardGestureBeginLocation = nil
        let currentLocation = location
        
        let accessoryHeight = (self.keyboardGestureAccessoryHeight ?? 0.0)
        
        var canDismiss = false
        if let upperInputPositionBound = self.upperInputPositionBound, upperInputPositionBound >= validLayout.size.height - accessoryHeight {
            canDismiss = true
        } else if let velocity = velocity, velocity.y > 100.0 {
            canDismiss = true
        }
        
        if canDismiss, let inputHeight = derivedLayoutState.inputNodeHeight, currentLocation.y + (self.keyboardGestureAccessoryHeight ?? 0.0) > validLayout.size.height - inputHeight {
            self.upperInputPositionBound = nil
            self.dismissInput()
        } else {
            self.upperInputPositionBound = nil
            self.updateLayoutInternal(transition: .animated(duration: 0.25, curve: .spring))
        }
    }
    
    func cancelInteractiveKeyboardGestures() {
        self.panRecognizer?.isEnabled = false
        self.panRecognizer?.isEnabled = true
        
        if self.upperInputPositionBound != nil {
            self.updateLayoutInternal(transition: .animated(duration: 0.25, curve: .spring))
        }
        
        if self.keyboardGestureBeginLocation != nil {
            self.keyboardGestureBeginLocation = nil
        }
    }
    
    func openStickers(beginWithEmoji: Bool) {
        self.openStickersBeginWithEmoji = beginWithEmoji
        
        if self.openStickersDisposable == nil {
            self.openStickersDisposable = (self.inputMediaNodeDataPromise.get()
            |> take(1)
            |> deliverOnMainQueue).startStrict(next: { [weak self] _ in
                guard let strongSelf = self else {
                    return
                }
                
                strongSelf.interfaceInteraction?.updateInputModeAndDismissedButtonKeyboardMessageId({ state in
                    return (.media(mode: .other, expanded: nil, focused: false), state.interfaceState.messageActionsState.closedButtonKeyboardMessageId)
                })
                
                if let emojiPackTooltipController = strongSelf.controller?.emojiPackTooltipController {
                    strongSelf.controller?.emojiPackTooltipController = nil
                    emojiPackTooltipController.dismiss()
                    
                    Queue.mainQueue().after(0.1) {
                        if let inputNode = strongSelf.inputNode as? ChatEntityKeyboardInputNode {
                            inputNode.scrollToGroupEmoji()
                        }
                    }
                }
            })
        }
    }
    
    func sendCurrentMessage(silentPosting: Bool? = nil, scheduleTime: Int32? = nil, postpone: Bool = false, messageEffect: ChatSendMessageEffect? = nil, completion: @escaping () -> Void = {}) {
        if let textInputPanelNode = self.inputPanelNode as? ChatTextInputPanelNode {
            self.historyNode.justSentTextMessage = true
            
            if let textInputNode = textInputPanelNode.textInputNode, textInputNode.isFirstResponder() {
                Keyboard.applyAutocorrection(textView: textInputNode.textView)
            }
            
            var effectivePresentationInterfaceState = self.chatPresentationInterfaceState
            if let textInputPanelNode = self.textInputPanelNode {
                effectivePresentationInterfaceState = effectivePresentationInterfaceState.updatedInterfaceState { $0.withUpdatedEffectiveInputState(textInputPanelNode.inputTextState) }
            }
            
            if let _ = effectivePresentationInterfaceState.interfaceState.editMessage {
                self.interfaceInteraction?.editMessage()
            } else {
                var isScheduledMessages = false
                if case .scheduledMessages = effectivePresentationInterfaceState.subject {
                    isScheduledMessages = true
                }
                
                if let _ = effectivePresentationInterfaceState.slowmodeState, !isScheduledMessages && scheduleTime == nil {
                    if let rect = self.frameForInputActionButton() {
                        self.interfaceInteraction?.displaySlowmodeTooltip(self.view, rect)
                    }
                    return
                }
                
                var messages: [EnqueueMessage] = []
                
                let effectiveInputText = expandedInputStateAttributedString(effectivePresentationInterfaceState.interfaceState.composeInputState.inputText)
                
                let peerSpecificEmojiPack = (self.controller?.contentData?.state.peerView?.cachedData as? CachedChannelData)?.emojiPack
                
                var inlineStickers: [MediaId: Media] = [:]
                var firstLockedPremiumEmoji: TelegramMediaFile?
                var bubbleUpEmojiOrStickersetsById: [Int64: ItemCollectionId] = [:]
                effectiveInputText.enumerateAttribute(ChatTextInputAttributes.customEmoji, in: NSRange(location: 0, length: effectiveInputText.length), using: { value, _, _ in
                    if let value = value as? ChatTextInputTextCustomEmojiAttribute {
                        if let file = value.file {
                            inlineStickers[file.fileId] = file
                            if let packId = value.interactivelySelectedFromPackId {
                                bubbleUpEmojiOrStickersetsById[file.fileId.id] = packId
                            }
                            
                            var isPeerSpecific = false
                            for attribute in file.attributes {
                                if case let .CustomEmoji(_, _, _, packReference) = attribute, case let .id(id, _) = packReference {
                                    isPeerSpecific = id == peerSpecificEmojiPack?.id.id
                                }
                            }
                            
                            if file.isPremiumEmoji && !self.chatPresentationInterfaceState.isPremium && self.chatPresentationInterfaceState.chatLocation.peerId != self.context.account.peerId && !isPeerSpecific {
                                if firstLockedPremiumEmoji == nil {
                                    firstLockedPremiumEmoji = file
                                }
                            }
                        }
                    }
                })
                
                if let firstLockedPremiumEmoji = firstLockedPremiumEmoji {
                    let presentationData = self.context.sharedContext.currentPresentationData.with { $0 }
                    self.controllerInteraction.displayUndo(.sticker(context: context, file: firstLockedPremiumEmoji, loop: true, title: nil, text: presentationData.strings.EmojiInput_PremiumEmojiToast_Text, undoText: presentationData.strings.EmojiInput_PremiumEmojiToast_Action, customAction: { [weak self] in
                        guard let strongSelf = self else {
                            return
                        }
                        strongSelf.dismissTextInput()
                        
                        var replaceImpl: ((ViewController) -> Void)?
                        let controller = PremiumDemoScreen(context: strongSelf.context, subject: .animatedEmoji, action: {
                            let controller = PremiumIntroScreen(context: strongSelf.context, source: .animatedEmoji)
                            replaceImpl?(controller)
                        })
                        replaceImpl = { [weak controller] c in
                            controller?.replace(with: c)
                        }
                        strongSelf.controller?.present(controller, in: .window(.root), with: nil)
                    }))
                    
                    return
                }
                
                if let replyMessageSubject = self.chatPresentationInterfaceState.interfaceState.replyMessageSubject, let quote = replyMessageSubject.quote {
                    if let replyMessage = self.chatPresentationInterfaceState.replyMessage {
                        let nsText = replyMessage.text as NSString
                        var startIndex = 0
                        var found = false
                        while true {
                            let range = nsText.range(of: quote.text, range: NSRange(location: startIndex, length: nsText.length - startIndex))
                            if range.location != NSNotFound {
                                let subEntities = messageTextEntitiesInRange(entities: replyMessage.textEntitiesAttribute?.entities ?? [], range: range, onlyQuoteable: true)
                                if subEntities == quote.entities {
                                    found = true
                                    break
                                }
                                
                                startIndex = range.upperBound
                            } else {
                                break
                            }
                        }
                        
                        if !found {
                            let authorName: String = (replyMessage.author.flatMap(EnginePeer.init))?.compactDisplayTitle ?? ""
                            let errorTextData =  self.chatPresentationInterfaceState.strings.Chat_ErrorQuoteOutdatedText(authorName)
                            let errorText = errorTextData.string
                            self.controller?.present(standardTextAlertController(theme: AlertControllerTheme(presentationData: self.context.sharedContext.currentPresentationData.with({ $0 })), title: self.chatPresentationInterfaceState.strings.Chat_ErrorQuoteOutdatedTitle, text: errorText, actions: [
                                TextAlertAction(type: .genericAction, title: self.chatPresentationInterfaceState.strings.Common_Cancel, action: {}),
                                TextAlertAction(type: .defaultAction, title: self.chatPresentationInterfaceState.strings.Chat_ErrorQuoteOutdatedActionEdit, action: { [weak self] in
                                    guard let self, let controller = self.controller else {
                                        return
                                    }
                                    controller.updateChatPresentationInterfaceState(interactive: false, { presentationInterfaceState in
                                        return presentationInterfaceState.updatedInterfaceState { interfaceState in
                                            guard var replyMessageSubject = interfaceState.replyMessageSubject else {
                                                return interfaceState
                                            }
                                            replyMessageSubject.quote = nil
                                            return interfaceState.withUpdatedReplyMessageSubject(replyMessageSubject)
                                        }
                                    })
                                    presentChatLinkOptions(selfController: controller, sourceNode: controller.displayNode)
                                }),
                            ], parseMarkdown: true), in: .window(.root))
                            
                            return
                        }
                    }
                }
                
                let timestamp = CACurrentMediaTime()
                if self.lastSendTimestamp + 0.15 > timestamp {
                    return
                }
                self.lastSendTimestamp = timestamp
                
                self.updateTypingActivity(false)
                
                let trimmedInputText = effectiveInputText.string.trimmingCharacters(in: .whitespacesAndNewlines)
                let peerId = effectivePresentationInterfaceState.chatLocation.peerId
                if peerId?.namespace != Namespaces.Peer.SecretChat, let interactiveEmojis = self.interactiveEmojis, interactiveEmojis.emojis.contains(trimmedInputText), effectiveInputText.attribute(ChatTextInputAttributes.customEmoji, at: 0, effectiveRange: nil) == nil {
                    messages.append(.message(text: "", attributes: [], inlineStickers: [:], mediaReference: AnyMediaReference.standalone(media: TelegramMediaDice(emoji: trimmedInputText)), threadId: self.chatLocation.threadId, replyToMessageId: self.chatPresentationInterfaceState.interfaceState.replyMessageSubject?.subjectModel, replyToStoryId: nil, localGroupingKey: nil, correlationId: nil, bubbleUpEmojiOrStickersets: []))
                } else {
                    let inputText = convertMarkdownToAttributes(effectiveInputText)
                    
                    for text in breakChatInputText(trimChatInputText(inputText)) {
                        if text.length != 0 {
                            var attributes: [MessageAttribute] = []
                            let entities: [MessageTextEntity]
                            if case let .customChatContents(customChatContents) = self.chatPresentationInterfaceState.subject, case .businessLinkSetup = customChatContents.kind {
                                entities = generateChatInputTextEntities(text, generateLinks: false)
                            } else {
                                entities = generateTextEntities(text.string, enabledTypes: .all, currentEntities: generateChatInputTextEntities(text, maxAnimatedEmojisInText: 0))
                            }
                            if !entities.isEmpty {
                                attributes.append(TextEntitiesMessageAttribute(entities: entities))
                            }
                                                        
                            var webpage: TelegramMediaWebpage?
                            if let urlPreview = self.chatPresentationInterfaceState.urlPreview {
                                if self.chatPresentationInterfaceState.interfaceState.composeDisableUrlPreviews.contains(urlPreview.url) {
                                    attributes.append(OutgoingContentInfoMessageAttribute(flags: [.disableLinkPreviews]))
                                } else {
                                    webpage = urlPreview.webPage
                                    attributes.append(WebpagePreviewMessageAttribute(leadingPreview: !urlPreview.positionBelowText, forceLargeMedia: urlPreview.largeMedia, isManuallyAdded: true, isSafe: false))
                                }
                            }
                            
                            var bubbleUpEmojiOrStickersets: [ItemCollectionId] = []
                            for entity in entities {
                                if case let .CustomEmoji(_, fileId) = entity.type {
                                    if let packId = bubbleUpEmojiOrStickersetsById[fileId] {
                                        if !bubbleUpEmojiOrStickersets.contains(packId) {
                                            bubbleUpEmojiOrStickersets.append(packId)
                                        }
                                    }
                                }
                            }
                            
                            if bubbleUpEmojiOrStickersets.count > 1 {
                                bubbleUpEmojiOrStickersets.removeAll()
                            }

                            messages.append(.message(text: text.string, attributes: attributes, inlineStickers: inlineStickers, mediaReference: webpage.flatMap(AnyMediaReference.standalone), threadId: self.chatLocation.threadId, replyToMessageId: self.chatPresentationInterfaceState.interfaceState.replyMessageSubject?.subjectModel, replyToStoryId: nil, localGroupingKey: nil, correlationId: nil, bubbleUpEmojiOrStickersets: bubbleUpEmojiOrStickersets))
                        }
                    }

                    var forwardingToSameChat = false
                    if case let .peer(id) = self.chatPresentationInterfaceState.chatLocation, id.namespace == Namespaces.Peer.CloudUser, id != self.context.account.peerId, let forwardMessageIds = self.chatPresentationInterfaceState.interfaceState.forwardMessageIds, forwardMessageIds.count == 1 {
                        for messageId in forwardMessageIds {
                            if messageId.peerId == id {
                                forwardingToSameChat = true
                            }
                        }
                    }
                    if !messages.isEmpty && forwardingToSameChat {
                        self.controllerInteraction.displaySwipeToReplyHint()
                    }
                }
                
                var postEmptyMessages = false
                if case let .customChatContents(customChatContents) = self.chatPresentationInterfaceState.subject {
                    switch customChatContents.kind {
                    case .hashTagSearch:
                        break
                    case .quickReplyMessageInput:
                        break
                    case .businessLinkSetup:
                        postEmptyMessages = true
                    }
                }
                
                if !messages.isEmpty, let messageEffect {
                    messages[0] = messages[0].withUpdatedAttributes { attributes in
                        var attributes = attributes
                        attributes.append(EffectMessageAttribute(id: messageEffect.id))
                        return attributes
                    }
                }
                
                if !messages.isEmpty || postEmptyMessages || self.chatPresentationInterfaceState.interfaceState.forwardMessageIds != nil {
                    if let forwardMessageIds = self.chatPresentationInterfaceState.interfaceState.forwardMessageIds {
                        var attributes: [MessageAttribute] = []
                        attributes.append(ForwardOptionsMessageAttribute(hideNames: self.chatPresentationInterfaceState.interfaceState.forwardOptionsState?.hideNames == true, hideCaptions: self.chatPresentationInterfaceState.interfaceState.forwardOptionsState?.hideCaptions == true))

                        var replyThreadId: Int64?
                        if case let .replyThread(replyThreadMessage) = self.chatPresentationInterfaceState.chatLocation {
                            replyThreadId = replyThreadMessage.threadId
                        }
                        
                        for id in forwardMessageIds.sorted() {
                            messages.append(.forward(source: id, threadId: replyThreadId, grouping: .auto, attributes: attributes, correlationId: nil))
                        }
                    }
                                        
                    var usedCorrelationId: Int64?

                    if !messages.isEmpty, case .message = messages[messages.count - 1] {
                        let correlationId = Int64.random(in: 0 ..< Int64.max)
                        messages[messages.count - 1] = messages[messages.count - 1].withUpdatedCorrelationId(correlationId)

                        var replyPanel: ReplyAccessoryPanelNode?
                        if let accessoryPanelNode = self.accessoryPanelNode as? ReplyAccessoryPanelNode {
                            replyPanel = accessoryPanelNode
                        }
                        if self.shouldAnimateMessageTransition, let inputPanelNode = self.inputPanelNode as? ChatTextInputPanelNode, let textInput = inputPanelNode.makeSnapshotForTransition() {
                            usedCorrelationId = correlationId
                            let source: ChatMessageTransitionNodeImpl.Source = .textInput(textInput: textInput, replyPanel: replyPanel)
                            self.messageTransitionNode.add(correlationId: correlationId, source: source, initiated: {
                            })
                        }
                    }

                    self.setupSendActionOnViewUpdate({ [weak self] in
                        if let strongSelf = self, let textInputPanelNode = strongSelf.inputPanelNode as? ChatTextInputPanelNode {
                            strongSelf.collapseInput()
                            
                            strongSelf.ignoreUpdateHeight = true
                            textInputPanelNode.text = ""
                            strongSelf.requestUpdateChatInterfaceState(.immediate, true, { $0.withUpdatedReplyMessageSubject(nil).withUpdatedSendMessageEffect(nil).withUpdatedForwardMessageIds(nil).withUpdatedForwardOptionsState(nil).withUpdatedComposeDisableUrlPreviews([]) })
                            strongSelf.ignoreUpdateHeight = false
                        }
                    }, usedCorrelationId)
                    completion()
                    
                    self.sendMessages(messages, silentPosting, scheduleTime, messages.count > 1, postpone)
                }
            }
        }
    }
    
    func animateIn(completion: (() -> Void)? = nil) {
        self.layer.animatePosition(from: CGPoint(x: self.layer.position.x, y: self.layer.position.y + self.layer.bounds.size.height), to: self.layer.position, duration: 0.5, timingFunction: kCAMediaTimingFunctionSpring, completion: { _ in
            completion?()
        })
    }
    
    func animateOut(completion: (() -> Void)? = nil) {
        self.layer.animatePosition(from: self.layer.position, to: CGPoint(x: self.layer.position.x, y: self.layer.position.y + self.layer.bounds.size.height), duration: 0.2, timingFunction: CAMediaTimingFunctionName.easeInEaseOut.rawValue, removeOnCompletion: false, completion: { _ in
            completion?()
        })
    }
    
    func setEnablePredictiveTextInput(_ value: Bool) {
        self.textInputPanelNode?.enablePredictiveInput = value
    }
    
    func updatePlainInputSeparatorAlpha(_ value: CGFloat, transition: ContainedViewLayoutTransition) {
        if self.plainInputSeparatorAlpha != value {
            let immediate = self.plainInputSeparatorAlpha == nil
            self.plainInputSeparatorAlpha = value
            self.updatePlainInputSeparator(transition: immediate ? .immediate : transition)
        }
    }
    
    func updatePlainInputSeparator(transition: ContainedViewLayoutTransition) {
        var resolvedValue: CGFloat
        if self.accessoryPanelNode != nil {
            resolvedValue = 1.0
        } else if self.usePlainInputSeparator {
            resolvedValue = self.plainInputSeparatorAlpha ?? 0.0
        } else {
            resolvedValue = 1.0
        }
        
        resolvedValue = resolvedValue * (1.0 - self.inputPanelContainerNode.expansionFraction)
        
        if resolvedValue != self.inputPanelBackgroundSeparatorNode.alpha {
            transition.updateAlpha(node: self.inputPanelBackgroundSeparatorNode, alpha: resolvedValue, beginWithCurrentState: true)
        }
    }
    
    private var previousConfettiAnimationTimestamp: Double?
    func playConfettiAnimation() {
        guard self.view.bounds.width > 0.0 else {
            return
        }
        let currentTime = CACurrentMediaTime()
        if let previousConfettiAnimationTimestamp = self.previousConfettiAnimationTimestamp, abs(currentTime - previousConfettiAnimationTimestamp) < 0.1 {
            return
        }
        self.previousConfettiAnimationTimestamp = currentTime
        
        self.view.insertSubview(ConfettiView(frame: self.view.bounds), aboveSubview: self.historyNode.view)
    }
    
    func willNavigateAway() {
    }
    
    func updateIsBlurred(_ isBlurred: Bool) {
        if isBlurred {
            if self.blurredHistoryNode == nil {
                let unscaledSize = self.historyNode.frame.size
                let image = generateImage(CGSize(width: floor(unscaledSize.width), height: floor(unscaledSize.height)), opaque: true, scale: 1.0, rotatedContext: { size, context in
                    context.clear(CGRect(origin: CGPoint(), size: size))
                    
                    UIGraphicsPushContext(context)
                    
                    let backgroundFrame = self.backgroundNode.view.convert(self.backgroundNode.bounds, to: self.historyNode.supernode?.view)
                    self.backgroundNode.view.drawHierarchy(in: backgroundFrame, afterScreenUpdates: false)
                    
                    context.translateBy(x: size.width / 2.0, y: size.height / 2.0)
                    context.scaleBy(x: -1.0, y: -1.0)
                    context.translateBy(x: -size.width / 2.0, y: -size.height / 2.0)
                    
                    self.historyNode.view.drawHierarchy(in: CGRect(origin: CGPoint(), size: unscaledSize), afterScreenUpdates: false)
                    
                    context.translateBy(x: size.width / 2.0, y: size.height / 2.0)
                    context.scaleBy(x: -1.0, y: -1.0)
                    context.translateBy(x: -size.width / 2.0, y: -size.height / 2.0)
                    
                    if let emptyNode = self.emptyNode {
                        emptyNode.view.drawHierarchy(in: CGRect(origin: CGPoint(), size: unscaledSize), afterScreenUpdates: false)
                    }
                    
                    UIGraphicsPopContext()
                }).flatMap(applyScreenshotEffectToImage)
                let blurredHistoryNode = ASImageNode()
                blurredHistoryNode.image = image
                blurredHistoryNode.frame = self.historyNode.frame
                self.blurredHistoryNode = blurredHistoryNode
                if let emptyNode = self.emptyNode {
                    emptyNode.supernode?.insertSubnode(blurredHistoryNode, aboveSubnode: emptyNode)
                } else {
                    self.historyNode.supernode?.insertSubnode(blurredHistoryNode, aboveSubnode: self.historyNode)
                }
            }
        } else {
            if let blurredHistoryNode = self.blurredHistoryNode {
                self.blurredHistoryNode = nil
                blurredHistoryNode.removeFromSupernode()
            }
        }
        self.historyNode.isHidden = isBlurred
    }

    var shouldAnimateMessageTransition: Bool {
        if (self.context.sharedContext.currentPresentationData.with({ $0 })).reduceMotion {
            return false
        }
        
        if self.chatPresentationInterfaceState.showCommands {
            return false
        }

        var hasAd = false
        self.historyNode.forEachVisibleItemNode { itemNode in
            if let itemNode = itemNode as? ChatMessageItemView {
                if let _ = itemNode.item?.message.adAttribute {
                    hasAd = true
                }
            }
        }

        if hasAd {
            return false
        }

        switch self.historyNode.visibleContentOffset() {
        case let .known(value) where value < 20.0:
            return true
        case .none:
            return true
        default:
            return false
        }
    }

    var shouldUseFastMessageSendAnimation: Bool {
        var hasAd = false
        self.historyNode.forEachVisibleItemNode { itemNode in
            if let itemNode = itemNode as? ChatMessageItemView {
                if let _ = itemNode.item?.message.adAttribute {
                    hasAd = true
                }
            }
        }

        if hasAd {
            return false
        }

        return true
    }

    var shouldAllowOverscrollActions: Bool {
        if let inputHeight = self.validLayout?.0.inputHeight, inputHeight > 0.0 {
            return false
        }
        if self.chatPresentationInterfaceState.inputTextPanelState.mediaRecordingState != nil {
            return false
        }
        if self.chatPresentationInterfaceState.interfaceState.mediaDraftState != nil {
            return false
        }
        if let inputPanelNode = self.inputPanelNode as? ChatTextInputPanelNode {
            if inputPanelNode.isFocused {
                return false
            }
            if !inputPanelNode.text.isEmpty {
                return false
            }
        }
        return true
    }

    final class SnapshotState {
        let backgroundNode: WallpaperBackgroundNode
        fileprivate let historySnapshotState: ChatHistoryListNodeImpl.SnapshotState
        let titleViewSnapshotState: ChatTitleView.SnapshotState?
        let avatarSnapshotState: ChatAvatarNavigationNode.SnapshotState?
        let navigationButtonsSnapshotState: ChatHistoryNavigationButtons.SnapshotState
        let titleAccessoryPanelSnapshot: UIView?
        let navigationBarHeight: CGFloat
        let inputPanelNodeSnapshot: UIView?
        let inputPanelOverscrollNodeSnapshot: UIView?

        fileprivate init(
            backgroundNode: WallpaperBackgroundNode,
            historySnapshotState: ChatHistoryListNodeImpl.SnapshotState,
            titleViewSnapshotState: ChatTitleView.SnapshotState?,
            avatarSnapshotState: ChatAvatarNavigationNode.SnapshotState?,
            navigationButtonsSnapshotState: ChatHistoryNavigationButtons.SnapshotState,
            titleAccessoryPanelSnapshot: UIView?,
            navigationBarHeight: CGFloat,
            inputPanelNodeSnapshot: UIView?,
            inputPanelOverscrollNodeSnapshot: UIView?
        ) {
            self.backgroundNode = backgroundNode
            self.historySnapshotState = historySnapshotState
            self.titleViewSnapshotState = titleViewSnapshotState
            self.avatarSnapshotState = avatarSnapshotState
            self.navigationButtonsSnapshotState = navigationButtonsSnapshotState
            self.titleAccessoryPanelSnapshot = titleAccessoryPanelSnapshot
            self.navigationBarHeight = navigationBarHeight
            self.inputPanelNodeSnapshot = inputPanelNodeSnapshot
            self.inputPanelOverscrollNodeSnapshot = inputPanelOverscrollNodeSnapshot
        }
    }

    func prepareSnapshotState(
        titleViewSnapshotState: ChatTitleView.SnapshotState?,
        avatarSnapshotState: ChatAvatarNavigationNode.SnapshotState?
    ) -> SnapshotState {
        var titleAccessoryPanelSnapshot: UIView?
        if let titleAccessoryPanelNode = self.titleAccessoryPanelNode, let snapshot = titleAccessoryPanelNode.view.snapshotView(afterScreenUpdates: false) {
            snapshot.frame = titleAccessoryPanelNode.frame
            titleAccessoryPanelSnapshot = snapshot
        }
        var inputPanelNodeSnapshot: UIView?
        if let inputPanelNode = self.inputPanelNode, let snapshot = inputPanelNode.view.snapshotView(afterScreenUpdates: false) {
            snapshot.frame = inputPanelNode.frame
            inputPanelNodeSnapshot = snapshot
        }
        var inputPanelOverscrollNodeSnapshot: UIView?
        if let inputPanelOverscrollNode = self.inputPanelOverscrollNode, let snapshot = inputPanelOverscrollNode.view.snapshotView(afterScreenUpdates: false) {
            snapshot.frame = inputPanelOverscrollNode.frame
            inputPanelOverscrollNodeSnapshot = snapshot
        }
        return SnapshotState(
            backgroundNode: self.backgroundNode,
            historySnapshotState: self.historyNode.prepareSnapshotState(),
            titleViewSnapshotState: titleViewSnapshotState,
            avatarSnapshotState: avatarSnapshotState,
            navigationButtonsSnapshotState: self.navigateButtons.prepareSnapshotState(),
            titleAccessoryPanelSnapshot: titleAccessoryPanelSnapshot,
            navigationBarHeight: self.navigationBar?.backgroundNode.bounds.height ?? 0.0,
            inputPanelNodeSnapshot: inputPanelNodeSnapshot,
            inputPanelOverscrollNodeSnapshot: inputPanelOverscrollNodeSnapshot
        )
    }

    func animateFromSnapshot(_ snapshotState: SnapshotState, completion: @escaping () -> Void) {
        let previousBackgroundNode = snapshotState.backgroundNode
        self.backgroundNode.supernode?.insertSubnode(previousBackgroundNode, belowSubnode: self.backgroundNode)
        
        self.historyNode.animateFromSnapshot(snapshotState.historySnapshotState, completion: { [weak previousBackgroundNode] in
            previousBackgroundNode?.removeFromSupernode()
            
            completion()
        })
        self.navigateButtons.animateFromSnapshot(snapshotState.navigationButtonsSnapshotState)

        if let titleAccessoryPanelSnapshot = snapshotState.titleAccessoryPanelSnapshot {
            self.titleAccessoryPanelContainer.view.addSubview(titleAccessoryPanelSnapshot)
            if let _ = self.titleAccessoryPanelNode {
                titleAccessoryPanelSnapshot.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.3, removeOnCompletion: false, completion: { [weak titleAccessoryPanelSnapshot] _ in
                    titleAccessoryPanelSnapshot?.removeFromSuperview()
                })
                titleAccessoryPanelSnapshot.layer.animatePosition(from: CGPoint(), to: CGPoint(x: 0.0, y: -10.0), duration: 0.5, timingFunction: kCAMediaTimingFunctionSpring, removeOnCompletion: false, additive: true)
            } else {
                titleAccessoryPanelSnapshot.layer.animatePosition(from: CGPoint(), to: CGPoint(x: 0.0, y: -titleAccessoryPanelSnapshot.bounds.height), duration: 0.5, timingFunction: kCAMediaTimingFunctionSpring, removeOnCompletion: false, additive: true, completion: { [weak titleAccessoryPanelSnapshot] _ in
                    titleAccessoryPanelSnapshot?.removeFromSuperview()
                })
            }
        }

        if let titleAccessoryPanelNode = self.titleAccessoryPanelNode {
            if let _ = snapshotState.titleAccessoryPanelSnapshot {
                titleAccessoryPanelNode.layer.animatePosition(from: CGPoint(x: 0.0, y: 10.0), to: CGPoint(), duration: 0.5, timingFunction: kCAMediaTimingFunctionSpring, removeOnCompletion: true, additive: true)
                titleAccessoryPanelNode.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.3, removeOnCompletion: true)
            } else {
                titleAccessoryPanelNode.layer.animatePosition(from: CGPoint(x: 0.0, y: -titleAccessoryPanelNode.bounds.height), to: CGPoint(), duration: 0.5, timingFunction: kCAMediaTimingFunctionSpring, removeOnCompletion: true, additive: true)
            }
        }

        if let navigationBar = self.navigationBar {
            let currentFrame = navigationBar.backgroundNode.frame
            var previousFrame = currentFrame
            previousFrame.size.height = snapshotState.navigationBarHeight
            if previousFrame != currentFrame {
                navigationBar.backgroundNode.update(size: previousFrame.size, transition: .immediate)
                navigationBar.backgroundNode.update(size: currentFrame.size, transition: .animated(duration: 0.5, curve: .spring))
            }
        }

        if let inputPanelNode = self.inputPanelNode, let inputPanelNodeSnapshot = snapshotState.inputPanelNodeSnapshot {
            inputPanelNode.view.superview?.insertSubview(inputPanelNodeSnapshot, belowSubview: inputPanelNode.view)

            inputPanelNodeSnapshot.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.3, removeOnCompletion: false, completion: { [weak inputPanelNodeSnapshot] _ in
                inputPanelNodeSnapshot?.removeFromSuperview()
            })
            inputPanelNodeSnapshot.layer.animatePosition(from: CGPoint(), to: CGPoint(x: 0.0, y: -5.0), duration: 0.5, timingFunction: kCAMediaTimingFunctionSpring, removeOnCompletion: false, additive: true)

            if let inputPanelOverscrollNodeSnapshot = snapshotState.inputPanelOverscrollNodeSnapshot {
                inputPanelNode.view.superview?.insertSubview(inputPanelOverscrollNodeSnapshot, belowSubview: inputPanelNode.view)

                inputPanelOverscrollNodeSnapshot.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.3, removeOnCompletion: false, completion: { [weak inputPanelOverscrollNodeSnapshot] _ in
                    inputPanelOverscrollNodeSnapshot?.removeFromSuperview()
                })
                inputPanelOverscrollNodeSnapshot.layer.animatePosition(from: CGPoint(), to: CGPoint(x: 0.0, y: -5.0), duration: 0.5, timingFunction: kCAMediaTimingFunctionSpring, removeOnCompletion: false, additive: true)
            }

            inputPanelNode.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.3)
            inputPanelNode.layer.animatePosition(from: CGPoint(x: 0.0, y: 5.0), to: CGPoint(), duration: 0.5, timingFunction: kCAMediaTimingFunctionSpring, additive: true)
        }
    }

    private var preivousChatInputPanelOverscrollNodeTimestamp: Double = 0.0

    func setChatInputPanelOverscrollNode(overscrollNode: ChatInputPanelOverscrollNode?) {
        let directionUp: Bool
        if let overscrollNode = overscrollNode {
            if let current = self.inputPanelOverscrollNode {
                directionUp = current.priority > overscrollNode.priority
            } else {
                directionUp = true
            }
        } else {
            directionUp = false
        }

        let transition: ContainedViewLayoutTransition = .animated(duration: 0.15, curve: .easeInOut)

        let timestamp = CFAbsoluteTimeGetCurrent()
        if self.preivousChatInputPanelOverscrollNodeTimestamp > timestamp - 0.05 {
            if let inputPanelOverscrollNode = self.inputPanelOverscrollNode {
                self.inputPanelOverscrollNode = nil
                inputPanelOverscrollNode.removeFromSupernode()
            }
        }
        self.preivousChatInputPanelOverscrollNodeTimestamp = timestamp

        if let inputPanelOverscrollNode = self.inputPanelOverscrollNode {
            self.inputPanelOverscrollNode = nil
            inputPanelOverscrollNode.layer.animatePosition(from: CGPoint(), to: CGPoint(x: 0.0, y: directionUp ? -5.0 : 5.0), duration: 0.15, timingFunction: CAMediaTimingFunctionName.easeInEaseOut.rawValue, removeOnCompletion: false, additive: true)
            inputPanelOverscrollNode.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.15, removeOnCompletion: false, completion: { [weak inputPanelOverscrollNode] _ in
                inputPanelOverscrollNode?.removeFromSupernode()
            })
        }

        if let inputPanelNode = self.inputPanelNode, let overscrollNode = overscrollNode {
            self.inputPanelOverscrollNode = overscrollNode
            inputPanelNode.supernode?.insertSubnode(overscrollNode, aboveSubnode: inputPanelNode)

            overscrollNode.frame = inputPanelNode.frame
            overscrollNode.update(size: overscrollNode.bounds.size)

            overscrollNode.layer.animatePosition(from: CGPoint(x: 0.0, y: directionUp ? 5.0 : -5.0), to: CGPoint(), duration: 0.15, timingFunction: CAMediaTimingFunctionName.easeInEaseOut.rawValue, additive: true)
            overscrollNode.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.15)
        }

        if let inputPanelNode = self.inputPanelNode {
            transition.updateAlpha(node: inputPanelNode, alpha: overscrollNode == nil ? 1.0 : 0.0)
            transition.updateSublayerTransformOffset(layer: inputPanelNode.layer, offset: CGPoint(x: 0.0, y: overscrollNode == nil ? 0.0 : -5.0))
        }
    }
    
    private func setupHistoryNode() {
        var backgroundColors: [UInt32] = []
        switch self.chatPresentationInterfaceState.chatWallpaper {
        case let .file(file):
            if file.isPattern {
                backgroundColors = file.settings.colors
            }
        case let .gradient(gradient):
            backgroundColors = gradient.colors
        case let .color(color):
            backgroundColors = [color]
        default:
            break
        }
        if !backgroundColors.isEmpty {
            let averageColor = UIColor.average(of: backgroundColors.map(UIColor.init(rgb:)))
            if averageColor.hsb.b >= 0.3 {
                self.historyNode.verticalScrollIndicatorColor = UIColor(white: 0.0, alpha: 0.3)
            } else {
                self.historyNode.verticalScrollIndicatorColor = UIColor(white: 1.0, alpha: 0.3)
            }
        } else {
            self.historyNode.verticalScrollIndicatorColor = UIColor(white: 0.5, alpha: 0.8)
        }
        self.historyNode.enableExtractedBackgrounds = true
        
        self.historyNode.setLoadStateUpdated { [weak self] loadState, animated in
            guard let strongSelf = self else {
                return
            }
            let wasLoading = strongSelf.isLoadingValue
            if case let .loading(earlier) = loadState {
                strongSelf.updateIsLoading(isLoading: true, earlier: earlier, animated: animated)
            } else {
                strongSelf.updateIsLoading(isLoading: false, earlier: false, animated: animated)
            }
            
            var emptyType: ChatHistoryNodeLoadState.EmptyType?
            if case let .empty(type) = loadState {
                if case .botInfo = type {
                } else {
                    emptyType = type
                    if case .joined = type {
                        if strongSelf.didDisplayEmptyGreeting {
                            emptyType = .generic
                        } else {
                            strongSelf.didDisplayEmptyGreeting = true
                        }
                    }
                }
            } else if case .messages = loadState {
                strongSelf.didDisplayEmptyGreeting = true
            }
            strongSelf.updateIsEmpty(emptyType, wasLoading: wasLoading, animated: animated)
        }
        
        self.historyNode.view.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(self.tapGesture(_:))))
        
        self.displayVideoUnmuteTipDisposable?.dispose()
        self.displayVideoUnmuteTipDisposable = (combineLatest(queue: Queue.mainQueue(), ApplicationSpecificNotice.getVolumeButtonToUnmute(accountManager: self.context.sharedContext.accountManager), self.historyNode.hasVisiblePlayableItemNodes, self.historyNode.isInteractivelyScrolling)
        |> mapToSignal { notice, hasVisiblePlayableItemNodes, isInteractivelyScrolling -> Signal<Bool, NoError> in
            let display = !notice && hasVisiblePlayableItemNodes && !isInteractivelyScrolling
            if display {
                return .complete()
                |> delay(2.5, queue: Queue.mainQueue())
                |> then(
                    .single(display)
                )
            } else {
                return .single(display)
            }
        }).startStrict(next: { [weak self] display in
            if let strongSelf = self, let interfaceInteraction = strongSelf.interfaceInteraction {
                if display {
                    var nodes: [(CGFloat, ChatMessageItemView, ASDisplayNode)] = []
                    var skip = false
                    strongSelf.historyNode.forEachVisibleItemNode { itemNode in
                        if let itemNode = itemNode as? ChatMessageItemView, let (_, soundEnabled, isVideoMessage, _, badgeNode) = itemNode.playMediaWithSound(), let node = badgeNode {
                            if soundEnabled {
                                skip = true
                            } else if !skip && !isVideoMessage, case let .visible(fraction, _) = itemNode.visibility {
                                nodes.insert((fraction, itemNode, node), at: 0)
                            }
                        }
                    }
                    for (fraction, _, badgeNode) in nodes {
                        if fraction > 0.7 {
                            interfaceInteraction.displayVideoUnmuteTip(badgeNode.view.convert(badgeNode.view.bounds, to: strongSelf.view).origin.offsetBy(dx: 42.0, dy: -1.0))
                            break
                        }
                    }
                } else {
                    interfaceInteraction.displayVideoUnmuteTip(nil)
                }
            }
        })
    }
    
    func chatLocationTabSwitchDirection(from fromLocation: Int64?, to toLocation: Int64?) -> Bool? {
        var leftIndex: Int?
        var rightIndex: Int?
        if let titleTopicsAccessoryPanelNode = self.titleTopicsAccessoryPanelNode {
            leftIndex = titleTopicsAccessoryPanelNode.topicIndex(threadId: fromLocation)
            rightIndex = titleTopicsAccessoryPanelNode.topicIndex(threadId: toLocation)
        } else if let leftPanelView = self.leftPanel?.view.view as? ChatSideTopicsPanel.View {
            leftIndex = leftPanelView.topicIndex(threadId: fromLocation)
            rightIndex = leftPanelView.topicIndex(threadId: toLocation)
        }
        guard let leftIndex, let rightIndex else {
            return nil
        }
        return leftIndex < rightIndex
    }
    
    func createHistoryNodeForChatLocation(chatLocation: ChatLocation, chatLocationContextHolder: Atomic<ChatLocationContextHolder?>) -> ChatHistoryListNodeImpl {
        let historyNode = ChatHistoryListNodeImpl(
            context: self.context,
            updatedPresentationData: self.controller?.updatedPresentationData ?? (self.context.sharedContext.currentPresentationData.with({ $0 }), self.context.sharedContext.presentationData),
            chatLocation: chatLocation,
            chatLocationContextHolder: chatLocationContextHolder,
            adMessagesContext: self.adMessagesContext,
            tag: nil,
            source: .default,
            subject: nil,
            controllerInteraction: self.controllerInteraction,
            selectedMessages: self.selectedMessagesPromise.get(),
            rotated: self.controllerInteraction.chatIsRotated,
            isChatPreview: false,
            messageTransitionNode: {
                return nil
            }
        )
        
        historyNode.position = self.historyNode.position
        historyNode.bounds = self.historyNode.bounds
        historyNode.transform = self.historyNode.transform
        
        if let currentListViewLayout = self.currentListViewLayout {
            let updateSizeAndInsets = ListViewUpdateSizeAndInsets(size: currentListViewLayout.size, insets: currentListViewLayout.insets, scrollIndicatorInsets: currentListViewLayout.scrollIndicatorInsets, duration: 0.0, curve: .Default(duration: nil), ensureTopInsetForOverlayHighlightedItems: nil, customAnimationTransition: nil)
            historyNode.updateLayout(transition: .immediate, updateSizeAndInsets: updateSizeAndInsets, additionalScrollDistance: 0.0, scrollToTop: false, completion: {})
        }
        
        return historyNode
    }
    
    func prepareSwitchToChatLocation(historyNode: ChatHistoryListNodeImpl, animationDirection: ChatControllerAnimateInnerChatSwitchDirection?) {
        self.chatLocation = historyNode.chatLocation
        self.pendingSwitchToChatLocation = PendingSwitchToChatLocation(
            historyNode: historyNode,
            animationDirection: animationDirection
        )
    }
    
    func updateChatLocation(chatLocation: ChatLocation, transition: ContainedViewLayoutTransition, tabSwitchDirection: ChatControllerAnimateInnerChatSwitchDirection?) {
        if chatLocation == self.chatLocation {
            return
        }
        self.chatLocation = chatLocation
        
        self.chatLocationContextHolder = Atomic<ChatLocationContextHolder?>(value: nil)
        let historyNode = ChatHistoryListNodeImpl(
            context: self.context,
            updatedPresentationData: self.controller?.updatedPresentationData ?? (self.context.sharedContext.currentPresentationData.with({ $0 }), self.context.sharedContext.presentationData),
            chatLocation: chatLocation,
            chatLocationContextHolder: self.chatLocationContextHolder,
            adMessagesContext: self.adMessagesContext,
            tag: nil,
            source: .default,
            subject: nil,
            controllerInteraction: self.controllerInteraction,
            selectedMessages: self.selectedMessagesPromise.get(),
            rotated: self.controllerInteraction.chatIsRotated,
            isChatPreview: false,
            messageTransitionNode: { [weak self] in
                return self?.messageTransitionNode
            }
        )
        
        var getContentAreaInScreenSpaceImpl: (() -> CGRect)?
        var onTransitionEventImpl: ((ContainedViewLayoutTransition) -> Void)?
        let messageTransitionNode = ChatMessageTransitionNodeImpl(listNode: historyNode, getContentAreaInScreenSpace: {
            return getContentAreaInScreenSpaceImpl?() ?? CGRect()
        }, onTransitionEvent: { transition in
            onTransitionEventImpl?(transition)
        })
        
        getContentAreaInScreenSpaceImpl = { [weak self] in
            guard let strongSelf = self else {
                return CGRect()
            }

            return strongSelf.view.convert(strongSelf.frameForVisibleArea(), to: nil)
        }

        onTransitionEventImpl = { [weak self] transition in
            guard let strongSelf = self else {
                return
            }
            if (strongSelf.context.sharedContext.currentPresentationData.with({ $0 })).reduceMotion {
                return
            }
            if strongSelf.context.sharedContext.energyUsageSettings.fullTranslucency {
                strongSelf.backgroundNode.animateEvent(transition: transition, extendAnimation: false)
            }
        }
        
        self.wrappingNode.contentNode.insertSubnode(messageTransitionNode, aboveSubnode: self.messageTransitionNode)
        self.messageTransitionNode.removeFromSupernode()
        self.messageTransitionNode = messageTransitionNode
        
        let previousHistoryNode = self.historyNode
        previousHistoryNode.supernode?.insertSubnode(historyNode, aboveSubnode: previousHistoryNode)
        self.historyNode = historyNode
        
        self.setupHistoryNode()
        
        historyNode.position = previousHistoryNode.position
        historyNode.bounds = previousHistoryNode.bounds
        historyNode.transform = previousHistoryNode.transform
        
        if let currentListViewLayout = self.currentListViewLayout {
            let updateSizeAndInsets = ListViewUpdateSizeAndInsets(size: currentListViewLayout.size, insets: currentListViewLayout.insets, scrollIndicatorInsets: currentListViewLayout.scrollIndicatorInsets, duration: 0.0, curve: .Default(duration: nil), ensureTopInsetForOverlayHighlightedItems: nil, customAnimationTransition: nil)
            historyNode.updateLayout(transition: .immediate, updateSizeAndInsets: updateSizeAndInsets, additionalScrollDistance: 0.0, scrollToTop: false, completion: {})
        }
        
        if let validLayout = self.validLayout, transition.isAnimated, let tabSwitchDirection {
            var offsetMultiplier = CGPoint()
            switch tabSwitchDirection {
            case .up:
                offsetMultiplier.y = -1.0
            case .down:
                offsetMultiplier.y = 1.0
            case .left:
                offsetMultiplier.x = -1.0
            case .right:
                offsetMultiplier.x = 1.0
            }
            
            previousHistoryNode.clipsToBounds = true
            historyNode.clipsToBounds = true
            
            transition.animatePosition(layer: historyNode.layer, from: CGPoint(x: offsetMultiplier.x * validLayout.0.size.width, y: offsetMultiplier.y * validLayout.0.size.height), to: CGPoint(), removeOnCompletion: true, additive: true)
            transition.animatePosition(layer: previousHistoryNode.layer, from: CGPoint(), to: CGPoint(x: -offsetMultiplier.x * validLayout.0.size.width, y: -offsetMultiplier.y * validLayout.0.size.height), removeOnCompletion: false, additive: true, completion: { [weak previousHistoryNode, weak historyNode] _ in
                previousHistoryNode?.removeFromSupernode()
                historyNode?.clipsToBounds = false
            })
        } else {
            previousHistoryNode.removeFromSupernode()
        }
    }
}
