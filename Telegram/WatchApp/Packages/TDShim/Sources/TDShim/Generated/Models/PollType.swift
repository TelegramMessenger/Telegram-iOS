//
//  PollType.swift
//  tl2swift
//
//  Generated automatically. Any changes will be lost!
//  Based on TDLib 1.8.64-49b3bcbb-49b3bcbb
//  https://github.com/tdlib/td/tree/49b3bcbb
//

import Foundation


/// Describes the type of poll
public indirect enum PollType: Codable, Equatable, Hashable {

    /// A regular poll
    case pollTypeRegular

    /// A poll in quiz mode, which has predefined correct answers
    case pollTypeQuiz(PollTypeQuiz)

    /// Decoded when the @type is not one of the known cases (forward-compatible).
    case unsupported

    private enum Kind: String, Codable {
        case pollTypeRegular
        case pollTypeQuiz
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: DtoCodingKeys.self)
        let typeString = try container.decode(String.self, forKey: .type)
        guard let type = Kind(rawValue: typeString) else {
            self = .unsupported
            return
        }
        switch type {
        case .pollTypeRegular:
            self = .pollTypeRegular
        case .pollTypeQuiz:
            let value = try PollTypeQuiz(from: decoder)
            self = .pollTypeQuiz(value)
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: DtoCodingKeys.self)
        switch self {
        case .pollTypeRegular:
            try container.encode(Kind.pollTypeRegular, forKey: .type)
        case .pollTypeQuiz(let value):
            try container.encode(Kind.pollTypeQuiz, forKey: .type)
            try value.encode(to: encoder)
        case .unsupported:
            try container.encode("unsupported", forKey: .type)
        }
    }
}

/// A poll in quiz mode, which has predefined correct answers
public struct PollTypeQuiz: Codable, Equatable, Hashable {

    /// Increasing list of 0-based identifiers of the correct answer options; empty for a yet unanswered poll
    public let correctOptionIds: [Int]

    /// Text that is shown when the user chooses an incorrect answer or taps on the lamp icon; empty for a yet unanswered poll
    public let explanation: FormattedText

    /// Media that is shown when the user chooses an incorrect answer or taps on the lamp icon; may be null if none or the poll is unanswered yet. If present, currently, can be only of the types messageAnimation, messageAudio, messageDocument, messageLocation, messagePhoto, messageVenue, or messageVideo without caption
    public let explanationMedia: MessageContent?


    public init(
        correctOptionIds: [Int],
        explanation: FormattedText,
        explanationMedia: MessageContent?
    ) {
        self.correctOptionIds = correctOptionIds
        self.explanation = explanation
        self.explanationMedia = explanationMedia
    }
}

