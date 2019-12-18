import Foundation
import UIKit
import Display
import AsyncDisplayKit
import SwiftSignalKit
import TelegramCore
import SyncCore
import TelegramPresentationData
import TelegramUIPreferences
import MergeLists
import ItemListUI
import ContextUI
import PresentationDataUtils

private enum ThemeSettingsColorEntryId: Hashable {
    case color(Int)
    case picker
}

private enum ThemeSettingsColorEntry: Comparable, Identifiable {
    case color(Int, PresentationThemeReference, PresentationThemeAccentColor?, Bool)
    case picker
    
    var stableId: ThemeSettingsColorEntryId {
        switch self {
            case let .color(index, _, _, _):
                return .color(index)
            case .picker:
                return .picker
        }
    }
    
    static func ==(lhs: ThemeSettingsColorEntry, rhs: ThemeSettingsColorEntry) -> Bool {
        switch lhs {
            case let .color(lhsIndex, lhsThemeReference, lhsAccentColor, lhsSelected):
                if case let .color(rhsIndex, rhsThemeReference, rhsAccentColor, rhsSelected) = rhs, lhsIndex == rhsIndex, lhsThemeReference.index == rhsThemeReference.index, lhsAccentColor == rhsAccentColor, lhsSelected == rhsSelected {
                    return true
                } else {
                    return false
                }
            case .picker:
                if case .picker = rhs {
                    return true
                } else {
                    return false
                }
        }
    }
    
    static func <(lhs: ThemeSettingsColorEntry, rhs: ThemeSettingsColorEntry) -> Bool {
        switch lhs {
            case let .color(lhsIndex, _, _, _):
                switch rhs {
                    case let .color(rhsIndex, _, _, _):
                        return lhsIndex < rhsIndex
                    case .picker:
                        return true
            }
            case .picker:
                return false
        }
    }
    
    func item(action: @escaping (PresentationThemeAccentColor?, Bool) -> Void, contextAction: ((PresentationThemeAccentColor?, ASDisplayNode, ContextGesture?) -> Void)?, openColorPicker: @escaping (Bool) -> Void) -> ListViewItem {
        switch self {
            case let .color(_, themeReference, accentColor, selected):
                return ThemeSettingsAccentColorIconItem(themeReference: themeReference, accentColor: accentColor, selected: selected, action: action, contextAction: contextAction)
            case .picker:
                return ThemeSettingsAccentColorPickerItem(action: openColorPicker)
        }
    }
}

private class ThemeSettingsAccentColorIconItem: ListViewItem {
    let themeReference: PresentationThemeReference
    let accentColor: PresentationThemeAccentColor?
    let selected: Bool
    let action: (PresentationThemeAccentColor?, Bool) -> Void
    let contextAction: ((PresentationThemeAccentColor?, ASDisplayNode, ContextGesture?) -> Void)?
    
    public init(themeReference: PresentationThemeReference, accentColor: PresentationThemeAccentColor?, selected: Bool, action: @escaping (PresentationThemeAccentColor?, Bool) -> Void, contextAction: ((PresentationThemeAccentColor?, ASDisplayNode, ContextGesture?) -> Void)?) {
        self.themeReference = themeReference
        self.accentColor = accentColor
        self.selected = selected
        self.action = action
        self.contextAction = contextAction
    }
    
    public func nodeConfiguredForParams(async: @escaping (@escaping () -> Void) -> Void, params: ListViewItemLayoutParams, synchronousLoads: Bool, previousItem: ListViewItem?, nextItem: ListViewItem?, completion: @escaping (ListViewItemNode, @escaping () -> (Signal<Void, NoError>?, (ListViewItemApply) -> Void)) -> Void) {
        async {
            let node = ThemeSettingsAccentColorIconItemNode()
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
            assert(node() is ThemeSettingsAccentColorIconItemNode)
            if let nodeValue = node() as? ThemeSettingsAccentColorIconItemNode {
                let layout = nodeValue.asyncLayout()
                async {
                    let (nodeLayout, apply) = layout(self, params)
                    Queue.mainQueue().async {
                        completion(nodeLayout, { _ in
                            apply(animation.isAnimated)
                        })
                    }
                }
            }
        }
    }
    
    public var selectable = true
    public func selected(listView: ListView) {
        self.action(self.accentColor, self.selected)
    }
}

private func generateRingImage(color: UIColor) -> UIImage? {
    return generateImage(CGSize(width: 40.0, height: 40.0), rotatedContext: { size, context in
        let bounds = CGRect(origin: CGPoint(), size: size)
        context.clear(bounds)
        
        context.setStrokeColor(color.cgColor)
        context.setLineWidth(2.0)
        context.strokeEllipse(in: bounds.insetBy(dx: 1.0, dy: 1.0))
    })
}

private func generateFillImage(color: UIColor) -> UIImage? {
    return generateImage(CGSize(width: 40.0, height: 40.0), rotatedContext: { size, context in
        let bounds = CGRect(origin: CGPoint(), size: size)
        context.clear(bounds)
        
        context.setFillColor(color.cgColor)
        context.fillEllipse(in: bounds.insetBy(dx: 4.0, dy: 4.0))
    })
}

private func generateCenterImage(topColor: UIColor, bottomColor: UIColor) -> UIImage? {
    return generateImage(CGSize(width: 40.0, height: 40.0), rotatedContext: { size, context in
        let bounds = CGRect(origin: CGPoint(), size: size)
        context.clear(bounds)
        
        context.addEllipse(in: bounds.insetBy(dx: 10.0, dy: 10.0))
        context.clip()
        
        let gradientColors = [topColor.cgColor, bottomColor.cgColor] as CFArray
        var locations: [CGFloat] = [0.0, 1.0]
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let gradient = CGGradient(colorsSpace: colorSpace, colors: gradientColors, locations: &locations)!
        context.drawLinearGradient(gradient, start: CGPoint(x: 0.0, y: 10.0), end: CGPoint(x: 0.0, y: size.height - 10.0), options: CGGradientDrawingOptions())
    })
}

private func generateDotsImage() -> UIImage? {
    return generateImage(CGSize(width: 40.0, height: 40.0), rotatedContext: { size, context in
        let bounds = CGRect(origin: CGPoint(), size: size)
        context.clear(bounds)
        
        context.setFillColor(UIColor.white.cgColor)
        let dotSize = CGSize(width: 4.0, height: 4.0)
        context.fillEllipse(in: CGRect(origin: CGPoint(x: 11.0, y: 18.0), size: dotSize))
        context.fillEllipse(in: CGRect(origin: CGPoint(x: 18.0, y: 18.0), size: dotSize))
        context.fillEllipse(in: CGRect(origin: CGPoint(x: 25.0, y: 18.0), size: dotSize))
    })
}

private final class ThemeSettingsAccentColorIconItemNode : ListViewItemNode {
    private let containerNode: ContextControllerSourceNode
    private let fillNode: ASImageNode
    private let ringNode: ASImageNode
    private let centerNode: ASImageNode
    private let dotsNode: ASImageNode
    
    var item: ThemeSettingsAccentColorIconItem?

    init() {
        self.containerNode = ContextControllerSourceNode()

        self.fillNode = ASImageNode()
        self.fillNode.displaysAsynchronously = false
        self.fillNode.displayWithoutProcessing = true
        
        self.ringNode = ASImageNode()
        self.ringNode.displaysAsynchronously = false
        self.ringNode.displayWithoutProcessing = true
        
        self.centerNode = ASImageNode()
        self.centerNode.displaysAsynchronously = false
        self.centerNode.displayWithoutProcessing = true
        
        self.dotsNode = ASImageNode()
        self.dotsNode.displaysAsynchronously = false
        self.dotsNode.displayWithoutProcessing = true
        self.dotsNode.image = generateDotsImage()

        super.init(layerBacked: false, dynamicBounce: false, rotated: false, seeThrough: false)

        self.addSubnode(self.containerNode)
        self.containerNode.addSubnode(self.fillNode)
        self.containerNode.addSubnode(self.ringNode)
        self.containerNode.addSubnode(self.dotsNode)
        self.containerNode.addSubnode(self.centerNode)

        self.containerNode.activated = { [weak self] gesture in
            guard let strongSelf = self, let item = strongSelf.item else {
                gesture.cancel()
                return
            }
            item.contextAction?(item.accentColor, strongSelf.containerNode, gesture)
        }
    }
    
    override func didLoad() {
        super.didLoad()
        
        self.layer.sublayerTransform = CATransform3DMakeRotation(CGFloat.pi / 2.0, 0.0, 0.0, 1.0)
    }
    
    func setSelected(_ selected: Bool, animated: Bool = false) {
        let transition: ContainedViewLayoutTransition = animated ? .animated(duration: 0.3, curve: .easeInOut) : .immediate
        if selected {
            transition.updateTransformScale(node: self.fillNode, scale: 1.0)
            transition.updateTransformScale(node: self.centerNode, scale: 0.16)
            transition.updateAlpha(node: self.centerNode, alpha: 0.0)
            transition.updateTransformScale(node: self.dotsNode, scale: 1.0)
            transition.updateAlpha(node: self.dotsNode, alpha: 1.0)
        } else {
            transition.updateTransformScale(node: self.fillNode, scale: 1.2)
            transition.updateTransformScale(node: self.centerNode, scale: 1.0)
            transition.updateAlpha(node: self.centerNode, alpha: 1.0)
            transition.updateTransformScale(node: self.dotsNode, scale: 0.7)
            transition.updateAlpha(node: self.dotsNode, alpha: 0.0)
        }
    }
    
    func asyncLayout() -> (ThemeSettingsAccentColorIconItem, ListViewItemLayoutParams) -> (ListViewItemNodeLayout, (Bool) -> Void) {
        let currentItem = self.item

        return { [weak self] item, params in
            var updatedAccentColor = false
            var updatedSelected = false
            
            if currentItem == nil || currentItem?.accentColor != item.accentColor {
                updatedAccentColor = true
            }
            if currentItem?.selected != item.selected {
                updatedSelected = true
            }
            
            let itemLayout = ListViewItemNodeLayout(contentSize: CGSize(width: 60.0, height: 58.0), insets: UIEdgeInsets())
            return (itemLayout, { animated in
                if let strongSelf = self {
                    strongSelf.item = item
                    
                    if updatedAccentColor {
                        var fillColor = item.accentColor?.color
                        var strokeColor = item.accentColor?.baseColor.color
                        if strokeColor == .clear {
                            strokeColor = fillColor
                        }
                        
                        //        if strokeColor.distance(to: theme.list.itemBlocksBackgroundColor) < 200 {
                        //            if strokeColor.distance(to: UIColor.white) < 200 {
                        //                strokeColor = UIColor(rgb: 0x999999)
                        //            } else {
                        //                strokeColor = theme.list.controlSecondaryColor
                        //            }
                        //        }
            
                        var topColor: UIColor?
                        var bottomColor: UIColor?
                        
                        if let colors = item.accentColor?.plainBubbleColors {
                            topColor = colors.0
                            bottomColor = colors.1
                        } else if case .builtin(.dayClassic) = item.themeReference {
                            if let accentColor = item.accentColor {
                                let hsb = accentColor.color.hsb
                                let bubbleColor = UIColor(hue: hsb.0, saturation: (hsb.1 > 0.0 && hsb.2 > 0.0) ? 0.14 : 0.0, brightness: 0.79 + hsb.2 * 0.21, alpha: 1.0)
                                topColor = bubbleColor
                                bottomColor = bubbleColor
                            } else {
                                fillColor = UIColor(rgb: 0x007ee5)
                                strokeColor = fillColor
                                topColor = UIColor(rgb: 0xe1ffc7)
                                bottomColor = topColor
                            }
                        }
                        
                        strongSelf.fillNode.image = generateFillImage(color: fillColor ?? .clear)
                        strongSelf.ringNode.image = generateRingImage(color: strokeColor ?? .clear)
                        strongSelf.centerNode.image = generateCenterImage(topColor: topColor ?? .clear, bottomColor: bottomColor ?? .clear)
                    }
                    
                    let center = CGPoint(x: 30.0, y: 29.0)
                    let bounds = CGRect(origin: CGPoint(x: 0.0, y: 0.0), size: CGSize(width: 40.0, height: 40.0))
                    strongSelf.containerNode.frame = CGRect(origin: CGPoint(), size: itemLayout.contentSize)
                    
                    strongSelf.fillNode.position = center
                    strongSelf.ringNode.position = center
                    strongSelf.centerNode.position = center
                    strongSelf.dotsNode.position = center
                    
                    strongSelf.fillNode.bounds = bounds
                    strongSelf.ringNode.bounds = bounds
                    strongSelf.centerNode.bounds = bounds
                    strongSelf.dotsNode.bounds = bounds
                    
                    if updatedSelected {
                        strongSelf.setSelected(item.selected, animated: currentItem != nil)
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

private class ThemeSettingsAccentColorPickerItem: ListViewItem {
    let action: (Bool) -> Void
    
    public init(action: @escaping (Bool) -> Void) {
        self.action = action
    }
    
    public func nodeConfiguredForParams(async: @escaping (@escaping () -> Void) -> Void, params: ListViewItemLayoutParams, synchronousLoads: Bool, previousItem: ListViewItem?, nextItem: ListViewItem?, completion: @escaping (ListViewItemNode, @escaping () -> (Signal<Void, NoError>?, (ListViewItemApply) -> Void)) -> Void) {
        async {
            let node = ThemeSettingsAccentColorPickerItemNode()
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
            assert(node() is ThemeSettingsAccentColorPickerItemNode)
            if let nodeValue = node() as? ThemeSettingsAccentColorPickerItemNode {
                let layout = nodeValue.asyncLayout()
                async {
                    let (nodeLayout, apply) = layout(self, params)
                    Queue.mainQueue().async {
                        completion(nodeLayout, { _ in
                            apply(animation.isAnimated)
                        })
                    }
                }
            }
        }
    }
    
    public var selectable = true
    public func selected(listView: ListView) {
        self.action(true)
    }
}


private func generateCustomSwatchImage() -> UIImage? {
    return generateImage(CGSize(width: 42.0, height: 42.0), rotatedContext: { size, context in
        let bounds = CGRect(origin: CGPoint(), size: size)
        context.clear(bounds)
        
        let dotSize = CGSize(width: 10.0, height: 10.0)
        
        context.setFillColor(UIColor(rgb: 0xd33213).cgColor)
        context.fillEllipse(in: CGRect(origin: CGPoint(x: 14.0, y: 16.0), size: dotSize))
        
        context.setFillColor(UIColor(rgb: 0xf08200).cgColor)
        context.fillEllipse(in: CGRect(origin: CGPoint(x: 14.0, y: 0.0), size: dotSize))
        
        context.setFillColor(UIColor(rgb: 0xedb400).cgColor)
        context.fillEllipse(in: CGRect(origin: CGPoint(x: 28.0, y: 8.0), size: dotSize))
        
        context.setFillColor(UIColor(rgb: 0x70bb23).cgColor)
        context.fillEllipse(in: CGRect(origin: CGPoint(x: 28.0, y: 24.0), size: dotSize))
        
        context.setFillColor(UIColor(rgb: 0x5396fa).cgColor)
        context.fillEllipse(in: CGRect(origin: CGPoint(x: 14.0, y: 32.0), size: dotSize))
        
        context.setFillColor(UIColor(rgb: 0x9472ee).cgColor)
        context.fillEllipse(in: CGRect(origin: CGPoint(x: 0.0, y: 24.0), size: dotSize))
        
        context.setFillColor(UIColor(rgb: 0xeb6ca4).cgColor)
        context.fillEllipse(in: CGRect(origin: CGPoint(x: 0.0, y: 8.0), size: dotSize))
    })
}

private final class ThemeSettingsAccentColorPickerItemNode : ListViewItemNode {
    private let imageNode: ASImageNode
    
    var item: ThemeSettingsAccentColorPickerItem?

    init() {
        self.imageNode = ASImageNode()
        self.imageNode.displaysAsynchronously = false
        self.imageNode.displayWithoutProcessing = true
        self.imageNode.image = generateCustomSwatchImage()

        super.init(layerBacked: false, dynamicBounce: false, rotated: false, seeThrough: false)

        self.addSubnode(self.imageNode)
    }
    
    override func didLoad() {
        super.didLoad()
        
        self.layer.sublayerTransform = CATransform3DMakeRotation(CGFloat.pi / 2.0, 0.0, 0.0, 1.0)
    }
    
    func asyncLayout() -> (ThemeSettingsAccentColorPickerItem, ListViewItemLayoutParams) -> (ListViewItemNodeLayout, (Bool) -> Void) {
        let currentItem = self.item

        return { [weak self] item, params in
            let itemLayout = ListViewItemNodeLayout(contentSize: CGSize(width: 60.0, height: 60.0), insets: UIEdgeInsets())
            return (itemLayout, { animated in
                if let strongSelf = self {
                    strongSelf.item = item
                    
                    strongSelf.imageNode.frame = CGRect(origin: CGPoint(x: 9.0, y: 9.0), size: CGSize(width: 42.0, height: 42.0))
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

enum ThemeSettingsAccentColor {
    case `default`
    case color(PresentationThemeBaseColor)
    case preset(PresentationThemeAccentColor)
    case custom(PresentationThemeAccentColor)
    
    var index: Int32? {
        switch self {
            case .default:
                return nil
            case let .color(color):
                return 10 + color.rawValue
            case let .preset(color), let .custom(color):
                return color.index
        }
    }
}

class ThemeSettingsAccentColorItem: ListViewItem, ItemListItem {
    var sectionId: ItemListSectionId
    
    let theme: PresentationTheme
    let themeReference: PresentationThemeReference
    let colors: [ThemeSettingsAccentColor]
    let currentColor: PresentationThemeAccentColor?
    let updated: (PresentationThemeAccentColor?) -> Void
    let contextAction: ((PresentationThemeReference, PresentationThemeAccentColor?, ASDisplayNode, ContextGesture?) -> Void)?
    let openColorPicker: (Bool) -> Void
    let tag: ItemListItemTag?
    
    init(theme: PresentationTheme, sectionId: ItemListSectionId, themeReference: PresentationThemeReference, colors: [ThemeSettingsAccentColor], currentColor: PresentationThemeAccentColor?, updated: @escaping (PresentationThemeAccentColor?) -> Void, contextAction: ((PresentationThemeReference, PresentationThemeAccentColor?, ASDisplayNode, ContextGesture?) -> Void)?, openColorPicker: @escaping (Bool) -> Void, tag: ItemListItemTag? = nil) {
        self.theme = theme
        self.themeReference = themeReference
        self.colors = colors
        self.currentColor = currentColor
        self.updated = updated
        self.contextAction = contextAction
        self.openColorPicker = openColorPicker
        self.tag = tag
        self.sectionId = sectionId
    }
    
    func nodeConfiguredForParams(async: @escaping (@escaping () -> Void) -> Void, params: ListViewItemLayoutParams, synchronousLoads: Bool, previousItem: ListViewItem?, nextItem: ListViewItem?, completion: @escaping (ListViewItemNode, @escaping () -> (Signal<Void, NoError>?, (ListViewItemApply) -> Void)) -> Void) {
        async {
            let node = ThemeSettingsAccentColorItemNode()
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
            if let nodeValue = node() as? ThemeSettingsAccentColorItemNode {
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
}

private struct ThemeSettingsAccentColorItemNodeTransition {
    let deletions: [ListViewDeleteItem]
    let insertions: [ListViewInsertItem]
    let updates: [ListViewUpdateItem]
    let crossfade: Bool
}

private func preparedTransition(action: @escaping (PresentationThemeAccentColor?, Bool) -> Void, contextAction: ((PresentationThemeAccentColor?, ASDisplayNode, ContextGesture?) -> Void)?, openColorPicker: @escaping (Bool) -> Void, from fromEntries: [ThemeSettingsColorEntry], to toEntries: [ThemeSettingsColorEntry], crossfade: Bool) -> ThemeSettingsAccentColorItemNodeTransition {
    let (deleteIndices, indicesAndItems, updateIndices) = mergeListsStableWithUpdates(leftList: fromEntries, rightList: toEntries)
    
    let deletions = deleteIndices.map { ListViewDeleteItem(index: $0, directionHint: nil) }
    let insertions = indicesAndItems.map { ListViewInsertItem(index: $0.0, previousIndex: $0.2, item: $0.1.item(action: action, contextAction: contextAction, openColorPicker: openColorPicker), directionHint: .Down) }
    let updates = updateIndices.map { ListViewUpdateItem(index: $0.0, previousIndex: $0.2, item: $0.1.item(action: action, contextAction: contextAction, openColorPicker: openColorPicker), directionHint: nil) }
    
    return ThemeSettingsAccentColorItemNodeTransition(deletions: deletions, insertions: insertions, updates: updates, crossfade: crossfade)
}

private func ensureColorVisible(listNode: ListView, accentColor: PresentationThemeAccentColor?, animated: Bool) -> Bool {
    var resultNode: ThemeSettingsAccentColorIconItemNode?
    listNode.forEachItemNode { node in
        if resultNode == nil, let node = node as? ThemeSettingsAccentColorIconItemNode {
            if node.item?.accentColor?.index == accentColor?.index {
                resultNode = node
            }
        }
    }
    if let resultNode = resultNode {
        listNode.ensureItemNodeVisible(resultNode, animated: animated, overflow: 24.0)
        return true
    } else {
        return false
    }
}

class ThemeSettingsAccentColorItemNode: ListViewItemNode, ItemListItemNode {
    private let containerNode: ASDisplayNode
    private let backgroundNode: ASDisplayNode
    private let topStripeNode: ASDisplayNode
    private let bottomStripeNode: ASDisplayNode
    private let maskNode: ASImageNode
    private var snapshotView: UIView?
    
    private let listNode: ListView
    private var entries: [ThemeSettingsColorEntry]?
    private var enqueuedTransitions: [ThemeSettingsAccentColorItemNodeTransition] = []
    private var initialized = false
    
    private var item: ThemeSettingsAccentColorItem?
    private var layoutParams: ListViewItemLayoutParams?
    
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
    
    private func enqueueTransition(_ transition: ThemeSettingsAccentColorItemNodeTransition) {
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
        
        var options = ListViewDeleteAndInsertOptions()
        if self.initialized && transition.crossfade {
            options.insert(.AnimateCrossfade)
        }
        
        var scrollToItem: ListViewScrollToItem?
        if !self.initialized {
            if let index = item.colors.firstIndex(where: { $0.index == item.currentColor?.index }) {
                scrollToItem = ListViewScrollToItem(index: index, position: .bottom(-24.0), animated: false, curve: .Default(duration: 0.0), directionHint: .Down)
                self.initialized = true
            }
        }
        
        self.listNode.transaction(deleteIndices: transition.deletions, insertIndicesAndItems: transition.insertions, updateIndicesAndItems: transition.updates, options: options, scrollToItem: scrollToItem, updateSizeAndInsets: nil, updateOpaqueState: nil, completion: { _ in
        })
    }
    
    func asyncLayout() -> (_ item: ThemeSettingsAccentColorItem, _ params: ListViewItemLayoutParams, _ neighbors: ItemListNeighbors) -> (ListViewItemNodeLayout, () -> Void) {
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
            insets = itemListNeighborsGroupedInsets(neighbors)
            
            let layout = ListViewItemNodeLayout(contentSize: contentSize, insets: insets)
            let layoutSize = layout.size
            
            return (layout, { [weak self] in
                if let strongSelf = self {
                    strongSelf.item = item
                    strongSelf.layoutParams = params
                    
                    strongSelf.backgroundNode.backgroundColor = item.theme.list.itemBlocksBackgroundColor
                    strongSelf.topStripeNode.backgroundColor = item.theme.list.itemBlocksSeparatorColor
                    strongSelf.bottomStripeNode.backgroundColor = item.theme.list.itemBlocksSeparatorColor
                    
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
                            bottomStripeInset = params.leftInset + 16.0
                            bottomStripeOffset = -separatorHeight
                        default:
                            bottomStripeInset = 0.0
                            bottomStripeOffset = 0.0
                            hasBottomCorners = true
                            strongSelf.bottomStripeNode.isHidden = hasCorners
                    }
                    
                    strongSelf.containerNode.frame = CGRect(x: 0.0, y: 0.0, width: contentSize.width, height: contentSize.height)
                    strongSelf.maskNode.image = hasCorners ? PresentationResourcesItemList.cornersImage(item.theme, top: hasTopCorners, bottom: hasBottomCorners) : nil
                    
                    strongSelf.backgroundNode.frame = CGRect(origin: CGPoint(x: 0.0, y: -min(insets.top, separatorHeight)), size: CGSize(width: params.width, height: contentSize.height + min(insets.top, separatorHeight) + min(insets.bottom, separatorHeight)))
                    strongSelf.maskNode.frame = strongSelf.backgroundNode.frame.insetBy(dx: params.leftInset, dy: 0.0)
                    strongSelf.topStripeNode.frame = CGRect(origin: CGPoint(x: 0.0, y: -min(insets.top, separatorHeight)), size: CGSize(width: layoutSize.width, height: separatorHeight))
                    strongSelf.bottomStripeNode.frame = CGRect(origin: CGPoint(x: bottomStripeInset, y: contentSize.height + bottomStripeOffset), size: CGSize(width: layoutSize.width - bottomStripeInset, height: separatorHeight))
                    
                    var listInsets = UIEdgeInsets()
                    listInsets.top += params.leftInset + 4.0
                    listInsets.bottom += params.rightInset + 4.0
                    
                    strongSelf.listNode.bounds = CGRect(x: 0.0, y: 0.0, width: contentSize.height, height: contentSize.width)
                    strongSelf.listNode.position = CGPoint(x: contentSize.width / 2.0, y: contentSize.height / 2.0)
                    strongSelf.listNode.transaction(deleteIndices: [], insertIndicesAndItems: [], updateIndicesAndItems: [], options: [.Synchronous], scrollToItem: nil, updateSizeAndInsets: ListViewUpdateSizeAndInsets(size: CGSize(width: contentSize.height, height: contentSize.width), insets: listInsets, duration: 0.0, curve: .Default(duration: nil)), stationaryItemRange: nil, updateOpaqueState: nil, completion: { _ in })
                    
                    var entries: [ThemeSettingsColorEntry] = []
                    var index: Int = 0
                    for color in item.colors {
                        switch color {
                            case .default:
                                let selected = item.currentColor == nil
                                entries.append(.color(index, item.themeReference, nil, selected))
                            case let .color(color):
                                let selected = item.currentColor?.baseColor == color
                                let accentColor: PresentationThemeAccentColor
                                if let currentColor = item.currentColor, selected {
                                    accentColor = currentColor
                                } else {
                                    accentColor = PresentationThemeAccentColor(index: 10 + color.rawValue, baseColor: color)
                                }
                                entries.append(.color(index, item.themeReference, accentColor, selected))
                            case let .preset(color), let .custom(color):
                                let selected = item.currentColor == color
                                entries.append(.color(index, item.themeReference, color, selected))
                        }
                        
                        index += 1
                    }
                    entries.append(.picker)
                    
                    let action: (PresentationThemeAccentColor?, Bool) -> Void = { [weak self] color, selected in
                        if let strongSelf = self, let item = strongSelf.item {
                            if selected {
                                item.openColorPicker(color?.baseColor != .custom)
                            } else {
                                item.updated(color)
                            }
                            ensureColorVisible(listNode: strongSelf.listNode, accentColor: color, animated: true)
                        }
                    }
                    let contextAction: ((PresentationThemeAccentColor?, ASDisplayNode, ContextGesture?) -> Void)? = { [weak item] color, node, gesture in
                        if let strongSelf = self, let item = strongSelf.item {
                            item.contextAction?(item.themeReference, color, node, gesture)
                        }
                    }
                    let openColorPicker: (Bool) -> Void = { [weak self] create in
                        if let strongSelf = self, let item = strongSelf.item {
                            item.openColorPicker(true)
                        }
                    }
                    
                    let previousEntries = strongSelf.entries ?? []
                    let crossfade = themeUpdated || previousEntries.count != entries.count
                    let transition = preparedTransition(action: action, contextAction: contextAction, openColorPicker: openColorPicker, from: previousEntries, to: entries, crossfade: crossfade)
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
    
    func prepareCrossfadeTransition() {
        self.snapshotView?.removeFromSuperview()
        
        if let snapshotView = self.containerNode.view.snapshotView(afterScreenUpdates: false) {
            self.view.insertSubview(snapshotView, aboveSubview: self.containerNode.view)
            self.snapshotView = snapshotView
        }
    }
    
    func animateCrossfadeTransition() {
        self.snapshotView?.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.3, removeOnCompletion: false, completion: { [weak self] _ in
            self?.snapshotView?.removeFromSuperview()
        })
    }
}
