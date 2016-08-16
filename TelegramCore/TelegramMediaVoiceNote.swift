import Foundation
import Postbox

public final class TelegramMediaVoiceNote: Media {
    public let id: MediaId?
    public let voiceNoteId: MediaId
    public let duration: Int
    public let mimeType: String
    public let size: Int
    public let peerIds: [PeerId] = []
    
    public init(voiceNoteId: MediaId, duration: Int, mimeType: String, size: Int) {
        self.id = voiceNoteId
        self.voiceNoteId = voiceNoteId
        self.duration = duration
        self.mimeType = mimeType
        self.size = size
    }
    
    public init(decoder: Decoder) {
        self.voiceNoteId = MediaId(decoder.decodeBytesForKeyNoCopy("i"))
        self.id = self.voiceNoteId
        self.duration = Int(decoder.decodeInt32ForKey("d"))
        self.mimeType = decoder.decodeStringForKey("m")
        self.size = Int(decoder.decodeInt32ForKey("s"))
    }
    
    public func encode(_ encoder: Encoder) {
        let buffer = WriteBuffer()
        self.voiceNoteId.encodeToBuffer(buffer)
        encoder.encodeBytes(buffer, forKey: "i")
        encoder.encodeInt32(Int32(self.duration), forKey: "d")
        encoder.encodeString(self.mimeType, forKey: "m")
        encoder.encodeInt32(Int32(self.size), forKey: "s")
    }
    
    public func isEqual(_ other: Media) -> Bool {
        if let other = other as? TelegramMediaVoiceNote {
            if other.voiceNoteId == self.voiceNoteId && other.duration == self.duration && other.mimeType == self.mimeType && other.size == self.size {
                return true
            }
        }
        return false
    }
}
