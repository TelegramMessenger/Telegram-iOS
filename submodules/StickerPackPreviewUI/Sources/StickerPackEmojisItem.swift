import Foundation
import UIKit
import Display
import TelegramCore
import SwiftSignalKit
import AsyncDisplayKit
import Postbox
import StickerResources
import AccountContext
import AnimatedStickerNode
import TelegramAnimatedStickerNode
import TelegramPresentationData
import ShimmerEffect
import EntityKeyboard
import AnimationCache
import MultiAnimationRenderer

private let nativeItemSize = 36.0
private let minItemsPerRow = 8
private let verticalSpacing = 9.0
private let minSpacing = 9.0
private let containerInsets = UIEdgeInsets(top: 0.0, left: 12.0, bottom: 0.0, right: 12.0)

class ItemLayout {
    let width: CGFloat
    let itemsCount: Int
    let hasTitle: Bool
    let itemsPerRow: Int
    let visibleItemSize: CGFloat
    let horizontalSpacing: CGFloat
    let itemTopOffset: CGFloat
    let height: CGFloat
    
    init(width: CGFloat, itemsCount: Int, hasTitle: Bool) {
        self.width = width
        self.itemsCount = itemsCount
        self.hasTitle = hasTitle
        
        let itemHorizontalSpace = width - containerInsets.left - containerInsets.right
        self.itemsPerRow = max(minItemsPerRow, Int((itemHorizontalSpace + minSpacing) / (nativeItemSize + minSpacing)))
        
        self.visibleItemSize = floor((itemHorizontalSpace - CGFloat(self.itemsPerRow - 1) * minSpacing) / CGFloat(self.itemsPerRow))
        
        self.horizontalSpacing = floor((itemHorizontalSpace - visibleItemSize * CGFloat(self.itemsPerRow)) / CGFloat(self.itemsPerRow - 1))
        
        let numRowsInGroup = (itemsCount + (self.itemsPerRow - 1)) / self.itemsPerRow
        
        self.itemTopOffset = hasTitle ? 61.0 : 0.0
        self.height = itemTopOffset + CGFloat(numRowsInGroup) * visibleItemSize + CGFloat(max(0, numRowsInGroup - 1)) * verticalSpacing
    }
    
    func frame(itemIndex: Int) -> CGRect {
        let row = itemIndex / self.itemsPerRow
        let column = itemIndex % self.itemsPerRow
        
        return CGRect(
            origin: CGPoint(
                x: containerInsets.left + CGFloat(column) * (self.visibleItemSize + self.horizontalSpacing),
                y: self.itemTopOffset + CGFloat(row) * (self.visibleItemSize + verticalSpacing)
            ),
            size: CGSize(
                width: self.visibleItemSize,
                height: self.visibleItemSize
            )
        )
    }
}

final class StickerPackEmojisItem: GridItem {
    let context: AccountContext
    let animationCache: AnimationCache
    let animationRenderer: MultiAnimationRenderer
    let interaction: StickerPackPreviewInteraction
    let info: StickerPackCollectionInfo
    let items: [StickerPackItem]
    let theme: PresentationTheme
    let strings: PresentationStrings
    let title: String?
    let isInstalled: Bool?
    let isEmpty: Bool
    
    let section: GridSection? = nil
    let fillsRowWithDynamicHeight: ((CGFloat) -> CGFloat)?
    
    init(context: AccountContext, animationCache: AnimationCache, animationRenderer: MultiAnimationRenderer, interaction: StickerPackPreviewInteraction, info: StickerPackCollectionInfo, items: [StickerPackItem], theme: PresentationTheme, strings: PresentationStrings, title: String?, isInstalled: Bool?, isEmpty: Bool) {
        self.context = context
        self.animationCache = animationCache
        self.animationRenderer = animationRenderer
        self.interaction = interaction
        self.info = info
        self.items = items
        self.theme = theme
        self.strings = strings
        self.title = title
        self.isInstalled = isInstalled
        self.isEmpty = isEmpty
        
        self.fillsRowWithDynamicHeight = { width in
            let layout = ItemLayout(width: width, itemsCount: items.count, hasTitle: title != nil)
            return layout.height
        }
    }
    
    func node(layout: GridNodeLayout, synchronousLoad: Bool) -> GridItemNode {
        let node = StickerPackEmojisItemNode()
        return node
    }
    
    func update(node: GridItemNode) {
        guard let _ = node as? StickerPackEmojisItemNode else {
            assertionFailure()
            return
        }
    }
}

private let textFont = Font.regular(20.0)

final class StickerPackEmojisItemNode: GridItemNode {
    private var item: StickerPackEmojisItem?
    private var itemLayout: ItemLayout?
    
    private var shimmerHostView: PortalSourceView?
    private var standaloneShimmerEffect: StandaloneShimmerEffect?
    
    private var boundsChangeTrackerLayer = SimpleLayer()
    
    private var visibleItemLayers: [EmojiPagerContentComponent.View.ItemLayer.Key: EmojiPagerContentComponent.View.ItemLayer] = [:]
    private var visibleItemPlaceholderViews: [EmojiPagerContentComponent.View.ItemLayer.Key: EmojiPagerContentComponent.View.ItemPlaceholderView] = [:]
    
    private let titleNode: ImmediateTextNode
    private let subtitleNode: ImmediateTextNode
    private let buttonNode: HighlightableButtonNode
    
    override init() {
        self.titleNode = ImmediateTextNode()
        self.subtitleNode = ImmediateTextNode()
        self.buttonNode = HighlightableButtonNode(pointerStyle: nil)
        self.buttonNode.clipsToBounds = true
        self.buttonNode.cornerRadius = 14.0
        
        super.init()
        
        self.addSubnode(self.titleNode)
        self.addSubnode(self.subtitleNode)
        self.addSubnode(self.buttonNode)
        
        self.buttonNode.addTarget(self, action: #selector(self.buttonPressed), forControlEvents: .touchUpInside)
    }
    
    @objc private func buttonPressed() {
        guard let item = self.item else {
            return
        }
        
        if item.isInstalled == true {
            item.interaction.removeStickerPack(item.info)
        } else {
            item.interaction.addStickerPack(item.info, item.items)
        }
    }
    
    override var isVisibleInGrid: Bool {
        didSet {

        }
    }
                        
    override func didLoad() {
        super.didLoad()
        
        let shimmerHostView = PortalSourceView()
        shimmerHostView.alpha = 0.0
        shimmerHostView.frame = CGRect(origin: CGPoint(), size: self.size)
        self.view.addSubview(shimmerHostView)
        self.shimmerHostView = shimmerHostView
        
        let standaloneShimmerEffect = StandaloneShimmerEffect()
        self.standaloneShimmerEffect = standaloneShimmerEffect
        if let item = self.item {
            let shimmerBackgroundColor = item.theme.chat.inputPanel.primaryTextColor.withMultipliedAlpha(0.08)
            let shimmerForegroundColor = item.theme.list.itemBlocksBackgroundColor.withMultipliedAlpha(0.15)
            standaloneShimmerEffect.update(background: shimmerBackgroundColor, foreground: shimmerForegroundColor)
            self.updateShimmerIfNeeded()
        }
        
        let boundsChangeTrackerLayer = SimpleLayer()
        boundsChangeTrackerLayer.opacity = 0.0
        self.layer.addSublayer(boundsChangeTrackerLayer)
        boundsChangeTrackerLayer.didEnterHierarchy = { [weak self] in
            self?.standaloneShimmerEffect?.updateLayer()
        }
        self.boundsChangeTrackerLayer =  boundsChangeTrackerLayer
    }
               
    private var size = CGSize()
    override func updateLayout(item: GridItem, size: CGSize, isVisible: Bool, synchronousLoads: Bool) {
        guard let item = item as? StickerPackEmojisItem else {
            return
        }
        self.item = item
        self.size = size
        
        if let title = item.title {
            let isInstalled = item.isInstalled ?? false
            
            self.titleNode.attributedText = NSAttributedString(string: title, font: Font.semibold(17.0), textColor: item.theme.actionSheet.primaryTextColor, paragraphAlignment: .natural)
            self.subtitleNode.attributedText = NSAttributedString(string: item.strings.EmojiPack_Emoji(Int32(item.items.count)), font: Font.regular(15.0), textColor: item.theme.actionSheet.secondaryTextColor, paragraphAlignment: .natural)
            
            self.buttonNode.setAttributedTitle(NSAttributedString(string: isInstalled ? item.strings.EmojiPack_Added.uppercased() : item.strings.EmojiPack_Add.uppercased(), font: Font.semibold(15.0), textColor: isInstalled ? item.theme.list.itemCheckColors.fillColor : item.theme.list.itemCheckColors.foregroundColor, paragraphAlignment: .center), for: .normal)
            self.buttonNode.backgroundColor = isInstalled ? item.theme.list.itemCheckColors.fillColor.withAlphaComponent(0.08) : item.theme.list.itemCheckColors.fillColor
        }
        
        self.updateVisibleItems(attemptSynchronousLoads: false, transition: .immediate)
        
        let shimmerBackgroundColor = item.theme.chat.inputPanel.primaryTextColor.withMultipliedAlpha(0.08)
        let shimmerForegroundColor = item.theme.list.itemBlocksBackgroundColor.withMultipliedAlpha(0.15)
        self.standaloneShimmerEffect?.update(background: shimmerBackgroundColor, foreground: shimmerForegroundColor)
        
        self.setNeedsLayout()
    }

    func updateVisibleItems(attemptSynchronousLoads: Bool, transition: ContainedViewLayoutTransition) {
        guard let item = self.item, !self.size.width.isZero else {
            return
        }
                
        let context = item.context
        let animationCache = item.animationCache
        let animationRenderer = item.animationRenderer
        let theme = item.theme
        let items = item.items
        var validIds = Set<EmojiPagerContentComponent.View.ItemLayer.Key>()
        
        let itemLayout: ItemLayout
        if let current = self.itemLayout, current.width == self.size.width && current.itemsCount == items.count && current.hasTitle == (item.title != nil) {
            itemLayout = current
        } else {
            itemLayout = ItemLayout(width: self.size.width, itemsCount: items.count, hasTitle: item.title != nil)
            self.itemLayout = itemLayout
        }
        
        for index in 0 ..< items.count {
            let item = items[index]
            let itemId = EmojiPagerContentComponent.View.ItemLayer.Key(groupId: 0, itemId: .file(item.file.fileId), staticEmoji: nil)
            validIds.insert(itemId)
            
            let itemDimensions = item.file.dimensions?.cgSize ?? CGSize(width: 512.0, height: 512.0)
            let itemNativeFitSize = itemDimensions.fitted(CGSize(width: nativeItemSize, height: nativeItemSize))
            let itemVisibleFitSize = itemDimensions.fitted(CGSize(width: itemLayout.visibleItemSize, height: itemLayout.visibleItemSize))
            
            var updateItemLayerPlaceholder = false
            var itemTransition = transition
            let itemLayer: EmojiPagerContentComponent.View.ItemLayer
            if let current = self.visibleItemLayers[itemId] {
                itemLayer = current
            } else {
                updateItemLayerPlaceholder = true
                itemTransition = .immediate
                                
                itemLayer = EmojiPagerContentComponent.View.ItemLayer(
                    item: EmojiPagerContentComponent.Item(animationData: EntityKeyboardAnimationData(file: item.file), itemFile: item.file, staticEmoji: nil, subgroupId: nil),
                    context: context,
                    attemptSynchronousLoad: attemptSynchronousLoads,
                    animationData: EntityKeyboardAnimationData(file: item.file),
                    staticEmoji: nil,
                    cache: animationCache,
                    renderer: animationRenderer,
                    placeholderColor: theme.chat.inputPanel.primaryTextColor.withMultipliedAlpha(0.1),
                    blurredBadgeColor: theme.chat.inputPanel.panelBackgroundColor.withMultipliedAlpha(0.5),
                    pointSize: itemNativeFitSize,
                    onUpdateDisplayPlaceholder: { [weak self] displayPlaceholder, duration in
                        guard let strongSelf = self else {
                            return
                        }
                        if displayPlaceholder {
                            if let itemLayer = strongSelf.visibleItemLayers[itemId] {
                                let placeholderView: EmojiPagerContentComponent.View.ItemPlaceholderView
                                if let current = strongSelf.visibleItemPlaceholderViews[itemId] {
                                    placeholderView = current
                                } else {
                                    placeholderView = EmojiPagerContentComponent.View.ItemPlaceholderView(
                                        context: context,
                                        dimensions: item.file.dimensions?.cgSize ?? CGSize(width: 512.0, height: 512.0),
                                        immediateThumbnailData: item.file.immediateThumbnailData,
                                        shimmerView: nil,//strongSelf.shimmerHostView,
                                        color: theme.chat.inputPanel.primaryTextColor.withMultipliedAlpha(0.08),
                                        size: itemNativeFitSize
                                    )
                                    strongSelf.visibleItemPlaceholderViews[itemId] = placeholderView
                                    strongSelf.view.insertSubview(placeholderView, at: 0)
                                }
                                placeholderView.frame = itemLayer.frame
                                placeholderView.update(size: placeholderView.bounds.size)
                                
                                strongSelf.updateShimmerIfNeeded()
                            }
                        } else {
                            if let placeholderView = strongSelf.visibleItemPlaceholderViews[itemId] {
                                strongSelf.visibleItemPlaceholderViews.removeValue(forKey: itemId)
                                
                                if duration > 0.0 {
                                    placeholderView.layer.opacity = 0.0
                                    placeholderView.layer.animateAlpha(from: 1.0, to: 0.0, duration: duration, completion: { [weak self, weak placeholderView] _ in
                                        guard let strongSelf = self else {
                                            return
                                        }
                                        placeholderView?.removeFromSuperview()
                                        strongSelf.updateShimmerIfNeeded()
                                    })
                                } else {
                                    placeholderView.removeFromSuperview()
                                    strongSelf.updateShimmerIfNeeded()
                                }
                            }
                        }
                    }
                )
                self.layer.addSublayer(itemLayer)
                self.visibleItemLayers[itemId] = itemLayer
            }
            
            var itemFrame = itemLayout.frame(itemIndex: index)
            
            itemFrame.origin.x += floor((itemFrame.width - itemVisibleFitSize.width) / 2.0)
            itemFrame.origin.y += floor((itemFrame.height - itemVisibleFitSize.height) / 2.0)
            itemFrame.size = itemVisibleFitSize
            
            let itemPosition = CGPoint(x: itemFrame.midX, y: itemFrame.midY)
            let itemBounds = CGRect(origin: CGPoint(), size: itemFrame.size)
            itemTransition.updatePosition(layer: itemLayer, position: itemPosition)
            itemTransition.updateBounds(layer: itemLayer, bounds: CGRect(origin: CGPoint(), size: itemFrame.size))
            
            if let placeholderView = self.visibleItemPlaceholderViews[itemId] {
                if placeholderView.layer.position != itemPosition || placeholderView.layer.bounds != itemBounds {
                    itemTransition.updateFrame(view: placeholderView, frame: itemFrame)
                    placeholderView.update(size: itemFrame.size)
                }
            } else if updateItemLayerPlaceholder {
                if itemLayer.displayPlaceholder {
                    itemLayer.onUpdateDisplayPlaceholder(true, 0.0)
                }
            }
            
            itemLayer.isVisibleForAnimations = true
        }
        
        for id in self.visibleItemLayers.keys {
            if !validIds.contains(id) {
                self.visibleItemLayers[id]?.removeFromSuperlayer()
                self.visibleItemLayers[id] = nil
            }
        }
        for id in self.visibleItemPlaceholderViews.keys {
            if !validIds.contains(id) {
                self.visibleItemPlaceholderViews[id]?.removeFromSuperview()
                self.visibleItemPlaceholderViews[id] = nil
            }
        }
    }
    
    private func updateShimmerIfNeeded() {
        if self.visibleItemPlaceholderViews.isEmpty {
            self.standaloneShimmerEffect?.layer = nil
        } else {
            self.standaloneShimmerEffect?.layer = self.shimmerHostView?.layer
        }
    }
    
    override func layout() {
        super.layout()
        
        if let _ = self.item {
            var buttonSize = self.buttonNode.calculateSizeThatFits(self.size)
            buttonSize.width += 24.0
            buttonSize.height = 28.0
            
            let titleSize = self.titleNode.updateLayout(CGSize(width: self.size.width - 60.0, height: self.size.height))
            let subtitleSize = self.subtitleNode.updateLayout(CGSize(width: self.size.width - 60.0, height: self.size.height))
            
            self.titleNode.frame = CGRect(origin: CGPoint(x: 16.0, y: 10.0), size: titleSize)
            self.subtitleNode.frame = CGRect(origin: CGPoint(x: 16.0, y: 33.0), size: subtitleSize)
            
            self.buttonNode.frame = CGRect(origin: CGPoint(x: self.size.width - buttonSize.width - 16.0, y: 17.0), size: buttonSize)
        }
        
        self.shimmerHostView?.frame = CGRect(origin: CGPoint(), size: self.size)
        self.updateVisibleItems(attemptSynchronousLoads: false, transition: .immediate)
    }
        
    func transitionNode() -> ASDisplayNode? {
        return self
    }
}

