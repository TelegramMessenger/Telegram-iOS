import Foundation
import UIKit
import Display
import AsyncDisplayKit
import TelegramCore
import SwiftSignalKit
import Postbox
import TelegramPresentationData
import StickerResources
import ItemListStickerPackItem
import AnimatedStickerNode
import TelegramAnimatedStickerNode
import ShimmerEffect
import MergeLists

private let boundingSize = CGSize(width: 41.0, height: 41.0)
private let boundingImageSize = CGSize(width: 28.0, height: 28.0)

private struct Transition {
    let deletions: [ListViewDeleteItem]
    let insertions: [ListViewInsertItem]
    let updates: [ListViewUpdateItem]
}

private enum EntryStableId: Hashable {
    case stickerPack(Int64)
}

private enum Entry: Comparable, Identifiable {
    case stickerPack(index: Int, info: StickerPackCollectionInfo, topItem: StickerPackItem?, unread: Bool, theme: PresentationTheme)

    var stableId: EntryStableId {
        switch self {
        case let .stickerPack(_, info, _, _, _):
            return .stickerPack(info.id.id)
        }
    }
    
    static func ==(lhs: Entry, rhs: Entry) -> Bool {
        switch lhs {
            case let .stickerPack(index, info, topItem, lhsUnread, lhsTheme):
                if case let .stickerPack(rhsIndex, rhsInfo, rhsTopItem, rhsUnread, rhsTheme) = rhs, index == rhsIndex, info == rhsInfo, topItem == rhsTopItem, lhsUnread == rhsUnread, lhsTheme === rhsTheme {
                    return true
                } else {
                    return false
                }
        }
    }
    
    static func <(lhs: Entry, rhs: Entry) -> Bool {
        switch lhs {
            case let .stickerPack(lhsIndex, lhsInfo, _, _, _):
                switch rhs {
                    case let .stickerPack(rhsIndex, rhsInfo, _, _, _):
                        if lhsIndex == rhsIndex {
                            return lhsInfo.id.id < rhsInfo.id.id
                        } else {
                            return lhsIndex <= rhsIndex
                        }
                }
        }
    }
    
    func item(account: Account, inputNodeInteraction: ChatMediaInputNodeInteraction, isVisible: @escaping () -> Bool) -> ListViewItem {
        switch self {
            case let .stickerPack(index, info, topItem, unread, theme):
                return FeaturedPackItem(account: account, inputNodeInteraction: inputNodeInteraction, collectionId: info.id, collectionInfo: info, stickerPackItem: topItem, unread: unread, index: index, theme: theme, selected: {
                    inputNodeInteraction.openTrending(info.id)
                }, isVisible: isVisible)
        }
    }
}

private func preparedEntryTransition(account: Account, from fromEntries: [Entry], to toEntries: [Entry], inputNodeInteraction: ChatMediaInputNodeInteraction, isVisible: @escaping () -> Bool) -> Transition {
    let (deleteIndices, indicesAndItems, updateIndices) = mergeListsStableWithUpdates(leftList: fromEntries, rightList: toEntries)
    
    let deletions = deleteIndices.map { ListViewDeleteItem(index: $0, directionHint: nil) }
    let insertions = indicesAndItems.map { ListViewInsertItem(index: $0.0, previousIndex: $0.2, item: $0.1.item(account: account, inputNodeInteraction: inputNodeInteraction, isVisible: isVisible), directionHint: nil) }
    let updates = updateIndices.map { ListViewUpdateItem(index: $0.0, previousIndex: $0.2, item: $0.1.item(account: account, inputNodeInteraction: inputNodeInteraction, isVisible: isVisible), directionHint: nil) }
    
    return Transition(deletions: deletions, insertions: insertions, updates: updates)
}

private func panelEntries(featuredPacks: [FeaturedStickerPackItem], theme: PresentationTheme) -> [Entry] {
    var entries: [Entry] = []
    var index = 0
    for pack in featuredPacks {
        entries.append(.stickerPack(index: index, info: pack.info, topItem: pack.topItems.first, unread: pack.unread, theme: theme))
        index += 1
    }
    return entries
}

private final class FeaturedPackItem: ListViewItem {
    let account: Account
    let inputNodeInteraction: ChatMediaInputNodeInteraction
    let collectionId: ItemCollectionId
    let collectionInfo: StickerPackCollectionInfo
    let stickerPackItem: StickerPackItem?
    let unread: Bool
    let selectedItem: () -> Void
    let index: Int
    let theme: PresentationTheme
    let isVisible: () -> Bool
    
    var selectable: Bool {
        return true
    }
    
    init(account: Account, inputNodeInteraction: ChatMediaInputNodeInteraction, collectionId: ItemCollectionId, collectionInfo: StickerPackCollectionInfo, stickerPackItem: StickerPackItem?, unread: Bool, index: Int, theme: PresentationTheme, selected: @escaping () -> Void, isVisible: @escaping () -> Bool) {
        self.account = account
        self.inputNodeInteraction = inputNodeInteraction
        self.collectionId = collectionId
        self.collectionInfo = collectionInfo
        self.stickerPackItem = stickerPackItem
        self.unread = unread
        self.index = index
        self.theme = theme
        self.selectedItem = selected
        self.isVisible = isVisible
    }
    
    func nodeConfiguredForParams(async: @escaping (@escaping () -> Void) -> Void, params: ListViewItemLayoutParams, synchronousLoads: Bool, previousItem: ListViewItem?, nextItem: ListViewItem?, completion: @escaping (ListViewItemNode, @escaping () -> (Signal<Void, NoError>?, (ListViewItemApply) -> Void)) -> Void) {
        async {
            let node = FeaturedPackItemNode()
            node.contentSize = boundingSize
            node.insets = ChatMediaInputNode.setupPanelIconInsets(item: self, previousItem: previousItem, nextItem: nextItem)
            node.inputNodeInteraction = self.inputNodeInteraction
            node.panelIsVisible = self.isVisible
            Queue.mainQueue().async {
                completion(node, {
                    return (nil, { _ in
                        node.updateStickerPackItem(account: self.account, info: self.collectionInfo, item: self.stickerPackItem, collectionId: self.collectionId, unread: self.unread, theme: self.theme)
                    })
                })
            }
        }
    }
    
    public func updateNode(async: @escaping (@escaping () -> Void) -> Void, node: @escaping () -> ListViewItemNode, params: ListViewItemLayoutParams, previousItem: ListViewItem?, nextItem: ListViewItem?, animation: ListViewItemUpdateAnimation, completion: @escaping (ListViewItemNodeLayout, @escaping (ListViewItemApply) -> Void) -> Void) {
        Queue.mainQueue().async {
            completion(ListViewItemNodeLayout(contentSize: boundingSize, insets: ChatMediaInputNode.setupPanelIconInsets(item: self, previousItem: previousItem, nextItem: nextItem)), { _ in
                (node() as? FeaturedPackItemNode)?.updateStickerPackItem(account: self.account, info: self.collectionInfo, item: self.stickerPackItem, collectionId: self.collectionId, unread: self.unread, theme: self.theme)
            })
        }
    }
    
    func selected(listView: ListView) {
        self.selectedItem()
    }
}

private final class FeaturedPackItemNode: ListViewItemNode {
    private let containerNode: ASDisplayNode
    private let imageNode: TransformImageNode
    private var animatedStickerNode: AnimatedStickerNode?
    private var placeholderNode: StickerShimmerEffectNode?
    private let unreadNode: ASImageNode
    
    var inputNodeInteraction: ChatMediaInputNodeInteraction?
    var currentCollectionId: ItemCollectionId?
    private var currentThumbnailItem: StickerPackThumbnailItem?
    private var theme: PresentationTheme?
    
    private let stickerFetchedDisposable = MetaDisposable()
    
    var panelIsVisible: () -> Bool = {
        return true
    }
    
    override var visibility: ListViewItemNodeVisibility {
        didSet {
            self.visibilityStatus = self.visibility != .none
        }
    }
    
    var visibilityStatus: Bool = false {
        didSet {
            if self.visibilityStatus != oldValue {
                self.updateVisibility()
            }
        }
    }
    
    func updateVisibility() {
        let loopAnimatedStickers = self.inputNodeInteraction?.stickerSettings?.loopAnimatedStickers ?? false
        let panelVisible = self.panelIsVisible()
        self.animatedStickerNode?.visibility = self.visibilityStatus && loopAnimatedStickers && panelVisible
    }
    
    init() {
        self.containerNode = ASDisplayNode()
        self.containerNode.transform = CATransform3DMakeRotation(CGFloat.pi / 2.0, 0.0, 0.0, 1.0)
                
        self.imageNode = TransformImageNode()
        self.imageNode.isLayerBacked = !smartInvertColorsEnabled()
                
        self.placeholderNode = StickerShimmerEffectNode()
        
        self.unreadNode = ASImageNode()
        self.unreadNode.isLayerBacked = true
        self.unreadNode.displayWithoutProcessing = true
        self.unreadNode.displaysAsynchronously = false
                               
        super.init(layerBacked: false, dynamicBounce: false)
        
        self.addSubnode(self.containerNode)
        
        self.containerNode.addSubnode(self.imageNode)
        if let placeholderNode = self.placeholderNode {
            self.containerNode.addSubnode(placeholderNode)
        }
        self.containerNode.addSubnode(self.unreadNode)
        
        var firstTime = true
        self.imageNode.imageUpdated = { [weak self] image in
            guard let strongSelf = self else {
                return
            }
            if image != nil {
                strongSelf.removePlaceholder(animated: !firstTime)
                if firstTime {
                    strongSelf.imageNode.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.2)
                }
            }
            firstTime = false
        }
    }
    
    deinit {
        self.stickerFetchedDisposable.dispose()
    }
    
    private func removePlaceholder(animated: Bool) {
        if let placeholderNode = self.placeholderNode {
            self.placeholderNode = nil
            if !animated {
                placeholderNode.removeFromSupernode()
            } else {
                placeholderNode.alpha = 0.0
                placeholderNode.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.2, completion: { [weak placeholderNode] _ in
                    placeholderNode?.removeFromSupernode()
                })
            }
        }
    }
    
    func updateStickerPackItem(account: Account, info: StickerPackCollectionInfo, item: StickerPackItem?, collectionId: ItemCollectionId, unread: Bool, theme: PresentationTheme) {
        self.currentCollectionId = collectionId
        
        if self.theme !== theme {
            self.theme = theme
        }
        
        var thumbnailItem: StickerPackThumbnailItem?
        var resourceReference: MediaResourceReference?
        if let thumbnail = info.thumbnail {
            if info.flags.contains(.isAnimated) || info.flags.contains(.isVideo) {
                thumbnailItem = .animated(thumbnail.resource, thumbnail.dimensions, info.flags.contains(.isVideo))
            } else {
                thumbnailItem = .still(thumbnail)
            }
            resourceReference = MediaResourceReference.stickerPackThumbnail(stickerPack: .id(id: info.id.id, accessHash: info.accessHash), resource: thumbnail.resource)
        } else if let item = item {
            if item.file.isAnimatedSticker || item.file.isVideoSticker {
                thumbnailItem = .animated(item.file.resource, item.file.dimensions ?? PixelDimensions(width: 100, height: 100), item.file.isVideoSticker)
                resourceReference = MediaResourceReference.media(media: .standalone(media: item.file), resource: item.file.resource)
            } else if let dimensions = item.file.dimensions, let resource = chatMessageStickerResource(file: item.file, small: true) as? TelegramMediaResource {
                thumbnailItem = .still(TelegramMediaImageRepresentation(dimensions: dimensions, resource: resource, progressiveSizes: [], immediateThumbnailData: nil))
                resourceReference = MediaResourceReference.media(media: .standalone(media: item.file), resource: resource)
            }
        }
        
        var imageSize = boundingImageSize
        
        if self.currentThumbnailItem != thumbnailItem {
            self.currentThumbnailItem = thumbnailItem
            if let thumbnailItem = thumbnailItem {
                switch thumbnailItem {
                    case let .still(representation):
                        imageSize = representation.dimensions.cgSize.aspectFitted(boundingImageSize)
                        let imageApply = self.imageNode.asyncLayout()(TransformImageArguments(corners: ImageCorners(), imageSize: imageSize, boundingSize: imageSize, intrinsicInsets: UIEdgeInsets()))
                        imageApply()
                        self.imageNode.setSignal(chatMessageStickerPackThumbnail(postbox: account.postbox, resource: representation.resource, nilIfEmpty: true))
                    case let .animated(resource, dimensions, isVideo):
                        imageSize = dimensions.cgSize.aspectFitted(boundingImageSize)
                        let imageApply = self.imageNode.asyncLayout()(TransformImageArguments(corners: ImageCorners(), imageSize: imageSize, boundingSize: imageSize, intrinsicInsets: UIEdgeInsets()))
                        imageApply()
                        self.imageNode.setSignal(chatMessageStickerPackThumbnail(postbox: account.postbox, resource: resource, animated: true, nilIfEmpty: true))
                        
                        let loopAnimatedStickers = self.inputNodeInteraction?.stickerSettings?.loopAnimatedStickers ?? false
                        
                        let animatedStickerNode: AnimatedStickerNode
                        if let current = self.animatedStickerNode {
                            animatedStickerNode = current
                        } else {
                            animatedStickerNode = AnimatedStickerNode()
                            animatedStickerNode.started = { [weak self] in
                                self?.imageNode.isHidden = true
                                self?.removePlaceholder(animated: false)
                            }
                            self.animatedStickerNode = animatedStickerNode
                            if let placeholderNode = self.placeholderNode {
                                self.containerNode.insertSubnode(animatedStickerNode, belowSubnode: placeholderNode)
                            } else {
                                self.containerNode.addSubnode(animatedStickerNode)
                            }
                            animatedStickerNode.setup(source: AnimatedStickerResourceSource(account: account, resource: resource, isVideo: isVideo), width: 128, height: 128, mode: .cached)
                        }
                        animatedStickerNode.visibility = self.visibilityStatus && loopAnimatedStickers
                }
                if let resourceReference = resourceReference {
                    self.stickerFetchedDisposable.set(fetchedMediaResource(mediaBox: account.postbox.mediaBox, reference: resourceReference).start())
                }
            }
        }
        
        if let placeholderNode = self.placeholderNode {
            var imageSize = PixelDimensions(width: 512, height: 512)
            var immediateThumbnailData: Data?
            if let data = info.immediateThumbnailData {
                if info.flags.contains(.isVideo) {
                    imageSize = PixelDimensions(width: 100, height: 100)
                }
                immediateThumbnailData = data
            } else if let data = item?.file.immediateThumbnailData {
                immediateThumbnailData = data
            }
            
            placeholderNode.update(backgroundColor: theme.chat.inputMediaPanel.stickersBackgroundColor.withAlphaComponent(1.0), foregroundColor: theme.chat.inputMediaPanel.stickersSectionTextColor.blitOver(theme.chat.inputMediaPanel.stickersBackgroundColor, alpha: 0.15), shimmeringColor: theme.list.itemBlocksBackgroundColor.withAlphaComponent(0.3), data: immediateThumbnailData, size: boundingImageSize, imageSize: imageSize.cgSize)
        }
        
        self.containerNode.frame = CGRect(origin: CGPoint(), size: boundingSize)
        
        self.imageNode.bounds = CGRect(origin: CGPoint(), size: imageSize)
        self.imageNode.position = CGPoint(x: boundingSize.height / 2.0, y: boundingSize.width / 2.0)
        if let animatedStickerNode = self.animatedStickerNode {
            animatedStickerNode.frame = self.imageNode.frame
            animatedStickerNode.updateLayout(size: self.imageNode.frame.size)
        }
        if let placeholderNode = self.placeholderNode {
            placeholderNode.bounds = CGRect(origin: CGPoint(), size: boundingImageSize)
            placeholderNode.position = self.imageNode.position
        }
        
        let unreadImage = PresentationResourcesItemList.stickerUnreadDotImage(theme)
        if unread {
            self.unreadNode.isHidden = false
        } else {
            self.unreadNode.isHidden = true
        }
        if let image = unreadImage {
            self.unreadNode.image = image
            self.unreadNode.frame = CGRect(origin: CGPoint(x: 35.0, y: 4.0), size: image.size)
        }
    }
        
    override func updateAbsoluteRect(_ rect: CGRect, within containerSize: CGSize) {
        if let placeholderNode = self.placeholderNode {
            placeholderNode.updateAbsoluteRect(rect, within: containerSize)
        }
    }
    
    override func animateAdded(_ currentTimestamp: Double, duration: Double) {
        self.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.2)
    }
    
    override func animateRemoved(_ currentTimestamp: Double, duration: Double) {
        self.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.15, removeOnCompletion: false)
    }
}


final class StickerPaneTrendingListGridItem: GridItem {
    let account: Account
    let theme: PresentationTheme
    let strings: PresentationStrings
    let trendingPacks: [FeaturedStickerPackItem]
    let inputNodeInteraction: ChatMediaInputNodeInteraction
    let dismiss: (() -> Void)?

    let section: GridSection? = nil
    let fillsRowWithDynamicHeight: ((CGFloat) -> CGFloat)?
    
    init(account: Account, theme: PresentationTheme, strings: PresentationStrings, trendingPacks: [FeaturedStickerPackItem], inputNodeInteraction: ChatMediaInputNodeInteraction, dismiss: (() -> Void)?) {
        self.account = account
        self.theme = theme
        self.strings = strings
        self.trendingPacks = trendingPacks
        self.inputNodeInteraction = inputNodeInteraction
        self.dismiss = dismiss
        self.fillsRowWithDynamicHeight = { _ in
            return 70.0
        }
    }
    
    func node(layout: GridNodeLayout, synchronousLoad: Bool) -> GridItemNode {
        let node = StickerPaneTrendingListGridItemNode()
        node.setup(item: self)
        return node
    }
    
    func update(node: GridItemNode) {
        guard let node = node as? StickerPaneTrendingListGridItemNode else {
            assertionFailure()
            return
        }
        node.setup(item: self)
    }
}

private let titleFont = Font.medium(12.0)

class StickerPaneTrendingListGridItemNode: GridItemNode {
    private let titleNode: TextNode
    private let dismissButtonNode: HighlightTrackingButtonNode
    
    private let listView: ListView
        
    private var item: StickerPaneTrendingListGridItem?
    private var appliedItem: StickerPaneTrendingListGridItem?
    
    private var isPanelVisible = false
    override var isVisibleInGrid: Bool {
        didSet {
            self.updateVisibility()
        }
    }
    
    private let disposable = MetaDisposable()
    private var currentEntries: [Entry] = []
    
    override init() {
        self.titleNode = TextNode()
        self.titleNode.isUserInteractionEnabled = false
        self.titleNode.contentMode = .left
        self.titleNode.contentsScale = UIScreen.main.scale
        
        self.dismissButtonNode = HighlightTrackingButtonNode()
        
        self.listView = ListView()
        self.listView.transform = CATransform3DMakeRotation(-CGFloat(Double.pi / 2.0), 0.0, 0.0, 1.0)
        self.listView.scroller.panGestureRecognizer.cancelsTouchesInView = false
        
        super.init()
        
        self.addSubnode(self.titleNode)
        self.addSubnode(self.listView)
        self.addSubnode(self.dismissButtonNode)
        
        self.dismissButtonNode.addTarget(self, action: #selector(self.dismissPressed), forControlEvents: .touchUpInside)
    }
    
    deinit {
        self.disposable.dispose()
    }
    
    private func enqueuePanelTransition(_ transition: Transition, firstTime: Bool) {
        var options = ListViewDeleteAndInsertOptions()
        if firstTime {
            options.insert(.Synchronous)
            options.insert(.LowLatency)
        } else {
            options.insert(.AnimateInsertion)
        }
        
        self.listView.transaction(deleteIndices: transition.deletions, insertIndicesAndItems: transition.insertions, updateIndicesAndItems: transition.updates, options: options, scrollToItem: nil, updateOpaqueState: nil, completion: { _ in })
    }
    
    func setup(item: StickerPaneTrendingListGridItem) {
        self.item = item
        
        let entries = panelEntries(featuredPacks: item.trendingPacks, theme: item.theme)
        let transition = preparedEntryTransition(account: item.account, from: self.currentEntries, to: entries, inputNodeInteraction: item.inputNodeInteraction, isVisible: { [weak self] in
            if let strongSelf = self {
                return strongSelf.isPanelVisible && strongSelf.isVisibleInGrid
            } else {
                return false
            }
        })
        self.enqueuePanelTransition(transition, firstTime: self.currentEntries.isEmpty)
        self.currentEntries = entries
        
        self.setNeedsLayout()
    }
    
    func updateIsPanelVisible(_ isPanelVisible: Bool) {
        if self.isPanelVisible != isPanelVisible {
            self.isPanelVisible = isPanelVisible
            self.updateVisibility()
        }
    }
    
    func updateVisibility() {
        self.listView.forEachItemNode { itemNode in
            if let itemNode = itemNode as? FeaturedPackItemNode {
                itemNode.updateVisibility()
            }
        }
    }
    
    override func layout() {
        super.layout()
        guard let item = self.item else {
            return
        }
        
        let params = ListViewItemLayoutParams(width: self.bounds.size.width, leftInset: 0.0, rightInset: 0.0, availableHeight: self.bounds.size.height)
        
        let makeTitleLayout = TextNode.asyncLayout(self.titleNode)
        
        let currentItem = self.appliedItem
        self.appliedItem = item
        
        let width = self.bounds.size.width
        
        self.listView.bounds = CGRect(x: 0.0, y: 0.0, width: 41.0, height: width)
        self.listView.position = CGPoint(x: width / 2.0, y: 26.0 + 41.0 / 2.0)
        
        let (duration, curve) = listViewAnimationDurationAndCurve(transition: .immediate)
        let updateSizeAndInsets = ListViewUpdateSizeAndInsets(size: CGSize(width: 41.0, height: self.bounds.size.width), insets: UIEdgeInsets(top: 4.0, left: 0.0, bottom: 4.0, right: 0.0), duration: duration, curve: curve)
        
        self.listView.transaction(deleteIndices: [], insertIndicesAndItems: [], updateIndicesAndItems: [], options: [.Synchronous, .LowLatency], scrollToItem: nil, updateSizeAndInsets: updateSizeAndInsets, stationaryItemRange: nil, updateOpaqueState: nil, completion: { _ in })
        
        if currentItem?.theme !== item.theme {
            self.dismissButtonNode.setImage(PresentationResourcesChat.chatInputMediaPanelGridDismissImage(item.theme), for: [])
        }
        
        let leftInset: CGFloat = 12.0
        let rightInset: CGFloat = 16.0
        let topOffset: CGFloat = 9.0
        
        let (titleLayout, titleApply) = makeTitleLayout(TextNodeLayoutArguments(attributedString: NSAttributedString(string: item.strings.StickerPacksSettings_FeaturedPacks.uppercased(), font: titleFont, textColor: item.theme.chat.inputMediaPanel.stickersSectionTextColor), backgroundColor: nil, maximumNumberOfLines: 1, truncationType: .end, constrainedSize: CGSize(width: params.width - params.leftInset - params.rightInset - leftInset - rightInset - 20.0, height: CGFloat.greatestFiniteMagnitude), alignment: .natural, cutout: nil, insets: UIEdgeInsets()))
        
        self.item = item
        
        let _ = titleApply()
        
        let titleFrame = CGRect(origin: CGPoint(x: params.leftInset + leftInset, y: topOffset), size: titleLayout.size)
        let dismissButtonSize = CGSize(width: 12.0, height: 12.0)
        self.dismissButtonNode.frame = CGRect(origin: CGPoint(x: params.width - params.rightInset - rightInset - dismissButtonSize.width + 1.0, y: topOffset - 1.0), size: dismissButtonSize)
        self.dismissButtonNode.isHidden = item.dismiss == nil
        self.titleNode.frame = titleFrame
    }
    
    @objc private func dismissPressed() {
        if let item = self.item {
            item.dismiss?()
        }
    }
}
