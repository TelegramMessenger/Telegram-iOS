import Foundation
import UIKit
import Display
import AsyncDisplayKit
import SwiftSignalKit
import TelegramPresentationData
import ComponentFlow
import AccountContext
import UIKitRuntimeUtils

private let minimizedNavigationHeight: CGFloat = 44.0
private let minimizedTopMargin: CGFloat = 3.0
private let maximizeLastStandingController = false

final class ScrollViewImpl: UIScrollView {
    var shouldPassthrough: () -> Bool = { return false }
    
    override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        let result = super.hitTest(point, with: event)
        if result === self && self.shouldPassthrough() {
            return nil
        }
        return result
    }
}

public class MinimizedContainerImpl: ASDisplayNode, MinimizedContainer, ASScrollViewDelegate, ASGestureRecognizerDelegate {
    final class Item {
        let id: AnyHashable
        let controller: MinimizableController
        let beforeMaximize: (NavigationController, @escaping () -> Void) -> Void
        let topEdgeOffset: CGFloat?
        
        init(
            id: AnyHashable,
            controller: MinimizableController,
            beforeMaximize: @escaping (NavigationController, @escaping () -> Void) -> Void,
            topEdgeOffset: CGFloat?
        ) {
            self.id = id
            self.controller = controller
            self.beforeMaximize = beforeMaximize
            self.topEdgeOffset = topEdgeOffset
        }
    }
    
    final class SnapshotContainerView: UIView {
        override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
            self.removeFromSuperview()
            return nil
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
        
        var isReady = false
        
        let item: Item
        private let containerNode: ASDisplayNode
        private let headerNode: MinimizedHeaderNode
        private let dimCoverNode: ASDisplayNode
        private let shadowNode: ASImageNode
        
        private var controllerView: UIView?
        fileprivate let snapshotContainerView = SnapshotContainerView()
        fileprivate var snapshotView: UIView?
        fileprivate var blurredSnapshotView: UIView?
        
        var tapped: (() -> Void)?
        var highlighted: ((Bool) -> Void)?
        var closeTapped: (() -> Void)?
        
        var isCovered: Bool = false {
            didSet {
                let transition: ContainedViewLayoutTransition = .animated(duration: 0.25, curve: .easeInOut)
                transition.updateAlpha(node: self.dimCoverNode, alpha: self.isCovered ? 0.25 : 0.0)
            }
        }
        
        private var validLayout: (CGSize, UIEdgeInsets, Bool)?
        
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
            
            self.snapshotContainerView.isUserInteractionEnabled = false
            
            super.init()

            self.clipsToBounds = true
            self.cornerRadius = 10.0
            applySmoothRoundedCorners(self.layer)
            applySmoothRoundedCorners(self.containerNode.layer)
            
            self.shadowNode.image = shadowImage
                        
            self.addSubnode(self.containerNode)
            self.controllerView = self.item.controller.displayNode.view
            self.containerNode.view.addSubview(self.item.controller.displayNode.view)
            
            Queue.mainQueue().after(0.45) {
                self.isReady = true
                if !self.isDismissed, let snapshotView = self.item.controller.makeContentSnapshotView() {
                    self.containerNode.view.addSubview(self.snapshotContainerView)
                    self.snapshotView = snapshotView
                    self.controllerView?.removeFromSuperview()
                    self.controllerView = nil
                    self.snapshotContainerView.addSubview(snapshotView)
                    self.requestLayout(transition: .immediate)
                }
            }
            
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
        
        func setTitleControllers(_ controllers: [MinimizableController]?) {
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
            guard let (_, insets, _) = self.validLayout, self.isReady else {
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
        
        private func requestLayout(transition: ContainedViewLayoutTransition) {
            guard let (size, insets, isExpanded) = self.validLayout else {
                return
            }
            self.updateLayout(size: size, insets: insets, isExpanded: isExpanded, transition: transition)
        }
        
        func updateLayout(size: CGSize, insets: UIEdgeInsets, isExpanded: Bool, transition: ContainedViewLayoutTransition) {
            self.validLayout = (size, insets, isExpanded)
            
            var topInset = insets.top
            if size.width < size.height {
                topInset += 10.0
            }
            self.containerNode.frame = CGRect(origin: .zero, size: size)
            if let _ = self.item.controller.minimizedTopEdgeOffset {
                self.containerNode.subnodeTransform = CATransform3DMakeTranslation(0.0, -topInset, 0.0)
            }
            
            self.snapshotContainerView.frame = CGRect(origin: .zero, size: size)
            
            self.shadowNode.frame = CGRect(origin: .zero, size: CGSize(width: size.width, height: size.height - topInset))
            
            var navigationHeight: CGFloat = minimizedNavigationHeight
            if !isExpanded {
                navigationHeight += insets.bottom
            }
            
            let headerFrame = CGRect(origin: .zero, size: CGSize(width: size.width, height: navigationHeight))
            self.headerNode.update(size: size, insets: insets, isExpanded: isExpanded, transition: transition)
            transition.updateFrame(node: self.headerNode, frame: headerFrame)
            transition.updateFrame(node: self.dimCoverNode, frame: CGRect(origin: .zero, size: size))
            
            if let snapshotView = self.snapshotView {
                var snapshotFrame = CGRect(origin: CGPoint(x: floorToScreenPixels((size.width - snapshotView.bounds.size.width) / 2.0), y: 0.0), size: snapshotView.bounds.size)
                if self.item.controller.minimizedTopEdgeOffset == nil && isExpanded {
                    snapshotFrame = snapshotFrame.offsetBy(dx: 0.0, dy: -12.0)
                }
                    
                var requiresBlur = false
                var blurFrame = snapshotFrame
                if snapshotView.frame.width * 1.1 < size.width {
                    if let _ = self.item.controller.minimizedTopEdgeOffset {
                        snapshotFrame = snapshotFrame.offsetBy(dx: 0.0, dy: -66.0)
                    }
                    blurFrame = CGRect(origin: CGPoint(x: 0.0, y: snapshotFrame.minY), size: CGSize(width: size.width, height: snapshotFrame.height))
                    requiresBlur = true
                } else if snapshotView.frame.width > size.width * 1.5 {
                    if let _ = self.item.controller.minimizedTopEdgeOffset {
                        snapshotFrame = snapshotFrame.offsetBy(dx: 0.0, dy: 66.0)
                    }
                    blurFrame = CGRect(origin: CGPoint(x: floorToScreenPixels((size.width - snapshotView.frame.width) / 2.0), y: snapshotFrame.minY), size: CGSize(width: snapshotFrame.width, height: size.height))
                    requiresBlur = true
                }
                
                if requiresBlur {
                    let blurredSnapshotView: UIView?
                    if let current = self.blurredSnapshotView {
                        blurredSnapshotView = current
                    } else {
                        blurredSnapshotView = snapshotView.snapshotView(afterScreenUpdates: false)
                        if let blurredSnapshotView {
                            if let blurFilter = makeBlurFilter() {
                                blurFilter.setValue(20.0 as NSNumber, forKey: "inputRadius")
                                blurFilter.setValue(true as NSNumber, forKey: "inputNormalizeEdges")
                                blurredSnapshotView.layer.filters = [blurFilter]
                            }
                            self.snapshotContainerView.insertSubview(blurredSnapshotView, at: 0)
                            self.blurredSnapshotView = blurredSnapshotView
                        }
                    }
                    blurredSnapshotView?.frame = blurFrame
                } else if let blurredSnapshotView = self.blurredSnapshotView {
                    self.blurredSnapshotView = nil
                    blurredSnapshotView.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.2, removeOnCompletion: false, completion: { _ in
                        blurredSnapshotView.removeFromSuperview()
                    })
                }
                transition.updateFrame(view: snapshotView, frame: snapshotFrame)
            }
            
            if !self.isDismissed {
                transition.updateAlpha(node: self.shadowNode, alpha: isExpanded ? 1.0 : 0.0)
            }
        }
    }
    
    private let sharedContext: SharedAccountContext
    public weak var navigationController: NavigationController?
    private var items: [Item] = []
    
    private var presentationData: PresentationData
    private var presentationDataDisposable: Disposable?
    
    public private(set) var isExpanded: Bool = false
    public var willMaximize: ((MinimizedContainer) -> Void)?
    public var willDismiss: ((MinimizedContainer) -> Void)?
    public var didDismiss: ((MinimizedContainer) -> Void)?
    
    public private(set) var statusBarStyle: StatusBarStyle = .White
    public var statusBarStyleUpdated: (() -> Void)?
    
    private let bottomEdgeView: UIImageView
    private let blurView: BlurView
    private let dimView: UIView
    private let scrollView: ScrollViewImpl
    private var itemNodes: [AnyHashable: ItemNode] = [:]
    
    private var highlightedItemId: AnyHashable?
    
    private var dismissingItemId: AnyHashable?
    private var dismissingItemOffset: CGFloat?
        
    private var expandedTapGestureRecoginzer: UITapGestureRecognizer?
    
    private var currentTransition: Transition?
    private var isApplyingTransition = false
    private var validLayout: ContainerViewLayout?
    
    public var controllers: [MinimizableController] {
        return self.items.map { $0.controller }
    }
    
    public init(sharedContext: SharedAccountContext) {
        self.sharedContext = sharedContext
        self.presentationData = sharedContext.currentPresentationData.with { $0 }
        
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
        
        self.presentationDataDisposable = (self.sharedContext.presentationData
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
        self.scrollView.shouldPassthrough = { [weak self] in
            guard let self else {
                return true
            }
            return !self.isExpanded
        }
        
        let panGestureRecognizer = UIPanGestureRecognizer(target: self, action: #selector(self.panGesture(_:)))
        panGestureRecognizer.delegate = self.wrappedGestureRecognizerDelegate
        panGestureRecognizer.delaysTouchesBegan = true
        self.scrollView.addGestureRecognizer(panGestureRecognizer)
        
        let expandedTapGestureRecoginzer = UITapGestureRecognizer(target: self, action: #selector(self.tapGesture(_:)))
        expandedTapGestureRecoginzer.isEnabled = false
        self.expandedTapGestureRecoginzer = expandedTapGestureRecoginzer
        self.scrollView.addGestureRecognizer(expandedTapGestureRecoginzer)
    }
    
    func item(at y: CGFloat) -> Int? {
        guard let layout = self.validLayout else {
            return nil
        }
        
        let insets = layout.insets(options: [.statusBar])
        let itemCount = self.items.count
        let spacing = interitemSpacing(itemCount: itemCount, boundingSize: self.scrollView.bounds.size, insets: insets)
        return max(0, min(Int(floor((y - additionalInsetTop - insets.top) / spacing)), itemCount - 1))
    }
    
    public override func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
        guard let panGesture = gestureRecognizer as? UIPanGestureRecognizer else {
            return false
        }
        
        let location = panGesture.location(in: gestureRecognizer.view)
        let velocity = panGesture.velocity(in: gestureRecognizer.view)
        
        if let _ = self.item(at: location.y) {
            if self.isExpanded {
                return abs(velocity.x) > abs(velocity.y)
            } else {
                return abs(velocity.y) > abs(velocity.x)
            }
        }
        return false
    }
    
    @objc func tapGesture(_ gestureRecognizer: UITapGestureRecognizer) {
        guard self.isExpanded else {
            return
        }
        if let result = self.scrollView.hitTest(gestureRecognizer.location(in: self.scrollView), with: nil), result === self.scrollView {
            self.collapse()
        }
    }
    
    @objc func panGesture(_ gestureRecognizer: UIPanGestureRecognizer) {
        if self.isExpanded {
            self.dismissPanGesture(gestureRecognizer)
        } else {
            self.expandPanGesture(gestureRecognizer)
        }
    }
    
    @objc func expandPanGesture(_ gestureRecognizer: UIPanGestureRecognizer) {
        guard let lastItem = self.items.last, let itemNode = self.itemNodes[lastItem.id], itemNode.isReady else {
            return
        }
        let translation = gestureRecognizer.translation(in: self.view)
        if translation.y < -10.0 {
            gestureRecognizer.isEnabled = false
            gestureRecognizer.isEnabled = true
            
            self.expand()
        }
    }
    
    @objc func dismissPanGesture(_ gestureRecognizer: UIPanGestureRecognizer) {
        let scrollView = self.scrollView
        
        switch gestureRecognizer.state {
        case .began:
            let location = gestureRecognizer.location(in: scrollView)
            guard let item = self.item(at: location.y) else { return }
            
            self.dismissingItemId = self.items[item].id
        case .changed:
            guard let _ = self.dismissingItemId else { return }
            
            var translation = gestureRecognizer.translation(in: scrollView)
            translation.y = 0
            
            if let offset = self.dismissingItemOffset {
                self.dismissingItemOffset = offset + translation.x
            } else {
                self.dismissingItemOffset = translation.x
            }
            
            gestureRecognizer.setTranslation(.zero, in: scrollView)
            
            self.requestUpdate(transition: .immediate)
        case .ended:
            var needsLayout = true
            if let itemId = self.dismissingItemId {
                if let offset = self.dismissingItemOffset {
                    let velocity = gestureRecognizer.velocity(in: self.view)
                    if offset < -self.frame.width / 3.0 || velocity.x < -300.0 {
                        let proceed = {
                            self.currentTransition = .dismiss(itemId: itemId)
                            
                            self.items.removeAll(where: { $0.id == itemId })
                            if self.items.count == 1, maximizeLastStandingController {
                                self.isExpanded = false
                                self.willMaximize?(self)
                                needsLayout = false
                            } else if self.items.count == 0 {
                                self.willDismiss?(self)
                                self.isExpanded = false
                            }
                        }
                        if let item = self.items.first(where: { $0.id == itemId }), !item.controller.shouldDismissImmediately() {
                            self.displayDismissConfirmation(completion: { commit in
                                self.dismissingItemOffset = nil
                                self.dismissingItemId = nil
                                if commit {
                                    proceed()
                                } else {
                                    self.requestUpdate(transition: .animated(duration: 0.4, curve: .spring))
                                }
                            })
                        } else {
                            proceed()
                            self.dismissingItemOffset = nil
                            self.dismissingItemId = nil
                        }
                    } else {
                        self.dismissingItemOffset = nil
                        self.dismissingItemId = nil
                    }
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
    
    public func addController(_ viewController: MinimizableController, topEdgeOffset: CGFloat?, beforeMaximize: @escaping (NavigationController, @escaping () -> Void) -> Void, transition: ContainedViewLayoutTransition) {
        let item = Item(
            id: AnyHashable(Int64.random(in: Int64.min ... Int64.max)),
            controller: viewController,
            beforeMaximize: beforeMaximize,
            topEdgeOffset: topEdgeOffset
        )
        self.items.append(item)
        
        self.currentTransition = .minimize(itemId: item.id)
        self.requestUpdate(transition: transition)
    }
    
    public func removeController(_ viewController: MinimizableController) {
        guard let item = self.items.first(where: { $0.controller === viewController }) else {
            return
        }
        
        self.items.removeAll(where: { $0.id == item.id })
        self.requestUpdate(transition: .animated(duration: 0.25, curve: .easeInOut))
    }
    
    private enum Transition: Equatable {
        case minimize(itemId: AnyHashable)
        case maximize(itemId: AnyHashable)
        case dismiss(itemId: AnyHashable)
        case dismissAll
        case collapse
        
        func matches(item: Item) -> Bool {
            switch self {
            case .minimize:
                return false
            case let .maximize(itemId), let .dismiss(itemId):
                return item.id == itemId
            case .dismissAll:
                return true
            case .collapse:
                return false
            }
        }
    }
    
    public func maximizeController(_ viewController: MinimizableController, animated: Bool, completion: @escaping (Bool) -> Void) {
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
    
    public func expand() {
        guard !self.items.isEmpty && !self.isExpanded && self.currentTransition == nil else {
            return
        }
        
        if self.items.count == 1, let item = self.items.first {
            if let navigationController = self.navigationController {
                item.beforeMaximize(navigationController, { [weak self] in
                    self?.navigationController?.maximizeViewController(item.controller, animated: true)
                })
            }
        } else {
            let contentOffset = max(0.0, self.scrollView.contentSize.height - self.scrollView.bounds.height)
            self.scrollView.contentOffset = CGPoint(x: 0.0, y: contentOffset)
            for itemNode in self.itemNodes.values {
                itemNode.frame = itemNode.frame.offsetBy(dx: 0.0, dy: contentOffset)
            }
            
            self.isExpanded = true
            self.requestUpdate(transition: .animated(duration: 0.4, curve: .spring))
        }
    }
    
    public func collapse() {
        self.isExpanded = false
        self.currentTransition = .collapse
        self.requestUpdate(transition: .animated(duration: 0.4, curve: .spring))
    }
        
    public func scrollViewDidScroll(_ scrollView: UIScrollView) {
        guard self.isExpanded, let layout = self.validLayout else {
            return
        }
        self.requestUpdate(transition: .immediate)
        
        let contentOffset = scrollView.contentOffset
        if scrollView.contentOffset.y < -64.0, let lastItemId = self.items.last?.id, let itemNode = self.itemNodes[lastItemId] {
            let velocity = scrollView.panGestureRecognizer.velocity(in: self.view).y
            let distance = layout.size.height - self.collapsedHeight(layout: layout) - itemNode.frame.minY
            let initialVelocity = min(8.0, distance != 0.0 ? abs(velocity / distance) : 0.0)
            
            self.isExpanded = false
            scrollView.isScrollEnabled = false
            scrollView.panGestureRecognizer.isEnabled = false
            scrollView.panGestureRecognizer.isEnabled = true
            scrollView.setContentOffset(contentOffset, animated: false)
            self.currentTransition = .collapse
            self.requestUpdate(transition: .animated(duration: 0.4, curve: .customSpring(damping: 180.0, initialVelocity: initialVelocity)))
        }
    }
    
    private func displayDismissConfirmation(completion: @escaping (Bool) -> Void) {
        let actionSheet = ActionSheetController(presentationData: self.presentationData)
        actionSheet.setItemGroups([
            ActionSheetItemGroup(items: [
                ActionSheetTextItem(title: self.presentationData.strings.WebApp_CloseConfirmation),
                ActionSheetButtonItem(title: self.presentationData.strings.WebApp_CloseAnyway, color: .destructive, action: { [weak actionSheet] in
                    actionSheet?.dismissAnimated()
                    completion(true)
                })
            ]),
            ActionSheetItemGroup(items: [
                ActionSheetButtonItem(title: self.presentationData.strings.Common_Cancel, color: .accent, font: .bold, action: { [weak actionSheet] in
                    actionSheet?.dismissAnimated()
                    completion(false)
                })
            ])
        ])
        actionSheet.dismissed = { cancelled in
            guard cancelled else {
                return
            }
            completion(false)
        }
        self.navigationController?.presentOverlay(controller: actionSheet, inGlobal: false, blockInteraction: false)
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
        
        if self.isApplyingTransition {
            return
        }
        
        let insets = layout.insets(options: [.statusBar])
        let itemInsets = UIEdgeInsets(top: insets.top, left: layout.safeInsets.left, bottom: insets.bottom, right: layout.safeInsets.right)
        var topInset = insets.top
        if layout.size.width < layout.size.height {
            topInset += 10.0
        }
        
        var index = 0
        let contentHeight = frameForIndex(index: self.items.count - 1, size: layout.size, insets: itemInsets, itemCount: self.items.count, boundingSize: layout.size).midY - 70.0
        
        var effectiveScrollBounds = self.scrollView.bounds
        effectiveScrollBounds.origin.y = max(0.0, min(contentHeight - self.scrollView.bounds.height, effectiveScrollBounds.origin.y))
        
        for item in self.items {
            if let currentTransition = self.currentTransition {
                if currentTransition.matches(item: item) {
                    continue
                } else if case .dismiss = currentTransition, self.items.count == 1 && maximizeLastStandingController {
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
            itemNode.closeTapped = { [weak self, weak itemNode] in
                guard let self else {
                    return
                }
                if self.isExpanded {
                    let proceed = { [weak self] in
                        guard let self else {
                            return
                        }
                        var needsLayout = true
                        self.currentTransition = .dismiss(itemId: item.id)
                        
                        self.items.removeAll(where: { $0.id == item.id })
                        if self.items.count == 1, maximizeLastStandingController {
                            self.isExpanded = false
                            self.willMaximize?(self)
                            needsLayout = false
                        } else if self.items.count == 0 {
                            self.isExpanded = false
                            self.willDismiss?(self)
                        }
                        if needsLayout {
                            self.requestUpdate(transition: .animated(duration: 0.4, curve: .spring))
                        }
                    }
                    if let item = itemNode?.item, !item.controller.shouldDismissImmediately() {
                        self.displayDismissConfirmation(completion: { commit in
                            if commit {
                                proceed()
                            }
                        })
                    } else {
                        proceed()
                    }
                } else {
                    if self.items.count > 1 {
                        let actionSheet = ActionSheetController(presentationData: self.presentationData)
                        actionSheet.setItemGroups([
                            ActionSheetItemGroup(items: [
                                ActionSheetTextItem(title: self.presentationData.strings.WebApp_Minimized_CloseAllTitle),
                                ActionSheetButtonItem(title: self.presentationData.strings.WebApp_Minimized_CloseAll(Int32(self.items.count)), color: .destructive, action: { [weak self, weak actionSheet] in
                                    actionSheet?.dismissAnimated()
                                    
                                    self?.navigationController?.dismissMinimizedControllers(animated: true)
                                })
                            ]),
                            ActionSheetItemGroup(items: [
                                ActionSheetButtonItem(title: self.presentationData.strings.Common_Cancel, color: .accent, font: .bold, action: { [weak actionSheet] in
                                    actionSheet?.dismissAnimated()
                                })
                            ])
                        ])
                        self.navigationController?.presentOverlay(controller: actionSheet, inGlobal: false, blockInteraction: false)
                    } else if let item = self.items.first {
                        if !item.controller.shouldDismissImmediately() {
                            self.displayDismissConfirmation(completion: { [weak self] commit in
                                if commit {
                                    self?.navigationController?.dismissMinimizedControllers(animated: true)
                                }
                            })
                        } else {
                            self.navigationController?.dismissMinimizedControllers(animated: true)
                        }
                    }
                }
            }
            itemNode.tapped = { [weak self, weak itemNode] in
                guard let self else {
                    return
                }
                if self.isExpanded, let itemNode {
                    if let navigationController = self.navigationController {
                        itemNode.item.beforeMaximize(navigationController, { [weak self, weak itemNode] in
                            if let item = itemNode?.item {
                                self?.navigationController?.maximizeViewController(item.controller, animated: true)
                            }
                        })
                    }
                } else {
                    self.expand()
                }
            }
                 
            let itemFrame: CGRect
            let itemTransform: CATransform3D
        
            if index == self.items.count - 1 {
                itemNode.layer.zPosition = 10000.0
            } else {
                itemNode.layer.zPosition = 0.0
            }
            
            if self.isExpanded {
                let currentItemFrame = frameForIndex(index: index, size: layout.size, insets: itemInsets, itemCount: self.items.count, boundingSize: layout.size)
                let currentItemTransform = final3dTransform(for: currentItemFrame.minY, size: currentItemFrame.size, contentHeight: contentHeight, itemCount: self.items.count, additionalAngle: self.highlightedItemId == item.id ? 0.04 : nil, scrollBounds: effectiveScrollBounds, insets: itemInsets)
                                
                var effectiveItemFrame = currentItemFrame
                let effectiveItemTransform = currentItemTransform
                
                if let dismissingItemId = self.dismissingItemId, let deletingIndex = self.items.firstIndex(where: { $0.id == dismissingItemId }), let offset = self.dismissingItemOffset {
//                    var targetItemFrame: CGRect?
//                    var targetItemTransform: CATransform3D?
                    if deletingIndex == index {
                        let effectiveOffset: CGFloat
                        if offset <= 0.0 {
                            effectiveOffset = offset
                        } else {
                            effectiveOffset = scrollingRubberBandingOffset(offset: offset, bandingStart: 0.0, range: 20.0)
                        }
                        effectiveItemFrame = effectiveItemFrame.offsetBy(dx: effectiveOffset, dy: 0.0)
                    } 
//                    else if index < deletingIndex {
//                        let frame = frameForIndex(index: index, size: layout.size, insets: itemInsets, itemCount: self.items.count - 1, boundingSize: layout.size)
//                        let spacing = interitemSpacing(itemCount: self.items.count - 1, boundingSize: layout.size, insets: itemInsets)
//                        
//                        targetItemFrame = frame
//                        targetItemTransform = final3dTransform(for: frame.minY, size: layout.size, contentHeight: contentHeight - layout.size.height - spacing, itemCount: self.items.count - 1, scrollBounds: self.scrollView.bounds, insets: itemInsets)
//                    } else {
//                        let frame = frameForIndex(index: index - 1, size: layout.size, insets: itemInsets, itemCount: self.items.count - 1, boundingSize: layout.size)
//                        let spacing = interitemSpacing(itemCount: self.items.count - 1, boundingSize: layout.size, insets: itemInsets)
//                        
//                        targetItemFrame = frame
//                        targetItemTransform = final3dTransform(for: frame.minY, size: layout.size, contentHeight: contentHeight - layout.size.height - spacing, itemCount: self.items.count - 1, scrollBounds: self.scrollView.bounds, insets: itemInsets)
//                    }
                    
//                    if let targetItemFrame, let targetItemTransform {
//                        let fraction = max(0.0, min(1.0, -1.0 * offset / (layout.size.width * 1.5)))
//                        effectiveItemFrame = effectiveItemFrame.interpolate(with: targetItemFrame, fraction: fraction)
//                        effectiveItemTransform = effectiveItemTransform.interpolate(with: targetItemTransform, fraction: fraction)
//                    }
                }
                itemFrame = effectiveItemFrame
                itemTransform = effectiveItemTransform
                
                itemNode.isCovered = false
            } else {
                var itemOffset: CGFloat = bottomEdgeOrigin + 13.0
                var hideTransform = false
                if let currentTransition = self.currentTransition {
                    if case let .maximize(itemId) = currentTransition {
                        itemOffset += self.scrollView.bounds.origin.y
                        
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
                
                itemNode.isCovered = index <= self.items.count - 2
            }
            
            itemNode.bounds = CGRect(origin: .zero, size: itemFrame.size)
            itemNode.updateLayout(size: itemFrame.size, insets: itemInsets, isExpanded: self.isExpanded, transition: itemTransition)
            
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
            var contentSizeDelta: CGFloat?
            if contentSize.height < self.scrollView.contentSize.height, transition.isAnimated {
                let currentContentOffset = self.scrollView.contentOffset.y
                let updatedContentOffset = max(0.0, contentSize.height - self.scrollView.bounds.height)
                contentSizeDelta = currentContentOffset - updatedContentOffset
            }
            self.scrollView.contentSize = contentSize
            if let contentSizeDelta {
                transition.animateBounds(layer: self.scrollView.layer, from: CGRect(origin: CGPoint(x: 0.0, y: self.scrollView.contentOffset.y + contentSizeDelta), size: self.scrollView.bounds.size))
            }
        }
        if self.scrollView.frame != bounds {
            self.scrollView.frame = bounds
        }
        self.scrollView.isScrollEnabled = self.isExpanded
        self.expandedTapGestureRecoginzer?.isEnabled = self.isExpanded
        
        var resolvedStatusBarStyle: StatusBarStyle = .Ignore
        if self.isExpanded {
            if self.scrollView.contentOffset.y > additionalInsetTop + insets.top / 2.0 {
                resolvedStatusBarStyle = .Hide
            } else {
                resolvedStatusBarStyle = .White
            }
        }
        if self.statusBarStyle != resolvedStatusBarStyle {
            self.statusBarStyle = resolvedStatusBarStyle
            Queue.mainQueue().justDispatch {
                self.statusBarStyleUpdated?()
            }
        }
        
        if let currentTransition = self.currentTransition {
            self.isApplyingTransition = true
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
                
                var initialOffset = insets.top
                if let topEdgeOffset = itemNode.item.topEdgeOffset {
                    initialOffset += topEdgeOffset
                    dimView.removeFromSuperview()
                } else {
                    if let minimizedTopEdgeOffset = itemNode.item.controller.minimizedTopEdgeOffset {
                        initialOffset += minimizedTopEdgeOffset
                    }
                    if layout.size.width < layout.size.height {
                        initialOffset += 10.0
                    }
                    if let minimizedBounds = itemNode.item.controller.minimizedBounds {
                        initialOffset += -minimizedBounds.minY
                    }
                }
                
                transition.animatePosition(node: itemNode, from: CGPoint(x: layout.size.width / 2.0, y: layout.size.height / 2.0 + initialOffset), completion: { _ in
                    self.isApplyingTransition = false
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
                if itemInsets.left > 0.0 {
                    itemNode.updateLayout(size: layout.size, insets: itemInsets, isExpanded: true, transition: transition)
                    transition.updateBounds(node: itemNode, bounds: CGRect(origin: .zero, size: layout.size))
                }
                transition.updateTransform(node: itemNode, transform: CATransform3DIdentity)
                
                if let _ = itemNode.snapshotView {
                    if itemNode.item.controller.isFullscreen {
                        if layout.size.width < layout.size.height {
                            let snapshotFrame = itemNode.snapshotContainerView.frame.offsetBy(dx: 0.0, dy: (layout.statusBarHeight ?? 0.0) + 10.0)
                            transition.updateFrame(view: itemNode.snapshotContainerView, frame: snapshotFrame)
                        }
                    } else if itemNode.item.controller.minimizedTopEdgeOffset == nil, let snapshotView = itemNode.snapshotView, snapshotView.frame.origin.y == -12.0 {
                        let snapshotFrame = snapshotView.frame.offsetBy(dx: 0.0, dy: 12.0)
                        transition.updateFrame(view: snapshotView, frame: snapshotFrame)
                    }
                }
                
                var maximizeTopInset = 0.0
                if !itemNode.item.controller.isFullscreen {
                    maximizeTopInset = topInset
                }
                
                transition.updatePosition(node: itemNode, position: CGPoint(x: layout.size.width / 2.0, y: layout.size.height / 2.0 + maximizeTopInset + self.scrollView.contentOffset.y), completion: { _ in
                    self.isApplyingTransition = false
                    if self.currentTransition == currentTransition {
                        self.currentTransition = nil
                    }
                                        
                    completion(currentTransition)
                    
                    if let _ = itemNode.snapshotView {
                        let snapshotContainerView = itemNode.snapshotContainerView
                        snapshotContainerView.isUserInteractionEnabled = true
                        snapshotContainerView.layer.allowsGroupOpacity = true
                        snapshotContainerView.center = CGPoint(x: itemNode.item.controller.displayNode.view.bounds.width / 2.0, y: snapshotContainerView.bounds.height / 2.0)
                        itemNode.item.controller.displayNode.view.addSubview(snapshotContainerView)
                        Queue.mainQueue().after(0.35, {
                            snapshotContainerView.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.25, removeOnCompletion: false, completion: { _ in
                                snapshotContainerView.removeFromSuperview()
                            })
                        })
                    }
                    
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
                if self.items.count == 1, maximizeLastStandingController {
                    if let itemNode = self.itemNodes.first(where: { $0.0 != itemId })?.value, let navigationController = self.navigationController {
                        itemNode.item.beforeMaximize(navigationController, { [weak self] in
                            guard let self else {
                                return
                            }
                            let dimView = UIView()
                            dimView.frame = CGRect(origin: .zero, size: layout.size)
                            dimView.backgroundColor = UIColor(white: 0.0, alpha: 0.25)
                            self.view.insertSubview(dimView, aboveSubview: self.blurView)
                            dimView.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.25)
                            
                            itemNode.animateOut()
                            transition.updateTransform(node: itemNode, transform: CATransform3DIdentity)
                            
                            if let _ = itemNode.snapshotView {
                                if itemNode.item.controller.minimizedTopEdgeOffset == nil, let snapshotView = itemNode.snapshotView, snapshotView.frame.origin.y == -12.0 {
                                    let snapshotFrame = snapshotView.frame.offsetBy(dx: 0.0, dy: 12.0)
                                    transition.updateFrame(view: snapshotView, frame: snapshotFrame)
                                }
                            }
                            
                            transition.updatePosition(node: itemNode, position: CGPoint(x: layout.size.width / 2.0, y: layout.size.height / 2.0 + topInset + self.scrollView.contentOffset.y), completion: { _ in
                                self.isApplyingTransition = false
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
                        })
                    }
                    transition.updatePosition(node: dismissedItemNode, position: CGPoint(x: -layout.size.width, y: dismissedItemNode.position.y))
                } else {
                    let isLast = self.items.isEmpty
                    transition.updatePosition(node: dismissedItemNode, position: CGPoint(x: -layout.size.width, y: dismissedItemNode.position.y), completion: { _ in
                        self.isApplyingTransition = false
                        if self.currentTransition == currentTransition {
                            self.currentTransition = nil
                        }
                        completion(currentTransition)
                        
                        self.itemNodes[itemId] = nil
                        dismissedItemNode.removeFromSupernode()
                        
                        if isLast {
                            self.didDismiss?(self)
                        }
                    })
                    if isLast {
                        let dismissOffset = collapsedHeight(layout: layout)
                        transition.updatePosition(layer: self.bottomEdgeView.layer, position: self.bottomEdgeView.layer.position.offsetBy(dx: 0.0, dy: dismissOffset))
                    }
                }
            case .dismissAll:
                let dismissOffset = collapsedHeight(layout: layout)
                transition.updatePosition(layer: self.bottomEdgeView.layer, position: self.bottomEdgeView.layer.position.offsetBy(dx: 0.0, dy: dismissOffset), completion: { _ in
                    self.isApplyingTransition = false
                    if self.currentTransition == currentTransition {
                        self.currentTransition = nil
                    }
                    completion(currentTransition)
                })
                transition.updatePosition(layer: self.scrollView.layer, position: self.scrollView.center.offsetBy(dx: 0.0, dy: dismissOffset))
            case .collapse:
                transition.updateBounds(layer: self.scrollView.layer, bounds: CGRect(origin: .zero, size: self.scrollView.bounds.size), completion: { _ in
                    self.isApplyingTransition = false
                    if self.currentTransition == currentTransition {
                        self.currentTransition = nil
                    }
                    completion(currentTransition)
                })
            default:
                break
            }
        }
    }
    
    public func collapsedHeight(layout: ContainerViewLayout) -> CGFloat {
        return minimizedNavigationHeight + minimizedTopMargin + layout.intrinsicInsets.bottom
    }
}
