import Foundation
import UIKit
import Display
import SwiftSignalKit
import Postbox
import TelegramCore
import LegacyComponents
import TelegramPresentationData
import TelegramUIPreferences
import ItemListUI
import PresentationDataUtils
import AccountContext
import ItemListPeerActionItem
import AttachmentUI
import TelegramStringFormatting
import ListMessageItem

private final class AttachmentFileControllerArguments {
    let context: AccountContext
    let openGallery: () -> Void
    let openFiles: () -> Void
    let send: (Message) -> Void
   
    init(context: AccountContext, openGallery: @escaping () -> Void, openFiles: @escaping () -> Void, send: @escaping (Message) -> Void) {
        self.context = context
        self.openGallery = openGallery
        self.openFiles = openFiles
        self.send = send
    }
}

private enum AttachmentFileSection: Int32 {
    case select
    case recent
}

private func areMessagesEqual(_ lhsMessage: Message?, _ rhsMessage: Message?) -> Bool {
    guard let lhsMessage = lhsMessage, let rhsMessage = rhsMessage else {
        return lhsMessage == nil && rhsMessage == nil
    }
    if lhsMessage.stableVersion != rhsMessage.stableVersion {
        return false
    }
    if lhsMessage.id != rhsMessage.id || lhsMessage.flags != rhsMessage.flags {
        return false
    }
    return true
}

private enum AttachmentFileEntry: ItemListNodeEntry {
    case selectFromGallery(PresentationTheme, String)
    case selectFromFiles(PresentationTheme, String)
    
    case recentHeader(PresentationTheme, String)
    case file(Int32, PresentationTheme, Message?)
  
    var section: ItemListSectionId {
        switch self {
            case .selectFromGallery, .selectFromFiles:
                return AttachmentFileSection.select.rawValue
            case .recentHeader, .file:
                return AttachmentFileSection.recent.rawValue
        }
    }
    
    var stableId: Int32 {
        switch self {
            case .selectFromGallery:
                return 0
            case .selectFromFiles:
                return 1
            case .recentHeader:
                return 2
            case let .file(index, _, _):
                return 3 + index
        }
    }
    
    static func ==(lhs: AttachmentFileEntry, rhs: AttachmentFileEntry) -> Bool {
        switch lhs {
            case let .selectFromGallery(lhsTheme, lhsText):
                if case let .selectFromGallery(rhsTheme, rhsText) = rhs, lhsTheme === rhsTheme, lhsText == rhsText {
                    return true
                } else {
                    return false
                }
            case let .selectFromFiles(lhsTheme, lhsText):
                if case let .selectFromFiles(rhsTheme, rhsText) = rhs, lhsTheme === rhsTheme, lhsText == rhsText {
                    return true
                } else {
                    return false
                }
            case let .recentHeader(lhsTheme, lhsText):
                if case let .recentHeader(rhsTheme, rhsText) = rhs, lhsTheme === rhsTheme, lhsText == rhsText {
                    return true
                } else {
                    return false
                }
            case let .file(lhsIndex, lhsTheme, lhsMessage):
                if case let .file(rhsIndex, rhsTheme, rhsMessage) = rhs, lhsIndex == rhsIndex, lhsTheme === rhsTheme, areMessagesEqual(lhsMessage, rhsMessage) {
                    return true
                } else {
                    return false
                }
        }
    }
    
    static func <(lhs: AttachmentFileEntry, rhs: AttachmentFileEntry) -> Bool {
        return lhs.stableId < rhs.stableId
    }
    
    func item(presentationData: ItemListPresentationData, arguments: Any) -> ListViewItem {
        let arguments = arguments as! AttachmentFileControllerArguments
        switch self {
            case let .selectFromGallery(_, text):
                return ItemListPeerActionItem(presentationData: presentationData, icon: PresentationResourcesItemList.imageIcon(presentationData.theme), title: text, alwaysPlain: false, sectionId: self.section, height: .generic, editing: false, action: {
                    arguments.openGallery()
                })
            case let .selectFromFiles(_, text):
                return ItemListPeerActionItem(presentationData: presentationData, icon: PresentationResourcesItemList.cloudIcon(presentationData.theme), title: text, alwaysPlain: false, sectionId: self.section, height: .generic, editing: false, action: {
                    arguments.openFiles()
                })
            case let .recentHeader(_, text):
                return ItemListSectionHeaderItem(presentationData: presentationData, text: text, sectionId: self.section)
            case let .file(_, _, message):
                let interaction = ListMessageItemInteraction(openMessage: { message, _ in
                    arguments.send(message)
                    return false
                }, openMessageContextMenu: { _, _, _, _, _ in }, toggleMessagesSelection: { _, _ in }, openUrl: { _, _, _, _ in }, openInstantPage: { _, _ in }, longTap: { _, _ in }, getHiddenMedia: { return [:] })
            
                let dateTimeFormat = arguments.context.sharedContext.currentPresentationData.with({$0}).dateTimeFormat
                let chatPresentationData = ChatPresentationData(theme: ChatPresentationThemeData(theme: presentationData.theme, wallpaper: .color(0)), fontSize: presentationData.fontSize, strings: presentationData.strings, dateTimeFormat: dateTimeFormat, nameDisplayOrder: .firstLast, disableAnimations: false, largeEmoji: false, chatBubbleCorners: PresentationChatBubbleCorners(mainRadius: 0, auxiliaryRadius: 0, mergeBubbleCorners: false))
            
                return ListMessageItem(presentationData: chatPresentationData, context: arguments.context, chatLocation: .peer(id: PeerId(0)), interaction: interaction, message: message, selection: .none, displayHeader: false, displayFileInfo: false, displayBackground: true, style: .blocks)
        }
    }
}

private func attachmentFileControllerEntries(presentationData: PresentationData, recentDocuments: [Message]?, empty: Bool) -> [AttachmentFileEntry] {
    guard !empty else {
        return []
    }
    var entries: [AttachmentFileEntry] = []
    entries.append(.selectFromGallery(presentationData.theme, presentationData.strings.Attachment_SelectFromGallery))
    entries.append(.selectFromFiles(presentationData.theme, presentationData.strings.Attachment_SelectFromFiles))
    
    if let recentDocuments = recentDocuments {
        if recentDocuments.count > 0 {
            entries.append(.recentHeader(presentationData.theme, presentationData.strings.Attachment_RecentlySentFiles.uppercased()))
            var i: Int32 = 0
            for file in recentDocuments {
                entries.append(.file(i, presentationData.theme, file))
                i += 1
            }
        }
    } else {
        entries.append(.recentHeader(presentationData.theme, presentationData.strings.Attachment_RecentlySentFiles.uppercased()))
        for i in 0 ..< 11 {
            entries.append(.file(Int32(i), presentationData.theme, nil))
        }
    }

    return entries
}

private class AttachmentFileControllerImpl: ItemListController, AttachmentContainable {
    public var requestAttachmentMenuExpansion: () -> Void = {}
    public var updateNavigationStack: (@escaping ([AttachmentContainable]) -> ([AttachmentContainable], AttachmentMediaPickerContext?)) -> Void = { _ in }
    public var updateTabBarAlpha: (CGFloat, ContainedViewLayoutTransition) -> Void = { _, _ in }
    public var cancelPanGesture: () -> Void = { }
    public var isContainerPanning: () -> Bool = { return false }
    public var isContainerExpanded: () -> Bool = { return false }
    
    var delayDisappear = false
    
    var resetForReuseImpl: () -> Void = {}
    public func resetForReuse() {
        self.resetForReuseImpl()
        self.scrollToTop?()
    }
    
    public func prepareForReuse() {
        self.delayDisappear = true
        self.visibleBottomContentOffsetChanged?(self.visibleBottomContentOffset)
        self.delayDisappear = false
    }
}

private struct AttachmentFileControllerState: Equatable {
    var searching: Bool
}

public func attachmentFileController(context: AccountContext, updatedPresentationData: (initial: PresentationData, signal: Signal<PresentationData, NoError>)? = nil, bannedSendMedia: (Int32, Bool)?, presentGallery: @escaping () -> Void, presentFiles: @escaping () -> Void, send: @escaping (AnyMediaReference) -> Void) -> AttachmentContainable {
    let actionsDisposable = DisposableSet()
    
    let statePromise = ValuePromise(AttachmentFileControllerState(searching: false), ignoreRepeated: true)
    let stateValue = Atomic(value: AttachmentFileControllerState(searching: false))
    let updateState: ((AttachmentFileControllerState) -> AttachmentFileControllerState) -> Void = { f in
        statePromise.set(stateValue.modify { f($0) })
    }
    
    var expandImpl: (() -> Void)?
    var dismissImpl: (() -> Void)?
    var dismissInputImpl: (() -> Void)?
    let arguments = AttachmentFileControllerArguments(
        context: context,
        openGallery: {
            presentGallery()
        },
        openFiles: {
            presentFiles()
        },
        send: { message in
            let _ = (context.engine.messages.getMessagesLoadIfNecessary([message.id], strategy: .cloud(skipLocal: true))
            |> deliverOnMainQueue).start(next: { messages in
                if let message = messages.first, let file = message.media.first(where: { $0 is TelegramMediaFile }) as? TelegramMediaFile {
                    send(.message(message: MessageReference(message), media: file))
                }
                dismissImpl?()
            })
        }
    )
    
    let recentDocuments: Signal<[Message]?, NoError> = .single(nil)
    |> then(
        context.engine.messages.searchMessages(location: .sentMedia(tags: [.file]), query: "", state: nil)
        |> map { result -> [Message]? in
            return result.0.messages
        }
    )
    
    let presentationData = updatedPresentationData?.signal ?? context.sharedContext.presentationData

    let previousRecentDocuments = Atomic<[Message]?>(value: nil)
    let signal = combineLatest(queue: Queue.mainQueue(),
       presentationData,
       recentDocuments,
       statePromise.get()
    )
    |> map { presentationData, recentDocuments, state -> (ItemListControllerState, (ItemListNodeState, Any)) in
        var presentationData = presentationData
        if presentationData.theme.list.blocksBackgroundColor.rgb == presentationData.theme.list.plainBackgroundColor.rgb {
            let updatedTheme = presentationData.theme.withModalBlocksBackground()
            presentationData = presentationData.withUpdated(theme: updatedTheme)
        }
        
        let previousRecentDocuments = previousRecentDocuments.swap(recentDocuments)
        let crossfade = previousRecentDocuments == nil && recentDocuments != nil
        var animateChanges = false
        if let previousRecentDocuments = previousRecentDocuments, let recentDocuments = recentDocuments, !previousRecentDocuments.isEmpty && !recentDocuments.isEmpty, !crossfade {
            animateChanges = true
        }
        
        var rightNavigationButton: ItemListNavigationButton?
        if bannedSendMedia == nil && (recentDocuments == nil || (recentDocuments?.count ?? 0) > 10) {
            rightNavigationButton = ItemListNavigationButton(content: .icon(.search), style: .regular, enabled: true, action: {
                updateState { state in
                    var updatedState = state
                    updatedState.searching = true
                    return updatedState
                }
            })
        }
        
        let controllerState = ItemListControllerState(presentationData: ItemListPresentationData(presentationData), title: .text(presentationData.strings.Attachment_File), leftNavigationButton: ItemListNavigationButton(content: .text(presentationData.strings.Common_Cancel), style: .regular, enabled: true, action: {
            dismissImpl?()
        }), rightNavigationButton: rightNavigationButton, backNavigationButton: ItemListBackButton(title: presentationData.strings.Common_Back), animateChanges: true)
        
        var emptyItem: AttachmentFileEmptyStateItem?
        if let (untilDate, personal) = bannedSendMedia {
            let banDescription: String
            if untilDate != 0 && untilDate != Int32.max {
                banDescription = presentationData.strings.Conversation_RestrictedMediaTimed(stringForFullDate(timestamp: untilDate, strings: presentationData.strings, dateTimeFormat: presentationData.dateTimeFormat)).string
            } else if personal {
                banDescription = presentationData.strings.Conversation_RestrictedMedia
            } else {
                banDescription = presentationData.strings.Conversation_DefaultRestrictedMedia
            }
            emptyItem = AttachmentFileEmptyStateItem(context: context, theme: presentationData.theme, strings: presentationData.strings, content: .bannedSendMedia(banDescription))
        } else if let recentDocuments = recentDocuments, recentDocuments.isEmpty {
            emptyItem = AttachmentFileEmptyStateItem(context: context, theme: presentationData.theme, strings: presentationData.strings, content: .intro)
        }
        
        var searchItem: ItemListControllerSearch?
        if state.searching {
            searchItem = AttachmentFileSearchItem(context: context, presentationData: presentationData, focus: {
                expandImpl?()
            }, cancel: {
                updateState { state in
                    var updatedState = state
                    updatedState.searching = false
                    return updatedState
                }
            }, send: { message in
                arguments.send(message)
            }, dismissInput: {
                dismissInputImpl?()
            })
        }
        
        let listState = ItemListNodeState(presentationData: ItemListPresentationData(presentationData), entries: attachmentFileControllerEntries(presentationData: presentationData, recentDocuments: recentDocuments, empty: bannedSendMedia != nil), style: .blocks, emptyStateItem: emptyItem, searchItem: searchItem, crossfadeState: crossfade, animateChanges: animateChanges)
        
        return (controllerState, (listState, arguments))
    } |> afterDisposed {
        actionsDisposable.dispose()
    }
    
    let controller = AttachmentFileControllerImpl(context: context, state: signal)
    controller.delayDisappear = true
    controller.visibleBottomContentOffsetChanged = { [weak controller] offset in
        switch offset {
            case let .known(value):
                let backgroundAlpha: CGFloat = min(30.0, max(0.0, value)) / 30.0
                if backgroundAlpha.isZero && controller?.delayDisappear == true {
                    Queue.mainQueue().after(0.25, {
                        controller?.updateTabBarAlpha(backgroundAlpha, .animated(duration: 0.1, curve: .easeInOut))
                    })
                } else {
                    controller?.updateTabBarAlpha(backgroundAlpha, .immediate)
                }
            case .unknown, .none:
                controller?.updateTabBarAlpha(1.0, .immediate)
                controller?.delayDisappear = false
        }
    }
    controller.resetForReuseImpl = {
        updateState { state in
            var updatedState = state
            updatedState.searching = false
            return updatedState
        }
    }
    dismissImpl = { [weak controller] in
        controller?.dismiss(animated: true)
    }
    dismissInputImpl = { [weak controller] in
        controller?.view.endEditing(true)
    }
    expandImpl = { [weak controller] in
        controller?.requestAttachmentMenuExpansion()
    }
    return controller
}
