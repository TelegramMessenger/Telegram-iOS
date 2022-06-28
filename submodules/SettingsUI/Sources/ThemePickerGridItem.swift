import Foundation
import UIKit
import Display
import AsyncDisplayKit
import SwiftSignalKit
import Postbox
import TelegramCore
import TelegramPresentationData
import MergeLists
import TelegramUIPreferences
import ItemListUI
import PresentationDataUtils
import WallpaperResources
import AccountContext
import AppBundle
import ContextUI
import AnimatedStickerNode
import TelegramAnimatedStickerNode
import ShimmerEffect
import StickerResources


private var cachedBorderImages: [String: UIImage] = [:]
private func generateBorderImage(theme: PresentationTheme, bordered: Bool, selected: Bool) -> UIImage? {
    let key = "\(theme.list.itemBlocksBackgroundColor.hexString)_\(selected ? "s" + theme.list.itemAccentColor.hexString : theme.list.disclosureArrowColor.hexString)"
    if let image = cachedBorderImages[key] {
        return image
    } else {
        let image = generateImage(CGSize(width: 18.0, height: 18.0), rotatedContext: { size, context in
            let bounds = CGRect(origin: CGPoint(), size: size)
            context.clear(bounds)

            let lineWidth: CGFloat
            if selected {
                lineWidth = 2.0
                context.setLineWidth(lineWidth)
                context.setStrokeColor(theme.list.itemBlocksBackgroundColor.cgColor)
                
                context.strokeEllipse(in: bounds.insetBy(dx: 3.0 + lineWidth / 2.0, dy: 3.0 + lineWidth / 2.0))
                
                var accentColor = theme.list.itemAccentColor
                if accentColor.rgb == 0xffffff {
                    accentColor = UIColor(rgb: 0x999999)
                }
                context.setStrokeColor(accentColor.cgColor)
            } else {
                context.setStrokeColor(theme.list.disclosureArrowColor.withAlphaComponent(0.4).cgColor)
                lineWidth = 1.0
            }

            if bordered || selected {
                context.setLineWidth(lineWidth)
                context.strokeEllipse(in: bounds.insetBy(dx: 1.0 + lineWidth / 2.0, dy: 1.0 + lineWidth / 2.0))
            }
        })?.stretchableImage(withLeftCapWidth: 9, topCapHeight: 9)
        cachedBorderImages[key] = image
        return image
    }
}

private final class ThemeGridThemeItemIconNode : ASDisplayNode {
    private let containerNode: ASDisplayNode
    private let emojiContainerNode: ASDisplayNode
    private let imageNode: TransformImageNode
    private let overlayNode: ASImageNode
    private let textNode: TextNode
    private let emojiNode: TextNode
    private let emojiImageNode: TransformImageNode
    private var animatedStickerNode: AnimatedStickerNode?
    private var placeholderNode: StickerShimmerEffectNode
    var snapshotView: UIView?
        
    private let stickerFetchedDisposable = MetaDisposable()
    
    private var item: ThemeCarouselThemeIconItem?
    private var size: CGSize?

    override init() {
        self.containerNode = ASDisplayNode()
        self.emojiContainerNode = ASDisplayNode()

        self.imageNode = TransformImageNode()
        self.imageNode.isLayerBacked = true
        self.imageNode.cornerRadius = 8.0
        self.imageNode.clipsToBounds = true
        
        self.overlayNode = ASImageNode()
        self.overlayNode.isLayerBacked = true

        self.textNode = TextNode()
        self.textNode.isUserInteractionEnabled = false
        self.textNode.displaysAsynchronously = false
        
        self.emojiNode = TextNode()
        self.emojiNode.isUserInteractionEnabled = false
        self.emojiNode.displaysAsynchronously = false
        
        self.emojiImageNode = TransformImageNode()
        
        self.placeholderNode = StickerShimmerEffectNode()

        super.init()
        
        self.addSubnode(self.containerNode)
        self.containerNode.addSubnode(self.imageNode)
        self.containerNode.addSubnode(self.overlayNode)
        self.containerNode.addSubnode(self.textNode)
        
        self.addSubnode(self.emojiContainerNode)
        self.emojiContainerNode.addSubnode(self.emojiNode)
        self.emojiContainerNode.addSubnode(self.emojiImageNode)
        self.emojiContainerNode.addSubnode(self.placeholderNode)
        
        var firstTime = true
        self.emojiImageNode.imageUpdated = { [weak self] image in
            guard let strongSelf = self else {
                return
            }
            if image != nil {
                strongSelf.removePlaceholder(animated: !firstTime)
                if firstTime {
                    strongSelf.emojiImageNode.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.2)
                }
            }
            firstTime = false
        }
    }

    deinit {
        self.stickerFetchedDisposable.dispose()
    }
    
    override func didLoad() {
        super.didLoad()
        
        self.view.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(self.tap)))
    }
    
    @objc private func tap() {
        guard let item = self.item else {
            return
        }
        item.action(item.themeReference)
    }
    
    private func removePlaceholder(animated: Bool) {
        if !animated {
            self.placeholderNode.removeFromSupernode()
        } else {
            self.placeholderNode.alpha = 0.0
            self.placeholderNode.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.2, completion: { [weak self] _ in
                self?.placeholderNode.removeFromSupernode()
            })
        }
    }
    
//    override func updateAbsoluteRect(_ rect: CGRect, within containerSize: CGSize) {
//        let emojiFrame = CGRect(origin: CGPoint(x: 33.0, y: 79.0), size: CGSize(width: 24.0, height: 24.0))
//        self.placeholderNode.updateAbsoluteRect(CGRect(origin: CGPoint(x: rect.minX + emojiFrame.minX, y: rect.minY + emojiFrame.minY), size: emojiFrame.size), within: containerSize)
//    }
        
    func setup(item: ThemeCarouselThemeIconItem, size: CGSize) {
        let currentItem = self.item
        let currentSize = self.size
        self.item = item
        self.size = size
        
        let makeTextLayout = TextNode.asyncLayout(self.textNode)
        let makeEmojiLayout = TextNode.asyncLayout(self.emojiNode)
        let makeImageLayout = self.imageNode.asyncLayout()
        
        var updatedThemeReference = false
        var updatedTheme = false
        var updatedNightMode = false
        var updatedWallpaper = false
        var updatedSelected = false
        let updatedSize = currentSize != size
        
        if currentItem?.themeReference != item.themeReference {
            updatedThemeReference = true
        }
        if currentItem?.nightMode != item.nightMode {
            updatedNightMode = true
        }
        if currentItem?.wallpaper != item.wallpaper {
            updatedWallpaper = true
        }
        if currentItem?.theme !== item.theme {
            updatedTheme = true
        }
        if currentItem?.selected != item.selected {
            updatedSelected = true
        }
        
        let string: String?
        if let _ = item.themeReference.emoticon {
            string = nil
        } else {
            string = themeDisplayName(strings: item.strings, reference: item.themeReference)
        }
                
        let text = NSAttributedString(string: string ?? item.strings.Conversation_Theme_NoTheme, font: Font.bold(14.0), textColor: .white)
        let (textLayout, textApply) = makeTextLayout(TextNodeLayoutArguments(attributedString: text, backgroundColor: nil, maximumNumberOfLines: 2, truncationType: .end, constrainedSize: CGSize(width: 70.0, height: CGFloat.greatestFiniteMagnitude), alignment: .center, cutout: nil, insets: UIEdgeInsets()))
        

        let title = NSAttributedString(string: "", font: Font.regular(22.0), textColor: .black)
        let (_, emojiApply) = makeEmojiLayout(TextNodeLayoutArguments(attributedString: title, backgroundColor: nil, maximumNumberOfLines: 1, truncationType: .end, constrainedSize: CGSize(width: size.width, height: CGFloat.greatestFiniteMagnitude), alignment: .center, cutout: nil, insets: UIEdgeInsets()))
        
        if updatedThemeReference || updatedWallpaper || updatedNightMode || updatedSize {
            var themeReference = item.themeReference
            if case .builtin = themeReference, item.nightMode {
                themeReference = .builtin(.night)
            }
            
            let color = item.themeSpecificAccentColors[themeReference.index]
            let wallpaper = item.themeSpecificChatWallpapers[themeReference.index]
            
            self.imageNode.setSignal(themeIconImage(account: item.context.account, accountManager: item.context.sharedContext.accountManager, theme: themeReference, color: color, wallpaper: wallpaper ?? item.wallpaper, nightMode: item.nightMode, emoticon: true, large: true))
            self.imageNode.backgroundColor = nil
        }
        
        if updatedTheme || updatedSelected {
            self.overlayNode.image = generateBorderImage(theme: item.theme, bordered: false, selected: item.selected)
        }
        
        if !item.selected && currentItem?.selected == true, let animatedStickerNode = self.animatedStickerNode {
            animatedStickerNode.transform = CATransform3DIdentity
            
            let initialScale: CGFloat = CGFloat((animatedStickerNode.value(forKeyPath: "layer.presentationLayer.transform.scale.x") as? NSNumber)?.floatValue ?? 1.0)
            animatedStickerNode.layer.animateSpring(from: initialScale as NSNumber, to: 1.0 as NSNumber, keyPath: "transform.scale", duration: 0.45)
        }
        
        self.textNode.frame = CGRect(origin: CGPoint(x: floorToScreenPixels((90.0 - textLayout.size.width) / 2.0), y: 83.0), size: textLayout.size)
        self.textNode.isHidden = string == nil
        
        self.containerNode.frame = CGRect(origin: CGPoint(), size: size)
        self.emojiContainerNode.frame = CGRect(origin: CGPoint(), size: size)
        
        let _ = textApply()
        let _ = emojiApply()

        let imageSize = size
        self.imageNode.frame = CGRect(origin: CGPoint(x: 0.0, y: 0.0), size: imageSize)
        let applyLayout = makeImageLayout(TransformImageArguments(corners: ImageCorners(), imageSize: imageSize, boundingSize: imageSize, intrinsicInsets: UIEdgeInsets(), emptyColor: .clear))
        applyLayout()
        
        self.overlayNode.frame = self.imageNode.frame.insetBy(dx: -1.0, dy: -1.0)
        self.emojiNode.frame = CGRect(origin: CGPoint(x: 0.0, y: 79.0), size: CGSize(width: 90.0, height: 30.0))
        
        let emojiFrame = CGRect(origin: CGPoint(x: floorToScreenPixels((size.width - 42.0) / 2.0), y: 98.0), size: CGSize(width: 42.0, height: 42.0))
        if let file = item.emojiFile, currentItem?.emojiFile == nil {
            let imageApply = self.emojiImageNode.asyncLayout()(TransformImageArguments(corners: ImageCorners(), imageSize: emojiFrame.size, boundingSize: emojiFrame.size, intrinsicInsets: UIEdgeInsets()))
            imageApply()
            self.emojiImageNode.setSignal(chatMessageStickerPackThumbnail(postbox: item.context.account.postbox, resource: file.resource, animated: true, nilIfEmpty: true))
            self.emojiImageNode.frame = emojiFrame
            
            let animatedStickerNode: AnimatedStickerNode
            if let current = self.animatedStickerNode {
                animatedStickerNode = current
            } else {
                animatedStickerNode = DefaultAnimatedStickerNodeImpl()
                animatedStickerNode.started = { [weak self] in
                    self?.emojiImageNode.isHidden = true
                }
                self.animatedStickerNode = animatedStickerNode
                self.emojiContainerNode.insertSubnode(animatedStickerNode, belowSubnode: self.placeholderNode)
                let pathPrefix = item.context.account.postbox.mediaBox.shortLivedResourceCachePathPrefix(file.resource.id)
                animatedStickerNode.setup(source: AnimatedStickerResourceSource(account: item.context.account, resource: file.resource), width: 128, height: 128, playbackMode: .still(.start), mode: .direct(cachePathPrefix: pathPrefix))
                
                animatedStickerNode.anchorPoint = CGPoint(x: 0.5, y: 1.0)
            }
            animatedStickerNode.autoplay = true
            animatedStickerNode.visibility = true
            
            self.stickerFetchedDisposable.set(fetchedMediaResource(mediaBox: item.context.account.postbox.mediaBox, reference: MediaResourceReference.media(media: .standalone(media: file), resource: file.resource)).start())
            
            let thumbnailDimensions = PixelDimensions(width: 512, height: 512)
            self.placeholderNode.update(backgroundColor: nil, foregroundColor: UIColor(rgb: 0xffffff, alpha: 0.2), shimmeringColor: UIColor(rgb: 0xffffff, alpha: 0.3), data: file.immediateThumbnailData, size: emojiFrame.size, imageSize: thumbnailDimensions.cgSize)
            self.placeholderNode.frame = emojiFrame
        }
        
        if let animatedStickerNode = self.animatedStickerNode {
            animatedStickerNode.frame = emojiFrame
            animatedStickerNode.updateLayout(size: emojiFrame.size)
        }
    }
    
    func crossfade() {
//        if let snapshotView = self.containerNode.view.snapshotView(afterScreenUpdates: false) {
//            snapshotView.transform = self.containerNode.view.transform
//            snapshotView.frame = self.containerNode.view.frame
//            self.view.insertSubview(snapshotView, aboveSubview: self.containerNode.view)
//
//            snapshotView.layer.animateAlpha(from: 1.0, to: 0.0, duration: ChatThemeScreen.themeCrossfadeDuration, delay: ChatThemeScreen.themeCrossfadeDelay, timingFunction: CAMediaTimingFunctionName.linear.rawValue, removeOnCompletion: false, completion: { [weak snapshotView] _ in
//                snapshotView?.removeFromSuperview()
//            })
//        }
    }
}

class ThemeGridThemeItem: ListViewItem, ItemListItem {
    var sectionId: ItemListSectionId

    let context: AccountContext
    let theme: PresentationTheme
    let strings: PresentationStrings
    let themes: [PresentationThemeReference]
    let animatedEmojiStickers: [String: [StickerPackItem]]
    let themeSpecificAccentColors: [Int64: PresentationThemeAccentColor]
    let themeSpecificChatWallpapers: [Int64: TelegramWallpaper]
    let nightMode: Bool
    let currentTheme: PresentationThemeReference
    let updatedTheme: (PresentationThemeReference) -> Void
    let contextAction: ((PresentationThemeReference, ASDisplayNode, ContextGesture?) -> Void)?
    let tag: ItemListItemTag?

    init(context: AccountContext, theme: PresentationTheme, strings: PresentationStrings, sectionId: ItemListSectionId, themes: [PresentationThemeReference], animatedEmojiStickers: [String: [StickerPackItem]], themeSpecificAccentColors: [Int64: PresentationThemeAccentColor], themeSpecificChatWallpapers: [Int64: TelegramWallpaper], nightMode: Bool, currentTheme: PresentationThemeReference, updatedTheme: @escaping (PresentationThemeReference) -> Void, contextAction: ((PresentationThemeReference, ASDisplayNode, ContextGesture?) -> Void)?, tag: ItemListItemTag? = nil) {
        self.context = context
        self.theme = theme
        self.strings = strings
        self.themes = themes
        self.animatedEmojiStickers = animatedEmojiStickers
        self.themeSpecificAccentColors = themeSpecificAccentColors
        self.themeSpecificChatWallpapers = themeSpecificChatWallpapers
        self.nightMode = nightMode
        self.currentTheme = currentTheme
        self.updatedTheme = updatedTheme
        self.contextAction = contextAction
        self.tag = tag
        self.sectionId = sectionId
    }

    func nodeConfiguredForParams(async: @escaping (@escaping () -> Void) -> Void, params: ListViewItemLayoutParams, synchronousLoads: Bool, previousItem: ListViewItem?, nextItem: ListViewItem?, completion: @escaping (ListViewItemNode, @escaping () -> (Signal<Void, NoError>?, (ListViewItemApply) -> Void)) -> Void) {
        async {
            let node = ThemeGridThemeItemNode()
            let (layout, apply) = node.asyncLayout()(self, params, itemListNeighbors(item: self, topItem: previousItem as? ItemListItem, bottomItem: nextItem as? ItemListItem))

            node.contentSize = layout.contentSize
            node.insets = layout.insets

            Queue.mainQueue().async {
                completion(node, {
                    return (nil, { _ in apply() })
                })
            }
        }
    }

    func updateNode(async: @escaping (@escaping () -> Void) -> Void, node: @escaping () -> ListViewItemNode, params: ListViewItemLayoutParams, previousItem: ListViewItem?, nextItem: ListViewItem?, animation: ListViewItemUpdateAnimation, completion: @escaping (ListViewItemNodeLayout, @escaping (ListViewItemApply) -> Void) -> Void) {
        Queue.mainQueue().async {
            if let nodeValue = node() as? ThemeGridThemeItemNode {
                let makeLayout = nodeValue.asyncLayout()

                async {
                    let (layout, apply) = makeLayout(self, params, itemListNeighbors(item: self, topItem: previousItem as? ItemListItem, bottomItem: nextItem as? ItemListItem))
                    Queue.mainQueue().async {
                        completion(layout, { _ in
                            apply()
                        })
                    }
                }
            }
        }
    }
}


class ThemeGridThemeItemNode: ListViewItemNode, ItemListItemNode {
    private let containerNode: ASDisplayNode
    private let backgroundNode: ASDisplayNode
    private let topStripeNode: ASDisplayNode
    private let bottomStripeNode: ASDisplayNode
    private let maskNode: ASImageNode
    private var snapshotView: UIView?
    
    private let scrollNode: ASScrollNode
    private var items: [ThemeCarouselThemeIconItem]?
    private var itemNodes: [Int64: ThemeGridThemeItemIconNode] = [:]
    private var initialized = false

    private var item: ThemeGridThemeItem?
    private var layoutParams: ListViewItemLayoutParams?

    var tag: ItemListItemTag? {
        return self.item?.tag
    }

    init() {
        self.containerNode = ASDisplayNode()
        
        self.backgroundNode = ASDisplayNode()
        self.backgroundNode.isLayerBacked = true

        self.topStripeNode = ASDisplayNode()
        self.topStripeNode.isLayerBacked = true

        self.bottomStripeNode = ASDisplayNode()
        self.bottomStripeNode.isLayerBacked = true

        self.maskNode = ASImageNode()

        self.scrollNode = ASScrollNode()

        super.init(layerBacked: false, dynamicBounce: false)

        self.addSubnode(self.containerNode)
        self.addSubnode(self.scrollNode)
    }
    
    func asyncLayout() -> (_ item: ThemeGridThemeItem, _ params: ListViewItemLayoutParams, _ neighbors: ItemListNeighbors) -> (ListViewItemNodeLayout, () -> Void) {
        return { item, params, neighbors in
            let contentSize: CGSize
            let insets: UIEdgeInsets
            let separatorHeight = UIScreenPixel
            
            let minSpacing: CGFloat = 6.0
            
            let referenceImageSize: CGSize
            let screenWidth = min(params.width, params.availableHeight)
            if screenWidth >= 390.0 {
                referenceImageSize = CGSize(width: 110.0, height: 150.0)
            } else {
                referenceImageSize = CGSize(width: 90.0, height: 150.0)
            }
            let totalWidth = params.width - params.leftInset - params.rightInset
            let imageCount = Int((totalWidth - minSpacing) / (referenceImageSize.width + minSpacing))
            var itemSize = referenceImageSize.aspectFilled(CGSize(width: floorToScreenPixels((totalWidth - CGFloat(imageCount + 1) * minSpacing) / CGFloat(imageCount)), height: referenceImageSize.height))
            itemSize.height = referenceImageSize.height
            let itemSpacing = floorToScreenPixels((totalWidth - CGFloat(imageCount) * itemSize.width) / CGFloat(imageCount + 1))
            
            var spacingOffset: CGFloat = 0.0
            if totalWidth - CGFloat(imageCount) * itemSize.width - CGFloat(imageCount + 1) * itemSpacing == 1.0 {
                spacingOffset = UIScreenPixel
            }
            
            let rows = ceil(CGFloat(item.themes.count) / CGFloat(imageCount))
            
            contentSize = CGSize(width: params.width, height: minSpacing + rows * (itemSize.height + itemSpacing))
            insets = itemListNeighborsGroupedInsets(neighbors, params)

            let layout = ListViewItemNodeLayout(contentSize: contentSize, insets: insets)
            let layoutSize = layout.size

            return (layout, { [weak self] in
                if let strongSelf = self {
                    strongSelf.item = item
                    strongSelf.layoutParams = params

                    strongSelf.backgroundNode.backgroundColor = item.theme.list.itemBlocksBackgroundColor
                    strongSelf.topStripeNode.backgroundColor = item.theme.list.itemBlocksSeparatorColor
                    strongSelf.bottomStripeNode.backgroundColor = item.theme.list.itemBlocksSeparatorColor

                    if strongSelf.backgroundNode.supernode == nil {
                        strongSelf.containerNode.insertSubnode(strongSelf.backgroundNode, at: 0)
                    }
                    if strongSelf.topStripeNode.supernode == nil {
                        strongSelf.containerNode.insertSubnode(strongSelf.topStripeNode, at: 1)
                    }
                    if strongSelf.bottomStripeNode.supernode == nil {
                        strongSelf.containerNode.insertSubnode(strongSelf.bottomStripeNode, at: 2)
                    }
                    if strongSelf.maskNode.supernode == nil {
                        strongSelf.containerNode.insertSubnode(strongSelf.maskNode, at: 3)
                    }
                    
                    let hasCorners = itemListHasRoundedBlockLayout(params)
                    var hasTopCorners = false
                    var hasBottomCorners = false
                    switch neighbors.top {
                        case .sameSection(false):
                            strongSelf.topStripeNode.isHidden = true
                        default:
                            hasTopCorners = true
                            strongSelf.topStripeNode.isHidden = hasCorners
                    }
                    let bottomStripeInset: CGFloat
                    let bottomStripeOffset: CGFloat
                    switch neighbors.bottom {
                        case .sameSection(false):
                            bottomStripeInset = params.leftInset + 16.0
                            bottomStripeOffset = -separatorHeight
                            strongSelf.bottomStripeNode.isHidden = false
                        default:
                            bottomStripeInset = 0.0
                            bottomStripeOffset = 0.0
                            hasBottomCorners = true
                            strongSelf.bottomStripeNode.isHidden = hasCorners
                    }
                    
                    strongSelf.containerNode.frame = CGRect(x: 0.0, y: 0.0, width: contentSize.width, height: contentSize.height)
                    strongSelf.maskNode.image = hasCorners ? PresentationResourcesItemList.cornersImage(item.theme, top: hasTopCorners, bottom: hasBottomCorners) : nil

                    strongSelf.backgroundNode.frame = CGRect(origin: CGPoint(x: 0.0, y: -min(insets.top, separatorHeight)), size: CGSize(width: params.width, height: contentSize.height + min(insets.top, separatorHeight) + min(insets.bottom, separatorHeight)))
                    strongSelf.maskNode.frame = strongSelf.backgroundNode.frame.insetBy(dx: params.leftInset, dy: 0.0)
                    strongSelf.topStripeNode.frame = CGRect(origin: CGPoint(x: 0.0, y: -min(insets.top, separatorHeight)), size: CGSize(width: layoutSize.width, height: separatorHeight))
                    strongSelf.bottomStripeNode.frame = CGRect(origin: CGPoint(x: bottomStripeInset, y: contentSize.height + bottomStripeOffset), size: CGSize(width: layoutSize.width - bottomStripeInset, height: separatorHeight))

                    var validIds: [Int64] = []
                    var index = 0
                    for theme in item.themes {
                        let selected = item.currentTheme.index == theme.index
                        
                        let iconItem = ThemeCarouselThemeIconItem(context: item.context, emojiFile: theme.emoticon.flatMap { item.animatedEmojiStickers[$0]?.first?.file }, themeReference: theme, nightMode: item.nightMode, themeSpecificAccentColors: item.themeSpecificAccentColors, themeSpecificChatWallpapers: item.themeSpecificChatWallpapers, selected: selected, theme: item.theme, strings: item.strings, wallpaper: nil, action: { theme in
                            item.updatedTheme(theme)
                        }, contextAction: nil)
                        
                        validIds.append(theme.index)
                        var itemNode: ThemeGridThemeItemIconNode
                        if let current = strongSelf.itemNodes[theme.index] {
                            itemNode = current
                            itemNode.setup(item: iconItem, size: itemSize)
                        } else {
                            let addedItemNode = ThemeGridThemeItemIconNode()
                            itemNode = addedItemNode
                            addedItemNode.setup(item: iconItem, size: itemSize)
                            strongSelf.itemNodes[theme.index] = addedItemNode
                            strongSelf.addSubnode(addedItemNode)
                        }
                        
                        let col = CGFloat(index % imageCount)
                        let row = floor(CGFloat(index) / CGFloat(imageCount))
                        let itemFrame = CGRect(origin: CGPoint(x: params.leftInset + spacingOffset + itemSpacing + (itemSize.width + itemSpacing) * col, y: minSpacing + (itemSize.height + itemSpacing) * row), size: itemSize)
                        itemNode.frame = itemFrame
                        
                        index += 1
                    }
                }
            })
        }
    }
    
    override func animateInsertion(_ currentTimestamp: Double, duration: Double, short: Bool) {
        self.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.4)
    }

    override func animateRemoved(_ currentTimestamp: Double, duration: Double) {
        self.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.15, removeOnCompletion: false)
    }
    
    func prepareCrossfadeTransition() {
        guard self.snapshotView == nil else {
            return
        }
        
        if let snapshotView = self.containerNode.view.snapshotView(afterScreenUpdates: false) {
            self.view.insertSubview(snapshotView, aboveSubview: self.containerNode.view)
            self.snapshotView = snapshotView
        }
        
//        self.listNode.forEachVisibleItemNode { node in
//            if let node = node as? ThemeCarouselThemeItemIconNode {
//                node.prepareCrossfadeTransition()
//            }
//        }
    }
    
    func animateCrossfadeTransition() {
//        guard self.snapshotView?.layer.animationKeys()?.isEmpty ?? true else {
//            return
//        }
//
//        var views: [UIView] = []
//        if let snapshotView = self.snapshotView {
//            views.append(snapshotView)
//            self.snapshotView = nil
//        }
//
//        self.listNode.forEachVisibleItemNode { node in
//            if let node = node as? ThemeCarouselThemeItemIconNode {
//                if let snapshotView = node.snapshotView {
//                    views.append(snapshotView)
//                    node.snapshotView = nil
//                }
//            }
//        }
//
//        UIView.animate(withDuration: 0.3, animations: {
//            for view in views {
//                view.alpha = 0.0
//            }
//        }, completion: { _ in
//            for view in views {
//                view.removeFromSuperview()
//            }
//        })
    }
}
