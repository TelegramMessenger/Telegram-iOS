import Foundation
import UIKit
import Display
import SwiftSignalKit
import ComponentFlow
import TelegramCore
import TelegramPresentationData
import AccountContext
import EntityKeyboard
import EmojiStatusSelectionComponent

final class QrStudioEmojiTabView: UIView {
    var resolveUnicode: ((String) -> QrStudioEmojiItem?)?
    var toggle: ((QrStudioEmojiItem) -> Bool)?
    var push: ((ViewController) -> Void)?
    var premiumRequired: (() -> Void)?
    var requestLayout: (() -> Void)?
    var scrollViewFound: ((UIScrollView) -> Void)?
    var isAnimatedUnicode: ((String) -> Bool)?

    private struct SearchResult {
        var groups: [EmojiPagerContentComponent.ItemGroup]
        var id: AnyHashable
        var version: Int
        var canLoadMore: Bool
        var isSearching: Bool
    }

    private let context: AccountContext
    private let keyboard = ComponentView<Empty>()
    private var emojiContent: EmojiPagerContentComponent?
    private var sourceEmojiContent: EmojiPagerContentComponent?
    private var filteredAnimatedCount = 0
    private var searchResult: SearchResult?
    private var emojiSearchContext: EmojiSearchContext?
    private let searchDisposable = MetaDisposable()
    private var emptyResultText = ""
    private var emojiContentDisposable: Disposable?
    private var didFindScrollView = false
    private let hapticFeedback = HapticFeedback()

    private let tintMaskContainer: UIView?
    private let tintFadeMask = CAGradientLayer()

    private static let topPanelHeight: CGFloat = 42.0
    private static let fadeHeight: CGFloat = 16.0

    init(context: AccountContext, tintMaskContainer: UIView?) {
        self.context = context
        self.tintMaskContainer = tintMaskContainer

        super.init(frame: CGRect())

        self.clipsToBounds = true

        self.emojiContentDisposable = (EmojiPagerContentComponent.emojiInputData(
            context: context,
            animationCache: context.animationCache,
            animationRenderer: context.animationRenderer,
            isStandalone: false,
            subject: .emoji,
            hasTrending: false,
            topReactionItems: [],
            areUnicodeEmojiEnabled: true,
            areCustomEmojiEnabled: true,
            chatPeerId: context.account.peerId,
            hasSearch: true,
            hideBackground: true
        )
        |> deliverOnMainQueue).startStrict(next: { [weak self] emojiContent in
            guard let self else {
                return
            }
            let emojiContent = QrStudioEmojiTabView.systemEmojiFirst(QrStudioEmojiTabView.supportedOnly(emojiContent))
            self.sourceEmojiContent = emojiContent
            self.filteredAnimatedCount = 0
            self.emojiContent = emojiContent
            emojiContent.inputInteractionHolder.inputInteraction = EmojiPagerContentComponent.InputInteraction(
                performItemAction: { [weak self] _, item, _, _, _, _ in
                    self?.perform(item: item)
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
                pushController: { [weak self] controller in
                    self?.push?(controller)
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
                    self?.updateSearchQuery(query)
                },
                updateScrollingToItemGroup: {
                },
                onScroll: {
                },
                loadMore: { [weak self] in
                    self?.emojiSearchContext?.loadMore()
                },
                chatPeerId: nil,
                peekBehavior: nil,
                customLayout: nil,
                externalBackground: self.tintMaskContainer.flatMap { EmojiPagerContentComponent.ExternalBackground(effectContainerView: $0) },
                externalExpansionView: nil,
                customContentView: nil,
                useOpaqueTheme: false,
                hideBackground: true,
                stateContext: nil,
                addImage: nil
            )
            self.requestLayout?()
        })
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    deinit {
        self.emojiContentDisposable?.dispose()
        self.searchDisposable.dispose()
    }

    private static func systemEmojiFirst(_ content: EmojiPagerContentComponent) -> EmojiPagerContentComponent {
        func reorder(_ groups: [EmojiPagerContentComponent.ItemGroup]) -> [EmojiPagerContentComponent.ItemGroup] {
            let isSystem: (EmojiPagerContentComponent.ItemGroup) -> Bool = { $0.groupId == AnyHashable("static") }
            return groups.filter(isSystem) + groups.filter { !isSystem($0) }
        }
        return content.withUpdatedItemGroups(panelItemGroups: reorder(content.panelItemGroups), contentItemGroups: reorder(content.contentItemGroups), itemContentUniqueId: content.itemContentUniqueId, emptySearchResults: content.emptySearchResults, searchState: content.searchState)
    }

    static func isSupported(_ file: TelegramMediaFile) -> Bool {
        return !file.isStaticEmoji && !file.isVideoEmoji && !file.isCustomTemplateEmoji
    }

    static func isSupported(_ file: TelegramMediaFile.Accessor) -> Bool {
        return !file.isStaticEmoji && !file.isVideoEmoji && !file.isCustomTemplateEmoji
    }

    private static func withItems(_ group: EmojiPagerContentComponent.ItemGroup, _ items: [EmojiPagerContentComponent.Item]) -> EmojiPagerContentComponent.ItemGroup {
        return EmojiPagerContentComponent.ItemGroup(
            supergroupId: group.supergroupId,
            groupId: group.groupId,
            title: group.title,
            subtitle: group.subtitle,
            badge: group.badge,
            actionButtonTitle: group.actionButtonTitle,
            isFeatured: group.isFeatured,
            isPremiumLocked: group.isPremiumLocked,
            isEmbedded: group.isEmbedded,
            hasClear: group.hasClear,
            hasEdit: group.hasEdit,
            collapsedLineCount: group.collapsedLineCount,
            displayPremiumBadges: group.displayPremiumBadges,
            headerItem: group.headerItem,
            fillWithLoadingPlaceholders: group.fillWithLoadingPlaceholders,
            customTintColor: group.customTintColor,
            items: items
        )
    }

    private static func supportedOnly(_ content: EmojiPagerContentComponent) -> EmojiPagerContentComponent {
        let contentGroups = content.contentItemGroups.compactMap { group -> EmojiPagerContentComponent.ItemGroup? in
            guard group.groupId != AnyHashable("static") else {
                return group
            }
            let items = group.items.filter { item in
                if let file = item.itemFile {
                    return QrStudioEmojiTabView.isSupported(file)
                }
                return true
            }
            if items.isEmpty && !group.items.isEmpty {
                return nil
            }
            return items.count == group.items.count ? group : QrStudioEmojiTabView.withItems(group, items)
        }
        let groupIds = Set(contentGroups.map { $0.groupId })
        let panelGroups = content.panelItemGroups.filter { groupIds.contains($0.groupId) }
        return content.withUpdatedItemGroups(panelItemGroups: panelGroups, contentItemGroups: contentGroups, itemContentUniqueId: content.itemContentUniqueId, emptySearchResults: content.emptySearchResults, searchState: content.searchState)
    }

    private func filterStaticEmoji(animatedCount: Int) {
        guard animatedCount > 0, animatedCount != self.filteredAnimatedCount, let content = self.sourceEmojiContent, let isAnimatedUnicode = self.isAnimatedUnicode else {
            return
        }
        self.filteredAnimatedCount = animatedCount
        let groups = content.contentItemGroups.map { group -> EmojiPagerContentComponent.ItemGroup in
            guard group.groupId == AnyHashable("static") else {
                return group
            }
            let items = group.items.filter { item in
                if case let .staticEmoji(emoji) = item.content {
                    return isAnimatedUnicode(emoji)
                }
                return true
            }
            return QrStudioEmojiTabView.withItems(group, items)
        }
        self.emojiContent = content.withUpdatedItemGroups(panelItemGroups: content.panelItemGroups, contentItemGroups: groups, itemContentUniqueId: content.itemContentUniqueId, emptySearchResults: content.emptySearchResults, searchState: content.searchState)
    }

    private static func searchGroup(_ items: [EmojiPagerContentComponent.Item], placeholders: Bool) -> EmojiPagerContentComponent.ItemGroup {
        return EmojiPagerContentComponent.ItemGroup(
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
            fillWithLoadingPlaceholders: placeholders,
            items: items
        )
    }

    private static func fileItem(_ file: TelegramMediaFile) -> EmojiPagerContentComponent.Item {
        let animationData = EntityKeyboardAnimationData(file: TelegramMediaFile.Accessor(file))
        return EmojiPagerContentComponent.Item(
            animationData: animationData,
            content: .animation(animationData),
            itemFile: TelegramMediaFile.Accessor(file),
            subgroupId: nil,
            icon: .none,
            tintMode: animationData.isTemplate ? .primary : .none
        )
    }

    func cancelSearch() {
        self.updateSearchQuery(nil)
    }

    private func updateSearchQuery(_ query: EmojiPagerContentComponent.SearchQuery?) {
        let context = self.context
        switch query {
        case .none:
            self.emojiSearchContext = nil
            self.searchDisposable.set(nil)
            self.searchResult = nil
            self.requestLayout?()
        case let .text(rawQuery, languageCode):
            let query = rawQuery.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !query.isEmpty else {
                self.updateSearchQuery(nil)
                return
            }
            self.emojiSearchContext = nil

            var keywords = context.engine.stickers.searchEmojiKeywords(inputLanguageCode: languageCode, query: query, completeMatch: false)
            if !languageCode.lowercased().hasPrefix("en") {
                keywords = keywords
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

            let isAnimatedUnicode = self.isAnimatedUnicode
            let hasPremium = context.isPremium
            let resultSignal = keywords
            |> mapToSignal { keywords -> Signal<(groups: [EmojiPagerContentComponent.ItemGroup], canLoadMore: Bool, isSearching: Bool, searchContext: EmojiSearchContext), NoError> in
                var emoticons: [String] = []
                var existingEmoticons = Set<String>()
                for keyword in keywords {
                    for emoticon in keyword.emoticons where !existingEmoticons.contains(emoticon) {
                        existingEmoticons.insert(emoticon)
                        emoticons.append(emoticon)
                    }
                }

                let searchContext = context.engine.stickers.emojiSearchContext(query: query, emoticon: emoticons, inputLanguageCode: languageCode)
                return searchContext.state
                |> map { found -> (groups: [EmojiPagerContentComponent.ItemGroup], canLoadMore: Bool, isSearching: Bool, searchContext: EmojiSearchContext) in
                    var items: [EmojiPagerContentComponent.Item] = []
                    for emoticon in emoticons where isAnimatedUnicode?(emoticon) ?? false {
                        items.append(EmojiPagerContentComponent.Item(
                            animationData: nil,
                            content: .staticEmoji(emoticon),
                            itemFile: nil,
                            subgroupId: nil,
                            icon: .none,
                            tintMode: .none
                        ))
                    }
                    var existingIds = Set<EngineMedia.Id>()
                    for file in found.items where !existingIds.contains(file.fileId) {
                        existingIds.insert(file.fileId)
                        if file.isPremiumEmoji && !hasPremium {
                            continue
                        }
                        if !QrStudioEmojiTabView.isSupported(file) {
                            continue
                        }
                        items.append(QrStudioEmojiTabView.fileItem(file))
                    }
                    return ([QrStudioEmojiTabView.searchGroup(items, placeholders: false)], found.canLoadMore, items.isEmpty && found.isLoadingMore, searchContext)
                }
            }

            var version = 0
            if self.searchResult == nil {
                self.searchResult = SearchResult(groups: [QrStudioEmojiTabView.searchGroup([], placeholders: true)], id: AnyHashable(query), version: -1, canLoadMore: false, isSearching: true)
            } else {
                self.searchResult?.isSearching = true
            }
            self.requestLayout?()
            self.searchDisposable.set((resultSignal
            |> delay(0.15, queue: .mainQueue())
            |> deliverOnMainQueue).startStrict(next: { [weak self] result in
                guard let self else {
                    return
                }
                self.emojiSearchContext = result.searchContext
                self.searchResult = SearchResult(groups: result.groups, id: AnyHashable(query), version: version, canLoadMore: result.canLoadMore, isSearching: result.isSearching)
                version += 1
                self.requestLayout?()
            }))
        case let .category(value):
            self.emojiSearchContext = nil
            let resultSignal = context.engine.stickers.searchEmoji(category: value)
            |> map { files, isFinalResult -> (items: [EmojiPagerContentComponent.Item], isFinalResult: Bool) in
                var items: [EmojiPagerContentComponent.Item] = []
                var existingIds = Set<EngineMedia.Id>()
                for file in files where !existingIds.contains(file.fileId) && QrStudioEmojiTabView.isSupported(file) {
                    existingIds.insert(file.fileId)
                    items.append(QrStudioEmojiTabView.fileItem(file))
                }
                return (items, isFinalResult)
            }
            var version = 0
            self.searchDisposable.set((resultSignal
            |> deliverOnMainQueue).startStrict(next: { [weak self] result in
                guard let self else {
                    return
                }
                let placeholders = result.items.isEmpty && !result.isFinalResult
                self.searchResult = SearchResult(groups: [QrStudioEmojiTabView.searchGroup(result.items, placeholders: placeholders)], id: AnyHashable(value.id), version: version, canLoadMore: false, isSearching: false)
                version += 1
                self.requestLayout?()
            }))
        }
    }

    private func perform(item: EmojiPagerContentComponent.Item) {
        var resolved: QrStudioEmojiItem?
        if case let .staticEmoji(emoji) = item.content {
            resolved = self.resolveUnicode?(emoji)
        } else if let itemFile = item.itemFile {
            let file = itemFile._parse()
            if file.isPremiumEmoji && !self.context.isPremium {
                self.hapticFeedback.error()
                self.premiumRequired?()
                return
            }
            resolved = QrStudioEmojiItem(file: file, unicode: nil)
        }
        guard let resolved, let toggle = self.toggle, toggle(resolved) else {
            self.hapticFeedback.error()
            return
        }
        self.hapticFeedback.tap()
    }

    private static func findScrollView(in view: UIView) -> UIScrollView? {
        var best: UIScrollView?
        var queue: [UIView] = [view]
        while !queue.isEmpty {
            let current = queue.removeFirst()
            if let scrollView = current as? UIScrollView, scrollView.bounds.height > 100.0, scrollView.bounds.width > 100.0 {
                if best == nil || scrollView.bounds.height > best!.bounds.height {
                    best = scrollView
                }
            }
            queue.append(contentsOf: current.subviews)
        }
        return best
    }

    func update(size: CGSize, theme: PresentationTheme, strings: PresentationStrings, deviceMetrics: DeviceMetrics, selected: [QrStudioEmojiItem], animatedCount: Int) {
        self.filterStaticEmoji(animatedCount: animatedCount)
        guard var emojiContent = self.emojiContent, size.width > 0.0, size.height > 0.0 else {
            return
        }
        if let searchResult = self.searchResult {
            var emptySearchResults: EmojiPagerContentComponent.EmptySearchResults?
            if !searchResult.groups.contains(where: { !$0.items.isEmpty || $0.fillWithLoadingPlaceholders }) {
                emptySearchResults = EmojiPagerContentComponent.EmptySearchResults(text: strings.EmojiSearch_SearchEmojiEmptyResult, iconFile: nil)
            }
            emojiContent = emojiContent.withUpdatedItemGroups(panelItemGroups: emojiContent.panelItemGroups, contentItemGroups: searchResult.groups, itemContentUniqueId: EmojiPagerContentComponent.ContentId(id: searchResult.id, version: searchResult.version), emptySearchResults: emptySearchResults, searchState: searchResult.isSearching ? .searching : .active, canLoadMore: searchResult.canLoadMore)
        }

        var selectedItems = Set<AnyHashable>()
        var order: [AnyHashable: Int] = [:]
        for (index, item) in selected.enumerated() {
            if let unicode = item.unicode {
                let stripped = unicode.replacingOccurrences(of: "\u{FE0F}", with: "")
                for variant in [unicode, stripped, stripped + "\u{FE0F}"] {
                    selectedItems.insert(variant)
                    order[variant] = index + 1
                }
            } else {
                selectedItems.insert(item.file.fileId)
                order[item.file.fileId] = index + 1
            }
        }

        let _ = self.keyboard.update(
            transition: .immediate,
            component: AnyComponent(EmojiStatusSelectionComponent(
                theme: theme,
                strings: strings,
                deviceMetrics: deviceMetrics,
                emojiContent: emojiContent.withSelection(items: selectedItems, order: order),
                color: nil,
                backgroundColor: .clear,
                separatorColor: .clear,
                hideTopPanel: false,
                disableTopPanel: false,
                hideTopPanelUpdated: { _, _ in
                },
                externalTintMaskContainer: self.tintMaskContainer,
                contentFadeHeight: QrStudioEmojiTabView.fadeHeight,
                keepsTopPanelVisible: true
            )),
            environment: {},
            containerSize: size
        )
        if let tintMaskContainer = self.tintMaskContainer {
            if tintMaskContainer.layer.mask !== self.tintFadeMask {
                self.tintFadeMask.colors = [UIColor.clear.cgColor, UIColor.clear.cgColor, UIColor.black.cgColor, UIColor.black.cgColor]
                self.tintFadeMask.startPoint = CGPoint(x: 0.5, y: 0.0)
                self.tintFadeMask.endPoint = CGPoint(x: 0.5, y: 1.0)
                tintMaskContainer.layer.mask = self.tintFadeMask
            }
            let height = max(1.0, size.height)
            CATransaction.begin()
            CATransaction.setDisableActions(true)
            self.tintFadeMask.frame = CGRect(origin: CGPoint(), size: size)
            self.tintFadeMask.locations = [0.0, NSNumber(value: Double(QrStudioEmojiTabView.topPanelHeight / height)), NSNumber(value: Double((QrStudioEmojiTabView.topPanelHeight + QrStudioEmojiTabView.fadeHeight) / height)), 1.0]
            CATransaction.commit()
        }

        if let keyboardView = self.keyboard.view {
            if keyboardView.superview == nil {
                self.addSubview(keyboardView)
            }
            keyboardView.frame = CGRect(origin: CGPoint(), size: size)

            if !self.didFindScrollView, let scrollView = QrStudioEmojiTabView.findScrollView(in: keyboardView) {
                self.didFindScrollView = true
                self.scrollViewFound?(scrollView)
            }
        }
    }
}
