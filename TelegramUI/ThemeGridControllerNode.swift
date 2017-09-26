import Foundation
import Display
import AsyncDisplayKit
import Postbox
import TelegramCore
import SwiftSignalKit

final class ThemeGridControllerInteraction {
    let openWallpaper: (TelegramWallpaper) -> Void
    
    init(openWallpaper: @escaping (TelegramWallpaper) -> Void) {
        self.openWallpaper = openWallpaper
    }
}

private struct ThemeGridControllerEntry: Comparable, Identifiable {
    let index: Int
    let wallpaper: TelegramWallpaper
    
    static func ==(lhs: ThemeGridControllerEntry, rhs: ThemeGridControllerEntry) -> Bool {
        return lhs.index == rhs.index && lhs.wallpaper == rhs.wallpaper
    }
    
    static func <(lhs: ThemeGridControllerEntry, rhs: ThemeGridControllerEntry) -> Bool {
        return lhs.index < rhs.index
    }
    
    var stableId: Int {
        return self.index
    }
    
    func item(account: Account, interaction: ThemeGridControllerInteraction) -> ThemeGridControllerItem {
        return ThemeGridControllerItem(account: account, wallpaper: self.wallpaper, interaction: interaction)
    }
}

private struct ThemeGridEntryTransition {
    let deletions: [Int]
    let insertions: [GridNodeInsertItem]
    let updates: [GridNodeUpdateItem]
    let updateFirstIndexInSectionOffset: Int?
    let stationaryItems: GridNodeStationaryItems
    let scrollToItem: GridNodeScrollToItem?
}

private func preparedThemeGridEntryTransition(account: Account, from fromEntries: [ThemeGridControllerEntry], to toEntries: [ThemeGridControllerEntry], interaction: ThemeGridControllerInteraction) -> ThemeGridEntryTransition {
    let stationaryItems: GridNodeStationaryItems = .none
    let scrollToItem: GridNodeScrollToItem? = nil
    
    let (deleteIndices, indicesAndItems, updateIndices) = mergeListsStableWithUpdates(leftList: fromEntries, rightList: toEntries)
    
    let deletions = deleteIndices
    let insertions = indicesAndItems.map { GridNodeInsertItem(index: $0.0, item: $0.1.item(account: account, interaction: interaction), previousIndex: $0.2) }
    let updates = updateIndices.map { GridNodeUpdateItem(index: $0.0, previousIndex: $0.2, item: $0.1.item(account: account, interaction: interaction)) }
    
    return ThemeGridEntryTransition(deletions: deletions, insertions: insertions, updates: updates, updateFirstIndexInSectionOffset: nil, stationaryItems: stationaryItems, scrollToItem: scrollToItem)
}

final class ThemeGridControllerNode: ASDisplayNode {
    private let account: Account
    private var presentationData: PresentationData
    
    private let present: (ViewController, Any?) -> Void
    
    let ready = ValuePromise<Bool>()
    
    private let gridNode: GridNode
    private var queuedTransitions: [ThemeGridEntryTransition] = []
    private var validLayout: (ContainerViewLayout, CGFloat)?
    
    private var disposable: Disposable?
    
    init(account: Account, presentationData: PresentationData, present: @escaping (ViewController, Any?) -> Void) {
        self.account = account
        self.presentationData = presentationData
        self.present = present
        
        self.gridNode = GridNode()
        self.gridNode.showVerticalScrollIndicator = true
        
        super.init()
        
        self.setViewBlock({
            return UITracingLayerView()
        })
        
        self.backgroundColor = presentationData.theme.list.itemBackgroundColor
        
        self.addSubnode(self.gridNode)
        
        let previousEntries = Atomic<[ThemeGridControllerEntry]?>(value: nil)
        
        let interaction = ThemeGridControllerInteraction(openWallpaper: { [weak self] wallpaper in
            if let strongSelf = self {
                let entries = previousEntries.with { $0 }
                if let entries = entries, !entries.isEmpty {
                    let wallpapers = entries.map { $0.wallpaper }
                    let controller = ThemeGalleryController(account: account, wallpapers: wallpapers, at: wallpaper)
                    strongSelf.present(controller, ThemePreviewControllerPresentationArguments(transitionArguments: { entry -> GalleryTransitionArguments? in
                        return nil
                    }))
                }
            }
        })
        
        let transition = telegramWallpapers(account: account)
            |> map { wallpapers -> (ThemeGridEntryTransition, Bool) in
                var entries: [ThemeGridControllerEntry] = []
                var index = 0
                for item in wallpapers {
                    entries.append(ThemeGridControllerEntry(index: index, wallpaper: item))
                    index += 1
                }
                let previous = previousEntries.swap(entries)
                return (preparedThemeGridEntryTransition(account: account, from: previous ?? [], to: entries, interaction: interaction), previous == nil)
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
        
        self.backgroundColor = presentationData.theme.list.itemBackgroundColor
    }
    
    private func enqueueTransition(_ transition: ThemeGridEntryTransition) {
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
        var insets = layout.insets(options: [.input])
        insets.top += navigationBarHeight
        let scrollIndicatorInsets = insets
        
        let referenceImageSize = CGSize(width: 108.0, height: 163.0)
        
        let minSpacing: CGFloat = 10.0
        
        let imageCount = Int((layout.size.width - minSpacing * 2.0) / (referenceImageSize.width + minSpacing))
        
        let imageSize = referenceImageSize.aspectFilled(CGSize(width: floor((layout.size.width - CGFloat(imageCount + 1) * minSpacing) / CGFloat(imageCount)), height: referenceImageSize.height))
        
        let spacing = floor((layout.size.width - CGFloat(imageCount) * imageSize.width) / CGFloat(imageCount + 1))
        
        insets.top += spacing
        
        self.gridNode.transaction(GridNodeTransaction(deleteItems: [], insertItems: [], updateItems: [], scrollToItem: nil, updateLayout: GridNodeUpdateLayout(layout: GridNodeLayout(size: layout.size, insets: insets, scrollIndicatorInsets: scrollIndicatorInsets, preloadSize: 300.0, type: .fixed(itemSize: imageSize, lineSpacing: spacing)), transition: .immediate), itemTransition: .immediate, stationaryItems: .none, updateFirstIndexInSectionOffset: nil), completion: { _ in })
        
        self.gridNode.frame = CGRect(x: 0.0, y: 0.0, width: layout.size.width, height: layout.size.height)
        
        let dequeue = self.validLayout == nil
        self.validLayout = (layout, navigationBarHeight)
        if dequeue {
            self.dequeueTransitions()
        }
    }
    
    func scrollToTop() {
        self.gridNode.transaction(GridNodeTransaction(deleteItems: [], insertItems: [], updateItems: [], scrollToItem: GridNodeScrollToItem(index: 0, position: .top, transition: .animated(duration: 0.25, curve: .easeInOut), directionHint: .up, adjustForSection: true, adjustForTopInset: true), updateLayout: nil, itemTransition: .immediate, stationaryItems: .none, updateFirstIndexInSectionOffset: nil), completion: { _ in })
    }
}
