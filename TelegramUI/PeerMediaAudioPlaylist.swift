import Foundation
import Postbox
import TelegramCore
import SwiftSignalKit

struct PeerMessageHistoryAudioPlaylistItemId: AudioPlaylistItemId {
    let id: MessageId
    
    var hashValue: Int {
        return self.id.hashValue
    }
    
    func isEqual(to: AudioPlaylistItemId) -> Bool {
        if let other = to as? PeerMessageHistoryAudioPlaylistItemId {
            return self.id == other.id
        } else {
            return false
        }
    }
}

final class PeerMessageHistoryAudioPlaylistItem: AudioPlaylistItem {
    let entry: MessageHistoryEntry
    
    var id: AudioPlaylistItemId {
        return PeerMessageHistoryAudioPlaylistItemId(id: self.entry.index.id)
    }
    
    var resource: MediaResource? {
        switch self.entry {
            case let .MessageEntry(message, _, _, _):
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
    
    var streamable: Bool {
        switch self.entry {
            case let .MessageEntry(message, _, _, _):
                for media in message.media {
                    if let file = media as? TelegramMediaFile {
                        if file.isMusic {
                            return true
                        }
                    }
                }
                return false
            case .HoleEntry:
                return false
        }
    }
    
    var info: AudioPlaylistItemInfo? {
        switch self.entry {
            case let .MessageEntry(message, _, _, _):
                for media in message.media {
                    if let file = media as? TelegramMediaFile {
                        for attribute in file.attributes {
                            switch attribute {
                                case let .Audio(isVoice, duration, title, performer, _):
                                    if isVoice {
                                        return AudioPlaylistItemInfo(duration: Double(duration), labelInfo: .voice)
                                    } else {
                                        return AudioPlaylistItemInfo(duration: Double(duration), labelInfo: .music(title: title, performer: performer))
                                    }
                                case let .Video(duration, _, flags):
                                    if flags.contains(.instantRoundVideo) {
                                        return AudioPlaylistItemInfo(duration: Double(duration), labelInfo: .video)
                                    }
                                default:
                                    break
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
    
    func isEqual(to: AudioPlaylistItem) -> Bool {
        if let other = to as? PeerMessageHistoryAudioPlaylistItem {
            return self.entry == other.entry
        } else {
            return false
        }
    }
}

struct PeerMessageHistoryAudioPlaylistId: AudioPlaylistId {
    let peerId: PeerId
    
    func isEqual(to: AudioPlaylistId) -> Bool {
        if let other = to as? PeerMessageHistoryAudioPlaylistId {
            if self.peerId != other.peerId {
                return false
            }
            return true
        } else {
            return false
        }
    }
}

func peerMessageAudioPlaylistAndItemIds(_ message: Message) -> (AudioPlaylistId, AudioPlaylistItemId)? {
    return (PeerMessageHistoryAudioPlaylistId(peerId: message.id.peerId), PeerMessageHistoryAudioPlaylistItemId(id: message.id))
}

func peerMessageHistoryAudioPlaylist(account: Account, messageId: MessageId) -> AudioPlaylist {
    return AudioPlaylist(id: PeerMessageHistoryAudioPlaylistId(peerId: messageId.peerId), navigate: { item, navigation in
        if let item = item as? PeerMessageHistoryAudioPlaylistItem {
            var tagMask: MessageTags?
            switch item.entry {
                case let .MessageEntry(message, _, _, _):
                    for media in message.media {
                        if let file = media as? TelegramMediaFile {
                            inner: for attribute in file.attributes {
                                switch attribute {
                                    case let .Video(_, _, flags):
                                        if flags.contains(.instantRoundVideo) {
                                            tagMask = .VoiceOrInstantVideo
                                            break inner
                                        }
                                    case let .Audio(isVoice, _, _, _, _):
                                        if isVoice {
                                            tagMask = .VoiceOrInstantVideo
                                        } else {
                                            tagMask = .Music
                                        }
                                        break inner
                                    default:
                                        break
                                }
                            }
                            break
                        }
                    }
                case .HoleEntry:
                    break
            }
            if let tagMask = tagMask {
                return account.postbox.aroundMessageHistoryViewForPeerId(item.entry.index.id.peerId, index: item.entry.index, count: 10, anchorIndex: item.entry.index, fixedCombinedReadState: nil, topTaggedMessageIdNamespaces: [], tagMask: tagMask, orderStatistics: [])
                    |> take(1)
                    |> map { (view, _, _) -> AudioPlaylistItem? in
                        var index = 0
                        for entry in view.entries {
                            if entry.index.id == item.entry.index.id {
                                switch navigation {
                                    case .previous:
                                        if index != 0 {
                                            return PeerMessageHistoryAudioPlaylistItem(entry: view.entries[index - 1])
                                        } else {
                                            return PeerMessageHistoryAudioPlaylistItem(entry: view.entries.first!)
                                        }
                                    case .next:
                                        if index + 1 < view.entries.count {
                                            return PeerMessageHistoryAudioPlaylistItem(entry: view.entries[index + 1])
                                        } else {
                                            return nil//PeerMessageHistoryAudioPlaylistItem(entry: view.entries.last!)
                                        }
                                }
                            }
                            index += 1
                        }
                        if !view.entries.isEmpty {
                            return PeerMessageHistoryAudioPlaylistItem(entry: view.entries.first!)
                        } else {
                            return nil
                        }
                    }
            } else {
                return .single(nil)
            }
        } else {
            return account.postbox.messageAtId(messageId)
                |> map { message -> AudioPlaylistItem? in
                    if let message = message {
                        return PeerMessageHistoryAudioPlaylistItem(entry: .MessageEntry(message, false, nil, nil))
                    } else {
                        return nil
                    }
                }
        }
    })
}
