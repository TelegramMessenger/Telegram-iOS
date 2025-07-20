import Foundation
import UIKit
import SwiftSignalKit
import Postbox
import TelegramCore
import Display
import AsyncDisplayKit
import TelegramPresentationData
import ChatPresentationInterfaceState
import ComponentFlow
import MultilineTextComponent
import AccountContext
import BlurredBackgroundComponent
import EmojiStatusComponent
import BundleIconComponent
import AvatarNode
import ChatListUI
import ContextUI
import AsyncListComponent
import TextBadgeComponent
import MaskedContainerComponent
import AppBundle
import PresentationDataUtils

public final class ChatSidePanelEnvironment: Equatable {
    public let insets: UIEdgeInsets
    
    public init(insets: UIEdgeInsets) {
        self.insets = insets
    }
    
    public static func ==(lhs: ChatSidePanelEnvironment, rhs: ChatSidePanelEnvironment) -> Bool {
        if lhs.insets != rhs.insets {
            return false
        }
        return true
    }
}

public final class ChatSideTopicsPanel: Component {
    public typealias EnvironmentType = ChatSidePanelEnvironment
    
    public enum Location {
        case side
        case top
    }
    
    let context: AccountContext
    let theme: PresentationTheme
    let strings: PresentationStrings
    let location: Location
    let peerId: EnginePeer.Id
    let isMonoforum: Bool
    let topicId: Int64?
    let controller: () -> ViewController?
    let togglePanel: () -> Void
    let updateTopicId: (Int64?, Bool) -> Void
    let openDeletePeer: (Int64) -> Void
    
    public init(
        context: AccountContext,
        theme: PresentationTheme,
        strings: PresentationStrings,
        location: Location,
        peerId: EnginePeer.Id,
        isMonoforum: Bool,
        topicId: Int64?,
        controller: @escaping () -> ViewController?,
        togglePanel: @escaping () -> Void,
        updateTopicId: @escaping (Int64?, Bool) -> Void,
        openDeletePeer: @escaping (Int64) -> Void
    ) {
        self.context = context
        self.theme = theme
        self.strings = strings
        self.location = location
        self.peerId = peerId
        self.isMonoforum = isMonoforum
        self.topicId = topicId
        self.controller = controller
        self.togglePanel = togglePanel
        self.updateTopicId = updateTopicId
        self.openDeletePeer = openDeletePeer
    }
    
    public static func ==(lhs: ChatSideTopicsPanel, rhs: ChatSideTopicsPanel) -> Bool {
        if lhs.context !== rhs.context {
            return false
        }
        if lhs.theme !== rhs.theme {
            return false
        }
        if lhs.strings !== rhs.strings {
            return false
        }
        if lhs.location != rhs.location {
            return false
        }
        if lhs.peerId != rhs.peerId {
            return false
        }
        if lhs.isMonoforum != rhs.isMonoforum {
            return false
        }
        if lhs.topicId != rhs.topicId {
            return false
        }
        return true
    }
    
    private final class Item: Equatable {
        typealias Id = EngineChatList.Item.Id
        
        let item: EngineChatList.Item
        
        var id: Id {
            return self.item.id
        }
        
        init(item: EngineChatList.Item) {
            self.item = item
        }
        
        public static func ==(lhs: Item, rhs: Item) -> Bool {
            if lhs === rhs {
                return true
            }
            if lhs.item != rhs.item {
                return false
            }
            return true
        }
    }
    
    private protocol ItemComponent: AnyObject {
        var item: Item { get }
    }
    
    private final class VerticalItemComponent: Component, ItemComponent {
        let context: AccountContext
        let item: Item
        let isSelected: Bool
        let isReordering: Bool
        let theme: PresentationTheme
        let action: (() -> Void)?
        let contextGesture: ((ContextGesture, ContextExtractedContentContainingNode) -> Void)?
        
        init(context: AccountContext, item: Item, isSelected: Bool, isReordering: Bool, theme: PresentationTheme, strings: PresentationStrings, action: (() -> Void)?, contextGesture: ((ContextGesture, ContextExtractedContentContainingNode) -> Void)?) {
            self.context = context
            self.item = item
            self.isSelected = isSelected
            self.isReordering = isReordering
            self.theme = theme
            self.action = action
            self.contextGesture = contextGesture
        }
        
        static func ==(lhs: VerticalItemComponent, rhs: VerticalItemComponent) -> Bool {
            if lhs === rhs {
                return true
            }
            if lhs.context !== rhs.context {
                return false
            }
            if lhs.item != rhs.item {
                return false
            }
            if lhs.isSelected != rhs.isSelected {
                return false
            }
            if lhs.isReordering != rhs.isReordering {
                return false
            }
            if lhs.theme !== rhs.theme {
                return false
            }
            if (lhs.action == nil) != (rhs.action == nil) {
                return false
            }
            if (lhs.contextGesture == nil) != (rhs.contextGesture == nil) {
                return false
            }
            return true
        }
        
        final class View: UIView, AsyncListComponent.ItemView {
            private let extractedContainerNode: ContextExtractedContentContainingNode
            private let containerNode: ContextControllerSourceNode
            
            private let containerButton: UIView
            private var extractedBackgroundView: UIImageView?
            
            private var tapRecognizer: UITapGestureRecognizer?
            
            private let iconContainer: MaskedContainerView
            private var icon: ComponentView<Empty>?
            private var avatarNode: AvatarNode?
            private let title = ComponentView<Empty>()
            private var badge: ComponentView<Empty>?
            
            private var component: VerticalItemComponent?
            
            override init(frame: CGRect) {
                self.extractedContainerNode = ContextExtractedContentContainingNode()
                self.containerNode = ContextControllerSourceNode()
                
                self.iconContainer = MaskedContainerView()
                self.iconContainer.isUserInteractionEnabled = false
                
                self.containerButton = UIView()
                
                super.init(frame: frame)
                
                self.extractedContainerNode.contentNode.view.addSubview(self.containerButton)
                
                self.containerNode.addSubnode(self.extractedContainerNode)
                self.containerNode.targetNodeForActivationProgress = self.extractedContainerNode.contentNode
                self.addSubview(self.containerNode.view)
                
                self.containerButton.addSubview(self.iconContainer)
                
                let tapRecognizer = UITapGestureRecognizer(target: self, action: #selector(self.tapGesture(_:)))
                self.tapRecognizer = tapRecognizer
                self.containerButton.addGestureRecognizer(tapRecognizer)
                tapRecognizer.isEnabled = false
                
                self.containerNode.activated = { [weak self] gesture, _ in
                    guard let self, let component = self.component else {
                        return
                    }
                    component.contextGesture?(gesture, self.extractedContainerNode)
                }
                
                self.extractedContainerNode.willUpdateIsExtractedToContextPreview = { [weak self] isExtracted, transition in
                    guard let self, let component = self.component else {
                        return
                    }
                    
                    if isExtracted {
                        let extractedBackgroundView: UIImageView
                        if let current = self.extractedBackgroundView {
                            extractedBackgroundView = current
                        } else {
                            extractedBackgroundView = UIImageView(image: generateStretchableFilledCircleImage(diameter: 28.0, color: component.theme.contextMenu.backgroundColor))
                            self.extractedBackgroundView = extractedBackgroundView
                            self.extractedContainerNode.contentNode.view.insertSubview(extractedBackgroundView, at: 0)
                            extractedBackgroundView.frame = self.extractedContainerNode.contentNode.bounds.insetBy(dx: 2.0, dy: 0.0)
                            extractedBackgroundView.alpha = 0.0
                        }
                        transition.updateAlpha(layer: extractedBackgroundView.layer, alpha: 1.0)
                    } else if let extractedBackgroundView = self.extractedBackgroundView {
                        self.extractedBackgroundView = nil
                        let alphaTransition: ContainedViewLayoutTransition
                        if transition.isAnimated {
                            alphaTransition = .animated(duration: 0.18, curve: .easeInOut)
                        } else {
                            alphaTransition = .immediate
                        }
                        alphaTransition.updateAlpha(layer: extractedBackgroundView.layer, alpha: 0.0, completion: { [weak extractedBackgroundView] _ in
                            extractedBackgroundView?.removeFromSuperview()
                        })
                    }
                }
                
                self.containerNode.isGestureEnabled = false
            }
            
            required init?(coder: NSCoder) {
                preconditionFailure()
            }
            
            @objc private func tapGesture(_ recognizer: UITapGestureRecognizer) {
                if case .ended = recognizer.state {
                    if let iconView = self.icon?.view as? EmojiStatusComponent.View {
                        iconView.playOnce()
                    }
                    self.component?.action?()
                }
            }
            
            override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
                var mappedPoint = point
                if self.bounds.insetBy(dx: -8.0, dy: -4.0).contains(point) {
                    mappedPoint = self.bounds.center
                }
                return super.hitTest(mappedPoint, with: event)
            }
            
            func isReorderable(at point: CGPoint) -> Bool {
                guard let component = self.component else {
                    return false
                }
                return component.isReordering
            }
            
            private func updateIsShaking(animated: Bool) {
                guard let component = self.component else {
                    return
                }
                
                if component.isReordering {
                    if self.layer.animation(forKey: "shaking_position") == nil {
                        let degreesToRadians: (_ x: CGFloat) -> CGFloat = { x in
                            return .pi * x / 180.0
                        }
                        
                        let duration: Double = 0.4
                        let displacement: CGFloat = 1.0
                        let degreesRotation: CGFloat = 2.0
                        
                        let negativeDisplacement = -1.0 * displacement
                        let position = CAKeyframeAnimation.init(keyPath: "position")
                        position.beginTime = 0.8
                        position.duration = duration
                        position.values = [
                            NSValue(cgPoint: CGPoint(x: negativeDisplacement, y: negativeDisplacement)),
                            NSValue(cgPoint: CGPoint(x: 0, y: 0)),
                            NSValue(cgPoint: CGPoint(x: negativeDisplacement, y: 0)),
                            NSValue(cgPoint: CGPoint(x: 0, y: negativeDisplacement)),
                            NSValue(cgPoint: CGPoint(x: negativeDisplacement, y: negativeDisplacement))
                        ]
                        position.calculationMode = .linear
                        position.isRemovedOnCompletion = false
                        position.repeatCount = Float.greatestFiniteMagnitude
                        position.beginTime = CFTimeInterval(Float(arc4random()).truncatingRemainder(dividingBy: Float(25)) / Float(100))
                        position.isAdditive = true
                        
                        let transform = CAKeyframeAnimation.init(keyPath: "transform")
                        transform.beginTime = 2.6
                        transform.duration = 0.3
                        transform.valueFunction = CAValueFunction(name: CAValueFunctionName.rotateZ)
                        transform.values = [
                            degreesToRadians(-1.0 * degreesRotation),
                            degreesToRadians(degreesRotation),
                            degreesToRadians(-1.0 * degreesRotation)
                        ]
                        transform.calculationMode = .linear
                        transform.isRemovedOnCompletion = false
                        transform.repeatCount = Float.greatestFiniteMagnitude
                        transform.isAdditive = true
                        transform.beginTime = CFTimeInterval(Float(arc4random()).truncatingRemainder(dividingBy: Float(25)) / Float(100))
                        
                        self.layer.add(position, forKey: "shaking_position")
                        self.layer.add(transform, forKey: "shaking_rotation")
                    }
                } else if self.layer.animation(forKey: "shaking_position") != nil {
                    if let presentationLayer = self.layer.presentation() {
                        let transition: ComponentTransition = .easeInOut(duration: 0.1)
                        if presentationLayer.position != self.layer.position {
                            transition.animatePosition(layer: self.layer, from: CGPoint(x: presentationLayer.position.x - self.layer.position.x, y: presentationLayer.position.y - self.layer.position.y), to: CGPoint(), additive: true)
                        }
                        if !CATransform3DIsIdentity(presentationLayer.transform) {
                            transition.setTransform(layer: self.layer, transform: CATransform3DIdentity)
                        }
                    }
                    
                    self.layer.removeAnimation(forKey: "shaking_position")
                    self.layer.removeAnimation(forKey: "shaking_rotation")
                }
            }
            
            func update(component: VerticalItemComponent, availableSize: CGSize, state: EmptyComponentState, environment: Environment<Empty>, transition: ComponentTransition) -> CGSize {
                let previousComponent = self.component
                self.component = component
                
                self.tapRecognizer?.isEnabled = component.action != nil
                
                self.containerNode.isGestureEnabled = component.contextGesture != nil
                self.containerNode.activated = { [weak self] gesture, _ in
                    guard let self, let component = self.component else {
                        return
                    }
                    component.contextGesture?(gesture, self.extractedContainerNode)
                }
                
                let topInset: CGFloat = 8.0
                let bottomInset: CGFloat = 8.0
                let spacing: CGFloat = 3.0
                let iconSize = CGSize(width: 30.0, height: 30.0)
                
                var avatarIconContent: EmojiStatusComponent.Content?
                if case let .forum(topicId) = component.item.item.id {
                    if topicId != 1, let threadData = component.item.item.threadData {
                        if let fileId = threadData.info.icon, fileId != 0 {
                            avatarIconContent = .animation(content: .customEmoji(fileId: fileId), size: iconSize, placeholderColor: component.theme.list.mediaPlaceholderColor, themeColor: component.isSelected ? component.theme.rootController.navigationBar.accentTextColor : component.theme.rootController.navigationBar.controlColor, loopMode: .count(0))
                        } else {
                            avatarIconContent = .topic(title: String(threadData.info.title.prefix(1)), color: threadData.info.iconColor, size: iconSize)
                        }
                    } else {
                        avatarIconContent = .image(image: PresentationResourcesChatList.generalTopicTemplateIcon(component.theme), tintColor: component.isSelected ? component.theme.rootController.navigationBar.accentTextColor : component.theme.rootController.navigationBar.controlColor)
                    }
                }
                
                if let avatarIconContent {
                    let avatarIconComponent = EmojiStatusComponent(
                        context: component.context,
                        animationCache: component.context.animationCache,
                        animationRenderer: component.context.animationRenderer,
                        content: avatarIconContent,
                        isVisibleForAnimations: true,
                        action: nil
                    )
                    let icon: ComponentView<Empty>
                    if let current = self.icon {
                        icon = current
                    } else {
                        icon = ComponentView()
                        self.icon = icon
                    }
                    
                    var iconTransition = transition
                    if iconTransition.animation.isImmediate, let previousComponent, previousComponent.isSelected != component.isSelected {
                        iconTransition = .easeInOut(duration: 0.2)
                    }
                    
                    let _ = icon.update(
                        transition: iconTransition,
                        component: AnyComponent(avatarIconComponent),
                        environment: {},
                        containerSize: iconSize
                    )
                } else if let icon = self.icon {
                    self.icon = nil
                    icon.view?.removeFromSuperview()
                }
                
                let titleText: String
                if case let .forum(topicId) = component.item.item.id {
                    let _ = topicId
                    if let threadData = component.item.item.threadData {
                        titleText = threadData.info.title
                    } else {
                        titleText = " "
                    }
                } else {
                    titleText = component.item.item.renderedPeer.chatMainPeer?.compactDisplayTitle ?? " "
                }
                
                if let avatarIconContent, let icon = self.icon {
                    let avatarIconComponent = EmojiStatusComponent(
                        context: component.context,
                        animationCache: component.context.animationCache,
                        animationRenderer: component.context.animationRenderer,
                        content: avatarIconContent,
                        isVisibleForAnimations: true,
                        action: nil
                    )
                    let _ = icon.update(
                        transition: .immediate,
                        component: AnyComponent(avatarIconComponent),
                        environment: {},
                        containerSize: iconSize
                    )
                }
                
                let titleSize = self.title.update(
                    transition: .immediate,
                    component: AnyComponent(MultilineTextComponent(
                        text: .plain(NSAttributedString(string: titleText, font: Font.regular(10.0), textColor: component.isSelected ? component.theme.rootController.navigationBar.accentTextColor : component.theme.rootController.navigationBar.secondaryTextColor)),
                        horizontalAlignment: .center,
                        maximumNumberOfLines: 2
                    )),
                    environment: {},
                    containerSize: CGSize(width: availableSize.width - 6.0 * 2.0, height: 100.0)
                )
                
                let contentSize: CGFloat = topInset + bottomInset + iconSize.height + spacing + titleSize.height
                let size = CGSize(width: availableSize.width, height: contentSize)
                
                let iconFrame = CGRect(origin: CGPoint(x: floor((size.width - iconSize.width) * 0.5), y: topInset), size: iconSize)
                let titleFrame = CGRect(origin: CGPoint(x: floor((size.width - titleSize.width) * 0.5), y: iconFrame.maxY + spacing), size: titleSize)
                
                self.iconContainer.frame = iconFrame
                
                if let icon = self.icon {
                    if let avatarNode = self.avatarNode {
                        self.avatarNode = nil
                        avatarNode.view.removeFromSuperview()
                    }
                    
                    if let iconView = icon.view {
                        if iconView.superview == nil {
                            iconView.isUserInteractionEnabled = false
                            self.iconContainer.contentView.addSubview(iconView)
                        }
                        iconView.frame = CGRect(origin: CGPoint(), size: iconFrame.size)
                    }
                } else {
                    let avatarNode: AvatarNode
                    if let current = self.avatarNode {
                        avatarNode = current
                    } else {
                        avatarNode = AvatarNode(font: avatarPlaceholderFont(size: 11.0))
                        avatarNode.isUserInteractionEnabled = false
                        self.avatarNode = avatarNode
                        self.iconContainer.contentView.addSubview(avatarNode.view)
                    }
                    avatarNode.frame = CGRect(origin: CGPoint(), size: iconFrame.size)
                    avatarNode.updateSize(size: iconFrame.size)
                    
                    if let peer = component.item.item.renderedPeer.chatMainPeer {
                        if peer.smallProfileImage != nil {
                            avatarNode.setPeerV2(context: component.context, theme: component.theme, peer: peer, overrideImage: nil, emptyColor: .gray, clipStyle: .round, synchronousLoad: false, displayDimensions: iconFrame.size)
                        } else {
                            avatarNode.setPeer(context: component.context, theme: component.theme, peer: peer, overrideImage: nil, emptyColor: .gray, clipStyle: .round, synchronousLoad: false, displayDimensions: iconFrame.size)
                        }
                    }
                }
                
                var iconMaskItems: [MaskedContainerView.Item] = []
                if let readCounters = component.item.item.readCounters, readCounters.count > 0 {
                    let badge: ComponentView<Empty>
                    var badgeTransition = transition
                    if let current = self.badge {
                        badge = current
                    } else {
                        badgeTransition = .immediate
                        badge = ComponentView<Empty>()
                        self.badge = badge
                    }
                    
                    let badgeSize = badge.update(
                        transition: badgeTransition,
                        component: AnyComponent(TextBadgeComponent(
                            text: countString(Int64(readCounters.count)),
                            font: Font.medium(12.0),
                            background: component.item.item.isMuted ? component.theme.chatList.unreadBadgeInactiveBackgroundColor : component.theme.chatList.unreadBadgeActiveBackgroundColor,
                            foreground: component.item.item.isMuted ? component.theme.chatList.unreadBadgeInactiveTextColor : component.theme.chatList.unreadBadgeActiveTextColor,
                            insets: UIEdgeInsets(top: 1.0, left: 5.0, bottom: 2.0, right: 5.0)
                        )),
                        environment: {},
                        containerSize: CGSize(width: 100.0, height: 100.0)
                    )
                    let badgeFrame = CGRect(origin: CGPoint(x: iconFrame.maxX + 10.0 - badgeSize.width, y: iconFrame.minY - 6.0), size: badgeSize)
                    if let badgeView = badge.view {
                        if badgeView.superview == nil {
                            self.containerButton.addSubview(badgeView)
                        }
                        badgeView.frame = badgeFrame
                    }
                    let badgeMaskFrame = badgeFrame.offsetBy(dx: -iconFrame.minX, dy: -iconFrame.minY).insetBy(dx: -1.33, dy: -1.33)
                    iconMaskItems.append(MaskedContainerView.Item(
                        frame: badgeMaskFrame,
                        shape: .roundedRect(cornerRadius: badgeMaskFrame.height * 0.5)
                    ))
                } else if let badge = self.badge {
                    self.badge = nil
                    badge.view?.removeFromSuperview()
                }
                self.iconContainer.update(size: iconFrame.size, items: iconMaskItems, isInverted: true)
                self.iconContainer.frame = iconFrame
                
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
                
                self.updateIsShaking(animated: !transition.animation.isImmediate)
                
                return size
            }
        }
        
        func makeView() -> View {
            return View(frame: CGRect())
        }
        
        func update(view: View, availableSize: CGSize, state: EmptyComponentState, environment: Environment<Empty>, transition: ComponentTransition) -> CGSize {
            return view.update(component: self, availableSize: availableSize, state: state, environment: environment, transition: transition)
        }
    }
    
    private final class HorizontalItemComponent: Component, ItemComponent {
        let context: AccountContext
        let item: Item
        let isSelected: Bool
        let isReordering: Bool
        let theme: PresentationTheme
        let action: (() -> Void)?
        let contextGesture: ((ContextGesture, ContextExtractedContentContainingNode) -> Void)?
        
        init(context: AccountContext, item: Item, isSelected: Bool, isReordering: Bool, theme: PresentationTheme, strings: PresentationStrings, action: (() -> Void)?, contextGesture: ((ContextGesture, ContextExtractedContentContainingNode) -> Void)?) {
            self.context = context
            self.item = item
            self.isSelected = isSelected
            self.isReordering = isReordering
            self.theme = theme
            self.action = action
            self.contextGesture = contextGesture
        }
        
        static func ==(lhs: HorizontalItemComponent, rhs: HorizontalItemComponent) -> Bool {
            if lhs === rhs {
                return true
            }
            if lhs.context !== rhs.context {
                return false
            }
            if lhs.item != rhs.item {
                return false
            }
            if lhs.isSelected != rhs.isSelected {
                return false
            }
            if lhs.isReordering != rhs.isReordering {
                return false
            }
            if lhs.theme !== rhs.theme {
                return false
            }
            if (lhs.action == nil) != (rhs.action == nil) {
                return false
            }
            if (lhs.contextGesture == nil) != (rhs.contextGesture == nil) {
                return false
            }
            return true
        }
        
        final class View: UIView, AsyncListComponent.ItemView {
            private let extractedContainerNode: ContextExtractedContentContainingNode
            private let containerNode: ContextControllerSourceNode
            
            private let containerButton: UIView
            private var extractedBackgroundView: UIImageView?
            
            private var tapRecognizer: UITapGestureRecognizer?
            
            private var icon: ComponentView<Empty>?
            private var avatarNode: AvatarNode?
            private let title = ComponentView<Empty>()
            private var badge: ComponentView<Empty>?
            
            private var component: HorizontalItemComponent?
            
            override init(frame: CGRect) {
                self.extractedContainerNode = ContextExtractedContentContainingNode()
                self.containerNode = ContextControllerSourceNode()
                
                self.containerButton = UIView()
                
                super.init(frame: frame)
                
                self.extractedContainerNode.contentNode.view.addSubview(self.containerButton)
                
                self.containerNode.addSubnode(self.extractedContainerNode)
                self.containerNode.targetNodeForActivationProgress = self.extractedContainerNode.contentNode
                self.addSubview(self.containerNode.view)
                
                let tapRecognizer = UITapGestureRecognizer(target: self, action: #selector(self.tapGesture(_:)))
                self.tapRecognizer = tapRecognizer
                self.containerButton.addGestureRecognizer(tapRecognizer)
                tapRecognizer.isEnabled = false
                
                self.containerNode.activated = { [weak self] gesture, _ in
                    guard let self, let component = self.component else {
                        return
                    }
                    component.contextGesture?(gesture, self.extractedContainerNode)
                }
                
                self.extractedContainerNode.willUpdateIsExtractedToContextPreview = { [weak self] isExtracted, transition in
                    guard let self, let component = self.component else {
                        return
                    }
                    
                    if isExtracted {
                        let extractedBackgroundView: UIImageView
                        if let current = self.extractedBackgroundView {
                            extractedBackgroundView = current
                        } else {
                            extractedBackgroundView = UIImageView(image: generateStretchableFilledCircleImage(diameter: 28.0, color: component.theme.contextMenu.backgroundColor))
                            self.extractedBackgroundView = extractedBackgroundView
                            self.extractedContainerNode.contentNode.view.insertSubview(extractedBackgroundView, at: 0)
                            extractedBackgroundView.frame = self.extractedContainerNode.contentNode.bounds.insetBy(dx: 2.0, dy: 0.0)
                            extractedBackgroundView.alpha = 0.0
                        }
                        transition.updateAlpha(layer: extractedBackgroundView.layer, alpha: 1.0)
                    } else if let extractedBackgroundView = self.extractedBackgroundView {
                        self.extractedBackgroundView = nil
                        let alphaTransition: ContainedViewLayoutTransition
                        if transition.isAnimated {
                            alphaTransition = .animated(duration: 0.18, curve: .easeInOut)
                        } else {
                            alphaTransition = .immediate
                        }
                        alphaTransition.updateAlpha(layer: extractedBackgroundView.layer, alpha: 0.0, completion: { [weak extractedBackgroundView] _ in
                            extractedBackgroundView?.removeFromSuperview()
                        })
                    }
                }
                
                self.containerNode.isGestureEnabled = false
            }
            
            required init?(coder: NSCoder) {
                preconditionFailure()
            }
            
            @objc private func tapGesture(_ recognizer: UITapGestureRecognizer) {
                if case .ended = recognizer.state {
                    if let iconView = self.icon?.view as? EmojiStatusComponent.View {
                        iconView.playOnce()
                    }
                    self.component?.action?()
                }
            }
            
            override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
                var mappedPoint = point
                if self.bounds.insetBy(dx: -8.0, dy: -4.0).contains(point) {
                    mappedPoint = self.bounds.center
                }
                return super.hitTest(mappedPoint, with: event)
            }
            
            func isReorderable(at point: CGPoint) -> Bool {
                guard let component = self.component else {
                    return false
                }
                return component.isReordering
            }
            
            private func updateIsShaking(animated: Bool) {
                guard let component = self.component else {
                    return
                }
                
                if component.isReordering {
                    if self.layer.animation(forKey: "shaking_position") == nil {
                        let degreesToRadians: (_ x: CGFloat) -> CGFloat = { x in
                            return .pi * x / 180.0
                        }
                        
                        let duration: Double = 0.4
                        let displacement: CGFloat = 1.0
                        let degreesRotation: CGFloat = 2.0
                        
                        let negativeDisplacement = -1.0 * displacement
                        let position = CAKeyframeAnimation.init(keyPath: "position")
                        position.beginTime = 0.8
                        position.duration = duration
                        position.values = [
                            NSValue(cgPoint: CGPoint(x: negativeDisplacement, y: negativeDisplacement)),
                            NSValue(cgPoint: CGPoint(x: 0, y: 0)),
                            NSValue(cgPoint: CGPoint(x: negativeDisplacement, y: 0)),
                            NSValue(cgPoint: CGPoint(x: 0, y: negativeDisplacement)),
                            NSValue(cgPoint: CGPoint(x: negativeDisplacement, y: negativeDisplacement))
                        ]
                        position.calculationMode = .linear
                        position.isRemovedOnCompletion = false
                        position.repeatCount = Float.greatestFiniteMagnitude
                        position.beginTime = CFTimeInterval(Float(arc4random()).truncatingRemainder(dividingBy: Float(25)) / Float(100))
                        position.isAdditive = true
                        
                        let transform = CAKeyframeAnimation.init(keyPath: "transform")
                        transform.beginTime = 2.6
                        transform.duration = 0.3
                        transform.valueFunction = CAValueFunction(name: CAValueFunctionName.rotateZ)
                        transform.values = [
                            degreesToRadians(-1.0 * degreesRotation),
                            degreesToRadians(degreesRotation),
                            degreesToRadians(-1.0 * degreesRotation)
                        ]
                        transform.calculationMode = .linear
                        transform.isRemovedOnCompletion = false
                        transform.repeatCount = Float.greatestFiniteMagnitude
                        transform.isAdditive = true
                        transform.beginTime = CFTimeInterval(Float(arc4random()).truncatingRemainder(dividingBy: Float(25)) / Float(100))
                        
                        self.layer.add(position, forKey: "shaking_position")
                        self.layer.add(transform, forKey: "shaking_rotation")
                    }
                } else if self.layer.animation(forKey: "shaking_position") != nil {
                    if let presentationLayer = self.layer.presentation() {
                        let transition: ComponentTransition = .easeInOut(duration: 0.1)
                        if presentationLayer.position != self.layer.position {
                            transition.animatePosition(layer: self.layer, from: CGPoint(x: presentationLayer.position.x - self.layer.position.x, y: presentationLayer.position.y - self.layer.position.y), to: CGPoint(), additive: true)
                        }
                        if !CATransform3DIsIdentity(presentationLayer.transform) {
                            transition.setTransform(layer: self.layer, transform: CATransform3DIdentity)
                        }
                    }
                    
                    self.layer.removeAnimation(forKey: "shaking_position")
                    self.layer.removeAnimation(forKey: "shaking_rotation")
                }
            }
            
            func update(component: HorizontalItemComponent, availableSize: CGSize, state: EmptyComponentState, environment: Environment<Empty>, transition: ComponentTransition) -> CGSize {
                self.component = component
                
                self.tapRecognizer?.isEnabled = component.action != nil
                
                self.containerNode.isGestureEnabled = component.contextGesture != nil
                self.containerNode.activated = { [weak self] gesture, _ in
                    guard let self, let component = self.component else {
                        return
                    }
                    component.contextGesture?(gesture, self.extractedContainerNode)
                }
                
                let leftInset: CGFloat = 12.0
                let rightInset: CGFloat = 12.0
                let spacing: CGFloat = 4.0
                let badgeSpacing: CGFloat = 4.0
                let iconSize = CGSize(width: 18.0, height: 18.0)
                
                var avatarIconContent: EmojiStatusComponent.Content?
                if case let .forum(topicId) = component.item.item.id {
                    if topicId != 1, let threadData = component.item.item.threadData {
                        if let fileId = threadData.info.icon, fileId != 0 {
                            avatarIconContent = .animation(content: .customEmoji(fileId: fileId), size: iconSize, placeholderColor: component.theme.list.mediaPlaceholderColor, themeColor: component.isSelected ? component.theme.rootController.navigationBar.accentTextColor : component.theme.rootController.navigationBar.controlColor, loopMode: .count(0))
                        } else {
                            avatarIconContent = .topic(title: String(threadData.info.title.prefix(1)), color: threadData.info.iconColor, size: iconSize)
                        }
                    } else {
                        avatarIconContent = .image(image: PresentationResourcesChatList.generalTopicTemplateIcon(component.theme), tintColor: component.isSelected ? component.theme.rootController.navigationBar.accentTextColor : component.theme.rootController.navigationBar.controlColor)
                    }
                }
                
                if let avatarIconContent {
                    let avatarIconComponent = EmojiStatusComponent(
                        context: component.context,
                        animationCache: component.context.animationCache,
                        animationRenderer: component.context.animationRenderer,
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
                        containerSize: iconSize
                    )
                } else if let icon = self.icon {
                    self.icon = nil
                    icon.view?.removeFromSuperview()
                }
                
                let titleText: String
                if case let .forum(topicId) = component.item.item.id {
                    let _ = topicId
                    if let threadData = component.item.item.threadData {
                        titleText = threadData.info.title
                    } else {
                        titleText = " "
                    }
                } else {
                    titleText = component.item.item.renderedPeer.chatMainPeer?.compactDisplayTitle ?? " "
                }
                
                if let avatarIconContent, let icon = self.icon {
                    let avatarIconComponent = EmojiStatusComponent(
                        context: component.context,
                        animationCache: component.context.animationCache,
                        animationRenderer: component.context.animationRenderer,
                        content: avatarIconContent,
                        isVisibleForAnimations: false,
                        action: nil
                    )
                    let _ = icon.update(
                        transition: .immediate,
                        component: AnyComponent(avatarIconComponent),
                        environment: {},
                        containerSize: iconSize
                    )
                }
                
                let titleSize = self.title.update(
                    transition: .immediate,
                    component: AnyComponent(MultilineTextComponent(
                        text: .plain(NSAttributedString(string: titleText, font: Font.medium(14.0), textColor: component.isSelected ? component.theme.rootController.navigationBar.accentTextColor : component.theme.rootController.navigationBar.secondaryTextColor)),
                        horizontalAlignment: .center,
                        maximumNumberOfLines: 2
                    )),
                    environment: {},
                    containerSize: CGSize(width: availableSize.width - 6.0 * 2.0, height: 100.0)
                )
                
                var badgeSize: CGSize?
                if let readCounters = component.item.item.readCounters, readCounters.count > 0 {
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
                            font: Font.medium(12.0),
                            background: component.item.item.isMuted ? component.theme.chatList.unreadBadgeInactiveBackgroundColor : component.theme.chatList.unreadBadgeActiveBackgroundColor,
                            foreground: component.item.item.isMuted ? component.theme.chatList.unreadBadgeInactiveTextColor : component.theme.chatList.unreadBadgeActiveTextColor,
                            insets: UIEdgeInsets(top: 1.0, left: 5.0, bottom: 2.0, right: 5.0)
                        )),
                        environment: {},
                        containerSize: CGSize(width: 100.0, height: 100.0)
                    )
                } else if let badge = self.badge {
                    self.badge = nil
                    badge.view?.removeFromSuperview()
                }
                
                var contentSize: CGFloat = leftInset + rightInset + iconSize.width + spacing + titleSize.width
                if let badgeSize {
                    contentSize += badgeSize.width + badgeSpacing
                }
                let size = CGSize(width: contentSize, height: availableSize.height)
                
                let iconFrame = CGRect(origin: CGPoint(x: leftInset, y: floor((size.height - iconSize.height) * 0.5)), size: iconSize)
                let titleFrame = CGRect(origin: CGPoint(x: iconFrame.maxX + spacing, y: floor((size.height - titleSize.height) * 0.5)), size: titleSize)
                
                if let icon = self.icon {
                    if let avatarNode = self.avatarNode {
                        self.avatarNode = nil
                        avatarNode.view.removeFromSuperview()
                    }
                    
                    if let iconView = icon.view {
                        if iconView.superview == nil {
                            iconView.isUserInteractionEnabled = false
                            self.containerButton.addSubview(iconView)
                        }
                        iconView.frame = iconFrame
                    }
                } else {
                    let avatarNode: AvatarNode
                    if let current = self.avatarNode {
                        avatarNode = current
                    } else {
                        avatarNode = AvatarNode(font: avatarPlaceholderFont(size: 8.0))
                        avatarNode.isUserInteractionEnabled = false
                        self.avatarNode = avatarNode
                        self.containerButton.addSubview(avatarNode.view)
                    }
                    avatarNode.frame = iconFrame
                    avatarNode.updateSize(size: iconFrame.size)
                    
                    if let peer = component.item.item.renderedPeer.chatMainPeer {
                        if peer.smallProfileImage != nil {
                            avatarNode.setPeerV2(context: component.context, theme: component.theme, peer: peer, overrideImage: nil, emptyColor: .gray, clipStyle: .round, synchronousLoad: false, displayDimensions: iconFrame.size)
                        } else {
                            avatarNode.setPeer(context: component.context, theme: component.theme, peer: peer, overrideImage: nil, emptyColor: .gray, clipStyle: .round, synchronousLoad: false, displayDimensions: iconFrame.size)
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
                
                if let badge = self.badge, let badgeSize {
                    let badgeFrame = CGRect(origin: CGPoint(x: titleFrame.maxX + badgeSpacing, y: floor((size.height - badgeSize.height) * 0.5)), size: badgeSize)
                    if let badgeView = badge.view {
                        if badgeView.superview == nil {
                            self.containerButton.addSubview(badgeView)
                        }
                        badgeView.frame = badgeFrame
                    }
                }
                
                transition.setFrame(view: self.containerButton, frame: CGRect(origin: CGPoint(), size: size))
                
                self.extractedContainerNode.frame = CGRect(origin: CGPoint(), size: size)
                self.extractedContainerNode.contentNode.frame = CGRect(origin: CGPoint(), size: size)
                self.extractedContainerNode.contentRect = CGRect(origin: CGPoint(x: 0.0, y: 0.0), size: CGSize(width: size.width, height: size.height))
                self.containerNode.frame = CGRect(origin: CGPoint(), size: size)
                
                self.updateIsShaking(animated: !transition.animation.isImmediate)
                
                return size
            }
        }
        
        func makeView() -> View {
            return View(frame: CGRect())
        }
        
        func update(view: View, availableSize: CGSize, state: EmptyComponentState, environment: Environment<Empty>, transition: ComponentTransition) -> CGSize {
            return view.update(component: self, availableSize: availableSize, state: state, environment: environment, transition: transition)
        }
    }
    
    private final class TabItemView: UIView {
        private let context: AccountContext
        private let action: () -> Void
        
        private let extractedContainerNode: ContextExtractedContentContainingNode
        private let containerNode: ContextControllerSourceNode
        
        private let containerButton: HighlightTrackingButton
        
        private var icon = ComponentView<Empty>()
        
        private var isReordering: Bool = false
        
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
            return super.hitTest(point, with: event)
        }
        
        func update(context: AccountContext, theme: PresentationTheme, width: CGFloat, location: Location, isReordering: Bool, transition: ComponentTransition) -> CGSize {
            let alphaTransition: ComponentTransition = transition.animation.isImmediate ? .immediate : .easeInOut(duration: 0.2)
            
            var animateIconIn = false
            if self.isReordering != isReordering {
                self.isReordering = isReordering
                if let iconView = self.icon.view {
                    self.icon = ComponentView()
                    transition.setScale(view: iconView, scale: 0.001)
                    alphaTransition.setAlpha(view: iconView, alpha: 0.0, completion: { [weak iconView] _ in
                        iconView?.removeFromSuperview()
                    })
                    animateIconIn = true
                }
            }
            
            let iconSize = self.icon.update(
                transition: .immediate,
                component: AnyComponent(BundleIconComponent(
                    name: isReordering ? "Media Editor/Done" : "Chat/Title Panels/SidebarIcon",
                    tintColor: location == .side ? theme.rootController.navigationBar.accentTextColor : theme.rootController.navigationBar.secondaryTextColor,
                    maxSize: CGSize(width: 24.0, height: 24.0),
                    scaleFactor: 1.0
                )),
                environment: {},
                containerSize: CGSize(width: 100.0, height: 100.0)
            )
            
            let topInset: CGFloat = 10.0
            let bottomInset: CGFloat = 2.0
            
            let contentSize: CGFloat = topInset + iconSize.height + bottomInset
            let size = CGSize(width: width, height: contentSize)
            
            let iconFrame = CGRect(origin: CGPoint(x: floor((size.width - iconSize.width) * 0.5), y: topInset), size: iconSize)
            
            if let iconView = self.icon.view {
                if iconView.superview == nil {
                    iconView.isUserInteractionEnabled = false
                    self.containerButton.addSubview(iconView)
                }
                iconView.frame = iconFrame
                if animateIconIn {
                    alphaTransition.animateAlpha(view: iconView, from: 0.0, to: 1.0)
                    transition.animateScale(view: iconView, from: 0.001, to: 1.0)
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
    
    private protocol AllItemComponent: AnyObject {
    }
    
    private final class VerticalAllItemComponent: Component, AllItemComponent {
        let isSelected: Bool
        let theme: PresentationTheme
        let strings: PresentationStrings
        let action: (() -> Void)?
        
        init(isSelected: Bool, theme: PresentationTheme, strings: PresentationStrings, action: (() -> Void)?) {
            self.isSelected = isSelected
            self.theme = theme
            self.strings = strings
            self.action = action
        }
        
        static func ==(lhs: VerticalAllItemComponent, rhs: VerticalAllItemComponent) -> Bool {
            if lhs === rhs {
                return true
            }
            if lhs.isSelected != rhs.isSelected {
                return false
            }
            if lhs.theme !== rhs.theme {
                return false
            }
            if lhs.strings !== rhs.strings {
                return false
            }
            if (lhs.action == nil) != (rhs.action == nil) {
                return false
            }
            return true
        }
        
        final class View: UIView {
            private let containerButton: UIView
            
            private let icon = ComponentView<Empty>()
            private let title = ComponentView<Empty>()
            
            private var tapRecognizer: UITapGestureRecognizer?
            
            private var component: VerticalAllItemComponent?
            
            override init(frame: CGRect) {
                self.containerButton = UIView()
                
                super.init(frame: frame)
                
                self.addSubview(self.containerButton)
                let tapRecognizer = UITapGestureRecognizer(target: self, action: #selector(self.tapGesture(_:)))
                self.tapRecognizer = tapRecognizer
                self.containerButton.addGestureRecognizer(tapRecognizer)
                tapRecognizer.isEnabled = false
            }
            
            required init?(coder: NSCoder) {
                fatalError("init(coder:) has not been implemented")
            }
            
            @objc private func tapGesture(_ recognizer: UITapGestureRecognizer) {
                if case .ended = recognizer.state {
                    self.component?.action?()
                }
            }
            
            override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
                var mappedPoint = point
                if self.bounds.insetBy(dx: -8.0, dy: -4.0).contains(point) {
                    mappedPoint = self.bounds.center
                }
                return super.hitTest(mappedPoint, with: event)
            }
            
            func update(component: VerticalAllItemComponent, availableSize: CGSize, state: EmptyComponentState, environment: Environment<Empty>, transition: ComponentTransition) -> CGSize {
                self.component = component
                
                self.tapRecognizer?.isEnabled = component.action != nil
                
                let topInset: CGFloat = 6.0
                let bottomInset: CGFloat = 8.0
                
                let spacing: CGFloat = 1.0
                
                let iconSize = self.icon.update(
                    transition: .immediate,
                    component: AnyComponent(BundleIconComponent(
                        name: "Chat List/Tabs/IconChats",
                        tintColor: component.isSelected ? component.theme.rootController.navigationBar.accentTextColor : component.theme.rootController.navigationBar.secondaryTextColor
                    )),
                    environment: {},
                    containerSize: CGSize(width: 100.0, height: 100.0)
                )
                
                let titleText: String = component.strings.Chat_InlineTopicMenu_AllTab
                let titleSize = self.title.update(
                    transition: .immediate,
                    component: AnyComponent(MultilineTextComponent(
                        text: .plain(NSAttributedString(string: titleText, font: Font.regular(10.0), textColor: component.isSelected ? component.theme.rootController.navigationBar.accentTextColor : component.theme.rootController.navigationBar.secondaryTextColor)),
                        maximumNumberOfLines: 2
                    )),
                    environment: {},
                    containerSize: CGSize(width: availableSize.width - 4.0 * 2.0, height: 100.0)
                )
                
                let contentSize: CGFloat = topInset + bottomInset + iconSize.height + spacing + titleSize.height
                let size = CGSize(width: availableSize.width, height: contentSize)
                
                let iconFrame = CGRect(origin: CGPoint(x: floor((size.width - iconSize.width) * 0.5), y: topInset), size: iconSize)
                let titleFrame = CGRect(origin: CGPoint(x: floor((size.width - titleSize.width) * 0.5), y: iconFrame.maxY + spacing), size: titleSize)
                
                if let iconView = self.icon.view {
                    if iconView.superview == nil {
                        iconView.isUserInteractionEnabled = false
                        self.containerButton.addSubview(iconView)
                    }
                    iconView.frame = iconFrame
                }
                
                if let titleView = self.title.view {
                    if titleView.superview == nil {
                        titleView.isUserInteractionEnabled = false
                        self.containerButton.addSubview(titleView)
                    }
                    titleView.frame = titleFrame
                }
                
                transition.setFrame(view: self.containerButton, frame: CGRect(origin: CGPoint(), size: size))
                
                return size
            }
        }
        
        func makeView() -> View {
            return View(frame: CGRect())
        }
        
        func update(view: View, availableSize: CGSize, state: EmptyComponentState, environment: Environment<Empty>, transition: ComponentTransition) -> CGSize {
            return view.update(component: self, availableSize: availableSize, state: state, environment: environment, transition: transition)
        }
    }
    
    private final class HorizontalAllItemComponent: Component, AllItemComponent {
        let isSelected: Bool
        let theme: PresentationTheme
        let strings: PresentationStrings
        let action: (() -> Void)?
        
        init(isSelected: Bool, theme: PresentationTheme, strings: PresentationStrings, action: (() -> Void)?) {
            self.isSelected = isSelected
            self.theme = theme
            self.strings = strings
            self.action = action
        }
        
        static func ==(lhs: HorizontalAllItemComponent, rhs: HorizontalAllItemComponent) -> Bool {
            if lhs === rhs {
                return true
            }
            if lhs.isSelected != rhs.isSelected {
                return false
            }
            if lhs.theme !== rhs.theme {
                return false
            }
            if lhs.strings !== rhs.strings {
                return false
            }
            if (lhs.action == nil) != (rhs.action == nil) {
                return false
            }
            return true
        }
        
        final class View: UIView {
            private let containerButton: UIView
            
            private let title = ComponentView<Empty>()
            
            private var tapRecognizer: UITapGestureRecognizer?
            
            private var component: HorizontalAllItemComponent?
            
            override init(frame: CGRect) {
                self.containerButton = UIView()
                
                super.init(frame: frame)
                
                self.addSubview(self.containerButton)
                let tapRecognizer = UITapGestureRecognizer(target: self, action: #selector(self.tapGesture(_:)))
                self.tapRecognizer = tapRecognizer
                self.containerButton.addGestureRecognizer(tapRecognizer)
                tapRecognizer.isEnabled = false
            }
            
            required init?(coder: NSCoder) {
                fatalError("init(coder:) has not been implemented")
            }
            
            @objc private func tapGesture(_ recognizer: UITapGestureRecognizer) {
                if case .ended = recognizer.state {
                    self.component?.action?()
                }
            }
            
            override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
                var mappedPoint = point
                if self.bounds.insetBy(dx: -8.0, dy: -4.0).contains(point) {
                    mappedPoint = self.bounds.center
                }
                return super.hitTest(mappedPoint, with: event)
            }
            
            func update(component: HorizontalAllItemComponent, availableSize: CGSize, state: EmptyComponentState, environment: Environment<Empty>, transition: ComponentTransition) -> CGSize {
                self.component = component
                
                self.tapRecognizer?.isEnabled = component.action != nil
                
                let leftInset: CGFloat = 6.0
                let rightInset: CGFloat = 12.0
                
                let titleText: String = component.strings.Chat_InlineTopicMenu_AllTab
                let titleSize = self.title.update(
                    transition: .immediate,
                    component: AnyComponent(MultilineTextComponent(
                        text: .plain(NSAttributedString(string: titleText, font: Font.medium(14.0), textColor: component.isSelected ? component.theme.rootController.navigationBar.accentTextColor : component.theme.rootController.navigationBar.secondaryTextColor)),
                        maximumNumberOfLines: 2
                    )),
                    environment: {},
                    containerSize: CGSize(width: 400.0, height: 200.0)
                )
                
                let contentSize: CGFloat = leftInset + rightInset + titleSize.height
                let size = CGSize(width: contentSize, height: availableSize.height)
                
                let titleFrame = CGRect(origin: CGPoint(x: leftInset, y: floor((size.height - titleSize.height) * 0.5)), size: titleSize)
                
                if let titleView = self.title.view {
                    if titleView.superview == nil {
                        titleView.isUserInteractionEnabled = false
                        self.containerButton.addSubview(titleView)
                    }
                    titleView.frame = titleFrame
                }
                
                transition.setFrame(view: self.containerButton, frame: CGRect(origin: CGPoint(), size: size))
                
                return size
            }
        }
        
        func makeView() -> View {
            return View(frame: CGRect())
        }
        
        func update(view: View, availableSize: CGSize, state: EmptyComponentState, environment: Environment<Empty>, transition: ComponentTransition) -> CGSize {
            return view.update(component: self, availableSize: availableSize, state: state, environment: environment, transition: transition)
        }
    }
    
    private enum ScrollId: Hashable {
        case all
        case topic(Int64)
    }
    
    public final class View: UIView {
        private let list = ComponentView<Empty>()
        private let listState = AsyncListComponent.ExternalState()
        private let scrollContainerView: UIView
        private let scrollViewMask: UIImageView
        
        private var background: ComponentView<Empty>?
        private var separatorLayer: SimpleLayer?
        
        private let selectedLineContainer: AsyncListComponent.OverlayContainerView
        private let selectedLineView: UIImageView
        private let pinnedBackgroundContainer: AsyncListComponent.OverlayContainerView
        private let pinnedBackgroundView: UIImageView
        private let pinnedIconView: UIImageView
        
        private var tabItemView: TabItemView?
        
        private var rawItems: [Item] = []
        private var reorderingItems: [Item]?
        private var resetReorderingOnNextUpdate: Bool = false
        private var itemsContentVersion: Int = 0
        
        private var isTogglingPinnedItem: Bool = false
        private weak var dismissContextControllerOnNextUpdate: ContextController?
        
        private var component: ChatSideTopicsPanel?
        private weak var state: EmptyComponentState?
        private var isUpdating: Bool = false
        
        private var appliedScrollToId: ScrollId?
        private var isReordering: Bool = false
        
        private var itemsDisposable: Disposable?
        
        override public init(frame: CGRect) {
            self.selectedLineView = UIImageView()
            self.selectedLineView.isHidden = true
            self.selectedLineContainer = AsyncListComponent.OverlayContainerView()
            self.selectedLineContainer.addSubview(self.selectedLineView)
            
            self.pinnedIconView = UIImageView()
            self.pinnedBackgroundView = UIImageView()
            self.pinnedBackgroundContainer = AsyncListComponent.OverlayContainerView()
            self.pinnedBackgroundContainer.addSubview(self.pinnedIconView)
            self.pinnedBackgroundContainer.addSubview(self.pinnedBackgroundView)
            self.pinnedBackgroundContainer.isHidden = true
            
            self.scrollContainerView = UIView()
            self.scrollViewMask = UIImageView()
            self.scrollContainerView.mask = self.scrollViewMask
            
            super.init(frame: frame)
            
            self.addSubview(self.scrollContainerView)
            self.scrollContainerView.addSubview(self.pinnedBackgroundContainer)
            self.scrollContainerView.addSubview(self.selectedLineContainer)
        }
        
        required public init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }
        
        deinit {
            self.itemsDisposable?.dispose()
        }

        public func updateGlobalOffset(globalOffset: CGFloat, transition: ComponentTransition) {
            guard let component = self.component else {
                return
            }
            if let tabItemView = self.tabItemView {
                switch component.location {
                case .side:
                    transition.setTransform(view: tabItemView, transform: CATransform3DMakeTranslation(-globalOffset, 0.0, 0.0))
                case .top:
                    transition.setTransform(view: tabItemView, transform: CATransform3DMakeTranslation(0.0, -globalOffset, 0.0))
                }
            }
        }
        
        public func topicIndex(threadId: Int64?) -> Int? {
            if let threadId {
                if let value = self.rawItems.firstIndex(where: { item in
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
            }
        }
        
        private func updateListOverlays(visibleItems: AsyncListComponent.VisibleItems, transition: ComponentTransition) {
            guard let component = self.component, let listView = self.list.view else {
                return
            }
            
            var selectedItemFrame: CGRect?
            var beforePinnedItemsPosition: CGFloat?
            var afterPinnedItemsPosition: CGFloat?
            var seenPinnedItems = false
            for item in visibleItems {
                if let _ = item.item.component.wrapped as? AllItemComponent {
                    if component.topicId == nil {
                        switch component.location {
                        case .side:
                            selectedItemFrame = item.frame
                        case .top:
                            selectedItemFrame = CGRect(origin: CGPoint(x: item.frame.minX + 5.0, y: item.frame.minY), size: CGSize(width: item.frame.width - 4.0 - 11.0, height: item.frame.height))
                        }
                    }
                    if !seenPinnedItems {
                        switch component.location {
                        case .side:
                            beforePinnedItemsPosition = item.frame.maxY
                        case .top:
                            beforePinnedItemsPosition = item.frame.maxX
                        }
                    }
                } else if let itemComponent = item.item.component.wrapped as? ItemComponent {
                    let topicId: Int64
                    switch itemComponent.item.item.id {
                    case let .chatList(peerId):
                        topicId = peerId.toInt64()
                    case let .forum(topicIdValue):
                        topicId = topicIdValue
                    }
                    if topicId == component.topicId {
                        selectedItemFrame = item.frame
                    }
                    
                    var isPinned = false
                    if case let .forum(pinnedIndex, _, _, _, _) = itemComponent.item.item.index {
                        if case .index = pinnedIndex {
                            isPinned = true
                        }
                    }
                    if isPinned {
                        seenPinnedItems = true
                    } else {
                        if !seenPinnedItems {
                            switch component.location {
                            case .side:
                                beforePinnedItemsPosition = item.frame.maxY
                            case .top:
                                beforePinnedItemsPosition = item.frame.maxX
                            }
                        } else {
                            if afterPinnedItemsPosition == nil {
                                switch component.location {
                                case .side:
                                    afterPinnedItemsPosition = item.frame.minY
                                case .top:
                                    afterPinnedItemsPosition = item.frame.minX
                                }
                            }
                        }
                    }
                }
            }
            
            if seenPinnedItems {
                if beforePinnedItemsPosition == nil {
                    beforePinnedItemsPosition = -500.0
                }
                if afterPinnedItemsPosition == nil {
                    switch component.location {
                    case .side:
                        afterPinnedItemsPosition = listView.bounds.height + 500.0
                    case .top:
                        afterPinnedItemsPosition = listView.bounds.width + 500.0
                    }
                }
            }
            
            if let selectedItemFrame {
                var lineTransition = transition
                if self.selectedLineView.isHidden {
                    self.selectedLineView.isHidden = false
                    lineTransition = .immediate
                }
                let selectedLineFrame: CGRect
                switch component.location {
                case .side:
                    selectedLineFrame = CGRect(origin: CGPoint(x: 0.0, y: selectedItemFrame.minY), size: CGSize(width: 4.0, height: selectedItemFrame.height))
                case .top:
                    selectedLineFrame = CGRect(origin: CGPoint(x: selectedItemFrame.minX, y: listView.frame.maxY - 3.0), size: CGSize(width: selectedItemFrame.width, height: 3.0))
                }
                
                self.selectedLineContainer.updatePosition(position: selectedLineFrame.origin, transition: lineTransition)
                lineTransition.setFrame(view: self.selectedLineView, frame: CGRect(origin: CGPoint(), size: selectedLineFrame.size))
            } else {
                self.selectedLineView.isHidden = true
            }
            
            if let beforePinnedItemsPosition, let afterPinnedItemsPosition, afterPinnedItemsPosition > beforePinnedItemsPosition {
                var pinnedItemsTransition = transition
                if self.pinnedBackgroundContainer.isHidden {
                    self.pinnedBackgroundContainer.isHidden = false
                    pinnedItemsTransition = .immediate
                }
                let pinnedItemsBackgroundFrame: CGRect
                switch component.location {
                case .side:
                    pinnedItemsBackgroundFrame = CGRect(origin: CGPoint(x: 5.0, y: beforePinnedItemsPosition), size: CGSize(width: listView.bounds.width - 5.0 - 4.0, height: afterPinnedItemsPosition - beforePinnedItemsPosition))
                case .top:
                    pinnedItemsBackgroundFrame = CGRect(origin: CGPoint(x: beforePinnedItemsPosition, y: 4.0), size: CGSize(width: afterPinnedItemsPosition - beforePinnedItemsPosition, height: listView.bounds.height - 5.0 - 4.0))
                }
                self.pinnedBackgroundContainer.updatePosition(position: pinnedItemsBackgroundFrame.origin, transition: pinnedItemsTransition)
                pinnedItemsTransition.setFrame(view: self.pinnedBackgroundView, frame: CGRect(origin: CGPoint(), size: pinnedItemsBackgroundFrame.size))
                
                let pinnedIconFrame = CGRect(origin: CGPoint(x: 2.0, y: 2.0), size: CGSize(width: 12.0, height: 12.0))
                pinnedItemsTransition.setFrame(view: self.pinnedIconView, frame: pinnedIconFrame)
            } else {
                self.pinnedBackgroundContainer.isHidden = true
            }
        }
        
        private func updateIsReordering(isReordering: Bool) {
            self.isReordering = isReordering
            if !self.isUpdating {
                self.state?.updated(transition: .spring(duration: 0.4))
            }
        }
        
        func update(component: ChatSideTopicsPanel, availableSize: CGSize, state: EmptyComponentState, environment: Environment<EnvironmentType>, transition: ComponentTransition) -> CGSize {
            self.isUpdating = true
            defer {
                self.isUpdating = false
            }
            
            self.state = state
            
            if self.resetReorderingOnNextUpdate {
                self.resetReorderingOnNextUpdate = false
                self.reorderingItems = nil
                self.isReordering = false
            }
            
            if self.component == nil {
                let threadListSignal: Signal<EngineChatList, NoError> = component.context.sharedContext.subscribeChatListData(context: component.context, location: component.isMonoforum ? .savedMessagesChats(peerId: component.peerId) : .forum(peerId: component.peerId))
                
                self.itemsDisposable = (threadListSignal
                |> deliverOnMainQueue).startStrict(next: { [weak self] chatList in
                    guard let self else {
                        return
                    }
                    
                    let wasEmpty = self.rawItems.isEmpty
                    
                    self.rawItems.removeAll()
                    for item in chatList.items.reversed() {
                        self.rawItems.append(Item(item: item))
                    }
                    
                    if self.reorderingItems != nil {
                        self.reorderingItems = self.rawItems
                    }
                    
                    if !self.isUpdating {
                        self.state?.updated(transition: (wasEmpty || self.isTogglingPinnedItem) ? .immediate : .spring(duration: 0.4))
                    }
                })
                
                switch component.location {
                case .side:
                    self.scrollViewMask.image = generateGradientImage(size: CGSize(width: 8.0, height: 8.0), colors: [
                        UIColor(white: 1.0, alpha: 0.0),
                        UIColor(white: 1.0, alpha: 1.0)
                    ], locations: [0.0, 1.0], direction: .vertical)?.stretchableImage(withLeftCapWidth: 0, topCapHeight: 8)
                case .top:
                    self.scrollViewMask.image = generateGradientImage(size: CGSize(width: 8.0, height: 8.0), colors: [
                        UIColor(white: 1.0, alpha: 0.0),
                        UIColor(white: 1.0, alpha: 1.0)
                    ], locations: [0.0, 1.0], direction: .horizontal)?.stretchableImage(withLeftCapWidth: 8, topCapHeight: 0)
                }
            }
            let themeUpdated = self.component?.theme !== component.theme
            self.component = component
            
            if case .side = component.location {
                let background: ComponentView<Empty>
                if let current = self.background {
                    background = current
                } else {
                    background = ComponentView()
                    self.background = background
                }
                let _ = background.update(
                    transition: transition,
                    component: AnyComponent(BlurredBackgroundComponent(
                        color: component.theme.rootController.navigationBar.blurredBackgroundColor
                    )),
                    environment: {},
                    containerSize: availableSize
                )
                
                if let backgroundView = background.view {
                    if backgroundView.superview == nil {
                        self.insertSubview(backgroundView, at: 0)
                    }
                    transition.setFrame(view: backgroundView, frame: CGRect(origin: CGPoint(), size: availableSize))
                }
                
                let separatorLayer: SimpleLayer
                if let current = self.separatorLayer {
                    separatorLayer = current
                } else {
                    separatorLayer = SimpleLayer()
                    self.separatorLayer = separatorLayer
                    self.layer.addSublayer(separatorLayer)
                }
                if themeUpdated {
                    separatorLayer.backgroundColor = component.theme.rootController.navigationBar.separatorColor.cgColor
                }
                
                transition.setFrame(layer: separatorLayer, frame: CGRect(origin: CGPoint(x: availableSize.width, y: 0.0), size: CGSize(width: UIScreenPixel, height: availableSize.height)))
            }
            
            if themeUpdated {
                switch component.location {
                case .side:
                    self.selectedLineView.image = generateImage(CGSize(width: 4.0, height: 7.0), rotatedContext: { size, context in
                        context.clear(CGRect(origin: CGPoint(), size: size))
                        context.setFillColor(component.theme.rootController.navigationBar.accentTextColor.cgColor)
                        context.fillEllipse(in: CGRect(origin: CGPoint(x: size.width - size.height, y: 0.0), size: CGSize(width: size.height, height: size.height)))
                    })?.stretchableImage(withLeftCapWidth: 1, topCapHeight: 4)
                case .top:
                    self.selectedLineView.image = generateImage(CGSize(width: 4.0, height: 3.0), rotatedContext: { size, context in
                        context.clear(CGRect(origin: CGPoint(), size: size))
                        context.setFillColor(component.theme.rootController.navigationBar.accentTextColor.cgColor)
                        context.addPath(UIBezierPath(roundedRect: CGRect(origin: CGPoint(), size: CGSize(width: size.width, height: size.height * 2.0)), cornerRadius: 2.0).cgPath)
                        context.fillPath()
                    })?.stretchableImage(withLeftCapWidth: 2, topCapHeight: 1)
                }
                
                if self.pinnedIconView.image == nil {
                    self.pinnedIconView.image = generateTintedImage(image: UIImage(bundleImageName: "Chat/Message/Pinned"), color: .white)?.withRenderingMode(.alwaysTemplate)
                }
                self.pinnedIconView.tintColor = component.theme.chatList.unreadBadgeInactiveBackgroundColor
                
                if self.pinnedBackgroundView.image == nil {
                    self.pinnedBackgroundView.image = generateStretchableFilledCircleImage(diameter: 10.0, color: .white)?.withRenderingMode(.alwaysTemplate)
                }
                var pinnedBackgroundColor = component.theme.rootController.navigationSearchBar.inputFillColor
                if pinnedBackgroundColor.distance(to: component.theme.list.blocksBackgroundColor) < 100 {
                    pinnedBackgroundColor = pinnedBackgroundColor.withMultipliedBrightnessBy(0.8)
                }
                self.pinnedBackgroundView.tintColor = pinnedBackgroundColor
            }
            
            let environment = environment[EnvironmentType.self].value
            
            let containerInsets = environment.insets
            
            var directionContainerInset: CGFloat
            switch component.location {
            case .side:
                directionContainerInset = containerInsets.top
            case .top:
                directionContainerInset = containerInsets.left
            }
            
            do {
                var itemTransition = transition
                var animateIn = false
                let itemView: TabItemView
                if let current = self.tabItemView {
                    itemView = current
                } else {
                    itemTransition = .immediate
                    animateIn = true
                    itemView = TabItemView(context: component.context, action: { [weak self] in
                        guard let self, let component = self.component else {
                            return
                        }
                        if self.isReordering {
                            if let reorderingItems = self.reorderingItems {
                                var threadIds: [Int64] = []
                                for item in reorderingItems {
                                    if case let .forum(pinnedIndex, _, threadId, _, _) = item.item.index, case .index = pinnedIndex {
                                        threadIds.append(threadId)
                                    }
                                }
                                
                                var currentThreadIds: [Int64] = []
                                for item in self.rawItems {
                                    if case let .forum(pinnedIndex, _, threadId, _, _) = item.item.index, case .index = pinnedIndex {
                                        currentThreadIds.append(threadId)
                                    }
                                }
                                
                                if threadIds != currentThreadIds {
                                    let _ = component.context.engine.peers.setForumChannelPinnedTopics(id: component.peerId, threadIds: threadIds).startStandalone()
                                    self.resetReorderingOnNextUpdate = true
                                } else {
                                    self.reorderingItems = nil
                                    self.isReordering = false
                                    self.state?.updated(transition: .spring(duration: 0.4))
                                }
                            } else {
                                self.isReordering = false
                                self.state?.updated(transition: .spring(duration: 0.4))
                            }
                        } else {
                            component.togglePanel()
                        }
                    })
                    self.tabItemView = itemView
                    self.addSubview(itemView)
                }
                
                let itemSize = itemView.update(context: component.context, theme: component.theme, width: 72.0, location: component.location, isReordering: self.isReordering, transition: itemTransition)
                let itemFrame: CGRect
                switch component.location {
                case .side:
                    itemFrame = CGRect(origin: CGPoint(x: 0.0, y: directionContainerInset), size: itemSize)
                    directionContainerInset += itemSize.height
                case .top:
                    itemFrame = CGRect(origin: CGPoint(x: directionContainerInset, y: 0.0), size: itemSize)
                    directionContainerInset += itemSize.width - 14.0
                }
                
                itemTransition.setPosition(layer: itemView.layer, position: itemFrame.center)
                itemTransition.setBounds(layer: itemView.layer, bounds: CGRect(origin: CGPoint(), size: itemFrame.size))
                
                if animateIn && !transition.animation.isImmediate {
                    itemView.layer.animateAlpha(from: 0.0, to: itemView.alpha, duration: 0.15)
                    transition.containedViewLayoutTransition.animateTransformScale(view: itemView, from: 0.001)
                }
            }
            
            let scrollSize: CGSize
            let scrollFrame: CGRect
            let listContentInsets: UIEdgeInsets
            switch component.location {
            case .side:
                scrollSize = CGSize(width: availableSize.width, height: availableSize.height - directionContainerInset)
                scrollFrame = CGRect(origin: CGPoint(x: 0.0, y: directionContainerInset), size: scrollSize)
                listContentInsets = UIEdgeInsets(top: 8.0 + environment.insets.top, left: 0.0, bottom: 8.0 + environment.insets.bottom, right: 0.0)
            case .top:
                scrollSize = CGSize(width: availableSize.width - directionContainerInset, height: availableSize.height)
                scrollFrame = CGRect(origin: CGPoint(x: directionContainerInset, y: 0.0), size: scrollSize)
                listContentInsets = UIEdgeInsets(top: 0.0, left: 8.0, bottom: 0.0, right: 8.0)
            }
            
            self.scrollContainerView.frame = scrollFrame
            self.scrollViewMask.frame = CGRect(origin: CGPoint(x: 0.0, y: 0.0), size: scrollSize)
            
            let scrollToId: ScrollId
            if let threadId = component.topicId {
                scrollToId = .topic(threadId)
            } else {
                scrollToId = .all
            }
            if self.appliedScrollToId != scrollToId {
                self.appliedScrollToId = scrollToId
                self.listState.resetScrolling(id: AnyHashable(scrollToId))
            }
            
            var listItems: [AnyComponentWithIdentity<Empty>] = []
            switch component.location {
            case .side:
                listItems.append(AnyComponentWithIdentity(
                    id: ScrollId.all,
                    component: AnyComponent(VerticalAllItemComponent(
                        isSelected: component.topicId == nil,
                        theme: component.theme,
                        strings: component.strings,
                        action: { [weak self] in
                            guard let self, let component = self.component else {
                                return
                            }
                            component.updateTopicId(nil, false)
                        }
                    )))
                )
            case .top:
                listItems.append(AnyComponentWithIdentity(
                    id: ScrollId.all,
                    component: AnyComponent(HorizontalAllItemComponent(
                        isSelected: component.topicId == nil,
                        theme: component.theme,
                        strings: component.strings,
                        action: { [weak self] in
                            guard let self, let component = self.component else {
                                return
                            }
                            component.updateTopicId(nil, false)
                        }
                    )))
                )
            }
            for item in self.reorderingItems ?? self.rawItems {
                let scrollId: ScrollId
                let topicId: Int64
                var isItemReordering = false
                switch item.item.id {
                case let .chatList(peerId):
                    topicId = peerId.toInt64()
                case let .forum(topicIdValue):
                    topicId = topicIdValue
                    if self.isReordering {
                        if case let .forum(pinnedIndex, _, _, _, _) = item.item.index, case .index = pinnedIndex {
                            isItemReordering = true
                        }
                    }
                }
                scrollId = .topic(topicId)
                
                let itemAction: (() -> Void)? = self.isReordering ? nil : { [weak self] in
                    guard let self, let component = self.component else {
                        return
                    }
                    
                    let direction: Bool
                    if let lhsIndex = self.topicIndex(threadId: component.topicId), let rhsIndex = self.topicIndex(threadId: topicId) {
                        direction = lhsIndex < rhsIndex
                    } else {
                        direction = false
                    }
                    component.updateTopicId(topicId, direction)
                }
                var itemContextGesture: ((ContextGesture, ContextExtractedContentContainingNode) -> Void)?
                if !self.isReordering && component.isMonoforum {
                    itemContextGesture = { [weak self] gesture, sourceNode in
                        Task { @MainActor in
                            guard let self, let component = self.component else {
                                return
                            }
                            guard let controller = component.controller() else {
                                return
                            }
                            
                            let presentationData = component.context.sharedContext.currentPresentationData.with({ $0 })
                            
                            if let listView = self.list.view as? AsyncListComponent.View {
                                listView.stopScrolling()
                            }
                            
                            let topicId: Int64
                            switch item.item.id {
                            case let .chatList(peerId):
                                topicId = peerId.toInt64()
                            case let .forum(topicIdValue):
                                topicId = topicIdValue
                            }
                            
                            var items: [ContextMenuItem] = []
                            
                            let threadInfo = await component.context.engine.data.get(
                                TelegramEngine.EngineData.Item.Messages.ThreadInfo(peerId: component.peerId, threadId: topicId)
                            ).get()
                            
                            if let threadInfo, threadInfo.isMessageFeeRemoved {
                                items.append(.action(ContextMenuActionItem(text: presentationData.strings.Chat_ReinstatePaidMessages, textColor: .primary, icon: { theme in generateTintedImage(image: UIImage(bundleImageName: "Chat/Context Menu/Rate"), color: theme.contextMenu.primaryColor) }, action: { [weak self] c, _ in
                                    guard let self, let component = self.component else {
                                        return
                                    }
                                    
                                    c?.dismiss(completion: {})
                                    
                                    let _ = component.context.engine.peers.reinstateNoPaidMessagesException(scopePeerId: component.peerId, peerId: EnginePeer.Id(topicId)).startStandalone()
                                })))
                            }
                            
                            if !items.isEmpty {
                                items.append(.separator)
                            }
                            items.append(.action(ContextMenuActionItem(text: presentationData.strings.ChatList_Context_Delete, textColor: .destructive, icon: { theme in generateTintedImage(image: UIImage(bundleImageName: "Chat/Context Menu/Delete"), color: theme.contextMenu.destructiveColor) }, action: { [weak self] c, _ in
                                guard let self else {
                                    return
                                }
                                
                                c?.dismiss(completion: { [weak self] in
                                    guard let self, let component = self.component else {
                                        return
                                    }
                                    component.openDeletePeer(topicId)
                                })
                            })))
                            
                            let contextController = ContextController(
                                presentationData: presentationData,
                                source: .extracted(ItemExtractedContentSource(
                                    sourceNode: sourceNode,
                                    containerView: self,
                                    keepInPlace: false
                                )),
                                items: .single(ContextController.Items(content: .list(items))),
                                recognizer: nil,
                                gesture: gesture
                            )
                            controller.presentInGlobalOverlay(contextController)
                        }
                    }
                } else if !self.isReordering {
                    itemContextGesture = { [weak self] gesture, sourceNode in
                        guard let self, let component = self.component else {
                            return
                        }
                        guard let controller = component.controller() else {
                            return
                        }
                        
                        let presentationData = component.context.sharedContext.currentPresentationData.with({ $0 })
                        
                        if let listView = self.list.view as? AsyncListComponent.View {
                            listView.stopScrolling()
                        }
                        
                        let topicId: Int64
                        switch item.item.id {
                        case let .chatList(peerId):
                            topicId = peerId.toInt64()
                        case let .forum(topicIdValue):
                            topicId = topicIdValue
                        }
                        
                        var isPinned = false
                        if case let .forum(pinnedIndex, _, _, _, _) = item.item.index {
                            if case .index = pinnedIndex {
                                isPinned = true
                            }
                        }
                        let isClosed = item.item.threadData?.isClosed
                        let threadData = item.item.threadData
                        
                        let _ = (chatForumTopicMenuItems(
                            context: component.context,
                            peerId: component.peerId,
                            threadId: topicId,
                            isPinned: isPinned,
                            isClosed: isClosed,
                            chatListController: controller,
                            joined: true,
                            canSelect: false,
                            customEdit: { [weak self] contextController in
                                contextController.dismiss(completion: {
                                    guard let self, let component = self.component, let threadData else {
                                        return
                                    }
                                    let editController = component.context.sharedContext.makeEditForumTopicScreen(
                                        context: component.context,
                                        peerId: component.peerId,
                                        threadId: topicId,
                                        threadInfo: threadData.info,
                                        isHidden: threadData.isHidden
                                    )
                                    component.controller()?.push(editController)
                                })
                            },
                            customPinUnpin: { [weak self] contextController in
                                guard let self, let component = self.component else {
                                    contextController.dismiss(completion: {})
                                    return
                                }
                                
                                self.isTogglingPinnedItem = true
                                self.dismissContextControllerOnNextUpdate = contextController
                                
                                let _ = (component.context.engine.peers.toggleForumChannelTopicPinned(id: component.peerId, threadId: topicId)
                                         |> deliverOnMainQueue).startStandalone(error: { [weak self, weak contextController] error in
                                    guard let self, let component = self.component else {
                                        contextController?.dismiss(completion: {})
                                        return
                                    }
                                    
                                    switch error {
                                    case let .limitReached(count):
                                        contextController?.dismiss(completion: {})
                                        if let controller = component.controller() {
                                            let presentationData = component.context.sharedContext.currentPresentationData.with { $0 }
                                            let text = presentationData.strings.ChatList_MaxThreadPinsFinalText(Int32(count))
                                            controller.present(textAlertController(context: component.context, title: presentationData.strings.Premium_LimitReached, text: text, actions: [TextAlertAction(type: .defaultAction, title: presentationData.strings.Common_OK, action: {})], parseMarkdown: true), in: .window(.root))
                                        }
                                    default:
                                        break
                                    }
                                })
                            },
                            reorder: { [weak self] in
                                guard let self else {
                                    return
                                }
                                self.updateIsReordering(isReordering: true)
                            }
                        )
                        |> take(1)
                        |> deliverOnMainQueue).startStandalone(next: { [weak self, weak sourceNode, weak gesture] items in
                            guard let self, let component = self.component else {
                                return
                            }
                            guard let controller = component.controller() else {
                                return
                            }
                            guard let sourceNode else {
                                return
                            }
                            
                            let contextController = ContextController(
                                presentationData: presentationData,
                                source: .extracted(ItemExtractedContentSource(
                                    sourceNode: sourceNode,
                                    containerView: self,
                                    keepInPlace: false
                                )),
                                items: .single(ContextController.Items(content: .list(items))),
                                recognizer: nil,
                                gesture: gesture
                            )
                            controller.presentInGlobalOverlay(contextController)
                        })
                    }
                }
                
                switch component.location {
                case .side:
                    listItems.append(AnyComponentWithIdentity(
                        id: scrollId,
                        component: AnyComponent(VerticalItemComponent(
                            context: component.context,
                            item: item,
                            isSelected: component.topicId == topicId,
                            isReordering: isItemReordering,
                            theme: component.theme,
                            strings: component.strings,
                            action: itemAction,
                            contextGesture: itemContextGesture
                        )))
                    )
                case .top:
                    listItems.append(AnyComponentWithIdentity(
                        id: scrollId,
                        component: AnyComponent(HorizontalItemComponent(
                            context: component.context,
                            item: item,
                            isSelected: component.topicId == topicId,
                            isReordering: isItemReordering,
                            theme: component.theme,
                            strings: component.strings,
                            action: itemAction,
                            contextGesture: itemContextGesture
                        )))
                    )
                }
            }
            
            let _ = self.list.update(
                transition: transition,
                component: AnyComponent(AsyncListComponent(
                    externalState: self.listState,
                    items: listItems,
                    itemSetId: AnyHashable(self.itemsContentVersion),
                    direction: component.location == .side ? .vertical : .horizontal,
                    insets: listContentInsets,
                    reorderItems: { [weak self] fromIndex, toIndex in
                        guard let self else {
                            return false
                        }
                        if !self.isReordering {
                            return false
                        }
                        
                        if self.reorderingItems == nil {
                            self.reorderingItems = self.rawItems
                        }
                        if var reorderingItems = self.reorderingItems {
                            var maxToIndex = -1
                            for item in reorderingItems {
                                if case let .forum(pinnedIndex, _, _, _, _) = item.item.index, case .index = pinnedIndex {
                                    maxToIndex += 1
                                } else {
                                    break
                                }
                            }
                            
                            let fromItemIndex = fromIndex - 1
                            // Account for synthesized "all" item: [all, item_0, item_1, ...]
                            let toItemIndex = max(0, min(maxToIndex, toIndex - 1))
                            if fromItemIndex == toItemIndex {
                                return false
                            }
                            
                            let reorderingItem = reorderingItems[fromItemIndex]
                            if toItemIndex < fromItemIndex {
                                reorderingItems.remove(at: fromItemIndex)
                                reorderingItems.insert(reorderingItem, at: toItemIndex)
                            } else {
                                reorderingItems.insert(reorderingItem, at: toItemIndex + 1)
                                reorderingItems.remove(at: fromItemIndex)
                            }
                            
                            self.reorderingItems = reorderingItems
                            self.state?.updated(transition: .spring(duration: 0.4))
                        }
                        
                        return true
                    },
                    onVisibleItemsUpdated: { [weak self] visibleItems, transition in
                        guard let self else {
                            return
                        }
                        self.updateListOverlays(visibleItems: visibleItems, transition: transition)
                    }
                )),
                environment: {},
                containerSize: scrollSize
            )
            if let listView = self.list.view {
                if listView.superview == nil {
                    self.scrollContainerView.addSubview(listView)
                }
                transition.setFrame(view: listView, frame: CGRect(origin: CGPoint(), size: scrollSize))
            }
            
            if self.isTogglingPinnedItem {
                self.isTogglingPinnedItem = false
            }
            if let dismissContextControllerOnNextUpdate = self.dismissContextControllerOnNextUpdate {
                self.dismissContextControllerOnNextUpdate = nil
                dismissContextControllerOnNextUpdate.dismiss(completion: {})
            }
            
            return availableSize
        }
    }
    
    public func makeView() -> View {
        return View(frame: CGRect())
    }
    
    public func update(view: View, availableSize: CGSize, state: EmptyComponentState, environment: Environment<EnvironmentType>, transition: ComponentTransition) -> CGSize {
        return view.update(component: self, availableSize: availableSize, state: state, environment: environment, transition: transition)
    }
}

private final class ItemExtractedContentSource: ContextExtractedContentSource {
    let keepInPlace: Bool
    let ignoreContentTouches: Bool = true
    let blurBackground: Bool = true
    let adjustContentForSideInset: Bool = true
    
    private let sourceNode: ContextExtractedContentContainingNode
    private weak var containerView: UIView?
    
    init(sourceNode: ContextExtractedContentContainingNode, containerView: UIView, keepInPlace: Bool) {
        self.sourceNode = sourceNode
        self.containerView = containerView
        self.keepInPlace = keepInPlace
    }
    
    func takeView() -> ContextControllerTakeViewInfo? {
        var contentArea: CGRect?
        if let containerView = self.containerView {
            contentArea = containerView.convert(containerView.bounds, to: nil)
        }
        
        return ContextControllerTakeViewInfo(
            containingItem: .node(self.sourceNode),
            contentAreaInScreenSpace: contentArea ?? UIScreen.main.bounds
        )
    }
    
    func putBack() -> ContextControllerPutBackViewInfo? {
        return ContextControllerPutBackViewInfo(contentAreaInScreenSpace: UIScreen.main.bounds)
    }
}
