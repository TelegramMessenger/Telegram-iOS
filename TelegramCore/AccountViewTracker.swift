import Foundation
import Postbox
import SwiftSignalKit
import MtProtoKit

private func pendingWebpages(entries: [MessageHistoryEntry]) -> Set<MessageId> {
    var messageIds = Set<MessageId>()
    for case let .MessageEntry(message, _) in entries {
        for media in message.media {
            if let media = media as? TelegramMediaWebpage {
                if case .Pending = media.content {
                    messageIds.insert(message.id)
                }
                break
            }
        }
    }
    return messageIds
}

private func fetchWebpage(account: Account, messageId: MessageId) -> Signal<Void, NoError> {
    return account.postbox.peerWithId(messageId.peerId)
        |> take(1)
        |> mapToSignal { peer in
            if let inputPeer = apiInputPeer(peer) {
                let messages: Signal<Api.messages.Messages, MTRpcError>
                switch inputPeer {
                    case let .inputPeerChannel(channelId, accessHash):
                        messages = account.network.request(Api.functions.channels.getMessages(channel: Api.InputChannel.inputChannel(channelId: channelId, accessHash: accessHash), id: [messageId.id]))
                    default:
                        messages = account.network.request(Api.functions.messages.getMessages(id: [messageId.id]))
                }
                return messages
                    |> retryRequest
                    |> mapToSignal { result in
                        let messages: [Api.Message]
                        let chats: [Api.Chat]
                        let users: [Api.User]
                        switch result {
                            case let .messages(messages: apiMessages, chats: apiChats, users: apiUsers):
                                messages = apiMessages
                                chats = apiChats
                                users = apiUsers
                            case let .messagesSlice(_, messages: apiMessages, chats: apiChats, users: apiUsers):
                                messages = apiMessages
                                chats = apiChats
                                users = apiUsers
                            case let .channelMessages(_, _, _, apiMessages, apiChats, apiUsers):
                                messages = apiMessages
                                chats = apiChats
                                users = apiUsers
                        }
                        
                        return account.postbox.modify { modifier -> Void in
                            var peers: [Peer] = []
                            for chat in chats {
                                let telegramGroup = TelegramGroup(chat: chat)
                                peers.append(telegramGroup)
                            }
                            for user in users {
                                let telegramUser = TelegramUser(user: user)
                                peers.append(telegramUser)
                            }
                            
                            for message in messages {
                                if let storeMessage = StoreMessage(apiMessage: message) {
                                    var webpage: TelegramMediaWebpage?
                                    for media in storeMessage.media {
                                        if let media = media as? TelegramMediaWebpage {
                                            webpage = media
                                        }
                                    }
                                    
                                    if let webpage = webpage {
                                        modifier.updateMedia(webpage.webpageId, update: webpage)
                                    } else {
                                        if let previousMessage = modifier.getMessage(messageId) {
                                            for media in previousMessage.media {
                                                if let media = media as? TelegramMediaWebpage {
                                                    modifier.updateMedia(media.webpageId, update: nil)
                                                    
                                                    break
                                                }
                                            }
                                        }
                                    }
                                    break
                                }
                            }
                            
                            modifier.updatePeers(peers, update: { _, updated -> Peer in
                                return updated
                            })
                        }
                    }
            } else {
                return .complete()
            }
        }
}

public final class AccountViewTracker {
    weak var account: Account?
    let queue = Queue()
    var nextViewId: Int32 = 0
    
    var viewPendingWebpageMessageIds: [Int32: Set<MessageId>] = [:]
    var pendingWebpageMessageIds: [MessageId: Int] = [:]
    var webpageDisposables: [MessageId: Disposable] = [:]
    
    init(account: Account) {
        self.account = account
    }
    
    deinit {
        
    }
    
    private func updatePendingWebpages(viewId: Int32, messageIds: Set<MessageId>) {
        self.queue.async {
            var addedMessageIds: [MessageId] = []
            var removedMessageIds: [MessageId] = []
            
            let viewMessageIds: Set<MessageId> = self.viewPendingWebpageMessageIds[viewId] ?? Set()
            
            let viewAddedMessageIds = messageIds.subtracting(viewMessageIds)
            let viewRemovedMessageIds = viewMessageIds.subtracting(messageIds)
            for messageId in viewAddedMessageIds {
                if let count = self.pendingWebpageMessageIds[messageId] {
                    self.pendingWebpageMessageIds[messageId] = count + 1
                } else {
                    self.pendingWebpageMessageIds[messageId] = 1
                    addedMessageIds.append(messageId)
                }
            }
            for messageId in viewRemovedMessageIds {
                if let count = self.pendingWebpageMessageIds[messageId] {
                    if count == 1 {
                        self.pendingWebpageMessageIds.removeValue(forKey: messageId)
                        removedMessageIds.append(messageId)
                    } else {
                        self.pendingWebpageMessageIds[messageId] = count - 1
                    }
                } else {
                    assertionFailure()
                }
            }
            
            if messageIds.isEmpty {
                self.viewPendingWebpageMessageIds.removeValue(forKey: viewId)
            } else {
                self.viewPendingWebpageMessageIds[viewId] = messageIds
            }
            
            for messageId in removedMessageIds {
                if let disposable = self.webpageDisposables.removeValue(forKey: messageId) {
                    disposable.dispose()
                }
            }
            
            if let account = self.account {
                for messageId in addedMessageIds {
                    if self.webpageDisposables[messageId] == nil {
                        self.webpageDisposables[messageId] = fetchWebpage(account: account, messageId: messageId).start(completed: { [weak self] in
                            if let strongSelf = self {
                                strongSelf.queue.async {
                                    strongSelf.webpageDisposables.removeValue(forKey: messageId)
                                }
                            }
                        })
                    } else {
                        assertionFailure()
                    }
                }
            }
        }
    }
    
    func wrappedMessageHistorySignal(_ signal: Signal<(MessageHistoryView, ViewUpdateType), NoError>) -> Signal<(MessageHistoryView, ViewUpdateType), NoError> {
        return withState(signal, { [weak self] () -> Int32 in
            if let strongSelf = self {
                return OSAtomicIncrement32(&strongSelf.nextViewId)
            } else {
                return -1
            }
        }, next: { [weak self] next, viewId in
            if let strongSelf = self {
                let messageIds = pendingWebpages(entries: next.0.entries)
                strongSelf.updatePendingWebpages(viewId: viewId, messageIds: messageIds)
            }
        }, disposed: { [weak self] viewId in
            if let strongSelf = self {
                strongSelf.updatePendingWebpages(viewId: viewId, messageIds: [])
            }
        })
    }
    
    public func aroundUnreadMessageHistoryViewForPeerId(_ peerId: PeerId, count: Int, tagMask: MessageTags? = nil) -> Signal<(MessageHistoryView, ViewUpdateType), NoError> {
        if let account = self.account {
            let signal = account.postbox.aroundUnreadMessageHistoryViewForPeerId(peerId, count: count, tagMask: tagMask)
            return wrappedMessageHistorySignal(signal)
        } else {
            return .never()
        }
    }
    
    public func aroundIdMessageHistoryViewForPeerId(_ peerId: PeerId, count: Int, messageId: MessageId, tagMask: MessageTags? = nil) -> Signal<(MessageHistoryView, ViewUpdateType), NoError> {
        if let account = self.account {
            let signal = account.postbox.aroundIdMessageHistoryViewForPeerId(peerId, count: count, messageId: messageId, tagMask: tagMask)
            return wrappedMessageHistorySignal(signal)
        } else {
            return .never()
        }
    }
    
    public func aroundMessageHistoryViewForPeerId(_ peerId: PeerId, index: MessageIndex, count: Int, anchorIndex: MessageIndex, fixedCombinedReadState: CombinedPeerReadState?, tagMask: MessageTags? = nil) -> Signal<(MessageHistoryView, ViewUpdateType), NoError> {
        if let account = self.account {
            let signal = account.postbox.aroundMessageHistoryViewForPeerId(peerId, index: index, count: count, anchorIndex: anchorIndex, fixedCombinedReadState: fixedCombinedReadState, tagMask: tagMask)
            return wrappedMessageHistorySignal(signal)
        } else {
            return .never()
        }
    }
}
