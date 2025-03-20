import Foundation
import UIKit
import AsyncDisplayKit
import Display
import SwiftSignalKit
import Postbox
import TelegramCore
import TelegramPresentationData
import PresentationDataUtils
import LegacyComponents
import MergeLists
import AccountContext
import StickerPeekUI
import Emoji
import AppBundle
import OverlayStatusController
import UndoUI
import ChatControllerInteraction
import FeaturedStickersScreen
import ChatPresentationInterfaceState
import StickerResources

private enum StickerSearchEntryId: Equatable, Hashable {
    case sticker(String?, Int64)
    case global(ItemCollectionId)
}

private enum StickerSearchEntry: Identifiable, Comparable {
    case sticker(index: Int, code: String?, stickerItem: FoundStickerItem, theme: PresentationTheme)
    case global(index: Int, info: StickerPackCollectionInfo, topItems: [StickerPackItem], installed: Bool, topSeparator: Bool)
    
    var stableId: StickerSearchEntryId {
        switch self {
        case let .sticker(_, code, stickerItem, _):
            return .sticker(code, stickerItem.file.fileId.id)
        case let .global(_, info, _, _, _):
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
        case let .global(index, info, topItems, installed, topSeparator):
            if case .global(index, info, topItems, installed, topSeparator) = rhs {
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
        case let .global(lhsIndex, _, _, _, _):
            switch rhs {
            case .sticker:
                return false
            case let .global(rhsIndex, _, _, _, _):
                return lhsIndex < rhsIndex
            }
        }
    }
    
    func item(context: AccountContext, theme: PresentationTheme, strings: PresentationStrings, interaction: StickerPaneSearchInteraction, inputNodeInteraction: ChatMediaInputNodeInteraction) -> GridItem {
        switch self {
        case let .sticker(_, code, stickerItem, theme):
            return StickerPaneSearchStickerItem(context: context, theme: theme, code: code, stickerItem: stickerItem, inputNodeInteraction: inputNodeInteraction, selected: { node, layer, rect in
                interaction.sendSticker(.standalone(media: stickerItem.file), node.view, layer, rect)
            })
        case let .global(_, info, topItems, installed, topSeparator):
            let itemContext = StickerPaneSearchGlobalItemContext()
            itemContext.canPlayMedia = true
            return StickerPaneSearchGlobalItem(context: context, theme: theme, strings: strings, listAppearance: false, info: StickerPackCollectionInfo.Accessor(info), topItems: topItems, topSeparator: topSeparator, regularInsets: false, installed: installed, unread: false, open: {
                interaction.open(info)
            }, install: {
                interaction.install(info, topItems, !installed)
            }, getItemIsPreviewed: { item in
                return interaction.getItemIsPreviewed(item)
            }, itemContext: itemContext)
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

private func preparedChatMediaInputGridEntryTransition(context: AccountContext, theme: PresentationTheme, strings: PresentationStrings, from fromEntries: [StickerSearchEntry], to toEntries: [StickerSearchEntry], interaction: StickerPaneSearchInteraction, inputNodeInteraction: ChatMediaInputNodeInteraction) -> StickerPaneSearchGridTransition {
    let stationaryItems: GridNodeStationaryItems = .none
    let scrollToItem: GridNodeScrollToItem? = nil
    var animated = false
    animated = true
    
    let (deleteIndices, indicesAndItems, updateIndices) = mergeListsStableWithUpdates(leftList: fromEntries, rightList: toEntries)
    
    let deletions = deleteIndices
    let insertions = indicesAndItems.map { GridNodeInsertItem(index: $0.0, item: $0.1.item(context: context, theme: theme, strings: strings, interaction: interaction, inputNodeInteraction: inputNodeInteraction), previousIndex: $0.2) }
    let updates = updateIndices.map { GridNodeUpdateItem(index: $0.0, previousIndex: $0.2, item: $0.1.item(context: context, theme: theme, strings: strings, interaction: interaction, inputNodeInteraction: inputNodeInteraction)) }
    
    let firstIndexInSectionOffset = 0
    
    return StickerPaneSearchGridTransition(deletions: deletions, insertions: insertions, updates: updates, updateFirstIndexInSectionOffset: firstIndexInSectionOffset, stationaryItems: stationaryItems, scrollToItem: scrollToItem, animated: animated)
}

final class StickerPaneSearchContentNode: ASDisplayNode, PaneSearchContentNode {
    private let context: AccountContext
    private let interaction: ChatEntityKeyboardInputNode.Interaction
    private let inputNodeInteraction: ChatMediaInputNodeInteraction
    private var searchInteraction: StickerPaneSearchInteraction?
    
    private var theme: PresentationTheme
    private var strings: PresentationStrings
    
    private let trendingPane: ChatMediaInputTrendingPane
    private let gridNode: GridNode
    private let notFoundNode: ASImageNode
    private let notFoundLabel: ImmediateTextNode
    
    private var validLayout: CGSize?
    
    private var enqueuedTransitions: [StickerPaneSearchGridTransition] = []
    
    private let searchDisposable = MetaDisposable()
    
    private let queue = Queue()
    private let currentEntries = Atomic<[StickerSearchEntry]?>(value: nil)
    private let currentRemotePacks = Atomic<FoundStickerSets?>(value: nil)
    
    private let _ready = Promise<Void>()
    var ready: Signal<Void, NoError> {
        return self._ready.get()
    }
    
    var deactivateSearchBar: (() -> Void)?
    var updateActivity: ((Bool) -> Void)?
    
    private let installDisposable = MetaDisposable()
    
    init(context: AccountContext, theme: PresentationTheme, strings: PresentationStrings, interaction: ChatEntityKeyboardInputNode.Interaction, inputNodeInteraction: ChatMediaInputNodeInteraction, stickerActionTitle: String?) {
        self.context = context
        self.interaction = interaction
        self.inputNodeInteraction = inputNodeInteraction
        
        self.theme = theme
        self.strings = strings
        
        let trendingPaneInteraction = ChatMediaInputTrendingPane.Interaction(
            sendSticker: interaction.sendSticker,
            presentController: interaction.presentController,
            getNavigationController: interaction.getNavigationController
        )
        
        self.trendingPane = ChatMediaInputTrendingPane(context: context, forceTheme: theme, interaction: trendingPaneInteraction, getItemIsPreviewed: { [weak inputNodeInteraction] item in
            return inputNodeInteraction?.previewedStickerPackItemFile?.id == item.file.id
        }, isPane: false)
        self.trendingPane.stickerActionTitle = stickerActionTitle
        
        self.gridNode = GridNode()
        
        self.notFoundNode = ASImageNode()
        self.notFoundNode.displayWithoutProcessing = true
        self.notFoundNode.displaysAsynchronously = false
        self.notFoundNode.clipsToBounds = false
        
        self.notFoundLabel = ImmediateTextNode()
        self.notFoundLabel.displaysAsynchronously = false
        self.notFoundLabel.isUserInteractionEnabled = false
        self.notFoundNode.addSubnode(self.notFoundLabel)
        
        self.gridNode.isHidden = true
        self.trendingPane.isHidden = false
        self.notFoundNode.isHidden = true
        
        super.init()
        
        self.addSubnode(self.trendingPane)
        self.addSubnode(self.gridNode)
        self.addSubnode(self.notFoundNode)
        
        self.gridNode.scrollView.alwaysBounceVertical = true
        self.gridNode.scrollingInitiated = { [weak self] in
            self?.deactivateSearchBar?()
        }
        
        self.trendingPane.scrollingInitiated = { [weak self] in
            self?.deactivateSearchBar?()
        }
        
        self.searchInteraction = StickerPaneSearchInteraction(open: { [weak self] info in
            if let strongSelf = self {
                strongSelf.view.window?.endEditing(true)
                let packReference: StickerPackReference = .id(id: info.id.id, accessHash: info.accessHash)
                
                let presentationData = strongSelf.context.sharedContext.currentPresentationData.with { $0 }.withUpdated(theme: theme)
                
                let controller = strongSelf.context.sharedContext.makeStickerPackScreen(
                    context: strongSelf.context,
                    updatedPresentationData: (presentationData, .single(presentationData)),
                    mainStickerPack: packReference,
                    stickerPacks: [packReference],
                    loadedStickerPacks: [],
                    actionTitle: stickerActionTitle,
                    isEditing: false,
                    expandIfNeeded: false,
                    parentNavigationController: strongSelf.interaction.getNavigationController(),
                    sendSticker: { [weak self] fileReference, sourceView, sourceRect in
                        if let strongSelf = self {
                            return strongSelf.interaction.sendSticker(fileReference, false, false, nil, false, sourceView, sourceRect, nil, [])
                        } else {
                            return false
                        }
                    },
                    actionPerformed: nil
                )
                strongSelf.interaction.presentController(controller, nil)
            }
        }, install: { [weak self] info, items, install in
            guard let strongSelf = self else {
                return
            }
            let context = strongSelf.context
            if install {
                var installSignal = strongSelf.context.engine.stickers.loadedStickerPack(reference: .id(id: info.id.id, accessHash: info.accessHash), forceActualized: false)
                |> mapToSignal { result -> Signal<(StickerPackCollectionInfo, [StickerPackItem]), NoError> in
                    switch result {
                    case let .result(info, items, installed):
                        let info = info._parse()
                        if installed {
                            return .complete()
                        } else {
                            return preloadedStickerPackThumbnail(account: context.account, info: StickerPackCollectionInfo.Accessor(info), items: items)
                            |> filter { $0 }
                            |> ignoreValues
                            |> then(
                                context.engine.stickers.addStickerPackInteractively(info: info, items: items)
                                |> ignoreValues
                            )
                            |> mapToSignal { _ -> Signal<(StickerPackCollectionInfo, [StickerPackItem]), NoError> in
                            }
                            |> then(.single((info, items)))
                        }
                    case .fetching:
                        break
                    case .none:
                        break
                    }
                    return .complete()
                }
                |> deliverOnMainQueue
                
                let context = strongSelf.context
                var cancelImpl: (() -> Void)?
                let progressSignal = Signal<Never, NoError> { subscriber in
                    let presentationData = context.sharedContext.currentPresentationData.with { $0 }.withUpdated(theme: theme)
                    let controller = OverlayStatusController(theme: presentationData.theme, type: .loading(cancelled: {
                        cancelImpl?()
                    }))
                    self?.interaction.presentController(controller, nil)
                    return ActionDisposable { [weak controller] in
                        Queue.mainQueue().async() {
                            controller?.dismiss()
                        }
                    }
                }
                |> runOn(Queue.mainQueue())
                |> delay(0.12, queue: Queue.mainQueue())
                let progressDisposable = progressSignal.start()
                
                installSignal = installSignal
                |> afterDisposed {
                    Queue.mainQueue().async {
                        progressDisposable.dispose()
                    }
                }
                cancelImpl = {
                    self?.installDisposable.set(nil)
                }
                    
                strongSelf.installDisposable.set(installSignal.start(next: { info, items in
                    guard let strongSelf = self else {
                        return
                    }
                    
                    var animateInAsReplacement = false
                    if let navigationController = strongSelf.interaction.getNavigationController() {
                        for controller in navigationController.overlayControllers {
                            if let controller = controller as? UndoOverlayController {
                                controller.dismissWithCommitActionAndReplacementAnimation()
                                animateInAsReplacement = true
                            }
                        }
                    }
                    
                    let presentationData = strongSelf.context.sharedContext.currentPresentationData.with { $0 }.withUpdated(theme: theme)
                    strongSelf.interaction.getNavigationController()?.presentOverlay(controller: UndoOverlayController(presentationData: presentationData, content: .stickersModified(title: presentationData.strings.StickerPackActionInfo_AddedTitle, text: presentationData.strings.StickerPackActionInfo_AddedText(info.title).string, undo: false, info: info, topItem: items.first, context: strongSelf.context), elevatedLayout: false, animateInAsReplacement: animateInAsReplacement, action: { _ in
                        return true
                    }))
                }))
            } else {
                let _ = (context.engine.stickers.removeStickerPackInteractively(id: info.id, option: .delete)
                |> deliverOnMainQueue).start(next: { _ in
                })
            }
        }, sendSticker: { [weak self] file, sourceView, sourceLayer, sourceRect in
            if let self {
                let sourceRect = sourceView.convert(sourceRect, to: self.view)
                let _ = self.interaction.sendSticker(file, false, false, nil, false, self.view, sourceRect, sourceLayer, [])
            }
        }, getItemIsPreviewed: { item in
            return inputNodeInteraction.previewedStickerPackItemFile?.id == item.file.id
        })
        
        self._ready.set(self.trendingPane.ready)
        self.trendingPane.activate()
    
        self.updateThemeAndStrings(theme: theme, strings: strings)
    }
    
    deinit {
        self.searchDisposable.dispose()
        self.installDisposable.dispose()
    }
    
    func updateText(_ text: String, languageCode: String?) {
        let signal: Signal<([(String?, FoundStickerItem)], FoundStickerSets, Bool, FoundStickerSets?)?, NoError>
        if !text.isEmpty {
            let context = self.context
            let stickers: Signal<([(String?, FoundStickerItem)], Bool), NoError> = Signal { subscriber in
                var signals: Signal<[Signal<(String?, [FoundStickerItem], Bool), NoError>], NoError> = .single([])
                
                let query = text.trimmingCharacters(in: .whitespacesAndNewlines)
                if query.isSingleEmoji {
                    signals = .single([context.engine.stickers.searchStickers(query: nil, emoticon: [text.basicEmoji.0])
                    |> map { (nil, $0.items, $0.isFinalResult) }])
                } else if query.count > 1, let languageCode = languageCode, !languageCode.isEmpty && languageCode != "emoji" {
                    var signal = context.engine.stickers.searchEmojiKeywords(inputLanguageCode: languageCode, query: query.lowercased(), completeMatch: query.count < 3)
                    if !languageCode.lowercased().hasPrefix("en") {
                        signal = signal
                        |> mapToSignal { keywords in
                            return .single(keywords)
                            |> then(
                                context.engine.stickers.searchEmojiKeywords(inputLanguageCode: "en-US", query: query.lowercased(), completeMatch: query.count < 3)
                                |> map { englishKeywords in
                                    return keywords + englishKeywords
                                }
                            )
                        }
                    }
                    signals = signal
                    |> map { keywords -> [Signal<(String?, [FoundStickerItem], Bool), NoError>] in
                        let emoticon = keywords.flatMap { $0.emoticons }.map { $0.basicEmoji.0 }
                        return [context.engine.stickers.searchStickers(query: query, emoticon: emoticon, inputLanguageCode: languageCode)
                        |> map { (nil, $0.items, $0.isFinalResult) }]
                    }
                }
                
                return (signals
                |> mapToSignal { signals in
                    return combineLatest(signals)
                }).start(next: { results in
                    var result: [(String?, FoundStickerItem)] = []
                    var allAreFinal = true
                    for (emoji, stickers, isFinal) in results {
                        for sticker in stickers {
                            result.append((emoji, sticker))
                        }
                        if !isFinal {
                            allAreFinal = false
                        }
                    }
                    subscriber.putNext((result, allAreFinal))
                }, completed: {
//                    subscriber.putCompletion()
                })
            }
            
            let local = context.engine.stickers.searchStickerSets(query: text)
            let remote = context.engine.stickers.searchStickerSetsRemotely(query: text)
            |> delay(0.2, queue: Queue.mainQueue())
            let rawPacks = local
            |> mapToSignal { result -> Signal<(FoundStickerSets, Bool, FoundStickerSets?), NoError> in
                var localResult = result
                if let currentRemote = self.currentRemotePacks.with ({ $0 }) {
                    localResult = localResult.merge(with: currentRemote)
                }
                return .single((localResult, false, nil))
                |> then(
                    remote
                    |> map { remote -> (FoundStickerSets, Bool, FoundStickerSets?) in
                        return (result.merge(with: remote), true, remote)
                    }
                )
            }
            
            let installedPackIds = context.account.postbox.combinedView(keys: [.itemCollectionInfos(namespaces: [Namespaces.ItemCollection.CloudStickerPacks])])
            |> map { view -> Set<ItemCollectionId> in
                var installedPacks = Set<ItemCollectionId>()
                if let stickerPacksView = view.views[.itemCollectionInfos(namespaces: [Namespaces.ItemCollection.CloudStickerPacks])] as? ItemCollectionInfosView {
                    if let packsEntries = stickerPacksView.entriesByNamespace[Namespaces.ItemCollection.CloudStickerPacks] {
                        for entry in packsEntries {
                            installedPacks.insert(entry.id)
                        }
                    }
                }
                return installedPacks
            }
            |> distinctUntilChanged
            let packs = combineLatest(rawPacks, installedPackIds)
            |> map { packs, installedPackIds -> (FoundStickerSets, Bool, FoundStickerSets?) in
                var (localPacks, completed, remotePacks) = packs
                
                for i in 0 ..< localPacks.infos.count {
                    let installed = installedPackIds.contains(localPacks.infos[i].0)
                    if installed != localPacks.infos[i].3 {
                        localPacks.infos[i].3 = installed
                    }
                }
                
                if remotePacks != nil {
                    for i in 0 ..< remotePacks!.infos.count {
                        let installed = installedPackIds.contains(remotePacks!.infos[i].0)
                        if installed != remotePacks!.infos[i].3 {
                            remotePacks!.infos[i].3 = installed
                        }
                    }
                }
                
                return (localPacks, completed, remotePacks)
            }
            
            signal = combineLatest(stickers, packs)
            |> map { stickers, packs -> ([(String?, FoundStickerItem)], FoundStickerSets, Bool, FoundStickerSets?)? in
                return (stickers.0, packs.0, packs.1 && stickers.1, packs.2)
            }
            self.updateActivity?(true)
        } else {
            signal = .single(nil)
            self.updateActivity?(false)
        }
        
        self.searchDisposable.set((signal
        |> deliverOn(self.queue)).start(next: { [weak self] result in
            Queue.mainQueue().async {
                guard let strongSelf = self, let interaction = strongSelf.searchInteraction else {
                    return
                }
                
                var entries: [StickerSearchEntry] = []
                if let (stickers, packs, final, remote) = result {
                    if let remote = remote {
                        let _ = strongSelf.currentRemotePacks.swap(remote)
                    }
                    strongSelf.gridNode.isHidden = false
                    strongSelf.trendingPane.isHidden = true
                    
                    if final {
                        strongSelf.updateActivity?(false)
                    }
                    
                    var index = 0
                    var existingStickerIds = Set<MediaId>()
                    var previousCode: String?
                    for (code, sticker) in stickers {
                        if let id = sticker.file.id, !existingStickerIds.contains(id) {
                            entries.append(.sticker(index: index, code: code != previousCode ? code : nil, stickerItem: sticker, theme: strongSelf.theme))
                            index += 1
                            
                            previousCode = code
                            existingStickerIds.insert(id)
                        }
                    }
                    var isFirstGlobal = true
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
                            entries.append(.global(index: index, info: info, topItems: topItems, installed: installed, topSeparator: !isFirstGlobal))
                            isFirstGlobal = false
                            index += 1
                        }
                    }
                    
                    if final || !entries.isEmpty {
                        strongSelf.notFoundNode.isHidden = !entries.isEmpty
                    }
                } else {
                    let _ = strongSelf.currentRemotePacks.swap(nil)
                    strongSelf.updateActivity?(false)
                    strongSelf.gridNode.isHidden = true
                    strongSelf.notFoundNode.isHidden = true
                    strongSelf.trendingPane.isHidden = false
                }
                
                let previousEntries = strongSelf.currentEntries.swap(entries)
                let transition = preparedChatMediaInputGridEntryTransition(context: strongSelf.context, theme: strongSelf.theme, strings: strongSelf.strings, from: previousEntries ?? [], to: entries, interaction: interaction, inputNodeInteraction: strongSelf.inputNodeInteraction)
                strongSelf.enqueueTransition(transition)
            }
        }))
    }
    
    func updateThemeAndStrings(theme: PresentationTheme, strings: PresentationStrings) {
        self.notFoundNode.image = generateTintedImage(image: UIImage(bundleImageName: "Chat/Input/Media/StickersNotFoundIcon"), color: theme.list.freeMonoIconColor)
        self.notFoundLabel.attributedText = NSAttributedString(string: strings.Stickers_NoStickersFound, font: Font.medium(14.0), textColor: theme.list.freeTextColor)
    }
    
    private func enqueueTransition(_ transition: StickerPaneSearchGridTransition) {
        self.enqueuedTransitions.append(transition)
        
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
            } else if let itemNode = itemNode as? StickerPaneSearchGlobalItemNode {
                itemNode.updatePreviewing(animated: animated)
            }
        }
        self.trendingPane.updatePreviewing(animated: animated)
    }
    
    func itemAt(point: CGPoint) -> (ASDisplayNode, Any)? {
        if !self.trendingPane.isHidden {
            if let (itemNode, item) = self.trendingPane.itemAt(point: self.view.convert(point, to: self.trendingPane.view)) {
                return (itemNode, StickerPreviewPeekItem.pack(item.file._parse()))
            }
        } else {
            if let itemNode = self.gridNode.itemNodeAtPoint(self.view.convert(point, to: self.gridNode.view)) {
                if let itemNode = itemNode as? StickerPaneSearchStickerItemNode, let stickerItem = itemNode.stickerItem {
                    return (itemNode, StickerPreviewPeekItem.found(stickerItem))
                } else if let itemNode = itemNode as? StickerPaneSearchGlobalItemNode {
                    if let (node, item) = itemNode.itemAt(point: self.view.convert(point, to: itemNode.view)) {
                        return (node, StickerPreviewPeekItem.pack(item.file._parse()))
                    }
                }
            }
        }
        return nil
    }
    
    func updateLayout(size: CGSize, leftInset: CGFloat, rightInset: CGFloat, bottomInset: CGFloat, inputHeight: CGFloat, deviceMetrics: DeviceMetrics, transition: ContainedViewLayoutTransition) {
        let firstLayout = self.validLayout == nil

        self.validLayout = size
        
        if let image = self.notFoundNode.image {
            let areaHeight = size.height - inputHeight
            
            let labelSize = self.notFoundLabel.updateLayout(CGSize(width: size.width, height: CGFloat.greatestFiniteMagnitude))
            
            transition.updateFrame(node: self.notFoundNode, frame: CGRect(origin: CGPoint(x: floor((size.width - image.size.width) / 2.0), y: floor((areaHeight - image.size.height - labelSize.height) / 2.0)), size: image.size))
            transition.updateFrame(node: self.notFoundLabel, frame: CGRect(origin: CGPoint(x: floor((image.size.width - labelSize.width) / 2.0), y: image.size.height + 8.0), size: labelSize))
        }
        
        let contentFrame = CGRect(origin: CGPoint(), size: size)
        self.gridNode.transaction(GridNodeTransaction(deleteItems: [], insertItems: [], updateItems: [], scrollToItem: nil, updateLayout: GridNodeUpdateLayout(layout: GridNodeLayout(size: contentFrame.size, insets: UIEdgeInsets(top: 4.0, left: 0.0, bottom: 4.0 + bottomInset, right: 0.0), preloadSize: 300.0, type: .fixed(itemSize: CGSize(width: 75.0, height: 75.0), fillWidth: nil, lineSpacing: 0.0, itemSpacing: nil)), transition: transition), itemTransition: .immediate, stationaryItems: .none, updateFirstIndexInSectionOffset: nil), completion: { _ in })

        transition.updateFrame(node: self.trendingPane, frame: contentFrame)
        self.trendingPane.updateLayout(size: contentFrame.size, topInset: 0.0, bottomInset: bottomInset, isExpanded: false, isVisible: true, deviceMetrics: deviceMetrics, transition: transition)
        
        transition.updateFrame(node: self.gridNode, frame: contentFrame)
        if firstLayout {
            while !self.enqueuedTransitions.isEmpty {
                self.dequeueTransition()
            }
        }
    }
    
    func animateIn(additivePosition: CGFloat, transition: ContainedViewLayoutTransition) {
        self.gridNode.alpha = 0.0
        transition.updateAlpha(node: self.gridNode, alpha: 1.0, completion: { _ in
        })
        self.trendingPane.alpha = 0.0
        transition.updateAlpha(node: self.trendingPane, alpha: 1.0, completion: { _ in
        })
        
        if case let .animated(duration, curve) = transition {
            self.trendingPane.layer.animatePosition(from: CGPoint(x: 0.0, y: additivePosition), to: CGPoint(), duration: duration, timingFunction: curve.timingFunction, additive: true)
        }
    }
    
    func animateOut(transition: ContainedViewLayoutTransition) {
        transition.updateAlpha(node: self.gridNode, alpha: 0.0, completion: { _ in
        })
        transition.updateAlpha(node: self.trendingPane, alpha: 0.0, completion: { _ in
        })
        transition.updateAlpha(node: self.notFoundNode, alpha: 0.0, completion: { _ in
        })
    }
}
