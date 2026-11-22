//
//  VoiceNote.swift
//  tl2swift
//
//  Generated automatically. Any changes will be lost!
//  Based on TDLib 1.8.64-49b3bcbb-49b3bcbb
//  https://github.com/tdlib/td/tree/49b3bcbb
//

import Foundation


/// Describes a voice note
public struct VoiceNote: Codable, Equatable, Hashable {

    /// Duration of the voice note, in seconds; as defined by the sender
    public let duration: Int

    /// MIME type of the file; as defined by the sender. Usually, one of "audio/ogg" for Opus in an OGG container, "audio/mpeg" for an MP3 audio, or "audio/mp4" for an M4A audio
    public let mimeType: String

    /// Result of speech recognition in the voice note; may be null
    public let speechRecognitionResult: SpeechRecognitionResult?

    /// File containing the voice note
    public let voice: File

    /// A waveform representation of the voice note in 5-bit format
    public let waveform: Data


    public init(
        duration: Int,
        mimeType: String,
        speechRecognitionResult: SpeechRecognitionResult?,
        voice: File,
        waveform: Data
    ) {
        self.duration = duration
        self.mimeType = mimeType
        self.speechRecognitionResult = speechRecognitionResult
        self.voice = voice
        self.waveform = waveform
    }
}

