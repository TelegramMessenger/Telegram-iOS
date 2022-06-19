import Foundation
import UIKit
import Display
import ComponentFlow
import PagerComponent
import TelegramPresentationData
import TelegramCore
import Postbox
import AnimationCache
import MultiAnimationRenderer
import AccountContext

final class EntityKeyboardAnimationTopPanelComponent: Component {
    typealias EnvironmentType = Empty
    
    let context: AccountContext
    let file: TelegramMediaFile
    let animationCache: AnimationCache
    let animationRenderer: MultiAnimationRenderer
    
    init(
        context: AccountContext,
        file: TelegramMediaFile,
        animationCache: AnimationCache,
        animationRenderer: MultiAnimationRenderer
    ) {
        self.context = context
        self.file = file
        self.animationCache = animationCache
        self.animationRenderer = animationRenderer
    }
    
    static func ==(lhs: EntityKeyboardAnimationTopPanelComponent, rhs: EntityKeyboardAnimationTopPanelComponent) -> Bool {
        if lhs.context !== rhs.context {
            return false
        }
        if lhs.file.fileId != rhs.file.fileId {
            return false
        }
        if lhs.animationCache !== rhs.animationCache {
            return false
        }
        if lhs.animationRenderer !== rhs.animationRenderer {
            return false
        }
        
        return true
    }
    
    final class View: UIView {
        var itemLayer: EmojiPagerContentComponent.View.ItemLayer?
        
        override init(frame: CGRect) {
            super.init(frame: frame)
        }
        
        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }
        
        func update(component: EntityKeyboardAnimationTopPanelComponent, availableSize: CGSize, state: EmptyComponentState, environment: Environment<EnvironmentType>, transition: Transition) -> CGSize {
            if self.itemLayer == nil {
                let itemLayer = EmojiPagerContentComponent.View.ItemLayer(
                    item: EmojiPagerContentComponent.Item(
                        emoji: "",
                        file: component.file
                    ),
                    context: component.context,
                    groupId: "topPanel",
                    attemptSynchronousLoad: false,
                    file: component.file,
                    cache: component.animationCache,
                    renderer: component.animationRenderer,
                    placeholderColor: .lightGray,
                    pointSize: CGSize(width: 28.0, height: 28.0)
                )
                self.itemLayer = itemLayer
                self.layer.addSublayer(itemLayer)
                itemLayer.frame = CGRect(origin: CGPoint(), size: CGSize(width: 28.0, height: 28.0))
                itemLayer.isVisibleForAnimations = true
            }
            
            return CGSize(width: 28.0, height: 28.0)
        }
    }
    
    func makeView() -> View {
        return View(frame: CGRect())
    }
    
    func update(view: View, availableSize: CGSize, state: EmptyComponentState, environment: Environment<EnvironmentType>, transition: Transition) -> CGSize {
        return view.update(component: self, availableSize: availableSize, state: state, environment: environment, transition: transition)
    }
}

final class EntityKeyboardTopPanelComponent: Component {
    typealias EnvironmentType = Empty
    
    final class Item: Equatable {
        let id: AnyHashable
        let content: AnyComponent<Empty>
        
        init(id: AnyHashable, content: AnyComponent<Empty>) {
            self.id = id
            self.content = content
        }
        
        static func ==(lhs: Item, rhs: Item) -> Bool {
            if lhs.id != rhs.id {
                return false
            }
            if lhs.content != rhs.content {
                return false
            }
            
            return true
        }
    }
    
    let theme: PresentationTheme
    let items: [Item]
    
    init(
        theme: PresentationTheme,
        items: [Item]
    ) {
        self.theme = theme
        self.items = items
    }
    
    static func ==(lhs: EntityKeyboardTopPanelComponent, rhs: EntityKeyboardTopPanelComponent) -> Bool {
        if lhs.theme !== rhs.theme {
            return false
        }
        if lhs.items != rhs.items {
            return false
        }
        
        return true
    }
    
    final class View: UIView, UIScrollViewDelegate {
        private struct ItemLayout {
            let sideInset: CGFloat = 7.0
            let itemSize: CGFloat = 32.0
            let innerItemSize: CGFloat = 28.0
            let itemSpacing: CGFloat = 15.0
            let itemCount: Int
            let contentSize: CGSize
            
            init(itemCount: Int) {
                self.itemCount = itemCount
                self.contentSize = CGSize(width: sideInset * 2.0 + CGFloat(itemCount) * self.itemSize + CGFloat(max(0, itemCount - 1)) * itemSpacing, height: 41.0)
            }
            
            func containerFrame(at index: Int) -> CGRect {
                return CGRect(origin: CGPoint(x: sideInset + CGFloat(index) * (self.itemSize + self.itemSpacing), y: floor((self.contentSize.height - self.itemSize) / 2.0)), size: CGSize(width: self.itemSize, height: self.itemSize))
            }
            
            func contentFrame(at index: Int) -> CGRect {
                var frame = self.containerFrame(at: index)
                frame.origin.x += floor((self.itemSize - self.innerItemSize)) / 2.0
                frame.origin.y += floor((self.itemSize - self.innerItemSize)) / 2.0
                frame.size = CGSize(width: self.innerItemSize, height: self.innerItemSize)
                return frame
            }
            
            func visibleItemRange(for rect: CGRect) -> (minIndex: Int, maxIndex: Int) {
                let offsetRect = rect.offsetBy(dx: -self.sideInset, dy: 0.0)
                var minVisibleColumn = Int(floor((offsetRect.minX - self.itemSpacing) / (self.itemSize + self.itemSpacing)))
                minVisibleColumn = max(0, minVisibleColumn)
                let maxVisibleColumn = Int(ceil((offsetRect.maxX - self.itemSpacing) / (self.itemSize + self.itemSpacing)))

                let minVisibleIndex = minVisibleColumn
                let maxVisibleIndex = min(maxVisibleColumn, self.itemCount - 1)

                return (minVisibleIndex, maxVisibleIndex)
            }
        }
        
        private let scrollView: UIScrollView
        private var itemViews: [AnyHashable: ComponentHostView<Empty>] = [:]
        private var highlightedIconBackgroundView: UIView
        
        private var itemLayout: ItemLayout?
        private var ignoreScrolling: Bool = false
        
        private var component: EntityKeyboardTopPanelComponent?
        
        override init(frame: CGRect) {
            self.scrollView = UIScrollView()
            
            self.highlightedIconBackgroundView = UIView()
            self.highlightedIconBackgroundView.isUserInteractionEnabled = false
            self.highlightedIconBackgroundView.layer.cornerRadius = 10.0
            self.highlightedIconBackgroundView.clipsToBounds = true
            
            super.init(frame: frame)
            
            self.scrollView.delaysContentTouches = false
            if #available(iOSApplicationExtension 11.0, iOS 11.0, *) {
                self.scrollView.contentInsetAdjustmentBehavior = .never
            }
            if #available(iOS 13.0, *) {
                self.scrollView.automaticallyAdjustsScrollIndicatorInsets = false
            }
            self.scrollView.showsVerticalScrollIndicator = false
            self.scrollView.showsHorizontalScrollIndicator = false
            self.scrollView.delegate = self
            self.addSubview(self.scrollView)
            
            self.scrollView.addSubview(self.highlightedIconBackgroundView)
            
            self.disablesInteractiveTransitionGestureRecognizerNow = { [weak self] in
                guard let strongSelf = self else {
                    return false
                }
                return strongSelf.scrollView.contentOffset.x > 0.0
            }
        }
        
        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }
        
        public func scrollViewDidScroll(_ scrollView: UIScrollView) {
            if self.ignoreScrolling {
                return
            }
            
            self.updateVisibleItems(attemptSynchronousLoads: false)
        }
        
        private func updateVisibleItems(attemptSynchronousLoads: Bool) {
            guard let component = self.component, let itemLayout = self.itemLayout else {
                return
            }
            
            var validIds = Set<AnyHashable>()
            let visibleItemRange = itemLayout.visibleItemRange(for: self.scrollView.bounds)
            if !component.items.isEmpty && visibleItemRange.maxIndex >= visibleItemRange.minIndex {
                for index in visibleItemRange.minIndex ... visibleItemRange.maxIndex {
                    let item = component.items[index]
                    validIds.insert(item.id)
                    
                    let itemView: ComponentHostView<Empty>
                    if let current = self.itemViews[item.id] {
                        itemView = current
                    } else {
                        itemView = ComponentHostView<Empty>()
                        self.scrollView.addSubview(itemView)
                        self.itemViews[item.id] = itemView
                    }
                    
                    let itemFrame = itemLayout.contentFrame(at: index)
                    itemView.frame = itemFrame
                    let _ = itemView.update(
                        transition: .immediate,
                        component: item.content,
                        environment: {},
                        containerSize: itemFrame.size
                    )
                }
            }
            var removedIds: [AnyHashable] = []
            for (id, itemView) in self.itemViews {
                if !validIds.contains(id) {
                    removedIds.append(id)
                    itemView.removeFromSuperview()
                }
            }
            for id in removedIds {
                self.itemViews.removeValue(forKey: id)
            }
        }
        
        func update(component: EntityKeyboardTopPanelComponent, availableSize: CGSize, state: EmptyComponentState, environment: Environment<EnvironmentType>, transition: Transition) -> CGSize {
            if self.component?.theme !== component.theme {
                self.highlightedIconBackgroundView.backgroundColor = component.theme.chat.inputMediaPanel.panelHighlightedIconBackgroundColor
            }
            self.component = component
            
            let intrinsicHeight: CGFloat = 41.0
            let height = intrinsicHeight
            
            let itemLayout = ItemLayout(itemCount: component.items.count)
            self.itemLayout = itemLayout
            
            self.ignoreScrolling = true
            transition.setFrame(view: self.scrollView, frame: CGRect(origin: CGPoint(), size: CGSize(width: availableSize.width, height: intrinsicHeight)))
            if self.scrollView.contentSize != itemLayout.contentSize {
                self.scrollView.contentSize = itemLayout.contentSize
            }
            self.ignoreScrolling = false
            
            if let _ = component.items.first {
                self.highlightedIconBackgroundView.isHidden = false
                let itemFrame = itemLayout.containerFrame(at: 0)
                transition.setFrame(view: self.highlightedIconBackgroundView, frame: itemFrame)
            }
            
            self.updateVisibleItems(attemptSynchronousLoads: true)
            
            return CGSize(width: availableSize.width, height: height)
        }
    }
    
    func makeView() -> View {
        return View(frame: CGRect())
    }
    
    func update(view: View, availableSize: CGSize, state: EmptyComponentState, environment: Environment<EnvironmentType>, transition: Transition) -> CGSize {
        return view.update(component: self, availableSize: availableSize, state: state, environment: environment, transition: transition)
    }
}
