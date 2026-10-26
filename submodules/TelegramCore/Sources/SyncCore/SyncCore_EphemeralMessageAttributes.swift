import Foundation
import Postbox

public final class EphemeralMessageAttribute: MessageAttribute {
    public let receiverId: Int64
    public let isWelcomeTemplate: Bool
    public let anchorMessageId: MessageId?
    public let isForwardingDisabled: Bool

    public var associatedPeerIds: [PeerId] {
        if self.receiverId == 0 {
            return []
        }
        return [PeerId(namespace: Namespaces.Peer.CloudUser, id: PeerId.Id._internalFromInt64Value(self.receiverId))]
    }

    public init(receiverId: Int64, isWelcomeTemplate: Bool = false, anchorMessageId: MessageId? = nil, isForwardingDisabled: Bool = false) {
        self.receiverId = receiverId
        self.isWelcomeTemplate = isWelcomeTemplate
        self.anchorMessageId = anchorMessageId
        self.isForwardingDisabled = isForwardingDisabled
    }

    required public init(decoder: PostboxDecoder) {
        self.receiverId = decoder.decodeInt64ForKey("r", orElse: 0)
        self.isWelcomeTemplate = decoder.decodeBoolForKey("w", orElse: false)
        if let peerId = decoder.decodeOptionalInt64ForKey("a.p"), let namespace = decoder.decodeOptionalInt32ForKey("a.n"), let id = decoder.decodeOptionalInt32ForKey("a.i") {
            self.anchorMessageId = MessageId(peerId: PeerId(peerId), namespace: namespace, id: id)
        } else {
            self.anchorMessageId = nil
        }
        self.isForwardingDisabled = decoder.decodeBoolForKey("nf", orElse: false)
    }

    public func encode(_ encoder: PostboxEncoder) {
        encoder.encodeInt64(self.receiverId, forKey: "r")
        encoder.encodeBool(self.isWelcomeTemplate, forKey: "w")
        if let anchorMessageId = self.anchorMessageId {
            encoder.encodeInt64(anchorMessageId.peerId.toInt64(), forKey: "a.p")
            encoder.encodeInt32(anchorMessageId.namespace, forKey: "a.n")
            encoder.encodeInt32(anchorMessageId.id, forKey: "a.i")
        } else {
            encoder.encodeNil(forKey: "a.p")
            encoder.encodeNil(forKey: "a.n")
            encoder.encodeNil(forKey: "a.i")
        }
        encoder.encodeBool(self.isForwardingDisabled, forKey: "nf")
    }
}

public final class EphemeralReplacementMessageAttribute: MessageAttribute {
    public enum State: Int32 {
        case active = 0
        case reverted = 1
    }

    public let state: State
    public let replacementMessageId: MessageId
    public let receiverId: Int64

    public var associatedMessageIds: [MessageId] {
        switch self.state {
        case .active:
            return [self.replacementMessageId]
        case .reverted:
            return []
        }
    }

    public var associatedPeerIds: [PeerId] {
        if self.receiverId == 0 {
            return []
        }
        return [PeerId(namespace: Namespaces.Peer.CloudUser, id: PeerId.Id._internalFromInt64Value(self.receiverId))]
    }

    public init(state: State, replacementMessageId: MessageId, receiverId: Int64) {
        self.state = state
        self.replacementMessageId = replacementMessageId
        self.receiverId = receiverId
    }

    required public init(decoder: PostboxDecoder) {
        self.state = State(rawValue: decoder.decodeInt32ForKey("s", orElse: State.active.rawValue)) ?? .active
        self.replacementMessageId = MessageId(
            peerId: PeerId(decoder.decodeInt64ForKey("m.p", orElse: 0)),
            namespace: decoder.decodeInt32ForKey("m.n", orElse: Namespaces.Message.EphemeralAnchored),
            id: decoder.decodeInt32ForKey("m.i", orElse: 0)
        )
        self.receiverId = decoder.decodeInt64ForKey("r", orElse: 0)
    }

    public func encode(_ encoder: PostboxEncoder) {
        encoder.encodeInt32(self.state.rawValue, forKey: "s")
        encoder.encodeInt64(self.replacementMessageId.peerId.toInt64(), forKey: "m.p")
        encoder.encodeInt32(self.replacementMessageId.namespace, forKey: "m.n")
        encoder.encodeInt32(self.replacementMessageId.id, forKey: "m.i")
        encoder.encodeInt64(self.receiverId, forKey: "r")
    }
}

public final class EphemeralOutgoingMessageAttribute: MessageAttribute {
    public enum State: Int32 {
        case sending = 0
        case failed = 1
    }

    public let botPeerId: PeerId
    public let randomId: Int64
    public let state: State
    public let isWelcomeTemplate: Bool

    public var associatedPeerIds: [PeerId] {
        return [self.botPeerId]
    }

    public init(botPeerId: PeerId, randomId: Int64, state: State, isWelcomeTemplate: Bool = false) {
        self.botPeerId = botPeerId
        self.randomId = randomId
        self.state = state
        self.isWelcomeTemplate = isWelcomeTemplate
    }

    required public init(decoder: PostboxDecoder) {
        self.botPeerId = PeerId(decoder.decodeInt64ForKey("b", orElse: 0))
        self.randomId = decoder.decodeInt64ForKey("r", orElse: 0)
        self.state = State(rawValue: decoder.decodeInt32ForKey("s", orElse: State.sending.rawValue)) ?? .sending
        self.isWelcomeTemplate = decoder.decodeBoolForKey("w", orElse: false)
    }

    public func encode(_ encoder: PostboxEncoder) {
        encoder.encodeInt64(self.botPeerId.toInt64(), forKey: "b")
        encoder.encodeInt64(self.randomId, forKey: "r")
        encoder.encodeInt32(self.state.rawValue, forKey: "s")
        encoder.encodeBool(self.isWelcomeTemplate, forKey: "w")
    }

    public func withUpdatedState(_ state: State) -> EphemeralOutgoingMessageAttribute {
        return EphemeralOutgoingMessageAttribute(botPeerId: self.botPeerId, randomId: self.randomId, state: state, isWelcomeTemplate: self.isWelcomeTemplate)
    }
}
