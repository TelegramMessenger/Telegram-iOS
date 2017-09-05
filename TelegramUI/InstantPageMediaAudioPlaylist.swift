import Foundation
import Postbox
import TelegramCore
import SwiftSignalKit

struct InstantPageAudioPlaylistItemId: AudioPlaylistItemId {
    let index: Int
    let id: MediaId
    
    var hashValue: Int {
        return self.id.hashValue &+ self.index.hashValue
    }
    
    func isEqual(to: AudioPlaylistItemId) -> Bool {
        if let other = to as? InstantPageAudioPlaylistItemId {
            return self.index == other.index && self.id == other.id
        } else {
            return false
        }
    }
}

final class InstantPageAudioPlaylistItem: AudioPlaylistItem {
    let media: InstantPageMedia
    
    var id: AudioPlaylistItemId {
        return InstantPageAudioPlaylistItemId(index: self.media.index, id: self.media.media.id!)
    }
    
    var resource: MediaResource? {
        if let file = self.media.media as? TelegramMediaFile {
            return file.resource
        }
        return nil
    }
    
    var streamable: Bool {
        if let file = self.media.media as? TelegramMediaFile {
            if file.isMusic {
                return true
            }
        }
        return false
    }
    
    var info: AudioPlaylistItemInfo? {
        if let file = self.media.media as? TelegramMediaFile {
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
        return nil
    }
    
    init(media: InstantPageMedia) {
        self.media = media
    }
    
    func isEqual(to: AudioPlaylistItem) -> Bool {
        if let other = to as? InstantPageAudioPlaylistItem {
            return self.media == other.media
        } else {
            return false
        }
    }
}

struct InstantPageAudioPlaylistId: AudioPlaylistId {
    let webpageId: MediaId
    
    func isEqual(to: AudioPlaylistId) -> Bool {
        if let other = to as? InstantPageAudioPlaylistId {
            if self.webpageId != other.webpageId {
                return false
            }
            return true
        } else {
            return false
        }
    }
}

func instantPageAudioPlaylistAndItemIds(webpage: TelegramMediaWebpage, media: InstantPageMedia) -> (AudioPlaylistId, AudioPlaylistItemId)? {
    return (InstantPageAudioPlaylistId(webpageId: webpage.webpageId), InstantPageAudioPlaylistItemId(index: media.index, id: media.media.id!))
}

func instantPageAudioPlaylist(account: Account, webpage: TelegramMediaWebpage, medias: [InstantPageMedia], at centralMedia: InstantPageMedia) -> AudioPlaylist {
    return AudioPlaylist(id: InstantPageAudioPlaylistId(webpageId: webpage.webpageId), navigate: { item, navigation in
        if let item = item as? InstantPageAudioPlaylistItem {
            if let index = medias.index(of: item.media) {
                switch navigation {
                    case .previous:
                        if index == 0 {
                            return .single(item)
                        } else {
                            return .single(InstantPageAudioPlaylistItem(media: medias[index - 1]))
                        }
                    case .next:
                        if index == medias.count - 1 {
                            return .single(nil)
                        } else {
                            return .single(InstantPageAudioPlaylistItem(media: medias[index + 1]))
                        }
                    }
            } else {
                return .single(nil)
            }
        } else {
            if let index = medias.index(of: centralMedia) {
                return .single(InstantPageAudioPlaylistItem(media: medias[index]))
            } else if let media = medias.first {
                return .single(InstantPageAudioPlaylistItem(media: media))
            } else {
                return .single(nil)
            }
        }
    })
}

