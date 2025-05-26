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
    
    let context: AccountContext
    let theme: PresentationTheme
    let strings: PresentationStrings
    let peerId: EnginePeer.Id
    let isMonoforum: Bool
    let topicId: Int64?
    let togglePanel: () -> Void
    let updateTopicId: (Int64?, Bool) -> Void
    
    public init(
        context: AccountContext,
        theme: PresentationTheme,
        strings: PresentationStrings,
        peerId: EnginePeer.Id,
        isMonoforum: Bool,
        topicId: Int64?,
        togglePanel: @escaping () -> Void,
        updateTopicId: @escaping (Int64?, Bool) -> Void
    ) {
        self.context = context
        self.theme = theme
        self.strings = strings
        self.peerId = peerId
        self.isMonoforum = isMonoforum
        self.topicId = topicId
        self.togglePanel = togglePanel
        self.updateTopicId = updateTopicId
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
    
    private final class ItemView: UIView {
        private let context: AccountContext
        private let action: () -> Void
        
        private let extractedContainerNode: ContextExtractedContentContainingNode
        private let containerNode: ContextControllerSourceNode
        
        private let containerButton: HighlightTrackingButton
        
        private var icon: ComponentView<Empty>?
        private var avatarNode: AvatarNode?
        private let title = ComponentView<Empty>()
        
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
        
        func update(context: AccountContext, item: Item, isSelected: Bool, theme: PresentationTheme, width: CGFloat, transition: ComponentTransition) -> CGSize {
            let spacing: CGFloat = 3.0
            let iconSize = CGSize(width: 30.0, height: 30.0)
            
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
                    containerSize: iconSize
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
            
            if let avatarIconContent, let icon = self.icon {
                let avatarIconComponent = EmojiStatusComponent(
                    context: context,
                    animationCache: context.animationCache,
                    animationRenderer: context.animationRenderer,
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
                    text: .plain(NSAttributedString(string: titleText, font: Font.regular(10.0), textColor: isSelected ? theme.rootController.navigationBar.accentTextColor : theme.rootController.navigationBar.secondaryTextColor)),
                    horizontalAlignment: .center,
                    maximumNumberOfLines: 2
                )),
                environment: {},
                containerSize: CGSize(width: width - 6.0 * 2.0, height: 100.0)
            )
            
            let contentSize: CGFloat = iconSize.height + spacing + titleSize.height
            let size = CGSize(width: width, height: contentSize)
            
            let iconFrame = CGRect(origin: CGPoint(x: floor((size.width - iconSize.width) * 0.5), y: 0.0), size: iconSize)
            let titleFrame = CGRect(origin: CGPoint(x: floor((size.width - titleSize.width) * 0.5), y: iconFrame.maxY + spacing), size: titleSize)
            
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
                    avatarNode = AvatarNode(font: avatarPlaceholderFont(size: 11.0))
                    avatarNode.isUserInteractionEnabled = false
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
        
        func update(context: AccountContext, theme: PresentationTheme, width: CGFloat, transition: ComponentTransition) -> CGSize {
            let iconSize = self.icon.update(
                transition: .immediate,
                component: AnyComponent(BundleIconComponent(
                    name: "Chat/Title Panels/SidebarIcon",
                    tintColor: theme.rootController.navigationBar.accentTextColor,
                    maxSize: nil,
                    scaleFactor: 1.0
                )),
                environment: {},
                containerSize: CGSize(width: 100.0, height: 100.0)
            )
            
            let topInset: CGFloat = 10.0
            let bottomInset: CGFloat = 12.0
            
            let contentSize: CGFloat = topInset + iconSize.height + bottomInset
            let size = CGSize(width: width, height: contentSize)
            
            let iconFrame = CGRect(origin: CGPoint(x: floor((size.width - iconSize.width) * 0.5), y: topInset), size: iconSize)
            
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
        
        private let icon = ComponentView<Empty>()
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
        
        func update(context: AccountContext, isSelected: Bool, theme: PresentationTheme, width: CGFloat, transition: ComponentTransition) -> CGSize {
            let spacing: CGFloat = 3.0
            
            let iconSize = self.icon.update(
                transition: .immediate,
                component: AnyComponent(BundleIconComponent(
                    name: "Chat List/Tabs/IconChats",
                    tintColor: isSelected ? theme.rootController.navigationBar.accentTextColor : theme.rootController.navigationBar.secondaryTextColor
                )),
                environment: {},
                containerSize: CGSize(width: 100.0, height: 100.0)
            )
            
            //TODO:localize
            let titleText: String = "All"
            let titleSize = self.title.update(
                transition: .immediate,
                component: AnyComponent(MultilineTextComponent(
                    text: .plain(NSAttributedString(string: titleText, font: Font.regular(10.0), textColor: isSelected ? theme.rootController.navigationBar.accentTextColor : theme.rootController.navigationBar.secondaryTextColor)),
                    maximumNumberOfLines: 2
                )),
                environment: {},
                containerSize: CGSize(width: width - 4.0 * 2.0, height: 100.0)
            )
            
            let contentSize: CGFloat = iconSize.height + spacing + titleSize.height
            let size = CGSize(width: width, height: contentSize)
            
            let iconFrame = CGRect(origin: CGPoint(x: floor((size.width - iconSize.width) * 0.5), y: 0.0), size: iconSize)
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
    
    public final class View: UIView {
        private let scrollView: ScrollView
        private let scrollContainerView: UIView
        private let scrollViewMask: UIImageView
        
        private let background = ComponentView<Empty>()
        private let separatorLayer: SimpleLayer
        private let selectedLineView: UIImageView
        
        private var items: [Item] = []
        private var itemViews: [Item.Id: ItemView] = [:]
        private var allItemView: AllItemView?
        private var tabItemView: TabItemView?
        
        private var component: ChatSideTopicsPanel?
        private weak var state: EmptyComponentState?
        private var isUpdating: Bool = false
        
        private var appliedScrollToId: ScrollId?
        
        private var itemsDisposable: Disposable?
        
        override public init(frame: CGRect) {
            self.selectedLineView = UIImageView()
            self.scrollView = ScrollView(frame: CGRect())
            
            self.scrollContainerView = UIView()
            self.scrollViewMask = UIImageView(image: generateGradientImage(size: CGSize(width: 8.0, height: 8.0), colors: [
                UIColor(white: 1.0, alpha: 0.0),
                UIColor(white: 1.0, alpha: 1.0)
            ], locations: [0.0, 1.0], direction: .vertical)?.stretchableImage(withLeftCapWidth: 0, topCapHeight: 8))
            self.scrollContainerView.mask = self.scrollViewMask
            
            self.separatorLayer = SimpleLayer()
            
            super.init(frame: frame)
            
            self.scrollView.delaysContentTouches = false
            self.scrollView.canCancelContentTouches = true
            self.scrollView.clipsToBounds = true
            self.scrollView.contentInsetAdjustmentBehavior = .never
            if #available(iOS 13.0, *) {
                self.scrollView.automaticallyAdjustsScrollIndicatorInsets = false
            }
            self.scrollView.showsVerticalScrollIndicator = false
            self.scrollView.showsHorizontalScrollIndicator = false
            self.scrollView.alwaysBounceHorizontal = false
            self.scrollView.alwaysBounceVertical = false
            self.scrollView.scrollsToTop = false
            
            self.addSubview(self.scrollContainerView)
            self.scrollContainerView.addSubview(self.scrollView)
            self.scrollView.addSubview(self.selectedLineView)
        }
        
        required public init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }
        
        deinit {
            self.itemsDisposable?.dispose()
        }

        public func updateGlobalOffset(globalOffset: CGFloat, transition: ComponentTransition) {
            if let tabItemView = self.tabItemView {
                transition.setTransform(view: tabItemView, transform: CATransform3DMakeTranslation(-globalOffset, 0.0, 0.0))
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
        
        func update(component: ChatSideTopicsPanel, availableSize: CGSize, state: EmptyComponentState, environment: Environment<EnvironmentType>, transition: ComponentTransition) -> CGSize {
            self.isUpdating = true
            defer {
                self.isUpdating = false
            }
            
            self.state = state
            
            if self.component == nil {
                let threadListSignal: Signal<EngineChatList, NoError> = component.context.sharedContext.subscribeChatListData(context: component.context, location: component.isMonoforum ? .savedMessagesChats(peerId: component.peerId) : .forum(peerId: component.peerId))
                
                self.itemsDisposable = (threadListSignal
                |> deliverOnMainQueue).startStrict(next: { [weak self] chatList in
                    guard let self else {
                        return
                    }
                    self.items.removeAll()
                    
                    for item in chatList.items.reversed() {
                        self.items.append(Item(item: item))
                    }
                    
                    if !self.isUpdating {
                        self.state?.updated(transition: .immediate)
                    }
                })
            }
            let themeUpdated = self.component?.theme !== component.theme
            self.component = component
            
            let _ = self.background.update(
                transition: transition,
                component: AnyComponent(BlurredBackgroundComponent(
                    color: component.theme.rootController.navigationBar.blurredBackgroundColor
                )),
                environment: {},
                containerSize: availableSize
            )
            self.separatorLayer.backgroundColor = component.theme.rootController.navigationBar.separatorColor.cgColor
            
            if let backgroundView = self.background.view {
                if backgroundView.superview == nil {
                    self.insertSubview(backgroundView, at: 0)
                }
                transition.setFrame(view: backgroundView, frame: CGRect(origin: CGPoint(), size: availableSize))
            }
            if self.separatorLayer.superlayer == nil {
                self.layer.addSublayer(self.separatorLayer)
            }
            transition.setFrame(layer: self.separatorLayer, frame: CGRect(origin: CGPoint(x: availableSize.width, y: 0.0), size: CGSize(width: UIScreenPixel, height: availableSize.height)))
            
            if themeUpdated {
                self.selectedLineView.image = generateImage(CGSize(width: 4.0, height: 7.0), rotatedContext: { size, context in
                    context.clear(CGRect(origin: CGPoint(), size: size))
                    context.setFillColor(component.theme.rootController.navigationBar.accentTextColor.cgColor)
                    context.fillEllipse(in: CGRect(origin: CGPoint(x: size.width - size.height, y: 0.0), size: CGSize(width: size.height, height: size.height)))
                })?.stretchableImage(withLeftCapWidth: 1, topCapHeight: 4)
            }
            
            let hadItemViews = !self.itemViews.isEmpty
            
            let environment = environment[EnvironmentType.self].value
            
            let containerInsets = environment.insets
            let panelWidth: CGFloat = availableSize.width - containerInsets.left
            
            let itemSpacing: CGFloat = 24.0
            
            var topContainerInset: CGFloat = containerInsets.top
            
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
                        component.togglePanel()
                    })
                    self.tabItemView = itemView
                    self.addSubview(itemView)
                }
                    
                let itemSize = itemView.update(context: component.context, theme: component.theme, width: panelWidth, transition: .immediate)
                let itemFrame = CGRect(origin: CGPoint(x: 0.0, y: topContainerInset), size: itemSize)
                
                itemTransition.setPosition(layer: itemView.layer, position: itemFrame.center)
                itemTransition.setBounds(layer: itemView.layer, bounds: CGRect(origin: CGPoint(), size: itemFrame.size))
                
                if animateIn && !transition.animation.isImmediate {
                    itemView.layer.animateAlpha(from: 0.0, to: itemView.alpha, duration: 0.15)
                    transition.containedViewLayoutTransition.animateTransformScale(view: itemView, from: 0.001)
                }
                
                topContainerInset += itemSize.height
                topContainerInset -= 24.0
            }
            
            var contentSize = CGSize(width: panelWidth, height: 0.0)
            contentSize.height += 36.0
            
            var validIds: [Item.Id] = []
            var isFirst = true
            var selectedItemFrame: CGRect?
            
            do {
                if isFirst {
                    isFirst = false
                } else {
                    contentSize.height += itemSpacing
                }
                
                var itemTransition = transition
                var animateIn = false
                let itemView: AllItemView
                if let current = self.allItemView {
                    itemView = current
                } else {
                    itemTransition = .immediate
                    animateIn = true
                    itemView = AllItemView(context: component.context, action: { [weak self] in
                        guard let self, let component = self.component else {
                            return
                        }
                        
                        component.updateTopicId(nil, false)
                    })
                    self.allItemView = itemView
                    self.scrollView.addSubview(itemView)
                }
                    
                var isSelected = false
                if component.topicId == nil {
                    isSelected = true
                }
                let itemSize = itemView.update(context: component.context, isSelected: isSelected, theme: component.theme, width: panelWidth, transition: .immediate)
                let itemFrame = CGRect(origin: CGPoint(x: containerInsets.left, y: contentSize.height), size: itemSize)
                
                if isSelected {
                    selectedItemFrame = itemFrame
                }
                
                itemTransition.setPosition(layer: itemView.layer, position: itemFrame.center)
                itemTransition.setBounds(layer: itemView.layer, bounds: CGRect(origin: CGPoint(), size: itemFrame.size))
                
                if animateIn && !transition.animation.isImmediate {
                    itemView.layer.animateAlpha(from: 0.0, to: itemView.alpha, duration: 0.15)
                    transition.containedViewLayoutTransition.animateTransformScale(view: itemView, from: 0.001)
                }
                
                contentSize.height += itemSize.height
            }
            
            for item in self.items {
                if isFirst {
                    isFirst = false
                } else {
                    contentSize.height += itemSpacing
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
                    itemView = ItemView(context: component.context, action: { [weak self] in
                        guard let self, let component = self.component else {
                            return
                        }
                        
                        let topicId: Int64
                        if case let .forum(topicIdValue) = chatListItem.id {
                            topicId = topicIdValue
                        } else {
                            topicId = chatListItem.renderedPeer.peerId.toInt64()
                        }
                        
                        var direction = true
                        if let lhsIndex = self.topicIndex(threadId: component.topicId), let rhsIndex = self.topicIndex(threadId: topicId) {
                            direction = lhsIndex < rhsIndex
                        }
                        
                        component.updateTopicId(topicId, direction)
                    }, contextGesture: { gesture, sourceNode in
                    })
                    self.itemViews[itemId] = itemView
                    self.scrollView.addSubview(itemView)
                }
                    
                var isSelected = false
                if case let .forum(topicId) = item.item.id {
                    isSelected = component.topicId == topicId
                } else {
                    isSelected = component.topicId == item.item.renderedPeer.peerId.toInt64()
                }
                let itemSize = itemView.update(context: component.context, item: item, isSelected: isSelected, theme: component.theme, width: panelWidth, transition: .immediate)
                let itemFrame = CGRect(origin: CGPoint(x: containerInsets.left, y: contentSize.height), size: itemSize)
                
                if isSelected {
                    selectedItemFrame = itemFrame
                }
                
                itemTransition.setPosition(layer: itemView.layer, position: itemFrame.center)
                itemTransition.setBounds(layer: itemView.layer, bounds: CGRect(origin: CGPoint(), size: itemFrame.size))
                
                if animateIn && !transition.animation.isImmediate {
                    itemView.layer.animateAlpha(from: 0.0, to: itemView.alpha, duration: 0.15)
                    transition.containedViewLayoutTransition.animateTransformScale(view: itemView, from: 0.001)
                }
                
                contentSize.height += itemSize.height
            }
            
            contentSize.height += 12.0
            
            var removedIds: [Item.Id] = []
            for (id, itemView) in self.itemViews {
                if !validIds.contains(id) {
                    removedIds.append(id)
                    
                    if !transition.animation.isImmediate {
                        itemView.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.18, removeOnCompletion: false, completion: { [weak itemView] _ in
                            itemView?.removeFromSuperview()
                        })
                        transition.setScale(layer: itemView.layer, scale: 0.001)
                    } else {
                        itemView.removeFromSuperview()
                    }
                }
            }
            for id in removedIds {
                self.itemViews.removeValue(forKey: id)
            }
            
            if let selectedItemFrame {
                let lineFrame = CGRect(origin: CGPoint(x: containerInsets.left, y: selectedItemFrame.minY), size: CGSize(width: 4.0, height: selectedItemFrame.height + 4.0))
                if self.selectedLineView.isHidden {
                    self.selectedLineView.isHidden = false
                    self.selectedLineView.frame = lineFrame
                } else {
                    transition.setFrame(view: self.selectedLineView, frame: lineFrame)
                }
            } else {
                self.selectedLineView.isHidden = true
            }
            
            contentSize.height += containerInsets.bottom
            
            let scrollSize = CGSize(width: availableSize.width, height: availableSize.height - topContainerInset)
            
            self.scrollContainerView.frame = CGRect(origin: CGPoint(x: 0.0, y: topContainerInset), size: scrollSize)
            self.scrollViewMask.frame = CGRect(origin: CGPoint(x: 0.0, y: topContainerInset), size: scrollSize)
            
            if self.scrollView.bounds.size != scrollSize {
                self.scrollView.frame = CGRect(origin: CGPoint(x: 0.0, y: 0.0), size: scrollSize)
            }
            if self.scrollView.contentSize != contentSize {
                self.scrollView.contentSize = contentSize
            }
            
            let scrollToId: ScrollId
            if let threadId = component.topicId {
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
