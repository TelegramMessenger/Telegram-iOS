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

private final class CustomBadgeComponent: Component {
    public let text: String
    public let font: UIFont
    public let background: UIColor
    public let foreground: UIColor
    public let insets: UIEdgeInsets
    
    public init(
        text: String,
        font: UIFont,
        background: UIColor,
        foreground: UIColor,
        insets: UIEdgeInsets
    ) {
        self.text = text
        self.font = font
        self.background = background
        self.foreground = foreground
        self.insets = insets
    }
    
    public static func ==(lhs: CustomBadgeComponent, rhs: CustomBadgeComponent) -> Bool {
        if lhs.text != rhs.text {
            return false
        }
        if lhs.font != rhs.font {
            return false
        }
        if lhs.background != rhs.background {
            return false
        }
        if lhs.foreground != rhs.foreground {
            return false
        }
        if lhs.insets != rhs.insets {
            return false
        }
        return true
    }
    
    private struct TextLayout {
        var size: CGSize
        var opticalBounds: CGRect
        
        init(size: CGSize, opticalBounds: CGRect) {
            self.size = size
            self.opticalBounds = opticalBounds
        }
    }
    
    public final class View: UIView {
        private let backgroundView: UIImageView
        private let textContentsView: UIImageView
        
        private var textLayout: TextLayout?
        
        private var component: CustomBadgeComponent?
        
        override public init(frame: CGRect) {
            self.backgroundView = UIImageView()
            
            self.textContentsView = UIImageView()
            self.textContentsView.layer.anchorPoint = CGPoint()
            
            super.init(frame: frame)
            
            self.addSubview(self.backgroundView)
            self.addSubview(self.textContentsView)
        }
        
        required public init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }
                
        func update(component: CustomBadgeComponent, availableSize: CGSize, state: EmptyComponentState, environment: Environment<Empty>, transition: ComponentTransition) -> CGSize {
            let previousComponent = self.component
            self.component = component
            
            if component.text != previousComponent?.text || component.font != previousComponent?.font {
                let attributedText = NSAttributedString(string: component.text, attributes: [
                    NSAttributedString.Key.font: component.font,
                    NSAttributedString.Key.foregroundColor: UIColor.white
                ])
                
                var boundingRect = attributedText.boundingRect(with: availableSize, options: .usesLineFragmentOrigin, context: nil)
                boundingRect.size.width = ceil(boundingRect.size.width)
                boundingRect.size.height = ceil(boundingRect.size.height)
                
                if let context = DrawingContext(size: boundingRect.size, scale: 0.0, opaque: false, clear: true) {
                    context.withContext { c in
                        UIGraphicsPushContext(c)
                        defer {
                            UIGraphicsPopContext()
                        }
                        
                        attributedText.draw(at: CGPoint())
                    }
                    var minFilledLineY = Int(context.scaledSize.height) - 1
                    var maxFilledLineY = 0
                    var minFilledLineX = Int(context.scaledSize.width) - 1
                    var maxFilledLineX = 0
                    for y in 0 ..< Int(context.scaledSize.height) {
                        let linePtr = context.bytes.advanced(by: max(0, y) * context.bytesPerRow).assumingMemoryBound(to: UInt32.self)
                        
                        for x in 0 ..< Int(context.scaledSize.width) {
                            let pixelPtr = linePtr.advanced(by: x)
                            if pixelPtr.pointee != 0 {
                                minFilledLineY = min(y, minFilledLineY)
                                maxFilledLineY = max(y, maxFilledLineY)
                                minFilledLineX = min(x, minFilledLineX)
                                maxFilledLineX = max(x, maxFilledLineX)
                            }
                        }
                    }
                    
                    var opticalBounds = CGRect()
                    if minFilledLineX <= maxFilledLineX && minFilledLineY <= maxFilledLineY {
                        opticalBounds.origin.x = CGFloat(minFilledLineX) / context.scale
                        opticalBounds.origin.y = CGFloat(minFilledLineY) / context.scale
                        opticalBounds.size.width = CGFloat(maxFilledLineX - minFilledLineX) / context.scale
                        opticalBounds.size.height = CGFloat(maxFilledLineY - minFilledLineY) / context.scale
                    }
                    
                    self.textContentsView.image = context.generateImage()?.withRenderingMode(.alwaysTemplate)
                    self.textLayout = TextLayout(size: boundingRect.size, opticalBounds: opticalBounds)
                } else {
                    self.textLayout = TextLayout(size: boundingRect.size, opticalBounds: CGRect(origin: CGPoint(), size: boundingRect.size))
                }
            }
            
            let textSize = self.textLayout?.size ?? CGSize(width: 1.0, height: 1.0)
            
            var size = CGSize(width: textSize.width + component.insets.left + component.insets.right, height: textSize.height + component.insets.top + component.insets.bottom)
            size.width = max(size.width, size.height)
            
            let backgroundFrame = CGRect(origin: CGPoint(), size: size)
            transition.setFrame(view: self.backgroundView, frame: backgroundFrame)
            
            let textFrame = CGRect(origin: CGPoint(x: floorToScreenPixels((size.width - textSize.width) * 0.5), y: component.insets.top + UIScreenPixel), size: textSize)
            /*if let textLayout = self.textLayout {
                textFrame.origin.x = textLayout.opticalBounds.minX + floorToScreenPixels((backgroundFrame.width - textLayout.opticalBounds.width) * 0.5)
                textFrame.origin.y = textLayout.opticalBounds.minY + floorToScreenPixels((backgroundFrame.height - textLayout.opticalBounds.height) * 0.5)
            }*/
            
            transition.setPosition(view: self.textContentsView, position: textFrame.origin)
            self.textContentsView.bounds = CGRect(origin: CGPoint(), size: textFrame.size)
            
            if size.height != self.backgroundView.image?.size.height {
                self.backgroundView.image = generateStretchableFilledCircleImage(diameter: size.height, color: .white)?.withRenderingMode(.alwaysTemplate)
            }
            
            self.backgroundView.tintColor = component.background
            self.textContentsView.tintColor = component.foreground
            
            return size
        }
    }

    public func makeView() -> View {
        return View(frame: CGRect())
    }
    
    public func update(view: View, availableSize: CGSize, state: EmptyComponentState, environment: Environment<Empty>, transition: ComponentTransition) -> CGSize {
        return view.update(component: self, availableSize: availableSize, state: state, environment: environment, transition: transition)
    }
}

final class ChatTopicListTitleAccessoryPanelNode: ChatTitleAccessoryPanelNode, ChatControllerCustomNavigationPanelNode, ASScrollViewDelegate {
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
    
    private final class ItemView: UIView {
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
                    component: AnyComponent(CustomBadgeComponent(
                        text: "\(readCounters.count)",
                        font: Font.regular(12.0),
                        background: theme.list.itemCheckColors.fillColor,
                        foreground: theme.list.itemCheckColors.foregroundColor,
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
    }
    
    private final class ScrollView: UIScrollView {
        override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
            return super.hitTest(point, with: event)
        }
        
        override func touchesShouldCancel(in view: UIView) -> Bool {
            return true
        }
    }
    
    private enum ScrollId: Equatable {
        case all
        case topic(Int64)
    }
    
    private let context: AccountContext
    private let isMonoforum: Bool
    
    private let scrollView: ScrollView
    
    private var params: Params?
    
    private var items: [Item] = []
    private var itemViews: [Item.Id: ItemView] = [:]
    private var allItemView: AllItemView?
    private var tabItemView: TabItemView?
    private let selectedLineView: UIImageView
    
    private var itemsDisposable: Disposable?
    
    private var appliedScrollToId: ScrollId?
    
    init(context: AccountContext, peerId: EnginePeer.Id, isMonoforum: Bool) {
        self.context = context
        self.isMonoforum = isMonoforum
        
        self.selectedLineView = UIImageView()
        
        self.scrollView = ScrollView(frame: CGRect())
        
        super.init()
        
        self.scrollView.delaysContentTouches = false
        self.scrollView.canCancelContentTouches = true
        self.scrollView.clipsToBounds = false
        self.scrollView.contentInsetAdjustmentBehavior = .never
        if #available(iOS 13.0, *) {
            self.scrollView.automaticallyAdjustsScrollIndicatorInsets = false
        }
        self.scrollView.showsVerticalScrollIndicator = false
        self.scrollView.showsHorizontalScrollIndicator = false
        self.scrollView.alwaysBounceHorizontal = false
        self.scrollView.alwaysBounceVertical = false
        self.scrollView.scrollsToTop = false
        self.scrollView.delegate = self.wrappedScrollViewDelegate
        
        self.view.addSubview(self.scrollView)
        
        self.scrollView.addSubview(self.selectedLineView)
        
        self.scrollView.disablesInteractiveTransitionGestureRecognizer = true
        
        let threadListSignal: Signal<EngineChatList, NoError> = context.sharedContext.subscribeChatListData(context: context, location: isMonoforum ? .savedMessagesChats(peerId: peerId) : .forum(peerId: peerId))
        
        self.itemsDisposable = (threadListSignal
        |> deliverOnMainQueue).startStrict(next: { [weak self] chatList in
            guard let self else {
                return
            }
            self.items.removeAll()
            
            for item in chatList.items.reversed() {
                self.items.append(Item(item: item))
            }
            
            self.update(transition: .immediate)
        })
    }
    
    deinit {
        self.itemsDisposable?.dispose()
    }
    
    private func update(transition: ContainedViewLayoutTransition) {
        if let params = self.params {
            self.update(params: params, transition: transition)
        }
    }
    
    override func updateLayout(width: CGFloat, leftInset: CGFloat, rightInset: CGFloat, transition: ContainedViewLayoutTransition, interfaceState: ChatPresentationInterfaceState) -> LayoutResult {
        let params = Params(width: width, leftInset: leftInset, rightInset: rightInset, interfaceState: interfaceState)
        if self.params != params {
            if self.params?.interfaceState.theme !== params.interfaceState.theme {
                self.selectedLineView.image = generateImage(CGSize(width: 7.0, height: 4.0), rotatedContext: { size, context in
                    context.clear(CGRect(origin: CGPoint(), size: size))
                    context.setFillColor(params.interfaceState.theme.rootController.navigationBar.accentTextColor.cgColor)
                    context.fillEllipse(in: CGRect(origin: CGPoint(), size: CGSize(width: size.width, height: size.width)))
                })?.stretchableImage(withLeftCapWidth: 4, topCapHeight: 1)
            }
            
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
        let hadItemViews = !self.itemViews.isEmpty
        
        var transition = transition
        if !hadItemViews {
            transition = .immediate
        }
        
        let panelHeight: CGFloat = 44.0
        
        let containerInsets = UIEdgeInsets(top: 0.0, left: params.leftInset + 16.0, bottom: 0.0, right: params.rightInset + 16.0)
        let itemSpacing: CGFloat = 24.0
        
        var contentSize = CGSize(width: 0.0, height: panelHeight)
        contentSize.width += containerInsets.left + 8.0
        
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
                self.scrollView.addSubview(itemView)
            }
                
            let itemSize = itemView.update(context: self.context, theme: params.interfaceState.theme, height: panelHeight, transition: .immediate)
            let itemFrame = CGRect(origin: CGPoint(x: contentSize.width, y: -5.0), size: itemSize)
            
            itemTransition.updatePosition(layer: itemView.layer, position: itemFrame.center)
            itemTransition.updateBounds(layer: itemView.layer, bounds: CGRect(origin: CGPoint(), size: itemFrame.size))
            
            if animateIn && transition.isAnimated {
                itemView.layer.animateAlpha(from: 0.0, to: itemView.alpha, duration: 0.15)
                transition.animateTransformScale(view: itemView, from: 0.001)
            }
            
            contentSize.width += itemSize.width
        }
        
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
        
        let scrollSize = CGSize(width: params.width, height: contentSize.height)
        if self.scrollView.bounds.size != scrollSize {
            self.scrollView.frame = CGRect(origin: CGPoint(x: 0.0, y: 0.0), size: scrollSize)
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
        }
    }

    public func updateGlobalOffset(globalOffset: CGFloat, transition: ComponentTransition) {
        if let tabItemView = self.tabItemView {
            transition.setTransform(view: tabItemView, transform: CATransform3DMakeTranslation(0.0, -globalOffset, 0.0))
        }
    }
    
    public func topicIndex(threadId: Int64?) -> Int? {
        if let threadId {
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
        }
    }
}
