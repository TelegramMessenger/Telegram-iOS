import Foundation
import Postbox
internal import TelegramApi
import SwiftSignalKit
import MtProtoKit


public enum JoinChannelError {
    case generic
    case tooMuchJoined
    case tooMuchUsers
    case inviteRequestSent
}

public enum JoinChannelResult {
    case joined(RenderedChannelParticipant?)
    case webView(JoinChatWebView)
}

func _internal_joinChannel(account: Account, peerId: PeerId, hash: String?, forNews: Bool = false) -> Signal<JoinChannelResult, JoinChannelError> {
    return account.postbox.loadedPeerWithId(peerId)
    |> take(1)
    |> castError(JoinChannelError.self)
    |> mapToSignal { peer -> Signal<JoinChannelResult, JoinChannelError> in
        let request: Signal<Api.messages.ChatInviteJoinResult, MTRpcError>
        if let hash = hash {
            request = account.network.request(Api.functions.messages.importChatInvite(hash: hash))
        } else if let inputChannel = apiInputChannel(peer) {
#if TELEGRAM_NEWS_FEED_API
            request = account.network.request(Api.functions.channels.joinChannel(flags: forNews ? (1 << 0) : 0, channel: inputChannel))
#else
            // The feed API is parked (layer 232): there is no News-only join; with News hidden nothing asks for one.
            assert(!forNews, "a News-only join while the feed API is parked would be a full join")
            request = account.network.request(Api.functions.channels.joinChannel(channel: inputChannel))
#endif
        } else {
            request = .fail(.init())
        }

        return request
        |> mapError { error -> JoinChannelError in
            switch error.errorDescription {
                case "CHANNELS_TOO_MUCH":
                    return .tooMuchJoined
                case "USERS_TOO_MUCH":
                    return .tooMuchUsers
                case "INVITE_REQUEST_SENT":
                    return .inviteRequestSent
                default:
                    return .generic
            }
        }
        |> mapToSignal { result -> Signal<JoinChannelResult, JoinChannelError> in
            let updates: Api.Updates
            switch result {
            case let .chatInviteJoinResultOk(data):
                updates = data.updates
            case let .chatInviteJoinResultWebView(data):
                let botPeerId = PeerId(namespace: Namespaces.Peer.CloudUser, id: PeerId.Id._internalFromInt64Value(data.botId))
                return account.postbox.transaction { transaction -> Signal<JoinChannelResult, JoinChannelError> in
                    updatePeers(transaction: transaction, accountPeerId: account.peerId, peers: AccumulatedPeers(users: data.users))
                    guard let botPeer = transaction.getPeer(botPeerId) else {
                        return .fail(.generic)
                    }
                    return .single(.webView(JoinChatWebView(botPeer: EnginePeer(botPeer), url: nil, queryId: data.queryId, peerId: peerId)))
                }
                |> castError(JoinChannelError.self)
                |> switchToLatest
            }

#if TELEGRAM_NEWS_FEED_API
            if forNews {
                // The client owns `in_news` for a while: it is stored before success is reported, and server channel
                // objects keep it (ChannelInNewsLocalChanges), the ones in these updates and in responses to requests
                // sent before the join alike. A News-only subscription may not be reported as membership, so the
                // participant fetch below could fail a join that succeeded.
                return account.postbox.transaction { transaction -> Void in
                    _internal_storeLocalInNews(transaction: transaction, accountPeerId: account.peerId, channelId: peerId, isInNews: true)
                }
                |> castError(JoinChannelError.self)
                |> map { _ -> JoinChannelResult in
                    account.stateManager.addUpdates(updates)
                    return .joined(nil)
                }
            }
#endif
            account.stateManager.addUpdates(updates)
            if hash == nil {
                let _ = _internal_requestRecommendedChannels(account: account, peerId: peerId, forceUpdate: true).startStandalone()
            }

            let channels = updates.chats.compactMap { parseTelegramGroupOrChannel(chat: $0) }.compactMap(apiInputChannel)

            if let inputChannel = channels.first {
                return account.network.request(Api.functions.channels.getParticipant(channel: inputChannel, participant: .inputPeerSelf))
                |> map(Optional.init)
                |> `catch` { _ -> Signal<Api.channels.ChannelParticipant?, JoinChannelError> in
                    return .single(nil)
                }
                |> mapToSignal { result -> Signal<JoinChannelResult, JoinChannelError> in
                    guard let result = result else {
                        return .fail(.generic)
                    }
                    return account.postbox.transaction { transaction -> JoinChannelResult in
                        var peers: [EnginePeer.Id: EnginePeer] = [:]
                        var presences: [PeerId: PeerPresence] = [:]
                        guard let peer = transaction.getPeer(account.peerId) else {
                            return .joined(nil)
                        }
                        peers[account.peerId] = EnginePeer(peer)
                        if let presence = transaction.getPeerPresence(peerId: account.peerId) {
                            presences[account.peerId] = presence
                        }
                        let updatedParticipant: ChannelParticipant
                        switch result {
                            case let .channelParticipant(channelParticipantData):
                                let participant = channelParticipantData.participant
                                updatedParticipant = ChannelParticipant(apiParticipant: participant)
                        }
                        if case let .member(_, _, maybeAdminInfo, _, _, _) = updatedParticipant {
                            if let adminInfo = maybeAdminInfo {
                                if let peer = transaction.getPeer(adminInfo.promotedBy) {
                                    peers[peer.id] = EnginePeer(peer)
                                }
                            }
                        }

                        return .joined(RenderedChannelParticipant(participant: updatedParticipant, peer: EnginePeer(peer), peers: peers, presences: presences))
                    }
                    |> castError(JoinChannelError.self)
                }
            } else {
                return .fail(.generic)
            }

        }
    }
}
