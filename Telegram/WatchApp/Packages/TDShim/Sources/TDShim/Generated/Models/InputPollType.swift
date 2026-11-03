//
//  InputPollType.swift
//  tl2swift
//
//  Generated automatically. Any changes will be lost!
//  Based on TDLib 1.8.64-49b3bcbb-49b3bcbb
//  https://github.com/tdlib/td/tree/49b3bcbb
//

import Foundation


/// Describes the type of poll to send
public indirect enum InputPollType: Codable, Equatable, Hashable {

    /// A regular poll
    case inputPollTypeRegular(InputPollTypeRegular)

    /// A poll in quiz mode, which has predefined correct answers
    case inputPollTypeQuiz(InputPollTypeQuiz)

    /// Decoded when the @type is not one of the known cases (forward-compatible).
    case unsupported

    private enum Kind: String, Codable {
        case inputPollTypeRegular
        case inputPollTypeQuiz
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: DtoCodingKeys.self)
        let typeString = try container.decode(String.self, forKey: .type)
        guard let type = Kind(rawValue: typeString) else {
            self = .unsupported
            return
        }
        switch type {
        case .inputPollTypeRegular:
            let value = try InputPollTypeRegular(from: decoder)
            self = .inputPollTypeRegular(value)
        case .inputPollTypeQuiz:
            let value = try InputPollTypeQuiz(from: decoder)
            self = .inputPollTypeQuiz(value)
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: DtoCodingKeys.self)
        switch self {
        case .inputPollTypeRegular(let value):
            try container.encode(Kind.inputPollTypeRegular, forKey: .type)
            try value.encode(to: encoder)
        case .inputPollTypeQuiz(let value):
            try container.encode(Kind.inputPollTypeQuiz, forKey: .type)
            try value.encode(to: encoder)
        case .unsupported:
            try container.encode("unsupported", forKey: .type)
        }
    }
}

/// A regular poll
public struct InputPollTypeRegular: Codable, Equatable, Hashable {

    /// True, if answer options can be added to the poll after creation; not supported in channel chats and for anonymous polls
    public let allowAddingOptions: Bool


    public init(allowAddingOptions: Bool) {
        self.allowAddingOptions = allowAddingOptions
    }
}

/// A poll in quiz mode, which has predefined correct answers
public struct InputPollTypeQuiz: Codable, Equatable, Hashable {

    /// Increasing list of 0-based identifiers of the correct answer options; must be non-empty
    public let correctOptionIds: [Int]

    /// Text that is shown when the user chooses an incorrect answer or taps on the lamp icon; 0-200 characters with at most 2 line feeds
    public let explanation: FormattedText

    /// Media that is shown when the user chooses an incorrect answer or taps on the lamp icon; pass null if none. Must be one of the following types: inputMessageAnimation, inputMessageAudio, inputMessageDocument, non-live inputMessageLocation, inputMessagePhoto, inputMessageVenue, or inputMessageVideo without caption
    public let explanationMedia: InputMessageContent?


    public init(
        correctOptionIds: [Int],
        explanation: FormattedText,
        explanationMedia: InputMessageContent?
    ) {
        self.correctOptionIds = correctOptionIds
        self.explanation = explanation
        self.explanationMedia = explanationMedia
    }
}

