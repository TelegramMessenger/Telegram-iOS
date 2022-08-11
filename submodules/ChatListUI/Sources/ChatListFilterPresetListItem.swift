import Foundation
import UIKit
import Display
import AsyncDisplayKit
import SwiftSignalKit
import Postbox
import TelegramCore
import TelegramPresentationData
import ItemListUI
import TelegramUIPreferences

struct ChatListFilterPresetListItemEditing: Equatable {
    let editable: Bool
    let editing: Bool
    let revealed: Bool
}

final class ChatListFilterPresetListItem: ListViewItem, ItemListItem {
    let presentationData: ItemListPresentationData
    let preset: ChatListFilter
    let title: String
    let label: String
    let editing: ChatListFilterPresetListItemEditing
    let canBeReordered: Bool
    let canBeDeleted: Bool
    let isAllChats: Bool
    let isDisabled: Bool
    let sectionId: ItemListSectionId
    let action: () -> Void
    let setItemWithRevealedOptions: (Int32?, Int32?) -> Void
    let remove: () -> Void
    
    init(
        presentationData: ItemListPresentationData,
        preset: ChatListFilter,
        title: String,
        label: String,
        editing: ChatListFilterPresetListItemEditing,
        canBeReordered: Bool,
        canBeDeleted: Bool,
        isAllChats: Bool,
        isDisabled: Bool,
        sectionId: ItemListSectionId,
        action: @escaping () -> Void,
        setItemWithRevealedOptions: @escaping (Int32?, Int32?) -> Void,
        remove: @escaping () -> Void
    ) {
        self.presentationData = presentationData
        self.preset = preset
        self.title = title
        self.label = label
        self.editing = editing
        self.canBeReordered = canBeReordered
        self.canBeDeleted = canBeDeleted
        self.isAllChats = isAllChats
        self.isDisabled = isDisabled
        self.sectionId = sectionId
        self.action = action
        self.setItemWithRevealedOptions = setItemWithRevealedOptions
        self.remove = remove
    }
    
    func nodeConfiguredForParams(async: @escaping (@escaping () -> Void) -> Void, params: ListViewItemLayoutParams, synchronousLoads: Bool, previousItem: ListViewItem?, nextItem: ListViewItem?, completion: @escaping (ListViewItemNode, @escaping () -> (Signal<Void, NoError>?, (ListViewItemApply) -> Void)) -> Void) {
        async {
            let node = ChatListFilterPresetListItemNode()
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
            if let nodeValue = node() as? ChatListFilterPresetListItemNode {
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
    
    var selectable: Bool  {
        return !self.isAllChats
    }
    
    func selected(listView: ListView){
        listView.clearHighlightAnimated(true)
        self.action()
    }
}

private let titleFont = Font.regular(17.0)

private final class ChatListFilterPresetListItemNode: ItemListRevealOptionsItemNode {
    private let backgroundNode: ASDisplayNode
    private let topStripeNode: ASDisplayNode
    private let bottomStripeNode: ASDisplayNode
    private let highlightedBackgroundNode: ASDisplayNode
    private let maskNode: ASImageNode
    
    private let containerNode: ASDisplayNode
    override var controlsContainer: ASDisplayNode {
        return self.containerNode
    }
    
    private let titleNode: TextNode
    private let labelNode: TextNode
    private let arrowNode: ASImageNode
    
    private let activateArea: AccessibilityAreaNode
    
    private var editableControlNode: ItemListEditableControlNode?
    private var reorderControlNode: ItemListEditableReorderControlNode?
    
    private var item: ChatListFilterPresetListItem?
    private var layoutParams: ListViewItemLayoutParams?
    
    override var canBeSelected: Bool {
        if self.editableControlNode != nil {
            return false
        }
        return true
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
        
        self.titleNode = TextNode()
        self.titleNode.isUserInteractionEnabled = false
        self.titleNode.contentMode = .left
        self.titleNode.contentsScale = UIScreen.main.scale
        
        self.labelNode = TextNode()
        self.labelNode.isUserInteractionEnabled = false
        
        self.arrowNode = ASImageNode()
        self.arrowNode.displayWithoutProcessing = true
        self.arrowNode.displaysAsynchronously = false
        self.arrowNode.isLayerBacked = true
        
        self.activateArea = AccessibilityAreaNode()
        
        self.highlightedBackgroundNode = ASDisplayNode()
        self.highlightedBackgroundNode.isLayerBacked = true
        
        super.init(layerBacked: false, dynamicBounce: false, rotated: false, seeThrough: false)
        
        self.addSubnode(self.containerNode)
        self.containerNode.addSubnode(self.titleNode)
        self.containerNode.addSubnode(self.labelNode)
        self.containerNode.addSubnode(self.arrowNode)
        self.addSubnode(self.activateArea)
        
        self.activateArea.activate = { [weak self] in
            self?.item?.action()
            return true
        }
    }
    
    func asyncLayout() -> (_ item: ChatListFilterPresetListItem, _ params: ListViewItemLayoutParams, _ neighbors: ItemListNeighbors) -> (ListViewItemNodeLayout, (Bool) -> Void) {
        let makeTitleLayout = TextNode.asyncLayout(self.titleNode)
        let makeLabelLayout = TextNode.asyncLayout(self.labelNode)
        let editableControlLayout = ItemListEditableControlNode.asyncLayout(self.editableControlNode)
        let reorderControlLayout = ItemListEditableReorderControlNode.asyncLayout(self.reorderControlNode)
        
        let currentItem = self.item
        
        return { item, params, neighbors in
            var updatedTheme: PresentationTheme?
            var updateArrowImage: UIImage?
            
            if currentItem?.presentationData.theme !== item.presentationData.theme || currentItem?.isDisabled != item.isDisabled {
                updatedTheme = item.presentationData.theme
                if item.isDisabled {
                    updateArrowImage = PresentationResourcesItemList.disclosureLockedImage(item.presentationData.theme)
                } else {
                    updateArrowImage = PresentationResourcesItemList.disclosureArrowImage(item.presentationData.theme)
                }
            }
            
            let peerRevealOptions: [ItemListRevealOption]
            if item.editing.editable && item.canBeDeleted {
                peerRevealOptions = [ItemListRevealOption(key: 0, title: item.presentationData.strings.Common_Delete, icon: .none, color: item.presentationData.theme.list.itemDisclosureActions.destructive.fillColor, textColor: item.presentationData.theme.list.itemDisclosureActions.destructive.foregroundColor)]
            } else {
                peerRevealOptions = []
            }
            
            let titleAttributedString = NSMutableAttributedString()
            titleAttributedString.append(NSAttributedString(string: item.isAllChats ? item.presentationData.strings.ChatList_FolderAllChats : item.title, font: titleFont, textColor: item.presentationData.theme.list.itemPrimaryTextColor))
            
            var editableControlSizeAndApply: (CGFloat, (CGFloat) -> ItemListEditableControlNode)?
            var reorderControlSizeAndApply: (CGFloat, (CGFloat, Bool, ContainedViewLayoutTransition) -> ItemListEditableReorderControlNode)?
            
            var editingOffset: CGFloat = 0.0
            var reorderInset: CGFloat = 0.0
            
            if item.editing.editing {
                let sizeAndApply = editableControlLayout(item.presentationData.theme, false)
                editableControlSizeAndApply = sizeAndApply
                editingOffset = sizeAndApply.0
                
                if item.canBeReordered {
                    let reorderSizeAndApply = reorderControlLayout(item.presentationData.theme)
                    reorderControlSizeAndApply = reorderSizeAndApply
                    reorderInset = reorderSizeAndApply.0
                }
            }
            
            let leftInset: CGFloat = 16.0 + params.leftInset
            let rightInset: CGFloat = params.rightInset + max(reorderInset, 55.0)
            let rightArrowInset: CGFloat = 34.0 + params.rightInset
            
            let (titleLayout, titleApply) = makeTitleLayout(TextNodeLayoutArguments(attributedString: titleAttributedString, backgroundColor: nil, maximumNumberOfLines: 1, truncationType: .middle, constrainedSize: CGSize(width: params.width - leftInset - 12.0 - editingOffset - rightInset, height: CGFloat.greatestFiniteMagnitude), alignment: .natural, cutout: nil, insets: UIEdgeInsets()))
            
            let labelConstrain: CGFloat = params.width - params.rightInset - leftInset - 40.0 - titleLayout.size.width - 10.0
            let (labelLayout, labelApply) = makeLabelLayout(TextNodeLayoutArguments(attributedString: NSAttributedString(string: item.label, font: titleFont, textColor: item.presentationData.theme.list.itemSecondaryTextColor), backgroundColor: nil, maximumNumberOfLines: 1, truncationType: .end, constrainedSize: CGSize(width: labelConstrain, height: CGFloat.greatestFiniteMagnitude), alignment: .natural, cutout: nil, insets: UIEdgeInsets()))
            
            let insets = itemListNeighborsGroupedInsets(neighbors, params)
            let contentSize = CGSize(width: params.width, height: titleLayout.size.height + 11.0 * 2.0)
            let separatorHeight = UIScreenPixel
            
            let layout = ListViewItemNodeLayout(contentSize: contentSize, insets: insets)
            let layoutSize = layout.size
            
            return (layout, { [weak self] animated in
                if let strongSelf = self {
                    strongSelf.item = item
                    strongSelf.layoutParams = params
                    
                    strongSelf.activateArea.accessibilityLabel = "\(titleAttributedString.string))"
                    
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
                    
                    if let reorderControlSizeAndApply = reorderControlSizeAndApply {
                        if strongSelf.reorderControlNode == nil {
                            let reorderControlNode = reorderControlSizeAndApply.1(layout.contentSize.height, false, .immediate)
                            strongSelf.reorderControlNode = reorderControlNode
                            strongSelf.controlsContainer.addSubnode(reorderControlNode)
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
                            strongSelf.insertSubnode(editableControlNode, aboveSubnode: strongSelf.containerNode)
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
                    strongSelf.editableControlNode?.isHidden = !item.canBeDeleted
                                        
                    let _ = titleApply()
                    let _ = labelApply()
                    
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
                    
                    transition.updateFrame(node: strongSelf.titleNode, frame: CGRect(origin: CGPoint(x: leftInset + revealOffset + editingOffset, y: 11.0), size: titleLayout.size))
                    
                    let labelFrame = CGRect(origin: CGPoint(x: params.width - rightArrowInset - labelLayout.size.width + revealOffset, y: 11.0), size: labelLayout.size)
                    strongSelf.labelNode.frame = labelFrame
                    
                    transition.updateAlpha(node: strongSelf.labelNode, alpha: reorderControlSizeAndApply != nil ? 0.0 : 1.0)
                    transition.updateAlpha(node: strongSelf.arrowNode, alpha: reorderControlSizeAndApply != nil ? 0.0 : 1.0)
                    
                    if let updateArrowImage = updateArrowImage {
                        strongSelf.arrowNode.image = updateArrowImage
                    }
                    
                    if let arrowImage = strongSelf.arrowNode.image {
                        var rightArrowInset = 0.0
                        if item.isDisabled == true {
                            rightArrowInset -= 3.0
                        }
                        strongSelf.arrowNode.frame = CGRect(origin: CGPoint(x: params.width - params.rightInset - 7.0 - arrowImage.size.width + rightArrowInset + revealOffset, y: floorToScreenPixels((layout.contentSize.height - arrowImage.size.height) / 2.0)), size: arrowImage.size)
                    }
                    strongSelf.arrowNode.isHidden = item.isAllChats
                    
                    strongSelf.activateArea.frame = CGRect(origin: CGPoint(x: leftInset + revealOffset + editingOffset, y: 0.0), size: CGSize(width: params.width - params.rightInset - 56.0 - (leftInset + revealOffset + editingOffset), height: layout.contentSize.height))
                    
                    strongSelf.highlightedBackgroundNode.frame = CGRect(origin: CGPoint(x: 0.0, y: -UIScreenPixel), size: CGSize(width: params.width, height: layout.contentSize.height + UIScreenPixel + UIScreenPixel))
                    
                    strongSelf.updateLayout(size: layout.contentSize, leftInset: params.leftInset, rightInset: params.rightInset)
                    
                    strongSelf.setRevealOptions((left: [], right: peerRevealOptions))
                    strongSelf.setRevealOptionsOpened(item.editing.revealed, animated: animated)
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
        
        guard let params = self.layoutParams else {
            return
        }
        
        let leftInset: CGFloat = 16.0 + params.leftInset
        var rightArrowInset: CGFloat = 34.0 + params.rightInset
        if self.item?.isDisabled == true {
            rightArrowInset -= 3.0
        }
        let editingOffset: CGFloat
        if let editableControlNode = self.editableControlNode {
            editingOffset = editableControlNode.bounds.size.width
            var editableControlFrame = editableControlNode.frame
            editableControlFrame.origin.x = params.leftInset + offset
            transition.updateFrame(node: editableControlNode, frame: editableControlFrame)
        } else {
            editingOffset = 0.0
        }
        
        transition.updateFrame(node: self.titleNode, frame: CGRect(origin: CGPoint(x: leftInset + offset + editingOffset, y: self.titleNode.frame.minY), size: self.titleNode.bounds.size))
        
        var labelFrame = self.labelNode.frame
        labelFrame.origin.x = params.width - rightArrowInset - labelFrame.width + revealOffset
        transition.updateFrame(node: self.labelNode, frame: labelFrame)
        
        var arrowFrame = self.arrowNode.frame
        arrowFrame.origin.x = params.width - params.rightInset - 7.0 - arrowFrame.width + revealOffset
        transition.updateFrame(node: self.arrowNode, frame: arrowFrame)
    }
    
    override func revealOptionsInteractivelyOpened() {
        if let item = self.item {
            item.setItemWithRevealedOptions(item.preset.id, nil)
        }
    }
    
    override func revealOptionsInteractivelyClosed() {
        if let item = self.item {
            item.setItemWithRevealedOptions(nil, item.preset.id)
        }
    }
    
    override func revealOptionSelected(_ option: ItemListRevealOption, animated: Bool) {
        self.setRevealOptionsOpened(false, animated: true)
        self.revealOptionsInteractivelyClosed()
        
         if let item = self.item {
            item.remove()
        }
    }
    
    override func isReorderable(at point: CGPoint) -> Bool {
        if let reorderControlNode = self.reorderControlNode, reorderControlNode.frame.contains(point), !self.isDisplayingRevealedOptions {
            return true
        }
        return false
    }
}
