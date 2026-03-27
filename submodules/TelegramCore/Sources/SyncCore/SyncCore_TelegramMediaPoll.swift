import Foundation
import Postbox

public struct TelegramMediaPollOption: Equatable, PostboxCoding {
    public let text: String
    public let entities: [MessageTextEntity]
    public let opaqueIdentifier: Data
    public let media: Media?
    public let date: Int32?
    public let addedBy: EnginePeer.Id?

    public init(text: String, entities: [MessageTextEntity], opaqueIdentifier: Data, media: Media? = nil, date: Int32?, addedBy: EnginePeer.Id?) {
        self.text = text
        self.entities = entities
        self.opaqueIdentifier = opaqueIdentifier
        self.media = media
        self.date = date
        self.addedBy = addedBy
    }

    public init(decoder: PostboxDecoder) {
        self.text = decoder.decodeStringForKey("t", orElse: "")
        self.entities = decoder.decodeObjectArrayWithDecoderForKey("et")
        self.opaqueIdentifier = decoder.decodeDataForKey("i") ?? Data()
        self.media = decoder.decodeObjectForKey("md") as? Media
        self.date = decoder.decodeOptionalInt32ForKey("d")
        self.addedBy = decoder.decodeOptionalInt64ForKey("ab").flatMap { PeerId($0) }
    }

    public func encode(_ encoder: PostboxEncoder) {
        encoder.encodeString(self.text, forKey: "t")
        encoder.encodeObjectArray(self.entities, forKey: "et")
        encoder.encodeData(self.opaqueIdentifier, forKey: "i")
        if let media = self.media {
            encoder.encodeObject(media, forKey: "md")
        } else {
            encoder.encodeNil(forKey: "md")
        }
        if let date = self.date {
            encoder.encodeInt32(date, forKey: "d")
        } else {
            encoder.encodeNil(forKey: "d")
        }
        if let addedBy = self.addedBy?.toInt64() {
            encoder.encodeInt64(addedBy, forKey: "ab")
        } else {
            encoder.encodeNil(forKey: "ab")
        }
    }

    public static func ==(lhs: TelegramMediaPollOption, rhs: TelegramMediaPollOption) -> Bool {
        if lhs.text != rhs.text {
            return false
        }
        if lhs.entities != rhs.entities {
            return false
        }
        if lhs.opaqueIdentifier != rhs.opaqueIdentifier {
            return false
        }
        if let lhsMedia = lhs.media, let rhsMedia = rhs.media {
            if !lhsMedia.isEqual(to: rhsMedia) {
                return false
            }
        } else if (lhs.media == nil) != (rhs.media == nil) {
            return false
        }
        if lhs.date != rhs.date {
            return false
        }
        if lhs.addedBy != rhs.addedBy {
            return false
        }
        return true
    }
}

public struct TelegramMediaPollOptionVoters: Equatable, PostboxCoding {
    public let selected: Bool
    public let opaqueIdentifier: Data
    public let count: Int32?
    public let isCorrect: Bool
    public let recentVoters: [PeerId]

    public init(selected: Bool, opaqueIdentifier: Data, count: Int32?, isCorrect: Bool, recentVoters: [PeerId] = []) {
        self.selected = selected
        self.opaqueIdentifier = opaqueIdentifier
        self.count = count
        self.isCorrect = isCorrect
        self.recentVoters = recentVoters
    }

    public init(decoder: PostboxDecoder) {
        self.selected = decoder.decodeInt32ForKey("s", orElse: 0) != 0
        self.opaqueIdentifier = decoder.decodeDataForKey("i") ?? Data()
        self.count = decoder.decodeOptionalInt32ForKey("c")
        self.isCorrect = decoder.decodeInt32ForKey("cr", orElse: 0) != 0
        self.recentVoters = decoder.decodeInt64ArrayForKey("orv").map(PeerId.init)
    }

    public func encode(_ encoder: PostboxEncoder) {
        encoder.encodeInt32(self.selected ? 1 : 0, forKey: "s")
        encoder.encodeData(self.opaqueIdentifier, forKey: "i")
        if let count = self.count {
            encoder.encodeInt32(count, forKey: "c")
        } else {
            encoder.encodeNil(forKey: "c")
        }
        encoder.encodeInt32(self.isCorrect ? 1 : 0, forKey: "cr")
        encoder.encodeInt64Array(self.recentVoters.map { $0.toInt64() }, forKey: "orv")
    }
}

public struct TelegramMediaPollResults: Equatable, PostboxCoding {
    public struct Solution: Equatable {
        public let text: String
        public let entities: [MessageTextEntity]
        public let media: Media?

        public init(text: String, entities: [MessageTextEntity], media: Media? = nil) {
            self.text = text
            self.entities = entities
            self.media = media
        }

        public static func ==(lhs: Solution, rhs: Solution) -> Bool {
            if lhs.text != rhs.text { return false }
            if lhs.entities != rhs.entities { return false }
            if let lhsMedia = lhs.media, let rhsMedia = rhs.media {
                if !lhsMedia.isEqual(to: rhsMedia) { return false }
            } else if (lhs.media == nil) != (rhs.media == nil) {
                return false
            }
            return true
        }
    }

    public let voters: [TelegramMediaPollOptionVoters]?
    public let totalVoters: Int32?
    public let recentVoters: [PeerId]
    public let solution: TelegramMediaPollResults.Solution?
    public let hasUnseenVotes: Bool?

    public init(voters: [TelegramMediaPollOptionVoters]?, totalVoters: Int32?, recentVoters: [PeerId], solution: TelegramMediaPollResults.Solution?, hasUnseenVotes: Bool?) {
        self.voters = voters
        self.totalVoters = totalVoters
        self.recentVoters = recentVoters
        self.solution = solution
        self.hasUnseenVotes = hasUnseenVotes
    }

    public init(decoder: PostboxDecoder) {
        self.voters = decoder.decodeOptionalObjectArrayWithDecoderForKey("v")
        self.totalVoters = decoder.decodeOptionalInt32ForKey("t")
        self.recentVoters = decoder.decodeInt64ArrayForKey("rv").map(PeerId.init)
        if let text = decoder.decodeOptionalStringForKey("sol") {
            let entities: [MessageTextEntity] = decoder.decodeObjectArrayWithDecoderForKey("solent")
            let media = decoder.decodeObjectForKey("solmd") as? Media
            self.solution = TelegramMediaPollResults.Solution(text: text, entities: entities, media: media)
        } else {
            self.solution = nil
        }
        self.hasUnseenVotes = decoder.decodeOptionalBoolForKey("uns")
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
            if let media = solution.media {
                encoder.encodeObject(media, forKey: "solmd")
            } else {
                encoder.encodeNil(forKey: "solmd")
            }
        } else {
            encoder.encodeNil(forKey: "sol")
        }
        if let hasUnseenVotes = self.hasUnseenVotes {
            encoder.encodeBool(hasUnseenVotes, forKey: "uns")
        } else {
            encoder.encodeNil(forKey: "uns")
        }
    }
}

public enum TelegramMediaPollPublicity: Int32 {
    case anonymous
    case `public`
}

public enum TelegramMediaPollKind: Equatable, PostboxCoding {
    case poll(multipleAnswers: Bool)
    case quiz(multipleAnswers: Bool)

    public init(decoder: PostboxDecoder) {
        switch decoder.decodeInt32ForKey("_v", orElse: 0) {
        case 0:
            self = .poll(multipleAnswers: decoder.decodeInt32ForKey("m", orElse: 0) != 0)
        case 1:
            self = .quiz(multipleAnswers: decoder.decodeInt32ForKey("m", orElse: 0) != 0)
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
        case let .quiz(multipleAnswers):
            encoder.encodeInt32(1, forKey: "_v")
            encoder.encodeInt32(multipleAnswers ? 1 : 0, forKey: "m")
        }
    }
    
    public var multipleAnswers: Bool {
        switch self {
        case let .poll(multipleAnswers), let .quiz(multipleAnswers):
            return multipleAnswers
        }
    }
}

public final class TelegramMediaPoll: Media, Equatable {
    public var id: MediaId? {
        return self.pollId
    }
    public let pollId: MediaId
    public var peerIds: [PeerId] {
        var peerIds = results.recentVoters
        if let voters = results.voters {
            for voter in voters {
                peerIds.append(contentsOf: voter.recentVoters)
            }
        }
        for option in options {
            if let addedBy = option.addedBy {
                peerIds.append(addedBy)
            }
        }
        return peerIds
    }

    public let publicity: TelegramMediaPollPublicity
    public let kind: TelegramMediaPollKind

    public let text: String
    public let textEntities: [MessageTextEntity]
    public let options: [TelegramMediaPollOption]
    public let correctAnswers: [Data]?
    public let results: TelegramMediaPollResults
    public let isClosed: Bool
    public let deadlineTimeout: Int32?
    public let deadlineDate: Int32?
    public let pollHash: Int64

    public let openAnswers: Bool
    public let revotingDisabled: Bool
    public let shuffleAnswers: Bool
    public let hideResultsUntilClose: Bool
    public let isCreator: Bool
    public let attachedMedia: Media?

    public init(pollId: MediaId, publicity: TelegramMediaPollPublicity, kind: TelegramMediaPollKind, text: String, textEntities: [MessageTextEntity], options: [TelegramMediaPollOption], correctAnswers: [Data]?, results: TelegramMediaPollResults, isClosed: Bool, deadlineTimeout: Int32?, deadlineDate: Int32?, pollHash: Int64, openAnswers: Bool = false, revotingDisabled: Bool = false, shuffleAnswers: Bool = false, hideResultsUntilClose: Bool = false, isCreator: Bool = false, attachedMedia: Media? = nil) {
        self.pollId = pollId
        self.publicity = publicity
        self.kind = kind
        self.text = text
        self.textEntities = textEntities
        self.options = options
        self.correctAnswers = correctAnswers
        self.results = results
        self.isClosed = isClosed
        self.deadlineTimeout = deadlineTimeout
        self.deadlineDate = deadlineDate
        self.pollHash = pollHash
        self.openAnswers = openAnswers
        self.revotingDisabled = revotingDisabled
        self.shuffleAnswers = shuffleAnswers
        self.hideResultsUntilClose = hideResultsUntilClose
        self.isCreator = isCreator
        self.attachedMedia = attachedMedia
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
        self.textEntities = decoder.decodeObjectArrayWithDecoderForKey("te")
        self.options = decoder.decodeObjectArrayWithDecoderForKey("os")
        self.correctAnswers = decoder.decodeOptionalDataArrayForKey("ca")
        self.results = decoder.decodeObjectForKey("rs", decoder: { TelegramMediaPollResults(decoder: $0) }) as? TelegramMediaPollResults ?? TelegramMediaPollResults(voters: nil, totalVoters: nil, recentVoters: [], solution: nil, hasUnseenVotes: nil)
        self.isClosed = decoder.decodeInt32ForKey("ic", orElse: 0) != 0
        self.deadlineTimeout = decoder.decodeOptionalInt32ForKey("dt")
        self.deadlineDate = decoder.decodeOptionalInt32ForKey("dd")
        self.pollHash = decoder.decodeInt64ForKey("ph", orElse: 0)
        self.openAnswers = decoder.decodeInt32ForKey("oa", orElse: 0) != 0
        self.revotingDisabled = decoder.decodeInt32ForKey("rd", orElse: 0) != 0
        self.shuffleAnswers = decoder.decodeInt32ForKey("sa", orElse: 0) != 0
        self.hideResultsUntilClose = decoder.decodeInt32ForKey("hr", orElse: 0) != 0
        self.isCreator = decoder.decodeInt32ForKey("cr", orElse: 0) != 0
        self.attachedMedia = decoder.decodeObjectForKey("am") as? Media
    }

    public func encode(_ encoder: PostboxEncoder) {
        let buffer = WriteBuffer()
        self.pollId.encodeToBuffer(buffer)
        encoder.encodeInt32(self.publicity.rawValue, forKey: "pb")
        encoder.encodeObject(self.kind, forKey: "kn")
        encoder.encodeBytes(buffer, forKey: "i")
        encoder.encodeString(self.text, forKey: "t")
        encoder.encodeObjectArray(self.textEntities, forKey: "te")
        encoder.encodeObjectArray(self.options, forKey: "os")
        if let correctAnswers = self.correctAnswers {
            encoder.encodeDataArray(correctAnswers, forKey: "ca")
        } else {
            encoder.encodeNil(forKey: "ca")
        }
        encoder.encodeObject(self.results, forKey: "rs")
        encoder.encodeInt32(self.isClosed ? 1 : 0, forKey: "ic")
        if let deadlineTimeout = self.deadlineTimeout {
            encoder.encodeInt32(deadlineTimeout, forKey: "dt")
        } else {
            encoder.encodeNil(forKey: "dt")
        }
        if let deadlineDate = self.deadlineDate {
            encoder.encodeInt32(deadlineDate, forKey: "dd")
        } else {
            encoder.encodeNil(forKey: "dd")
        }
        encoder.encodeInt64(self.pollHash, forKey: "ph")
        encoder.encodeInt32(self.openAnswers ? 1 : 0, forKey: "oa")
        encoder.encodeInt32(self.revotingDisabled ? 1 : 0, forKey: "rd")
        encoder.encodeInt32(self.shuffleAnswers ? 1 : 0, forKey: "sa")
        encoder.encodeInt32(self.hideResultsUntilClose ? 1 : 0, forKey: "hr")
        encoder.encodeInt32(self.isCreator ? 1 : 0, forKey: "cr")
        if let attachedMedia = self.attachedMedia {
            encoder.encodeObject(attachedMedia, forKey: "am")
        } else {
            encoder.encodeNil(forKey: "am")
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
        if lhs.textEntities != rhs.textEntities {
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
        if lhs.deadlineDate != rhs.deadlineDate {
            return false
        }
        if lhs.pollHash != rhs.pollHash {
            return false
        }
        if lhs.openAnswers != rhs.openAnswers {
            return false
        }
        if lhs.revotingDisabled != rhs.revotingDisabled {
            return false
        }
        if lhs.shuffleAnswers != rhs.shuffleAnswers {
            return false
        }
        if lhs.hideResultsUntilClose != rhs.hideResultsUntilClose {
            return false
        }
        if lhs.isCreator != rhs.isCreator {
            return false
        }
        if let lhsMedia = lhs.attachedMedia, let rhsMedia = rhs.attachedMedia {
            if !lhsMedia.isEqual(to: rhsMedia) { return false }
        } else if (lhs.attachedMedia == nil) != (rhs.attachedMedia == nil) {
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
                    return TelegramMediaPollOptionVoters(selected: selectedOpaqueIdentifiers.contains(voters.opaqueIdentifier), opaqueIdentifier: voters.opaqueIdentifier, count: voters.count, isCorrect: correctOpaqueIdentifiers.contains(voters.opaqueIdentifier), recentVoters: voters.recentVoters)
                }), totalVoters: results.totalVoters, recentVoters: results.recentVoters, solution: results.solution ?? self.results.solution, hasUnseenVotes: results.hasUnseenVotes ?? self.results.hasUnseenVotes)
            } else if let updatedVoters = results.voters {
                updatedResults = TelegramMediaPollResults(voters: updatedVoters, totalVoters: results.totalVoters, recentVoters: results.recentVoters, solution: results.solution ?? self.results.solution, hasUnseenVotes: results.hasUnseenVotes ?? self.results.hasUnseenVotes)
            } else {
                updatedResults = TelegramMediaPollResults(voters: self.results.voters, totalVoters: results.totalVoters, recentVoters: results.recentVoters, solution: results.solution ?? self.results.solution, hasUnseenVotes: results.hasUnseenVotes ?? self.results.hasUnseenVotes)
            }
        } else {
            updatedResults = results
        }
        return TelegramMediaPoll(pollId: self.pollId, publicity: self.publicity, kind: self.kind, text: self.text, textEntities: self.textEntities, options: self.options, correctAnswers: self.correctAnswers, results: updatedResults, isClosed: self.isClosed, deadlineTimeout: self.deadlineTimeout, deadlineDate: self.deadlineDate, pollHash: self.pollHash, openAnswers: self.openAnswers, revotingDisabled: self.revotingDisabled, shuffleAnswers: self.shuffleAnswers, hideResultsUntilClose: self.hideResultsUntilClose, isCreator: self.isCreator, attachedMedia: self.attachedMedia)
    }
    
    public func withoutUnreadResults() -> TelegramMediaPoll {
        let updatedResults = TelegramMediaPollResults(voters: self.results.voters, totalVoters: self.results.totalVoters, recentVoters: self.results.recentVoters, solution: self.results.solution, hasUnseenVotes: false)
        return TelegramMediaPoll(pollId: self.pollId, publicity: self.publicity, kind: self.kind, text: self.text, textEntities: self.textEntities, options: self.options, correctAnswers: self.correctAnswers, results: updatedResults, isClosed: self.isClosed, deadlineTimeout: self.deadlineTimeout, deadlineDate: self.deadlineDate, pollHash: self.pollHash, openAnswers: self.openAnswers, revotingDisabled: self.revotingDisabled, shuffleAnswers: self.shuffleAnswers, hideResultsUntilClose: self.hideResultsUntilClose, isCreator: self.isCreator, attachedMedia: self.attachedMedia)
    }
}

