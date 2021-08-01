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

public class ChatListAdditionalCategoryItem: ItemListItem, ListViewItemWithHeader {
    let presentationData: ItemListPresentationData
    public let sectionId: ItemListSectionId
    let context: AccountContext
    let title: String
    let image: UIImage?
    let appearance: ChatListNodeAdditionalCategory.Appearance
    let isSelected: Bool
    let action: () -> Void
    
    public let selectable: Bool = true
    
    public let header: ListViewItemHeader?
    
    public init(
        presentationData: ItemListPresentationData,
        sectionId: ItemListSectionId = 0,
        context: AccountContext,
        title: String,
        image: UIImage?,
        appearance: ChatListNodeAdditionalCategory.Appearance,
        isSelected: Bool,
        header: ListViewItemHeader?,
        action: @escaping () -> Void
    ) {
        self.presentationData = presentationData
        self.sectionId = sectionId
        self.context = context
        self.title = title
        self.image = image
        self.appearance = appearance
        self.isSelected = isSelected
        self.action = action
        
        switch appearance {
        case .option:
            self.header = ChatListSearchItemHeader(type: .chatTypes, theme: presentationData.theme, strings: presentationData.strings, actionTitle: nil, action: nil)
        case .action:
            self.header = header
        }
    }
    
    public func nodeConfiguredForParams(async: @escaping (@escaping () -> Void) -> Void, params: ListViewItemLayoutParams, synchronousLoads: Bool, previousItem: ListViewItem?, nextItem: ListViewItem?, completion: @escaping (ListViewItemNode, @escaping () -> (Signal<Void, NoError>?, (ListViewItemApply) -> Void)) -> Void) {
        async {
            let node = ChatListAdditionalCategoryItemNode()
            let makeLayout = node.asyncLayout()
            let (first, last, firstWithHeader) = ChatListAdditionalCategoryItem.mergeType(item: self, previousItem: previousItem, nextItem: nextItem)
            let (nodeLayout, nodeApply) = makeLayout(self, params, first, last, firstWithHeader, itemListNeighbors(item: self, topItem: previousItem as? ItemListItem, bottomItem: nextItem as? ItemListItem))
            node.contentSize = nodeLayout.contentSize
            node.insets = nodeLayout.insets
            
            Queue.mainQueue().async {
                completion(node, {
                    let (signal, apply) = nodeApply()
                    return (signal, { _ in
                        apply(false, synchronousLoads)
                    })
                })
            }
        }
    }
    
    public func updateNode(async: @escaping (@escaping () -> Void) -> Void, node: @escaping () -> ListViewItemNode, params: ListViewItemLayoutParams, previousItem: ListViewItem?, nextItem: ListViewItem?, animation: ListViewItemUpdateAnimation, completion: @escaping (ListViewItemNodeLayout, @escaping (ListViewItemApply) -> Void) -> Void) {
        Queue.mainQueue().async {
            if let nodeValue = node() as? ChatListAdditionalCategoryItemNode {
                let layout = nodeValue.asyncLayout()
                async {
                    let (first, last, firstWithHeader) = ChatListAdditionalCategoryItem.mergeType(item: self, previousItem: previousItem, nextItem: nextItem)
                    let (nodeLayout, apply) = layout(self, params, first, last, firstWithHeader, itemListNeighbors(item: self, topItem: previousItem as? ItemListItem, bottomItem: nextItem as? ItemListItem))
                    Queue.mainQueue().async {
                        completion(nodeLayout, { _ in
                            apply().1(animation.isAnimated, false)
                        })
                    }
                }
            }
        }
    }
    
    public func selected(listView: ListView) {
        if case .action = self.appearance {
            listView.clearHighlightAnimated(true)
        }
        self.action()
    }
    
    static func mergeType(item: ChatListAdditionalCategoryItem, previousItem: ListViewItem?, nextItem: ListViewItem?) -> (first: Bool, last: Bool, firstWithHeader: Bool) {
        var first = false
        var last = false
        var firstWithHeader = false
        if let previousItem = previousItem {
            if let header = item.header {
                if let previousItem = previousItem as? ListViewItemWithHeader {
                    firstWithHeader = header.id != previousItem.header?.id
                } else {
                    firstWithHeader = true
                }
            }
        } else {
            first = true
            firstWithHeader = item.header != nil
        }
        if let nextItem = nextItem {
            if let header = item.header {
                if let nextItem = nextItem as? ListViewItemWithHeader {
                    last = header.id != nextItem.header?.id
                } else {
                    last = true
                }
            } else if let _ = nextItem as? ChatListAdditionalCategoryItem {
            } else {
                last = true
            }
        } else {
            last = true
        }
        return (first, last, firstWithHeader)
    }
}

private let avatarFont = avatarPlaceholderFont(size: 16.0)

public class ChatListAdditionalCategoryItemNode: ItemListRevealOptionsItemNode {
    private let backgroundNode: ASDisplayNode
    private let topSeparatorNode: ASDisplayNode
    private let separatorNode: ASDisplayNode
    private let highlightedBackgroundNode: ASDisplayNode
    
    private let avatarNode: ASImageNode
    private let titleNode: TextNode
    private var selectionNode: CheckNode?
    
    private var isHighlighted: Bool = false

    private var item: ChatListAdditionalCategoryItem?

    required public init() {
        self.backgroundNode = ASDisplayNode()
        self.backgroundNode.isLayerBacked = true
        
        self.topSeparatorNode = ASDisplayNode()
        self.topSeparatorNode.isLayerBacked = true
        
        self.separatorNode = ASDisplayNode()
        self.separatorNode.isLayerBacked = true
        
        self.highlightedBackgroundNode = ASDisplayNode()
        self.highlightedBackgroundNode.isLayerBacked = true
        
        self.avatarNode = ASImageNode()
        
        self.titleNode = TextNode()
        
        super.init(layerBacked: false, dynamicBounce: false, rotated: false, seeThrough: false)
        
        self.isAccessibilityElement = true
        
        self.addSubnode(self.backgroundNode)
        self.addSubnode(self.topSeparatorNode)
        self.addSubnode(self.separatorNode)
        
        self.addSubnode(self.avatarNode)
        self.addSubnode(self.titleNode)
    }
    
    override public func layoutForParams(_ params: ListViewItemLayoutParams, item: ListViewItem, previousItem: ListViewItem?, nextItem: ListViewItem?) {
        if let item = self.item {
            let (first, last, firstWithHeader) = ChatListAdditionalCategoryItem.mergeType(item: item, previousItem: previousItem, nextItem: nextItem)
            let makeLayout = self.asyncLayout()
            let (nodeLayout, nodeApply) = makeLayout(item, params, first, last, firstWithHeader, itemListNeighbors(item: item, topItem: previousItem as? ItemListItem, bottomItem: nextItem as? ItemListItem))
            self.contentSize = nodeLayout.contentSize
            self.insets = nodeLayout.insets
            let _ = nodeApply()
        }
    }
    
    override public func setHighlighted(_ highlighted: Bool, at point: CGPoint, animated: Bool) {
        if let item = self.item, case .action = item.appearance {
            super.setHighlighted(highlighted, at: point, animated: animated)
            
            self.isHighlighted = highlighted
            self.updateIsHighlighted(transition: (animated && !highlighted) ? .animated(duration: 0.3, curve: .easeInOut) : .immediate)
        }
    }

    
    public func updateIsHighlighted(transition: ContainedViewLayoutTransition) {
        let reallyHighlighted = self.isHighlighted
        let highlightProgress: CGFloat = 1.0
        
        if reallyHighlighted {
            if self.highlightedBackgroundNode.supernode == nil {
                self.insertSubnode(self.highlightedBackgroundNode, aboveSubnode: self.separatorNode)
                self.highlightedBackgroundNode.alpha = 0.0
            }
            self.highlightedBackgroundNode.layer.removeAllAnimations()
            transition.updateAlpha(layer: self.highlightedBackgroundNode.layer, alpha: highlightProgress)
        } else {
            if self.highlightedBackgroundNode.supernode != nil {
                transition.updateAlpha(layer: self.highlightedBackgroundNode.layer, alpha: 1.0 - highlightProgress, completion: { [weak self] completed in
                    if let strongSelf = self {
                        if completed {
                            strongSelf.highlightedBackgroundNode.removeFromSupernode()
                        }
                    }
                })
            }
        }
    }
    
    public func asyncLayout() -> (_ item: ChatListAdditionalCategoryItem, _ params: ListViewItemLayoutParams, _ first: Bool, _ last: Bool, _ firstWithHeader: Bool, _ neighbors: ItemListNeighbors) -> (ListViewItemNodeLayout, () -> (Signal<Void, NoError>?, (Bool, Bool) -> Void)) {
        let makeTitleLayout = TextNode.asyncLayout(self.titleNode)
        let currentSelectionNode = self.selectionNode
        
        let currentItem = self.item
        
        return { [weak self] item, params, first, last, firstWithHeader, neighbors in
            var updatedTheme: PresentationTheme?
            
            let titleFont = Font.regular(item.presentationData.fontSize.itemListBaseFontSize)
            
            let avatarDiameter: CGFloat = 40.0
            
            if currentItem?.presentationData.theme !== item.presentationData.theme {
                updatedTheme = item.presentationData.theme
            }
            let leftInset: CGFloat = 65.0 + params.leftInset
            var rightInset: CGFloat = 10.0 + params.rightInset
            
            let updatedSelectionNode: CheckNode?
            let isSelected = item.isSelected
            
            if case .option = item.appearance {
                rightInset += 28.0
                
                let selectionNode: CheckNode
                if let current = currentSelectionNode {
                    selectionNode = current
                    updatedSelectionNode = selectionNode
                } else {
                    selectionNode = CheckNode(theme: CheckNodeTheme(theme: item.presentationData.theme, style: .plain))
                    selectionNode.isUserInteractionEnabled = false
                    updatedSelectionNode = selectionNode
                }
            } else {
                updatedSelectionNode = nil
            }
            
            var titleAttributedString: NSAttributedString?
            let textColor: UIColor
            if case .action = item.appearance {
                textColor = item.presentationData.theme.list.itemAccentColor
            } else {
                textColor = item.presentationData.theme.list.itemPrimaryTextColor
            }
            titleAttributedString = NSAttributedString(string: item.title, font: titleFont, textColor: textColor)
            
            let (titleLayout, titleApply) = makeTitleLayout(TextNodeLayoutArguments(attributedString: titleAttributedString, backgroundColor: nil, maximumNumberOfLines: 1, truncationType: .end, constrainedSize: CGSize(width: max(0.0, params.width - leftInset - rightInset), height: CGFloat.infinity), alignment: .natural, cutout: nil, insets: UIEdgeInsets()))
            
            let verticalInset: CGFloat = 13.0
            
            let statusHeightComponent: CGFloat
            statusHeightComponent = 0.0
            
            let nodeLayout = ListViewItemNodeLayout(contentSize: CGSize(width: params.width, height: verticalInset * 2.0 + titleLayout.size.height + statusHeightComponent), insets: UIEdgeInsets(top: firstWithHeader ? 29.0 : 0.0, left: 0.0, bottom: 0.0, right: 0.0))
            
            let titleFrame: CGRect
            titleFrame = CGRect(origin: CGPoint(x: leftInset, y: floor((nodeLayout.contentSize.height - titleLayout.size.height) / 2.0)), size: titleLayout.size)
            
            return (nodeLayout, { [weak self] in
                if let strongSelf = self {
                    return (.complete(), { [weak strongSelf] animated, synchronousLoads in
                        if let strongSelf = strongSelf {
                            strongSelf.item = item
                            
                            strongSelf.accessibilityLabel = titleAttributedString?.string
                            
                            //strongSelf.containerNode.frame = CGRect(origin: CGPoint(), size: nodeLayout.contentSize)
                            //strongSelf.containerNode.isGestureEnabled = item.contextAction != nil
                            
                            let transition: ContainedViewLayoutTransition
                            if animated {
                                transition = ContainedViewLayoutTransition.animated(duration: 0.4, curve: .spring)
                            } else {
                                transition = .immediate
                            }
                            
                            let revealOffset = strongSelf.revealOffset
                            
                            if let _ = updatedTheme {
                                strongSelf.topSeparatorNode.backgroundColor = item.presentationData.theme.list.itemPlainSeparatorColor
                                strongSelf.separatorNode.backgroundColor = item.presentationData.theme.list.itemPlainSeparatorColor
                                strongSelf.backgroundNode.backgroundColor = item.presentationData.theme.list.plainBackgroundColor
                                strongSelf.highlightedBackgroundNode.backgroundColor = item.presentationData.theme.list.itemHighlightedBackgroundColor
                            }
                            
                            strongSelf.topSeparatorNode.isHidden = true
                            
                            if let image = item.image {
                                strongSelf.avatarNode.image = item.image
                                transition.updateFrame(node: strongSelf.avatarNode, frame: CGRect(origin: CGPoint(x: revealOffset + leftInset - 50.0 + floor((avatarDiameter - image.size.width) / 2.0), y: floor((nodeLayout.contentSize.height - image.size.width) / 2.0)), size: image.size))
                            }
                            
                            let _ = titleApply()
                            transition.updateFrame(node: strongSelf.titleNode, frame: titleFrame.offsetBy(dx: revealOffset, dy: 0.0))
                            
                            if let updatedSelectionNode = updatedSelectionNode {
                                if strongSelf.selectionNode !== updatedSelectionNode {
                                    strongSelf.selectionNode?.removeFromSupernode()
                                    strongSelf.selectionNode = updatedSelectionNode
                                    strongSelf.addSubnode(updatedSelectionNode)
                                }
                                updatedSelectionNode.setSelected(isSelected, animated: animated)
                                
                                updatedSelectionNode.frame = CGRect(origin: CGPoint(x: params.width - params.rightInset - 22.0 - 17.0, y: floor((nodeLayout.contentSize.height - 22.0) / 2.0)), size: CGSize(width: 22.0, height: 22.0))
                            } else if let selectionNode = strongSelf.selectionNode {
                                selectionNode.removeFromSupernode()
                                strongSelf.selectionNode = nil
                            }
                            
                            let separatorHeight = UIScreenPixel
                            
                            let topHighlightInset: CGFloat = (first || !nodeLayout.insets.top.isZero) ? 0.0 : separatorHeight
                            strongSelf.backgroundNode.frame = CGRect(origin: CGPoint(x: 0.0, y: 0.0), size: CGSize(width: nodeLayout.contentSize.width, height: nodeLayout.contentSize.height))
                            strongSelf.highlightedBackgroundNode.frame = CGRect(origin: CGPoint(x: 0.0, y: -nodeLayout.insets.top - topHighlightInset), size: CGSize(width: nodeLayout.size.width, height: nodeLayout.size.height + topHighlightInset))
                            strongSelf.topSeparatorNode.frame = CGRect(origin: CGPoint(x: 0.0, y: -min(nodeLayout.insets.top, separatorHeight)), size: CGSize(width: nodeLayout.contentSize.width, height: separatorHeight))
                            strongSelf.separatorNode.frame = CGRect(origin: CGPoint(x: leftInset, y: nodeLayout.contentSize.height - separatorHeight), size: CGSize(width: max(0.0, nodeLayout.size.width - leftInset), height: separatorHeight))
                            strongSelf.separatorNode.isHidden = last
                            
                            strongSelf.updateLayout(size: nodeLayout.contentSize, leftInset: params.leftInset, rightInset: params.rightInset)
                        }
                    })
                } else {
                    return (nil, { _, _ in
                    })
                }
            })
        }
    }
    
    override public func layoutHeaderAccessoryItemNode(_ accessoryItemNode: ListViewAccessoryItemNode) {
        let bounds = self.bounds
        accessoryItemNode.frame = CGRect(origin: CGPoint(x: 0.0, y: -29.0), size: CGSize(width: bounds.size.width, height: 29.0))
    }
    
    override public func animateInsertion(_ currentTimestamp: Double, duration: Double, short: Bool) {
        self.layer.animateAlpha(from: 0.0, to: 1.0, duration: duration * 0.5)
    }
    
    override public func animateRemoved(_ currentTimestamp: Double, duration: Double) {
        self.layer.animateAlpha(from: 1.0, to: 0.0, duration: duration * 0.5, removeOnCompletion: false)
    }
    
    override public func headers() -> [ListViewItemHeader]? {
        if let item = self.item {
            return item.header.flatMap { [$0] }
        } else {
            return nil
        }
    }
}
