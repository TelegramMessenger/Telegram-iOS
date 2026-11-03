import Foundation
import UIKit
import Display
import ComponentFlow
import MultilineTextComponent
import AccountContext
import TelegramCore
import TelegramPresentationData
import SwiftSignalKit
import TelegramCallsUI
import AsyncListComponent
import AvatarNode
import ContextUI
import StarsParticleEffect
import StoryLiveChatMessageComponent
import PeerNameTextComponent

private final class PinnedBarMessageComponent: Component {
    let context: AccountContext
    let strings: PresentationStrings
    let theme: PresentationTheme
    let message: GroupCallMessagesContext.Message
    let topPlace: Int?
    let action: () -> Void
    let contextGesture: ((ContextGesture, ContextExtractedContentContainingNode) -> Void)?
    
    init(context: AccountContext, strings: PresentationStrings, theme: PresentationTheme, message: GroupCallMessagesContext.Message, topPlace: Int?, action: @escaping () -> Void, contextGesture: ((ContextGesture, ContextExtractedContentContainingNode) -> Void)?) {
        self.context = context
        self.strings = strings
        self.theme = theme
        self.message = message
        self.topPlace = topPlace
        self.action = action
        self.contextGesture = contextGesture
    }
    
    static func ==(lhs: PinnedBarMessageComponent, rhs: PinnedBarMessageComponent) -> Bool {
        if lhs === rhs {
            return true
        }
        if lhs.context !== rhs.context {
            return false
        }
        if lhs.strings !== rhs.strings {
            return false
        }
        if lhs.theme !== rhs.theme {
            return false
        }
        if lhs.message != rhs.message {
            return false
        }
        if lhs.topPlace != rhs.topPlace {
            return false
        }
        if (lhs.contextGesture == nil) != (rhs.contextGesture == nil) {
            return false
        }
        return true
    }
    
    final class View: UIView {
        private let extractedContainerNode: ContextExtractedContentContainingNode
        private let containerNode: ContextControllerSourceNode
        
        private let backgroundView: UIImageView
        private let foregroundClippingView: UIView
        private let foregroundView: UIImageView
        private let effectLayer: StarsParticleEffectLayer
        
        private var avatarNode: AvatarNode?
        private let title = ComponentView<Empty>()
        private var crownIcon: UIImageView?

        private var component: PinnedBarMessageComponent?
        private weak var state: EmptyComponentState?
        private var isUpdating: Bool = false
        
        private var updateTimer: Foundation.Timer?
        
        override init(frame: CGRect) {
            self.extractedContainerNode = ContextExtractedContentContainingNode()
            self.containerNode = ContextControllerSourceNode()
            
            self.backgroundView = UIImageView()
            self.foregroundClippingView = UIView()
            self.foregroundClippingView.clipsToBounds = true
            self.foregroundView = UIImageView()
            self.effectLayer = StarsParticleEffectLayer()
            
            super.init(frame: frame)
            
            self.containerNode.addSubnode(self.extractedContainerNode)
            self.containerNode.targetNodeForActivationProgress = self.extractedContainerNode.contentNode
            self.addSubview(self.containerNode.view)
            
            self.containerNode.activated = { [weak self] gesture, _ in
                guard let self, let component = self.component else {
                    return
                }
                component.contextGesture?(gesture, self.extractedContainerNode)
            }
            
            self.extractedContainerNode.contentNode.view.addSubview(self.backgroundView)
            
            self.foregroundClippingView.addSubview(self.foregroundView)
            self.extractedContainerNode.contentNode.view.addSubview(self.foregroundClippingView)
            self.extractedContainerNode.contentNode.view.layer.addSublayer(self.effectLayer)
            
            self.extractedContainerNode.contentNode.view.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(self.tapGesture(_:))))
        }
        
        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }
        
        deinit {
            self.updateTimer?.invalidate()
        }
        
        @objc private func tapGesture(_ recognizer: UITapGestureRecognizer) {
            guard let component = self.component else {
                return
            }
            if case .ended = recognizer.state {
                component.action()
            }
        }
        
        override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
            if !self.bounds.contains(point) {
                return nil
            }
            
            guard let result = super.hitTest(point, with: event) else {
                return nil
            }
            
            return result
        }
        
        func update(component: PinnedBarMessageComponent, availableSize: CGSize, state: EmptyComponentState, environment: Environment<Empty>, transition: ComponentTransition) -> CGSize {
            self.isUpdating = true
            defer {
                self.isUpdating = false
            }
            
            if self.updateTimer == nil {
                self.updateTimer = Foundation.Timer.scheduledTimer(withTimeInterval: 1.0 / 30.0, repeats: true, block: { [weak self] _ in
                    guard let self else {
                        return
                    }
                    if !self.isUpdating {
                        self.state?.updated(transition: .immediate, isLocal: true)
                    }
                })
            }
            
            let previousComponent = self.component
            self.component = component
            self.state = state
            
            self.containerNode.isGestureEnabled = component.contextGesture != nil
            
            let params = LiveChatMessageParams(appConfig: component.context.currentAppConfiguration.with({ $0 }))
            let baseColor = StoryLiveChatMessageComponent.getMessageColor(color: GroupCallMessagesContext.getStarAmountParamMapping(params: params, value: component.message.paidStars ?? 0).color ?? GroupCallMessagesContext.Message.Color(rawValue: 0x985FDC))
            
            let itemHeight: CGFloat = 32.0
            let avatarInset: CGFloat = 4.0
            let avatarSize: CGFloat = 24.0
            let avatarSpacing: CGFloat = 6.0
            let rightInset: CGFloat = 10.0
            
            let titleSize = self.title.update(
                transition: .immediate,
                component: AnyComponent(PeerNameTextComponent(
                    context: component.context,
                    peer: component.message.author,
                    text: .name,
                    font: Font.semibold(15.0),
                    textColor: .white,
                    iconBackgroundColor: .white,
                    iconForegroundColor: baseColor,
                    strings: component.strings
                )),
                environment: {},
                containerSize: CGSize(width: 200.0, height: itemHeight)
            )
            
            var size = CGSize(width: avatarInset + avatarSize + avatarSpacing + titleSize.width + rightInset, height: itemHeight)
            
            if let topPlace = component.topPlace {
                let crownIcon: UIImageView
                if let current = self.crownIcon {
                    crownIcon = current
                } else {
                    crownIcon = UIImageView()
                    self.crownIcon = crownIcon
                    self.extractedContainerNode.contentNode.view.addSubview(crownIcon)
                }
                if topPlace != previousComponent?.topPlace {
                    crownIcon.image = StoryLiveChatMessageComponent.generateCrownImage(place: topPlace, backgroundColor: .white, foregroundColor: .clear, borderColor: nil)
                }
                crownIcon.tintColor = .white
                
                if let image = crownIcon.image {
                    size.width += image.size.width + 4.0
                }
            } else {
                if let crownIcon = self.crownIcon {
                    self.crownIcon = nil
                    crownIcon.removeFromSuperview()
                }
            }
            
            if self.backgroundView.image == nil {
                self.backgroundView.image = generateStretchableFilledCircleImage(diameter: itemHeight, color: .white)?.withRenderingMode(.alwaysTemplate)
                self.foregroundView.image = self.backgroundView.image
            }
            
            self.backgroundView.tintColor = baseColor.withMultipliedBrightnessBy(0.7)
            self.foregroundView.tintColor = baseColor
            
            let timestamp = CFAbsoluteTimeGetCurrent() + kCFAbsoluteTimeIntervalSince1970
            let currentDuration = max(0.0, timestamp - Double(component.message.date))
            var timeFraction: CGFloat = 1.0 - min(1.0, currentDuration / Double(component.message.lifetime))
            if case .local = component.message.id.space {
                timeFraction = 1.0
            }
            
            let backgroundFrame = CGRect(origin: CGPoint(), size: size)
            transition.setFrame(view: self.backgroundView, frame: backgroundFrame)
            transition.setFrame(view: self.foregroundView, frame: CGRect(origin: CGPoint(), size: size))
            transition.setFrame(view: self.foregroundClippingView, frame: CGRect(origin: CGPoint(), size: CGSize(width: floorToScreenPixels(size.width * timeFraction), height: size.height)))
            
            transition.setFrame(layer: self.effectLayer, frame: CGRect(origin: CGPoint(), size: size))
            self.effectLayer.update(color: UIColor(white: 1.0, alpha: 0.5), size: size, cornerRadius: size.height * 0.5, transition: transition)
            
            let avatarFrame = CGRect(origin: CGPoint(x: avatarInset, y: floor((itemHeight - avatarSize) * 0.5)), size: CGSize(width: avatarSize, height: avatarSize))
            do {
                let avatarNode: AvatarNode
                if let current = self.avatarNode {
                    avatarNode = current
                } else {
                    avatarNode = AvatarNode(font: avatarPlaceholderFont(size: 10.0))
                    self.avatarNode = avatarNode
                    self.extractedContainerNode.contentNode.view.addSubview(avatarNode.view)
                }
                transition.setFrame(view: avatarNode.view, frame: avatarFrame)
                avatarNode.updateSize(size: avatarFrame.size)
                if let peer = component.message.author {
                    if peer.smallProfileImage != nil {
                        avatarNode.setPeerV2(context: component.context, theme: component.theme, peer: peer, displayDimensions: CGSize(width: avatarSize, height: avatarSize))
                    } else {
                        avatarNode.setPeer(context: component.context, theme: component.theme, peer: peer, displayDimensions: CGSize(width: avatarSize, height: avatarSize))
                    }
                } else {
                    avatarNode.setCustomLetters([" "])
                }
            }
            
            var titleFrame = CGRect(origin: CGPoint(x: avatarInset + avatarSize + avatarSpacing, y: floor((itemHeight - titleSize.height) * 0.5)), size: titleSize)
            if let crownIcon = self.crownIcon, let image = crownIcon.image {
                crownIcon.frame = CGRect(origin: CGPoint(x: titleFrame.minX, y: titleFrame.minY - 1.0), size: image.size)
                titleFrame.origin.x += image.size.width + 4.0
            }
            
            if let titleView = self.title.view {
                if titleView.superview == nil {
                    titleView.layer.anchorPoint = CGPoint()
                    self.extractedContainerNode.contentNode.view.addSubview(titleView)
                }
                transition.setPosition(view: titleView, position: titleFrame.origin)
                titleView.bounds = CGRect(origin: CGPoint(), size: titleFrame.size)
            }
            
            self.extractedContainerNode.frame = CGRect(origin: CGPoint(), size: size)
            self.extractedContainerNode.contentNode.frame = CGRect(origin: CGPoint(), size: size)
            self.extractedContainerNode.contentRect = backgroundFrame.insetBy(dx: -4.0, dy: 0.0)
            self.containerNode.frame = CGRect(origin: CGPoint(), size: size)
            
            return CGSize(width: size.width + 10.0, height: size.height)
        }
    }

    func makeView() -> View {
        return View(frame: CGRect())
    }
    
    func update(view: View, availableSize: CGSize, state: EmptyComponentState, environment: Environment<Empty>, transition: ComponentTransition) -> CGSize {
        return view.update(component: self, availableSize: availableSize, state: state, environment: environment, transition: transition)
    }
}

final class PinnedBarComponent: Component {
    let context: AccountContext
    let strings: PresentationStrings
    let theme: PresentationTheme
    let isExpanded: Bool
    let messages: [GroupCallMessagesContext.Message]
    let topIndices: [EnginePeer.Id: Int]
    let action: (GroupCallMessagesContext.Message) -> Void
    let contextGesture: (GroupCallMessagesContext.Message, ContextGesture, ContextExtractedContentContainingNode) -> Void
    
    init(context: AccountContext, strings: PresentationStrings, theme: PresentationTheme, isExpanded: Bool, messages: [GroupCallMessagesContext.Message], topIndices: [EnginePeer.Id: Int], action: @escaping (GroupCallMessagesContext.Message) -> Void, contextGesture: @escaping (GroupCallMessagesContext.Message, ContextGesture, ContextExtractedContentContainingNode) -> Void) {
        self.context = context
        self.strings = strings
        self.theme = theme
        self.isExpanded = isExpanded
        self.messages = messages
        self.topIndices = topIndices
        self.action = action
        self.contextGesture = contextGesture
    }
    
    static func ==(lhs: PinnedBarComponent, rhs: PinnedBarComponent) -> Bool {
        if lhs === rhs {
            return true
        }
        if lhs.context !== rhs.context {
            return false
        }
        if lhs.strings !== rhs.strings {
            return false
        }
        if lhs.theme !== rhs.theme {
            return false
        }
        if lhs.isExpanded != rhs.isExpanded {
            return false
        }
        if lhs.messages != rhs.messages {
            return false
        }
        if lhs.topIndices != rhs.topIndices {
            return false
        }
        return true
    }
    
    final class View: UIView {
        private let listContainer: UIView
        private let listState = AsyncListComponent.ExternalState()
        private let list = ComponentView<Empty>()

        private var component: PinnedBarComponent?
        private weak var state: EmptyComponentState?
        private var isUpdating: Bool = false
        
        override init(frame: CGRect) {
            self.listContainer = UIView()
            self.listContainer.clipsToBounds = true
            
            super.init(frame: frame)
            
            self.addSubview(self.listContainer)
        }
        
        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }
        
        deinit {
        }
        
        override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
            if !self.bounds.contains(point) {
                return nil
            }
            
            guard let result = super.hitTest(point, with: event) else {
                return nil
            }
            
            return result
        }
        
        func update(component: PinnedBarComponent, availableSize: CGSize, state: EmptyComponentState, environment: Environment<Empty>, transition: ComponentTransition) -> CGSize {
            self.isUpdating = true
            defer {
                self.isUpdating = false
            }
            
            let previousComponent = self.component
            self.component = component
            self.state = state
            
            let itemHeight: CGFloat = 32.0
            
            let insets = UIEdgeInsets(top: 13.0, left: 20.0, bottom: 13.0, right: 20.0)
            
            let size = CGSize(width: availableSize.width, height: insets.top + itemHeight + insets.bottom)
            
            var listItems: [AnyComponentWithIdentity<Empty>] = []
            for message in component.messages {
                if let author = message.author {
                    let id = message.id
                    listItems.append(AnyComponentWithIdentity(id: author.id, component: AnyComponent(PinnedBarMessageComponent(
                        context: component.context,
                        strings: component.strings,
                        theme: component.theme,
                        message: message,
                        topPlace: message.author.flatMap { component.topIndices[$0.id] },
                        action: { [weak self] in
                            guard let self, let component = self.component else {
                                return
                            }
                            if let message = component.messages.first(where: { $0.id == id }) {
                                component.action(message)
                            }
                        },
                        contextGesture: message.isIncoming ? { [weak self] gesture, sourceNode in
                            guard let self, let component = self.component else {
                                return
                            }
                            if let message = component.messages.first(where: { $0.id == id }) {
                                component.contextGesture(message, gesture, sourceNode)
                            } else {
                                gesture.cancel()
                            }
                        } : nil
                    ))))
                }
            }
            
            let listInsets = UIEdgeInsets(top: 0.0, left: insets.left, bottom: 0.0, right: insets.right)
            let listFrame = CGRect(origin: CGPoint(x: 0.0, y: 0.0), size: CGSize(width: size.width, height: size.height))
            
            var listTransition = transition
            var animateIn = false
            if let previousComponent {
                if previousComponent.messages.isEmpty {
                    listTransition = listTransition.withAnimation(.none)
                    animateIn = true
                }
            } else {
                listTransition = listTransition.withAnimation(.none)
                animateIn = true
            }
            
            let _ = self.list.update(
                transition: listTransition,
                component: AnyComponent(AsyncListComponent(
                    externalState: self.listState,
                    items: listItems,
                    itemSetId: AnyHashable(0),
                    direction: .horizontal,
                    insets: listInsets
                )),
                environment: {},
                containerSize: listFrame.size
            )
            if let listView = self.list.view {
                if listView.superview == nil {
                    self.listContainer.addSubview(listView)
                }
                transition.setPosition(view: listView, position: CGRect(origin: CGPoint(), size: listFrame.size).center)
                transition.setBounds(view: listView, bounds: CGRect(origin: CGPoint(), size: listFrame.size))
                
                if animateIn {
                    transition.animateAlpha(view: listView, from: 0.0, to: 1.0)
                }
            }
            
            transition.setFrame(view: self.listContainer, frame: listFrame)
            
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
