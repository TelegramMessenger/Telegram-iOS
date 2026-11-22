//
//  Document.swift
//  tl2swift
//
//  Generated automatically. Any changes will be lost!
//  Based on TDLib 1.8.64-49b3bcbb-49b3bcbb
//  https://github.com/tdlib/td/tree/49b3bcbb
//

import Foundation


/// Describes a document of any type
public struct Document: Codable, Equatable, Hashable {

    /// File containing the document
    public let document: File

    /// Original name of the file; as defined by the sender
    public let fileName: String

    /// MIME type of the file; as defined by the sender
    public let mimeType: String

    /// Document minithumbnail; may be null
    public let minithumbnail: Minithumbnail?

    /// Document thumbnail in JPEG or PNG format (PNG will be used only for background patterns); as defined by the sender; may be null
    public let thumbnail: Thumbnail?


    public init(
        document: File,
        fileName: String,
        mimeType: String,
        minithumbnail: Minithumbnail?,
        thumbnail: Thumbnail?
    ) {
        self.document = document
        self.fileName = fileName
        self.mimeType = mimeType
        self.minithumbnail = minithumbnail
        self.thumbnail = thumbnail
    }
}

