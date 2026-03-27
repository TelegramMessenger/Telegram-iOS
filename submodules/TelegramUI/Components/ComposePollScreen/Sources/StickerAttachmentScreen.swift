import Foundation
import UIKit
import Display
import AccountContext
import TelegramCore
import Postbox
import SwiftSignalKit
import TelegramPresentationData
import ComponentFlow
import ViewControllerComponent
import AttachmentUI
import EntityKeyboard
import ChatEntityKeyboardInputNode
import ChatPresentationInterfaceState
import PagerComponent
import FeaturedStickersScreen
import TelegramNotices
import CounterControllerTitleView
import GlassBackgroundComponent
import GlassBarButtonComponent
import BundleIconComponent
import EdgeEffect

final class StickerAttachmentScreenComponent: Component {
    typealias EnvironmentType = ViewControllerComponentContainer.Environment
    
    let context: AccountContext
    let mode: StickerAttachmentScreen.Mode
    let completion: (AnyMediaReference) -> Void
    
    init(
        context: AccountContext,
        mode: StickerAttachmentScreen.Mode,
        completion: @escaping (AnyMediaReference) -> Void
    ) {
        self.context = context
        self.mode = mode
        self.completion = completion
    }
    
    static func ==(lhs: StickerAttachmentScreenComponent, rhs: StickerAttachmentScreenComponent) -> Bool {
        return true
    }
    
    final class KeyboardClippingView: UIView {
        var hitEdgeInsets: UIEdgeInsets = .zero
        
        override func point(inside point: CGPoint, with event: UIEvent?) -> Bool {
            let bounds = self.bounds.inset(by: self.hitEdgeInsets)
            return bounds.contains(point)
        }
    }
    
    final class View: UIView, UIScrollViewDelegate {
        private var topEdgeEffectView: EdgeEffectView
        private var bottomEdgeEffectView: EdgeEffectView
        
        fileprivate let keyboardView: ComponentView<Empty>
        private let keyboardClippingView: KeyboardClippingView
        private let panelBackgroundView: GlassBackgroundView
        private let panelClippingView: UIView
        private let panelHostView: PagerExternalTopPanelContainer
        private let cancelButton: ComponentView<Empty>
        
        private var component: StickerAttachmentScreenComponent?
        private(set) weak var state: EmptyComponentState?
        private var environment: EnvironmentType?
        
        private var interaction: ChatEntityKeyboardInputNode.Interaction?
        private var inputNodeInteraction: ChatMediaInputNodeInteraction?
        
        private var searchVisible = false
        private var forceUpdate = false
        
        private var ignoreNextZeroScrollingOffset = false
        private var topPanelScrollingOffset: CGFloat = 0.0
        private var keyboardContentId: AnyHashable?
        
        private let contentDisposable = MetaDisposable()
        
        private var emojiContent: EmojiPagerContentComponent?
        private var stickerContent: EmojiPagerContentComponent?
        
        private var scheduledEmojiContentAnimationHint: EmojiPagerContentComponent.ContentAnimation?
        
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
        
        private let emojiSearchDisposable = MetaDisposable()
        private let emojiSearchState = Promise<EmojiSearchState>(EmojiSearchState(result: nil, isSearching: false))
        private var emojiSearchStateValue = EmojiSearchState(result: nil, isSearching: false) {
            didSet {
                self.emojiSearchState.set(.single(self.emojiSearchStateValue))
            }
        }
        
        private let stickerSearchDisposable = MetaDisposable()
        private let stickerSearchState = Promise<EmojiSearchState>(EmojiSearchState(result: nil, isSearching: false))
        private var stickerSearchStateValue = EmojiSearchState(result: nil, isSearching: false) {
            didSet {
                self.stickerSearchState.set(.single(self.stickerSearchStateValue))
            }
        }
        
        override init(frame: CGRect) {
            self.keyboardView = ComponentView<Empty>()
            self.keyboardClippingView = KeyboardClippingView()
            self.topEdgeEffectView = EdgeEffectView()
            self.bottomEdgeEffectView = EdgeEffectView()
            self.panelBackgroundView = GlassBackgroundView()
            self.panelClippingView = UIView()
            self.panelHostView = PagerExternalTopPanelContainer()
            self.cancelButton = ComponentView<Empty>()
            
            super.init(frame: frame)
            
            self.addSubview(self.keyboardClippingView)
            self.addSubview(self.topEdgeEffectView)
            self.addSubview(self.bottomEdgeEffectView)
            self.addSubview(self.panelBackgroundView)
            self.panelBackgroundView.contentView.addSubview(self.panelClippingView)
            self.panelClippingView.addSubview(self.panelHostView)
            
            self.interaction = ChatEntityKeyboardInputNode.Interaction(
                sendSticker: { [weak self] file, _, _, _, _, _, _, _, _ in
                    if let self {
                        self.complete(file.abstract)
                    }
                    return false
                },
                sendEmoji: { _, _, _ in
                },
                sendGif: { _, _, _, _, _ in
                    return false
                },
                sendBotContextResultAsGif: { _, _, _, _, _, _ in
                    return false
                },
                editGif: { _, _ in
                },
                updateChoosingSticker: { _ in },
                switchToTextInput: {},
                dismissTextInput: {},
                insertText: { _ in
                },
                backwardsDeleteText: {},
                openStickerEditor: {},
                presentController: { [weak self] c, a in
                    if let self, let controller = self.environment?.controller() {
                        controller.present(c, in: .window(.root), with: a)
                    }
                },
                presentGlobalOverlayController: { [weak self] c, a in
                    if let self, let controller = self.environment?.controller() {
                        controller.presentInGlobalOverlay(c, with: a)
                    }
                },
                getNavigationController: {
                    return nil
                },
                requestLayout: { transition in
                    let _ = transition
                }
            )
            
            self.inputNodeInteraction = ChatMediaInputNodeInteraction(
                navigateToCollectionId: { _ in
                },
                navigateBackToStickers: {
                },
                setGifMode: { _ in
                },
                openSettings: {
                },
                openTrending: { _ in
                },
                dismissTrendingPacks: { _ in
                },
                toggleSearch: { _, _, _ in
                },
                openPeerSpecificSettings: {
                },
                dismissPeerSpecificSettings: {
                },
                clearRecentlyUsedStickers: {
                }
            )
        }
        
        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }
        
        deinit {
            self.contentDisposable.dispose()
        }
        
        func complete(_ fileReference: AnyMediaReference) {
            guard let component = self.component else {
                return
            }
            component.completion(fileReference)
            (self.environment?.controller() as? StickerAttachmentScreen)?.dismiss(animated: true)
        }
        
        func updateContent(component: StickerAttachmentScreenComponent) {
            self.emojiContent?.inputInteractionHolder.inputInteraction = EmojiPagerContentComponent.InputInteraction(
                performItemAction: { [weak self] groupId, item, _, _, _, _ in
                    guard let self, let component = self.component else {
                        return
                    }
                    let context = component.context
                    if groupId == AnyHashable("featuredTop"), let file = item.itemFile {
                        let _ = (
                        combineLatest(
                            ChatEntityKeyboardInputNode.hasPremium(context: context, chatPeerId: context.account.peerId, premiumIfSavedMessages: true),
                            ChatEntityKeyboardInputNode.hasPremium(context: context, chatPeerId: context.account.peerId, premiumIfSavedMessages: false)
                        )
                        |> take(1)
                        |> deliverOnMainQueue).start(next: { [weak self] hasPremium, hasGlobalPremium in
                            guard let self else {
                                return
                            }
                            
                            let viewKey = PostboxViewKey.orderedItemList(id: Namespaces.OrderedItemList.CloudFeaturedEmojiPacks)
                            let _ = (combineLatest(
                                context.account.postbox.itemCollectionsView(orderedItemListCollectionIds: [], namespaces: [Namespaces.ItemCollection.CloudEmojiPacks], aroundIndex: nil, count: 10000000),
                                context.account.postbox.combinedView(keys: [viewKey])
                            )
                            |> take(1)
                            |> deliverOnMainQueue).start(next: { [weak self] emojiPacksView, views in
                                guard let view = views.views[viewKey] as? OrderedItemListView else {
                                    return
                                }
                                guard let self else {
                                    return
                                }
                                                                
                                var installedCollectionIds = Set<ItemCollectionId>()
                                for (id, _, _) in emojiPacksView.collectionInfos {
                                    installedCollectionIds.insert(id)
                                }
                                
                                let stickerPacks = view.items.map({ $0.contents.get(FeaturedStickerPackItem.self)! }).filter({
                                    !installedCollectionIds.contains($0.info.id)
                                })
                                
                                for featuredStickerPack in stickerPacks {
                                    if featuredStickerPack.topItems.contains(where: { $0.file.fileId == file.fileId }) {
                                        if let pagerView = self.keyboardView.view as? EntityKeyboardComponent.View, let emojiInputInteraction = self.emojiContent?.inputInteractionHolder.inputInteraction {
                                            pagerView.openCustomSearch(content: EmojiSearchContent(
                                                context: context,
                                                forceTheme: nil,
                                                items: stickerPacks,
                                                initialFocusId: featuredStickerPack.info.id,
                                                hasPremiumForUse: hasPremium,
                                                hasPremiumForInstallation: hasGlobalPremium,
                                                parentInputInteraction: emojiInputInteraction
                                            ))
                                        }
                                        break
                                    }
                                }
                            })
                        })
                    } else if let file = item.itemFile?._parse() {
                        self.complete(.standalone(media: file))
                    }
                },
                deleteBackwards: nil,
                openStickerSettings: nil,
                openFeatured: nil,
                openSearch: {
                },
                addGroupAction: { [weak self] groupId, isPremiumLocked, _ in
                    guard let self, let component = self.component, let collectionId = groupId.base as? ItemCollectionId else {
                        return
                    }
                    let context = component.context
                    let viewKey = PostboxViewKey.orderedItemList(id: Namespaces.OrderedItemList.CloudFeaturedEmojiPacks)
                    let _ = (context.account.postbox.combinedView(keys: [viewKey])
                    |> take(1)
                    |> deliverOnMainQueue).start(next: { views in
                        guard let view = views.views[viewKey] as? OrderedItemListView else {
                            return
                        }
                        for featuredStickerPack in view.items.lazy.map({ $0.contents.get(FeaturedStickerPackItem.self)! }) {
                            if featuredStickerPack.info.id == collectionId {
                                let _ = (context.engine.stickers.loadedStickerPack(reference: .id(id: featuredStickerPack.info.id.id, accessHash: featuredStickerPack.info.accessHash), forceActualized: false)
                                |> mapToSignal { result -> Signal<Void, NoError> in
                                    switch result {
                                    case let .result(info, items, installed):
                                        if installed {
                                            return .complete()
                                        } else {
                                            return context.engine.stickers.addStickerPackInteractively(info: info._parse(), items: items)
                                        }
                                    case .fetching:
                                        break
                                    case .none:
                                        break
                                    }
                                    return .complete()
                                }
                                |> deliverOnMainQueue).start(completed: {
                                })
                                
                                break
                            }
                        }
                    })
                },
                clearGroup: { [weak self] groupId in
                    guard let self, let component = self.component else {
                        return
                    }
                    let context = component.context
                    let presentationData = component.context.sharedContext.currentPresentationData.with { $0 }
                    if groupId == AnyHashable("recent") {
                        let actionSheet = ActionSheetController(theme: ActionSheetControllerTheme(presentationTheme: presentationData.theme, fontSize: presentationData.listsFontSize))
                        var items: [ActionSheetItem] = []
                        items.append(ActionSheetButtonItem(title: presentationData.strings.Emoji_ClearRecent, color: .destructive, action: { [weak actionSheet] in
                            actionSheet?.dismissAnimated()
                            let _ = context.engine.stickers.clearRecentlyUsedEmoji().start()
                        }))
                        actionSheet.setItemGroups([ActionSheetItemGroup(items: items), ActionSheetItemGroup(items: [
                            ActionSheetButtonItem(title: presentationData.strings.Common_Cancel, color: .accent, font: .bold, action: { [weak actionSheet] in
                                actionSheet?.dismissAnimated()
                            })
                        ])])
                        context.sharedContext.mainWindow?.presentInGlobalOverlay(actionSheet)
                    } else if groupId == AnyHashable("popular") {
                        let actionSheet = ActionSheetController(theme: ActionSheetControllerTheme(presentationTheme: presentationData.theme, fontSize: presentationData.listsFontSize))
                        var items: [ActionSheetItem] = []
                        items.append(ActionSheetTextItem(title: presentationData.strings.Chat_ClearReactionsAlertText, parseMarkdown: true))
                        items.append(ActionSheetButtonItem(title: presentationData.strings.Chat_ClearReactionsAlertAction, color: .destructive, action: { [weak self, weak actionSheet] in
                            actionSheet?.dismissAnimated()
                            guard let self else {
                                return
                            }
                            
                            self.scheduledEmojiContentAnimationHint = EmojiPagerContentComponent.ContentAnimation(type: .groupRemoved(id: "popular"))
                            let _ = context.engine.stickers.clearRecentlyUsedReactions().start()
                        }))
                        actionSheet.setItemGroups([ActionSheetItemGroup(items: items), ActionSheetItemGroup(items: [
                            ActionSheetButtonItem(title: presentationData.strings.Common_Cancel, color: .accent, font: .bold, action: { [weak actionSheet] in
                                actionSheet?.dismissAnimated()
                            })
                        ])])
                        context.sharedContext.mainWindow?.presentInGlobalOverlay(actionSheet)
                    }
                },
                editAction: { _ in },
                pushController: { c in
                },
                presentController: { c in
                },
                presentGlobalOverlayController: { c in
                },
                navigationController: { [weak self] in
                    return self?.environment?.controller()?.navigationController as? NavigationController
                },
                requestUpdate: { [weak self] transition in
                    guard let self else {
                        return
                    }
                    if !transition.animation.isImmediate {
                        self.state?.updated(transition: transition)
                    }
                },
                updateSearchQuery: { [weak self] query in
                    guard let self, let component = self.component else {
                        return
                    }
                    let context = component.context
                    
                    switch query {
                    case .none:
                        self.emojiSearchDisposable.set(nil)
                        self.emojiSearchState.set(.single(EmojiSearchState(result: nil, isSearching: false)))
                    case let .text(rawQuery, languageCode):
                        let query = rawQuery.trimmingCharacters(in: .whitespacesAndNewlines)
                        
                        if query.isEmpty {
                            self.emojiSearchDisposable.set(nil)
                            self.emojiSearchState.set(.single(EmojiSearchState(result: nil, isSearching: false)))
                        } else {
                            var signal = context.engine.stickers.searchEmojiKeywords(inputLanguageCode: languageCode, query: query, completeMatch: false)
                            if !languageCode.lowercased().hasPrefix("en") {
                                signal = signal
                                |> mapToSignal { keywords in
                                    return .single(keywords)
                                    |> then(
                                        context.engine.stickers.searchEmojiKeywords(inputLanguageCode: "en-US", query: query, completeMatch: query.count < 3)
                                        |> map { englishKeywords in
                                            return keywords + englishKeywords
                                        }
                                    )
                                }
                            }
                        
                            let hasPremium: Signal<Bool, NoError> = .single(true)
                            let resultSignal = combineLatest(
                                signal,
                                hasPremium
                            )
                            |> mapToSignal { keywords, hasPremium -> Signal<[EmojiPagerContentComponent.ItemGroup], NoError> in
                                var allEmoticons: [String: String] = [:]
                                for keyword in keywords {
                                    for emoticon in keyword.emoticons {
                                        allEmoticons[emoticon] = keyword.keyword
                                    }
                                }
                                let remoteSignal: Signal<(items: [TelegramMediaFile], isFinalResult: Bool), NoError>
                                if hasPremium {
                                    remoteSignal = context.engine.stickers.searchEmoji(query: query, emoticon: Array(allEmoticons.keys), inputLanguageCode: languageCode)
                                } else {
                                    remoteSignal = .single(([], true))
                                }
                                return remoteSignal
                                |> mapToSignal { foundEmoji -> Signal<[EmojiPagerContentComponent.ItemGroup], NoError> in
                                    if foundEmoji.items.isEmpty && !foundEmoji.isFinalResult {
                                        return .complete()
                                    }
                                    var items: [EmojiPagerContentComponent.Item] = []
                                    
                                    let appendUnicodeEmoji = {
                                        for (_, list) in EmojiPagerContentComponent.staticEmojiMapping {
                                            for emojiString in list {
                                                if allEmoticons[emojiString] != nil {
                                                    let item = EmojiPagerContentComponent.Item(
                                                        animationData: nil,
                                                        content: .staticEmoji(emojiString),
                                                        itemFile: nil,
                                                        subgroupId: nil,
                                                        icon: .none,
                                                        tintMode: .none
                                                    )
                                                    items.append(item)
                                                }
                                            }
                                        }
                                    }
                                    
                                    if !hasPremium {
                                        appendUnicodeEmoji()
                                    }
                                    
                                    var existingIds = Set<MediaId>()
                                    for itemFile in foundEmoji.items {
                                        if existingIds.contains(itemFile.fileId) {
                                            continue
                                        }
                                        existingIds.insert(itemFile.fileId)
                                        if itemFile.isPremiumEmoji && !hasPremium {
                                            continue
                                        }
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
                                    
                                    if hasPremium {
                                        appendUnicodeEmoji()
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
                            }
                            
                            var version = 0
                            self.emojiSearchStateValue.isSearching = true
                            self.emojiSearchDisposable.set((resultSignal
                            |> delay(0.15, queue: .mainQueue())
                            |> deliverOnMainQueue).start(next: { [weak self] result in
                                guard let self else {
                                    return
                                }
                                
                                self.emojiSearchStateValue = EmojiSearchState(result: EmojiSearchResult(groups: result, id: AnyHashable(query), version: version, isPreset: false), isSearching: false)
                                version += 1
                            }))
                        }
                    case let .category(value):
                        let resultSignal = context.engine.stickers.searchEmoji(category: value)
                        |> mapToSignal { files, isFinalResult -> Signal<(items: [EmojiPagerContentComponent.ItemGroup], isFinalResult: Bool), NoError> in
                            var items: [EmojiPagerContentComponent.Item] = []
                            
                            var existingIds = Set<MediaId>()
                            for itemFile in files {
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
                            )], isFinalResult))
                        }
                            
                        var version = 0
                        self.emojiSearchDisposable.set((resultSignal
                        |> deliverOnMainQueue).start(next: { [weak self] result in
                            guard let self else {
                                return
                            }
                            
                            guard let group = result.items.first else {
                                return
                            }
                            if group.items.isEmpty && !result.isFinalResult {
                                self.emojiSearchStateValue = EmojiSearchState(result: EmojiSearchResult(groups: [
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
                                return
                            }
                            self.emojiSearchStateValue = EmojiSearchState(result: EmojiSearchResult(groups: result.items, id: AnyHashable(value.id), version: version, isPreset: true), isSearching: false)
                            version += 1
                        }))
                    }
                },
                updateScrollingToItemGroup: { // [weak self] in
//                    if let self, let componentView = self.hostView.componentView as? StickerSelectionComponent.View {
//                        componentView.scrolledToItemGroup()
//                    }
//                    self?.update(isExpanded: true, transition: .animated(duration: 0.4, curve: .spring))
                },
                onScroll: {},
                chatPeerId: nil,
                peekBehavior: nil,
                customLayout: nil,
                externalBackground: nil,
                externalExpansionView: nil,
                customContentView: nil,
                useOpaqueTheme: true,
                hideBackground: true,
                stateContext: nil,
                addImage: nil
            )
            
            var stickerPeekBehavior: EmojiContentPeekBehaviorImpl?
            stickerPeekBehavior = EmojiContentPeekBehaviorImpl(
                context: component.context,
                forceTheme: nil,
                interaction: nil,
                chatPeerId: nil,
                present: { [weak self] c, a in
                    self?.environment?.controller()?.presentInGlobalOverlay(c, with: a)
                }
            )
            
            self.stickerContent?.inputInteractionHolder.inputInteraction = EmojiPagerContentComponent.InputInteraction(
                performItemAction: { [weak self] groupId, item, _, _, _, _ in
                    guard let self, let component = self.component, let file = item.itemFile?._parse() else {
                        return
                    }
                    let context = component.context
                    let presentationData = context.sharedContext.currentPresentationData.with { $0 }
                    if groupId == AnyHashable("featuredTop") {
                        let viewKey = PostboxViewKey.orderedItemList(id: Namespaces.OrderedItemList.CloudFeaturedStickerPacks)
                        let _ = (context.account.postbox.combinedView(keys: [viewKey])
                        |> take(1)
                        |> deliverOnMainQueue).start(next: { [weak self] views in
                            guard let self, let controller = self.environment?.controller(), let view = views.views[viewKey] as? OrderedItemListView else {
                                return
                            }
                            for featuredStickerPack in view.items.lazy.map({ $0.contents.get(FeaturedStickerPackItem.self)! }) {
                                if featuredStickerPack.topItems.contains(where: { $0.file.fileId == file.fileId }) {
                                    controller.push(FeaturedStickersScreen(
                                        context: context,
                                        highlightedPackId: featuredStickerPack.info.id,
                                        forceTheme: nil,
                                        stickerActionTitle: presentationData.strings.StickerPack_AddSticker,
                                        sendSticker: { [weak self] fileReference, _, _ in
                                            if let self {
                                                self.complete(fileReference.abstract)
                                            }
                                            return true
                                        }
                                    ))
                                    
                                    break
                                }
                            }
                        })
                    } else {
                        let reference: FileMediaReference
                        if groupId == AnyHashable("saved") {
                            reference = .savedSticker(media: file)
                        } else if groupId == AnyHashable("recent") {
                            reference = .recentSticker(media: file)
                        } else {
                            reference = .standalone(media: file)
                        }
                        self.complete(reference.abstract)
                    }
                },
                deleteBackwards: nil,
                openStickerSettings: nil,
                openFeatured: nil,
                openSearch: { [weak self] in
                    guard let self else {
                        return
                    }
                    if let pagerView = self.keyboardView.view as? EntityKeyboardComponent.View {
                        pagerView.openSearch()
                    }
                },
                addGroupAction: { [weak self] groupId, isPremiumLocked, _ in
                    guard let strongSelf = self, let component = strongSelf.component, let collectionId = groupId.base as? ItemCollectionId else {
                        return
                    }
                    let context = component.context
                    let viewKey = PostboxViewKey.orderedItemList(id: Namespaces.OrderedItemList.CloudFeaturedStickerPacks)
                    let _ = (context.account.postbox.combinedView(keys: [viewKey])
                    |> take(1)
                    |> deliverOnMainQueue).start(next: { views in
                        guard let view = views.views[viewKey] as? OrderedItemListView else {
                            return
                        }
                        for featuredStickerPack in view.items.lazy.map({ $0.contents.get(FeaturedStickerPackItem.self)! }) {
                            if featuredStickerPack.info.id == collectionId {
                                let _ = (context.engine.stickers.loadedStickerPack(reference: .id(id: featuredStickerPack.info.id.id, accessHash: featuredStickerPack.info.accessHash), forceActualized: false)
                                |> mapToSignal { result -> Signal<Void, NoError> in
                                    switch result {
                                    case let .result(info, items, installed):
                                        if installed {
                                            return .complete()
                                        } else {
                                            return context.engine.stickers.addStickerPackInteractively(info: info._parse(), items: items)
                                        }
                                    case .fetching:
                                        break
                                    case .none:
                                        break
                                    }
                                    return .complete()
                                }
                                |> deliverOnMainQueue).start(completed: {
                                })
                                
                                break
                            }
                        }
                    })
                },
                clearGroup: { [weak self] groupId in
                    guard let strongSelf = self, let component = strongSelf.component else {
                        return
                    }
                    let context = component.context
                    if groupId == AnyHashable("recent") {
                        let presentationData = context.sharedContext.currentPresentationData.with { $0 }
                        let actionSheet = ActionSheetController(theme: ActionSheetControllerTheme(presentationTheme: presentationData.theme, fontSize: presentationData.listsFontSize))
                        var items: [ActionSheetItem] = []
                        items.append(ActionSheetButtonItem(title: presentationData.strings.Stickers_ClearRecent, color: .destructive, action: { [weak actionSheet] in
                            actionSheet?.dismissAnimated()
                            let _ = context.engine.stickers.clearRecentlyUsedStickers().start()
                        }))
                        actionSheet.setItemGroups([ActionSheetItemGroup(items: items), ActionSheetItemGroup(items: [
                            ActionSheetButtonItem(title: presentationData.strings.Common_Cancel, color: .accent, font: .bold, action: { [weak actionSheet] in
                                actionSheet?.dismissAnimated()
                            })
                        ])])
                        context.sharedContext.mainWindow?.presentInGlobalOverlay(actionSheet)
                    } else if groupId == AnyHashable("featuredTop") {
                        let viewKey = PostboxViewKey.orderedItemList(id: Namespaces.OrderedItemList.CloudFeaturedStickerPacks)
                        let _ = (context.account.postbox.combinedView(keys: [viewKey])
                        |> take(1)
                        |> deliverOnMainQueue).start(next: { views in
                            guard let view = views.views[viewKey] as? OrderedItemListView else {
                                return
                            }
                            var stickerPackIds: [Int64] = []
                            for featuredStickerPack in view.items.lazy.map({ $0.contents.get(FeaturedStickerPackItem.self)! }) {
                                stickerPackIds.append(featuredStickerPack.info.id.id)
                            }
                            let _ = ApplicationSpecificNotice.setDismissedTrendingStickerPacks(accountManager: context.sharedContext.accountManager, values: stickerPackIds).start()
                        })
                    } else if groupId == AnyHashable("peerSpecific") {
                    }
                },
                editAction: { _ in },
                pushController: { c in
                },
                presentController: { c in
                },
                presentGlobalOverlayController: { c in
                },
                navigationController: { [weak self] in
                    return self?.environment?.controller()?.navigationController as? NavigationController
                },
                requestUpdate: { [weak self] transition in
                    guard let self else {
                        return
                    }
                    if !transition.animation.isImmediate {
                        self.state?.updated(transition: transition)
                    }
                },
                updateSearchQuery: { [weak self] query in
                    guard let self = self, let component = self.component else {
                        return
                    }
                    let context = component.context
                    
                    switch query {
                    case .none:
                        self.stickerSearchDisposable.set(nil)
                        self.stickerSearchStateValue = EmojiSearchState(result: nil, isSearching: false)
                    case .text:
                        self.stickerSearchDisposable.set(nil)
                        self.stickerSearchStateValue = EmojiSearchState(result: nil, isSearching: false)
                    case let .category(value):
                        let resultSignal = context.engine.stickers.searchStickers(category: value, scope: [.installed, .remote])
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
                                    icon: .none,
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
                            guard let strongSelf = self else {
                                return
                            }
                            guard let group = result.items.first else {
                                return
                            }
                            if group.items.isEmpty && !result.isFinalResult {
                                strongSelf.stickerSearchStateValue = EmojiSearchState(result: EmojiSearchResult(groups: [
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
                                return
                            }
                            strongSelf.stickerSearchStateValue = EmojiSearchState(result: EmojiSearchResult(groups: result.items, id: AnyHashable(value.id), version: version, isPreset: true), isSearching: false)
                            version += 1
                        }))
                    }
                },
                updateScrollingToItemGroup: {
//                    if let self, let componentView = self.hostView.componentView as? StickerSelectionComponent.View {
//                        componentView.scrolledToItemGroup()
//                    }
//                    self?.update(isExpanded: true, transition: .animated(duration: 0.4, curve: .spring))
                },
                onScroll: {},
                chatPeerId: nil,
                peekBehavior: stickerPeekBehavior,
                customLayout: nil,
                externalBackground: nil,
                externalExpansionView: nil,
                customContentView: nil,
                useOpaqueTheme: true,
                hideBackground: true,
                stateContext: nil,
                addImage: nil
            )
        }
        
        func update(component: StickerAttachmentScreenComponent, availableSize: CGSize, state: EmptyComponentState, environment: Environment<EnvironmentType>, transition: ComponentTransition) -> CGSize {
            let environment = environment[EnvironmentType.self].value
            self.environment = environment
            
            let theme = environment.theme.withModalBlocksBackground()
            
            self.backgroundColor = theme.list.plainBackgroundColor
            
            if self.component == nil {
                let data = combineLatest(
                    queue: Queue.mainQueue(),
                    self.stickerSearchState.get(),
                    self.emojiSearchState.get()
                )
                self.contentDisposable.set(data.start(next: { [weak self] stickerSearchState, emojiSearchState in
                    guard let self else {
                        return
                    }
                    
                    let presentationData = component.context.sharedContext.currentPresentationData.with { $0 }
                    
                    switch component.mode {
                    case var .emoji(emojiContent):
                        if let emojiSearchResult = emojiSearchState.result {
                            var emptySearchResults: EmojiPagerContentComponent.EmptySearchResults?
                            if !emojiSearchResult.groups.contains(where: { !$0.items.isEmpty || $0.fillWithLoadingPlaceholders }) {
                                emptySearchResults = EmojiPagerContentComponent.EmptySearchResults(
                                    text: presentationData.strings.EmojiSearch_SearchEmojiEmptyResult,
                                    iconFile: nil
                                )
                            }
                            
                            let defaultSearchState: EmojiPagerContentComponent.SearchState = emojiSearchResult.isPreset ? .active : .empty(hasResults: true)
                            emojiContent = emojiContent.withUpdatedItemGroups(panelItemGroups: emojiContent.panelItemGroups, contentItemGroups: emojiSearchResult.groups, itemContentUniqueId: EmojiPagerContentComponent.ContentId(id: emojiSearchResult.id, version: emojiSearchResult.version), emptySearchResults: emptySearchResults, searchState: emojiSearchState.isSearching ? .searching : defaultSearchState)
                        } else if emojiSearchState.isSearching {
                            emojiContent = emojiContent.withUpdatedItemGroups(panelItemGroups: emojiContent.panelItemGroups, contentItemGroups: emojiContent.contentItemGroups, itemContentUniqueId: emojiContent.itemContentUniqueId, emptySearchResults: emojiContent.emptySearchResults, searchState: .searching)
                        }
                        self.emojiContent = emojiContent
                    case var .stickers(stickerContent):
                        if let stickerSearchResult = stickerSearchState.result {
                            var stickerSearchResults: EmojiPagerContentComponent.EmptySearchResults?
                            if !stickerSearchResult.groups.contains(where: { !$0.items.isEmpty || $0.fillWithLoadingPlaceholders }) {
                                stickerSearchResults = EmojiPagerContentComponent.EmptySearchResults(
                                    text: presentationData.strings.EmojiSearch_SearchStickersEmptyResult,
                                    iconFile: nil
                                )
                            }
                            
                            let defaultSearchState: EmojiPagerContentComponent.SearchState = stickerSearchResult.isPreset ? .active : .empty(hasResults: true)
                            stickerContent = stickerContent.withUpdatedItemGroups(panelItemGroups: stickerContent.panelItemGroups, contentItemGroups: stickerSearchResult.groups, itemContentUniqueId: EmojiPagerContentComponent.ContentId(id: stickerSearchResult.id, version: stickerSearchResult.version), emptySearchResults: stickerSearchResults, searchState: stickerSearchState.isSearching ? .searching : defaultSearchState)
                        } else if stickerSearchState.isSearching {
                            stickerContent = stickerContent.withUpdatedItemGroups(panelItemGroups: stickerContent.panelItemGroups, contentItemGroups: stickerContent.contentItemGroups, itemContentUniqueId: stickerContent.itemContentUniqueId, emptySearchResults: stickerContent.emptySearchResults, searchState: .searching)
                        }
                        self.stickerContent = stickerContent
                    }
                    self.updateContent(component: component)
                }))
            }
            
            self.component = component
            self.state = state
            
            let topPanelHeight: CGFloat = 42.0
            let topInset: CGFloat = 64.0 //component.topInset
                        
            let context = component.context
            let stickerPeekBehavior = EmojiContentPeekBehaviorImpl(
                context: context,
                forceTheme: nil,
                interaction: nil,
                chatPeerId: nil,
                present: { c, a in
                }
            )
            
            let keyboardSize = self.keyboardView.update(
                transition: transition.withUserData(EmojiPagerContentComponent.SynchronousLoadBehavior(isDisabled: true)),
                component: AnyComponent(EntityKeyboardComponent(
                    theme: theme,
                    strings: environment.strings,
                    isContentInFocus: true,
                    containerInsets: UIEdgeInsets(top: topPanelHeight + topInset - 11.0, left: 0.0, bottom: 0.0, right: 0.0),
                    topPanelInsets: UIEdgeInsets(top: 0.0, left: 12.0, bottom: 0.0, right: 12.0),
                    emojiContent: self.emojiContent,
                    stickerContent: self.stickerContent,
                    maskContent: nil,
                    gifContent: nil,
                    hasRecentGifs: false,
                    availableGifSearchEmojies: [],
                    defaultToEmojiTab: self.emojiContent != nil,
                    externalTopPanelContainer: self.panelHostView,
                    externalBottomPanelContainer: nil,
                    externalTintMaskContainer: nil,
                    displayTopPanelBackground: .blur,
                    topPanelExtensionUpdated: { _, _ in
                    },
                    topPanelScrollingOffset: { [weak self] offset, transition in
                        if let self {
                            if self.ignoreNextZeroScrollingOffset && offset == 0.0 {
                            } else {
                                self.ignoreNextZeroScrollingOffset = false
                                self.topPanelScrollingOffset = offset
                            }
                        }
                    },
                    hideInputUpdated: { [weak self] _, searchVisible, transition in
                        guard let self else {
                            return
                        }
                        self.forceUpdate = true
                        self.searchVisible = searchVisible
                        self.state?.updated(transition: transition)
                        
                        let transition: ComponentTransition = .easeInOut(duration: 0.2)
                        if let controller = self.environment?.controller() as? StickerAttachmentScreen {
                            if let titleView = controller.navigationItem.titleView {
                                transition.setAlpha(view: titleView, alpha: searchVisible ? 0.0 : 1.0)
                            }
                            if searchVisible {
                                controller.requestAttachmentMenuExpansion()
                            }
                        }
                    },
                    hideTopPanelUpdated: { _, _ in
                    },
                    switchToTextInput: {},
                    switchToGifSubject: { _ in },
                    reorderItems: { _, _ in },
                    makeSearchContainerNode: { [weak self] content in
                        guard let self, let interaction = self.interaction, let inputNodeInteraction = self.inputNodeInteraction else {
                            return nil
                        }

                        let mappedMode: ChatMediaInputSearchMode
                        switch content {
                        case .stickers:
                            mappedMode = .sticker
                        case .gifs:
                            mappedMode = .gif
                        }
                        
                        let presentationData = context.sharedContext.currentPresentationData.with { $0 }
                        let searchContainerNode = PaneSearchContainerNode(
                            context: context,
                            theme: presentationData.theme,
                            strings: presentationData.strings,
                            interaction: interaction,
                            inputNodeInteraction: inputNodeInteraction,
                            mode: mappedMode,
                            batchVideoRenderingContext: nil,
                            stickerActionTitle: presentationData.strings.StickerPack_AddSticker,
                            trendingGifsPromise: Promise(nil),
                            cancel: {
                            },
                            peekBehavior: stickerPeekBehavior
                        )
                        return searchContainerNode
                    },
                    contentIdUpdated: { [weak self] id in
                        guard let self else {
                            return
                        }
                        self.keyboardContentId = id
                    },
                    deviceMetrics: environment.deviceMetrics,
                    hiddenInputHeight: 0.0,
                    inputHeight: 0.0,
                    displayBottomPanel: false,
                    isExpanded: true,
                    clipContentToTopPanel: false,
                    useExternalSearchContainer: false
                )),
                environment: {},
                forceUpdate: self.forceUpdate,
                containerSize: availableSize
            )
            self.forceUpdate = false
            if let keyboardComponentView = self.keyboardView.view {
                if keyboardComponentView.superview == nil {
                    self.keyboardClippingView.addSubview(keyboardComponentView)
                }
                
                self.keyboardClippingView.clipsToBounds = false
                
                transition.setFrame(view: self.keyboardClippingView, frame: CGRect(origin: CGPoint(x: 0.0, y: topPanelHeight + topInset), size: CGSize(width: availableSize.width, height: availableSize.height - topPanelHeight - topInset)))
                self.keyboardClippingView.hitEdgeInsets = UIEdgeInsets(top: -topPanelHeight - topInset, left: 0.0, bottom: 0.0, right: 0.0)
                
                let panelBackgroundFrame = CGRect(origin: CGPoint(x: 12.0, y: topPanelHeight + topInset - 29.0), size: CGSize(width: availableSize.width - 24.0, height: 44.0))
                
                self.panelClippingView.clipsToBounds = true
                self.panelClippingView.layer.cornerRadius = panelBackgroundFrame.height * 0.5
                transition.setFrame(view: self.panelClippingView, frame: CGRect(origin: .zero, size: panelBackgroundFrame.size))
                
                self.panelBackgroundView.update(size: panelBackgroundFrame.size, cornerRadius: panelBackgroundFrame.size.height * 0.5, isDark: theme.overallDarkAppearance, tintColor: .init(kind: .panel), isInteractive: true, isVisible: !self.searchVisible, transition: transition)
                transition.setFrame(view: self.panelBackgroundView, frame: panelBackgroundFrame)
                
                transition.setFrame(view: keyboardComponentView, frame: CGRect(origin: CGPoint(x: 0.0, y: -topPanelHeight - topInset), size: keyboardSize))
                transition.setFrame(view: self.panelHostView, frame: CGRect(origin: CGPoint(x: -12.0, y: 8.0 - UIScreenPixel), size: CGSize(width: keyboardSize.width, height: 0.0)))
            }
            
            let barButtonSize = CGSize(width: 44.0, height: 44.0)
            let cancelButtonSize = self.cancelButton.update(
                transition: transition,
                component: AnyComponent(GlassBarButtonComponent(
                    size: barButtonSize,
                    backgroundColor: nil,
                    isDark: theme.overallDarkAppearance,
                    state: .glass,
                    component: AnyComponentWithIdentity(id: "close", component: AnyComponent(
                        BundleIconComponent(
                            name: "Navigation/Close",
                            tintColor: theme.chat.inputPanel.panelControlColor
                        )
                    )),
                    action: { [weak self] _ in
                        guard let self else {
                            return
                        }
                        (self.environment?.controller() as? StickerAttachmentScreen)?.dismiss(animated: true)
                    }
                )),
                environment: {},
                containerSize: barButtonSize
            )
            let cancelButtonFrame = CGRect(origin: CGPoint(x: 16.0, y: 16.0), size: cancelButtonSize)
            if let cancelButtonView = self.cancelButton.view {
                if cancelButtonView.superview == nil {
                    self.addSubview(cancelButtonView)
                }
                transition.setBounds(view: cancelButtonView, bounds: CGRect(origin: .zero, size: cancelButtonFrame.size))
                transition.setPosition(view: cancelButtonView, position: cancelButtonFrame.center)
                transition.setAlpha(view: cancelButtonView, alpha: self.searchVisible ? 0.0 : 1.0)
                transition.setScale(view: cancelButtonView, scale: self.searchVisible ? 0.001 : 1.0)
            }
            
            let edgeEffectHeight: CGFloat = 88.0
            let topEdgeEffectFrame = CGRect(origin: .zero, size: CGSize(width: availableSize.width, height: edgeEffectHeight))
            transition.setFrame(view: self.topEdgeEffectView, frame: topEdgeEffectFrame)
            self.topEdgeEffectView.update(content: theme.list.blocksBackgroundColor, blur: true, alpha: 1.0, rect: topEdgeEffectFrame, edge: .top, edgeSize: topEdgeEffectFrame.height, transition: transition)
            
            let bottomEdgeEffectFrame = CGRect(origin: CGPoint(x: 0.0, y: availableSize.height - edgeEffectHeight - environment.additionalInsets.bottom), size: CGSize(width: availableSize.width, height: edgeEffectHeight))
            transition.setFrame(view: self.bottomEdgeEffectView, frame: bottomEdgeEffectFrame)
            self.bottomEdgeEffectView.update(content: theme.list.blocksBackgroundColor, blur: true, alpha: 1.0, rect: bottomEdgeEffectFrame, edge: .bottom, edgeSize: bottomEdgeEffectFrame.height, transition: transition)
            
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

final class StickerAttachmentScreen: ViewControllerComponentContainer, AttachmentContainable {
    enum Mode {
        case stickers(EmojiPagerContentComponent)
        case emoji(EmojiPagerContentComponent)
    }
    
    enum Source: Equatable {
        enum PollMode: Equatable {
            case description
            case quizAnswer
            case option
        }
        
        case poll(PollMode)
    }
    
    private let context: AccountContext
    private let mode: Mode
    private let completion: (AnyMediaReference) -> Void
    
    init(context: AccountContext, mode: Mode, source: Source, completion: @escaping (AnyMediaReference) -> Void) {
        self.context = context
        self.mode = mode
        self.completion = completion
        
        super.init(context: context, component: StickerAttachmentScreenComponent(
            context: context,
            mode: mode,
            completion: completion
        ), navigationBarAppearance: .transparent, theme: .default)
        
        self._hasGlassStyle = true
        
        let presentationData = context.sharedContext.currentPresentationData.with { $0 }
        switch source {
        case let .poll(pollMode):
            let title: String
            let subtitle: String
            switch mode {
            case .stickers:
                title = presentationData.strings.StickerPicker_Title
                switch pollMode {
                case .description:
                    subtitle = ""
                case .quizAnswer:
                    subtitle = ""
                case .option:
                    subtitle = presentationData.strings.StickerPicker_PollSubtitle_PollOption
                }
            case .emoji:
                title = "Emoji"
                switch pollMode {
                case .description:
                    subtitle = ""
                case .quizAnswer:
                    subtitle = ""
                case .option:
                    subtitle = "Add emoji to this option"
                }
            }
            let titleView = CounterControllerTitleView(theme: presentationData.theme, verticalOffset: -2.0)
            titleView.title = CounterControllerTitle(title: title, counter: subtitle)
            self.navigationItem.titleView = titleView
        }
        self.navigationItem.leftBarButtonItem = UIBarButtonItem(customView: UIView())
    }
    
    required init(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    public var isMinimized: Bool = false
    
    public var requestAttachmentMenuExpansion: () -> Void = {
    }
    public var updateNavigationStack: (@escaping ([AttachmentContainable]) -> ([AttachmentContainable], AttachmentMediaPickerContext?)) -> Void = { _ in
    }
    public var parentController: () -> ViewController? = {
        return nil
    }
    public var updateTabBarAlpha: (CGFloat, ContainedViewLayoutTransition) -> Void = { _, _ in
    }
    public var updateTabBarVisibility: (Bool, ContainedViewLayoutTransition) -> Void = { _, _ in
    }
    public var cancelPanGesture: () -> Void = {
    }
    public var isContainerPanning: () -> Bool = {
        return false
    }
    public var isContainerExpanded: () -> Bool = {
        return false
    }
    public var mediaPickerContext: AttachmentMediaPickerContext?
    
    public var isPanGestureEnabled: (() -> Bool)? {
        return {
            return true
//            guard let self, let componentView = self.node.hostView.componentView as? ComposePollScreenComponent.View else {
//                return true
//            }
//            return componentView.isPanGestureEnabled()
        }
    }
    
    public func isContainerPanningUpdated(_ panning: Bool) {
    }
    
    public func resetForReuse() {
    }
    
    public func prepareForReuse() {
    }
    
    public func requestDismiss(completion: @escaping () -> Void) {
        completion()
    }
    
    public func shouldDismissImmediately() -> Bool {
        return true
    }
}
