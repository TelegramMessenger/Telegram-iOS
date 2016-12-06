import Foundation
import Postbox
import TelegramCore
import SwiftSignalKit

struct PeerMessageHistoryAudioPlaylistItemId: AudioPlaylistItemId {
    let id: MessageId
    
    var hashValue: Int {
        return self.id.hashValue
    }
    
    func isEqual(other: AudioPlaylistItemId) -> Bool {
        if let other = other as? PeerMessageHistoryAudioPlaylistItemId {
            return self.id == other.id
        } else {
            return false
        }
    }
}

private final class PeerMessageHistoryAudioPlaylistItem: AudioPlaylistItem {
    let entry: MessageHistoryEntry
    
    var id: AudioPlaylistItemId {
        return PeerMessageHistoryAudioPlaylistItemId(id: self.entry.index.id)
    }
    
    var resource: MediaResource? {
        switch self.entry {
            case let .MessageEntry(message, _, _):
                for media in message.media {
                    if let file = media as? TelegramMediaFile {
                        return file.resource
                    }
                }
                return nil
            case .HoleEntry:
                return nil
        }
    }
    
    var info: AudioPlaylistItemInfo? {
        switch self.entry {
            case let .MessageEntry(message, _, _):
                for media in message.media {
                    if let file = media as? TelegramMediaFile {
                        for attribute in file.attributes {
                            if case let .Audio(isVoice, duration, title, performer, waveform: nil) = attribute {
                                if isVoice {
                                    return AudioPlaylistItemInfo(duration: Double(duration), labelInfo: .voice)
                                } else {
                                    return AudioPlaylistItemInfo(duration: Double(duration), labelInfo: .music(title: title, performer: performer))
                                }
                            }
                        }
                        return nil
                    }
                }
            case .HoleEntry:
                break
        }
        
        return nil
    }
    
    init(entry: MessageHistoryEntry) {
        self.entry = entry
    }
    
    func isEqual(other: AudioPlaylistItem) -> Bool {
        if let other = other as? PeerMessageHistoryAudioPlaylistItem {
            return self.entry == other.entry
        } else {
            return false
        }
    }
}

struct PeerMessageHistoryAudioPlaylistId: AudioPlaylistId {
    let peerId: PeerId
    
    func isEqual(other: AudioPlaylistId) -> Bool {
        if let other = other as? PeerMessageHistoryAudioPlaylistId {
            if self.peerId != other.peerId {
                return false
            }
            return true
        } else {
            return false
        }
    }
}

func peerMessageHistoryAudioPlaylist(account: Account, messageId: MessageId) -> AudioPlaylist {
    return AudioPlaylist(id: PeerMessageHistoryAudioPlaylistId(peerId: messageId.peerId), navigate: { item, navigation in
        return account.postbox.messageAtId(messageId)
            |> map { message -> AudioPlaylistItem? in
                if let message = message {
                    return PeerMessageHistoryAudioPlaylistItem(entry: .MessageEntry(message, false, nil))
                } else {
                    return nil
                }
            }
        })
}
