import Postbox
import SwiftSignalKit
import TelegramApi
import MtProtoKit
import SyncCore

public struct GroupCallInfo: Equatable {
    public var id: Int64
    public var accessHash: Int64
    public var peerId: PeerId?
    public var clientParams: String?
}

private extension GroupCallInfo {
    init?(_ call: Api.GroupCall) {
        switch call {
        case let .groupCallPrivate(_, id, accessHash, channelId, _, _):
            self.init(
                id: id,
                accessHash: accessHash,
                peerId: channelId.flatMap { PeerId(namespace: Namespaces.Peer.CloudChannel, id: $0) },
                clientParams: nil
            )
        case let .groupCall(_, id, accessHash, channelId, _, _, params):
            var clientParams: String?
            if let params = params {
                switch params {
                case let .dataJSON(data):
                    clientParams = data
                }
            }
            self.init(
                id: id,
                accessHash: accessHash,
                peerId: channelId.flatMap { PeerId(namespace: Namespaces.Peer.CloudChannel, id: $0) },
                clientParams: clientParams
            )
        case .groupCallDiscarded:
            return nil
        }
    }
}

public enum GetCurrentGroupCallError {
    case generic
}

public func getCurrentGroupCall(account: Account, peerId: PeerId) -> Signal<GroupCallInfo?, GetCurrentGroupCallError> {
    return account.postbox.transaction { transaction -> Api.InputChannel? in
        transaction.getPeer(peerId).flatMap(apiInputChannel)
    }
    |> castError(GetCurrentGroupCallError.self)
    |> mapToSignal { inputPeer -> Signal<MessageId?, GetCurrentGroupCallError> in
        guard let inputPeer = inputPeer else {
            return .fail(.generic)
        }
        return account.network.request(Api.functions.channels.getFullChannel(channel: inputPeer))
        |> mapError { _ -> GetCurrentGroupCallError in
            return .generic
        }
        |> mapToSignal { result -> Signal<MessageId?, GetCurrentGroupCallError> in
            switch result {
            case let .chatFull(fullChat, _, _):
                switch fullChat {
                case let .channelFull(_, _, _, _, _, _, _, _, _, _, _, _, _, _, _, _, _, _, _, _, _, _, _, _, _, _, _, callMsgId):
                    return .single(callMsgId.flatMap { callMsgId in
                        MessageId(peerId: peerId, namespace: Namespaces.Peer.CloudChannel, id: callMsgId)
                    })
                default:
                    return .single(nil)
                }
            default:
                return .single(nil)
            }
        }
    }
    |> mapToSignal { messageId -> Signal<GroupCallInfo?, GetCurrentGroupCallError> in
        guard let messageId = messageId else {
            return .single(nil)
        }
        return account.postbox.transaction { transaction -> Api.InputChannel? in
            return transaction.getPeer(peerId).flatMap(apiInputChannel)
        }
        |> castError(GetCurrentGroupCallError.self)
        |> mapToSignal { inputPeer -> Signal<GroupCallInfo?, GetCurrentGroupCallError> in
            guard let inputPeer = inputPeer else {
                return .fail(.generic)
            }
            return account.network.request(Api.functions.channels.getMessages(channel: inputPeer, id: [.inputMessageID(id: messageId.id)]))
            |> mapError { _ -> GetCurrentGroupCallError in
                return .generic
            }
            |> mapToSignal { result -> Signal<GroupCallInfo?, GetCurrentGroupCallError> in
                let messages: [Api.Message]
                let chats: [Api.Chat]
                let users: [Api.User]
                
                switch result {
                case let .messages(apiMessages, apiChats, apiUsers):
                    messages = apiMessages
                    chats = apiChats
                    users = apiUsers
                case let .messagesSlice(_, _, _, _, messages: apiMessages, chats: apiChats, users: apiUsers):
                    messages = apiMessages
                    chats = apiChats
                    users = apiUsers
                case let .channelMessages(_, _, _, _, apiMessages, apiChats, apiUsers):
                    messages = apiMessages
                    chats = apiChats
                    users = apiUsers
                case .messagesNotModified:
                    return .fail(.generic)
                }
                
                guard let apiMessage = messages.first else {
                    return .single(nil)
                }
                guard let message = StoreMessage(apiMessage: apiMessage) else {
                    return .fail(.generic)
                }
                
                var maybeInputCall: Api.InputGroupCall?
                loop: for media in message.media {
                    if let action = media as? TelegramMediaAction {
                        switch action.action {
                        case let .groupPhoneCall(callId, accessHash, _):
                            maybeInputCall = .inputGroupCall(id: callId, accessHash: accessHash)
                            break loop
                        default:
                            break
                        }
                    }
                }
                
                guard let inputCall = maybeInputCall else {
                    return .fail(.generic)
                }
                
                return account.network.request(Api.functions.phone.getGroupCall(call: inputCall))
                |> mapError { _ -> GetCurrentGroupCallError in
                    return .generic
                }
                |> mapToSignal { result -> Signal<GroupCallInfo?, GetCurrentGroupCallError> in
                    switch result {
                    case let .groupCall(call, participants, chats, users):
                        return account.postbox.transaction { transaction -> GroupCallInfo? in
                            return GroupCallInfo(call)
                        }
                        |> mapError { _ -> GetCurrentGroupCallError in
                            return .generic
                        }
                    }
                }
            }
        }
    }
}

public enum CreateGroupCallError {
    case generic
}

public func createGroupCall(account: Account, peerId: PeerId) -> Signal<GroupCallInfo, CreateGroupCallError> {
    return account.postbox.transaction { transaction -> Api.InputChannel? in
        return transaction.getPeer(peerId).flatMap(apiInputChannel)
    }
    |> castError(CreateGroupCallError.self)
    |> mapToSignal { inputPeer -> Signal<GroupCallInfo, CreateGroupCallError> in
        guard let inputPeer = inputPeer else {
            return .fail(.generic)
        }
        
        return account.network.request(Api.functions.phone.createGroupCall(flags: 0, channel: inputPeer, randomId: Int32.random(in: Int32.min ... Int32.max)))
        |> mapError { _ -> CreateGroupCallError in
            return .generic
        }
        |> mapToSignal { result -> Signal<GroupCallInfo, CreateGroupCallError> in
            account.stateManager.addUpdates(result)
            
            var parsedCall: GroupCallInfo?
            loop: for update in result.allUpdates {
                switch update {
                case let .updateGroupCall(call):
                    parsedCall = GroupCallInfo(call)
                    break loop
                default:
                    break
                }
            }
            
            if let parsedCall = parsedCall {
                return .single(parsedCall)
            } else {
                return .fail(.generic)
            }
        }
    }
}

public enum JoinGroupCallError {
    case generic
}

public struct JoinGroupCallResult {
    public var callInfo: GroupCallInfo
    public var ssrcs: [Int32]
}

public func joinGroupCall(account: Account, callId: Int64, accessHash: Int64, joinPayload: String) -> Signal<JoinGroupCallResult, JoinGroupCallError> {
    return account.network.request(Api.functions.phone.joinGroupCall(call: .inputGroupCall(id: callId, accessHash: accessHash), params: .dataJSON(data: joinPayload)))
    |> mapError { _ -> JoinGroupCallError in
        return .generic
    }
    |> mapToSignal { updates -> Signal<JoinGroupCallResult, JoinGroupCallError> in
        return account.network.request(Api.functions.phone.getGroupCall(call: .inputGroupCall(id: callId, accessHash: accessHash)))
        |> mapError { _ -> JoinGroupCallError in
            return .generic
        }
        |> mapToSignal { result -> Signal<JoinGroupCallResult, JoinGroupCallError> in
            account.stateManager.addUpdates(updates)
            
            var maybeParsedCall: GroupCallInfo?
            loop: for update in updates.allUpdates {
                switch update {
                case let .updateGroupCall(call):
                    maybeParsedCall = GroupCallInfo(call)
                    break loop
                default:
                    break
                }
            }
            
            guard let parsedCall = maybeParsedCall else {
                return .fail(.generic)
            }
            
            switch result {
            case let .groupCall(call, participants, chats, users):
                guard let _ = GroupCallInfo(call) else {
                    return .fail(.generic)
                }
                var ssrcs: [Int32] = []
                for participant in participants {
                    var ssrc: Int32?
                    switch participant {
                    case let .groupCallParticipantAdmin(_, source):
                        ssrc = source
                    case let .groupCallParticipant(_, _, _, source):
                        ssrc = source
                    case .groupCallParticipantLeft:
                        break
                    case .groupCallParticipantKicked:
                        break
                    case .groupCallParticipantInvited:
                        break
                    }
                    if let ssrc = ssrc {
                        ssrcs.append(ssrc)
                    }
                }
                return account.postbox.transaction { transaction -> JoinGroupCallResult in
                    return JoinGroupCallResult(
                        callInfo: parsedCall,
                        ssrcs: ssrcs
                    )
                }
                |> castError(JoinGroupCallError.self)
            }
        }
    }
}

public enum StopGroupCallError {
    case generic
}

public func stopGroupCall(account: Account, callId: Int64, accessHash: Int64) -> Signal<Never, StopGroupCallError> {
    return account.network.request(Api.functions.phone.discardGroupCall(call: .inputGroupCall(id: callId, accessHash: accessHash)))
    |> mapError { _ -> StopGroupCallError in
        return .generic
    }
    |> mapToSignal { result -> Signal<Never, StopGroupCallError> in
        account.stateManager.addUpdates(result)
        
        return .complete()
    }
}
