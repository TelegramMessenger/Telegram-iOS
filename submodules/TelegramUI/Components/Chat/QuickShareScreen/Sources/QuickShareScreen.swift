import Foundation
import UIKit
import AsyncDisplayKit
import Display
import ComponentFlow
import SwiftSignalKit
import TelegramCore
import TextFormat
import TelegramPresentationData
import MultilineTextComponent
import LottieComponent
import AccountContext
import ViewControllerComponent
import AvatarNode
import ComponentDisplayAdapters

private final class QuickShareScreenComponent: Component {
    typealias EnvironmentType = ViewControllerComponentContainer.Environment
    
    let context: AccountContext
    let sourceNode: ASDisplayNode
    let gesture: ContextGesture
    
    init(
        context: AccountContext,
        sourceNode: ASDisplayNode,
        gesture: ContextGesture
    ) {
        self.context = context
        self.sourceNode = sourceNode
        self.gesture = gesture
    }
    
    static func ==(lhs: QuickShareScreenComponent, rhs: QuickShareScreenComponent) -> Bool {
        return true
    }
    
    final class View: UIView {
        private let backgroundView: BlurredBackgroundView
        private let backgroundTintView: UIView
        private let containerView: UIView
        
        private var items: [EnginePeer.Id: ComponentView<Empty>] = [:]
        
        private var isUpdating: Bool = false
        private var component: QuickShareScreenComponent?
        private var environment: EnvironmentType?
        private weak var state: EmptyComponentState?
        
        private var disposable: Disposable?
        private var peers: [EnginePeer]?
        private var selectedPeerId: EnginePeer.Id?
        
        private var didCompleteAnimationIn: Bool = false
        private var initialContinueGesturePoint: CGPoint?
        private var didMoveFromInitialGesturePoint = false
        
        override init(frame: CGRect) {
            self.backgroundView = BlurredBackgroundView(color: nil, enableBlur: true)
            self.backgroundView.clipsToBounds = true
            self.backgroundTintView = UIView()
            self.backgroundTintView.clipsToBounds = true
            
            self.containerView = UIView()
            self.containerView.clipsToBounds = true
            
            super.init(frame: frame)
            
            self.addSubview(self.backgroundView)
            self.backgroundView.addSubview(self.backgroundTintView)
            self.addSubview(self.containerView)
        }
        
        required init?(coder: NSCoder) {
            preconditionFailure()
        }
        
        deinit {
            self.disposable?.dispose()
        }
                
        func animateIn() {
            let transition = ComponentTransition(animation: .curve(duration: 0.3, curve: .spring))
            transition.animateBoundsSize(view: self.backgroundView, from: CGSize(width: 0.0, height: self.backgroundView.bounds.height), to: self.backgroundView.bounds.size)
            transition.animateBounds(view: self.containerView, from: CGRect(x: self.containerView.bounds.width / 2.0, y: 0.0, width: 0.0, height: self.backgroundView.bounds.height), to: self.containerView.bounds)
            
            Queue.mainQueue().after(0.3) {
                self.containerView.clipsToBounds = false
                self.didCompleteAnimationIn = true
            }
        }
        
        func animateOut(completion: @escaping () -> Void) {
            let transition = ComponentTransition(animation: .curve(duration: 0.3, curve: .linear))
            transition.setAlpha(view: self, alpha: 0.0, completion: { _ in
                completion()
            })
        }
        
        func highlightGestureMoved(location: CGPoint) {
            for (peerId, view) in self.items {
                guard let view = view.view else {
                    continue
                }
                if view.frame.contains(location) {
                    self.selectedPeerId = peerId
                    self.state?.updated(transition: .spring(duration: 0.3))
                    break
                }
            }
        }
        
        func highlightGestureFinished(performAction: Bool) {
            if let selectedPeerId = self.selectedPeerId, performAction {
                let _ = selectedPeerId
                self.animateOut {
                    if let controller = self.environment?.controller() {
                        controller.dismiss()
                    }
                }
            } else {
                self.animateOut {
                    if let controller = self.environment?.controller() {
                        controller.dismiss()
                    }
                }
            }
        }
        
        func update(component: QuickShareScreenComponent, availableSize: CGSize, state: EmptyComponentState, environment: Environment<ViewControllerComponentContainer.Environment>, transition: ComponentTransition) -> CGSize {
            self.isUpdating = true
            defer {
                self.isUpdating = false
            }
            
            let environment = environment[ViewControllerComponentContainer.Environment.self].value
            self.environment = environment
            self.state = state
            
            if self.component == nil {
                self.disposable = combineLatest(queue: Queue.mainQueue(),
                    component.context.engine.peers.recentPeers() |> take(1),
                    component.context.engine.data.get(TelegramEngine.EngineData.Item.Peer.Peer(id: component.context.account.peerId))
                ).start(next: { [weak self] recentPeers, accountPeer in
                    guard let self else {
                        return
                    }
                    var result: [EnginePeer] = []
                    switch recentPeers {
                    case let .peers(peers):
                        result = peers.map(EnginePeer.init)
                    case .disabled:
                        break
                    }
                    if !result.isEmpty, let accountPeer {
                        self.peers = Array([accountPeer] + result.prefix(4))
                        self.state?.updated()
                    } else {
                        self.environment?.controller()?.dismiss()
                    }
                })
                
                component.gesture.externalUpdated = { [weak self] view, point in
                    guard let self else {
                        return
                    }
                    let localPoint = self.convert(point, from: view)
                    let initialPoint: CGPoint
                    if let current = self.initialContinueGesturePoint {
                        initialPoint = current
                    } else {
                        initialPoint = localPoint
                        self.initialContinueGesturePoint = localPoint
                    }
                    if self.didCompleteAnimationIn {
                        if !self.didMoveFromInitialGesturePoint {
                            let distance = abs(localPoint.y - initialPoint.y)
                            if distance > 4.0 {
                                self.didMoveFromInitialGesturePoint = true
                            }
                        }
                        if self.didMoveFromInitialGesturePoint {
                            let presentationPoint = self.convert(localPoint, to: self.containerView)
                            self.highlightGestureMoved(location: presentationPoint)
                        }
                    }
                }
                component.gesture.externalEnded = { [weak self] viewAndPoint in
                    guard let self, let gesture = self.component?.gesture else {
                        return
                    }
                    gesture.externalUpdated = nil
                    if self.didMoveFromInitialGesturePoint {
                        self.highlightGestureFinished(performAction: viewAndPoint != nil)
                    } else {
                        self.highlightGestureFinished(performAction: false)
                    }
                }
            }
            
            self.component = component
            
            let theme = environment.theme
            
            if theme.overallDarkAppearance {
                self.backgroundView.updateColor(color: theme.contextMenu.backgroundColor, forceKeepBlur: true, transition: .immediate)
                self.backgroundTintView.backgroundColor = UIColor(white: 1.0, alpha: 0.5)
            } else {
                self.backgroundView.updateColor(color: .clear, forceKeepBlur: true, transition: .immediate)
                self.backgroundTintView.backgroundColor = theme.contextMenu.backgroundColor
            }
            
            let sourceRect = component.sourceNode.view.convert(component.sourceNode.view.bounds, to: nil)
            
            let sideInset: CGFloat = 16.0
            let padding: CGFloat = 5.0
            let spacing: CGFloat = 7.0
            let itemSize = CGSize(width: 38.0, height: 38.0)
            let itemsCount = 5
            
            var itemFrame = CGRect(origin: CGPoint(x: padding, y: padding), size: itemSize)
            if let peers = self.peers {
                for peer in peers {
                    var componentTransition = transition
                    let componentView: ComponentView<Empty>
                    if let current = self.items[peer.id] {
                        componentView = current
                    } else {
                        componentTransition = .immediate
                        componentView = ComponentView<Empty>()
                        self.items[peer.id] = componentView
                    }
                    
                    var isFocused: Bool?
                    if let selectedPeerId {
                        isFocused = peer.id == selectedPeerId
                    }
                    
                    let _ = componentView.update(
                        transition: componentTransition,
                        component: AnyComponent(
                            ItemComponent(
                                context: component.context,
                                theme: environment.theme,
                                peer: peer,
                                isFocused: isFocused
                            )
                        ),
                        environment: {},
                        containerSize: itemSize
                    )
                    if let view = componentView.view {
                        if view.superview == nil {
                            self.containerView.addSubview(view)
                        }
                        componentTransition.setFrame(view: view, frame: itemFrame)
                    }
                    itemFrame.origin.x += itemSize.width + spacing
                }
            }
            
            let size = CGSize(width: itemSize.width * CGFloat(itemsCount) + spacing * CGFloat(itemsCount - 1) + padding * 2.0, height: itemSize.height + padding * 2.0)
            let contentRect = CGRect(
                origin: CGPoint(
                    x: max(sideInset, min(availableSize.width - sideInset - size.width, sourceRect.maxX + itemSize.width + spacing - size.width)),
                    y: sourceRect.minY - size.height - padding * 2.0
                ),
                size: size
            )

            self.containerView.layer.cornerRadius = size.height / 2.0
            self.backgroundView.layer.cornerRadius = size.height / 2.0
            self.backgroundTintView.layer.cornerRadius = size.height / 2.0
            transition.setFrame(view: self.backgroundView, frame: contentRect)
            transition.setFrame(view: self.containerView, frame: contentRect)
            self.backgroundView.update(size: contentRect.size, cornerRadius: size.height / 2.0, transition: transition.containedViewLayoutTransition)
            transition.setFrame(view: self.backgroundTintView, frame: CGRect(origin: .zero, size: contentRect.size))
            
            return availableSize
        }
    }
    
    func makeView() -> View {
        return View(frame: CGRect())
    }
    
    func update(view: View, availableSize: CGSize, state: EmptyComponentState, environment: Environment<ViewControllerComponentContainer.Environment>, transition: ComponentTransition) -> CGSize {
        return view.update(component: self, availableSize: availableSize, state: state, environment: environment, transition: transition)
    }
}

public class QuickShareScreen: ViewControllerComponentContainer {
    private var processedDidAppear: Bool = false
    private var processedDidDisappear: Bool = false
    
    public init(
        context: AccountContext,
        sourceNode: ASDisplayNode,
        gesture: ContextGesture
    ) {
        super.init(
            context: context,
            component: QuickShareScreenComponent(
                context: context,
                sourceNode: sourceNode,
                gesture: gesture
            ),
            navigationBarAppearance: .none,
            statusBarStyle: .ignore,
            presentationMode: .default,
            updatedPresentationData: nil
        )
        self.navigationPresentation = .flatModal
    }
    
    required public init(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    deinit {
    }
    
    override public func containerLayoutUpdated(_ layout: ContainerViewLayout, transition: ContainedViewLayoutTransition) {
        super.containerLayoutUpdated(layout, transition: transition)
    }
    
    override public func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        if !self.processedDidAppear {
            self.processedDidAppear = true
            if let componentView = self.node.hostView.componentView as? QuickShareScreenComponent.View {
                componentView.animateIn()
            }
        }
    }
    
    private func superDismiss() {
        super.dismiss()
    }
    
    override public func dismiss(completion: (() -> Void)? = nil) {
        if !self.processedDidDisappear {
            self.processedDidDisappear = true
            
            if let componentView = self.node.hostView.componentView as? QuickShareScreenComponent.View {
                componentView.animateOut(completion: { [weak self] in
                    if let self {
                        self.superDismiss()
                    }
                    completion?()
                })
            } else {
                super.dismiss(completion: completion)
            }
        }
    }
}

private final class ItemComponent: Component {
    let context: AccountContext
    let theme: PresentationTheme
    let peer: EnginePeer
    let isFocused: Bool?
    
    init(
        context: AccountContext,
        theme: PresentationTheme,
        peer: EnginePeer,
        isFocused: Bool?
    ) {
        self.context = context
        self.theme = theme
        self.peer = peer
        self.isFocused = isFocused
    }
    
    static func ==(lhs: ItemComponent, rhs: ItemComponent) -> Bool {
        if lhs.peer != rhs.peer {
            return false
        }
        if lhs.isFocused != rhs.isFocused {
            return false
        }
        return true
    }
    
    final class View: UIView {
        private let avatarNode: AvatarNode
        private let backgroundNode: NavigationBackgroundNode
        private let text = ComponentView<Empty>()
        
        private var isUpdating: Bool = false
        private var component: QuickShareScreenComponent?
        private var environment: EnvironmentType?
        private weak var state: EmptyComponentState?
                        
        override init(frame: CGRect) {
            self.avatarNode = AvatarNode(font: avatarPlaceholderFont(size: 14.0))
            self.backgroundNode = NavigationBackgroundNode(color: .clear)
            
            super.init(frame: frame)
            
            self.addSubview(self.avatarNode.view)
            self.addSubview(self.backgroundNode.view)
        }
        
        required init?(coder: NSCoder) {
            preconditionFailure()
        }
        
        func update(component: ItemComponent, availableSize: CGSize, state: EmptyComponentState, environment: Environment<Empty>, transition: ComponentTransition) -> CGSize {
            self.isUpdating = true
            defer {
                self.isUpdating = false
            }
            
            var title = component.peer.compactDisplayTitle
            var overrideImage: AvatarNodeImageOverride?
            if component.peer.id == component.context.account.peerId {
                overrideImage = .savedMessagesIcon
                title = "Saved Messages"
            }
                        
            self.avatarNode.setPeer(
                context: component.context,
                theme: component.theme,
                peer: component.peer,
                overrideImage: overrideImage,
                synchronousLoad: true
            )
           
            self.avatarNode.view.center = CGPoint(x: availableSize.width / 2.0, y: availableSize.height / 2.0)
            self.avatarNode.view.bounds = CGRect(origin: .zero, size: availableSize)
            self.avatarNode.updateSize(size: availableSize)
            
            var scale: CGFloat = 1.0
            var alpha: CGFloat = 1.0
            var textAlpha: CGFloat = 0.0
            var textOffset: CGFloat = 6.0
            if let isFocused = component.isFocused {
                scale = isFocused ? 1.1 : 1.0
                alpha = isFocused ? 1.0 : 0.6
                textAlpha = isFocused ? 1.0 : 0.0
                textOffset = isFocused ? 0.0 : 6.0
            }
            transition.setScale(view: self.avatarNode.view, scale: scale)
            transition.setAlpha(view: self.avatarNode.view, alpha: alpha)
            
            let textSize = self.text.update(
                transition: .immediate,
                component: AnyComponent(
                    MultilineTextComponent(text: .plain(NSAttributedString(string: title, font: Font.semibold(13.0), textColor: .white)))
                ),
                environment: {},
                containerSize: CGSize(width: 160.0, height: 33.0)
            )
            if let textView = self.text.view {
                if textView.superview == nil {
                    self.addSubview(textView)
                }
                let textFrame = CGRect(origin: CGPoint(x: floor((availableSize.width - textSize.width) / 2.0), y: -16.0 - textSize.height + textOffset), size: textSize)
                transition.setFrame(view: textView, frame: textFrame)
                
                let backgroundFrame = textFrame.insetBy(dx: -7.0, dy: -3.0)
                transition.setFrame(view: self.backgroundNode.view, frame: backgroundFrame)
                self.backgroundNode.update(size: backgroundFrame.size, cornerRadius: backgroundFrame.size.height / 2.0, transition: .immediate)
                self.backgroundNode.updateColor(color: component.theme.chat.serviceMessage.components.withDefaultWallpaper.dateFillStatic, enableBlur: true, transition: .immediate)
                
                transition.setAlpha(view: textView, alpha: textAlpha)
                transition.setAlpha(view: self.backgroundNode.view, alpha: textAlpha)
            }
            
            return availableSize
        }
    }
    
    func makeView() -> View {
        return View(frame: CGRect())
    }
    
    func update(view: View, availableSize: CGSize, state: EmptyComponentState, environment: Environment<Empty>, transition: ComponentTransition) -> CGSize {
        return view.update(component: self, availableSize: availableSize, state: state, environment: environment, transition: transition)
    }
}
