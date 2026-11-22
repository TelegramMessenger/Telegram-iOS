//
//  Audio.swift
//  tl2swift
//
//  Generated automatically. Any changes will be lost!
//  Based on TDLib 1.8.64-49b3bcbb-49b3bcbb
//  https://github.com/tdlib/td/tree/49b3bcbb
//

import Foundation


/// Describes an audio file. Audio is usually in MP3 or M4A format
public struct Audio: Codable, Equatable, Hashable {

    /// The minithumbnail of the album cover; may be null
    public let albumCoverMinithumbnail: Minithumbnail?

    /// The thumbnail of the album cover in JPEG format; as defined by the sender. The full size thumbnail is expected to be extracted from the downloaded audio file; may be null
    public let albumCoverThumbnail: Thumbnail?

    /// File containing the audio
    public let audio: File

    /// Duration of the audio, in seconds; as defined by the sender
    public let duration: Int

    /// Album cover variants to use if the downloaded audio file contains no album cover. Provided thumbnail dimensions are approximate
    public let externalAlbumCovers: [Thumbnail]

    /// Original name of the file; as defined by the sender
    public let fileName: String

    /// The MIME type of the file; as defined by the sender
    public let mimeType: String

    /// Performer of the audio; as defined by the sender
    public let performer: String

    /// Title of the audio; as defined by the sender
    public let title: String


    public init(
        albumCoverMinithumbnail: Minithumbnail?,
        albumCoverThumbnail: Thumbnail?,
        audio: File,
        duration: Int,
        externalAlbumCovers: [Thumbnail],
        fileName: String,
        mimeType: String,
        performer: String,
        title: String
    ) {
        self.albumCoverMinithumbnail = albumCoverMinithumbnail
        self.albumCoverThumbnail = albumCoverThumbnail
        self.audio = audio
        self.duration = duration
        self.externalAlbumCovers = externalAlbumCovers
        self.fileName = fileName
        self.mimeType = mimeType
        self.performer = performer
        self.title = title
    }
}

