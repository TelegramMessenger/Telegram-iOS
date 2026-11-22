import Foundation
import UIKit
import AsyncDisplayKit
import Display
import ButtonComponent
import ComponentFlow
import EdgeEffect
import SwiftSignalKit
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
import EntityKeyboard
import EmojiTextAttachmentView
import MultilineTextComponent
import TextFormat

private let packPanelHeight: CGFloat = 76.0
private let collapsedPackPanelHeight: CGFloat = 40.0

private enum StickerSearchEntryId: Equatable, Hashable {
    case sticker(String?, Int64)
}

private enum StickerSearchEntry: Identifiable, Comparable {
    case sticker(index: Int, code: String?, stickerItem: FoundStickerItem, theme: PresentationTheme)

    var stableId: StickerSearchEntryId {
        switch self {
        case let .sticker(_, code, stickerItem, _):
            return .sticker(code, stickerItem.file.fileId.id)
        }
    }

    static func ==(lhs: StickerSearchEntry, rhs: StickerSearchEntry) -> Bool {
        switch (lhs, rhs) {
        case let (.sticker(lhsIndex, lhsCode, lhsStickerItem, lhsTheme), .sticker(rhsIndex, rhsCode, rhsStickerItem, rhsTheme)):
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
        }
    }

    static func <(lhs: StickerSearchEntry, rhs: StickerSearchEntry) -> Bool {
        switch (lhs, rhs) {
        case let (.sticker(lhsIndex, _, _, _), .sticker(rhsIndex, _, _, _)):
            return lhsIndex < rhsIndex
        }
    }

    func item(context: AccountContext, theme: PresentationTheme, strings: PresentationStrings, interaction: StickerPaneSearchInteraction, inputNodeInteraction: ChatMediaInputNodeInteraction) -> GridItem {
        switch self {
        case let .sticker(_, code, stickerItem, theme):
            return StickerPaneSearchStickerItem(context: context, theme: theme, code: code, stickerItem: stickerItem, inputNodeInteraction: inputNodeInteraction, selected: { node, layer, rect in
                interaction.sendSticker(.standalone(media: stickerItem.file), node.view, layer, rect)
            })
        }
    }
}

struct StickerPaneSearchSelectedPack {
    let info: StickerPackCollectionInfo
    let installed: Bool
}

private struct StickerPaneSearchPack: Equatable {
    let info: StickerPackCollectionInfo
    let topItems: [StickerPackItem]
    let installed: Bool
}

private final class StickerSearchPackTopPanelItemComponent: Component {
    typealias EnvironmentType = EntityKeyboardTopPanelItemEnvironment

    let context: AccountContext
    let theme: PresentationTheme
    let info: StickerPackCollectionInfo
    let topItem: StickerPackItem?
    let pressed: () -> Void

    init(
        context: AccountContext,
        theme: PresentationTheme,
        info: StickerPackCollectionInfo,
        topItem: StickerPackItem?,
        pressed: @escaping () -> Void
    ) {
        self.context = context
        self.theme = theme
        self.info = info
        self.topItem = topItem
        self.pressed = pressed
    }

    static func ==(lhs: StickerSearchPackTopPanelItemComponent, rhs: StickerSearchPackTopPanelItemComponent) -> Bool {
        if lhs.context !== rhs.context {
            return false
        }
        if lhs.theme !== rhs.theme {
            return false
        }
        if lhs.info != rhs.info {
            return false
        }
        if lhs.topItem != rhs.topItem {
            return false
        }
        return true
    }

    final class View: UIView {
        private var itemLayer: InlineStickerItemLayer?
        private var itemFileId: EngineMedia.Id?
        private var titleView: ComponentView<Empty>?
        private var component: StickerSearchPackTopPanelItemComponent?

        override init(frame: CGRect) {
            super.init(frame: frame)

            self.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(self.tapGesture(_:))))
        }

        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }

        @objc private func tapGesture(_ recognizer: UITapGestureRecognizer) {
            if case .ended = recognizer.state {
                self.component?.pressed()
            }
        }

        func update(component: StickerSearchPackTopPanelItemComponent, availableSize: CGSize, state: EmptyComponentState, environment: Environment<EnvironmentType>, transition: ComponentTransition) -> CGSize {
            self.component = component

            let itemEnvironment = environment[EntityKeyboardTopPanelItemEnvironment.self].value
            let file = component.topItem?.file._parse()
            let fileId = file?.fileId
            if self.itemFileId != fileId {
                self.itemFileId = fileId
                if let itemLayer = self.itemLayer {
                    self.itemLayer = nil
                    itemLayer.removeFromSuperlayer()
                }

                if let file {
                    let itemDimensions = file.dimensions?.cgSize ?? CGSize(width: 512.0, height: 512.0)
                    let displaySize = itemDimensions.aspectFitted(CGSize(width: 44.0, height: 44.0))
                    let itemLayer = InlineStickerItemLayer(
                        context: component.context,
                        userLocation: .other,
                        attemptSynchronousLoad: false,
                        emoji: ChatTextInputTextCustomEmojiAttribute(interactivelySelectedFromPackId: nil, fileId: file.fileId.id, file: file),
                        file: file,
                        cache: component.context.animationCache,
                        renderer: component.context.animationRenderer,
                        placeholderColor: component.theme.chat.inputPanel.primaryTextColor.withMultipliedAlpha(0.1),
                        pointSize: displaySize,
                        dynamicColor: .white
                    )
                    self.itemLayer = itemLayer
                    self.layer.addSublayer(itemLayer)
                }
            }

            let iconFitSize: CGSize = itemEnvironment.isExpanded ? CGSize(width: 44.0, height: 44.0) : CGSize(width: 24.0, height: 24.0)
            if let itemLayer = self.itemLayer, let file {
                let itemDimensions = file.dimensions?.cgSize ?? CGSize(width: 512.0, height: 512.0)
                let iconSize = itemDimensions.aspectFitted(iconFitSize)
                let iconFrame = CGRect(origin: CGPoint(x: floor((availableSize.width - iconSize.width) / 2.0), y: floor((iconFitSize.height - iconSize.height) / 2.0)), size: iconSize)
                transition.setPosition(layer: itemLayer, position: CGPoint(x: iconFrame.midX, y: iconFrame.midY))
                transition.setBounds(layer: itemLayer, bounds: CGRect(origin: CGPoint(), size: iconFrame.size))
                itemLayer.isVisibleForAnimations = itemEnvironment.isContentInFocus && component.context.sharedContext.energyUsageSettings.loopStickers
            }

            if itemEnvironment.isExpanded {
                let titleView: ComponentView<Empty>
                if let current = self.titleView {
                    titleView = current
                } else {
                    titleView = ComponentView<Empty>()
                    self.titleView = titleView
                }
                let titleSize = titleView.update(
                    transition: .immediate,
                    component: AnyComponent(MultilineTextComponent(
                        text: .plain(NSAttributedString(string: component.info.title, font: Font.regular(10.0), textColor: component.theme.chat.inputPanel.primaryTextColor)),
                        insets: UIEdgeInsets(top: 1.0, left: 1.0, bottom: 1.0, right: 1.0)
                    )),
                    environment: {},
                    containerSize: CGSize(width: 62.0, height: 100.0)
                )
                if let view = titleView.view {
                    if view.superview == nil {
                        view.alpha = 0.0
                        self.addSubview(view)
                    }
                    view.frame = CGRect(origin: CGPoint(x: floor((availableSize.width - titleSize.width) / 2.0), y: availableSize.height - titleSize.height - 1.0), size: titleSize)
                    transition.setAlpha(view: view, alpha: 1.0)
                }
            } else if let titleView = self.titleView {
                self.titleView = nil
                if let view = titleView.view {
                    if !transition.animation.isImmediate {
                        view.alpha = 0.0
                        view.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.08, completion: { [weak view] _ in
                            view?.removeFromSuperview()
                        })
                    } else {
                        view.removeFromSuperview()
                    }
                }
            }

            return availableSize
        }
    }

    func makeView() -> View {
        return View(frame: CGRect())
    }

    func update(view: View, availableSize: CGSize, state: EmptyComponentState, environment: Environment<EnvironmentType>, transition: ComponentTransition) -> CGSize {
        return view.update(component: self, availableSize: availableSize, state: state, environment: environment, transition: transition)
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
    let crossfade: Bool
}

private struct StickerPaneSearchStickerState {
    let context: StickerSearchContext?
    let items: [FoundStickerItem]
    let isLoadingMore: Bool
}

private func preparedChatMediaInputGridEntryTransition(context: AccountContext, theme: PresentationTheme, strings: PresentationStrings, from fromEntries: [StickerSearchEntry], to toEntries: [StickerSearchEntry], interaction: StickerPaneSearchInteraction, inputNodeInteraction: ChatMediaInputNodeInteraction, crossfade: Bool) -> StickerPaneSearchGridTransition {
    let stationaryItems: GridNodeStationaryItems = .none
    let scrollToItem: GridNodeScrollToItem? = nil
    var animated = false
    animated = true

    let (deleteIndices, indicesAndItems, updateIndices) = mergeListsStableWithUpdates(leftList: fromEntries, rightList: toEntries)

    let deletions = deleteIndices
    let insertions = indicesAndItems.map { GridNodeInsertItem(index: $0.0, item: $0.1.item(context: context, theme: theme, strings: strings, interaction: interaction, inputNodeInteraction: inputNodeInteraction), previousIndex: $0.2) }
    let updates = updateIndices.map { GridNodeUpdateItem(index: $0.0, previousIndex: $0.2, item: $0.1.item(context: context, theme: theme, strings: strings, interaction: interaction, inputNodeInteraction: inputNodeInteraction)) }

    let firstIndexInSectionOffset = 0

    return StickerPaneSearchGridTransition(deletions: deletions, insertions: insertions, updates: updates, updateFirstIndexInSectionOffset: firstIndexInSectionOffset, stationaryItems: stationaryItems, scrollToItem: scrollToItem, animated: animated, crossfade: crossfade)
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
    private let packPanel = ComponentView<EntityKeyboardTopContainerPanelEnvironment>()
    private let topEdgeEffectView = EdgeEffectView()
    private let bottomEdgeEffectView = EdgeEffectView()
    private let selectedPackAddButton = ComponentView<Empty>()
    private let packPanelVisibilityFractionUpdated = ActionSlot<(CGFloat, ComponentTransition)>()
    private let packPanelActiveItemUpdated = ActionSlot<(AnyHashable, AnyHashable?, ComponentTransition)>()

    private var validLayout: (size: CGSize, leftInset: CGFloat, rightInset: CGFloat, bottomInset: CGFloat, inputHeight: CGFloat, deviceMetrics: DeviceMetrics)?

    private var enqueuedTransitions: [StickerPaneSearchGridTransition] = []

    private let searchDisposable = MetaDisposable()
    private let selectedPackDisposable = MetaDisposable()

    private let queue = Queue()
    private let currentEntries = Atomic<[StickerSearchEntry]?>(value: nil)
    private let currentRemotePacks = Atomic<FoundStickerSets?>(value: nil)
    private var currentSearchEntries: [StickerSearchEntry] = []
    private var currentPacks: [StickerPaneSearchPack] = []
    private var currentSearchIsFinal: Bool = false
    private var searchIsActive: Bool = false
    private var selectedPack: StickerPaneSearchPack?
    private var isPackPanelExpanded: Bool = true
    private var installedPackIds = Set<EngineItemCollectionId>()
    private var stickerSearchContext: StickerSearchContext?
    private var currentSearchStickerCount: Int = 0
    private var currentStickerCount: Int = 0

    private let _ready = Promise<Void>()
    var ready: Signal<Void, NoError> {
        return self._ready.get()
    }

    var deactivateSearchBar: (() -> Void)?
    var updateActivity: ((Bool) -> Void)?
    var selectedPackUpdated: ((StickerPaneSearchSelectedPack?) -> Void)?

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
        self.topEdgeEffectView.isUserInteractionEnabled = false
        self.bottomEdgeEffectView.isUserInteractionEnabled = false
        self.bottomEdgeEffectView.alpha = 0.0

        super.init()

        self.addSubnode(self.trendingPane)
        self.addSubnode(self.gridNode)
        self.addSubnode(self.notFoundNode)
        self.view.addSubview(self.topEdgeEffectView)
        self.view.addSubview(self.bottomEdgeEffectView)

        self.gridNode.scrollView.alwaysBounceVertical = true
        self.gridNode.scrollingInitiated = { [weak self] in
            self?.deactivateSearchBar?()
        }
        self.gridNode.visibleItemsUpdated = { [weak self] visibleItems in
            guard let self else {
                return
            }
            self.updatePackPanelExpansionFromScroll()

            guard let (bottomVisible, _) = visibleItems.bottomVisible else {
                return
            }
            guard self.selectedPack == nil, self.currentStickerCount != 0 else {
                return
            }
            if bottomVisible >= max(0, self.currentStickerCount - 8) {
                self.stickerSearchContext?.loadMore()
            }
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
                    actionPerformed: { [weak self] actions in
                        self?.presentStickerPackActionOverlay(actions)
                    }
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
                    let presentationData = strongSelf.context.sharedContext.currentPresentationData.with { $0 }.withUpdated(theme: theme)
                    strongSelf.interaction.getNavigationController()?.presentOverlay(controller: UndoOverlayController(presentationData: presentationData, content: .stickersModified(title: presentationData.strings.StickerPackActionInfo_AddedTitle, text: presentationData.strings.StickerPackActionInfo_AddedText(info.title).string, undo: false, info: info, topItem: items.first, context: strongSelf.context), elevatedLayout: false, action: { _ in
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
        self.selectedPackDisposable.dispose()
        self.installDisposable.dispose()
    }

    private func presentStickerPackActionOverlay(_ actions: [StickerPackScreenActionResult]) {
        guard let action = actions.first else {
            return
        }

        var animateInAsReplacement = false
        if let navigationController = self.interaction.getNavigationController() {
            for controller in navigationController.overlayControllers {
                if let controller = controller as? UndoOverlayController {
                    controller.dismissWithCommitActionAndReplacementAnimation()
                    animateInAsReplacement = true
                }
            }
        }

        let presentationData = self.context.sharedContext.currentPresentationData.with { $0 }.withUpdated(theme: self.theme)
        let controller: UndoOverlayController
        switch action.action {
        case .add:
            self.setPackInstalledState(id: action.info.id, installed: true)
            controller = UndoOverlayController(
                presentationData: presentationData,
                content: .stickersModified(
                    title: presentationData.strings.StickerPackActionInfo_AddedTitle,
                    text: presentationData.strings.StickerPackActionInfo_AddedText(action.info.title).string,
                    undo: false,
                    info: action.info,
                    topItem: action.items.first,
                    context: self.context
                ),
                elevatedLayout: false,
                animateInAsReplacement: animateInAsReplacement,
                action: { _ in
                    return true
                }
            )
        case let .remove(positionInList):
            self.setPackInstalledState(id: action.info.id, installed: false)
            controller = UndoOverlayController(
                presentationData: presentationData,
                content: .stickersModified(
                    title: presentationData.strings.StickerPackActionInfo_RemovedTitle,
                    text: presentationData.strings.StickerPackActionInfo_RemovedText(action.info.title).string,
                    undo: true,
                    info: action.info,
                    topItem: action.items.first,
                    context: self.context
                ),
                elevatedLayout: false,
                animateInAsReplacement: animateInAsReplacement,
                action: { [weak self] overlayAction in
                    if case .undo = overlayAction {
                        let _ = self?.context.engine.stickers.addStickerPackInteractively(info: action.info, items: action.items, positionInList: positionInList).start()
                        self?.setPackInstalledState(id: action.info.id, installed: true)
                    }
                    return true
                }
            )
        }

        if let navigationController = self.interaction.getNavigationController() {
            navigationController.presentOverlay(controller: controller)
        } else {
            self.interaction.presentController(controller, nil)
        }
    }

    func updateText(_ text: String, languageCode: String?) {
        if self.selectedPack != nil {
            self.clearSelectedPack(applySearchResults: false)
        }
        self.stickerSearchContext = nil
        self.currentSearchStickerCount = 0
        self.currentStickerCount = 0
        self.isPackPanelExpanded = true
        let _ = self.currentRemotePacks.swap(nil)

        let query = text.trimmingCharacters(in: .whitespacesAndNewlines)
        let signal: Signal<(StickerPaneSearchStickerState, FoundStickerSets, Bool, FoundStickerSets?)?, NoError>
        if query.isSingleEmoji || query.count >= 2 {
            let context = self.context
            let stickers: Signal<StickerPaneSearchStickerState, NoError>
            if query.isSingleEmoji {
                let searchContext = context.engine.stickers.stickerSearchContext(query: nil, emoticon: [query.basicEmoji.0])
                stickers = searchContext.state
                |> map { state -> StickerPaneSearchStickerState in
                    return StickerPaneSearchStickerState(context: searchContext, items: state.items, isLoadingMore: state.isLoadingMore)
                }
            } else if query.count > 1, let languageCode = languageCode, !languageCode.isEmpty && languageCode != "emoji" {
                var keywords = context.engine.stickers.searchEmojiKeywords(inputLanguageCode: languageCode, query: query.lowercased(), completeMatch: query.count < 3)
                if !languageCode.lowercased().hasPrefix("en") {
                    keywords = keywords
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
                stickers = .single(StickerPaneSearchStickerState(context: nil, items: [], isLoadingMore: true))
                |> then(
                    keywords
                |> mapToSignal { keywords -> Signal<StickerPaneSearchStickerState, NoError> in
                    let emoticon = keywords.flatMap { $0.emoticons }.map { $0.basicEmoji.0 }
                    let searchContext = context.engine.stickers.stickerSearchContext(query: query, emoticon: emoticon, inputLanguageCode: languageCode)
                    return searchContext.state
                    |> map { state -> StickerPaneSearchStickerState in
                        return StickerPaneSearchStickerState(context: searchContext, items: state.items, isLoadingMore: state.isLoadingMore)
                    }
                })
            } else {
                stickers = .single(StickerPaneSearchStickerState(context: nil, items: [], isLoadingMore: false))
            }

            let local = context.engine.stickers.searchStickerSets(query: query)
            let remote = context.engine.stickers.searchStickerSetsRemotely(query: query)
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

            let installedPackIds = context.engine.data.subscribe(TelegramEngine.EngineData.Item.ItemCollections.InstalledPackInfos(namespace: Namespaces.ItemCollection.CloudStickerPacks))
            |> map { entries -> Set<EngineItemCollectionId> in
                var installedPacks = Set<EngineItemCollectionId>()
                for entry in entries {
                    installedPacks.insert(entry.id)
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
            |> map { stickers, packs -> (StickerPaneSearchStickerState, FoundStickerSets, Bool, FoundStickerSets?)? in
                return (stickers, packs.0, packs.1 && !stickers.isLoadingMore, packs.2)
            }
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

                if let (stickers, packs, final, remote) = result {
                    strongSelf.stickerSearchContext = stickers.context
                    strongSelf.currentSearchStickerCount = stickers.items.count
                    strongSelf.currentStickerCount = stickers.items.count
                    strongSelf.updateActivity?(stickers.items.isEmpty && stickers.isLoadingMore)

                    if let remote = remote {
                        let _ = strongSelf.currentRemotePacks.swap(remote)
                    }
                    strongSelf.gridNode.isHidden = false
                    strongSelf.trendingPane.isHidden = true

                    let previousPacks = strongSelf.currentPacks
                    let entries = strongSelf.entries(stickers: stickers.items)
                    
                    var packItems: [StickerPaneSearchPack] = strongSelf.packs(from: packs)
                    if !strongSelf.installedPackIds.isEmpty {
                        packItems = packItems.map { pack in
                            if strongSelf.installedPackIds.contains(pack.info.id) && !pack.installed {
                                return StickerPaneSearchPack(info: pack.info, topItems: pack.topItems, installed: true)
                            } else {
                                return pack
                            }
                        }
                    }

                    strongSelf.currentSearchEntries = entries
                    strongSelf.currentPacks = packItems
                    if let selectedPack = strongSelf.selectedPack, let updatedPack = packItems.first(where: { $0.info.id == selectedPack.info.id }), selectedPack.installed != updatedPack.installed {
                        strongSelf.setPackInstalledState(id: selectedPack.info.id, installed: updatedPack.installed, transition: .immediate)
                    }
                    strongSelf.currentSearchIsFinal = final
                    strongSelf.searchIsActive = true

                    if strongSelf.selectedPack == nil {
                        strongSelf.enqueueEntries(entries, interaction: interaction)
                        strongSelf.updateNotFound()
                    }
                    if previousPacks != packItems {
                        strongSelf.requestLayout(transition: .immediate)
                    }
                } else {
                    let _ = strongSelf.currentRemotePacks.swap(nil)
                    strongSelf.stickerSearchContext = nil
                    strongSelf.currentSearchStickerCount = 0
                    strongSelf.currentStickerCount = 0
                    strongSelf.currentSearchEntries = []
                    strongSelf.currentPacks = []
                    strongSelf.currentSearchIsFinal = false
                    strongSelf.searchIsActive = false
                    strongSelf.updateActivity?(false)
                    strongSelf.gridNode.isHidden = true
                    strongSelf.notFoundNode.isHidden = true
                    strongSelf.trendingPane.isHidden = false
                    strongSelf.enqueueEntries([], interaction: interaction)
                    strongSelf.requestLayout(transition: .immediate)
                }
            }
        }))
    }

    private func entries(stickers: [FoundStickerItem]) -> [StickerSearchEntry] {
        var entries: [StickerSearchEntry] = []
        var index = 0
        var existingStickerIds = Set<EngineMedia.Id>()
        for sticker in stickers {
            if let id = sticker.file.id, !existingStickerIds.contains(id) {
                entries.append(.sticker(index: index, code: nil, stickerItem: sticker, theme: self.theme))
                index += 1
                existingStickerIds.insert(id)
            }
        }

        return entries
    }

    private func packs(from packs: FoundStickerSets) -> [StickerPaneSearchPack] {
        var result: [StickerPaneSearchPack] = []
        var existingIds = Set<EngineItemCollectionId>()
        for (collectionId, info, _, installed) in packs.infos {
            guard !existingIds.contains(collectionId), let info = info as? StickerPackCollectionInfo else {
                continue
            }
            existingIds.insert(collectionId)

            var topItems: [StickerPackItem] = []
            for entry in packs.entries {
                if let item = entry.item as? StickerPackItem, entry.index.collectionId == collectionId {
                    topItems.append(item)
                }
            }
            result.append(StickerPaneSearchPack(info: info, topItems: topItems, installed: installed))
        }

        return result
    }

    private func entries(packItems: [StickerPackItem]) -> [StickerSearchEntry] {
        var entries: [StickerSearchEntry] = []
        var existingStickerIds = Set<EngineMedia.Id>()
        var index = 0
        for item in packItems {
            let file = item.file._parse()
            if let id = file.id, !existingStickerIds.contains(id) {
                entries.append(.sticker(index: index, code: nil, stickerItem: FoundStickerItem(file: file, stringRepresentations: item.getStringRepresentationsOfIndexKeys()), theme: self.theme))
                existingStickerIds.insert(id)
                index += 1
            }
        }
        return entries
    }

    private var shouldDisplayPackPanel: Bool {
        return self.searchIsActive && !self.currentPacks.isEmpty
    }

    private var currentPackPanelHeight: CGFloat {
        guard self.shouldDisplayPackPanel else {
            return 0.0
        }
        return packPanelHeight
    }

    private var currentVisiblePackPanelHeight: CGFloat {
        guard self.shouldDisplayPackPanel else {
            return 0.0
        }
        return self.isPackPanelExpanded ? packPanelHeight : collapsedPackPanelHeight
    }

    private var isInstallPackButtonVisible: Bool {
        guard let selectedPack = self.selectedPack else {
            return false
        }
        return !selectedPack.installed && !self.installedPackIds.contains(selectedPack.info.id)
    }
    
    func setPackInstalledState(id: EngineItemCollectionId, installed: Bool, transition: ContainedViewLayoutTransition = .animated(duration: 0.2, curve: .easeInOut)) {
        if installed {
            self.installedPackIds.insert(id)
        } else {
            self.installedPackIds.remove(id)
        }

        var updatedSelectedPack: StickerPaneSearchPack?
        if let selectedPack = self.selectedPack, selectedPack.info.id == id {
            if selectedPack.installed != installed {
                let pack = StickerPaneSearchPack(info: selectedPack.info, topItems: selectedPack.topItems, installed: installed)
                self.selectedPack = pack
                updatedSelectedPack = pack
            } else {
                updatedSelectedPack = selectedPack
            }
        }

        var updatedPacks = false
        self.currentPacks = self.currentPacks.map { pack in
            if pack.info.id == id && pack.installed != installed {
                updatedPacks = true
                return StickerPaneSearchPack(info: pack.info, topItems: pack.topItems, installed: installed)
            } else {
                return pack
            }
        }

        if let updatedSelectedPack {
            self.selectedPackUpdated?(StickerPaneSearchSelectedPack(info: updatedSelectedPack.info, installed: updatedSelectedPack.installed))
        }

        if updatedSelectedPack != nil || updatedPacks {
            self.requestLayout(transition: transition)
        }
    }

    private func updatePackPanelExpansionFromScroll() {
        guard self.shouldDisplayPackPanel else {
            return
        }

        let contentOffsetY = self.gridNode.scrollView.contentOffset.y
        let shouldExpand: Bool
        if self.gridNode.scrollView.contentInset.top < 10.0 {
            shouldExpand = true
        } else {
            shouldExpand = contentOffsetY <= -packPanelHeight + 20.0
        }
        if self.isPackPanelExpanded != shouldExpand {
            self.isPackPanelExpanded = shouldExpand
            self.requestLayout(transition: .animated(duration: 0.2, curve: .easeInOut))
        }
    }

    private func resetGridScrollToTop() {
        let scrollView = self.gridNode.scrollView
        scrollView.setContentOffset(CGPoint(x: 0.0, y: -scrollView.contentInset.top), animated: false)
    }

    private func enqueueEntries(_ entries: [StickerSearchEntry], interaction: StickerPaneSearchInteraction, crossfade: Bool = false) {
        let previousEntries = self.currentEntries.swap(entries)
        let transition = preparedChatMediaInputGridEntryTransition(context: self.context, theme: self.theme, strings: self.strings, from: previousEntries ?? [], to: entries, interaction: interaction, inputNodeInteraction: self.inputNodeInteraction, crossfade: crossfade)
        self.enqueueTransition(transition)
    }

    private func updateNotFound() {
        if self.selectedPack != nil || !self.searchIsActive {
            self.notFoundNode.isHidden = true
        } else if self.currentSearchIsFinal || !self.currentSearchEntries.isEmpty || !self.currentPacks.isEmpty {
            self.notFoundNode.isHidden = !(self.currentSearchEntries.isEmpty && self.currentPacks.isEmpty)
        } else {
            self.notFoundNode.isHidden = true
        }
    }

    private func selectPack(_ pack: StickerPaneSearchPack) {
        guard let interaction = self.searchInteraction else {
            return
        }

        self.view.window?.endEditing(true)
        self.deactivateSearchBar?()

        self.selectedPackDisposable.set(nil)
        self.selectedPack = pack
        self.currentStickerCount = 0
        self.notFoundNode.isHidden = true
        self.gridNode.isHidden = false
        self.trendingPane.isHidden = true
        self.selectedPackUpdated?(StickerPaneSearchSelectedPack(info: pack.info, installed: pack.installed))

        self.enqueueEntries(self.entries(packItems: pack.topItems), interaction: interaction, crossfade: true)
        self.isPackPanelExpanded = true
        self.requestLayout(transition: .animated(duration: 0.2, curve: .easeInOut))
        self.resetGridScrollToTop()

        let packId = pack.info.id
        self.selectedPackDisposable.set((self.context.engine.stickers.loadedStickerPack(reference: .id(id: pack.info.id.id, accessHash: pack.info.accessHash), forceActualized: false)
        |> deliverOnMainQueue).start(next: { [weak self] result in
            guard let self, let interaction = self.searchInteraction, self.selectedPack?.info.id == packId else {
                return
            }
            switch result {
            case let .result(_, items, _):
                self.enqueueEntries(self.entries(packItems: items), interaction: interaction)
            case .fetching, .none:
                break
            }
        }))
    }

    private func installSelectedStickerPack() {
        guard let selectedPack = self.selectedPack, !selectedPack.installed, !self.installedPackIds.contains(selectedPack.info.id) else {
            return
        }

        let context = self.context
        let packId = selectedPack.info.id
        let accessHash = selectedPack.info.accessHash

        self.setPackInstalledState(id: packId, installed: true)

        let installSignal = (context.engine.stickers.loadedStickerPack(reference: .id(id: packId.id, accessHash: accessHash), forceActualized: false)
        |> mapToSignal { result -> Signal<(StickerPackCollectionInfo, [StickerPackItem]), NoError> in
            switch result {
            case let .result(info, items, installed):
                let info = info._parse()
                if installed {
                    return .single((info, items))
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
        |> deliverOnMainQueue)

        self.installDisposable.set(installSignal.start(next: { [weak self] info, items in
            guard let self else {
                return
            }
            let presentationData = self.context.sharedContext.currentPresentationData.with { $0 }.withUpdated(theme: self.theme)
            self.interaction.getNavigationController()?.presentOverlay(controller: UndoOverlayController(presentationData: presentationData, content: .stickersModified(title: presentationData.strings.StickerPackActionInfo_AddedTitle, text: presentationData.strings.StickerPackActionInfo_AddedText(info.title).string, undo: false, info: info, topItem: items.first, context: self.context), elevatedLayout: false, action: { _ in
                return true
            }))
        }))
    }

    func clearSelectedPack(applySearchResults: Bool = true) {
        guard self.selectedPack != nil else {
            return
        }
        self.selectedPack = nil
        self.selectedPackDisposable.set(nil)

        self.selectedPackUpdated?(nil)
        
        if applySearchResults, let interaction = self.searchInteraction {
            self.currentStickerCount = self.currentSearchStickerCount
            self.gridNode.isHidden = !self.searchIsActive
            self.trendingPane.isHidden = self.searchIsActive
            self.enqueueEntries(self.currentSearchEntries, interaction: interaction, crossfade: true)
            self.updateNotFound()
            self.requestLayout(transition: .animated(duration: 0.2, curve: .easeInOut))
        }
    }

    func updateThemeAndStrings(theme: PresentationTheme, strings: PresentationStrings) {
        self.theme = theme
        self.strings = strings
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

            if transition.crossfade, let snapshotView = self.gridNode.scrollView.snapshotContentTree() {
                snapshotView.frame = self.gridNode.frame
                self.gridNode.view.superview?.addSubview(snapshotView)
                
                snapshotView.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.25, removeOnCompletion: false, completion: { _ in
                    snapshotView.removeFromSuperview()
                })
                
                self.gridNode.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.25)
            }
            
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
                }
            }
        }
        return nil
    }

    private func updatePackButtonsLayout(size: CGSize, bottomInset: CGFloat, transition: ContainedViewLayoutTransition) {
        if self.shouldDisplayPackPanel {
            let componentTransition = ComponentTransition(transition)
            let panelSize = self.packPanel.update(
                transition: componentTransition,
                component: AnyComponent(EntityKeyboardTopPanelComponent(
                    id: AnyHashable("stickerSearchPacks"),
                    theme: self.theme,
                    customTintColor: nil,
                    items: self.currentPacks.map { pack in
                        return EntityKeyboardTopPanelComponent.Item(
                            id: AnyHashable(pack.info.id),
                            isReorderable: false,
                            content: AnyComponent(StickerSearchPackTopPanelItemComponent(
                                context: self.context,
                                theme: self.theme,
                                info: pack.info,
                                topItem: pack.topItems.first,
                                pressed: { [weak self] in
                                    self?.selectPack(pack)
                                }
                            ))
                        )
                    },
                    containerSideInset: 0.0,
                    forceActiveItemId: self.selectedPack.flatMap { AnyHashable($0.info.id) },
                    displayHighlightInExpanded: true,
                    automaticallySelectsFirstItem: false,
                    itemSpacing: 14.0,
                    activeContentItemIdUpdated: self.packPanelActiveItemUpdated,
                    reorderItems: { _ in }
                )),
                environment: {
                    EntityKeyboardTopContainerPanelEnvironment(
                        isContentInFocus: true,
                        height: collapsedPackPanelHeight,
                        visibilityFractionUpdated: self.packPanelVisibilityFractionUpdated,
                        isExpandedUpdated: { _, _ in }
                    )
                },
                containerSize: CGSize(width: size.width, height: self.currentVisiblePackPanelHeight)
            )
            
            if let view = self.packPanel.view {
                if view.superview == nil {
                    self.view.addSubview(view)
                }
                componentTransition.setFrame(view: view, frame: CGRect(origin: CGPoint(), size: panelSize))
            }
        } else if let view = self.packPanel.view {
            view.removeFromSuperview()
        }
        
        let isVisible = self.isInstallPackButtonVisible
        
        let componentTransition = ComponentTransition(transition)
        let edgeEffectHeight: CGFloat = isVisible ? 88.0 + bottomInset : 0.0
        let edgeEffectFrame = CGRect(origin: CGPoint(x: 0.0, y: size.height - edgeEffectHeight), size: CGSize(width: size.width, height: edgeEffectHeight))
        transition.updateFrame(view: self.bottomEdgeEffectView, frame: edgeEffectFrame)
        self.bottomEdgeEffectView.update(
            content: self.theme.chat.inputMediaPanel.stickersBackgroundColor.withAlphaComponent(1.0),
            blur: true,
            alpha: 1.0,
            rect: edgeEffectFrame,
            edge: .bottom,
            edgeSize: min(edgeEffectFrame.height, 80.0),
            transition: componentTransition
        )
        transition.updateAlpha(layer: self.bottomEdgeEffectView.layer, alpha: isVisible ? 1.0 : 0.0)

        if isVisible, let selectedPack = self.selectedPack {
            let buttonTitle = self.strings.StickerPack_AddStickerCount(selectedPack.info.count)
            let buttonForegroundColor = self.theme.list.itemCheckColors.foregroundColor
            let buttonBackgroundColor = self.theme.list.itemCheckColors.fillColor
            let buttonInsets = ContainerViewLayout.concentricInsets(bottomInset: bottomInset, innerDiameter: 52.0, sideInset: 30.0)
            let buttonSize = self.selectedPackAddButton.update(
                transition: componentTransition,
                component: AnyComponent(ButtonComponent(
                    background: ButtonComponent.Background(
                        style: .actualGlass,
                        color: buttonBackgroundColor,
                        foreground: buttonForegroundColor,
                        pressedColor: buttonBackgroundColor.withMultipliedAlpha(0.9)
                    ),
                    content: AnyComponentWithIdentity(
                        id: AnyHashable(buttonTitle),
                        component: AnyComponent(Text(text: buttonTitle, font: Font.semibold(17.0), color: buttonForegroundColor))
                    ),
                    action: { [weak self] in
                        self?.installSelectedStickerPack()
                    }
                )),
                environment: {},
                containerSize: CGSize(width: max(0.0, size.width - buttonInsets.left - buttonInsets.right), height: 52.0)
            )

            if let buttonView = self.selectedPackAddButton.view {
                if buttonView.superview == nil {
                    self.view.addSubview(buttonView)
                }
                buttonView.isUserInteractionEnabled = true
                buttonView.frame = CGRect(origin: CGPoint(x: floor((size.width - buttonSize.width) / 2.0), y: size.height - bottomInset - buttonInsets.bottom - buttonSize.height), size: buttonSize)
                componentTransition.setAlpha(view: buttonView, alpha: 1.0)
            }
        } else if let buttonView = self.selectedPackAddButton.view {
            buttonView.isUserInteractionEnabled = false
            componentTransition.setAlpha(view: buttonView, alpha: 0.0)
        }
    }
    
    func requestLayout(transition: ContainedViewLayoutTransition) {
        guard let (size, leftInset, rightInset, bottomInset, inputHeight, deviceMetrics) = self.validLayout else {
            return
        }
        self.updateLayout(size: size, leftInset: leftInset, rightInset: rightInset, bottomInset: bottomInset, inputHeight: inputHeight, deviceMetrics: deviceMetrics, transition: transition)
    }

    func updateLayout(size: CGSize, leftInset: CGFloat, rightInset: CGFloat, bottomInset: CGFloat, inputHeight: CGFloat, deviceMetrics: DeviceMetrics, transition: ContainedViewLayoutTransition) {
        let firstLayout = self.validLayout == nil

        self.validLayout = (size, leftInset, rightInset, bottomInset, inputHeight, deviceMetrics)

        let edgeEffectHeight: CGFloat = 80.0
        let edgeEffectFrame = CGRect(origin: .zero, size: CGSize(width: size.width, height: edgeEffectHeight))
        transition.updateFrame(view: self.topEdgeEffectView, frame: edgeEffectFrame)
        self.topEdgeEffectView.update(
            content: self.theme.chat.inputMediaPanel.stickersBackgroundColor.withAlphaComponent(1.0),
            blur: true,
            alpha: 1.0,
            rect: edgeEffectFrame,
            edge: .top,
            edgeSize: edgeEffectFrame.height,
            transition: ComponentTransition(transition)
        )
        transition.updateAlpha(layer: self.topEdgeEffectView.layer, alpha: self.shouldDisplayPackPanel ? 1.0 : 0.0)
        self.updatePackButtonsLayout(size: size, bottomInset: bottomInset, transition: transition)

        if let image = self.notFoundNode.image {
            let areaHeight = max(0.0, size.height - inputHeight)

            let labelSize = self.notFoundLabel.updateLayout(CGSize(width: size.width, height: CGFloat.greatestFiniteMagnitude))

            transition.updateFrame(node: self.notFoundNode, frame: CGRect(origin: CGPoint(x: floor((size.width - image.size.width) / 2.0), y: floor((areaHeight - image.size.height - labelSize.height) / 2.0)), size: image.size))
            transition.updateFrame(node: self.notFoundLabel, frame: CGRect(origin: CGPoint(x: floor((image.size.width - labelSize.width) / 2.0), y: image.size.height + 8.0), size: labelSize))
        }

        let contentFrame = CGRect(origin: CGPoint(), size: size)
        let gridTopInset: CGFloat = 4.0 + self.currentPackPanelHeight
        self.gridNode.transaction(GridNodeTransaction(deleteItems: [], insertItems: [], updateItems: [], scrollToItem: nil, updateLayout: GridNodeUpdateLayout(layout: GridNodeLayout(size: contentFrame.size, insets: UIEdgeInsets(top: gridTopInset, left: 0.0, bottom: 4.0 + bottomInset + 64.0, right: 0.0), preloadSize: 300.0, type: .fixed(itemSize: CGSize(width: 75.0, height: 75.0), fillWidth: nil, lineSpacing: 0.0, itemSpacing: nil)), transition: transition), itemTransition: .immediate, stationaryItems: .none, updateFirstIndexInSectionOffset: nil), completion: { _ in })

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
        if let view = self.packPanel.view {
            view.alpha = 0.0
            ComponentTransition(transition).setAlpha(view: view, alpha: 1.0)
        }
        self.topEdgeEffectView.alpha = 0.0
        ComponentTransition(transition).setAlpha(view: self.topEdgeEffectView, alpha: self.shouldDisplayPackPanel ? 1.0 : 0.0)
        self.bottomEdgeEffectView.alpha = 0.0
        ComponentTransition(transition).setAlpha(view: self.bottomEdgeEffectView, alpha: self.isInstallPackButtonVisible ? 1.0 : 0.0)
        if let buttonView = self.selectedPackAddButton.view {
            buttonView.alpha = 0.0
            ComponentTransition(transition).setAlpha(view: buttonView, alpha: self.isInstallPackButtonVisible ? 1.0 : 0.0)
        }
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
        if let view = self.packPanel.view {
            ComponentTransition(transition).setAlpha(view: view, alpha: 0.0)
        }
        ComponentTransition(transition).setAlpha(view: self.topEdgeEffectView, alpha: 0.0)
        ComponentTransition(transition).setAlpha(view: self.bottomEdgeEffectView, alpha: 0.0)
        if let buttonView = self.selectedPackAddButton.view {
            ComponentTransition(transition).setAlpha(view: buttonView, alpha: 0.0)
        }
        transition.updateAlpha(node: self.trendingPane, alpha: 0.0, completion: { _ in
        })
        transition.updateAlpha(node: self.notFoundNode, alpha: 0.0, completion: { _ in
        })
    }
}
