import Foundation
import UIKit
import Display
import ComponentFlow
import TelegramPresentationData
import TelegramCore
import Postbox
import AnimationCache
import MultiAnimationRenderer
import AccountContext
import AsyncDisplayKit
import ComponentDisplayAdapters
import PagerComponent
import SwiftSignalKit

public final class EmojiSearchContent: ASDisplayNode, EntitySearchContainerNode {
    private struct Params: Equatable {
        var size: CGSize
        var leftInset: CGFloat
        var rightInset: CGFloat
        var bottomInset: CGFloat
        var inputHeight: CGFloat
        var deviceMetrics: DeviceMetrics
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
    
    private let context: AccountContext
    private let forceTheme: PresentationTheme?
    private var initialFocusId: ItemCollectionId?
    private let hasPremiumForUse: Bool
    private let hasPremiumForInstallation: Bool
    private let parentInputInteraction: EmojiPagerContentComponent.InputInteraction
    private var presentationData: PresentationData
    
    private let keyboardView = ComponentView<Empty>()
    private let panelHostView: PagerExternalTopPanelContainer
    private let inputInteractionHolder: EmojiPagerContentComponent.InputInteractionHolder
    
    private var params: Params?
    
    private var itemGroups: [EmojiPagerContentComponent.ItemGroup] = []
    
    public var onCancel: (() -> Void)?
        
    private let emojiSearchDisposable = MetaDisposable()
    private let emojiSearchState = Promise<EmojiSearchState>(EmojiSearchState(result: nil, isSearching: false))
    private var emojiSearchStateValue = EmojiSearchState(result: nil, isSearching: false) {
        didSet {
            self.emojiSearchState.set(.single(self.emojiSearchStateValue))
        }
    }
    private var immediateEmojiSearchState: EmojiSearchState = EmojiSearchState(result: nil, isSearching: false)
    
    private var dataDisposable: Disposable?

    public init(
        context: AccountContext,
        forceTheme: PresentationTheme?,
        items: [FeaturedStickerPackItem],
        initialFocusId: ItemCollectionId?,
        hasPremiumForUse: Bool,
        hasPremiumForInstallation: Bool,
        parentInputInteraction: EmojiPagerContentComponent.InputInteraction
    ) {
        self.context = context
        self.forceTheme = forceTheme
        self.initialFocusId = initialFocusId
        self.hasPremiumForUse = hasPremiumForUse
        self.hasPremiumForInstallation = hasPremiumForInstallation
        self.parentInputInteraction = parentInputInteraction
        
        var presentationData = context.sharedContext.currentPresentationData.with { $0 }
        if let forceTheme {
            presentationData = presentationData.withUpdated(theme: forceTheme)
        }
        self.presentationData = presentationData
        
        self.panelHostView = PagerExternalTopPanelContainer()
        self.inputInteractionHolder = EmojiPagerContentComponent.InputInteractionHolder()
        
        super.init()
        
        for groupItem in items {
            var groupItems: [EmojiPagerContentComponent.Item] = []
            for item in groupItem.topItems {
                var tintMode: EmojiPagerContentComponent.Item.TintMode = .none
                if item.file.isCustomTemplateEmoji {
                    tintMode = .primary
                }
                
                let animationData = EntityKeyboardAnimationData(file: item.file)
                let resultItem = EmojiPagerContentComponent.Item(
                    animationData: animationData,
                    content: .animation(animationData),
                    itemFile: item.file,
                    subgroupId: nil,
                    icon: .none,
                    tintMode: tintMode
                )
                
                groupItems.append(resultItem)
            }
            
            self.itemGroups.append(EmojiPagerContentComponent.ItemGroup(
                supergroupId: AnyHashable(groupItem.info.id),
                groupId: AnyHashable(groupItem.info.id),
                title: groupItem.info.title,
                subtitle: nil,
                actionButtonTitle: self.presentationData.strings.EmojiInput_AddPack(groupItem.info.title).string,
                isFeatured: true,
                isPremiumLocked: !self.hasPremiumForInstallation,
                isEmbedded: false,
                hasClear: false,
                collapsedLineCount: 3,
                displayPremiumBadges: false,
                headerItem: nil,
                fillWithLoadingPlaceholders: false,
                items: groupItems
            ))
        }
        
        self.inputInteractionHolder.inputInteraction = EmojiPagerContentComponent.InputInteraction(
            performItemAction: { [weak self] groupId, item, sourceView, sourceRect, sourceLayer, isPreview in
                guard let self else {
                    return
                }
                self.parentInputInteraction.performItemAction(groupId, item, sourceView, sourceRect, sourceLayer, isPreview)
                if self.hasPremiumForUse {
                    self.onCancel?()
                }
            },
            deleteBackwards: {
            },
            openStickerSettings: {
            },
            openFeatured: {
            },
            openSearch: {
            },
            addGroupAction: { [weak self] groupId, isPremiumLocked, _ in
                guard let self else {
                    return
                }
                self.parentInputInteraction.addGroupAction(groupId, isPremiumLocked, false)
                
                if !isPremiumLocked {
                    if self.itemGroups.count == 1 {
                        self.onCancel?()
                    } else {
                        self.itemGroups.removeAll(where: { $0.groupId == groupId })
                        self.update(transition: Transition(animation: .curve(duration: 0.4, curve: .spring)).withUserData(EmojiPagerContentComponent.ContentAnimation(type: .groupRemoved(id: groupId))))
                    }
                }
            },
            clearGroup: { _ in
            },
            pushController: { _ in
            },
            presentController: { _ in
            },
            presentGlobalOverlayController: { _ in
            },
            navigationController: {
                return nil
            },
            requestUpdate: { _ in
            },
            updateSearchQuery: { [weak self] query in
                guard let self else {
                    return
                }
                
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
                        let context = self.context
                        
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
                    
                        let hasPremium = context.engine.data.subscribe(TelegramEngine.EngineData.Item.Peer.Peer(id: context.account.peerId))
                        |> map { peer -> Bool in
                            guard case let .user(user) = peer else {
                                return false
                            }
                            return user.isPremium
                        }
                        |> distinctUntilChanged
                        
                        let resultSignal = signal
                        |> mapToSignal { keywords -> Signal<[EmojiPagerContentComponent.ItemGroup], NoError> in
                            return combineLatest(
                                context.account.postbox.itemCollectionsView(orderedItemListCollectionIds: [], namespaces: [Namespaces.ItemCollection.CloudEmojiPacks], aroundIndex: nil, count: 10000000),
                                context.engine.stickers.availableReactions(),
                                hasPremium
                            )
                            |> take(1)
                            |> map { view, availableReactions, hasPremium -> [EmojiPagerContentComponent.ItemGroup] in
                                var result: [(String, TelegramMediaFile?, String)] = []
                                
                                var allEmoticons: [String: String] = [:]
                                for keyword in keywords {
                                    for emoticon in keyword.emoticons {
                                        allEmoticons[emoticon] = keyword.keyword
                                    }
                                }
                                
                                for entry in view.entries {
                                    guard let item = entry.item as? StickerPackItem else {
                                        continue
                                    }
                                    for attribute in item.file.attributes {
                                        switch attribute {
                                        case let .CustomEmoji(_, _, alt, _):
                                            if !item.file.isPremiumEmoji || hasPremium {
                                                if !alt.isEmpty, let keyword = allEmoticons[alt] {
                                                    result.append((alt, item.file, keyword))
                                                } else if alt == query {
                                                    result.append((alt, item.file, alt))
                                                }
                                            }
                                        default:
                                            break
                                        }
                                    }
                                }
                                
                                var items: [EmojiPagerContentComponent.Item] = []
                                
                                var existingIds = Set<MediaId>()
                                for item in result {
                                    if let itemFile = item.1 {
                                        if existingIds.contains(itemFile.fileId) {
                                            continue
                                        }
                                        existingIds.insert(itemFile.fileId)
                                        let animationData = EntityKeyboardAnimationData(file: itemFile)
                                        let item = EmojiPagerContentComponent.Item(
                                            animationData: animationData,
                                            content: .animation(animationData),
                                            itemFile: itemFile, subgroupId: nil,
                                            icon: .none,
                                            tintMode: animationData.isTemplate ? .primary : .none
                                        )
                                        items.append(item)
                                    }
                                }
                                
                                return [EmojiPagerContentComponent.ItemGroup(
                                    supergroupId: "search",
                                    groupId: "search",
                                    title: nil,
                                    subtitle: nil,
                                    actionButtonTitle: nil,
                                    isFeatured: false,
                                    isPremiumLocked: false,
                                    isEmbedded: false,
                                    hasClear: false,
                                    collapsedLineCount: nil,
                                    displayPremiumBadges: false,
                                    headerItem: nil,
                                    fillWithLoadingPlaceholders: false,
                                    items: items
                                )]
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
                    let resultSignal = self.context.engine.stickers.searchEmoji(emojiString: value)
                    |> mapToSignal { files, isFinalResult -> Signal<(items: [EmojiPagerContentComponent.ItemGroup], isFinalResult: Bool), NoError> in
                        var items: [EmojiPagerContentComponent.Item] = []
                        
                        var existingIds = Set<MediaId>()
                        for itemFile in files {
                            if existingIds.contains(itemFile.fileId) {
                                continue
                            }
                            existingIds.insert(itemFile.fileId)
                            let animationData = EntityKeyboardAnimationData(file: itemFile)
                            let item = EmojiPagerContentComponent.Item(
                                animationData: animationData,
                                content: .animation(animationData),
                                itemFile: itemFile, subgroupId: nil,
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
                            actionButtonTitle: nil,
                            isFeatured: false,
                            isPremiumLocked: false,
                            isEmbedded: false,
                            hasClear: false,
                            collapsedLineCount: nil,
                            displayPremiumBadges: false,
                            headerItem: nil,
                            fillWithLoadingPlaceholders: false,
                            items: items
                        )], isFinalResult))
                    }
                    
                    let _ = resultSignal
                        
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
                            //self.emojiSearchStateValue.isSearching = true
                            self.emojiSearchStateValue = EmojiSearchState(result: EmojiSearchResult(groups: [
                                EmojiPagerContentComponent.ItemGroup(
                                    supergroupId: "search",
                                    groupId: "search",
                                    title: nil,
                                    subtitle: nil,
                                    actionButtonTitle: nil,
                                    isFeatured: false,
                                    isPremiumLocked: false,
                                    isEmbedded: false,
                                    hasClear: false,
                                    collapsedLineCount: nil,
                                    displayPremiumBadges: false,
                                    headerItem: nil,
                                    fillWithLoadingPlaceholders: true,
                                    items: []
                                )
                            ], id: AnyHashable(value), version: version, isPreset: true), isSearching: false)
                            return
                        }
                        
                        self.emojiSearchStateValue = EmojiSearchState(result: EmojiSearchResult(groups: result.items, id: AnyHashable(value), version: version, isPreset: false), isSearching: false)
                        version += 1
                    }))
                }
            },
            updateScrollingToItemGroup: {
            },
            externalCancel: { [weak self] in
                guard let self else {
                    return
                }
                self.onCancel?()
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
        
        self.dataDisposable = (
            self.emojiSearchState.get()
            |> deliverOnMainQueue
        ).start(next: { [weak self] emojiSearchState in
            guard let self else {
                return
            }
            self.immediateEmojiSearchState = emojiSearchState
            self.update(transition: .immediate)
        })
    }
    
    deinit {
        self.emojiSearchDisposable.dispose()
        self.dataDisposable?.dispose()
    }
    
    private func update(transition: Transition) {
        if let params = self.params {
            self.update(size: params.size, leftInset: params.leftInset, rightInset: params.rightInset, bottomInset: params.bottomInset, inputHeight: params.inputHeight, deviceMetrics: params.deviceMetrics, transition: transition)
        }
    }
    
    public func updateLayout(size: CGSize, leftInset: CGFloat, rightInset: CGFloat, bottomInset: CGFloat, inputHeight: CGFloat, deviceMetrics: DeviceMetrics, transition: ContainedViewLayoutTransition) {
        self.update(size: size, leftInset: leftInset, rightInset: rightInset, bottomInset: bottomInset, inputHeight: inputHeight, deviceMetrics: deviceMetrics, transition: Transition(transition))
    }
     
    private func update(size: CGSize, leftInset: CGFloat, rightInset: CGFloat, bottomInset: CGFloat, inputHeight: CGFloat, deviceMetrics: DeviceMetrics, transition: Transition) {
        self.backgroundColor = self.presentationData.theme.list.plainBackgroundColor
        
        let params = Params(size: size, leftInset: leftInset, rightInset: rightInset, bottomInset: bottomInset, inputHeight: inputHeight, deviceMetrics: deviceMetrics)
        self.params = params
        
        var emojiContent = EmojiPagerContentComponent(
            id: "emoji",
            context: self.context,
            avatarPeer: nil,
            animationCache: self.context.animationCache,
            animationRenderer: self.context.animationRenderer,
            inputInteractionHolder: self.inputInteractionHolder,
            panelItemGroups: [],
            contentItemGroups: self.itemGroups,
            itemLayoutType: .compact,
            itemContentUniqueId: EmojiPagerContentComponent.ContentId(id: "main", version: 0),
            searchState: .empty(hasResults: false),
            warpContentsOnEdges: false,
            hideBackground: false,
            displaySearchWithPlaceholder: self.presentationData.strings.EmojiSearch_SearchEmojiPlaceholder,
            searchCategories: nil,
            searchInitiallyHidden: false,
            searchAlwaysActive: true,
            searchIsPlaceholderOnly: false,
            emptySearchResults: nil,
            enableLongPress: false,
            selectedItems: Set()
        )
        
        if let emojiSearchResult = self.immediateEmojiSearchState.result {
            var emptySearchResults: EmojiPagerContentComponent.EmptySearchResults?
            if !emojiSearchResult.groups.contains(where: { !$0.items.isEmpty || $0.fillWithLoadingPlaceholders }) {
                emptySearchResults = EmojiPagerContentComponent.EmptySearchResults(
                    text: self.presentationData.strings.EmojiSearch_SearchEmojiEmptyResult,
                    iconFile: nil
                )
            }
            emojiContent = emojiContent.withUpdatedItemGroups(panelItemGroups: emojiContent.panelItemGroups, contentItemGroups: emojiSearchResult.groups, itemContentUniqueId: EmojiPagerContentComponent.ContentId(id: emojiSearchResult.id, version: emojiSearchResult.version), emptySearchResults: emptySearchResults, searchState: self.immediateEmojiSearchState.isSearching ? .searching : .empty(hasResults: true))
        }
        
        let _ = self.keyboardView.update(
            transition: transition.withUserData(EmojiPagerContentComponent.SynchronousLoadBehavior(isDisabled: true)),
            component: AnyComponent(EntityKeyboardComponent(
                theme: self.presentationData.theme,
                strings: self.presentationData.strings,
                isContentInFocus: true,
                containerInsets: UIEdgeInsets(top: 0.0, left: leftInset, bottom: bottomInset, right: rightInset),
                topPanelInsets: UIEdgeInsets(top: 0.0, left: 4.0, bottom: 0.0, right: 4.0),
                emojiContent: emojiContent,
                stickerContent: nil,
                maskContent: nil,
                gifContent: nil,
                hasRecentGifs: false,
                availableGifSearchEmojies: [],
                defaultToEmojiTab: true,
                externalTopPanelContainer: self.panelHostView,
                externalBottomPanelContainer: nil,
                displayTopPanelBackground: .blur,
                topPanelExtensionUpdated: { _, _ in },
                topPanelScrollingOffset: { _, _ in },
                hideInputUpdated: { _, _, _ in },
                hideTopPanelUpdated: { _, _ in
                },
                switchToTextInput: {},
                switchToGifSubject: { _ in },
                reorderItems: { _, _ in },
                makeSearchContainerNode: { _ in return nil },
                contentIdUpdated: { _ in },
                deviceMetrics: deviceMetrics,
                hiddenInputHeight: 0.0,
                inputHeight: 0.0,
                displayBottomPanel: false,
                isExpanded: false,
                clipContentToTopPanel: false,
                useExternalSearchContainer: false,
                hidePanels: true
            )),
            environment: {},
            containerSize: size
        )
        if let keyboardComponentView = self.keyboardView.view as? EntityKeyboardComponent.View {
            if keyboardComponentView.superview == nil {
                self.view.addSubview(keyboardComponentView)
            }
            transition.setFrame(view: keyboardComponentView, frame: CGRect(origin: CGPoint(), size: size))
            
            if let initialFocusId = self.initialFocusId {
                self.initialFocusId = nil
                
                keyboardComponentView.scrollToItemGroup(contentId: "emoji", groupId: AnyHashable(initialFocusId), subgroupId: nil, animated: false)
            }
        }
    }
}
