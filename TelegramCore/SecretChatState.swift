import Foundation
#if os(macOS)
    import PostboxMac
#else
    import Postbox
#endif

enum SecretChatRole: Int32 {
    case creator
    case participant
}

enum SecretChatLayer: Int32 {
    case layer8 = 8
    case layer46 = 46
}

struct SecretChatBasicFingerprint: Equatable {
    let k0: Int64
    let k1: Int64
    
    static func ==(lhs: SecretChatBasicFingerprint, rhs: SecretChatBasicFingerprint) -> Bool {
        if lhs.k0 != rhs.k0 {
            return false
        }
        if lhs.k1 != rhs.k1 {
            return false
        }
        return true
    }
}

struct SecretChatExtendedFingerprint: Equatable {
    let k0: Int64
    let k1: Int64
    
    static func ==(lhs: SecretChatExtendedFingerprint, rhs: SecretChatExtendedFingerprint) -> Bool {
        if lhs.k0 != rhs.k0 {
            return false
        }
        if lhs.k1 != rhs.k1 {
            return false
        }
        return true
    }
}

public enum SecretChatEmbeddedPeerState: Int32 {
    case terminated = 0
    case handshake = 1
    case active = 2
}

private enum SecretChatEmbeddedStateValue: Int32 {
    case terminated = 0
    case handshake = 1
    case basicLayer = 2
    case sequenceBasedLayer = 3
}

struct SecretChatLayerNegotiationState: Coding, Equatable {
    let activeLayer: Int32
    let locallyRequestedLayer: Int32
    let remotelyRequestedLayer: Int32
    
    init(activeLayer: Int32, locallyRequestedLayer: Int32, remotelyRequestedLayer: Int32) {
        self.activeLayer = activeLayer
        self.locallyRequestedLayer = locallyRequestedLayer
        self.remotelyRequestedLayer = remotelyRequestedLayer
    }
    
    init(decoder: Decoder) {
        self.activeLayer = decoder.decodeInt32ForKey("a")
        self.locallyRequestedLayer = decoder.decodeInt32ForKey("lr")
        self.remotelyRequestedLayer = decoder.decodeInt32ForKey("rr")
    }
    
    func encode(_ encoder: Encoder) {
        encoder.encodeInt32(self.activeLayer, forKey: "a")
        encoder.encodeInt32(self.locallyRequestedLayer, forKey: "lr")
        encoder.encodeInt32(self.remotelyRequestedLayer, forKey: "rr")
    }
    
    static func ==(lhs: SecretChatLayerNegotiationState, rhs: SecretChatLayerNegotiationState) -> Bool {
        if lhs.activeLayer != rhs.activeLayer {
            return false
        }
        if lhs.locallyRequestedLayer != rhs.locallyRequestedLayer {
            return false
        }
        if lhs.remotelyRequestedLayer != rhs.remotelyRequestedLayer {
            return false
        }
        return true
    }
}

private enum SecretChatRekeySessionDataValue: Int32 {
    case requesting = 0
    case requested = 1
    case accepting = 2
    case accepted = 3
}

enum SecretChatRekeySessionData: Coding, Equatable {
    case requesting
    case requested(a: MemoryBuffer, config: SecretChatEncryptionConfig)
    case accepting
    case accepted(key: MemoryBuffer, keyFingerprint: Int64)
    
    init(decoder: Decoder) {
        switch decoder.decodeInt32ForKey("r") as Int32 {
            case SecretChatRekeySessionDataValue.requesting.rawValue:
                self = .requesting
            case SecretChatRekeySessionDataValue.requested.rawValue:
                self = .requested(a: decoder.decodeBytesForKey("a")!, config: decoder.decodeObjectForKey("c", decoder: { SecretChatRekeySessionData(decoder: $0) }) as! SecretChatEncryptionConfig)
            case SecretChatRekeySessionDataValue.accepting.rawValue:
                self = .accepting
            case SecretChatRekeySessionDataValue.accepted.rawValue:
                self = .accepted(key: decoder.decodeBytesForKey("k")!, keyFingerprint: decoder.decodeInt64ForKey("f"))
            default:
                preconditionFailure()
        }
    }
    
    func encode(_ encoder: Encoder) {
        switch self {
            case .requesting:
                encoder.encodeInt32(SecretChatRekeySessionDataValue.requesting.rawValue, forKey: "r")
            case let .requested(a, config):
                encoder.encodeInt32(SecretChatRekeySessionDataValue.requested.rawValue, forKey: "r")
                encoder.encodeBytes(a, forKey: "a")
                encoder.encodeObject(config, forKey: "c")
            case .accepting:
                encoder.encodeInt32(SecretChatRekeySessionDataValue.accepting.rawValue, forKey: "r")
            case let .accepted(key, keyFingerprint):
                encoder.encodeInt32(SecretChatRekeySessionDataValue.accepted.rawValue, forKey: "r")
                encoder.encodeBytes(key, forKey: "k")
                encoder.encodeInt64(keyFingerprint, forKey: "f")
        }
    }
    
    static func ==(lhs: SecretChatRekeySessionData, rhs: SecretChatRekeySessionData) -> Bool {
        switch lhs {
            case let .requesting:
                if case .requesting = rhs {
                    return true
                } else {
                    return false
                }
            case let .requested(a, _):
                if case .requested(a, _) = rhs {
                    return true
                } else {
                    return false
                }
            case .accepting:
                if case .accepting = rhs {
                    return true
                } else {
                    return false
                }
            case let .accepted(key, keyFingerprint):
                if case .accepted(key, keyFingerprint) = rhs {
                    return true
                } else {
                    return false
                }
        }
    }
}

struct SecretChatRekeySessionState: Coding, Equatable {
    let id: Int64
    let data: SecretChatRekeySessionData
    
    init(id: Int64, data: SecretChatRekeySessionData) {
        self.id = id
        self.data = data
    }
    
    init(decoder: Decoder) {
        self.id = decoder.decodeInt64ForKey("i")
        self.data = decoder.decodeObjectForKey("d", decoder: { SecretChatRekeySessionData(decoder: $0) }) as! SecretChatRekeySessionData
    }
    
    func encode(_ encoder: Encoder) {
        encoder.encodeInt64(self.id, forKey: "i")
        encoder.encodeObject(self.data, forKey: "d")
    }
    
    static func ==(lhs: SecretChatRekeySessionState, rhs: SecretChatRekeySessionState) -> Bool {
        if lhs.id != rhs.id {
            return false
        }
        if lhs.data != rhs.data {
            return false
        }
        return true
    }
}

struct SecretChatSequenceBasedLayerState: Coding, Equatable {
    let layerNegotiationState: SecretChatLayerNegotiationState
    let rekeyState: SecretChatRekeySessionState?
    let baseIncomingOperationIndex: Int32
    let baseOutgoingOperationIndex: Int32
    let topProcessedCanonicalIncomingOperationIndex: Int32?
    
    init(layerNegotiationState: SecretChatLayerNegotiationState, rekeyState: SecretChatRekeySessionState?, baseIncomingOperationIndex: Int32, baseOutgoingOperationIndex: Int32, topProcessedCanonicalIncomingOperationIndex: Int32?) {
        self.layerNegotiationState = layerNegotiationState
        self.rekeyState = rekeyState
        self.baseIncomingOperationIndex = baseIncomingOperationIndex
        self.baseOutgoingOperationIndex = baseOutgoingOperationIndex
        self.topProcessedCanonicalIncomingOperationIndex = topProcessedCanonicalIncomingOperationIndex
    }
    
    init(decoder: Decoder) {
        self.layerNegotiationState = decoder.decodeObjectForKey("ln", decoder: { SecretChatLayerNegotiationState(decoder: $0) }) as! SecretChatLayerNegotiationState
        self.rekeyState = decoder.decodeObjectForKey("rs", decoder: { SecretChatRekeySessionState(decoder: $0) }) as? SecretChatRekeySessionState
        self.baseIncomingOperationIndex = decoder.decodeInt32ForKey("bi")
        self.baseOutgoingOperationIndex = decoder.decodeInt32ForKey("bo")
        if let topProcessedCanonicalIncomingOperationIndex = decoder.decodeInt32ForKey("pi") as Int32? {
            self.topProcessedCanonicalIncomingOperationIndex = topProcessedCanonicalIncomingOperationIndex
        } else {
            self.topProcessedCanonicalIncomingOperationIndex = nil
        }
    }
    
    func encode(_ encoder: Encoder) {
        encoder.encodeObject(self.layerNegotiationState, forKey: "ln")
        if let rekeyState = self.rekeyState {
            encoder.encodeObject(rekeyState, forKey: "rs")
        } else {
            encoder.encodeNil(forKey: "rs")
        }
        encoder.encodeInt32(self.baseIncomingOperationIndex, forKey: "bi")
        encoder.encodeInt32(self.baseOutgoingOperationIndex, forKey: "bo")
        if let topProcessedCanonicalIncomingOperationIndex = self.topProcessedCanonicalIncomingOperationIndex {
            encoder.encodeInt32(topProcessedCanonicalIncomingOperationIndex, forKey: "pi")
        } else {
            encoder.encodeNil(forKey: "pi")
        }
    }
    
    func canonicalIncomingOperationIndex(_ index: Int32) -> Int32 {
        return index - self.baseIncomingOperationIndex
    }
    
    func canonicalOutgoingOperationIndex(_ index: Int32) -> Int32 {
        return index - self.baseOutgoingOperationIndex
    }
    
    func outgoingOperationIndexFromCanonicalOperationIndex(_ index: Int32) -> Int32 {
        return index + self.baseOutgoingOperationIndex
    }
    
    func withUpdatedLayerNegotiationState(_ layerNegotiationState: SecretChatLayerNegotiationState) -> SecretChatSequenceBasedLayerState {
        return SecretChatSequenceBasedLayerState(layerNegotiationState: layerNegotiationState, rekeyState: self.rekeyState, baseIncomingOperationIndex: self.baseIncomingOperationIndex, baseOutgoingOperationIndex: self.baseOutgoingOperationIndex, topProcessedCanonicalIncomingOperationIndex: self.topProcessedCanonicalIncomingOperationIndex)
    }
    
    func withUpdatedRekeyState(_ rekeyState: SecretChatRekeySessionState?) -> SecretChatSequenceBasedLayerState {
        return SecretChatSequenceBasedLayerState(layerNegotiationState: self.layerNegotiationState, rekeyState: rekeyState, baseIncomingOperationIndex: self.baseIncomingOperationIndex, baseOutgoingOperationIndex: self.baseOutgoingOperationIndex, topProcessedCanonicalIncomingOperationIndex: self.topProcessedCanonicalIncomingOperationIndex)
    }
    
    func withUpdatedTopProcessedCanonicalIncomingOperationIndex(_ topProcessedCanonicalIncomingOperationIndex: Int32?) -> SecretChatSequenceBasedLayerState {
        return SecretChatSequenceBasedLayerState(layerNegotiationState: self.layerNegotiationState, rekeyState: self.rekeyState, baseIncomingOperationIndex: self.baseIncomingOperationIndex, baseOutgoingOperationIndex: self.baseOutgoingOperationIndex, topProcessedCanonicalIncomingOperationIndex: topProcessedCanonicalIncomingOperationIndex)
    }
    
    static func ==(lhs: SecretChatSequenceBasedLayerState, rhs: SecretChatSequenceBasedLayerState) -> Bool {
        if lhs.layerNegotiationState != rhs.layerNegotiationState {
            return false
        }
        if lhs.rekeyState != rhs.rekeyState {
            return false
        }
        if lhs.baseIncomingOperationIndex != rhs.baseIncomingOperationIndex || lhs.baseOutgoingOperationIndex != rhs.baseOutgoingOperationIndex {
            return false
        }
        if lhs.topProcessedCanonicalIncomingOperationIndex != rhs.topProcessedCanonicalIncomingOperationIndex {
            return false
        }
        return true
    }
}

enum SecretChatEmbeddedState: Coding, Equatable {
    case terminated
    case handshake
    case basicLayer
    case sequenceBasedLayer(SecretChatSequenceBasedLayerState)
    
    var peerState: SecretChatEmbeddedPeerState {
        switch self {
            case .terminated:
                return .terminated
            case .handshake:
                return .handshake
            case .basicLayer, .sequenceBasedLayer:
                return .active
        }
    }
    
    init(decoder: Decoder) {
        switch decoder.decodeInt32ForKey("r") as Int32 {
            case SecretChatEmbeddedStateValue.handshake.rawValue:
                self = .terminated
            case SecretChatEmbeddedStateValue.handshake.rawValue:
                self = .handshake
            case SecretChatEmbeddedStateValue.basicLayer.rawValue:
                self = .basicLayer
            case SecretChatEmbeddedStateValue.sequenceBasedLayer.rawValue:
                self = .sequenceBasedLayer(decoder.decodeObjectForKey("s", decoder: { SecretChatSequenceBasedLayerState(decoder: $0) }) as! SecretChatSequenceBasedLayerState)
            default:
                self = .handshake
        }
    }
    
    func encode(_ encoder: Encoder) {
        switch self {
            case .terminated:
                encoder.encodeInt32(SecretChatEmbeddedStateValue.terminated.rawValue, forKey: "r")
            case .handshake:
                encoder.encodeInt32(SecretChatEmbeddedStateValue.handshake.rawValue, forKey: "r")
            case .basicLayer:
                encoder.encodeInt32(SecretChatEmbeddedStateValue.basicLayer.rawValue, forKey: "r")
            case let .sequenceBasedLayer(state):
                encoder.encodeInt32(SecretChatEmbeddedStateValue.sequenceBasedLayer.rawValue, forKey: "r")
                encoder.encodeObject(state, forKey: "s")
        }
    }
    
    static func ==(lhs: SecretChatEmbeddedState, rhs: SecretChatEmbeddedState) -> Bool {
        switch lhs {
            case .terminated:
                if case .terminated = rhs {
                    return true
                } else {
                    return false
                }
            case .handshake:
                if case .handshake = rhs {
                    return true
                } else {
                    return false
                }
            case .basicLayer:
                if case .basicLayer = rhs {
                    return true
                } else {
                    return false
                }
            case let .sequenceBasedLayer(state):
                if case .sequenceBasedLayer(state) = rhs {
                    return true
                } else {
                    return false
                }
        }
    }
}

final class SecretChatState: PeerChatState, Equatable {
    let role: SecretChatRole
    let embeddedState: SecretChatEmbeddedState
    let keychain: SecretChatKeychain
    let messageAutoremoveTimeout: Int32?
    
    init(role: SecretChatRole, embeddedState: SecretChatEmbeddedState, keychain: SecretChatKeychain, messageAutoremoveTimeout: Int32?) {
        self.role = role
        self.embeddedState = embeddedState
        self.keychain = keychain
        self.messageAutoremoveTimeout = messageAutoremoveTimeout
    }
    
    init(decoder: Decoder) {
        self.role = SecretChatRole(rawValue: decoder.decodeInt32ForKey("r"))!
        self.embeddedState = decoder.decodeObjectForKey("s", decoder: { return SecretChatEmbeddedState(decoder: $0) }) as! SecretChatEmbeddedState
        self.keychain = decoder.decodeObjectForKey("k", decoder: { return SecretChatKeychain(decoder: $0) }) as! SecretChatKeychain
        self.messageAutoremoveTimeout = decoder.decodeInt32ForKey("a")
    }
    
    func encode(_ encoder: Encoder) {
        encoder.encodeInt32(self.role.rawValue, forKey: "r")
        encoder.encodeObject(self.embeddedState, forKey: "s")
        encoder.encodeObject(self.keychain, forKey: "k")
        if let messageAutoremoveTimeout = self.messageAutoremoveTimeout {
            encoder.encodeInt32(messageAutoremoveTimeout, forKey: "a")
        } else {
            encoder.encodeNil(forKey: "a")
        }
    }
    
    func equals(_ other: PeerChatState) -> Bool {
        if let other = other as? SecretChatState, other == self {
            return true
        }
        return false
    }
    
    static func ==(lhs: SecretChatState, rhs: SecretChatState) -> Bool {
        return lhs.role == rhs.role && lhs.embeddedState == rhs.embeddedState && lhs.keychain == rhs.keychain && lhs.messageAutoremoveTimeout == rhs.messageAutoremoveTimeout
    }
    
    func withUpdatedEmbeddedState(_ embeddedState: SecretChatEmbeddedState) -> SecretChatState {
        return SecretChatState(role: self.role, embeddedState: embeddedState, keychain: self.keychain, messageAutoremoveTimeout: self.messageAutoremoveTimeout)
    }
    
    func withUpdatedKeychain(_ keychain: SecretChatKeychain) -> SecretChatState {
        return SecretChatState(role: self.role, embeddedState: self.embeddedState, keychain: keychain, messageAutoremoveTimeout: self.messageAutoremoveTimeout)
    }
    
    func withUpdatedMessageAutoremoveTimeout(_ messageAutoremoveTimeout: Int32?) -> SecretChatState {
        return SecretChatState(role: self.role, embeddedState: self.embeddedState, keychain: self.keychain, messageAutoremoveTimeout: messageAutoremoveTimeout)
    }
}
