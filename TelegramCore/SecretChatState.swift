import Foundation
#if os(macOS)
    import PostboxMac
#else
    import Postbox
#endif

enum SecretChatRole {
    case creator
    case participant
}

struct SecretChatFingerprint: Equatable {
    let k0: Int64
    let k1: Int64
    let k2: Int64
    let k3: Int64
    
    static func ==(lhs: SecretChatFingerprint, rhs: SecretChatFingerprint) -> Bool {
        if lhs.k0 != rhs.k0 {
            return false
        }
        if lhs.k1 != rhs.k1 {
            return false
        }
        if lhs.k2 != rhs.k2 {
            return false
        }
        if lhs.k3 != rhs.k3 {
            return false
        }
        return true
    }
}

struct SecretChatSequenceState: Equatable {
    let seqIn: Int32
    let seqOut: Int32
    
    static func ==(lhs: SecretChatSequenceState, rhs: SecretChatSequenceState) -> Bool {
        if lhs.seqIn == rhs.seqIn && lhs.seqOut == rhs.seqOut {
            return true
        } else {
            return false
        }
    }
}

struct SecretChatLayerState: Equatable {
    let effectiveLayer: Int32
    let sentLayer: Int32?
    let receivedLayer: Int32?
    let sequenceState: SecretChatSequenceState?
    
    static func ==(lhs: SecretChatLayerState, rhs: SecretChatLayerState) -> Bool {
        if lhs.effectiveLayer != rhs.effectiveLayer {
            return false
        }
        if lhs.sentLayer != rhs.sentLayer {
            return false
        }
        if lhs.receivedLayer != rhs.receivedLayer {
            return false
        }
        if lhs.sequenceState != rhs.sequenceState {
            return false
        }
        return true
    }
}

enum SecretChatEmbeddedState: Equatable {
    case requested(accessHash: Int64, gA: MemoryBuffer)
    case active(accessHash: Int64, role: SecretChatRole, baseKeyFingerprint: SecretChatFingerprint, layerState: SecretChatLayerState)
    case closed

    static func ==(lhs: SecretChatEmbeddedState, rhs: SecretChatEmbeddedState) -> Bool {
        switch lhs {
            case let .requested(lhsAccessHash, lhsGA):
                if case let .requested(rhsAccessHash, rhsGA) = rhs, lhsAccessHash == rhsAccessHash, lhsGA == rhsGA {
                    return true
                } else {
                    return false
                }
            case let .active(lhsAccessHash, lhsRole, lhsBaseKeyFingerprint, lhsLayerState):
                if case let .active(rhsAccessHash, rhsRole, rhsBaseKeyFingerprint, rhsLayerState) = rhs, lhsAccessHash == rhsAccessHash, lhsRole == rhsRole, lhsBaseKeyFingerprint == rhsBaseKeyFingerprint, lhsLayerState == rhsLayerState {
                    return true
                } else {
                    return false
                }
            case .closed:
                if case .closed = rhs {
                    return true
                } else {
                    return false
                }
        }
    }
}

final class SecretChatState: PeerChatState, Equatable, CustomStringConvertible {
    let embeddedState: SecretChatEmbeddedState
    
    init(embeddedState: SecretChatEmbeddedState) {
        self.embeddedState = embeddedState
    }
    
    init(decoder: Decoder) {
        preconditionFailure()
    }
    
    func encode(_ encoder: Encoder) {
        
    }
    
    func equals(_ other: PeerChatState) -> Bool {
        if let other = other as? SecretChatState, other == self {
            return true
        }
        return false
    }
    
    var description: String {
        return "(embeddedState: \(self.embeddedState))"
    }
    
    static func ==(lhs: SecretChatState, rhs: SecretChatState) -> Bool {
        return lhs.embeddedState == rhs.embeddedState
    }
}
