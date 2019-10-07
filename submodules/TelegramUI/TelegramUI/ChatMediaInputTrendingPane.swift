import Foundation
import UIKit
import AsyncDisplayKit
import Display
import Postbox
import TelegramCore
import SwiftSignalKit
import TelegramPresentationData
import MergeLists
import OverlayStatusController
import AccountContext
import StickerPackPreviewUI

final class TrendingPaneInteraction {
    let installPack: (ItemCollectionInfo) -> Void
    let openPack: (ItemCollectionInfo) -> Void
    let getItemIsPreviewed: (StickerPackItem) -> Bool
    
    init(installPack: @escaping (ItemCollectionInfo) -> Void, openPack: @escaping (ItemCollectionInfo) -> Void, getItemIsPreviewed: @escaping (StickerPackItem) -> Bool) {
        self.installPack = installPack
        self.openPack = openPack
        self.getItemIsPreviewed = getItemIsPreviewed
    }
}

private final class TrendingPaneEntry: Identifiable, Comparable {
    let index: Int
    let info: StickerPackCollectionInfo
    let theme: PresentationTheme
    let strings: PresentationStrings
    let topItems: [StickerPackItem]
    let installed: Bool
    let unread: Bool
    
    init(index: Int, info: StickerPackCollectionInfo, theme: PresentationTheme, strings: PresentationStrings, topItems: [StickerPackItem], installed: Bool, unread: Bool) {
        self.index = index
        self.info = info
        self.theme = theme
        self.strings = strings
        self.topItems = topItems
        self.installed = installed
        self.unread = unread
    }
    
    var stableId: ItemCollectionId {
        return self.info.id
    }
    
    static func ==(lhs: TrendingPaneEntry, rhs: TrendingPaneEntry) -> Bool {
        if lhs.index != rhs.index {
            return false
        }
        if lhs.info != rhs.info {
            return false
        }
        if lhs.theme !== rhs.theme {
            return false
        }
        if lhs.strings !== rhs.strings {
            return false
        }
        if lhs.topItems != rhs.topItems {
            return false
        }
        if lhs.installed != rhs.installed {
            return false
        }
        if lhs.unread != rhs.unread {
            return false
        }
        return true
    }
    
    static func <(lhs: TrendingPaneEntry, rhs: TrendingPaneEntry) -> Bool {
        return lhs.index < rhs.index
    }
    
    func item(account: Account, interaction: TrendingPaneInteraction) -> GridItem {
        let info = self.info
        return StickerPaneSearchGlobalItem(account: account, theme: self.theme, strings: self.strings, info: self.info, topItems: self.topItems, grid: true, installed: self.installed, unread: self.unread, open: {
            interaction.openPack(info)
        }, install: {
            interaction.installPack(info)
        }, getItemIsPreviewed: { item in
            return interaction.getItemIsPreviewed(item)
        })
    }
}

private struct TrendingPaneTransition {
    let deletions: [Int]
    let insertions: [GridNodeInsertItem]
    let updates: [GridNodeUpdateItem]
    let initial: Bool
}

private func preparedTransition(from fromEntries: [TrendingPaneEntry], to toEntries: [TrendingPaneEntry], account: Account, interaction: TrendingPaneInteraction, initial: Bool) -> TrendingPaneTransition {
    let (deleteIndices, indicesAndItems, updateIndices) = mergeListsStableWithUpdates(leftList: fromEntries, rightList: toEntries)
    
    let deletions = deleteIndices
    let insertions = indicesAndItems.map { GridNodeInsertItem(index: $0.0, item: $0.1.item(account: account, interaction: interaction), previousIndex: $0.2) }
    let updates = updateIndices.map { GridNodeUpdateItem(index: $0.0, previousIndex: $0.2, item: $0.1.item(account: account, interaction: interaction)) }
    
    return TrendingPaneTransition(deletions: deletions, insertions: insertions, updates: updates, initial: initial)
}

private func trendingPaneEntries(trendingEntries: [FeaturedStickerPackItem], installedPacks: Set<ItemCollectionId>, theme: PresentationTheme, strings: PresentationStrings) -> [TrendingPaneEntry] {
    var result: [TrendingPaneEntry] = []
    var index = 0
    for item in trendingEntries {
        if !installedPacks.contains(item.info.id) {
            result.append(TrendingPaneEntry(index: index, info: item.info, theme: theme, strings: strings, topItems: item.topItems, installed: installedPacks.contains(item.info.id), unread: item.unread))
            index += 1
        }
    }
    return result
}

final class ChatMediaInputTrendingPane: ChatMediaInputPane {
    private let context: AccountContext
    private let controllerInteraction: ChatControllerInteraction
    private let getItemIsPreviewed: (StickerPackItem) -> Bool
    
    let gridNode: GridNode
    
    private var enqueuedTransitions: [TrendingPaneTransition] = []
    private var validLayout: (CGSize, CGFloat)?
    
    private var disposable: Disposable?
    private var isActivated = false
    
    private let _ready = Promise<Void>()
    private var didSetReady = false
    var ready: Signal<Void, NoError> {
        return self._ready.get()
    }
    
    var scrollingInitiated: (() -> Void)?
    
    init(context: AccountContext, controllerInteraction: ChatControllerInteraction, getItemIsPreviewed: @escaping (StickerPackItem) -> Bool) {
        self.context = context
        self.controllerInteraction = controllerInteraction
        self.getItemIsPreviewed = getItemIsPreviewed
        
        self.gridNode = GridNode()
        
        super.init()
        
        self.addSubnode(self.gridNode)
        
        self.gridNode.scrollingInitiated = { [weak self] in
            self?.scrollingInitiated?()
        }
    }
    
    deinit {
        self.disposable?.dispose()
    }
    
    func activate() {
        if self.isActivated {
            return
        }
        self.isActivated = true
        
        let interaction = TrendingPaneInteraction(installPack: { [weak self] info in
            if let strongSelf = self, let info = info as? StickerPackCollectionInfo {
                let _ = (loadedStickerPack(postbox: strongSelf.context.account.postbox, network: strongSelf.context.account.network, reference: .id(id: info.id.id, accessHash: info.accessHash), forceActualized: false)
                |> mapToSignal { result -> Signal<Void, NoError> in
                    switch result {
                        case let .result(info, items, installed):
                            if installed {
                                return .complete()
                            } else {
                                return addStickerPackInteractively(postbox: strongSelf.context.account.postbox, info: info, items: items)
                            }
                        case .fetching:
                            break
                        case .none:
                            break
                    }
                    return .complete()
                } |> deliverOnMainQueue).start(completed: {
                    if let strongSelf = self {
                        let presentationData = strongSelf.context.sharedContext.currentPresentationData.with { $0 }
                        strongSelf.controllerInteraction.presentController(OverlayStatusController(theme: presentationData.theme, type: .success), nil)
                    }
                })
            }
        }, openPack: { [weak self] info in
            if let strongSelf = self, let info = info as? StickerPackCollectionInfo {
                strongSelf.view.window?.endEditing(true)
                let controller = StickerPackPreviewController(context: strongSelf.context, stickerPack: .id(id: info.id.id, accessHash: info.accessHash), parentNavigationController: strongSelf.controllerInteraction.navigationController())
                controller.sendSticker = { fileReference, sourceNode, sourceRect in
                    if let strongSelf = self {
                        return strongSelf.controllerInteraction.sendSticker(fileReference, false, sourceNode, sourceRect)
                    } else {
                        return false
                    }
                }
                strongSelf.controllerInteraction.presentController(controller, ViewControllerPresentationArguments(presentationAnimation: .modalSheet))
            }
        }, getItemIsPreviewed: self.getItemIsPreviewed)
        
        let previousEntries = Atomic<[TrendingPaneEntry]?>(value: nil)
        let context = self.context
        self.disposable = (combineLatest(context.account.viewTracker.featuredStickerPacks(), context.account.postbox.combinedView(keys: [.itemCollectionInfos(namespaces: [Namespaces.ItemCollection.CloudStickerPacks])]), context.sharedContext.presentationData)
        |> map { trendingEntries, view, presentationData -> TrendingPaneTransition in
            var installedPacks = Set<ItemCollectionId>()
            if let stickerPacksView = view.views[.itemCollectionInfos(namespaces: [Namespaces.ItemCollection.CloudStickerPacks])] as? ItemCollectionInfosView {
                if let packsEntries = stickerPacksView.entriesByNamespace[Namespaces.ItemCollection.CloudStickerPacks] {
                    for entry in packsEntries {
                        installedPacks.insert(entry.id)
                    }
                }
            }
            let entries = trendingPaneEntries(trendingEntries: trendingEntries, installedPacks: installedPacks, theme: presentationData.theme, strings: presentationData.strings)
            let previous = previousEntries.swap(entries)
            
            return preparedTransition(from: previous ?? [], to: entries, account: context.account, interaction: interaction, initial: previous == nil)
        }
        |> deliverOnMainQueue).start(next: { [weak self] transition in
            guard let strongSelf = self else {
                return
            }
            strongSelf.enqueueTransition(transition)
            if !strongSelf.didSetReady {
                strongSelf.didSetReady = true
                strongSelf._ready.set(.single(Void()))
            }
        })
    }
    
    override func updateLayout(size: CGSize, topInset: CGFloat, bottomInset: CGFloat, isExpanded: Bool, isVisible: Bool, deviceMetrics: DeviceMetrics, transition: ContainedViewLayoutTransition) {
        let hadValidLayout = self.validLayout != nil
        self.validLayout = (size, bottomInset)
        
        let itemSize: CGSize
        if case .tablet = deviceMetrics.type, size.width > 480.0 {
            itemSize = CGSize(width: floor(size.width / 2.0), height: 128.0)
        } else {
            itemSize = CGSize(width: size.width, height: 128.0)
        }
        
        self.gridNode.transaction(GridNodeTransaction(deleteItems: [], insertItems: [], updateItems: [], scrollToItem: nil, updateLayout: GridNodeUpdateLayout(layout: GridNodeLayout(size: size, insets: UIEdgeInsets(top: topInset, left: 0.0, bottom: bottomInset, right: 0.0), preloadSize: isVisible ? 300.0 : 0.0, type: .fixed(itemSize: itemSize, fillWidth: nil, lineSpacing: 0.0, itemSpacing: nil)), transition: transition), itemTransition: .immediate, stationaryItems: .none, updateFirstIndexInSectionOffset: nil), completion: { _ in })
        
        transition.updateFrame(node: self.gridNode, frame: CGRect(origin: CGPoint(), size: CGSize(width: size.width, height: size.height)))
        
//        transition.updateFrame(node: self.listNode, frame: CGRect(origin: CGPoint(), size: size))
//
//        var duration: Double = 0.0
//        var listViewCurve: ListViewAnimationCurve = .Default(duration: nil)
//        switch transition {
//            case .immediate:
//                break
//            case let .animated(animationDuration, animationCurve):
//                duration = animationDuration
//                switch animationCurve {
//                    case .easeInOut, .custom:
//                        listViewCurve = .Default(duration: duration)
//                    case .spring:
//                        listViewCurve = .Spring(duration: duration)
//                }
//        }
//
//        self.listNode.transaction(deleteIndices: [], insertIndicesAndItems: [], updateIndicesAndItems: [], options: [.Synchronous], scrollToItem: nil, updateSizeAndInsets: ListViewUpdateSizeAndInsets(size: size, insets: UIEdgeInsets(top: topInset, left: 0.0, bottom: bottomInset, right: 0.0), duration: duration, curve: listViewCurve), stationaryItemRange: nil, updateOpaqueState: nil, completion: { _ in })
        
        if !hadValidLayout {
            while !self.enqueuedTransitions.isEmpty {
                self.dequeueTransition()
            }
        }
    }
    
    private func enqueueTransition(_ transition: TrendingPaneTransition) {
        self.enqueuedTransitions.append(transition)
        
        if self.validLayout != nil {
            while !self.enqueuedTransitions.isEmpty {
                self.dequeueTransition()
            }
        }
    }
    
    override func willEnterHierarchy() {
        super.willEnterHierarchy()
        
        self.activate()
    }
    
    private func dequeueTransition() {
        if let transition = self.enqueuedTransitions.first {
            self.enqueuedTransitions.remove(at: 0)
            
            let itemTransition: ContainedViewLayoutTransition = .immediate
            self.gridNode.transaction(GridNodeTransaction(deleteItems: transition.deletions, insertItems: transition.insertions, updateItems: transition.updates, scrollToItem: nil, updateLayout: nil, itemTransition: itemTransition, stationaryItems: .none, updateFirstIndexInSectionOffset: nil, synchronousLoads: transition.initial), completion: { _ in })
        }
    }
    
    func itemAt(point: CGPoint) -> (ASDisplayNode, StickerPackItem)? {
        let localPoint = self.view.convert(point, to: self.gridNode.view)
        var resultNode: StickerPaneSearchGlobalItemNode?
        self.gridNode.forEachItemNode { itemNode in
            if itemNode.frame.contains(localPoint), let itemNode = itemNode as? StickerPaneSearchGlobalItemNode {
                resultNode = itemNode
            }
        }
        if let resultNode = resultNode {
            return resultNode.itemAt(point: self.gridNode.view.convert(localPoint, to: resultNode.view))
        }
        return nil
    }
    
    func updatePreviewing(animated: Bool) {
        self.gridNode.forEachItemNode { itemNode in
            if let itemNode = itemNode as? StickerPaneSearchGlobalItemNode {
                itemNode.updatePreviewing(animated: animated)
            }
        }
    }
}
