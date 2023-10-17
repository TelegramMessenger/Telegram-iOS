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

private final class PeerNameColorScreenArguments {
    let context: AccountContext
    let updateNameColor: (PeerNameColor) -> Void
    let openBackgroundEmoji: () -> Void
    
    init(
        context: AccountContext,
        updateNameColor: @escaping (PeerNameColor) -> Void,
        openBackgroundEmoji: @escaping () -> Void
    ) {
        self.context = context
        self.updateNameColor = updateNameColor
        self.openBackgroundEmoji = openBackgroundEmoji
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
        case backgroundEmoji
        case backgroundEmojiDescription
    }
    
    case colorHeader(String)
    case colorMessage(wallpaper: TelegramWallpaper, fontSize: PresentationFontSize, bubbleCorners: PresentationChatBubbleCorners, dateTimeFormat: PresentationDateTimeFormat, nameDisplayOrder: PresentationPersonNameOrder, items: [PeerNameColorChatPreviewItem.MessageItem])
    case colorPicker(colors: [PeerNameColor], currentColor: PeerNameColor)
    case colorDescription(String)
    case backgroundEmoji(String, MessageReaction.Reaction, AvailableReactions)
    case backgroundEmojiDescription(String)
    
    var section: ItemListSectionId {
        switch self {
        case .colorHeader, .colorMessage, .colorPicker, .colorDescription:
            return PeerNameColorScreenSection.nameColor.rawValue
        case .backgroundEmoji, .backgroundEmojiDescription:
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
        case .backgroundEmoji:
            return .backgroundEmoji
        case .backgroundEmojiDescription:
            return .backgroundEmojiDescription
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
        case .backgroundEmoji:
            return 4
        case .backgroundEmojiDescription:
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
        case let .backgroundEmoji(lhsText, lhsReaction, lhsAvailableReactions):
            if case let .backgroundEmoji(rhsText, rhsReaction, rhsAvailableReactions) = rhs, lhsText == rhsText, lhsReaction == rhsReaction, lhsAvailableReactions == rhsAvailableReactions {
                return true
            } else {
                return false
            }
        case let .backgroundEmojiDescription(text):
            if case .backgroundEmojiDescription(text) = rhs {
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
        case let .backgroundEmoji(title, reaction, availableReactions):
            return BackgroundEmojiItem(
                context: arguments.context,
                presentationData: presentationData,
                title: title,
                reaction: reaction,
                availableReactions:  availableReactions,
                sectionId: self.section,
                style: .blocks,
                action: {
                    arguments.openBackgroundEmoji()
                })
        case let .backgroundEmojiDescription(text):
            return ItemListTextItem(presentationData: presentationData, text: .plain(text), sectionId: self.section)
        }
    }
}

private struct PeerNameColorScreenState: Equatable {
    var updatedNameColor: PeerNameColor?
}

private func peerNameColorScreenEntries(
    presentationData: PresentationData,
    state: PeerNameColorScreenState,
    peer: EnginePeer?,
    isPremium: Bool
) -> [PeerNameColorScreenEntry] {
    var entries: [PeerNameColorScreenEntry] = []
    
    if let peer {
        var allColors: [PeerNameColor] = [
            .blue
        ]
        allColors.append(contentsOf: PeerNameColor.allCases.filter { $0 != .blue})
        allColors.removeLast(3)
        
        let nameColor: PeerNameColor
        if let updatedNameColor = state.updatedNameColor {
            nameColor = updatedNameColor
        } else if let peerNameColor = peer.nameColor {
            nameColor = peerNameColor
        } else {
            nameColor = .blue
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
            peerId: peer.id,
            author: peer.compactDisplayTitle,
            photo: peer.profileImageRepresentations,
            nameColor: nameColor,
            backgroundEmojiId: nil,
            reply: (peer.compactDisplayTitle, replyText),
            linkPreview: (presentationData.strings.NameColor_ChatPreview_LinkSite, presentationData.strings.NameColor_ChatPreview_LinkTitle, presentationData.strings.NameColor_ChatPreview_LinkText),
            text: messageText
        )
        
        entries.append(.colorHeader(presentationData.strings.NameColor_ChatPreview_Title))
        entries.append(.colorMessage(
            wallpaper: presentationData.chatWallpaper,
            fontSize: presentationData.chatFontSize,
            bubbleCorners: presentationData.chatBubbleCorners,
            dateTimeFormat: presentationData.dateTimeFormat,
            nameDisplayOrder: presentationData.nameDisplayOrder,
            items: [messageItem]
        ))
        entries.append(.colorPicker(
            colors: allColors,
            currentColor: nameColor
        ))
        entries.append(.colorDescription(presentationData.strings.NameColor_ChatPreview_Description_Account))
    }
    
//    entries.append(.backgroundEmoji(presentationData.strings.Settings_QuickReactionSetup_ChooseQuickReaction, reactionSettings.quickReaction, availableReactions))
//    entries.append(.backgroundEmojiDescription(presentationData.strings.Settings_QuickReactionSetup_ChooseQuickReactionInfo))
    
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
    
    var presentImpl: ((ViewController) -> Void)?
    var pushImpl: ((ViewController) -> Void)?
    var dismissImpl: (() -> Void)?
    
//    var openQuickReactionImpl: (() -> Void)?
    
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
        openBackgroundEmoji: {
            
        }
    )
    
    let peerId: EnginePeer.Id
    switch subject {
    case .account:
        peerId = context.account.peerId
    case let .channel(channelId):
        peerId = channelId
    }
    
    let presentationData = updatedPresentationData?.signal ?? context.sharedContext.presentationData
    let signal = combineLatest(queue: .mainQueue(),
        presentationData,
        statePromise.get(),
        context.engine.stickers.availableReactions(),
        context.engine.data.get(TelegramEngine.EngineData.Item.Peer.Peer(id: peerId))
    )
    |> deliverOnMainQueue
    |> map { presentationData, state, availableReactions, peer -> (ItemListControllerState, (ItemListNodeState, Any)) in
        let isPremium = peer?.isPremium ?? false
        let title: String
        let isLocked: Bool
        switch subject {
        case .account:
            title = presentationData.strings.NameColor_Title_Account
            isLocked = !isPremium
        case .channel:
            title = presentationData.strings.NameColor_Title_Channel
            isLocked = false
        }
        
        let footerItem = ApplyColorFooterItem(
            theme: presentationData.theme,
            title: presentationData.strings.NameColor_ApplyColor,
            locked: isLocked,
            action: {
                if isPremium {
                    let state = stateValue.with { $0 }
                    if let nameColor = state.updatedNameColor {
                        let _ = context.engine.accountData.updateNameColorAndEmoji(nameColor: nameColor, backgroundEmojiId: nil).startStandalone()
                    }
                    dismissImpl?()
                } else {
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
                                let controller = context.sharedContext.makePremiumIntroController(context: context, source: .storiesSuggestedReactions, forceDark: false, dismissed: nil)
                                pushImpl?(controller)
                            }
                            return true
                        }
                    )
                    presentImpl?(controller)
                }
            }
        )
    
        let entries = peerNameColorScreenEntries(
            presentationData: presentationData,
            state: state,
            peer: peer,
            isPremium: isPremium
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
            animateChanges: true
        )
        
        return (controllerState, (listState, arguments))
    }
    |> afterDisposed {
        actionsDisposable.dispose()
    }
    
    let controller = ItemListController(context: context, state: signal)
//    openQuickReactionImpl = { [weak controller] in
//        let _ = (combineLatest(queue: .mainQueue(),
//            settings,
//            context.engine.stickers.availableReactions()
//        )
//        |> take(1)
//        |> deliverOnMainQueue).start(next: { settings, availableReactions in
//            var currentSelectedFileId: MediaId?
//            switch settings.quickReaction {
//            case .builtin:
//                if let availableReactions = availableReactions {
//                    if let reaction = availableReactions.reactions.first(where: { $0.value == settings.quickReaction }) {
//                        currentSelectedFileId = reaction.selectAnimation.fileId
//                        break
//                    }
//                }
//            case let .custom(fileId):
//                currentSelectedFileId = MediaId(namespace: Namespaces.Media.CloudFile, id: fileId)
//            }
//            
//            var selectedItems = Set<MediaId>()
//            if let currentSelectedFileId = currentSelectedFileId {
//                selectedItems.insert(currentSelectedFileId)
//            }
//            
//            guard let controller = controller else {
//                return
//            }
//            var sourceItemNode: ItemListReactionItemNode?
//            controller.forEachItemNode { itemNode in
//                if let itemNode = itemNode as? ItemListReactionItemNode {
//                    sourceItemNode = itemNode
//                }
//            }
//            
//            if let sourceItemNode = sourceItemNode {
//                controller.present(EmojiStatusSelectionController(
//                    context: context,
//                    mode: .quickReactionSelection(completion: {
//                        updateState { state in
//                            var state = state
//                            state.hasReaction = false
//                            return state
//                        }
//                    }),
//                    sourceView: sourceItemNode.iconView,
//                    emojiContent: EmojiPagerContentComponent.emojiInputData(
//                        context: context,
//                        animationCache: context.animationCache,
//                        animationRenderer: context.animationRenderer,
//                        isStandalone: false,
//                        isStatusSelection: false,
//                        isReactionSelection: true,
//                        isEmojiSelection: false,
//                        hasTrending: false,
//                        isQuickReactionSelection: true,
//                        topReactionItems: [],
//                        areUnicodeEmojiEnabled: false,
//                        areCustomEmojiEnabled: true,
//                        chatPeerId: context.account.peerId,
//                        selectedItems: selectedItems
//                    ),
//                    currentSelection: nil,
//                    destinationItemView: { [weak sourceItemNode] in
//                        return sourceItemNode?.iconView
//                    }
//                ), in: .window(.root))
//            }
//        })
//    }
    
    presentImpl = { [weak controller] c in
        guard let controller else {
            return
        }
        controller.present(c, in: .current)
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
    
    return controller
}

