import Foundation
import UIKit
import AsyncDisplayKit
import Display
import ComponentFlow
import SwiftSignalKit
import Postbox
import TelegramCore
import TelegramPresentationData
import AccountContext
import ViewControllerComponent
import MultilineTextComponent

private final class QuickBookmarksScreenComponent: Component {
    typealias EnvironmentType = ViewControllerComponentContainer.Environment
    
    let context: AccountContext
    let sourceNode: ASDisplayNode
    let gesture: ContextGesture
    let completion: (EnginePeer, Int64, CGRect, String) -> Void
    let ready: Promise<Bool>
    
    init(
        context: AccountContext,
        sourceNode: ASDisplayNode,
        gesture: ContextGesture,
        completion: @escaping (EnginePeer, Int64, CGRect, String) -> Void,
        ready: Promise<Bool>
    ) {
        self.context = context
        self.sourceNode = sourceNode
        self.gesture = gesture
        self.completion = completion
        self.ready = ready
    }
    
    static func ==(lhs: QuickBookmarksScreenComponent, rhs: QuickBookmarksScreenComponent) -> Bool {
        return true
    }
    
    private final class TopicItemComponent: Component {
        typealias EnvironmentType = Empty
        
        let context: AccountContext
        let theme: PresentationTheme
        let strings: PresentationStrings
        let title: String
        let iconColor: Int32
        let initial: String
        let safeInsets: UIEdgeInsets
        let isFocused: Bool?
        
        init(context: AccountContext, theme: PresentationTheme, strings: PresentationStrings, title: String, iconColor: Int32, initial: String, safeInsets: UIEdgeInsets, isFocused: Bool?) {
            self.context = context
            self.theme = theme
            self.strings = strings
            self.title = title
            self.iconColor = iconColor
            self.initial = initial
            self.safeInsets = safeInsets
            self.isFocused = isFocused
        }
        
        static func == (lhs: TopicItemComponent, rhs: TopicItemComponent) -> Bool {
            return lhs.title == rhs.title && lhs.iconColor == rhs.iconColor && lhs.initial == rhs.initial && lhs.safeInsets == rhs.safeInsets && lhs.isFocused == rhs.isFocused
        }
        
        final class View: UIView {
            private let iconContainer = UIView()
            private let initialLabel = UILabel()
            private let textView = ComponentView<Empty>()
            private let backgroundNode = NavigationBackgroundNode(color: .clear)
            
            override init(frame: CGRect) {
                super.init(frame: frame)
                self.iconContainer.clipsToBounds = true
                self.addSubview(self.iconContainer)
                self.initialLabel.font = Font.semibold(24.0)
                self.initialLabel.textAlignment = .center
                self.initialLabel.textColor = .white
                self.addSubview(self.initialLabel)
                self.addSubview(self.backgroundNode.view)
            }
            
            required init?(coder: NSCoder) { fatalError() }
            
            func update(component: TopicItemComponent, availableSize: CGSize, state: EmptyComponentState, environment: Environment<Empty>, transition: ComponentTransition) -> CGSize {
                let size = CGSize(width: 60.0, height: 60.0)
                let iconSize = CGSize(width: 54.0, height: 54.0)
                let iconFrame = CGRect(origin: CGPoint(x: floor((size.width - iconSize.width) / 2.0), y: floor((size.height - iconSize.height) / 2.0)), size: iconSize)
                transition.setFrame(view: self.iconContainer, frame: iconFrame)
                self.iconContainer.layer.cornerRadius = iconSize.width / 2.0
                self.iconContainer.backgroundColor = UIColor(rgb: UInt32(bitPattern: Int32(component.iconColor)))
                self.initialLabel.text = component.initial
                self.initialLabel.frame = iconFrame
                var textAlpha: CGFloat = 0.0
                var textOffset: CGFloat = 6.0
                if let isFocused = component.isFocused {
                    textAlpha = isFocused ? 1.0 : 0.0
                    textOffset = isFocused ? 0.0 : 6.0
                }
                let textSize = self.textView.update(
                    transition: .immediate,
                    component: AnyComponent(MultilineTextComponent(text: .plain(NSAttributedString(string: component.title, font: Font.semibold(13.0), textColor: .white)))),
                    environment: {},
                    containerSize: CGSize(width: 160.0, height: 33.0)
                )
                if let tv = self.textView.view {
                    if tv.superview == nil { self.addSubview(tv) }
                    let initialX = floor((size.width - textSize.width) / 2.0)
                    var textFrame = CGRect(origin: CGPoint(x: initialX, y: -13.0 - textSize.height + textOffset), size: textSize)
                    let sideInset: CGFloat = 8.0
                    let textPadding: CGFloat = 8.0
                    let leftDistanceToEdge = 0.0 - textFrame.minX
                    let rightDistanceToEdge = textFrame.maxX - size.width
                    let leftSafeInset = component.safeInsets.left - textPadding - sideInset
                    let rightSafeInset = component.safeInsets.right - textPadding - sideInset
                    if leftSafeInset < leftDistanceToEdge { textFrame.origin.x = -leftSafeInset }
                    if rightSafeInset < rightDistanceToEdge { textFrame.origin.x = size.width + rightSafeInset - textFrame.width }
                    transition.setFrame(view: tv, frame: textFrame)
                    let backgroundFrame = textFrame.insetBy(dx: -textPadding, dy: -3.0 - UIScreenPixel)
                    transition.setFrame(view: self.backgroundNode.view, frame: backgroundFrame)
                    self.backgroundNode.update(size: backgroundFrame.size, cornerRadius: backgroundFrame.size.height / 2.0, transition: .immediate)
                    self.backgroundNode.updateColor(color: component.theme.chat.serviceMessage.components.withDefaultWallpaper.dateFillStatic, enableBlur: true, transition: .immediate)
                    transition.setAlpha(view: tv, alpha: textAlpha)
                    transition.setAlpha(view: self.backgroundNode.view, alpha: textAlpha)
                }
                return size
            }
        }
        
        func makeView() -> View { View(frame: .zero) }
        func update(view: View, availableSize: CGSize, state: EmptyComponentState, environment: Environment<Empty>, transition: ComponentTransition) -> CGSize {
            return view.update(component: self, availableSize: availableSize, state: state, environment: environment, transition: transition)
        }
    }
    
    final class View: UIView {
        private let backgroundShadowLayer: SimpleLayer
        private let backgroundView: BlurredBackgroundView
        private let backgroundTintView: UIView
        private let containerView: UIView
        
        private var items: [(peer: EnginePeer, threadId: Int64, title: String, iconColor: Int32, iconFileId: Int64?)] = []
        private var itemViews: [UIView] = []
        
        private var component: QuickBookmarksScreenComponent?
        private var environment: EnvironmentType?
        private weak var state: EmptyComponentState?
        
        private var didCompleteAnimationIn = false
        private var initialPoint: CGPoint?
        private var didMoveFromInitialGesturePoint = false
        private var selectedIndex: Int?
        private var startedFetch: Bool = false
        
        private let haptic = HapticFeedback()
        
        override init(frame: CGRect) {
            self.backgroundView = BlurredBackgroundView(color: nil, enableBlur: true)
            self.backgroundView.clipsToBounds = true
            self.backgroundTintView = UIView()
            self.backgroundTintView.clipsToBounds = true
            
            self.backgroundShadowLayer = SimpleLayer()
            self.backgroundShadowLayer.opacity = 0.0
            
            self.containerView = UIView()
            self.containerView.clipsToBounds = true
            
            super.init(frame: frame)
            
            self.addSubview(self.backgroundView)
            self.backgroundView.addSubview(self.backgroundTintView)
            self.layer.addSublayer(self.backgroundShadowLayer)
            self.addSubview(self.containerView)
            let tap = UITapGestureRecognizer(target: self, action: #selector(self.onTapOutside(_:)))
            tap.cancelsTouchesInView = false
            self.addGestureRecognizer(tap)
        }
        required init?(coder: NSCoder) { fatalError() }
        
        @objc private func onTapOutside(_ recognizer: UITapGestureRecognizer) {
            guard let environment = self.environment else { return }
            let p = recognizer.location(in: self)
            if !self.containerView.frame.contains(p) {
                self.animateOut {
                    environment.controller()?.dismiss()
                }
            }
        }
        
        func animateIn() {
            self.haptic.impact()
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
            for itemView in self.itemViews {
                let distance = abs(itemView.frame.center.x - backgroundCenter)
                let distanceNorm = distance / backgroundWidth
                let itemDelay = mainCircleDelay + distanceNorm * 0.3
                itemView.isHidden = true
                DispatchQueue.main.asyncAfter(deadline: DispatchTime.now() + itemDelay * UIView.animationDurationFactor()) { [weak itemView] in
                    itemView?.isHidden = false
                    itemView?.layer.animateSpring(from: 0.01 as NSNumber, to: 0.63 as NSNumber, keyPath: "transform.scale", duration: 0.4)
                }
            }
            Queue.mainQueue().after(0.3) {
                self.containerView.clipsToBounds = false
                self.didCompleteAnimationIn = true
            }
        }
        
        func animateOut(completion: @escaping () -> Void) {
            let transition = ComponentTransition(animation: .curve(duration: 0.3, curve: .linear))
            transition.setAlpha(view: self, alpha: 0.0, completion: { _ in completion() })
        }
        
        func update(component: QuickBookmarksScreenComponent, availableSize: CGSize, state: EmptyComponentState, environment: Environment<ViewControllerComponentContainer.Environment>, transition: ComponentTransition) -> CGSize {
            self.component = component
            let env = environment[ViewControllerComponentContainer.Environment.self].value
            self.environment = env
            self.state = state
            
            // Theming like QuickShare
            let theme = env.theme
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
            let itemsCount = max(1, min(self.items.count, 5))
            
            let widthExtension: CGFloat = self.selectedIndex != nil ? selectedItemSize.width - itemSize.width : 0.0
            let size = CGSize(width: itemSize.width * CGFloat(itemsCount) + spacing * CGFloat(itemsCount - 1) + padding * 2.0 + widthExtension, height: itemSize.height + padding * 2.0)
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
            self.backgroundView.update(size: contentRect.size, cornerRadius: 0.0, transition: transition.containedViewLayoutTransition)
            transition.setFrame(view: self.backgroundTintView, frame: CGRect(origin: .zero, size: contentRect.size))
            
            let shadowInset: CGFloat = 15.0
            let shadowColor = UIColor(white: 0.0, alpha: 0.4)
            if self.backgroundShadowLayer.contents == nil, let image = generateBubbleShadowImage(shadow: shadowColor, diameter: 46.0, shadowBlur: shadowInset) {
                ASDisplayNodeSetResizableContents(self.backgroundShadowLayer, image)
            }
            transition.setFrame(layer: self.backgroundShadowLayer, frame: contentRect.insetBy(dx: -shadowInset, dy: -shadowInset))
            
            // Initial fetch of Bookmarks topics
            if !self.startedFetch {
                self.startedFetch = true
                let presentationData = component.context.sharedContext.currentPresentationData.with { $0 }
                let _ = (component.context.engine.contacts.searchLocalPeers(query: "Bookmarks")
                |> take(1)
                |> map { peers -> EnginePeer? in
                    for rendered in peers {
                        if let peer = rendered.peer, case let .channel(channel) = peer, channel.isForum {
                            if peer.displayTitle(strings: presentationData.strings, displayOrder: presentationData.nameDisplayOrder) == "Bookmarks" {
                                return peer
                            }
                        }
                    }
                    return nil
                }
                |> mapToSignal { peerOpt -> Signal<[(EnginePeer, Int64, String, Int32, Int64?)], NoError> in
                    guard let bookmarksPeer = peerOpt else { return .single([]) }
                    return component.context.account.postbox.transaction { transaction -> [(EnginePeer, Int64, String, Int32, Int64?)] in
                        var result: [(EnginePeer, Int64, String, Int32, Int64?)] = []
                        let entries = transaction.getMessageHistoryThreadIndex(peerId: bookmarksPeer.id, limit: 8)
                        for entry in entries {
                            if let data: MessageHistoryThreadData = entry.info.data.get(MessageHistoryThreadData.self) {
                                let title = data.info.title
                                let iconColor: Int32 = data.info.iconColor
                                let iconFileId: Int64? = data.info.icon
                                result.append((bookmarksPeer, entry.threadId, title, iconColor, iconFileId))
                            }
                        }
                        return result
                    }
                }
                |> deliverOnMainQueue).startStandalone(next: { [weak self] items in
                    self?.setItems(items)
                    component.ready.set(.single(true))
                })
            }
            
            // Layout topic items using TopicItemComponent
            var itemFrame = CGRect(origin: CGPoint(x: padding, y: padding), size: itemSize)
            for v in self.itemViews { v.removeFromSuperview() }
            self.itemViews.removeAll()
            let showItems = Array(self.items.prefix(itemsCount))
            for (index, item) in showItems.enumerated() {
                let isFocused = (index == self.selectedIndex)
                let effectiveItemSize = isFocused ? selectedItemSize : itemSize
                let effectiveItemFrame = CGRect(origin: itemFrame.origin.offsetBy(dx: 0.0, dy: itemSize.height - effectiveItemSize.height), size: effectiveItemSize)
                let componentView = ComponentView<Empty>()
                let _ = componentView.update(
                    transition: .immediate,
                    component: AnyComponent(TopicItemComponent(
                        context: component.context,
                        theme: env.theme,
                        strings: env.strings,
                        title: item.title,
                        iconColor: item.iconColor,
                        initial: String(item.title.prefix(1)),
                        safeInsets: UIEdgeInsets(top: 0.0, left: contentRect.minX + effectiveItemFrame.minX, bottom: 0.0, right: availableSize.width - contentRect.maxX + contentRect.width - effectiveItemFrame.maxX),
                        isFocused: isFocused
                    )),
                    environment: {},
                    containerSize: selectedItemSize
                )
                if let v = componentView.view {
                    self.containerView.addSubview(v)
                    transition.setScale(view: v, scale: effectiveItemSize.width / selectedItemSize.width)
                    transition.setBounds(view: v, bounds: CGRect(origin: .zero, size: selectedItemSize))
                    transition.setPosition(view: v, position: effectiveItemFrame.center)
                    self.itemViews.append(v)
                }
                itemFrame.origin.x += effectiveItemFrame.width + spacing
            }
            
            // Gesture piping like QuickShare
            component.gesture.externalUpdated = { [weak self] view, point in
                guard let self else { return }
                let localPoint = self.convert(point, from: view)
                let initialPoint: CGPoint
                if let current = self.initialPoint {
                    initialPoint = current
                } else {
                    initialPoint = localPoint
                    self.initialPoint = localPoint
                }
                if self.didCompleteAnimationIn {
                    if !self.didMoveFromInitialGesturePoint {
                        let distance = abs(localPoint.y - initialPoint.y)
                        if distance > 4.0 { self.didMoveFromInitialGesturePoint = true }
                    }
                    if self.didMoveFromInitialGesturePoint {
                        // find selected index
                        var newSelected: Int?
                        for (idx, v) in self.itemViews.enumerated() {
                            if v.frame.insetBy(dx: -6.0, dy: -6.0).contains(localPoint) { newSelected = idx; break }
                        }
                        if newSelected != self.selectedIndex {
                            self.haptic.tap()
                            self.selectedIndex = newSelected
                            self.state?.updated(transition: .spring(duration: 0.2))
                        }
                    }
                }
            }
            component.gesture.externalEnded = { [weak self] _ in
                guard let self, let component = self.component else { return }
                let idx = self.selectedIndex
                self.animateOut {
                    self.environment?.controller()?.dismiss()
                    if let idx, idx < self.items.count {
                        let topic = self.items[idx]
                        let view = self.itemViews[idx]
                        let frame = view.convert(view.bounds, to: nil)
                        component.completion(topic.peer, topic.threadId, frame, topic.title)
                    }
                }
            }
            
            component.ready.set(.single(true))
            return availableSize
        }
        
        func setItems(_ items: [(EnginePeer, Int64, String, Int32, Int64?)]) {
            self.items = items
            self.state?.updated(transition: .spring(duration: 0.2))
        }
        
        @objc private func itemTapped(_ recognizer: UITapGestureRecognizer) {
            guard let component = self.component, let environment = self.environment else { return }
            guard let name = recognizer.name, let idx = Int(name), idx >= 0, idx < self.items.count else { return }
            let item = self.items[idx]
            let sourceFrame: CGRect
            if let view = recognizer.view {
                sourceFrame = view.convert(view.bounds, to: nil)
            } else {
                sourceFrame = self.convert(self.bounds, to: nil)
            }
            self.animateOut {
                environment.controller()?.dismiss()
                component.completion(item.peer, item.threadId, sourceFrame, item.title)
            }
        }
    }
    
    func makeView() -> View {
        return View()
    }
    
    func update(view: View, availableSize: CGSize, state: EmptyComponentState, environment: Environment<ViewControllerComponentContainer.Environment>, transition: ComponentTransition) -> CGSize {
        return view.update(component: self, availableSize: availableSize, state: state, environment: environment, transition: transition)
    }
}

public final class QuickBookmarksScreen: ViewControllerComponentContainer {
    private let readyValue = Promise<Bool>()
    public var onReady: (() -> Void)?
    
    public init(context: AccountContext, sourceNode: ASDisplayNode, gesture: ContextGesture, completion: @escaping (EnginePeer, Int64, CGRect, String) -> Void) {
        let ready = Promise<Bool>()
        let component = QuickBookmarksScreenComponent(context: context, sourceNode: sourceNode, gesture: gesture, completion: completion, ready: ready)
        super.init(context: context, component: component, navigationBarAppearance: .none)
        self.statusBar.statusBarStyle = .Ignore
        self.onReady = { [weak self] in
            if let view = self?.node.hostView.componentView as? QuickBookmarksScreenComponent.View {
                view.animateIn()
            }
        }
        self.readyValue.set(ready.get())
        self.ready.set(self.readyValue.get())
    }
    
    required public init(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override public func viewDidLoad() {
        super.viewDidLoad()
    }
    
    override public func loadDisplayNode() {
        super.loadDisplayNode()
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
