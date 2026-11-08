import Foundation
import Postbox
import SwiftSignalKit
internal import TelegramApi
import MtProtoKit


public enum JokerCoreHooks {
    private static func boolFlag(_ key: String, defaultOnIfUnset: Bool = false) -> Bool {
        if UserDefaults.standard.object(forKey: key) == nil {
            return defaultOnIfUnset
        }
        return UserDefaults.standard.bool(forKey: key)
    }

    public static func bypassCopyProtectionEnabled() -> Bool {
        return boolFlag("joker_bypass_copy_protection")
    }

    public static func freezeLastSeenEnabled() -> Bool {
        return boolFlag("joker_freeze_last_seen")
    }

    public static func keepDeletedMessagesEnabled() -> Bool {
        return boolFlag("joker_keep_deleted_messages")
    }

    public static func autoSaveMediaEnabled() -> Bool {
        return boolFlag("joker_auto_save_media")
    }

    public static func ghostModeEnabled() -> Bool {
        return boolFlag("joker_ghost_mode")
    }

    public static func storyStealthModeEnabled() -> Bool {
        return boolFlag("joker_story_stealth")
    }

    public static func requireSubscriptionGateEnabled() -> Bool {
        return boolFlag("joker_require_subscription", defaultOnIfUnset: true)
    }

    public static func isChannelSubscribed() -> Bool {
        return boolFlag("joker_channel_subscribed")
    }

    public static let subscriptionChannelUsername = "aljokeruserbot"

    public static func checkChannelSubscription(network: Network, username: String) -> Signal<Bool, NoError> {
        var normalizedName = username
        if normalizedName.hasPrefix("@") {
            normalizedName.removeFirst()
        }
        let cachedStatus = isChannelSubscribed()
        return network.request(Api.functions.contacts.resolveUsername(flags: 0, username: normalizedName, referer: nil))
        |> map(Optional.init)
        |> `catch` { _ -> Signal<Api.contacts.ResolvedPeer?, NoError> in
            return .single(nil)
        }
        |> mapToSignal { result -> Signal<Bool, NoError> in
            guard let result = result, case let .resolvedPeer(resolvedPeerData) = result else {
                return .single(cachedStatus)
            }
            let channels: [Api.InputChannel] = resolvedPeerData.chats.compactMap { chat -> Api.InputChannel? in
                guard let peer = parseTelegramGroupOrChannel(chat: chat) else {
                    return nil
                }
                return apiInputChannel(peer)
            }
            guard let inputChannel = channels.first else {
                return .single(false)
            }
            return network.request(Api.functions.channels.getParticipant(channel: inputChannel, participant: .inputPeerSelf))
            |> map { result -> Bool in
                switch result {
                case let .channelParticipant(channelParticipantData):
                    switch channelParticipantData.participant {
                    case .channelParticipantLeft:
                        return false
                    case let .channelParticipantBanned(bannedData):
                        let hasLeft = (bannedData.flags & (1 << 0)) != 0
                        return !hasLeft
                    default:
                        return true
                    }
                }
            }
            |> `catch` { error -> Signal<Bool, NoError> in
                if error.errorCode == 400 || error.errorCode == 403 {
                    return .single(false)
                }
                return .single(cachedStatus)
            }
        }
    }

    public static func refreshChannelSubscription(network: Network) -> Signal<Void, NoError> {
        guard requireSubscriptionGateEnabled() else {
            return .complete()
        }
        return checkChannelSubscription(network: network, username: subscriptionChannelUsername)
        |> map { isSubscribed -> Void in
            UserDefaults.standard.set(isSubscribed, forKey: "joker_channel_subscribed")
            return ()
        }
    }

    public static func markMessagesAsReadViaNetwork(account: Account, messageIds: [MessageId]) -> Signal<Void, NoError> {
        guard !messageIds.isEmpty else {
            return .complete()
        }
        return account.postbox.transaction { transaction -> [(Api.InputPeer, [Int32], Api.InputChannel?, Bool)] in
            var groupedIds: [PeerId: [Int32]] = [:]
            for messageId in messageIds {
                groupedIds[messageId.peerId, default: []].append(messageId.id)
            }
            var result: [(Api.InputPeer, [Int32], Api.InputChannel?, Bool)] = []
            for (peerId, ids) in groupedIds {
                guard let peer = transaction.getPeer(peerId), let inputPeer = apiInputPeer(peer) else {
                    continue
                }
                if peer is TelegramChannel {
                    result.append((inputPeer, ids, apiInputChannel(peer), true))
                } else {
                    result.append((inputPeer, ids, nil, false))
                }
            }
            return result
        }
        |> mapToSignal { groups -> Signal<Void, NoError> in
            var requests: [Signal<Void, NoError>] = []
            for group in groups {
                let (inputPeer, ids, inputChannel, isChannel) = group
                _ = inputPeer
                if isChannel, let inputChannel = inputChannel {
                    requests.append(account.network.request(Api.functions.channels.readMessageContents(channel: inputChannel, id: ids))
                    |> map { _ -> Void in
                        return ()
                    }
                    |> `catch` { _ -> Signal<Void, NoError> in
                        return .complete()
                    })
                } else {
                    requests.append(account.network.request(Api.functions.messages.readMessageContents(id: ids))
                    |> map { _ -> Void in
                        return ()
                    }
                    |> `catch` { _ -> Signal<Void, NoError> in
                        return .complete()
                    })
                }
            }
            return requests.reduce(Signal<Void, NoError>.complete()) { $0 |> then($1) }
        }
    }

    public static func readAllMessagesForPeer(account: Account, peerId: PeerId) -> Signal<Void, NoError> {
        return account.postbox.transaction { transaction -> (Api.InputPeer, Api.InputChannel?)? in
            guard let peer = transaction.getPeer(peerId), let inputPeer = apiInputPeer(peer) else {
                return nil
            }
            if peerId.namespace == Namespaces.Peer.CloudChannel {
                return (inputPeer, apiInputChannel(peer))
            }
            return (inputPeer, nil)
        }
        |> mapToSignal { resolved -> Signal<Void, NoError> in
            guard let (inputPeer, inputChannel) = resolved else {
                return .complete()
            }
            if peerId.namespace == Namespaces.Peer.CloudChannel, let inputChannel = inputChannel {
                return account.network.request(Api.functions.channels.readHistory(channel: inputChannel, maxId: Int32.max - 1))
                |> map { _ -> Void in
                    return ()
                }
                |> `catch` { _ -> Signal<Void, NoError> in
                    return .complete()
                }
            } else if peerId.namespace == Namespaces.Peer.CloudUser || peerId.namespace == Namespaces.Peer.CloudGroup {
                return account.network.request(Api.functions.messages.readHistory(peer: inputPeer, maxId: Int32.max - 1))
                |> map(Optional.init)
                |> `catch` { _ -> Signal<Api.messages.AffectedMessages?, NoError> in
                    return .single(nil)
                }
                |> mapToSignal { result -> Signal<Void, NoError> in
                    if let result = result, case let .affectedMessages(affectedMessagesData) = result {
                        account.stateManager.addUpdateGroups([.updatePts(pts: affectedMessagesData.pts, ptsCount: affectedMessagesData.ptsCount)])
                    }
                    return .complete()
                }
            }
            return .complete()
        }
    }

    public static func readMessagesUpToViaNetwork(account: Account, peerId: PeerId, maxMessageId: Int32) -> Signal<Void, NoError> {
        return account.postbox.transaction { transaction -> (Api.InputPeer, Api.InputChannel?)? in
            guard let peer = transaction.getPeer(peerId), let inputPeer = apiInputPeer(peer) else {
                return nil
            }
            if peerId.namespace == Namespaces.Peer.CloudChannel {
                return (inputPeer, apiInputChannel(peer))
            }
            return (inputPeer, nil)
        }
        |> mapToSignal { resolved -> Signal<Void, NoError> in
            guard let (inputPeer, inputChannel) = resolved else {
                return .complete()
            }
            if peerId.namespace == Namespaces.Peer.CloudChannel, let inputChannel = inputChannel {
                return account.network.request(Api.functions.channels.readHistory(channel: inputChannel, maxId: maxMessageId))
                |> map { _ -> Void in
                    return ()
                }
                |> `catch` { _ -> Signal<Void, NoError> in
                    return .complete()
                }
            } else if peerId.namespace == Namespaces.Peer.CloudUser || peerId.namespace == Namespaces.Peer.CloudGroup {
                return account.network.request(Api.functions.messages.readHistory(peer: inputPeer, maxId: maxMessageId))
                |> map(Optional.init)
                |> `catch` { _ -> Signal<Api.messages.AffectedMessages?, NoError> in
                    return .single(nil)
                }
                |> mapToSignal { result -> Signal<Void, NoError> in
                    if let result = result, case let .affectedMessages(affectedMessagesData) = result {
                        account.stateManager.addUpdateGroups([.updatePts(pts: affectedMessagesData.pts, ptsCount: affectedMessagesData.ptsCount)])
                    }
                    return .complete()
                }
            }
            return .complete()
        }
    }

    public static func saveConsumedMediaIfNeeded(account: Account, messageId: MessageId) -> Signal<Void, NoError> {
        guard autoSaveMediaEnabled() else {
            return .complete()
        }
        struct SavedMediaItem {
            var resource: TelegramMediaResource
            var isImage: Bool
            var width: Int32
            var height: Int32
            var mimeType: String
            var fileName: String?
            var attributes: [TelegramMediaFileAttribute]
        }
        return account.postbox.transaction { transaction -> (media: SavedMediaItem, caption: String, entities: [MessageTextEntity])? in
            guard let message = transaction.getMessage(messageId), message.flags.contains(.Incoming) else {
                return nil
            }
            var isSelfDestruct = false
            for attribute in message.attributes {
                if let consumable = attribute as? ConsumableContentMessageAttribute, !consumable.consumed {
                    isSelfDestruct = true
                    break
                }
                if let autoclear = attribute as? AutoclearTimeoutMessageAttribute, autoclear.countdownBeginTime == nil || autoclear.countdownBeginTime == 0 {
                    isSelfDestruct = true
                    break
                }
            }
            guard isSelfDestruct else {
                return nil
            }
            let caption = message.text
            var entities: [MessageTextEntity] = []
            if let entitiesAttribute = message.attributes.first(where: { $0 is TextEntitiesMessageAttribute }) as? TextEntitiesMessageAttribute {
                entities = entitiesAttribute.entities
            }
            for media in message.media {
                if let image = media as? TelegramMediaImage, let largest = largestImageRepresentation(image.representations) {
                    return (SavedMediaItem(resource: largest.resource, isImage: true, width: largest.dimensions.width, height: largest.dimensions.height, mimeType: "image/jpeg", fileName: nil, attributes: []), caption, entities)
                } else if let file = media as? TelegramMediaFile {
                    return (SavedMediaItem(resource: file.resource, isImage: false, width: 0, height: 0, mimeType: file.mimeType, fileName: file.fileName, attributes: file.attributes), caption, entities)
                }
            }
            return nil
        }
        |> mapToSignal { item -> Signal<Void, NoError> in
            guard let item = item else {
                return .complete()
            }
            return account.postbox.mediaBox.resourceData(item.media.resource, option: .complete(waitUntilFetchStatus: true))
            |> take(1)
            |> mapToSignal { data -> Signal<Void, NoError> in
                guard data.complete, let bytes = try? Data(contentsOf: URL(fileURLWithPath: data.path)) else {
                    return .complete()
                }
                let peerId = account.peerId
                let auxiliaryMethods = AccountAuxiliaryMethods(fetchResource: { _, _, _, _ in
                    return nil
                }, fetchResourceMediaReferenceHash: { _ in
                    return .single(nil)
                }, prepareSecretThumbnailData: { _ in
                    return nil
                }, backgroundUpload: { _, _, _ in
                    return .single(nil)
                })
                let text = StandaloneSendEnqueueMessage.Text(string: item.caption, entities: item.entities)
                let upload: Signal<StandaloneUploadMediaEvent, StandaloneUploadMediaError>
                if item.media.isImage {
                    upload = standaloneUploadedImage(postbox: account.postbox, network: account.network, peerId: peerId, text: "", source: .data(bytes), thumbnailData: nil, dimensions: PixelDimensions(width: item.media.width, height: item.media.height))
                } else {
                    upload = standaloneUploadedFile(postbox: account.postbox, network: account.network, peerId: peerId, text: "", source: .data(bytes), thumbnailData: nil, mimeType: item.media.mimeType, attributes: item.media.attributes, hintFileIsLarge: bytes.count > 10 * 1024 * 1024)
                }
                return upload
                |> `catch` { _ -> Signal<StandaloneUploadMediaEvent, NoError> in
                    return .complete()
                }
                |> mapToSignal { event -> Signal<Void, NoError> in
                    guard case let .result(result) = event, case let .media(reference) = result else {
                        return .complete()
                    }
                    let message = StandaloneSendEnqueueMessage(content: .arbitraryMedia(media: reference, text: text), replyToMessageId: nil)
                    return standaloneSendEnqueueMessages(accountPeerId: peerId, postbox: account.postbox, network: account.network, stateManager: account.stateManager, auxiliaryMethods: auxiliaryMethods, peerId: peerId, threadId: nil, messages: [message])
                    |> `catch` { _ -> Signal<StandaloneSendMessageStatus, NoError> in
                        return .complete()
                    }
                    |> map { _ in }
                }
            }
        }
    }
    private static func jokerLocalGreeting() -> (enabled: Bool, text: String) {
        let enabled = UserDefaults.standard.bool(forKey: "joker_greeting_enabled")
        let text = UserDefaults.standard.string(forKey: "joker_greeting_text") ?? ""
        return (enabled, text)
    }

    private static func jokerLocalGreetedPeers() -> Set<Int64> {
        return Set((UserDefaults.standard.array(forKey: "joker_greeting_sent_peers") as? [Int64]) ?? [])
    }

    private static func markJokerLocalGreetedPeer(_ id: Int64) {
        var peers = (UserDefaults.standard.array(forKey: "joker_greeting_sent_peers") as? [Int64]) ?? []
        if !peers.contains(id) {
            peers.append(id)
            UserDefaults.standard.set(peers, forKey: "joker_greeting_sent_peers")
        }
    }

    private static func jokerStandaloneAuxiliaryMethods() -> AccountAuxiliaryMethods {
        return AccountAuxiliaryMethods(fetchResource: { _, _, _, _ in
            return nil
        }, fetchResourceMediaReferenceHash: { _ in
            return .single(nil)
        }, prepareSecretThumbnailData: { _ in
            return nil
        }, backgroundUpload: { _, _, _ in
            return .single(nil)
        })
    }

    public static func sendGreetingIfNeeded(account: Account, messages: [Message]) -> Signal<Void, NoError> {
        let greeting = jokerLocalGreeting()
        guard greeting.enabled else {
            return .complete()
        }
        let text = greeting.text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else {
            return .complete()
        }

        var seenPeers = Set<PeerId>()
        var candidateIds: [MessageId] = []
        for message in messages {
            guard message.flags.contains(.Incoming) else { continue }
            if message.threadId != nil { continue }
            let peerId = message.id.peerId
            guard peerId.namespace == Namespaces.Peer.CloudUser else { continue }
            if seenPeers.contains(peerId) { continue }
            seenPeers.insert(peerId)
            candidateIds.append(message.id)
        }
        guard !candidateIds.isEmpty else {
            return .complete()
        }

        let accountPeerId = account.peerId
        return account.postbox.transaction { transaction -> [PeerId] in
            var result: [PeerId] = []
            let greeted = jokerLocalGreetedPeers()
            for id in candidateIds {
                guard let message = transaction.getMessage(id) else { continue }
                let peerId = message.id.peerId
                if greeted.contains(peerId.id._internalGetInt64Value()) { continue }
                if let user = transaction.getPeer(peerId) as? TelegramUser, user.botInfo != nil { continue }
                if transaction.isPeerContact(peerId: peerId) { continue }
                var hasOutgoing = false
                transaction.withAllMessages(peerId: peerId, namespace: Namespaces.Message.Cloud) { message in
                    if !message.flags.contains(.Incoming) {
                        hasOutgoing = true
                        return false
                    }
                    return true
                }
                if hasOutgoing { continue }
                result.append(peerId)
            }
            return result
        }
        |> mapToSignal { peers -> Signal<Void, NoError> in
            var signals: [Signal<Void, NoError>] = []
            for peerId in peers {
                markJokerLocalGreetedPeer(peerId.id._internalGetInt64Value())
                let message = StandaloneSendEnqueueMessage(content: .text(text: StandaloneSendEnqueueMessage.Text(string: text, entities: [])), replyToMessageId: nil)
                signals.append(standaloneSendEnqueueMessages(accountPeerId: accountPeerId, postbox: account.postbox, network: account.network, stateManager: account.stateManager, auxiliaryMethods: jokerStandaloneAuxiliaryMethods(), peerId: peerId, threadId: nil, messages: [message])
                |> map { _ -> Void in
                    return ()
                }
                |> `catch` { _ -> Signal<Void, NoError> in
                    return .complete()
                })
            }
            return signals.reduce(Signal<Void, NoError>.single(())) { $0 |> then($1) }
        }
    }

    private static let keptDeletedStorageKey = "joker_kept_deleted_ids"

    public static func recordKeptDeletedMessages(_ messageIds: [MessageId]) {
        guard keepDeletedMessagesEnabled(), !messageIds.isEmpty else {
            return
        }
        var storage = UserDefaults.standard.dictionary(forKey: keptDeletedStorageKey) as? [String: [Int64]] ?? [:]
        for messageId in messageIds {
            let key = String(messageId.peerId.id._internalGetInt64Value())
            var values = storage[key] ?? []
            let packed = Int64(messageId.namespace) << 32 | Int64(UInt32(bitPattern: messageId.id))
            if !values.contains(packed) {
                values.append(packed)
            }
            storage[key] = values
        }
        UserDefaults.standard.set(storage, forKey: keptDeletedStorageKey)
        UserDefaults.standard.synchronize()
    }

    public static func isKeptDeletedMessage(peerId: PeerId, namespace: Int32, id: Int32) -> Bool {
        let storage = UserDefaults.standard.dictionary(forKey: keptDeletedStorageKey) as? [String: [Int64]] ?? [:]
        guard let values = storage[String(peerId.id._internalGetInt64Value())] else {
            return false
        }
        let packed = Int64(namespace) << 32 | Int64(UInt32(bitPattern: id))
        return values.contains(packed)
    }
}
