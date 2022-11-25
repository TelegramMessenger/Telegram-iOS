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
import ReactionImageComponent
import WebPBinding
import EmojiStatusSelectionComponent
import EntityKeyboard

private final class QuickReactionSetupControllerArguments {
    let context: AccountContext
    let openQuickReaction: () -> Void
    let toggleReaction: () -> Void
    
    init(
        context: AccountContext,
        openQuickReaction: @escaping () -> Void,
        toggleReaction: @escaping () -> Void
    ) {
        self.context = context
        self.openQuickReaction = openQuickReaction
        self.toggleReaction = toggleReaction
    }
}

private enum QuickReactionSetupControllerSection: Int32 {
    case demo
    case items
}

private enum QuickReactionSetupControllerEntry: ItemListNodeEntry {
    enum StableId: Hashable {
        case demoHeader
        case demoMessage
        case demoDescription
        case quickReaction
        case quickReactionDescription
    }
    
    case demoHeader(String)
    case demoMessage(wallpaper: TelegramWallpaper, fontSize: PresentationFontSize, bubbleCorners: PresentationChatBubbleCorners, dateTimeFormat: PresentationDateTimeFormat, nameDisplayOrder: PresentationPersonNameOrder, availableReactions: AvailableReactions?, reaction: MessageReaction.Reaction?)
    case demoDescription(String)
    case quickReaction(String, MessageReaction.Reaction, AvailableReactions)
    case quickReactionDescription(String)
    
    var section: ItemListSectionId {
        switch self {
        case .demoHeader, .demoMessage, .demoDescription:
            return QuickReactionSetupControllerSection.demo.rawValue
        case .quickReaction, .quickReactionDescription:
            return QuickReactionSetupControllerSection.items.rawValue
        }
    }
    
    var stableId: StableId {
        switch self {
        case .demoHeader:
            return .demoHeader
        case .demoMessage:
            return .demoMessage
        case .demoDescription:
            return .demoDescription
        case .quickReaction:
            return .quickReaction
        case .quickReactionDescription:
            return .quickReactionDescription
        }
    }
    
    var sortId: Int {
        switch self {
        case .demoHeader:
            return 0
        case .demoMessage:
            return 1
        case .demoDescription:
            return 2
        case .quickReaction:
            return 3
        case .quickReactionDescription:
            return 4
        }
    }
    
    static func ==(lhs: QuickReactionSetupControllerEntry, rhs: QuickReactionSetupControllerEntry) -> Bool {
        switch lhs {
        case let .demoHeader(text):
            if case .demoHeader(text) = rhs {
                return true
            } else {
                return false
            }
        case let .demoMessage(lhsWallpaper, lhsFontSize, lhsBubbleCorners, lhsDateTimeFormat, lhsNameDisplayOrder, lhsAvailableReactions, lhsReaction):
            if case let .demoMessage(rhsWallpaper, rhsFontSize, rhsBubbleCorners, rhsDateTimeFormat, rhsNameDisplayOrder, rhsAvailableReactions, rhsReaction) = rhs, lhsWallpaper == rhsWallpaper, lhsFontSize == rhsFontSize, lhsBubbleCorners == rhsBubbleCorners, lhsDateTimeFormat == rhsDateTimeFormat, lhsNameDisplayOrder == rhsNameDisplayOrder, lhsAvailableReactions == rhsAvailableReactions, lhsReaction == rhsReaction {
                return true
            } else {
                return false
            }
        case let .demoDescription(text):
            if case .demoDescription(text) = rhs {
                return true
            } else {
                return false
            }
        case let .quickReaction(lhsText, lhsReaction, lhsAvailableReactions):
            if case let .quickReaction(rhsText, rhsReaction, rhsAvailableReactions) = rhs, lhsText == rhsText, lhsReaction == rhsReaction, lhsAvailableReactions == rhsAvailableReactions {
                return true
            } else {
                return false
            }
        case let .quickReactionDescription(text):
            if case .quickReactionDescription(text) = rhs {
                return true
            } else {
                return false
            }
        }
    }
    
    static func <(lhs: QuickReactionSetupControllerEntry, rhs: QuickReactionSetupControllerEntry) -> Bool {
        return lhs.sortId < rhs.sortId
    }
    
    func item(presentationData: ItemListPresentationData, arguments: Any) -> ListViewItem {
        let arguments = arguments as! QuickReactionSetupControllerArguments
        switch self {
        case let .demoHeader(text):
            return ItemListSectionHeaderItem(presentationData: presentationData, text: text, sectionId: self.section)
        case let .demoMessage(wallpaper, fontSize, chatBubbleCorners, dateTimeFormat, nameDisplayOrder, availableReactions, reaction):
            return ReactionChatPreviewItem(
                context: arguments.context,
                theme: presentationData.theme,
                strings: presentationData.strings,
                sectionId: self.section,
                fontSize: fontSize,
                chatBubbleCorners: chatBubbleCorners,
                wallpaper: wallpaper,
                dateTimeFormat: dateTimeFormat,
                nameDisplayOrder: nameDisplayOrder,
                availableReactions: availableReactions,
                reaction: reaction,
                toggleReaction: {
                    arguments.toggleReaction()
                }
            )
        case let .demoDescription(text):
            return ItemListTextItem(presentationData: presentationData, text: .plain(text), sectionId: self.section)
        case let .quickReaction(title, reaction, availableReactions):
            return ItemListReactionItem(context: arguments.context, presentationData: presentationData, title: title, reaction: reaction, availableReactions: availableReactions, sectionId: self.section, style: .blocks, action: {
                arguments.openQuickReaction()
            })
        case let .quickReactionDescription(text):
            return ItemListTextItem(presentationData: presentationData, text: .plain(text), sectionId: self.section)
        }
    }
}

private struct QuickReactionSetupControllerState: Equatable {
    var hasReaction: Bool = false
}

private func quickReactionSetupControllerEntries(
    presentationData: PresentationData,
    availableReactions: AvailableReactions?,
    reactionSettings: ReactionSettings,
    state: QuickReactionSetupControllerState,
    isPremium: Bool
) -> [QuickReactionSetupControllerEntry] {
    var entries: [QuickReactionSetupControllerEntry] = []
    
    if let availableReactions = availableReactions {
        entries.append(.demoHeader(presentationData.strings.Settings_QuickReactionSetup_DemoHeader))
        entries.append(.demoMessage(
            wallpaper: presentationData.chatWallpaper,
            fontSize: presentationData.chatFontSize,
            bubbleCorners: presentationData.chatBubbleCorners,
            dateTimeFormat: presentationData.dateTimeFormat,
            nameDisplayOrder: presentationData.nameDisplayOrder,
            availableReactions: availableReactions,
            reaction: state.hasReaction ? reactionSettings.effectiveQuickReaction(hasPremium: isPremium) : nil
        ))
        entries.append(.demoDescription(presentationData.strings.Settings_QuickReactionSetup_DemoInfo))
        
        entries.append(.quickReaction(presentationData.strings.Settings_QuickReactionSetup_ChooseQuickReaction, reactionSettings.quickReaction, availableReactions))
        
        entries.append(.quickReactionDescription(presentationData.strings.Settings_QuickReactionSetup_ChooseQuickReactionInfo))
    }
    
    return entries
}

public func quickReactionSetupController(
    context: AccountContext,
    updatedPresentationData: (initial: PresentationData, signal: Signal<PresentationData, NoError>)? = nil
) -> ViewController {
    let statePromise = ValuePromise(QuickReactionSetupControllerState(), ignoreRepeated: true)
    let stateValue = Atomic(value: QuickReactionSetupControllerState())
    let updateState: ((QuickReactionSetupControllerState) -> QuickReactionSetupControllerState) -> Void = { f in
        statePromise.set(stateValue.modify { f($0) })
    }
    
    var dismissImpl: (() -> Void)?
    let _ = dismissImpl
    
    var openQuickReactionImpl: (() -> Void)?
    
    let actionsDisposable = DisposableSet()
    
    let arguments = QuickReactionSetupControllerArguments(
        context: context,
        openQuickReaction: {
            openQuickReactionImpl?()
        },
        toggleReaction: {
            updateState { state in
                var state = state
                state.hasReaction = !state.hasReaction
                return state
            }
        }
    )
    
    let settings = context.account.postbox.preferencesView(keys: [PreferencesKeys.reactionSettings])
    |> map { preferencesView -> ReactionSettings in
        let reactionSettings: ReactionSettings
        if let entry = preferencesView.values[PreferencesKeys.reactionSettings], let value = entry.get(ReactionSettings.self) {
            reactionSettings = value
        } else {
            reactionSettings = .default
        }
        return reactionSettings
    }
    
    let presentationData = updatedPresentationData?.signal ?? context.sharedContext.presentationData
    let signal = combineLatest(queue: .mainQueue(),
        presentationData,
        statePromise.get(),
        context.engine.stickers.availableReactions(),
        settings,
        context.engine.data.get(TelegramEngine.EngineData.Item.Peer.Peer(id: context.account.peerId))
    )
    |> deliverOnMainQueue
    |> map { presentationData, state, availableReactions, settings, accountPeer -> (ItemListControllerState, (ItemListNodeState, Any)) in
        let isPremium = accountPeer?.isPremium ?? false
        let title: String = presentationData.strings.Settings_QuickReactionSetup_Title
        
        let entries = quickReactionSetupControllerEntries(
            presentationData: presentationData,
            availableReactions: availableReactions,
            reactionSettings: settings,
            state: state,
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
            animateChanges: true
        )
        
        return (controllerState, (listState, arguments))
    }
    |> afterDisposed {
        actionsDisposable.dispose()
    }
    
    let controller = ItemListController(context: context, state: signal)
    
    controller.didScrollWithOffset = { [weak controller] offset, transition, _, _ in
        guard let controller = controller else {
            return
        }
        controller.forEachItemNode { itemNode in
            if let itemNode = itemNode as? ReactionChatPreviewItemNode {
                itemNode.standaloneReactionAnimation?.addRelativeContentOffset(CGPoint(x: 0.0, y: offset), transition: transition)
            }
        }
    }
    
    openQuickReactionImpl = { [weak controller] in
        let _ = (combineLatest(queue: .mainQueue(),
            settings,
            context.engine.stickers.availableReactions()
        )
        |> take(1)
        |> deliverOnMainQueue).start(next: { settings, availableReactions in
            var currentSelectedFileId: MediaId?
            switch settings.quickReaction {
            case .builtin:
                if let availableReactions = availableReactions {
                    if let reaction = availableReactions.reactions.first(where: { $0.value == settings.quickReaction }) {
                        currentSelectedFileId = reaction.selectAnimation.fileId
                        break
                    }
                }
            case let .custom(fileId):
                currentSelectedFileId = MediaId(namespace: Namespaces.Media.CloudFile, id: fileId)
            }
            
            var selectedItems = Set<MediaId>()
            if let currentSelectedFileId = currentSelectedFileId {
                selectedItems.insert(currentSelectedFileId)
            }
            
            guard let controller = controller else {
                return
            }
            var sourceItemNode: ItemListReactionItemNode?
            controller.forEachItemNode { itemNode in
                if let itemNode = itemNode as? ItemListReactionItemNode {
                    sourceItemNode = itemNode
                }
            }
            
            if let sourceItemNode = sourceItemNode {
                controller.present(EmojiStatusSelectionController(
                    context: context,
                    mode: .quickReactionSelection(completion: {
                        updateState { state in
                            var state = state
                            state.hasReaction = false
                            return state
                        }
                    }),
                    sourceView: sourceItemNode.iconView,
                    emojiContent: EmojiPagerContentComponent.emojiInputData(
                        context: context,
                        animationCache: context.animationCache,
                        animationRenderer: context.animationRenderer,
                        isStandalone: false,
                        isStatusSelection: false,
                        isReactionSelection: true,
                        isQuickReactionSelection: true,
                        topReactionItems: [],
                        areUnicodeEmojiEnabled: false,
                        areCustomEmojiEnabled: true,
                        chatPeerId: context.account.peerId,
                        selectedItems: selectedItems
                    ),
                    currentSelection: nil,
                    destinationItemView: { [weak sourceItemNode] in
                        return sourceItemNode?.iconView
                    }
                ), in: .window(.root))
            }
        })
    }
    
    dismissImpl = { [weak controller] in
        guard let controller = controller else {
            return
        }
        controller.dismiss()
    }
    
    return controller
}

