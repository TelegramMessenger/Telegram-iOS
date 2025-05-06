import Foundation
import UIKit
import ComponentFlow
import Display
import TelegramPresentationData
import ViewControllerComponent
import AccountContext

final class GiftPagerComponent: Component {
    typealias EnvironmentType = ViewControllerComponentContainer.Environment
    
    public final class Item: Equatable {
        let id: AnyHashable
        let subject: GiftViewScreen.Subject
        
        public init(id: AnyHashable, subject: GiftViewScreen.Subject) {
            self.id = id
            self.subject = subject
        }
        
        public static func ==(lhs: Item, rhs: Item) -> Bool {
            if lhs.id != rhs.id {
                return false
            }
            if lhs.subject != rhs.subject {
                return false
            }
            
            return true
        }
    }
    
    let context: AccountContext
    let items: [Item]
    let index: Int
    let itemSpacing: CGFloat
    let updated: (CGFloat, Int) -> Void
    
    public init(
        context: AccountContext,
        items: [Item],
        index: Int = 0,
        itemSpacing: CGFloat = 0.0,
        updated: @escaping (CGFloat, Int) -> Void
    ) {
        self.context = context
        self.items = items
        self.index = index
        self.itemSpacing = itemSpacing
        self.updated = updated
    }
    
    public static func ==(lhs: GiftPagerComponent, rhs: GiftPagerComponent) -> Bool {
        if lhs.items != rhs.items {
            return false
        }
        if lhs.index != rhs.index {
            return false
        }
        if lhs.itemSpacing != rhs.itemSpacing {
            return false
        }
        return true
    }
    
    final class View: UIView, UIScrollViewDelegate {
        private let scrollView: UIScrollView
        private var itemViews: [AnyHashable: ComponentHostView<EnvironmentType>] = [:]
        
        private var component: GiftPagerComponent?
        private var environment: Environment<EnvironmentType>?
        
        override init(frame: CGRect) {
            self.scrollView = UIScrollView(frame: frame)
            self.scrollView.isPagingEnabled = true
            self.scrollView.showsHorizontalScrollIndicator = false
            self.scrollView.showsVerticalScrollIndicator = false
            self.scrollView.alwaysBounceHorizontal = false
            self.scrollView.bounces = false
            self.scrollView.layer.cornerRadius = 10.0
            if #available(iOSApplicationExtension 11.0, iOS 11.0, *) {
                self.scrollView.contentInsetAdjustmentBehavior = .never
            }
            
            super.init(frame: frame)
            
            self.scrollView.delegate = self
            
            self.addSubview(self.scrollView)
        }
        
        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }
        
        private var isSwiping: Bool = false
        private var lastScrollTime: TimeInterval = 0
        private let swipeInactiveThreshold: TimeInterval = 0.5
            
        public func scrollViewWillBeginDragging(_ scrollView: UIScrollView) {
            self.isSwiping = true
            self.lastScrollTime = CACurrentMediaTime()
        }
        
        public func scrollViewDidEndDragging(_ scrollView: UIScrollView, willDecelerate decelerate: Bool) {
            if !decelerate {
                self.isSwiping = false
            }
        }
        
        public func scrollViewDidEndDecelerating(_ scrollView: UIScrollView) {
            self.isSwiping = false
        }
        
        private var ignoreContentOffsetChange = false
        public func scrollViewDidScroll(_ scrollView: UIScrollView) {
            guard let component = self.component, let environment = self.environment, !self.ignoreContentOffsetChange && !self.isUpdating else {
                return
            }
            
            if self.isSwiping {
                self.lastScrollTime = CACurrentMediaTime()
            }

            self.ignoreContentOffsetChange = true
            let _ = self.update(component: component, availableSize: self.bounds.size, environment: environment, transition: .immediate)
            component.updated(self.scrollView.contentOffset.x / (self.scrollView.contentSize.width - self.scrollView.frame.width), component.items.count)
            self.ignoreContentOffsetChange = false
        }
        
        private var isUpdating = true
        func update(component: GiftPagerComponent, availableSize: CGSize, environment: Environment<EnvironmentType>, transition: ComponentTransition) -> CGSize {
            self.isUpdating = true
            defer {
                self.isUpdating = false
            }
            var validIds: [AnyHashable] = []
            
            self.component = component
            self.environment = environment
            
            let firstTime = self.itemViews.isEmpty
            
            let itemWidth = availableSize.width
            let totalWidth = itemWidth * CGFloat(component.items.count) + component.itemSpacing * CGFloat(max(0, component.items.count - 1))
                    
            let contentSize = CGSize(width: totalWidth, height: availableSize.height)
            if self.scrollView.contentSize != contentSize {
                self.scrollView.contentSize = contentSize
            }
            let scrollFrame = CGRect(origin: .zero, size: availableSize)
            if self.scrollView.frame != scrollFrame {
                self.scrollView.frame = scrollFrame
            }
            
            if firstTime {
                let initialOffset = CGFloat(component.index) * (itemWidth + component.itemSpacing)
                self.scrollView.contentOffset = CGPoint(x: initialOffset, y: 0.0)
                
                var position: CGFloat
                if self.scrollView.contentSize.width > self.scrollView.frame.width {
                    position = self.scrollView.contentOffset.x / (self.scrollView.contentSize.width - self.scrollView.frame.width)
                } else {
                    position = 0.0
                }
                component.updated(position, component.items.count)
            }
            let viewportCenter = self.scrollView.contentOffset.x + availableSize.width * 0.5
            
            let currentTime = CACurrentMediaTime()
            let isSwipingActive = self.isSwiping || (currentTime - self.lastScrollTime < self.swipeInactiveThreshold)
            
            var i = 0
            for item in component.items {
                let itemOriginX = (itemWidth + component.itemSpacing) * CGFloat(i)
                let itemFrame = CGRect(origin: CGPoint(x: itemOriginX, y: 0.0), size: CGSize(width: itemWidth, height: availableSize.height))
                
                let centerDelta = itemFrame.midX - viewportCenter
                let position = centerDelta / (availableSize.width * 0.75)
                
                i += 1
                
                if !isSwipingActive && abs(position) > 0.5 {
                    continue
                } else if isSwipingActive && abs(position) > 1.5 {
                    continue
                }
                
                validIds.append(item.id)
                
                let itemView: ComponentHostView<EnvironmentType>
                var itemTransition = transition
                
                if let current = self.itemViews[item.id] {
                    itemView = current
                } else {
                    itemTransition = transition.withAnimation(.none)
                    itemView = ComponentHostView<EnvironmentType>()
                    self.itemViews[item.id] = itemView
                    
                    self.scrollView.addSubview(itemView)
                }
                                
                let environment = environment[EnvironmentType.self]
                
                let _ = itemView.update(
                    transition: itemTransition,
                    component: AnyComponent(GiftViewSheetComponent(
                        context: component.context,
                        subject: item.subject
                    )),
                    environment: { environment },
                    containerSize: availableSize
                )
                
                itemView.frame = itemFrame
            }
            
            var removeIds: [AnyHashable] = []
            for (id, itemView) in self.itemViews {
                if !validIds.contains(id) {
                    removeIds.append(id)
                    itemView.removeFromSuperview()
                }
            }
            for id in removeIds {
                self.itemViews.removeValue(forKey: id)
            }
                
            return availableSize
        }
    }
    
    func makeView() -> View {
        return View(frame: CGRect())
    }
    
    func update(view: View, availableSize: CGSize, state: EmptyComponentState, environment: Environment<EnvironmentType>, transition: ComponentTransition) -> CGSize {
        return view.update(component: self, availableSize: availableSize, environment: environment, transition: transition)
    }
}
