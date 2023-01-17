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

final class EmojiSearchSearchBarComponent: Component {
    let theme: PresentationTheme
    let strings: PresentationStrings
    let searchTermUpdated: (String?) -> Void

    init(
        theme: PresentationTheme,
        strings: PresentationStrings,
        searchTermUpdated: @escaping (String?) -> Void
    ) {
        self.theme = theme
        self.strings = strings
        self.searchTermUpdated = searchTermUpdated
    }
    
    static func ==(lhs: EmojiSearchSearchBarComponent, rhs: EmojiSearchSearchBarComponent) -> Bool {
        if lhs.theme !== rhs.theme {
            return false
        }
        if lhs.strings !== rhs.strings {
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
        let sideInset: CGFloat
        
        init(containerSize: CGSize, itemCount: Int) {
            self.containerSize = containerSize
            self.itemCount = itemCount
            self.itemSpacing = 8.0
            self.sideInset = 8.0
            self.itemSize = CGSize(width: 24.0, height: 24.0)
            
            self.contentSize = CGSize(width: self.sideInset * 2.0 + self.itemSize.width * CGFloat(self.itemCount) + self.itemSpacing * CGFloat(max(0, self.itemCount - 1)), height: containerSize.height)
        }
        
        func visibleItems(for rect: CGRect) -> Range<Int>? {
            let offsetRect = rect.offsetBy(dx: -self.sideInset, dy: 0.0)
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
            return CGRect(origin: CGPoint(x: self.sideInset + CGFloat(index) * (self.itemSize.width + self.itemSpacing), y: floor((self.containerSize.height - self.itemSize.height) * 0.5)), size: self.itemSize)
        }
    }
    
    final class View: UIView, UIScrollViewDelegate {
        private let scrollView: UIScrollView
        
        private var visibleItemViews: [AnyHashable: ComponentView<Empty>] = [:]
        private let selectedItemBackground: SimpleLayer
        
        private var items: [String] = []
        
        private var component: EmojiSearchSearchBarComponent?
        private weak var state: EmptyComponentState?
        
        private var itemLayout: ItemLayout?
        private var ignoreScrolling: Bool = false
        
        private let maskLayer: SimpleLayer
        
        private var selectedItem: String?
        
        override init(frame: CGRect) {
            self.scrollView = UIScrollView()
            self.maskLayer = SimpleLayer()
            
            self.selectedItemBackground = SimpleLayer()
            
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
            self.scrollView.clipsToBounds = false
            self.scrollView.scrollsToTop = false
            
            self.addSubview(self.scrollView)
            
            //self.layer.mask = self.maskLayer
            self.layer.addSublayer(self.maskLayer)
            self.layer.masksToBounds = true
            
            self.scrollView.layer.addSublayer(self.selectedItemBackground)
            
            self.scrollView.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(self.tapGesture(_:))))
            
            self.items = ["Smile", "🤔", "😝", "😡", "😐", "🏌️‍♀️", "🎉", "😨", "❤️", "😄", "👍", "☹️", "👎", "⛔", "💤", "💼", "🍔", "🏠", "🛁", "🏖", "⚽️", "🕔"]
        }
        
        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }
        
        @objc private func tapGesture(_ recognizer: UITapGestureRecognizer) {
            if case .ended = recognizer.state {
                let location = recognizer.location(in: self.scrollView)
                for (id, itemView) in self.visibleItemViews {
                    if let itemComponentView = itemView.view, itemComponentView.frame.contains(location), let item = id.base as? String {
                        if self.selectedItem == item {
                            self.selectedItem = nil
                        } else {
                            self.selectedItem = item
                        }
                        self.state?.updated(transition: .immediate)
                        self.component?.searchTermUpdated(self.selectedItem)
                        
                        break
                    }
                }
            }
        }
        
        func clearSelection(dispatchEvent: Bool) {
            if self.selectedItem != nil {
                self.selectedItem = nil
                self.state?.updated(transition: .immediate)
                if dispatchEvent {
                    self.component?.searchTermUpdated(self.selectedItem)
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
            
            var validItemIds = Set<AnyHashable>()
            let visibleBounds = self.scrollView.bounds
            
            var animateAppearingItems = false
            if fromScrolling {
                animateAppearingItems = true
            }
            
            let items = self.items
            
            for i in 0 ..< items.count {
                let itemFrame = itemLayout.frame(at: i)
                if visibleBounds.intersects(itemFrame) {
                    let item = items[i]
                    validItemIds.insert(AnyHashable(item))
                    
                    var animateItem = false
                    var itemTransition = transition
                    let itemView: ComponentView<Empty>
                    if let current = self.visibleItemViews[item] {
                        itemView = current
                    } else {
                        animateItem = animateAppearingItems
                        itemTransition = .immediate
                        itemView = ComponentView<Empty>()
                        self.visibleItemViews[item] = itemView
                    }
                    
                    let animationName: String
                    
                    switch EmojiPagerContentComponent.StaticEmojiSegment.allCases[i % EmojiPagerContentComponent.StaticEmojiSegment.allCases.count] {
                    case .people:
                        animationName = "emojicat_smiles"
                    case .animalsAndNature:
                        animationName = "emojicat_animals"
                    case .foodAndDrink:
                        animationName = "emojicat_food"
                    case .activityAndSport:
                        animationName = "emojicat_activity"
                    case .travelAndPlaces:
                        animationName = "emojicat_places"
                    case .objects:
                        animationName = "emojicat_objects"
                    case .symbols:
                        animationName = "emojicat_symbols"
                    case .flags:
                        animationName = "emojicat_flags"
                    }
                    
                    let baseColor: UIColor
                    baseColor = component.theme.chat.inputMediaPanel.panelIconColor
                    
                    let baseHighlightedColor = component.theme.chat.inputMediaPanel.panelHighlightedIconBackgroundColor.blitOver(component.theme.chat.inputPanel.panelBackgroundColor, alpha: 1.0)
                    let color = baseColor.blitOver(baseHighlightedColor, alpha: 1.0)
                    
                    let _ = itemTransition
                    let _ = itemView.update(
                        transition: .immediate,
                        component: AnyComponent(LottieAnimationComponent(
                            animation: LottieAnimationComponent.AnimationItem(
                                name: animationName,
                                mode: .still(position: .end)
                            ),
                            colors: ["__allcolors__": color],
                            size: itemLayout.itemSize
                        )),
                        environment: {},
                        containerSize: itemLayout.itemSize
                    )
                    if let view = itemView.view {
                        if view.superview == nil {
                            self.scrollView.addSubview(view)
                        }
                        
                        itemTransition.setPosition(view: view, position: CGPoint(x: itemFrame.midX, y: itemFrame.midY))
                        itemTransition.setBounds(view: view, bounds: CGRect(origin: CGPoint(), size: CGSize(width: itemLayout.itemSize.width, height: itemLayout.itemSize.height)))
                        let scaleFactor = itemFrame.width / itemLayout.itemSize.width
                        itemTransition.setSublayerTransform(view: view, transform: CATransform3DMakeScale(scaleFactor, scaleFactor, 1.0))
                        
                        let isHidden = !visibleBounds.intersects(itemFrame)
                        if isHidden != view.isHidden {
                            view.isHidden = isHidden
                            
                            if !isHidden {
                                if let view = view as? LottieAnimationComponent.View {
                                    view.playOnce()
                                }
                            }
                        } else if animateItem {
                            if let view = view as? LottieAnimationComponent.View {
                                view.playOnce()
                            }
                        }
                    }
                }
            }
            
            var removedItemIds: [AnyHashable] = []
            for (id, itemView) in self.visibleItemViews {
                if !validItemIds.contains(id) {
                    removedItemIds.append(id)
                    itemView.view?.removeFromSuperview()
                }
            }
            for id in removedItemIds {
                self.visibleItemViews.removeValue(forKey: id)
            }
            
            if let selectedItem = self.selectedItem, let index = self.items.firstIndex(of: selectedItem) {
                self.selectedItemBackground.isHidden = false
                
                let selectedItemCenter = itemLayout.frame(at: index).center
                let selectionSize = CGSize(width: 28.0, height: 28.0)
                
                self.selectedItemBackground.backgroundColor = component.theme.chat.inputMediaPanel.panelContentControlOpaqueSelectionColor.cgColor
                self.selectedItemBackground.cornerRadius = selectionSize.height * 0.5
                
                self.selectedItemBackground.frame = CGRect(origin: CGPoint(x: floor(selectedItemCenter.x - selectionSize.width * 0.5), y: floor(selectedItemCenter.y - selectionSize.height * 0.5)), size: selectionSize)
            } else {
                self.selectedItemBackground.isHidden = true
            }
        }
        
        func update(component: EmojiSearchSearchBarComponent, availableSize: CGSize, state: EmptyComponentState, environment: Environment<Empty>, transition: Transition) -> CGSize {
            self.component = component
            self.state = state
            
            transition.setCornerRadius(layer: self.layer, cornerRadius: availableSize.height * 0.5)
            
            let itemLayout = ItemLayout(containerSize: availableSize, itemCount: self.items.count)
            self.itemLayout = itemLayout
            
            self.ignoreScrolling = true
            if self.scrollView.bounds.size != availableSize {
                transition.setFrame(view: self.scrollView, frame: CGRect(origin: CGPoint(), size: availableSize))
            }
            if self.scrollView.contentSize != itemLayout.contentSize {
                self.scrollView.contentSize = itemLayout.contentSize
            }
            self.ignoreScrolling = false
            
            self.updateScrolling(transition: transition, fromScrolling: false)
            
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
