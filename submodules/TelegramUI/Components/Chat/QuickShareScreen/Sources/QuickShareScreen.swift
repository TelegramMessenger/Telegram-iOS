import Foundation
import UIKit
import AsyncDisplayKit
import Display
import ComponentFlow
import SwiftSignalKit
import Postbox
import TelegramCore
import TextFormat
import TelegramPresentationData
import MultilineTextComponent
import AccountContext
import ViewControllerComponent
import AvatarNode
import ComponentDisplayAdapters

private let largeCircleSize: CGFloat = 16.0
private let smallCircleSize: CGFloat = 8.0

private final class QuickShareScreenComponent: Component {
    typealias EnvironmentType = ViewControllerComponentContainer.Environment
    
    let context: AccountContext
    let sourceNode: ASDisplayNode
    let gesture: ContextGesture
    let completion: (EnginePeer, CGRect) -> Void
    let ready: Promise<Bool>
    
    init(
        context: AccountContext,
        sourceNode: ASDisplayNode,
        gesture: ContextGesture,
        completion: @escaping (EnginePeer, CGRect) -> Void,
        ready: Promise<Bool>
    ) {
        self.context = context
        self.sourceNode = sourceNode
        self.gesture = gesture
        self.completion = completion
        self.ready = ready
    }
    
    static func ==(lhs: QuickShareScreenComponent, rhs: QuickShareScreenComponent) -> Bool {
        return true
    }
    
    final class View: UIView {
        private let backgroundShadowLayer: SimpleLayer
        private let backgroundView: BlurredBackgroundView
        private let backgroundTintView: UIView
        private let containerView: UIView
        
        private let largeCircleLayer: SimpleLayer
        private let largeCircleShadowLayer: SimpleLayer
        private let smallCircleLayer: SimpleLayer
        private let smallCircleShadowLayer: SimpleLayer
        
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
        
        private let hapticFeedback = HapticFeedback()
        
        override init(frame: CGRect) {
            self.backgroundView = BlurredBackgroundView(color: nil, enableBlur: true)
            self.backgroundView.clipsToBounds = true
            self.backgroundTintView = UIView()
            self.backgroundTintView.clipsToBounds = true
            
            self.backgroundShadowLayer = SimpleLayer()
            self.backgroundShadowLayer.opacity = 0.0
            
            self.largeCircleLayer = SimpleLayer()
            self.largeCircleShadowLayer = SimpleLayer()
            self.smallCircleLayer = SimpleLayer()
            self.smallCircleShadowLayer = SimpleLayer()
            
            self.largeCircleLayer.backgroundColor = UIColor.black.cgColor
            self.largeCircleLayer.masksToBounds = true
            self.largeCircleLayer.cornerRadius = largeCircleSize / 2.0
            
            self.smallCircleLayer.backgroundColor = UIColor.black.cgColor
            self.smallCircleLayer.masksToBounds = true
            self.smallCircleLayer.cornerRadius = smallCircleSize / 2.0
            
            self.containerView = UIView()
            self.containerView.clipsToBounds = true
            
            super.init(frame: frame)
            
            self.addSubview(self.backgroundView)
            self.backgroundView.addSubview(self.backgroundTintView)
            self.layer.addSublayer(self.backgroundShadowLayer)
            self.addSubview(self.containerView)
        }
        
        required init?(coder: NSCoder) {
            preconditionFailure()
        }
        
        deinit {
            self.disposable?.dispose()
        }
                
        func animateIn() {
            self.hapticFeedback.impact()
            
            let transition = ComponentTransition(animation: .curve(duration: 0.3, curve: .spring))
            transition.animateBoundsSize(view: self.backgroundView, from: CGSize(width: 0.0, height: self.backgroundView.bounds.height), to: self.backgroundView.bounds.size)
            transition.animateBounds(view: self.containerView, from: CGRect(x: self.containerView.bounds.width / 2.0, y: 0.0, width: 0.0, height: self.backgroundView.bounds.height), to: self.containerView.bounds)
            self.backgroundView.layer.animate(from: 0.0 as NSNumber, to: self.backgroundView.layer.cornerRadius as NSNumber, keyPath: "cornerRadius", timingFunction: CAMediaTimingFunctionName.easeInEaseOut.rawValue, duration: 0.1)
            self.backgroundTintView.layer.animate(from: 0.0 as NSNumber, to: self.backgroundTintView.layer.cornerRadius as NSNumber, keyPath: "cornerRadius", timingFunction: CAMediaTimingFunctionName.easeInEaseOut.rawValue, duration: 0.1)
            
            self.backgroundShadowLayer.opacity = 1.0
            transition.animateBoundsSize(layer: self.backgroundShadowLayer, from: CGSize(width: 0.0, height: self.backgroundShadowLayer.bounds.height), to: self.backgroundShadowLayer.bounds.size)
            self.backgroundShadowLayer.animateAlpha(from: 0.0, to: 1.0, duration: 0.3)
            
            let mainCircleDelay: Double = 0.01
            let backgroundCenter = self.backgroundView.frame.width / 2.0
            let backgroundWidth = self.backgroundView.frame.width
            for item in self.items.values {
                guard let itemView = item.view else {
                    continue
                }
                
                let distance = abs(itemView.frame.center.x - backgroundCenter)
                let distanceNorm = distance / backgroundWidth
                let adjustedDistanceNorm = distanceNorm
                let itemDelay = mainCircleDelay + adjustedDistanceNorm * 0.3
                
                itemView.isHidden = true
                DispatchQueue.main.asyncAfter(deadline: DispatchTime.now() + itemDelay * UIView.animationDurationFactor(), execute: { [weak itemView] in
                    guard let itemView else {
                        return
                    }
                    itemView.isHidden = false
                    itemView.layer.animateSpring(from: 0.01 as NSNumber, to: 0.63 as NSNumber, keyPath: "transform.scale", duration: 0.4)
                })
            }
            
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
            var selectedPeerId: EnginePeer.Id?
            for (peerId, view) in self.items {
                guard let view = view.view else {
                    continue
                }
                if view.frame.insetBy(dx: -4.0, dy: -4.0).contains(location) {
                    selectedPeerId = peerId
                    break
                }
            }
            if let selectedPeerId, selectedPeerId != self.selectedPeerId {
                self.hapticFeedback.tap()
            }
            self.selectedPeerId = selectedPeerId
            self.state?.updated(transition: .spring(duration: 0.3))
        }
        
        func highlightGestureFinished(performAction: Bool) {
            if let selectedPeerId = self.selectedPeerId, performAction {
                if let component = self.component, let peer = self.peers?.first(where: { $0.id == selectedPeerId }), let view = self.items[selectedPeerId]?.view as? ItemComponent.View {
                    component.completion(peer, view.convert(view.bounds, to: nil))
                    view.avatarNode.isHidden = true
                }
                
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
                let peers = component.context.engine.peers.recentPeers()
                |> take(1)
                |> mapToSignal { recentPeers -> Signal<[EnginePeer], NoError> in
                    if case let .peers(peers) = recentPeers, !peers.isEmpty {
                        return .single(peers.map(EnginePeer.init))
                    } else {
                        return component.context.account.stateManager.postbox.tailChatListView(
                            groupId: .root,
                            count: 20,
                            summaryComponents: ChatListEntrySummaryComponents()
                        )
                        |> take(1)
                        |> map { view -> [EnginePeer] in
                            var peers: [EnginePeer] = []
                            for entry in view.0.entries.reversed() {
                                if case let .MessageEntry(entryData) = entry {
                                    if let user = entryData.renderedPeer.chatMainPeer as? TelegramUser, user.isGenericUser && user.id != component.context.account.peerId && !user.id.isSecretChat {
                                        peers.append(EnginePeer(user))
                                    }
                                }
                            }
                            return peers
                        }
                    }
                }
                
                self.disposable = combineLatest(queue: Queue.mainQueue(),
                    peers,
                    component.context.engine.data.get(TelegramEngine.EngineData.Item.Peer.Peer(id: component.context.account.peerId))
                ).start(next: { [weak self] peers, accountPeer in
                    guard let self else {
                        return
                    }
                    if !peers.isEmpty, let accountPeer {
                        self.peers = Array([accountPeer] + peers.prefix(4))
                        self.state?.updated()
                        component.ready.set(.single(true))
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
                self.backgroundTintView.backgroundColor = .clear
            } else {
                self.backgroundView.updateColor(color: .clear, forceKeepBlur: true, transition: .immediate)
                self.backgroundTintView.backgroundColor = theme.contextMenu.backgroundColor
            }
            
            let sourceRect = component.sourceNode.view.convert(component.sourceNode.view.bounds, to: nil)
            
            let sideInset: CGFloat = 16.0
            let padding: CGFloat = 5.0
            let spacing: CGFloat = 7.0
            let itemSize = CGSize(width: 38.0, height: 38.0)
            let selectedItemSize = CGSize(width: 60.0, height: 60.0)
            let itemsCount = self.peers?.count ?? 5
            
            let widthExtension: CGFloat = self.selectedPeerId != nil ? selectedItemSize.width - itemSize.width : 0.0
            
            let size = CGSize(width: itemSize.width * CGFloat(itemsCount) + spacing * CGFloat(itemsCount - 1) + padding * 2.0 + widthExtension, height: itemSize.height + padding * 2.0)
            let contentRect = CGRect(
                origin: CGPoint(
                    x: max(sideInset, min(availableSize.width - sideInset - size.width, sourceRect.maxX + itemSize.width + spacing - size.width)),
                    y: sourceRect.minY - size.height - padding * 2.0
                ),
                size: size
            )
            
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
                    
                    let effectiveItemSize = isFocused == true ? selectedItemSize : itemSize
                    let effectiveItemFrame = CGRect(origin: itemFrame.origin.offsetBy(dx: 0.0, dy: itemSize.height - effectiveItemSize.height), size: effectiveItemSize)
                    
                    let _ = componentView.update(
                        transition: componentTransition,
                        component: AnyComponent(
                            ItemComponent(
                                context: component.context,
                                theme: environment.theme,
                                strings: environment.strings,
                                peer: peer,
                                safeInsets: UIEdgeInsets(top: 0.0, left: contentRect.minX + effectiveItemFrame.minX, bottom: 0.0, right: availableSize.width - contentRect.maxX + contentRect.width - effectiveItemFrame.maxX),
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
                        componentTransition.setScale(view: view, scale: effectiveItemSize.width / selectedItemSize.width)
                        componentTransition.setBounds(view: view, bounds: CGRect(origin: .zero, size: selectedItemSize))
                        componentTransition.setPosition(view: view, position: effectiveItemFrame.center)
                    }
                    itemFrame.origin.x += effectiveItemFrame.width + spacing
                }
            }
            
            self.containerView.layer.cornerRadius = size.height / 2.0
            self.backgroundView.layer.cornerRadius = size.height / 2.0
            self.backgroundTintView.layer.cornerRadius = size.height / 2.0
            transition.setFrame(view: self.backgroundView, frame: contentRect)
            transition.setFrame(view: self.containerView, frame: contentRect)
            self.backgroundView.update(size: contentRect.size, cornerRadius: 0.0, transition: transition.containedViewLayoutTransition)
            transition.setFrame(view: self.backgroundTintView, frame: CGRect(origin: .zero, size: contentRect.size))
            
            let shadowInset: CGFloat = 15.0
            let shadowColor = UIColor(white: 0.0, alpha: 0.4)
            if self.backgroundShadowLayer.contents == nil, let image = generateBubbleShadowImage(shadow: shadowColor, diameter: 46.0, shadowBlur: shadowInset) {
                ASDisplayNodeSetResizableContents(self.backgroundShadowLayer, image)
            }
            transition.setFrame(layer: self.backgroundShadowLayer, frame: contentRect.insetBy(dx: -shadowInset, dy: -shadowInset))
            
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
    
    private let readyValue = Promise<Bool>()
    override public var ready: Promise<Bool> {
        return self.readyValue
    }
    
    public init(
        context: AccountContext,
        sourceNode: ASDisplayNode,
        gesture: ContextGesture,
        completion: @escaping (EnginePeer, CGRect) -> Void
    ) {
        let componentReady = Promise<Bool>()
        
        super.init(
            context: context,
            component: QuickShareScreenComponent(
                context: context,
                sourceNode: sourceNode,
                gesture: gesture,
                completion: completion,
                ready: componentReady
            ),
            navigationBarAppearance: .none,
            statusBarStyle: .ignore,
            presentationMode: .default,
            updatedPresentationData: nil
        )
        self.navigationPresentation = .flatModal
        
        self.readyValue.set(componentReady.get() |> timeout(1.0, queue: .mainQueue(), alternate: .single(true)))
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
    let strings: PresentationStrings
    let peer: EnginePeer
    let safeInsets: UIEdgeInsets
    let isFocused: Bool?
    
    init(
        context: AccountContext,
        theme: PresentationTheme,
        strings: PresentationStrings,
        peer: EnginePeer,
        safeInsets: UIEdgeInsets,
        isFocused: Bool?
    ) {
        self.context = context
        self.theme = theme
        self.strings = strings
        self.peer = peer
        self.safeInsets = safeInsets
        self.isFocused = isFocused
    }
    
    static func ==(lhs: ItemComponent, rhs: ItemComponent) -> Bool {
        if lhs.peer != rhs.peer {
            return false
        }
        if lhs.safeInsets != rhs.safeInsets {
            return false
        }
        if lhs.isFocused != rhs.isFocused {
            return false
        }
        return true
    }
    
    final class View: UIView {
        fileprivate let avatarNode: AvatarNode
        private let backgroundNode: NavigationBackgroundNode
        private let text = ComponentView<Empty>()
        
        private var isUpdating: Bool = false
        private var component: QuickShareScreenComponent?
        private var environment: EnvironmentType?
        private weak var state: EmptyComponentState?
                        
        override init(frame: CGRect) {
            self.avatarNode = AvatarNode(font: avatarPlaceholderFont(size: 26.0))
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
            
            let size = CGSize(width: 60.0, height: 60.0)
            
            var title = component.peer.compactDisplayTitle
            var overrideImage: AvatarNodeImageOverride?
            if component.peer.id == component.context.account.peerId {
                overrideImage = .savedMessagesIcon
                title = component.strings.DialogList_SavedMessages
            }
                        
            self.avatarNode.setPeer(
                context: component.context,
                theme: component.theme,
                peer: component.peer,
                overrideImage: overrideImage,
                synchronousLoad: true
            )
           
            self.avatarNode.view.center = CGPoint(x: size.width / 2.0, y: size.height / 2.0)
            self.avatarNode.view.bounds = CGRect(origin: .zero, size: size)
            self.avatarNode.updateSize(size: size)
            
            var textAlpha: CGFloat = 0.0
            var textOffset: CGFloat = 6.0
            if let isFocused = component.isFocused {
                textAlpha = isFocused ? 1.0 : 0.0
                textOffset = isFocused ? 0.0 : 6.0
            }
            
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
                
                let initialX = floor((size.width - textSize.width) / 2.0)
                var textFrame = CGRect(origin: CGPoint(x: initialX, y: -13.0 - textSize.height + textOffset), size: textSize)
                
                let sideInset: CGFloat = 8.0
                let textPadding: CGFloat = 8.0
                let leftDistanceToEdge = 0.0 - textFrame.minX
                let rightDistanceToEdge = textFrame.maxX - size.width
                
                let leftSafeInset = component.safeInsets.left - textPadding - sideInset
                let rightSafeInset = component.safeInsets.right - textPadding - sideInset
                if leftSafeInset < leftDistanceToEdge {
                    textFrame.origin.x = -leftSafeInset
                }
                if rightSafeInset < rightDistanceToEdge {
                    textFrame.origin.x = size.width + rightSafeInset - textFrame.width
                }
                
                transition.setFrame(view: textView, frame: textFrame)
                
                let backgroundFrame = textFrame.insetBy(dx: -textPadding, dy: -3.0 - UIScreenPixel)
                transition.setFrame(view: self.backgroundNode.view, frame: backgroundFrame)
                self.backgroundNode.update(size: backgroundFrame.size, cornerRadius: backgroundFrame.size.height / 2.0, transition: .immediate)
                self.backgroundNode.updateColor(color: component.theme.chat.serviceMessage.components.withDefaultWallpaper.dateFillStatic, enableBlur: true, transition: .immediate)
                
                transition.setAlpha(view: textView, alpha: textAlpha)
                transition.setAlpha(view: self.backgroundNode.view, alpha: textAlpha)
            }
            
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

private func generateBubbleShadowImage(shadow: UIColor, diameter: CGFloat, shadowBlur: CGFloat) -> UIImage? {
    return generateImage(CGSize(width: diameter + shadowBlur * 2.0, height: diameter + shadowBlur * 2.0), rotatedContext: { size, context in
        context.clear(CGRect(origin: CGPoint(), size: size))
        context.setFillColor(shadow.cgColor)
        context.setShadow(offset: CGSize(), blur: shadowBlur, color: shadow.cgColor)
        context.fillEllipse(in: CGRect(origin: CGPoint(x: shadowBlur, y: shadowBlur), size: CGSize(width: diameter, height: diameter)))
        context.setShadow(offset: CGSize(), blur: 1.0, color: shadow.cgColor)
        context.fillEllipse(in: CGRect(origin: CGPoint(x: shadowBlur, y: shadowBlur), size: CGSize(width: diameter, height: diameter)))
        context.setFillColor(UIColor.clear.cgColor)
        context.setBlendMode(.copy)
        context.fillEllipse(in: CGRect(origin: CGPoint(x: shadowBlur, y: shadowBlur), size: CGSize(width: diameter, height: diameter)))
    })?.stretchableImage(withLeftCapWidth: Int(shadowBlur + diameter / 2.0), topCapHeight: Int(shadowBlur + diameter / 2.0))
}
