import Foundation
import SwiftSignalKit
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
import MultilineTextComponent

final class EntityKeyboardAnimationTopPanelComponent: Component {
    typealias EnvironmentType = EntityKeyboardTopPanelItemEnvironment
    
    let context: AccountContext
    let file: TelegramMediaFile
    let animationCache: AnimationCache
    let animationRenderer: MultiAnimationRenderer
    let theme: PresentationTheme
    let title: String
    let pressed: () -> Void
    
    init(
        context: AccountContext,
        file: TelegramMediaFile,
        animationCache: AnimationCache,
        animationRenderer: MultiAnimationRenderer,
        theme: PresentationTheme,
        title: String,
        pressed: @escaping () -> Void
    ) {
        self.context = context
        self.file = file
        self.animationCache = animationCache
        self.animationRenderer = animationRenderer
        self.theme = theme
        self.title = title
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
        if lhs.theme !== rhs.theme {
            return false
        }
        if lhs.title != rhs.title {
            return false
        }
        
        return true
    }
    
    final class View: UIView {
        var itemLayer: EmojiPagerContentComponent.View.ItemLayer?
        var placeholderView: EmojiPagerContentComponent.View.ItemPlaceholderView?
        var component: EntityKeyboardAnimationTopPanelComponent?
        var titleView: ComponentView<Empty>?
        
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
            
            let itemEnvironment = environment[EntityKeyboardTopPanelItemEnvironment.self].value
            
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
                    pointSize: CGSize(width: 44.0, height: 44.0),
                    onUpdateDisplayPlaceholder: { [weak self] displayPlaceholder in
                        guard let strongSelf = self else {
                            return
                        }
                        strongSelf.updateDisplayPlaceholder(displayPlaceholder: displayPlaceholder)
                    }
                )
                self.itemLayer = itemLayer
                self.layer.addSublayer(itemLayer)
                
                if itemLayer.displayPlaceholder {
                    self.updateDisplayPlaceholder(displayPlaceholder: true)
                }
            }
            
            let iconSize: CGSize = itemEnvironment.isExpanded ? CGSize(width: 44.0, height: 44.0) : CGSize(width: 28.0, height: 28.0)
            let iconFrame = CGRect(origin: CGPoint(x: floor((availableSize.width - iconSize.width) / 2.0), y: 0.0), size: iconSize)
            
            if let itemLayer = self.itemLayer {
                transition.setPosition(layer: itemLayer, position: CGPoint(x: iconFrame.midX, y: iconFrame.midY))
                transition.setBounds(layer: itemLayer, bounds: CGRect(origin: CGPoint(), size: iconFrame.size))
                itemLayer.isVisibleForAnimations = true
            }
            
            if itemEnvironment.isExpanded {
                let titleView: ComponentView<Empty>
                if let current = self.titleView {
                    titleView = current
                } else {
                    titleView = ComponentView<Empty>()
                    self.titleView = titleView
                }
                let titleSize = titleView.update(
                    transition: .immediate,
                    component: AnyComponent(MultilineTextComponent(
                        text: .plain(NSAttributedString(string: component.title, font: Font.regular(10.0), textColor: component.theme.chat.inputPanel.primaryTextColor))
                    )),
                    environment: {},
                    containerSize: CGSize(width: 62.0, height: 100.0)
                )
                if let view = titleView.view {
                    if view.superview == nil {
                        view.alpha = 0.0
                        self.addSubview(view)
                    }
                    view.frame = CGRect(origin: CGPoint(x: floor((availableSize.width - titleSize.width) / 2.0), y: availableSize.height - titleSize.height), size: titleSize)
                    transition.setAlpha(view: view, alpha: 1.0)
                }
            } else if let titleView = self.titleView {
                self.titleView = nil
                if let view = titleView.view {
                    transition.setAlpha(view: view, alpha: 0.0, completion: { [weak view] _ in
                        view?.removeFromSuperview()
                    })
                }
            }
            
            return availableSize
        }
        
        private func updateDisplayPlaceholder(displayPlaceholder: Bool) {
            if displayPlaceholder {
                if self.placeholderView == nil, let component = self.component {
                    let placeholderView = EmojiPagerContentComponent.View.ItemPlaceholderView(
                        context: component.context,
                        file: component.file,
                        shimmerView: nil,
                        color: component.theme.chat.inputPanel.primaryTextColor.withMultipliedAlpha(0.08),
                        size: CGSize(width: 28.0, height: 28.0)
                    )
                    self.placeholderView = placeholderView
                    self.insertSubview(placeholderView, at: 0)
                    placeholderView.frame = CGRect(origin: CGPoint(), size: CGSize(width: 28.0, height: 28.0))
                    placeholderView.update(size: CGSize(width: 28.0, height: 28.0))
                }
            } else {
                if let placeholderView = self.placeholderView {
                    self.placeholderView = nil
                    placeholderView.removeFromSuperview()
                }
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

final class EntityKeyboardIconTopPanelComponent: Component {
    typealias EnvironmentType = EntityKeyboardTopPanelItemEnvironment
    
    let imageName: String
    let theme: PresentationTheme
    let title: String
    let pressed: () -> Void
    
    init(
        imageName: String,
        theme: PresentationTheme,
        title: String,
        pressed: @escaping () -> Void
    ) {
        self.imageName = imageName
        self.theme = theme
        self.title = title
        self.pressed = pressed
    }
    
    static func ==(lhs: EntityKeyboardIconTopPanelComponent, rhs: EntityKeyboardIconTopPanelComponent) -> Bool {
        if lhs.imageName != rhs.imageName {
            return false
        }
        if lhs.theme !== rhs.theme {
            return false
        }
        if lhs.title != rhs.title {
            return false
        }
        
        return true
    }
    
    final class View: UIView {
        let iconView: UIImageView
        var component: EntityKeyboardIconTopPanelComponent?
        var titleView: ComponentView<Empty>?
        
        override init(frame: CGRect) {
            self.iconView = UIImageView()
            
            super.init(frame: frame)
            
            self.addSubview(self.iconView)
            
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
        
        func update(component: EntityKeyboardIconTopPanelComponent, availableSize: CGSize, state: EmptyComponentState, environment: Environment<EnvironmentType>, transition: Transition) -> CGSize {
            let itemEnvironment = environment[EntityKeyboardTopPanelItemEnvironment.self].value
            
            if self.component?.imageName != component.imageName {
                self.iconView.image = generateTintedImage(image: UIImage(bundleImageName: component.imageName), color: component.theme.chat.inputMediaPanel.panelIconColor)
            }
                
            self.component = component
            
            let nativeIconSize: CGSize = itemEnvironment.isExpanded ? CGSize(width: 44.0, height: 44.0) : CGSize(width: 28.0, height: 28.0)
            let boundingIconSize: CGSize = itemEnvironment.isExpanded ? CGSize(width: 38.0, height: 38.0) : CGSize(width: 24.0, height: 24.0)
            
            let iconSize = (self.iconView.image?.size ?? nativeIconSize).aspectFitted(boundingIconSize)
            let iconFrame = CGRect(origin: CGPoint(x: floor((availableSize.width - iconSize.width) / 2.0), y: floor((nativeIconSize.height - iconSize.height) / 2.0)), size: iconSize)
            
            transition.setFrame(view: self.iconView, frame: iconFrame)
            
            if itemEnvironment.isExpanded {
                let titleView: ComponentView<Empty>
                if let current = self.titleView {
                    titleView = current
                } else {
                    titleView = ComponentView<Empty>()
                    self.titleView = titleView
                }
                let titleSize = titleView.update(
                    transition: .immediate,
                    component: AnyComponent(MultilineTextComponent(
                        text: .plain(NSAttributedString(string: component.title, font: Font.regular(10.0), textColor: component.theme.chat.inputPanel.primaryTextColor))
                    )),
                    environment: {},
                    containerSize: CGSize(width: 62.0, height: 100.0)
                )
                if let view = titleView.view {
                    if view.superview == nil {
                        view.alpha = 0.0
                        self.addSubview(view)
                    }
                    view.frame = CGRect(origin: CGPoint(x: floor((availableSize.width - titleSize.width) / 2.0), y: availableSize.height - titleSize.height), size: titleSize)
                    transition.setAlpha(view: view, alpha: 1.0)
                }
            } else if let titleView = self.titleView {
                self.titleView = nil
                if let view = titleView.view {
                    transition.setAlpha(view: view, alpha: 0.0, completion: { [weak view] _ in
                        view?.removeFromSuperview()
                    })
                }
            }
            
            return availableSize
        }
    }
    
    func makeView() -> View {
        return View(frame: CGRect())
    }
    
    func update(view: View, availableSize: CGSize, state: EmptyComponentState, environment: Environment<EnvironmentType>, transition: Transition) -> CGSize {
        return view.update(component: self, availableSize: availableSize, state: state, environment: environment, transition: transition)
    }
}

final class EntityKeyboardTopPanelItemEnvironment: Equatable {
    let isExpanded: Bool
    
    init(isExpanded: Bool) {
        self.isExpanded = isExpanded
    }
    
    static func ==(lhs: EntityKeyboardTopPanelItemEnvironment, rhs: EntityKeyboardTopPanelItemEnvironment) -> Bool {
        if lhs.isExpanded != rhs.isExpanded {
            return false
        }
        return true
    }
}

final class EntityKeyboardTopPanelComponent: Component {
    typealias EnvironmentType = EntityKeyboardTopContainerPanelEnvironment
    
    final class Item: Equatable {
        let id: AnyHashable
        let content: AnyComponent<EntityKeyboardTopPanelItemEnvironment>
        
        init(id: AnyHashable, content: AnyComponent<EntityKeyboardTopPanelItemEnvironment>) {
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
    let defaultActiveItemId: AnyHashable?
    let activeContentItemIdUpdated: ActionSlot<(AnyHashable, Transition)>
    
    init(
        theme: PresentationTheme,
        items: [Item],
        defaultActiveItemId: AnyHashable? = nil,
        activeContentItemIdUpdated: ActionSlot<(AnyHashable, Transition)>
    ) {
        self.theme = theme
        self.items = items
        self.defaultActiveItemId = defaultActiveItemId
        self.activeContentItemIdUpdated = activeContentItemIdUpdated
    }
    
    static func ==(lhs: EntityKeyboardTopPanelComponent, rhs: EntityKeyboardTopPanelComponent) -> Bool {
        if lhs.theme !== rhs.theme {
            return false
        }
        if lhs.items != rhs.items {
            return false
        }
        if lhs.defaultActiveItemId != rhs.defaultActiveItemId {
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
            let itemSize: CGSize
            let innerItemSize: CGSize
            let itemSpacing: CGFloat = 15.0
            let itemCount: Int
            let contentSize: CGSize
            let isExpanded: Bool
            
            init(itemCount: Int, isExpanded: Bool, height: CGFloat) {
                self.isExpanded = isExpanded
                self.itemSize = self.isExpanded ? CGSize(width: 54.0, height: 68.0) : CGSize(width: 32.0, height: 32.0)
                self.innerItemSize = self.isExpanded ? CGSize(width: 50.0, height: 62.0) : CGSize(width: 28.0, height: 28.0)
                self.itemCount = itemCount
                self.contentSize = CGSize(width: sideInset * 2.0 + CGFloat(itemCount) * self.itemSize.width + CGFloat(max(0, itemCount - 1)) * itemSpacing, height: height)
            }
            
            func containerFrame(at index: Int) -> CGRect {
                return CGRect(origin: CGPoint(x: sideInset + CGFloat(index) * (self.itemSize.width + self.itemSpacing), y: floor((self.contentSize.height - self.itemSize.height) / 2.0)), size: self.itemSize)
            }
            
            func contentFrame(containerFrame: CGRect) -> CGRect {
                var frame = containerFrame
                frame.origin.x += floor((self.itemSize.width - self.innerItemSize.width)) / 2.0
                frame.origin.y += floor((self.itemSize.height - self.innerItemSize.height)) / 2.0
                frame.size = self.innerItemSize
                return frame
            }
            
            func contentFrame(at index: Int) -> CGRect {
                return self.contentFrame(containerFrame: self.containerFrame(at: index))
            }
            
            func visibleItemRange(for rect: CGRect) -> (minIndex: Int, maxIndex: Int) {
                let offsetRect = rect.offsetBy(dx: -self.sideInset, dy: 0.0)
                var minVisibleColumn = Int(floor((offsetRect.minX - self.itemSpacing) / (self.itemSize.width + self.itemSpacing)))
                minVisibleColumn = max(0, minVisibleColumn)
                let maxVisibleColumn = Int(ceil((offsetRect.maxX - self.itemSpacing) / (self.itemSize.width + self.itemSpacing)))

                let minVisibleIndex = minVisibleColumn
                let maxVisibleIndex = min(maxVisibleColumn, self.itemCount - 1)

                return (minVisibleIndex, maxVisibleIndex)
            }
        }
        
        private let scrollView: UIScrollView
        private var itemViews: [AnyHashable: ComponentHostView<EntityKeyboardTopPanelItemEnvironment>] = [:]
        private var highlightedIconBackgroundView: UIView
        
        private var itemLayout: ItemLayout?
        private var ignoreScrolling: Bool = false
        
        private var isDragging: Bool = false
        private var draggingStoppedTimer: SwiftSignalKit.Timer?
        
        private var isExpanded: Bool = false
        
        private var visibilityFraction: CGFloat = 1.0
        
        private var activeContentItemId: AnyHashable?
        
        private var component: EntityKeyboardTopPanelComponent?
        private var environment: EntityKeyboardTopContainerPanelEnvironment?
        
        override init(frame: CGRect) {
            self.scrollView = UIScrollView()
            
            self.highlightedIconBackgroundView = UIView()
            self.highlightedIconBackgroundView.isUserInteractionEnabled = false
            self.highlightedIconBackgroundView.layer.cornerRadius = 10.0
            self.highlightedIconBackgroundView.clipsToBounds = true
            
            super.init(frame: frame)
            
            self.scrollView.layer.anchorPoint = CGPoint()
            self.scrollView.delaysContentTouches = false
            self.scrollView.clipsToBounds = false
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
            
            self.clipsToBounds = true
            
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
            
            self.updateVisibleItems(attemptSynchronousLoads: false, transition: .immediate)
        }
        
        public func scrollViewWillBeginDragging(_ scrollView: UIScrollView) {
            self.updateIsDragging(true)
        }
        
        public func scrollViewDidEndDragging(_ scrollView: UIScrollView, willDecelerate decelerate: Bool) {
            if !decelerate {
                self.updateIsDragging(false)
            }
        }
        
        public func scrollViewDidEndDecelerating(_ scrollView: UIScrollView) {
            self.updateIsDragging(false)
        }
        
        private func updateIsDragging(_ isDragging: Bool) {
            if !isDragging {
                if !self.isDragging {
                    return
                }
                
                if self.draggingStoppedTimer == nil {
                    self.draggingStoppedTimer = SwiftSignalKit.Timer(timeout: 0.8, repeat: false, completion: { [weak self] in
                        guard let strongSelf = self else {
                            return
                        }
                        strongSelf.draggingStoppedTimer = nil
                        strongSelf.isDragging = false
                        guard let environment = strongSelf.environment else {
                            return
                        }
                        environment.isExpandedUpdated(false, Transition(animation: .curve(duration: 0.3, curve: .spring)))
                    }, queue: .mainQueue())
                    self.draggingStoppedTimer?.start()
                }
            } else {
                self.draggingStoppedTimer?.invalidate()
                self.draggingStoppedTimer = nil
            
                if !self.isDragging {
                    self.isDragging = true
                    
                    guard let environment = self.environment else {
                        return
                    }
                    environment.isExpandedUpdated(true, Transition(animation: .curve(duration: 0.3, curve: .spring)))
                }
            }
        }
        
        private func updateVisibleItems(attemptSynchronousLoads: Bool, transition: Transition) {
            guard let component = self.component, let itemLayout = self.itemLayout else {
                return
            }
            
            var visibleBounds = self.scrollView.bounds
            visibleBounds.size.width += 200.0
            
            var validIds = Set<AnyHashable>()
            let visibleItemRange = itemLayout.visibleItemRange(for: visibleBounds)
            if !component.items.isEmpty && visibleItemRange.maxIndex >= visibleItemRange.minIndex {
                for index in visibleItemRange.minIndex ... visibleItemRange.maxIndex {
                    let item = component.items[index]
                    validIds.insert(item.id)
                    
                    var itemTransition = transition
                    let itemView: ComponentHostView<EntityKeyboardTopPanelItemEnvironment>
                    if let current = self.itemViews[item.id] {
                        itemView = current
                    } else {
                        itemTransition = .immediate
                        itemView = ComponentHostView<EntityKeyboardTopPanelItemEnvironment>()
                        self.scrollView.addSubview(itemView)
                        self.itemViews[item.id] = itemView
                    }
                    
                    let itemOuterFrame = itemLayout.contentFrame(at: index)
                    let itemSize = itemView.update(
                        transition: itemTransition,
                        component: item.content,
                        environment: {
                            EntityKeyboardTopPanelItemEnvironment(isExpanded: itemLayout.isExpanded)
                        },
                        containerSize: itemOuterFrame.size
                    )
                    let itemFrame = CGRect(origin: CGPoint(x: itemOuterFrame.minX + floor((itemOuterFrame.width - itemSize.width) / 2.0), y: itemOuterFrame.minY + floor((itemOuterFrame.height - itemSize.height) / 2.0)), size: itemSize)
                    /*if index == visibleItemRange.minIndex, !itemTransition.animation.isImmediate {
                        print("\(index): \(itemView.frame) -> \(itemFrame)")
                    }*/
                    itemTransition.setFrame(view: itemView, frame: itemFrame)
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
            
            if let defaultActiveItemId = component.defaultActiveItemId {
                self.activeContentItemId = defaultActiveItemId
            }
            
            let panelEnvironment = environment[EntityKeyboardTopContainerPanelEnvironment.self].value
            self.environment = panelEnvironment
            
            let isExpanded = availableSize.height > 41.0
            let wasExpanded = self.isExpanded
            self.isExpanded = isExpanded
            
            let intrinsicHeight: CGFloat = availableSize.height
            let height = intrinsicHeight
            
            let previousItemLayout = self.itemLayout
            let itemLayout = ItemLayout(itemCount: component.items.count, isExpanded: isExpanded, height: availableSize.height)
            self.itemLayout = itemLayout
            
            self.ignoreScrolling = true
            
            var updatedBounds: CGRect?
            if wasExpanded != isExpanded, let previousItemLayout = previousItemLayout {
                var visibleBounds = self.scrollView.bounds
                visibleBounds.size.width += 200.0
                
                let previousVisibleRange = previousItemLayout.visibleItemRange(for: visibleBounds)
                if previousVisibleRange.minIndex <= previousVisibleRange.maxIndex {
                    let previousItemFrame = previousItemLayout.containerFrame(at: previousVisibleRange.minIndex)
                    let updatedItemFrame = itemLayout.containerFrame(at: previousVisibleRange.minIndex)
                    
                    let previousDistanceToItem = (previousItemFrame.minX - self.scrollView.bounds.minX)// / previousItemFrame.width
                    let newBounds = CGRect(origin: CGPoint(x: updatedItemFrame.minX - previousDistanceToItem/* * updatedItemFrame.width)*/, y: 0.0), size: availableSize)
                    updatedBounds = newBounds
                    
                    var updatedVisibleBounds = newBounds
                    updatedVisibleBounds.size.width += 200.0
                    let updatedVisibleRange = itemLayout.visibleItemRange(for: updatedVisibleBounds)
                    
                    let baseFrame = CGRect(origin: CGPoint(x: updatedItemFrame.minX, y: previousItemFrame.minY), size: previousItemFrame.size)
                    for index in updatedVisibleRange.minIndex ..< updatedVisibleRange.maxIndex {
                        let indexDifference = index - previousVisibleRange.minIndex
                        if let itemView = self.itemViews[component.items[index].id] {
                            let itemContainerOriginX = baseFrame.minX + CGFloat(indexDifference) * (previousItemLayout.itemSize.width + previousItemLayout.itemSpacing)
                            let itemContainerFrame = CGRect(origin: CGPoint(x: itemContainerOriginX, y: baseFrame.minY), size: baseFrame.size)
                            let itemOuterFrame = previousItemLayout.contentFrame(containerFrame: itemContainerFrame)
                            
                            let itemSize = itemView.bounds.size
                            itemView.frame = CGRect(origin: CGPoint(x: itemOuterFrame.minX + floor((itemOuterFrame.width - itemSize.width) / 2.0), y: itemOuterFrame.minY + floor((itemOuterFrame.height - itemSize.height) / 2.0)), size: itemSize)
                        }
                    }
                }
            }
            
            if self.scrollView.contentSize != itemLayout.contentSize {
                self.scrollView.contentSize = itemLayout.contentSize
            }
            if let updatedBounds = updatedBounds {
                self.scrollView.bounds = updatedBounds
            } else {
                self.scrollView.bounds = CGRect(origin: self.scrollView.bounds.origin, size: availableSize)
            }
            self.ignoreScrolling = false
            
            self.updateVisibleItems(attemptSynchronousLoads: !(self.scrollView.isDragging || self.scrollView.isDecelerating), transition: transition)
            
            if let activeContentItemId = self.activeContentItemId {
                if let index = component.items.firstIndex(where: { $0.id == activeContentItemId }) {
                    let itemFrame = itemLayout.containerFrame(at: index)
                    transition.setPosition(view: self.highlightedIconBackgroundView, position: CGPoint(x: itemFrame.midX, y: itemFrame.midY))
                    transition.setBounds(view: self.highlightedIconBackgroundView, bounds: CGRect(origin: CGPoint(), size: itemFrame.size))
                }
            }
            transition.setAlpha(view: self.highlightedIconBackgroundView, alpha: isExpanded ? 0.0 : 1.0)
            
            panelEnvironment.visibilityFractionUpdated.connect { [weak self] (fraction, transition) in
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
            
            self.activeContentItemId = itemId

            var found = false
            for i in 0 ..< component.items.count {
                if component.items[i].id == itemId {
                    found = true
                    self.highlightedIconBackgroundView.isHidden = false
                    let itemFrame = itemLayout.containerFrame(at: i)
                    transition.setPosition(view: self.highlightedIconBackgroundView, position: CGPoint(x: itemFrame.midX, y: itemFrame.midY))
                    transition.setBounds(view: self.highlightedIconBackgroundView, bounds: CGRect(origin: CGPoint(), size: itemFrame.size))
                    
                    self.scrollView.scrollRectToVisible(itemFrame.insetBy(dx: -6.0, dy: 0.0), animated: true)
                    
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
