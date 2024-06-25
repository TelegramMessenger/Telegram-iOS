import Foundation
import UIKit
import Display
import AsyncDisplayKit
import SwiftSignalKit
import TelegramPresentationData
import ComponentFlow
import AccountContext

private let minimizedNavigationHeight: CGFloat = 44.0
private let minimizedTopMargin: CGFloat = 3.0

final class ScrollViewImpl: UIScrollView {
    var passthrough = false
    
    override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        let result = super.hitTest(point, with: event)
        if result === self && self.passthrough {
            return nil
        }
        return result
    }
}

public class MinimizedContainerImpl: ASDisplayNode, MinimizedContainer, ASScrollViewDelegate, ASGestureRecognizerDelegate {
    final class Item {
        let id: AnyHashable
        let controller: ViewController
        
        init(id: AnyHashable, controller: ViewController) {
            self.id = id
            self.controller = controller
        }
    }
    
    final class ItemNode: ASDisplayNode {
        var theme: PresentationTheme {
            didSet {
                if self.theme !== oldValue {
                    self.headerNode.theme = NavigationControllerTheme(presentationTheme: self.theme)
                }
            }
        }
        
        let item: Item
        private let containerNode: ASDisplayNode
        private let headerNode: MinimizedHeaderNode
        private let dimCoverNode: ASDisplayNode
        private let shadowNode: ASImageNode
        
        var tapped: (() -> Void)?
        var highlighted: ((Bool) -> Void)?
        var closeTapped: (() -> Void)?
        
        var isCovered: Bool = false {
            didSet {
                let transition: ContainedViewLayoutTransition = .animated(duration: 0.25, curve: .easeInOut)
                transition.updateAlpha(node: self.dimCoverNode, alpha: self.isCovered ? 0.25 : 0.0)
            }
        }
        var isExpanded = false
        
        private var validLayout: (CGSize, UIEdgeInsets)?
        
        init(theme: PresentationTheme, strings: PresentationStrings, item: Item) {
            self.theme = theme
            self.item = item
            
            self.shadowNode = ASImageNode()
            self.shadowNode.clipsToBounds = true
            self.shadowNode.cornerRadius = 10.0
            self.shadowNode.displaysAsynchronously = false
            self.shadowNode.displayWithoutProcessing = true
            self.shadowNode.contentMode = .scaleToFill
            self.shadowNode.isUserInteractionEnabled = false
            
            self.containerNode = ASDisplayNode()
            self.containerNode.isUserInteractionEnabled = false
            self.containerNode.cornerRadius = 10.0
            
            self.headerNode = MinimizedHeaderNode(theme: NavigationControllerTheme(presentationTheme: theme), strings: strings)
            self.headerNode.layer.allowsGroupOpacity = true
            
            self.dimCoverNode = ASDisplayNode()
            self.dimCoverNode.alpha = 0.0
            self.dimCoverNode.backgroundColor = UIColor.black
            self.dimCoverNode.isUserInteractionEnabled = false
            
            super.init()
                        
            self.clipsToBounds = true
            self.cornerRadius = 10.0
            applySmoothRoundedCorners(self.layer)
            applySmoothRoundedCorners(self.containerNode.layer)
            
            self.shadowNode.image = shadowImage
            
            self.addSubnode(self.containerNode)
            self.containerNode.addSubnode(self.item.controller.displayNode)
            self.addSubnode(self.headerNode)
            self.addSubnode(self.dimCoverNode)
            self.addSubnode(self.shadowNode)
            
            self.headerNode.requestClose = { [weak self] in
                if let self {
                    self.closeTapped?()
                }
            }
            
            self.headerNode.requestMaximize = { [weak self] in
                if let self {
                    self.tapped?()
                }
            }
            
            self.headerNode.controllers = [item.controller]
        }
        
        func setTitleControllers(_ controllers: [ViewController]?) {
            self.headerNode.controllers = controllers ?? [self.item.controller]
        }
        
        func animateIn() {
            self.headerNode.alpha = 0.0
            let alphaTransition = ContainedViewLayoutTransition.animated(duration: 0.25, curve: .easeInOut)
            alphaTransition.updateAlpha(node: self.headerNode, alpha: 1.0)
        }
        
        private var isDismissed = false
        func animateOut() {
            self.isDismissed = true
            let transition = ContainedViewLayoutTransition.animated(duration: 0.25, curve: .easeInOut)
            transition.updateAlpha(node: self.headerNode, alpha: 0.0)
            transition.updateAlpha(node: self.shadowNode, alpha: 0.0)
        }
        
        override func didLoad() {
            super.didLoad()
            
            let recognizer = TapLongTapOrDoubleTapGestureRecognizer(target: self, action: #selector(self.tapLongTapOrDoubleTapGesture(_:)))
            recognizer.tapActionAtPoint = { point in
                return .waitForSingleTap
            }
            recognizer.highlight = { [weak self] point in
                if let point = point, point.x > 280.0 {
                    self?.highlighted?(true)
                } else {
                    self?.highlighted?(false)
                }
            }
            self.view.addGestureRecognizer(recognizer)
        }
        
        @objc func tapLongTapOrDoubleTapGesture(_ recognizer: TapLongTapOrDoubleTapGestureRecognizer) {
            guard let (_, insets) = self.validLayout else {
                return
            }
            switch recognizer.state {
            case .ended:
                if let (gesture, location) = recognizer.lastRecognizedGestureAndLocation {
                    switch gesture {
                    case .tap:
                        if location.x < insets.left + minimizedNavigationHeight && location.y < minimizedNavigationHeight {
                            self.closeTapped?()
                        } else {
                            self.tapped?()
                        }
                    default:
                        break
                    }
                }
            default:
                break
            }
        }
        
        func updateLayout(size: CGSize, insets: UIEdgeInsets, transition: ContainedViewLayoutTransition) {
            self.validLayout = (size, insets)
            
            var topInset = insets.top
            if size.width < size.height {
                topInset += 10.0
            }
            self.containerNode.frame = CGRect(origin: .zero, size: size)
            self.containerNode.subnodeTransform = CATransform3DMakeTranslation(0.0, -topInset, 0.0)
            
            self.shadowNode.frame = CGRect(origin: .zero, size: CGSize(width: size.width, height: size.height - topInset))
            
            var navigationHeight: CGFloat = minimizedNavigationHeight
            if !self.isExpanded {
                navigationHeight += insets.bottom
            }
            
            let headerFrame = CGRect(origin: .zero, size: CGSize(width: size.width, height: navigationHeight))
            self.headerNode.update(size: size, insets: insets, transition: transition)
            transition.updateFrame(node: self.headerNode, frame: headerFrame)
            transition.updateFrame(node: self.dimCoverNode, frame: CGRect(origin: .zero, size: size))
            
            if !self.isDismissed {
                transition.updateAlpha(node: self.shadowNode, alpha: self.isExpanded ? 1.0 : 0.0)
            }
        }
    }
    
    private let context: AccountContext
    private weak var navigationController: NavigationController?
    private var items: [Item] = []
    
    private var presentationData: PresentationData
    private var presentationDataDisposable: Disposable?
    
    var isExpanded: Bool = false
    public var willMaximize: (() -> Void)?
    
    private let bottomEdgeView: UIImageView
    private let blurView: BlurView
    private let dimView: UIView
    private let scrollView: ScrollViewImpl
    private var itemNodes: [AnyHashable: ItemNode] = [:]
    
    private var highlightedItemId: AnyHashable?
    
    private var dismissGestureRecognizer: UIPanGestureRecognizer?
    private var dismissingItemId: AnyHashable?
    private var dismissingItemOffset: CGFloat?
        
    private var currentTransition: Transition?
    private var validLayout: ContainerViewLayout?
    
    public init(context: AccountContext, navigationController: NavigationController) {
        self.context = context
        self.navigationController = navigationController
        self.presentationData = context.sharedContext.currentPresentationData.with { $0 }
        
        self.bottomEdgeView = UIImageView()
        self.bottomEdgeView.contentMode = .scaleToFill
        self.bottomEdgeView.image = generateImage(CGSize(width: 22.0, height: 24.0), rotatedContext: { size, context in
            context.setFillColor(UIColor.black.cgColor)
            context.fill(CGRect(origin: .zero, size: size))
            
            context.setBlendMode(.clear)
            context.setFillColor(UIColor.clear.cgColor)
            
            let path = UIBezierPath(roundedRect: CGRect(x: 0, y: -10, width: 22, height: 20), cornerRadius: 10)
            context.addPath(path.cgPath)
            context.fillPath()
        })?.stretchableImage(withLeftCapWidth: 11, topCapHeight: 12)
        
        self.blurView = BlurView(effect: nil)
        self.dimView = UIView()
        self.dimView.alpha = 0.0
        self.dimView.backgroundColor = UIColor(rgb: 0x000000, alpha: 0.6)
        self.dimView.isUserInteractionEnabled = false
        
        self.scrollView = ScrollViewImpl()
        self.scrollView.contentInsetAdjustmentBehavior = .never
        self.scrollView.alwaysBounceVertical = true
        
        super.init()
        
        self.view.addSubview(self.bottomEdgeView)
        self.view.addSubview(self.blurView)
        self.view.addSubview(self.dimView)
        self.view.addSubview(self.scrollView)
        
        self.presentationDataDisposable = (self.context.sharedContext.presentationData
        |> deliverOnMainQueue).startStrict(next: { [weak self] presentationData in
            guard let self else {
                return
            }
            self.presentationData = presentationData
        })
    }
    
    deinit {
        self.presentationDataDisposable?.dispose()
    }
    
    public override func didLoad() {
        super.didLoad()
        
        self.scrollView.delegate = self.wrappedScrollViewDelegate
        self.scrollView.alwaysBounceVertical = true
        self.scrollView.showsVerticalScrollIndicator = false
        self.scrollView.showsHorizontalScrollIndicator = false
        
        let dismissGestureRecognizer = UIPanGestureRecognizer(target: self, action: #selector(self.dismissPan(_:)))
        dismissGestureRecognizer.delegate = self.wrappedGestureRecognizerDelegate
        dismissGestureRecognizer.delaysTouchesBegan = true
        self.scrollView.addGestureRecognizer(dismissGestureRecognizer)
        self.dismissGestureRecognizer = dismissGestureRecognizer
    }
    
    func item(at y: CGFloat) -> Int? {
        guard let layout = self.validLayout else {
            return nil
        }
        
        let insets = layout.insets(options: [.statusBar])
        let itemCount = self.items.count
        let spacing = interitemSpacing(itemCount: itemCount, boundingSize: self.scrollView.bounds.size, insets: insets)
        return max(0, min(Int(floor((y - additionalInsetTop) / spacing)), itemCount - 1))
    }
    
    public override func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
        guard let panGesture = gestureRecognizer as? UIPanGestureRecognizer else {
            return false
        }
        
        let location = panGesture.location(in: gestureRecognizer.view)
        let velocity = panGesture.velocity(in: gestureRecognizer.view)
        
        if abs(velocity.x) > abs(velocity.y), let _ = self.item(at: location.y) {
            return true
        }
        return false
    }
    
    @objc func dismissPan(_ gestureRecognizer: UIPanGestureRecognizer) {
        let scrollView = self.scrollView
        
        switch gestureRecognizer.state {
        case .began:
            let location = gestureRecognizer.location(in: scrollView)
            guard let item = self.item(at: location.y) else { return }
            
            self.dismissingItemId = self.items[item].id
        case .changed:
            guard let _ = self.dismissingItemId else { return }
            
            var delta = gestureRecognizer.translation(in: scrollView)
            delta.y = 0
            
            if let offset = self.dismissingItemOffset {
                self.dismissingItemOffset = offset + delta.x
            } else {
                self.dismissingItemOffset = delta.x
            }
            
            gestureRecognizer.setTranslation(.zero, in: scrollView)
            
            self.requestUpdate(transition: .immediate)
        case .ended:
            var needsLayout = true
            if let itemId = self.dismissingItemId {
                if let offset = self.dismissingItemOffset {
                    if offset < -self.frame.width / 4.0 {
                        self.currentTransition = .dismiss(itemId: itemId)
                        
                        self.items.removeAll(where: { $0.id == itemId })
                        if self.items.count == 1 {
                            self.isExpanded = false
                            self.willMaximize?()
                            needsLayout = false
                        }
                    }
                    self.dismissingItemOffset = nil
                    self.dismissingItemId = nil
                }
            }
            if needsLayout {
                self.requestUpdate(transition: .animated(duration: 0.4, curve: .spring))
            }
        case .cancelled, .failed:
            self.dismissingItemId = nil
        default:
            break
        }
    }
    
    public override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        let result = super.hitTest(point, with: event)
        if result === self.view {
            return nil
        }
        return result
    }
    
    public func addController(_ viewController: ViewController, transition: ContainedViewLayoutTransition) {
        let item = Item(
            id: AnyHashable(Int64.random(in: Int64.min ... Int64.max)),
            controller: viewController
        )
        self.items.append(item)
        
        self.currentTransition = .minimize(itemId: item.id)
        self.requestUpdate(transition: transition)
    }
    
    private enum Transition: Equatable {
        case minimize(itemId: AnyHashable)
        case maximize(itemId: AnyHashable)
        case dismiss(itemId: AnyHashable)
        case dismissAll
        
        func matches(item: Item) -> Bool {
            switch self {
            case .minimize:
                return false
            case let .maximize(itemId), let .dismiss(itemId):
                return item.id == itemId
            case .dismissAll:
                return true
            }
        }
    }
    
    public func maximizeController(_ viewController: ViewController, animated: Bool, completion: @escaping (Bool) -> Void) {
        guard let item = self.items.first(where: { $0.controller === viewController }) else {
            completion(self.items.count == 0)
            return
        }
        if !animated {
            self.items.removeAll(where: { $0.id == item.id })
            self.itemNodes[item.id]?.removeFromSupernode()
            self.itemNodes[item.id] = nil
            completion(self.items.count == 0)
            self.scrollView.contentOffset = .zero
            return
        }
        self.isExpanded = false
        self.currentTransition = .maximize(itemId: item.id)
        self.requestUpdate(transition: .animated(duration: 0.4, curve: .spring), completion: { [weak self] _ in
            guard let self else {
                return
            }
            completion(self.items.count == 0)
            self.scrollView.contentOffset = .zero
        })
        self.items.removeAll(where: { $0.id == item.id })
    }
    
    public func dismissAll(completion: @escaping () -> Void) {
        self.currentTransition = .dismissAll
        self.requestUpdate(transition: .animated(duration: 0.4, curve: .spring), completion: { _ in
            completion()
        })
    }
        
    public func scrollViewDidScroll(_ scrollView: UIScrollView) {
        guard self.isExpanded else {
            return
        }
        self.requestUpdate(transition: .immediate)
    }
    
    private func requestUpdate(transition: ContainedViewLayoutTransition, completion: @escaping (Transition) -> Void = { _ in }) {
        guard let layout = self.validLayout else {
            return
        }
        self.updateLayout(layout, transition: transition, completion: completion)
    }
    
    public func updateLayout(_ layout: ContainerViewLayout, transition: ContainedViewLayoutTransition) {
        self.updateLayout(layout, transition: transition, completion: { _ in })
    }
    
    private func updateLayout(_ layout: ContainerViewLayout, transition: ContainedViewLayoutTransition, completion: @escaping (Transition) -> Void = { _ in }) {
        let isFirstTime = self.validLayout == nil
        var containerTransition = transition
        if isFirstTime {
            containerTransition = .immediate
        }
        
        self.validLayout = layout
        
        let bounds = CGRect(origin: .zero, size: layout.size)
        
        containerTransition.updateFrame(view: self.blurView, frame: bounds)
        containerTransition.updateFrame(view: self.dimView, frame: bounds)
        if self.isExpanded {
            if self.blurView.effect == nil {
                UIView.animate(withDuration: 0.25, animations: {
                    self.blurView.effect = UIBlurEffect(style: self.presentationData.theme.overallDarkAppearance ? .dark : .light)
                    self.dimView.alpha = 1.0
                })
            }
        } else {
            if self.blurView.effect != nil {
                UIView.animate(withDuration: 0.25, animations: {
                    self.blurView.effect = nil
                    self.dimView.alpha = 0.0
                })
            }
        }
        self.blurView.isUserInteractionEnabled = self.isExpanded
        
        let bottomEdgeHeight = 24.0 + 33.0 + layout.intrinsicInsets.bottom
        let bottomEdgeOrigin = layout.size.height - bottomEdgeHeight
        containerTransition.updateFrame(view: self.bottomEdgeView, frame: CGRect(origin: CGPoint(x: 0.0, y: layout.size.height - bottomEdgeHeight), size: CGSize(width: layout.size.width, height: bottomEdgeHeight)))
        
        if isFirstTime {
            let transition = ContainedViewLayoutTransition.animated(duration: 0.4, curve: .spring)
            transition.animatePosition(layer: self.bottomEdgeView.layer, from: self.bottomEdgeView.layer.position.offsetBy(dx: 0.0, dy: minimizedNavigationHeight + minimizedTopMargin), to: self.bottomEdgeView.layer.position)
        }
        
        let insets = layout.insets(options: [.statusBar])
        let itemInsets = UIEdgeInsets(top: insets.top, left: layout.safeInsets.left, bottom: insets.bottom, right: layout.safeInsets.right)
        var topInset = insets.top
        if layout.size.width < layout.size.height {
            topInset += 10.0
        }
        
        var index = 0
        let contentHeight = frameForIndex(index: self.items.count - 1, size: layout.size, insets: itemInsets, itemCount: self.items.count, boundingSize: layout.size).midY - 70.0
        for item in self.items {
            if let currentTransition = self.currentTransition {
                if currentTransition.matches(item: item) {
                    continue
                } else if case .dismiss = currentTransition, self.items.count == 1 {
                    continue
                }
            }

            var itemTransition = containerTransition
    
            let itemNode: ItemNode
            if let current = self.itemNodes[item.id] {
                itemNode = current
                itemNode.theme = self.presentationData.theme
            } else {
                itemTransition = .immediate
                itemNode = ItemNode(theme: self.presentationData.theme, strings: self.presentationData.strings, item: item)
                self.scrollView.addSubnode(itemNode)
                self.itemNodes[item.id] = itemNode
            }
            itemNode.closeTapped = { [weak self] in
                guard let self else {
                    return
                }
                if self.isExpanded {
                    var needsLayout = true
                    self.currentTransition = .dismiss(itemId: item.id)
                    
                    self.items.removeAll(where: { $0.id == item.id })
                    if self.items.count == 1 {
                        self.isExpanded = false
                        self.willMaximize?()
                        needsLayout = false
                    }
                    if needsLayout {
                        self.requestUpdate(transition: .animated(duration: 0.4, curve: .spring))
                    }
                } else {
                    self.navigationController?.dismissMinimizedControllers(animated: true)
                }
            }
            itemNode.tapped = { [weak self] in
                guard let self else {
                    return
                }
                if self.isExpanded {
                    self.navigationController?.maximizeViewController(item.controller, animated: true)
                } else {
                    if self.items.count == 1 {
                        self.navigationController?.maximizeViewController(item.controller, animated: true)
                    } else {
                        self.isExpanded = true
                        self.requestUpdate(transition: .animated(duration: 0.4, curve: .spring))
                    }
                }
            }
                 
            let itemFrame: CGRect
            let itemTransform: CATransform3D
        
            if index == self.items.count - 1 {
                itemNode.layer.zPosition = 10000.0
            } else {
                itemNode.layer.zPosition = 0.0
            }
            itemNode.isExpanded = self.isExpanded
            
            if self.isExpanded {
                let currentItemFrame = frameForIndex(index: index, size: layout.size, insets: itemInsets, itemCount: self.items.count, boundingSize: layout.size)
                let currentItemTransform = final3dTransform(for: currentItemFrame.minY, size: currentItemFrame.size, contentHeight: contentHeight, itemCount: self.items.count, additionalAngle: self.highlightedItemId == item.id ? 0.04 : nil, scrollBounds: self.scrollView.bounds, insets: itemInsets)
                                
                var effectiveItemFrame = currentItemFrame
                var effectiveItemTransform = currentItemTransform
                
                if let dismissingItemId = self.dismissingItemId, let deletingIndex = self.items.firstIndex(where: { $0.id == dismissingItemId }), let offset = self.dismissingItemOffset {
                    var targetItemFrame: CGRect?
                    var targetItemTransform: CATransform3D?
                    if deletingIndex == index {
                        let effectiveOffset: CGFloat
                        if offset <= 0.0 {
                            effectiveOffset = offset
                        } else {
                            effectiveOffset = scrollingRubberBandingOffset(offset: offset, bandingStart: 0.0, range: 20.0)
                        }
                        effectiveItemFrame = effectiveItemFrame.offsetBy(dx: effectiveOffset, dy: 0.0)
                    } else if index < deletingIndex {
                        let frame = frameForIndex(index: index, size: layout.size, insets: itemInsets, itemCount: self.items.count - 1, boundingSize: layout.size)
                        let spacing = interitemSpacing(itemCount: self.items.count - 1, boundingSize: layout.size, insets: itemInsets)
                        
                        targetItemFrame = frame
                        targetItemTransform = final3dTransform(for: frame.minY, size: layout.size, contentHeight: contentHeight - layout.size.height - spacing, itemCount: self.items.count - 1, scrollBounds: self.scrollView.bounds, insets: itemInsets)
                    } else {
                        let frame = frameForIndex(index: index - 1, size: layout.size, insets: itemInsets, itemCount: self.items.count - 1, boundingSize: layout.size)
                        let spacing = interitemSpacing(itemCount: self.items.count - 1, boundingSize: layout.size, insets: itemInsets)
                        
                        targetItemFrame = frame
                        targetItemTransform = final3dTransform(for: frame.minY, size: layout.size, contentHeight: contentHeight - layout.size.height - spacing, itemCount: self.items.count - 1, scrollBounds: self.scrollView.bounds, insets: itemInsets)
                    }
                    
                    if let targetItemFrame, let targetItemTransform {
                        let fraction = max(0.0, min(1.0, -1.0 * offset / (layout.size.width * 1.5)))
                        effectiveItemFrame = effectiveItemFrame.interpolate(with: targetItemFrame, fraction: fraction)
                        effectiveItemTransform = effectiveItemTransform.interpolate(with: targetItemTransform, fraction: fraction)
                    }
                }
                itemFrame = effectiveItemFrame
                itemTransform = effectiveItemTransform
                
                itemNode.isCovered = false
            } else {
                var itemOffset: CGFloat = bottomEdgeOrigin + 13.0
                var hideTransform = false
                if let currentTransition = self.currentTransition {
                    if case let .maximize(itemId) = currentTransition {
                        itemOffset += layout.size.height * 0.25
                        if let lastItemNode = self.scrollView.subviews.last?.asyncdisplaykit_node as? ItemNode, lastItemNode.item.id == itemId {
                            hideTransform = true
                        }
                    } else if case .dismiss = currentTransition, self.items.count == 1 {
                        itemOffset += layout.size.height * 0.25
                    }
                }
                
                var effectiveItemFrame = CGRect(origin: CGPoint(x: 0.0, y: itemOffset), size: layout.size)
                var effectiveItemTransform = itemNode.transform
                if hideTransform {
                    effectiveItemTransform = CATransform3DMakeScale(0.7, 0.7, 1.0)
                } else if index == self.items.count - 1 {
                    if self.items.count > 1 {
                        effectiveItemFrame = effectiveItemFrame.offsetBy(dx: 0.0, dy: 4.0)
                    }
                    effectiveItemTransform = CATransform3DIdentity
                } else {
                    let sideInset: CGFloat = 10.0
                    let scaledWidth = layout.size.width - sideInset * 2.0
                    let scale = scaledWidth / layout.size.width
                    let scaledHeight = layout.size.height * scale
                    let verticalOffset = layout.size.height - scaledHeight
                    effectiveItemFrame = effectiveItemFrame.offsetBy(dx: 0.0, dy: -verticalOffset / 2.0)
                    effectiveItemTransform = CATransform3DMakeScale(scale, scale, 1.0)
                }
                itemFrame = effectiveItemFrame
                itemTransform = effectiveItemTransform
                
                itemNode.isCovered = index == self.items.count - 2
            }
            
            itemNode.bounds = CGRect(origin: .zero, size: itemFrame.size)
            itemNode.updateLayout(size: layout.size, insets: itemInsets, transition: itemTransition)
            
            if index == self.items.count - 1 && !self.isExpanded {
                itemNode.setTitleControllers(self.items.map { $0.controller })
            } else {
                itemNode.setTitleControllers(nil)
            }
            
            itemTransition.updateTransform(node: itemNode, transform: itemTransform)
            itemTransition.updatePosition(node: itemNode, position: itemFrame.center)
            
            index += 1
        }
        
        let contentSize = CGSize(width: layout.size.width, height: contentHeight)
        if self.scrollView.contentSize != contentSize {
            self.scrollView.contentSize = contentSize
        }
        if self.scrollView.frame != bounds {
            self.scrollView.frame = bounds
        }
        self.scrollView.passthrough = !self.isExpanded
        self.scrollView.isScrollEnabled = self.isExpanded
        
        if let currentTransition = self.currentTransition {
            switch self.currentTransition {
            case let .minimize(itemId):
                guard let itemNode = self.itemNodes[itemId] else {
                    return
                }
                
                let dimView = UIView()
                dimView.alpha = 1.0
                dimView.frame = CGRect(origin: .zero, size: layout.size)
                dimView.backgroundColor = UIColor(white: 0.0, alpha: 0.25)
                self.view.insertSubview(dimView, aboveSubview: self.blurView)
                dimView.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.25, removeOnCompletion: false, completion: { _ in
                    dimView.removeFromSuperview()
                })
                
                
                itemNode.animateIn()
                
                var initialOffset = insets.top + itemNode.item.controller.minimizedTopEdgeOffset
                if layout.size.width < layout.size.height {
                    initialOffset += 10.0
                }
                if let minimizedBounds = itemNode.item.controller.minimizedBounds {
                    initialOffset += -minimizedBounds.minY
                }
                
                transition.animatePosition(node: itemNode, from: CGPoint(x: layout.size.width / 2.0, y: layout.size.height / 2.0 + initialOffset), completion: { _ in
                    if self.currentTransition == currentTransition {
                        self.currentTransition = nil
                    }
                    completion(currentTransition)
                })
            case let .maximize(itemId):
                let transition = ContainedViewLayoutTransition.animated(duration: 0.4, curve: .spring)
                guard let itemNode = self.itemNodes[itemId] else {
                    return
                }
                
                let dimView = UIView()
                dimView.frame = CGRect(origin: .zero, size: layout.size)
                dimView.backgroundColor = UIColor(white: 0.0, alpha: 0.25)
                self.view.insertSubview(dimView, aboveSubview: self.blurView)
                dimView.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.25)
                
                itemNode.animateOut()
                transition.updateTransform(node: itemNode, transform: CATransform3DIdentity)
                transition.updatePosition(node: itemNode, position: CGPoint(x: layout.size.width / 2.0, y: layout.size.height / 2.0 + topInset + self.scrollView.contentOffset.y), completion: { _ in
                    if self.currentTransition == currentTransition {
                        self.currentTransition = nil
                    }
                    completion(currentTransition)
                    self.itemNodes[itemId] = nil
                    itemNode.removeFromSupernode()
                    dimView.removeFromSuperview()
                    
                    self.requestUpdate(transition: .immediate)
                })
            case let .dismiss(itemId):
                let transition = ContainedViewLayoutTransition.animated(duration: 0.4, curve: .spring)
                guard let dismissedItemNode = self.itemNodes[itemId] else {
                    return
                }
                if self.items.count == 1 {
                    if let itemNode = self.itemNodes.first(where: { $0.0 != itemId })?.value {
                        let dimView = UIView()
                        dimView.frame = CGRect(origin: .zero, size: layout.size)
                        dimView.backgroundColor = UIColor(white: 0.0, alpha: 0.25)
                        self.view.insertSubview(dimView, aboveSubview: self.blurView)
                        dimView.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.25)
                        
                        itemNode.animateOut()
                        transition.updateTransform(node: itemNode, transform: CATransform3DIdentity)
                        transition.updatePosition(node: itemNode, position: CGPoint(x: layout.size.width / 2.0, y: layout.size.height / 2.0 + topInset + self.scrollView.contentOffset.y), completion: { _ in
                            if self.currentTransition == currentTransition {
                                self.currentTransition = nil
                            }
                            completion(currentTransition)
                            self.itemNodes[itemId] = nil
                            itemNode.removeFromSupernode()
                            dimView.removeFromSuperview()
                            
                            self.navigationController?.maximizeViewController(itemNode.item.controller, animated: false)
                            
                            self.requestUpdate(transition: .immediate)
                        })
                    }
                    transition.updatePosition(node: dismissedItemNode, position: CGPoint(x: -layout.size.width, y: dismissedItemNode.position.y))
                } else {
                    transition.updatePosition(node: dismissedItemNode, position: CGPoint(x: -layout.size.width, y: dismissedItemNode.position.y), completion: { _ in
                        if self.currentTransition == currentTransition {
                            self.currentTransition = nil
                        }
                        completion(currentTransition)
                        
                        self.itemNodes[itemId] = nil
                        dismissedItemNode.removeFromSupernode()
                    })
                }
            case .dismissAll:
                let dismissOffset = collapsedHeight(layout: layout)
                transition.updatePosition(layer: self.bottomEdgeView.layer, position: self.bottomEdgeView.layer.position.offsetBy(dx: 0.0, dy: dismissOffset), completion: { _ in
                    if self.currentTransition == currentTransition {
                        self.currentTransition = nil
                    }
                    completion(currentTransition)
                })
                transition.updatePosition(layer: self.scrollView.layer, position: self.scrollView.center.offsetBy(dx: 0.0, dy: dismissOffset))
            default:
                break
            }
        }
    }
    
    public func collapsedHeight(layout: ContainerViewLayout) -> CGFloat {
        return minimizedNavigationHeight + minimizedTopMargin + layout.intrinsicInsets.bottom
    }
}

private let maxInteritemSpacing: CGFloat = 240.0
private let additionalInsetTop: CGFloat = 16.0
private let additionalInsetBottom: CGFloat = 0.0
private let zOffset: CGFloat = -60.0

private let perspectiveCorrection: CGFloat = -1.0 / 1000.0
private let maxRotationAngle: CGFloat = -CGFloat.pi / 2.2

private func angle(for origin: CGFloat, itemCount: Int, scrollBounds: CGRect, contentHeight: CGFloat?, insets: UIEdgeInsets) -> CGFloat {
    var rotationAngle = rotationAngleAt0(itemCount: itemCount)
    
    var contentOffset = scrollBounds.origin.y
    if contentOffset < 0.0 {
        contentOffset *= 2.0
    }
    
    var yOnScreen = origin - contentOffset - additionalInsetTop - insets.top
    if yOnScreen < 0 {
        yOnScreen = 0
    } else if yOnScreen > scrollBounds.height {
        yOnScreen = scrollBounds.height
    }
    
    let maxRotationVariance = maxRotationAngle - rotationAngleAt0(itemCount: itemCount)
    rotationAngle += (maxRotationVariance / scrollBounds.height) * yOnScreen

    return rotationAngle
}

private func final3dTransform(for origin: CGFloat, size: CGSize, contentHeight: CGFloat?, itemCount: Int, forcedAngle: CGFloat? = nil, additionalAngle: CGFloat? = nil, scrollBounds: CGRect, insets: UIEdgeInsets) -> CATransform3D {
    var transform = CATransform3DIdentity
    transform.m34 = perspectiveCorrection
    
    let rotationAngle = forcedAngle ?? angle(for: origin, itemCount: itemCount, scrollBounds: scrollBounds, contentHeight: contentHeight, insets: insets)
    var effectiveRotationAngle = rotationAngle
    if let additionalAngle = additionalAngle {
        effectiveRotationAngle += additionalAngle
    }
    
    let r = size.height / 2.0 + abs(zOffset / sin(rotationAngle))
    
    let zTranslation = r * sin(rotationAngle)
    let yTranslation: CGFloat = r * (1 - cos(rotationAngle))
    
    let zTranslateTransform = CATransform3DTranslate(transform, 0.0, -yTranslation, zTranslation)
    
    let rotateTransform = CATransform3DRotate(zTranslateTransform, effectiveRotationAngle, 1.0, 0.0, 0.0)
    
    return rotateTransform
}

private func interitemSpacing(itemCount: Int, boundingSize: CGSize, insets: UIEdgeInsets) -> CGFloat {
    var interitemSpacing = maxInteritemSpacing
    if itemCount > 0 {
        interitemSpacing = (boundingSize.height - additionalInsetTop - additionalInsetBottom  - insets.top) / CGFloat(min(itemCount, 5))
    }
    return interitemSpacing
}

private func frameForIndex(index: Int, size: CGSize, insets: UIEdgeInsets, itemCount: Int, boundingSize: CGSize) -> CGRect {
    let spacing = interitemSpacing(itemCount: itemCount, boundingSize: boundingSize, insets: insets)
    let y = additionalInsetTop + insets.top + spacing * CGFloat(index)
    let origin = CGPoint(x: insets.left, y: y)
    
    return CGRect(origin: origin, size: CGSize(width: size.width - insets.left - insets.right, height: size.height))
}

private func rotationAngleAt0(itemCount: Int) -> CGFloat {
    let multiplier: CGFloat = min(CGFloat(itemCount), 5.0) - 1.0
    return -CGFloat.pi / 7.0 - CGFloat.pi / 7.0 * multiplier / 4.0
}

private class BlurView: UIVisualEffectView {
    private func setup() {
        for subview in self.subviews {
            if subview.description.contains("VisualEffectSubview") {
                subview.isHidden = true
            }
        }
        
        if let sublayer = self.layer.sublayers?[0], let filters = sublayer.filters {
            sublayer.backgroundColor = nil
            sublayer.isOpaque = false
            let allowedKeys: [String] = [
                "gaussianBlur",
                "colorSaturate"
            ]
            sublayer.filters = filters.filter { filter in
                guard let filter = filter as? NSObject else {
                    return true
                }
                let filterName = String(describing: filter)
                if !allowedKeys.contains(filterName) {
                    return false
                }
                return true
            }
        }
    }
    
    override var effect: UIVisualEffect? {
        get {
            return super.effect
        }
        set {
            super.effect = newValue
            self.setup()
        }
    }
    
    override func didAddSubview(_ subview: UIView) {
        super.didAddSubview(subview)
        self.setup()
    }
}

private let shadowImage: UIImage? = {
    return generateImage(CGSize(width: 1.0, height: 480.0), rotatedContext: { size, context in
        let bounds = CGRect(origin: CGPoint(), size: size)
        context.clear(bounds)
        
        let gradientColors = [UIColor.black.withAlphaComponent(0.0).cgColor, UIColor.black.withAlphaComponent(0.55).cgColor, UIColor.black.withAlphaComponent(0.55).cgColor] as CFArray
        
        var locations: [CGFloat] = [0.0, 0.65, 1.0]
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let gradient = CGGradient(colorsSpace: colorSpace, colors: gradientColors, locations: &locations)!
        context.drawLinearGradient(gradient, start: CGPoint(x: 0.0, y: 0.0), end: CGPoint(x: 0.0, y: bounds.height), options: [])
    })
}()
