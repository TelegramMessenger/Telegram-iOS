import Foundation
import UIKit
import Display
import AsyncDisplayKit
import TelegramPresentationData
import ChatPresentationInterfaceState
import AccountContext
import ComponentFlow
import MultilineTextComponent
import PlainButtonComponent
import TelegramCore
import Postbox
import EmojiStatusComponent
import SwiftSignalKit
import BundleIconComponent
import AvatarNode
import TextBadgeComponent
import ChatSideTopicsPanel
import ComponentDisplayAdapters

final class ChatTopicListTitleAccessoryPanelNode: ChatTitleAccessoryPanelNode, ChatControllerCustomNavigationPanelNode {
    private struct Params: Equatable {
        var width: CGFloat
        var leftInset: CGFloat
        var rightInset: CGFloat
        var interfaceState: ChatPresentationInterfaceState
        
        init(width: CGFloat, leftInset: CGFloat, rightInset: CGFloat, interfaceState: ChatPresentationInterfaceState) {
            self.width = width
            self.leftInset = leftInset
            self.rightInset = rightInset
            self.interfaceState = interfaceState
        }
        
        static func ==(lhs: Params, rhs: Params) -> Bool {
            if lhs.width != rhs.width {
                return false
            }
            if lhs.leftInset != rhs.leftInset {
                return false
            }
            if lhs.rightInset != rhs.rightInset {
                return false
            }
            if lhs.interfaceState != rhs.interfaceState {
                return false
            }
            return true
        }
    }
    
    /*private final class ItemView: UIView {
        private let context: AccountContext
        private let action: () -> Void
        
        private let extractedContainerNode: ContextExtractedContentContainingNode
        private let containerNode: ContextControllerSourceNode
        
        private let containerButton: HighlightTrackingButton
        
        private var icon: ComponentView<Empty>?
        private var avatarNode: AvatarNode?
        private let title = ComponentView<Empty>()
        private var badge: ComponentView<Empty>?
        
        init(context: AccountContext, action: @escaping (() -> Void), contextGesture: @escaping (ContextGesture, ContextExtractedContentContainingNode) -> Void) {
            self.context = context
            self.action = action
            
            self.extractedContainerNode = ContextExtractedContentContainingNode()
            self.containerNode = ContextControllerSourceNode()
            
            self.containerButton = HighlightTrackingButton()
            
            super.init(frame: CGRect())
            
            self.extractedContainerNode.contentNode.view.addSubview(self.containerButton)
            
            self.containerNode.addSubnode(self.extractedContainerNode)
            self.containerNode.targetNodeForActivationProgress = self.extractedContainerNode.contentNode
            self.addSubview(self.containerNode.view)
            
            self.containerButton.addTarget(self, action: #selector(self.pressed), for: .touchUpInside)
            self.containerButton.highligthedChanged = { [weak self] highlighted in
                if let self, self.bounds.width > 0.0 {
                    let topScale: CGFloat = (self.bounds.width - 1.0) / self.bounds.width
                    let maxScale: CGFloat = (self.bounds.width + 1.0) / self.bounds.width
                    
                    if highlighted {
                        self.layer.removeAnimation(forKey: "opacity")
                        self.layer.removeAnimation(forKey: "sublayerTransform")
                        let transition: ContainedViewLayoutTransition = .animated(duration: 0.2, curve: .easeInOut)
                        transition.updateTransformScale(layer: self.layer, scale: topScale)
                    } else {
                        let transition: ContainedViewLayoutTransition = .immediate
                        transition.updateTransformScale(layer: self.layer, scale: 1.0)
                        
                        self.layer.animateScale(from: topScale, to: maxScale, duration: 0.13, timingFunction: CAMediaTimingFunctionName.easeOut.rawValue, removeOnCompletion: false, completion: { [weak self] _ in
                            guard let self else {
                                return
                            }
                            
                            self.layer.animateScale(from: maxScale, to: 1.0, duration: 0.1, timingFunction: CAMediaTimingFunctionName.easeIn.rawValue)
                        })
                    }
                }
            }
            
            self.containerNode.isGestureEnabled = false
        }
        
        required init?(coder: NSCoder) {
            preconditionFailure()
        }
        
        @objc private func pressed() {
            self.action()
        }
        
        override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
            var mappedPoint = point
            if self.bounds.insetBy(dx: -8.0, dy: -4.0).contains(point) {
                mappedPoint = self.bounds.center
            }
            return super.hitTest(mappedPoint, with: event)
        }
        
        func update(context: AccountContext, item: Item, isSelected: Bool, theme: PresentationTheme, height: CGFloat, transition: ComponentTransition) -> CGSize {
            let alphaTransition: ComponentTransition = transition.animation.isImmediate ? .immediate : .easeInOut(duration: 0.25)
            
            let spacing: CGFloat = 3.0
            let badgeSpacing: CGFloat = 4.0
            
            let iconSize = CGSize(width: 18.0, height: 18.0)
            
            var avatarIconContent: EmojiStatusComponent.Content?
            if case let .forum(topicId) = item.item.id {
                if topicId != 1, let threadData = item.item.threadData {
                    if let fileId = threadData.info.icon, fileId != 0 {
                        avatarIconContent = .animation(content: .customEmoji(fileId: fileId), size: iconSize, placeholderColor: theme.list.mediaPlaceholderColor, themeColor: theme.list.itemAccentColor, loopMode: .count(0))
                    } else {
                        avatarIconContent = .topic(title: String(threadData.info.title.prefix(1)), color: threadData.info.iconColor, size: iconSize)
                    }
                } else {
                    avatarIconContent = .image(image: PresentationResourcesChatList.generalTopicIcon(theme), tintColor: theme.rootController.navigationBar.secondaryTextColor)
                }
            }
            
            if let avatarIconContent {
                let avatarIconComponent = EmojiStatusComponent(
                    context: context,
                    animationCache: context.animationCache,
                    animationRenderer: context.animationRenderer,
                    content: avatarIconContent,
                    isVisibleForAnimations: false,
                    action: nil
                )
                let icon: ComponentView<Empty>
                if let current = self.icon {
                    icon = current
                } else {
                    icon = ComponentView()
                    self.icon = icon
                }
                let _ = icon.update(
                    transition: .immediate,
                    component: AnyComponent(avatarIconComponent),
                    environment: {},
                    containerSize: CGSize(width: 18.0, height: 18.0)
                )
            } else if let icon = self.icon {
                self.icon = nil
                icon.view?.removeFromSuperview()
            }
            
            let titleText: String
            if case let .forum(topicId) = item.item.id {
                let _ = topicId
                if let threadData = item.item.threadData {
                    titleText = threadData.info.title
                } else {
                    //TODO:localize
                    titleText = "General"
                }
            } else {
                titleText = item.item.renderedPeer.chatMainPeer?.compactDisplayTitle ?? " "
            }
            let titleSize = self.title.update(
                transition: .immediate,
                component: AnyComponent(MultilineTextComponent(
                    text: .plain(NSAttributedString(string: titleText, font: Font.medium(14.0), textColor: isSelected ? theme.rootController.navigationBar.accentTextColor : theme.rootController.navigationBar.secondaryTextColor))
                )),
                environment: {},
                containerSize: CGSize(width: 100.0, height: 100.0)
            )
            
            var badgeSize: CGSize?
            if let readCounters = item.item.readCounters, readCounters.count > 0 {
                let badge: ComponentView<Empty>
                var badgeTransition = transition
                if let current = self.badge {
                    badge = current
                } else {
                    badgeTransition = .immediate
                    badge = ComponentView<Empty>()
                    self.badge = badge
                }
                
                badgeSize = badge.update(
                    transition: badgeTransition,
                    component: AnyComponent(TextBadgeComponent(
                        text: countString(Int64(readCounters.count)),
                        font: Font.regular(12.0),
                        background: item.item.isMuted ? theme.chatList.unreadBadgeInactiveBackgroundColor : theme.chatList.unreadBadgeActiveBackgroundColor,
                        foreground: item.item.isMuted ? theme.chatList.unreadBadgeInactiveTextColor : theme.chatList.unreadBadgeActiveTextColor,
                        insets: UIEdgeInsets(top: 1.0, left: 5.0, bottom: 2.0, right: 5.0)
                    )),
                    environment: {},
                    containerSize: CGSize(width: 100.0, height: 100.0)
                )
            }
            
            var contentSize: CGFloat = iconSize.width + spacing + titleSize.width
            if let badgeSize {
                contentSize += badgeSpacing + badgeSize.width
            }
            
            let size = CGSize(width: contentSize, height: height)
            
            let iconFrame = CGRect(origin: CGPoint(x: 0.0, y: 5.0 + floor((size.height - iconSize.height) * 0.5)), size: iconSize)
            let titleFrame = CGRect(origin: CGPoint(x: iconFrame.maxX + spacing, y: 5.0 + floor((size.height - titleSize.height) * 0.5)), size: titleSize)
            
            if let icon = self.icon {
                if let iconView = icon.view {
                    if iconView.superview == nil {
                        iconView.isUserInteractionEnabled = false
                        self.containerButton.addSubview(iconView)
                    }
                    iconView.frame = iconFrame
                }
                
                if let avatarNode = self.avatarNode {
                    self.avatarNode = nil
                    avatarNode.view.removeFromSuperview()
                }
            } else {
                let avatarNode: AvatarNode
                if let current = self.avatarNode {
                    avatarNode = current
                } else {
                    avatarNode = AvatarNode(font: avatarPlaceholderFont(size: 7.0))
                    self.avatarNode = avatarNode
                    self.containerButton.addSubview(avatarNode.view)
                }
                avatarNode.frame = iconFrame
                avatarNode.updateSize(size: iconFrame.size)
                
                if let peer = item.item.renderedPeer.chatMainPeer {
                    if peer.smallProfileImage != nil {
                        avatarNode.setPeerV2(context: context, theme: theme, peer: peer, overrideImage: nil, emptyColor: .gray, clipStyle: .round, synchronousLoad: false, displayDimensions: iconFrame.size)
                    } else {
                        avatarNode.setPeer(context: context, theme: theme, peer: peer, overrideImage: nil, emptyColor: .gray, clipStyle: .round, synchronousLoad: false, displayDimensions: iconFrame.size)
                    }
                }
            }
            
            if let titleView = self.title.view {
                if titleView.superview == nil {
                    titleView.isUserInteractionEnabled = false
                    self.containerButton.addSubview(titleView)
                }
                titleView.frame = titleFrame
            }
            
            if let badgeSize, let badge = self.badge {
                let badgeFrame = CGRect(origin: CGPoint(x: titleFrame.maxX + badgeSpacing, y: titleFrame.minY + floorToScreenPixels((titleFrame.height - badgeSize.height) * 0.5)), size: badgeSize)
                
                if let badgeView = badge.view {
                    if badgeView.superview == nil {
                        badgeView.isUserInteractionEnabled = false
                        self.containerButton.addSubview(badgeView)
                        badgeView.frame = badgeFrame
                        badgeView.alpha = 0.0
                    }
                    transition.setPosition(view: badgeView, position: badgeFrame.center)
                    transition.setBounds(view: badgeView, bounds: CGRect(origin: CGPoint(), size: badgeFrame.size))
                    transition.setScale(view: badgeView, scale: 1.0)
                    alphaTransition.setAlpha(view: badgeView, alpha: 1.0)
                }
            } else if let badge = self.badge {
                self.badge = nil
                if let badgeView = badge.view {
                    let badgeFrame = CGRect(origin: CGPoint(x: titleFrame.maxX + badgeSpacing, y: titleFrame.minX + floorToScreenPixels((titleFrame.height - badgeView.bounds.height) * 0.5)), size: badgeView.bounds.size)
                    transition.setPosition(view: badgeView, position: badgeFrame.center)
                    transition.setScale(view: badgeView, scale: 0.001)
                    alphaTransition.setAlpha(view: badgeView, alpha: 0.0, completion: { [weak badgeView] _ in
                        badgeView?.removeFromSuperview()
                    })
                }
            }
            
            transition.setFrame(view: self.containerButton, frame: CGRect(origin: CGPoint(), size: size))
            
            self.extractedContainerNode.frame = CGRect(origin: CGPoint(), size: size)
            self.extractedContainerNode.contentNode.frame = CGRect(origin: CGPoint(), size: size)
            self.extractedContainerNode.contentRect = CGRect(origin: CGPoint(x: 0.0, y: 0.0), size: CGSize(width: size.width, height: size.height))
            self.containerNode.frame = CGRect(origin: CGPoint(), size: size)
            
            return size
        }
    }
    
    private final class TabItemView: UIView {
        private let context: AccountContext
        private let action: () -> Void
        
        private let extractedContainerNode: ContextExtractedContentContainingNode
        private let containerNode: ContextControllerSourceNode
        
        private let containerButton: HighlightTrackingButton
        
        private let icon = ComponentView<Empty>()
        
        init(context: AccountContext, action: @escaping (() -> Void)) {
            self.context = context
            self.action = action
            
            self.extractedContainerNode = ContextExtractedContentContainingNode()
            self.containerNode = ContextControllerSourceNode()
            
            self.containerButton = HighlightTrackingButton()
            
            super.init(frame: CGRect())
            
            self.extractedContainerNode.contentNode.view.addSubview(self.containerButton)
            
            self.containerNode.addSubnode(self.extractedContainerNode)
            self.containerNode.targetNodeForActivationProgress = self.extractedContainerNode.contentNode
            self.addSubview(self.containerNode.view)
            
            self.containerButton.addTarget(self, action: #selector(self.pressed), for: .touchUpInside)
            self.containerButton.highligthedChanged = { [weak self] highlighted in
                if let self, self.bounds.width > 0.0 {
                    let topScale: CGFloat = (self.bounds.width - 1.0) / self.bounds.width
                    let maxScale: CGFloat = (self.bounds.width + 1.0) / self.bounds.width
                    
                    if highlighted {
                        self.layer.removeAnimation(forKey: "opacity")
                        self.layer.removeAnimation(forKey: "sublayerTransform")
                        let transition: ContainedViewLayoutTransition = .animated(duration: 0.2, curve: .easeInOut)
                        transition.updateTransformScale(layer: self.layer, scale: topScale)
                    } else {
                        let transition: ContainedViewLayoutTransition = .immediate
                        transition.updateTransformScale(layer: self.layer, scale: 1.0)
                        
                        self.layer.animateScale(from: topScale, to: maxScale, duration: 0.13, timingFunction: CAMediaTimingFunctionName.easeOut.rawValue, removeOnCompletion: false, completion: { [weak self] _ in
                            guard let self else {
                                return
                            }
                            
                            self.layer.animateScale(from: maxScale, to: 1.0, duration: 0.1, timingFunction: CAMediaTimingFunctionName.easeIn.rawValue)
                        })
                    }
                }
            }
            
            self.containerNode.isGestureEnabled = false
        }
        
        required init?(coder: NSCoder) {
            preconditionFailure()
        }
        
        @objc private func pressed() {
            self.action()
        }
        
        override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
            var mappedPoint = point
            if self.bounds.insetBy(dx: -8.0, dy: -4.0).contains(point) {
                mappedPoint = self.bounds.center
            }
            return super.hitTest(mappedPoint, with: event)
        }
        
        func update(context: AccountContext, theme: PresentationTheme, height: CGFloat, transition: ComponentTransition) -> CGSize {
            let iconSize = self.icon.update(
                transition: .immediate,
                component: AnyComponent(BundleIconComponent(
                    name: "Chat/Title Panels/SidebarIcon",
                    tintColor: theme.rootController.navigationBar.secondaryTextColor,
                    maxSize: nil,
                    scaleFactor: 1.0
                )),
                environment: {},
                containerSize: CGSize(width: 100.0, height: 100.0)
            )
            
            let contentSize: CGFloat = iconSize.width
            let size = CGSize(width: contentSize, height: height)
            
            let iconFrame = CGRect(origin: CGPoint(x: 0.0, y: 5.0 + floor((size.height - iconSize.height) * 0.5)), size: iconSize)
            
            if let iconView = self.icon.view {
                if iconView.superview == nil {
                    iconView.isUserInteractionEnabled = false
                    self.containerButton.addSubview(iconView)
                }
                iconView.frame = iconFrame
            }
            
            transition.setFrame(view: self.containerButton, frame: CGRect(origin: CGPoint(), size: size))
            
            self.extractedContainerNode.frame = CGRect(origin: CGPoint(), size: size)
            self.extractedContainerNode.contentNode.frame = CGRect(origin: CGPoint(), size: size)
            self.extractedContainerNode.contentRect = CGRect(origin: CGPoint(x: 0.0, y: 0.0), size: CGSize(width: size.width, height: size.height))
            self.containerNode.frame = CGRect(origin: CGPoint(), size: size)
            
            return size
        }
    }
    
    private final class AllItemView: UIView {
        private let context: AccountContext
        private let action: () -> Void
        
        private let extractedContainerNode: ContextExtractedContentContainingNode
        private let containerNode: ContextControllerSourceNode
        
        private let containerButton: HighlightTrackingButton
        
        private let title = ComponentView<Empty>()
        
        init(context: AccountContext, action: @escaping (() -> Void)) {
            self.context = context
            self.action = action
            
            self.extractedContainerNode = ContextExtractedContentContainingNode()
            self.containerNode = ContextControllerSourceNode()
            
            self.containerButton = HighlightTrackingButton()
            
            super.init(frame: CGRect())
            
            self.extractedContainerNode.contentNode.view.addSubview(self.containerButton)
            
            self.containerNode.addSubnode(self.extractedContainerNode)
            self.containerNode.targetNodeForActivationProgress = self.extractedContainerNode.contentNode
            self.addSubview(self.containerNode.view)
            
            self.containerButton.addTarget(self, action: #selector(self.pressed), for: .touchUpInside)
            self.containerButton.highligthedChanged = { [weak self] highlighted in
                if let self, self.bounds.width > 0.0 {
                    let topScale: CGFloat = (self.bounds.width - 1.0) / self.bounds.width
                    let maxScale: CGFloat = (self.bounds.width + 1.0) / self.bounds.width
                    
                    if highlighted {
                        self.layer.removeAnimation(forKey: "opacity")
                        self.layer.removeAnimation(forKey: "sublayerTransform")
                        let transition: ContainedViewLayoutTransition = .animated(duration: 0.2, curve: .easeInOut)
                        transition.updateTransformScale(layer: self.layer, scale: topScale)
                    } else {
                        let transition: ContainedViewLayoutTransition = .immediate
                        transition.updateTransformScale(layer: self.layer, scale: 1.0)
                        
                        self.layer.animateScale(from: topScale, to: maxScale, duration: 0.13, timingFunction: CAMediaTimingFunctionName.easeOut.rawValue, removeOnCompletion: false, completion: { [weak self] _ in
                            guard let self else {
                                return
                            }
                            
                            self.layer.animateScale(from: maxScale, to: 1.0, duration: 0.1, timingFunction: CAMediaTimingFunctionName.easeIn.rawValue)
                        })
                    }
                }
            }
            
            self.containerNode.isGestureEnabled = false
        }
        
        required init?(coder: NSCoder) {
            preconditionFailure()
        }
        
        @objc private func pressed() {
            self.action()
        }
        
        override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
            var mappedPoint = point
            if self.bounds.insetBy(dx: -8.0, dy: -4.0).contains(point) {
                mappedPoint = self.bounds.center
            }
            return super.hitTest(mappedPoint, with: event)
        }
        
        func update(context: AccountContext, isSelected: Bool, theme: PresentationTheme, height: CGFloat, transition: ComponentTransition) -> CGSize {
            //TODO:localize
            let titleText: String = "All"
            let titleSize = self.title.update(
                transition: .immediate,
                component: AnyComponent(MultilineTextComponent(
                    text: .plain(NSAttributedString(string: titleText, font: Font.medium(14.0), textColor: isSelected ? theme.rootController.navigationBar.accentTextColor : theme.rootController.navigationBar.secondaryTextColor))
                )),
                environment: {},
                containerSize: CGSize(width: 100.0, height: 100.0)
            )
            
            let contentSize: CGFloat = titleSize.width
            let size = CGSize(width: contentSize, height: height)
            
            let titleFrame = CGRect(origin: CGPoint(x: 0.0, y: 5.0 + floor((size.height - titleSize.height) * 0.5)), size: titleSize)
            
            if let titleView = self.title.view {
                if titleView.superview == nil {
                    titleView.isUserInteractionEnabled = false
                    self.containerButton.addSubview(titleView)
                }
                titleView.frame = titleFrame
            }
            
            transition.setFrame(view: self.containerButton, frame: CGRect(origin: CGPoint(), size: size))
            
            self.extractedContainerNode.frame = CGRect(origin: CGPoint(), size: size)
            self.extractedContainerNode.contentNode.frame = CGRect(origin: CGPoint(), size: size)
            self.extractedContainerNode.contentRect = CGRect(origin: CGPoint(x: 0.0, y: 0.0), size: CGSize(width: size.width, height: size.height))
            self.containerNode.frame = CGRect(origin: CGPoint(), size: size)
            
            return size
        }
    }*/
    
    private var params: Params?
    
    private let context: AccountContext
    private let peerId: EnginePeer.Id
    private let isMonoforum: Bool
    private let panel = ComponentView<ChatSidePanelEnvironment>()
    
    init(context: AccountContext, peerId: EnginePeer.Id, isMonoforum: Bool) {
        self.context = context
        self.peerId = peerId
        self.isMonoforum = isMonoforum
        
        super.init()
        
        
    }
    
    deinit {
    }
    
    private func update(transition: ContainedViewLayoutTransition) {
        if let params = self.params {
            self.update(params: params, transition: transition)
        }
    }
    
    override func updateLayout(width: CGFloat, leftInset: CGFloat, rightInset: CGFloat, transition: ContainedViewLayoutTransition, interfaceState: ChatPresentationInterfaceState) -> LayoutResult {
        let params = Params(width: width, leftInset: leftInset, rightInset: rightInset, interfaceState: interfaceState)
        if self.params != params {
            self.params = params
            self.update(params: params, transition: transition)
        }
        
        let panelHeight: CGFloat = 44.0
        
        return LayoutResult(backgroundHeight: panelHeight, insetHeight: panelHeight, hitTestSlop: 0.0)
    }
    
    func updateLayout(width: CGFloat, leftInset: CGFloat, rightInset: CGFloat, transition: ContainedViewLayoutTransition, chatController: ChatController) -> LayoutResult {
        return self.updateLayout(width: width, leftInset: leftInset, rightInset: rightInset, transition: transition, interfaceState: (chatController as! ChatControllerImpl).presentationInterfaceState)
    }
    
    private func update(params: Params, transition: ContainedViewLayoutTransition) {
        let panelHeight: CGFloat = 44.0
        
        let panelFrame = CGRect(origin: CGPoint(), size: CGSize(width: params.width, height: panelHeight))
        let _ = self.panel.update(
            transition: ComponentTransition(transition),
            component: AnyComponent(ChatSideTopicsPanel(
                context: self.context,
                theme: params.interfaceState.theme,
                strings: params.interfaceState.strings,
                location: .top,
                peerId: self.peerId,
                isMonoforum: self.isMonoforum,
                topicId: params.interfaceState.chatLocation.threadId,
                controller: { [weak self] in
                    return self?.interfaceInteraction?.chatController()
                },
                togglePanel: { [weak self] in
                    guard let self else {
                        return
                    }
                    self.interfaceInteraction?.toggleChatSidebarMode()
                },
                updateTopicId: { [weak self] topicId, direction in
                    guard let self else {
                        return
                    }
                    self.interfaceInteraction?.updateChatLocationThread(topicId, direction ? .right : .left)
                }
            )),
            environment: {
                ChatSidePanelEnvironment(insets: UIEdgeInsets(
                    top: 0.0,
                    left: params.leftInset,
                    bottom: 0.0,
                    right: params.rightInset
                ))
            },
            containerSize: panelFrame.size
        )
        if let panelView = self.panel.view {
            if panelView.superview == nil {
                panelView.disablesInteractiveTransitionGestureRecognizer = true
                self.view.addSubview(panelView)
            }
            transition.updateFrame(view: panelView, frame: panelFrame)
        }
        
        /*
        
        let containerInsets = UIEdgeInsets(top: 0.0, left: params.leftInset + 16.0, bottom: 0.0, right: params.rightInset + 16.0)
        let itemSpacing: CGFloat = 24.0
        
        var leftContentInset: CGFloat = containerInsets.left + 8.0
        
        do {
            var itemTransition = transition
            var animateIn = false
            let itemView: TabItemView
            if let current = self.tabItemView {
                itemView = current
            } else {
                itemTransition = .immediate
                animateIn = true
                itemView = TabItemView(context: self.context, action: { [weak self] in
                    guard let self else {
                        return
                    }
                    self.interfaceInteraction?.toggleChatSidebarMode()
                })
                self.tabItemView = itemView
                self.view.addSubview(itemView)
            }
                
            let itemSize = itemView.update(context: self.context, theme: params.interfaceState.theme, height: panelHeight, transition: .immediate)
            let itemFrame = CGRect(origin: CGPoint(x: leftContentInset, y: -5.0), size: itemSize)
            
            itemTransition.updatePosition(layer: itemView.layer, position: itemFrame.center)
            itemTransition.updateBounds(layer: itemView.layer, bounds: CGRect(origin: CGPoint(), size: itemFrame.size))
            
            if animateIn && transition.isAnimated {
                itemView.layer.animateAlpha(from: 0.0, to: itemView.alpha, duration: 0.15)
                transition.animateTransformScale(view: itemView, from: 0.001)
            }
            
            leftContentInset += itemSize.width + 8.0
        }
        
        var contentSize = CGSize(width: itemSpacing - 8.0, height: panelHeight)
        
        var validIds: [Item.Id] = []
        var isFirst = true
        var selectedItemFrame: CGRect?
        
        do {
            if isFirst {
                isFirst = false
            } else {
                contentSize.width += itemSpacing
            }
            
            var itemTransition = transition
            var animateIn = false
            let itemView: AllItemView
            if let current = self.allItemView {
                itemView = current
            } else {
                itemTransition = .immediate
                animateIn = true
                itemView = AllItemView(context: self.context, action: { [weak self] in
                    guard let self else {
                        return
                    }
                    self.interfaceInteraction?.updateChatLocationThread(nil, .left)
                })
                self.allItemView = itemView
                self.scrollView.addSubview(itemView)
            }
                
            var isSelected = false
            if params.interfaceState.chatLocation.threadId == nil {
                isSelected = true
            }
            let itemSize = itemView.update(context: self.context, isSelected: isSelected, theme: params.interfaceState.theme, height: panelHeight, transition: .immediate)
            let itemFrame = CGRect(origin: CGPoint(x: contentSize.width, y: -5.0), size: itemSize)
            
            if isSelected {
                selectedItemFrame = itemFrame
            }
            
            itemTransition.updatePosition(layer: itemView.layer, position: itemFrame.center)
            itemTransition.updateBounds(layer: itemView.layer, bounds: CGRect(origin: CGPoint(), size: itemFrame.size))
            
            if animateIn && transition.isAnimated {
                itemView.layer.animateAlpha(from: 0.0, to: itemView.alpha, duration: 0.15)
                transition.animateTransformScale(view: itemView, from: 0.001)
            }
            
            contentSize.width += itemSize.width
        }
        
        for item in self.items {
            if isFirst {
                isFirst = false
            } else {
                contentSize.width += itemSpacing
            }
            let itemId = item.id
            validIds.append(itemId)
            
            var itemTransition = transition
            var animateIn = false
            let itemView: ItemView
            if let current = self.itemViews[itemId] {
                itemView = current
            } else {
                itemTransition = .immediate
                animateIn = true
                let chatListItem = item.item
                itemView = ItemView(context: self.context, action: { [weak self] in
                    guard let self else {
                        return
                    }
                    
                    let topicId: Int64
                    if case let .forum(topicIdValue) = chatListItem.id {
                        topicId = topicIdValue
                    } else {
                        topicId = chatListItem.renderedPeer.peerId.toInt64()
                    }
                    
                    var direction = true
                    if let params = self.params, let lhsIndex = self.topicIndex(threadId:  params.interfaceState.chatLocation.threadId), let rhsIndex = self.topicIndex(threadId: topicId) {
                        direction = lhsIndex < rhsIndex
                    }
                    
                    self.interfaceInteraction?.updateChatLocationThread(topicId, direction ? .right : .left)
                }, contextGesture: { gesture, sourceNode in
                })
                self.itemViews[itemId] = itemView
                self.scrollView.addSubview(itemView)
            }
                
            var isSelected = false
            if case let .forum(topicId) = item.item.id {
                isSelected = params.interfaceState.chatLocation.threadId == topicId
            } else {
                isSelected = params.interfaceState.chatLocation.threadId == item.item.renderedPeer.peerId.toInt64()
            }
            let itemSize = itemView.update(context: self.context, item: item, isSelected: isSelected, theme: params.interfaceState.theme, height: panelHeight, transition: .immediate)
            let itemFrame = CGRect(origin: CGPoint(x: contentSize.width, y: -5.0), size: itemSize)
            
            if isSelected {
                selectedItemFrame = itemFrame
            }
            
            itemTransition.updatePosition(layer: itemView.layer, position: itemFrame.center)
            itemTransition.updateBounds(layer: itemView.layer, bounds: CGRect(origin: CGPoint(), size: itemFrame.size))
            
            if animateIn && transition.isAnimated {
                itemView.layer.animateAlpha(from: 0.0, to: itemView.alpha, duration: 0.15)
                transition.animateTransformScale(view: itemView, from: 0.001)
            }
            
            contentSize.width += itemSize.width
        }
        var removedIds: [Item.Id] = []
        for (id, itemView) in self.itemViews {
            if !validIds.contains(id) {
                removedIds.append(id)
                
                if transition.isAnimated {
                    itemView.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.18, removeOnCompletion: false, completion: { [weak itemView] _ in
                        itemView?.removeFromSuperview()
                    })
                    transition.updateTransformScale(layer: itemView.layer, scale: 0.001)
                } else {
                    itemView.removeFromSuperview()
                }
            }
        }
        for id in removedIds {
            self.itemViews.removeValue(forKey: id)
        }
        
        if let selectedItemFrame {
            let lineFrame = CGRect(origin: CGPoint(x: selectedItemFrame.minX, y: panelHeight - 4.0), size: CGSize(width: selectedItemFrame.width + 4.0, height: 4.0))
            if self.selectedLineView.isHidden {
                self.selectedLineView.isHidden = false
                self.selectedLineView.frame = lineFrame
            } else {
                transition.updateFrame(view: self.selectedLineView, frame: lineFrame)
            }
        } else {
            self.selectedLineView.isHidden = true
        }
        
        contentSize.width += containerInsets.right
        
        let scrollSize = CGSize(width: params.width - leftContentInset, height: contentSize.height)
        self.scrollViewContainer.frame = CGRect(origin: CGPoint(x: leftContentInset, y: 0.0), size: scrollSize)
        self.scrollViewMask.frame = CGRect(origin: CGPoint(), size: scrollSize)
        
        if self.scrollView.bounds.size != scrollSize {
            self.scrollView.frame = CGRect(origin: CGPoint(), size: scrollSize)
        }
        if self.scrollView.contentSize != contentSize {
            self.scrollView.contentSize = contentSize
        }
        
        let scrollToId: ScrollId
        if let threadId = params.interfaceState.chatLocation.threadId {
            scrollToId = .topic(threadId)
        } else {
            scrollToId = .all
        }
        if self.appliedScrollToId != scrollToId {
            if case let .topic(threadId) = scrollToId {
                if let itemView = self.itemViews[.forum(threadId)] {
                    self.appliedScrollToId = scrollToId
                    self.scrollView.scrollRectToVisible(itemView.frame.insetBy(dx: -46.0, dy: 0.0), animated: hadItemViews)
                }
            } else if case .all = scrollToId {
                self.appliedScrollToId = scrollToId
                self.scrollView.scrollRectToVisible(CGRect(origin: CGPoint(), size: CGSize(width: 1.0, height: 1.0)), animated: hadItemViews)
            } else {
                self.appliedScrollToId = scrollToId
            }
        }*/
    }

    public func updateGlobalOffset(globalOffset: CGFloat, transition: ComponentTransition) {
        if let panelView = self.panel.view as? ChatSideTopicsPanel.View {
            panelView.updateGlobalOffset(globalOffset: globalOffset, transition: transition)
            //transition.setTransform(view: tabItemView, transform: CATransform3DMakeTranslation(0.0, -globalOffset, 0.0))
        }
    }
    
    public func topicIndex(threadId: Int64?) -> Int? {
        if let panelView = self.panel.view as? ChatSideTopicsPanel.View {
            return panelView.topicIndex(threadId: threadId)
        } else {
            return nil
        }
        
        /*if let threadId {
            if let value = self.items.firstIndex(where: { item in
                if item.id == .chatList(PeerId(threadId)) {
                    return true
                } else if item.id == .forum(threadId) {
                    return true
                } else {
                    return false
                }
            }) {
                return value + 1
            } else {
                return nil
            }
        } else {
            return 0
        }*/
    }
}
