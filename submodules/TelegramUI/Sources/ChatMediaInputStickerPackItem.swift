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

final class ChatMediaInputStickerPackItem: ListViewItem {
    let account: Account
    let inputNodeInteraction: ChatMediaInputNodeInteraction
    let collectionId: ItemCollectionId
    let collectionInfo: StickerPackCollectionInfo
    let stickerPackItem: StickerPackItem?
    let selectedItem: () -> Void
    let index: Int
    let theme: PresentationTheme
    let expanded: Bool
    let reorderable: Bool
    
    var selectable: Bool {
        return true
    }
    
    init(account: Account, inputNodeInteraction: ChatMediaInputNodeInteraction, collectionId: ItemCollectionId, collectionInfo: StickerPackCollectionInfo, stickerPackItem: StickerPackItem?, index: Int, theme: PresentationTheme, expanded: Bool, reorderable: Bool, selected: @escaping () -> Void) {
        self.account = account
        self.inputNodeInteraction = inputNodeInteraction
        self.collectionId = collectionId
        self.collectionInfo = collectionInfo
        self.stickerPackItem = stickerPackItem
        self.selectedItem = selected
        self.index = index
        self.theme = theme
        self.expanded = expanded
        self.reorderable = reorderable
    }
    
    func nodeConfiguredForParams(async: @escaping (@escaping () -> Void) -> Void, params: ListViewItemLayoutParams, synchronousLoads: Bool, previousItem: ListViewItem?, nextItem: ListViewItem?, completion: @escaping (ListViewItemNode, @escaping () -> (Signal<Void, NoError>?, (ListViewItemApply) -> Void)) -> Void) {
        async {
            let node = ChatMediaInputStickerPackItemNode()
            node.contentSize = self.expanded ? expandedBoundingSize : boundingSize
            node.insets = ChatMediaInputNode.setupPanelIconInsets(item: self, previousItem: previousItem, nextItem: nextItem)
            node.inputNodeInteraction = self.inputNodeInteraction
            Queue.mainQueue().async {
                completion(node, {
                    return (nil, { _ in
                        node.updateStickerPackItem(account: self.account, info: self.collectionInfo, item: self.stickerPackItem, collectionId: self.collectionId, theme: self.theme, expanded: self.expanded, reorderable: self.reorderable)
                        node.updateAppearanceTransition(transition: .immediate)
                    })
                })
            }
        }
    }
    
    public func updateNode(async: @escaping (@escaping () -> Void) -> Void, node: @escaping () -> ListViewItemNode, params: ListViewItemLayoutParams, previousItem: ListViewItem?, nextItem: ListViewItem?, animation: ListViewItemUpdateAnimation, completion: @escaping (ListViewItemNodeLayout, @escaping (ListViewItemApply) -> Void) -> Void) {
        Queue.mainQueue().async {
            completion(ListViewItemNodeLayout(contentSize: self.expanded ? expandedBoundingSize : boundingSize, insets: ChatMediaInputNode.setupPanelIconInsets(item: self, previousItem: previousItem, nextItem: nextItem)), { _ in
                (node() as? ChatMediaInputStickerPackItemNode)?.updateStickerPackItem(account: self.account, info: self.collectionInfo, item: self.stickerPackItem, collectionId: self.collectionId, theme: self.theme, expanded: self.expanded, reorderable: self.reorderable)
            })
        }
    }
    
    func selected(listView: ListView) {
        self.selectedItem()
    }
}

private let boundingSize = CGSize(width: 72.0, height: 41.0)
private let expandedBoundingSize = CGSize(width: 72.0, height: 72.0)
private let boundingImageSize = CGSize(width: 45.0, height: 45.0)
private let boundingImageScale: CGFloat = 0.625
private let highlightSize = CGSize(width: 56.0, height: 56.0)
private let verticalOffset: CGFloat = -3.0

final class ChatMediaInputStickerPackItemNode: ListViewItemNode {
    private let containerNode: ASDisplayNode
    private let scalingNode: ASDisplayNode
    private let imageNode: TransformImageNode
    private var animatedStickerNode: AnimatedStickerNode?
    private var placeholderNode: StickerShimmerEffectNode?
    private let highlightNode: ASImageNode
    private let titleNode: ImmediateTextNode
    
    var inputNodeInteraction: ChatMediaInputNodeInteraction?
    var currentCollectionId: ItemCollectionId?
    private var account: Account?
    private var currentThumbnailItem: StickerPackThumbnailItem?
    private var currentExpanded = false
    private var theme: PresentationTheme?
    private var reorderable = false
    
    private let stickerFetchedDisposable = MetaDisposable()
    
    override var visibility: ListViewItemNodeVisibility {
        didSet {
            self.visibilityStatus = self.visibility != .none
        }
    }
    
    private var visibilityStatus: Bool = false {
        didSet {
            if self.visibilityStatus != oldValue {
                let loopAnimatedStickers = self.inputNodeInteraction?.stickerSettings?.loopAnimatedStickers ?? false
                self.animatedStickerNode?.visibility = self.visibilityStatus && loopAnimatedStickers
            }
        }
    }
    
    init() {
        self.containerNode = ASDisplayNode()
        self.containerNode.transform = CATransform3DMakeRotation(CGFloat.pi / 2.0, 0.0, 0.0, 1.0)
        
        self.scalingNode = ASDisplayNode()
        
        self.highlightNode = ASImageNode()
        self.highlightNode.isLayerBacked = true
        self.highlightNode.isHidden = true
        
        self.imageNode = TransformImageNode()
        self.imageNode.isLayerBacked = !smartInvertColorsEnabled()
                
        self.placeholderNode = StickerShimmerEffectNode()
       
        self.titleNode = ImmediateTextNode()
                        
        super.init(layerBacked: false, dynamicBounce: false)
        
        self.addSubnode(self.containerNode)
        self.containerNode.addSubnode(self.scalingNode)
        
        self.scalingNode.addSubnode(self.highlightNode)
        self.scalingNode.addSubnode(self.titleNode)
        self.scalingNode.addSubnode(self.imageNode)
        if let placeholderNode = self.placeholderNode {
            self.scalingNode.addSubnode(placeholderNode)
        }
        
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
    
    func updateStickerPackItem(account: Account, info: StickerPackCollectionInfo, item: StickerPackItem?, collectionId: ItemCollectionId, theme: PresentationTheme, expanded: Bool, reorderable: Bool) {
        self.currentCollectionId = collectionId
        self.account = account
        self.reorderable = reorderable
        var themeUpdated = false
        if self.theme !== theme {
            self.theme = theme
            themeUpdated = true
            
            self.highlightNode.image = PresentationResourcesChat.chatMediaInputPanelHighlightedIconImage(theme)
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
                thumbnailItem = .still(TelegramMediaImageRepresentation(dimensions: dimensions, resource: resource, progressiveSizes: [], immediateThumbnailData: nil, hasVideo: false))
                resourceReference = MediaResourceReference.media(media: .standalone(media: item.file), resource: resource)
            }
        }
        
        if themeUpdated || self.titleNode.attributedText?.string != info.title {
            self.titleNode.attributedText = NSAttributedString(string: info.title, font: Font.regular(11.0), textColor: theme.chat.inputPanel.primaryTextColor)
        }
        
        let boundsSize = expanded ? expandedBoundingSize : CGSize(width: boundingSize.height, height: boundingSize.height)
        var imageSize = boundingImageSize
        
        if self.currentThumbnailItem != thumbnailItem {
            self.currentThumbnailItem = thumbnailItem
            if let thumbnailItem = thumbnailItem {
                switch thumbnailItem {
                    case let .still(representation):
                        imageSize = representation.dimensions.cgSize.aspectFitted(boundingImageSize)
                        let imageApply = self.imageNode.asyncLayout()(TransformImageArguments(corners: ImageCorners(radius: 6.0), imageSize: imageSize, boundingSize: boundingImageSize, intrinsicInsets: UIEdgeInsets()))
                        imageApply()
                        self.imageNode.setSignal(chatMessageStickerPackThumbnail(postbox: account.postbox, resource: representation.resource, nilIfEmpty: true))
                    case let .animated(resource, dimensions, isVideo):
                        imageSize = dimensions.cgSize.aspectFitted(boundingImageSize)
                        let imageApply = self.imageNode.asyncLayout()(TransformImageArguments(corners: ImageCorners(), imageSize: imageSize, boundingSize: boundingImageSize, intrinsicInsets: UIEdgeInsets()))
                        imageApply()
                        self.imageNode.setSignal(chatMessageStickerPackThumbnail(postbox: account.postbox, resource: resource, animated: true, nilIfEmpty: true))
                        
                        let loopAnimatedStickers = self.inputNodeInteraction?.stickerSettings?.loopAnimatedStickers ?? false
    
                        let animatedStickerNode: AnimatedStickerNode
                        if let current = self.animatedStickerNode {
                            animatedStickerNode = current
                        } else {
                            animatedStickerNode = DefaultAnimatedStickerNodeImpl()
                            animatedStickerNode.started = { [weak self] in
                                self?.imageNode.isHidden = true
                                self?.removePlaceholder(animated: false)
                            }
                            self.animatedStickerNode = animatedStickerNode
                            if let placeholderNode = self.placeholderNode {
                                self.scalingNode.insertSubnode(animatedStickerNode, belowSubnode: placeholderNode)
                            } else {
                                self.scalingNode.addSubnode(animatedStickerNode)
                            }
                            animatedStickerNode.setup(source: AnimatedStickerResourceSource(account: account, resource: resource, isVideo: isVideo), width: 128, height: 128, playbackMode: .loop, mode: .cached)
                        }
                        animatedStickerNode.visibility = self.visibilityStatus && loopAnimatedStickers
                }
                if let resourceReference = resourceReference {
                    self.stickerFetchedDisposable.set(fetchedMediaResource(mediaBox: account.postbox.mediaBox, reference: resourceReference).start())
                }
            }
                                    
            self.updateIsHighlighted()
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
            
            placeholderNode.update(backgroundColor: nil, foregroundColor: theme.chat.inputMediaPanel.stickersSectionTextColor.blitOver(theme.chat.inputPanel.panelBackgroundColor, alpha: 0.4), shimmeringColor: theme.chat.inputMediaPanel.panelHighlightedIconBackgroundColor.withMultipliedAlpha(0.2), data: immediateThumbnailData, size: boundingImageSize, imageSize: imageSize.cgSize)
        }
        
        self.containerNode.frame = CGRect(origin: CGPoint(x: 0.0, y: 0.0), size: expandedBoundingSize)
        self.scalingNode.bounds = CGRect(origin: CGPoint(), size: expandedBoundingSize)
        
        let expandScale: CGFloat = expanded ? 1.0 : boundingImageScale
        let expandTransition: ContainedViewLayoutTransition = self.currentExpanded != expanded ? .animated(duration: 0.3, curve: .spring) : .immediate
        expandTransition.updateTransformScale(node: self.scalingNode, scale: expandScale)
        expandTransition.updatePosition(node: self.scalingNode, position: CGPoint(x: boundsSize.width / 2.0, y: boundsSize.height / 2.0 + (expanded ? -53.0 : -7.0)))

        let titleSize = self.titleNode.updateLayout(CGSize(width: expandedBoundingSize.width - 4.0, height: expandedBoundingSize.height))
        
        let titleFrame = CGRect(origin: CGPoint(x: floorToScreenPixels((expandedBoundingSize.width - titleSize.width) / 2.0), y: expandedBoundingSize.height - titleSize.height + 6.0), size: titleSize)
        let displayTitleFrame = expanded ? titleFrame : CGRect(origin: CGPoint(x: titleFrame.minX, y: self.imageNode.position.y - titleFrame.size.height), size: titleFrame.size)
        expandTransition.updateFrameAsPositionAndBounds(node: self.titleNode, frame: displayTitleFrame)
        expandTransition.updateTransformScale(node: self.titleNode, scale: expanded ? 1.0 : 0.001)
        
        let alphaTransition: ContainedViewLayoutTransition = self.currentExpanded != expanded ? .animated(duration: expanded ? 0.15 : 0.1, curve: .linear) : .immediate
        alphaTransition.updateAlpha(node: self.titleNode, alpha: expanded ? 1.0 : 0.0, delay: expanded ? 0.05 : 0.0)
        
        self.currentExpanded = expanded
        
        self.imageNode.bounds = CGRect(origin: CGPoint(), size: imageSize)
        self.imageNode.position = CGPoint(x: expandedBoundingSize.height / 2.0, y: expandedBoundingSize.width / 2.0)
        if let animatedStickerNode = self.animatedStickerNode {
            animatedStickerNode.frame = self.imageNode.frame
            animatedStickerNode.updateLayout(size: self.imageNode.frame.size)
        }
        if let placeholderNode = self.placeholderNode {
            placeholderNode.bounds = CGRect(origin: CGPoint(), size: boundingImageSize)
            placeholderNode.position = self.imageNode.position
        }
        expandTransition.updateFrame(node: self.highlightNode, frame: expanded ? titleFrame.insetBy(dx: -7.0, dy: -2.0) : CGRect(origin: CGPoint(x: self.imageNode.position.x - highlightSize.width / 2.0, y: self.imageNode.position.y - highlightSize.height / 2.0), size: highlightSize))
    }
        
    override func updateAbsoluteRect(_ rect: CGRect, within containerSize: CGSize) {
        if let placeholderNode = self.placeholderNode {
            placeholderNode.updateAbsoluteRect(rect, within: containerSize)
        }
    }
    
    func updateIsHighlighted() {
        assert(Queue.mainQueue().isCurrent())
        if let currentCollectionId = self.currentCollectionId, let inputNodeInteraction = self.inputNodeInteraction {
            self.highlightNode.isHidden = inputNodeInteraction.highlightedItemCollectionId != currentCollectionId
        }
    }
    
    func updateAppearanceTransition(transition: ContainedViewLayoutTransition) {
        assert(Queue.mainQueue().isCurrent())
        if let inputNodeInteraction = self.inputNodeInteraction {
            transition.updateSublayerTransformScale(node: self, scale: inputNodeInteraction.appearanceTransition)
        }
    }
    
    override func animateAdded(_ currentTimestamp: Double, duration: Double) {
        self.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.2)
    }
    
    override func animateRemoved(_ currentTimestamp: Double, duration: Double) {
        self.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.15, removeOnCompletion: false)
    }
    
    override func isReorderable(at point: CGPoint) -> Bool {
        guard self.reorderable else {
            return false
        }
        if self.bounds.inset(by: UIEdgeInsets(top: 0.0, left: 0.0, bottom: 0.0, right: -28.0)).contains(point) {
            return true
        }
        return false
    }
    
    override func snapshotForReordering() -> UIView? {
        if let account = self.account, let thumbnailItem = self.currentThumbnailItem {
            var imageSize = boundingImageSize
            let loopAnimatedStickers = self.inputNodeInteraction?.stickerSettings?.loopAnimatedStickers ?? false
            let containerNode = ASDisplayNode()
            let scalingNode = ASDisplayNode()
            containerNode.addSubnode(scalingNode)
            containerNode.transform = CATransform3DMakeRotation(CGFloat.pi / 2.0, 0.0, 0.0, 1.0)
            
            var snapshotImageNode: TransformImageNode?
            var snapshotAnimationNode: AnimatedStickerNode?
            switch thumbnailItem {
                case let .still(representation):
                    imageSize = representation.dimensions.cgSize.aspectFitted(boundingImageSize)
                    
                    let imageNode = TransformImageNode()
                    let imageApply = imageNode.asyncLayout()(TransformImageArguments(corners: ImageCorners(radius: 6.0), imageSize: imageSize, boundingSize: boundingImageSize, intrinsicInsets: UIEdgeInsets()))
                    imageApply()
                    imageNode.setSignal(chatMessageStickerPackThumbnail(postbox: account.postbox, resource: representation.resource, nilIfEmpty: true))
                    scalingNode.addSubnode(imageNode)
                    
                    snapshotImageNode = imageNode
                case let .animated(resource, dimensions, isVideo):
                    imageSize = dimensions.cgSize.aspectFitted(boundingImageSize)
                
                    let animatedStickerNode = DefaultAnimatedStickerNodeImpl()
                    animatedStickerNode.setup(source: AnimatedStickerResourceSource(account: account, resource: resource, isVideo: isVideo), width: 128, height: 128, mode: .cached)
                    animatedStickerNode.visibility = self.visibilityStatus && loopAnimatedStickers
                    scalingNode.addSubnode(animatedStickerNode)
                    
                    animatedStickerNode.cloneCurrentFrame(from: self.animatedStickerNode)
                    animatedStickerNode.play(fromIndex: self.animatedStickerNode?.currentFrameIndex)
                    
                    snapshotAnimationNode = animatedStickerNode
            }
            
            containerNode.frame = CGRect(origin: CGPoint(x: 0.0, y: 0.0), size: expandedBoundingSize)
            scalingNode.bounds = CGRect(origin: CGPoint(), size: expandedBoundingSize)
            
            if let titleView = self.titleNode.view.snapshotContentTree() {
                titleView.frame = self.titleNode.frame
                scalingNode.view.addSubview(titleView)
            }
            
            let imageFrame = CGRect(origin: CGPoint(x: (expandedBoundingSize.height - imageSize.width) / 2.0, y: (expandedBoundingSize.width - imageSize.height) / 2.0), size: imageSize)
            if let imageNode = snapshotImageNode {
                imageNode.bounds = CGRect(origin: CGPoint(), size: imageSize)
                imageNode.position = imageFrame.center
            }
            if let animatedStickerNode = snapshotAnimationNode {
                animatedStickerNode.frame = imageFrame
                animatedStickerNode.updateLayout(size: imageFrame.size)
            }

            let expanded = self.currentExpanded
            let scale = expanded ? 1.0 : boundingImageScale
            let boundsSize = expanded ? expandedBoundingSize : CGSize(width: boundingSize.height, height: boundingSize.height)
            scalingNode.transform = CATransform3DMakeScale(scale, scale, 1.0)
            scalingNode.position = CGPoint(x: boundsSize.width / 2.0 + 3.0, y: boundsSize.height / 2.0 + (expanded ? -53.0 : -7.0) - 3.0)
            
            return containerNode.view
        }
        return nil
    }
}
