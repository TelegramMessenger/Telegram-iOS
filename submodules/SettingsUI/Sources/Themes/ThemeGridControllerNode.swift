import Foundation
import UIKit
import Display
import AsyncDisplayKit
import Postbox
import TelegramCore
import SyncCore
import SwiftSignalKit
import UniversalMediaPlayer
import TelegramPresentationData
import TelegramUIPreferences
import MergeLists
import ItemListUI
import PresentationDataUtils
import AccountContext
import SearchBarNode
import SearchUI
import WallpaperResources

struct ThemeGridControllerNodeState: Equatable {
    let editing: Bool
    var selectedIndices: Set<Int64>
    
    func withUpdatedEditing(_ editing: Bool) -> ThemeGridControllerNodeState {
        return ThemeGridControllerNodeState(editing: editing, selectedIndices: editing ? self.selectedIndices : Set())
    }
    
    func withUpdatedSelectedIndices(_ selectedIndices: Set<Int64>) -> ThemeGridControllerNodeState {
        return ThemeGridControllerNodeState(editing: self.editing, selectedIndices: selectedIndices)
    }
    
    static func ==(lhs: ThemeGridControllerNodeState, rhs: ThemeGridControllerNodeState) -> Bool {
        if lhs.editing != rhs.editing {
            return false
        }
        if lhs.selectedIndices != rhs.selectedIndices {
            return false
        }
        return true
    }
}

final class ThemeGridControllerInteraction {
    let openWallpaper: (TelegramWallpaper) -> Void
    let toggleWallpaperSelection: (Int64, Bool) -> Void
    let deleteSelectedWallpapers: () -> Void
    let shareSelectedWallpapers: () -> Void
    var selectionState: (Bool, Set<Int64>) = (false, Set())
    
    init(openWallpaper: @escaping (TelegramWallpaper) -> Void, toggleWallpaperSelection: @escaping (Int64, Bool) -> Void, deleteSelectedWallpapers: @escaping () -> Void, shareSelectedWallpapers: @escaping () -> Void) {
        self.openWallpaper = openWallpaper
        self.toggleWallpaperSelection = toggleWallpaperSelection
        self.deleteSelectedWallpapers = deleteSelectedWallpapers
        self.shareSelectedWallpapers = shareSelectedWallpapers
    }
}

private struct ThemeGridControllerEntry: Comparable, Identifiable {
    let index: Int
    let wallpaper: TelegramWallpaper
    let isEditable: Bool
    let isSelected: Bool
    
    static func ==(lhs: ThemeGridControllerEntry, rhs: ThemeGridControllerEntry) -> Bool {
        return lhs.index == rhs.index && lhs.wallpaper == rhs.wallpaper && lhs.isEditable == rhs.isEditable && lhs.isSelected == rhs.isSelected
    }
    
    static func <(lhs: ThemeGridControllerEntry, rhs: ThemeGridControllerEntry) -> Bool {
        return lhs.index < rhs.index
    }
    
    var stableId: Int64 {
        switch self.wallpaper {
            case .builtin:
                return 0
            case let .color(color):
                return (Int64(1) << 32) | Int64(bitPattern: UInt64(color))
            case let .gradient(topColor, bottomColor, _):
                var hash: UInt32 = topColor
                hash = hash &* 31 &+ bottomColor
                return (Int64(2) << 32) | Int64(hash)
            case let .file(id, _, _, _, _, _, _, _, settings):
                var hash: Int = id.hashValue
                hash = hash &* 31 &+ (settings.color?.hashValue ?? 0)
                hash = hash &* 31 &+ (settings.intensity?.hashValue ?? 0)
                return (Int64(3) << 32) | Int64(hash)
            case let .image(representations, _):
                if let largest = largestImageRepresentation(representations) {
                    return (Int64(4) << 32) | Int64(largest.resource.id.hashValue)
                } else {
                    return 0
                }
        }
    }
    
    func item(context: AccountContext, interaction: ThemeGridControllerInteraction) -> ThemeGridControllerItem {
        return ThemeGridControllerItem(context: context, wallpaper: self.wallpaper, index: self.index, editable: self.isEditable, selected: self.isSelected, interaction: interaction)
    }
}

private struct ThemeGridEntryTransition {
    let deletions: [Int]
    let insertions: [GridNodeInsertItem]
    let updates: [GridNodeUpdateItem]
    let isEmpty: Bool
    let updateFirstIndexInSectionOffset: Int?
    let stationaryItems: GridNodeStationaryItems
    let scrollToItem: GridNodeScrollToItem?
    let synchronousLoad: Bool
}

private func preparedThemeGridEntryTransition(context: AccountContext, from fromEntries: [ThemeGridControllerEntry], to toEntries: [ThemeGridControllerEntry], interaction: ThemeGridControllerInteraction) -> ThemeGridEntryTransition {
    let stationaryItems: GridNodeStationaryItems = .none
    let scrollToItem: GridNodeScrollToItem? = nil
    
    let (deleteIndices, indicesAndItems, updateIndices) = mergeListsStableWithUpdates(leftList: fromEntries, rightList: toEntries)
    
    let deletions = deleteIndices
    let insertions = indicesAndItems.map { GridNodeInsertItem(index: $0.0, item: $0.1.item(context: context, interaction: interaction), previousIndex: $0.2) }
    let updates = updateIndices.map { GridNodeUpdateItem(index: $0.0, previousIndex: $0.2, item: $0.1.item(context: context, interaction: interaction)) }
    
    var hasEditableItems = false
    loop: for entry in toEntries {
        switch entry.wallpaper {
            case .file, .image:
                hasEditableItems = true
                break loop
            default:
                break
        }
    }
    
    var synchronousLoad = false
    if let previousWallpaper = fromEntries.first?.wallpaper, let newWallpaper = toEntries.first?.wallpaper {
        if case .image = previousWallpaper, case let .file(file) = newWallpaper, file.isCreator {
            synchronousLoad = true
        }
    }
    
    return ThemeGridEntryTransition(deletions: deletions, insertions: insertions, updates: updates, isEmpty: !hasEditableItems, updateFirstIndexInSectionOffset: nil, stationaryItems: stationaryItems, scrollToItem: scrollToItem, synchronousLoad: synchronousLoad)
}

private func selectedWallpapers(entries: [ThemeGridControllerEntry]?, state: ThemeGridControllerNodeState) -> [TelegramWallpaper] {
    guard let entries = entries, state.editing else {
        return []
    }
    var wallpapers: [TelegramWallpaper] = []
    for entry in entries {
        if case let .file(file) = entry.wallpaper {
            if state.selectedIndices.contains(file.id) {
                wallpapers.append(entry.wallpaper)
            }
        } else if case .image = entry.wallpaper {
            if state.selectedIndices.contains(0) {
                wallpapers.append(entry.wallpaper)
            }
        }
    }
    return wallpapers
}

final class ThemeGridControllerNode: ASDisplayNode {
    private let context: AccountContext
    private var presentationData: PresentationData
    private var controllerInteraction: ThemeGridControllerInteraction?
    
    private let presentPreviewController: (WallpaperListSource) -> Void
    private let presentGallery: () -> Void
    private let presentColors: () -> Void
    private let emptyStateUpdated: (Bool) -> Void
    private let resetWallpapers: () -> Void
    
    var requestDeactivateSearch: (() -> Void)?
    
    let ready = ValuePromise<Bool>()
    let wallpapersPromise: Promise<[TelegramWallpaper]>
    
    private var backgroundNode: ASDisplayNode
    private var separatorNode: ASDisplayNode
    private var bottomBackgroundNode: ASDisplayNode
    private var bottomSeparatorNode: ASDisplayNode
    
    private let colorItemNode: ItemListActionItemNode
    private var colorItem: ItemListActionItem
    private let galleryItemNode: ItemListActionItemNode
    private var galleryItem: ItemListActionItem
    private let descriptionItemNode: ItemListTextItemNode
    private var descriptionItem: ItemListTextItem
    private let resetItemNode: ItemListActionItemNode
    private var resetItem: ItemListActionItem
    private let resetDescriptionItemNode: ItemListTextItemNode
    private var resetDescriptionItem: ItemListTextItem
    
    private var selectionPanel: ThemeGridSelectionPanelNode?
    private var selectionPanelSeparatorNode: ASDisplayNode?
    private var selectionPanelBackgroundNode: ASDisplayNode?
    
    let gridNode: GridNode
    private let leftOverlayNode: ASDisplayNode
    private let rightOverlayNode: ASDisplayNode
    var navigationBar: NavigationBar?
    
    private var queuedTransitions: [ThemeGridEntryTransition] = []
    private var validLayout: (ContainerViewLayout, CGFloat)?
    
    private(set) var currentState: ThemeGridControllerNodeState
    private let statePromise: ValuePromise<ThemeGridControllerNodeState>
    var state: Signal<ThemeGridControllerNodeState, NoError> {
        return self.statePromise.get()
    }
    
    private(set) var searchDisplayController: SearchDisplayController?
    
    private var disposable: Disposable?
    
    init(context: AccountContext, presentationData: PresentationData, presentPreviewController: @escaping (WallpaperListSource) -> Void, presentGallery: @escaping () -> Void, presentColors: @escaping () -> Void, emptyStateUpdated: @escaping (Bool) -> Void, deleteWallpapers: @escaping ([TelegramWallpaper], @escaping () -> Void) -> Void, shareWallpapers: @escaping ([TelegramWallpaper]) -> Void, resetWallpapers: @escaping () -> Void, popViewController: @escaping () -> Void) {
        self.context = context
        self.presentationData = presentationData
        self.presentPreviewController = presentPreviewController
        self.presentGallery = presentGallery
        self.presentColors = presentColors
        self.emptyStateUpdated = emptyStateUpdated
        self.resetWallpapers = resetWallpapers
        
        self.gridNode = GridNode()
        self.gridNode.showVerticalScrollIndicator = true
        self.leftOverlayNode = ASDisplayNode()
        self.leftOverlayNode.backgroundColor = presentationData.theme.list.blocksBackgroundColor
        self.rightOverlayNode = ASDisplayNode()
        self.rightOverlayNode.backgroundColor = presentationData.theme.list.blocksBackgroundColor
        
        self.backgroundNode = ASDisplayNode()
        self.backgroundNode.backgroundColor = presentationData.theme.list.blocksBackgroundColor
        
        self.separatorNode = ASDisplayNode()
        self.separatorNode.backgroundColor = presentationData.theme.list.itemBlocksSeparatorColor
        
        self.bottomBackgroundNode = ASDisplayNode()
        self.bottomBackgroundNode.backgroundColor = presentationData.theme.list.blocksBackgroundColor
        
        self.bottomSeparatorNode = ASDisplayNode()
        self.bottomSeparatorNode.backgroundColor = presentationData.theme.list.itemBlocksSeparatorColor
        
        self.colorItemNode = ItemListActionItemNode()
        self.colorItem = ItemListActionItem(presentationData: ItemListPresentationData(presentationData), title: presentationData.strings.Wallpaper_SetColor, kind: .generic, alignment: .natural, sectionId: 0, style: .blocks, action: {
            presentColors()
        })
        self.galleryItemNode = ItemListActionItemNode()
        self.galleryItem = ItemListActionItem(presentationData: ItemListPresentationData(presentationData), title: presentationData.strings.Wallpaper_SetCustomBackground, kind: .generic, alignment: .natural, sectionId: 0, style: .blocks, action: {
            presentGallery()
        })
        self.descriptionItemNode = ItemListTextItemNode()
        self.descriptionItem = ItemListTextItem(presentationData: ItemListPresentationData(presentationData), text: .plain(presentationData.strings.Wallpaper_SetCustomBackgroundInfo), sectionId: 0)
        self.resetItemNode = ItemListActionItemNode()
        self.resetItem = ItemListActionItem(presentationData: ItemListPresentationData(presentationData), title: presentationData.strings.Wallpaper_ResetWallpapers, kind: .generic, alignment: .natural, sectionId: 0, style: .blocks, action: {
            resetWallpapers()
        })
        self.resetDescriptionItemNode = ItemListTextItemNode()
        self.resetDescriptionItem = ItemListTextItem(presentationData: ItemListPresentationData(presentationData), text: .plain(presentationData.strings.Wallpaper_ResetWallpapersInfo), sectionId: 0)
        
        self.currentState = ThemeGridControllerNodeState(editing: false, selectedIndices: Set())
        self.statePromise = ValuePromise(self.currentState, ignoreRepeated: true)
        
        let wallpapersPromise = Promise<[TelegramWallpaper]>()
        wallpapersPromise.set(telegramWallpapers(postbox: context.account.postbox, network: context.account.network))
        self.wallpapersPromise = wallpapersPromise
        
        let deletedWallpaperSlugsValue = Atomic<Set<String>>(value: Set())
        let deletedWallpaperSlugsPromise = ValuePromise<Set<String>>(Set())
        
        super.init()
        
        self.setViewBlock({
            return UITracingLayerView()
        })
        
        self.backgroundColor = presentationData.theme.list.itemBlocksBackgroundColor
        
        self.gridNode.addSubnode(self.backgroundNode)
        self.gridNode.addSubnode(self.separatorNode)
        self.gridNode.addSubnode(self.bottomBackgroundNode)
        self.gridNode.addSubnode(self.bottomSeparatorNode)
        self.gridNode.addSubnode(self.colorItemNode)
        self.gridNode.addSubnode(self.galleryItemNode)
        self.gridNode.addSubnode(self.descriptionItemNode)
        self.gridNode.addSubnode(self.resetItemNode)
        self.gridNode.addSubnode(self.resetDescriptionItemNode)
        self.addSubnode(self.gridNode)
        
        let previousEntries = Atomic<[ThemeGridControllerEntry]?>(value: nil)
        let interaction = ThemeGridControllerInteraction(openWallpaper: { [weak self] wallpaper in
            if let strongSelf = self, !strongSelf.currentState.editing {
                let entries = previousEntries.with { $0 }
                if let entries = entries, !entries.isEmpty {
                    let wallpapers = entries.map { $0.wallpaper }
                    
                    var options = WallpaperPresentationOptions()
                    if wallpaper == strongSelf.presentationData.chatWallpaper, let settings = wallpaper.settings {
                        if settings.blur {
                            options.insert(.blur)
                        }
                        if settings.motion {
                            options.insert(.motion)
                        }
                    }
                    presentPreviewController(.list(wallpapers: wallpapers, central: wallpaper, type: .wallpapers(options)))
                }
            }
        }, toggleWallpaperSelection: { [weak self] id, value in
            if let strongSelf = self {
                strongSelf.updateState { current in
                    var updated = current.selectedIndices
                    if value {
                        updated.insert(id)
                    } else {
                        updated.remove(id)
                    }
                    return current.withUpdatedSelectedIndices(updated)
                }
            }
        }, deleteSelectedWallpapers: { [weak self] in
            let entries = previousEntries.with { $0 }
            if let strongSelf = self, let entries = entries {
                deleteWallpapers(selectedWallpapers(entries: entries, state: strongSelf.currentState), { [weak self] in
                    if let strongSelf = self {
                        var updatedDeletedSlugs = deletedWallpaperSlugsValue.with { $0 }
                        
                        for entry in entries {
                            if case let .file(file) = entry.wallpaper, strongSelf.currentState.selectedIndices.contains(file.id) {
                                updatedDeletedSlugs.insert(file.slug)
                            }
                        }
                        
                        let _ = deletedWallpaperSlugsValue.swap(updatedDeletedSlugs)
                        deletedWallpaperSlugsPromise.set(updatedDeletedSlugs)
                    }
                })
            }
        }, shareSelectedWallpapers: { [weak self] in
            let entries = previousEntries.with { $0 }
            if let strongSelf = self, let entries = entries {
                shareWallpapers(selectedWallpapers(entries: entries, state: strongSelf.currentState))
            }
        })
        self.controllerInteraction = interaction
        
        let transition = combineLatest(wallpapersPromise.get(), deletedWallpaperSlugsPromise.get(), context.sharedContext.presentationData)
        |> map { wallpapers, deletedWallpaperSlugs, presentationData -> (ThemeGridEntryTransition, Bool) in
            var entries: [ThemeGridControllerEntry] = []
            var index = 1
            
            var isSelectedEditable = true
            if case .builtin = presentationData.chatWallpaper {
                isSelectedEditable = false
            } else if presentationData.chatWallpaper.isBasicallyEqual(to: presentationData.theme.chat.defaultWallpaper) {
                isSelectedEditable = false
            }
            entries.insert(ThemeGridControllerEntry(index: 0, wallpaper: presentationData.chatWallpaper, isEditable: isSelectedEditable, isSelected: true), at: 0)
            
            var defaultWallpaper: TelegramWallpaper?
            if !presentationData.chatWallpaper.isBasicallyEqual(to: presentationData.theme.chat.defaultWallpaper) {
                if case .builtin = presentationData.theme.chat.defaultWallpaper {
                } else {
                    defaultWallpaper = presentationData.theme.chat.defaultWallpaper
                    entries.insert(ThemeGridControllerEntry(index: 1, wallpaper: presentationData.theme.chat.defaultWallpaper, isEditable: false, isSelected: false), at: 1)
                    index += 1
                }
            }
            
            var sortedWallpapers: [TelegramWallpaper] = []
            if presentationData.theme.overallDarkAppearance {
                var darkWallpapers: [TelegramWallpaper] = []
                for wallpaper in wallpapers {
                    if case let .file(file) = wallpaper, file.isDark {
                        darkWallpapers.append(wallpaper)
                    } else {
                        sortedWallpapers.append(wallpaper)
                    }
                }
                sortedWallpapers = darkWallpapers + sortedWallpapers
            } else {
                sortedWallpapers = wallpapers
            }
            
            for wallpaper in sortedWallpapers {
                if case let .file(file) = wallpaper, deletedWallpaperSlugs.contains(file.slug) || (wallpaper.isPattern && file.settings.color == nil) {
                    continue
                }
                let selected = presentationData.chatWallpaper.isBasicallyEqual(to: wallpaper)
                var isDefault = false
                if let defaultWallpaper = defaultWallpaper, defaultWallpaper.isBasicallyEqual(to: wallpaper) {
                    isDefault = true
                }
                var isEditable = true
                if case .builtin = wallpaper {
                    isEditable = false
                }
                if !selected && !isDefault {
                    entries.append(ThemeGridControllerEntry(index: index, wallpaper: wallpaper, isEditable: isEditable, isSelected: false))
                }
                index += 1
            }
            
            let previous = previousEntries.swap(entries)
            return (preparedThemeGridEntryTransition(context: context, from: previous ?? [], to: entries, interaction: interaction), previous == nil)
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
    
    override func didLoad() {
        super.didLoad()
        
        let tapRecognizer = TapLongTapOrDoubleTapGestureRecognizer(target: self, action: #selector(self.tapAction(_:)))
        tapRecognizer.delaysTouchesBegan = false
        tapRecognizer.tapActionAtPoint = { _ in
            return .waitForSingleTap
        }
        tapRecognizer.highlight = { [weak self] point in
            if let strongSelf = self {
                var highlightedNode: ListViewItemNode?
                if let point = point {
                    if strongSelf.colorItemNode.frame.contains(point) {
                        highlightedNode = strongSelf.colorItemNode
                    } else if strongSelf.galleryItemNode.frame.contains(point) {
                        highlightedNode = strongSelf.galleryItemNode
                    } else if strongSelf.resetItemNode.frame.contains(point) {
                        highlightedNode = strongSelf.resetItemNode
                    }
                }
                
                if let highlightedNode = highlightedNode {
                    highlightedNode.setHighlighted(true, at: CGPoint(), animated: false)
                } else {
                    strongSelf.colorItemNode.setHighlighted(false, at: CGPoint(), animated: true)
                    strongSelf.galleryItemNode.setHighlighted(false, at: CGPoint(), animated: true)
                    strongSelf.resetItemNode.setHighlighted(false, at: CGPoint(), animated: true)
                }
            }
        }
        self.gridNode.view.addGestureRecognizer(tapRecognizer)
        
        self.gridNode.presentationLayoutUpdated = { [weak self] gridLayout, transition in
            if let strongSelf = self, let (layout, _) = strongSelf.validLayout {
                transition.updateFrame(node: strongSelf.bottomBackgroundNode, frame: CGRect(origin: CGPoint(x: 0.0, y: gridLayout.contentSize.height), size: CGSize(width: layout.size.width, height: 500.0)))
                transition.updateFrame(node: strongSelf.bottomSeparatorNode, frame: CGRect(origin: CGPoint(x: 0.0, y: gridLayout.contentSize.height), size: CGSize(width: layout.size.width, height: UIScreenPixel)))
                
                let params = ListViewItemLayoutParams(width: layout.size.width, leftInset: layout.safeInsets.left, rightInset: layout.safeInsets.right, availableHeight: layout.size.height)
                
                let makeResetLayout = strongSelf.resetItemNode.asyncLayout()
                let makeResetDescriptionLayout = strongSelf.resetDescriptionItemNode.asyncLayout()
                let (resetLayout, resetApply) = makeResetLayout(strongSelf.resetItem, params, ItemListNeighbors(top: .none, bottom: .sameSection(alwaysPlain: true)))
                let (resetDescriptionLayout, resetDescriptionApply) = makeResetDescriptionLayout(strongSelf.resetDescriptionItem, params, ItemListNeighbors(top: .none, bottom: .none))
                
                resetApply()
                resetDescriptionApply()
                
                transition.updateFrame(node: strongSelf.resetItemNode, frame: CGRect(origin: CGPoint(x: 0.0, y: gridLayout.contentSize.height + 35.0), size: resetLayout.contentSize))
                transition.updateFrame(node: strongSelf.resetDescriptionItemNode, frame: CGRect(origin: CGPoint(x: 0.0, y: gridLayout.contentSize.height + 35.0 + resetLayout.contentSize.height), size: resetDescriptionLayout.contentSize))
            }
        }
    }
    
    @objc private func tapAction(_ recognizer: TapLongTapOrDoubleTapGestureRecognizer) {
        switch recognizer.state {
            case .ended:
                if let (gesture, location) = recognizer.lastRecognizedGestureAndLocation {
                    switch gesture {
                        case .tap:
                            if self.colorItemNode.frame.contains(location) {
                                self.colorItem.action()
                            } else if self.galleryItemNode.frame.contains(location) {
                                self.galleryItem.action() 
                            } else if self.resetItemNode.frame.contains(location) {
                                self.resetItem.action()
                            }
                        default:
                            break
                    }
                }
            default:
                break
        }
    }
    
    func updateWallpapers() {
        self.wallpapersPromise.set(telegramWallpapers(postbox: self.context.account.postbox, network: self.context.account.network))
    }
    
    func updatePresentationData(_ presentationData: PresentationData) {
        self.presentationData = presentationData
        
        self.backgroundColor = presentationData.theme.list.itemBlocksBackgroundColor
        self.searchDisplayController?.updatePresentationData(self.presentationData)
        
        self.leftOverlayNode.backgroundColor = presentationData.theme.list.blocksBackgroundColor
        self.rightOverlayNode.backgroundColor = presentationData.theme.list.blocksBackgroundColor
        self.backgroundNode.backgroundColor = presentationData.theme.list.blocksBackgroundColor
        self.separatorNode.backgroundColor = presentationData.theme.list.itemBlocksSeparatorColor
        self.bottomBackgroundNode.backgroundColor = presentationData.theme.list.blocksBackgroundColor
        self.bottomSeparatorNode.backgroundColor = presentationData.theme.list.itemBlocksSeparatorColor
        
        self.colorItem = ItemListActionItem(presentationData: ItemListPresentationData(presentationData), title: presentationData.strings.Wallpaper_SetColor, kind: .generic, alignment: .natural, sectionId: 0, style: .blocks, action: { [weak self] in
            self?.presentColors()
        })
        self.galleryItem = ItemListActionItem(presentationData: ItemListPresentationData(presentationData), title: presentationData.strings.Wallpaper_SetCustomBackground, kind: .generic, alignment: .natural, sectionId: 0, style: .blocks, action: { [weak self] in
            self?.presentGallery()
        })
        self.descriptionItem = ItemListTextItem(presentationData: ItemListPresentationData(presentationData), text: .plain(presentationData.strings.Wallpaper_SetCustomBackgroundInfo), sectionId: 0)
        self.resetItem = ItemListActionItem(presentationData: ItemListPresentationData(presentationData), title: presentationData.strings.Wallpaper_ResetWallpapers, kind: .generic, alignment: .natural, sectionId: 0, style: .blocks, action: { [weak self] in
            self?.resetWallpapers()
        })
        self.resetDescriptionItem = ItemListTextItem(presentationData: ItemListPresentationData(presentationData), text: .plain(presentationData.strings.Wallpaper_ResetWallpapersInfo), sectionId: 0)
        
        if let (layout, navigationBarHeight) = self.validLayout {
            self.containerLayoutUpdated(layout, navigationBarHeight: navigationBarHeight, transition: .immediate)
        }
    }
    
    func updateState(_ f: (ThemeGridControllerNodeState) -> ThemeGridControllerNodeState) {
        let state = f(self.currentState)
        if state != self.currentState {
            self.currentState = state
            self.statePromise.set(state)
        }
        
        let selectionState = (self.currentState.editing, self.currentState.selectedIndices)
        if let interaction = self.controllerInteraction, interaction.selectionState != selectionState {
            let requestLayout = interaction.selectionState.0 != self.currentState.editing
            self.controllerInteraction?.selectionState = selectionState
            
            self.gridNode.forEachItemNode { itemNode in
                if let node = itemNode as? ThemeGridControllerItemNode {
                    node.updateSelectionState(animated: true)
                }
            }
            
            if requestLayout, let (containerLayout, navigationBarHeight) = self.validLayout {
                self.containerLayoutUpdated(containerLayout, navigationBarHeight: navigationBarHeight, transition: .animated(duration: 0.4, curve: .spring))
            }
            self.selectionPanel?.selectedIndices = selectionState.1
        }
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
            self.gridNode.transaction(GridNodeTransaction(deleteItems: transition.deletions, insertItems: transition.insertions, updateItems: transition.updates, scrollToItem: transition.scrollToItem, updateLayout: nil, itemTransition: .immediate, stationaryItems: transition.stationaryItems, updateFirstIndexInSectionOffset: transition.updateFirstIndexInSectionOffset, synchronousLoads: transition.synchronousLoad), completion: { [weak self] _ in
                if let strongSelf = self {
                    strongSelf.ready.set(true)
                }
            })
            
            self.emptyStateUpdated(transition.isEmpty)
        }
    }

    func containerLayoutUpdated(_ layout: ContainerViewLayout, navigationBarHeight: CGFloat, transition: ContainedViewLayoutTransition) {
        let hadValidLayout = self.validLayout != nil
        self.validLayout = (layout, navigationBarHeight)
        
        var insets = layout.insets(options: [.input])
        insets.top += navigationBarHeight
        insets.left = layout.safeInsets.left
        insets.right = layout.safeInsets.right
        var scrollIndicatorInsets = insets
        
        let minSpacing: CGFloat = 8.0
        let referenceImageSize: CGSize
        let screenWidth = min(layout.size.width, layout.size.height)
        if screenWidth >= 375.0 {
            referenceImageSize = CGSize(width: 108.0, height: 230.0)
        } else {
            referenceImageSize = CGSize(width: 91.0, height: 161.0)
        }
        let imageCount = Int((layout.size.width - insets.left - insets.right - minSpacing * 2.0) / (referenceImageSize.width + minSpacing))
        let imageSize = referenceImageSize.aspectFilled(CGSize(width: floor((layout.size.width - CGFloat(imageCount + 1) * minSpacing) / CGFloat(imageCount)), height: referenceImageSize.height))
        let spacing = floor((layout.size.width - CGFloat(imageCount) * imageSize.width) / CGFloat(imageCount + 1))
        
        let makeColorLayout = self.colorItemNode.asyncLayout()
        let makeGalleryLayout = self.galleryItemNode.asyncLayout()
        let makeDescriptionLayout = self.descriptionItemNode.asyncLayout()
        
        var listInsets = insets
        if layout.size.width > 480.0 {
            let inset = max(20.0, floor((layout.size.width - 674.0) / 2.0))
            listInsets.left += inset
            listInsets.right += inset
            
            if self.leftOverlayNode.supernode == nil {
                self.gridNode.addSubnode(self.leftOverlayNode)
            }
            if self.rightOverlayNode.supernode == nil {
                self.gridNode.addSubnode(self.rightOverlayNode)
            }
        } else {
            if self.leftOverlayNode.supernode != nil {
                self.leftOverlayNode.removeFromSupernode()
            }
            if self.rightOverlayNode.supernode != nil {
                self.rightOverlayNode.removeFromSupernode()
            }
        }
        
        let params = ListViewItemLayoutParams(width: layout.size.width, leftInset: listInsets.left, rightInset: listInsets.right, availableHeight: layout.size.height)
        let (colorLayout, colorApply) = makeColorLayout(self.colorItem, params, ItemListNeighbors(top: .none, bottom: .sameSection(alwaysPlain: false)))
        let (galleryLayout, galleryApply) = makeGalleryLayout(self.galleryItem, params, ItemListNeighbors(top: .sameSection(alwaysPlain: false), bottom: .sameSection(alwaysPlain: true)))
        let (descriptionLayout, descriptionApply) = makeDescriptionLayout(self.descriptionItem, params, ItemListNeighbors(top: .none, bottom: .none))
        
        colorApply()
        galleryApply()
        descriptionApply()
        
        let buttonTopInset: CGFloat = 32.0
        let buttonHeight: CGFloat = 44.0
        let buttonBottomInset: CGFloat = descriptionLayout.contentSize.height + 17.0
        
        let buttonInset: CGFloat = buttonTopInset + buttonHeight * 2.0 + buttonBottomInset
        let buttonOffset = buttonInset + 10.0
        
        transition.updateFrame(node: self.backgroundNode, frame: CGRect(origin: CGPoint(x: 0.0, y: -buttonOffset - 500.0), size: CGSize(width: layout.size.width, height: buttonInset + 500.0)))
        transition.updateFrame(node: self.separatorNode, frame: CGRect(origin: CGPoint(x: 0.0, y: -buttonOffset + buttonInset - UIScreenPixel), size: CGSize(width: layout.size.width, height: UIScreenPixel)))
        
        transition.updateFrame(node: self.colorItemNode, frame: CGRect(origin: CGPoint(x: 0.0, y: -buttonOffset + buttonTopInset), size: colorLayout.contentSize))
        transition.updateFrame(node: self.galleryItemNode, frame: CGRect(origin: CGPoint(x: 0.0, y: -buttonOffset + buttonTopInset + colorLayout.contentSize.height), size: galleryLayout.contentSize))
        transition.updateFrame(node: self.descriptionItemNode, frame: CGRect(origin: CGPoint(x: 0.0, y: -buttonOffset + buttonTopInset + colorLayout.contentSize.height + galleryLayout.contentSize.height), size: descriptionLayout.contentSize))
        
        self.leftOverlayNode.frame = CGRect(x: 0.0, y: -buttonOffset, width: listInsets.left, height: buttonTopInset + colorLayout.contentSize.height + galleryLayout.contentSize.height)
        self.rightOverlayNode.frame = CGRect(x: layout.size.width - listInsets.right, y: -buttonOffset, width: listInsets.right, height: buttonTopInset + colorLayout.contentSize.height + galleryLayout.contentSize.height)
        
        insets.top += spacing + buttonInset
        
        if self.currentState.editing {
            let panelHeight: CGFloat
            if let selectionPanel = self.selectionPanel {
                selectionPanel.selectedIndices = self.currentState.selectedIndices
                panelHeight = selectionPanel.updateLayout(width: layout.size.width, leftInset: layout.safeInsets.left, rightInset: layout.safeInsets.right, maxHeight: 0.0, transition: transition, metrics: layout.metrics)
                transition.updateFrame(node: selectionPanel, frame: CGRect(origin: CGPoint(x: 0.0, y: layout.size.height - insets.bottom - panelHeight), size: CGSize(width: layout.size.width, height: panelHeight)))
                if let selectionPanelSeparatorNode = self.selectionPanelSeparatorNode {
                    transition.updateFrame(node: selectionPanelSeparatorNode, frame: CGRect(origin: CGPoint(x: 0.0, y: layout.size.height - insets.bottom - panelHeight), size: CGSize(width: layout.size.width, height: UIScreenPixel)))
                }
                if let selectionPanelBackgroundNode = self.selectionPanelBackgroundNode {
                    transition.updateFrame(node: selectionPanelBackgroundNode, frame: CGRect(origin: CGPoint(x: 0.0, y: layout.size.height - insets.bottom - panelHeight), size: CGSize(width: layout.size.width, height: insets.bottom + panelHeight)))
                }
            } else {
                let selectionPanelBackgroundNode = ASDisplayNode()
                selectionPanelBackgroundNode.isLayerBacked = true
                selectionPanelBackgroundNode.backgroundColor = self.presentationData.theme.chat.inputPanel.panelBackgroundColor
                self.addSubnode(selectionPanelBackgroundNode)
                self.selectionPanelBackgroundNode = selectionPanelBackgroundNode
                
                let selectionPanel = ThemeGridSelectionPanelNode(theme: self.presentationData.theme)
                selectionPanel.backgroundColor = self.presentationData.theme.chat.inputPanel.panelBackgroundColor
                selectionPanel.controllerInteraction = self.controllerInteraction
                selectionPanel.selectedIndices = self.currentState.selectedIndices
                panelHeight = selectionPanel.updateLayout(width: layout.size.width, leftInset: layout.safeInsets.left, rightInset: layout.safeInsets.right, maxHeight: 0.0, transition: .immediate, metrics: layout.metrics)
                self.selectionPanel = selectionPanel
                self.addSubnode(selectionPanel)
                
                let selectionPanelSeparatorNode = ASDisplayNode()
                selectionPanelSeparatorNode.isLayerBacked = true
                selectionPanelSeparatorNode.backgroundColor = self.presentationData.theme.chat.inputPanel.panelSeparatorColor
                self.addSubnode(selectionPanelSeparatorNode)
                self.selectionPanelSeparatorNode = selectionPanelSeparatorNode
                
                selectionPanel.frame = CGRect(origin: CGPoint(x: 0.0, y: layout.size.height), size: CGSize(width: layout.size.width, height: panelHeight))
                selectionPanelBackgroundNode.frame = CGRect(origin: CGPoint(x: 0.0, y: layout.size.height), size: CGSize(width: layout.size.width, height: 0.0))
                selectionPanelSeparatorNode.frame = CGRect(origin: CGPoint(x: 0.0, y: layout.size.height), size: CGSize(width: layout.size.width, height: UIScreenPixel))
                transition.updateFrame(node: selectionPanel, frame: CGRect(origin: CGPoint(x: 0.0, y: layout.size.height - insets.bottom - panelHeight), size: CGSize(width: layout.size.width, height: panelHeight)))
                transition.updateFrame(node: selectionPanelBackgroundNode, frame: CGRect(origin: CGPoint(x: 0.0, y: layout.size.height - insets.bottom - panelHeight), size: CGSize(width: layout.size.width, height: insets.bottom + panelHeight)))
                transition.updateFrame(node: selectionPanelSeparatorNode, frame: CGRect(origin: CGPoint(x: 0.0, y: layout.size.height - insets.bottom - panelHeight), size: CGSize(width: layout.size.width, height: UIScreenPixel)))
            }
            
            insets.bottom += panelHeight
            scrollIndicatorInsets.bottom += panelHeight
        } else if let selectionPanel = self.selectionPanel {
            self.selectionPanel = nil
            transition.updateFrame(node: selectionPanel, frame: selectionPanel.frame.offsetBy(dx: 0.0, dy: selectionPanel.bounds.size.height + insets.bottom), completion: { [weak selectionPanel] _ in
                selectionPanel?.removeFromSupernode()
            })
            if let selectionPanelSeparatorNode = self.selectionPanelSeparatorNode {
                transition.updateFrame(node: selectionPanelSeparatorNode, frame: selectionPanelSeparatorNode.frame.offsetBy(dx: 0.0, dy: selectionPanel.bounds.size.height + insets.bottom), completion: { [weak selectionPanelSeparatorNode] _ in
                    selectionPanelSeparatorNode?.removeFromSupernode()
                })
            }
            if let selectionPanelBackgroundNode = self.selectionPanelBackgroundNode {
                transition.updateFrame(node: selectionPanelBackgroundNode, frame: selectionPanelBackgroundNode.frame.offsetBy(dx: 0.0, dy: selectionPanel.bounds.size.height + insets.bottom), completion: { [weak selectionPanelSeparatorNode] _ in
                    selectionPanelSeparatorNode?.removeFromSupernode()
                })
            }
        }
        
        let makeResetDescriptionLayout = self.resetDescriptionItemNode.asyncLayout()
        let (resetDescriptionLayout, _) = makeResetDescriptionLayout(self.resetDescriptionItem, params, ItemListNeighbors(top: .none, bottom: .none))
        insets.bottom += buttonHeight + 35.0 + resetDescriptionLayout.contentSize.height + 32.0
        
        self.gridNode.frame = CGRect(x: 0.0, y: 0.0, width: layout.size.width, height: layout.size.height)
        self.gridNode.transaction(GridNodeTransaction(deleteItems: [], insertItems: [], updateItems: [], scrollToItem: nil, updateLayout: GridNodeUpdateLayout(layout: GridNodeLayout(size: layout.size, insets: insets, scrollIndicatorInsets: scrollIndicatorInsets, preloadSize: 300.0, type: .fixed(itemSize: imageSize, fillWidth: nil, lineSpacing: spacing, itemSpacing: nil)), transition: transition), itemTransition: .immediate, stationaryItems: .none, updateFirstIndexInSectionOffset: nil), completion: { _ in })

        if !hadValidLayout {
            self.dequeueTransitions()
        }
        
        if let searchDisplayController = self.searchDisplayController {
            searchDisplayController.containerLayoutUpdated(layout, navigationBarHeight: navigationBarHeight, transition: transition)
        }
    }
    
    func activateSearch(placeholderNode: SearchBarPlaceholderNode) {
        guard let (containerLayout, navigationBarHeight) = self.validLayout, let navigationBar = self.navigationBar, self.searchDisplayController == nil else {
            return
        }
        
        self.searchDisplayController = SearchDisplayController(presentationData: self.presentationData, contentNode: ThemeGridSearchContentNode(context: context, openResult: { [weak self] result in
            if let strongSelf = self {
                strongSelf.presentPreviewController(.contextResult(result))
            }
        }), cancel: { [weak self] in
            self?.requestDeactivateSearch?()
        })
        
        self.searchDisplayController?.containerLayoutUpdated(containerLayout, navigationBarHeight: navigationBarHeight, transition: .immediate)
        self.searchDisplayController?.activate(insertSubnode: { [weak self, weak placeholderNode] subnode, isSearchBar in
            if let strongSelf = self, let strongPlaceholderNode = placeholderNode {
                if isSearchBar {
                    strongPlaceholderNode.supernode?.insertSubnode(subnode, aboveSubnode: strongPlaceholderNode)
                } else {
                    strongSelf.insertSubnode(subnode, belowSubnode: navigationBar)
                }
            }
        }, placeholder: placeholderNode)
    }
    
    func deactivateSearch(placeholderNode: SearchBarPlaceholderNode, animated: Bool) {
        if let searchDisplayController = self.searchDisplayController {
            searchDisplayController.deactivate(placeholder: placeholderNode, animated: animated)
            self.searchDisplayController = nil
        }
    }
    
    func fixNavigationSearchableGridNodeScrolling(searchNode: NavigationBarSearchContentNode) -> Bool {
        if searchNode.expansionProgress > 0.0 && searchNode.expansionProgress < 1.0 {
            let scrollToItem: GridNodeScrollToItem
            let targetProgress: CGFloat
            
            let duration: Double = 0.3
            let curve = ContainedViewLayoutTransitionCurve.slide
            let transition: ContainedViewLayoutTransition = .animated(duration: duration, curve: curve)
            let timingFunction = curve.timingFunction
            let mediaTimingFunction = curve.mediaTimingFunction
            
            if searchNode.expansionProgress < 0.6 {
                scrollToItem = GridNodeScrollToItem(index: 0, position: .top(navigationBarSearchContentHeight), transition: transition, directionHint: .up, adjustForSection: true, adjustForTopInset: true)
                targetProgress = 0.0
            } else {
                scrollToItem = GridNodeScrollToItem(index: 0, position: .top(0.0), transition: transition, directionHint: .up, adjustForSection: true, adjustForTopInset: true)
                targetProgress = 1.0
            }
            
            let previousOffset = (self.gridNode.scrollView.contentOffset.y + self.gridNode.scrollView.contentInset.top)
            searchNode.updateExpansionProgress(targetProgress, animated: true)
            
            self.gridNode.transaction(GridNodeTransaction(deleteItems: [], insertItems: [], updateItems: [], scrollToItem: scrollToItem, updateLayout: nil, itemTransition: .immediate, stationaryItems: .none, updateFirstIndexInSectionOffset: nil, updateOpaqueState: nil, synchronousLoads: false), completion: { _ in })
            
            let offset = (self.gridNode.scrollView.contentOffset.y + self.gridNode.scrollView.contentInset.top) - previousOffset
            
            self.backgroundNode.layer.animatePosition(from: self.backgroundNode.layer.position.offsetBy(dx: 0.0, dy: offset), to: self.backgroundNode.layer.position, duration: duration, timingFunction: timingFunction, mediaTimingFunction: mediaTimingFunction)
            self.separatorNode.layer.animatePosition(from: self.separatorNode.layer.position.offsetBy(dx: 0.0, dy: offset), to: self.separatorNode.layer.position, duration: duration, timingFunction: timingFunction, mediaTimingFunction: mediaTimingFunction)
            self.colorItemNode.layer.animatePosition(from: self.colorItemNode.layer.position.offsetBy(dx: 0.0, dy: offset), to: self.colorItemNode.layer.position, duration: duration, timingFunction: timingFunction, mediaTimingFunction: mediaTimingFunction)
            self.galleryItemNode.layer.animatePosition(from: self.galleryItemNode.layer.position.offsetBy(dx: 0.0, dy: offset), to: self.galleryItemNode.layer.position, duration: duration, timingFunction: timingFunction, mediaTimingFunction: mediaTimingFunction)
            self.descriptionItemNode.layer.animatePosition(from: self.descriptionItemNode.layer.position.offsetBy(dx: 0.0, dy: offset), to: self.descriptionItemNode.layer.position, duration: duration, timingFunction: timingFunction, mediaTimingFunction: mediaTimingFunction)
            
            return true
        }
        return false
    }
    
    func scrollToTop(animated: Bool = true) {
        if let searchDisplayController = self.searchDisplayController {
            searchDisplayController.contentNode.scrollToTop()
        } else {
            let offset = self.gridNode.scrollView.contentOffset.y + self.gridNode.scrollView.contentInset.top
            let duration: Double = 0.25
            let transition: ContainedViewLayoutTransition = animated ? .animated(duration: duration, curve: .easeInOut) : .immediate
            
            self.gridNode.transaction(GridNodeTransaction(deleteItems: [], insertItems: [], updateItems: [], scrollToItem: GridNodeScrollToItem(index: 0, position: .top(0.0), transition: transition, directionHint: .up, adjustForSection: true, adjustForTopInset: true), updateLayout: nil, itemTransition: .immediate, stationaryItems: .none, updateFirstIndexInSectionOffset: nil), completion: { _ in })
    
            if animated {
                self.backgroundNode.layer.animatePosition(from: self.backgroundNode.layer.position.offsetBy(dx: 0.0, dy: -offset), to: self.backgroundNode.layer.position, duration: duration)
                self.separatorNode.layer.animatePosition(from: self.separatorNode.layer.position.offsetBy(dx: 0.0, dy: -offset), to: self.separatorNode.layer.position, duration: duration)
                self.colorItemNode.layer.animatePosition(from: self.colorItemNode.layer.position.offsetBy(dx: 0.0, dy: -offset), to: self.colorItemNode.layer.position, duration: duration)
                self.galleryItemNode.layer.animatePosition(from: self.galleryItemNode.layer.position.offsetBy(dx: 0.0, dy: -offset), to: self.galleryItemNode.layer.position, duration: duration)
                self.descriptionItemNode.layer.animatePosition(from: self.descriptionItemNode.layer.position.offsetBy(dx: 0.0, dy: -offset), to: self.descriptionItemNode.layer.position, duration: duration)
            }
        }
    }
}
