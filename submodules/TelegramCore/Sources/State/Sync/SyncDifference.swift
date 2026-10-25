import Foundation
import Postbox
import SwiftSignalKit
internal import TelegramApi
import MtProtoKit
import EncryptionProvider

func finalStateWithDifference(accountPeerId: PeerId, postbox: Postbox, network: Network, state: AccountMutableState, difference: Api.updates.Difference, asyncResetChannels: (([(peer: Peer, pts: Int32?)]) -> Void)?) -> Signal<AccountFinalState, NoError> {
    var updatedState = state
    
    var messages: [Api.Message] = []
    var encryptedMessages: [Api.EncryptedMessage] = []
    var updates: [Api.Update] = []
    var chats: [Api.Chat] = []
    var users: [Api.User] = []
    
    switch difference {
        case let .difference(differenceData):
            let (newMessages, newEncryptedMessages, otherUpdates, apiChats, apiUsers, apiState) = (differenceData.newMessages, differenceData.newEncryptedMessages, differenceData.otherUpdates, differenceData.chats, differenceData.users, differenceData.state)
            messages = newMessages
            encryptedMessages = newEncryptedMessages
            updates = otherUpdates
            chats = apiChats
            users = apiUsers
            switch apiState {
                case let .state(stateData):
                    let (pts, qts, date, seq, _) = (stateData.pts, stateData.qts, stateData.date, stateData.seq, stateData.unreadCount)
                    updatedState.updateState(AuthorizedAccountState.State(pts: pts, qts: qts, date: date, seq: seq))
            }
        case let .differenceEmpty(differenceEmptyData):
            let (date, seq) = (differenceEmptyData.date, differenceEmptyData.seq)
            updatedState.updateState(AuthorizedAccountState.State(pts: updatedState.state.pts, qts: updatedState.state.qts, date: date, seq: seq))
        case let .differenceSlice(differenceSliceData):
            let (newMessages, newEncryptedMessages, otherUpdates, apiChats, apiUsers, apiState) = (differenceSliceData.newMessages, differenceSliceData.newEncryptedMessages, differenceSliceData.otherUpdates, differenceSliceData.chats, differenceSliceData.users, differenceSliceData.intermediateState)
            messages = newMessages
            encryptedMessages = newEncryptedMessages
            updates = otherUpdates
            chats = apiChats
            users = apiUsers
            switch apiState {
                case let .state(stateData):
                    let (pts, qts, date, seq, _) = (stateData.pts, stateData.qts, stateData.date, stateData.seq, stateData.unreadCount)
                    updatedState.updateState(AuthorizedAccountState.State(pts: pts, qts: qts, date: date, seq: seq))
            }
        case .differenceTooLong:
            assertionFailure()
            break
    }
    
    updatedState.mergeChats(chats)
    updatedState.mergeUsers(users)
    
    let currentTime = Int32(CFAbsoluteTimeGetCurrent() + kCFAbsoluteTimeIntervalSince1970)
    for message in messages {
        if let preCachedResources = message.preCachedResources {
            for (resource, data) in preCachedResources {
                updatedState.addPreCachedResource(resource, data: data)
            }
        }
        if let preCachedStories = message.preCachedStories {
            for (id, story) in preCachedStories {
                updatedState.addPreCachedStory(id: id, story: story)
            }
        }
        var peerIsForum = false
        if let peerId = message.peerId {
            peerIsForum = updatedState.isPeerForum(peerId: peerId)
        }
        if let message = StoreMessage(apiMessage: message, accountPeerId: accountPeerId, peerIsForum: peerIsForum) {
            updatedState.addMessages([message], location: .UpperHistoryBlock)
            
            if let reportDeliveryAttribute = message.attributes.first(where: { $0 is ReportDeliveryMessageAttribute }) as? ReportDeliveryMessageAttribute, case let .Id(id) = message.id, reportDeliveryAttribute.untilDate > currentTime {
                updatedState.addReportMessageDelivery(messageIds: [id])
            }
        }
    }
    
    if !encryptedMessages.isEmpty {
        updatedState.addSecretMessages(encryptedMessages)
    }
    
    return finalStateWithUpdates(accountPeerId: accountPeerId, postbox: postbox, network: network, state: updatedState, updates: updates, shouldPoll: false, missingUpdates: false, shouldResetChannels: true, updatesDate: nil, asyncResetChannels: asyncResetChannels)
}
