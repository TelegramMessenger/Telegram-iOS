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
import StickerResources
import AnimatedStickerNode
import TelegramAnimatedStickerNode
import ShimmerEffect

public struct ItemListStickerPackItemEditing: Equatable {
    public var editable: Bool
    public var editing: Bool
    public var revealed: Bool
    public var reorderable: Bool
    public var selectable: Bool
    
    public init(editable: Bool, editing: Bool, revealed: Bool, reorderable: Bool, selectable: Bool) {
        self.editable = editable
        self.editing = editing
        self.revealed = revealed
        self.reorderable = reorderable
        self.selectable = selectable
    }
}

public enum ItemListStickerPackItemControl: Equatable {
    case none
    case installation(installed: Bool)
    case selection
    case check(checked: Bool)
}

public final class ItemListStickerPackItem: ListViewItem, ItemListItem {
    let presentationData: ItemListPresentationData
    let account: Account
    let packInfo: StickerPackCollectionInfo
    let itemCount: String
    let topItem: StickerPackItem?
    let unread: Bool
    let control: ItemListStickerPackItemControl
    let editing: ItemListStickerPackItemEditing
    let enabled: Bool
    let playAnimatedStickers: Bool
    public let sectionId: ItemListSectionId
    let action: (() -> Void)?
    let setPackIdWithRevealedOptions: (ItemCollectionId?, ItemCollectionId?) -> Void
    let addPack: () -> Void
    let removePack: () -> Void
    let toggleSelected: () -> Void
    
    public init(presentationData: ItemListPresentationData, account: Account, packInfo: StickerPackCollectionInfo, itemCount: String, topItem: StickerPackItem?, unread: Bool, control: ItemListStickerPackItemControl, editing: ItemListStickerPackItemEditing, enabled: Bool, playAnimatedStickers: Bool, sectionId: ItemListSectionId, action: (() -> Void)?, setPackIdWithRevealedOptions: @escaping (ItemCollectionId?, ItemCollectionId?) -> Void, addPack: @escaping () -> Void, removePack: @escaping () -> Void, toggleSelected: @escaping () -> Void) {
        self.presentationData = presentationData
        self.account = account
        self.packInfo = packInfo
        self.itemCount = itemCount
        self.topItem = topItem
        self.unread = unread
        self.control = control
        self.editing = editing
        self.enabled = enabled
        self.playAnimatedStickers = playAnimatedStickers
        self.sectionId = sectionId
        self.action = action
        self.setPackIdWithRevealedOptions = setPackIdWithRevealedOptions
        self.addPack = addPack
        self.removePack = removePack
        self.toggleSelected = toggleSelected
    }
    
    public func nodeConfiguredForParams(async: @escaping (@escaping () -> Void) -> Void, params: ListViewItemLayoutParams, synchronousLoads: Bool, previousItem: ListViewItem?, nextItem: ListViewItem?, completion: @escaping (ListViewItemNode, @escaping () -> (Signal<Void, NoError>?, (ListViewItemApply) -> Void)) -> Void) {
        async {
            let node = ItemListStickerPackItemNode()
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
    
    public func updateNode(async: @escaping (@escaping () -> Void) -> Void, node: @escaping () -> ListViewItemNode, params: ListViewItemLayoutParams, previousItem: ListViewItem?, nextItem: ListViewItem?, animation: ListViewItemUpdateAnimation, completion: @escaping (ListViewItemNodeLayout, @escaping (ListViewItemApply) -> Void) -> Void) {
        Queue.mainQueue().async {
            if let nodeValue = node() as? ItemListStickerPackItemNode {
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
    
    public var selectable: Bool = true
    
    public func selected(listView: ListView){
        listView.clearHighlightAnimated(true)
        self.action?()
    }
}

public enum StickerPackThumbnailItem: Equatable {
    case still(TelegramMediaImageRepresentation)
    case animated(MediaResource, PixelDimensions, Bool)
    
    public static func ==(lhs: StickerPackThumbnailItem, rhs: StickerPackThumbnailItem) -> Bool {
        switch lhs {
        case let .still(representation):
            if case .still(representation) = rhs {
                return true
            } else {
                return false
            }
        case let .animated(lhsResource, lhsDimensions, lhsIsVideo):
            if case let .animated(rhsResource, rhsDimensions, rhsIsVideo) = rhs, lhsResource.isEqual(to: rhsResource), lhsDimensions == rhsDimensions, lhsIsVideo == rhsIsVideo {
                return true
            } else {
                return false
            }
        }
    }
}

class ItemListStickerPackItemNode: ItemListRevealOptionsItemNode {
    private var currentThumbnailItem: StickerPackThumbnailItem?
    
    private let backgroundNode: ASDisplayNode
    private let topStripeNode: ASDisplayNode
    private let bottomStripeNode: ASDisplayNode
    private let highlightedBackgroundNode: ASDisplayNode
    private var disabledOverlayNode: ASDisplayNode?
    private let maskNode: ASImageNode
    
    private let containerNode: ASDisplayNode
    override var controlsContainer: ASDisplayNode {
        return self.containerNode
    }
    
    fileprivate let imageNode: TransformImageNode
    private var animationNode: AnimatedStickerNode?
    private var placeholderNode: StickerShimmerEffectNode?
    private let unreadNode: ASImageNode
    private let titleNode: TextNode
    private let statusNode: TextNode
    private let installTextNode: TextNode
    private let installationActionBackgroundNode: ASImageNode
    private let installationActionNode: HighlightableButtonNode
    private let selectionIconNode: ASImageNode
    
    private var layoutParams: (ItemListStickerPackItem, ListViewItemLayoutParams, ItemListNeighbors)?
    
    private var selectableControlNode: ItemListSelectableControlNode?
    private var editableControlNode: ItemListEditableControlNode?
    private var reorderControlNode: ItemListEditableReorderControlNode?
    
    private let activateArea: AccessibilityAreaNode
    
    private let fetchDisposable = MetaDisposable()
    
    override var canBeSelected: Bool {
        if self.selectableControlNode != nil || self.editableControlNode != nil || self.disabledOverlayNode != nil {
            return false
        }
        if let item = self.layoutParams?.0, item.action != nil {
            return super.canBeSelected
        } else {
            return false
        }
    }
    
    override var visibility: ListViewItemNodeVisibility {
        didSet {
            let wasVisible = oldValue != .none
            let isVisible = self.visibility != .none
            
            if wasVisible != isVisible {
                let visibility = isVisible && (self.layoutParams?.0.playAnimatedStickers ?? true)
                self.animationNode?.visibility = visibility
            }
        }
    }
    
    init() {
        self.backgroundNode = ASDisplayNode()
        self.backgroundNode.isLayerBacked = true
        
        self.topStripeNode = ASDisplayNode()
        self.topStripeNode.isLayerBacked = true
        
        self.bottomStripeNode = ASDisplayNode()
        self.bottomStripeNode.isLayerBacked = true
        
        self.containerNode = ASDisplayNode()
        
        self.maskNode = ASImageNode()
        self.maskNode.isUserInteractionEnabled = false
        
        self.imageNode = TransformImageNode()
        self.imageNode.isLayerBacked = !smartInvertColorsEnabled()
        
        self.placeholderNode = StickerShimmerEffectNode()
        self.placeholderNode?.isUserInteractionEnabled = false
        
        self.titleNode = TextNode()
        self.titleNode.isUserInteractionEnabled = false
        self.titleNode.contentMode = .left
        self.titleNode.contentsScale = UIScreen.main.scale
        
        self.statusNode = TextNode()
        self.statusNode.isUserInteractionEnabled = false
        self.statusNode.contentMode = .left
        self.statusNode.contentsScale = UIScreen.main.scale
        
        self.unreadNode = ASImageNode()
        self.unreadNode.isLayerBacked = true
        self.unreadNode.displaysAsynchronously = false
        self.unreadNode.displayWithoutProcessing = true
        
        self.installationActionBackgroundNode = ASImageNode()
        self.installationActionBackgroundNode.displaysAsynchronously = false
        self.installationActionBackgroundNode.displayWithoutProcessing = true
        self.installationActionBackgroundNode.isLayerBacked = true
        self.installationActionNode = HighlightableButtonNode()
        self.installationActionNode.hitTestSlop = UIEdgeInsets(top: -16.0, left: -16.0, bottom: -16.0, right: -16.0)
        
        self.installTextNode = TextNode()
        self.installTextNode.isUserInteractionEnabled = false
        self.installTextNode.contentMode = .left
        self.installTextNode.contentsScale = UIScreen.main.scale
        
        self.selectionIconNode = ASImageNode()
        self.selectionIconNode.displaysAsynchronously = false
        self.selectionIconNode.displayWithoutProcessing = true
        self.selectionIconNode.isLayerBacked = true
        
        self.highlightedBackgroundNode = ASDisplayNode()
        self.highlightedBackgroundNode.isLayerBacked = true
        
        self.activateArea = AccessibilityAreaNode()
        
        super.init(layerBacked: false, dynamicBounce: false, rotated: false, seeThrough: false)
        
        self.addSubnode(self.containerNode)
        
        if let placeholderNode = self.placeholderNode {
            self.containerNode.addSubnode(placeholderNode)
        }
        
        self.containerNode.addSubnode(self.imageNode)
        self.containerNode.addSubnode(self.titleNode)
        self.containerNode.addSubnode(self.statusNode)
        self.containerNode.addSubnode(self.unreadNode)
        self.containerNode.addSubnode(self.installationActionBackgroundNode)
        self.containerNode.addSubnode(self.installTextNode)
        self.containerNode.addSubnode(self.installationActionNode)
        self.containerNode.addSubnode(self.selectionIconNode)
        self.addSubnode(self.activateArea)
        
        self.installationActionNode.addTarget(self, action: #selector(self.installationActionPressed), forControlEvents: .touchUpInside)
        self.installationActionNode.highligthedChanged = { [weak self] highlighted in
            if let strongSelf = self {
                if highlighted {
                    strongSelf.installationActionBackgroundNode.layer.removeAnimation(forKey: "opacity")
                    strongSelf.installationActionBackgroundNode.alpha = 0.4
                } else {
                    strongSelf.installationActionBackgroundNode.alpha = 1.0
                    strongSelf.installationActionBackgroundNode.layer.animateAlpha(from: 0.4, to: 1.0, duration: 0.2)
                }
            }
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
        self.fetchDisposable.dispose()
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
    
    override func tapped() {
        guard let item = self.layoutParams?.0, item.editing.editing && item.editing.selectable else {
            return
        }
        item.toggleSelected()
    }
    
    func asyncLayout() -> (_ item: ItemListStickerPackItem, _ params: ListViewItemLayoutParams, _ neighbors: ItemListNeighbors) -> (ListViewItemNodeLayout, (Bool) -> Void) {
        let makeImageLayout = self.imageNode.asyncLayout()
        let makeTitleLayout = TextNode.asyncLayout(self.titleNode)
        let makeStatusLayout = TextNode.asyncLayout(self.statusNode)
        let makeInstallLayout = TextNode.asyncLayout(self.installTextNode)
        let editableControlLayout = ItemListEditableControlNode.asyncLayout(self.editableControlNode)
        let reorderControlLayout = ItemListEditableReorderControlNode.asyncLayout(self.reorderControlNode)
        let selectableControlLayout = ItemListSelectableControlNode.asyncLayout(self.selectableControlNode)
        
        let previousThumbnailItem = self.currentThumbnailItem
        var currentDisabledOverlayNode = self.disabledOverlayNode
        
        let currentItem = self.layoutParams?.0
        
        return { item, params, neighbors in
            let titleFont = Font.bold(floor(item.presentationData.fontSize.itemListBaseFontSize * 15.0 / 17.0))
            let statusFont = Font.regular(floor(item.presentationData.fontSize.itemListBaseFontSize * 14.0 / 17.0))
            
            var titleAttributedString: NSAttributedString?
            var statusAttributedString: NSAttributedString?
            
            var updatedTheme: PresentationTheme?
            
            if currentItem?.presentationData.theme !== item.presentationData.theme {
                updatedTheme = item.presentationData.theme
            }
            
            let packRevealOptions: [ItemListRevealOption]
            if item.editing.editable && item.enabled {
                packRevealOptions = [ItemListRevealOption(key: 0, title: item.presentationData.strings.Common_Delete, icon: .none, color: item.presentationData.theme.list.itemDisclosureActions.destructive.fillColor, textColor: item.presentationData.theme.list.itemDisclosureActions.destructive.foregroundColor)]
            } else {
                packRevealOptions = []
            }
            
            var rightInset: CGFloat = params.rightInset
            
            var installationBackgroundImage: UIImage?
            var installationText: String?
            var checkImage: UIImage?
            switch item.control {
                case .none:
                    break
                case let .installation(installed):
                    if installed {
                        installationBackgroundImage = PresentationResourcesChat.chatInputMediaPanelAddedPackButtonImage(item.presentationData.theme)
                        installationText = item.presentationData.strings.Stickers_Installed
                    } else {
                        installationBackgroundImage = PresentationResourcesChat.chatInputMediaPanelAddPackButtonImage(item.presentationData.theme)
                        installationText = item.presentationData.strings.Stickers_Install
                    }
                case .selection:
                    rightInset += 16.0
                    checkImage = PresentationResourcesItemList.checkIconImage(item.presentationData.theme)
                default:
                    break
            }
            
            var unreadImage: UIImage?
            if item.unread {
                unreadImage = PresentationResourcesItemList.stickerUnreadDotImage(item.presentationData.theme)
            }
            
            titleAttributedString = NSAttributedString(string: item.packInfo.title, font: titleFont, textColor: item.presentationData.theme.list.itemPrimaryTextColor)
            statusAttributedString = NSAttributedString(string: item.itemCount, font: statusFont, textColor: item.presentationData.theme.list.itemSecondaryTextColor)
            
            let leftInset: CGFloat = 65.0 + params.leftInset
            
            let verticalInset: CGFloat = 11.0
            let titleSpacing: CGFloat = 2.0
            
            let insets = itemListNeighborsGroupedInsets(neighbors, params)
            let separatorHeight = UIScreenPixel
            
            var editableControlSizeAndApply: (CGFloat, (CGFloat) -> ItemListEditableControlNode)?
            var reorderControlSizeAndApply: (CGFloat, (CGFloat, Bool, ContainedViewLayoutTransition) -> ItemListEditableReorderControlNode)?
            var selectableControlSizeAndApply: (CGFloat, (CGSize, Bool) -> ItemListSelectableControlNode)?
            
            var editingOffset: CGFloat = 0.0
            var reorderInset: CGFloat = 0.0
            
            if item.editing.editing {
                if item.editing.selectable {
                    var selected = false
                    if case let .check(checked) = item.control {
                        selected = checked
                    }
                    let sizeAndApply = selectableControlLayout(item.presentationData.theme.list.itemCheckColors.strokeColor, item.presentationData.theme.list.itemCheckColors.fillColor, item.presentationData.theme.list.itemCheckColors.foregroundColor, selected, true)
                    selectableControlSizeAndApply = sizeAndApply
                    editingOffset = sizeAndApply.0
                } else {
                    let sizeAndApply = editableControlLayout(item.presentationData.theme, false)
                    editableControlSizeAndApply = sizeAndApply
                    editingOffset = sizeAndApply.0
                }
                
                if item.editing.reorderable {
                    let sizeAndApply = reorderControlLayout(item.presentationData.theme)
                    reorderControlSizeAndApply = sizeAndApply
                    reorderInset = sizeAndApply.0
                }
            }
                        
            var installed = false
            if case .installation(true) = item.control {
                installed = true
            }
            
            let (installLayout, installApply) = makeInstallLayout(TextNodeLayoutArguments(attributedString: NSAttributedString(string: installationText ?? "", font: Font.semibold(13.0), textColor: installed ? item.presentationData.theme.list.itemCheckColors.fillColor : item.presentationData.theme.list.itemCheckColors.foregroundColor), backgroundColor: nil, maximumNumberOfLines: 1, truncationType: .end, constrainedSize: CGSize(width: params.width - params.leftInset - params.rightInset - leftInset - rightInset, height: CGFloat.greatestFiniteMagnitude), alignment: .natural, cutout: nil, insets: UIEdgeInsets()))
            let installWidth: CGFloat
            if installLayout.size.width > 0.0 {
                installWidth = installLayout.size.width + 32.0
            } else {
                installWidth = 0.0
            }
            
            let (titleLayout, titleApply) = makeTitleLayout(TextNodeLayoutArguments(attributedString: titleAttributedString, backgroundColor: nil, maximumNumberOfLines: 1, truncationType: .end, constrainedSize: CGSize(width: params.width - leftInset - 8.0 - editingOffset - rightInset - 10.0 - reorderInset - installWidth, height: CGFloat.greatestFiniteMagnitude), alignment: .natural, cutout: nil, insets: UIEdgeInsets()))
            let (statusLayout, statusApply) = makeStatusLayout(TextNodeLayoutArguments(attributedString: statusAttributedString, backgroundColor: nil, maximumNumberOfLines: 1, truncationType: .end, constrainedSize: CGSize(width: params.width - leftInset - 8.0 - editingOffset - rightInset - reorderInset - installWidth, height: CGFloat.greatestFiniteMagnitude), alignment: .natural, cutout: nil, insets: UIEdgeInsets()))
            
            let contentSize = CGSize(width: params.width, height: verticalInset * 2.0 + titleLayout.size.height + titleSpacing + statusLayout.size.height)
            let layout = ListViewItemNodeLayout(contentSize: contentSize, insets: insets)
            let layoutSize = layout.size
            
            if !item.enabled {
                if currentDisabledOverlayNode == nil {
                    currentDisabledOverlayNode = ASDisplayNode()
                    currentDisabledOverlayNode?.backgroundColor = item.presentationData.theme.list.itemBlocksBackgroundColor.withAlphaComponent(0.5)
                }
            } else {
                currentDisabledOverlayNode = nil
            }
            
            var thumbnailItem: StickerPackThumbnailItem?
            var resourceReference: MediaResourceReference?
            if let thumbnail = item.packInfo.thumbnail {
                if item.packInfo.flags.contains(.isAnimated) || item.packInfo.flags.contains(.isVideo)  {
                    thumbnailItem = .animated(thumbnail.resource, thumbnail.dimensions, item.packInfo.flags.contains(.isVideo))
                } else {
                    thumbnailItem = .still(thumbnail)
                }
                resourceReference = MediaResourceReference.stickerPackThumbnail(stickerPack: .id(id: item.packInfo.id.id, accessHash: item.packInfo.accessHash), resource: thumbnail.resource)
            } else if let item = item.topItem {
                if item.file.isAnimatedSticker || item.file.isVideoSticker {
                    thumbnailItem = .animated(item.file.resource, item.file.dimensions ?? PixelDimensions(width: 100, height: 100), item.file.isVideoSticker)
                    resourceReference = MediaResourceReference.media(media: .standalone(media: item.file), resource: item.file.resource)
                } else if let dimensions = item.file.dimensions, let resource = chatMessageStickerResource(file: item.file, small: true) as? TelegramMediaResource {
                    thumbnailItem = .still(TelegramMediaImageRepresentation(dimensions: dimensions, resource: resource, progressiveSizes: [], immediateThumbnailData: nil))
                    resourceReference = MediaResourceReference.media(media: .standalone(media: item.file), resource: resource)
                }
            }
            
            var updatedImageSignal: Signal<(TransformImageArguments) -> DrawingContext?, NoError>?
            var updatedFetchSignal: Signal<FetchResourceSourceType, FetchResourceError>?
            
            let imageBoundingSize = CGSize(width: 34.0, height: 34.0)
            var imageApply: (() -> Void)?
            let fileUpdated = thumbnailItem != previousThumbnailItem
            
            var imageSize: CGSize?
            
            if let thumbnailItem = thumbnailItem {
                switch thumbnailItem {
                    case let .still(representation):
                        let stillImageSize = representation.dimensions.cgSize.aspectFitted(imageBoundingSize)
                        imageSize = stillImageSize
                        
                        if fileUpdated {
                            imageApply = makeImageLayout(TransformImageArguments(corners: ImageCorners(), imageSize: stillImageSize, boundingSize: stillImageSize, intrinsicInsets: UIEdgeInsets()))
                            updatedImageSignal = chatMessageStickerPackThumbnail(postbox: item.account.postbox, resource: representation.resource, nilIfEmpty: true)
                        }
                    case let .animated(resource, dimensions, _):
                        imageSize = dimensions.cgSize.aspectFitted(imageBoundingSize)
                    
                        if fileUpdated {
                            imageApply = makeImageLayout(TransformImageArguments(corners: ImageCorners(), imageSize: imageBoundingSize, boundingSize: imageBoundingSize, intrinsicInsets: UIEdgeInsets()))
                            updatedImageSignal = chatMessageStickerPackThumbnail(postbox: item.account.postbox, resource: resource, animated: true, nilIfEmpty: true)
                        }
                }
                if fileUpdated, let resourceReference = resourceReference {
                    updatedFetchSignal = fetchedMediaResource(mediaBox: item.account.postbox.mediaBox, reference: resourceReference)
                }
            } else {
                updatedImageSignal = .single({ _ in return nil })
                updatedFetchSignal = .complete()
            }
            
            return (layout, { [weak self] animated in
                if let strongSelf = self {
                    strongSelf.layoutParams = (item, params, neighbors)
                    
                    strongSelf.activateArea.frame = CGRect(origin: CGPoint(x: params.leftInset, y: 0.0), size: CGSize(width: params.width - params.leftInset - params.rightInset, height: layout.contentSize.height))
                    strongSelf.activateArea.accessibilityLabel = titleAttributedString?.string ?? ""
                    strongSelf.activateArea.accessibilityValue = statusAttributedString?.string ?? ""
                    if item.enabled {
                        strongSelf.activateArea.accessibilityTraits = []
                    } else {
                        strongSelf.activateArea.accessibilityTraits = .notEnabled
                    }
                    
                    if fileUpdated {
                        strongSelf.currentThumbnailItem = thumbnailItem
                    }
                    
                    if let _ = updatedTheme {
                        strongSelf.topStripeNode.backgroundColor = item.presentationData.theme.list.itemBlocksSeparatorColor
                        strongSelf.bottomStripeNode.backgroundColor = item.presentationData.theme.list.itemBlocksSeparatorColor
                        strongSelf.backgroundNode.backgroundColor = item.presentationData.theme.list.itemBlocksBackgroundColor
                        strongSelf.highlightedBackgroundNode.backgroundColor = item.presentationData.theme.list.itemHighlightedBackgroundColor
                    }
                    
                    let revealOffset = strongSelf.revealOffset
                    
                    let transition: ContainedViewLayoutTransition
                    if animated {
                        transition = ContainedViewLayoutTransition.animated(duration: 0.4, curve: .spring)
                    } else {
                        transition = .immediate
                    }
                    
                    if let currentDisabledOverlayNode = currentDisabledOverlayNode {
                        if currentDisabledOverlayNode != strongSelf.disabledOverlayNode {
                            strongSelf.disabledOverlayNode = currentDisabledOverlayNode
                            strongSelf.addSubnode(currentDisabledOverlayNode)
                            currentDisabledOverlayNode.alpha = 0.0
                            transition.updateAlpha(node: currentDisabledOverlayNode, alpha: 1.0)
                            currentDisabledOverlayNode.frame = CGRect(origin: CGPoint(), size: CGSize(width: layout.contentSize.width, height: layout.contentSize.height - separatorHeight))
                        } else {
                            transition.updateFrame(node: currentDisabledOverlayNode, frame: CGRect(origin: CGPoint(), size: CGSize(width: layout.contentSize.width, height: layout.contentSize.height - separatorHeight)))
                        }
                    } else if let disabledOverlayNode = strongSelf.disabledOverlayNode {
                        transition.updateAlpha(node: disabledOverlayNode, alpha: 0.0, completion: { [weak disabledOverlayNode] _ in
                            disabledOverlayNode?.removeFromSupernode()
                        })
                        strongSelf.disabledOverlayNode = nil
                    }
                    
                    if let editableControlSizeAndApply = editableControlSizeAndApply {
                        let editableControlFrame = CGRect(origin: CGPoint(x: params.leftInset + revealOffset, y: 0.0), size: CGSize(width: editableControlSizeAndApply.0, height: layout.contentSize.height))
                        if strongSelf.editableControlNode == nil {
                            let editableControlNode = editableControlSizeAndApply.1(layout.contentSize.height)
                            editableControlNode.tapped = {
                                if let strongSelf = self {
                                    strongSelf.setRevealOptionsOpened(true, animated: true)
                                    strongSelf.revealOptionsInteractivelyOpened()
                                }
                            }
                            strongSelf.editableControlNode = editableControlNode
                            strongSelf.insertSubnode(editableControlNode, aboveSubnode: strongSelf.imageNode)
                            editableControlNode.frame = editableControlFrame
                            transition.animatePosition(node: editableControlNode, from: CGPoint(x: -editableControlFrame.size.width / 2.0, y: editableControlFrame.midY))
                            editableControlNode.alpha = 0.0
                            transition.updateAlpha(node: editableControlNode, alpha: 1.0)
                        } else {
                            strongSelf.editableControlNode?.frame = editableControlFrame
                        }
                        strongSelf.editableControlNode?.isHidden = !item.editing.editable
                    } else if let editableControlNode = strongSelf.editableControlNode {
                        var editableControlFrame = editableControlNode.frame
                        editableControlFrame.origin.x = -editableControlFrame.size.width
                        strongSelf.editableControlNode = nil
                        transition.updateAlpha(node: editableControlNode, alpha: 0.0)
                        transition.updateFrame(node: editableControlNode, frame: editableControlFrame, completion: { [weak editableControlNode] _ in
                            editableControlNode?.removeFromSupernode()
                        })
                    }
                    
                    if let selectableControlSizeAndApply = selectableControlSizeAndApply {
                        let selectableControlSize = CGSize(width: selectableControlSizeAndApply.0, height: layout.contentSize.height)
                        let selectableControlFrame = CGRect(origin: CGPoint(x: params.leftInset + revealOffset, y: 0.0), size: selectableControlSize)
                        if strongSelf.selectableControlNode == nil {
                            let selectableControlNode = selectableControlSizeAndApply.1(selectableControlSize, false)
                            strongSelf.selectableControlNode = selectableControlNode
                            strongSelf.addSubnode(selectableControlNode)
                            selectableControlNode.frame = selectableControlFrame
                            transition.animatePosition(node: selectableControlNode, from: CGPoint(x: -selectableControlFrame.size.width / 2.0, y: selectableControlFrame.midY))
                            selectableControlNode.alpha = 0.0
                            transition.updateAlpha(node: selectableControlNode, alpha: 1.0)
                        } else if let selectableControlNode = strongSelf.selectableControlNode {
                            transition.updateFrame(node: selectableControlNode, frame: selectableControlFrame)
                            let _ = selectableControlSizeAndApply.1(selectableControlSize, transition.isAnimated)
                        }
                    } else if let selectableControlNode = strongSelf.selectableControlNode {
                        var selectableControlFrame = selectableControlNode.frame
                        selectableControlFrame.origin.x = -selectableControlFrame.size.width
                        strongSelf.selectableControlNode = nil
                        transition.updateAlpha(node: selectableControlNode, alpha: 0.0)
                        transition.updateFrame(node: selectableControlNode, frame: selectableControlFrame, completion: { [weak selectableControlNode] _ in
                            selectableControlNode?.removeFromSupernode()
                        })
                    }
                    
                    if let reorderControlSizeAndApply = reorderControlSizeAndApply {
                        if strongSelf.reorderControlNode == nil {
                            let reorderControlNode = reorderControlSizeAndApply.1(layout.contentSize.height, false, .immediate)
                            strongSelf.reorderControlNode = reorderControlNode
                            strongSelf.addSubnode(reorderControlNode)
                            reorderControlNode.alpha = 0.0
                            transition.updateAlpha(node: reorderControlNode, alpha: 1.0)
                        }
                        let reorderControlFrame = CGRect(origin: CGPoint(x: params.width + revealOffset - params.rightInset - reorderControlSizeAndApply.0, y: 0.0), size: CGSize(width: reorderControlSizeAndApply.0, height: layout.contentSize.height))
                        strongSelf.reorderControlNode?.frame = reorderControlFrame
                    } else if let reorderControlNode = strongSelf.reorderControlNode {
                        strongSelf.reorderControlNode = nil
                        transition.updateAlpha(node: reorderControlNode, alpha: 0.0, completion: { [weak reorderControlNode] _ in
                            reorderControlNode?.removeFromSupernode()
                        })
                    }
                    
                    imageApply?()
                    
                    let _ = titleApply()
                    let _ = statusApply()
                    let _ = installApply()
                                        
                    switch item.control {
                        case .none:
                            strongSelf.installationActionNode.isHidden = true
                            strongSelf.installationActionBackgroundNode.isHidden = true
                            strongSelf.selectionIconNode.isHidden = true
                        case let .installation(installed):
                            strongSelf.installationActionBackgroundNode.isHidden = false
                            strongSelf.installationActionNode.isHidden = false
                            strongSelf.selectionIconNode.isHidden = true
                            strongSelf.installationActionNode.isUserInteractionEnabled = !installed
                        
                            if let backgroundImage = installationBackgroundImage {
                                strongSelf.installationActionBackgroundNode.image = backgroundImage
                            }
                        
                            let installationActionFrame = CGRect(origin: CGPoint(x: params.width - rightInset - installWidth - 16.0, y: 0.0), size: CGSize(width: installWidth, height: layout.contentSize.height))
                            strongSelf.installationActionNode.frame = installationActionFrame
                        
                            let buttonFrame = CGRect(origin: CGPoint(x: params.width - rightInset - installWidth - 16.0, y: installationActionFrame.minY + floor((installationActionFrame.size.height - 28.0) / 2.0)), size: CGSize(width: installWidth, height: 28.0))
                            strongSelf.installationActionBackgroundNode.frame = buttonFrame
                            strongSelf.installTextNode.frame = CGRect(origin: CGPoint(x: buttonFrame.minX + floorToScreenPixels((buttonFrame.width - installLayout.size.width) / 2.0), y: buttonFrame.minY + floorToScreenPixels((buttonFrame.height - installLayout.size.height) / 2.0) + 1.0), size: installLayout.size)
                        case .selection:
                            strongSelf.installationActionNode.isHidden = true
                            strongSelf.installationActionBackgroundNode.isHidden = true
                            strongSelf.selectionIconNode.isHidden = false
                            if let image = checkImage {
                                strongSelf.selectionIconNode.image = image
                                strongSelf.selectionIconNode.frame = CGRect(origin: CGPoint(x: params.width - params.rightInset - image.size.width - floor((44.0 - image.size.width) / 2.0), y: floor((contentSize.height - image.size.height) / 2.0)), size: image.size)
                            }
                        case .check:
                            strongSelf.installationActionNode.isHidden = true
                            strongSelf.installationActionBackgroundNode.isHidden = true
                            strongSelf.selectionIconNode.isHidden = true
                    }
                    
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
                    
                    strongSelf.maskNode.image = hasCorners ? PresentationResourcesItemList.cornersImage(item.presentationData.theme, top: hasTopCorners, bottom: hasBottomCorners) : nil
                    
                    strongSelf.backgroundNode.frame = CGRect(origin: CGPoint(x: 0.0, y: -min(insets.top, separatorHeight)), size: CGSize(width: params.width, height: contentSize.height + min(insets.top, separatorHeight) + min(insets.bottom, separatorHeight)))
                    strongSelf.containerNode.frame = CGRect(origin: CGPoint(), size: strongSelf.backgroundNode.frame.size)
                    strongSelf.maskNode.frame = strongSelf.backgroundNode.frame.insetBy(dx: params.leftInset, dy: 0.0)
                    transition.updateFrame(node: strongSelf.topStripeNode, frame: CGRect(origin: CGPoint(x: 0.0, y: -min(insets.top, separatorHeight)), size: CGSize(width: layoutSize.width, height: separatorHeight)))
                    transition.updateFrame(node: strongSelf.bottomStripeNode, frame: CGRect(origin: CGPoint(x: bottomStripeInset, y: contentSize.height + bottomStripeOffset), size: CGSize(width: layoutSize.width - bottomStripeInset, height: separatorHeight)))
                    
                    if let unreadImage = unreadImage {
                        strongSelf.unreadNode.image = unreadImage
                        strongSelf.unreadNode.isHidden = false
                        strongSelf.unreadNode.frame = CGRect(origin: CGPoint(x: leftInset, y: 16.0), size: unreadImage.size)
                    } else {
                        strongSelf.unreadNode.isHidden = true
                    }
                    
                    transition.updateFrame(node: strongSelf.titleNode, frame: CGRect(origin: CGPoint(x: (strongSelf.unreadNode.isHidden ? 0.0 : 10.0) + leftInset + revealOffset + editingOffset, y: verticalInset), size: titleLayout.size))
                    transition.updateFrame(node: strongSelf.statusNode, frame: CGRect(origin: CGPoint(x: leftInset + revealOffset + editingOffset, y: strongSelf.titleNode.frame.maxY + titleSpacing), size: statusLayout.size))
                    
                    let boundingSize = CGSize(width: 34.0, height: 34.0)
                    let imageFrame: CGRect
                    if let imageSize = imageSize {
                        imageFrame = CGRect(origin: CGPoint(x: params.leftInset + revealOffset + editingOffset + 15.0 + floor((boundingSize.width - imageSize.width) / 2.0), y: floor((layout.contentSize.height - imageSize.height) / 2.0)), size: imageSize)
                    } else {
                        imageFrame = CGRect()
                    }
                    if let thumbnailItem = thumbnailItem {
                        transition.updateFrame(node: strongSelf.imageNode, frame: imageFrame)
                        
                        switch thumbnailItem {
                            case .still:
                                break
                            case let .animated(resource, _, isVideo):
                                let animationNode: AnimatedStickerNode
                                if let current = strongSelf.animationNode {
                                    animationNode = current
                                } else {
                                    animationNode = DefaultAnimatedStickerNodeImpl()
                                    animationNode.started = { [weak self] in
                                        self?.removePlaceholder(animated: false)
                                    }
                                    strongSelf.animationNode = animationNode
                                    strongSelf.addSubnode(animationNode)
                                    
                                    animationNode.setup(source: AnimatedStickerResourceSource(account: item.account, resource: resource, isVideo: isVideo), width: 80, height: 80, playbackMode: .loop, mode: .cached)
                                }
                                animationNode.visibility = strongSelf.visibility != .none && item.playAnimatedStickers
                                animationNode.isHidden = !item.playAnimatedStickers
                                strongSelf.imageNode.isHidden = item.playAnimatedStickers
                                if let animationNode = strongSelf.animationNode {
                                    transition.updateFrame(node: animationNode, frame: imageFrame)
                                }
                        }
                    }
                    
                    if let placeholderNode = strongSelf.placeholderNode {
                        var imageSize = PixelDimensions(width: 512, height: 512)
                        var immediateThumbnailData: Data?
                        if let data = item.packInfo.immediateThumbnailData {
                            if item.packInfo.flags.contains(.isVideo) {
                                imageSize = PixelDimensions(width: 100, height: 100)
                            }
                            immediateThumbnailData = data
                        } else if let data = item.topItem?.file.immediateThumbnailData {
                            immediateThumbnailData = data
                        }
                        
                        placeholderNode.frame = imageFrame
                        
                        placeholderNode.update(backgroundColor: nil, foregroundColor: item.presentationData.theme.list.disclosureArrowColor.blitOver(item.presentationData.theme.list.itemBlocksBackgroundColor, alpha: 0.55), shimmeringColor: item.presentationData.theme.list.itemBlocksBackgroundColor.withAlphaComponent(0.4), data: immediateThumbnailData, size: imageFrame.size, imageSize: imageSize.cgSize)
                    }
                    
                    if let updatedImageSignal = updatedImageSignal {
                        strongSelf.imageNode.setSignal(updatedImageSignal)
                    }
                    
                    strongSelf.highlightedBackgroundNode.frame = CGRect(origin: CGPoint(x: 0.0, y: -UIScreenPixel), size: CGSize(width: params.width, height: strongSelf.backgroundNode.frame.height + UIScreenPixel + UIScreenPixel))
                    
                    strongSelf.updateLayout(size: layout.contentSize, leftInset: params.leftInset, rightInset: params.rightInset)
                    
                    strongSelf.setRevealOptions((left: [], right: packRevealOptions))
                    strongSelf.setRevealOptionsOpened(item.editing.revealed, animated: animated)
                    
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
    
    override func updateRevealOffset(offset: CGFloat, transition: ContainedViewLayoutTransition) {
        super.updateRevealOffset(offset: offset, transition: transition)
        
        guard let params = self.layoutParams?.1 else {
            return
        }
        
        let leftInset: CGFloat = 65.0 + params.leftInset
        
        let editingOffset: CGFloat
        if let editableControlNode = self.editableControlNode {
            editingOffset = editableControlNode.bounds.size.width
            var editableControlFrame = editableControlNode.frame
            editableControlFrame.origin.x = params.leftInset + offset
            transition.updateFrame(node: editableControlNode, frame: editableControlFrame)
        } else {
            editingOffset = 0.0
        }
        
        transition.updateFrame(node: self.titleNode, frame: CGRect(origin: CGPoint(x: leftInset + self.revealOffset + editingOffset, y: self.titleNode.frame.minY), size: self.titleNode.bounds.size))
        transition.updateFrame(node: self.statusNode, frame: CGRect(origin: CGPoint(x: leftInset + self.revealOffset + editingOffset, y: self.statusNode.frame.minY), size: self.statusNode.bounds.size))
        
        let boundingSize = CGSize(width: 34.0, height: 34.0)
        
        transition.updateFrame(node: self.imageNode, frame: CGRect(origin: CGPoint(x: params.leftInset + self.revealOffset + editingOffset + 15.0 + floor((boundingSize.width - self.imageNode.frame.size.width) / 2.0), y: self.imageNode.frame.minY), size: self.imageNode.frame.size))
        if let animationNode = self.animationNode {
            transition.updateFrame(node: animationNode, frame: CGRect(origin: CGPoint(x: params.leftInset + self.revealOffset + editingOffset + 15.0 + floor((boundingSize.width - animationNode.frame.size.width) / 2.0), y: animationNode.frame.minY), size: animationNode.frame.size))
        }
    }
    
    override func revealOptionsInteractivelyOpened() {
        if let (item, _, _) = self.layoutParams {
            item.setPackIdWithRevealedOptions(item.packInfo.id, nil)
        }
    }
    
    override func revealOptionsInteractivelyClosed() {
        if let (item, _, _) = self.layoutParams {
            item.setPackIdWithRevealedOptions(nil, item.packInfo.id)
        }
    }
    
    override func revealOptionSelected(_ option: ItemListRevealOption, animated: Bool) {
        self.setRevealOptionsOpened(false, animated: true)
        self.revealOptionsInteractivelyClosed()
        
        if let (item, _, _) = self.layoutParams {
            item.removePack()
        }
    }
    
    @objc func installationActionPressed() {
        if let (item, _, _) = self.layoutParams {
            item.addPack()
        }
    }
    
    override func isReorderable(at point: CGPoint) -> Bool {
        if let reorderControlNode = self.reorderControlNode, reorderControlNode.frame.contains(point), !self.isDisplayingRevealedOptions {
            return true
        }
        return false
    }
    
    override func snapshotForReordering() -> UIView? {
        self.backgroundNode.alpha = 0.9
        let result = self.view.snapshotContentTree()
        self.backgroundNode.alpha = 1.0
        return result
    }
}
