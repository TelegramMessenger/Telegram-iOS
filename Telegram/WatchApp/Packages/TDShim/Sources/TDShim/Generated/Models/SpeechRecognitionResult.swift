//
//  SpeechRecognitionResult.swift
//  tl2swift
//
//  Generated automatically. Any changes will be lost!
//  Based on TDLib 1.8.64-49b3bcbb-49b3bcbb
//  https://github.com/tdlib/td/tree/49b3bcbb
//

import Foundation


/// Describes result of speech recognition in a voice note
public indirect enum SpeechRecognitionResult: Codable, Equatable, Hashable {

    /// The speech recognition is ongoing
    case speechRecognitionResultPending(SpeechRecognitionResultPending)

    /// The speech recognition successfully finished
    case speechRecognitionResultText(SpeechRecognitionResultText)

    /// The speech recognition failed
    case speechRecognitionResultError(SpeechRecognitionResultError)

    /// Decoded when the @type is not one of the known cases (forward-compatible).
    case unsupported

    private enum Kind: String, Codable {
        case speechRecognitionResultPending
        case speechRecognitionResultText
        case speechRecognitionResultError
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: DtoCodingKeys.self)
        let typeString = try container.decode(String.self, forKey: .type)
        guard let type = Kind(rawValue: typeString) else {
            self = .unsupported
            return
        }
        switch type {
        case .speechRecognitionResultPending:
            let value = try SpeechRecognitionResultPending(from: decoder)
            self = .speechRecognitionResultPending(value)
        case .speechRecognitionResultText:
            let value = try SpeechRecognitionResultText(from: decoder)
            self = .speechRecognitionResultText(value)
        case .speechRecognitionResultError:
            let value = try SpeechRecognitionResultError(from: decoder)
            self = .speechRecognitionResultError(value)
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: DtoCodingKeys.self)
        switch self {
        case .speechRecognitionResultPending(let value):
            try container.encode(Kind.speechRecognitionResultPending, forKey: .type)
            try value.encode(to: encoder)
        case .speechRecognitionResultText(let value):
            try container.encode(Kind.speechRecognitionResultText, forKey: .type)
            try value.encode(to: encoder)
        case .speechRecognitionResultError(let value):
            try container.encode(Kind.speechRecognitionResultError, forKey: .type)
            try value.encode(to: encoder)
        case .unsupported:
            try container.encode("unsupported", forKey: .type)
        }
    }
}

/// The speech recognition is ongoing
public struct SpeechRecognitionResultPending: Codable, Equatable, Hashable {

    /// Partially recognized text
    public let partialText: String


    public init(partialText: String) {
        self.partialText = partialText
    }
}

/// The speech recognition successfully finished
public struct SpeechRecognitionResultText: Codable, Equatable, Hashable {

    /// Recognized text
    public let text: String


    public init(text: String) {
        self.text = text
    }
}

/// The speech recognition failed
public struct SpeechRecognitionResultError: Codable, Equatable, Hashable {

    /// Recognition error. An error with a message "MSG_VOICE_TOO_LONG" is returned when media duration is too big to be recognized
    public let error: TDError


    public init(error: TDError) {
        self.error = error
    }
}

