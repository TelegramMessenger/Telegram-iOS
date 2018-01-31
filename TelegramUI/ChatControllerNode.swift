import Foundation
import AsyncDisplayKit
import Postbox
import SwiftSignalKit
import Display
import TelegramCore

private final class ChatControllerNodeView: UITracingLayerView, WindowInputAccessoryHeightProvider {
    var inputAccessoryHeight: (() -> CGFloat)?
    
    func getWindowInputAccessoryHeight() -> CGFloat {
        return self.inputAccessoryHeight?() ?? 0.0
    }
}

class ChatControllerNode: ASDisplayNode, UIScrollViewDelegate {
    let account: Account
    let chatLocation: ChatLocation
    let controllerInteraction: ChatControllerInteraction
    
    let navigationBar: NavigationBar
    
    private var backgroundEffectNode: ASDisplayNode?
    private var containerBackgroundNode: ASImageNode?
    private var scrollContainerNode: ASScrollNode?
    private var containerNode: ASDisplayNode?
    private var overlayNavigationBar: ChatOverlayNavigationBar?
    
    let backgroundNode: ASDisplayNode
    let historyNode: ChatHistoryListNode
    let loadingNode: ChatLoadingNode
    
    private var validLayout: ContainerViewLayout?
    
    private var searchNavigationNode: ChatSearchNavigationContentNode?
    
    private let inputPanelBackgroundNode: ASDisplayNode
    private let inputPanelBackgroundSeparatorNode: ASDisplayNode
    
    private let titleAccessoryPanelContainer: ChatControllerTitlePanelNodeContainer
    private var titleAccessoryPanelNode: ChatTitleAccessoryPanelNode?
    
    private var inputPanelNode: ChatInputPanelNode?
    private var accessoryPanelNode: AccessoryPanelNode?
    private var inputContextPanelNode: ChatInputContextPanelNode?
    private var overlayContextPanelNode: ChatInputContextPanelNode?
    
    private var inputNode: ChatInputNode?
    
    private var textInputPanelNode: ChatTextInputPanelNode?
    private var inputMediaNode: ChatMediaInputNode?
    
    let navigateButtons: ChatHistoryNavigationButtons
    
    private var ignoreUpdateHeight = false
    
    private var animateInAsOverlayCompletion: (() -> Void)?
    private var dismissAsOverlayCompletion: (() -> Void)?
    private var dismissedAsOverlay = false
    private var scheduledAnimateInAsOverlayFromNode: ASDisplayNode?
    private var dismissAsOverlayLayout: ContainerViewLayout?
    
    private var hapticFeedback: HapticFeedback?
    private var scrollViewDismissStatus = false
    
    var chatPresentationInterfaceState: ChatPresentationInterfaceState
    var automaticMediaDownloadSettings: AutomaticMediaDownloadSettings
    
    private let selectedMessagesPromise = Promise<Set<MessageId>?>(nil)
    var selectedMessages: Set<MessageId>? {
        didSet {
            if self.selectedMessages != oldValue {
                self.selectedMessagesPromise.set(.single(self.selectedMessages))
            }
        }
    }
    
    var requestUpdateChatInterfaceState: (Bool, (ChatInterfaceState) -> ChatInterfaceState) -> Void = { _, _ in }
    var displayAttachmentMenu: () -> Void = { }
    var displayPasteMenu: ([UIImage]) -> Void = { _ in }
    var updateTypingActivity: () -> Void = { }
    var dismissUrlPreview: () -> Void = { }
    var setupSendActionOnViewUpdate: (@escaping () -> Void) -> Void = { _ in }
    var requestLayout: (ContainedViewLayoutTransition) -> Void = { _ in }
    var dismissAsOverlay: () -> Void = { }
    
    var interfaceInteraction: ChatPanelInterfaceInteraction?
    
    private var containerLayoutAndNavigationBarHeight: (ContainerViewLayout, CGFloat)?
    
    private var scheduledLayoutTransitionRequestId: Int = 0
    private var scheduledLayoutTransitionRequest: (Int, ContainedViewLayoutTransition)?
    
    private var isLoading: Bool = false {
        didSet {
            if self.isLoading != oldValue {
                if self.isLoading {
                    self.historyNode.supernode?.insertSubnode(self.loadingNode, aboveSubnode: self.historyNode)
                } else {
                    self.loadingNode.removeFromSupernode()
                }
            }
        }
    }
    
    init(account: Account, chatLocation: ChatLocation, messageId: MessageId?, controllerInteraction: ChatControllerInteraction, chatPresentationInterfaceState: ChatPresentationInterfaceState, automaticMediaDownloadSettings: AutomaticMediaDownloadSettings, navigationBar: NavigationBar) {
        self.account = account
        self.chatLocation = chatLocation
        self.controllerInteraction = controllerInteraction
        self.chatPresentationInterfaceState = chatPresentationInterfaceState
        self.automaticMediaDownloadSettings = automaticMediaDownloadSettings
        self.navigationBar = navigationBar
        
        self.backgroundNode = ASDisplayNode()
        self.backgroundNode.isLayerBacked = true
        self.backgroundNode.contentMode = .scaleAspectFill
        self.backgroundNode.displaysAsynchronously = false
        self.backgroundNode.clipsToBounds = true
        
        self.titleAccessoryPanelContainer = ChatControllerTitlePanelNodeContainer()
        self.titleAccessoryPanelContainer.clipsToBounds = true
        
        self.historyNode = ChatHistoryListNode(account: account, chatLocation: chatLocation, tagMask: nil, messageId: messageId, controllerInteraction: controllerInteraction, selectedMessages: self.selectedMessagesPromise.get())
        self.loadingNode = ChatLoadingNode(theme: chatPresentationInterfaceState.theme)
        
        self.inputPanelBackgroundNode = ASDisplayNode()
        self.inputPanelBackgroundNode.backgroundColor = self.chatPresentationInterfaceState.theme.chat.inputPanel.panelBackgroundColor
        self.inputPanelBackgroundNode.isLayerBacked = true
        
        self.inputPanelBackgroundSeparatorNode = ASDisplayNode()
        self.inputPanelBackgroundSeparatorNode.backgroundColor = self.chatPresentationInterfaceState.theme.chat.inputPanel.panelStrokeColor
        self.inputPanelBackgroundSeparatorNode.isLayerBacked = true
        
        self.navigateButtons = ChatHistoryNavigationButtons(theme: self.chatPresentationInterfaceState.theme)
        
        super.init()
        
        self.setViewBlock({
            return ChatControllerNodeView()
        })
        
        (self.view as? ChatControllerNodeView)?.inputAccessoryHeight = { [weak self] in
            if let strongSelf = self {
                return strongSelf.getWindowInputAccessoryHeight()
            } else {
                return 0.0
            }
        }
        
        assert(Queue.mainQueue().isCurrent())
        
        self.historyNode.setLoadStateUpdated { [weak self] loadState in
            if let strongSelf = self {
                if case .loading = loadState {
                    strongSelf.isLoading = true
                } else {
                    strongSelf.isLoading = false
                }
            }
        }
        
        self.backgroundNode.contents = chatControllerBackgroundImage(wallpaper: chatPresentationInterfaceState.chatWallpaper, postbox: account.postbox)?.cgImage
        
        self.addSubnode(self.backgroundNode)
        self.addSubnode(self.historyNode)
        self.addSubnode(self.titleAccessoryPanelContainer)
        
        self.addSubnode(self.inputPanelBackgroundNode)
        self.addSubnode(self.inputPanelBackgroundSeparatorNode)
        
        self.addSubnode(self.navigateButtons)
        
        self.historyNode.view.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(self.tapGesture(_:))))
        
        self.textInputPanelNode = ChatTextInputPanelNode(theme: chatPresentationInterfaceState.theme, presentController: { [weak self] controller in
            self?.interfaceInteraction?.presentController(controller, nil)
        })
        self.textInputPanelNode?.updateHeight = { [weak self] in
            if let strongSelf = self, let _ = strongSelf.inputPanelNode as? ChatTextInputPanelNode, !strongSelf.ignoreUpdateHeight {
                strongSelf.requestLayout(.animated(duration: 0.1, curve: .easeInOut))
            }
        }
        self.textInputPanelNode?.sendMessage = { [weak self] in
            if let strongSelf = self, let textInputPanelNode = strongSelf.inputPanelNode as? ChatTextInputPanelNode {
                if textInputPanelNode.textInputNode?.isFirstResponder() ?? false {
                    applyKeyboardAutocorrection()
                }
                
                var effectivePresentationInterfaceState = strongSelf.chatPresentationInterfaceState
                if let textInputPanelNode = strongSelf.textInputPanelNode {
                    effectivePresentationInterfaceState = effectivePresentationInterfaceState.updatedInterfaceState { $0.withUpdatedEffectiveInputState(textInputPanelNode.inputTextState) }
                }
                
                if let _ = effectivePresentationInterfaceState.interfaceState.editMessage {
                    strongSelf.interfaceInteraction?.editMessage()
                } else {
                    var messages: [EnqueueMessage] = []
                    
                    for text in breakChatInputText(trimChatInputText(effectivePresentationInterfaceState.interfaceState.composeInputState.inputText)) {
                        if text.length != 0 {
                            var attributes: [MessageAttribute] = []
                            let entities = generateTextEntities(text.string, enabledTypes: .all, currentEntities: generateChatInputTextEntities(text))
                            if !entities.isEmpty {
                                attributes.append(TextEntitiesMessageAttribute(entities: entities))
                            }
                            var webpage: TelegramMediaWebpage?
                            if strongSelf.chatPresentationInterfaceState.interfaceState.composeDisableUrlPreview != nil {
                                attributes.append(OutgoingContentInfoMessageAttribute(flags: [.disableLinkPreviews]))
                            } else {
                                webpage = strongSelf.chatPresentationInterfaceState.urlPreview?.1
                            }
                            messages.append(.message(text: text.string, attributes: attributes, media: webpage, replyToMessageId: strongSelf.chatPresentationInterfaceState.interfaceState.replyMessageId, localGroupingKey: nil))
                        }
                    }
                    
                    if !messages.isEmpty || strongSelf.chatPresentationInterfaceState.interfaceState.forwardMessageIds != nil {
                        strongSelf.setupSendActionOnViewUpdate({ [weak strongSelf] in
                            if let strongSelf = strongSelf, let textInputPanelNode = strongSelf.inputPanelNode as? ChatTextInputPanelNode {
                                strongSelf.ignoreUpdateHeight = true
                                textInputPanelNode.text = ""
                                strongSelf.requestUpdateChatInterfaceState(false, { $0.withUpdatedReplyMessageId(nil).withUpdatedForwardMessageIds(nil).withUpdatedComposeDisableUrlPreview(nil) })
                                strongSelf.ignoreUpdateHeight = false
                            }
                        })
                        
                        
                        if let forwardMessageIds = strongSelf.chatPresentationInterfaceState.interfaceState.forwardMessageIds {
                            for id in forwardMessageIds {
                                messages.append(.forward(source: id, grouping: .auto))
                            }
                        }
                        
                        if case let .peer(peerId) = strongSelf.chatLocation {
                            let _ = (enqueueMessages(account: strongSelf.account, peerId: peerId, messages: messages) |> deliverOnMainQueue).start(next: { _ in
                                if let strongSelf = self {
                                    strongSelf.historyNode.scrollToEndOfHistory()
                                }
                            })
                        }
                    }
                }
            }
        }
        
        self.textInputPanelNode?.pasteImages = { [weak self] images in
            self?.displayPasteMenu(images)
        }
        
        self.textInputPanelNode?.displayAttachmentMenu = { [weak self] in
            self?.displayAttachmentMenu()
        }
        
        self.textInputPanelNode?.updateActivity = { [weak self] in
            self?.updateTypingActivity()
        }
    }
    
    func containerLayoutUpdated(_ layout: ContainerViewLayout, navigationBarHeight: CGFloat, transition protoTransition: ContainedViewLayoutTransition, listViewTransaction:
        (ListViewUpdateSizeAndInsets, CGFloat, Bool) -> Void) {
        let transition: ContainedViewLayoutTransition
        if let _ = self.scheduledAnimateInAsOverlayFromNode {
            transition = .immediate
        } else {
            transition = protoTransition
        }
        
        self.scheduledLayoutTransitionRequest = nil
        if case .overlay = self.chatPresentationInterfaceState.mode {
            if self.backgroundEffectNode == nil {
                let backgroundEffectNode = ASDisplayNode()
                switch self.chatPresentationInterfaceState.theme.inAppNotification.expandedNotification.backgroundType {
                    case .light:
                        backgroundEffectNode.backgroundColor = UIColor(white: 1.0, alpha: 0.8)
                    case .dark:
                        backgroundEffectNode.backgroundColor = UIColor(white: 0.0, alpha: 0.8)
                }
                self.insertSubnode(backgroundEffectNode, at: 0)
                self.backgroundEffectNode = backgroundEffectNode
            }
            if self.scrollContainerNode == nil {
                let scrollContainerNode = ASScrollNode()
                scrollContainerNode.view.delaysContentTouches = false
                //scrollContainerNode.view.canCancelContentTouches = false
                //scrollContainerNode.view.panGestureRecognizer.cancelsTouchesInView = false
                scrollContainerNode.view.delegate = self
                scrollContainerNode.view.alwaysBounceVertical = true
                if #available(iOSApplicationExtension 11.0, *) {
                    scrollContainerNode.view.contentInsetAdjustmentBehavior = .never
                }
                self.insertSubnode(scrollContainerNode, aboveSubnode: self.backgroundEffectNode!)
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
                containerNode.addSubnode(self.historyNode)
                self.containerNode = containerNode
                self.scrollContainerNode?.addSubnode(containerNode)
                self.navigationBar.isHidden = true
            }
            if self.overlayNavigationBar == nil {
                let overlayNavigationBar = ChatOverlayNavigationBar(theme: self.chatPresentationInterfaceState.theme, close: { [weak self] in
                    self?.dismissAsOverlay()
                })
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
                self.insertSubnode(self.backgroundNode, at: 0)
                self.insertSubnode(self.historyNode, aboveSubnode: self.backgroundNode)
                self.navigationBar.isHidden = false
            }
            if let overlayNavigationBar = self.overlayNavigationBar {
                overlayNavigationBar.removeFromSupernode()
                self.overlayNavigationBar = nil
            }
        }
        
        var dismissedInputByDragging = false
        if let validLayout = self.validLayout {
            var wasDragging = false
            if validLayout.inputHeight != nil && validLayout.inputHeightIsInteractivellyChanging {
                wasDragging = true
            }
            if wasDragging {
                if layout.inputHeight == 0.0 && validLayout.inputHeightIsInteractivellyChanging && !layout.inputHeightIsInteractivellyChanging {
                    dismissedInputByDragging = true
                }
            }
        }
        self.validLayout = layout
        
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
        self.containerLayoutAndNavigationBarHeight = (layout, navigationBarHeight)
        
        let transitionIsAnimated: Bool
        if case .immediate = transition {
            transitionIsAnimated = false
        } else {
            transitionIsAnimated = true
        }
        
        if let _ = self.chatPresentationInterfaceState.search, let interfaceInteraction = self.interfaceInteraction {
            var activate = false
            if self.searchNavigationNode == nil {
                activate = true
                self.searchNavigationNode = ChatSearchNavigationContentNode(theme: self.chatPresentationInterfaceState.theme, strings: self.chatPresentationInterfaceState.strings, chatLocation: self.chatPresentationInterfaceState.chatLocation, interaction: interfaceInteraction)
            }
            self.navigationBar.setContentNode(self.searchNavigationNode, animated: transitionIsAnimated)
            self.searchNavigationNode?.update(presentationInterfaceState: self.chatPresentationInterfaceState)
            if activate {
                self.searchNavigationNode?.activate()
            }
        } else if let _ = self.searchNavigationNode {
            self.searchNavigationNode = nil
            self.navigationBar.setContentNode(nil, animated: transitionIsAnimated)
        }
        
        var dismissedTitleAccessoryPanelNode: ChatTitleAccessoryPanelNode?
        var immediatelyLayoutTitleAccessoryPanelNodeAndAnimateAppearance = false
        if let titleAccessoryPanelNode = titlePanelForChatPresentationInterfaceState(self.chatPresentationInterfaceState, account: self.account, currentPanel: self.titleAccessoryPanelNode, interfaceInteraction: self.interfaceInteraction) {
            if self.titleAccessoryPanelNode != titleAccessoryPanelNode {
                 dismissedTitleAccessoryPanelNode = self.titleAccessoryPanelNode
                self.titleAccessoryPanelNode = titleAccessoryPanelNode
                immediatelyLayoutTitleAccessoryPanelNodeAndAnimateAppearance = true
                self.titleAccessoryPanelContainer.addSubnode(titleAccessoryPanelNode)
            }
        } else if let titleAccessoryPanelNode = self.titleAccessoryPanelNode {
            dismissedTitleAccessoryPanelNode = titleAccessoryPanelNode
            self.titleAccessoryPanelNode = nil
        }
        
        var dismissedInputNode: ChatInputNode?
        var immediatelyLayoutInputNodeAndAnimateAppearance = false
        var inputNodeHeight: CGFloat?
        if let inputNode = inputNodeForChatPresentationIntefaceState(self.chatPresentationInterfaceState, account: self.account, currentNode: self.inputNode, interfaceInteraction: self.interfaceInteraction, inputMediaNode: self.inputMediaNode, controllerInteraction: self.controllerInteraction, inputPanelNode: self.inputPanelNode) {
            if let inputTextPanelNode = self.inputPanelNode as? ChatTextInputPanelNode {
                inputTextPanelNode.ensureUnfocused()
            }
            if let inputMediaNode = inputNode as? ChatMediaInputNode, self.inputMediaNode == nil {
                self.inputMediaNode = inputMediaNode
            }
            if self.inputNode != inputNode {
                dismissedInputNode = self.inputNode
                self.inputNode = inputNode
                inputNode.alpha = 1.0
                immediatelyLayoutInputNodeAndAnimateAppearance = true
                if let inputPanelNode = self.inputPanelNode, inputPanelNode.supernode != nil {
                    self.insertSubnode(inputNode, aboveSubnode: inputPanelNode)
                } else {
                    self.insertSubnode(inputNode, aboveSubnode: self.inputPanelBackgroundNode)
                }
            }
            inputNodeHeight = inputNode.updateLayout(width: layout.size.width, leftInset: layout.safeInsets.left, rightInset: layout.safeInsets.right, bottomInset: cleanInsets.bottom, transition: immediatelyLayoutInputNodeAndAnimateAppearance ? .immediate : transition, interfaceState: self.chatPresentationInterfaceState)
        } else if let inputNode = self.inputNode {
            dismissedInputNode = inputNode
            self.inputNode = nil
        }
        
        var insets: UIEdgeInsets
        if let inputNodeHeight = inputNodeHeight {
            insets = layout.insets(options: [])
            insets.bottom = max(inputNodeHeight, insets.bottom)
        } else {
            insets = layout.insets(options: [.input])
        }
        if case .overlay = self.chatPresentationInterfaceState.mode {
            insets.top = 44.0
        } else {
            insets.top += navigationBarHeight
        }
        
        var wrappingInsets = UIEdgeInsets()
        if case .overlay = self.chatPresentationInterfaceState.mode {
            wrappingInsets.left = 8.0 + layout.safeInsets.left
            wrappingInsets.right = 8.0 + layout.safeInsets.right
            wrappingInsets.top = 8.0
            if let statusBarHeight = layout.statusBarHeight, CGFloat(40.0).isLess(than: statusBarHeight) {
                wrappingInsets.top += statusBarHeight
            }
        }
        
        var dismissedInputPanelNode: ASDisplayNode?
        var dismissedAccessoryPanelNode: ASDisplayNode?
        var dismissedInputContextPanelNode: ChatInputContextPanelNode?
        var dismissedOverlayContextPanelNode: ChatInputContextPanelNode?
        
        var inputPanelSize: CGSize?
        var immediatelyLayoutInputPanelAndAnimateAppearance = false
        if let inputPanelNode = inputPanelForChatPresentationIntefaceState(self.chatPresentationInterfaceState, account: self.account, currentPanel: self.inputPanelNode, textInputPanelNode: self.textInputPanelNode, interfaceInteraction: self.interfaceInteraction) {
            if inputPanelNode !== self.inputPanelNode {
                if let inputTextPanelNode = self.inputPanelNode as? ChatTextInputPanelNode {
                    inputTextPanelNode.ensureUnfocused()
                }
                dismissedInputPanelNode = self.inputPanelNode
                immediatelyLayoutInputPanelAndAnimateAppearance = true
                let inputPanelHeight = inputPanelNode.updateLayout(width: layout.size.width, leftInset: layout.safeInsets.left, rightInset: layout.safeInsets.right, maxHeight: layout.size.height - insets.top - insets.bottom, transition: .immediate, interfaceState: self.chatPresentationInterfaceState)
                inputPanelSize = CGSize(width: layout.size.width, height: inputPanelHeight)
                self.inputPanelNode = inputPanelNode
                self.insertSubnode(inputPanelNode, aboveSubnode: self.inputPanelBackgroundNode)
            } else {
                let inputPanelHeight = inputPanelNode.updateLayout(width: layout.size.width, leftInset: layout.safeInsets.left, rightInset: layout.safeInsets.right, maxHeight: layout.size.height - insets.top - insets.bottom, transition: transition, interfaceState: self.chatPresentationInterfaceState)
                inputPanelSize = CGSize(width: layout.size.width, height: inputPanelHeight)
            }
        } else {
            dismissedInputPanelNode = self.inputPanelNode
            self.inputPanelNode = nil
        }
        
        if let inputMediaNode = self.inputMediaNode, inputMediaNode != self.inputNode {
            let _ = inputMediaNode.updateLayout(width: layout.size.width, leftInset: layout.safeInsets.left, rightInset: layout.safeInsets.right, bottomInset: cleanInsets.bottom, transition: .immediate, interfaceState: self.chatPresentationInterfaceState)
        }
        
        transition.updateFrame(node: self.titleAccessoryPanelContainer, frame: CGRect(origin: CGPoint(x: 0.0, y: insets.top), size: CGSize(width: layout.size.width, height: 56.0)))
        
        var titleAccessoryPanelFrame: CGRect?
        if let titleAccessoryPanelNode = self.titleAccessoryPanelNode {
            let panelHeight = titleAccessoryPanelNode.updateLayout(width: layout.size.width, leftInset: layout.safeInsets.left, rightInset: layout.safeInsets.right, transition: immediatelyLayoutTitleAccessoryPanelNodeAndAnimateAppearance ? .immediate : transition, interfaceState: self.chatPresentationInterfaceState)
            titleAccessoryPanelFrame = CGRect(origin: CGPoint(x: 0.0, y: 0.0), size: CGSize(width: layout.size.width, height: panelHeight))
            insets.top += panelHeight
        }
        
        var duration: Double = 0.0
        var curve: UInt = 0
        switch transition {
            case .immediate:
                break
            case let .animated(animationDuration, animationCurve):
                duration = animationDuration
                switch animationCurve {
                    case .easeInOut:
                        break
                    case .spring:
                        curve = 7
                }
        }
        
        let contentBounds = CGRect(x: 0.0, y: 0.0, width: layout.size.width - wrappingInsets.left - wrappingInsets.right, height: layout.size.height - wrappingInsets.top - wrappingInsets.bottom)
        
        if let backgroundEffectNode = self.backgroundEffectNode {
            transition.updateFrame(node: backgroundEffectNode, frame: CGRect(origin: CGPoint(), size: layout.size))
        }
        
        transition.updateFrame(node: self.backgroundNode, frame: contentBounds)
        transition.updateBounds(node: self.historyNode, bounds: CGRect(origin: CGPoint(), size: contentBounds.size))
        transition.updatePosition(node: self.historyNode, position: CGPoint(x: contentBounds.midX, y: contentBounds.midY))
        
        self.loadingNode.updateLayout(size: contentBounds.size, insets: insets, transition: transition)
        transition.updateFrame(node: self.loadingNode, frame: contentBounds)
        
        let listViewCurve: ListViewAnimationCurve
        if curve == 7 {
            listViewCurve = .Spring(duration: duration)
        } else {
            listViewCurve = .Default
        }
        
        var accessoryPanelSize: CGSize?
        var immediatelyLayoutAccessoryPanelAndAnimateAppearance = false
        if let accessoryPanelNode = accessoryPanelForChatPresentationIntefaceState(self.chatPresentationInterfaceState, account: self.account, currentPanel: self.accessoryPanelNode, interfaceInteraction: self.interfaceInteraction) {
            accessoryPanelSize = accessoryPanelNode.measure(CGSize(width: layout.size.width, height: layout.size.height))
            
            if accessoryPanelNode !== self.accessoryPanelNode {
                dismissedAccessoryPanelNode = self.accessoryPanelNode
                self.accessoryPanelNode = accessoryPanelNode
                
                if let inputPanelNode = self.inputPanelNode {
                    self.insertSubnode(accessoryPanelNode, belowSubnode: inputPanelNode)
                } else {
                    self.insertSubnode(accessoryPanelNode, aboveSubnode: self.navigateButtons)
                }
                
                accessoryPanelNode.dismiss = { [weak self, weak accessoryPanelNode] in
                    if let strongSelf = self, let accessoryPanelNode = accessoryPanelNode, strongSelf.accessoryPanelNode === accessoryPanelNode {
                        if let _ = accessoryPanelNode as? ReplyAccessoryPanelNode {
                            strongSelf.requestUpdateChatInterfaceState(true, { $0.withUpdatedReplyMessageId(nil) })
                        } else if let _ = accessoryPanelNode as? ForwardAccessoryPanelNode {
                            strongSelf.requestUpdateChatInterfaceState(true, { $0.withUpdatedForwardMessageIds(nil) })
                        } else if let _ = accessoryPanelNode as? EditAccessoryPanelNode {
                            strongSelf.requestUpdateChatInterfaceState(true, { $0.withUpdatedEditMessage(nil) })
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
        
        var immediatelyLayoutInputContextPanelAndAnimateAppearance = false
        if let inputContextPanelNode = inputContextPanelForChatPresentationIntefaceState(self.chatPresentationInterfaceState, account: self.account, currentPanel: self.inputContextPanelNode, interfaceInteraction: self.interfaceInteraction) {
            if inputContextPanelNode !== self.inputContextPanelNode {
                dismissedInputContextPanelNode = self.inputContextPanelNode
                self.inputContextPanelNode = inputContextPanelNode
                
                self.addSubnode(inputContextPanelNode)
                immediatelyLayoutInputContextPanelAndAnimateAppearance = true
            }
        } else if let inputContextPanelNode = self.inputContextPanelNode {
            dismissedInputContextPanelNode = inputContextPanelNode
            self.inputContextPanelNode = nil
        }
        
        var immediatelyLayoutOverlayContextPanelAndAnimateAppearance = false
        if let overlayContextPanelNode = chatOverlayContextPanelForChatPresentationIntefaceState(self.chatPresentationInterfaceState, account: self.account, currentPanel: self.overlayContextPanelNode, interfaceInteraction: self.interfaceInteraction) {
            if overlayContextPanelNode !== self.overlayContextPanelNode {
                dismissedOverlayContextPanelNode = self.overlayContextPanelNode
                self.overlayContextPanelNode = overlayContextPanelNode
                
                self.addSubnode(overlayContextPanelNode)
                immediatelyLayoutOverlayContextPanelAndAnimateAppearance = true
            }
        } else if let overlayContextPanelNode = self.overlayContextPanelNode {
            dismissedOverlayContextPanelNode = overlayContextPanelNode
            self.overlayContextPanelNode = nil
        }
        
        var inputPanelsHeight: CGFloat = 0.0
        
        var inputPanelFrame: CGRect?
        if self.inputPanelNode != nil {
            assert(inputPanelSize != nil)
            inputPanelFrame = CGRect(origin: CGPoint(x: 0.0, y: layout.size.height - insets.bottom - inputPanelsHeight - inputPanelSize!.height), size: CGSize(width: layout.size.width, height: inputPanelSize!.height))
            if self.dismissedAsOverlay {
                inputPanelFrame = inputPanelFrame!.offsetBy(dx: 0.0, dy: inputPanelsHeight + inputPanelSize!.height)
            }
            inputPanelsHeight += inputPanelSize!.height
        }
        
        var accessoryPanelFrame: CGRect?
        if self.accessoryPanelNode != nil {
            assert(accessoryPanelSize != nil)
            accessoryPanelFrame = CGRect(origin: CGPoint(x: 0.0, y: layout.size.height - insets.bottom - inputPanelsHeight - accessoryPanelSize!.height), size: CGSize(width: layout.size.width, height: accessoryPanelSize!.height))
            if self.dismissedAsOverlay {
                accessoryPanelFrame = accessoryPanelFrame!.offsetBy(dx: 0.0, dy: inputPanelsHeight + accessoryPanelSize!.height)
            }
            inputPanelsHeight += accessoryPanelSize!.height
        }
        
        if self.dismissedAsOverlay {
            inputPanelsHeight = 0.0
        }
        
        let inputBackgroundInset: CGFloat
        if cleanInsets.bottom < insets.bottom {
            inputBackgroundInset = 0.0
        } else {
            inputBackgroundInset = cleanInsets.bottom
        }
        
        let inputBackgroundFrame = CGRect(origin: CGPoint(x: 0.0, y: layout.size.height - insets.bottom - inputPanelsHeight), size: CGSize(width: layout.size.width, height: inputPanelsHeight + inputBackgroundInset))
        
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
            if let inputNodeHeight = inputNodeHeight {
                containerInsets = dismissAsOverlayLayout.insets(options: [])
                containerInsets.bottom = max(inputNodeHeight, insets.bottom)
            } else {
                containerInsets = dismissAsOverlayLayout.insets(options: [.input])
            }
        }
        
        if let containerNode = self.containerNode {
            contentBottomInset += 8.0
            let containerNodeFrame = CGRect(origin: CGPoint(x: wrappingInsets.left, y: wrappingInsets.top), size: CGSize(width: contentBounds.size.width, height: contentBounds.size.height - containerInsets.bottom - inputPanelsHeight - 8.0))
            transition.updateFrame(node: containerNode, frame: containerNodeFrame)
            
            if let containerBackgroundNode = self.containerBackgroundNode {
                transition.updateFrame(node: containerBackgroundNode, frame: CGRect(origin: CGPoint(x: containerNodeFrame.minX - 8.0, y: containerNodeFrame.minY - 8.0), size: CGSize(width: containerNodeFrame.size.width + 8.0 * 2.0, height: containerNodeFrame.size.height + 8.0 + 20.0)))
            }
        }
        
        if let overlayNavigationBar = self.overlayNavigationBar {
            let barFrame = CGRect(origin: CGPoint(), size: CGSize(width: contentBounds.size.width, height: 44.0))
            transition.updateFrame(node: overlayNavigationBar, frame: barFrame)
            overlayNavigationBar.updateLayout(size: barFrame.size, presentationInterfaceState: self.chatPresentationInterfaceState, transition: transition)
        }
        
        var listInsets = UIEdgeInsets(top: containerInsets.bottom + contentBottomInset, left: containerInsets.right, bottom: containerInsets.top, right: containerInsets.left)
        if case .standard = self.chatPresentationInterfaceState.mode {
            listInsets.left += layout.safeInsets.left
            listInsets.right += layout.safeInsets.right
        }
        
        listViewTransaction(ListViewUpdateSizeAndInsets(size: contentBounds.size, insets: listInsets, duration: duration, curve: listViewCurve), additionalScrollDistance, scrollToTop)
        
        let navigateButtonsSize = self.navigateButtons.updateLayout(transition: transition)
        var navigateButtonsFrame = CGRect(origin: CGPoint(x: layout.size.width - layout.safeInsets.right - navigateButtonsSize.width - 6.0, y: layout.size.height - containerInsets.bottom - inputPanelsHeight - navigateButtonsSize.height - 6.0), size: navigateButtonsSize)
        if case .overlay = self.chatPresentationInterfaceState.mode {
            navigateButtonsFrame = navigateButtonsFrame.offsetBy(dx: -8.0, dy: -8.0)
        }
        
        transition.updateFrame(node: self.inputPanelBackgroundNode, frame: inputBackgroundFrame)
        transition.updateFrame(node: self.inputPanelBackgroundSeparatorNode, frame: CGRect(origin: CGPoint(x: 0.0, y: inputBackgroundFrame.origin.y - UIScreenPixel), size: CGSize(width: inputBackgroundFrame.size.width, height: UIScreenPixel)))
        transition.updateFrame(node: self.navigateButtons, frame: navigateButtonsFrame)
        
        if let titleAccessoryPanelNode = self.titleAccessoryPanelNode, let titleAccessoryPanelFrame = titleAccessoryPanelFrame, !titleAccessoryPanelNode.frame.equalTo(titleAccessoryPanelFrame) {
            if immediatelyLayoutTitleAccessoryPanelNodeAndAnimateAppearance {
                titleAccessoryPanelNode.frame = titleAccessoryPanelFrame.offsetBy(dx: 0.0, dy: -titleAccessoryPanelFrame.size.height)
            }
            transition.updateFrame(node: titleAccessoryPanelNode, frame: titleAccessoryPanelFrame)
        }
        
        if let inputPanelNode = self.inputPanelNode, let inputPanelFrame = inputPanelFrame, !inputPanelNode.frame.equalTo(inputPanelFrame) {
            if immediatelyLayoutInputPanelAndAnimateAppearance {
                inputPanelNode.frame = inputPanelFrame.offsetBy(dx: 0.0, dy: inputPanelFrame.size.height)
                inputPanelNode.alpha = 0.0
            }
            
            transition.updateFrame(node: inputPanelNode, frame: inputPanelFrame)
            transition.updateAlpha(node: inputPanelNode, alpha: 1.0)
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
        
        let inputContextPanelsFrame = CGRect(origin: CGPoint(x: 0.0, y: insets.top), size: CGSize(width: layout.size.width, height: max(0.0, layout.size.height - insets.bottom - inputPanelsHeight - insets.top - UIScreenPixel)))
        let inputContextPanelsOverMainPanelFrame = CGRect(origin: CGPoint(x: 0.0, y: insets.top), size: CGSize(width: layout.size.width, height: max(0.0, layout.size.height - insets.bottom - (inputPanelSize == nil ? CGFloat(0.0) : inputPanelSize!.height) - insets.top - UIScreenPixel)))
        
        if let inputContextPanelNode = self.inputContextPanelNode {
            let panelFrame = inputContextPanelNode.placement == .overTextInput ? inputContextPanelsOverMainPanelFrame : inputContextPanelsFrame
            if immediatelyLayoutInputContextPanelAndAnimateAppearance {
                inputContextPanelNode.frame = panelFrame
                inputContextPanelNode.updateLayout(size: panelFrame.size, leftInset: layout.safeInsets.left, rightInset: layout.safeInsets.right, transition: .immediate, interfaceState: self.chatPresentationInterfaceState)
            } else if !inputContextPanelNode.frame.equalTo(panelFrame) {
                transition.updateFrame(node: inputContextPanelNode, frame: panelFrame)
                inputContextPanelNode.updateLayout(size: panelFrame.size, leftInset: layout.safeInsets.left, rightInset: layout.safeInsets.right, transition: transition, interfaceState: self.chatPresentationInterfaceState)
            }
        }
        
        if let overlayContextPanelNode = self.overlayContextPanelNode {
            let panelFrame = overlayContextPanelNode.placement == .overTextInput ? inputContextPanelsOverMainPanelFrame : inputContextPanelsFrame
            if immediatelyLayoutOverlayContextPanelAndAnimateAppearance {
                overlayContextPanelNode.frame = panelFrame
                overlayContextPanelNode.updateLayout(size: panelFrame.size, leftInset: layout.safeInsets.left, rightInset: layout.safeInsets.right, transition: .immediate, interfaceState: self.chatPresentationInterfaceState)
            } else if !overlayContextPanelNode.frame.equalTo(panelFrame) {
                transition.updateFrame(node: overlayContextPanelNode, frame: panelFrame)
                overlayContextPanelNode.updateLayout(size: panelFrame.size, leftInset: layout.safeInsets.left, rightInset: layout.safeInsets.right, transition: transition, interfaceState: self.chatPresentationInterfaceState)
            }
        }
        
        if let inputNode = self.inputNode, let inputNodeHeight = inputNodeHeight {
            let inputNodeFrame = CGRect(origin: CGPoint(x: 0.0, y: layout.size.height - inputNodeHeight), size: CGSize(width: layout.size.width, height: inputNodeHeight))
            if immediatelyLayoutInputNodeAndAnimateAppearance {
                var adjustedForPreviousInputHeightFrame = inputNodeFrame
                var heightDifference = inputNodeHeight - previousInputHeight
                if previousInputHeight.isLessThanOrEqualTo(cleanInsets.bottom) {
                    heightDifference = inputNodeHeight
                }
                adjustedForPreviousInputHeightFrame.origin.y += heightDifference
                inputNode.frame = adjustedForPreviousInputHeightFrame
                transition.updateFrame(node: inputNode, frame: inputNodeFrame)
            } else {
                transition.updateFrame(node: inputNode, frame: inputNodeFrame)
            }
        }
        
        if let dismissedTitleAccessoryPanelNode = dismissedTitleAccessoryPanelNode {
            var dismissedPanelFrame = dismissedTitleAccessoryPanelNode.frame
            dismissedPanelFrame.origin.y = -dismissedPanelFrame.size.height
            transition.updateFrame(node: dismissedTitleAccessoryPanelNode, frame: dismissedPanelFrame, completion: { [weak dismissedTitleAccessoryPanelNode] _ in
                dismissedTitleAccessoryPanelNode?.removeFromSupernode()
            })
        }
        
        if let dismissedInputPanelNode = dismissedInputPanelNode {
            var frameCompleted = false
            var alphaCompleted = false
            let completed = { [weak self, weak dismissedInputPanelNode] in
                if let strongSelf = self, let dismissedInputPanelNode = dismissedInputPanelNode, strongSelf.inputPanelNode === dismissedInputPanelNode {
                    return
                }
                if frameCompleted && alphaCompleted {
                    dismissedInputPanelNode?.removeFromSupernode()
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
        
        if let dismissedInputNode = dismissedInputNode {
            let targetY: CGFloat
            if cleanInsets.bottom.isLess(than: insets.bottom) {
                targetY = layout.size.height - insets.bottom
            } else {
                targetY = layout.size.height
            }
            transition.updateFrame(node: dismissedInputNode, frame: CGRect(origin: CGPoint(x: 0.0, y: targetY), size: CGSize(width: layout.size.width, height: max(insets.bottom, dismissedInputNode.bounds.size.height))), force: true, completion: { [weak self, weak dismissedInputNode] completed in
                if completed, let dismissedInputNode = dismissedInputNode {
                    if let strongSelf = self {
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
    }
    
    private func chatPresentationInterfaceStateRequiresInputFocus(_ state: ChatPresentationInterfaceState) -> Bool {
        switch state.inputMode {
            case .text:
                if state.interfaceState.selectionState != nil {
                    return false
                } else {
                    return true
                }
            default:
                return false
        }
    }
    
    func updateChatPresentationInterfaceState(_ chatPresentationInterfaceState: ChatPresentationInterfaceState, animated: Bool, interactive: Bool) {
        self.selectedMessages = chatPresentationInterfaceState.interfaceState.selectionState?.selectedIds
        
        if let textInputPanelNode = self.textInputPanelNode {
            self.chatPresentationInterfaceState = self.chatPresentationInterfaceState.updatedInterfaceState { $0.withUpdatedEffectiveInputState(textInputPanelNode.inputTextState) }
        }
        
        if self.chatPresentationInterfaceState != chatPresentationInterfaceState {
            let updatedInputFocus = self.chatPresentationInterfaceStateRequiresInputFocus(self.chatPresentationInterfaceState) != self.chatPresentationInterfaceStateRequiresInputFocus(chatPresentationInterfaceState)
            let updateInputTextState = self.chatPresentationInterfaceState.interfaceState.effectiveInputState != chatPresentationInterfaceState.interfaceState.effectiveInputState
            self.chatPresentationInterfaceState = chatPresentationInterfaceState
            
            self.navigateButtons.updateTheme(theme: chatPresentationInterfaceState.theme)
            
            let keepSendButtonEnabled = chatPresentationInterfaceState.interfaceState.forwardMessageIds != nil || chatPresentationInterfaceState.interfaceState.editMessage != nil
            var extendedSearchLayout = false
            loop: for (_, result) in chatPresentationInterfaceState.inputQueryResults {
                if case let .contextRequestResult(peer, _) = result, peer != nil {
                    extendedSearchLayout = true
                    break loop
                }
            }
            
            if let textInputPanelNode = self.textInputPanelNode, updateInputTextState {
                textInputPanelNode.updateInputTextState(chatPresentationInterfaceState.interfaceState.effectiveInputState, keepSendButtonEnabled: keepSendButtonEnabled, extendedSearchLayout: extendedSearchLayout, animated: animated)
            } else {
                textInputPanelNode?.updateKeepSendButtonEnabled(keepSendButtonEnabled: keepSendButtonEnabled, extendedSearchLayout: extendedSearchLayout, animated: animated)
            }
            
            let layoutTransition: ContainedViewLayoutTransition = animated ? .animated(duration: 0.4, curve: .spring) : .immediate
            
            if updatedInputFocus {
                if !self.ignoreUpdateHeight {
                    self.scheduleLayoutTransitionRequest(layoutTransition)
                }
                
                if self.chatPresentationInterfaceStateRequiresInputFocus(chatPresentationInterfaceState) {
                    self.ensureInputViewFocused()
                } else {
                    if let inputTextPanelNode = self.inputPanelNode as? ChatTextInputPanelNode {
                        inputTextPanelNode.ensureUnfocused()
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
        }
    }
    
    func updateAutomaticMediaDownloadSettings() {
        self.historyNode.forEachItemNode { itemNode in
            if let itemNode = itemNode as? ChatMessageItemView {
                itemNode.updateAutomaticMediaDownloadSettings()
            }
        }
    }
    
    func ensureInputViewFocused() {
        if let inputPanelNode = self.inputPanelNode as? ChatTextInputPanelNode {
            inputPanelNode.ensureFocused()
        }
    }
    
    @objc func tapGesture(_ recognizer: UITapGestureRecognizer) {
        if recognizer.state == .ended {
            self.dismissInput()
        }
    }
    
    func dismissInput() {
        switch self.chatPresentationInterfaceState.inputMode {
            case .none:
                break
            default:
                self.interfaceInteraction?.updateInputModeAndDismissedButtonKeyboardMessageId({ state in
                    return (.none, state.interfaceState.messageActionsState.closedButtonKeyboardMessageId)
                })
        }
        self.searchNavigationNode?.deactivate()
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
    
    func loadInputPanels(theme: PresentationTheme, strings: PresentationStrings) {
        if self.inputMediaNode == nil {
            let inputNode = ChatMediaInputNode(account: self.account, controllerInteraction: self.controllerInteraction, theme: theme, strings: strings, gifPaneIsActiveUpdated: { [weak self] value in
                if let strongSelf = self, let interfaceInteraction = strongSelf.interfaceInteraction {
                    interfaceInteraction.updateInputModeAndDismissedButtonKeyboardMessageId { state in
                        if case .media = state.inputMode {
                            if value {
                                return (.media(.gif), nil)
                            } else {
                                return (.media(.other), nil)
                            }
                        } else {
                            return (state.inputMode, nil)
                        }
                    }
                }
            })
            inputNode.interfaceInteraction = interfaceInteraction
            self.inputMediaNode = inputNode
            if let validLayout = self.validLayout {
                let _ = inputNode.updateLayout(width: validLayout.size.width, leftInset: validLayout.safeInsets.left, rightInset: validLayout.safeInsets.right, bottomInset: validLayout.intrinsicInsets.bottom, transition: .immediate, interfaceState: self.chatPresentationInterfaceState)
            }
        }
    }
    
    func currentInputPanelFrame() -> CGRect? {
        return self.inputPanelNode?.frame
    }
    
    var isTextInputPanelActive: Bool {
        return self.inputPanelNode is ChatTextInputPanelNode
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
                transition.animatePositionAdditive(node: self.backgroundNode, offset: -containerNode.bounds.size.height)
                transition.animatePositionAdditive(node: self.historyNode, offset: -containerNode.bounds.size.height)
                
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
            self.dismissAsOverlayLayout = self.validLayout
            
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
            if self.hapticFeedback == nil {
                self.hapticFeedback = HapticFeedback()
            }
            self.hapticFeedback?.prepareImpact()
        }
    }
    
    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        if let scrollContainerNode = self.scrollContainerNode, scrollView === scrollContainerNode.view {
            let dismissStatus = abs(scrollView.contentOffset.y) > 50.0
            if dismissStatus != self.scrollViewDismissStatus {
                self.scrollViewDismissStatus = dismissStatus
                if !self.dismissedAsOverlay {
                    self.hapticFeedback?.impact()
                }
            }
        }
    }
}
