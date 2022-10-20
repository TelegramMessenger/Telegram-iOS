import Foundation
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
    public let isCorrect: Bool
    
    public init(selected: Bool, opaqueIdentifier: Data, count: Int32, isCorrect: Bool) {
        self.selected = selected
        self.opaqueIdentifier = opaqueIdentifier
        self.count = count
        self.isCorrect = isCorrect
    }
    
    public init(decoder: PostboxDecoder) {
        self.selected = decoder.decodeInt32ForKey("s", orElse: 0) != 0
        self.opaqueIdentifier = decoder.decodeDataForKey("i") ?? Data()
        self.count = decoder.decodeInt32ForKey("c", orElse: 0)
        self.isCorrect = decoder.decodeInt32ForKey("cr", orElse: 0) != 0
    }
    
    public func encode(_ encoder: PostboxEncoder) {
        encoder.encodeInt32(self.selected ? 1 : 0, forKey: "s")
        encoder.encodeData(self.opaqueIdentifier, forKey: "i")
        encoder.encodeInt32(self.count, forKey: "c")
        encoder.encodeInt32(self.isCorrect ? 1 : 0, forKey: "cr")
    }
}

public struct TelegramMediaPollResults: Equatable, PostboxCoding {
    public struct Solution: Equatable {
        public let text: String
        public let entities: [MessageTextEntity]
        
        public init(text: String, entities: [MessageTextEntity]) {
            self.text = text
            self.entities = entities
        }
    }
    
    public let voters: [TelegramMediaPollOptionVoters]?
    public let totalVoters: Int32?
    public let recentVoters: [PeerId]
    public let solution: TelegramMediaPollResults.Solution?
    
    public init(voters: [TelegramMediaPollOptionVoters]?, totalVoters: Int32?, recentVoters: [PeerId], solution: TelegramMediaPollResults.Solution?) {
        self.voters = voters
        self.totalVoters = totalVoters
        self.recentVoters = recentVoters
        self.solution = solution
    }
    
    public init(decoder: PostboxDecoder) {
        self.voters = decoder.decodeOptionalObjectArrayWithDecoderForKey("v")
        self.totalVoters = decoder.decodeOptionalInt32ForKey("t")
        self.recentVoters = decoder.decodeInt64ArrayForKey("rv").map(PeerId.init)
        if let text = decoder.decodeOptionalStringForKey("sol") {
            let entities: [MessageTextEntity] = decoder.decodeObjectArrayWithDecoderForKey("solent")
            self.solution = TelegramMediaPollResults.Solution(text: text, entities: entities)
        } else {
            self.solution = nil
        }
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
        encoder.encodeInt64Array(self.recentVoters.map { $0.toInt64() }, forKey: "rv")
        if let solution = self.solution {
            encoder.encodeString(solution.text, forKey: "sol")
            encoder.encodeObjectArray(solution.entities, forKey: "solent")
        } else {
            encoder.encodeNil(forKey: "sol")
        }
    }
}

public enum TelegramMediaPollPublicity: Int32 {
    case anonymous
    case `public`
}

public enum TelegramMediaPollKind: Equatable, PostboxCoding {
    case poll(multipleAnswers: Bool)
    case quiz
    
    public init(decoder: PostboxDecoder) {
        switch decoder.decodeInt32ForKey("_v", orElse: 0) {
        case 0:
            self = .poll(multipleAnswers: decoder.decodeInt32ForKey("m", orElse: 0) != 0)
        case 1:
            self = .quiz
        default:
            assertionFailure()
            self = .poll(multipleAnswers: false)
        }
    }
    
    public func encode(_ encoder: PostboxEncoder) {
        switch self {
        case let .poll(multipleAnswers):
            encoder.encodeInt32(0, forKey: "_v")
            encoder.encodeInt32(multipleAnswers ? 1 : 0, forKey: "m")
        case .quiz:
            encoder.encodeInt32(1, forKey: "_v")
        }
    }
}

public final class TelegramMediaPoll: Media, Equatable {
    public var id: MediaId? {
        return self.pollId
    }
    public let pollId: MediaId
    public var peerIds: [PeerId] {
        return results.recentVoters
    }
    
    public let publicity: TelegramMediaPollPublicity
    public let kind: TelegramMediaPollKind
    
    public let text: String
    public let options: [TelegramMediaPollOption]
    public let correctAnswers: [Data]?
    public let results: TelegramMediaPollResults
    public let isClosed: Bool
    public let deadlineTimeout: Int32?
    
    public init(pollId: MediaId, publicity: TelegramMediaPollPublicity, kind: TelegramMediaPollKind, text: String, options: [TelegramMediaPollOption], correctAnswers: [Data]?, results: TelegramMediaPollResults, isClosed: Bool, deadlineTimeout: Int32?) {
        self.pollId = pollId
        self.publicity = publicity
        self.kind = kind
        self.text = text
        self.options = options
        self.correctAnswers = correctAnswers
        self.results = results
        self.isClosed = isClosed
        self.deadlineTimeout = deadlineTimeout
    }
    
    public init(decoder: PostboxDecoder) {
        if let idBytes = decoder.decodeBytesForKeyNoCopy("i") {
            self.pollId = MediaId(idBytes)
        } else {
            self.pollId = MediaId(namespace: Namespaces.Media.LocalPoll, id: 0)
        }
        self.publicity = TelegramMediaPollPublicity(rawValue: decoder.decodeInt32ForKey("pb", orElse: 0)) ?? TelegramMediaPollPublicity.anonymous
        self.kind = decoder.decodeObjectForKey("kn", decoder: { TelegramMediaPollKind(decoder: $0) }) as? TelegramMediaPollKind ?? TelegramMediaPollKind.poll(multipleAnswers: false)
        self.text = decoder.decodeStringForKey("t", orElse: "")
        self.options = decoder.decodeObjectArrayWithDecoderForKey("os")
        self.correctAnswers = decoder.decodeOptionalDataArrayForKey("ca")
        self.results = decoder.decodeObjectForKey("rs", decoder: { TelegramMediaPollResults(decoder: $0) }) as? TelegramMediaPollResults ?? TelegramMediaPollResults(voters: nil, totalVoters: nil, recentVoters: [], solution: nil)
        self.isClosed = decoder.decodeInt32ForKey("ic", orElse: 0) != 0
        self.deadlineTimeout = decoder.decodeOptionalInt32ForKey("dt")
    }
    
    public func encode(_ encoder: PostboxEncoder) {
        let buffer = WriteBuffer()
        self.pollId.encodeToBuffer(buffer)
        encoder.encodeInt32(self.publicity.rawValue, forKey: "pb")
        encoder.encodeObject(self.kind, forKey: "kn")
        encoder.encodeBytes(buffer, forKey: "i")
        encoder.encodeString(self.text, forKey: "t")
        encoder.encodeObjectArray(self.options, forKey: "os")
        if let correctAnswers = self.correctAnswers {
            encoder.encodeDataArray(correctAnswers, forKey: "ca")
        } else {
            encoder.encodeNil(forKey: "ca")
        }
        encoder.encodeObject(results, forKey: "rs")
        encoder.encodeInt32(self.isClosed ? 1 : 0, forKey: "ic")
        if let deadlineTimeout = self.deadlineTimeout {
            encoder.encodeInt32(deadlineTimeout, forKey: "dt")
        } else {
            encoder.encodeNil(forKey: "dt")
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
        if lhs.pollId != rhs.pollId {
            return false
        }
        if lhs.publicity != rhs.publicity {
            return false
        }
        if lhs.kind != rhs.kind {
            return false
        }
        if lhs.text != rhs.text {
            return false
        }
        if lhs.options != rhs.options {
            return false
        }
        if lhs.correctAnswers != rhs.correctAnswers {
            return false
        }
        if lhs.results != rhs.results {
            return false
        }
        if lhs.isClosed != rhs.isClosed {
            return false
        }
        if lhs.deadlineTimeout != rhs.deadlineTimeout {
            return false
        }
        return true
    }
    
    public func withUpdatedResults(_ results: TelegramMediaPollResults, min: Bool) -> TelegramMediaPoll {
        let updatedResults: TelegramMediaPollResults
        if min {
            if let currentVoters = self.results.voters, let updatedVoters = results.voters {
                var selectedOpaqueIdentifiers = Set<Data>()
                var correctOpaqueIdentifiers = Set<Data>()
                for voters in currentVoters {
                    if voters.selected {
                        selectedOpaqueIdentifiers.insert(voters.opaqueIdentifier)
                    }
                    if voters.isCorrect {
                        correctOpaqueIdentifiers.insert(voters.opaqueIdentifier)
                    }
                }
                updatedResults = TelegramMediaPollResults(voters: updatedVoters.map({ voters in
                    return TelegramMediaPollOptionVoters(selected: selectedOpaqueIdentifiers.contains(voters.opaqueIdentifier), opaqueIdentifier: voters.opaqueIdentifier, count: voters.count, isCorrect: correctOpaqueIdentifiers.contains(voters.opaqueIdentifier))
                }), totalVoters: results.totalVoters, recentVoters: results.recentVoters, solution: results.solution ?? self.results.solution)
            } else if let updatedVoters = results.voters {
                updatedResults = TelegramMediaPollResults(voters: updatedVoters, totalVoters: results.totalVoters, recentVoters: results.recentVoters, solution: results.solution ?? self.results.solution)
            } else {
                updatedResults = TelegramMediaPollResults(voters: self.results.voters, totalVoters: results.totalVoters, recentVoters: results.recentVoters, solution: results.solution ?? self.results.solution)
            }
        } else {
            updatedResults = results
        }
        return TelegramMediaPoll(pollId: self.pollId, publicity: self.publicity, kind: self.kind, text: self.text, options: self.options, correctAnswers: self.correctAnswers, results: updatedResults, isClosed: self.isClosed, deadlineTimeout: self.deadlineTimeout)
    }
}
