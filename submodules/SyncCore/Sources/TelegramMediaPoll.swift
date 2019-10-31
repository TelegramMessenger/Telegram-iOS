import Postbox

public struct TelegramMediaPollOption: Equatable, PostboxCoding {
    public let text: String
    public let opaqueIdentifier: Data
    
    public init(text: String, opaqueIdentifier: Data) {
        self.text = text
        self.opaqueIdentifier = opaqueIdentifier
    }
    
    public init(decoder: PostboxDecoder) {
        self.text = decoder.decodeStringForKey("t", orElse: "")
        self.opaqueIdentifier = decoder.decodeDataForKey("i") ?? Data()
    }
    
    public func encode(_ encoder: PostboxEncoder) {
        encoder.encodeString(self.text, forKey: "t")
        encoder.encodeData(self.opaqueIdentifier, forKey: "i")
    }
}

public struct TelegramMediaPollOptionVoters: Equatable, PostboxCoding {
    public let selected: Bool
    public let opaqueIdentifier: Data
    public let count: Int32
    
    public init(selected: Bool, opaqueIdentifier: Data, count: Int32) {
        self.selected = selected
        self.opaqueIdentifier = opaqueIdentifier
        self.count = count
    }
    
    public init(decoder: PostboxDecoder) {
        self.selected = decoder.decodeInt32ForKey("s", orElse: 0) != 0
        self.opaqueIdentifier = decoder.decodeDataForKey("i") ?? Data()
        self.count = decoder.decodeInt32ForKey("c", orElse: 0)
    }
    
    public func encode(_ encoder: PostboxEncoder) {
        encoder.encodeInt32(self.selected ? 1 : 0, forKey: "s")
        encoder.encodeData(self.opaqueIdentifier, forKey: "i")
        encoder.encodeInt32(self.count, forKey: "c")
    }
}

public struct TelegramMediaPollResults: Equatable, PostboxCoding {
    public let voters: [TelegramMediaPollOptionVoters]?
    public let totalVoters: Int32?
    
    public init(voters: [TelegramMediaPollOptionVoters]?, totalVoters: Int32?) {
        self.voters = voters
        self.totalVoters = totalVoters
    }
    
    public init(decoder: PostboxDecoder) {
        self.voters = decoder.decodeOptionalObjectArrayWithDecoderForKey("v")
        self.totalVoters = decoder.decodeOptionalInt32ForKey("t")
    }
    
    public func encode(_ encoder: PostboxEncoder) {
        if let voters = self.voters {
            encoder.encodeObjectArray(voters, forKey: "v")
        } else {
            encoder.encodeNil(forKey: "v")
        }
        if let totalVoters = self.totalVoters {
            encoder.encodeInt32(totalVoters, forKey: "t")
        } else {
            encoder.encodeNil(forKey: "t")
        }
    }
}

public final class TelegramMediaPoll: Media, Equatable {
    public var id: MediaId? {
        return self.pollId
    }
    public let pollId: MediaId
    public let peerIds: [PeerId] = []
    
    public let text: String
    public let options: [TelegramMediaPollOption]
    public let results: TelegramMediaPollResults
    public let isClosed: Bool
    
    public init(pollId: MediaId, text: String, options: [TelegramMediaPollOption], results: TelegramMediaPollResults, isClosed: Bool) {
        self.pollId = pollId
        self.text = text
        self.options = options
        self.results = results
        self.isClosed = isClosed
    }
    
    public init(decoder: PostboxDecoder) {
        if let idBytes = decoder.decodeBytesForKeyNoCopy("i") {
            self.pollId = MediaId(idBytes)
        } else {
            self.pollId = MediaId(namespace: Namespaces.Media.LocalPoll, id: 0)
        }
        self.text = decoder.decodeStringForKey("t", orElse: "")
        self.options = decoder.decodeObjectArrayWithDecoderForKey("os")
        self.results = decoder.decodeObjectForKey("rs", decoder: { TelegramMediaPollResults(decoder: $0) }) as? TelegramMediaPollResults ?? TelegramMediaPollResults(voters: nil, totalVoters: nil)
        self.isClosed = decoder.decodeInt32ForKey("ic", orElse: 0) != 0
    }
    
    public func encode(_ encoder: PostboxEncoder) {
        let buffer = WriteBuffer()
        self.pollId.encodeToBuffer(buffer)
        encoder.encodeBytes(buffer, forKey: "i")
        encoder.encodeString(self.text, forKey: "t")
        encoder.encodeObjectArray(self.options, forKey: "os")
        encoder.encodeObject(results, forKey: "rs")
        encoder.encodeInt32(self.isClosed ? 1 : 0, forKey: "ic")
    }
    
    public func isEqual(to other: Media) -> Bool {
        guard let other = other as? TelegramMediaPoll else {
            return false
        }
        return self == other
    }
    
    public func isSemanticallyEqual(to other: Media) -> Bool {
        return self.isEqual(to: other)
    }
    
    public static func ==(lhs: TelegramMediaPoll, rhs: TelegramMediaPoll) -> Bool {
        if lhs.pollId != rhs.pollId {
            return false
        }
        if lhs.text != rhs.text {
            return false
        }
        if lhs.options != rhs.options {
            return false
        }
        if lhs.results != rhs.results {
            return false
        }
        if lhs.isClosed != rhs.isClosed {
            return false
        }
        return true
    }
    
    public func withUpdatedResults(_ results: TelegramMediaPollResults, min: Bool) -> TelegramMediaPoll {
        let updatedResults: TelegramMediaPollResults
        if min {
            if let currentVoters = self.results.voters, let updatedVoters = results.voters {
                var selectedOpaqueIdentifiers = Set<Data>()
                for voters in currentVoters {
                    if voters.selected {
                        selectedOpaqueIdentifiers.insert(voters.opaqueIdentifier)
                    }
                }
                updatedResults = TelegramMediaPollResults(voters: updatedVoters.map({ voters in
                    return TelegramMediaPollOptionVoters(selected: selectedOpaqueIdentifiers.contains(voters.opaqueIdentifier), opaqueIdentifier: voters.opaqueIdentifier, count: voters.count)
                }), totalVoters: results.totalVoters)
            } else {
                updatedResults = TelegramMediaPollResults(voters: self.results.voters, totalVoters: results.totalVoters)
            }
        } else {
            updatedResults = results
        }
        return TelegramMediaPoll(pollId: self.pollId, text: self.text, options: self.options, results: updatedResults, isClosed: self.isClosed)
    }
}
