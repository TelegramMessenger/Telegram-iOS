import Foundation
import UIKit
import Display
import AsyncDisplayKit
import SwiftSignalKit
import Postbox
import TelegramCore
import TelegramPresentationData
import ItemListUI
import PresentationDataUtils
import ActivityIndicator
import StickerResources
import AnimatedStickerNode
import TelegramAnimatedStickerNode
import ShimmerEffect
import AppBundle

enum GroupStickerPackCurrentItemContent: Equatable {
    case notFound(isEmoji: Bool)
    case searching
    case found(packInfo: StickerPackCollectionInfo, topItem: StickerPackItem?, subtitle: String)
}

final class GroupStickerPackCurrentItem: ListViewItem, ItemListItem {
    let theme: PresentationTheme
    let strings: PresentationStrings
    let account: Account
    let content: GroupStickerPackCurrentItemContent
    let sectionId: ItemListSectionId
    let action: (() -> Void)?
    let remove: (() -> Void)?
    
    init(theme: PresentationTheme, strings: PresentationStrings, account: Account, content: GroupStickerPackCurrentItemContent, sectionId: ItemListSectionId, action: (() -> Void)?, remove: (() -> Void)?) {
        self.theme = theme
        self.strings = strings
        self.account = account
        self.content = content
        self.sectionId = sectionId
        self.action = action
        self.remove = remove
    }
    
    func nodeConfiguredForParams(async: @escaping (@escaping () -> Void) -> Void, params: ListViewItemLayoutParams, synchronousLoads: Bool, previousItem: ListViewItem?, nextItem: ListViewItem?, completion: @escaping (ListViewItemNode, @escaping () -> (Signal<Void, NoError>?, (ListViewItemApply) -> Void)) -> Void) {
        async {
            let node = GroupStickerPackCurrentItemNode()
            let (layout, apply) = node.asyncLayout()(self, params, itemListNeighbors(item: self, topItem: previousItem as? ItemListItem, bottomItem: nextItem as? ItemListItem))
            
            node.contentSize = layout.contentSize
            node.insets = layout.insets
            
            Queue.mainQueue().async {
                completion(node, {
                    return (nil, { _ in apply(false) })
                })
            }
        }
    }
    
    func updateNode(async: @escaping (@escaping () -> Void) -> Void, node: @escaping () -> ListViewItemNode, params: ListViewItemLayoutParams, previousItem: ListViewItem?, nextItem: ListViewItem?, animation: ListViewItemUpdateAnimation, completion: @escaping (ListViewItemNodeLayout, @escaping (ListViewItemApply) -> Void) -> Void) {
        Queue.mainQueue().async {
            if let nodeValue = node() as? GroupStickerPackCurrentItemNode {
                let makeLayout = nodeValue.asyncLayout()
                
                var animated = true
                if case .None = animation {
                    animated = false
                }
                
                async {
                    let (layout, apply) = makeLayout(self, params, itemListNeighbors(item: self, topItem: previousItem as? ItemListItem, bottomItem: nextItem as? ItemListItem))
                    Queue.mainQueue().async {
                        completion(layout, { _ in
                            apply(animated)
                        })
                    }
                }
            }
        }
    }
    
    var selectable: Bool = true
    
    func selected(listView: ListView){
        listView.clearHighlightAnimated(true)
        self.action?()
    }
}

private let titleFont = Font.bold(15.0)
private let statusFont = Font.regular(14.0)

class GroupStickerPackCurrentItemNode: ItemListRevealOptionsItemNode {
    private let backgroundNode: ASDisplayNode
    private let topStripeNode: ASDisplayNode
    private let bottomStripeNode: ASDisplayNode
    private let highlightedBackgroundNode: ASDisplayNode
    private let maskNode: ASImageNode
    
    fileprivate let imageNode: TransformImageNode
    private var animationNode: AnimatedStickerNode?
    private var placeholderNode: StickerShimmerEffectNode?
    
    private let notFoundNode: ASImageNode
    private let titleNode: TextNode
    private let statusNode: TextNode
    private let activityIndicator: ActivityIndicator
    
    private let removeButton: HighlightTrackingButtonNode
    private let removeButtonIcon: ASImageNode
    
    private var item: GroupStickerPackCurrentItem?
    
    private var editableControlNode: ItemListEditableControlNode?
    
    private let fetchDisposable = MetaDisposable()
    
    override var canBeSelected: Bool {
        if let item = self.item {
            if case .found = item.content {
                return true
            }
        }
        return false
    }
    
    init() {
        self.backgroundNode = ASDisplayNode()
        self.backgroundNode.isLayerBacked = true
        
        self.topStripeNode = ASDisplayNode()
        self.topStripeNode.isLayerBacked = true
        
        self.bottomStripeNode = ASDisplayNode()
        self.bottomStripeNode.isLayerBacked = true
        
        self.maskNode = ASImageNode()
        self.maskNode.isUserInteractionEnabled = false
        
        self.imageNode = TransformImageNode()
        self.imageNode.isLayerBacked = !smartInvertColorsEnabled()
        
        self.placeholderNode = StickerShimmerEffectNode()
        self.placeholderNode?.isUserInteractionEnabled = false
        
        self.notFoundNode = ASImageNode()
        self.notFoundNode.isLayerBacked = true
        self.notFoundNode.displayWithoutProcessing = true
        self.notFoundNode.displaysAsynchronously = false
        
        self.titleNode = TextNode()
        self.titleNode.isUserInteractionEnabled = false
        self.titleNode.displaysAsynchronously = false
        self.titleNode.contentMode = .left
        self.titleNode.contentsScale = UIScreen.main.scale
        
        self.statusNode = TextNode()
        self.statusNode.isUserInteractionEnabled = false
        self.statusNode.displaysAsynchronously = false
        self.statusNode.contentMode = .left
        self.statusNode.contentsScale = UIScreen.main.scale
        
        self.activityIndicator = ActivityIndicator(type: .custom(.blue, 22.0, 1.0, false))
        
        self.highlightedBackgroundNode = ASDisplayNode()
        self.highlightedBackgroundNode.isLayerBacked = true
        
        self.removeButton = HighlightTrackingButtonNode(pointerStyle: nil)
        self.removeButtonIcon = ASImageNode()
        self.removeButtonIcon.displaysAsynchronously = false
        
        super.init(layerBacked: false, dynamicBounce: false, rotated: false, seeThrough: false)
        
        if let placeholderNode = self.placeholderNode {
            self.addSubnode(placeholderNode)
        }
        
        self.addSubnode(self.imageNode)
        self.addSubnode(self.titleNode)
        self.addSubnode(self.statusNode)
        self.addSubnode(self.notFoundNode)
        self.addSubnode(self.activityIndicator)
        
        self.addSubnode(self.removeButtonIcon)
        self.addSubnode(self.removeButton)
        
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
        
        self.removeButton.addTarget(self, action: #selector(self.removeButtonPressed), forControlEvents: .touchUpInside)
        self.removeButton.highligthedChanged = { [weak self] highlighted in
            if let self {
                if highlighted {
                    self.removeButtonIcon.layer.removeAnimation(forKey: "opacity")
                    self.removeButtonIcon.alpha = 0.4
                } else {
                    self.removeButtonIcon.alpha = 1.0
                    self.removeButtonIcon.layer.animateAlpha(from: 0.4, to: 1.0, duration: 0.2)
                }
            }
        }
    }
    
    deinit {
        self.fetchDisposable.dispose()
    }
    
    @objc private func removeButtonPressed() {
        self.item?.remove?()
    }
    
    private func removePlaceholder(animated: Bool) {
        if let placeholderNode = self.placeholderNode {
            self.placeholderNode = nil
            if !animated {
                placeholderNode.removeFromSupernode()
            } else {
                placeholderNode.allowsGroupOpacity = true
                placeholderNode.alpha = 0.0
                placeholderNode.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.2, completion: { [weak placeholderNode] _ in
                    placeholderNode?.removeFromSupernode()
                    placeholderNode?.allowsGroupOpacity = false
                })
            }
        }
    }
    
    private var absoluteLocation: (CGRect, CGSize)?
    override func updateAbsoluteRect(_ rect: CGRect, within containerSize: CGSize) {
        self.absoluteLocation = (rect, containerSize)
        if let placeholderNode = placeholderNode {
            placeholderNode.updateAbsoluteRect(CGRect(origin: CGPoint(x: rect.minX + placeholderNode.frame.minX, y: rect.minY + placeholderNode.frame.minY), size: placeholderNode.frame.size), within: containerSize)
        }
    }
    
    func asyncLayout() -> (_ item: GroupStickerPackCurrentItem, _ params: ListViewItemLayoutParams, _ neighbors: ItemListNeighbors) -> (ListViewItemNodeLayout, (Bool) -> Void) {
        let makeImageLayout = self.imageNode.asyncLayout()
        let makeTitleLayout = TextNode.asyncLayout(self.titleNode)
        let makeStatusLayout = TextNode.asyncLayout(self.statusNode)
        
        let currentItem = self.item
        
        return { item, params, neighbors in
            var titleAttributedString: NSAttributedString?
            var statusAttributedString: NSAttributedString?
            
            var updatedTheme: PresentationTheme?
            
            var updatedNotFoundImage: UIImage?
            if currentItem?.theme !== item.theme {
                updatedTheme = item.theme
                updatedNotFoundImage = generateTintedImage(image: UIImage(bundleImageName: "Peer Info/GroupStickerPackNotFound"), color: item.theme.list.freeMonoIconColor)
            }
            
            let rightInset: CGFloat = params.rightInset
            
            var file: TelegramMediaFile?
            var previousFile: TelegramMediaFile?
            if let currentItem = currentItem, case let .found(_, topItem, _) = currentItem.content {
                previousFile = topItem?.file._parse()
            }
            
            switch item.content {
                case let .notFound(isEmoji):
                    titleAttributedString = NSAttributedString(string: isEmoji ? item.strings.Group_Emoji_NotFound : item.strings.Channel_Stickers_NotFound, font: titleFont, textColor: item.theme.list.itemDestructiveColor)
                    statusAttributedString = NSAttributedString(string: isEmoji ? item.strings.Group_Emoji_NotFoundHelp : item.strings.Channel_Stickers_NotFoundHelp, font: statusFont, textColor: item.theme.list.itemSecondaryTextColor)
                case .searching:
                    titleAttributedString = NSAttributedString(string: item.strings.Channel_Stickers_Searching, font: titleFont, textColor: item.theme.list.itemPrimaryTextColor)
                    statusAttributedString = NSAttributedString(string: "", font: statusFont, textColor: item.theme.list.itemSecondaryTextColor)
                case let .found(packInfo, topItem, subtitle):
                    file = topItem?.file._parse()
                    titleAttributedString = NSAttributedString(string: packInfo.title, font: titleFont, textColor: item.theme.list.itemPrimaryTextColor)
                    statusAttributedString = NSAttributedString(string: subtitle, font: statusFont, textColor: item.theme.list.itemSecondaryTextColor)
            }
            
            var fileUpdated = false
            if let file = file, let previousFile = previousFile {
                fileUpdated = !file.isEqual(to: previousFile)
            } else if (file != nil) != (previousFile != nil) {
                fileUpdated = true
            }
            
            let leftInset: CGFloat = 65.0 + params.leftInset
            
            let insets = itemListNeighborsGroupedInsets(neighbors, params)
            let contentSize = CGSize(width: params.width, height: 59.0)
            let separatorHeight = UIScreenPixel
            
            let layout = ListViewItemNodeLayout(contentSize: contentSize, insets: insets)
            let layoutSize = layout.size
            
            let editingOffset: CGFloat = 0.0
            
            let (titleLayout, titleApply) = makeTitleLayout(TextNodeLayoutArguments(attributedString: titleAttributedString, backgroundColor: nil, maximumNumberOfLines: 1, truncationType: .end, constrainedSize: CGSize(width: params.width - leftInset - 8.0 - rightInset - 10.0, height: CGFloat.greatestFiniteMagnitude), alignment: .natural, cutout: nil, insets: UIEdgeInsets()))
            let (statusLayout, statusApply) = makeStatusLayout(TextNodeLayoutArguments(attributedString: statusAttributedString, backgroundColor: nil, maximumNumberOfLines: 1, truncationType: .end, constrainedSize: CGSize(width: params.width - leftInset - 8.0 - rightInset, height: CGFloat.greatestFiniteMagnitude), alignment: .natural, cutout: nil, insets: UIEdgeInsets()))
            
            var imageApply: (() -> Void)?
            var imageSize: CGSize = CGSize(width: 34.0, height: 34.0)
            if let file = file, let dimensions = file.dimensions {
                let imageBoundingSize = CGSize(width: 34.0, height: 34.0)
                imageSize = dimensions.cgSize.aspectFitted(imageBoundingSize)
                imageApply = makeImageLayout(TransformImageArguments(corners: ImageCorners(), imageSize: imageSize, boundingSize: imageSize, intrinsicInsets: UIEdgeInsets()))
            }
            
            var updatedImageSignal: Signal<(TransformImageArguments) -> DrawingContext?, NoError>?
            var updatedFetchSignal: Signal<FetchResourceSourceType, FetchResourceError>?
            if fileUpdated {
                if let file = file {
                    updatedImageSignal = chatMessageSticker(account: item.account, userLocation: .other, file: file, small: false)
                    updatedFetchSignal = fetchedMediaResource(mediaBox: item.account.postbox.mediaBox, userLocation: .other, userContentType: .sticker, reference: stickerPackFileReference(file).resourceReference(file.resource))
                } else {
                    updatedImageSignal = .single({ _ in return nil })
                    updatedFetchSignal = .complete()
                }
            }
            
            return (layout, { [weak self] animated in
                if let strongSelf = self {
                    strongSelf.item = item
                    
                    if let _ = updatedTheme {
                        strongSelf.topStripeNode.backgroundColor = item.theme.list.itemBlocksSeparatorColor
                        strongSelf.bottomStripeNode.backgroundColor = item.theme.list.itemBlocksSeparatorColor
                        strongSelf.backgroundNode.backgroundColor = item.theme.list.itemBlocksBackgroundColor
                        strongSelf.highlightedBackgroundNode.backgroundColor = item.theme.list.itemHighlightedBackgroundColor
                        strongSelf.activityIndicator.type = .custom(item.theme.list.itemAccentColor, 22.0, 1.0, false)
                    }
                    
                    if case .notFound = item.content {
                        strongSelf.notFoundNode.isHidden = false
                    } else {
                        strongSelf.notFoundNode.isHidden = true
                    }
                    
                    if case .searching = item.content {
                        strongSelf.activityIndicator.isHidden = false
                        strongSelf.imageNode.isHidden = true
                    } else {
                        strongSelf.activityIndicator.isHidden = true
                    }
                    
                    if case .found = item.content {
                        strongSelf.removeButtonIcon.isHidden = false
                        strongSelf.removeButton.isHidden = false
                        strongSelf.imageNode.isHidden = false
                    } else {
                        strongSelf.removeButtonIcon.isHidden = true
                        strongSelf.removeButton.isHidden = true
                    }
                    
                    let revealOffset = strongSelf.revealOffset
                    
                    let transition: ContainedViewLayoutTransition = .immediate
                    
                    imageApply?()
                    
                    let _ = titleApply()
                    let _ = statusApply()
                    
                    if strongSelf.backgroundNode.supernode == nil {
                        strongSelf.insertSubnode(strongSelf.backgroundNode, at: 0)
                    }
                    if strongSelf.topStripeNode.supernode == nil {
                        strongSelf.insertSubnode(strongSelf.topStripeNode, at: 1)
                    }
                    if strongSelf.bottomStripeNode.supernode == nil {
                        strongSelf.insertSubnode(strongSelf.bottomStripeNode, at: 2)
                    }
                    if strongSelf.maskNode.supernode == nil {
                        strongSelf.addSubnode(strongSelf.maskNode)
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
                            bottomStripeInset = leftInset + editingOffset
                            bottomStripeOffset = -separatorHeight
                            strongSelf.bottomStripeNode.isHidden = false
                        default:
                            bottomStripeInset = 0.0
                            bottomStripeOffset = 0.0
                            hasBottomCorners = true
                            strongSelf.bottomStripeNode.isHidden = hasCorners
                    }
                    
                    strongSelf.maskNode.image = hasCorners ? PresentationResourcesItemList.cornersImage(item.theme, top: hasTopCorners, bottom: hasBottomCorners) : nil
                    strongSelf.removeButtonIcon.image = PresentationResourcesItemList.itemListRemoveIconImage(item.theme)
                    
                    strongSelf.backgroundNode.frame = CGRect(origin: CGPoint(x: 0.0, y: -min(insets.top, separatorHeight)), size: CGSize(width: params.width, height: contentSize.height + min(insets.top, separatorHeight) + min(insets.bottom, separatorHeight)))
                    strongSelf.maskNode.frame = strongSelf.backgroundNode.frame.insetBy(dx: params.leftInset, dy: 0.0)
                    transition.updateFrame(node: strongSelf.topStripeNode, frame: CGRect(origin: CGPoint(x: 0.0, y: -min(insets.top, separatorHeight)), size: CGSize(width: layoutSize.width, height: separatorHeight)))
                    transition.updateFrame(node: strongSelf.bottomStripeNode, frame: CGRect(origin: CGPoint(x: bottomStripeInset, y: contentSize.height + bottomStripeOffset), size: CGSize(width: layoutSize.width - bottomStripeInset, height: separatorHeight)))
                    
                    let titleVerticalOffset: CGFloat
                    if statusLayout.size.width.isZero {
                        titleVerticalOffset = 19.0
                    } else {
                        titleVerticalOffset = 11.0
                    }
                    transition.updateFrame(node: strongSelf.titleNode, frame: CGRect(origin: CGPoint(x: leftInset, y: titleVerticalOffset), size: titleLayout.size))
                    transition.updateFrame(node: strongSelf.statusNode, frame: CGRect(origin: CGPoint(x: leftInset, y: 32.0), size: statusLayout.size))
                    
                    let boundingSize = CGSize(width: 34.0, height: 34.0)
                    let indicatorSize = CGSize(width: 22.0, height: 22.0)
                    transition.updateFrame(node: strongSelf.activityIndicator, frame: CGRect(origin: CGPoint(x: params.leftInset + 15.0 + floor((boundingSize.width - indicatorSize.width) / 2.0), y: 11.0 + floor((boundingSize.height - indicatorSize.height) / 2.0)), size: indicatorSize))
                    
                    if let image = updatedNotFoundImage {
                        strongSelf.notFoundNode.image = image
                    }
                    if let image = strongSelf.notFoundNode.image {
                        transition.updateFrame(node: strongSelf.notFoundNode, frame: CGRect(origin: CGPoint(x: params.leftInset + 15.0 + floor((boundingSize.width - image.size.width) / 2.0), y: 13.0 + floor((boundingSize.height - image.size.height) / 2.0)), size: image.size))
                    }
                    
                    if let updatedImageSignal = updatedImageSignal {
                        strongSelf.imageNode.setSignal(updatedImageSignal)
                    }
                    let imageFrame = CGRect(origin: CGPoint(x: params.leftInset + revealOffset + editingOffset + 15.0 + floor((boundingSize.width - imageSize.width) / 2.0), y: 11.0 + floor((boundingSize.height - imageSize.height) / 2.0)), size: imageSize)
                    transition.updateFrame(node: strongSelf.imageNode, frame: imageFrame)
                    
                    strongSelf.removeButton.frame = CGRect(origin: CGPoint(x: layoutSize.width - params.rightInset - layoutSize.height, y: 0.0), size: CGSize(width: layoutSize.height, height: layoutSize.height))
                    if let icon = strongSelf.removeButtonIcon.image {
                        strongSelf.removeButtonIcon.frame = CGRect(origin: CGPoint(x: layoutSize.width - params.rightInset - icon.size.width - 18.0, y: floor((layoutSize.height - icon.size.height) / 2.0)), size: icon.size)
                    }
                    
                    strongSelf.highlightedBackgroundNode.frame = CGRect(origin: CGPoint(x: 0.0, y: -UIScreenPixel), size: CGSize(width: params.width, height: contentSize.height + UIScreenPixel + UIScreenPixel))
                    
                    strongSelf.updateLayout(size: layout.contentSize, leftInset: params.leftInset, rightInset: params.rightInset)
                    
                    if let updatedFetchSignal = updatedFetchSignal {
                        strongSelf.fetchDisposable.set(updatedFetchSignal.start())
                    }
                }
            })
        }
    }
    
    override func setHighlighted(_ highlighted: Bool, at point: CGPoint, animated: Bool) {
        super.setHighlighted(highlighted, at: point, animated: animated)
        
        if highlighted {
            self.highlightedBackgroundNode.alpha = 1.0
            if self.highlightedBackgroundNode.supernode == nil {
                var anchorNode: ASDisplayNode?
                if self.bottomStripeNode.supernode != nil {
                    anchorNode = self.bottomStripeNode
                } else if self.topStripeNode.supernode != nil {
                    anchorNode = self.topStripeNode
                } else if self.backgroundNode.supernode != nil {
                    anchorNode = self.backgroundNode
                }
                if let anchorNode = anchorNode {
                    self.insertSubnode(self.highlightedBackgroundNode, aboveSubnode: anchorNode)
                } else {
                    self.addSubnode(self.highlightedBackgroundNode)
                }
            }
        } else {
            if self.highlightedBackgroundNode.supernode != nil {
                if animated {
                    self.highlightedBackgroundNode.layer.animateAlpha(from: self.highlightedBackgroundNode.alpha, to: 0.0, duration: 0.4, completion: { [weak self] completed in
                        if let strongSelf = self {
                            if completed {
                                strongSelf.highlightedBackgroundNode.removeFromSupernode()
                            }
                        }
                    })
                    self.highlightedBackgroundNode.alpha = 0.0
                } else {
                    self.highlightedBackgroundNode.removeFromSupernode()
                }
            }
        }
    }
    
    override func animateInsertion(_ currentTimestamp: Double, duration: Double, options: ListViewItemAnimationOptions) {
        self.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.4)
    }
    
    override func animateRemoved(_ currentTimestamp: Double, duration: Double) {
        self.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.15, removeOnCompletion: false)
    }
}
