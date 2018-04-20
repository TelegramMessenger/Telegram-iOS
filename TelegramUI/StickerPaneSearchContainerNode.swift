import Foundation
import AsyncDisplayKit
import Display
import SwiftSignalKit
import Postbox
import TelegramCore

import LegacyComponents
import TelegramUIPrivateModule

final class StickerPaneSearchInteraction {
    let open: (StickerPackCollectionInfo) -> Void
    let install: (StickerPackCollectionInfo) -> Void
    let sendSticker: (TelegramMediaFile) -> Void
    
    init(open: @escaping (StickerPackCollectionInfo) -> Void, install: @escaping (StickerPackCollectionInfo) -> Void, sendSticker: @escaping (TelegramMediaFile) -> Void) {
        self.open = open
        self.install = install
        self.sendSticker = sendSticker
    }
}

private enum StickerSearchEntryId: Equatable, Hashable {
    case sticker(String, Int64)
    case global(ItemCollectionId)
}

private enum StickerSearchEntry: Identifiable, Comparable {
    case sticker(index: Int, code: String, stickerItem: FoundStickerItem, theme: PresentationTheme)
    case global(index: Int, info: StickerPackCollectionInfo, topItems: [StickerPackItem], installed: Bool)
    
    var stableId: StickerSearchEntryId {
        switch self {
            case let .sticker(index, code, stickerItem, _):
                return .sticker(code, stickerItem.file.fileId.id)
            case let .global(_, info, _, _):
                return .global(info.id)
        }
    }
    
    static func ==(lhs: StickerSearchEntry, rhs: StickerSearchEntry) -> Bool {
        switch lhs {
            case let .sticker(lhsIndex, lhsCode, lhsStickerItem, lhsTheme):
                if case let .sticker(rhsIndex, rhsCode, rhsStickerItem, rhsTheme) = rhs {
                    if lhsIndex != rhsIndex {
                        return false
                    }
                    if lhsCode != rhsCode {
                        return false
                    }
                    if lhsStickerItem != rhsStickerItem {
                        return false
                    }
                    if lhsTheme !== rhsTheme {
                        return false
                    }
                    return true
                } else {
                    return false
                }
            case let .global(index, info, topItems, installed):
                if case .global(index, info, topItems, installed) = rhs {
                    return true
                } else {
                    return false
                }
        }
    }
    
    static func <(lhs: StickerSearchEntry, rhs: StickerSearchEntry) -> Bool {
        switch lhs {
            case let .sticker(lhsIndex, _, _, _):
                switch rhs {
                    case let .sticker(rhsIndex, _, _, _):
                        return lhsIndex < rhsIndex
                    default:
                        return true
            }
            case let .global(lhsIndex, _, _, _):
                switch rhs {
                    case .sticker:
                        return false
                    case let .global(rhsIndex, _, _, _):
                        return lhsIndex < rhsIndex
                }
        }
    }
    
    func item(account: Account, theme: PresentationTheme, strings: PresentationStrings, interaction: StickerPaneSearchInteraction, inputNodeInteraction: ChatMediaInputNodeInteraction) -> GridItem {
        switch self {
            case let .sticker(_, code, stickerItem, theme):
                return StickerPaneSearchStickerItem(account: account, code: code, stickerItem: stickerItem, inputNodeInteraction: inputNodeInteraction, theme: theme, selected: {
                    interaction.sendSticker(stickerItem.file)
                })
            case let .global(_, info, topItems, installed):
                return StickerPaneSearchGlobalItem(account: account, theme: theme, strings: strings, info: info, topItems: topItems, installed: installed, unread: false, open: {
                    interaction.open(info)
                }, install: {
                    interaction.install(info)
                })
        }
    }
}

private struct StickerPaneSearchGridTransition {
    let deletions: [Int]
    let insertions: [GridNodeInsertItem]
    let updates: [GridNodeUpdateItem]
    let updateFirstIndexInSectionOffset: Int?
    let stationaryItems: GridNodeStationaryItems
    let scrollToItem: GridNodeScrollToItem?
    let animated: Bool
}

private func preparedChatMediaInputGridEntryTransition(account: Account, theme: PresentationTheme, strings: PresentationStrings, from fromEntries: [StickerSearchEntry], to toEntries: [StickerSearchEntry], interaction: StickerPaneSearchInteraction, inputNodeInteraction: ChatMediaInputNodeInteraction) -> StickerPaneSearchGridTransition {
    let stationaryItems: GridNodeStationaryItems = .none
    let scrollToItem: GridNodeScrollToItem? = nil
    var animated = false
    animated = true
    
    let (deleteIndices, indicesAndItems, updateIndices) = mergeListsStableWithUpdates(leftList: fromEntries, rightList: toEntries)
    
    let deletions = deleteIndices
    let insertions = indicesAndItems.map { GridNodeInsertItem(index: $0.0, item: $0.1.item(account: account, theme: theme, strings: strings, interaction: interaction, inputNodeInteraction: inputNodeInteraction), previousIndex: $0.2) }
    let updates = updateIndices.map { GridNodeUpdateItem(index: $0.0, previousIndex: $0.2, item: $0.1.item(account: account, theme: theme, strings: strings, interaction: interaction, inputNodeInteraction: inputNodeInteraction)) }
    
    let firstIndexInSectionOffset = 0
    
    return StickerPaneSearchGridTransition(deletions: deletions, insertions: insertions, updates: updates, updateFirstIndexInSectionOffset: firstIndexInSectionOffset, stationaryItems: stationaryItems, scrollToItem: scrollToItem, animated: animated)
}

final class StickerPaneSearchContainerNode: ASDisplayNode {
    private let account: Account
    private let theme: PresentationTheme
    private let strings: PresentationStrings
    private let controllerInteraction: ChatControllerInteraction
    private let inputNodeInteraction: ChatMediaInputNodeInteraction
    
    private let backgroundNode: ASDisplayNode
    private let searchBar: StickerPaneSearchBarNode
    private let trendingPane: ChatMediaInputTrendingPane
    private let gridNode: GridNode
    
    private var validLayout: CGSize?
    
    private var enqueuedTransitions: [StickerPaneSearchGridTransition] = []
    
    private let searchDisposable = MetaDisposable()
    
    init(account: Account, theme: PresentationTheme, strings: PresentationStrings, controllerInteraction: ChatControllerInteraction, inputNodeInteraction: ChatMediaInputNodeInteraction, cancel: @escaping () -> Void) {
        self.account = account
        self.theme = theme
        self.strings = strings
        self.controllerInteraction = controllerInteraction
        self.inputNodeInteraction = inputNodeInteraction
        
        self.backgroundNode = ASDisplayNode()
        self.backgroundNode.backgroundColor = theme.chat.inputMediaPanel.stickersBackgroundColor
        
        self.trendingPane = ChatMediaInputTrendingPane(account: account, controllerInteraction: controllerInteraction)
        
        self.searchBar = StickerPaneSearchBarNode(theme: theme, strings: strings)
        
        self.gridNode = GridNode()
        
        self.gridNode.isHidden = true
        self.trendingPane.isHidden = false
        
        super.init()
        
        self.addSubnode(self.backgroundNode)
        self.addSubnode(self.trendingPane)
        self.addSubnode(self.gridNode)
        self.addSubnode(self.searchBar)
        
        self.gridNode.scrollView.alwaysBounceVertical = true
        self.gridNode.scrollingInitiated = { [weak self] in
            self?.searchBar.deactivate(clear: false)
        }
        
        self.searchBar.placeholderString = NSAttributedString(string: strings.Stickers_Search, font: Font.regular(14.0), textColor: theme.chat.inputMediaPanel.stickersSearchPlaceholderColor)
        self.searchBar.cancel = {
            cancel()
        }
        self.searchBar.activate()
        
        let interaction = StickerPaneSearchInteraction(open: { [weak self] info in
            if let strongSelf = self {
                strongSelf.controllerInteraction.presentController(StickerPackPreviewController(account: strongSelf.account, stickerPack: .id(id: info.id.id, accessHash: info.accessHash)), ViewControllerPresentationArguments(presentationAnimation: .modalSheet))
            }
        }, install: { [weak self] info in
            if let strongSelf = self {
                let _ = (loadedStickerPack(postbox: strongSelf.account.postbox, network: strongSelf.account.network, reference: .id(id: info.id.id, accessHash: info.accessHash))
                    |> mapToSignal { result -> Signal<Void, NoError> in
                        switch result {
                            case let .result(info, items, installed):
                                if installed {
                                    return .complete()
                                } else {
                                    return addStickerPackInteractively(postbox: strongSelf.account.postbox, info: info, items: items)
                                }
                            case .fetching:
                                break
                            case .none:
                                break
                        }
                        return .complete()
                    }).start()
            }
        }, sendSticker: { [weak self] file in
            if let strongSelf = self {
                strongSelf.controllerInteraction.sendSticker(file)
            }
        })
        
        let queue = Queue()
        let currentEntries = Atomic<[StickerSearchEntry]?>(value: nil)
        
        self.searchBar.textUpdated = { [weak self] text in
            guard let strongSelf = self else {
                return
            }
            
            let signal: Signal<([(String, FoundStickerItem)], FoundStickerSets, Bool)?, NoError>
            if !text.isEmpty {
                let stickers: Signal<[(String, FoundStickerItem)], NoError> = Signal { subscriber in
                    var signals: [Signal<(String, [FoundStickerItem]), NoError>] = []
                    for entry in TGEmojiSuggestions.suggestions(forQuery: text.lowercased()) {
                        if let entry = entry as? TGAlphacodeEntry {
                            signals.append(searchStickers(account: account, query: entry.emoji)
                                |> take(1)
                                |> map { (entry.emoji, $0) })
                        }
                    }
                    
                    return combineLatest(signals).start(next: { results in
                        var result: [(String, FoundStickerItem)] = []
                        for (emoji, stickers) in results {
                            for sticker in stickers {
                                result.append((emoji, sticker))
                            }
                        }
                        subscriber.putNext(result)
                    }, completed: {
                        subscriber.putCompletion()
                    })
                }
                
                let local = searchStickerSets(postbox: account.postbox, query: text)
                let remote = searchStickerSetsRemotely(network: account.network, query: text)
                let packs = local
                |> mapToSignal { result -> Signal<(FoundStickerSets, Bool), NoError> in
                    return .single((result, false))
                    |> then(remote |> map { remote -> (FoundStickerSets, Bool) in
                        return (result.merge(with: remote), true)
                    })
                }
                signal = combineLatest(stickers, packs)
                |> map { stickers, packs -> ([(String, FoundStickerItem)], FoundStickerSets, Bool)? in
                    return (stickers, packs.0, packs.1)
                }
                strongSelf.searchBar.activity = true
            } else {
                signal = .single(nil)
                strongSelf.searchBar.activity = false
            }
            
            strongSelf.searchDisposable.set((signal
            |> deliverOn(queue)).start(next: { result in
                Queue.mainQueue().async {
                    guard let strongSelf = self else {
                        return
                    }
                    
                    var entries: [StickerSearchEntry] = []
                    if let (stickers, packs, final) = result {
                        strongSelf.gridNode.isHidden = false
                        strongSelf.trendingPane.isHidden = true
                        
                        if final {
                            strongSelf.searchBar.activity = false
                        }
                        
                        var index = 0
                        for (code, sticker) in stickers {
                            entries.append(StickerSearchEntry.sticker(index: index, code: code, stickerItem: sticker, theme: theme))
                            index += 1
                        }
                        for (collectionId, info, _, installed) in packs.infos {
                            if let info = info as? StickerPackCollectionInfo {
                                var topItems: [StickerPackItem] = []
                                for e in packs.entries {
                                    if let item = e.item as? StickerPackItem {
                                        if e.index.collectionId == collectionId {
                                            topItems.append(item)
                                        }
                                    }
                                }
                                entries.append(.global(index: index, info: info, topItems: topItems, installed: installed))
                                index += 1
                            }
                        }
                    } else {
                        strongSelf.searchBar.activity = false
                        strongSelf.gridNode.isHidden = true
                        strongSelf.trendingPane.isHidden = false
                    }
                    
                    let previousEntries = currentEntries.swap(entries)
                    let transition = preparedChatMediaInputGridEntryTransition(account: account, theme: theme, strings: strings, from: previousEntries ?? [], to: entries, interaction: interaction, inputNodeInteraction: strongSelf.inputNodeInteraction)
                    strongSelf.enqueueTransition(transition)
                }
            }))
        }
    }
    
    deinit {
        self.searchDisposable.dispose()
    }
    
    func updateLayout(size: CGSize, transition: ContainedViewLayoutTransition) {
        let firstLayout = self.validLayout == nil
        self.validLayout = size
        transition.updateFrame(node: self.backgroundNode, frame: CGRect(origin: CGPoint(), size: size))
        
        let searchBarHeight: CGFloat = 48.0
        transition.updateFrame(node: self.searchBar, frame: CGRect(origin: CGPoint(), size: CGSize(width: size.width, height: searchBarHeight)))
        self.searchBar.updateLayout(boundingSize: CGSize(width: size.width, height: searchBarHeight), leftInset: 0.0, rightInset: 0.0, transition: transition)
        
        let contentFrame = CGRect(origin: CGPoint(x: 0.0, y: searchBarHeight), size: CGSize(width: size.width, height: size.height - searchBarHeight))
        
        self.gridNode.transaction(GridNodeTransaction(deleteItems: [], insertItems: [], updateItems: [], scrollToItem: nil, updateLayout: GridNodeUpdateLayout(layout: GridNodeLayout(size: contentFrame.size, insets: UIEdgeInsets(top: 4.0, left: 0.0, bottom: 4.0, right: 0.0), preloadSize: 300.0, type: .fixed(itemSize: CGSize(width: 75.0, height: 75.0), lineSpacing: 0.0)), transition: transition), itemTransition: .immediate, stationaryItems: .none, updateFirstIndexInSectionOffset: nil), completion: { _ in })
        
        transition.updateFrame(node: self.trendingPane, frame: contentFrame)
        self.trendingPane.updateLayout(size: contentFrame.size, topInset: 0.0, bottomInset: 0.0, transition: transition)
        
        transition.updateFrame(node: self.gridNode, frame: contentFrame)
        if firstLayout {
            while !self.enqueuedTransitions.isEmpty {
                self.dequeueTransition()
            }
        }
    }
    
    func deactivate() {
        self.searchBar.deactivate(clear: true)
    }
    
    func animateIn(from placeholder: StickerPaneSearchBarPlaceholderNode, transition: ContainedViewLayoutTransition) {
        self.backgroundNode.alpha = 0.0
        transition.updateAlpha(node: self.backgroundNode, alpha: 1.0, completion: { _ in
        })
        self.gridNode.alpha = 0.0
        transition.updateAlpha(node: self.gridNode, alpha: 1.0, completion: { _ in
        })
        self.trendingPane.alpha = 0.0
        transition.updateAlpha(node: self.trendingPane, alpha: 1.0, completion: { _ in
        })
        switch transition {
            case let .animated(duration, curve):
                self.searchBar.animateIn(from: placeholder, duration: duration, timingFunction: curve.timingFunction)
            case .immediate:
                break
        }
    }
    
    func animateOut(to placeholder: StickerPaneSearchBarPlaceholderNode, transition: ContainedViewLayoutTransition, completion: @escaping () -> Void) {
        self.searchBar.transitionOut(to: placeholder, transition: transition, completion: {
            completion()
        })
        transition.updateAlpha(node: self.backgroundNode, alpha: 0.0, completion: { _ in
        })
        transition.updateAlpha(node: self.gridNode, alpha: 0.0, completion: { _ in
        })
        transition.updateAlpha(node: self.trendingPane, alpha: 0.0, completion: { _ in
        })
        self.deactivate()
    }
    
    private func enqueueTransition(_ transition: StickerPaneSearchGridTransition) {
        enqueuedTransitions.append(transition)
        
        if self.validLayout != nil {
            while !self.enqueuedTransitions.isEmpty {
                self.dequeueTransition()
            }
        }
    }
    
    private func dequeueTransition() {
        if let transition = self.enqueuedTransitions.first {
            self.enqueuedTransitions.remove(at: 0)
            
            let itemTransition: ContainedViewLayoutTransition = .immediate
            self.gridNode.transaction(GridNodeTransaction(deleteItems: transition.deletions, insertItems: transition.insertions, updateItems: transition.updates, scrollToItem: transition.scrollToItem, updateLayout: nil, itemTransition: itemTransition, stationaryItems: .none, updateFirstIndexInSectionOffset: transition.updateFirstIndexInSectionOffset), completion: { _ in })
        }
    }
    
    func updatePreviewing(animated: Bool) {
        self.gridNode.forEachItemNode { itemNode in
            if let itemNode = itemNode as? StickerPaneSearchStickerItemNode {
                itemNode.updatePreviewing(animated: animated)
            }
        }
    }
    
    func itemAt(point: CGPoint) -> (ASDisplayNode, FoundStickerItem)? {
        if let itemNode = self.gridNode.itemNodeAtPoint(self.view.convert(point, to: self.gridNode.view)) as? StickerPaneSearchStickerItemNode, let stickerItem = itemNode.stickerItem {
            return (itemNode, stickerItem)
        }
        return nil
    }
}
