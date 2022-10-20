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
import AppBundle

enum GroupStickerPackCurrentItemContent: Equatable {
    case notFound
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
    
    init(theme: PresentationTheme, strings: PresentationStrings, account: Account, content: GroupStickerPackCurrentItemContent, sectionId: ItemListSectionId, action: (() -> Void)?) {
        self.theme = theme
        self.strings = strings
        self.account = account
        self.content = content
        self.sectionId = sectionId
        self.action = action
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
    
    fileprivate let imageNode: TransformImageNode
    private let notFoundNode: ASImageNode
    private let titleNode: TextNode
    private let statusNode: TextNode
    private let activityIndicator: ActivityIndicator
    
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
        
        self.imageNode = TransformImageNode()
        self.imageNode.isLayerBacked = !smartInvertColorsEnabled()
        
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
        
        super.init(layerBacked: false, dynamicBounce: false, rotated: false, seeThrough: false)
        
        self.addSubnode(self.imageNode)
        self.addSubnode(self.titleNode)
        self.addSubnode(self.statusNode)
        self.addSubnode(self.notFoundNode)
        self.addSubnode(self.activityIndicator)
    }
    
    deinit {
        self.fetchDisposable.dispose()
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
                previousFile = topItem?.file
            }
            
            switch item.content {
                case .notFound:
                    titleAttributedString = NSAttributedString(string: item.strings.Channel_Stickers_NotFound, font: titleFont, textColor: item.theme.list.itemDestructiveColor)
                    statusAttributedString = NSAttributedString(string: item.strings.Channel_Stickers_NotFoundHelp, font: statusFont, textColor: item.theme.list.itemSecondaryTextColor)
                case .searching:
                    titleAttributedString = NSAttributedString(string: item.strings.Channel_Stickers_Searching, font: titleFont, textColor: item.theme.list.itemPrimaryTextColor)
                    statusAttributedString = NSAttributedString(string: "", font: statusFont, textColor: item.theme.list.itemSecondaryTextColor)
                case let .found(packInfo, topItem, subtitle):
                    file = topItem?.file
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
                    updatedImageSignal = chatMessageSticker(account: item.account, file: file, small: false)
                    updatedFetchSignal = fetchedMediaResource(mediaBox: item.account.postbox.mediaBox, reference: stickerPackFileReference(file).resourceReference(file.resource))
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
                    } else {
                        strongSelf.activityIndicator.isHidden = true
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
                    switch neighbors.top {
                        case .sameSection(false):
                            strongSelf.topStripeNode.isHidden = true
                        default:
                            strongSelf.topStripeNode.isHidden = false
                    }
                    let bottomStripeInset: CGFloat
                    let bottomStripeOffset: CGFloat
                    switch neighbors.bottom {
                        case .sameSection(false):
                            bottomStripeInset = leftInset + editingOffset
                            bottomStripeOffset = -separatorHeight
                        default:
                            bottomStripeInset = 0.0
                            bottomStripeOffset = 0.0
                    }
                    strongSelf.backgroundNode.frame = CGRect(origin: CGPoint(x: 0.0, y: -min(insets.top, separatorHeight)), size: CGSize(width: params.width, height: contentSize.height + min(insets.top, separatorHeight) + min(insets.bottom, separatorHeight)))
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
                    transition.updateFrame(node: strongSelf.imageNode, frame: CGRect(origin: CGPoint(x: params.leftInset + revealOffset + editingOffset + 15.0 + floor((boundingSize.width - imageSize.width) / 2.0), y: 11.0 + floor((boundingSize.height - imageSize.height) / 2.0)), size: imageSize))
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
    
    override func animateInsertion(_ currentTimestamp: Double, duration: Double, short: Bool) {
        self.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.4)
    }
    
    override func animateRemoved(_ currentTimestamp: Double, duration: Double) {
        self.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.15, removeOnCompletion: false)
    }
}
