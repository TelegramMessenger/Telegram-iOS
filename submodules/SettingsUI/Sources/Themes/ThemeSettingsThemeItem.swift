import Foundation
import UIKit
import Display
import AsyncDisplayKit
import SwiftSignalKit
import Postbox
import TelegramCore
import TelegramPresentationData
import MergeLists
import TelegramUIPreferences
import ItemListUI
import PresentationDataUtils
import WallpaperResources
import AccountContext
import AppBundle
import ContextUI

private struct ThemeSettingsThemeEntry: Comparable, Identifiable {    
    let index: Int
    let themeReference: PresentationThemeReference
    let title: String
    let accentColor: PresentationThemeAccentColor?
    var selected: Bool
    let theme: PresentationTheme
    let wallpaper: TelegramWallpaper?
    
    var stableId: Int64 {
        return self.themeReference.generalThemeReference.index
    }
    
    static func ==(lhs: ThemeSettingsThemeEntry, rhs: ThemeSettingsThemeEntry) -> Bool {
        if lhs.index != rhs.index {
            return false
        }
        if lhs.themeReference.index != rhs.themeReference.index {
            return false
        }
        if lhs.accentColor != rhs.accentColor {
            return false
        }
        if lhs.title != rhs.title {
            return false
        }
        if lhs.selected != rhs.selected {
            return false
        }
        if lhs.theme !== rhs.theme {
            return false
        }
        if lhs.wallpaper != rhs.wallpaper {
            return false
        }
        return true
    }
    
    static func <(lhs: ThemeSettingsThemeEntry, rhs: ThemeSettingsThemeEntry) -> Bool {
        return lhs.index < rhs.index
    }
    
    func item(context: AccountContext, action: @escaping (PresentationThemeReference) -> Void, contextAction: ((PresentationThemeReference, ASDisplayNode, ContextGesture?) -> Void)?) -> ListViewItem {
        return ThemeSettingsThemeIconItem(context: context, themeReference: self.themeReference, accentColor: self.accentColor, selected: self.selected, title: self.title, theme: self.theme, wallpaper: self.wallpaper, action: action, contextAction: contextAction)
    }
}


private class ThemeSettingsThemeIconItem: ListViewItem {
    let context: AccountContext
    let themeReference: PresentationThemeReference
    let accentColor: PresentationThemeAccentColor?
    let selected: Bool
    let title: String
    let theme: PresentationTheme
    let wallpaper: TelegramWallpaper?
    let action: (PresentationThemeReference) -> Void
    let contextAction: ((PresentationThemeReference, ASDisplayNode, ContextGesture?) -> Void)?
    
    public init(context: AccountContext, themeReference: PresentationThemeReference, accentColor: PresentationThemeAccentColor?, selected: Bool, title: String, theme: PresentationTheme, wallpaper: TelegramWallpaper?, action: @escaping (PresentationThemeReference) -> Void, contextAction: ((PresentationThemeReference, ASDisplayNode, ContextGesture?) -> Void)?) {
        self.context = context
        self.themeReference = themeReference
        self.accentColor = accentColor
        self.selected = selected
        self.title = title
        self.theme = theme
        self.wallpaper = wallpaper
        self.action = action
        self.contextAction = contextAction
    }
    
    public func nodeConfiguredForParams(async: @escaping (@escaping () -> Void) -> Void, params: ListViewItemLayoutParams, synchronousLoads: Bool, previousItem: ListViewItem?, nextItem: ListViewItem?, completion: @escaping (ListViewItemNode, @escaping () -> (Signal<Void, NoError>?, (ListViewItemApply) -> Void)) -> Void) {
        async {
            let node = ThemeSettingsThemeItemIconNode()
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
            assert(node() is ThemeSettingsThemeItemIconNode)
            if let nodeValue = node() as? ThemeSettingsThemeItemIconNode {
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
        self.action(self.themeReference)
    }
}


private let textFont = Font.regular(12.0)
private let selectedTextFont = Font.bold(12.0)

private var cachedBorderImages: [String: UIImage] = [:]
private func generateBorderImage(theme: PresentationTheme, bordered: Bool, selected: Bool) -> UIImage? {
    let key = "\(theme.list.itemBlocksBackgroundColor.hexString)_\(selected ? "s" + theme.list.itemAccentColor.hexString : theme.list.disclosureArrowColor.hexString)"
    if let image = cachedBorderImages[key] {
        return image
    } else {
        let image = generateImage(CGSize(width: 32.0, height: 32.0), rotatedContext: { size, context in
            let bounds = CGRect(origin: CGPoint(), size: size)
            context.clear(bounds)

            let lineWidth: CGFloat
            if selected {
                lineWidth = 2.0
                context.setLineWidth(lineWidth)
                context.setStrokeColor(theme.list.itemBlocksBackgroundColor.cgColor)
                
                context.strokeEllipse(in: bounds.insetBy(dx: 3.0 + lineWidth / 2.0, dy: 3.0 + lineWidth / 2.0))
                
                var accentColor = theme.list.itemAccentColor
                if accentColor.rgb == 0xffffff {
                    accentColor = UIColor(rgb: 0x999999)
                }
                context.setStrokeColor(accentColor.cgColor)
            } else {
                context.setStrokeColor(theme.list.disclosureArrowColor.withAlphaComponent(0.4).cgColor)
                lineWidth = 1.0
            }

            if bordered || selected {
                context.setLineWidth(lineWidth)
                context.strokeEllipse(in: bounds.insetBy(dx: 1.0 + lineWidth / 2.0, dy: 1.0 + lineWidth / 2.0))
            }
        })?.stretchableImage(withLeftCapWidth: 16, topCapHeight: 16)
        cachedBorderImages[key] = image
        return image
    }
}

private func createThemeImage(theme: PresentationTheme) -> Signal<(TransformImageArguments) -> DrawingContext?, NoError> {
    return .single(theme)
    |> map { theme -> (TransformImageArguments) -> DrawingContext? in
        return { arguments in
            let context = DrawingContext(size: arguments.drawingSize, scale: arguments.scale ?? 0.0, clear: true)
            let drawingRect = arguments.drawingRect
            
            context.withContext { c in
                c.clear(CGRect(origin: CGPoint(), size: drawingRect.size))
                
                c.translateBy(x: drawingRect.width / 2.0, y: drawingRect.height / 2.0)
                c.scaleBy(x: 1.0, y: -1.0)
                c.translateBy(x: -drawingRect.width / 2.0, y: -drawingRect.height / 2.0)
                
                if let icon = generateTintedImage(image: UIImage(bundleImageName: "Settings/CreateThemeIcon"), color: theme.list.itemAccentColor) {
                    c.draw(icon.cgImage!, in: CGRect(origin: CGPoint(x: floor((drawingRect.width - icon.size.width) / 2.0) - 3.0, y: floor((drawingRect.height - icon.size.height) / 2.0)), size: icon.size))
                }
            }
            addCorners(context, arguments: arguments)
            return context
        }
    }
}


private final class ThemeSettingsThemeItemIconNode : ListViewItemNode {
    private let containerNode: ContextControllerSourceNode
    private let imageNode: TransformImageNode
    private let overlayNode: ASImageNode
    private let titleNode: TextNode
    var snapshotView: UIView?
    
    var item: ThemeSettingsThemeIconItem?

    init() {
        self.containerNode = ContextControllerSourceNode()

        self.imageNode = TransformImageNode()
        self.imageNode.frame = CGRect(origin: CGPoint(), size: CGSize(width: 98.0, height: 62.0))
        self.imageNode.isLayerBacked = true

        self.overlayNode = ASImageNode()
        self.overlayNode.frame = CGRect(origin: CGPoint(), size: CGSize(width: 100.0, height: 64.0))
        self.overlayNode.isLayerBacked = true

        self.titleNode = TextNode()
        self.titleNode.isUserInteractionEnabled = false

        super.init(layerBacked: false, dynamicBounce: false, rotated: false, seeThrough: false)

        self.addSubnode(self.containerNode)
        self.containerNode.addSubnode(self.imageNode)
        self.containerNode.addSubnode(self.overlayNode)
        self.containerNode.addSubnode(self.titleNode)

        self.containerNode.activated = { [weak self] gesture, _ in
            guard let strongSelf = self, let item = strongSelf.item else {
                gesture.cancel()
                return
            }
            item.contextAction?(item.themeReference, strongSelf.containerNode, gesture)
        }
    }
    
    override func didLoad() {
        super.didLoad()
        
        self.layer.sublayerTransform = CATransform3DMakeRotation(CGFloat.pi / 2.0, 0.0, 0.0, 1.0)
    }
    
    func asyncLayout() -> (ThemeSettingsThemeIconItem, ListViewItemLayoutParams) -> (ListViewItemNodeLayout, (Bool) -> Void) {
        let makeTitleLayout = TextNode.asyncLayout(self.titleNode)
        let makeImageLayout = self.imageNode.asyncLayout()
        
        let currentItem = self.item

        return { [weak self] item, params in
            var updatedThemeReference = false
            var updatedAccentColor = false
            var updatedTheme = false
            var updatedWallpaper = false
            var updatedSelected = false
            
            if currentItem?.themeReference != item.themeReference {
                updatedThemeReference = true
            }
            if currentItem?.wallpaper != item.wallpaper {
                updatedWallpaper = true
            }
            if currentItem == nil || currentItem?.accentColor != item.accentColor {
                updatedAccentColor = true
            }
            if currentItem?.theme !== item.theme {
                updatedTheme = true
            }
            if currentItem?.selected != item.selected {
                updatedSelected = true
            }
            
            let title = NSAttributedString(string: item.title, font: item.selected ? selectedTextFont : textFont, textColor: item.selected ? item.theme.list.itemAccentColor : item.theme.list.itemPrimaryTextColor)
            let (_, titleApply) = makeTitleLayout(TextNodeLayoutArguments(attributedString: title, backgroundColor: nil, maximumNumberOfLines: 1, truncationType: .end, constrainedSize: CGSize(width: params.width, height: CGFloat.greatestFiniteMagnitude), alignment: .center, cutout: nil, insets: UIEdgeInsets()))
            
            let itemLayout = ListViewItemNodeLayout(contentSize: CGSize(width: 116.0, height: 116.0), insets: UIEdgeInsets())
            return (itemLayout, { animated in
                if let strongSelf = self {
                    strongSelf.item = item
                    
                    if case let .cloud(theme) = item.themeReference, theme.theme.file == nil && theme.theme.settings == nil {
                        if updatedTheme {
                            strongSelf.imageNode.setSignal(createThemeImage(theme: item.theme))
                        }
                        strongSelf.containerNode.isGestureEnabled = false
                    } else {
                        if updatedThemeReference || updatedAccentColor || updatedWallpaper {
                            strongSelf.imageNode.setSignal(themeIconImage(account: item.context.account, accountManager: item.context.sharedContext.accountManager, theme: item.themeReference, color: item.accentColor, wallpaper: item.wallpaper))
                        }
                        strongSelf.containerNode.isGestureEnabled = true
                    }
                    if updatedTheme || updatedSelected {
                        strongSelf.overlayNode.image = generateBorderImage(theme: item.theme, bordered: true, selected: item.selected)
                    }
                    
                    strongSelf.containerNode.frame = CGRect(origin: CGPoint(), size: itemLayout.contentSize)
                    
                    let _ = titleApply()

                    let imageSize = CGSize(width: 98.0, height: 62.0)
                    strongSelf.imageNode.frame = CGRect(origin: CGPoint(x: 10.0, y: 14.0), size: imageSize)
                    let applyLayout = makeImageLayout(TransformImageArguments(corners: ImageCorners(radius: 16.0), imageSize: imageSize, boundingSize: imageSize, intrinsicInsets: UIEdgeInsets(), emptyColor: .clear))
                    applyLayout()
                    
                    strongSelf.overlayNode.frame = CGRect(origin: CGPoint(x: 9.0, y: 13.0), size: CGSize(width: 100.0, height: 64.0))
                    strongSelf.titleNode.frame = CGRect(origin: CGPoint(x: 0.0, y: 88.0), size: CGSize(width: itemLayout.contentSize.width, height: 16.0))
                }
            })
        }
    }
    
    func prepareCrossfadeTransition() {
        guard self.snapshotView == nil else {
            return
        }
        
        if let snapshotView = self.containerNode.view.snapshotView(afterScreenUpdates: false) {
            self.view.insertSubview(snapshotView, aboveSubview: self.containerNode.view)
            self.snapshotView = snapshotView
        }
    }
    
    func animateCrossfadeTransition() {
        guard self.snapshotView?.layer.animationKeys()?.isEmpty ?? true else {
            return
        }
        
        self.snapshotView?.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.3, removeOnCompletion: false, completion: { [weak self] _ in
            self?.snapshotView?.removeFromSuperview()
            self?.snapshotView = nil
        })
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

class ThemeSettingsThemeItem: ListViewItem, ItemListItem {
    var sectionId: ItemListSectionId

    let context: AccountContext
    let theme: PresentationTheme
    let strings: PresentationStrings
    let themes: [PresentationThemeReference]
    let allThemes: [PresentationThemeReference]
    let displayUnsupported: Bool
    let themeSpecificAccentColors: [Int64: PresentationThemeAccentColor]
    let themeSpecificChatWallpapers: [Int64: TelegramWallpaper]
    let themePreferredBaseTheme: [Int64: TelegramBaseTheme]
    let currentTheme: PresentationThemeReference
    let updatedTheme: (PresentationThemeReference) -> Void
    let contextAction: ((PresentationThemeReference, ASDisplayNode, ContextGesture?) -> Void)?
    let tag: ItemListItemTag?

    init(context: AccountContext, theme: PresentationTheme, strings: PresentationStrings, sectionId: ItemListSectionId, themes: [PresentationThemeReference], allThemes: [PresentationThemeReference], displayUnsupported: Bool, themeSpecificAccentColors: [Int64: PresentationThemeAccentColor], themeSpecificChatWallpapers: [Int64: TelegramWallpaper], themePreferredBaseTheme: [Int64: TelegramBaseTheme], currentTheme: PresentationThemeReference, updatedTheme: @escaping (PresentationThemeReference) -> Void, contextAction: ((PresentationThemeReference, ASDisplayNode, ContextGesture?) -> Void)?, tag: ItemListItemTag? = nil) {
        self.context = context
        self.theme = theme
        self.strings = strings
        self.themes = themes
        self.allThemes = allThemes
        self.displayUnsupported = displayUnsupported
        self.themeSpecificAccentColors = themeSpecificAccentColors
        self.themeSpecificChatWallpapers = themeSpecificChatWallpapers
        self.themePreferredBaseTheme = themePreferredBaseTheme
        self.currentTheme = currentTheme
        self.updatedTheme = updatedTheme
        self.contextAction = contextAction
        self.tag = tag
        self.sectionId = sectionId
    }

    func nodeConfiguredForParams(async: @escaping (@escaping () -> Void) -> Void, params: ListViewItemLayoutParams, synchronousLoads: Bool, previousItem: ListViewItem?, nextItem: ListViewItem?, completion: @escaping (ListViewItemNode, @escaping () -> (Signal<Void, NoError>?, (ListViewItemApply) -> Void)) -> Void) {
        async {
            let node = ThemeSettingsThemeItemNode()
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
            if let nodeValue = node() as? ThemeSettingsThemeItemNode {
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

private struct ThemeSettingsThemeItemNodeTransition {
    let deletions: [ListViewDeleteItem]
    let insertions: [ListViewInsertItem]
    let updates: [ListViewUpdateItem]
    let crossfade: Bool
    let entries: [ThemeSettingsThemeEntry]
}

private func preparedTransition(context: AccountContext, action: @escaping (PresentationThemeReference) -> Void, contextAction: ((PresentationThemeReference, ASDisplayNode, ContextGesture?) -> Void)?, from fromEntries: [ThemeSettingsThemeEntry], to toEntries: [ThemeSettingsThemeEntry], crossfade: Bool) -> ThemeSettingsThemeItemNodeTransition {
    let (deleteIndices, indicesAndItems, updateIndices) = mergeListsStableWithUpdates(leftList: fromEntries, rightList: toEntries)
    
    let deletions = deleteIndices.map { ListViewDeleteItem(index: $0, directionHint: nil) }
    let insertions = indicesAndItems.map { ListViewInsertItem(index: $0.0, previousIndex: $0.2, item: $0.1.item(context: context, action: action, contextAction: contextAction), directionHint: .Down) }
    let updates = updateIndices.map { ListViewUpdateItem(index: $0.0, previousIndex: $0.2, item: $0.1.item(context: context, action: action, contextAction: contextAction), directionHint: nil) }
    
    return ThemeSettingsThemeItemNodeTransition(deletions: deletions, insertions: insertions, updates: updates, crossfade: crossfade, entries: toEntries)
}

private func ensureThemeVisible(listNode: ListView, themeReference: PresentationThemeReference, animated: Bool) -> Bool {
    var resultNode: ThemeSettingsThemeItemIconNode?
    listNode.forEachItemNode { node in
        if resultNode == nil, let node = node as? ThemeSettingsThemeItemIconNode {
            if node.item?.themeReference.index == themeReference.index {
                resultNode = node
            }
        }
    }
    if let resultNode = resultNode {
        listNode.ensureItemNodeVisible(resultNode, animated: animated, overflow: 57.0)
        return true
    } else {
        return false
    }
}

class ThemeSettingsThemeItemNode: ListViewItemNode, ItemListItemNode {
    private let containerNode: ASDisplayNode
    private let backgroundNode: ASDisplayNode
    private let topStripeNode: ASDisplayNode
    private let bottomStripeNode: ASDisplayNode
    private let maskNode: ASImageNode
    private var snapshotView: UIView?
    
    private let listNode: ListView
    private var entries: [ThemeSettingsThemeEntry]?
    private var enqueuedTransitions: [ThemeSettingsThemeItemNodeTransition] = []
    private var initialized = false

    private var item: ThemeSettingsThemeItem?
    private var layoutParams: ListViewItemLayoutParams?

    var tag: ItemListItemTag? {
        return self.item?.tag
    }
    
    private var tapping = false

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
    
    private func enqueueTransition(_ transition: ThemeSettingsThemeItemNodeTransition) {
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
        options.insert(.Synchronous)
        
        var scrollToItem: ListViewScrollToItem?
        if !self.initialized || !self.tapping {
            if let index = transition.entries.firstIndex(where: { entry in
                return entry.theme.index == item.currentTheme.index
            }) {
                scrollToItem = ListViewScrollToItem(index: index, position: .bottom(-57.0), animated: false, curve: .Default(duration: 0.0), directionHint: .Down)
                self.initialized = true
            }
        }
        
        self.listNode.transaction(deleteIndices: transition.deletions, insertIndicesAndItems: transition.insertions, updateIndicesAndItems: transition.updates, options: options, scrollToItem: scrollToItem, updateSizeAndInsets: nil, updateOpaqueState: nil, completion: { _ in
        })
    }

    func asyncLayout() -> (_ item: ThemeSettingsThemeItem, _ params: ListViewItemLayoutParams, _ neighbors: ItemListNeighbors) -> (ListViewItemNodeLayout, () -> Void) {
        return { item, params, neighbors in
            let contentSize: CGSize
            let insets: UIEdgeInsets
            let separatorHeight = UIScreenPixel

            contentSize = CGSize(width: params.width, height: 116.0)
            insets = itemListNeighborsGroupedInsets(neighbors, params)

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
                            strongSelf.bottomStripeNode.isHidden = false
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
                    strongSelf.listNode.position = CGPoint(x: contentSize.width / 2.0, y: contentSize.height / 2.0 + 2.0)
                    strongSelf.listNode.transaction(deleteIndices: [], insertIndicesAndItems: [], updateIndicesAndItems: [], options: [.Synchronous], scrollToItem: nil, updateSizeAndInsets: ListViewUpdateSizeAndInsets(size: CGSize(width: contentSize.height, height: contentSize.width), insets: listInsets, duration: 0.0, curve: .Default(duration: nil)), stationaryItemRange: nil, updateOpaqueState: nil, completion: { _ in })
                    
                    var themes: [Int64: PresentationThemeReference] = [:]
                    for theme in item.allThemes {
                        themes[theme.index] = theme
                    }
                    
                    var entries: [ThemeSettingsThemeEntry] = []
                    var index: Int = 0
                    for theme in item.themes {
                        if case let .cloud(theme) = theme {
                            if !item.displayUnsupported && theme.theme.file == nil {
                                continue
                            }
                        }
                        let title = themeDisplayName(strings: item.strings, reference: theme)
                        let accentColor = item.themeSpecificAccentColors[theme.generalThemeReference.index]
                        /*if let customThemeIndex = accentColor?.themeIndex {
                            if let customTheme = themes[customThemeIndex] {
                                theme = customTheme
                            }
                            accentColor = nil
                        }*/

                        var themeWallpaper: TelegramWallpaper?
                        if case let .cloud(theme) = theme {
                            themeWallpaper = theme.resolvedWallpaper ?? theme.theme.settings?.first?.wallpaper
                        }

                        let customWallpaper = item.themeSpecificChatWallpapers[theme.generalThemeReference.index]
                        
                        let wallpaper = accentColor?.wallpaper ?? customWallpaper ?? themeWallpaper

                        var baseThemeReference = item.currentTheme.generalThemeReference
                        if let baseTheme = item.themePreferredBaseTheme[item.currentTheme.index] {
                            baseThemeReference = PresentationThemeReference.builtin(.init(baseTheme: baseTheme))
                        }
                        
                        let selected = item.currentTheme.index == theme.index || baseThemeReference == theme
                        entries.append(ThemeSettingsThemeEntry(index: index, themeReference: theme, title: title, accentColor: accentColor, selected: selected, theme: item.theme, wallpaper: wallpaper))
                        index += 1
                    }
                    
                    let action: (PresentationThemeReference) -> Void = { [weak self] themeReference in
                        if let strongSelf = self {
                            strongSelf.tapping = true
                            strongSelf.item?.updatedTheme(themeReference)
                            let _ = ensureThemeVisible(listNode: strongSelf.listNode, themeReference: themeReference, animated: true)
                            Queue.mainQueue().after(0.4) {
                                strongSelf.tapping = false
                            }
                        }
                    }
                    let previousEntries = strongSelf.entries ?? []
                    let crossfade = previousEntries.count != entries.count
                    let transition = preparedTransition(context: item.context, action: action, contextAction: item.contextAction, from: previousEntries, to: entries, crossfade: crossfade)
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
        guard self.snapshotView == nil else {
            return
        }
        
        if let snapshotView = self.containerNode.view.snapshotView(afterScreenUpdates: false) {
            self.view.insertSubview(snapshotView, aboveSubview: self.containerNode.view)
            self.snapshotView = snapshotView
        }
        
        self.listNode.forEachVisibleItemNode { node in
            if let node = node as? ThemeSettingsThemeItemIconNode {
                node.prepareCrossfadeTransition()
            }
        }
    }
    
    func animateCrossfadeTransition() {
        guard self.snapshotView?.layer.animationKeys()?.isEmpty ?? true else {
            return
        }
        
        var views: [UIView] = []
        if let snapshotView = self.snapshotView {
            views.append(snapshotView)
            self.snapshotView = nil
        }
        
        self.listNode.forEachVisibleItemNode { node in
            if let node = node as? ThemeSettingsThemeItemIconNode {
                if let snapshotView = node.snapshotView {
                    views.append(snapshotView)
                    node.snapshotView = nil
                }
            }
        }
        
        UIView.animate(withDuration: 0.3, animations: {
            for view in views {
                view.alpha = 0.0
            }
        }, completion: { _ in
            for view in views {
                view.removeFromSuperview()
            }
        })
    }
}
