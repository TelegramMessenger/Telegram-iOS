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
import AsyncDisplayKit
import ComponentDisplayAdapters
import LottieAnimationComponent
import EmojiStatusComponent
import LottieComponent
import LottieComponentEmojiContent
import AudioToolbox

private final class RoundMaskView: UIImageView {
    private var currentDiameter: CGFloat?
    
    func update(diameter: CGFloat) {
        if self.currentDiameter != diameter {
            self.currentDiameter = diameter
            
            let shadowWidth: CGFloat = 6.0
            self.image = generateImage(CGSize(width: shadowWidth * 2.0 + diameter, height: diameter), rotatedContext: { size, context in
                context.clear(CGRect(origin: CGPoint(), size: size))
                
                let shadowColor = UIColor.black

                let stepCount = 10
                var colors: [CGColor] = []
                var locations: [CGFloat] = []

                for i in 0 ... stepCount {
                    let t = CGFloat(i) / CGFloat(stepCount)
                    colors.append(shadowColor.withAlphaComponent(t * t).cgColor)
                    locations.append(t)
                }

                let gradient = CGGradient(colorsSpace: deviceColorSpace, colors: colors as CFArray, locations: &locations)!
                
                let center = CGPoint(x: size.width / 2.0, y: size.height / 2.0)
                let gradientWidth = shadowWidth
                context.drawRadialGradient(gradient, startCenter: center, startRadius: size.width / 2.0, endCenter: center, endRadius: size.width / 2.0 - gradientWidth, options: [])
                
                context.setFillColor(shadowColor.cgColor)
                context.fillEllipse(in: CGRect(origin: CGPoint(x: shadowWidth, y: 0.0), size: CGSize(width: size.height, height: size.height)).insetBy(dx: -0.5, dy: -0.5))
            })?.stretchableImage(withLeftCapWidth: Int(shadowWidth * 0.5 + diameter * 0.5), topCapHeight: Int(diameter * 0.5))
        }
    }
}

private final class HoldGestureRecognizer: UITapGestureRecognizer {
    private var currentHighlightPoint: CGPoint?
    var updateHighlight: ((CGPoint?) -> Void)?
    
    override var state: UIGestureRecognizer.State {
        didSet {
            print("set state \(self.state)")
        }
    }
    
    override func reset() {
        super.reset()
        
        if let _ = self.currentHighlightPoint {
            self.currentHighlightPoint = nil
            self.updateHighlight?(nil)
        }
    }
    
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent) {
        super.touchesBegan(touches, with: event)
        
        let point = touches.first?.location(in: self.view)
        if self.currentHighlightPoint == nil {
            self.currentHighlightPoint = point
            self.updateHighlight?(point)
        }
    }
    
    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent) {
        super.touchesEnded(touches, with: event)
    }
    
    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent) {
        super.touchesCancelled(touches, with: event)
    }
}

final class EmojiSearchSearchBarComponent: Component {
    enum TextInputState: Equatable {
        case inactive
        case active(hasText: Bool)
    }
    
    let context: AccountContext
    let theme: PresentationTheme
    let strings: PresentationStrings
    let useOpaqueTheme: Bool
    let textInputState: TextInputState
    let categories: EmojiSearchCategories?
    let searchTermUpdated: ([String]?) -> Void
    let activateTextInput: () -> Void

    init(
        context: AccountContext,
        theme: PresentationTheme,
        strings: PresentationStrings,
        useOpaqueTheme: Bool,
        textInputState: TextInputState,
        categories: EmojiSearchCategories?,
        searchTermUpdated: @escaping ([String]?) -> Void,
        activateTextInput: @escaping () -> Void
    ) {
        self.context = context
        self.theme = theme
        self.strings = strings
        self.useOpaqueTheme = useOpaqueTheme
        self.textInputState = textInputState
        self.categories = categories
        self.searchTermUpdated = searchTermUpdated
        self.activateTextInput = activateTextInput
    }
    
    static func ==(lhs: EmojiSearchSearchBarComponent, rhs: EmojiSearchSearchBarComponent) -> Bool {
        if lhs.theme !== rhs.theme {
            return false
        }
        if lhs.strings !== rhs.strings {
            return false
        }
        if lhs.useOpaqueTheme != rhs.useOpaqueTheme {
            return false
        }
        if lhs.textInputState != rhs.textInputState {
            return false
        }
        if lhs.categories != rhs.categories {
            return false
        }
        return true
    }
    
    private struct ItemLayout {
        let containerSize: CGSize
        let itemCount: Int
        let itemSize: CGSize
        let itemSpacing: CGFloat
        let contentSize: CGSize
        let leftInset: CGFloat
        let rightInset: CGFloat
        let itemStartX: CGFloat
        
        let textSpacing: CGFloat
        let textFrame: CGRect
        
        init(containerSize: CGSize, textSize: CGSize, itemCount: Int) {
            self.containerSize = containerSize
            self.itemCount = itemCount
            self.itemSpacing = 11.0
            self.leftInset = 8.0
            self.rightInset = 8.0
            self.itemSize = CGSize(width: 24.0, height: 24.0)
            self.textSpacing = 11.0
            
            self.textFrame = CGRect(origin: CGPoint(x: self.leftInset, y: floor((containerSize.height - textSize.height) * 0.5)), size: textSize)
            
            let itemsWidth: CGFloat = self.itemSize.width * CGFloat(self.itemCount) + self.itemSpacing * CGFloat(max(0, self.itemCount - 1))
            
            var itemStartX = self.textFrame.maxX + self.textSpacing
            if itemStartX + itemsWidth + self.rightInset < containerSize.width {
                itemStartX = containerSize.width - self.rightInset - itemsWidth
            }
            
            self.itemStartX = itemStartX
            
            self.contentSize = CGSize(width: self.itemStartX + itemsWidth + self.rightInset, height: containerSize.height)
        }
        
        func visibleItems(for rect: CGRect) -> Range<Int>? {
            let baseItemX: CGFloat = self.itemStartX
            let offsetRect = rect.offsetBy(dx: -baseItemX, dy: 0.0)
            var minVisibleIndex = Int(floor((offsetRect.minX - self.itemSpacing) / (self.itemSize.width + self.itemSpacing)))
            minVisibleIndex = max(0, minVisibleIndex)
            var maxVisibleIndex = Int(ceil((offsetRect.maxX - self.itemSpacing) / (self.itemSize.height + self.itemSpacing)))
            maxVisibleIndex = min(maxVisibleIndex, self.itemCount - 1)
            
            if minVisibleIndex <= maxVisibleIndex {
                return minVisibleIndex ..< (maxVisibleIndex + 1)
            } else {
                return nil
            }
        }
        
        func frame(at index: Int) -> CGRect {
            return CGRect(origin: CGPoint(x: self.itemStartX + CGFloat(index) * (self.itemSize.width + self.itemSpacing), y: floor((self.containerSize.height - self.itemSize.height) * 0.5)), size: self.itemSize)
        }
    }
    
    private final class ContentScrollView: UIScrollView, PagerExpandableScrollView {
        override static var layerClass: AnyClass {
            return EmojiPagerContentComponent.View.ContentScrollLayer.self
        }
        
        private let mirrorView: UIView
        
        init(mirrorView: UIView) {
            self.mirrorView = mirrorView
            
            super.init(frame: CGRect())
            
            (self.layer as? EmojiPagerContentComponent.View.ContentScrollLayer)?.mirrorLayer = mirrorView.layer
            self.canCancelContentTouches = true
        }
        
        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }
        
        override func touchesShouldCancel(in view: UIView) -> Bool {
            return true
        }
    }
    
    private final class ItemView {
        let view = ComponentView<Empty>()
        let tintView = UIImageView()
        
        init() {
        }
    }
    
    final class View: UIView, UIScrollViewDelegate {
        let tintContainerView: UIView
        private let scrollView: ContentScrollView
        private let tintScrollView: UIView
        
        private let textView = ComponentView<Empty>()
        private let textContainerView: UIView
        
        private let tintTextView = ComponentView<Empty>()
        private let tintTextContainerView: UIView
        
        private var visibleItemViews: [AnyHashable: ItemView] = [:]
        private let selectedItemBackground: SimpleLayer
        private let selectedItemTintBackground: SimpleLayer
        
        private var component: EmojiSearchSearchBarComponent?
        private weak var componentState: EmptyComponentState?
        
        private var itemLayout: ItemLayout?
        private var ignoreScrolling: Bool = false
        
        private let roundMaskView: RoundMaskView
        private let tintRoundMaskView: RoundMaskView
        
        private var highlightedItem: AnyHashable?
        private var selectedItem: AnyHashable?
        
        private lazy var hapticFeedback: HapticFeedback = {
            return HapticFeedback()
        }()
        
        override init(frame: CGRect) {
            self.tintContainerView = UIView()
            
            self.tintScrollView = UIView()
            self.tintScrollView.clipsToBounds = true
            self.scrollView = ContentScrollView(mirrorView: self.tintScrollView)
            
            self.textContainerView = UIView()
            self.textContainerView.isUserInteractionEnabled = false
            self.tintTextContainerView = UIView()
            self.tintTextContainerView.isUserInteractionEnabled = false
            
            self.roundMaskView = RoundMaskView()
            self.tintRoundMaskView = RoundMaskView()
            
            self.selectedItemBackground = SimpleLayer()
            self.selectedItemTintBackground = SimpleLayer()
            
            super.init(frame: frame)
            
            self.scrollView.delaysContentTouches = false
            if #available(iOSApplicationExtension 11.0, iOS 11.0, *) {
                self.scrollView.contentInsetAdjustmentBehavior = .never
            }
            if #available(iOS 13.0, *) {
                self.scrollView.automaticallyAdjustsScrollIndicatorInsets = false
            }
            self.scrollView.showsVerticalScrollIndicator = true
            self.scrollView.showsHorizontalScrollIndicator = false
            self.scrollView.delegate = self
            self.scrollView.clipsToBounds = true
            self.scrollView.scrollsToTop = false
            
            self.addSubview(self.scrollView)
            self.addSubview(self.textContainerView)
            
            self.tintContainerView.addSubview(self.tintScrollView)
            self.tintContainerView.addSubview(self.tintTextContainerView)
            
            self.mask = self.roundMaskView
            self.tintContainerView.mask = self.tintRoundMaskView
            
            self.scrollView.layer.addSublayer(self.selectedItemBackground)
            self.tintScrollView.layer.addSublayer(self.selectedItemTintBackground)
            
            let tapRecognizer = HoldGestureRecognizer(target: self, action: #selector(self.tapGesture(_:)))
            tapRecognizer.updateHighlight = { [weak self] point in
                guard let self else {
                    return
                }
                var highlightedItem: AnyHashable?
                
                if let point = point {
                    let location = self.convert(point, to: self.scrollView)
                    for (id, itemView) in self.visibleItemViews {
                        if let itemComponentView = itemView.view.view, itemComponentView.frame.contains(location) {
                            highlightedItem = id
                            break
                        }
                    }
                }
                
                if self.highlightedItem != highlightedItem {
                    self.highlightedItem = highlightedItem
                    self.componentState?.updated(transition: .easeInOut(duration: 0.2))
                }
            }
            self.addGestureRecognizer(tapRecognizer)
        }
        
        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }
        
        @objc private func tapGesture(_ recognizer: UITapGestureRecognizer) {
            if case .ended = recognizer.state {
                guard let component = self.component, let itemLayout = self.itemLayout else {
                    return
                }
                let location = recognizer.location(in: self.scrollView)
                if (component.categories?.groups ?? []).isEmpty || location.x <= itemLayout.itemStartX - itemLayout.textSpacing {
                    component.activateTextInput()
                } else {
                    for (id, itemView) in self.visibleItemViews {
                        if let itemComponentView = itemView.view.view, itemComponentView.frame.contains(location), let itemId = id.base as? Int64 {
                            if self.selectedItem == AnyHashable(id) {
                                self.selectedItem = nil
                            } else {
                                self.selectedItem = AnyHashable(id)
                                AudioServicesPlaySystemSound(0x450)
                                self.hapticFeedback.tap()
                            }
                            self.componentState?.updated(transition: .easeInOut(duration: 0.2))
                            
                            if let _ = self.selectedItem, let categories = component.categories, let group = categories.groups.first(where: { $0.id == itemId }) {
                                component.searchTermUpdated(group.identifiers)
                                
                                if let itemComponentView = itemView.view.view {
                                    var offset = self.scrollView.contentOffset.x
                                    let maxDistance: CGFloat = 44.0
                                    if itemComponentView.frame.maxX - offset > self.scrollView.bounds.width - maxDistance {
                                        offset = itemComponentView.frame.maxX - (self.scrollView.bounds.width - maxDistance)
                                    }
                                    if itemComponentView.frame.minX - offset < maxDistance {
                                        offset = itemComponentView.frame.minX - maxDistance
                                    }
                                    offset = max(0.0, min(offset, self.scrollView.contentSize.width - self.scrollView.bounds.width))
                                    if offset != self.scrollView.contentOffset.x {
                                        self.scrollView.setContentOffset(CGPoint(x: offset, y: 0.0), animated: true)
                                    }
                                }
                            } else {
                                let transition = Transition(animation: .curve(duration: 0.4, curve: .spring))
                                transition.setBoundsOrigin(view: self.scrollView, origin: CGPoint())
                                self.updateScrolling(transition: transition, fromScrolling: false)
                                //self.scrollView.setContentOffset(CGPoint(), animated: true)
                                
                                component.searchTermUpdated(nil)
                            }
                            
                            break
                        }
                    }
                }
            }
        }
        
        func clearSelection(dispatchEvent: Bool) {
            if self.selectedItem != nil {
                self.selectedItem = nil
                
                let transition = Transition(animation: .curve(duration: 0.4, curve: .spring))
                transition.setBoundsOrigin(view: self.scrollView, origin: CGPoint())
                self.updateScrolling(transition: transition, fromScrolling: false)
                
                self.componentState?.updated(transition: transition)
                
                if dispatchEvent {
                    self.component?.searchTermUpdated(nil)
                }
            }
        }
        
        func scrollViewDidScroll(_ scrollView: UIScrollView) {
            if !self.ignoreScrolling {
                self.updateScrolling(transition: .immediate, fromScrolling: true)
            }
        }
        
        private func updateScrolling(transition: Transition, fromScrolling: Bool) {
            guard let component = self.component, let itemLayout = self.itemLayout else {
                return
            }
            
            let itemAlpha: CGFloat
            switch component.textInputState {
            case .active:
                itemAlpha = 0.0
            case .inactive:
                itemAlpha = 1.0
            }
            
            var validItemIds = Set<AnyHashable>()
            let visibleBounds = self.scrollView.bounds
            
            var animateAppearingItems = false
            if fromScrolling {
                animateAppearingItems = true
            }
            
            let items = component.categories?.groups ?? []
            
            for i in 0 ..< items.count {
                let itemFrame = itemLayout.frame(at: i)
                if visibleBounds.intersects(itemFrame) {
                    let item = items[i]
                    validItemIds.insert(AnyHashable(item.id))
                    
                    var animateItem = false
                    var itemTransition = transition
                    let itemView: ItemView
                    if let current = self.visibleItemViews[AnyHashable(item.id)] {
                        itemView = current
                    } else {
                        animateItem = animateAppearingItems
                        itemTransition = .immediate
                        itemView = ItemView()
                        self.visibleItemViews[AnyHashable(item.id)] = itemView
                    }
                    
                    let color: UIColor
                    if component.useOpaqueTheme {
                        color = self.selectedItem == AnyHashable(item.id) ? component.theme.chat.inputMediaPanel.panelContentOpaqueSearchOverlaySelectedColor : component.theme.chat.inputMediaPanel.panelContentOpaqueSearchOverlayColor
                    } else {
                        color = self.selectedItem == AnyHashable(item.id) ? component.theme.chat.inputMediaPanel.panelContentVibrantSearchOverlaySelectedColor : component.theme.chat.inputMediaPanel.panelContentVibrantSearchOverlayColor
                    }
                    
                    let _ = itemView.view.update(
                        transition: .immediate,
                        component: AnyComponent(LottieComponent(
                            content: LottieComponent.EmojiContent(
                                context: component.context,
                                fileId: item.id
                            ),
                            color: color
                        )),
                        environment: {},
                        containerSize: itemLayout.itemSize
                    )
                    
                    itemView.tintView.tintColor = .white
                    
                    if let view = itemView.view.view as? LottieComponent.View {
                        if view.superview == nil {
                            self.scrollView.addSubview(view)
                            
                            view.output = itemView.tintView
                            self.tintScrollView.addSubview(itemView.tintView)
                        }
                        
                        itemTransition.setPosition(view: view, position: CGPoint(x: itemFrame.midX, y: itemFrame.midY))
                        itemTransition.setBounds(view: view, bounds: CGRect(origin: CGPoint(), size: CGSize(width: itemLayout.itemSize.width, height: itemLayout.itemSize.height)))
                        
                        var scaleFactor = itemFrame.width / itemLayout.itemSize.width
                        if self.highlightedItem == AnyHashable(item.id) {
                            scaleFactor *= 0.8
                        }
                        
                        itemTransition.setScale(view: view, scale: scaleFactor)
                        
                        itemTransition.setPosition(view: itemView.tintView, position: CGPoint(x: itemFrame.midX, y: itemFrame.midY))
                        itemTransition.setBounds(view: itemView.tintView, bounds: CGRect(origin: CGPoint(), size: CGSize(width: itemLayout.itemSize.width, height: itemLayout.itemSize.height)))
                        itemTransition.setScale(view: itemView.tintView, scale: scaleFactor)
                        
                        itemTransition.setAlpha(view: view, alpha: itemAlpha)
                        itemTransition.setAlpha(view: itemView.tintView, alpha: itemAlpha)
                        
                        let isHidden = !visibleBounds.intersects(itemFrame)
                        if isHidden != view.isHidden {
                            view.isHidden = isHidden
                            itemView.tintView.isHidden = true
                            
                            if !isHidden {
                                view.playOnce()
                            }
                        } else if animateItem {
                            if fromScrolling {
                                view.playOnce(delay: 0.08)
                            }
                        }
                    }
                }
            }
            
            var removedItemIds: [AnyHashable] = []
            for (id, itemView) in self.visibleItemViews {
                if !validItemIds.contains(id) {
                    removedItemIds.append(id)
                    
                    if let itemComponentView = itemView.view.view {
                        transition.attachAnimation(view: itemComponentView, id: "remove", completion: { [weak itemComponentView] _ in
                            itemComponentView?.removeFromSuperview()
                        })
                    }
                    let tintView = itemView.tintView
                    transition.attachAnimation(view: tintView, id: "remove", completion: { [weak tintView] _ in
                        tintView?.removeFromSuperview()
                    })
                    //itemView.view.view?.removeFromSuperview()
                    //itemView.tintView.removeFromSuperview()
                }
            }
            for id in removedItemIds {
                self.visibleItemViews.removeValue(forKey: id)
            }
            
            if let selectedItem = self.selectedItem, let index = items.firstIndex(where: { AnyHashable($0.id) == selectedItem }) {
                let selectedItemCenter = itemLayout.frame(at: index).center
                let selectionSize = CGSize(width: 28.0, height: 28.0)
                self.selectedItemBackground.backgroundColor = component.useOpaqueTheme ? component.theme.chat.inputMediaPanel.panelContentOpaqueSearchOverlayHighlightColor.cgColor : component.theme.chat.inputMediaPanel.panelContentVibrantSearchOverlayHighlightColor.cgColor
                self.selectedItemTintBackground.backgroundColor = UIColor(white: 1.0, alpha: 0.15).cgColor
                self.selectedItemBackground.cornerRadius = selectionSize.height * 0.5
                self.selectedItemTintBackground.cornerRadius = selectionSize.height * 0.5
                
                let selectionFrame = CGRect(origin: CGPoint(x: floor(selectedItemCenter.x - selectionSize.width * 0.5), y: floor(selectedItemCenter.y - selectionSize.height * 0.5)), size: selectionSize)
                
                self.selectedItemBackground.bounds = CGRect(origin: CGPoint(), size: selectionFrame.size)
                self.selectedItemTintBackground.bounds = CGRect(origin: CGPoint(), size: selectionFrame.size)
                
                if self.selectedItemBackground.opacity == 0.0 {
                    self.selectedItemBackground.position = selectionFrame.center
                    self.selectedItemTintBackground.position = selectionFrame.center
                    
                    self.selectedItemBackground.opacity = 1.0
                    self.selectedItemTintBackground.opacity = 1.0
                    
                    Transition.immediate.setScale(layer: self.selectedItemBackground, scale: 1.0)
                    Transition.immediate.setScale(layer: self.selectedItemTintBackground, scale: 1.0)
                    
                    if !transition.animation.isImmediate {
                        self.selectedItemBackground.animateAlpha(from: 0.0, to: 1.0, duration: 0.2)
                        self.selectedItemTintBackground.animateAlpha(from: 0.0, to: 1.0, duration: 0.2)
                        
                        self.selectedItemBackground.animateSpring(from: 0.1 as NSNumber, to: 1.0 as NSNumber, keyPath: "transform.scale", duration: 0.5, damping: 92.0)
                        self.selectedItemTintBackground.animateSpring(from: 0.1 as NSNumber, to: 1.0 as NSNumber, keyPath: "transform.scale", duration: 0.5, damping: 92.0)
                    }
                } else {
                    if self.selectedItemBackground.position != selectionFrame.center {
                        transition.setPosition(layer: self.selectedItemBackground, position: selectionFrame.center)
                        transition.setPosition(layer: self.selectedItemTintBackground, position: selectionFrame.center)
                        
                        if case let .curve(duration, _) = transition.animation {
                            Transition.immediate.setScale(layer: self.selectedItemBackground, scale: 1.0)
                            Transition.immediate.setScale(layer: self.selectedItemTintBackground, scale: 1.0)
                            
                            self.selectedItemBackground.animateKeyframes(values: [1.0 as NSNumber, 0.75 as NSNumber, 1.0 as NSNumber], duration: duration, keyPath: "transform.scale")
                            self.selectedItemTintBackground.animateKeyframes(values: [1.0 as NSNumber, 0.75 as NSNumber, 1.0 as NSNumber], duration: duration, keyPath: "transform.scale")
                        } else {
                            transition.setScale(layer: self.selectedItemBackground, scale: 1.0)
                            transition.setScale(layer: self.selectedItemTintBackground, scale: 1.0)
                        }
                    }
                }
            } else {
                transition.setAlpha(layer: self.selectedItemBackground, alpha: 0.0)
                transition.setScale(layer: self.selectedItemBackground, scale: 0.8)
                transition.setAlpha(layer: self.selectedItemTintBackground, alpha: 0.0)
                transition.setScale(layer: self.selectedItemTintBackground, scale: 0.8)
            }
            
            let scrollBounds = self.scrollView.bounds
            let textOffset = max(0.0, scrollBounds.minX - (itemLayout.itemStartX - itemLayout.textFrame.maxX - itemLayout.textSpacing))
            
            transition.setPosition(view: self.textContainerView, position: self.scrollView.center)
            transition.setBounds(view: self.textContainerView, bounds: CGRect(origin: CGPoint(x: textOffset, y: 0.0), size: scrollBounds.size))
            
            transition.setPosition(view: self.tintTextContainerView, position: self.scrollView.center)
            transition.setBounds(view: self.tintTextContainerView, bounds: CGRect(origin: CGPoint(x: textOffset, y: 0.0), size: scrollBounds.size))
        }
        
        func update(component: EmojiSearchSearchBarComponent, availableSize: CGSize, state: EmptyComponentState, environment: Environment<Empty>, transition: Transition) -> CGSize {
            self.component = component
            self.componentState = state
            
            let textSize = self.textView.update(
                transition: .immediate,
                component: AnyComponent(Text(
                    text: component.strings.Common_Search,
                    font: Font.regular(17.0),
                    color: component.useOpaqueTheme ? component.theme.chat.inputMediaPanel.panelContentOpaqueSearchOverlayColor : component.theme.chat.inputMediaPanel.panelContentVibrantSearchOverlayColor
                )),
                environment: {},
                containerSize: CGSize(width: availableSize.width - 32.0, height: 100.0)
            )
            let _ = self.tintTextView.update(
                transition: .immediate,
                component: AnyComponent(Text(
                    text: component.strings.Common_Search,
                    font: Font.regular(17.0),
                    color: .white
                )),
                environment: {},
                containerSize: CGSize(width: availableSize.width - 32.0, height: 100.0)
            )
            
            let itemLayout = ItemLayout(containerSize: availableSize, textSize: textSize, itemCount: component.categories?.groups.count ?? 0)
            self.itemLayout = itemLayout
            
            if let textComponentView = self.textView.view {
                if textComponentView.superview == nil {
                    self.textContainerView.addSubview(textComponentView)
                }
                transition.setFrame(view: textComponentView, frame: itemLayout.textFrame)
            }
            if let tintTextComponentView = self.tintTextView.view {
                if tintTextComponentView.superview == nil {
                    self.tintTextContainerView.addSubview(tintTextComponentView)
                }
                transition.setFrame(view: tintTextComponentView, frame: itemLayout.textFrame)
            }
            
            self.ignoreScrolling = true
            if self.scrollView.bounds.size != availableSize {
                transition.setFrame(view: self.scrollView, frame: CGRect(origin: CGPoint(), size: availableSize))
            }
            if case .active = component.textInputState {
                transition.setBoundsOrigin(view: self.scrollView, origin: CGPoint())
            }
            if self.scrollView.contentSize != itemLayout.contentSize {
                self.scrollView.contentSize = itemLayout.contentSize
            }
            self.ignoreScrolling = false
            
            let maskFrame = CGRect(origin: CGPoint(), size: availableSize)
            transition.setFrame(view: self.roundMaskView, frame: maskFrame)
            self.roundMaskView.update(diameter: maskFrame.height)
            transition.setFrame(view: self.tintRoundMaskView, frame: maskFrame)
            self.tintRoundMaskView.update(diameter: maskFrame.height)
            
            self.updateScrolling(transition: transition, fromScrolling: false)
            
            switch component.textInputState {
            case let .active(hasText):
                self.isUserInteractionEnabled = false
                self.textView.view?.isHidden = hasText
                self.tintTextView.view?.isHidden = hasText
            case .inactive:
                self.isUserInteractionEnabled = true
                self.textView.view?.isHidden = false
                self.tintTextView.view?.isHidden = false
            }
            
            return availableSize
        }
    }
    
    func makeView() -> View {
        return View(frame: CGRect())
    }
    
    func update(view: View, availableSize: CGSize, state: EmptyComponentState, environment: Environment<Empty>, transition: Transition) -> CGSize {
        return view.update(component: self, availableSize: availableSize, state: state, environment: environment, transition: transition)
    }
}
