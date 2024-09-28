import Foundation
import UIKit
import AsyncDisplayKit
import Display
import Postbox
import TelegramCore
import SwiftSignalKit
import TelegramPresentationData
import AccountContext
import AppBundle
import ChatPresentationInterfaceState
import ChatInputPanelNode
import ReactionSelectionNode
import EntityKeyboard
import TopMessageReactions

private final class ChatMessageSelectionInputPanelNodeViewForOverlayContent: UIView, ChatInputPanelViewForOverlayContent {
    var reactionContextNode: ReactionContextNode?
    var anchorRect: CGRect?
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        
        self.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(self.backgroundTapGesture(_:))))
    }
    
    required init(coder: NSCoder) {
        preconditionFailure()
    }
    
    @objc private func backgroundTapGesture(_ recognizer: UITapGestureRecognizer) {
        if case .ended = recognizer.state {
            self.dismissReactionSelection()
        }
    }
    
    func dismissReactionSelection() {
        if let reactionContextNode = self.reactionContextNode {
            self.reactionContextNode = nil
            reactionContextNode.animateOut(to: self.anchorRect, animatingOutToReaction: false)
            ContainedViewLayoutTransition.animated(duration: 0.25, curve: .easeInOut).updateAlpha(node: reactionContextNode, alpha: 0.0, completion: { [weak reactionContextNode] _ in
                reactionContextNode?.removeFromSupernode()
            })
        }
    }
    
    func maybeDismissContent(point: CGPoint) {
        if self.hitTest(point, with: nil) == self {
            self.dismissReactionSelection()
        }
    }
    
    override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        if let reactionContextNode = self.reactionContextNode {
            if let result = reactionContextNode.view.hitTest(self.convert(point, to: reactionContextNode.view), with: event) {
                return result
            }
            return self
        }
        return nil
    }
}

public final class ChatMessageSelectionInputPanelNode: ChatInputPanelNode {
    private let deleteButton: HighlightableButtonNode
    private let reportButton: HighlightableButtonNode
    private let forwardButton: HighlightableButtonNode
    private let shareButton: HighlightableButtonNode
    private let tagButton: HighlightableButtonNode
    private let tagEditButton: HighlightableButtonNode
    private let separatorNode: ASDisplayNode
    
    private let reactionOverlayContainer: ChatMessageSelectionInputPanelNodeViewForOverlayContent
    
    private var validLayout: (width: CGFloat, leftInset: CGFloat, rightInset: CGFloat, bottomInset: CGFloat, additionalSideInsets: UIEdgeInsets, maxHeight: CGFloat, metrics: LayoutMetrics, isSecondary: Bool, isMediaInputExpanded: Bool)?
    private var presentationInterfaceState: ChatPresentationInterfaceState?
    private var actions: ChatAvailableMessageActions?
    
    private var theme: PresentationTheme
    private let peerMedia: Bool
    
    private let canDeleteMessagesDisposable = MetaDisposable()
    
    public var selectedMessages = Set<MessageId>() {
        didSet {
            if oldValue != self.selectedMessages {
                self.updateActions()
            }
        }
    }
    
    public init(theme: PresentationTheme, strings: PresentationStrings, peerMedia: Bool = false) {
        self.theme = theme
        self.peerMedia = peerMedia
        
        self.deleteButton = HighlightableButtonNode(pointerStyle: .rectangle(CGSize(width: 56.0, height: 40.0)))
        self.deleteButton.isEnabled = false
        self.deleteButton.isAccessibilityElement = true
        self.deleteButton.accessibilityLabel = strings.VoiceOver_MessageContextDelete
        
        self.reportButton = HighlightableButtonNode(pointerStyle: .rectangle(CGSize(width: 56.0, height: 40.0)))
        self.reportButton.isEnabled = false
        self.reportButton.isAccessibilityElement = true
        self.reportButton.accessibilityLabel = strings.VoiceOver_MessageContextReport
        
        self.forwardButton = HighlightableButtonNode(pointerStyle: .rectangle(CGSize(width: 56.0, height: 40.0)))
        self.forwardButton.isAccessibilityElement = true
        self.forwardButton.accessibilityLabel = strings.VoiceOver_MessageContextForward
        
        self.shareButton = HighlightableButtonNode(pointerStyle: .rectangle(CGSize(width: 56.0, height: 40.0)))
        self.shareButton.isAccessibilityElement = true
        self.shareButton.accessibilityLabel = strings.VoiceOver_MessageContextShare
        
        self.tagButton = HighlightableButtonNode(pointerStyle: .rectangle(CGSize(width: 56.0, height: 40.0)))
        self.tagButton.isAccessibilityElement = true
        self.tagButton.accessibilityLabel = strings.VoiceOver_MessageSelectionButtonTag
        
        self.tagEditButton = HighlightableButtonNode(pointerStyle: .rectangle(CGSize(width: 56.0, height: 40.0)))
        self.tagEditButton.isAccessibilityElement = true
        self.tagEditButton.accessibilityLabel = strings.VoiceOver_MessageSelectionButtonTag
        
        self.deleteButton.setImage(generateTintedImage(image: UIImage(bundleImageName: "Chat/Input/Accessory Panels/MessageSelectionTrash"), color: theme.chat.inputPanel.panelControlAccentColor), for: [.normal])
        self.deleteButton.setImage(generateTintedImage(image: UIImage(bundleImageName: "Chat/Input/Accessory Panels/MessageSelectionTrash"), color: theme.chat.inputPanel.panelControlDisabledColor), for: [.disabled])
        self.reportButton.setImage(generateTintedImage(image: UIImage(bundleImageName: "Chat/Input/Accessory Panels/MessageSelectionReport"), color: theme.chat.inputPanel.panelControlAccentColor), for: [.normal])
        self.reportButton.setImage(generateTintedImage(image: UIImage(bundleImageName: "Chat/Input/Accessory Panels/MessageSelectionReport"), color: theme.chat.inputPanel.panelControlDisabledColor), for: [.disabled])
        self.forwardButton.setImage(generateTintedImage(image: UIImage(bundleImageName: "Chat/Input/Accessory Panels/MessageSelectionForward"), color: theme.chat.inputPanel.panelControlAccentColor), for: [.normal])
        self.forwardButton.setImage(generateTintedImage(image: UIImage(bundleImageName: "Chat/Input/Accessory Panels/MessageSelectionForward"), color: theme.chat.inputPanel.panelControlDisabledColor), for: [.disabled])
        self.shareButton.setImage(generateTintedImage(image: UIImage(bundleImageName: "Chat/Input/Accessory Panels/MessageSelectionAction"), color: theme.chat.inputPanel.panelControlAccentColor), for: [.normal])
        self.shareButton.setImage(generateTintedImage(image: UIImage(bundleImageName: "Chat/Input/Accessory Panels/MessageSelectionAction"), color: theme.chat.inputPanel.panelControlDisabledColor), for: [.disabled])
        self.tagButton.setImage(generateTintedImage(image: UIImage(bundleImageName: "Chat/Input/Accessory Panels/TagIcon"), color: theme.chat.inputPanel.panelControlAccentColor), for: [.normal])
        self.tagEditButton.setImage(generateTintedImage(image: UIImage(bundleImageName: "Chat/Input/Accessory Panels/TagEditIcon"), color: theme.chat.inputPanel.panelControlAccentColor), for: [.normal])
        
        self.separatorNode = ASDisplayNode()
        self.separatorNode.backgroundColor = theme.chat.inputPanel.panelSeparatorColor
        
        self.reactionOverlayContainer = ChatMessageSelectionInputPanelNodeViewForOverlayContent()
        
        super.init()
        
        self.addSubnode(self.deleteButton)
        self.addSubnode(self.reportButton)
        self.addSubnode(self.forwardButton)
        self.addSubnode(self.shareButton)
        self.addSubnode(self.tagButton)
        self.addSubnode(self.tagEditButton)
        self.addSubnode(self.separatorNode)
        
        self.viewForOverlayContent = self.reactionOverlayContainer
        
        self.forwardButton.isImplicitlyDisabled = true
        self.shareButton.isImplicitlyDisabled = true
        
        self.deleteButton.addTarget(self, action: #selector(self.deleteButtonPressed), forControlEvents: .touchUpInside)
        self.reportButton.addTarget(self, action: #selector(self.reportButtonPressed), forControlEvents: .touchUpInside)
        self.forwardButton.addTarget(self, action: #selector(self.forwardButtonPressed), forControlEvents: .touchUpInside)
        self.shareButton.addTarget(self, action: #selector(self.shareButtonPressed), forControlEvents: .touchUpInside)
        self.tagButton.addTarget(self, action: #selector(self.tagButtonPressed), forControlEvents: .touchUpInside)
        self.tagEditButton.addTarget(self, action: #selector(self.tagButtonPressed), forControlEvents: .touchUpInside)
    }
    
    deinit {
        self.canDeleteMessagesDisposable.dispose()
    }
    
    private func updateActions() {
        self.forwardButton.isEnabled = self.selectedMessages.count != 0
        
        if self.selectedMessages.isEmpty {
            self.actions = nil
            if let (width, leftInset, rightInset, bottomInset, additionalSideInsets, maxHeight, metrics, isSecondary, isMediaInputExpanded) = self.validLayout, let interfaceState = self.presentationInterfaceState {
                let _ = self.updateLayout(width: width, leftInset: leftInset, rightInset: rightInset, bottomInset: bottomInset, additionalSideInsets: additionalSideInsets, maxHeight: maxHeight, isSecondary: isSecondary, transition: .immediate, interfaceState: interfaceState, metrics: metrics, isMediaInputExpanded: isMediaInputExpanded)
            }
            self.canDeleteMessagesDisposable.set(nil)
        } else if let context = self.context {
            self.canDeleteMessagesDisposable.set((context.sharedContext.chatAvailableMessageActions(engine: context.engine, accountPeerId: context.account.peerId, messageIds: self.selectedMessages, keepUpdated: true)
            |> deliverOnMainQueue).startStrict(next: { [weak self] actions in
                if let strongSelf = self {
                    strongSelf.actions = actions
                    if let (width, leftInset, rightInset, bottomInset, additionalSideInsets, maxHeight, metrics, isSecondary, isMediaInputExpanded) = strongSelf.validLayout, let interfaceState = strongSelf.presentationInterfaceState {
                        let _ = strongSelf.updateLayout(width: width, leftInset: leftInset, rightInset: rightInset, bottomInset: bottomInset, additionalSideInsets: additionalSideInsets, maxHeight: maxHeight, isSecondary: isSecondary, transition: .immediate, interfaceState: interfaceState, metrics: metrics, isMediaInputExpanded: isMediaInputExpanded)
                    }
                }
            }))
        }
    }
    
    public func updateTheme(theme: PresentationTheme) {
        if self.theme !== theme {
            self.theme = theme
            
            self.deleteButton.setImage(generateTintedImage(image: UIImage(bundleImageName: "Chat/Input/Accessory Panels/MessageSelectionTrash"), color: theme.chat.inputPanel.panelControlAccentColor), for: [.normal])
            self.deleteButton.setImage(generateTintedImage(image: UIImage(bundleImageName: "Chat/Input/Accessory Panels/MessageSelectionTrash"), color: theme.chat.inputPanel.panelControlDisabledColor), for: [.disabled])
            self.reportButton.setImage(generateTintedImage(image: UIImage(bundleImageName: "Chat/Input/Accessory Panels/MessageSelectionReport"), color: theme.chat.inputPanel.panelControlAccentColor), for: [.normal])
            self.reportButton.setImage(generateTintedImage(image: UIImage(bundleImageName: "Chat/Input/Accessory Panels/MessageSelectionReport"), color: theme.chat.inputPanel.panelControlDisabledColor), for: [.disabled])
            self.forwardButton.setImage(generateTintedImage(image: UIImage(bundleImageName: "Chat/Input/Accessory Panels/MessageSelectionForward"), color: theme.chat.inputPanel.panelControlAccentColor), for: [.normal])
            self.forwardButton.setImage(generateTintedImage(image: UIImage(bundleImageName: "Chat/Input/Accessory Panels/MessageSelectionForward"), color: theme.chat.inputPanel.panelControlDisabledColor), for: [.disabled])
            self.shareButton.setImage(generateTintedImage(image: UIImage(bundleImageName: "Chat/Input/Accessory Panels/MessageSelectionAction"), color: theme.chat.inputPanel.panelControlAccentColor), for: [.normal])
            self.shareButton.setImage(generateTintedImage(image: UIImage(bundleImageName: "Chat/Input/Accessory Panels/MessageSelectionAction"), color: theme.chat.inputPanel.panelControlDisabledColor), for: [.disabled])
            self.tagButton.setImage(generateTintedImage(image: UIImage(bundleImageName: "Chat/Input/Accessory Panels/WebpageIcon"), color: theme.chat.inputPanel.panelControlAccentColor), for: [.normal])
            self.tagEditButton.setImage(generateTintedImage(image: UIImage(bundleImageName: "Chat/Input/Accessory Panels/LinkSettingsIcon"), color: theme.chat.inputPanel.panelControlAccentColor), for: [.normal])
            
            self.separatorNode.backgroundColor = theme.chat.inputPanel.panelSeparatorColor
        }
    }
    
    @objc private func deleteButtonPressed() {
        self.interfaceInteraction?.deleteSelectedMessages()
    }
    
    @objc private func reportButtonPressed() {
        self.interfaceInteraction?.reportSelectedMessages()
    }
    
    @objc private func forwardButtonPressed() {
        if let _ = self.presentationInterfaceState?.renderedPeer?.peer as? TelegramSecretChat {
            return
        }
        if let actions = self.actions, actions.isCopyProtected {
            self.interfaceInteraction?.displayCopyProtectionTip(self.forwardButton, false)
        } else if !self.forwardButton.isImplicitlyDisabled {
            self.interfaceInteraction?.forwardSelectedMessages()
        }
    }
    
    @objc private func shareButtonPressed() {
        if let _ = self.presentationInterfaceState?.renderedPeer?.peer as? TelegramSecretChat {
            return
        }
        if let actions = self.actions, actions.isCopyProtected {
            self.interfaceInteraction?.displayCopyProtectionTip(self.shareButton, true)
        } else if !self.shareButton.isImplicitlyDisabled {
            self.interfaceInteraction?.shareSelectedMessages()
        }
    }
    
    @objc private func tagButtonPressed() {
        guard let context = self.context else {
            return
        }
        
        if self.reactionOverlayContainer.reactionContextNode != nil {
            return
        }
        
        let reactionItems: Signal<[ReactionItem], NoError> = tagMessageReactions(context: context, subPeerId: self.presentationInterfaceState?.chatLocation.threadId.flatMap(EnginePeer.Id.init))
        
        let _ = (reactionItems
        |> take(1)
        |> deliverOnMainQueue).start(next: { [weak self] reactionItems in
            guard let self, let actions = self.actions, let context = self.context else {
                return
            }
            
            let presentationData = context.sharedContext.currentPresentationData.with { $0 }
            
            let reactionContextNode = ReactionContextNode(
                context: context,
                animationCache: context.animationCache,
                presentationData: presentationData,
                items: reactionItems.map { ReactionContextItem.reaction(item: $0, icon: .none) },
                selectedItems: actions.editTags,
                title: actions.editTags.isEmpty ? presentationData.strings.Chat_ReactionSelectionTitleAddTag : presentationData.strings.Chat_ReactionSelectionTitleEditTag,
                reactionsLocked: false,
                alwaysAllowPremiumReactions: false,
                allPresetReactionsAreAvailable: true,
                getEmojiContent: { animationCache, animationRenderer in
                    let mappedReactionItems: [EmojiComponentReactionItem] = reactionItems.map { reaction -> EmojiComponentReactionItem in
                        return EmojiComponentReactionItem(reaction: reaction.reaction.rawValue, file: reaction.stillAnimation)
                    }
                    
                    return EmojiPagerContentComponent.emojiInputData(
                        context: context,
                        animationCache: animationCache,
                        animationRenderer: animationRenderer,
                        isStandalone: false,
                        subject: .messageTag,
                        hasTrending: false,
                        topReactionItems: mappedReactionItems,
                        areUnicodeEmojiEnabled: false,
                        areCustomEmojiEnabled: true,
                        chatPeerId: context.account.peerId,
                        selectedItems: Set(),
                        premiumIfSavedMessages: false
                    )
                },
                isExpandedUpdated: { [weak self] transition in
                    guard let self else {
                        return
                    }
                    self.update(transition: transition)
                },
                requestLayout: { [weak self] transition in
                    guard let self else {
                        return
                    }
                    self.update(transition: transition)
                },
                requestUpdateOverlayWantsToBeBelowKeyboard: { [weak self] transition in
                    guard let self else {
                        return
                    }
                    self.update(transition: transition)
                }
            )
            reactionContextNode.reactionSelected = { [weak self] updateReaction, _ in
                guard let self, let context = self.context, let presentationInterfaceState = self.presentationInterfaceState, let actions = self.actions else {
                    return
                }
                
                self.interfaceInteraction?.cancelMessageSelection(.animated(duration: 0.4, curve: .spring))
                
                if actions.editTags.contains(updateReaction.reaction) {
                    var reactions = actions.editTags
                    reactions.remove(updateReaction.reaction)
                    let mappedUpdatedReactions = reactions.map { reaction -> UpdateMessageReaction in
                        switch reaction {
                        case let .builtin(value):
                            return .builtin(value)
                        case let .custom(fileId):
                            return .custom(fileId: fileId, file: nil)
                        case .stars:
                            return .stars
                        }
                    }
                    if let selectionState = presentationInterfaceState.interfaceState.selectionState {
                        context.engine.messages.setMessageReactions(ids: Array(selectionState.selectedIds), reactions: mappedUpdatedReactions)
                    } else {
                        context.engine.messages.setMessageReactions(ids: Array(self.selectedMessages), reactions: mappedUpdatedReactions)
                    }
                } else {
                    if let selectionState = presentationInterfaceState.interfaceState.selectionState {
                        context.engine.messages.addMessageReactions(ids: Array(selectionState.selectedIds), reactions: [updateReaction])
                    } else {
                        context.engine.messages.addMessageReactions(ids: Array(self.selectedMessages), reactions: [updateReaction])
                    }
                }
                
                self.reactionOverlayContainer.dismissReactionSelection()
            }
            reactionContextNode.displayTail = true
            reactionContextNode.forceTailToRight = true
            reactionContextNode.forceDark = false
            self.reactionOverlayContainer.reactionContextNode = reactionContextNode
            self.reactionOverlayContainer.addSubnode(reactionContextNode)
            
            self.update(transition: .immediate)
        })
    }
    
    private func update(transition: ContainedViewLayoutTransition) {
        if let (width, leftInset, rightInset, bottomInset, additionalSideInsets, maxHeight, metrics, isSecondary, isMediaInputExpanded) = self.validLayout, let interfaceState = self.presentationInterfaceState {
            let _ = self.updateLayout(width: width, leftInset: leftInset, rightInset: rightInset, bottomInset: bottomInset, additionalSideInsets: additionalSideInsets, maxHeight: maxHeight, isSecondary: isSecondary, transition: transition, interfaceState: interfaceState, metrics: metrics, isMediaInputExpanded: isMediaInputExpanded)
        }
    }
    
    override public func updateLayout(width: CGFloat, leftInset: CGFloat, rightInset: CGFloat, bottomInset: CGFloat, additionalSideInsets: UIEdgeInsets, maxHeight: CGFloat, isSecondary: Bool, transition: ContainedViewLayoutTransition, interfaceState: ChatPresentationInterfaceState, metrics: LayoutMetrics, isMediaInputExpanded: Bool) -> CGFloat {
        self.validLayout = (width, leftInset, rightInset, bottomInset, additionalSideInsets, maxHeight, metrics, isSecondary, isMediaInputExpanded)
        
        let panelHeight = defaultHeight(metrics: metrics)
        
        if self.presentationInterfaceState != interfaceState {
            self.presentationInterfaceState = interfaceState
        }
        if let actions = self.actions {
            self.deleteButton.isEnabled = false
            self.reportButton.isEnabled = false
            self.forwardButton.isImplicitlyDisabled = !actions.options.contains(.forward)
            
            if self.peerMedia {
                self.deleteButton.isEnabled = !actions.options.intersection([.deleteLocally, .deleteGlobally]).isEmpty
            } else {
                self.deleteButton.isEnabled = !actions.disableDelete
            }
            self.shareButton.isImplicitlyDisabled = actions.options.intersection(.forward).isEmpty || actions.options.intersection(.externalShare).isEmpty
            self.reportButton.isEnabled = !actions.options.intersection([.report]).isEmpty
            
            if self.peerMedia {
                self.deleteButton.isHidden = !self.deleteButton.isEnabled
            } else {
                self.deleteButton.isHidden = false
            }
            self.reportButton.isHidden = !self.reportButton.isEnabled
            
            if actions.setTag {
                if !actions.editTags.isEmpty {
                    self.tagButton.isHidden = true
                    self.tagEditButton.isHidden = false
                } else {
                    self.tagButton.isHidden = false
                    self.tagEditButton.isHidden = true
                }   
            } else {
                self.tagButton.isHidden = true
                self.tagEditButton.isHidden = true
            }
        } else {
            self.deleteButton.isEnabled = false
            self.deleteButton.isHidden = self.peerMedia
            self.reportButton.isEnabled = false
            self.reportButton.isHidden = true
            self.forwardButton.isImplicitlyDisabled = true
            self.shareButton.isImplicitlyDisabled = true
            self.tagButton.isHidden = true
            self.tagEditButton.isHidden = true
            self.tagButton.isHidden = true
            self.tagEditButton.isHidden = true
        }
        
        if self.reportButton.isHidden || (self.peerMedia && self.deleteButton.isHidden && self.reportButton.isHidden) {
            if let peer = interfaceState.renderedPeer?.peer as? TelegramChannel, case .broadcast = peer.info {
                self.reportButton.isHidden = false
            } else if self.peerMedia {
                self.deleteButton.isHidden = false
            }
        }
        
        var width = width
        if additionalSideInsets.right > 0.0 {
            width -= additionalSideInsets.right
        }
        
        var tagButton: HighlightableButtonNode?
        if !self.tagButton.isHidden {
            tagButton = self.tagButton
        } else if !self.tagEditButton.isHidden {
            tagButton = self.tagEditButton
        }
        
        let buttons: [HighlightableButtonNode]
        if self.reportButton.isHidden {
            if let tagButton {
                buttons = [
                    self.deleteButton,
                    tagButton,
                    self.forwardButton,
                    self.shareButton
                ]
            } else {
                buttons = [
                    self.deleteButton,
                    self.shareButton,
                    self.forwardButton
                ]
            }
        } else if !self.deleteButton.isHidden {
            if let tagButton {
                buttons = [
                    self.deleteButton,
                    self.reportButton,
                    tagButton,
                    self.shareButton,
                    self.forwardButton
                ]
            } else {
                buttons = [
                    self.deleteButton,
                    self.reportButton,
                    self.shareButton,
                    self.forwardButton
                ]
            }
        } else {
            if let tagButton {
                buttons = [
                    self.deleteButton,
                    self.reportButton,
                    tagButton,
                    self.shareButton,
                    self.forwardButton
                ]
            } else {
                buttons = [
                    self.deleteButton,
                    self.reportButton,
                    self.shareButton,
                    self.forwardButton
                ]
            }
        }
        
        let buttonSize = CGSize(width: 57.0, height: panelHeight)
        
        let availableWidth = width - leftInset - rightInset
        let spacing: CGFloat = floor((availableWidth - buttonSize.width * CGFloat(buttons.count)) / CGFloat(buttons.count - 1))
        var offset: CGFloat = leftInset
        for i in 0 ..< buttons.count {
            let button = buttons[i]
            if i == buttons.count - 1 {
                button.frame = CGRect(origin: CGPoint(x: width - rightInset - buttonSize.width, y: 0.0), size: buttonSize)
            } else {
                button.frame = CGRect(origin: CGPoint(x: offset, y: 0.0), size: buttonSize)
            }
            offset += buttonSize.width + spacing
        }
        
        transition.updateAlpha(node: self.separatorNode, alpha: isSecondary ? 1.0 : 0.0)
        self.separatorNode.frame = CGRect(origin: CGPoint(x: 0.0, y: panelHeight), size: CGSize(width: width, height: UIScreenPixel))
        
        if let reactionContextNode = self.reactionOverlayContainer.reactionContextNode, let tagButton {
            let isFirstTime = reactionContextNode.bounds.isEmpty
            
            let size = CGSize(width: width, height: maxHeight)
            let reactionsAnchorRect = tagButton.frame.offsetBy(dx: -54.0, dy: -(panelHeight - size.height) + 14.0)
            transition.updateFrame(node: reactionContextNode, frame: CGRect(origin: CGPoint(x: 0.0, y: panelHeight - size.height), size: size))
            reactionContextNode.updateLayout(size: size, insets: UIEdgeInsets(), anchorRect: reactionsAnchorRect, centerAligned: true, isCoveredByInput: false, isAnimatingOut: false, transition: transition)
            reactionContextNode.updateIsIntersectingContent(isIntersectingContent: true, transition: .immediate)
            if isFirstTime {
                reactionContextNode.animateIn(from: reactionsAnchorRect)
            }
        }
        
        return panelHeight
    }
    
    override public func minimalHeight(interfaceState: ChatPresentationInterfaceState, metrics: LayoutMetrics) -> CGFloat {
        return defaultHeight(metrics: metrics)
    }
}
