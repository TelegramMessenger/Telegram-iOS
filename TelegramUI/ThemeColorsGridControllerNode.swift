import Foundation
import Display
import AsyncDisplayKit
import Postbox
import TelegramCore
import SwiftSignalKit

final class ThemeColorsGridControllerInteraction {
    let openWallpaper: (TelegramWallpaper) -> Void
    
    init(openWallpaper: @escaping (TelegramWallpaper) -> Void) {
        self.openWallpaper = openWallpaper
    }
}

private struct ThemeColorsGridControllerEntry: Comparable, Identifiable {
    let index: Int
    let wallpaper: TelegramWallpaper
    let selected: Bool
    
    static func ==(lhs: ThemeColorsGridControllerEntry, rhs: ThemeColorsGridControllerEntry) -> Bool {
        return lhs.index == rhs.index && lhs.wallpaper == rhs.wallpaper && lhs.selected == rhs.selected
    }
    
    static func <(lhs: ThemeColorsGridControllerEntry, rhs: ThemeColorsGridControllerEntry) -> Bool {
        return lhs.index < rhs.index
    }
    
    var stableId: Int {
        return self.index
    }
    
    func item(account: Account, interaction: ThemeColorsGridControllerInteraction) -> ThemeColorsGridControllerItem {
        return ThemeColorsGridControllerItem(account: account, wallpaper: self.wallpaper, selected: self.selected, interaction: interaction)
    }
}

private struct ThemeColorsGridEntryTransition {
    let deletions: [Int]
    let insertions: [GridNodeInsertItem]
    let updates: [GridNodeUpdateItem]
    let updateFirstIndexInSectionOffset: Int?
    let stationaryItems: GridNodeStationaryItems
    let scrollToItem: GridNodeScrollToItem?
}

private func preparedThemeColorsGridEntryTransition(account: Account, from fromEntries: [ThemeColorsGridControllerEntry], to toEntries: [ThemeColorsGridControllerEntry], interaction: ThemeColorsGridControllerInteraction) -> ThemeColorsGridEntryTransition {
    let stationaryItems: GridNodeStationaryItems = .none
    let scrollToItem: GridNodeScrollToItem? = nil
    
    let (deleteIndices, indicesAndItems, updateIndices) = mergeListsStableWithUpdates(leftList: fromEntries, rightList: toEntries)
    
    let deletions = deleteIndices
    let insertions = indicesAndItems.map { GridNodeInsertItem(index: $0.0, item: $0.1.item(account: account, interaction: interaction), previousIndex: $0.2) }
    let updates = updateIndices.map { GridNodeUpdateItem(index: $0.0, previousIndex: $0.2, item: $0.1.item(account: account, interaction: interaction)) }
    
    return ThemeColorsGridEntryTransition(deletions: deletions, insertions: insertions, updates: updates, updateFirstIndexInSectionOffset: nil, stationaryItems: stationaryItems, scrollToItem: scrollToItem)
}

private func availableColors() -> [Int32] {
    return [
        0xffffff,
        0xd4dfea,
        0xb3cde1,
        0x6ab7ea,
        0x008dd0,
        0xd3e2da,
        0xc8e6c9,
        0xc5e1a5,
        0x61b06e,
        0xcdcfaf,
        0xa7a895,
        0x7c6f72,
        0xffd7ae,
        0xffb66d,
        0xde8751,
        0xefd5e0,
        0xdba1b9,
        0xffafaf,
        0xf16a60,
        0xe8bcea,
        0x9592ed,
        0xd9bc60,
        0xb17e49,
        0xd5cef7,
        0xdf506b,
        0x8bd2cc,
        0x3c847e,
        0x22612c,
        0x244d7c,
        0x3d3b85,
        0x65717d,
        0x18222d,
        0x000000
    ]
}

final class ThemeColorsGridControllerNode: ASDisplayNode {
    private let account: Account
    private var presentationData: PresentationData
    private var controllerInteraction: ThemeColorsGridControllerInteraction?
    private let present: (ViewController, Any?) -> Void
    
    let ready = ValuePromise<Bool>()
    
    private var backgroundNode: ASDisplayNode
    private var separatorNode: ASDisplayNode
    
    private let customColorItemNode: ItemListActionItemNode
    private var customColorItem: ItemListActionItem
    
    let gridNode: GridNode
    
    private var queuedTransitions: [ThemeColorsGridEntryTransition] = []
    private var validLayout: (ContainerViewLayout, CGFloat)?
    
    private var disposable: Disposable?
    
    init(account: Account, presentationData: PresentationData, present: @escaping (ViewController, Any?) -> Void) {
        self.account = account
        self.presentationData = presentationData
        self.present = present
        
        self.gridNode = GridNode()
        self.gridNode.showVerticalScrollIndicator = true
        
        self.backgroundNode = ASDisplayNode()
        self.backgroundNode.backgroundColor = presentationData.theme.list.blocksBackgroundColor
        
        self.separatorNode = ASDisplayNode()
        self.separatorNode.backgroundColor = presentationData.theme.list.itemBlocksSeparatorColor
        
        self.customColorItemNode = ItemListActionItemNode()
        self.customColorItem = ItemListActionItem(theme: presentationData.theme, title: presentationData.strings.WallpaperColors_SetCustomColor, kind: .generic, alignment: .natural, sectionId: 0, style: .blocks, action: {
        })
        
        super.init()
        
        self.setViewBlock({
            return UITracingLayerView()
        })
        
        self.backgroundColor = presentationData.theme.list.itemBlocksBackgroundColor
        
        self.gridNode.addSubnode(self.backgroundNode)
        self.gridNode.addSubnode(self.separatorNode)
        self.gridNode.addSubnode(self.customColorItemNode)
        self.addSubnode(self.gridNode)
        
        let previousEntries = Atomic<[ThemeColorsGridControllerEntry]?>(value: nil)
        
        let interaction = ThemeColorsGridControllerInteraction(openWallpaper: { [weak self] wallpaper in
            if let strongSelf = self {
                let entries = previousEntries.with { $0 }
                if let entries = entries, !entries.isEmpty {
                    let wallpapers = entries.map { $0.wallpaper }
                    let controller = WallpaperListPreviewController(account: account, source: .list(wallpapers: wallpapers, central: wallpaper, mode: nil))
                    strongSelf.present(controller, nil)
                }
            }
        })
        self.controllerInteraction = interaction
        
        let wallpapers = availableColors().map { TelegramWallpaper.color($0) }
        let transition = account.telegramApplicationContext.presentationData
        |> map { presentationData -> (ThemeColorsGridEntryTransition, Bool) in
            var entries: [ThemeColorsGridControllerEntry] = []
            var index = 0
            
            for wallpaper in wallpapers {
                let selected = presentationData.chatWallpaper == wallpaper
                entries.append(ThemeColorsGridControllerEntry(index: index, wallpaper: wallpaper, selected: selected))
                index += 1
            }
            
            let previous = previousEntries.swap(entries)
            return (preparedThemeColorsGridEntryTransition(account: account, from: previous ?? [], to: entries, interaction: interaction), previous == nil)
        }
        self.disposable = (transition |> deliverOnMainQueue).start(next: { [weak self] (transition, _) in
            if let strongSelf = self {
                strongSelf.enqueueTransition(transition)
            }
        })
    }
    
    deinit {
        self.disposable?.dispose()
    }
    
    func updatePresentationData(_ presentationData: PresentationData) {
        self.presentationData = presentationData
        
        self.backgroundColor = presentationData.theme.list.itemBlocksBackgroundColor
    
        self.customColorItem = ItemListActionItem(theme: presentationData.theme, title: presentationData.strings.WallpaperColors_SetCustomColor, kind: .generic, alignment: .natural, sectionId: 0, style: .blocks, action: { [weak self] in
        })
        
        if let (layout, navigationBarHeight) = self.validLayout {
            self.containerLayoutUpdated(layout, navigationBarHeight: navigationBarHeight, transition: .immediate)
        }
    }
    
    private func enqueueTransition(_ transition: ThemeColorsGridEntryTransition) {
        self.queuedTransitions.append(transition)
        if self.validLayout != nil {
            self.dequeueTransitions()
        }
    }
    
    private func dequeueTransitions() {
        while !self.queuedTransitions.isEmpty {
            let transition = self.queuedTransitions.removeFirst()
            self.gridNode.transaction(GridNodeTransaction(deleteItems: transition.deletions, insertItems: transition.insertions, updateItems: transition.updates, scrollToItem: transition.scrollToItem, updateLayout: nil, itemTransition: .immediate, stationaryItems: transition.stationaryItems, updateFirstIndexInSectionOffset: transition.updateFirstIndexInSectionOffset), completion: { [weak self] _ in
                if let strongSelf = self {
                    strongSelf.ready.set(true)
                }
            })
        }
    }
    
    func containerLayoutUpdated(_ layout: ContainerViewLayout, navigationBarHeight: CGFloat, transition: ContainedViewLayoutTransition) {
        let hadValidLayout = self.validLayout != nil
        
        var insets = layout.insets(options: [.input])
        insets.top += navigationBarHeight
        let scrollIndicatorInsets = insets
        
        let referenceImageSize = CGSize(width: 108.0, height: 108.0)
        
        let minSpacing: CGFloat = 8.0
        
        let imageCount = Int((layout.size.width - minSpacing * 2.0) / (referenceImageSize.width + minSpacing))
        
        let imageSize = referenceImageSize.aspectFilled(CGSize(width: floor((layout.size.width - CGFloat(imageCount + 1) * minSpacing) / CGFloat(imageCount)), height: referenceImageSize.height))
        
        let spacing = floor((layout.size.width - CGFloat(imageCount) * imageSize.width) / CGFloat(imageCount + 1))
        
        let makeColorLayout = self.customColorItemNode.asyncLayout()
        let params = ListViewItemLayoutParams(width: layout.size.width, leftInset: insets.left, rightInset: insets.right)
        let (colorLayout, colorApply) = makeColorLayout(self.customColorItem, params, ItemListNeighbors(top: .none, bottom: .none))
        colorApply()
    
        let buttonTopInset: CGFloat = 32.0
        let buttonHeight: CGFloat = 44.0
        let buttonBottomInset: CGFloat = 17.0
        
        let buttonInset: CGFloat = buttonTopInset + buttonHeight + buttonBottomInset
        let buttonOffset = buttonInset + 10.0
        
        transition.updateFrame(node: self.backgroundNode, frame: CGRect(origin: CGPoint(x: 0.0, y: -buttonOffset - 500.0), size: CGSize(width: layout.size.width, height: buttonInset + 500.0)))
        transition.updateFrame(node: self.separatorNode, frame: CGRect(origin: CGPoint(x: 0.0, y: -buttonOffset + buttonInset - UIScreenPixel), size: CGSize(width: layout.size.width, height: UIScreenPixel)))
        transition.updateFrame(node: self.customColorItemNode, frame: CGRect(origin: CGPoint(x: 0.0, y: -buttonOffset + buttonTopInset), size: colorLayout.contentSize))
    
        insets.top += spacing + buttonInset
        
        self.gridNode.transaction(GridNodeTransaction(deleteItems: [], insertItems: [], updateItems: [], scrollToItem: nil, updateLayout: GridNodeUpdateLayout(layout: GridNodeLayout(size: layout.size, insets: insets, scrollIndicatorInsets: scrollIndicatorInsets, preloadSize: 300.0, type: .fixed(itemSize: imageSize, fillWidth: nil, lineSpacing: spacing, itemSpacing: nil)), transition: transition), itemTransition: .immediate, stationaryItems: .none, updateFirstIndexInSectionOffset: nil), completion: { _ in })
        
        self.gridNode.frame = CGRect(x: 0.0, y: 0.0, width: layout.size.width, height: layout.size.height)
        
        self.validLayout = (layout, navigationBarHeight)
        if !hadValidLayout {
            self.dequeueTransitions()
        }
    }
    
    func scrollToTop() {
        self.gridNode.transaction(GridNodeTransaction(deleteItems: [], insertItems: [], updateItems: [], scrollToItem: GridNodeScrollToItem(index: 0, position: .top, transition: .animated(duration: 0.25, curve: .easeInOut), directionHint: .up, adjustForSection: true, adjustForTopInset: true), updateLayout: nil, itemTransition: .immediate, stationaryItems: .none, updateFirstIndexInSectionOffset: nil), completion: { _ in })
    }
}
