import Foundation
#if os(macOS)
    import PostboxMac
#else
    import Postbox
#endif

final class TelegramPeerGroupState: PeerGroupState, Equatable {
    let stateIndex: Int32
    let invalidatedStateIndex: Int32?
    
    init() {
        self.stateIndex = 0
        self.invalidatedStateIndex = nil
    }
    
    init(stateIndex: Int32, invalidatedStateIndex: Int32?) {
        self.stateIndex = stateIndex
        self.invalidatedStateIndex = invalidatedStateIndex
    }
    
    init(decoder: PostboxDecoder) {
        self.stateIndex = decoder.decodeInt32ForKey("state", orElse: 0)
        self.invalidatedStateIndex = decoder.decodeOptionalInt32ForKey("istate")
    }
    
    func encode(_ encoder: PostboxEncoder) {
        encoder.encodeInt32(stateIndex, forKey: "state")
        if let invalidatedStateIndex = self.invalidatedStateIndex {
            encoder.encodeInt32(invalidatedStateIndex, forKey: "istate")
        } else {
            encoder.encodeNil(forKey: "istate")
        }
    }
    
    func withInvalidatedStateIndex() -> TelegramPeerGroupState {
        let stateIndex = self.stateIndex + 1
        return TelegramPeerGroupState(stateIndex: stateIndex, invalidatedStateIndex: stateIndex)
    }
    
    func equals(_ other: PeerGroupState) -> Bool {
        if let other = other as? TelegramPeerGroupState, other == self {
            return true
        }
        return false
    }
    
    static func ==(lhs: TelegramPeerGroupState, rhs: TelegramPeerGroupState) -> Bool {
        return lhs.stateIndex == rhs.stateIndex && lhs.invalidatedStateIndex == rhs.invalidatedStateIndex
    }
}

