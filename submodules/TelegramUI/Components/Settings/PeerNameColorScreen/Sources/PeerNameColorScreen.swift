import Foundation
import UIKit
import Display
import AsyncDisplayKit
import SwiftSignalKit
import Postbox
import TelegramCore
import TelegramPresentationData
import TelegramUIPreferences
import ItemListUI
import PresentationDataUtils
import AccountContext
import UndoUI
import EntityKeyboard
import PremiumUI

private final class PeerNameColorScreenArguments {
    let context: AccountContext
    let updateNameColor: (PeerNameColor) -> Void
    let updateBackgroundEmojiId: (Int64?) -> Void
    
    init(
        context: AccountContext,
        updateNameColor: @escaping (PeerNameColor) -> Void,
        updateBackgroundEmojiId: @escaping (Int64?) -> Void
    ) {
        self.context = context
        self.updateNameColor = updateNameColor
        self.updateBackgroundEmojiId = updateBackgroundEmojiId
    }
}

private enum PeerNameColorScreenSection: Int32 {
    case nameColor
    case backgroundEmoji
}

private enum PeerNameColorScreenEntry: ItemListNodeEntry {
    enum StableId: Hashable {
        case colorHeader
        case colorMessage
        case colorPicker
        case colorDescription
        case backgroundEmojiHeader
        case backgroundEmoji
    }
    
    case colorHeader(String)
    case colorMessage(wallpaper: TelegramWallpaper, fontSize: PresentationFontSize, bubbleCorners: PresentationChatBubbleCorners, dateTimeFormat: PresentationDateTimeFormat, nameDisplayOrder: PresentationPersonNameOrder, items: [PeerNameColorChatPreviewItem.MessageItem])
    case colorPicker(colors: PeerNameColors, currentColor: PeerNameColor)
    case colorDescription(String)
    case backgroundEmojiHeader(String, String?)
    case backgroundEmoji(EmojiPagerContentComponent, UIColor)
    
    var section: ItemListSectionId {
        switch self {
        case .colorHeader, .colorMessage, .colorPicker, .colorDescription:
            return PeerNameColorScreenSection.nameColor.rawValue
        case .backgroundEmojiHeader, .backgroundEmoji:
            return PeerNameColorScreenSection.backgroundEmoji.rawValue
        }
    }
    
    var stableId: StableId {
        switch self {
        case .colorHeader:
            return .colorHeader
        case .colorMessage:
            return .colorMessage
        case .colorPicker:
            return .colorPicker
        case .colorDescription:
            return .colorDescription
        case .backgroundEmojiHeader:
            return .backgroundEmojiHeader
        case .backgroundEmoji:
            return .backgroundEmoji
        }
    }
    
    var sortId: Int {
        switch self {
        case .colorHeader:
            return 0
        case .colorMessage:
            return 1
        case .colorPicker:
            return 2
        case .colorDescription:
            return 3
        case .backgroundEmojiHeader:
            return 4
        case .backgroundEmoji:
            return 5
        }
    }
    
    static func ==(lhs: PeerNameColorScreenEntry, rhs: PeerNameColorScreenEntry) -> Bool {
        switch lhs {
        case let .colorHeader(text):
            if case .colorHeader(text) = rhs {
                return true
            } else {
                return false
            }
        case let .colorMessage(lhsWallpaper, lhsFontSize, lhsBubbleCorners, lhsDateTimeFormat, lhsNameDisplayOrder, lhsItems):
            if case let .colorMessage(rhsWallpaper, rhsFontSize, rhsBubbleCorners, rhsDateTimeFormat, rhsNameDisplayOrder, rhsItems) = rhs, lhsWallpaper == rhsWallpaper, lhsFontSize == rhsFontSize, lhsBubbleCorners == rhsBubbleCorners, lhsDateTimeFormat == rhsDateTimeFormat, lhsNameDisplayOrder == rhsNameDisplayOrder, lhsItems == rhsItems {
                return true
            } else {
                return false
            }
        case let .colorPicker(lhsColors, lhsCurrentColor):
            if case let .colorPicker(rhsColors, rhsCurrentColor) = rhs, lhsColors == rhsColors, lhsCurrentColor == rhsCurrentColor {
                return true
            } else {
                return false
            }
        case let .colorDescription(text):
            if case .colorDescription(text) = rhs {
                return true
            } else {
                return false
            }
        case let .backgroundEmojiHeader(text, action):
            if case .backgroundEmojiHeader(text, action) = rhs {
                return true
            } else {
                return false
            }
        case let .backgroundEmoji(lhsEmojiContent, lhsBackgroundIconColor):
            if case let .backgroundEmoji(rhsEmojiContent, rhsBackgroundIconColor) = rhs, lhsEmojiContent == rhsEmojiContent, lhsBackgroundIconColor == rhsBackgroundIconColor {
                return true
            } else {
                return false
            }
        }
    }
    
    static func <(lhs: PeerNameColorScreenEntry, rhs: PeerNameColorScreenEntry) -> Bool {
        return lhs.sortId < rhs.sortId
    }
    
    func item(presentationData: ItemListPresentationData, arguments: Any) -> ListViewItem {
        let arguments = arguments as! PeerNameColorScreenArguments
        switch self {
        case let .colorHeader(text):
            return ItemListSectionHeaderItem(presentationData: presentationData, text: text, sectionId: self.section)
        case let .colorMessage(wallpaper, fontSize, chatBubbleCorners, dateTimeFormat, nameDisplayOrder, items):
            return PeerNameColorChatPreviewItem(
                context: arguments.context,
                theme: presentationData.theme,
                componentTheme: presentationData.theme,
                strings: presentationData.strings,
                sectionId: self.section,
                fontSize: fontSize,
                chatBubbleCorners: chatBubbleCorners,
                wallpaper: wallpaper,
                dateTimeFormat: dateTimeFormat,
                nameDisplayOrder: nameDisplayOrder,
                messageItems: items)
        case let .colorPicker(colors, currentColor):
            return PeerNameColorItem(
                theme: presentationData.theme,
                colors: colors,
                currentColor: currentColor,
                updated: { color in
                    arguments.updateNameColor(color)
                },
                sectionId: self.section
            )
        case let .colorDescription(text):
            return ItemListTextItem(presentationData: presentationData, text: .plain(text), sectionId: self.section)
        case let .backgroundEmojiHeader(text, action):
            return ItemListSectionHeaderItem(presentationData: presentationData, text: text, actionText: action, action: action != nil ? {
                arguments.updateBackgroundEmojiId(0)
            } : nil, sectionId: self.section)
        case let .backgroundEmoji(emojiContent, backgroundIconColor):
            return EmojiPickerItem(context: arguments.context, theme: presentationData.theme, strings: presentationData.strings, emojiContent: emojiContent, backgroundIconColor: backgroundIconColor, sectionId: self.section)
        }
    }
}

private struct PeerNameColorScreenState: Equatable {
    var updatedNameColor: PeerNameColor?
    var updatedBackgroundEmojiId: Int64?
    var inProgress: Bool = false
    var needsBoosts: Bool = false
}

private func peerNameColorScreenEntries(
    nameColors: PeerNameColors,
    presentationData: PresentationData,
    state: PeerNameColorScreenState,
    peer: EnginePeer?,
    isPremium: Bool,
    emojiContent: EmojiPagerContentComponent?
) -> [PeerNameColorScreenEntry] {
    var entries: [PeerNameColorScreenEntry] = []
    
    if let peer {
        let nameColor: PeerNameColor
        if let updatedNameColor = state.updatedNameColor {
            nameColor = updatedNameColor
        } else if let peerNameColor = peer.nameColor {
            nameColor = peerNameColor
        } else {
            nameColor = .blue
        }
        
        let colors = nameColors.get(nameColor, dark: presentationData.theme.overallDarkAppearance)
        
        let backgroundEmojiId: Int64?
        if let updatedBackgroundEmojiId = state.updatedBackgroundEmojiId {
            if updatedBackgroundEmojiId == 0 {
                backgroundEmojiId = nil
            } else {
                backgroundEmojiId = updatedBackgroundEmojiId
            }
        } else if let emojiId = peer.backgroundEmojiId {
            backgroundEmojiId = emojiId
        } else {
            backgroundEmojiId = nil
        }
        
        let replyText: String
        let messageText: String
        if case .channel = peer {
            replyText = presentationData.strings.NameColor_ChatPreview_ReplyText_Channel
            messageText = presentationData.strings.NameColor_ChatPreview_MessageText_Channel
        } else {
            replyText = presentationData.strings.NameColor_ChatPreview_ReplyText_Account
            messageText = presentationData.strings.NameColor_ChatPreview_MessageText_Account
        }
        let messageItem = PeerNameColorChatPreviewItem.MessageItem(
            outgoing: false,
            peerId: PeerId(namespace: peer.id.namespace, id: PeerId.Id._internalFromInt64Value(0)),
            author: peer.compactDisplayTitle,
            photo: peer.profileImageRepresentations,
            nameColor: nameColor,
            backgroundEmojiId: backgroundEmojiId,
            reply: (peer.compactDisplayTitle, replyText),
            linkPreview: (presentationData.strings.NameColor_ChatPreview_LinkSite, presentationData.strings.NameColor_ChatPreview_LinkTitle, presentationData.strings.NameColor_ChatPreview_LinkText),
            text: messageText
        )
        entries.append(.colorMessage(
            wallpaper: presentationData.chatWallpaper,
            fontSize: presentationData.chatFontSize,
            bubbleCorners: presentationData.chatBubbleCorners,
            dateTimeFormat: presentationData.dateTimeFormat,
            nameDisplayOrder: presentationData.nameDisplayOrder,
            items: [messageItem]
        ))
        entries.append(.colorPicker(
            colors: nameColors,
            currentColor: nameColor
        ))
        if case .channel = peer {
            entries.append(.colorDescription(presentationData.strings.NameColor_ChatPreview_Description_Channel))
        } else {
            entries.append(.colorDescription(presentationData.strings.NameColor_ChatPreview_Description_Account))
        }
        
        if let emojiContent {
            entries.append(.backgroundEmojiHeader(presentationData.strings.NameColor_BackgroundEmoji_Title, backgroundEmojiId != nil ? presentationData.strings.NameColor_BackgroundEmoji_Remove : nil))
            entries.append(.backgroundEmoji(emojiContent, colors.main))
        }
    }
    
    return entries
}

public enum PeerNameColorScreenSubject {
    case account
    case channel(EnginePeer.Id)
}

public func PeerNameColorScreen(
    context: AccountContext,
    updatedPresentationData: (initial: PresentationData, signal: Signal<PresentationData, NoError>)? = nil,
    subject: PeerNameColorScreenSubject
) -> ViewController {
    let statePromise = ValuePromise(PeerNameColorScreenState(), ignoreRepeated: true)
    let stateValue = Atomic(value: PeerNameColorScreenState())
    let updateState: ((PeerNameColorScreenState) -> PeerNameColorScreenState) -> Void = { f in
        statePromise.set(stateValue.modify { f($0) })
    }
    
    let premiumConfiguration = PremiumConfiguration.with(appConfiguration: context.currentAppConfiguration.with { $0 })
    
    var presentImpl: ((ViewController) -> Void)?
    var pushImpl: ((ViewController) -> Void)?
    var dismissImpl: (() -> Void)?
    var attemptNavigationImpl: ((@escaping () -> Void) -> Bool)?
    var applyChangesImpl: (() -> Void)?
    
    let actionsDisposable = DisposableSet()
    
    let arguments = PeerNameColorScreenArguments(
        context: context,
        updateNameColor: { color in
            updateState { state in
                var updatedState = state
                updatedState.updatedNameColor = color
                return updatedState
            }
        },
        updateBackgroundEmojiId: { emojiId in
            updateState { state in
                var updatedState = state
                updatedState.updatedBackgroundEmojiId = emojiId
                return updatedState
            }
        }
    )
    
    let peerId: EnginePeer.Id
    switch subject {
    case .account:
        peerId = context.account.peerId
    case let .channel(channelId):
        peerId = channelId
    }
    
    let emojiContent = combineLatest(
        context.sharedContext.presentationData,
        statePromise.get(),
        context.engine.data.get(TelegramEngine.EngineData.Item.Peer.Peer(id: peerId))
    )
    |> mapToSignal { presentationData, state, peer -> Signal<EmojiPagerContentComponent, NoError> in
        var selectedEmojiId: Int64?
        if let updatedBackgroundEmojiId = state.updatedBackgroundEmojiId {
            selectedEmojiId = updatedBackgroundEmojiId
        } else {
            selectedEmojiId = peer?.backgroundEmojiId
        }
        let nameColor: PeerNameColor
        if let updatedNameColor = state.updatedNameColor {
            nameColor = updatedNameColor
        } else {
            nameColor = (peer?.nameColor ?? .blue)
        }
        let color = context.peerNameColors.get(nameColor, dark: presentationData.theme.overallDarkAppearance)
        
        let selectedItems: [EngineMedia.Id]
        if let selectedEmojiId, selectedEmojiId != 0 {
            selectedItems = [EngineMedia.Id(namespace: Namespaces.Media.CloudFile, id: selectedEmojiId)]
        } else {
            selectedItems = []
        }
        
        return EmojiPagerContentComponent.emojiInputData(
            context: context,
            animationCache: context.animationCache,
            animationRenderer: context.animationRenderer,
            isStandalone: false,
            subject: .backgroundIcon,
            hasTrending: false,
            topReactionItems: [],
            areUnicodeEmojiEnabled: false,
            areCustomEmojiEnabled: true,
            chatPeerId: context.account.peerId,
            selectedItems: Set(selectedItems),
            backgroundIconColor: color.main
        )
    }
    
    let presentationData = updatedPresentationData?.signal ?? context.sharedContext.presentationData
    let signal = combineLatest(queue: .mainQueue(),
        presentationData,
        statePromise.get(),
        context.engine.stickers.availableReactions(),
        context.engine.data.subscribe(TelegramEngine.EngineData.Item.Peer.Peer(id: peerId)),
        emojiContent
    )
    |> deliverOnMainQueue
    |> map { presentationData, state, availableReactions, peer, emojiContent -> (ItemListControllerState, (ItemListNodeState, Any)) in
        let isPremium = peer?.isPremium ?? false
        let title: String
        let buttonTitle: String
        let isLocked: Bool
        switch subject {
        case .account:
            title = presentationData.strings.NameColor_Title_Account
            isLocked = !isPremium
        case .channel:
            title = presentationData.strings.NameColor_Title_Channel
            isLocked = false
        }
        
        let backgroundEmojiId: Int64
        if let updatedBackgroundEmojiId = state.updatedBackgroundEmojiId {
            backgroundEmojiId = updatedBackgroundEmojiId
        } else if let emojiId = peer?.backgroundEmojiId {
            backgroundEmojiId = emojiId
        } else {
            backgroundEmojiId = 0
        }
        if backgroundEmojiId != 0 {
            buttonTitle = presentationData.strings.NameColor_ApplyColorAndBackgroundEmoji
        } else {
            buttonTitle = presentationData.strings.NameColor_ApplyColor
        }
        
        let footerItem = ApplyColorFooterItem(
            theme: presentationData.theme,
            title: buttonTitle,
            locked: isLocked,
            inProgress: state.inProgress,
            action: {
                if !isLocked {
                    applyChangesImpl?()
                } else {
                    HapticFeedback().impact(.light)
                    let controller = UndoOverlayController(
                        presentationData: presentationData,
                        content: .premiumPaywall(
                            title: nil,
                            text: presentationData.strings.NameColor_TooltipPremium_Account,
                            customUndoText: nil,
                            timeout: nil,
                            linkAction: nil
                        ),
                        elevatedLayout: false,
                        action: { action in
                            if case .info = action {
                                let controller = context.sharedContext.makePremiumIntroController(context: context, source: .nameColor, forceDark: false, dismissed: nil)
                                pushImpl?(controller)
                            }
                            return true
                        }
                    )
                    presentImpl?(controller)
                }
            }
        )
    
        emojiContent.inputInteractionHolder.inputInteraction = EmojiPagerContentComponent.InputInteraction(
            performItemAction: { _, item, _, _, _, _ in
                var selectedFileId: Int64?
                if let fileId = item.itemFile?.fileId.id {
                    selectedFileId = fileId
                } else {
                    selectedFileId = 0
                }
                arguments.updateBackgroundEmojiId(selectedFileId)
            },
            deleteBackwards: {
            },
            openStickerSettings: {
            },
            openFeatured: {
            },
            openSearch: {
            },
            addGroupAction: { groupId, isPremiumLocked, _ in
                guard let collectionId = groupId.base as? ItemCollectionId else {
                    return
                }
                
                let viewKey = PostboxViewKey.orderedItemList(id: Namespaces.OrderedItemList.CloudFeaturedEmojiPacks)
                let _ = (context.account.postbox.combinedView(keys: [viewKey])
                |> take(1)
                |> deliverOnMainQueue).start(next: { views in
                    guard let view = views.views[viewKey] as? OrderedItemListView else {
                        return
                    }
                    for featuredEmojiPack in view.items.lazy.map({ $0.contents.get(FeaturedStickerPackItem.self)! }) {
                        if featuredEmojiPack.info.id == collectionId {
                            let _ = context.engine.stickers.addStickerPackInteractively(info: featuredEmojiPack.info, items: featuredEmojiPack.topItems).start()
                            
                            break
                        }
                    }
                })
            },
            clearGroup: { _ in
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
            updateSearchQuery: { _ in
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
        
        let entries = peerNameColorScreenEntries(
            nameColors: context.peerNameColors,
            presentationData: presentationData,
            state: state,
            peer: peer,
            isPremium: isPremium,
            emojiContent: emojiContent
        )
        
        let controllerState = ItemListControllerState(
            presentationData: ItemListPresentationData(presentationData),
            title: .text(title),
            leftNavigationButton: nil,
            rightNavigationButton: nil,
            backNavigationButton: ItemListBackButton(title: presentationData.strings.Common_Back),
            animateChanges: false
        )
        let listState = ItemListNodeState(
            presentationData: ItemListPresentationData(presentationData),
            entries: entries,
            style: .blocks,
            footerItem: footerItem,
            animateChanges: false
        )
        
        return (controllerState, (listState, arguments))
    }
    |> afterDisposed {
        actionsDisposable.dispose()
    }
    
    let controller = ItemListController(context: context, state: signal)
    controller.supportedOrientations = ViewControllerSupportedOrientations(regularSize: .all, compactSize: .portrait)
    presentImpl = { [weak controller] c in
        guard let controller else {
            return
        }
        if c is UndoOverlayController {
            controller.present(c, in: .current)
        } else {
            controller.present(c, in: .window(.root))
        }
    }
    pushImpl = { [weak controller] c in
        guard let controller else {
            return
        }
        controller.push(c)
    }
    dismissImpl = { [weak controller] in
        guard let controller else {
            return
        }
        controller.dismiss()
    }
    controller.attemptNavigation = { f in
        return attemptNavigationImpl?(f) ?? true
    }
    attemptNavigationImpl = { f in
        if case .account = subject, !context.isPremium {
            return true
        }
        let state = stateValue.with({ $0 })
        if case .channel = subject, state.needsBoosts {
            return true
        }
        var hasChanges = false
        if state.updatedNameColor != nil || state.updatedBackgroundEmojiId != nil {
            hasChanges = true
        }
        if hasChanges {
            let presentationData = context.sharedContext.currentPresentationData.with { $0 }
            presentImpl?(standardTextAlertController(theme: AlertControllerTheme(presentationData: presentationData), title: presentationData.strings.NameColor_UnsavedChanges_Title, text: presentationData.strings.NameColor_UnsavedChanges_Text, actions: [
                TextAlertAction(type: .genericAction, title: presentationData.strings.NameColor_UnsavedChanges_Discard, action: {
                    f()
                    dismissImpl?()
                }),
                TextAlertAction(type: .defaultAction, title: presentationData.strings.NameColor_UnsavedChanges_Apply, action: {
                    applyChangesImpl?()
                })
            ]))
            return false
        } else {
            return true
        }
    }
    applyChangesImpl = { [weak controller] in
        let _ = (context.engine.data.get(TelegramEngine.EngineData.Item.Peer.Peer(id: peerId))
        |> deliverOnMainQueue).startStandalone(next: { peer in
            guard let peer else {
                return
            }
            let state = stateValue.with { $0 }
            if state.updatedNameColor == nil && state.updatedBackgroundEmojiId == nil {
                dismissImpl?()
                return
            }
            
            let presentationData = context.sharedContext.currentPresentationData.with { $0 }

            let nameColor = state.updatedNameColor ?? peer.nameColor
            let backgroundEmojiId = state.updatedBackgroundEmojiId ?? peer.backgroundEmojiId
            let colors = context.peerNameColors.get(nameColor ?? .blue, dark: presentationData.theme.overallDarkAppearance)
            
            switch subject {
            case .account:
                let _ = context.engine.accountData.updateNameColorAndEmoji(nameColor: nameColor ?? .blue, backgroundEmojiId: backgroundEmojiId ?? 0).startStandalone()
                
                if let navigationController = controller?.navigationController as? NavigationController {
                    Queue.mainQueue().after(0.25) {
                        if let lastController = navigationController.viewControllers.last as? ViewController {
                            let tipController = UndoOverlayController(presentationData: presentationData, content: .image(image: generatePeerNameColorImage(nameColor: colors, isDark: presentationData.theme.overallDarkAppearance,  bounds: CGSize(width: 32.0, height: 32.0), size: CGSize(width: 22.0, height: 22.0))!, title: nil, text: presentationData.strings.NameColor_YourColorUpdated, round: false, undoText: nil), elevatedLayout: false, position: .bottom, animateInAsReplacement: false, action: { _ in return false })
                            lastController.present(tipController, in: .window(.root))
                        }
                    }
                }
                
                dismissImpl?()
            case let .channel(peerId):
                updateState { state in
                    var updatedState = state
                    updatedState.inProgress = true
                    return updatedState
                }
                let _ = (context.engine.peers.updatePeerNameColorAndEmoji(peerId: peerId, nameColor: nameColor ?? .blue, backgroundEmojiId: backgroundEmojiId ?? 0)
                |> deliverOnMainQueue).startStandalone(next: {
                }, error: { error in
                    if case .channelBoostRequired = error {
                        updateState { state in
                            var updatedState = state
                            updatedState.needsBoosts = true
                            return updatedState
                        }
                        
                        let _ = combineLatest(
                            queue: Queue.mainQueue(),
                            context.engine.data.get(TelegramEngine.EngineData.Item.Peer.Peer(id: peerId)),
                            context.engine.peers.getChannelBoostStatus(peerId: peerId)
                        ).startStandalone(next: { peer, status in
                            guard let peer, let status else {
                                return
                            }
                            
                            updateState { state in
                                var updatedState = state
                                updatedState.inProgress = false
                                return updatedState
                            }
                            
                            let link = status.url
                            let controller = PremiumLimitScreen(context: context, subject: .storiesChannelBoost(peer: peer, boostSubject: .nameColors, isCurrent: true, level: Int32(status.level), currentLevelBoosts: Int32(status.currentLevelBoosts), nextLevelBoosts: status.nextLevelBoosts.flatMap(Int32.init), link: link, myBoostCount: 0, canBoostAgain: false), count: Int32(status.boosts), action: {
                                UIPasteboard.general.string = link
                                let presentationData = context.sharedContext.currentPresentationData.with { $0 }
                                presentImpl?(UndoOverlayController(presentationData: presentationData, content: .linkCopied(text: presentationData.strings.ChannelBoost_BoostLinkCopied), elevatedLayout: false, position: .bottom, animateInAsReplacement: false, action: { _ in return false }))
                                return true
                            }, openStats: nil, openGift: premiumConfiguration.giveawayGiftsPurchaseAvailable ? {
                                let controller = createGiveawayController(context: context, peerId: peerId, subject: .generic)
                                pushImpl?(controller)
                            } : nil)
                            pushImpl?(controller)
                            
                            HapticFeedback().impact(.light)
                        })
                    } else {
                        updateState { state in
                            var updatedState = state
                            updatedState.inProgress = false
                            return updatedState
                        }
                    }
                }, completed: {
                    if let navigationController = controller?.navigationController as? NavigationController {
                        Queue.mainQueue().after(0.25) {
                            if let lastController = navigationController.viewControllers.last as? ViewController {
                                let tipController = UndoOverlayController(presentationData: presentationData, content: .image(image: generatePeerNameColorImage(nameColor: colors, isDark: presentationData.theme.overallDarkAppearance, bounds: CGSize(width: 32.0, height: 32.0), size: CGSize(width: 22.0, height: 22.0))!, title: nil, text: presentationData.strings.NameColor_ChannelColorUpdated, round: false, undoText: nil), elevatedLayout: false, position: .bottom, animateInAsReplacement: false, action: { _ in return false })
                                lastController.present(tipController, in: .window(.root))
                            }
                        }
                    }
                    
                    dismissImpl?()
                })
            }
        })
    }
    return controller
}
