import Foundation
import TelegramPresentationData
import AccountContext
import Postbox
import TelegramCore
import SwiftSignalKit
import Display
import TelegramPresentationData
import PresentationDataUtils
import UndoUI
import AdminUserActionsSheet
import ContextUI
import TelegramStringFormatting
import StorageUsageScreen
import SettingsUI
import DeleteChatPeerActionSheetItem
import OverlayStatusController

fileprivate struct InitialBannedRights {
    var value: TelegramChatBannedRights?
}

extension ChatControllerImpl {
    fileprivate func applyAdminUserActionsResult(messageIds: Set<MessageId>, result: AdminUserActionsSheet.Result, initialUserBannedRights: [EnginePeer.Id: InitialBannedRights]) {
        guard let messagesPeerId = self.chatLocation.peerId else {
            return
        }
        guard let banLocationPeerId = self.presentationInterfaceState.renderedPeer?.chatOrMonoforumMainPeer?.id else {
            return
        }
        
        
        var title: String? = messageIds.count == 1 ? self.presentationData.strings.Chat_AdminAction_ToastMessagesDeletedTitleSingle : self.presentationData.strings.Chat_AdminAction_ToastMessagesDeletedTitleMultiple
        if !result.deleteAllFromPeers.isEmpty {
            title = self.presentationData.strings.Chat_AdminAction_ToastMessagesDeletedTitleMultiple
        }
        var text: String = ""
        var undoRights: [EnginePeer.Id: InitialBannedRights] = [:]
        
        if !result.reportSpamPeers.isEmpty {
            if !text.isEmpty {
                text.append("\n")
            }
            text.append(self.presentationData.strings.Chat_AdminAction_ToastReportedSpamText(Int32(result.reportSpamPeers.count)))
        }
        if !result.banPeers.isEmpty {
            if !text.isEmpty {
                text.append("\n")
            }
            text.append(self.presentationData.strings.Chat_AdminAction_ToastBannedText(Int32(result.banPeers.count)))
            for id in result.banPeers {
                if let value = initialUserBannedRights[id] {
                    undoRights[id] = value
                }
            }
        }
        if !result.updateBannedRights.isEmpty {
            if !text.isEmpty {
                text.append("\n")
            }
            text.append(self.presentationData.strings.Chat_AdminAction_ToastRestrictedText(Int32(result.updateBannedRights.count)))
            for (id, _) in result.updateBannedRights {
                if let value = initialUserBannedRights[id] {
                    undoRights[id] = value
                }
            }
        }
        
        do {
            let _ = self.context.engine.messages.deleteMessagesInteractively(messageIds: Array(messageIds), type: .forEveryone).startStandalone()
            
            for authorId in result.deleteAllFromPeers {
                let _ = self.context.engine.messages.deleteAllMessagesWithAuthor(peerId: messagesPeerId, authorId: authorId, namespace: Namespaces.Message.Cloud).startStandalone()
                let _ = self.context.engine.messages.clearAuthorHistory(peerId: messagesPeerId, memberId: authorId).startStandalone()
            }
            
            for authorId in result.reportSpamPeers {
                let _ = self.context.engine.peers.reportPeer(peerId: authorId, reason: .spam, message: "").startStandalone()
            }
            
            for authorId in result.banPeers {
                let _ = self.context.engine.peers.removePeerMember(peerId: banLocationPeerId, memberId: authorId).startStandalone()
            }
            
            for (authorId, rights) in result.updateBannedRights {
                let _ = self.context.engine.peers.updateChannelMemberBannedRights(peerId: banLocationPeerId, memberId: authorId, rights: rights).startStandalone()
            }
        }
        
        if text.isEmpty {
            text = messageIds.count == 1 ? self.presentationData.strings.Chat_AdminAction_ToastMessagesDeletedTextSingle : self.presentationData.strings.Chat_AdminAction_ToastMessagesDeletedTextMultiple
            if !result.deleteAllFromPeers.isEmpty {
                text = self.presentationData.strings.Chat_AdminAction_ToastMessagesDeletedTextMultiple
            }
            title = nil
        }
        
        self.present(
            UndoOverlayController(
                presentationData: self.presentationData,
                content: undoRights.isEmpty ? .actionSucceeded(title: title, text: text, cancel: nil, destructive: false) : .removedChat(context: self.context, title: NSAttributedString(string: title ?? text), text: title == nil ? nil : text),
                elevatedLayout: false,
                action: { [weak self] action in
                    guard let self else {
                        return true
                    }
                    
                    switch action {
                    case .commit:
                        break
                    case .undo:
                        for (authorId, rights) in initialUserBannedRights {
                            let _ = self.context.engine.peers.updateChannelMemberBannedRights(peerId: banLocationPeerId, memberId: authorId, rights: rights.value).startStandalone()
                        }
                    default:
                        break
                    }
                    return true
                }
            ),
            in: .current
        )
        
        self.updateChatPresentationInterfaceState(animated: true, interactive: true, { $0.updatedInterfaceState { $0.withoutSelectionState() } })
    }
    
    func presentMultiBanMessageOptions(accountPeerId: PeerId, authors: [Peer], messageIds: Set<MessageId>, options: ChatAvailableMessageActionOptions) {
        guard let peerId = self.chatLocation.peerId else {
            return
        }
        
        var deleteAllMessageCount: Signal<Int?, NoError> = .single(nil)
        if authors.count == 1 {
            deleteAllMessageCount = self.context.engine.messages.searchMessages(location: .peer(peerId: peerId, fromId: authors[0].id, tags: nil, reactions: nil, threadId: self.chatLocation.threadId, minDate: nil, maxDate: nil), query: "", state: nil)
            |> map { result, _ -> Int? in
                return Int(result.totalCount)
            }
        }
        
        var signal = combineLatest(authors.map { author in
            self.context.engine.peers.fetchChannelParticipant(peerId: peerId, participantId: author.id)
            |> map { result -> (Peer, ChannelParticipant?) in
                return (author, result)
            }
        })
        let disposables = MetaDisposable()
        self.navigationActionDisposable.set(disposables)
        
        var cancelImpl: (() -> Void)?
        let presentationData = self.context.sharedContext.currentPresentationData.with { $0 }
        let progressSignal = Signal<Never, NoError> { [weak self] subscriber in
            let controller = OverlayStatusController(theme: presentationData.theme, type: .loading(cancelled: {
                cancelImpl?()
            }))
            self?.present(controller, in: .window(.root), with: ViewControllerPresentationArguments(presentationAnimation: .modalSheet))
            return ActionDisposable { [weak controller] in
                Queue.mainQueue().async() {
                    controller?.dismiss()
                }
            }
        }
        |> runOn(Queue.mainQueue())
        |> delay(0.3, queue: Queue.mainQueue())
        let progressDisposable = progressSignal.startStrict()
        
        signal = signal
        |> afterDisposed {
            Queue.mainQueue().async {
                progressDisposable.dispose()
            }
        }
        cancelImpl = {
            disposables.set(nil)
        }
        
        disposables.set((combineLatest(signal, deleteAllMessageCount)
        |> deliverOnMainQueue).startStrict(next: { [weak self] authorsAndParticipants, deleteAllMessageCount in
            guard let self else {
                return
            }
            let _ = (self.context.engine.data.get(
                TelegramEngine.EngineData.Item.Peer.Peer(id: peerId)
            )
            |> deliverOnMainQueue).startStandalone(next: { [weak self] chatPeer in
                guard let self, let chatPeer else {
                    return
                }
                var renderedParticipants: [RenderedChannelParticipant] = []
                var initialUserBannedRights: [EnginePeer.Id: InitialBannedRights] = [:]
                for (author, maybeParticipant) in authorsAndParticipants {
                    let participant: ChannelParticipant
                    if let maybeParticipant {
                        participant = maybeParticipant
                    } else {
                        participant = .member(id: author.id, invitedAt: 0, adminInfo: nil, banInfo: ChannelParticipantBannedInfo(
                            rights: TelegramChatBannedRights(
                                flags: [.banReadMessages],
                                untilDate: Int32.max
                            ),
                            restrictedBy: self.context.account.peerId,
                            timestamp: 0,
                            isMember: false
                        ), rank: nil, subscriptionUntilDate: nil)
                    }
                    
                    let peer = author
                    renderedParticipants.append(RenderedChannelParticipant(
                        participant: participant,
                        peer: peer
                    ))
                    switch participant {
                    case .creator:
                        break
                    case let .member(_, _, _, banInfo, _, _):
                        if let banInfo {
                            initialUserBannedRights[participant.peerId] = InitialBannedRights(value: banInfo.rights)
                        } else {
                            initialUserBannedRights[participant.peerId] = InitialBannedRights(value: nil)
                        }
                    }
                }
                self.push(AdminUserActionsSheet(
                    context: self.context,
                    chatPeer: chatPeer,
                    peers: renderedParticipants,
                    messageCount: messageIds.count,
                    deleteAllMessageCount: deleteAllMessageCount,
                    completion: { [weak self] result in
                        guard let self else {
                            return
                        }
                        self.applyAdminUserActionsResult(messageIds: messageIds, result: result, initialUserBannedRights: initialUserBannedRights)
                    }
                ))
            })
        }))
    }
    
    func presentBanMessageOptions(accountPeerId: PeerId, author: Peer, messageIds: Set<MessageId>, options: ChatAvailableMessageActionOptions) {
        guard let peerId = self.chatLocation.peerId else {
            return
        }
        
        var signal = self.context.engine.peers.fetchChannelParticipant(peerId: peerId, participantId: author.id)
        let disposables = MetaDisposable()
        self.navigationActionDisposable.set(disposables)
        
        var cancelImpl: (() -> Void)?
        let presentationData = self.context.sharedContext.currentPresentationData.with { $0 }
        let progressSignal = Signal<Never, NoError> { [weak self] subscriber in
            let controller = OverlayStatusController(theme: presentationData.theme, type: .loading(cancelled: {
                cancelImpl?()
            }))
            self?.present(controller, in: .window(.root), with: ViewControllerPresentationArguments(presentationAnimation: .modalSheet))
            return ActionDisposable { [weak controller] in
                Queue.mainQueue().async() {
                    controller?.dismiss()
                }
            }
        }
        |> runOn(Queue.mainQueue())
        |> delay(0.3, queue: Queue.mainQueue())
        let progressDisposable = progressSignal.startStrict()
        
        signal = signal
        |> afterDisposed {
            Queue.mainQueue().async {
                progressDisposable.dispose()
            }
        }
        cancelImpl = {
            disposables.set(nil)
        }
        
        var deleteAllMessageCount: Signal<Int?, NoError> = .single(nil)
        do {
            deleteAllMessageCount = self.context.engine.messages.getSearchMessageCount(location: .peer(peerId: peerId, fromId: author.id, tags: nil, reactions: nil, threadId: self.chatLocation.threadId, minDate: nil, maxDate: nil), query: "")
            |> map { result -> Int? in
                return result
            }
        }
        
        disposables.set((combineLatest(signal, deleteAllMessageCount)
        |> deliverOnMainQueue).startStrict(next: { [weak self] maybeParticipant, deleteAllMessageCount in
            guard let self else {
                return
            }
            
            let participant: ChannelParticipant
            if let maybeParticipant {
                participant = maybeParticipant
            } else {
                participant = .member(id: author.id, invitedAt: 0, adminInfo: nil, banInfo: ChannelParticipantBannedInfo(
                    rights: TelegramChatBannedRights(
                        flags: [.banReadMessages],
                        untilDate: Int32.max
                    ),
                    restrictedBy: self.context.account.peerId,
                    timestamp: 0,
                    isMember: false
                ), rank: nil, subscriptionUntilDate: nil)
            }
            
            let _ = (self.context.engine.data.get(
                TelegramEngine.EngineData.Item.Peer.Peer(id: peerId),
                TelegramEngine.EngineData.Item.Peer.Peer(id: author.id)
            )
            |> deliverOnMainQueue).startStandalone(next: { [weak self] chatPeer, authorPeer in
                guard let self, let chatPeer else {
                    return
                }
                guard let authorPeer else {
                    return
                }
                var initialUserBannedRights: [EnginePeer.Id: InitialBannedRights] = [:]
                switch participant {
                case .creator:
                    break
                case let .member(_, _, _, banInfo, _, _):
                    if let banInfo {
                        initialUserBannedRights[participant.peerId] = InitialBannedRights(value: banInfo.rights)
                    } else {
                        initialUserBannedRights[participant.peerId] = InitialBannedRights(value: nil)
                    }
                }
                self.push(AdminUserActionsSheet(
                    context: self.context,
                    chatPeer: chatPeer,
                    peers: [RenderedChannelParticipant(
                        participant: participant,
                        peer: authorPeer._asPeer()
                    )],
                    messageCount: messageIds.count,
                    deleteAllMessageCount: deleteAllMessageCount,
                    completion: { [weak self] result in
                        guard let self else {
                            return
                        }
                        self.applyAdminUserActionsResult(messageIds: messageIds, result: result, initialUserBannedRights: initialUserBannedRights)
                    }
                ))
            })
        }))
    }
    
    func beginDeleteMessagesWithUndo(messageIds: Set<MessageId>, type: InteractiveMessagesDeletionType) {
        var deleteImmediately = false
        if case .forEveryone = type {
            deleteImmediately = true
        } else if case .scheduledMessages = self.presentationInterfaceState.subject {
            deleteImmediately = true
        } else if case .peer(self.context.account.peerId) = self.chatLocation {
            deleteImmediately = true
        }
        
        if deleteImmediately {
            let _ = self.context.engine.messages.deleteMessagesInteractively(messageIds: Array(messageIds), type: type).startStandalone()
            return
        }
        
        self.chatDisplayNode.historyNode.ignoreMessageIds = Set(messageIds)
        
        let undoTitle = self.presentationData.strings.Chat_MessagesDeletedToast_Text(Int32(messageIds.count))
        self.present(UndoOverlayController(presentationData: self.context.sharedContext.currentPresentationData.with { $0 }, content: .removedChat(context: self.context, title: NSAttributedString(string: undoTitle), text: nil), elevatedLayout: false, position: .top, action: { [weak self] value in
            guard let self else {
                return false
            }
            if value == .commit {
                let _ = self.context.engine.messages.deleteMessagesInteractively(messageIds: Array(messageIds), type: type).startStandalone()
                return true
            } else if value == .undo {
                self.chatDisplayNode.historyNode.ignoreMessageIds = Set()
                return true
            }
            return false
        }), in: .current)
    }
    
    func presentDeleteMessageOptions(messageIds: Set<MessageId>, options: ChatAvailableMessageActionOptions, contextController: ContextControllerProtocol?, completion: @escaping (ContextMenuActionResult) -> Void) {
        let _ = (self.context.engine.data.get(
            EngineDataMap(messageIds.map(TelegramEngine.EngineData.Item.Messages.Message.init(id:)))
        )
        |> deliverOnMainQueue).start(next: { [weak self] messages in
            guard let self else {
                return
            }
            
            let actionSheet = ActionSheetController(presentationData: self.presentationData)
            var items: [ActionSheetItem] = []
            var personalPeerName: String?
            var isChannel = false
            if let user = self.presentationInterfaceState.renderedPeer?.peer as? TelegramUser {
                personalPeerName = EnginePeer(user).compactDisplayTitle
            } else if let peer = self.presentationInterfaceState.renderedPeer?.peer as? TelegramSecretChat, let associatedPeerId = peer.associatedPeerId, let user = self.presentationInterfaceState.renderedPeer?.peers[associatedPeerId] as? TelegramUser {
                personalPeerName = EnginePeer(user).compactDisplayTitle
            } else if let channel = self.presentationInterfaceState.renderedPeer?.peer as? TelegramChannel, case .broadcast = channel.info {
                isChannel = true
            }
            
            if options.contains(.cancelSending) {
                items.append(ActionSheetButtonItem(title: self.presentationData.strings.Conversation_ContextMenuCancelSending, color: .destructive, action: { [weak self, weak actionSheet] in
                    actionSheet?.dismissAnimated()
                    if let strongSelf = self {
                        strongSelf.updateChatPresentationInterfaceState(animated: true, interactive: true, { $0.updatedInterfaceState { $0.withoutSelectionState() } })
                        strongSelf.beginDeleteMessagesWithUndo(messageIds: messageIds, type: .forEveryone)
                    }
                }))
            }
            
            var contextItems: [ContextMenuItem] = []
            var canDisplayContextMenu = true
            
            var unsendPersonalMessages = false
            if options.contains(.unsendPersonal) {
                canDisplayContextMenu = false
                items.append(ActionSheetTextItem(title: self.presentationData.strings.Chat_UnsendMyMessagesAlertTitle(personalPeerName ?? "").string))
                items.append(ActionSheetSwitchItem(title: self.presentationData.strings.Chat_UnsendMyMessages, isOn: false, action: { value in
                    unsendPersonalMessages = value
                }))
            } else if options.contains(.deleteGlobally) {
                let globalTitle: String
                if isChannel {
                    globalTitle = self.presentationData.strings.Conversation_DeleteMessagesForEveryone
                } else if let personalPeerName = personalPeerName {
                    globalTitle = self.presentationData.strings.Conversation_DeleteMessagesFor(personalPeerName).string
                } else {
                    globalTitle = self.presentationData.strings.Conversation_DeleteMessagesForEveryone
                }
                contextItems.append(.action(ContextMenuActionItem(text: globalTitle, textColor: .destructive, icon: { _ in nil }, action: { [weak self] c, f in
                    if let strongSelf = self {
                        var giveaway: TelegramMediaGiveaway?
                        for messageId in messageIds {
                            if let message = strongSelf.chatDisplayNode.historyNode.messageInCurrentHistoryView(messageId) {
                                if let media = message.media.first(where: { $0 is TelegramMediaGiveaway }) as? TelegramMediaGiveaway {
                                    giveaway = media
                                    break
                                }
                            }
                        }
                        let commit = {
                            strongSelf.updateChatPresentationInterfaceState(animated: true, interactive: true, { $0.updatedInterfaceState { $0.withoutSelectionState() } })
                            
                            strongSelf.beginDeleteMessagesWithUndo(messageIds: messageIds, type: .forEveryone)
                        }
                        if let giveaway {
                            let currentTime = Int32(CFAbsoluteTimeGetCurrent() + kCFAbsoluteTimeIntervalSince1970)
                            if currentTime < giveaway.untilDate {
                                Queue.mainQueue().after(0.2) {
                                    let dateString = stringForDate(timestamp: giveaway.untilDate, timeZone: .current, strings: strongSelf.presentationData.strings)
                                    strongSelf.present(textAlertController(context: strongSelf.context, updatedPresentationData: strongSelf.updatedPresentationData, title: strongSelf.presentationData.strings.Chat_Giveaway_DeleteConfirmation_Title, text: strongSelf.presentationData.strings.Chat_Giveaway_DeleteConfirmation_Text(dateString).string, actions: [TextAlertAction(type: .destructiveAction, title: strongSelf.presentationData.strings.Common_Delete, action: {
                                        commit()
                                    }), TextAlertAction(type: .defaultAction, title: strongSelf.presentationData.strings.Common_Cancel, action: {
                                    })], parseMarkdown: true), in: .window(.root))
                                }
                                f(.default)
                            } else {
                                f(.dismissWithoutContent)
                                commit()
                            }
                        } else {
                            if "".isEmpty {
                                f(.dismissWithoutContent)
                                commit()
                            } else {
                                c?.dismiss(completion: {
                                    DispatchQueue.main.asyncAfter(deadline: DispatchTime.now() + 0.1, execute: {
                                        commit()
                                    })
                                })
                            }
                        }
                    }
                })))
                items.append(ActionSheetButtonItem(title: globalTitle, color: .destructive, action: { [weak self, weak actionSheet] in
                    actionSheet?.dismissAnimated()
                    if let strongSelf = self {
                        strongSelf.updateChatPresentationInterfaceState(animated: true, interactive: true, { $0.updatedInterfaceState { $0.withoutSelectionState() } })
                        
                        strongSelf.beginDeleteMessagesWithUndo(messageIds: messageIds, type: .forEveryone)
                    }
                }))
            }
            if options.contains(.deleteLocally) {
                var localOptionText = self.presentationData.strings.Conversation_DeleteMessagesForMe
                if self.chatLocation.peerId == self.context.account.peerId {
                    if case .peer(self.context.account.peerId) = self.chatLocation, messages.values.allSatisfy({ message in message?._asMessage().effectivelyIncoming(self.context.account.peerId) ?? false }) {
                        localOptionText = self.presentationData.strings.Chat_ConfirmationRemoveFromSavedMessages
                    } else {
                        localOptionText = self.presentationData.strings.Chat_ConfirmationDeleteFromSavedMessages
                    }
                } else if case .scheduledMessages = self.presentationInterfaceState.subject {
                    localOptionText = messageIds.count > 1 ? self.presentationData.strings.ScheduledMessages_DeleteMany : self.presentationData.strings.ScheduledMessages_Delete
                } else {
                    if options.contains(.unsendPersonal) {
                        localOptionText = self.presentationData.strings.Chat_DeleteMessagesConfirmation(Int32(messageIds.count))
                    } else if case .peer(self.context.account.peerId) = self.chatLocation {
                        if messageIds.count == 1 {
                            localOptionText = self.presentationData.strings.Conversation_Moderate_Delete
                        } else {
                            localOptionText = self.presentationData.strings.Conversation_DeleteManyMessages
                        }
                    }
                }
                contextItems.append(.action(ContextMenuActionItem(text: localOptionText, textColor: .destructive, icon: { _ in nil }, action: { [weak self] c, f in
                    if let strongSelf = self {
                        strongSelf.updateChatPresentationInterfaceState(animated: true, interactive: true, { $0.updatedInterfaceState { $0.withoutSelectionState() } })
                        
                        let commit: () -> Void = {
                            guard let strongSelf = self else {
                                return
                            }
                            strongSelf.beginDeleteMessagesWithUndo(messageIds: messageIds, type: unsendPersonalMessages ? .forEveryone : .forLocalPeer)
                        }
                        
                        if "".isEmpty {
                            f(.dismissWithoutContent)
                            commit()
                        } else {
                            c?.dismiss(completion: {
                                DispatchQueue.main.asyncAfter(deadline: DispatchTime.now() + 0.1, execute: {
                                    commit()
                                })
                            })
                        }
                    }
                })))
                items.append(ActionSheetButtonItem(title: localOptionText, color: .destructive, action: { [weak self, weak actionSheet] in
                    actionSheet?.dismissAnimated()
                    if let strongSelf = self {
                        strongSelf.updateChatPresentationInterfaceState(animated: true, interactive: true, { $0.updatedInterfaceState { $0.withoutSelectionState() } })
                        
                        strongSelf.beginDeleteMessagesWithUndo(messageIds: messageIds, type: unsendPersonalMessages ? .forEveryone : .forLocalPeer)
                    }
                }))
            }
            
            if canDisplayContextMenu, let contextController = contextController {
                contextController.setItems(.single(ContextController.Items(content: .list(contextItems))), minHeight: nil, animated: true)
            } else {
                actionSheet.setItemGroups([ActionSheetItemGroup(items: items), ActionSheetItemGroup(items: [
                    ActionSheetButtonItem(title: self.presentationData.strings.Common_Cancel, color: .accent, font: .bold, action: { [weak actionSheet] in
                        actionSheet?.dismissAnimated()
                    })
                ])])
                
                if let contextController = contextController {
                    contextController.dismiss(completion: { [weak self] in
                        self?.present(actionSheet, in: .window(.root))
                    })
                } else {
                    self.chatDisplayNode.dismissInput()
                    self.present(actionSheet, in: .window(.root))
                    completion(.default)
                }
            }
        })
    }
    
    func presentClearCacheSuggestion() {
        guard let peer = self.presentationInterfaceState.renderedPeer?.peer else {
            return
        }
        self.updateChatPresentationInterfaceState(animated: true, interactive: true, { $0.updatedInterfaceState({ $0.withoutSelectionState() }) })
        
        let actionSheet = ActionSheetController(presentationData: self.presentationData)
        var items: [ActionSheetItem] = []
        
        items.append(DeleteChatPeerActionSheetItem(context: self.context, peer: EnginePeer(peer), chatPeer: EnginePeer(peer), action: .clearCacheSuggestion, strings: self.presentationData.strings, nameDisplayOrder: self.presentationData.nameDisplayOrder))
        
        var presented = false
        items.append(ActionSheetButtonItem(title: self.presentationData.strings.ClearCache_FreeSpace, color: .accent, action: { [weak self, weak actionSheet] in
           actionSheet?.dismissAnimated()
            if let strongSelf = self, !presented {
                presented = true
                let context = strongSelf.context
                strongSelf.push(StorageUsageScreen(context: context, makeStorageUsageExceptionsScreen: { category in
                    return storageUsageExceptionsScreen(context: context, category: category)
                }))
           }
        }))
    
        actionSheet.setItemGroups([ActionSheetItemGroup(items: items), ActionSheetItemGroup(items: [
            ActionSheetButtonItem(title: self.presentationData.strings.Common_Cancel, color: .accent, font: .bold, action: { [weak actionSheet] in
                actionSheet?.dismissAnimated()
            })
        ])])
        self.chatDisplayNode.dismissInput()
        self.presentInGlobalOverlay(actionSheet)
    }
}
