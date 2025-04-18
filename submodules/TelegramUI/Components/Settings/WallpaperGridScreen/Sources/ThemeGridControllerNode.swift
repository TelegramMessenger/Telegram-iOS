import Foundation
import UIKit
import Display
import AsyncDisplayKit
import Postbox
import TelegramCore
import SwiftSignalKit
import UniversalMediaPlayer
import TelegramPresentationData
import TelegramUIPreferences
import MergeLists
import ItemListUI
import ItemListPeerActionItem
import PresentationDataUtils
import AccountContext
import SearchBarNode
import SearchUI
import WallpaperResources
import WallpaperGalleryScreen
import BoostLevelIconComponent

struct ThemeGridControllerNodeState: Equatable {
    var editing: Bool
    var selectedIds: Set<ThemeGridControllerEntry.StableId>
}

final class ThemeGridControllerInteraction {
    let openWallpaper: (TelegramWallpaper) -> Void
    let toggleWallpaperSelection: (ThemeGridControllerEntry.StableId, Bool) -> Void
    let deleteSelectedWallpapers: () -> Void
    let shareSelectedWallpapers: () -> Void
    var selectionState: (Bool, Set<ThemeGridControllerEntry.StableId>) = (false, Set())
    var removeWallpaper: () -> Void
    
    init(openWallpaper: @escaping (TelegramWallpaper) -> Void, toggleWallpaperSelection: @escaping (ThemeGridControllerEntry.StableId, Bool) -> Void, deleteSelectedWallpapers: @escaping () -> Void, shareSelectedWallpapers: @escaping () -> Void, removeWallpaper: @escaping () -> Void) {
        self.openWallpaper = openWallpaper
        self.toggleWallpaperSelection = toggleWallpaperSelection
        self.deleteSelectedWallpapers = deleteSelectedWallpapers
        self.shareSelectedWallpapers = shareSelectedWallpapers
        self.removeWallpaper = removeWallpaper
    }
}

struct ThemeGridControllerEntry: Comparable, Identifiable {
    enum StableId: Hashable {
        case builtin
        case color(UInt32)
        case gradient([UInt32])
        case file(Int64, [UInt32], Int32)
        case image(String)
        case emoticon(String)
    }

    var index: Int
    var theme: PresentationTheme?
    var wallpaper: TelegramWallpaper
    var isEmpty: Bool = false
    var emoji: TelegramMediaFile?
    var channelMode: Bool = false
    var isEditable: Bool
    var isSelected: Bool
    
    static func <(lhs: ThemeGridControllerEntry, rhs: ThemeGridControllerEntry) -> Bool {
        return lhs.index < rhs.index
    }
    
    var stableId: StableId {
        switch self.wallpaper {
        case .builtin:
            return .builtin
        case let .color(color):
            return .color(color)
        case let .gradient(gradient):
            return .gradient(gradient.colors)
        case let .file(file):
            return .file(file.id, file.settings.colors, file.settings.intensity ?? 0)
        case let .image(representations, _):
            if let largest = largestImageRepresentation(representations) {
                return .image(largest.resource.id.stringRepresentation)
            } else {
                return .image("")
            }
        case let .emoticon(emoticon):
            return .emoticon(emoticon)
        }
    }
    
    func item(context: AccountContext, interaction: ThemeGridControllerInteraction) -> ThemeGridControllerItem {
        return ThemeGridControllerItem(context: context, theme: self.theme, wallpaper: self.wallpaper, wallpaperId: self.stableId, isEmpty: self.isEmpty, emojiFile: self.emoji, channelMode: self.channelMode, index: self.index, editable: self.isEditable, selected: self.isSelected, interaction: interaction)
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
        if state.selectedIds.contains(entry.stableId) {
            wallpapers.append(entry.wallpaper)
        }
    }
    return wallpapers
}

final class ThemeGridControllerNode: ASDisplayNode {
    private struct Wallpaper: Equatable {
        var wallpaper: TelegramWallpaper
        var isLocal: Bool
    }

    private let context: AccountContext
    private let mode: ThemeGridController.Mode
    private var presentationData: PresentationData
    private var controllerInteraction: ThemeGridControllerInteraction?
    
    private let presentPreviewController: (WallpaperListSource) -> Void
    private let presentGallery: () -> Void
    private let presentColors: () -> Void
    private let emptyStateUpdated: (Bool) -> Void
    private let resetWallpapers: () -> Void
    
    var requestDeactivateSearch: (() -> Void)?
    var requestWallpaperRemoval: (() -> Void)?
    
    let ready = ValuePromise<Bool>()
    private let wallpapersPromise = Promise<[Wallpaper]>()
    private let themesPromise = Promise<[TelegramTheme]>()
    
    private var backgroundNode: ASDisplayNode
    private var separatorNode: ASDisplayNode
    private var bottomBackgroundNode: ASDisplayNode
    private var bottomSeparatorNode: ASDisplayNode
    private let maskNode: ASImageNode
    
    private let colorItemNode: ItemListActionItemNode
    private var colorItem: ItemListActionItem
    private let galleryItemNode: ListViewItemNode
    private var galleryItem: ItemListItem
    private let removeItemNode: ItemListPeerActionItemNode
    private var removeItem: ItemListPeerActionItem
    private let descriptionItemNode: ItemListTextItemNode
    private var descriptionItem: ItemListTextItem
    private let resetItemNode: ItemListActionItemNode
    private var resetItem: ItemListActionItem
    private let resetDescriptionItemNode: ItemListTextItemNode
    private var resetDescriptionItem: ItemListTextItem
    
    private var selectionPanel: ThemeGridSelectionPanelNode?
    private var selectionPanelSeparatorNode: ASDisplayNode?
    private var selectionPanelBackgroundNode: NavigationBackgroundNode?
    
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
    
    init(context: AccountContext, mode: ThemeGridController.Mode, presentationData: PresentationData, presentPreviewController: @escaping (WallpaperListSource) -> Void, presentGallery: @escaping () -> Void, presentColors: @escaping () -> Void, emptyStateUpdated: @escaping (Bool) -> Void, deleteWallpapers: @escaping ([TelegramWallpaper], @escaping () -> Void) -> Void, shareWallpapers: @escaping ([TelegramWallpaper]) -> Void, resetWallpapers: @escaping () -> Void, popViewController: @escaping () -> Void) {
        self.context = context
        self.mode = mode
        self.presentationData = presentationData
        self.presentPreviewController = presentPreviewController
        self.presentGallery = presentGallery
        self.presentColors = presentColors
        self.emptyStateUpdated = emptyStateUpdated
        self.resetWallpapers = resetWallpapers
        
        self.gridNode = GridNode()
        self.gridNode.showVerticalScrollIndicator = false
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
        
        self.maskNode = ASImageNode()
        self.maskNode.isUserInteractionEnabled = false
        
        self.colorItemNode = ItemListActionItemNode()
        self.colorItem = ItemListActionItem(presentationData: ItemListPresentationData(presentationData), title: presentationData.strings.Wallpaper_SetColor, kind: .generic, alignment: .natural, sectionId: 0, style: .blocks, action: {
            presentColors()
        })
        
        switch mode {
        case .generic:
            self.galleryItem = ItemListActionItem(presentationData: ItemListPresentationData(presentationData), title: presentationData.strings.Wallpaper_SetCustomBackground, kind: .generic, alignment: .natural, sectionId: 0, style: .blocks, action: {
                presentGallery()
            })
            self.galleryItemNode = ItemListActionItemNode()
        case .peer:
            var requiredCustomWallpaperLevel: Int?
            if case let .peer(_, _, _, _, customLevel) = mode {
                requiredCustomWallpaperLevel = customLevel
            }

            self.galleryItem = ItemListPeerActionItem(presentationData: ItemListPresentationData(presentationData), icon: generateTintedImage(image: UIImage(bundleImageName: "Chat/Attach Menu/Image"), color: presentationData.theme.list.itemAccentColor), title: presentationData.strings.Wallpaper_SetCustomBackground, additionalBadgeIcon: requiredCustomWallpaperLevel.flatMap { generateDisclosureActionBoostLevelBadgeImage(text: presentationData.strings.Channel_Appearance_BoostLevel("\($0)").string) }, alwaysPlain: false, hasSeparator: true, sectionId: 0, height: .generic, color: .accent, editing: false, action: {
                presentGallery()
            })
            self.galleryItemNode = ItemListPeerActionItemNode()
        }
        
        var removeImpl: (() -> Void)?
        self.removeItem = ItemListPeerActionItem(presentationData: ItemListPresentationData(presentationData), icon: generateTintedImage(image: UIImage(bundleImageName: "Chat/Input/Accessory Panels/MessageSelectionTrash"), color: presentationData.theme.list.itemDestructiveColor), title: presentationData.strings.Wallpaper_ChannelRemoveBackground, alwaysPlain: false, hasSeparator: true, sectionId: 0, height: .generic, color: .destructive, editing: false, action: {
            removeImpl?()
        })
        self.removeItemNode = ItemListPeerActionItemNode()

        self.descriptionItemNode = ItemListTextItemNode()

        let descriptionText: String
        switch mode {
        case .generic:
            descriptionText = presentationData.strings.Wallpaper_SetCustomBackgroundInfo
        case .peer:
            descriptionText = presentationData.strings.Wallpaper_ChannelCustomBackgroundInfo
        }
        self.descriptionItem = ItemListTextItem(presentationData: ItemListPresentationData(presentationData), text: .plain(descriptionText), sectionId: 0)

        self.resetItemNode = ItemListActionItemNode()
        self.resetItem = ItemListActionItem(presentationData: ItemListPresentationData(presentationData), title: presentationData.strings.Wallpaper_ResetWallpapers, kind: .generic, alignment: .natural, sectionId: 0, style: .blocks, action: {
            resetWallpapers()
        })
        self.resetDescriptionItemNode = ItemListTextItemNode()
        self.resetDescriptionItem = ItemListTextItem(presentationData: ItemListPresentationData(presentationData), text: .plain(presentationData.strings.Wallpaper_ResetWallpapersInfo), sectionId: 0)
        
        self.currentState = ThemeGridControllerNodeState(editing: false, selectedIds: Set())
        self.statePromise = ValuePromise(self.currentState, ignoreRepeated: true)

        let deletedWallpaperIdsValue = Atomic<Set<ThemeGridControllerEntry.StableId>>(value: Set())
        let deletedWallpaperIdsPromise = ValuePromise<Set<ThemeGridControllerEntry.StableId>>(Set())
        
        super.init()
        
        self.setViewBlock({
            return UITracingLayerView()
        })
        
        self.backgroundColor = presentationData.theme.list.itemBlocksBackgroundColor
        
        self.gridNode.addSubnode(self.backgroundNode)
        self.gridNode.addSubnode(self.bottomBackgroundNode)
//        self.gridNode.addSubnode(self.bottomSeparatorNode)
        if case .generic = mode {
            self.gridNode.addSubnode(self.colorItemNode)
        }
        self.gridNode.addSubnode(self.galleryItemNode)
        if case let .peer(_, _, wallpaper, _, _) = mode, let wallpaper, !wallpaper.isEmoticon {
            self.gridNode.addSubnode(self.removeItemNode)
        }
        self.gridNode.addSubnode(self.descriptionItemNode)
        
        if case .generic = mode {
            self.gridNode.addSubnode(self.resetItemNode)
            self.gridNode.addSubnode(self.resetDescriptionItemNode)
        }
        
        self.addSubnode(self.gridNode)
        self.gridNode.addSubnode(self.maskNode)
        self.maskNode.image = PresentationResourcesItemList.cornersImage(presentationData.theme, top: true, bottom: true)
        
        let previousEntries = Atomic<[ThemeGridControllerEntry]?>(value: nil)
        let interaction = ThemeGridControllerInteraction(openWallpaper: { [weak self] wallpaper in
            if let strongSelf = self, !strongSelf.currentState.editing {
                let entries = previousEntries.with { $0 }
                if let entries = entries, !entries.isEmpty {
                    var wallpapers = entries.map { $0.wallpaper }
                    if case .peer = mode {
                        wallpapers = wallpapers.filter { !$0.isColorOrGradient }
                    }
                    
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
                strongSelf.updateState { state in
                    var state = state
                    if value {
                        state.selectedIds.insert(id)
                    } else {
                        state.selectedIds.remove(id)
                    }
                    return state
                }
            }
        }, deleteSelectedWallpapers: { [weak self] in
            let entries = previousEntries.with { $0 }
            if let strongSelf = self, let entries = entries {
                let wallpapers = selectedWallpapers(entries: entries, state: strongSelf.currentState)

                deleteWallpapers(wallpapers, { [weak self] in
                    if let strongSelf = self {
                        var updatedDeletedIds = deletedWallpaperIdsValue.with { $0 }
                        
                        for entry in entries {
                            if strongSelf.currentState.selectedIds.contains(entry.stableId) {
                                updatedDeletedIds.insert(entry.stableId)
                            }
                        }
                        
                        let _ = deletedWallpaperIdsValue.swap(updatedDeletedIds)
                        deletedWallpaperIdsPromise.set(updatedDeletedIds)

                        let _ = (strongSelf.context.sharedContext.accountManager.transaction { transaction in
                            WallpapersState.update(transaction: transaction, { state in
                                var state = state
                                for wallpaper in wallpapers {
                                    if let index = state.wallpapers.firstIndex(where: {
                                        $0.isBasicallyEqual(to: wallpaper)
                                    }) {
                                        state.wallpapers.remove(at: index)
                                    }
                                }
                                return state
                            })
                        }).start()
                    }
                })
            }
        }, shareSelectedWallpapers: { [weak self] in
            let entries = previousEntries.with { $0 }
            if let strongSelf = self, let entries = entries {
                shareWallpapers(selectedWallpapers(entries: entries, state: strongSelf.currentState))
            }
        }, removeWallpaper: { [weak self] in
            if let self {
                self.requestWallpaperRemoval?()
            }
        })
        self.controllerInteraction = interaction
        
        let transition = combineLatest(self.wallpapersPromise.get(), self.themesPromise.get(), deletedWallpaperIdsPromise.get(), context.sharedContext.presentationData)
        |> map { wallpapers, themes, deletedWallpaperIds, presentationData -> (ThemeGridEntryTransition, Bool) in
            var entries: [ThemeGridControllerEntry] = []
            var index: Int = 0
            
            if !themes.isEmpty {
                var selectedWallpaper: TelegramWallpaper?
                if case let .peer(_, _, wallpaper, _, _) = mode {
                    selectedWallpaper = wallpaper
                }
                
                if let selectedWallpaper, !selectedWallpaper.isEmoticon {
                    entries.append(ThemeGridControllerEntry(index: index, theme: presentationData.theme, wallpaper: selectedWallpaper, channelMode: true, isEditable: false, isSelected: true))
                } else {
                    let emojiFile = context.animatedEmojiStickersValue["❌"]?.first?.file._parse()
                    entries.append(ThemeGridControllerEntry(index: index, theme: presentationData.theme, wallpaper: .color(0), isEmpty: true, emoji: emojiFile, channelMode: true, isEditable: false, isSelected: selectedWallpaper == nil))
                }
                index += 1
                
                for theme in themes {
                    guard let wallpaper = theme.settings?.first?.wallpaper, let themeEmoticon = theme.emoticon else {
                        continue
                    }
                    
                    var updatedWallpaper = wallpaper
                    if let settings = wallpaper.settings {
                        var updatedSettings = settings
                        updatedSettings.emoticon = themeEmoticon
                        updatedWallpaper = wallpaper.withUpdatedSettings(updatedSettings)
                    }
                    
                    var isSelected = false
                    if let selectedWallpaper, case let .emoticon(emoticon) = selectedWallpaper, emoticon.strippedEmoji == themeEmoticon.strippedEmoji {
                        isSelected = true
                    }

                    let emoji = context.animatedEmojiStickersValue[themeEmoticon]
                    entries.append(ThemeGridControllerEntry(index: index, theme: presentationData.theme, wallpaper: updatedWallpaper, emoji: emoji?.first?.file._parse(), channelMode: true, isEditable: false, isSelected: isSelected))
                    index += 1
                }
            } else {
                entries.insert(ThemeGridControllerEntry(index: 0, wallpaper: presentationData.chatWallpaper, emoji: nil, isEditable: false, isSelected: true), at: 0)
                index += 1
                
                var defaultWallpaper: TelegramWallpaper?
                if !presentationData.chatWallpaper.isBasicallyEqual(to: presentationData.theme.chat.defaultWallpaper) {
                    let entry = ThemeGridControllerEntry(index: 1, wallpaper: presentationData.theme.chat.defaultWallpaper, emoji: nil, isEditable: false, isSelected: false)
                    if !entries.contains(where: { $0.stableId == entry.stableId }) {
                        defaultWallpaper = presentationData.theme.chat.defaultWallpaper
                        entries.insert(entry, at: index)
                        index += 1
                    }
                }
                
                var sortedWallpapers: [TelegramWallpaper] = []
                if presentationData.theme.overallDarkAppearance {
                    var localWallpapers: [TelegramWallpaper] = []
                    var darkWallpapers: [TelegramWallpaper] = []
                    for wallpaper in wallpapers {
                        if wallpaper.isLocal {
                            localWallpapers.append(wallpaper.wallpaper)
                        } else {
                            if case let .file(file) = wallpaper.wallpaper, file.isDark {
                                darkWallpapers.append(wallpaper.wallpaper)
                            } else {
                                sortedWallpapers.append(wallpaper.wallpaper)
                            }
                        }
                    }
                    sortedWallpapers = localWallpapers + darkWallpapers + sortedWallpapers
                } else {
                    sortedWallpapers = wallpapers.map(\.wallpaper)
                }
                
                if let builtinIndex = sortedWallpapers.firstIndex(where: { wallpaper in
                    if case .builtin = wallpaper {
                        return true
                    } else {
                        return false
                    }
                }) {
                    sortedWallpapers[builtinIndex] = defaultBuiltinWallpaper(data: .legacy, colors: legacyBuiltinWallpaperGradientColors.map(\.rgb))
                }
                
                for wallpaper in sortedWallpapers {
                    if case let .file(file) = wallpaper, (wallpaper.isPattern && file.settings.colors.isEmpty) {
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
                    if isDefault || presentationData.chatWallpaper.isBasicallyEqual(to: wallpaper) {
                        isEditable = false
                    }
                    if !selected && !isDefault {
                        let entry = ThemeGridControllerEntry(index: index, wallpaper: wallpaper, isEditable: isEditable, isSelected: false)
                        if deletedWallpaperIds.contains(entry.stableId) {
                            continue
                        }
                        if !entries.contains(where: { $0.stableId == entry.stableId }) {
                            entries.append(entry)
                            index += 1
                        }
                    }
                }
            }

            let previous = previousEntries.swap(entries)
            return (preparedThemeGridEntryTransition(context: context, from: previous ?? [], to: entries, interaction: interaction), previous == nil)
        }
        self.disposable = (transition |> deliverOnMainQueue).start(next: { [weak self] (transition, _) in
            if let strongSelf = self {
                strongSelf.enqueueTransition(transition)
            }
        })
        
        removeImpl = { [weak self] in
            self?.controllerInteraction?.removeWallpaper()
        }

        self.updateWallpapers()
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
                    } else if strongSelf.removeItemNode.frame.contains(point) {
                        highlightedNode = strongSelf.removeItemNode
                    }
                }
                
                if let highlightedNode = highlightedNode {
                    highlightedNode.setHighlighted(true, at: CGPoint(), animated: false)
                } else {
                    strongSelf.colorItemNode.setHighlighted(false, at: CGPoint(), animated: true)
                    strongSelf.galleryItemNode.setHighlighted(false, at: CGPoint(), animated: true)
                    strongSelf.resetItemNode.setHighlighted(false, at: CGPoint(), animated: true)
                    strongSelf.removeItemNode.setHighlighted(false, at: CGPoint(), animated: true)
                }
            }
        }
        self.gridNode.view.addGestureRecognizer(tapRecognizer)
        
        self.gridNode.presentationLayoutUpdated = { [weak self] gridLayout, transition in
            if let strongSelf = self, let (layout, _) = strongSelf.validLayout {
                transition.updateFrame(node: strongSelf.bottomBackgroundNode, frame: CGRect(origin: CGPoint(x: 0.0, y: gridLayout.contentSize.height), size: CGSize(width: layout.size.width, height: 500.0)))
                transition.updateFrame(node: strongSelf.bottomSeparatorNode, frame: CGRect(origin: CGPoint(x: 0.0, y: gridLayout.contentSize.height), size: CGSize(width: layout.size.width, height: UIScreenPixel)))
                
                let sideInset = max(16.0, floor((layout.size.width - 674.0) / 2.0))
                var listInsets = layout.safeInsets
                if layout.size.width >= 375.0 {
                    listInsets.left = sideInset
                    listInsets.right = sideInset
                }
                
                let params = ListViewItemLayoutParams(width: layout.size.width, leftInset: listInsets.left, rightInset: listInsets.right, availableHeight: layout.size.height)
                
                let makeResetLayout = strongSelf.resetItemNode.asyncLayout()
                let makeResetDescriptionLayout = strongSelf.resetDescriptionItemNode.asyncLayout()
                let (resetLayout, resetApply) = makeResetLayout(strongSelf.resetItem, params, ItemListNeighbors(top: .none, bottom: .sameSection(alwaysPlain: true)))
                let (resetDescriptionLayout, resetDescriptionApply) = makeResetDescriptionLayout(strongSelf.resetDescriptionItem, params, ItemListNeighbors(top: .none, bottom: .none))
                
                resetApply(false)
                resetDescriptionApply()
                
                transition.updateFrame(node: strongSelf.resetItemNode, frame: CGRect(origin: CGPoint(x: 0.0, y: gridLayout.contentSize.height + 35.0), size: resetLayout.contentSize))
                transition.updateFrame(node: strongSelf.resetDescriptionItemNode, frame: CGRect(origin: CGPoint(x: 0.0, y: gridLayout.contentSize.height + 35.0 + resetLayout.contentSize.height), size: resetDescriptionLayout.contentSize))
                
                let maskSideInset = strongSelf.leftOverlayNode.frame.maxX
                strongSelf.maskNode.frame = CGRect(origin: CGPoint(x: maskSideInset, y: strongSelf.separatorNode.frame.minY + UIScreenPixel + 4.0), size: CGSize(width: layout.size.width - sideInset * 2.0, height: gridLayout.contentSize.height + 6.0))
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
                                if let galleryItem = self.galleryItem as? ItemListActionItem {
                                    galleryItem.action()
                                } else if let galleryItem = self.galleryItem as? ItemListPeerActionItem {
                                    galleryItem.action?()
                                }
                            } else if self.resetItemNode.frame.contains(location) {
                                self.resetItem.action()
                            } else if self.removeItemNode.frame.contains(location) {
                                self.removeItem.action?()
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
        switch self.mode {
        case .generic:
            self.wallpapersPromise.set(combineLatest(queue: .mainQueue(),
                telegramWallpapers(postbox: self.context.account.postbox, network: self.context.account.network),
                self.context.sharedContext.accountManager.sharedData(keys: [SharedDataKeys.wallapersState])
            )
            |> map { remoteWallpapers, sharedData -> [Wallpaper] in
                let localState = sharedData.entries[SharedDataKeys.wallapersState]?.get(WallpapersState.self) ?? WallpapersState.default

                var wallpapers: [Wallpaper] = []
                for wallpaper in localState.wallpapers {
                    if !wallpapers.contains(where: {
                        $0.wallpaper.isBasicallyEqual(to: wallpaper)
                    }) {
                        wallpapers.append(Wallpaper(wallpaper: wallpaper, isLocal: true))
                    }
                }
                for wallpaper in remoteWallpapers {
                    if !wallpapers.contains(where: {
                        $0.wallpaper.isBasicallyEqual(to: wallpaper)
                    }) {
                        wallpapers.append(Wallpaper(wallpaper: wallpaper, isLocal: false))
                    }
                }

                return wallpapers
            })
            self.themesPromise.set(.single([]))
        case let .peer(_, themes, _, _, _):
            self.themesPromise.set(.single(themes))
            self.wallpapersPromise.set(.single([]))
        }
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
        
        switch self.mode {
        case .generic:
            self.galleryItem = ItemListActionItem(presentationData: ItemListPresentationData(presentationData), title: presentationData.strings.Wallpaper_SetCustomBackground, kind: .generic, alignment: .natural, sectionId: 0, style: .blocks, action: { [weak self] in
                self?.presentGallery()
            })
        case .peer:
            var requiredCustomWallpaperLevel: Int?
            if case let .peer(_, _, _, _, customLevel) = mode {
                requiredCustomWallpaperLevel = customLevel
            }
            self.galleryItem = ItemListPeerActionItem(presentationData: ItemListPresentationData(presentationData), icon: generateTintedImage(image: UIImage(bundleImageName: "Chat/Attach Menu/Image"), color: presentationData.theme.list.itemAccentColor), title: presentationData.strings.Wallpaper_SetCustomBackground, additionalBadgeIcon: requiredCustomWallpaperLevel.flatMap { generateDisclosureActionBoostLevelBadgeImage(text: presentationData.strings.Channel_Appearance_BoostLevel("\($0)").string) }, alwaysPlain: false, hasSeparator: true, sectionId: 0, height: .generic, color: .accent, editing: false, action: { [weak self] in
                self?.presentGallery()
            })
            self.removeItem = ItemListPeerActionItem(presentationData: ItemListPresentationData(presentationData), icon: generateTintedImage(image: UIImage(bundleImageName: "Chat/Input/Accessory Panels/MessageSelectionTrash"), color: presentationData.theme.list.itemDestructiveColor), title: presentationData.strings.Wallpaper_ChannelRemoveBackground, alwaysPlain: false, hasSeparator: true, sectionId: 0, height: .generic, color: .destructive, editing: false, action: { [weak self] in
                self?.controllerInteraction?.removeWallpaper()
            })
        }
        
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
        
        let selectionState = (self.currentState.editing, self.currentState.selectedIds)
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
            self.selectionPanel?.selectedIds = selectionState.1
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
        
        let minSpacing: CGFloat = 6.0
        let referenceImageSize: CGSize
        let screenWidth = min(layout.size.width, layout.size.height)
        if screenWidth >= 390.0 {
            referenceImageSize = CGSize(width: 112.0, height: 150.0)
        } else {
            referenceImageSize = CGSize(width: 91.0, height: 161.0)
        }
        
        let sideInset = max(16.0, floor((layout.size.width - 674.0) / 2.0))
        
        let gridWidth = layout.size.width - sideInset * 2.0
        
        let imageCount = Int((gridWidth - minSpacing * 2.0) / (referenceImageSize.width))
        let imageSize = referenceImageSize.aspectFilled(CGSize(width: floor((gridWidth - CGFloat(imageCount + 1) * minSpacing) / CGFloat(imageCount)), height: referenceImageSize.height))
        let spacing = floor((gridWidth - CGFloat(imageCount) * imageSize.width) / CGFloat(imageCount + 1))
        
        let makeColorLayout = self.colorItemNode.asyncLayout()
        let makeGalleryLayout = (self.galleryItemNode as? ItemListActionItemNode)?.asyncLayout()
        let makeGalleryIconLayout = (self.galleryItemNode as? ItemListPeerActionItemNode)?.asyncLayout()
        let makeRemoveLayout = self.removeItemNode.asyncLayout()
        let makeDescriptionLayout = self.descriptionItemNode.asyncLayout()
        
        var listInsets = insets
        if layout.size.width >= 375.0 {
            listInsets.left = sideInset
            listInsets.right = sideInset
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
        
        var isChannel = false
        var hasCustomWallpaper = false
        if case let .peer(_, _, wallpaper, _, _) = self.mode {
            isChannel = true
            if let wallpaper, !wallpaper.isEmoticon {
                hasCustomWallpaper = true
            }
        }
        
        let params = ListViewItemLayoutParams(width: layout.size.width, leftInset: listInsets.left, rightInset: listInsets.right, availableHeight: layout.size.height)
        let (colorLayout, colorApply) = makeColorLayout(self.colorItem, params, ItemListNeighbors(top: .none, bottom: .sameSection(alwaysPlain: false)))
        let (galleryLayout, galleryApply): (ListViewItemNodeLayout, (Bool) -> Void)
        if let makeGalleryIconLayout, let galleryItem = self.galleryItem as? ItemListPeerActionItem {
            (galleryLayout, galleryApply) = makeGalleryIconLayout(galleryItem, params, ItemListNeighbors(top: isChannel ? .none : .sameSection(alwaysPlain: false), bottom: .sameSection(alwaysPlain: !hasCustomWallpaper)))
        } else if let makeGalleryLayout, let galleryItem = self.galleryItem as? ItemListActionItem {
            (galleryLayout, galleryApply) = makeGalleryLayout(galleryItem, params, ItemListNeighbors(top: isChannel ? .none : .sameSection(alwaysPlain: false), bottom: .sameSection(alwaysPlain: true)))
        } else {
            fatalError()
        }
        let (removeLayout, removeApply) = makeRemoveLayout(self.removeItem, params, ItemListNeighbors(top: .sameSection(alwaysPlain: false), bottom: .none))
        
        let (descriptionLayout, descriptionApply) = makeDescriptionLayout(self.descriptionItem, params, ItemListNeighbors(top: .none, bottom: .none))
        
        
        colorApply(false)
        galleryApply(false)
        removeApply(false)
        descriptionApply()
        
        let buttonTopInset: CGFloat = 32.0
        let buttonHeight: CGFloat = 44.0
        var buttonBottomInset: CGFloat = descriptionLayout.contentSize.height + 17.0
        if hasCustomWallpaper {
            buttonBottomInset = 17.0
        }
        
        var buttonInset: CGFloat = buttonTopInset + buttonHeight + buttonBottomInset
        if !isChannel || hasCustomWallpaper {
            buttonInset += buttonHeight
        }
        let buttonOffset = buttonInset + 10.0
        
        transition.updateFrame(node: self.backgroundNode, frame: CGRect(origin: CGPoint(x: 0.0, y: -buttonOffset - 500.0), size: CGSize(width: layout.size.width, height: buttonInset + 504.0)))
        transition.updateFrame(node: self.separatorNode, frame: CGRect(origin: CGPoint(x: 0.0, y: -buttonOffset + buttonInset - UIScreenPixel), size: CGSize(width: layout.size.width, height: UIScreenPixel)))
        
        var originY = -buttonOffset + buttonTopInset
        if !isChannel {
            transition.updateFrame(node: self.colorItemNode, frame: CGRect(origin: CGPoint(x: 0.0, y: originY), size: colorLayout.contentSize))
            originY += colorLayout.contentSize.height
        }
        transition.updateFrame(node: self.galleryItemNode, frame: CGRect(origin: CGPoint(x: 0.0, y: originY), size: galleryLayout.contentSize))
        originY += galleryLayout.contentSize.height
        
        if hasCustomWallpaper {
            self.descriptionItemNode.isHidden = true
            self.removeItemNode.isHidden = false
            
            transition.updateFrame(node: self.removeItemNode, frame: CGRect(origin: CGPoint(x: 0.0, y: originY), size: removeLayout.contentSize))
        } else {
            self.descriptionItemNode.isHidden = false
            self.removeItemNode.isHidden = true
            transition.updateFrame(node: self.descriptionItemNode, frame: CGRect(origin: CGPoint(x: 0.0, y: originY), size: descriptionLayout.contentSize))
        }
        
        self.leftOverlayNode.frame = CGRect(x: 0.0, y: -buttonOffset, width: listInsets.left, height: buttonTopInset + colorLayout.contentSize.height + galleryLayout.contentSize.height + 10000.0)
        self.rightOverlayNode.frame = CGRect(x: layout.size.width - listInsets.right, y: -buttonOffset, width: listInsets.right, height: buttonTopInset + colorLayout.contentSize.height + galleryLayout.contentSize.height + 10000.0)
        
        insets.top += spacing + buttonInset
        listInsets.top = insets.top
        
        if self.currentState.editing {
            let panelHeight: CGFloat
            if let selectionPanel = self.selectionPanel {
                selectionPanel.selectedIds = self.currentState.selectedIds
                panelHeight = selectionPanel.updateLayout(width: layout.size.width, leftInset: layout.safeInsets.left, rightInset: layout.safeInsets.right, maxHeight: 0.0, transition: transition, metrics: layout.metrics)
                transition.updateFrame(node: selectionPanel, frame: CGRect(origin: CGPoint(x: 0.0, y: layout.size.height - insets.bottom - panelHeight), size: CGSize(width: layout.size.width, height: panelHeight)))
                if let selectionPanelSeparatorNode = self.selectionPanelSeparatorNode {
                    transition.updateFrame(node: selectionPanelSeparatorNode, frame: CGRect(origin: CGPoint(x: 0.0, y: layout.size.height - insets.bottom - panelHeight), size: CGSize(width: layout.size.width, height: UIScreenPixel)))
                }
                if let selectionPanelBackgroundNode = self.selectionPanelBackgroundNode {
                    transition.updateFrame(node: selectionPanelBackgroundNode, frame: CGRect(origin: CGPoint(x: 0.0, y: layout.size.height - insets.bottom - panelHeight), size: CGSize(width: layout.size.width, height: insets.bottom + panelHeight)))
                    selectionPanelBackgroundNode.update(size: selectionPanelBackgroundNode.bounds.size, transition: transition)
                }
            } else {
                let selectionPanelBackgroundNode = NavigationBackgroundNode(color: self.presentationData.theme.rootController.navigationBar.blurredBackgroundColor)
                self.addSubnode(selectionPanelBackgroundNode)
                self.selectionPanelBackgroundNode = selectionPanelBackgroundNode
                
                let selectionPanel = ThemeGridSelectionPanelNode(theme: self.presentationData.theme)
                selectionPanel.controllerInteraction = self.controllerInteraction
                selectionPanel.selectedIds = self.currentState.selectedIds
                panelHeight = selectionPanel.updateLayout(width: layout.size.width, leftInset: layout.safeInsets.left, rightInset: layout.safeInsets.right, maxHeight: 0.0, transition: .immediate, metrics: layout.metrics)
                self.selectionPanel = selectionPanel
                self.addSubnode(selectionPanel)
                
                let selectionPanelSeparatorNode = ASDisplayNode()
                selectionPanelSeparatorNode.backgroundColor = self.presentationData.theme.chat.inputPanel.panelSeparatorColor
                self.addSubnode(selectionPanelSeparatorNode)
                self.selectionPanelSeparatorNode = selectionPanelSeparatorNode
                
                selectionPanel.frame = CGRect(origin: CGPoint(x: 0.0, y: layout.size.height), size: CGSize(width: layout.size.width, height: panelHeight))
                selectionPanelBackgroundNode.frame = CGRect(origin: CGPoint(x: 0.0, y: layout.size.height), size: CGSize(width: layout.size.width, height: 0.0))
                selectionPanelSeparatorNode.frame = CGRect(origin: CGPoint(x: 0.0, y: layout.size.height), size: CGSize(width: layout.size.width, height: UIScreenPixel))
                transition.updateFrame(node: selectionPanel, frame: CGRect(origin: CGPoint(x: 0.0, y: layout.size.height - insets.bottom - panelHeight), size: CGSize(width: layout.size.width, height: panelHeight)))
                transition.updateFrame(node: selectionPanelBackgroundNode, frame: CGRect(origin: CGPoint(x: 0.0, y: layout.size.height - insets.bottom - panelHeight), size: CGSize(width: layout.size.width, height: insets.bottom + panelHeight)))
                selectionPanelBackgroundNode.update(size: selectionPanelBackgroundNode.bounds.size, transition: .immediate)
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
                selectionPanelBackgroundNode.update(size: selectionPanelBackgroundNode.bounds.size, transition: transition)
            }
        }
        
        let makeResetDescriptionLayout = self.resetDescriptionItemNode.asyncLayout()
        let (resetDescriptionLayout, _) = makeResetDescriptionLayout(self.resetDescriptionItem, params, ItemListNeighbors(top: .none, bottom: .none))
    
        if !isChannel {
            listInsets.bottom += buttonHeight + 35.0 + resetDescriptionLayout.contentSize.height + 32.0
        }
        
        self.gridNode.frame = CGRect(x: 0.0, y: 0.0, width: layout.size.width, height: layout.size.height)
        self.gridNode.transaction(GridNodeTransaction(deleteItems: [], insertItems: [], updateItems: [], scrollToItem: nil, updateLayout: GridNodeUpdateLayout(layout: GridNodeLayout(size: layout.size, insets: listInsets, scrollIndicatorInsets: scrollIndicatorInsets, preloadSize: 300.0, type: .fixed(itemSize: imageSize, fillWidth: nil, lineSpacing: spacing, itemSpacing: nil)), transition: transition), itemTransition: .immediate, stationaryItems: .none, updateFirstIndexInSectionOffset: nil), completion: { _ in })

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
