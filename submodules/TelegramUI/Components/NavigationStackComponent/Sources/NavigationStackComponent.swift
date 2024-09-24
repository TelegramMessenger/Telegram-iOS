import Foundation
import UIKit
import Display
import ComponentFlow
import AppBundle
import BundleIconComponent

private final class NavigationContainer: UIView, UIGestureRecognizerDelegate {
    var requestUpdate: ((ComponentTransition) -> Void)?
    var requestPop: (() -> Void)?
    var transitionFraction: CGFloat = 0.0
    
    private var panRecognizer: InteractiveTransitionGestureRecognizer?
    
    var isNavigationEnabled: Bool = false {
        didSet {
            self.panRecognizer?.isEnabled = self.isNavigationEnabled
        }
    }
    
    init() {
        super.init(frame: .zero)
                
        let panRecognizer = InteractiveTransitionGestureRecognizer(target: self, action: #selector(self.panGesture(_:)), allowedDirections: { [weak self] point in
            guard let strongSelf = self else {
                return []
            }
            let _ = strongSelf
            return [.right]
        })
        panRecognizer.delegate = self
        self.addGestureRecognizer(panRecognizer)
        self.panRecognizer = panRecognizer
    }
    
    required public init(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool {
        return false
    }
    
    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldBeRequiredToFailBy otherGestureRecognizer: UIGestureRecognizer) -> Bool {
        if let _ = otherGestureRecognizer as? InteractiveTransitionGestureRecognizer {
            return false
        }
        if let _ = otherGestureRecognizer as? UIPanGestureRecognizer {
            return true
        }
        return false
    }
    
    @objc private func panGesture(_ recognizer: UIPanGestureRecognizer) {
        switch recognizer.state {
        case .began:
            self.transitionFraction = 0.0
        case .changed:
            let distanceFactor: CGFloat = recognizer.translation(in: self).x / self.bounds.width
            let transitionFraction = max(0.0, min(1.0, distanceFactor))
            if self.transitionFraction != transitionFraction {
                self.transitionFraction = transitionFraction
                self.requestUpdate?(.immediate)
            }
        case .ended, .cancelled:
            let distanceFactor: CGFloat = recognizer.translation(in: self).x / self.bounds.width
            let transitionFraction = max(0.0, min(1.0, distanceFactor))
            if transitionFraction > 0.2 {
                self.transitionFraction = 0.0
                self.requestPop?()
            } else {
                self.transitionFraction = 0.0
                self.requestUpdate?(.spring(duration: 0.45))
            }
        default:
            break
        }
    }
}

public final class NavigationStackComponent<ChildEnvironment: Equatable>: Component {
    public enum CurlTransition {
        case show
        case hide
    }
    
    public let items: [AnyComponentWithIdentity<ChildEnvironment>]
    public let clipContent: Bool
    public let requestPop: () -> Void
    
    public init(
        items: [AnyComponentWithIdentity<ChildEnvironment>],
        clipContent: Bool = true,
        requestPop: @escaping () -> Void
    ) {
        self.items = items
        self.clipContent = clipContent
        self.requestPop = requestPop
    }
    
    public static func ==(lhs: NavigationStackComponent, rhs: NavigationStackComponent) -> Bool {
        if lhs.items != rhs.items {
            return false
        }
        if lhs.clipContent != rhs.clipContent {
            return false
        }
        return true
    }
        
    private final class ItemView: UIView {
        let contents = ComponentView<ChildEnvironment>()
        let dimView = UIView()
        
        override init(frame: CGRect) {
            super.init(frame: frame)
            
            self.dimView.alpha = 0.0
            self.dimView.backgroundColor = UIColor.black.withAlphaComponent(0.3)
            self.dimView.isUserInteractionEnabled = false
            self.addSubview(self.dimView)
        }
        
        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }
    }
    
    private struct ReadyItem {
        var index: Int
        var itemId: AnyHashable
        var itemView: ItemView
        var itemTransition: ComponentTransition
        var itemSize: CGSize
        
        init(index: Int, itemId: AnyHashable, itemView: ItemView, itemTransition: ComponentTransition, itemSize: CGSize) {
            self.index = index
            self.itemId = itemId
            self.itemView = itemView
            self.itemTransition = itemTransition
            self.itemSize = itemSize
        }
    }
    
    public final class View: UIView {
        private var itemViews: [AnyHashable: ItemView] = [:]
        private let navigationContainer = NavigationContainer()
        
        private var component: NavigationStackComponent?
        private var state: EmptyComponentState?
        
        public override init(frame: CGRect) {
            super.init(frame: CGRect())
            
            self.addSubview(self.navigationContainer)
            
            self.navigationContainer.requestUpdate = { [weak self] transition in
                guard let self else {
                    return
                }
                self.state?.updated(transition: transition)
            }
            
            self.navigationContainer.requestPop = { [weak self] in
                guard let self else {
                    return
                }
                self.component?.requestPop()
            }
        }
        
        required public init?(coder: NSCoder) {
            preconditionFailure()
        }
                
        func update(component: NavigationStackComponent, availableSize: CGSize, state: EmptyComponentState, environment: Environment<ChildEnvironment>, transition: ComponentTransition) -> CGSize {
            self.component = component
            self.state = state
            
            var transition = transition
            var curlTransition: NavigationStackComponent<ChildEnvironment>.CurlTransition?
            if let curlTransitionValue = transition.userData(NavigationStackComponent<ChildEnvironment>.CurlTransition.self) {
                transition = .immediate
                curlTransition = curlTransitionValue
            }
            
            let navigationTransitionFraction = self.navigationContainer.transitionFraction
            self.navigationContainer.isNavigationEnabled = component.items.count > 1
                                    
            var validItemIds: [AnyHashable] = []
        
            var removeImpl: (() -> Void)?
            
            var readyItems: [ReadyItem] = []
            for i in 0 ..< component.items.count {
                let item = component.items[i]
                let itemId = item.id
                validItemIds.append(itemId)
                
                let itemView: ItemView
                var itemTransition = transition
                if let current = self.itemViews[itemId] {
                    itemView = current
                } else {
                    itemTransition = itemTransition.withAnimation(.none)
                    itemView = ItemView()
                    itemView.clipsToBounds = component.clipContent
                    self.itemViews[itemId] = itemView
                    itemView.contents.parentState = state
                }
                
                let itemSize = itemView.contents.update(
                    transition: itemTransition,
                    component: item.component,
                    environment: { environment[ChildEnvironment.self] },
                    containerSize: CGSize(width: availableSize.width, height: availableSize.height)
                )
                
                readyItems.append(ReadyItem(
                    index: i,
                    itemId: itemId,
                    itemView: itemView,
                    itemTransition: itemTransition,
                    itemSize: itemSize
                ))
            }
            
            let sortedItems = readyItems.sorted(by: { $0.index < $1.index })
            for readyItem in sortedItems {
                let transitionFraction: CGFloat
                let alphaTransitionFraction: CGFloat
                if readyItem.index == readyItems.count - 1 {
                    transitionFraction = navigationTransitionFraction
                    alphaTransitionFraction = 1.0
                } else if readyItem.index == readyItems.count - 2 {
                    transitionFraction = navigationTransitionFraction - 1.0
                    alphaTransitionFraction = navigationTransitionFraction
                } else {
                    transitionFraction = 0.0
                    alphaTransitionFraction = 0.0
                }
                
                let transitionOffset: CGFloat
                if readyItem.index == readyItems.count - 1 {
                    transitionOffset = readyItem.itemSize.width * transitionFraction
                } else {
                    transitionOffset = readyItem.itemSize.width / 3.0 * transitionFraction
                }
                
                let itemFrame = CGRect(origin: CGPoint(x: transitionOffset, y: 0.0), size: readyItem.itemSize)
                
                let itemBounds = CGRect(origin: .zero, size: itemFrame.size)
                if let itemComponentView = readyItem.itemView.contents.view {
                    var isAdded = false
                    if itemComponentView.superview == nil {
                        isAdded = true
                        
                        readyItem.itemView.insertSubview(itemComponentView, at: 0)
                        self.navigationContainer.addSubview(readyItem.itemView)
                    }
                    readyItem.itemTransition.setFrame(view: readyItem.itemView, frame: itemFrame)
                    readyItem.itemTransition.setFrame(view: itemComponentView, frame: itemBounds)
                    readyItem.itemTransition.setFrame(view: readyItem.itemView.dimView, frame: CGRect(origin: .zero, size: availableSize))
                    readyItem.itemTransition.setAlpha(view: readyItem.itemView.dimView, alpha: 1.0 - alphaTransitionFraction)
                    
                    if curlTransition == .show && isAdded {
                        var fromFrame = itemFrame
                        fromFrame.size.height = 0.0
                        let transition = ComponentTransition.easeInOut(duration: 0.3)
                        transition.animateBoundsSize(view: readyItem.itemView, from: fromFrame.size, to: itemFrame.size, completion: { _ in
                            removeImpl?()
                        })
                        transition.animatePosition(view: readyItem.itemView, from: fromFrame.center, to: itemFrame.center)
                    } else if curlTransition == .hide && isAdded {
                        let transition = ComponentTransition.easeInOut(duration: 0.3)
                        transition.animateAlpha(view: readyItem.itemView.dimView, from: 1.0, to: 0.0)
                    } else if readyItem.index > 0 && isAdded {
                        transition.animatePosition(view: itemComponentView, from: CGPoint(x: itemFrame.width, y: 0.0), to: .zero, additive: true, completion: nil)
                    }
                }
            }
            
            let lastHeight = sortedItems.last?.itemSize.height ?? 0.0
            let previousHeight: CGFloat
            if sortedItems.count > 1 {
                previousHeight = sortedItems[sortedItems.count - 2].itemSize.height
            } else {
                previousHeight = lastHeight
            }
            let contentHeight = lastHeight * (1.0 - navigationTransitionFraction) + previousHeight * navigationTransitionFraction
            
            var removedItemIds: [AnyHashable] = []
            for (id, _) in self.itemViews {
                if !validItemIds.contains(id) {
                    removedItemIds.append(id)
                }
            }
            
            removeImpl = {
                for id in removedItemIds {
                    guard let itemView = self.itemViews[id] else {
                        continue
                    }
                    if let itemComponentView = itemView.contents.view, curlTransition != .show {
                        if curlTransition == .hide {
                            itemView.superview?.bringSubviewToFront(itemView)
                            var toFrame = itemView.frame
                            toFrame.size.height = 0.0
                            let transition = ComponentTransition.easeInOut(duration: 0.3)
                            transition.setFrame(view: itemView, frame: toFrame, completion: { _ in
                                itemView.removeFromSuperview()
                                self.itemViews.removeValue(forKey: id)
                            })
                        } else {
                            var position = itemComponentView.center
                            position.x += itemComponentView.bounds.width
                            transition.setPosition(view: itemComponentView, position: position, completion: { _ in
                                itemView.removeFromSuperview()
                                self.itemViews.removeValue(forKey: id)
                            })
                        }
                    } else {
                        itemView.removeFromSuperview()
                        self.itemViews.removeValue(forKey: id)
                    }
                }
            }
            
            if curlTransition == .show {
                let transition = ComponentTransition.easeInOut(duration: 0.3)
                for id in removedItemIds {
                    guard let itemView = self.itemViews[id] else {
                        continue
                    }
                    transition.setAlpha(view: itemView.dimView, alpha: 1.0)
                }
            } else {
                removeImpl?()
            }
            
            let contentSize = CGSize(width: availableSize.width, height: contentHeight)
            self.navigationContainer.frame = CGRect(origin: .zero, size: contentSize)
            
            return contentSize
        }
    }
    
    public func makeView() -> View {
        return View(frame: CGRect())
    }
    
    public func update(view: View, availableSize: CGSize, state: EmptyComponentState, environment: Environment<ChildEnvironment>, transition: ComponentTransition) -> CGSize {
        return view.update(component: self, availableSize: availableSize, state: state, environment: environment, transition: transition)
    }
}
