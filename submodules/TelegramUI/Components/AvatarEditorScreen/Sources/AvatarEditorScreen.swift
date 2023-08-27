import Foundation
import UIKit
import Display
import AsyncDisplayKit
import ComponentFlow
import SwiftSignalKit
import ViewControllerComponent
import ComponentDisplayAdapters
import TelegramPresentationData
import AccountContext
import TelegramCore
import MultilineTextComponent
import EmojiStatusComponent
import Postbox
import TelegramStringFormatting
import TelegramNotices
import EntityKeyboard
import PagerComponent
import Markdown
import GradientBackground
import LegacyComponents
import DrawingUI
import SolidRoundedButtonComponent
import AnimationCache
import EmojiTextAttachmentView
import MediaEditor

enum AvatarBackground: Equatable {
    case gradient([UInt32])
    
    var colors: [UInt32] {
        switch self {
        case let .gradient(colors):
            return colors
        }
    }
    
    var isLight: Bool {
        switch self {
            case let .gradient(colors):
                if colors.count == 1 {
                    return UIColor(rgb: colors.first!).lightness > 0.99
                } else if colors.count == 2 {
                    return UIColor(rgb: colors.first!).lightness > 0.99 || UIColor(rgb: colors.last!).lightness > 0.99
                } else {
                    var lightCount = 0
                    for color in colors {
                        if UIColor(rgb: color).lightness > 0.99 {
                            lightCount += 1
                        }
                    }
                    return lightCount >= 2
                }
        }
    }
    
    func generateImage(size: CGSize) -> UIImage {
        switch self {
            case let .gradient(colors):
                if colors.count == 1 {
                    return generateSingleColorImage(size: size, color: UIColor(rgb: colors.first!))!
                } else if colors.count == 2 {
                    return generateGradientImage(size: size, colors: colors.map { UIColor(rgb: $0) }, locations: [0.0, 1.0])!
                } else {
                    return GradientBackgroundNode.generatePreview(size: size, colors: colors.map { UIColor(rgb: $0) })
                }
        }
    }
}

private let defaultBackgrounds: [AvatarBackground] = [
    .gradient([0xFF5A7FFF, 0xFF2CA0F2, 0xFF4DFF89, 0xFF6BFCEB]),
    .gradient([0xFFFF011D, 0xFFFF530D, 0xFFFE64DC, 0xFFFFDC61]),
    .gradient([0xFFFE64DC, 0xFFFF6847, 0xFFFFDD02, 0xFFFFAE10]),
    .gradient([0xFF84EC00, 0xFF00B7C2, 0xFF00C217, 0xFFFFE600]),
    .gradient([0xFF86B0FF, 0xFF35FFCF, 0xFF69FFFF, 0xFF76DEFF]),
    .gradient([0xFFFAE100, 0xFFFF54EE, 0xFFFC2B78, 0xFFFF52D9]),
    .gradient([0xFF73A4FF, 0xFF5F55FF, 0xFFFF49F8, 0xFFEC76FF]),
]

public struct AvatarKeyboardInputData: Equatable {
    var emoji: EmojiPagerContentComponent
    var stickers: EmojiPagerContentComponent?
    
    init(
        emoji: EmojiPagerContentComponent,
        stickers: EmojiPagerContentComponent?
    ) {
        self.emoji = emoji
        self.stickers = stickers
    }
}

final class AvatarEditorScreenComponent: Component {
    typealias EnvironmentType = ViewControllerComponentContainer.Environment
    
    let context: AccountContext
    let ready: Promise<Bool>
    let peerType: AvatarEditorScreen.PeerType
    let markup: TelegramMediaImage.EmojiMarkup?
    
    init(
        context: AccountContext,
        ready: Promise<Bool>,
        peerType: AvatarEditorScreen.PeerType,
        markup: TelegramMediaImage.EmojiMarkup?
    ) {
        self.context = context
        self.ready = ready
        self.peerType = peerType
        self.markup = markup
    }
    
    static func ==(lhs: AvatarEditorScreenComponent, rhs: AvatarEditorScreenComponent) -> Bool {
        if lhs.context !== rhs.context {
            return false
        }
        if lhs.peerType != rhs.peerType {
            return false
        }
        if lhs.markup != rhs.markup {
            return false
        }
        return true
    }

    final class State: ComponentState {
        let context: AccountContext
        let ready: Promise<Bool>
        
        var selectedBackground: AvatarBackground
        var selectedFile: TelegramMediaFile?
        
        var keyboardContentId: AnyHashable = "emoji"
        var expanded: Bool = false
        var editingColor: Bool = false
        var previousColor: AvatarBackground
        
        var previousCustomColor: AvatarBackground?
        var customColor: AvatarBackground?
        
        var isSearchActive: Bool = false
        
        private var fileDisposable: Disposable?
        
        init(context: AccountContext, ready: Promise<Bool>, markup: TelegramMediaImage.EmojiMarkup?) {
            self.context = context
            self.ready = ready
         
            self.selectedBackground = defaultBackgrounds.first!
            self.previousColor = self.selectedBackground
            
            super.init()
            
            if let markup {
                switch markup.content {
                case let .emoji(fileId):
                    self.fileDisposable = (context.engine.stickers.resolveInlineStickers(fileIds: [fileId])
                    |> deliverOnMainQueue).start(next: { [weak self] files in
                        if let strongSelf = self, let file = files.values.first {
                            strongSelf.selectedFile = file
                            strongSelf.updated(transition: .immediate)
                        }
                    })
                case let .sticker(packReference, fileId):
                    self.fileDisposable = (context.engine.stickers.loadedStickerPack(reference: packReference, forceActualized: false)
                    |> map { pack -> TelegramMediaFile? in
                        if case let .result(_, items, _) = pack, let item = items.first(where: { $0.file.fileId.id == fileId }) {
                            return item.file
                        }
                        return nil
                    }
                    |> deliverOnMainQueue).start(next: { [weak self] file in
                        if let strongSelf = self, let file {
                            strongSelf.selectedFile = file
                            strongSelf.updated(transition: .immediate)
                        }
                    })
                }

                self.selectedBackground = .gradient(markup.backgroundColors.map { UInt32(bitPattern: $0) })
                self.previousColor = self.selectedBackground
            } else {
                self.selectedBackground = defaultBackgrounds.first!
            }
            
            self.previousColor = self.selectedBackground
        }
        
        deinit {
            self.fileDisposable?.dispose()
        }
    }
    
    func makeState() -> State {
        return State(
            context: self.context,
            ready: self.ready,
            markup: self.markup
        )
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
    
    class View: UIView {
        private let navigationCancelButton = ComponentView<Empty>()
        private let navigationDoneButton = ComponentView<Empty>()
                
        private let previewContainerView: UIView
        private let previewView = ComponentView<Empty>()
        
        private let backgroundContainerView: UIView
        private let backgroundTitleView = ComponentView<Empty>()
        private let backgroundView = ComponentView<Empty>()
        private let colorPickerView = ComponentView<Empty>()
        
        private let keyboardContainerView: UIView
        private let keyboardTitleView = ComponentView<Empty>()
        private let keyboardSwitchView = ComponentView<Empty>()
        private let keyboardView = ComponentView<Empty>()
        private let panelBackgroundView: BlurredBackgroundView
        private let panelHostView: PagerExternalTopPanelContainer
        private let panelSeparatorView: UIView
    
        private let buttonView = ComponentView<Empty>()
        
        private var component: AvatarEditorScreenComponent?
        private weak var state: State?
        
        private var navigationMetrics: (navigationHeight: CGFloat, statusBarHeight: CGFloat)?
        private var controller: (() -> AvatarEditorScreen?)?
        
        private var dataDisposable: Disposable?
        private var data: AvatarKeyboardInputData?

        private let emojiSearchDisposable = MetaDisposable()
        private let emojiSearchState = Promise<EmojiSearchState>(EmojiSearchState(result: nil, isSearching: false))
        private var emojiSearchStateValue = EmojiSearchState(result: nil, isSearching: false) {
            didSet {
                self.emojiSearchState.set(.single(self.emojiSearchStateValue))
            }
        }
        
        private var scheduledEmojiContentAnimationHint: EmojiPagerContentComponent.ContentAnimation?
        
        override init(frame: CGRect) {
            self.previewContainerView = UIView()
            self.previewContainerView.clipsToBounds = true
            if #available(iOS 13.0, *) {
                self.previewContainerView.layer.cornerCurve = .circular
            }
            
            self.backgroundContainerView = UIView()
            self.backgroundContainerView.clipsToBounds = true
            self.backgroundContainerView.layer.cornerRadius = 10.0
            
            self.keyboardContainerView = UIView()
            self.keyboardContainerView.clipsToBounds = true
            self.keyboardContainerView.layer.cornerRadius = 10.0
            
            self.panelBackgroundView = BlurredBackgroundView(color: .white)
            self.panelHostView = PagerExternalTopPanelContainer()
            self.panelSeparatorView = UIView()
                        
            super.init(frame: frame)
    
            self.addSubview(self.previewContainerView)
            self.addSubview(self.backgroundContainerView)
            self.addSubview(self.keyboardContainerView)
            self.keyboardContainerView.addSubview(self.panelBackgroundView)
            self.keyboardContainerView.addSubview(self.panelHostView)
            self.keyboardContainerView.addSubview(self.panelSeparatorView)
        }
        
        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }
        
        deinit {
            self.dataDisposable?.dispose()
            self.emojiSearchDisposable.dispose()
        }
        
        private func updateData(_ data: AvatarKeyboardInputData) {
            let wasEmpty = self.data == nil
            self.data = data
            
            if wasEmpty && self.state?.selectedFile == nil {
                self.state?.selectedFile = data.emoji.panelItemGroups.first?.items.first?.itemFile
            }
                        
            let updateSearchQuery: (EmojiPagerContentComponent.SearchQuery?) -> Void = { [weak self] query in
                guard let self, let context = self.state?.context else {
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
                                            
                        let resultSignal = signal
                        |> mapToSignal { keywords -> Signal<[EmojiPagerContentComponent.ItemGroup], NoError> in
                            return combineLatest(
                                context.account.postbox.itemCollectionsView(orderedItemListCollectionIds: [], namespaces: [Namespaces.ItemCollection.CloudEmojiPacks], aroundIndex: nil, count: 10000000) |> take(1),
                                combineLatest(keywords.map { context.engine.stickers.searchStickers(query: $0.emoticons)
                                |> map { items -> [FoundStickerItem] in
                                    return items.items
                                }
                                })
                            )
                            |> map { view, stickers -> [EmojiPagerContentComponent.ItemGroup] in
                                let hasPremium = true
                                
                                var emoji: [(String, TelegramMediaFile?, String)] = []
                                
                                var existingEmoticons = Set<String>()
                                var allEmoticons: [String: String] = [:]
                                for keyword in keywords {
                                    for emoticon in keyword.emoticons {
                                        allEmoticons[emoticon] = keyword.keyword
                                        existingEmoticons.insert(emoticon)
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
                                                    emoji.append((alt, item.file, keyword))
                                                } else if alt == query {
                                                    emoji.append((alt, item.file, alt))
                                                }
                                            }
                                        default:
                                            break
                                        }
                                    }
                                }
                                
                                var emojiItems: [EmojiPagerContentComponent.Item] = []
                                
                                var existingIds = Set<MediaId>()
                                for item in emoji {
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
                                        emojiItems.append(item)
                                    }
                                }
                                
                                var stickerItems: [EmojiPagerContentComponent.Item] = []
                                for stickerResult in stickers {
                                    for sticker in stickerResult {
                                        if existingIds.contains(sticker.file.fileId) {
                                            continue
                                        }
                                        
                                        existingIds.insert(sticker.file.fileId)
                                        let animationData = EntityKeyboardAnimationData(file: sticker.file)
                                        let item = EmojiPagerContentComponent.Item(
                                            animationData: animationData,
                                            content: .animation(animationData),
                                            itemFile: sticker.file,
                                            subgroupId: nil,
                                            icon: .none,
                                            tintMode: .none
                                        )
                                        stickerItems.append(item)
                                    }
                                }
                                
                                var result: [EmojiPagerContentComponent.ItemGroup] = []
                                if !emojiItems.isEmpty {
                                    result.append(
                                        EmojiPagerContentComponent.ItemGroup(
                                            supergroupId: "search",
                                            groupId: "emoji",
                                            title: "Emoji",
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
                                            items: emojiItems
                                        )
                                    )
                                }
                                if !stickerItems.isEmpty {
                                    result.append(
                                        EmojiPagerContentComponent.ItemGroup(
                                            supergroupId: "search",
                                            groupId: "stickers",
                                            title: "Stickers",
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
                                            items: stickerItems
                                        )
                                    )
                                }
                                return result
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
                    let resultSignal = context.engine.stickers.searchEmoji(emojiString: value)
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
                        
                        self.emojiSearchStateValue = EmojiSearchState(result: EmojiSearchResult(groups: result.items, id: AnyHashable(value), version: version, isPreset: true), isSearching: false)
                        version += 1
                    }))
                }
            }
            
            data.emoji.inputInteractionHolder.inputInteraction = EmojiPagerContentComponent.InputInteraction(
                performItemAction: { [weak self] _, item, _, _, _, _ in
                    guard let self, let _ = item.itemFile else {
                        return
                    }
                    self.state?.selectedFile = item.itemFile
                    self.state?.updated(transition: .easeInOut(duration: 0.2))
                },
                deleteBackwards: nil,
                openStickerSettings: nil,
                openFeatured: nil,
                openSearch: {
                },
                addGroupAction: { [weak self] groupId, isPremiumLocked, _ in
                    guard let strongSelf = self, let controller = strongSelf.controller?(), let collectionId = groupId.base as? ItemCollectionId else {
                        return
                    }
                    let context = controller.context
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
                                            return context.engine.stickers.addStickerPackInteractively(info: info, items: items)
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
                    guard let strongSelf = self, let controller = strongSelf.controller?() else {
                        return
                    }
                    let context = controller.context
                    let presentationData = controller.context.sharedContext.currentPresentationData.with { $0 }
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
                        items.append(ActionSheetButtonItem(title: presentationData.strings.Chat_ClearReactionsAlertAction, color: .destructive, action: { [weak actionSheet] in
                            actionSheet?.dismissAnimated()
                            guard let strongSelf = self else {
                                return
                            }
                            
                            strongSelf.scheduledEmojiContentAnimationHint = EmojiPagerContentComponent.ContentAnimation(type: .groupRemoved(id: "popular"))
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
                pushController: { c in
                },
                presentController: { c in
                },
                presentGlobalOverlayController: { c in
                },
                navigationController: { [weak self] in
                    return self?.controller?()?.navigationController as? NavigationController
                },
                requestUpdate: { [weak self] transition in
                    guard let strongSelf = self else {
                        return
                    }
                    if !transition.animation.isImmediate {
                        strongSelf.state?.updated(transition: transition)
                    }
                },
                updateSearchQuery: { query in
                    updateSearchQuery(query)
                },
                updateScrollingToItemGroup: {
                },
                onScroll: { [weak self] in
                    if let self {
                        self.endEditing(true)
                        if let state = self.state, state.expanded {
                            state.expanded = false
                            state.updated(transition: Transition(animation: .curve(duration: 0.45, curve: .spring)))
                        }
                    }
                },
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
            
            data.stickers?.inputInteractionHolder.inputInteraction = EmojiPagerContentComponent.InputInteraction(
                performItemAction: { [weak self] _, item, _, _, _, _ in
                    guard let self, let _ = item.itemFile else {
                        return
                    }
                    self.state?.selectedFile = item.itemFile
                    self.state?.updated(transition: .easeInOut(duration: 0.2))
                },
                deleteBackwards: nil,
                openStickerSettings: nil,
                openFeatured: nil,
                openSearch: {
                },
                addGroupAction: { [weak self] groupId, isPremiumLocked, _ in
                    guard let strongSelf = self, let controller = strongSelf.controller?(), let collectionId = groupId.base as? ItemCollectionId else {
                        return
                    }
                    let context = controller.context
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
                                            return context.engine.stickers.addStickerPackInteractively(info: info, items: items)
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
                    guard let strongSelf = self, let controller = strongSelf.controller?() else {
                        return
                    }
                    let context = controller.context
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
                pushController: { c in
                },
                presentController: { c in
                },
                presentGlobalOverlayController: { c in
                },
                navigationController: { [weak self] in
                    return self?.controller?()?.navigationController as? NavigationController
                },
                requestUpdate: { [weak self] transition in
                    guard let strongSelf = self else {
                        return
                    }
                    if !transition.animation.isImmediate {
                        strongSelf.state?.updated(transition: transition)
                    }
                },
                updateSearchQuery: { query in
                    updateSearchQuery(query)
                },
                updateScrollingToItemGroup: {
                },
                onScroll: { [weak self] in
                    if let self {
                        self.endEditing(true)
                        if let state = self.state, state.expanded {
                            state.expanded = false
                            state.updated(transition: Transition(animation: .curve(duration: 0.45, curve: .spring)))
                        }
                    }
                },
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
            
            self.state?.updated(transition: .immediate)
            self.state?.ready.set(.single(true))
        }
        
        private var isExpanded = false
        
        func update(component: AvatarEditorScreenComponent, availableSize: CGSize, state: State, environment: Environment<ViewControllerComponentContainer.Environment>, transition: Transition) -> CGSize {
            self.component = component
            self.state = state
                        
            let environment = environment[ViewControllerComponentContainer.Environment.self].value
            let strings = environment.strings
            
            let controller = environment.controller
            self.controller = {
                return controller() as? AvatarEditorScreen
            }
            self.navigationMetrics = (environment.navigationHeight, environment.statusBarHeight)
            
            let sideInset: CGFloat = 16.0 + environment.safeInsets.left
            
            if state.expanded && environment.inputHeight > 0.0 {
                state.expanded = false
            }
            
            let effectiveIsExpanded = state.expanded || state.editingColor
            
            if self.isExpanded != effectiveIsExpanded {
                self.isExpanded = effectiveIsExpanded
                
                if let snapshotView = self.navigationCancelButton.view?.snapshotContentTree() {
                    snapshotView.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.2, removeOnCompletion: false, completion: { [weak snapshotView] _ in
                        snapshotView?.removeFromSuperview()
                    })
                    self.addSubview(snapshotView)
                }
                
                if let navigationDoneButton = self.navigationDoneButton.view, !navigationDoneButton.alpha.isZero, let snapshotView = self.navigationDoneButton.view?.snapshotContentTree() {
                    snapshotView.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.2, removeOnCompletion: false, completion: { [weak snapshotView] _ in
                        snapshotView?.removeFromSuperview()
                    })
                    self.addSubview(snapshotView)
                }
            }
            
            let backgroundIsBright = UIColor(rgb: state.selectedBackground.colors.first ?? 0).lightness > 0.8
            
            let navigationCancelButtonSize = self.navigationCancelButton.update(
                transition: transition,
                component: AnyComponent(Button(
                    content: AnyComponent(Text(text: environment.strings.Common_Cancel, font: Font.regular(17.0), color: state.expanded && !backgroundIsBright ? .white : environment.theme.rootController.navigationBar.accentTextColor)),
                    action: { [weak self] in
                        guard let self else {
                            return
                        }
                        self.controller?()?.dismiss()
                    }
                ).minSize(CGSize(width: 16.0, height: environment.navigationHeight - environment.statusBarHeight))),
                environment: {},
                containerSize: CGSize(width: 150.0, height: environment.navigationHeight - environment.statusBarHeight)
            )
            if let navigationCancelButtonView = self.navigationCancelButton.view {
                if navigationCancelButtonView.superview == nil {
                    self.addSubview(navigationCancelButtonView)
                }
                transition.setFrame(view: navigationCancelButtonView, frame: CGRect(origin: CGPoint(x: 16.0 + environment.safeInsets.left, y: environment.statusBarHeight), size: navigationCancelButtonSize))
                transition.setAlpha(view: navigationCancelButtonView, alpha: !state.editingColor ? 1.0 : 0.0)
            }
            
            let navigationDoneButtonSize = self.navigationDoneButton.update(
                transition: transition,
                component: AnyComponent(Button(
                    content: AnyComponent(Text(text: component.peerType == .suggest ? strings.AvatarEditor_Suggest : strings.AvatarEditor_Set, font: Font.semibold(17.0), color: state.expanded && !backgroundIsBright ? .white : environment.theme.rootController.navigationBar.accentTextColor)),
                    action: { [weak self] in
                        guard let self else {
                            return
                        }
                        self.complete()
                    }
                ).minSize(CGSize(width: 16.0, height: environment.navigationHeight - environment.statusBarHeight))),
                environment: {},
                containerSize: CGSize(width: 150.0, height: environment.navigationHeight - environment.statusBarHeight)
            )
            if let navigationDoneButtonView = self.navigationDoneButton.view {
                if navigationDoneButtonView.superview == nil {
                    self.addSubview(navigationDoneButtonView)
                }
                
                transition.setFrame(view: navigationDoneButtonView, frame: CGRect(origin: CGPoint(x: availableSize.width - 16.0 - environment.safeInsets.right - navigationDoneButtonSize.width, y: environment.statusBarHeight), size: navigationDoneButtonSize))
                transition.setAlpha(view: navigationDoneButtonView, alpha: (state.expanded || environment.inputHeight > 0.0) && !state.editingColor ? 1.0 : 0.0)
            }
                        
            self.backgroundColor = environment.theme.list.blocksBackgroundColor
            self.backgroundContainerView.backgroundColor = environment.theme.list.itemBlocksBackgroundColor
            self.keyboardContainerView.backgroundColor = environment.theme.list.itemBlocksBackgroundColor
            self.panelSeparatorView.backgroundColor = environment.theme.list.itemPlainSeparatorColor
                        
            if self.dataDisposable == nil, let controller = controller() as? AvatarEditorScreen {
                let context = component.context
                let signal = combineLatest(queue: .mainQueue(),
                    controller.inputData |> delay(0.01, queue: .mainQueue()),
                    self.emojiSearchState.get()
                )
                self.dataDisposable = (signal
                |> deliverOnMainQueue
                ).start(next: { [weak self, weak state] data, emojiSearchState in
                    if let self {
                        var data = data

                        if let searchResult = emojiSearchState.result {
                            let presentationData = context.sharedContext.currentPresentationData.with { $0 }
                            var emptySearchResults: EmojiPagerContentComponent.EmptySearchResults?
                            if !searchResult.groups.contains(where: { !$0.items.isEmpty || $0.fillWithLoadingPlaceholders }) {
                                emptySearchResults = EmojiPagerContentComponent.EmptySearchResults(
                                    text: presentationData.strings.EmojiSearch_SearchEmojiEmptyResult,
                                    iconFile: nil
                                )
                            }
                            
                            if state?.keyboardContentId == AnyHashable("emoji") {
                                data.emoji = data.emoji.withUpdatedItemGroups(panelItemGroups: data.emoji.panelItemGroups, contentItemGroups: searchResult.groups, itemContentUniqueId: EmojiPagerContentComponent.ContentId(id: searchResult.id, version: searchResult.version), emptySearchResults: emptySearchResults, searchState: .active)
                            } else {
                                data.stickers = data.stickers?.withUpdatedItemGroups(panelItemGroups: data.stickers?.panelItemGroups ?? searchResult.groups, contentItemGroups: searchResult.groups, itemContentUniqueId: EmojiPagerContentComponent.ContentId(id: searchResult.id, version: searchResult.version), emptySearchResults: emptySearchResults, searchState: .active)
                            }
                        }
                        
                        self.updateData(data)
                        state?.updated(transition: .immediate)
                    }
                })
            }
                      
            var contentHeight: CGFloat = 0.0
            
            let collapsedAvatarSize = CGSize(width: 100.0, height: 100.0)
            let avatarPreviewSize = self.previewView.update(
                transition: transition,
                component: AnyComponent(
                    AvatarPreviewComponent(
                        context: component.context,
                        background: state.selectedBackground,
                        file: state.selectedFile,
                        tapped: { [weak state, weak self] in
                            if let state, !state.editingColor {
                                if let emojiView = self?.keyboardView.findTaggedView(tag: EmojiPagerContentComponent.Tag(id: AnyHashable("emoji"))) as? EmojiPagerContentComponent.View {
                                    emojiView.ensureSearchUnfocused()
                                } else if let emojiView = self?.keyboardView.findTaggedView(tag: EmojiPagerContentComponent.Tag(id: AnyHashable("stickers"))) as? EmojiPagerContentComponent.View {
                                    emojiView.ensureSearchUnfocused()
                                }
                                state.expanded = !state.expanded
                                state.updated(transition: Transition(animation: .curve(duration: 0.35, curve: .spring)))
                            }
                        }
                    )
                ),
                environment: {},
                containerSize: CGSize(width: availableSize.width, height: availableSize.width)
            )
            if let previewView = self.previewView.view {
                if previewView.superview == nil {
                    self.previewContainerView.addSubview(previewView)
                }
                
                let previewScale = effectiveIsExpanded ? 1.0 : collapsedAvatarSize.width / avatarPreviewSize.width
                let cornerRadius = effectiveIsExpanded ? 0.0 : availableSize.width / (component.peerType == .forum ? 4.0 : 2.0)
                let position = effectiveIsExpanded ? avatarPreviewSize.height / 2.0 : environment.navigationHeight + 10.0
                                
                transition.setBounds(view: previewView, bounds: CGRect(origin: .zero, size: avatarPreviewSize))
                transition.setPosition(view: previewView, position: CGPoint(x: avatarPreviewSize.width / 2.0, y: avatarPreviewSize.height / 2.0))
                
                transition.setBounds(view: self.previewContainerView, bounds: CGRect(origin: .zero, size: avatarPreviewSize))
                transition.setPosition(view: self.previewContainerView, position: CGPoint(x: availableSize.width / 2.0, y: position))
                transition.setTransform(view: self.previewContainerView, transform: CATransform3DMakeScale(previewScale, previewScale, 1.0))
                transition.setCornerRadius(layer: self.previewContainerView.layer, cornerRadius: cornerRadius)
                
                contentHeight += effectiveIsExpanded ? avatarPreviewSize.height : environment.navigationHeight + collapsedAvatarSize.height - 41.0
            }
            contentHeight += 17.0
            
            let body = MarkdownAttributeSet(font: Font.regular(13.0), textColor: environment.theme.list.freeTextColor)
            let bold = MarkdownAttributeSet(font: Font.semibold(13.0), textColor: environment.theme.list.freeTextColor)
            let link = MarkdownAttributeSet(font: Font.regular(13.0), textColor: environment.theme.list.itemAccentColor)
            
            let backgroundTitleSize = self.backgroundTitleView.update(
                transition: transition,
                component: AnyComponent(MultilineTextComponent(
                    text: .markdown(
                        text: strings.AvatarEditor_Background.uppercased(), attributes: MarkdownAttributes(
                            body: body,
                            bold: bold,
                            link: body,
                            linkAttribute: { _ in nil }
                        )
                    ),
                    maximumNumberOfLines: 0
                )),
                environment: {},
                containerSize: CGSize(width: availableSize.width - sideInset * 2.0 - 15.0 * 2.0, height: .greatestFiniteMagnitude)
            )
            let backgroundTitleFrame = CGRect(origin: CGPoint(x: sideInset + 15.0, y: contentHeight), size: backgroundTitleSize)
            if let backgroundTitleView = self.backgroundTitleView.view {
                if backgroundTitleView.superview == nil {
                    self.addSubview(backgroundTitleView)
                }
                transition.setFrame(view: backgroundTitleView, frame: backgroundTitleFrame)
            }
            contentHeight += backgroundTitleSize.height
            contentHeight += 8.0
            
            let backgroundSize = self.backgroundView.update(
                transition: transition,
                component: AnyComponent(BackgroundColorComponent(
                    theme: environment.theme,
                    values: defaultBackgrounds,
                    selectedValue: state.selectedBackground,
                    customValue: state.customColor,
                    updateValue: { [weak state] value in
                        if let state {
                            state.selectedBackground = value
                            state.updated(transition: .easeInOut(duration: 0.2))
                        }
                    },
                    openColorPicker: { [weak state] in
                        if let state {
                            state.editingColor = true
                            state.previousColor = state.selectedBackground
                            state.previousCustomColor = state.customColor
                            state.updated(transition: .easeInOut(duration: 0.3))
                        }
                    }
                )),
                environment: {},
                containerSize: CGSize(width: availableSize.width - sideInset * 2.0, height: .greatestFiniteMagnitude)
            )
            let backgroundFrame = CGRect(origin: .zero, size: backgroundSize)
            if let backgroundView = self.backgroundView.view {
                if backgroundView.superview == nil {
                    self.backgroundContainerView.addSubview(backgroundView)
                }
                transition.setFrame(view: backgroundView, frame: backgroundFrame)
                transition.setAlpha(view: backgroundView, alpha: state.editingColor ? 0.0 : 1.0)
            }
            
            var colorPickerBottomInset: CGFloat = 0.0
            if environment.deviceMetrics.type != .tablet {
                colorPickerBottomInset = environment.safeInsets.bottom
            }
            
            let colorPickerSize = self.colorPickerView.update(
                transition: transition,
                component: AnyComponent(
                    ColorPickerComponent(
                        theme: environment.theme,
                        strings: environment.strings,
                        isVisible: state.editingColor,
                        bottomInset: colorPickerBottomInset,
                        colors: state.selectedBackground.colors,
                        colorsChanged: { [weak state] colors in
                            if let state {
                                state.customColor = .gradient(colors)
                                state.selectedBackground = .gradient(colors)
                                state.updated(transition: .immediate)
                            }
                        },
                        cancel: { [weak state] in
                            if let state {
                                state.selectedBackground = state.previousColor
                                state.customColor = state.previousCustomColor
                                state.editingColor = false
                                state.updated(transition: .easeInOut(duration: 0.3))
                            }
                        },
                        done: { [weak state] in
                            if let state {
                                state.editingColor = false
                                state.customColor = state.selectedBackground
                                state.updated(transition: .easeInOut(duration: 0.3))
                            }
                        }
                    )
                ),
                environment: {},
                containerSize: CGSize(width: availableSize.width - sideInset * 2.0, height: availableSize.height)
            )
            let colorPickerFrame = CGRect(origin: .zero, size: colorPickerSize)
            if let colorPickerView = self.colorPickerView.view {
                if colorPickerView.superview == nil {
                    self.backgroundContainerView.addSubview(colorPickerView)
                }
                transition.setFrame(view: colorPickerView, frame: colorPickerFrame)
                transition.setAlpha(view: colorPickerView, alpha: state.editingColor ? 1.0 : 0.0)
            }
            
            let backgroundContainerFrame = CGRect(origin: CGPoint(x: sideInset, y: contentHeight), size: state.editingColor ? colorPickerSize : backgroundSize)
            transition.setFrame(view: self.backgroundContainerView, frame: backgroundContainerFrame)
            
            contentHeight += backgroundContainerFrame.height
            contentHeight += 24.0
            
            let keyboardTitle: String
            let keyboardSwitchTitle: String
            
            if state.isSearchActive {
                keyboardTitle = strings.AvatarEditor_EmojiOrSticker
                keyboardSwitchTitle = " "
            } else if state.keyboardContentId == AnyHashable("emoji") {
                keyboardTitle = strings.AvatarEditor_Emoji
                keyboardSwitchTitle = strings.AvatarEditor_SwitchToStickers
            } else if state.keyboardContentId == AnyHashable("stickers") {
                keyboardTitle = strings.AvatarEditor_Stickers
                keyboardSwitchTitle = strings.AvatarEditor_SwitchToEmoji
            } else {
                keyboardTitle = " "
                keyboardSwitchTitle = " "
            }
            
            let keyboardTitleSize = self.keyboardTitleView.update(
                transition: .immediate,
                component: AnyComponent(MultilineTextComponent(
                    text: .markdown(
                        text: keyboardTitle.uppercased(), attributes: MarkdownAttributes(
                            body: body,
                            bold: bold,
                            link: body,
                            linkAttribute: { _ in nil }
                        )
                    ),
                    maximumNumberOfLines: 1
                )),
                environment: {},
                containerSize: CGSize(width: availableSize.width - sideInset * 2.0 - 15.0 * 2.0, height: .greatestFiniteMagnitude)
            )
            let keyboardTitleFrame = CGRect(origin: CGPoint(x: sideInset + 15.0, y: contentHeight), size: keyboardTitleSize)
            if let keyboardTitleView = self.keyboardTitleView.view {
                if keyboardTitleView.superview == nil {
                    self.addSubview(keyboardTitleView)
                }
                keyboardTitleView.bounds = CGRect(origin: .zero, size: keyboardTitleFrame.size)
                if keyboardTitleFrame.center.y == keyboardTitleView.center.y {
                    keyboardTitleView.center = keyboardTitleFrame.center
                } else {
                    transition.setPosition(view: keyboardTitleView, position: keyboardTitleFrame.center)
                }
                transition.setAlpha(view: keyboardTitleView, alpha: state.editingColor ? 0.0 : 1.0)
            }
            
            let keyboardSwitchSize = self.keyboardSwitchView.update(
                transition: .immediate,
                component: AnyComponent(
                    Button(
                        content: AnyComponent(
                            MultilineTextComponent(
                                text: .markdown(
                                    text: keyboardSwitchTitle.uppercased(), attributes: MarkdownAttributes(
                                        body: link,
                                        bold: link,
                                        link: link,
                                        linkAttribute: { _ in nil }
                                    )
                                ),
                                maximumNumberOfLines: 1
                            )
                        ), action: { [weak self] in
                            if let strongSelf = self, let state = strongSelf.state {
                                if let strongSelf = self, let pagerView = strongSelf.keyboardView.view as? EntityKeyboardComponent.View {
                                    let targetContentId: AnyHashable
                                    if state.keyboardContentId == AnyHashable("emoji") {
                                        targetContentId = AnyHashable("stickers")
                                    } else {
                                        targetContentId = AnyHashable("emoji")
                                    }
                                    pagerView.scrollToContentId(targetContentId)
                                }
                            }
                        }
                    )
                ),
                environment: {},
                containerSize: CGSize(width: availableSize.width - sideInset * 2.0 - 15.0 * 2.0, height: .greatestFiniteMagnitude)
            )
            let keyboardSwitchFrame = CGRect(origin: CGPoint(x: availableSize.width - sideInset - 15.0 - keyboardSwitchSize.width, y: contentHeight), size: keyboardSwitchSize)
            if let keyboardSwitchView = self.keyboardSwitchView.view {
                if keyboardSwitchView.superview == nil {
                    self.addSubview(keyboardSwitchView)
                }
                keyboardSwitchView.bounds = CGRect(origin: .zero, size: keyboardSwitchFrame.size)
                if keyboardSwitchFrame.center.y == keyboardSwitchView.center.y {
                    keyboardSwitchView.center = keyboardSwitchFrame.center
                } else {
                    transition.setPosition(view: keyboardSwitchView, position: keyboardSwitchFrame.center)
                }
                transition.setAlpha(view: keyboardSwitchView, alpha: state.editingColor ? 0.0 : 1.0)
            }
            contentHeight += keyboardTitleSize.height
            contentHeight += 8.0
            
            var bottomInset: CGFloat = environment.safeInsets.bottom > 0.0 ? environment.safeInsets.bottom : 16.0
            if !effectiveIsExpanded {
                bottomInset += 50.0 + 16.0
            }
            
            let keyboardContainerFrame = CGRect(origin: CGPoint(x: sideInset, y: contentHeight), size: CGSize(width: availableSize.width - sideInset * 2.0, height: availableSize.height - contentHeight - bottomInset))
            transition.setFrame(view: self.keyboardContainerView, frame: keyboardContainerFrame)
            transition.setAlpha(view: self.keyboardContainerView, alpha: state.editingColor ? 0.0 : 1.0)
            
            let isSearchActive = state.isSearchActive
            let topPanelHeight: CGFloat = isSearchActive ? 0.0 : 42.0

            if let data = self.data {
                let keyboardSize = self.keyboardView.update(
                    transition: transition.withUserData(EmojiPagerContentComponent.SynchronousLoadBehavior(isDisabled: true)),
                    component: AnyComponent(EntityKeyboardComponent(
                        theme: environment.theme,
                        strings: environment.strings,
                        isContentInFocus: false,
                        containerInsets: UIEdgeInsets(),
                        topPanelInsets: UIEdgeInsets(top: 0.0, left: topPanelHeight - 34.0, bottom: 0.0, right: 4.0),
                        emojiContent: data.emoji,
                        stickerContent: data.stickers,
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
                        hideTopPanelUpdated: { [weak self] hideTopPanel, transition in
                            if let strongSelf = self {
                                strongSelf.state?.isSearchActive = hideTopPanel
                                if hideTopPanel {
                                    strongSelf.state?.expanded = false
                                }
                                strongSelf.state?.updated(transition: transition)
                            }
                        },
                        switchToTextInput: {},
                        switchToGifSubject: { _ in },
                        reorderItems: { _, _ in },
                        makeSearchContainerNode: { _ in return nil },
                        contentIdUpdated: { [weak self] contentId in
                            if let strongSelf = self {
                                strongSelf.state?.keyboardContentId = contentId
                                strongSelf.state?.updated(transition: .immediate)
                            }
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
                    containerSize: CGSize(width: keyboardContainerFrame.size.width, height: keyboardContainerFrame.size.height - 6.0 + (isSearchActive ? 40.0 : 0.0))
                )
                if let keyboardComponentView = self.keyboardView.view {
                    if keyboardComponentView.superview == nil {
                        self.keyboardContainerView.insertSubview(keyboardComponentView, at: 0)
                    }
                    
                    self.panelBackgroundView.update(size: CGSize(width: keyboardSize.width, height: 42.0), transition: .immediate)
                    self.panelBackgroundView.updateColor(color: environment.theme.list.itemBlocksBackgroundColor.withAlphaComponent(0.8), transition: .immediate)
                    
                    transition.setFrame(view: self.panelBackgroundView, frame: CGRect(origin: CGPoint(x: 0.0, y: isSearchActive ? -42.0 : 0.0), size: CGSize(width: keyboardSize.width, height: 42.0)))
                    transition.setFrame(view: self.panelHostView, frame: CGRect(origin: CGPoint(x: 0.0, y: topPanelHeight - 34.0), size: CGSize(width: keyboardSize.width, height: 0.0)))
                    transition.setFrame(view: keyboardComponentView, frame: CGRect(origin: CGPoint(x: 0.0, y: topPanelHeight - 34.0), size: keyboardSize))
                    
                    transition.setFrame(view: self.panelSeparatorView, frame: CGRect(origin: CGPoint(x: 0.0, y: isSearchActive ? -UIScreenPixel : topPanelHeight), size: CGSize(width: availableSize.width, height: UIScreenPixel)))
                    transition.setAlpha(view: self.panelSeparatorView, alpha: isSearchActive ? 0.0 : 1.0)
                }
            }
            
            contentHeight += keyboardContainerFrame.height
            
            if effectiveIsExpanded {
                contentHeight += bottomInset
            } else {
                contentHeight += 16.0
            }
            
            let buttonText: String
            switch component.peerType {
            case .suggest:
                buttonText = strings.AvatarEditor_SuggestProfilePhoto
            case .user:
                buttonText = strings.AvatarEditor_SetProfilePhoto
            case .group, .forum:
                buttonText = strings.AvatarEditor_SetGroupPhoto
            case .channel:
                buttonText = strings.AvatarEditor_SetChannelPhoto
            }
            
            let buttonSize = self.buttonView.update(
                transition: transition,
                component: AnyComponent(
                    SolidRoundedButtonComponent(
                        title: buttonText,
                        theme: SolidRoundedButtonComponent.Theme(theme: environment.theme),
                        fontSize: 17.0,
                        height: 50.0,
                        cornerRadius: 10.0,
                        action: { [weak self] in
                            self?.complete()
                        }
                    )
                ),
                environment: {},
                containerSize: CGSize(width: availableSize.width - sideInset * 2.0, height: environment.navigationHeight - environment.statusBarHeight)
            )
            if let buttonView = self.buttonView.view {
                if buttonView.superview == nil {
                    self.addSubview(buttonView)
                }
                transition.setFrame(view: buttonView, frame: CGRect(origin: CGPoint(x: sideInset, y: contentHeight), size: buttonSize))
            }
          
            return availableSize
        }
        
        private let queue = Queue()
        func complete() {
            guard let state = self.state, let file = state.selectedFile, let controller = self.controller?() else {
                return
            }
            let context = controller.context
            let _ = context.animationCache.getFirstFrame(queue: self.queue, sourceId: file.resource.id.stringRepresentation, size: CGSize(width: 640.0, height: 640.0), fetch: animationCacheFetchFile(context: context, userLocation: .other, userContentType: .sticker, resource: .media(media: .standalone(media: file), resource: file.resource), type: AnimationCacheAnimationType(file: file), keyframeOnly: true, customColor: nil), completion: { result in
                guard let item = result.item else {
                    return
                }
                var image: UIImage?
                if let frame = item.advance(advance: .frames(1), requestedFormat: .rgba) {
                    switch frame.frame.format {
                    case let .rgba(data, width, height, bytesPerRow):
                        guard let context = DrawingContext(size: CGSize(width: CGFloat(width), height: CGFloat(height)), scale: 1.0, opaque: false, bytesPerRow: bytesPerRow) else {
                            return
                        }
                        
                        data.withUnsafeBytes { bytes -> Void in
                            memcpy(context.bytes, bytes.baseAddress!, height * bytesPerRow)
                        }
                        
                        image = context.generateImage()
                        if file.isCustomTemplateEmoji {
                            image = generateTintedImage(image: image, color: .white)
                        }
                    default:
                        return
                    }
                }
                
                Queue.mainQueue().async {
                    guard let image else {
                        return
                    }
                    
                    let size = CGSize(width: 800.0, height: 800.0)
                    let backgroundImage = state.selectedBackground.generateImage(size: size)
                    let tempPath = NSTemporaryDirectory() + "/\(UInt64.random(in: 0 ... UInt64.max)).jpg"
                    let tempUrl = NSURL(fileURLWithPath: tempPath) as URL
                    try? backgroundImage.jpegData(compressionQuality: 0.8)?.write(to: tempUrl)
                    
                    let drawingSize = CGSize(width: 1920.0, height: 1920.0)
                    let entity = DrawingStickerEntity(content: .file(file))
                    entity.referenceDrawingSize = drawingSize
                    entity.position = CGPoint(x: drawingSize.width / 2.0, y: drawingSize.height / 2.0)
                    entity.scale = 3.3
                    
                    var fileId: Int64 = 0
                    var stickerPackId: Int64 = 0
                    var stickerPackAccessHash: Int64 = 0
                    if case let .file(file) = entity.content {
                        if file.isCustomEmoji {
                            fileId = file.fileId.id
                        } else if file.isAnimatedSticker {
                            for attribute in file.attributes {
                                if case let .Sticker(_, packReference, _) = attribute, let packReference, case let .id(id, accessHash) = packReference {
                                    fileId = file.fileId.id
                                    stickerPackId = id
                                    stickerPackAccessHash = accessHash
                                    break
                                }
                            }
                            
                        }
                    }
                    
                    let colors: [NSNumber] = state.selectedBackground.colors.map { Int32(bitPattern: $0) as NSNumber }
                    
                    let entitiesData = DrawingEntitiesView.encodeEntitiesData([entity])
                    
                    let paintingData = TGPaintingData(
                        drawing: nil,
                        entitiesData: entitiesData,
                        image: nil,
                        stillImage: nil,
                        hasAnimation: entity.isAnimated,
                        stickers: []
                    )
                    
                    let adjustments = PGPhotoEditorValues(
                        originalSize: size,
                        cropRect: CGRect(origin: .zero, size: size),
                        cropRotation: 0.0,
                        cropOrientation: .up,
                        cropLockedAspectRatio: 1.0,
                        cropMirrored: false,
                        toolValues: [:],
                        paintingData: paintingData,
                        sendAsGif: true
                    )
                    let preset: TGMediaVideoConversionPreset = TGMediaVideoConversionPresetProfileHigh
                    
                    let combinedImage = generateImage(size, contextGenerator: { size, context in
                        let bounds = CGRect(origin: .zero, size: size)
                        if let cgImage = backgroundImage.cgImage {
                            context.draw(cgImage, in: bounds)
                        }
                        context.translateBy(x: size.width / 2.0, y: size.height / 2.0)
                        context.scaleBy(x: 0.67, y: 0.67)
                        context.translateBy(x: -size.width / 2.0, y: -size.height / 2.0)
                        
                        if let cgImage = image.cgImage {
                            context.draw(cgImage, in: bounds)
                        }
                    }, opaque: false)!
                    
                    if entity.isAnimated {
                        if stickerPackId != 0 {
                            controller.videoCompletion(combinedImage, tempUrl, TGVideoEditAdjustments(photoEditorValues: adjustments, preset: preset, stickerPackId: stickerPackId, stickerPackAccessHash: stickerPackAccessHash, documentId: fileId, colors: colors), { [weak controller] in
                                controller?.dismiss()
                            })
                        } else {
                            controller.videoCompletion(combinedImage, tempUrl, TGVideoEditAdjustments(photoEditorValues: adjustments, preset: preset, documentId: fileId, colors: colors), { [weak controller] in
                                controller?.dismiss()
                            })
                        }
                    } else {
                        controller.imageCompletion(combinedImage, { [weak controller] in
                            controller?.dismiss()
                        })
                    }
                }
            })
        }
    }
        
        
    func makeView() -> View {
        return View(frame: CGRect())
    }
    
    func update(view: View, availableSize: CGSize, state: State, environment: Environment<ViewControllerComponentContainer.Environment>, transition: Transition) -> CGSize {
        return view.update(component: self, availableSize: availableSize, state: state, environment: environment, transition: transition)
    }
}

public final class AvatarEditorScreen: ViewControllerComponentContainer {
    public enum PeerType {
        case suggest
        case user
        case group
        case channel
        case forum
    }
    fileprivate let context: AccountContext
    fileprivate let inputData: Signal<AvatarKeyboardInputData, NoError>
    
    private let readyValue = Promise<Bool>()
    override public var ready: Promise<Bool> {
        return self.readyValue
    }
    
    public var imageCompletion: (UIImage, @escaping () -> Void) -> Void = { _, _ in }
    public var videoCompletion: (UIImage, URL, TGVideoEditAdjustments, @escaping () -> Void) -> Void = { _, _, _, _ in }
        
    public static func inputData(context: AccountContext, isGroup: Bool) -> Signal<AvatarKeyboardInputData, NoError> {
        let emojiItems = EmojiPagerContentComponent.emojiInputData(
            context: context,
            animationCache: context.animationCache,
            animationRenderer: context.animationRenderer,
            isStandalone: false,
            isStatusSelection: false,
            isReactionSelection: false,
            isEmojiSelection: false,
            hasTrending: false,
            isProfilePhotoEmojiSelection: !isGroup,
            isGroupPhotoEmojiSelection: isGroup,
            topReactionItems: [],
            areUnicodeEmojiEnabled: false,
            areCustomEmojiEnabled: true,
            chatPeerId: context.account.peerId,
            hasSearch: true,
            forceHasPremium: true
        )
        
        let stickerItems = EmojiPagerContentComponent.stickerInputData(
            context: context,
            animationCache: context.animationCache,
            animationRenderer: context.animationRenderer,
            stickerNamespaces: [Namespaces.ItemCollection.CloudStickerPacks],
            stickerOrderedItemListCollectionIds: [Namespaces.OrderedItemList.CloudSavedStickers, Namespaces.OrderedItemList.CloudRecentStickers, Namespaces.OrderedItemList.CloudAllPremiumStickers],
            chatPeerId: context.account.peerId,
            hasSearch: true,
            hasTrending: false,
            forceHasPremium: true,
            searchIsPlaceholderOnly: false,
            isProfilePhotoEmojiSelection: !isGroup,
            isGroupPhotoEmojiSelection: isGroup
        )
        
        let signal = combineLatest(queue: .mainQueue(),
            emojiItems,
            stickerItems
        ) |> map { emoji, stickers -> AvatarKeyboardInputData in
            return AvatarKeyboardInputData(emoji: emoji, stickers: stickers)
        }
        return signal
    }
    
    public init(context: AccountContext, inputData: Signal<AvatarKeyboardInputData, NoError>, peerType: PeerType, markup: TelegramMediaImage.EmojiMarkup?) {
        self.context = context
        self.inputData = inputData
        
        let componentReady = Promise<Bool>()
        super.init(context: context, component: AvatarEditorScreenComponent(context: context, ready: componentReady, peerType: peerType, markup: markup), navigationBarAppearance: .transparent)
        self.navigationPresentation = .modal
            
        self.readyValue.set(componentReady.get() |> timeout(0.3, queue: .mainQueue(), alternate: .single(true)))
        
        self.navigationItem.leftBarButtonItem = UIBarButtonItem(customView: UIView())
        
        self.supportedOrientations = ViewControllerSupportedOrientations(regularSize: .all, compactSize: .portrait)
        
        self.scrollToTop = { [weak self] in
            if let self {
                if let view = self.node.hostView.findTaggedView(tag: EmojiPagerContentComponent.Tag(id: AnyHashable("emoji"))) as? EmojiPagerContentComponent.View {
                    view.scrollToTop()
                } else if let view = self.node.hostView.findTaggedView(tag: EmojiPagerContentComponent.Tag(id: AnyHashable("emoji"))) as? EmojiPagerContentComponent.View {
                    view.scrollToTop()
                }
            }
        }
    }
    
    required public init(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override public func viewDidLoad() {
        super.viewDidLoad()
    }
    
    public override func preferredContentSizeForLayout(_ layout: ContainerViewLayout) -> CGSize? {
        return CGSize(width: 390.0, height: 730.0)
    }
}
