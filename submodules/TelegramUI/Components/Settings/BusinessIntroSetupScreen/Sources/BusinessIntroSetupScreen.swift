import Foundation
import UIKit
import Display
import AsyncDisplayKit
import SwiftSignalKit
import Postbox
import TelegramCore
import TelegramPresentationData
import TelegramUIPreferences
import PresentationDataUtils
import AccountContext
import ComponentFlow
import ViewControllerComponent
import MultilineTextComponent
import BalancedTextComponent
import ListSectionComponent
import ListActionItemComponent
import ListMultilineTextFieldItemComponent
import BundleIconComponent
import LottieComponent
import EntityKeyboard
import PeerAllowedReactionsScreen
import EmojiActionIconComponent
import TextFieldComponent

final class BusinessIntroSetupScreenComponent: Component {
    typealias EnvironmentType = ViewControllerComponentContainer.Environment
    
    let context: AccountContext
    let initialData: BusinessIntroSetupScreen.InitialData

    init(
        context: AccountContext,
        initialData: BusinessIntroSetupScreen.InitialData
    ) {
        self.context = context
        self.initialData = initialData
    }

    static func ==(lhs: BusinessIntroSetupScreenComponent, rhs: BusinessIntroSetupScreenComponent) -> Bool {
        if lhs.context !== rhs.context {
            return false
        }

        return true
    }
    
    private final class ScrollView: UIScrollView {
        override func touchesShouldCancel(in view: UIView) -> Bool {
            return true
        }
    }
    
    private struct EmojiSearchResult {
        var groups: [EmojiPagerContentComponent.ItemGroup]
        var id: AnyHashable
        var version: Int
        var isPreset: Bool
    }
    
    private struct EmojiSearchState {
        var result: EmojiSearchResult?
        var isSearching: Bool
        
        init(result: EmojiSearchResult?, isSearching: Bool) {
            self.result = result
            self.isSearching = isSearching
        }
    }
    
    final class View: UIView, UIScrollViewDelegate {
        private let topOverscrollLayer = SimpleLayer()
        private let scrollView: ScrollView
        
        private let navigationTitle = ComponentView<Empty>()
        private let introContent = ComponentView<Empty>()
        private let introSection = ComponentView<Empty>()
        private let deleteSection = ComponentView<Empty>()
        
        private var ignoreScrolling: Bool = false
        private var isUpdating: Bool = false
        
        private var component: BusinessIntroSetupScreenComponent?
        private(set) weak var state: EmptyComponentState?
        private var environment: EnvironmentType?
        
        private let introPlaceholderTag = NSObject()
        private let titleInputState = ListMultilineTextFieldItemComponent.ExternalState()
        private let titleInputTag = NSObject()
        private var resetTitle: String?
        private let textInputState = ListMultilineTextFieldItemComponent.ExternalState()
        private let textInputTag = NSObject()
        private var resetText: String?
        
        private var previousHadInputHeight: Bool = false
        private var recenterOnTag: NSObject?
        
        private var stickerFile: TelegramMediaFile?
        
        private var stickerContent: EmojiPagerContentComponent?
        private var stickerContentDisposable: Disposable?
        private let stickerSearchDisposable = MetaDisposable()
        private var stickerSearchState = EmojiSearchState(result: nil, isSearching: false)
        
        private var displayStickerInput: Bool = false
        private var stickerSelectionControlDimView: UIView?
        private var stickerSelectionControl: ComponentView<Empty>?
        
        override init(frame: CGRect) {
            self.scrollView = ScrollView()
            self.scrollView.showsVerticalScrollIndicator = true
            self.scrollView.showsHorizontalScrollIndicator = false
            self.scrollView.scrollsToTop = false
            self.scrollView.delaysContentTouches = false
            self.scrollView.canCancelContentTouches = true
            self.scrollView.contentInsetAdjustmentBehavior = .never
            if #available(iOS 13.0, *) {
                self.scrollView.automaticallyAdjustsScrollIndicatorInsets = false
            }
            self.scrollView.alwaysBounceVertical = true
            
            super.init(frame: frame)
            
            self.scrollView.delegate = self
            self.addSubview(self.scrollView)
            
            self.scrollView.layer.addSublayer(self.topOverscrollLayer)
        }
        
        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }
        
        deinit {
            self.stickerContentDisposable?.dispose()
        }

        func scrollToTop() {
            self.scrollView.setContentOffset(CGPoint(), animated: true)
        }
        
        func attemptNavigation(complete: @escaping () -> Void) -> Bool {
            guard let component = self.component, let environment = self.environment else {
                return true
            }
            let _ = environment
            
            let title = self.titleInputState.text.string
            let text = self.textInputState.text.string
            
            let intro: TelegramBusinessIntro?
            if !title.isEmpty || !text.isEmpty || self.stickerFile != nil {
                intro = TelegramBusinessIntro(title: title, text: text, stickerFile: self.stickerFile)
            } else {
                intro = nil
            }
            if intro != component.initialData.intro {
                let _ = component.context.engine.accountData.updateBusinessIntro(intro: intro).startStandalone()
            }
            
            return true
        }
        
        func openStickerEditor() {
            guard let component = self.component, let environment = self.environment, let controller = environment.controller() as? BusinessIntroSetupScreen else {
                return
            }
            
            let context = component.context
            let navigationController = controller.navigationController as? NavigationController
            
            var dismissImpl: (() -> Void)?
            let mainController = context.sharedContext.makeStickerMediaPickerScreen(
                context: context,
                getSourceRect: { return .zero },
                completion: { result, transitionView, transitionRect, transitionImage, fromCamera, completion, cancelled in
                    let editorController = context.sharedContext.makeStickerEditorScreen(
                        context: context,
                        source: result,
                        intro: true,
                        transitionArguments: transitionView.flatMap { ($0, transitionRect, transitionImage) },
                        completion: { [weak self] file, emoji, commit in
                            dismissImpl?()
                            
                            guard let self else {
                                return
                            }
                           
                            self.stickerFile = file
                            if !self.isUpdating {
                                self.state?.updated(transition: .spring(duration: 0.4))
                            }
                            
                            commit()
                        },
                        cancelled: cancelled
                    )
                    navigationController?.pushViewController(editorController)
                },
                dismissed: {}
            )
            dismissImpl = { [weak mainController] in
                if let mainController, let navigationController = mainController.navigationController {
                    var viewControllers = navigationController.viewControllers
                    viewControllers = viewControllers.filter { c in
                        return !(c is CameraScreen) && c !== mainController
                    }
                    navigationController.setViewControllers(viewControllers, animated: false)
                }
            }
            navigationController?.pushViewController(mainController)
        }
        
        func scrollViewDidScroll(_ scrollView: UIScrollView) {
            if !self.ignoreScrolling {
                self.updateScrolling(transition: .immediate)
            }
        }
        
        private var scrolledUp = true
        private func updateScrolling(transition: ComponentTransition) {
            let navigationRevealOffsetY: CGFloat = 0.0
            
            let navigationAlphaDistance: CGFloat = 16.0
            let navigationAlpha: CGFloat = max(0.0, min(1.0, (self.scrollView.contentOffset.y - navigationRevealOffsetY) / navigationAlphaDistance))
            if let controller = self.environment?.controller(), let navigationBar = controller.navigationBar {
                transition.setAlpha(layer: navigationBar.backgroundNode.layer, alpha: navigationAlpha)
                transition.setAlpha(layer: navigationBar.stripeNode.layer, alpha: navigationAlpha)
            }
            
            var scrolledUp = false
            if navigationAlpha < 0.5 {
                scrolledUp = true
            } else if navigationAlpha > 0.5 {
                scrolledUp = false
            }
            
            if self.scrolledUp != scrolledUp {
                self.scrolledUp = scrolledUp
                if !self.isUpdating {
                    self.state?.updated()
                }
            }
            
            if let navigationTitleView = self.navigationTitle.view {
                transition.setAlpha(view: navigationTitleView, alpha: 1.0)
            }
        }
        
        @objc private func stickerSelectionControlDimTapGesture(_ recognizer: UITapGestureRecognizer) {
            if case .ended = recognizer.state {
                self.displayStickerInput = false
                self.state?.updated(transition: .spring(duration: 0.4))
            }
        }
        
        func update(component: BusinessIntroSetupScreenComponent, availableSize: CGSize, state: EmptyComponentState, environment: Environment<EnvironmentType>, transition: ComponentTransition) -> CGSize {
            self.isUpdating = true
            defer {
                self.isUpdating = false
            }
            
            if self.component == nil {
                if let intro = component.initialData.intro {
                    self.resetTitle = intro.title
                    self.resetText = intro.text
                    self.stickerFile = intro.stickerFile
                }
            }
            
            if self.stickerContentDisposable == nil {
                let stickerContent = EmojiPagerContentComponent.stickerInputData(
                    context: component.context,
                    animationCache: component.context.animationCache,
                    animationRenderer: component.context.animationRenderer,
                    stickerNamespaces: [Namespaces.ItemCollection.CloudStickerPacks],
                    stickerOrderedItemListCollectionIds: [Namespaces.OrderedItemList.CloudSavedStickers, Namespaces.OrderedItemList.CloudRecentStickers, Namespaces.OrderedItemList.CloudAllPremiumStickers],
                    chatPeerId: nil,
                    hasSearch: true,
                    hasTrending: false,
                    forceHasPremium: true,
                    hasAdd: true,
                    searchIsPlaceholderOnly: false,
                    subject: .greetingStickers
                )
                self.stickerContentDisposable = (stickerContent
                |> deliverOnMainQueue).start(next: { [weak self] stickerContent in
                    guard let self else {
                        return
                    }
                    self.stickerContent = stickerContent
                    
                    stickerContent.inputInteractionHolder.inputInteraction = EmojiPagerContentComponent.InputInteraction(
                        performItemAction: { [weak self] _, item, _, _, _, _ in
                            guard let self else {
                                return
                            }
                            guard let itemFile = item.itemFile else {
                                if case .icon(.add) = item.content {
                                    self.openStickerEditor()
                                    self.displayStickerInput = false
                                    if !self.isUpdating {
                                        self.state?.updated(transition: .spring(duration: 0.4))
                                    }
                                }
                                return
                            }
                            
                            self.stickerFile = itemFile._parse()
                            self.displayStickerInput = false
                            
                            self.stickerSearchDisposable.set(nil)
                            self.stickerSearchState = EmojiSearchState(result: nil, isSearching: false)
                            
                            if !self.isUpdating {
                                self.state?.updated(transition: .spring(duration: 0.4))
                            }
                        },
                        deleteBackwards: nil,
                        openStickerSettings: nil,
                        openFeatured: nil,
                        openSearch: {
                        },
                        addGroupAction: { _, _, _ in
                        },
                        clearGroup: { _ in
                        },
                        editAction: { _ in
                        },
                        pushController: { c in
                        },
                        presentController: { c in
                        },
                        presentGlobalOverlayController: { c in
                        },
                        navigationController: {
                            return nil
                        },
                        requestUpdate: { [weak self] transition in
                            guard let self else {
                                return
                            }
                            if let stickerSelectionControlView = self.stickerSelectionControl?.view as? EmojiSelectionComponent.View {
                                stickerSelectionControlView.internalRequestUpdate(transition: transition)
                            }
                        },
                        updateSearchQuery: { [weak self] query in
                            guard let self, let component = self.component else {
                                return
                            }
                            
                            switch query {
                            case .none:
                                self.stickerSearchDisposable.set(nil)
                                self.stickerSearchState = EmojiSearchState(result: nil, isSearching: false)
                                if !self.isUpdating {
                                    self.state?.updated(transition: .immediate)
                                }
                            case let .text(rawQuery, languageCode):
                                let query = rawQuery.trimmingCharacters(in: .whitespacesAndNewlines)
                                
                                if query.isEmpty {
                                    self.stickerSearchDisposable.set(nil)
                                    self.stickerSearchState = EmojiSearchState(result: nil, isSearching: false)
                                    self.state?.updated(transition: .immediate)
                                } else {
                                    let context = component.context
                                    
                                    let stickers: Signal<[(String?, FoundStickerItem)], NoError> = Signal { subscriber in
                                        var signals: Signal<[Signal<(String?, [FoundStickerItem]), NoError>], NoError> = .single([])
                                        
                                        if query.isSingleEmoji {
                                            signals = .single([context.engine.stickers.searchStickers(query: nil, emoticon: [query.basicEmoji.0])
                                            |> map { (nil, $0.items) }])
                                        } else if query.count > 1, !languageCode.isEmpty && languageCode != "emoji" {
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
                                            |> map { keywords -> [Signal<(String?, [FoundStickerItem]), NoError>] in
                                                let emoticon = keywords.flatMap { $0.emoticons }.map { $0.basicEmoji.0 }
                                                return [context.engine.stickers.searchStickers(query: query, emoticon: emoticon, inputLanguageCode: languageCode)
                                                |> map { (nil, $0.items) }]
                                            }
                                        }
                                        
                                        return (signals
                                        |> mapToSignal { signals in
                                            return combineLatest(signals)
                                        }).start(next: { results in
                                            var result: [(String?, FoundStickerItem)] = []
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
                                    
                                    let currentRemotePacks = Atomic<FoundStickerSets?>(value: nil)
                                    
                                    let local = context.engine.stickers.searchStickerSets(query: query)
                                    let remote = context.engine.stickers.searchStickerSetsRemotely(query: query)
                                    |> delay(0.2, queue: Queue.mainQueue())
                                    let rawPacks = local
                                    |> mapToSignal { result -> Signal<(FoundStickerSets, Bool, FoundStickerSets?), NoError> in
                                        var localResult = result
                                        if let currentRemote = currentRemotePacks.with ({ $0 }) {
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
                                    
                                    let signal = combineLatest(stickers, packs)
                                    |> map { stickers, packs -> ([(String?, FoundStickerItem)], FoundStickerSets, Bool, FoundStickerSets?)? in
                                        return (stickers, packs.0, packs.1, packs.2)
                                    }
                                    
                                    let resultSignal: Signal<[EmojiPagerContentComponent.ItemGroup], NoError> = signal
                                    |> mapToSignal { result in
                                        guard let result else {
                                            return .complete()
                                        }
                                        
                                        let (foundItems, localSets, complete, remoteSets) = result
                                        
                                        var items: [EmojiPagerContentComponent.Item] = []
                                        
                                        var existingIds = Set<MediaId>()
                                        for (_, entry) in foundItems {
                                            let itemFile = entry.file
                                            
                                            if existingIds.contains(itemFile.fileId) {
                                                continue
                                            }
                                            existingIds.insert(itemFile.fileId)
                                            
                                            let animationData = EntityKeyboardAnimationData(file: TelegramMediaFile.Accessor(itemFile))
                                            let item = EmojiPagerContentComponent.Item(
                                                animationData: animationData,
                                                content: .animation(animationData),
                                                itemFile: TelegramMediaFile.Accessor(itemFile),
                                                subgroupId: nil,
                                                icon: .none,
                                                tintMode: animationData.isTemplate ? .primary : .none
                                            )
                                            items.append(item)
                                        }
                                        
                                        var mergedSets = localSets
                                        if let remoteSets {
                                            mergedSets = mergedSets.merge(with: remoteSets)
                                        }
                                        for entry in mergedSets.entries {
                                            guard let stickerPackItem = entry.item as? StickerPackItem else {
                                                continue
                                            }
                                            let itemFile = stickerPackItem.file
                                            
                                            if existingIds.contains(itemFile.fileId) {
                                                continue
                                            }
                                            existingIds.insert(itemFile.fileId)
                                            
                                            let animationData = EntityKeyboardAnimationData(file: itemFile)
                                            let item = EmojiPagerContentComponent.Item(
                                                animationData: animationData,
                                                content: .animation(animationData),
                                                itemFile: itemFile,
                                                subgroupId: nil,
                                                icon: .none,
                                                tintMode: animationData.isTemplate ? .primary : .none
                                            )
                                            items.append(item)
                                        }
                                        
                                        if items.isEmpty && !complete {
                                            return .complete()
                                        }
                                    
                                        return .single([EmojiPagerContentComponent.ItemGroup(
                                            supergroupId: "search",
                                            groupId: "search",
                                            title: nil,
                                            subtitle: nil,
                                            badge: nil,
                                            actionButtonTitle: nil,
                                            isFeatured: false,
                                            isPremiumLocked: false,
                                            isEmbedded: false,
                                            hasClear: false,
                                            hasEdit: false,
                                            collapsedLineCount: nil,
                                            displayPremiumBadges: false,
                                            headerItem: nil,
                                            fillWithLoadingPlaceholders: false,
                                            items: items
                                        )])
                                    }
                                    
                                    var version = 0
                                    self.stickerSearchState.isSearching = true
                                    self.state?.updated(transition: .immediate)
                                    
                                    self.stickerSearchDisposable.set((resultSignal
                                    |> delay(0.15, queue: .mainQueue())
                                    |> deliverOnMainQueue).start(next: { [weak self] result in
                                        guard let self else {
                                            return
                                        }
                                        
                                        self.stickerSearchState = EmojiSearchState(result: EmojiSearchResult(groups: result, id: AnyHashable(query), version: version, isPreset: false), isSearching: false)
                                        version += 1
                                        self.state?.updated(transition: .immediate)
                                    }))
                                }
                            case let .category(value):
                                let resultSignal = component.context.engine.stickers.searchStickers(category: value, scope: [.installed, .remote])
                                |> mapToSignal { files -> Signal<(items: [EmojiPagerContentComponent.ItemGroup], isFinalResult: Bool), NoError> in
                                    var items: [EmojiPagerContentComponent.Item] = []
                                    
                                    var existingIds = Set<MediaId>()
                                    for item in files.items {
                                        let itemFile = item.file
                                        if existingIds.contains(itemFile.fileId) {
                                            continue
                                        }
                                        existingIds.insert(itemFile.fileId)
                                        let animationData = EntityKeyboardAnimationData(file: TelegramMediaFile.Accessor(itemFile))
                                        let item = EmojiPagerContentComponent.Item(
                                            animationData: animationData,
                                            content: .animation(animationData),
                                            itemFile: TelegramMediaFile.Accessor(itemFile),
                                            subgroupId: nil,
                                            icon: itemFile.isPremiumSticker ? .premium : .none,
                                            tintMode: animationData.isTemplate ? .primary : .none
                                        )
                                        items.append(item)
                                    }
                                    
                                    return .single(([EmojiPagerContentComponent.ItemGroup(
                                        supergroupId: "search",
                                        groupId: "search",
                                        title: nil,
                                        subtitle: nil,
                                        badge: nil,
                                        actionButtonTitle: nil,
                                        isFeatured: false,
                                        isPremiumLocked: false,
                                        isEmbedded: false,
                                        hasClear: false,
                                        hasEdit: false,
                                        collapsedLineCount: nil,
                                        displayPremiumBadges: false,
                                        headerItem: nil,
                                        fillWithLoadingPlaceholders: false,
                                        items: items
                                    )], files.isFinalResult))
                                }
                                    
                                var version = 0
                                self.stickerSearchDisposable.set((resultSignal
                                |> deliverOnMainQueue).start(next: { [weak self] result in
                                    guard let self else {
                                        return
                                    }
                                    guard let group = result.items.first else {
                                        return
                                    }
                                    if group.items.isEmpty && !result.isFinalResult {
                                        self.stickerSearchState = EmojiSearchState(result: EmojiSearchResult(groups: [
                                            EmojiPagerContentComponent.ItemGroup(
                                                supergroupId: "search",
                                                groupId: "search",
                                                title: nil,
                                                subtitle: nil,
                                                badge: nil,
                                                actionButtonTitle: nil,
                                                isFeatured: false,
                                                isPremiumLocked: false,
                                                isEmbedded: false,
                                                hasClear: false,
                                                hasEdit: false,
                                                collapsedLineCount: nil,
                                                displayPremiumBadges: false,
                                                headerItem: nil,
                                                fillWithLoadingPlaceholders: true,
                                                items: []
                                            )
                                        ], id: AnyHashable(value.id), version: version, isPreset: true), isSearching: false)
                                        if !self.isUpdating {
                                            self.state?.updated(transition: .immediate)
                                        }
                                        return
                                    }
                                    self.stickerSearchState = EmojiSearchState(result: EmojiSearchResult(groups: result.items, id: AnyHashable(value.id), version: version, isPreset: true), isSearching: false)
                                    version += 1
                                    if !self.isUpdating {
                                        self.state?.updated(transition: .immediate)
                                    }
                                }))
                            }
                        },
                        updateScrollingToItemGroup: {
                        },
                        onScroll: {},
                        chatPeerId: nil,
                        peekBehavior: nil,
                        customLayout: nil,
                        externalBackground: nil,
                        externalExpansionView: nil,
                        customContentView: nil,
                        useOpaqueTheme: true,
                        hideBackground: false,
                        stateContext: nil,
                        addImage: nil
                    )
                    
                    if !self.isUpdating {
                        self.state?.updated(transition: .immediate)
                    }
                })
            }
            
            let environment = environment[EnvironmentType.self].value
            let themeUpdated = self.environment?.theme !== environment.theme
            self.environment = environment
            
            self.component = component
            self.state = state
            
            let alphaTransition: ComponentTransition
            if !transition.animation.isImmediate {
                alphaTransition = .easeInOut(duration: 0.25)
            } else {
                alphaTransition = .immediate
            }
            
            if themeUpdated {
                self.backgroundColor = environment.theme.list.blocksBackgroundColor
            }
            
            let presentationData = component.context.sharedContext.currentPresentationData.with { $0 }
            
            let _ = alphaTransition
            let _ = presentationData
            
            let navigationTitleSize = self.navigationTitle.update(
                transition: transition,
                component: AnyComponent(MultilineTextComponent(
                    text: .plain(NSAttributedString(string: environment.strings.Business_Intro_Title, font: Font.semibold(17.0), textColor: environment.theme.rootController.navigationBar.primaryTextColor)),
                    horizontalAlignment: .center
                )),
                environment: {},
                containerSize: CGSize(width: availableSize.width, height: 100.0)
            )
            let navigationTitleFrame = CGRect(origin: CGPoint(x: floor((availableSize.width - navigationTitleSize.width) / 2.0), y: environment.statusBarHeight + floor((environment.navigationHeight - environment.statusBarHeight - navigationTitleSize.height) / 2.0)), size: navigationTitleSize)
            if let navigationTitleView = self.navigationTitle.view {
                if navigationTitleView.superview == nil {
                    if let controller = self.environment?.controller(), let navigationBar = controller.navigationBar {
                        navigationBar.view.addSubview(navigationTitleView)
                    }
                }
                transition.setFrame(view: navigationTitleView, frame: navigationTitleFrame)
            }
            
            let bottomContentInset: CGFloat = 24.0
            let sideInset: CGFloat = 16.0 + environment.safeInsets.left
            let sectionSpacing: CGFloat = 24.0
            
            var contentHeight: CGFloat = 0.0
            
            contentHeight += environment.navigationHeight
            contentHeight += 26.0
            
            let maxTitleLength = 32
            let maxTextLength = 70
            
            self.recenterOnTag = nil
            if let hint = transition.userData(TextFieldComponent.AnimationHint.self), let targetView = hint.view {
                if let titleView = self.introSection.findTaggedView(tag: self.titleInputTag) {
                    if targetView.isDescendant(of: titleView) {
                        self.recenterOnTag = self.titleInputTag
                    }
                }
                if let textView = self.introSection.findTaggedView(tag: self.textInputTag) {
                    if targetView.isDescendant(of: textView) {
                        self.recenterOnTag = self.textInputTag
                    }
                }
            }
            
            var introSectionItems: [AnyComponentWithIdentity<Empty>] = []
            introSectionItems.append(AnyComponentWithIdentity(id: introSectionItems.count, component: AnyComponent(Rectangle(color: .clear, height: 346.0, tag: self.introPlaceholderTag))))
            introSectionItems.append(AnyComponentWithIdentity(id: introSectionItems.count, component: AnyComponent(ListMultilineTextFieldItemComponent(
                externalState: self.titleInputState,
                context: component.context,
                theme: environment.theme,
                strings: environment.strings,
                initialText: "",
                resetText: self.resetTitle.flatMap {
                    return ListMultilineTextFieldItemComponent.ResetText(value: $0)
                },
                placeholder: environment.strings.Business_Intro_IntroTitlePlaceholder,
                autocapitalizationType: .none,
                autocorrectionType: .no,
                returnKeyType: .next,
                characterLimit: maxTitleLength,
                displayCharacterLimit: true,
                emptyLineHandling: .notAllowed,
                updated: { _ in
                },
                returnKeyAction: { [weak self] in
                    guard let self else {
                        return
                    }
                    
                    if let titleView = self.introSection.findTaggedView(tag: self.textInputTag) as? ListMultilineTextFieldItemComponent.View {
                        titleView.activateInput()
                    }
                },
                textUpdateTransition: .spring(duration: 0.4),
                tag: self.titleInputTag
            ))))
            self.resetTitle = nil
            introSectionItems.append(AnyComponentWithIdentity(id: introSectionItems.count, component: AnyComponent(ListMultilineTextFieldItemComponent(
                externalState: self.textInputState,
                context: component.context,
                theme: environment.theme,
                strings: environment.strings,
                initialText: "",
                resetText: self.resetText.flatMap {
                    return ListMultilineTextFieldItemComponent.ResetText(value: $0)
                },
                placeholder: environment.strings.Business_Intro_IntroTextPlaceholder,
                autocapitalizationType: .none,
                autocorrectionType: .no,
                returnKeyType: .done,
                characterLimit: 70,
                displayCharacterLimit: true,
                emptyLineHandling: .notAllowed,
                updated: { _ in
                },
                returnKeyAction: { [weak self] in
                    guard let self else {
                        return
                    }
                    if let titleView = self.introSection.findTaggedView(tag: self.textInputTag) as? ListMultilineTextFieldItemComponent.View {
                        titleView.endEditing(true)
                    }
                },
                textUpdateTransition: .spring(duration: 0.4),
                tag: self.textInputTag
            ))))
            self.resetText = nil
            
            let stickerIcon: ListActionItemComponent.Icon
            if let stickerFile = self.stickerFile {
                stickerIcon = ListActionItemComponent.Icon(component: AnyComponentWithIdentity(id: 0, component: AnyComponent(EmojiActionIconComponent(
                    context: component.context,
                    color: environment.theme.list.itemPrimaryTextColor,
                    fileId: stickerFile.fileId.id,
                    file: stickerFile
                ))))
            } else {
                stickerIcon = ListActionItemComponent.Icon(component: AnyComponentWithIdentity(id: 1, component: AnyComponent(MultilineTextComponent(
                    text: .plain(NSAttributedString(
                        string: environment.strings.Business_Intro_IntroStickerValueRandom,
                        font: Font.regular(presentationData.listsFontSize.baseDisplaySize),
                        textColor: environment.theme.list.itemSecondaryTextColor
                    )),
                    maximumNumberOfLines: 1
                ))))
            }
            
            introSectionItems.append(AnyComponentWithIdentity(id: introSectionItems.count, component: AnyComponent(ListActionItemComponent(
                theme: environment.theme,
                title: AnyComponent(VStack([
                    AnyComponentWithIdentity(id: AnyHashable(0), component: AnyComponent(MultilineTextComponent(
                        text: .plain(NSAttributedString(
                            string: environment.strings.Business_Intro_IntroSticker,
                            font: Font.regular(presentationData.listsFontSize.baseDisplaySize),
                            textColor: environment.theme.list.itemPrimaryTextColor
                        )),
                        maximumNumberOfLines: 1
                    ))),
                ], alignment: .left, spacing: 2.0)),
                icon: stickerIcon,
                accessory: .none,
                action: { [weak self] _ in
                    guard let self else {
                        return
                    }
                    
                    self.displayStickerInput = true
                    self.endEditing(true)
                    
                    if !self.isUpdating {
                        self.state?.updated(transition: .spring(duration: 0.5))
                    }
                }
            ))))
            let introSectionSize = self.introSection.update(
                transition: transition,
                component: AnyComponent(ListSectionComponent(
                    theme: environment.theme,
                    header: AnyComponent(MultilineTextComponent(
                        text: .plain(NSAttributedString(
                            string: environment.strings.Business_Intro_CustomizeSectionHeader,
                            font: Font.regular(presentationData.listsFontSize.itemListBaseHeaderFontSize),
                            textColor: environment.theme.list.freeTextColor
                        )),
                        maximumNumberOfLines: 0
                    )),
                    footer: AnyComponent(MultilineTextComponent(
                        text: .plain(NSAttributedString(
                            string: environment.strings.Business_Intro_CustomizeSectionFooter,
                            font: Font.regular(presentationData.listsFontSize.itemListBaseHeaderFontSize),
                            textColor: environment.theme.list.freeTextColor
                        )),
                        maximumNumberOfLines: 0
                    )),
                    items: introSectionItems
                )),
                environment: {},
                containerSize: CGSize(width: availableSize.width - sideInset * 2.0, height: 10000.0)
            )
            let introSectionFrame = CGRect(origin: CGPoint(x: sideInset, y: contentHeight), size: introSectionSize)
            if let introSectionView = self.introSection.view {
                if introSectionView.superview == nil {
                    self.scrollView.addSubview(introSectionView)
                    self.introSection.parentState = state
                }
                transition.setFrame(view: introSectionView, frame: introSectionFrame)
            }
            contentHeight += introSectionSize.height
            contentHeight += sectionSpacing
            
            let titleText: String
            if self.titleInputState.text.string.isEmpty {
                titleText = environment.strings.Conversation_EmptyPlaceholder
            } else {
                let rawTitle = self.titleInputState.text.string
                titleText = rawTitle.count <= maxTitleLength ? rawTitle : String(rawTitle[rawTitle.startIndex ..< rawTitle.index(rawTitle.startIndex, offsetBy: maxTitleLength)])
            }
            
            let textText: String
            if self.textInputState.text.string.isEmpty {
                textText = environment.strings.Conversation_GreetingText
            } else {
                let rawText = self.textInputState.text.string
                textText = rawText.count <= maxTextLength ? rawText : String(rawText[rawText.startIndex ..< rawText.index(rawText.startIndex, offsetBy: maxTextLength)])
            }
            
            let introContentSize = self.introContent.update(
                transition: transition,
                component: AnyComponent(ChatIntroItemComponent(
                    context: component.context,
                    theme: environment.theme,
                    strings: environment.strings,
                    stickerFile: stickerFile,
                    title: titleText,
                    text: textText
                )),
                environment: {},
                containerSize: CGSize(width: availableSize.width - sideInset * 2.0, height: 10000.0)
            )
            if let introContentView = self.introContent.view {
                if introContentView.superview == nil {
                    if let placeholderView = self.introSection.findTaggedView(tag: self.introPlaceholderTag) {
                        placeholderView.addSubview(introContentView)
                    }
                }
                transition.setFrame(view: introContentView, frame: CGRect(origin: CGPoint(), size: introContentSize))
            }
            
            if self.recenterOnTag == nil && self.previousHadInputHeight != (environment.inputHeight > 0.0) {
                if self.titleInputState.isEditing {
                    self.recenterOnTag = self.titleInputTag
                } else if self.textInputState.isEditing {
                    self.recenterOnTag = self.textInputTag
                }
            }
            self.previousHadInputHeight = environment.inputHeight > 0.0
            
            let displayDelete = !self.titleInputState.text.string.isEmpty || !self.textInputState.text.string.isEmpty || self.stickerFile != nil
            
            var deleteSectionHeight: CGFloat = 0.0
            deleteSectionHeight += sectionSpacing
            let deleteSectionSize = self.deleteSection.update(
                transition: transition,
                component: AnyComponent(ListSectionComponent(
                    theme: environment.theme,
                    header: nil,
                    footer: nil,
                    items: [
                        AnyComponentWithIdentity(id: 0, component: AnyComponent(ListActionItemComponent(
                            theme: environment.theme,
                            title: AnyComponent(VStack([
                                AnyComponentWithIdentity(id: AnyHashable(0), component: AnyComponent(MultilineTextComponent(
                                    text: .plain(NSAttributedString(
                                        string: environment.strings.Business_Intro_ResetToDefault,
                                        font: Font.regular(presentationData.listsFontSize.baseDisplaySize),
                                        textColor: environment.theme.list.itemDestructiveColor
                                    )),
                                    maximumNumberOfLines: 1
                                ))),
                            ], alignment: .center, spacing: 2.0, fillWidth: true)),
                            accessory: nil,
                            action: { [weak self] _ in
                                guard let self else {
                                    return
                                }
                                
                                self.resetTitle = ""
                                self.resetText = ""
                                self.stickerFile = nil
                                self.state?.updated(transition: .spring(duration: 0.4))
                            }
                        )))
                    ],
                    displaySeparators: false
                )),
                environment: {},
                containerSize: CGSize(width: availableSize.width - sideInset * 2.0, height: 10000.0)
            )
            let deleteSectionFrame = CGRect(origin: CGPoint(x: sideInset, y: contentHeight + deleteSectionHeight), size: deleteSectionSize)
            if let deleteSectionView = self.deleteSection.view {
                if deleteSectionView.superview == nil {
                    self.scrollView.addSubview(deleteSectionView)
                }
                transition.setFrame(view: deleteSectionView, frame: deleteSectionFrame)
                
                if displayDelete {
                    alphaTransition.setAlpha(view: deleteSectionView, alpha: 1.0)
                } else {
                    alphaTransition.setAlpha(view: deleteSectionView, alpha: 0.0)
                }
            }
            deleteSectionHeight += deleteSectionSize.height
            if displayDelete {
                contentHeight += deleteSectionHeight
            }
            
            contentHeight += bottomContentInset
            
            var inputHeight: CGFloat = environment.inputHeight
            if self.displayStickerInput, let stickerContent = self.stickerContent {
                let stickerSelectionControlDimView: UIView
                if let current = self.stickerSelectionControlDimView {
                    stickerSelectionControlDimView = current
                } else {
                    stickerSelectionControlDimView = UIView()
                    self.stickerSelectionControlDimView = stickerSelectionControlDimView
                    self.addSubview(stickerSelectionControlDimView)
                    stickerSelectionControlDimView.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(self.stickerSelectionControlDimTapGesture(_:))))
                }
                
                let stickerSelectionControl: ComponentView<Empty>
                var animateIn = false
                if let current = self.stickerSelectionControl {
                    stickerSelectionControl = current
                } else {
                    animateIn = true
                    stickerSelectionControl = ComponentView()
                    self.stickerSelectionControl = stickerSelectionControl
                }
                var selectedItems = Set<MediaId>()
                if let stickerFile = self.stickerFile {
                    selectedItems.insert(stickerFile.fileId)
                }
                stickerSelectionControl.parentState = state
                
                var stickerContent = stickerContent
                
                if let stickerSearchResult = self.stickerSearchState.result {
                    var stickerSearchResults: EmojiPagerContentComponent.EmptySearchResults?
                    if !stickerSearchResult.groups.contains(where: { !$0.items.isEmpty || $0.fillWithLoadingPlaceholders }) {
                        stickerSearchResults = EmojiPagerContentComponent.EmptySearchResults(
                            text: environment.strings.Stickers_NoStickersFound,
                            iconFile: nil
                        )
                    }
                    let defaultSearchState: EmojiPagerContentComponent.SearchState = stickerSearchResult.isPreset ? .active : .empty(hasResults: true)
                    stickerContent = stickerContent.withUpdatedItemGroups(panelItemGroups: stickerContent.panelItemGroups, contentItemGroups: stickerSearchResult.groups, itemContentUniqueId: EmojiPagerContentComponent.ContentId(id: stickerSearchResult.id, version: stickerSearchResult.version), emptySearchResults: stickerSearchResults, searchState: self.stickerSearchState.isSearching ? .searching : defaultSearchState)
                } else if self.stickerSearchState.isSearching {
                    stickerContent = stickerContent.withUpdatedItemGroups(panelItemGroups: stickerContent.panelItemGroups, contentItemGroups: stickerContent.contentItemGroups, itemContentUniqueId: stickerContent.itemContentUniqueId, emptySearchResults: stickerContent.emptySearchResults, searchState: .searching)
                }
                
                let stickerSelectionControlTransition = animateIn ? .immediate : transition
                
                stickerSelectionControlTransition.setFrame(view: stickerSelectionControlDimView, frame: CGRect(origin: CGPoint(x: 0.0, y: environment.navigationHeight), size: CGSize(width: availableSize.width, height: availableSize.height - environment.navigationHeight)))
                
                let stickerSelectionControlSize = stickerSelectionControl.update(
                    transition: stickerSelectionControlTransition,
                    component: AnyComponent(EmojiSelectionComponent(
                        theme: environment.theme,
                        strings: environment.strings,
                        sideInset: environment.safeInsets.left,
                        bottomInset: environment.safeInsets.bottom,
                        deviceMetrics: environment.deviceMetrics,
                        emojiContent: nil,
                        stickerContent: stickerContent.withSelectedItems(selectedItems),
                        backgroundIconColor: nil,
                        backgroundColor: environment.theme.list.itemBlocksBackgroundColor,
                        separatorColor: environment.theme.list.itemBlocksSeparatorColor,
                        backspace: nil
                    )),
                    environment: {},
                    containerSize: CGSize(width: availableSize.width, height: availableSize.height - environment.navigationHeight)
                )
                let stickerSelectionControlFrame = CGRect(origin: CGPoint(x: 0.0, y: availableSize.height - stickerSelectionControlSize.height), size: stickerSelectionControlSize)
                if let stickerSelectionControlView = stickerSelectionControl.view {
                    if stickerSelectionControlView.superview == nil {
                        self.addSubview(stickerSelectionControlView)
                    }
                    if animateIn {
                        stickerSelectionControlView.frame = stickerSelectionControlFrame
                        transition.animatePosition(view: stickerSelectionControlView, from: CGPoint(x: 0.0, y: stickerSelectionControlFrame.height), to: CGPoint(), additive: true)
                    } else {
                        transition.setFrame(view: stickerSelectionControlView, frame: stickerSelectionControlFrame)
                    }
                }
                inputHeight = stickerSelectionControlSize.height
            } else {
                if let stickerSelectionControl = self.stickerSelectionControl {
                    self.stickerSelectionControl = nil
                    if let stickerSelectionControlView = stickerSelectionControl.view {
                        transition.setPosition(view: stickerSelectionControlView, position: CGPoint(x: stickerSelectionControlView.center.x, y: availableSize.height + stickerSelectionControlView.bounds.height * 0.5), completion: { [weak stickerSelectionControlView] _ in
                            stickerSelectionControlView?.removeFromSuperview()
                        })
                    }
                }
                if let stickerSelectionControlDimView = self.stickerSelectionControlDimView {
                    self.stickerSelectionControlDimView = nil
                    stickerSelectionControlDimView.removeFromSuperview()
                }
            }
            
            let combinedBottomInset = max(inputHeight, environment.safeInsets.bottom)
            contentHeight += combinedBottomInset
            
            let previousBounds = self.scrollView.bounds
            
            self.ignoreScrolling = true
            let contentSize = CGSize(width: availableSize.width, height: contentHeight)
            if self.scrollView.frame != CGRect(origin: CGPoint(), size: availableSize) {
                self.scrollView.frame = CGRect(origin: CGPoint(), size: availableSize)
            }
            if self.scrollView.contentSize != contentSize {
                self.scrollView.contentSize = contentSize
            }
            let scrollInsets = UIEdgeInsets(top: environment.navigationHeight, left: 0.0, bottom: 0.0, right: 0.0)
            if self.scrollView.verticalScrollIndicatorInsets != scrollInsets {
                self.scrollView.verticalScrollIndicatorInsets = scrollInsets
            }
                        
            if !previousBounds.isEmpty, !transition.animation.isImmediate {
                let bounds = self.scrollView.bounds
                if bounds.maxY != previousBounds.maxY {
                    let offsetY = previousBounds.maxY - bounds.maxY
                    transition.animateBoundsOrigin(view: self.scrollView, from: CGPoint(x: 0.0, y: offsetY), to: CGPoint(), additive: true)
                }
            }
            
            if let recenterOnTag = self.recenterOnTag {
                self.recenterOnTag = nil
                
                if let targetView = self.introSection.findTaggedView(tag: recenterOnTag) {
                    let caretRect = targetView.convert(targetView.bounds, to: self.scrollView)
                    var scrollViewBounds = self.scrollView.bounds
                    let minButtonDistance: CGFloat = 16.0
                    if -scrollViewBounds.minY + caretRect.maxY > availableSize.height - combinedBottomInset - minButtonDistance {
                        scrollViewBounds.origin.y = -(availableSize.height - combinedBottomInset - minButtonDistance - caretRect.maxY)
                        if scrollViewBounds.origin.y < 0.0 {
                            scrollViewBounds.origin.y = 0.0
                        }
                    }
                    if self.scrollView.bounds != scrollViewBounds {
                        transition.setBounds(view: self.scrollView, bounds: scrollViewBounds)
                    }
                }
            }
            
            self.topOverscrollLayer.frame = CGRect(origin: CGPoint(x: 0.0, y: -3000.0), size: CGSize(width: availableSize.width, height: 3000.0))
            self.ignoreScrolling = false
            
            self.updateScrolling(transition: transition)
            
            return availableSize
        }
    }
    
    func makeView() -> View {
        return View()
    }
    
    func update(view: View, availableSize: CGSize, state: EmptyComponentState, environment: Environment<EnvironmentType>, transition: ComponentTransition) -> CGSize {
        return view.update(component: self, availableSize: availableSize, state: state, environment: environment, transition: transition)
    }
}

public final class BusinessIntroSetupScreen: ViewControllerComponentContainer {
    public final class InitialData: BusinessIntroSetupScreenInitialData {
        fileprivate let intro: TelegramBusinessIntro?
        
        fileprivate init(intro: TelegramBusinessIntro?) {
            self.intro = intro
        }
    }
    
    private let context: AccountContext
    
    public init(
        context: AccountContext,
        initialData: InitialData
    ) {
        self.context = context
        
        super.init(context: context, component: BusinessIntroSetupScreenComponent(
            context: context,
            initialData: initialData
        ), navigationBarAppearance: .default, theme: .default, updatedPresentationData: nil)
        
        let presentationData = context.sharedContext.currentPresentationData.with { $0 }
        self.title = ""
        self.navigationItem.backBarButtonItem = UIBarButtonItem(title: presentationData.strings.Common_Back, style: .plain, target: nil, action: nil)
        
        self.scrollToTop = { [weak self] in
            guard let self, let componentView = self.node.hostView.componentView as? BusinessIntroSetupScreenComponent.View else {
                return
            }
            componentView.scrollToTop()
        }
        
        self.attemptNavigation = { [weak self] complete in
            guard let self, let componentView = self.node.hostView.componentView as? BusinessIntroSetupScreenComponent.View else {
                return true
            }
            
            return componentView.attemptNavigation(complete: complete)
        }
    }
    
    required public init(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    deinit {
    }
    
    @objc private func cancelPressed() {
        self.dismiss()
    }
    
    override public func containerLayoutUpdated(_ layout: ContainerViewLayout, transition: ContainedViewLayoutTransition) {
        super.containerLayoutUpdated(layout, transition: transition)
    }
    
    public static func initialData(context: AccountContext) -> Signal<BusinessIntroSetupScreenInitialData, NoError> {
        return context.engine.data.get(
            TelegramEngine.EngineData.Item.Peer.BusinessIntro(id: context.account.peerId)
        )
        |> map { intro -> BusinessIntroSetupScreenInitialData in
            let value: TelegramBusinessIntro?
            switch intro {
            case let .known(intro):
                value = intro
            case .unknown:
                value = nil
            }
            return InitialData(intro: value)
        }
    }
}
