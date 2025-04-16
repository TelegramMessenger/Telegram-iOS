//
//  SyncCore_TextTranscriptionMessageAttribute.swift
//  Telegram
//
//  Created by Dmitry Bolonikov on 7.04.25.
//

import Postbox

public class TextTranscriptionMessageAttribute: MessageAttribute, Equatable {
    public let id: Int64
    public let visible: Bool
    public let downloading: Bool
    public let file: TelegramMediaFile

    public var associatedPeerIds: [PeerId] {
        return []
    }
    
    public init(
        id: Int64,
        visible: Bool,
        downloading: Bool,
        file: TelegramMediaFile
    ) {
        self.id = id
        self.visible = visible
        self.downloading = downloading
        self.file = file
    }
    
    required public init(decoder: PostboxDecoder) {
        self.id = decoder.decodeInt64ForKey("id", orElse: 0)
        self.visible = decoder.decodeBoolForKey("visible", orElse: false)
        self.downloading = decoder.decodeBoolForKey("downloading", orElse: false)
        self.file = decoder.decodeObjectForKey("file") as! TelegramMediaFile
    }
    
    public func encode(_ encoder: PostboxEncoder) {
        encoder.encodeInt64(self.id, forKey: "id")
        encoder.encodeBool(self.visible, forKey: "visible")
        encoder.encodeBool(self.downloading, forKey: "downloading")
        encoder.encodeObject(file, forKey: "file")
    }
    
    public static func ==(lhs: TextTranscriptionMessageAttribute, rhs: TextTranscriptionMessageAttribute) -> Bool {
        if lhs.id != rhs.id {
            return false
        }
        if lhs.visible != rhs.visible {
            return false
        }
        if lhs.file != rhs.file {
            return false
        }
        if lhs.downloading != rhs.downloading {
            return false
        }
        return true
    }
}
