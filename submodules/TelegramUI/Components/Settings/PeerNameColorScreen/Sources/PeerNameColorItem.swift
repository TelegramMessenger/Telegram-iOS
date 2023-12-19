import Foundation
import UIKit
import Display
import AsyncDisplayKit
import SwiftSignalKit
import TelegramCore
import TelegramPresentationData
import TelegramUIPreferences
import MergeLists
import ItemListUI
import PresentationDataUtils
import AccountContext
import ListItemComponentAdaptor

private enum PeerNameColorEntryId: Hashable {
    case color(Int32)
}

private enum PeerNameColorEntry: Comparable, Identifiable {
    case color(Int, PeerNameColor, PeerNameColors.Colors, Bool, Bool)
    
    var stableId: PeerNameColorEntryId {
        switch self {
            case let .color(_, color, _, _, _):
                return .color(color.rawValue)
        }
    }
    
    static func ==(lhs: PeerNameColorEntry, rhs: PeerNameColorEntry) -> Bool {
        switch lhs {
            case let .color(lhsIndex, lhsColor, lhsAccentColor, lhsIsDark, lhsSelected):
                if case let .color(rhsIndex, rhsColor, rhsAccentColor, rhsIsDark, rhsSelected) = rhs, lhsIndex == rhsIndex, lhsColor == rhsColor, lhsAccentColor == rhsAccentColor, lhsIsDark == rhsIsDark, lhsSelected == rhsSelected {
                    return true
                } else {
                    return false
                }
        }
    }
    
    static func <(lhs: PeerNameColorEntry, rhs: PeerNameColorEntry) -> Bool {
        switch lhs {
            case let .color(lhsIndex, _, _, _, _):
                switch rhs {
                    case let .color(rhsIndex, _, _, _, _):
                        return lhsIndex < rhsIndex
            }
        }
    }
    
    func item(action: @escaping (PeerNameColor) -> Void) -> ListViewItem {
        switch self {
            case let .color(_, index, colors, isDark, selected):
                return PeerNameColorIconItem(index: index, colors: colors, isDark: isDark, selected: selected, action: action)
        }
    }
}


private class PeerNameColorIconItem: ListViewItem {
    let index: PeerNameColor
    let colors: PeerNameColors.Colors
    let isDark: Bool
    let selected: Bool
    let action: (PeerNameColor) -> Void
    
    public init(index: PeerNameColor, colors: PeerNameColors.Colors, isDark: Bool, selected: Bool, action: @escaping (PeerNameColor) -> Void) {
        self.index = index
        self.colors = colors
        self.isDark = isDark
        self.selected = selected
        self.action = action
    }
    
    public func nodeConfiguredForParams(async: @escaping (@escaping () -> Void) -> Void, params: ListViewItemLayoutParams, synchronousLoads: Bool, previousItem: ListViewItem?, nextItem: ListViewItem?, completion: @escaping (ListViewItemNode, @escaping () -> (Signal<Void, NoError>?, (ListViewItemApply) -> Void)) -> Void) {
        async {
            let node = PeerNameColorIconItemNode()
            let (nodeLayout, apply) = node.asyncLayout()(self, params)
            node.insets = nodeLayout.insets
            node.contentSize = nodeLayout.contentSize
            
            Queue.mainQueue().async {
                completion(node, {
                    return (nil, { _ in
                        apply(false)
                    })
                })
            }
        }
    }
    
    public func updateNode(async: @escaping (@escaping () -> Void) -> Void, node: @escaping () -> ListViewItemNode, params: ListViewItemLayoutParams, previousItem: ListViewItem?, nextItem: ListViewItem?, animation: ListViewItemUpdateAnimation, completion: @escaping (ListViewItemNodeLayout, @escaping (ListViewItemApply) -> Void) -> Void) {
        Queue.mainQueue().async {
            assert(node() is PeerNameColorIconItemNode)
            if let nodeValue = node() as? PeerNameColorIconItemNode {
                let layout = nodeValue.asyncLayout()
                async {
                    let (nodeLayout, apply) = layout(self, params)
                    Queue.mainQueue().async {
                        completion(nodeLayout, { _ in
                            let animated: Bool
                            if case .Crossfade = animation {
                                animated = true
                            } else {
                                animated = false
                            }
                            apply(animated)
                        })
                    }
                }
            }
        }
    }
    
    public var selectable = true
    public func selected(listView: ListView) {
        self.action(self.index)
    }
}

private func generateRingImage(nameColor: PeerNameColors.Colors) -> UIImage? {
    return generateImage(CGSize(width: 40.0, height: 40.0), rotatedContext: { size, context in
        let bounds = CGRect(origin: CGPoint(), size: size)
        context.clear(bounds)
        
        context.setStrokeColor(nameColor.main.cgColor)
        context.setLineWidth(2.0)
        context.strokeEllipse(in: bounds.insetBy(dx: 1.0, dy: 1.0))
    })
}

public func generatePeerNameColorImage(nameColor: PeerNameColors.Colors, isDark: Bool, bounds: CGSize = CGSize(width: 40.0, height: 40.0), size: CGSize = CGSize(width: 40.0, height: 40.0)) -> UIImage? {
    return generateImage(bounds, rotatedContext: { contextSize, context in
        let bounds = CGRect(origin: CGPoint(), size: contextSize)
        context.clear(bounds)
        
        let circleBounds = CGRect(origin: CGPoint(x: floorToScreenPixels((bounds.width - size.width) / 2.0), y: floorToScreenPixels((bounds.height - size.height) / 2.0)), size: size)
        context.addEllipse(in: circleBounds)
        context.clip()
        
        if let secondColor = nameColor.secondary {
            var firstColor = nameColor.main
            var secondColor = secondColor
            if isDark, nameColor.tertiary == nil {
                firstColor = secondColor
                secondColor = nameColor.main
            }
            
            context.setFillColor(secondColor.cgColor)
            context.fill(circleBounds)
            
            if let thirdColor = nameColor.tertiary {
                context.move(to: CGPoint(x: contextSize.width, y: 0.0))
                context.addLine(to: CGPoint(x: contextSize.width, y: contextSize.height))
                context.addLine(to: CGPoint(x: 0.0, y: contextSize.height))
                context.closePath()
                context.setFillColor(firstColor.cgColor)
                context.fillPath()
                
                context.setFillColor(thirdColor.cgColor)
                context.translateBy(x: contextSize.width / 2.0, y: contextSize.height / 2.0)
                context.rotate(by: .pi / 4.0)
                
                let rectSide = size.width / 40.0 * 18.0
                let rectCornerRadius = round(size.width / 40.0 * 4.0)
                let path = UIBezierPath(roundedRect: CGRect(origin: CGPoint(x: -rectSide / 2.0, y: -rectSide / 2.0), size: CGSize(width: rectSide, height: rectSide)), cornerRadius: rectCornerRadius)
                context.addPath(path.cgPath)
                context.fillPath()
            } else {
                context.move(to: .zero)
                context.addLine(to: CGPoint(x: contextSize.width, y: 0.0))
                context.addLine(to: CGPoint(x: 0.0, y: contextSize.height))
                context.closePath()
                context.setFillColor(firstColor.cgColor)
                context.fillPath()
            }
        } else {
            context.setFillColor(nameColor.main.cgColor)
            context.fill(circleBounds)
        }
    })
}

public func generateSettingsMenuPeerColorsLabelIcon(colors: [PeerNameColors.Colors]) -> UIImage {
    let iconWidth: CGFloat = 24.0
    let iconSpacing: CGFloat = 18.0
    let borderWidth: CGFloat = 2.0
    
    if colors.isEmpty {
        return generateSingleColorImage(size: CGSize(width: iconWidth, height: iconWidth), color: .clear)!
    }

    return generateImage(CGSize(width: CGFloat(max(0, colors.count - 1)) * iconSpacing + CGFloat(colors.count == 0 ? 0 : 1) * iconWidth, height: 24.0), rotatedContext: { size, context in
        context.clear(CGRect(origin: CGPoint(), size: size))
        
        for i in 0 ..< colors.count {
            let iconFrame = CGRect(origin: CGPoint(x: CGFloat(i) * iconSpacing, y: 0.0), size: CGSize(width: iconWidth, height: iconWidth))
            context.setBlendMode(.copy)
            context.setFillColor(UIColor.clear.cgColor)
            context.fillEllipse(in: iconFrame.insetBy(dx: -borderWidth, dy: -borderWidth))
            context.setBlendMode(.normal)
            
            if let image = generatePeerNameColorImage(nameColor: colors[i], isDark: false, bounds: iconFrame.size, size: iconFrame.size)?.cgImage {
                context.saveGState()
                context.translateBy(x: iconFrame.midX, y: iconFrame.midY)
                context.scaleBy(x: 1.0, y: -1.0)
                context.translateBy(x: -iconFrame.midX, y: -iconFrame.midY)
                context.draw(image, in: iconFrame)
                context.restoreGState()
            }
        }
    })!
}

private final class PeerNameColorIconItemNode : ListViewItemNode {
    private let containerNode: ContextControllerSourceNode
    private let fillNode: ASImageNode
    private let ringNode: ASImageNode
    
    var item: PeerNameColorIconItem?

    init() {
        self.containerNode = ContextControllerSourceNode()

        self.fillNode = ASImageNode()
        self.fillNode.displaysAsynchronously = false
        self.fillNode.displayWithoutProcessing = true
        
        self.ringNode = ASImageNode()
        self.ringNode.displaysAsynchronously = false
        self.ringNode.displayWithoutProcessing = true
    
        super.init(layerBacked: false, dynamicBounce: false, rotated: false, seeThrough: false)

        self.addSubnode(self.containerNode)
        self.containerNode.addSubnode(self.ringNode)
        self.containerNode.addSubnode(self.fillNode)
    }
    
    override func didLoad() {
        super.didLoad()
        
        self.layer.sublayerTransform = CATransform3DMakeRotation(CGFloat.pi / 2.0, 0.0, 0.0, 1.0)
    }
    
    func setSelected(_ selected: Bool, animated: Bool = false) {
        let transition: ContainedViewLayoutTransition = animated ? .animated(duration: 0.3, curve: .easeInOut) : .immediate
        if selected {
            transition.updateTransformScale(node: self.fillNode, scale: 0.8)
            transition.updateTransformScale(node: self.ringNode, scale: 1.0)
        } else {
            transition.updateTransformScale(node: self.fillNode, scale: 1.0)
            transition.updateTransformScale(node: self.ringNode, scale: 0.99)
        }
    }
    
    func asyncLayout() -> (PeerNameColorIconItem, ListViewItemLayoutParams) -> (ListViewItemNodeLayout, (Bool) -> Void) {
        let currentItem = self.item

        return { [weak self] item, params in
            var updatedAccentColor = false
            var updatedSelected = false
            
            if currentItem == nil || currentItem?.colors != item.colors {
                updatedAccentColor = true
            }
            if currentItem?.selected != item.selected {
                updatedSelected = true
            }
            
            let itemLayout = ListViewItemNodeLayout(contentSize: CGSize(width: 60.0, height: 56.0), insets: UIEdgeInsets())
            return (itemLayout, { animated in
                if let strongSelf = self {
                    strongSelf.item = item
                    
                    if updatedAccentColor {
                        strongSelf.fillNode.image = generatePeerNameColorImage(nameColor: item.colors, isDark: item.isDark)
                        strongSelf.ringNode.image = generateRingImage(nameColor: item.colors)
                    }
                    
                    let center = CGPoint(x: 30.0, y: 28.0)
                    let bounds = CGRect(origin: CGPoint(x: 0.0, y: 0.0), size: CGSize(width: 40.0, height: 40.0))
                    strongSelf.containerNode.frame = CGRect(origin: CGPoint(), size: itemLayout.contentSize)
                    
                    strongSelf.fillNode.position = center
                    strongSelf.ringNode.position = center
                    
                    strongSelf.fillNode.bounds = bounds
                    strongSelf.ringNode.bounds = bounds
                    
                    if updatedSelected {
                        strongSelf.setSelected(item.selected, animated: !updatedAccentColor && currentItem != nil)
                    }
                }
            })
        }
    }
    
    override func animateInsertion(_ currentTimestamp: Double, duration: Double, short: Bool) {
        super.animateInsertion(currentTimestamp, duration: duration, short: short)
        
        self.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.2)
    }
    
    override func animateRemoved(_ currentTimestamp: Double, duration: Double) {
        super.animateRemoved(currentTimestamp, duration: duration)
        
        self.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.2, removeOnCompletion: false)
    }
    
    override func animateAdded(_ currentTimestamp: Double, duration: Double) {
        super.animateAdded(currentTimestamp, duration: duration)
        
        self.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.2)
    }
}

final class PeerNameColorItem: ListViewItem, ItemListItem, ListItemComponentAdaptor.ItemGenerator {
    var sectionId: ItemListSectionId
    
    let theme: PresentationTheme
    let colors: PeerNameColors
    let isProfile: Bool
    let currentColor: PeerNameColor?
    let updated: (PeerNameColor) -> Void
    let tag: ItemListItemTag?
    
    init(theme: PresentationTheme, colors: PeerNameColors, isProfile: Bool, currentColor: PeerNameColor?, updated: @escaping (PeerNameColor) -> Void, tag: ItemListItemTag? = nil, sectionId: ItemListSectionId) {
        self.theme = theme
        self.colors = colors
        self.isProfile = isProfile
        self.currentColor = currentColor
        self.updated = updated
        self.tag = tag
        self.sectionId = sectionId
    }
    
    func nodeConfiguredForParams(async: @escaping (@escaping () -> Void) -> Void, params: ListViewItemLayoutParams, synchronousLoads: Bool, previousItem: ListViewItem?, nextItem: ListViewItem?, completion: @escaping (ListViewItemNode, @escaping () -> (Signal<Void, NoError>?, (ListViewItemApply) -> Void)) -> Void) {
        async {
            let node = PeerNameColorItemNode()
            let (layout, apply) = node.asyncLayout()(self, params, itemListNeighbors(item: self, topItem: previousItem as? ItemListItem, bottomItem: nextItem as? ItemListItem))
            
            node.contentSize = layout.contentSize
            node.insets = layout.insets
            
            Queue.mainQueue().async {
                completion(node, {
                    return (nil, { _ in apply() })
                })
            }
        }
    }
    
    func updateNode(async: @escaping (@escaping () -> Void) -> Void, node: @escaping () -> ListViewItemNode, params: ListViewItemLayoutParams, previousItem: ListViewItem?, nextItem: ListViewItem?, animation: ListViewItemUpdateAnimation, completion: @escaping (ListViewItemNodeLayout, @escaping (ListViewItemApply) -> Void) -> Void) {
        Queue.mainQueue().async {
            if let nodeValue = node() as? PeerNameColorItemNode {
                let makeLayout = nodeValue.asyncLayout()
                
                async {
                    let (layout, apply) = makeLayout(self, params, itemListNeighbors(item: self, topItem: previousItem as? ItemListItem, bottomItem: nextItem as? ItemListItem))
                    Queue.mainQueue().async {
                        completion(layout, { _ in
                            apply()
                        })
                    }
                }
            }
        }
    }
    
    public func item() -> ListViewItem {
        return self
    }
    
    public static func ==(lhs: PeerNameColorItem, rhs: PeerNameColorItem) -> Bool {
        if lhs.theme !== rhs.theme {
            return false
        }
        if lhs.colors != rhs.colors {
            return false
        }
        if lhs.isProfile != rhs.isProfile {
            return false
        }
        if lhs.currentColor != rhs.currentColor {
            return false
        }
        
        return true
    }
}

private struct PeerNameColorItemNodeTransition {
    let deletions: [ListViewDeleteItem]
    let insertions: [ListViewInsertItem]
    let updates: [ListViewUpdateItem]
    let updatePosition: Bool
}

private func preparedTransition(action: @escaping (PeerNameColor) -> Void, from fromEntries: [PeerNameColorEntry], to toEntries: [PeerNameColorEntry], updatePosition: Bool) -> PeerNameColorItemNodeTransition {
    let (deleteIndices, indicesAndItems, updateIndices) = mergeListsStableWithUpdates(leftList: fromEntries, rightList: toEntries)
    
    let deletions = deleteIndices.map { ListViewDeleteItem(index: $0, directionHint: nil) }
    let insertions = indicesAndItems.map { ListViewInsertItem(index: $0.0, previousIndex: $0.2, item: $0.1.item(action: action), directionHint: .Down) }
    let updates = updateIndices.map { ListViewUpdateItem(index: $0.0, previousIndex: $0.2, item: $0.1.item(action: action), directionHint: nil) }
    
    return PeerNameColorItemNodeTransition(deletions: deletions, insertions: insertions, updates: updates, updatePosition: updatePosition)
}

private func ensureColorVisible(listNode: ListView, color: PeerNameColor, animated: Bool) -> Bool {
    var resultNode: PeerNameColorIconItemNode?
    listNode.forEachItemNode { node in
        if resultNode == nil, let node = node as? PeerNameColorIconItemNode {
            if node.item?.index == color {
                resultNode = node
            }
        }
    }
    if let resultNode = resultNode {
        listNode.ensureItemNodeVisible(resultNode, animated: animated, overflow: 76.0)
        return true
    } else {
        return false
    }
}

final class PeerNameColorItemNode: ListViewItemNode, ItemListItemNode {
    private let containerNode: ASDisplayNode
    private let backgroundNode: ASDisplayNode
    private let topStripeNode: ASDisplayNode
    private let bottomStripeNode: ASDisplayNode
    private let maskNode: ASImageNode

    private let listNode: ListView
    private var entries: [PeerNameColorEntry]?
    private var enqueuedTransitions: [PeerNameColorItemNodeTransition] = []
    private var initialized = false
    
    private var item: PeerNameColorItem?
    private var layoutParams: ListViewItemLayoutParams?
    
    private var tapping = false
    
    var tag: ItemListItemTag? {
        return self.item?.tag
    }
        
    init() {
        self.containerNode = ASDisplayNode()
        
        self.backgroundNode = ASDisplayNode()
        self.backgroundNode.isLayerBacked = true
        
        self.topStripeNode = ASDisplayNode()
        self.topStripeNode.isLayerBacked = true
        
        self.bottomStripeNode = ASDisplayNode()
        self.bottomStripeNode.isLayerBacked = true
        
        self.maskNode = ASImageNode()
        
        self.listNode = ListView()
        self.listNode.transform = CATransform3DMakeRotation(-CGFloat.pi / 2.0, 0.0, 0.0, 1.0)
        
        super.init(layerBacked: false, dynamicBounce: false)
        
        self.addSubnode(self.containerNode)
        self.addSubnode(self.listNode)
    }
    
    override func didLoad() {
        super.didLoad()
        self.listNode.view.disablesInteractiveTransitionGestureRecognizer = true
    }
    
    private func enqueueTransition(_ transition: PeerNameColorItemNodeTransition) {
        self.enqueuedTransitions.append(transition)
        
        if let _ = self.item {
            while !self.enqueuedTransitions.isEmpty {
                self.dequeueTransition()
            }
        }
    }
    
    private func dequeueTransition() {
        guard let item = self.item, let transition = self.enqueuedTransitions.first else {
            return
        }
        self.enqueuedTransitions.remove(at: 0)
        
        let options = ListViewDeleteAndInsertOptions()
        var scrollToItem: ListViewScrollToItem?
        if !self.initialized || transition.updatePosition || !self.tapping {
            let displayOrder: [Int32]
            if item.isProfile {
                displayOrder = item.colors.profileDisplayOrder
            } else {
                displayOrder = item.colors.displayOrder
            }
            if let index = displayOrder.firstIndex(where: { $0 == item.currentColor?.rawValue }) {
                scrollToItem = ListViewScrollToItem(index: index, position: .bottom(-70.0), animated: false, curve: .Default(duration: 0.0), directionHint: .Down)
                self.initialized = true
            }
        }

        self.listNode.transaction(deleteIndices: transition.deletions, insertIndicesAndItems: transition.insertions, updateIndicesAndItems: transition.updates, options: options, scrollToItem: scrollToItem, updateSizeAndInsets: nil, updateOpaqueState: nil, completion: { _ in
        })
    }
    
    func asyncLayout() -> (_ item: PeerNameColorItem, _ params: ListViewItemLayoutParams, _ neighbors: ItemListNeighbors) -> (ListViewItemNodeLayout, () -> Void) {
        let currentItem = self.item
        
        return { item, params, neighbors in
            var themeUpdated = false
            if currentItem?.theme !== item.theme {
                themeUpdated = true
            }
            
            let contentSize: CGSize
            let insets: UIEdgeInsets
            let separatorHeight = UIScreenPixel
            
            contentSize = CGSize(width: params.width, height: 60.0)
            insets = itemListNeighborsGroupedInsets(neighbors, params)
            
            let layout = ListViewItemNodeLayout(contentSize: contentSize, insets: insets)
            let layoutSize = layout.size
            
            return (layout, { [weak self] in
                if let strongSelf = self {
                    strongSelf.item = item
                    strongSelf.layoutParams = params
                    
                    if themeUpdated {
                        strongSelf.backgroundNode.backgroundColor = item.theme.list.itemBlocksBackgroundColor
                        strongSelf.topStripeNode.backgroundColor = item.theme.list.itemBlocksSeparatorColor
                        strongSelf.bottomStripeNode.backgroundColor = item.theme.list.itemBlocksSeparatorColor
                    }
                    
                    if strongSelf.backgroundNode.supernode == nil {
                        strongSelf.containerNode.insertSubnode(strongSelf.backgroundNode, at: 0)
                    }
                    if strongSelf.topStripeNode.supernode == nil {
                        strongSelf.containerNode.insertSubnode(strongSelf.topStripeNode, at: 1)
                    }
                    if strongSelf.bottomStripeNode.supernode == nil {
                        strongSelf.containerNode.insertSubnode(strongSelf.bottomStripeNode, at: 2)
                    }
                    if strongSelf.maskNode.supernode == nil {
                        strongSelf.containerNode.insertSubnode(strongSelf.maskNode, at: 3)
                    }
                    
                    if params.isStandalone {
                        strongSelf.backgroundNode.isHidden = true
                        strongSelf.topStripeNode.isHidden = true
                        strongSelf.bottomStripeNode.isHidden = true
                        strongSelf.maskNode.isHidden = true
                    } else {
                        let hasCorners = itemListHasRoundedBlockLayout(params)
                        var hasTopCorners = false
                        var hasBottomCorners = false
                        if item.currentColor != nil {
                            switch neighbors.top {
                            case .sameSection(false):
                                strongSelf.topStripeNode.isHidden = true
                            default:
                                hasTopCorners = true
                                strongSelf.topStripeNode.isHidden = hasCorners
                            }
                        } else {
                            strongSelf.topStripeNode.isHidden = true
                            hasTopCorners = true
                        }
                        let bottomStripeInset: CGFloat
                        let bottomStripeOffset: CGFloat
                        switch neighbors.bottom {
                        case .sameSection(false):
                            bottomStripeInset = params.leftInset + 16.0
                            bottomStripeOffset = -separatorHeight
                            strongSelf.bottomStripeNode.isHidden = false
                        default:
                            bottomStripeInset = 0.0
                            bottomStripeOffset = 0.0
                            hasBottomCorners = true
                            strongSelf.bottomStripeNode.isHidden = hasCorners
                        }
                        strongSelf.maskNode.image = hasCorners ? PresentationResourcesItemList.cornersImage(item.theme, top: hasTopCorners, bottom: hasBottomCorners) : nil
                        
                        strongSelf.bottomStripeNode.frame = CGRect(origin: CGPoint(x: bottomStripeInset, y: contentSize.height + bottomStripeOffset), size: CGSize(width: layoutSize.width - bottomStripeInset, height: separatorHeight))
                    }
                    
                    strongSelf.containerNode.frame = CGRect(x: 0.0, y: 0.0, width: contentSize.width, height: contentSize.height)
                    
                    strongSelf.backgroundNode.frame = CGRect(origin: CGPoint(x: 0.0, y: -min(insets.top, separatorHeight)), size: CGSize(width: params.width, height: contentSize.height + min(insets.top, separatorHeight) + min(insets.bottom, separatorHeight)))
                    strongSelf.maskNode.frame = strongSelf.backgroundNode.frame.insetBy(dx: params.leftInset, dy: 0.0)
                    strongSelf.topStripeNode.frame = CGRect(origin: CGPoint(x: 0.0, y: -min(insets.top, separatorHeight)), size: CGSize(width: layoutSize.width, height: separatorHeight))
                    
                    var listInsets = UIEdgeInsets()
                    listInsets.top += params.leftInset + 8.0
                    listInsets.bottom += params.rightInset + 8.0
                    
                    strongSelf.listNode.bounds = CGRect(x: 0.0, y: 0.0, width: contentSize.height, height: contentSize.width)
                    strongSelf.listNode.position = CGPoint(x: contentSize.width / 2.0, y: contentSize.height / 2.0)
                    strongSelf.listNode.transaction(deleteIndices: [], insertIndicesAndItems: [], updateIndicesAndItems: [], options: [.Synchronous], scrollToItem: nil, updateSizeAndInsets: ListViewUpdateSizeAndInsets(size: CGSize(width: contentSize.height, height: contentSize.width), insets: listInsets, duration: 0.0, curve: .Default(duration: nil)), stationaryItemRange: nil, updateOpaqueState: nil, completion: { _ in })
                    
                    var entries: [PeerNameColorEntry] = []
                    
                    let displayOrder: [Int32]
                    if item.isProfile {
                        displayOrder = item.colors.profileDisplayOrder
                    } else {
                        displayOrder = item.colors.displayOrder
                    }
                    var i: Int = 0
                    for index in displayOrder {
                        let color = PeerNameColor(rawValue: index)
                        let colors: PeerNameColors.Colors
                        if item.isProfile {
                            colors = item.colors.getProfile(color, dark: item.theme.overallDarkAppearance, subject: .palette)
                        } else {
                            colors = item.colors.get(color, dark: item.theme.overallDarkAppearance)
                        }
                        entries.append(.color(i, color, colors, item.theme.overallDarkAppearance, color == item.currentColor))
                        
                        i += 1
                    }
                    
                    let action: (PeerNameColor) -> Void = { [weak self] color in
                        guard let self else {
                            return
                        }
                        self.tapping = true
                        item.updated(color)
                        Queue.mainQueue().after(0.4) {
                            self.tapping = false
                        }
                        let _ = ensureColorVisible(listNode: self.listNode, color: color, animated: true)
                    }
                 
                    let previousEntries = strongSelf.entries ?? []
                    let updatePosition = currentItem != nil && previousEntries.count != entries.count
                    let transition = preparedTransition(action: action, from: previousEntries, to: entries, updatePosition: updatePosition)
                    strongSelf.enqueueTransition(transition)
                    
                    strongSelf.entries = entries
                }
            })
        }
    }
    
    override func animateInsertion(_ currentTimestamp: Double, duration: Double, short: Bool) {
        self.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.4)
    }
    
    override func animateRemoved(_ currentTimestamp: Double, duration: Double) {
        self.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.15, removeOnCompletion: false)
    }
}
