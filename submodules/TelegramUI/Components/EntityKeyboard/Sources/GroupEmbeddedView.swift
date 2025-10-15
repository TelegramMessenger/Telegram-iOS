import Foundation
import UIKit
import Display
import ComponentFlow
import AccountContext
import TelegramPresentationData
import AnimationCache
import MultiAnimationRenderer
import PagerComponent

final class GroupEmbeddedView: UIScrollView, UIScrollViewDelegate, PagerExpandableScrollView {
    private struct ItemLayout {
        var itemSize: CGFloat
        var itemSpacing: CGFloat
        var sideInset: CGFloat
        var itemCount: Int
        var contentSize: CGSize
        
        init(height: CGFloat, sideInset: CGFloat, itemCount: Int) {
            self.itemSize = 30.0
            self.itemSpacing = 20.0
            self.sideInset = sideInset
            self.itemCount = itemCount
            
            self.contentSize = CGSize(width: self.sideInset * 2.0 + CGFloat(self.itemCount) * self.itemSize + CGFloat(self.itemCount - 1) * self.itemSpacing, height: height)
        }
        
        func frame(at index: Int) -> CGRect {
            return CGRect(origin: CGPoint(x: sideInset + CGFloat(index) * (self.itemSize + self.itemSpacing), y: floor((self.contentSize.height - self.itemSize) / 2.0)), size: CGSize(width: self.itemSize, height: self.itemSize))
        }
        
        func visibleItems(for rect: CGRect) -> Range<Int>? {
            let offsetRect = rect.offsetBy(dx: -self.sideInset, dy: 0.0)
            var minVisibleIndex = Int(floor((offsetRect.minX - self.itemSpacing) / (self.itemSize + self.itemSpacing)))
            minVisibleIndex = max(0, minVisibleIndex)
            var maxVisibleIndex = Int(ceil((offsetRect.maxX - self.itemSpacing) / (self.itemSize + self.itemSpacing)))
            maxVisibleIndex = min(maxVisibleIndex, self.itemCount - 1)
            
            if minVisibleIndex <= maxVisibleIndex {
                return minVisibleIndex ..< (maxVisibleIndex + 1)
            } else {
                return nil
            }
        }
    }
    
    private let performItemAction: (EmojiPagerContentComponent.Item, UIView, CGRect, CALayer) -> Void
    
    private var visibleItemLayers: [EmojiKeyboardItemLayer.Key: EmojiKeyboardItemLayer] = [:]
    private var ignoreScrolling: Bool = false
    
    private var context: AccountContext?
    private var theme: PresentationTheme?
    private var cache: AnimationCache?
    private var renderer: MultiAnimationRenderer?
    private var currentInsets: UIEdgeInsets?
    private var currentSize: CGSize?
    private var items: [EmojiPagerContentComponent.Item]?
    private var isStickers: Bool = false
    
    private var itemLayout: ItemLayout?
    
    init(performItemAction: @escaping (EmojiPagerContentComponent.Item, UIView, CGRect, CALayer) -> Void) {
        self.performItemAction = performItemAction
        
        super.init(frame: CGRect())
        
        self.delaysContentTouches = false
        if #available(iOSApplicationExtension 11.0, iOS 11.0, *) {
            self.contentInsetAdjustmentBehavior = .never
        }
        if #available(iOS 13.0, *) {
            self.automaticallyAdjustsScrollIndicatorInsets = false
        }
        self.showsVerticalScrollIndicator = true
        self.showsHorizontalScrollIndicator = false
        self.delegate = self
        self.clipsToBounds = true
        self.scrollsToTop = false
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    func tapGesture(point: CGPoint) -> Bool {
        guard let itemLayout = self.itemLayout else {
            return false
        }

        for (_, itemLayer) in self.visibleItemLayers {
            if itemLayer.frame.inset(by: UIEdgeInsets(top: -6.0, left: -itemLayout.itemSpacing, bottom: -6.0, right: -itemLayout.itemSpacing)).contains(point) {
                self.performItemAction(itemLayer.item, self, itemLayer.frame, itemLayer)
                return true
            }
        }
        
        return false
    }
    
    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        if !self.ignoreScrolling {
            self.updateVisibleItems(transition: .immediate, attemptSynchronousLoad: false)
        }
    }
    
    private func updateVisibleItems(transition: ComponentTransition, attemptSynchronousLoad: Bool) {
        guard let context = self.context, let theme = self.theme, let itemLayout = self.itemLayout, let items = self.items, let cache = self.cache, let renderer = self.renderer else {
            return
        }
        
        var validIds = Set<EmojiKeyboardItemLayer.Key>()
        if let itemRange = itemLayout.visibleItems(for: self.bounds) {
            for index in itemRange.lowerBound ..< itemRange.upperBound {
                let item = items[index]
                let itemId = EmojiKeyboardItemLayer.Key(
                    groupId: AnyHashable(0),
                    itemId: item.content.id
                )
                validIds.insert(itemId)
                
                let itemLayer: EmojiKeyboardItemLayer
                if let current = self.visibleItemLayers[itemId] {
                    itemLayer = current
                } else {
                    itemLayer = EmojiKeyboardItemLayer(
                        item: item,
                        context: context,
                        attemptSynchronousLoad: attemptSynchronousLoad,
                        content: item.content,
                        cache: cache,
                        renderer: renderer,
                        placeholderColor: .clear,
                        blurredBadgeColor: .clear,
                        accentIconColor: theme.list.itemAccentColor,
                        pointSize: CGSize(width: 32.0, height: 32.0),
                        onUpdateDisplayPlaceholder: { _, _ in
                        }
                    )
                    self.visibleItemLayers[itemId] = itemLayer
                    self.layer.addSublayer(itemLayer)
                }
                
                switch item.tintMode {
                case let .custom(color):
                    itemLayer.layerTintColor = color.cgColor
                case .accent:
                    itemLayer.layerTintColor = theme.list.itemAccentColor.cgColor
                case .primary:
                    itemLayer.layerTintColor = theme.list.itemPrimaryTextColor.cgColor
                case .none:
                    itemLayer.layerTintColor = nil
                }
                
                let itemFrame = itemLayout.frame(at: index)
                itemLayer.frame = itemFrame
                
                itemLayer.isVisibleForAnimations = self.isStickers ? context.sharedContext.energyUsageSettings.loopStickers : context.sharedContext.energyUsageSettings.loopEmoji
            }
        }
        
        var removedIds: [EmojiKeyboardItemLayer.Key] = []
        for (id, itemLayer) in self.visibleItemLayers {
            if !validIds.contains(id) {
                removedIds.append(id)
                itemLayer.removeFromSuperlayer()
            }
        }
        for id in removedIds {
            self.visibleItemLayers.removeValue(forKey: id)
        }
    }
    
    func update(
        context: AccountContext,
        theme: PresentationTheme,
        insets: UIEdgeInsets,
        size: CGSize,
        items: [EmojiPagerContentComponent.Item],
        isStickers: Bool,
        cache: AnimationCache,
        renderer: MultiAnimationRenderer,
        attemptSynchronousLoad: Bool
    ) {
        if self.theme === theme && self.currentInsets == insets && self.currentSize == size && self.items == items {
            return
        }
        
        self.context = context
        self.theme = theme
        self.currentInsets = insets
        self.currentSize = size
        self.items = items
        self.isStickers = isStickers
        self.cache = cache
        self.renderer = renderer
        
        let itemLayout = ItemLayout(height: size.height, sideInset: insets.left, itemCount: items.count)
        self.itemLayout = itemLayout
        
        self.ignoreScrolling = true
        if itemLayout.contentSize != self.contentSize {
            self.contentSize = itemLayout.contentSize
        }
        self.ignoreScrolling = false
        
        self.updateVisibleItems(transition: .immediate, attemptSynchronousLoad: attemptSynchronousLoad)
    }
}
