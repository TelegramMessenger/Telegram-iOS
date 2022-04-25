import Foundation
import UIKit
import Display
import AsyncDisplayKit
import SwiftSignalKit
import TelegramPresentationData
import ItemListUI
import PresentationDataUtils
import ActivityIndicator
import ChatListSearchItemNode
import ShimmerEffect

public struct LocalizationListItemEditing: Equatable {
    let editable: Bool
    let editing: Bool
    let revealed: Bool
    let reorderable: Bool
    
    public init(editable: Bool, editing: Bool, revealed: Bool, reorderable: Bool) {
        self.editable = editable
        self.editing = editing
        self.revealed = revealed
        self.reorderable = reorderable
    }
}

public class LocalizationListItem: ListViewItem, ItemListItem {
    let presentationData: ItemListPresentationData
    let id: String
    let title: String
    let subtitle: String
    let checked: Bool
    let activity: Bool
    let loading: Bool
    let editing: LocalizationListItemEditing
    let enabled: Bool
    public let sectionId: ItemListSectionId
    let alwaysPlain: Bool
    let action: () -> Void
    let setItemWithRevealedOptions: (String?, String?) -> Void
    let removeItem: (String) -> Void
    
    public init(presentationData: ItemListPresentationData, id: String, title: String, subtitle: String, checked: Bool, activity: Bool, loading: Bool, editing: LocalizationListItemEditing, enabled: Bool = true, sectionId: ItemListSectionId, alwaysPlain: Bool, action: @escaping () -> Void, setItemWithRevealedOptions: @escaping (String?, String?) -> Void, removeItem: @escaping (String) -> Void) {
        self.presentationData = presentationData
        self.id = id
        self.title = title
        self.subtitle = subtitle
        self.checked = checked
        self.activity = activity
        self.loading = loading
        self.editing = editing
        self.enabled = enabled
        self.sectionId = sectionId
        self.alwaysPlain = alwaysPlain
        self.action = action
        self.setItemWithRevealedOptions = setItemWithRevealedOptions
        self.removeItem = removeItem
    }
    
    public func nodeConfiguredForParams(async: @escaping (@escaping () -> Void) -> Void, params: ListViewItemLayoutParams, synchronousLoads: Bool, previousItem: ListViewItem?, nextItem: ListViewItem?, completion: @escaping (ListViewItemNode, @escaping () -> (Signal<Void, NoError>?, (ListViewItemApply) -> Void)) -> Void) {
        async {
            let node = LocalizationListItemNode()
            var neighbors = itemListNeighbors(item: self, topItem: previousItem as? ItemListItem, bottomItem: nextItem as? ItemListItem)
            if previousItem == nil && self.alwaysPlain {
                neighbors.top = .sameSection(alwaysPlain: false)
            }
            let (layout, apply) = node.asyncLayout()(self, params, neighbors)
            
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
            if let nodeValue = node() as? LocalizationListItemNode {
                let makeLayout = nodeValue.asyncLayout()
                
                async {
                    var neighbors = itemListNeighbors(item: self, topItem: previousItem as? ItemListItem, bottomItem: nextItem as? ItemListItem)
                    if previousItem == nil && self.alwaysPlain {
                        neighbors.top = .sameSection(alwaysPlain: false)
                    }
                    let (layout, apply) = makeLayout(self, params, neighbors)
                    Queue.mainQueue().async {
                        completion(layout, { _ in
                            apply(animation.isAnimated)
                        })
                    }
                }
            }
        }
    }
    
    public var selectable: Bool = true
    
    public func selected(listView: ListView){
        listView.clearHighlightAnimated(true)
        self.action()
    }
}

class LocalizationListItemNode: ItemListRevealOptionsItemNode {
    private let backgroundNode: ASDisplayNode
    private let topStripeNode: ASDisplayNode
    private let bottomStripeNode: ASDisplayNode
    private let highlightedBackgroundNode: ASDisplayNode
    private let maskNode: ASImageNode
    
    private let iconNode: ASImageNode
    private let activityNode: ActivityIndicator
    private let titleNode: TextNode
    private let subtitleNode: TextNode
    
    private var item: LocalizationListItem?
    private var layoutParams: (ListViewItemLayoutParams, ItemListNeighbors)?
    
    private var placeholderNode: ShimmerEffectNode?
    private var absoluteLocation: (CGRect, CGSize)?
    
    private var editableControlNode: ItemListEditableControlNode?
    private var reorderControlNode: ItemListEditableReorderControlNode?
    
    private let activateArea: AccessibilityAreaNode
    
    private let containerNode: ASDisplayNode
    override var controlsContainer: ASDisplayNode {
        return self.containerNode
    }
    
    override var canBeSelected: Bool {
        if self.editableControlNode != nil {
            return false
        }
        if let _ = self.layoutParams?.0, let item = self.item, !item.loading {
            return super.canBeSelected
        } else {
            return false
        }
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
        
        self.containerNode = ASDisplayNode()
        
        self.iconNode = ASImageNode()
        self.iconNode.isLayerBacked = true
        self.iconNode.displayWithoutProcessing = true
        self.iconNode.displaysAsynchronously = false
        
        self.activityNode = ActivityIndicator(type: ActivityIndicatorType.custom(.black, 22.0, 0.0, false))
        self.activityNode.isHidden = true
        
        self.titleNode = TextNode()
        self.titleNode.isUserInteractionEnabled = false
        self.titleNode.contentMode = .left
        self.titleNode.contentsScale = UIScreenScale
        
        self.subtitleNode = TextNode()
        self.subtitleNode.isUserInteractionEnabled = false
        self.subtitleNode.contentMode = .left
        self.subtitleNode.contentsScale = UIScreenScale
        
        self.highlightedBackgroundNode = ASDisplayNode()
        self.highlightedBackgroundNode.isLayerBacked = true
        
        self.activateArea = AccessibilityAreaNode()
        
        super.init(layerBacked: false, dynamicBounce: false, rotated: false, seeThrough: false)
        
        self.addSubnode(self.containerNode)
        
        self.containerNode.addSubnode(self.iconNode)
        self.containerNode.addSubnode(self.activityNode)
        self.containerNode.addSubnode(self.titleNode)
        self.containerNode.addSubnode(self.subtitleNode)
        
        self.addSubnode(self.activateArea)
    }
    
    override public func updateAbsoluteRect(_ rect: CGRect, within containerSize: CGSize) {
        var rect = rect
        rect.origin.y += self.insets.top
        self.absoluteLocation = (rect, containerSize)
        if let shimmerNode = self.placeholderNode {
            shimmerNode.updateAbsoluteRect(rect, within: containerSize)
        }
    }
    
    func asyncLayout() -> (_ item: LocalizationListItem, _ params: ListViewItemLayoutParams, _ neighbors: ItemListNeighbors) -> (ListViewItemNodeLayout, (Bool) -> Void) {
        let makeTitleLayout = TextNode.asyncLayout(self.titleNode)
        let makeSubtitleLayout = TextNode.asyncLayout(self.subtitleNode)
        let editableControlLayout = ItemListEditableControlNode.asyncLayout(self.editableControlNode)
        
        let currentItem = self.item
        
        return { item, params, neighbors in
            var leftInset: CGFloat = params.leftInset
            
            let titleFont = Font.regular(item.presentationData.fontSize.itemListBaseFontSize)
            let subtitleFont = Font.regular(floor(item.presentationData.fontSize.itemListBaseFontSize * 13.0 / 17.0))
            
            let (titleLayout, titleApply) = makeTitleLayout(TextNodeLayoutArguments(attributedString: NSAttributedString(string: item.title, font: titleFont, textColor: item.presentationData.theme.list.itemPrimaryTextColor), backgroundColor: nil, maximumNumberOfLines: 1, truncationType: .end, constrainedSize: CGSize(width: params.width - leftInset - 50.0, height: CGFloat.greatestFiniteMagnitude), alignment: .natural, cutout: nil, insets: UIEdgeInsets()))
            
            let (subtitleLayout, subtitleApply) = makeSubtitleLayout(TextNodeLayoutArguments(attributedString: NSAttributedString(string: item.subtitle, font: subtitleFont, textColor: item.presentationData.theme.list.itemPrimaryTextColor), backgroundColor: nil, maximumNumberOfLines: 1, truncationType: .end, constrainedSize: CGSize(width: params.width - leftInset - 50.0, height: CGFloat.greatestFiniteMagnitude), alignment: .natural, cutout: nil, insets: UIEdgeInsets()))
            
            let insets = itemListNeighborsGroupedInsets(neighbors, params)
            let contentSize = CGSize(width: params.width, height: titleLayout.size.height + 1.0 + subtitleLayout.size.height + 8.0 * 2.0)
            
            let layout = ListViewItemNodeLayout(contentSize: contentSize, insets: insets)
            
            var editableControlSizeAndApply: (CGFloat, (CGFloat) -> ItemListEditableControlNode)?
            
            var editingOffset: CGFloat = 0.0
            
            if item.editing.editing {
                let sizeAndApply = editableControlLayout(item.presentationData.theme, false)
                editableControlSizeAndApply = sizeAndApply
                editingOffset = sizeAndApply.0
            }
            
            leftInset += 16.0
            
            let separatorHeight = UIScreenPixel
            
            var updateCheckImage: UIImage?
            var updatedTheme: PresentationTheme?
            
            if currentItem?.presentationData.theme !== item.presentationData.theme {
                updatedTheme = item.presentationData.theme
                updateCheckImage = PresentationResourcesItemList.checkIconImage(item.presentationData.theme)
            }
            
            return (layout, { [weak self] animated in
                if let strongSelf = self {
                    strongSelf.item = item
                    strongSelf.layoutParams = (params, neighbors)
                    
                    strongSelf.activateArea.frame = CGRect(origin: CGPoint(x: params.leftInset, y: 0.0), size: CGSize(width: params.width - params.leftInset - params.rightInset, height: layout.contentSize.height))
                    strongSelf.activateArea.accessibilityLabel = item.title
                    strongSelf.activateArea.accessibilityValue = item.subtitle
                    
                    let revealOffset = strongSelf.revealOffset
                    
                    let transition: ContainedViewLayoutTransition
                    if animated {
                        transition = ContainedViewLayoutTransition.animated(duration: 0.4, curve: .spring)
                    } else {
                        transition = .immediate
                    }
                    
                    if let updateCheckImage = updateCheckImage {
                        strongSelf.iconNode.image = updateCheckImage
                        strongSelf.activityNode.type = ActivityIndicatorType.custom(item.presentationData.theme.list.itemAccentColor, 22.0, 0.0, false)
                    }
                    
                    strongSelf.activityNode.isHidden = !item.activity
                    
                    if let _ = updatedTheme {
                        strongSelf.topStripeNode.backgroundColor = item.presentationData.theme.list.itemBlocksSeparatorColor
                        strongSelf.bottomStripeNode.backgroundColor = item.presentationData.theme.list.itemBlocksSeparatorColor
                        strongSelf.backgroundNode.backgroundColor = item.presentationData.theme.list.itemBlocksBackgroundColor
                        strongSelf.highlightedBackgroundNode.backgroundColor = item.presentationData.theme.list.itemHighlightedBackgroundColor
                    }
                    
                    let _ = titleApply()
                    let _ = subtitleApply()
                    
                    if let image = strongSelf.iconNode.image {
                        transition.updateFrame(node: strongSelf.iconNode, frame: CGRect(origin: CGPoint(x: editingOffset + revealOffset + params.width - params.rightInset - image.size.width - floor((44.0 - image.size.width) / 2.0), y: floor((contentSize.height - image.size.height) / 2.0)), size: image.size))
                    }
                    let activitySize = CGSize(width: 22.0, height: 22.0)
                    transition.updateFrame(node: strongSelf.activityNode, frame: CGRect(origin: CGPoint(x: editingOffset + revealOffset + params.width - params.rightInset - activitySize.width - floor((44.0 - activitySize.width) / 2.0), y: floor((contentSize.height - activitySize.height) / 2.0)), size: activitySize))
                    strongSelf.iconNode.isHidden = !item.checked || item.activity
                    
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
                    switch neighbors.bottom {
                        case .sameSection(false):
                            bottomStripeInset = leftInset
                            strongSelf.bottomStripeNode.isHidden = false
                        default:
                            bottomStripeInset = 0.0
                            hasBottomCorners = true
                            strongSelf.bottomStripeNode.isHidden = hasCorners
                    }
                    
                    strongSelf.maskNode.image = hasCorners ? PresentationResourcesItemList.cornersImage(item.presentationData.theme, top: hasTopCorners, bottom: hasBottomCorners) : nil
                    
                    strongSelf.backgroundNode.frame = CGRect(origin: CGPoint(x: 0.0, y: -min(insets.top, separatorHeight)), size: CGSize(width: params.width, height: contentSize.height + min(insets.top, separatorHeight) + min(insets.bottom, separatorHeight)))
                    strongSelf.containerNode.frame = CGRect(origin: CGPoint(), size: strongSelf.backgroundNode.frame.size)
                    strongSelf.maskNode.frame = strongSelf.backgroundNode.frame.insetBy(dx: params.leftInset, dy: 0.0)
                    strongSelf.topStripeNode.frame = CGRect(origin: CGPoint(x: 0.0, y: -min(insets.top, separatorHeight)), size: CGSize(width: params.width, height: separatorHeight))
                    strongSelf.bottomStripeNode.frame = CGRect(origin: CGPoint(x: bottomStripeInset, y: contentSize.height - separatorHeight), size: CGSize(width: params.width - bottomStripeInset, height: separatorHeight))
                    
                    transition.updateFrame(node: strongSelf.titleNode, frame: CGRect(origin: CGPoint(x: editingOffset + revealOffset + leftInset, y: 8.0), size: titleLayout.size))
                    transition.updateFrame(node: strongSelf.subtitleNode, frame: CGRect(origin: CGPoint(x: editingOffset + revealOffset + leftInset, y: strongSelf.titleNode.frame.maxY + 1.0), size: subtitleLayout.size))
                    
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
                            strongSelf.addSubnode(editableControlNode)
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
                    
                    strongSelf.highlightedBackgroundNode.frame = CGRect(origin: CGPoint(x: 0.0, y: -UIScreenPixel), size: CGSize(width: params.width, height: contentSize.height + UIScreenPixel + UIScreenPixel))
                    
                    strongSelf.updateLayout(size: layout.contentSize, leftInset: params.leftInset, rightInset: params.rightInset)
                    
                    if item.editing.editable {
                        strongSelf.setRevealOptions((left: [], right: [ItemListRevealOption(key: 0, title: item.presentationData.strings.Common_Delete, icon: .none, color: item.presentationData.theme.list.itemDisclosureActions.destructive.fillColor, textColor: item.presentationData.theme.list.itemDisclosureActions.destructive.foregroundColor)]))
                    } else {
                        strongSelf.setRevealOptions((left: [], right: []))
                    }
                    strongSelf.setRevealOptionsOpened(item.editing.revealed, animated: animated)
                    
                    if item.loading {
                        let shimmerNode: ShimmerEffectNode
                        if let current = strongSelf.placeholderNode {
                            shimmerNode = current
                        } else {
                            shimmerNode = ShimmerEffectNode()
                            strongSelf.placeholderNode = shimmerNode
                            if strongSelf.bottomStripeNode.supernode != nil {
                                strongSelf.insertSubnode(shimmerNode, belowSubnode: strongSelf.bottomStripeNode)
                            } else {
                                strongSelf.addSubnode(shimmerNode)
                            }
                        }
                        shimmerNode.frame = CGRect(origin: CGPoint(), size: layout.contentSize)
                        if let (rect, size) = strongSelf.absoluteLocation {
                            shimmerNode.updateAbsoluteRect(rect, within: size)
                        }
                        
                        var shapes: [ShimmerEffectNode.Shape] = []
                        
                        let titleLineWidth: CGFloat = 80.0
                        let subtitleLineWidth: CGFloat = 50.0
                        let lineDiameter: CGFloat = 10.0
                        
                        let titleFrame = strongSelf.titleNode.frame
                        shapes.append(.roundedRectLine(startPoint: CGPoint(x: titleFrame.minX, y: titleFrame.minY + floor((titleFrame.height - lineDiameter) / 2.0)), width: titleLineWidth, diameter: lineDiameter))
                        
                        let subtitleFrame = strongSelf.subtitleNode.frame
                        shapes.append(.roundedRectLine(startPoint: CGPoint(x: subtitleFrame.minX, y: subtitleFrame.minY + floor((subtitleFrame.height - lineDiameter) / 2.0)), width: subtitleLineWidth, diameter: lineDiameter))
                        
                        shimmerNode.update(backgroundColor: item.presentationData.theme.list.itemBlocksBackgroundColor, foregroundColor: item.presentationData.theme.list.mediaPlaceholderColor, shimmeringColor: item.presentationData.theme.list.itemBlocksBackgroundColor.withAlphaComponent(0.4), shapes: shapes, size: layout.contentSize)
                    } else if let shimmerNode = strongSelf.placeholderNode {
                        strongSelf.placeholderNode = nil
                        shimmerNode.removeFromSupernode()
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
        
        guard let params = self.layoutParams?.0 else {
            return
        }
        
        var leftInset: CGFloat = params.leftInset
        leftInset += 16.0
        
        var editingOffset: CGFloat = 0.0
        if let editableControlNode = self.editableControlNode {
            editingOffset += editableControlNode.bounds.size.width
            var editableControlFrame = editableControlNode.frame
            editableControlFrame.origin.x = params.leftInset + offset
            transition.updateFrame(node: editableControlNode, frame: editableControlFrame)
        }
        
        transition.updateFrame(node: self.titleNode, frame: CGRect(origin: CGPoint(x: editingOffset + leftInset + offset, y: self.titleNode.frame.minY), size: self.titleNode.bounds.size))
        transition.updateFrame(node: self.subtitleNode, frame: CGRect(origin: CGPoint(x: editingOffset + leftInset + offset, y: self.subtitleNode.frame.minY), size: self.subtitleNode.bounds.size))
        
        if let image = self.iconNode.image {
            transition.updateFrame(node: self.iconNode, frame: CGRect(origin: CGPoint(x: editingOffset + offset + params.width - params.rightInset - image.size.width - floor((44.0 - image.size.width) / 2.0), y: self.iconNode.frame.minY), size: self.iconNode.bounds.size))
        }
        let activitySize = CGSize(width: 22.0, height: 22.0)
        transition.updateFrame(node: self.activityNode, frame: CGRect(origin: CGPoint(x: editingOffset + offset + params.width - params.rightInset - activitySize.width - floor((44.0 - activitySize.width) / 2.0), y: floor((contentSize.height - activitySize.height) / 2.0)), size: activitySize))
    }
    
    override func revealOptionsInteractivelyOpened() {
        if let item = self.item {
            item.setItemWithRevealedOptions(item.id, nil)
        }
    }
    
    override func revealOptionsInteractivelyClosed() {
        if let item = self.item {
            item.setItemWithRevealedOptions(nil, item.id)
        }
    }
    
    override func revealOptionSelected(_ option: ItemListRevealOption, animated: Bool) {
        self.setRevealOptionsOpened(false, animated: true)
        self.revealOptionsInteractivelyClosed()
        
        if let item = self.item {
            item.removeItem(item.id)
        }
    }
}
