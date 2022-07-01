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
    let pressed: () -> Void
    
    init(
        context: AccountContext,
        file: TelegramMediaFile,
        animationCache: AnimationCache,
        animationRenderer: MultiAnimationRenderer,
        pressed: @escaping () -> Void
    ) {
        self.context = context
        self.file = file
        self.animationCache = animationCache
        self.animationRenderer = animationRenderer
        self.pressed = pressed
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
        var component: EntityKeyboardAnimationTopPanelComponent?
        
        override init(frame: CGRect) {
            super.init(frame: frame)
            
            self.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(self.tapGesture(_:))))
        }
        
        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }
        
        @objc private func tapGesture(_ recognizer: UITapGestureRecognizer) {
            if case .ended = recognizer.state {
                self.component?.pressed()
            }
        }
        
        func update(component: EntityKeyboardAnimationTopPanelComponent, availableSize: CGSize, state: EmptyComponentState, environment: Environment<EnvironmentType>, transition: Transition) -> CGSize {
            self.component = component
            
            if self.itemLayer == nil {
                let itemLayer = EmojiPagerContentComponent.View.ItemLayer(
                    item: EmojiPagerContentComponent.Item(
                        emoji: "",
                        file: component.file,
                        stickerPackItem: nil
                    ),
                    context: component.context,
                    groupId: "topPanel",
                    attemptSynchronousLoad: false,
                    file: component.file,
                    cache: component.animationCache,
                    renderer: component.animationRenderer,
                    placeholderColor: .lightGray,
                    blurredBadgeColor: .clear,
                    displayPremiumBadgeIfAvailable: false,
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
    typealias EnvironmentType = EntityKeyboardTopContainerPanelEnvironment
    
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
    let activeContentItemIdUpdated: ActionSlot<(AnyHashable, Transition)>
    
    init(
        theme: PresentationTheme,
        items: [Item],
        activeContentItemIdUpdated: ActionSlot<(AnyHashable, Transition)>
    ) {
        self.theme = theme
        self.items = items
        self.activeContentItemIdUpdated = activeContentItemIdUpdated
    }
    
    static func ==(lhs: EntityKeyboardTopPanelComponent, rhs: EntityKeyboardTopPanelComponent) -> Bool {
        if lhs.theme !== rhs.theme {
            return false
        }
        if lhs.items != rhs.items {
            return false
        }
        if lhs.activeContentItemIdUpdated !== rhs.activeContentItemIdUpdated {
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
        
        private var visibilityFraction: CGFloat = 1.0
        
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
                    
                    let itemOuterFrame = itemLayout.contentFrame(at: index)
                    let itemSize = itemView.update(
                        transition: .immediate,
                        component: item.content,
                        environment: {},
                        containerSize: itemOuterFrame.size
                    )
                    itemView.frame = CGRect(origin: CGPoint(x: itemOuterFrame.minX + floor((itemOuterFrame.width - itemSize.width) / 2.0), y: itemOuterFrame.minY + floor((itemOuterFrame.height - itemSize.height) / 2.0)), size: itemSize)
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
            
            self.updateVisibleItems(attemptSynchronousLoads: true)
            
            environment[EntityKeyboardTopContainerPanelEnvironment.self].value.visibilityFractionUpdated.connect { [weak self] (fraction, transition) in
                guard let strongSelf = self else {
                    return
                }
                strongSelf.visibilityFractionUpdated(value: fraction, transition: transition)
            }
            
            component.activeContentItemIdUpdated.connect { [weak self] (itemId, transition) in
                guard let strongSelf = self else {
                    return
                }
                strongSelf.activeContentItemIdUpdated(itemId: itemId, transition: transition)
            }
            
            return CGSize(width: availableSize.width, height: height)
        }
        
        private func visibilityFractionUpdated(value: CGFloat, transition: Transition) {
            if self.visibilityFraction == value {
                return
            }
            
            self.visibilityFraction = value
            
            let scale = max(0.01, self.visibilityFraction)
            
            transition.setScale(view: self.highlightedIconBackgroundView, scale: scale)
            transition.setAlpha(view: self.highlightedIconBackgroundView, alpha: self.visibilityFraction)
            
            for (_, itemView) in self.itemViews {
                transition.setSublayerTransform(view: itemView, transform: CATransform3DMakeScale(scale, scale, 1.0))
                transition.setAlpha(view: itemView, alpha: self.visibilityFraction)
            }
        }
        
        private func activeContentItemIdUpdated(itemId: AnyHashable, transition: Transition) {
            guard let component = self.component, let itemLayout = self.itemLayout else {
                return
            }

            var found = false
            for i in 0 ..< component.items.count {
                if component.items[i].id == itemId {
                    found = true
                    self.highlightedIconBackgroundView.isHidden = false
                    let itemFrame = itemLayout.containerFrame(at: i)
                    transition.setFrame(view: self.highlightedIconBackgroundView, frame: itemFrame)
                    
                    break
                }
            }
            if !found {
                self.highlightedIconBackgroundView.isHidden = true
            }
        }
    }
    
    func makeView() -> View {
        return View(frame: CGRect())
    }
    
    func update(view: View, availableSize: CGSize, state: EmptyComponentState, environment: Environment<EnvironmentType>, transition: Transition) -> CGSize {
        return view.update(component: self, availableSize: availableSize, state: state, environment: environment, transition: transition)
    }
}
