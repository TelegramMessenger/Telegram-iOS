import Foundation
import UIKit
import AsyncDisplayKit
import Display
import SwiftSignalKit
import ItemListUI
import CheckNode
import AvatarNode
import AccountContext
import TelegramPresentationData
import ChatListSearchItemHeader

enum ChatListFilterCategoryIcon {
    case contacts
    case nonContacts
    case groups
    case channels
    case bots
    case muted
    case read
    case archived
}

final class ChatListFilterPresetCategoryItem: ListViewItem, ItemListItem {
    let presentationData: ItemListPresentationData
    let title: String
    let icon: ChatListFilterCategoryIcon
    let isRevealed: Bool
    let selectable: Bool = false
    let sectionId: ItemListSectionId
    let updatedRevealedOptions: (Bool) -> Void
    let remove: () -> Void
    
    init(
        presentationData: ItemListPresentationData,
        title: String,
        icon: ChatListFilterCategoryIcon,
        isRevealed: Bool,
        sectionId: ItemListSectionId,
        updatedRevealedOptions: @escaping (Bool) -> Void,
        remove: @escaping () -> Void
    ) {
        self.presentationData = presentationData
        self.title = title
        self.icon = icon
        self.isRevealed = isRevealed
        self.sectionId = sectionId
        self.updatedRevealedOptions = updatedRevealedOptions
        self.remove = remove
    }
    
    func nodeConfiguredForParams(async: @escaping (@escaping () -> Void) -> Void, params: ListViewItemLayoutParams, synchronousLoads: Bool, previousItem: ListViewItem?, nextItem: ListViewItem?, completion: @escaping (ListViewItemNode, @escaping () -> (Signal<Void, NoError>?, (ListViewItemApply) -> Void)) -> Void) {
        async {
            let node = ChatListFilterPresetCategoryItemNode()
            let (layout, apply) = node.asyncLayout()(self, params, itemListNeighbors(item: self, topItem: previousItem as? ItemListItem, bottomItem: nextItem as? ItemListItem), false)
            
            node.contentSize = layout.contentSize
            node.insets = layout.insets
            
            Queue.mainQueue().async {
                completion(node, {
                    return (.complete(), { _ in apply(synchronousLoads, false) })
                })
            }
        }
    }
    
    func updateNode(async: @escaping (@escaping () -> Void) -> Void, node: @escaping () -> ListViewItemNode, params: ListViewItemLayoutParams, previousItem: ListViewItem?, nextItem: ListViewItem?, animation: ListViewItemUpdateAnimation, completion: @escaping (ListViewItemNodeLayout, @escaping (ListViewItemApply) -> Void) -> Void) {
        Queue.mainQueue().async {
            if let nodeValue = node() as? ChatListFilterPresetCategoryItemNode {
                let makeLayout = nodeValue.asyncLayout()
                
                var animated = true
                if case .None = animation {
                    animated = false
                }
                
                async {
                    let (layout, apply) = makeLayout(self, params, itemListNeighbors(item: self, topItem: previousItem as? ItemListItem, bottomItem: nextItem as? ItemListItem), false)
                    Queue.mainQueue().async {
                        completion(layout, { _ in
                            apply(false, animated)
                        })
                    }
                }
            }
        }
    }
    
    func selected(listView: ListView){
        listView.clearHighlightAnimated(true)
    }
}

private let avatarFont = avatarPlaceholderFont(size: floor(40.0 * 16.0 / 37.0))
private let badgeFont = Font.regular(15.0)

class ChatListFilterPresetCategoryItemNode: ItemListRevealOptionsItemNode, ItemListItemNode {
    private let backgroundNode: ASDisplayNode
    private let topStripeNode: ASDisplayNode
    private let bottomStripeNode: ASDisplayNode
    private let highlightedBackgroundNode: ASDisplayNode
    private let maskNode: ASImageNode
    
    private let avatarNode: ASImageNode
    private let titleNode: TextNode
    
    private var item: ChatListFilterPresetCategoryItem?
    private var layoutParams: ListViewItemLayoutParams?
    
    private var editableControlNode: ItemListEditableControlNode?
    
    override var canBeSelected: Bool {
        if self.editableControlNode != nil {
            return false
        }
        return false
    }
    
    var tag: ItemListItemTag? {
        return nil
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
        
        self.avatarNode = ASImageNode()
        self.avatarNode.isUserInteractionEnabled = false
        
        self.titleNode = TextNode()
        self.titleNode.isUserInteractionEnabled = false
        self.titleNode.contentMode = .left
        self.titleNode.contentsScale = UIScreen.main.scale
        
        self.highlightedBackgroundNode = ASDisplayNode()
        self.highlightedBackgroundNode.isLayerBacked = true
        
        super.init(layerBacked: false, dynamicBounce: false, rotated: false, seeThrough: false)
        
        self.isAccessibilityElement = true
        
        self.addSubnode(self.avatarNode)
        self.addSubnode(self.titleNode)
    }
    
    override func didLoad() {
        super.didLoad()
    }
    
    func asyncLayout() -> (_ item: ChatListFilterPresetCategoryItem, _ params: ListViewItemLayoutParams, _ neighbors: ItemListNeighbors, _ headerAtTop: Bool) -> (ListViewItemNodeLayout, (Bool, Bool) -> Void) {
        let makeTitleLayout = TextNode.asyncLayout(self.titleNode)
        
        let currentItem = self.item
        
        return { item, params, neighbors, headerAtTop in
            var updatedTheme: PresentationTheme?
            
            let titleFont = Font.medium(item.presentationData.fontSize.itemListBaseFontSize)
            
            if currentItem?.presentationData.theme !== item.presentationData.theme {
                updatedTheme = item.presentationData.theme
            }
            
            var titleAttributedString: NSAttributedString?
            
            let peerRevealOptions: [ItemListRevealOption]
            peerRevealOptions = [ItemListRevealOption(key: 0, title: item.presentationData.strings.Common_Delete, icon: .none, color: item.presentationData.theme.list.itemDisclosureActions.destructive.fillColor, textColor: item.presentationData.theme.list.itemDisclosureActions.destructive.foregroundColor)]
            
            let rightInset: CGFloat = params.rightInset
            
            let titleColor: UIColor
            titleColor = item.presentationData.theme.list.itemPrimaryTextColor
            
            
            titleAttributedString = NSAttributedString(string: item.title, font: titleFont, textColor: titleColor)

            let leftInset: CGFloat
            let verticalInset: CGFloat
            let verticalOffset: CGFloat
            let avatarSize: CGFloat
            
            verticalInset = 14.0
            verticalOffset = 0.0
            avatarSize = 40.0
            leftInset = 65.0 + params.leftInset
            
            let editableControlSizeAndApply: (CGFloat, (CGFloat) -> ItemListEditableControlNode)? = nil
            
            let editingOffset: CGFloat
            editingOffset = 0.0
            
            let (titleLayout, titleApply) = makeTitleLayout(TextNodeLayoutArguments(attributedString: titleAttributedString, backgroundColor: nil, maximumNumberOfLines: 1, truncationType: .end, constrainedSize: CGSize(width: params.width - leftInset - 12.0 - editingOffset - rightInset, height: CGFloat.greatestFiniteMagnitude), alignment: .natural, cutout: nil, insets: UIEdgeInsets()))
            
            let insets = itemListNeighborsGroupedInsets(neighbors, params)
            
            let minHeight: CGFloat = titleLayout.size.height + verticalInset * 2.0
            let rawHeight: CGFloat = verticalInset * 2.0 + titleLayout.size.height
            
            let contentSize = CGSize(width: params.width, height: max(minHeight, rawHeight))
            let separatorHeight = UIScreenPixel
            
            let layout = ListViewItemNodeLayout(contentSize: contentSize, insets: insets)
            let layoutSize = layout.size
            
            let hadAvatarImage = self.avatarNode.image != nil
            
            return (layout, { [weak self] synchronousLoad, animated in
                if let strongSelf = self {
                    strongSelf.item = item
                    strongSelf.layoutParams = params
                    
                    strongSelf.accessibilityLabel = titleAttributedString?.string
                    
                    if let _ = updatedTheme {
                        strongSelf.topStripeNode.backgroundColor = item.presentationData.theme.list.itemBlocksSeparatorColor
                        strongSelf.bottomStripeNode.backgroundColor = item.presentationData.theme.list.itemBlocksSeparatorColor
                        strongSelf.backgroundNode.backgroundColor = item.presentationData.theme.list.itemBlocksBackgroundColor
                        strongSelf.highlightedBackgroundNode.backgroundColor = item.presentationData.theme.list.itemHighlightedBackgroundColor
                    }
                    
                    var updatedAvatarImage: UIImage?
                    if !hadAvatarImage {
                        let color: AvatarBackgroundColor
                        let imageName: String
                        switch item.icon {
                        case .contacts:
                            color = .blue
                            imageName = "Chat/Context Menu/User"
                        case .nonContacts:
                            color = .yellow
                            imageName = "Chat/Context Menu/UnknownUser"
                        case .groups:
                            color = .green
                            imageName = "Chat/Context Menu/Groups"
                        case .channels:
                            color = .red
                            imageName = "Chat/Context Menu/Channels"
                        case .bots:
                            color = .violet
                            imageName = "Chat/Context Menu/Bots"
                        case .muted:
                            color = .red
                            imageName = "Chat/Context Menu/Muted"
                        case .read:
                            color = .blue
                            imageName = "Chat/Context Menu/Message"
                        case .archived:
                            color = .yellow
                            imageName = "Chat/Context Menu/Archive"
                        }
                        updatedAvatarImage = generateAvatarImage(size: CGSize(width: avatarSize, height: avatarSize), icon: generateTintedImage(image: UIImage(bundleImageName: imageName), color: .white), color: color)
                    }
                    
                    let revealOffset = strongSelf.revealOffset
                    
                    let transition: ContainedViewLayoutTransition
                    if animated {
                        transition = ContainedViewLayoutTransition.animated(duration: 0.4, curve: .spring)
                    } else {
                        transition = .immediate
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
                            strongSelf.addSubnode(editableControlNode)
                            editableControlNode.frame = editableControlFrame
                            transition.animatePosition(node: editableControlNode, from: CGPoint(x: -editableControlFrame.size.width / 2.0, y: editableControlFrame.midY))
                            editableControlNode.alpha = 0.0
                            transition.updateAlpha(node: editableControlNode, alpha: 1.0)
                        } else {
                            strongSelf.editableControlNode?.frame = editableControlFrame
                        }
                        strongSelf.editableControlNode?.isHidden = true
                    } else if let editableControlNode = strongSelf.editableControlNode {
                        var editableControlFrame = editableControlNode.frame
                        editableControlFrame.origin.x = -editableControlFrame.size.width
                        strongSelf.editableControlNode = nil
                        transition.updateAlpha(node: editableControlNode, alpha: 0.0)
                        transition.updateFrame(node: editableControlNode, frame: editableControlFrame, completion: { [weak editableControlNode] _ in
                            editableControlNode?.removeFromSupernode()
                        })
                    }
                    
                    let _ = titleApply()
                    
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
                    strongSelf.maskNode.frame = strongSelf.backgroundNode.frame.insetBy(dx: params.leftInset, dy: 0.0)
                    transition.updateFrame(node: strongSelf.topStripeNode, frame: CGRect(origin: CGPoint(x: 0.0, y: -min(insets.top, separatorHeight)), size: CGSize(width: layoutSize.width, height: separatorHeight)))
                    transition.updateFrame(node: strongSelf.bottomStripeNode, frame: CGRect(origin: CGPoint(x: bottomStripeInset, y: contentSize.height + bottomStripeOffset), size: CGSize(width: layoutSize.width - bottomStripeInset, height: separatorHeight)))
                    
                    transition.updateFrame(node: strongSelf.titleNode, frame: CGRect(origin: CGPoint(x: leftInset + revealOffset + editingOffset, y: verticalInset + verticalOffset), size: titleLayout.size))
                    
                    transition.updateFrame(node: strongSelf.avatarNode, frame: CGRect(origin: CGPoint(x: params.leftInset + revealOffset + editingOffset + 15.0, y: floorToScreenPixels((layout.contentSize.height - avatarSize) / 2.0)), size: CGSize(width: avatarSize, height: avatarSize)))
                    
                    if let updatedAvatarImage = updatedAvatarImage {
                        strongSelf.avatarNode.image = updatedAvatarImage
                    }
                    
                    strongSelf.highlightedBackgroundNode.frame = CGRect(origin: CGPoint(x: 0.0, y: -UIScreenPixel), size: CGSize(width: params.width, height: layout.contentSize.height + UIScreenPixel + UIScreenPixel))
                    
                    strongSelf.backgroundNode.isHidden = false
                    strongSelf.highlightedBackgroundNode.isHidden = true
                    
                    strongSelf.updateLayout(size: layout.contentSize, leftInset: params.leftInset, rightInset: params.rightInset)
                    
                    strongSelf.setRevealOptions((left: [], right: peerRevealOptions))
                    strongSelf.setRevealOptionsOpened(item.isRevealed, animated: animated)
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
        
        guard let _ = self.item, let params = self.layoutParams else {
            return
        }
        
        let leftInset: CGFloat
        leftInset = 65.0 + params.leftInset
        
        let editingOffset: CGFloat
        if let editableControlNode = self.editableControlNode {
            editingOffset = editableControlNode.bounds.size.width
            var editableControlFrame = editableControlNode.frame
            editableControlFrame.origin.x = params.leftInset + offset
            transition.updateFrame(node: editableControlNode, frame: editableControlFrame)
        } else {
            editingOffset = 0.0
        }
        
        transition.updateFrame(node: self.titleNode, frame: CGRect(origin: CGPoint(x: leftInset + revealOffset + editingOffset, y: self.titleNode.frame.minY), size: self.titleNode.bounds.size))
        
        transition.updateFrame(node: self.avatarNode, frame: CGRect(origin: CGPoint(x: revealOffset + editingOffset + params.leftInset + 15.0, y: self.avatarNode.frame.minY), size: self.avatarNode.bounds.size))
    }
    
    override func revealOptionsInteractivelyOpened() {
        if let item = self.item {
            item.updatedRevealedOptions(true)
        }
    }
    
    override func revealOptionsInteractivelyClosed() {
        if let item = self.item {
            item.updatedRevealedOptions(false)
        }
    }
    
    override func revealOptionSelected(_ option: ItemListRevealOption, animated: Bool) {
        self.setRevealOptionsOpened(false, animated: true)
        self.revealOptionsInteractivelyClosed()
        
        if let item = self.item {
            item.remove()
        }
    }
    
    override func headers() -> [ListViewItemHeader]? {
        return nil
    }
}
