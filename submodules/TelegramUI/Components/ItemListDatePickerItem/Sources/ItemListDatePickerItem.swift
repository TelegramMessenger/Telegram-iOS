import Foundation
import UIKit
import Display
import AsyncDisplayKit
import SwiftSignalKit
import TelegramPresentationData
import ItemListUI
import DatePickerNode

public class ItemListDatePickerItem: ListViewItem, ItemListItem {
    let presentationData: ItemListPresentationData
    let dateTimeFormat: PresentationDateTimeFormat
    let date: Int32?
    let minDate: Int32?
    let maxDate: Int32?
    let title: String
    let displayingDateSelection: Bool
    let displayingTimeSelection: Bool
    
    public let sectionId: ItemListSectionId
    let style: ItemListStyle
    
    let toggleDateSelection: (() -> Void)?
    let toggleTimeSelection: (() -> Void)?
    
    let updated: ((Int32) -> Void)?
    public let tag: ItemListItemTag?
    
    public init(
        presentationData: ItemListPresentationData,
        dateTimeFormat: PresentationDateTimeFormat,
        date: Int32?,
        minDate: Int32? = nil,
        maxDate: Int32? = nil,
        title: String,
        displayingDateSelection: Bool,
        displayingTimeSelection: Bool,
        sectionId: ItemListSectionId,
        style: ItemListStyle,
        toggleDateSelection: (() -> Void)?,
        toggleTimeSelection: (() -> Void)?,
        updated: ((Int32) -> Void)?,
        tag: ItemListItemTag? = nil
    ) {
        self.presentationData = presentationData
        self.dateTimeFormat = dateTimeFormat
        self.date = date
        self.minDate = minDate
        self.maxDate = maxDate
        self.title = title
        self.displayingDateSelection = displayingDateSelection
        self.displayingTimeSelection = displayingTimeSelection
        self.sectionId = sectionId
        self.style = style
        self.toggleDateSelection = toggleDateSelection
        self.toggleTimeSelection = toggleTimeSelection
        self.updated = updated
        self.tag = tag
    }
    
    public func nodeConfiguredForParams(async: @escaping (@escaping () -> Void) -> Void, params: ListViewItemLayoutParams, synchronousLoads: Bool, previousItem: ListViewItem?, nextItem: ListViewItem?, completion: @escaping (ListViewItemNode, @escaping () -> (Signal<Void, NoError>?, (ListViewItemApply) -> Void)) -> Void) {
        async {
            let node = ItemListDatePickerItemNode()
            let (layout, apply) = node.asyncLayout()(self, params, itemListNeighbors(item: self, topItem: previousItem as? ItemListItem, bottomItem: nextItem as? ItemListItem))
            
            node.contentSize = layout.contentSize
            node.insets = layout.insets
            
            Queue.mainQueue().async {
                completion(node, {
                    return (nil, { _ in apply(.None) })
                })
            }
        }
    }
    
    public func updateNode(async: @escaping (@escaping () -> Void) -> Void, node: @escaping () -> ListViewItemNode, params: ListViewItemLayoutParams, previousItem: ListViewItem?, nextItem: ListViewItem?, animation: ListViewItemUpdateAnimation, completion: @escaping (ListViewItemNodeLayout, @escaping (ListViewItemApply) -> Void) -> Void) {
        Queue.mainQueue().async {
            if let nodeValue = node() as? ItemListDatePickerItemNode {
                let makeLayout = nodeValue.asyncLayout()
                
                async {
                    let (layout, apply) = makeLayout(self, params, itemListNeighbors(item: self, topItem: previousItem as? ItemListItem, bottomItem: nextItem as? ItemListItem))
                    Queue.mainQueue().async {
                        completion(layout, { _ in
                            apply(animation)
                        })
                    }
                }
            }
        }
    }
    
    public var selectable: Bool = false
}

public class ItemListDatePickerItemNode: ListViewItemNode, ItemListItemNode {
    private let backgroundNode: ASDisplayNode
    private let topStripeNode: ASDisplayNode
    private let bottomStripeNode: ASDisplayNode
    private let maskNode: ASImageNode
    
    private let containerNode: ASDisplayNode
    
    private var datePickerNode: DatePickerNode?
    
    private var item: ItemListDatePickerItem?
    
    override public var canBeSelected: Bool {
        return false
    }
    
    public var tag: ItemListItemTag? {
        return self.item?.tag
    }
    
    public init() {
        self.backgroundNode = ASDisplayNode()
        self.backgroundNode.isLayerBacked = true
        self.backgroundNode.backgroundColor = .white
        
        self.maskNode = ASImageNode()
        self.maskNode.isUserInteractionEnabled = false
        
        self.topStripeNode = ASDisplayNode()
        self.topStripeNode.isLayerBacked = true
        
        self.bottomStripeNode = ASDisplayNode()
        self.bottomStripeNode.isLayerBacked = true
        
        self.containerNode = ASDisplayNode()
        self.containerNode.clipsToBounds = true
        
        super.init(layerBacked: false, dynamicBounce: false)
        
        self.addSubnode(self.containerNode)
                
        self.allowsGroupOpacity = true
    }
    
    public func asyncLayout() -> (_ item: ItemListDatePickerItem, _ params: ListViewItemLayoutParams, _ insets: ItemListNeighbors) -> (ListViewItemNodeLayout, (ListViewItemUpdateAnimation) -> Void) {
        let currentItem = self.item
        
        return { item, params, neighbors in
            var updatedTheme: PresentationTheme?
            if currentItem?.presentationData.theme !== item.presentationData.theme {
                updatedTheme = item.presentationData.theme
            }
            
            let contentSize: CGSize
            let insets: UIEdgeInsets
            let separatorHeight = UIScreenPixel
            let itemBackgroundColor: UIColor
            let itemSeparatorColor: UIColor
            
            let leftInset = 16.0 + params.leftInset
            
            let width = params.width - params.leftInset - params.rightInset
            let constrainedWidth = min(390.0, width)
            let cellSize = floor((constrainedWidth - 12.0 * 2.0) / 7.0)
            let pickerHeight = 122.0 + cellSize * 6.0
            let height: CGFloat
            if item.displayingDateSelection {
                height = pickerHeight
            } else if item.displayingTimeSelection {
                height = 260.0
            } else {
                height = 44.0
            }
            switch item.style {
            case .plain:
                itemBackgroundColor = item.presentationData.theme.list.plainBackgroundColor
                itemSeparatorColor = item.presentationData.theme.list.itemPlainSeparatorColor
                contentSize = CGSize(width: params.width, height: height)
                insets = itemListNeighborsPlainInsets(neighbors)
            case .blocks:
                itemBackgroundColor = item.presentationData.theme.list.itemBlocksBackgroundColor
                itemSeparatorColor = item.presentationData.theme.list.itemBlocksSeparatorColor
                contentSize = CGSize(width: params.width, height: height)
                insets = itemListNeighborsGroupedInsets(neighbors, params)
            }
            
            return (ListViewItemNodeLayout(contentSize: contentSize, insets: insets), { [weak self] animation in
                if let strongSelf = self {
                    strongSelf.item = item
                    
                    let transition = animation.transition

                    if let _ = updatedTheme {
                        strongSelf.topStripeNode.backgroundColor = itemSeparatorColor
                        strongSelf.bottomStripeNode.backgroundColor = itemSeparatorColor
                        strongSelf.backgroundNode.backgroundColor = itemBackgroundColor
                        
                        strongSelf.datePickerNode?.updateTheme(DatePickerTheme(theme: item.presentationData.theme))
                    }
                                        
                    switch item.style {
                    case .plain:
                        if strongSelf.backgroundNode.supernode != nil {
                            strongSelf.backgroundNode.removeFromSupernode()
                        }
                        if strongSelf.topStripeNode.supernode != nil {
                            strongSelf.topStripeNode.removeFromSupernode()
                        }
                        if strongSelf.bottomStripeNode.supernode == nil {
                            strongSelf.insertSubnode(strongSelf.bottomStripeNode, at: 0)
                        }
                        if strongSelf.maskNode.supernode != nil {
                            strongSelf.maskNode.removeFromSupernode()
                        }
                        strongSelf.bottomStripeNode.frame = CGRect(origin: CGPoint(x: leftInset, y: contentSize.height - separatorHeight), size: CGSize(width: params.width - leftInset, height: separatorHeight))
                    case .blocks:
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
                        
                        transition.updateFrame(node: strongSelf.backgroundNode, frame: CGRect(origin: CGPoint(x: 0.0, y: -min(insets.top, separatorHeight)), size: CGSize(width: params.width, height: contentSize.height + min(insets.top, separatorHeight) + min(insets.bottom, separatorHeight))))
                        transition.updateFrame(node: strongSelf.maskNode, frame: strongSelf.backgroundNode.frame.insetBy(dx: params.leftInset, dy: 0.0))
                        transition.updateFrame(node: strongSelf.topStripeNode, frame: CGRect(origin: CGPoint(x: 0.0, y: -min(insets.top, separatorHeight)), size: CGSize(width: params.width, height: separatorHeight)))
                        transition.updateFrame(node: strongSelf.bottomStripeNode, frame: CGRect(origin: CGPoint(x: bottomStripeInset, y: contentSize.height - separatorHeight), size: CGSize(width: params.width - bottomStripeInset, height: separatorHeight)))
                    }
                    
                    let datePickerNode: DatePickerNode
                    if let current = strongSelf.datePickerNode {
                        datePickerNode = current
                    } else {
                        datePickerNode = DatePickerNode(theme: DatePickerTheme(theme: item.presentationData.theme), strings: item.presentationData.strings, dateTimeFormat: item.dateTimeFormat, title: item.title)
                        strongSelf.containerNode.addSubnode(datePickerNode)
                        strongSelf.datePickerNode = datePickerNode
                    }
                    datePickerNode.valueUpdated = { [weak self] date in
                        if let self {
                            self.item?.updated?(Int32(date.timeIntervalSince1970))
                        }
                    }
                    datePickerNode.toggleDateSelection = { [weak self] in
                        if let self {
                            self.item?.toggleDateSelection?()
                        }
                    }
                    datePickerNode.toggleTimeSelection = { [weak self] in
                        if let self {
                            self.item?.toggleTimeSelection?()
                        }
                    }
                    
                    datePickerNode.displayDateSelection = item.displayingDateSelection
                    datePickerNode.displayTimeSelection = item.displayingTimeSelection
                
                    if let minDate = item.minDate {
                        datePickerNode.minimumDate = Date(timeIntervalSince1970: TimeInterval(minDate))
                    } else {
                        datePickerNode.minimumDate = Date()
                    }
                    if let maxDate = item.maxDate {
                        datePickerNode.maximumDate = Date(timeIntervalSince1970: TimeInterval(maxDate))
                    }
                    
                    datePickerNode.date = item.date.flatMap { Date(timeIntervalSince1970: TimeInterval($0)) }
                   
                    let datePickerSize = CGSize(width: width, height: pickerHeight)
                    datePickerNode.frame = CGRect(origin: CGPoint(x: floorToScreenPixels((params.width - datePickerSize.width) / 2.0), y: 0.0), size: datePickerSize)
                    datePickerNode.updateLayout(size: datePickerSize, transition: .immediate)
                    
                    transition.updateFrame(node: strongSelf.containerNode, frame: CGRect(origin: .zero, size: CGSize(width: params.width, height: contentSize.height)))
                    
                }
            })
        }
    }
    
    override public func animateInsertion(_ currentTimestamp: Double, duration: Double, options: ListViewItemAnimationOptions) {
        self.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.4)
    }
    
    override public func animateAdded(_ currentTimestamp: Double, duration: Double) {
        self.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.2)
    }
    
    override public func animateRemoved(_ currentTimestamp: Double, duration: Double) {
        self.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.15, removeOnCompletion: false)
    }
}

