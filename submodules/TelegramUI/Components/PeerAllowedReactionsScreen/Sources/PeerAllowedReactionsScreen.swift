import Foundation
import UIKit
import Display
import TelegramPresentationData
import ComponentFlow
import ComponentDisplayAdapters
import AppBundle
import ViewControllerComponent
import AccountContext
import TelegramCore
import Postbox
import SwiftSignalKit
import EntityKeyboard
import MultilineTextComponent
import Markdown
import ButtonComponent
import PremiumUI
import UndoUI
import BundleIconComponent
import AnimatedTextComponent
import TextFormat
import AudioToolbox
import PremiumLockButtonSubtitleComponent
import ListSectionComponent
import ListItemSliderSelectorComponent
import ListSwitchItemComponent

final class PeerAllowedReactionsScreenComponent: Component {
    typealias EnvironmentType = ViewControllerComponentContainer.Environment
    
    let context: AccountContext
    let peerId: EnginePeer.Id
    let initialContent: PeerAllowedReactionsScreen.Content

    init(
        context: AccountContext,
        peerId: EnginePeer.Id,
        initialContent: PeerAllowedReactionsScreen.Content
    ) {
        self.context = context
        self.peerId = peerId
        self.initialContent = initialContent
    }

    static func ==(lhs: PeerAllowedReactionsScreenComponent, rhs: PeerAllowedReactionsScreenComponent) -> Bool {
        if lhs.context !== rhs.context {
            return false
        }
        if lhs.peerId != rhs.peerId {
            return false
        }

        return true
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
        private let scrollView: UIScrollView
        private let switchItem = ComponentView<Empty>()
        private let switchInfoText = ComponentView<Empty>()
        private var reactionsTitleText: ComponentView<Empty>?
        private var reactionsInfoText: ComponentView<Empty>?
        private var reactionInput: ComponentView<Empty>?
        private var reactionCountSection: ComponentView<Empty>?
        private var paidReactionsSection: ComponentView<Empty>?
        private let actionButton = ComponentView<Empty>()
        
        private var reactionSelectionControl: ComponentView<Empty>?
        
        private var isUpdating: Bool = false
        
        private var component: PeerAllowedReactionsScreenComponent?
        private(set) weak var state: EmptyComponentState?
        private var environment: EnvironmentType?
        
        private var boostStatus: ChannelBoostStatus?
        private var boostStatusDisposable: Disposable?
        
        private var isEnabled: Bool = false
        private var availableReactions: AvailableReactions?
        private var enabledReactions: [EmojiComponentReactionItem]?
        private var allowedReactionCount: Int = 11
        private var appliedReactionSettings: PeerReactionSettings?
        
        private var areStarsReactionsEnabled: Bool = true
        
        private var emojiContent: EmojiPagerContentComponent?
        private var emojiContentDisposable: Disposable?
        
        private let emojiSearchDisposable = MetaDisposable()
        private let emojiSearchState = Promise<EmojiSearchState>(EmojiSearchState(result: nil, isSearching: false))
        private var emojiSearchStateValue = EmojiSearchState(result: nil, isSearching: false) {
            didSet {
                self.emojiSearchState.set(.single(self.emojiSearchStateValue))
            }
        }
        
        private var emptyResultEmojis: [TelegramMediaFile] = []
        private var stableEmptyResultEmoji: TelegramMediaFile?
        private let stableEmptyResultEmojiDisposable = MetaDisposable()
        
        private var caretPosition: Int?
        
        private var displayInput: Bool = false
        private var recenterOnCaret: Bool = false
        
        private var isApplyingSettings: Bool = false
        private var applyDisposable: Disposable?
        
        private var resolveStickersBotDisposable: Disposable?
        
        private weak var currentUndoController: UndoOverlayController?
        
        private var cachedChevronImage: (UIImage, PresentationTheme)?
        
        override init(frame: CGRect) {
            self.scrollView = UIScrollView()
            self.scrollView.showsVerticalScrollIndicator = true
            self.scrollView.showsHorizontalScrollIndicator = false
            self.scrollView.scrollsToTop = false
            self.scrollView.delaysContentTouches = false
            self.scrollView.canCancelContentTouches = true
            self.scrollView.contentInsetAdjustmentBehavior = .never
            self.scrollView.alwaysBounceVertical = true
            
            super.init(frame: frame)
            
            self.scrollView.delegate = self
            self.addSubview(self.scrollView)
        }
        
        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }
        
        deinit {
            self.emojiContentDisposable?.dispose()
            self.applyDisposable?.dispose()
            self.boostStatusDisposable?.dispose()
            self.resolveStickersBotDisposable?.dispose()
        }

        func scrollToTop() {
            self.scrollView.setContentOffset(CGPoint(), animated: true)
        }
        
        func attemptNavigation(complete: @escaping () -> Void) -> Bool {
            guard let component = self.component else {
                return true
            }
            if self.isApplyingSettings {
                return true
            }
            guard var enabledReactions = self.enabledReactions else {
                return true
            }
            if !self.isEnabled {
                enabledReactions.removeAll()
            }
            
            enabledReactions.removeAll(where: { $0.reaction == .stars })
            
            guard let availableReactions = self.availableReactions else {
                return true
            }
            
            let allowedReactions: PeerAllowedReactions
            if self.isEnabled {
                if Set(availableReactions.reactions.filter({ $0.isEnabled }).map(\.value)) == Set(enabledReactions.map(\.reaction)) {
                    allowedReactions = .all
                } else {
                    if enabledReactions.isEmpty {
                        allowedReactions = .empty
                    } else {
                        allowedReactions = .limited(enabledReactions.map(\.reaction))
                    }
                }
            } else {
                allowedReactions = .empty
            }
            
            let reactionSettings = PeerReactionSettings(allowedReactions: allowedReactions, maxReactionCount: self.allowedReactionCount >= 11 ? nil : Int32(self.allowedReactionCount), starsAllowed: self.isEnabled && self.areStarsReactionsEnabled)
            
            if self.appliedReactionSettings != reactionSettings {
                if case .empty = allowedReactions {
                    self.applySettings(standalone: true)
                } else {
                    let presentationData = component.context.sharedContext.currentPresentationData.with { $0 }
                    self.environment?.controller()?.present(standardTextAlertController(theme: AlertControllerTheme(presentationData: presentationData), title: presentationData.strings.ChannelReactions_UnsavedChangesAlertTitle, text: presentationData.strings.ChannelReactions_UnsavedChangesAlertText, actions: [
                        TextAlertAction(type: .genericAction, title: presentationData.strings.ChannelReactions_UnsavedChangesAlertDiscard, action: { [weak self] in
                            guard let self else {
                                return
                            }
                            self.environment?.controller()?.dismiss()
                        }),
                        TextAlertAction(type: .defaultAction, title: presentationData.strings.ChannelReactions_UnsavedChangesAlertApply, action: { [weak self] in
                            guard let self else {
                                return
                            }
                            self.applySettings(standalone: false)
                        })
                    ]), in: .window(.root))
                    
                    return false
                }
            }
            
            return true
        }
        
        func scrollViewDidScroll(_ scrollView: UIScrollView) {
            self.updateScrolling(transition: .immediate)
        }
        
        private func updateScrolling(transition: ComponentTransition) {
            let navigationAlphaDistance: CGFloat = 16.0
            let navigationAlpha: CGFloat = max(0.0, min(1.0, self.scrollView.contentOffset.y / navigationAlphaDistance))
            if let controller = self.environment?.controller(), let navigationBar = controller.navigationBar {
                transition.setAlpha(layer: navigationBar.backgroundNode.layer, alpha: navigationAlpha)
                transition.setAlpha(layer: navigationBar.stripeNode.layer, alpha: navigationAlpha)
            }
        }
        
        private func applySettings(standalone: Bool) {
            guard let component = self.component else {
                return
            }
            if self.isApplyingSettings {
                return
            }
            guard var enabledReactions = self.enabledReactions else {
                return
            }
            enabledReactions.removeAll(where: { $0.reaction == .stars })
            
            if !self.isEnabled {
                enabledReactions.removeAll()
            }
            
            guard let availableReactions = self.availableReactions else {
                return
            }
            
            let customReactions = enabledReactions.filter({ item in
                switch item.reaction {
                case .custom:
                    return true
                case .builtin:
                    return false
                case .stars:
                    return false
                }
            })
            
            if let boostStatus = self.boostStatus, !customReactions.isEmpty, customReactions.count > boostStatus.level {
                self.displayPremiumScreen(reactionCount: customReactions.count)
                return
            }
            
            self.isApplyingSettings = true
            self.state?.updated(transition: .immediate)
            
            self.applyDisposable?.dispose()
            
            let allowedReactions: PeerAllowedReactions
            if self.isEnabled {
                if Set(availableReactions.reactions.filter({ $0.isEnabled }).map(\.value)) == Set(enabledReactions.map(\.reaction)) {
                    allowedReactions = .all
                } else if enabledReactions.isEmpty {
                    allowedReactions = .empty
                } else {
                    allowedReactions = .limited(enabledReactions.map(\.reaction))
                }
            } else {
                allowedReactions = .empty
            }
            let reactionSettings = PeerReactionSettings(allowedReactions: allowedReactions, maxReactionCount: self.allowedReactionCount == 11 ? nil : Int32(self.allowedReactionCount), starsAllowed: self.isEnabled && self.areStarsReactionsEnabled)
            
            let applyDisposable = (component.context.engine.peers.updatePeerReactionSettings(peerId: component.peerId, reactionSettings: reactionSettings)
            |> deliverOnMainQueue).start(error: { [weak self] error in
                guard let self, let component = self.component else {
                    return
                }
                self.isApplyingSettings = false
                self.state?.updated(transition: .immediate)
                
                if !standalone {
                    switch error {
                    case .boostRequired:
                        self.displayPremiumScreen(reactionCount: customReactions.count)
                    case .generic:
                        let presentationData = component.context.sharedContext.currentPresentationData.with { $0 }
                        self.environment?.controller()?.present(standardTextAlertController(theme: AlertControllerTheme(presentationData: presentationData), title: nil, text: presentationData.strings.Login_UnknownError, actions: [TextAlertAction(type: .defaultAction, title: presentationData.strings.Common_OK, action: {})]), in: .window(.root))
                    }
                }
            }, completed: { [weak self] in
                guard let self else {
                    return
                }
                self.appliedReactionSettings = reactionSettings
                if !standalone {
                    self.environment?.controller()?.dismiss()
                }
            })
            
            if standalone {
                let _ = applyDisposable
            } else {
                self.applyDisposable = applyDisposable
            }
        }
        
        private func displayPremiumScreen(reactionCount: Int) {
            guard let component = self.component else {
                return
            }
            
            let _ = (component.context.engine.data.get(TelegramEngine.EngineData.Item.Peer.Peer(id: component.peerId))
            |> deliverOnMainQueue).startStandalone(next: { [weak self] peer in
                guard let self, let component = self.component, let peer, let status = self.boostStatus else {
                    return
                }
                
                let premiumConfiguration = PremiumConfiguration.with(appConfiguration: component.context.currentAppConfiguration.with { $0 })
                
                let link = status.url
                let controller = PremiumLimitScreen(context: component.context, subject: .storiesChannelBoost(peer: peer, boostSubject: .channelReactions(reactionCount: reactionCount), isCurrent: true, level: Int32(status.level), currentLevelBoosts: Int32(status.currentLevelBoosts), nextLevelBoosts: status.nextLevelBoosts.flatMap(Int32.init), link: link, myBoostCount: 0, canBoostAgain: false), count: Int32(status.boosts), action: { [weak self] in
                    guard let self, let component = self.component else {
                        return true
                    }
                            
                    UIPasteboard.general.string = link
                    let presentationData = component.context.sharedContext.currentPresentationData.with { $0 }
                    self.environment?.controller()?.present(UndoOverlayController(presentationData: presentationData, content: .linkCopied(title: nil, text: presentationData.strings.ChannelBoost_BoostLinkCopied), elevatedLayout: false, position: .bottom, animateInAsReplacement: false, action: { _ in return false }), in: .current)
                    return true
                }, openStats: { [weak self] in
                    guard let self else {
                        return
                    }
                    self.openBoostStats()
                }, openGift: premiumConfiguration.giveawayGiftsPurchaseAvailable ? { [weak self] in
                    guard let self, let component = self.component else {
                        return
                    }
                    let controller = createGiveawayController(context: component.context, peerId: component.peerId, subject: .generic)
                    self.environment?.controller()?.push(controller)
                } : nil)
                self.environment?.controller()?.push(controller)
                
                HapticFeedback().impact(.light)
            })
        }
        
        private func openBoostStats() {
            guard let component = self.component, let boostStatus = self.boostStatus else {
                return
            }
            let statsController = component.context.sharedContext.makeChannelStatsController(context: component.context, updatedPresentationData: nil, peerId: component.peerId, boosts: true, boostStatus: boostStatus)
            self.environment?.controller()?.push(statsController)
        }
        
        func update(component: PeerAllowedReactionsScreenComponent, availableSize: CGSize, state: EmptyComponentState, environment: Environment<EnvironmentType>, transition: ComponentTransition) -> CGSize {
            self.isUpdating = true
            defer {
                self.isUpdating = false
            }
            
            let environment = environment[EnvironmentType.self].value
            let themeUpdated = self.environment?.theme !== environment.theme
            self.environment = environment
            
            self.component = component
            self.state = state
            
            let topInset: CGFloat = 24.0
            let bottomInset: CGFloat = 8.0
            let sideInset: CGFloat = 16.0 + environment.safeInsets.left
            let textSideInset: CGFloat = 16.0
            
            let enabledReactions: [EmojiComponentReactionItem]
            if let current = self.enabledReactions {
                enabledReactions = current
            } else {
                if let value = component.initialContent.reactionSettings?.starsAllowed {
                    self.areStarsReactionsEnabled = value
                } else {
                    self.areStarsReactionsEnabled = component.initialContent.isStarReactionAvailable
                }
                
                var enabledReactionsValue = component.initialContent.enabledReactions
                if self.areStarsReactionsEnabled {
                    if let item = component.initialContent.availableReactions?.reactions.first(where: { $0.value == .stars }) {
                        enabledReactionsValue.insert(EmojiComponentReactionItem(reaction: item.value, file: item.selectAnimation), at: 0)
                    }
                }
                
                enabledReactions = enabledReactionsValue
                self.enabledReactions = enabledReactions
                self.availableReactions = component.initialContent.availableReactions
                self.isEnabled = component.initialContent.isEnabled
                self.appliedReactionSettings = component.initialContent.reactionSettings.flatMap { reactionSettings in
                    return PeerReactionSettings(
                        allowedReactions: reactionSettings.allowedReactions,
                        maxReactionCount: reactionSettings.maxReactionCount == 11 ? nil : reactionSettings.maxReactionCount,
                        starsAllowed: reactionSettings.starsAllowed
                    )
                }
                self.allowedReactionCount = (component.initialContent.reactionSettings?.maxReactionCount).flatMap(Int.init) ?? 11
            }
            var caretPosition = self.caretPosition ?? enabledReactions.count
            caretPosition = max(0, min(enabledReactions.count, caretPosition))
            self.caretPosition = caretPosition
            
            if self.emojiContentDisposable == nil {
                let emojiContent = EmojiPagerContentComponent.emojiInputData(
                    context: component.context,
                    animationCache: component.context.animationCache,
                    animationRenderer: component.context.animationRenderer,
                    isStandalone: false,
                    subject: .reactionList,
                    hasTrending: false,
                    topReactionItems: [],
                    areUnicodeEmojiEnabled: false,
                    areCustomEmojiEnabled: true,
                    chatPeerId: nil,
                    selectedItems: Set(),
                    backgroundIconColor: nil,
                    hasSearch: true,
                    forceHasPremium: true
                )
                self.emojiContentDisposable = (combineLatest(queue: .mainQueue(),
                    emojiContent,
                    self.emojiSearchState.get()
                )
                |> deliverOnMainQueue).start(next: { [weak self] emojiContent, emojiSearchState in
                    guard let self else {
                        return
                    }
                    guard let environment = self.environment else {
                        return
                    }
                    
                    var emojiContent = emojiContent
                    if let emojiSearchResult = emojiSearchState.result {
                        var emptySearchResults: EmojiPagerContentComponent.EmptySearchResults?
                        if !emojiSearchResult.groups.contains(where: { !$0.items.isEmpty || $0.fillWithLoadingPlaceholders }) {
                            if self.stableEmptyResultEmoji == nil {
                                self.stableEmptyResultEmoji = self.emptyResultEmojis.randomElement()
                            }
                            emptySearchResults = EmojiPagerContentComponent.EmptySearchResults(
                                text: environment.strings.EmojiSearch_SearchReactionsEmptyResult,
                                iconFile: self.stableEmptyResultEmoji
                            )
                        } else {
                            self.stableEmptyResultEmoji = nil
                        }
                        emojiContent = emojiContent.withUpdatedItemGroups(panelItemGroups: emojiContent.panelItemGroups, contentItemGroups: emojiSearchResult.groups, itemContentUniqueId: EmojiPagerContentComponent.ContentId(id: emojiSearchResult.id, version: emojiSearchResult.version), emptySearchResults: emptySearchResults, searchState: emojiSearchState.isSearching ? .searching : .active)
                    } else {
                        self.stableEmptyResultEmoji = nil
                        
                        if emojiSearchState.isSearching {
                            emojiContent = emojiContent.withUpdatedItemGroups(panelItemGroups: emojiContent.panelItemGroups, contentItemGroups: emojiContent.contentItemGroups, itemContentUniqueId: emojiContent.itemContentUniqueId, emptySearchResults: emojiContent.emptySearchResults, searchState: .searching)
                        }
                    }
                    
                    emojiContent.inputInteractionHolder.inputInteraction = EmojiPagerContentComponent.InputInteraction(
                        performItemAction: { [weak self] _, item, _, _, _, _ in
                            guard let self, var enabledReactions = self.enabledReactions else {
                                return
                            }
                            if self.isApplyingSettings {
                                return
                            }
                            guard let itemFile = item.itemFile else {
                                return
                            }
                            
                            AudioServicesPlaySystemSound(0x450)
                            
                            if let index = enabledReactions.firstIndex(where: { $0.file.fileId.id == itemFile.fileId.id }) {
                                enabledReactions.remove(at: index)
                                if let caretPosition = self.caretPosition, caretPosition > index {
                                    self.caretPosition = max(0, caretPosition - 1)
                                }
                            } else {
                                if enabledReactions.count >= 100 {
                                    let presentationData = component.context.sharedContext.currentPresentationData.with { $0 }
                                    
                                    var animateAsReplacement = false
                                    if let currentUndoController = self.currentUndoController {
                                        currentUndoController.dismiss()
                                        animateAsReplacement = true
                                    }
                                    
                                    let undoController = UndoOverlayController(presentationData: presentationData, content: .info(title: nil, text: presentationData.strings.ChannelReactions_ToastMaxReactionsReached, timeout: nil, customUndoText: nil), elevatedLayout: false, position: .bottom, animateInAsReplacement: animateAsReplacement, action: { _ in return false })
                                    self.currentUndoController = undoController
                                    self.environment?.controller()?.present(undoController, in: .current)
                                    return
                                }
                                
                                let reaction: MessageReaction.Reaction
                                if let availableReactions = self.availableReactions, let reactionItem = availableReactions.reactions.filter({ $0.isEnabled }).first(where: { $0.selectAnimation.fileId.id == itemFile.fileId.id }) {
                                    reaction = reactionItem.value
                                } else {
                                    reaction = .custom(itemFile.fileId.id)
                                    
                                    if let boostStatus = self.boostStatus {
                                        let enabledCustomReactions = enabledReactions.filter({ item in
                                            switch item.reaction {
                                            case .custom:
                                                return true
                                            case .builtin:
                                                return false
                                            case .stars:
                                                return false
                                            }
                                        })
                                        
                                        let nextCustomReactionCount = enabledCustomReactions.count + 1
                                        if nextCustomReactionCount > boostStatus.level {
                                            let presentationData = component.context.sharedContext.currentPresentationData.with { $0 }
                                            
                                            var animateAsReplacement = false
                                            if let currentUndoController = self.currentUndoController {
                                                currentUndoController.dismiss()
                                                animateAsReplacement = true
                                            }
                                            
                                            let text = presentationData.strings.ChannelReactions_ToastLevelBoostRequiredTemplate(presentationData.strings.ChannelReactions_ToastLevelBoostRequiredTemplateLevel(Int32(nextCustomReactionCount)), presentationData.strings.ChannelReactions_ToastLevelBoostRequiredTemplateEmojiCount(Int32(nextCustomReactionCount))).string
                                            let undoController = UndoOverlayController(presentationData: presentationData, content: .customEmoji(context: component.context, file: itemFile._parse(), loop: false, title: nil, text: text, undoText: nil, customAction: nil), elevatedLayout: false, position: .bottom, animateInAsReplacement: animateAsReplacement, action: { _ in return false })
                                            self.currentUndoController = undoController
                                            self.environment?.controller()?.present(undoController, in: .current)
                                        }
                                    }
                                }
                                let item = EmojiComponentReactionItem(reaction: reaction, file: itemFile)
                                
                                if let caretPosition = self.caretPosition, caretPosition < enabledReactions.count {
                                    enabledReactions.insert(item, at: caretPosition)
                                    self.caretPosition = caretPosition + 1
                                } else {
                                    enabledReactions.append(item)
                                    self.caretPosition = enabledReactions.count
                                }
                                self.recenterOnCaret = true
                            }
                            self.enabledReactions = enabledReactions
                            if !self.isUpdating {
                                self.state?.updated(transition: .spring(duration: 0.25))
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
                        requestUpdate: { _ in
                        },
                        updateSearchQuery: { [weak self] query in
                            guard let self, let component = self.component else {
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
                                    let context = component.context
                                    let isEmojiOnly = !"".isEmpty
                                    
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
                                    
                                    let resultSignal: Signal<[EmojiPagerContentComponent.ItemGroup], NoError>
                                    do {
                                        let remotePacksSignal: Signal<(sets: FoundStickerSets, isFinalResult: Bool), NoError> = .single((FoundStickerSets(), false))
                                        |> then(
                                            context.engine.stickers.searchEmojiSetsRemotely(query: query) |> map {
                                                ($0, true)
                                            }
                                        )
                                        let localPacksSignal: Signal<FoundStickerSets, NoError> = context.engine.stickers.searchEmojiSets(query: query)
                                        
                                        resultSignal = signal
                                        |> mapToSignal { keywords -> Signal<[EmojiPagerContentComponent.ItemGroup], NoError> in
                                            var allEmoticons: [String: String] = [:]
                                            for keyword in keywords {
                                                for emoticon in keyword.emoticons {
                                                    allEmoticons[emoticon] = keyword.keyword
                                                }
                                            }
                                            if isEmojiOnly {
                                                var items: [EmojiPagerContentComponent.Item] = []
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
                                                var resultGroups: [EmojiPagerContentComponent.ItemGroup] = []
                                                resultGroups.append(EmojiPagerContentComponent.ItemGroup(
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
                                                ))
                                                return .single(resultGroups)
                                            } else {
                                                let remoteSignal = context.engine.stickers.searchEmoji(query: query, emoticon: Array(allEmoticons.keys), inputLanguageCode: languageCode)
                                                
                                                return combineLatest(
                                                    context.account.postbox.itemCollectionsView(orderedItemListCollectionIds: [], namespaces: [Namespaces.ItemCollection.CloudEmojiPacks], aroundIndex: nil, count: 10000000) |> take(1),
                                                    context.engine.stickers.availableReactions() |> take(1),
                                                    hasPremium |> take(1),
                                                    remotePacksSignal,
                                                    remoteSignal,
                                                    localPacksSignal
                                                )
                                                |> map { view, availableReactions, hasPremium, foundPacks, foundEmoji, foundLocalPacks -> [EmojiPagerContentComponent.ItemGroup] in
                                                    var result: [(String, TelegramMediaFile.Accessor?, String)] = []
                                                    
                                                    var allEmoticons: [String: String] = [:]
                                                    for keyword in keywords {
                                                        for emoticon in keyword.emoticons {
                                                            allEmoticons[emoticon] = keyword.keyword
                                                        }
                                                    }
                                                    
                                                    for itemFile in foundEmoji.items {
                                                        for attribute in itemFile.attributes {
                                                            switch attribute {
                                                            case let .CustomEmoji(_, _, alt, _):
                                                                if !alt.isEmpty, let keyword = allEmoticons[alt] {
                                                                    result.append((alt, TelegramMediaFile.Accessor(itemFile), keyword))
                                                                } else if alt == query {
                                                                    result.append((alt, TelegramMediaFile.Accessor(itemFile), alt))
                                                                }
                                                            default:
                                                                break
                                                            }
                                                        }
                                                    }
                                                    
                                                    for entry in view.entries {
                                                        guard let item = entry.item as? StickerPackItem else {
                                                            continue
                                                        }
                                                        if !item.file.isPremiumEmoji {
                                                            if let alt = item.file.customEmojiAlt {
                                                                if !alt.isEmpty, let keyword = allEmoticons[alt] {
                                                                    result.append((alt, item.file, keyword))
                                                                } else if alt == query {
                                                                    result.append((alt, item.file, alt))
                                                                }
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
                                                                icon: (!hasPremium && itemFile.isPremiumEmoji) ? .locked : .none,
                                                                tintMode: animationData.isTemplate ? .primary : .none
                                                            )
                                                            items.append(item)
                                                        }
                                                    }
                                                    
                                                    var resultGroups: [EmojiPagerContentComponent.ItemGroup] = []
                                                    resultGroups.append(EmojiPagerContentComponent.ItemGroup(
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
                                                    ))
                                                    
                                                    var combinedSets: FoundStickerSets
                                                    combinedSets = foundLocalPacks
                                                    combinedSets = combinedSets.merge(with: foundPacks.sets)
                                                    
                                                    var existingCollectionIds = Set<ItemCollectionId>()
                                                    for (collectionId, info, _, _) in combinedSets.infos {
                                                        if !existingCollectionIds.contains(collectionId) {
                                                            existingCollectionIds.insert(collectionId)
                                                        } else {
                                                            continue
                                                        }
                                                        
                                                        if let info = info as? StickerPackCollectionInfo {
                                                            var topItems: [StickerPackItem] = []
                                                            for e in combinedSets.entries {
                                                                if let item = e.item as? StickerPackItem {
                                                                    if e.index.collectionId == collectionId {
                                                                        topItems.append(item)
                                                                    }
                                                                }
                                                            }
                                                            
                                                            var groupItems: [EmojiPagerContentComponent.Item] = []
                                                            for item in topItems {
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
                                                                    icon: (!hasPremium && item.file.isPremiumEmoji) ? .locked : .none,
                                                                    tintMode: tintMode
                                                                )
                                                                
                                                                groupItems.append(resultItem)
                                                            }
                                                            
                                                            resultGroups.append(EmojiPagerContentComponent.ItemGroup(
                                                                supergroupId: AnyHashable(info.id),
                                                                groupId: AnyHashable(info.id),
                                                                title: info.title,
                                                                subtitle: nil,
                                                                badge: nil,
                                                                actionButtonTitle: nil,
                                                                isFeatured: false,
                                                                isPremiumLocked: false,
                                                                isEmbedded: false,
                                                                hasClear: false,
                                                                hasEdit: false,
                                                                collapsedLineCount: 3,
                                                                displayPremiumBadges: false,
                                                                headerItem: nil,
                                                                fillWithLoadingPlaceholders: false,
                                                                items: groupItems
                                                            ))
                                                        }
                                                    }
                                                    return resultGroups
                                                }
                                            }
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
                                let resultSignal: Signal<(items: [EmojiPagerContentComponent.ItemGroup], isFinalResult: Bool), NoError>
                                do {
                                    resultSignal = component.context.engine.stickers.searchEmoji(category: value)
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
                                        //self.emojiSearchStateValue.isSearching = true
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
                    
                    self.emojiContent = emojiContent
                    
                    if !self.isUpdating {
                        self.state?.updated(transition: .immediate)
                    }
                })
            }
            
            if self.boostStatusDisposable == nil {
                self.boostStatusDisposable = (component.context.engine.peers.getChannelBoostStatus(peerId: component.peerId)
                |> deliverOnMainQueue).start(next: { [weak self] boostStatus in
                    guard let self else {
                        return
                    }
                    self.boostStatus = boostStatus
                    if !self.isUpdating {
                        self.state?.updated(transition: .immediate)
                    }
                })
            }
            
            if themeUpdated {
                self.backgroundColor = environment.theme.list.blocksBackgroundColor
            }
            
            var contentHeight: CGFloat = 0.0
            contentHeight += environment.navigationHeight
            contentHeight += topInset
            
            let switchSize = self.switchItem.update(
                transition: transition,
                component: AnyComponent(ListSwitchItemComponent(
                    theme: environment.theme,
                    title: environment.strings.PeerInfo_AllowedReactions_AllowAllText,
                    value: self.isEnabled,
                    valueUpdated: { [weak self] value in
                        guard let self else {
                            return
                        }
                        if self.isEnabled != value {
                            self.isEnabled = value
                            
                            if self.isEnabled {
                                if var enabledReactions = self.enabledReactions, enabledReactions.isEmpty {
                                    if let availableReactions = self.availableReactions {
                                        for reactionItem in availableReactions.reactions.filter({ $0.isEnabled }) {
                                            enabledReactions.append(EmojiComponentReactionItem(reaction: reactionItem.value, file: reactionItem.selectAnimation))
                                        }
                                    }
                                    if self.areStarsReactionsEnabled {
                                        if let item = component.initialContent.availableReactions?.reactions.first(where: { $0.value == .stars }) {
                                            enabledReactions.insert(EmojiComponentReactionItem(reaction: item.value, file: item.selectAnimation), at: 0)
                                        }
                                    }
                                    self.enabledReactions = enabledReactions
                                    self.caretPosition = enabledReactions.count
                                }
                            } else {
                                self.displayInput = false
                            }
                            
                            self.state?.updated(transition: .immediate)
                        }
                    }
                )),
                environment: {},
                containerSize: CGSize(width: availableSize.width - sideInset * 2.0, height: .greatestFiniteMagnitude)
            )
            let switchFrame = CGRect(origin: CGPoint(x: sideInset, y: contentHeight), size: switchSize)
            if let switchView = self.switchItem.view {
                if switchView.superview == nil {
                    self.scrollView.addSubview(switchView)
                }
                transition.setFrame(view: switchView, frame: switchFrame)
            }
            contentHeight += switchSize.height
            contentHeight += 7.0
            
            let switchInfoTextSize = self.switchInfoText.update(
                transition: .immediate,
                component: AnyComponent(MultilineTextComponent(
                    text: .plain(NSAttributedString(
                        string: environment.strings.ChannelReactions_GeneralInfoLabel,
                        font: Font.regular(13.0),
                        textColor: environment.theme.list.freeTextColor
                    )),
                    maximumNumberOfLines: 0
                )),
                environment: {},
                containerSize: CGSize(width: availableSize.width - sideInset * 2.0 - textSideInset * 2.0, height: .greatestFiniteMagnitude)
            )
            let switchInfoTextFrame = CGRect(origin: CGPoint(x: sideInset + textSideInset, y: contentHeight), size: switchInfoTextSize)
            if let switchInfoTextView = self.switchInfoText.view {
                if switchInfoTextView.superview == nil {
                    switchInfoTextView.layer.anchorPoint = CGPoint()
                    self.scrollView.addSubview(switchInfoTextView)
                }
                transition.setPosition(view: switchInfoTextView, position: switchInfoTextFrame.origin)
                switchInfoTextView.bounds = CGRect(origin: CGPoint(), size: switchInfoTextFrame.size)
            }
            contentHeight += switchInfoTextSize.height
            contentHeight += 37.0
            
            if self.isEnabled {
                var animateIn = false
                
                let reactionsTitleText: ComponentView<Empty>
                if let current = self.reactionsTitleText {
                    reactionsTitleText = current
                } else {
                    reactionsTitleText = ComponentView()
                    self.reactionsTitleText = reactionsTitleText
                    animateIn = true
                }
                
                let reactionsTitleTextSize = reactionsTitleText.update(
                    transition: .immediate,
                    component: AnyComponent(MultilineTextComponent(
                        text: .plain(NSAttributedString(
                            string: environment.strings.ChannelReactions_ReactionsSectionTitle,
                            font: Font.regular(13.0),
                            textColor: environment.theme.list.freeTextColor
                        )),
                        maximumNumberOfLines: 0
                    )),
                    environment: {},
                    containerSize: CGSize(width: availableSize.width - sideInset * 2.0 - textSideInset * 2.0, height: .greatestFiniteMagnitude)
                )
                let reactionsTitleTextFrame = CGRect(origin: CGPoint(x: sideInset + textSideInset, y: contentHeight), size: reactionsTitleTextSize)
                if let reactionsTitleTextView = reactionsTitleText.view {
                    if reactionsTitleTextView.superview == nil {
                        reactionsTitleTextView.layer.anchorPoint = CGPoint()
                        self.scrollView.addSubview(reactionsTitleTextView)
                    }
                    
                    if animateIn {
                        reactionsTitleTextView.frame = reactionsTitleTextFrame
                        if !transition.animation.isImmediate {
                            reactionsTitleTextView.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.2)
                        }
                    } else {
                        transition.setPosition(view: reactionsTitleTextView, position: reactionsTitleTextFrame.origin)
                        reactionsTitleTextView.bounds = CGRect(origin: CGPoint(), size: reactionsTitleTextFrame.size)
                    }
                }
                contentHeight += reactionsTitleTextSize.height
                contentHeight += 6.0
                
                let reactionInput: ComponentView<Empty>
                if let current = self.reactionInput {
                    reactionInput = current
                } else {
                    reactionInput = ComponentView()
                    self.reactionInput = reactionInput
                }
                
                let reactionInputSize = reactionInput.update(
                    transition: animateIn ? .immediate : transition,
                    component: AnyComponent(EmojiListInputComponent(
                        context: component.context,
                        theme: environment.theme,
                        placeholder: environment.strings.ChannelReactions_InputPlaceholder,
                        reactionItems: enabledReactions,
                        isInputActive: self.displayInput,
                        caretPosition: caretPosition,
                        activateInput: { [weak self] in
                            guard let self else {
                                return
                            }
                            if self.emojiContent != nil && !self.displayInput {
                                self.displayInput = true
                                self.recenterOnCaret = true
                                self.state?.updated(transition: .spring(duration: 0.5))
                            }
                        },
                        setCaretPosition: { [weak self] value in
                            guard let self else {
                                return
                            }
                            if self.caretPosition != value {
                                self.caretPosition = value
                                self.state?.updated(transition: .immediate)
                            }
                        }
                    )),
                    environment: {},
                    containerSize: CGSize(width: availableSize.width - sideInset * 2.0, height: .greatestFiniteMagnitude)
                )
                let reactionInputFrame = CGRect(origin: CGPoint(x: sideInset, y: contentHeight), size: reactionInputSize)
                if let reactionInputView = reactionInput.view {
                    if reactionInputView.superview == nil {
                        self.scrollView.addSubview(reactionInputView)
                    }
                    if animateIn {
                        reactionInputView.frame = reactionInputFrame
                        if !transition.animation.isImmediate {
                            reactionInputView.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.2)
                        }
                    } else {
                        transition.setFrame(view: reactionInputView, frame: reactionInputFrame)
                    }
                }
                contentHeight += reactionInputSize.height
                contentHeight += 7.0
                
                let reactionsInfoText: ComponentView<Empty>
                if let current = self.reactionsInfoText {
                    reactionsInfoText = current
                } else {
                    reactionsInfoText = ComponentView()
                    self.reactionsInfoText = reactionsInfoText
                }
                
                let body = MarkdownAttributeSet(font: UIFont.systemFont(ofSize: 13.0), textColor: environment.theme.list.freeTextColor)
                let link = MarkdownAttributeSet(font: UIFont.systemFont(ofSize: 13.0), textColor: environment.theme.list.itemAccentColor, additionalAttributes: [:])
                let attributes = MarkdownAttributes(body: body, bold: body, link: link, linkAttribute: { contents in
                    return (TelegramTextAttributes.URL, contents)
                })
                let reactionsInfoTextSize = reactionsInfoText.update(
                    transition: .immediate,
                    component: AnyComponent(MultilineTextComponent(
                        text: .markdown(text: environment.strings.ChannelReactions_ReactionsInfoLabel, attributes: attributes),
                        maximumNumberOfLines: 0,
                        highlightAction: { attributes in
                            if let _ = attributes[NSAttributedString.Key(rawValue: TelegramTextAttributes.URL)] {
                                return NSAttributedString.Key(rawValue: TelegramTextAttributes.URL)
                            } else {
                                return nil
                            }
                        },
                        tapAction: { [weak self] attributes, _ in
                            guard let self, let component = self.component, attributes[NSAttributedString.Key(rawValue: TelegramTextAttributes.URL)] != nil else {
                                return
                            }
                            self.resolveStickersBotDisposable?.dispose()
                            self.resolveStickersBotDisposable = (component.context.engine.peers.resolvePeerByName(name: "stickers", referrer: nil)
                            |> mapToSignal { result -> Signal<EnginePeer?, NoError> in
                                guard case let .result(result) = result else {
                                    return .complete()
                                }
                                return .single(result)
                            }
                            |> deliverOnMainQueue).start(next: { [weak self] peer in
                                guard let self, let component = self.component, let peer else {
                                    return
                                }
                                guard let navigationController = self.environment?.controller()?.navigationController as? NavigationController else {
                                    return
                                }
                                component.context.sharedContext.navigateToChatController(NavigateToChatControllerParams(
                                    navigationController: navigationController,
                                    context: component.context,
                                    chatLocation: .peer(peer),
                                    keepStack: .always
                                ))
                            })
                        }
                    )),
                    environment: {},
                    containerSize: CGSize(width: availableSize.width - sideInset * 2.0 - textSideInset * 2.0, height: .greatestFiniteMagnitude)
                )
                let reactionsInfoTextFrame = CGRect(origin: CGPoint(x: sideInset + textSideInset, y: contentHeight), size: reactionsInfoTextSize)
                if let reactionsInfoTextView = reactionsInfoText.view {
                    if reactionsInfoTextView.superview == nil {
                        reactionsInfoTextView.layer.anchorPoint = CGPoint()
                        self.scrollView.addSubview(reactionsInfoTextView)
                    }
                    if animateIn {
                        reactionsInfoTextView.frame = reactionsInfoTextFrame
                        if !transition.animation.isImmediate {
                            reactionsInfoTextView.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.2)
                        }
                    } else {
                        transition.setPosition(view: reactionsInfoTextView, position: reactionsInfoTextFrame.origin)
                        reactionsInfoTextView.bounds = CGRect(origin: CGPoint(), size: reactionsInfoTextFrame.size)
                    }
                }
                contentHeight += reactionsInfoTextSize.height
                contentHeight += 6.0
                
                contentHeight += 32.0
                
                let reactionCountSection: ComponentView<Empty>
                if let current = self.reactionCountSection {
                    reactionCountSection = current
                } else {
                    reactionCountSection = ComponentView()
                    self.reactionCountSection = reactionCountSection
                }
                
                let reactionCountValueList = (1 ... 11).map { i -> String in
                    return "\(i)"
                }
                let sliderTitle: String = environment.strings.PeerInfo_AllowedReactions_MaxCountValue(Int32(self.allowedReactionCount))
                let reactionCountSectionSize = reactionCountSection.update(
                    transition: transition,
                    component: AnyComponent(ListSectionComponent(
                        theme: environment.theme,
                        header: AnyComponent(MultilineTextComponent(
                            text: .plain(NSAttributedString(
                                string: environment.strings.PeerInfo_AllowedReactions_MaxCountSectionTitle,
                                font: Font.regular(13.0),
                                textColor: environment.theme.list.freeTextColor
                            )),
                            maximumNumberOfLines: 0
                        )),
                        footer: AnyComponent(MultilineTextComponent(
                            text: .plain(NSAttributedString(
                                string: environment.strings.PeerInfo_AllowedReactions_MaxCountSectionFooter,
                                font: Font.regular(13.0),
                                textColor: environment.theme.list.freeTextColor
                            )),
                            maximumNumberOfLines: 0
                        )),
                        items: [
                            AnyComponentWithIdentity(id: 0, component: AnyComponent(ListItemSliderSelectorComponent(
                                theme: environment.theme,
                                content: .discrete(ListItemSliderSelectorComponent.Discrete(
                                    values: reactionCountValueList.map { item in
                                        return item
                                    },
                                    markPositions: false,
                                    selectedIndex: max(0, min(reactionCountValueList.count - 1, self.allowedReactionCount - 1)),
                                    title: sliderTitle,
                                    selectedIndexUpdated: { [weak self] index in
                                        guard let self else {
                                            return
                                        }
                                        let index = max(1, min(reactionCountValueList.count, index + 1))
                                        self.allowedReactionCount = index
                                        self.state?.updated(transition: .immediate)
                                    }
                                ))
                            )))
                        ],
                        displaySeparators: false
                    )),
                    environment: {},
                    containerSize: CGSize(width: availableSize.width - sideInset * 2.0, height: 10000.0)
                )
                let reactionCountSectionFrame = CGRect(origin: CGPoint(x: sideInset, y: contentHeight), size: reactionCountSectionSize)
                if let reactionCountSectionView = reactionCountSection.view {
                    if reactionCountSectionView.superview == nil {
                        self.scrollView.addSubview(reactionCountSectionView)
                    }
                    if animateIn {
                        reactionCountSectionView.frame = reactionCountSectionFrame
                        if !transition.animation.isImmediate {
                            reactionCountSectionView.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.2)
                        }
                    } else {
                        transition.setFrame(view: reactionCountSectionView, frame: reactionCountSectionFrame)
                    }
                }
                contentHeight += reactionCountSectionSize.height
                
                if component.initialContent.isStarReactionAvailable {
                    contentHeight += 32.0
                    
                    let paidReactionsSection: ComponentView<Empty>
                    if let current = self.paidReactionsSection {
                        paidReactionsSection = current
                    } else {
                        paidReactionsSection = ComponentView()
                        self.paidReactionsSection = paidReactionsSection
                    }
                    
                    let parsedString = parseMarkdownIntoAttributedString(environment.strings.PeerInfo_AllowedReactions_StarReactionsFooter, attributes: MarkdownAttributes(
                        body: MarkdownAttributeSet(font: Font.regular(13.0), textColor: environment.theme.list.freeTextColor),
                        bold: MarkdownAttributeSet(font: Font.semibold(13.0), textColor: environment.theme.list.freeTextColor),
                        link: MarkdownAttributeSet(font: Font.regular(13.0), textColor: environment.theme.list.itemAccentColor),
                        linkAttribute: { url in
                            return ("URL", url)
                        }))
                    
                    let paidReactionsFooterText = NSMutableAttributedString(attributedString: parsedString)
                    
                    if self.cachedChevronImage == nil || self.cachedChevronImage?.1 !== environment.theme {
                        self.cachedChevronImage = (generateTintedImage(image: UIImage(bundleImageName: "Item List/InlineTextRightArrow"), color: environment.theme.list.itemAccentColor)!, environment.theme)
                    }
                    if let range = paidReactionsFooterText.string.range(of: ">"), let chevronImage = self.cachedChevronImage?.0 {
                        paidReactionsFooterText.addAttribute(.attachment, value: chevronImage, range: NSRange(range, in: paidReactionsFooterText.string))
                    }
                    
                    let paidReactionsSectionSize = paidReactionsSection.update(
                        transition: transition,
                        component: AnyComponent(ListSectionComponent(
                            theme: environment.theme,
                            header: nil,
                            footer: AnyComponent(MultilineTextComponent(
                                text: .plain(paidReactionsFooterText),
                                maximumNumberOfLines: 0,
                                highlightColor: environment.theme.list.itemAccentColor.withAlphaComponent(0.1),
                                highlightInset: UIEdgeInsets(top: 0.0, left: 0.0, bottom: 0.0, right: -8.0),
                                highlightAction: { attributes in
                                    if let _ = attributes[NSAttributedString.Key(rawValue: "URL")] {
                                        return NSAttributedString.Key(rawValue: "URL")
                                    } else {
                                        return nil
                                    }
                                }, tapAction: { [weak self] attributes, _ in
                                    guard let self, let component = self.component else {
                                        return
                                    }
                                    if let url = attributes[NSAttributedString.Key(rawValue: "URL")] as? String {
                                        component.context.sharedContext.applicationBindings.openUrl(url)
                                    }
                                }
                            )),
                            items: [
                                AnyComponentWithIdentity(id: 0, component: AnyComponent(ListSwitchItemComponent(
                                    theme: environment.theme,
                                    title: environment.strings.PeerInfo_AllowedReactions_StarReactions,
                                    value: self.areStarsReactionsEnabled,
                                    valueUpdated: { [weak self] value in
                                        guard let self, let component = self.component else {
                                            return
                                        }
                                        self.areStarsReactionsEnabled = value
                                        
                                        var enabledReactions = self.enabledReactions ?? []
                                        if self.areStarsReactionsEnabled {
                                            if let item = component.initialContent.availableReactions?.reactions.first(where: { $0.value == .stars }) {
                                                enabledReactions.insert(EmojiComponentReactionItem(reaction: item.value, file: item.selectAnimation), at: 0)
                                                if let caretPosition = self.caretPosition {
                                                    self.caretPosition = min(enabledReactions.count, caretPosition + 1)
                                                }
                                            }
                                        } else {
                                            if let index = enabledReactions.firstIndex(where: { $0.reaction == .stars }) {
                                                enabledReactions.remove(at: index)
                                                if let caretPosition = self.caretPosition, caretPosition > index {
                                                    self.caretPosition = max(0, caretPosition - 1)
                                                }
                                            }
                                        }
                                        
                                        self.enabledReactions = enabledReactions
                                        
                                        if !self.isUpdating {
                                            self.state?.updated(transition: .spring(duration: 0.25))
                                        }
                                    }
                                )))
                            ]
                        )),
                        environment: {},
                        containerSize: CGSize(width: availableSize.width - sideInset * 2.0, height: 10000.0)
                    )
                    let paidReactionsSectionFrame = CGRect(origin: CGPoint(x: sideInset, y: contentHeight), size: paidReactionsSectionSize)
                    if let paidReactionsSectionView = paidReactionsSection.view {
                        if paidReactionsSectionView.superview == nil {
                            self.scrollView.addSubview(paidReactionsSectionView)
                        }
                        if animateIn {
                            paidReactionsSectionView.frame = paidReactionsSectionFrame
                            if !transition.animation.isImmediate {
                                paidReactionsSectionView.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.2)
                            }
                        } else {
                            transition.setFrame(view: paidReactionsSectionView, frame: paidReactionsSectionFrame)
                        }
                    }
                    contentHeight += paidReactionsSectionSize.height
                    contentHeight += 12.0
                } else {
                    contentHeight += 12.0
                    
                    if let paidReactionsSection = self.paidReactionsSection {
                        self.paidReactionsSection = nil
                        if let paidReactionsSectionView = paidReactionsSection.view {
                            if !transition.animation.isImmediate {
                                paidReactionsSectionView.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.2, removeOnCompletion: false, completion: { [weak paidReactionsSectionView] _ in
                                    paidReactionsSectionView?.removeFromSuperview()
                                })
                            } else {
                                paidReactionsSectionView.removeFromSuperview()
                            }
                        }
                    }
                }
            } else {
                if let reactionsTitleText = self.reactionsTitleText {
                    self.reactionsTitleText = nil
                    if let reactionsTitleTextView = reactionsTitleText.view {
                        if !transition.animation.isImmediate {
                            reactionsTitleTextView.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.2, removeOnCompletion: false, completion: { [weak reactionsTitleTextView] _ in
                                reactionsTitleTextView?.removeFromSuperview()
                            })
                        } else {
                            reactionsTitleTextView.removeFromSuperview()
                        }
                    }
                }
                
                if let reactionInput = self.reactionInput {
                    self.reactionInput = nil
                    if let reactionInputView = reactionInput.view {
                        if !transition.animation.isImmediate {
                            reactionInputView.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.2, removeOnCompletion: false, completion: { [weak reactionInputView] _ in
                                reactionInputView?.removeFromSuperview()
                            })
                        } else {
                            reactionInputView.removeFromSuperview()
                        }
                    }
                }
                
                if let reactionsInfoText = self.reactionsInfoText {
                    self.reactionsInfoText = nil
                    if let reactionsInfoTextView = reactionsInfoText.view {
                        if !transition.animation.isImmediate {
                            reactionsInfoTextView.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.2, removeOnCompletion: false, completion: { [weak reactionsInfoTextView] _ in
                                reactionsInfoTextView?.removeFromSuperview()
                            })
                        } else {
                            reactionsInfoTextView.removeFromSuperview()
                        }
                    }
                }
                
                if let reactionCountSection = self.reactionCountSection {
                    self.reactionCountSection = nil
                    if let reactionCountSectionView = reactionCountSection.view {
                        if !transition.animation.isImmediate {
                            reactionCountSectionView.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.2, removeOnCompletion: false, completion: { [weak reactionCountSectionView] _ in
                                reactionCountSectionView?.removeFromSuperview()
                            })
                        } else {
                            reactionCountSectionView.removeFromSuperview()
                        }
                    }
                }
                
                if let paidReactionsSection = self.paidReactionsSection {
                    self.paidReactionsSection = nil
                    if let paidReactionsSectionView = paidReactionsSection.view {
                        if !transition.animation.isImmediate {
                            paidReactionsSectionView.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.2, removeOnCompletion: false, completion: { [weak paidReactionsSectionView] _ in
                                paidReactionsSectionView?.removeFromSuperview()
                            })
                        } else {
                            paidReactionsSectionView.removeFromSuperview()
                        }
                    }
                }
            }
            
            var buttonContents: [AnyComponentWithIdentity<Empty>] = []
            buttonContents.append(AnyComponentWithIdentity(id: AnyHashable(0 as Int), component: AnyComponent(
                Text(text: environment.strings.ChannelReactions_SaveAction, font: Font.semibold(17.0), color: environment.theme.list.itemCheckColors.foregroundColor)
            )))
            
            let customReactionCount = self.isEnabled ? enabledReactions.filter({ item in
                switch item.reaction {
                case .custom:
                    return true
                case .builtin:
                    return false
                case .stars:
                    return false
                }
            }).count : 0
            
            if let boostStatus = self.boostStatus, customReactionCount > boostStatus.level {
                buttonContents.append(AnyComponentWithIdentity(id: AnyHashable(1 as Int), component: AnyComponent(PremiumLockButtonSubtitleComponent(
                    count: customReactionCount,
                    theme: environment.theme,
                    strings: environment.strings
                ))))
            }
            
            let buttonSize = self.actionButton.update(
                transition: transition,
                component: AnyComponent(ButtonComponent(
                    background: ButtonComponent.Background(
                        color: environment.theme.list.itemCheckColors.fillColor,
                        foreground: environment.theme.list.itemCheckColors.foregroundColor,
                        pressedColor: environment.theme.list.itemCheckColors.fillColor.withMultipliedAlpha(0.8)
                    ),
                    content: AnyComponentWithIdentity(id: AnyHashable(0 as Int), component: AnyComponent(
                        VStack(buttonContents, spacing: 3.0)
                    )),
                    isEnabled: true,
                    tintWhenDisabled: false,
                    displaysProgress: self.isApplyingSettings,
                    action: { [weak self] in
                        guard let self else {
                            return
                        }
                        self.applySettings(standalone: false)
                    }
                )),
                environment: {},
                containerSize: CGSize(width: availableSize.width - sideInset * 2.0, height: 50.0)
            )
            contentHeight += buttonSize.height
            
            var inputHeight: CGFloat = 0.0
            if self.displayInput, let emojiContent = self.emojiContent {
                let reactionSelectionControl: ComponentView<Empty>
                var animateIn = false
                if let current = self.reactionSelectionControl {
                    reactionSelectionControl = current
                } else {
                    animateIn = true
                    reactionSelectionControl = ComponentView()
                    self.reactionSelectionControl = reactionSelectionControl
                    reactionSelectionControl.parentState = state
                }
                let reactionSelectionControlSize = reactionSelectionControl.update(
                    transition: animateIn ? .immediate : transition,
                    component: AnyComponent(EmojiSelectionComponent(
                        theme: environment.theme,
                        strings: environment.strings,
                        sideInset: environment.safeInsets.left,
                        bottomInset: environment.safeInsets.bottom,
                        deviceMetrics: environment.deviceMetrics,
                        emojiContent: emojiContent.withSelectedItems(Set(enabledReactions.map(\.file.fileId))),
                        stickerContent: nil,
                        backgroundIconColor: nil,
                        backgroundColor: environment.theme.list.itemBlocksBackgroundColor,
                        separatorColor: environment.theme.list.itemBlocksSeparatorColor,
                        backspace: enabledReactions.isEmpty ? nil : { [weak self] in
                            guard let self, var enabledReactions = self.enabledReactions, !enabledReactions.isEmpty else {
                                return
                            }
                            if let caretPosition = self.caretPosition, caretPosition < enabledReactions.count {
                                if caretPosition > 0 {
                                    enabledReactions.remove(at: caretPosition - 1)
                                    self.caretPosition = caretPosition - 1
                                    self.recenterOnCaret = true
                                }
                            } else {
                                enabledReactions.removeLast()
                                self.caretPosition = enabledReactions.count
                                self.recenterOnCaret = true
                            }
                            self.enabledReactions = enabledReactions
                            
                            if !enabledReactions.contains(where: { $0.reaction == .stars }) {
                                self.areStarsReactionsEnabled = false
                            }
                            
                            if !self.isUpdating {
                                self.state?.updated(transition: .spring(duration: 0.25))
                            }
                        }
                    )),
                    environment: {},
                    containerSize: CGSize(width: availableSize.width, height: availableSize.height)
                )
                let reactionSelectionControlFrame = CGRect(origin: CGPoint(x: 0.0, y: availableSize.height - reactionSelectionControlSize.height), size: reactionSelectionControlSize)
                if let reactionSelectionControlView = reactionSelectionControl.view {
                    if reactionSelectionControlView.superview == nil {
                        self.addSubview(reactionSelectionControlView)
                    }
                    if animateIn {
                        reactionSelectionControlView.frame = reactionSelectionControlFrame
                        transition.animatePosition(view: reactionSelectionControlView, from: CGPoint(x: 0.0, y: reactionSelectionControlFrame.height), to: CGPoint(), additive: true)
                    } else {
                        transition.setFrame(view: reactionSelectionControlView, frame: reactionSelectionControlFrame)
                    }
                }
                inputHeight = reactionSelectionControlSize.height
            } else if let reactionSelectionControl = self.reactionSelectionControl {
                self.reactionSelectionControl = nil
                if let reactionSelectionControlView = reactionSelectionControl.view {
                    transition.setPosition(view: reactionSelectionControlView, position: CGPoint(x: reactionSelectionControlView.center.x, y: availableSize.height + reactionSelectionControlView.bounds.height * 0.5), completion: { [weak reactionSelectionControlView] _ in
                        reactionSelectionControlView?.removeFromSuperview()
                    })
                }
            }
            
            let buttonY: CGFloat
            
            if self.displayInput {
                contentHeight += bottomInset + 8.0
                contentHeight += inputHeight
                
                buttonY = availableSize.height - bottomInset - 8.0 - inputHeight - buttonSize.height
            } else {
                contentHeight += bottomInset
                contentHeight += environment.safeInsets.bottom
                
                buttonY = availableSize.height - bottomInset - environment.safeInsets.bottom - buttonSize.height
            }
            
            let buttonFrame = CGRect(origin: CGPoint(x: sideInset, y: buttonY), size: buttonSize)
            if let buttonView = self.actionButton.view {
                if buttonView.superview == nil {
                    self.addSubview(buttonView)
                }
                transition.setFrame(view: buttonView, frame: buttonFrame)
                transition.setAlpha(view: buttonView, alpha: self.isEnabled ? 1.0 : 0.0)
            }
            
            let contentSize = CGSize(width: availableSize.width, height: contentHeight)
            if self.scrollView.frame != CGRect(origin: CGPoint(), size: availableSize) {
                self.scrollView.frame = CGRect(origin: CGPoint(), size: availableSize)
            }
            if self.scrollView.contentSize != contentSize {
                self.scrollView.contentSize = contentSize
            }
            let scrollInsets = UIEdgeInsets(top: environment.navigationHeight, left: 0.0, bottom: environment.safeInsets.bottom, right: 0.0)
            if self.scrollView.verticalScrollIndicatorInsets != scrollInsets {
                self.scrollView.verticalScrollIndicatorInsets = scrollInsets
            }
            
            if self.recenterOnCaret {
                self.recenterOnCaret = false
                
                if let reactionInputView = self.reactionInput?.view as? EmojiListInputComponent.View, let localCaretRect = reactionInputView.caretRect() {
                    let caretRect = reactionInputView.convert(localCaretRect, to: self.scrollView)
                    var scrollViewBounds = self.scrollView.bounds
                    let minButtonDistance: CGFloat = 16.0
                    if -scrollViewBounds.minY + caretRect.maxY > buttonFrame.minY - minButtonDistance {
                        scrollViewBounds.origin.y = -(buttonFrame.minY - minButtonDistance - caretRect.maxY)
                        if scrollViewBounds.origin.y < 0.0 {
                            scrollViewBounds.origin.y = 0.0
                        }
                    }
                    if self.scrollView.bounds != scrollViewBounds {
                        transition.setBounds(view: self.scrollView, bounds: scrollViewBounds)
                    }
                }
            }
            
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

public class PeerAllowedReactionsScreen: ViewControllerComponentContainer {
    public final class Content: Equatable {
        public let isEnabled: Bool
        public let enabledReactions: [EmojiComponentReactionItem]
        public let availableReactions: AvailableReactions?
        public let reactionSettings: PeerReactionSettings?
        public let isStarReactionAvailable: Bool
        
        init(
            isEnabled: Bool,
            enabledReactions: [EmojiComponentReactionItem],
            availableReactions: AvailableReactions?,
            reactionSettings: PeerReactionSettings?,
            isStarReactionAvailable: Bool
        ) {
            self.isEnabled = isEnabled
            self.enabledReactions = enabledReactions
            self.availableReactions = availableReactions
            self.reactionSettings = reactionSettings
            self.isStarReactionAvailable = isStarReactionAvailable
        }
        
        public static func ==(lhs: Content, rhs: Content) -> Bool {
            if lhs === rhs {
                return true
            }
            if lhs.isEnabled != rhs.isEnabled {
                return false
            }
            if lhs.enabledReactions != rhs.enabledReactions {
                return false
            }
            if lhs.availableReactions != rhs.availableReactions {
                return false
            }
            if lhs.reactionSettings != rhs.reactionSettings {
                return false
            }
            if lhs.isStarReactionAvailable != rhs.isStarReactionAvailable {
                return false
            }
            return true
        }
    }
    
    private let context: AccountContext
    private var isDismissed: Bool = false
    
    public init(
        context: AccountContext,
        peerId: EnginePeer.Id,
        initialContent: Content
    ) {
        self.context = context
        
        super.init(context: context, component: PeerAllowedReactionsScreenComponent(
            context: context,
            peerId: peerId,
            initialContent: initialContent
        ), navigationBarAppearance: .default, theme: .default)
        
        self.title = context.sharedContext.currentPresentationData.with({ $0 }).strings.ChannelReactions_Reactions
        
        self.scrollToTop = { [weak self] in
            guard let self, let componentView = self.node.hostView.componentView as? PeerAllowedReactionsScreenComponent.View else {
                return
            }
            componentView.scrollToTop()
        }
        
        self.attemptNavigation = { [weak self] complete in
            guard let self, let componentView = self.node.hostView.componentView as? PeerAllowedReactionsScreenComponent.View else {
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
    
    public static func content(context: AccountContext, peerId: EnginePeer.Id) -> Signal<Content, NoError> {
        return combineLatest(
            context.engine.stickers.availableReactions(),
            context.account.postbox.combinedView(keys: [.cachedPeerData(peerId: peerId)])
        )
        |> mapToSignal { availableReactions, combinedView -> Signal<Content, NoError> in
            guard let cachedDataView = combinedView.views[.cachedPeerData(peerId: peerId)] as? CachedPeerDataView, let cachedData = cachedDataView.cachedPeerData as? CachedChannelData else {
                return .complete()
            }
            
            var reactions: [MessageReaction.Reaction] = []
            var isEnabled = false
            
            let reactionSettings = cachedData.reactionSettings.knownValue
            if let reactionSettings {
                switch reactionSettings.allowedReactions {
                case .all:
                    isEnabled = true
                    if let availableReactions {
                        reactions = availableReactions.reactions.filter({ $0.isEnabled }).map(\.value)
                    }
                case let .limited(list):
                    isEnabled = true
                    reactions.append(contentsOf: list)
                case .empty:
                    isEnabled = false
                }
                if let starsAllowed = reactionSettings.starsAllowed, starsAllowed {
                    isEnabled = true
                }
            }
            
            var missingReactionFiles: [Int64] = []
            for reaction in reactions {
                if let availableReactions, let _ = availableReactions.reactions.filter({ $0.isEnabled }).first(where: { $0.value == reaction }) {
                } else {
                    if case let .custom(fileId) = reaction {
                        if !missingReactionFiles.contains(fileId) {
                            missingReactionFiles.append(fileId)
                        }
                    }
                }
            }
            
            return context.engine.stickers.resolveInlineStickers(fileIds: missingReactionFiles)
            |> map { files -> Content in
                var result: [EmojiComponentReactionItem] = []
                
                for reaction in reactions {
                    if let availableReactions, let item = availableReactions.reactions.filter({ $0.isEnabled }).first(where: { $0.value == reaction }) {
                        result.append(EmojiComponentReactionItem(reaction: reaction, file: item.selectAnimation))
                    } else {
                        if case let .custom(fileId) = reaction {
                            if let file = files[fileId] {
                                result.append(EmojiComponentReactionItem(reaction: reaction, file: TelegramMediaFile.Accessor(file)))
                            }
                        }
                    }
                }
                
                return Content(isEnabled: isEnabled, enabledReactions: result, availableReactions: availableReactions, reactionSettings: reactionSettings, isStarReactionAvailable: cachedData.flags.contains(.paidMediaAllowed))
            }
        }
        |> distinctUntilChanged
    }
}
