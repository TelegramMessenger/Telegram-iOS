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

private class PeerNameColorIconItem {
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
}

private func generateRingImage(nameColor: PeerNameColors.Colors, size: CGSize = CGSize(width: 40.0, height: 40.0)) -> UIImage? {
    return generateImage(size, rotatedContext: { size, context in
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

private final class PeerNameColorIconItemNode : ASDisplayNode {
    private let containerNode: ContextControllerSourceNode
    private let fillNode: ASImageNode
    private let ringNode: ASImageNode
    
    var item: PeerNameColorIconItem?

    override init() {
        self.containerNode = ContextControllerSourceNode()

        self.fillNode = ASImageNode()
        self.fillNode.displaysAsynchronously = false
        self.fillNode.displayWithoutProcessing = true
        
        self.ringNode = ASImageNode()
        self.ringNode.displaysAsynchronously = false
        self.ringNode.displayWithoutProcessing = true
    
        super.init()

        self.addSubnode(self.containerNode)
        self.containerNode.addSubnode(self.ringNode)
        self.containerNode.addSubnode(self.fillNode)
    }
    
    override func didLoad() {
        super.didLoad()
        
        self.view.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(self.tapped)))
    }

    @objc private func tapped() {
        guard let item = self.item else {
            return
        }
        item.action(item.index)
    }
    
    func setSelected(_ selected: Bool, animated: Bool = false) {
        let transition: ContainedViewLayoutTransition = animated ? .animated(duration: 0.3, curve: .easeInOut) : .immediate
        if selected {
            transition.updateTransformScale(node: self.fillNode, scale: 0.75)
            transition.updateTransformScale(node: self.ringNode, scale: 1.0)
        } else {
            transition.updateTransformScale(node: self.fillNode, scale: 1.0)
            transition.updateTransformScale(node: self.ringNode, scale: 0.99)
        }
    }
    
    func updateItem(_ item: PeerNameColorIconItem, size: CGSize) {
        let currentItem = self.item
        
        var updatedAccentColor = false
        var updatedSelected = false
        
        if currentItem == nil || currentItem?.colors != item.colors {
            updatedAccentColor = true
        }
        if currentItem?.selected != item.selected {
            updatedSelected = true
        }
        
        self.item = item
        
        if updatedAccentColor {
            self.fillNode.image = generatePeerNameColorImage(nameColor: item.colors, isDark: item.isDark, bounds: size, size: size)
            self.ringNode.image = generateRingImage(nameColor: item.colors, size: size)
        }
        
        let center = CGPoint(x: size.width / 2.0, y: size.height / 2.0)
        let bounds = CGRect(origin: CGPoint(x: 0.0, y: 0.0), size: size)
        self.containerNode.frame = CGRect(origin: CGPoint(), size: bounds.size)
        
        self.fillNode.position = center
        self.ringNode.position = center
        
        self.fillNode.bounds = bounds
        self.ringNode.bounds = bounds
        
        if updatedSelected {
            self.setSelected(item.selected, animated: !updatedAccentColor && currentItem != nil)
        }
    }
}

public final class PeerNameColorItem: ListViewItem, ItemListItem, ListItemComponentAdaptor.ItemGenerator {
    public var sectionId: ItemListSectionId
    
    public let theme: PresentationTheme
    public let colors: PeerNameColors
    public let isProfile: Bool
    public let currentColor: PeerNameColor?
    public let updated: (PeerNameColor) -> Void
    public let tag: ItemListItemTag?
    
    public init(theme: PresentationTheme, colors: PeerNameColors, isProfile: Bool, currentColor: PeerNameColor?, updated: @escaping (PeerNameColor) -> Void, tag: ItemListItemTag? = nil, sectionId: ItemListSectionId) {
        self.theme = theme
        self.colors = colors
        self.isProfile = isProfile
        self.currentColor = currentColor
        self.updated = updated
        self.tag = tag
        self.sectionId = sectionId
    }
    
    public func nodeConfiguredForParams(async: @escaping (@escaping () -> Void) -> Void, params: ListViewItemLayoutParams, synchronousLoads: Bool, previousItem: ListViewItem?, nextItem: ListViewItem?, completion: @escaping (ListViewItemNode, @escaping () -> (Signal<Void, NoError>?, (ListViewItemApply) -> Void)) -> Void) {
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
    
    public func updateNode(async: @escaping (@escaping () -> Void) -> Void, node: @escaping () -> ListViewItemNode, params: ListViewItemLayoutParams, previousItem: ListViewItem?, nextItem: ListViewItem?, animation: ListViewItemUpdateAnimation, completion: @escaping (ListViewItemNodeLayout, @escaping (ListViewItemApply) -> Void) -> Void) {
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

public final class PeerNameColorItemNode: ListViewItemNode, ItemListItemNode {
    private let containerNode: ASDisplayNode
    private let backgroundNode: ASDisplayNode
    private let topStripeNode: ASDisplayNode
    private let bottomStripeNode: ASDisplayNode
    private let maskNode: ASImageNode

    private var items: [PeerNameColorIconItem] = []
    private var itemNodes: [Int32 : PeerNameColorIconItemNode] = [:]
    private var initialized = false
    
    private var item: PeerNameColorItem?
    private var layoutParams: ListViewItemLayoutParams?
        
    public var tag: ItemListItemTag? {
        return self.item?.tag
    }
        
    public init() {
        self.containerNode = ASDisplayNode()
        
        self.backgroundNode = ASDisplayNode()
        self.backgroundNode.isLayerBacked = true
        
        self.topStripeNode = ASDisplayNode()
        self.topStripeNode.isLayerBacked = true
        
        self.bottomStripeNode = ASDisplayNode()
        self.bottomStripeNode.isLayerBacked = true
        
        self.maskNode = ASImageNode()
        
        super.init(layerBacked: false, dynamicBounce: false)
        
        self.addSubnode(self.containerNode)
    }
    
    public func asyncLayout() -> (_ item: PeerNameColorItem, _ params: ListViewItemLayoutParams, _ neighbors: ItemListNeighbors) -> (ListViewItemNodeLayout, () -> Void) {
        let currentItem = self.item
        
        return { item, params, neighbors in
            var themeUpdated = false
            if currentItem?.theme !== item.theme {
                themeUpdated = true
            }
            
            let contentSize: CGSize
            let insets: UIEdgeInsets
            let separatorHeight = UIScreenPixel
            
            let itemsPerRow: Int
            let displayOrder: [Int32]
            if item.isProfile {
                displayOrder = item.colors.profileDisplayOrder
                itemsPerRow = 8
            } else {
                displayOrder = item.colors.displayOrder
                itemsPerRow = 7
            }
            
            let rowsCount = ceil(CGFloat(displayOrder.count) / CGFloat(itemsPerRow))
            
            contentSize = CGSize(width: params.width, height: 48.0 * rowsCount)
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
                    
                    let action: (PeerNameColor) -> Void = { color in
                        item.updated(color)
                    }
                    
                    var items: [PeerNameColorIconItem] = []
                    var i: Int = 0
                    for index in displayOrder {
                        let color = PeerNameColor(rawValue: index)
                        let colors: PeerNameColors.Colors
                        if item.isProfile {
                            colors = item.colors.getProfile(color, dark: item.theme.overallDarkAppearance, subject: .palette)
                        } else {
                            colors = item.colors.get(color, dark: item.theme.overallDarkAppearance)
                        }
                        
                        items.append(PeerNameColorIconItem(index: color, colors: colors, isDark: item.theme.overallDarkAppearance, selected: color == item.currentColor, action: action))
                        i += 1
                    }
                    strongSelf.items = items
                    
                    let sideInset: CGFloat = params.leftInset + 10.0
                    let iconSize = CGSize(width: 32.0, height: 32.0)
                    
                    let spacing = (params.width - sideInset * 2.0 - iconSize.width * CGFloat(itemsPerRow)) / CGFloat(itemsPerRow - 1)
                    
                    var origin = CGPoint(x: sideInset, y: 10.0)
                    
                    i = 0
                    for item in items {
                        let iconItemNode: PeerNameColorIconItemNode
                        if let current = strongSelf.itemNodes[item.index.rawValue] {
                            iconItemNode = current
                        } else {
                            iconItemNode = PeerNameColorIconItemNode()
                            strongSelf.itemNodes[item.index.rawValue] = iconItemNode
                            strongSelf.containerNode.addSubnode(iconItemNode)
                        }
                        
                        let itemFrame = CGRect(origin: origin, size: iconSize)
                        origin.x += iconSize.width + spacing
                        iconItemNode.frame = itemFrame
                        iconItemNode.updateItem(item, size: iconSize)
                        
                        i += 1
                        if i == itemsPerRow {
                            i = 0
                            origin.x = sideInset
                            origin.y += iconSize.height + 10.0
                        }
                    }
                }
            })
        }
    }
    
    override public func animateInsertion(_ currentTimestamp: Double, duration: Double, short: Bool) {
        self.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.4)
    }
    
    override public func animateRemoved(_ currentTimestamp: Double, duration: Double) {
        self.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.15, removeOnCompletion: false)
    }
}
