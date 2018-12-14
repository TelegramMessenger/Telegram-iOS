import Foundation
#if os(macOS)
import PostboxMac
#else
import Postbox
#endif

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

extension TelegramMediaPollOption {
    init(apiOption: Api.PollAnswer) {
        switch apiOption {
            case let .pollAnswer(text, option):
                self.init(text: text, opaqueIdentifier: option.makeData())
        }
    }
    
    var apiOption: Api.PollAnswer {
        return .pollAnswer(text: self.text, option: Buffer(data: self.opaqueIdentifier))
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

extension TelegramMediaPollOptionVoters {
    init(apiVoters: Api.PollAnswerVoters) {
        switch apiVoters {
            case let .pollAnswerVoters(flags, option, voters):
                self.init(selected: (flags & (1 << 0)) != 0, opaqueIdentifier: option.makeData(), count: voters)
        }
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

extension TelegramMediaPollResults {
    init(apiResults: Api.PollResults) {
        switch apiResults {
            case let .pollResults(_, results, totalVoters):
                self.init(voters: results.flatMap({ $0.map(TelegramMediaPollOptionVoters.init(apiVoters:)) }), totalVoters: totalVoters)
        }
    }
}

public final class TelegramMediaPoll: Media, Equatable {
    public let id: MediaId? = nil
    public let peerIds: [PeerId] = []
    
    public let text: String
    public let options: [TelegramMediaPollOption]
    public let results: TelegramMediaPollResults?
    
    public init(text: String, options: [TelegramMediaPollOption], results: TelegramMediaPollResults?) {
        self.text = text
        self.options = options
        self.results = results
    }
    
    public init(decoder: PostboxDecoder) {
        self.text = decoder.decodeStringForKey("t", orElse: "")
        self.options = decoder.decodeObjectArrayWithDecoderForKey("os")
        self.results = decoder.decodeObjectForKey("rs", decoder: { TelegramMediaPollResults(decoder: $0) }) as? TelegramMediaPollResults
    }
    
    public func encode(_ encoder: PostboxEncoder) {
        encoder.encodeString(self.text, forKey: "t")
        encoder.encodeObjectArray(self.options, forKey: "os")
        if let results = self.results {
            encoder.encodeObject(results, forKey: "rs")
        } else {
            encoder.encodeNil(forKey: "rs")
        }
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
        if lhs.text != rhs.text {
            return false
        }
        if lhs.options != rhs.options {
            return false
        }
        if lhs.results != rhs.results {
            return false
        }
        return true
    }
    
    func withUpdatedResults(_ results: (TelegramMediaPollResults, Bool)?) -> TelegramMediaPoll {
        let updatedResults: TelegramMediaPollResults?
        if let (results, min) = results {
            if min, let currentResults = self.results, let currentVoters = currentResults.voters, let updatedVoters = results.voters {
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
                updatedResults = results
            }
        } else {
            updatedResults = nil
        }
        return TelegramMediaPoll(text: self.text, options: self.options, results: updatedResults)
    }
}
