import Foundation
@testable import Postbox

/// A peer with an id and a title, enough to be stored and looked up.
final class FixturePeer: Peer {
    static let register: Void = {
        declareEncodable(FixturePeer.self, f: { FixturePeer(decoder: $0) })
        declareEncodable(FixtureCachedPeerData.self, f: { FixtureCachedPeerData(decoder: $0) })
    }()

    let id: PeerId
    let title: String
    let containerPeerId: PeerId?
    let associatedPeerId: PeerId?
    let associatedPeerOverridesIdentity: Bool
    /// A forum's read counter comes from its per-topic summaries rather than its read
    /// state (`SeedConfiguration.peerSummaryIsThreadBased` reads this).
    let isForum: Bool

    init(id: PeerId, title: String, containerPeerId: PeerId? = nil, associatedPeerId: PeerId? = nil, associatedPeerOverridesIdentity: Bool = false, isForum: Bool = false) {
        self.id = id
        self.title = title
        self.containerPeerId = containerPeerId
        self.associatedPeerId = associatedPeerId
        self.associatedPeerOverridesIdentity = associatedPeerOverridesIdentity
        self.isForum = isForum
    }

    init(decoder: PostboxDecoder) {
        self.id = PeerId(decoder.decodeInt64ForKey("i", orElse: 0))
        self.title = decoder.decodeStringForKey("t", orElse: "")
        self.containerPeerId = decoder.decodeOptionalInt64ForKey("c").map(PeerId.init)
        self.associatedPeerId = decoder.decodeOptionalInt64ForKey("a").map(PeerId.init)
        self.associatedPeerOverridesIdentity = decoder.decodeBoolForKey("o", orElse: false)
        self.isForum = decoder.decodeBoolForKey("f", orElse: false)
    }

    func encode(_ encoder: PostboxEncoder) {
        encoder.encodeInt64(self.id.toInt64(), forKey: "i")
        encoder.encodeString(self.title, forKey: "t")
        if let containerPeerId = self.containerPeerId {
            encoder.encodeInt64(containerPeerId.toInt64(), forKey: "c")
        }
        if let associatedPeerId = self.associatedPeerId {
            encoder.encodeInt64(associatedPeerId.toInt64(), forKey: "a")
        }
        encoder.encodeBool(self.associatedPeerOverridesIdentity, forKey: "o")
        encoder.encodeBool(self.isForum, forKey: "f")
    }

    var indexName: PeerIndexNameRepresentation { return .title(title: self.title, addressNames: []) }
    var notificationSettingsPeerId: PeerId? { return nil }
    var associatedMediaIds: [MediaId]? { return nil }
    var timeoutAttribute: UInt32? { return nil }

    func isEqual(_ other: Peer) -> Bool {
        guard let other = other as? FixturePeer else { return false }
        return other.id == self.id && other.title == self.title && other.isForum == self.isForum
    }
}

/// Cached data that names the peers it refers to and, for a channel migrated from a basic
/// group, the group's last message (which makes the channel's history views `.associated`).
final class FixtureCachedPeerData: CachedPeerData {
    let peerIds: Set<PeerId>
    let messageIds: Set<MessageId> = []
    let associatedHistoryMessageId: MessageId?

    init(peerIds: Set<PeerId>, associatedHistoryMessageId: MessageId? = nil) {
        self.peerIds = peerIds
        self.associatedHistoryMessageId = associatedHistoryMessageId
    }

    init(decoder: PostboxDecoder) {
        self.peerIds = Set(decoder.decodeInt64ArrayForKey("p").map(PeerId.init))
        if let peerId = decoder.decodeOptionalInt64ForKey("ap") {
            self.associatedHistoryMessageId = MessageId(peerId: PeerId(peerId), namespace: decoder.decodeInt32ForKey("an", orElse: 0), id: decoder.decodeInt32ForKey("ai", orElse: 0))
        } else {
            self.associatedHistoryMessageId = nil
        }
    }

    func encode(_ encoder: PostboxEncoder) {
        encoder.encodeInt64Array(self.peerIds.map { $0.toInt64() }.sorted(), forKey: "p")
        if let associatedHistoryMessageId = self.associatedHistoryMessageId {
            encoder.encodeInt64(associatedHistoryMessageId.peerId.toInt64(), forKey: "ap")
            encoder.encodeInt32(associatedHistoryMessageId.namespace, forKey: "an")
            encoder.encodeInt32(associatedHistoryMessageId.id, forKey: "ai")
        }
    }

    func isEqual(to other: CachedPeerData) -> Bool {
        guard let other = other as? FixtureCachedPeerData else { return false }
        return other.peerIds == self.peerIds && other.associatedHistoryMessageId == self.associatedHistoryMessageId
    }
}
