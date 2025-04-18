import Postbox

public protocol AccountState: PostboxCoding {
    func equalsTo(_ other: AccountState) -> Bool
}

public func ==(lhs: AccountState, rhs: AccountState) -> Bool {
    return lhs.equalsTo(rhs)
}

public class AuthorizedAccountState: AccountState {
    public final class State: PostboxCoding, Equatable, CustomStringConvertible {
        public let pts: Int32
        public let qts: Int32
        public let date: Int32
        public let seq: Int32
        
        public init(pts: Int32, qts: Int32, date: Int32, seq: Int32) {
            self.pts = pts
            self.qts = qts
            self.date = date
            self.seq = seq
        }
        
        public init(decoder: PostboxDecoder) {
            self.pts = decoder.decodeInt32ForKey("pts", orElse: 0)
            self.qts = decoder.decodeInt32ForKey("qts", orElse: 0)
            self.date = decoder.decodeInt32ForKey("date", orElse: 0)
            self.seq = decoder.decodeInt32ForKey("seq", orElse: 0)
        }
        
        public func encode(_ encoder: PostboxEncoder) {
            encoder.encodeInt32(self.pts, forKey: "pts")
            encoder.encodeInt32(self.qts, forKey: "qts")
            encoder.encodeInt32(self.date, forKey: "date")
            encoder.encodeInt32(self.seq, forKey: "seq")
        }
        
        public var description: String {
            return "(pts: \(pts), qts: \(qts), seq: \(seq), date: \(date))"
        }
    }
    
    public struct InvalidatedChannel: PostboxCoding, Equatable {
        public var peerId: PeerId
        public var pts: Int32?
        public var validityMarker: Int64
        
        public init(peerId: PeerId, pts: Int32?, validityMarker: Int64) {
            self.peerId = peerId
            self.pts = pts
            self.validityMarker = validityMarker
        }
        
        public init(decoder: PostboxDecoder) {
            self.peerId = PeerId(decoder.decodeInt64ForKey("i", orElse: 0))
            self.pts = decoder.decodeOptionalInt32ForKey("p")
            self.validityMarker = decoder.decodeInt64ForKey("m", orElse: 0)
        }
        
        public func encode(_ encoder: PostboxEncoder) {
            encoder.encodeInt64(self.peerId.toInt64(), forKey: "i")
            if let pts = self.pts {
                encoder.encodeInt32(pts, forKey: "p")
            } else {
                encoder.encodeNil(forKey: "p")
            }
            encoder.encodeInt64(self.validityMarker, forKey: "m")
        }
    }
    
    public let isTestingEnvironment: Bool
    public let masterDatacenterId: Int32
    public let peerId: PeerId
    
    public let state: State?
    public let invalidatedChannels: [InvalidatedChannel]
    
    public required init(decoder: PostboxDecoder) {
        self.isTestingEnvironment = decoder.decodeInt32ForKey("isTestingEnvironment", orElse: 0) != 0
        self.masterDatacenterId = decoder.decodeInt32ForKey("masterDatacenterId", orElse: 0)
        self.peerId = PeerId(decoder.decodeInt64ForKey("peerId", orElse: 0))
        self.state = decoder.decodeObjectForKey("state", decoder: { return State(decoder: $0) }) as? State
        self.invalidatedChannels = decoder.decodeObjectArrayWithDecoderForKey("invalidatedChannels")
    }
    
    public func encode(_ encoder: PostboxEncoder) {
        encoder.encodeInt32(self.isTestingEnvironment ? 1 : 0, forKey: "isTestingEnvironment")
        encoder.encodeInt32(self.masterDatacenterId, forKey: "masterDatacenterId")
        encoder.encodeInt64(self.peerId.toInt64(), forKey: "peerId")
        if let state = self.state {
            encoder.encodeObject(state, forKey: "state")
        }
        encoder.encodeObjectArray(self.invalidatedChannels, forKey: "invalidatedChannels")
    }
    
    public init(isTestingEnvironment: Bool, masterDatacenterId: Int32, peerId: PeerId, state: State?, invalidatedChannels: [InvalidatedChannel]) {
        self.isTestingEnvironment = isTestingEnvironment
        self.masterDatacenterId = masterDatacenterId
        self.peerId = peerId
        self.state = state
        self.invalidatedChannels = invalidatedChannels
    }
    
    public func changedState(_ state: State) -> AuthorizedAccountState {
        return AuthorizedAccountState(isTestingEnvironment: self.isTestingEnvironment, masterDatacenterId: self.masterDatacenterId, peerId: self.peerId, state: state, invalidatedChannels: self.invalidatedChannels)
    }
    
    public func withInvalidatedChannels(_ invalidatedChannels: [InvalidatedChannel]) -> AuthorizedAccountState {
        return AuthorizedAccountState(isTestingEnvironment: self.isTestingEnvironment, masterDatacenterId: self.masterDatacenterId, peerId: self.peerId, state: self.state, invalidatedChannels: invalidatedChannels)
    }
    
    public func equalsTo(_ other: AccountState) -> Bool {
        if let other = other as? AuthorizedAccountState {
            return self.isTestingEnvironment == other.isTestingEnvironment && self.masterDatacenterId == other.masterDatacenterId &&
                self.peerId == other.peerId &&
                self.state == other.state &&
                self.invalidatedChannels == other.invalidatedChannels
        } else {
            return false
        }
    }
}

public func ==(lhs: AuthorizedAccountState.State, rhs: AuthorizedAccountState.State) -> Bool {
    return lhs.pts == rhs.pts &&
        lhs.qts == rhs.qts &&
        lhs.date == rhs.date &&
        lhs.seq == rhs.seq
}
