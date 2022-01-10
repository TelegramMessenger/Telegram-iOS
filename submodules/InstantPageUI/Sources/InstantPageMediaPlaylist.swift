import Foundation
import UIKit
import SwiftSignalKit
import Postbox
import TelegramCore
import TelegramUIPreferences
import AccountContext
import MusicAlbumArtResources

struct InstantPageMediaPlaylistItemId: SharedMediaPlaylistItemId {
    let index: Int
    
    func isEqual(to: SharedMediaPlaylistItemId) -> Bool {
        if let to = to as? InstantPageMediaPlaylistItemId {
            if self.index != to.index {
                return false
            }
            return true
        }
        return false
    }
}

private func extractFileMedia(_ item: InstantPageMedia) -> TelegramMediaFile? {
    return item.media as? TelegramMediaFile
}

final class InstantPageMediaPlaylistItem: SharedMediaPlaylistItem {
    let webPage: TelegramMediaWebpage
    let id: SharedMediaPlaylistItemId
    let item: InstantPageMedia
    
    init(webPage: TelegramMediaWebpage, item: InstantPageMedia) {
        self.webPage = webPage
        self.id = InstantPageMediaPlaylistItemId(index: item.index)
        self.item = item
    }
    
    var stableId: AnyHashable {
        return self.item.index
    }
    
    var playbackData: SharedMediaPlaybackData? {
        if let file = extractFileMedia(self.item) {
            for attribute in file.attributes {
                switch attribute {
                    case let .Audio(isVoice, _, _, _, _):
                        if isVoice {
                            return SharedMediaPlaybackData(type: .voice, source: .telegramFile(reference: .webPage(webPage: WebpageReference(self.webPage), media: file), isCopyProtected: false))
                        } else {
                            return SharedMediaPlaybackData(type: .music, source: .telegramFile(reference: .webPage(webPage: WebpageReference(self.webPage), media: file), isCopyProtected: false))
                        }
                    case let .Video(_, _, flags):
                        if flags.contains(.instantRoundVideo) {
                            return SharedMediaPlaybackData(type: .instantVideo, source: .telegramFile(reference: .webPage(webPage: WebpageReference(self.webPage), media: file), isCopyProtected: false))
                        } else {
                            return nil
                        }
                    default:
                        break
                }
            }
            if file.mimeType.hasPrefix("audio/") {
                return SharedMediaPlaybackData(type: .music, source: .telegramFile(reference: .webPage(webPage: WebpageReference(self.webPage), media: file), isCopyProtected: false))
            }
            if let fileName = file.fileName {
                let ext = (fileName as NSString).pathExtension.lowercased()
                if ext == "wav" || ext == "opus" {
                    return SharedMediaPlaybackData(type: .music, source: .telegramFile(reference: .webPage(webPage: WebpageReference(self.webPage), media: file), isCopyProtected: false))
                }
            }
        }
        return nil
    }
    
    var displayData: SharedMediaPlaybackDisplayData? {
        if let file = extractFileMedia(self.item) {
            for attribute in file.attributes {
                switch attribute {
                    case let .Audio(isVoice, _, title, performer, _):
                        if isVoice {
                            return SharedMediaPlaybackDisplayData.voice(author: nil, peer: nil)
                        } else {
                            var updatedTitle = title
                            let updatedPerformer = performer
                            if (title ?? "").isEmpty && (performer ?? "").isEmpty {
                                updatedTitle = file.fileName ?? ""
                            }
                            
                            let albumArt: SharedMediaPlaybackAlbumArt?
                            if file.fileName?.lowercased().hasSuffix(".ogg") == true {
                                albumArt = nil
                            } else {
                                albumArt = SharedMediaPlaybackAlbumArt(thumbnailResource: ExternalMusicAlbumArtResource(title: updatedTitle ?? "", performer: updatedPerformer ?? "", isThumbnail: true), fullSizeResource: ExternalMusicAlbumArtResource(title: updatedTitle ?? "", performer: updatedPerformer ?? "", isThumbnail: false))
                            }
                            
                            return SharedMediaPlaybackDisplayData.music(title: updatedTitle, performer: updatedPerformer, albumArt: albumArt, long: false)
                        }
                    case let .Video(_, _, flags):
                        if flags.contains(.instantRoundVideo) {
                            return SharedMediaPlaybackDisplayData.instantVideo(author: nil, peer: nil, timestamp: 0)
                        } else {
                            return nil
                        }
                    default:
                        break
                }
            }
            
            return SharedMediaPlaybackDisplayData.music(title: file.fileName ?? "", performer: "", albumArt: nil, long: false)
        }
        return nil
    }
}

struct InstantPageMediaPlaylistId: SharedMediaPlaylistId {
    let webpageId: MediaId
    
    func isEqual(to: SharedMediaPlaylistId) -> Bool {
        if let to = to as? InstantPageMediaPlaylistId {
            return self.webpageId == to.webpageId
        }
        return false
    }
}

struct InstantPagePlaylistLocation: Equatable, SharedMediaPlaylistLocation {
    let webpageId: MediaId
    
    func isEqual(to: SharedMediaPlaylistLocation) -> Bool {
        guard let to = to as? InstantPagePlaylistLocation else {
            return false
        }
        if self.webpageId == to.webpageId {
            return false
        }
        return true
    }
}

final class InstantPageMediaPlaylist: SharedMediaPlaylist {
    private let webPage: TelegramMediaWebpage
    private let items: [InstantPageMedia]
    private let initialItemIndex: Int
    
    var location: SharedMediaPlaylistLocation {
        return InstantPagePlaylistLocation(webpageId: self.webPage.webpageId)
    }
    
    var currentItemDisappeared: (() -> Void)?
    
    private var currentItem: InstantPageMedia?
    private var playedToEnd: Bool = false
    private var order: MusicPlaybackSettingsOrder = .regular
    private(set) var looping: MusicPlaybackSettingsLooping = .none
    
    let id: SharedMediaPlaylistId
    
    private let stateValue = Promise<SharedMediaPlaylistState>()
    var state: Signal<SharedMediaPlaylistState, NoError> {
        return self.stateValue.get()
    }
    
    init(webPage: TelegramMediaWebpage, items: [InstantPageMedia], initialItemIndex: Int) {
        assert(Queue.mainQueue().isCurrent())
        
        self.id = InstantPageMediaPlaylistId(webpageId: webPage.webpageId)
        
        self.webPage = webPage
        self.items = items
        self.initialItemIndex = initialItemIndex
        
        self.control(.next)
    }
    
    func control(_ action: SharedMediaPlaylistControlAction) {
        assert(Queue.mainQueue().isCurrent())
        
        switch action {
            case .next, .previous:
                if let currentItem = self.currentItem, let currentIndex = self.items.firstIndex(where: { $0.index == currentItem.index }) {
                    let selectedIndex: Int?
                    switch self.order {
                        case .regular:
                            if case .next = action {
                                selectedIndex = max(0, currentIndex - 1)
                            } else {
                                if currentIndex == self.items.count - 1 {
                                    selectedIndex = nil
                                } else {
                                    selectedIndex = currentIndex + 1
                                }
                            }
                        case .reversed:
                            if case .next = action {
                                if currentIndex == self.items.count - 1 {
                                    selectedIndex = nil
                                } else {
                                    selectedIndex = currentIndex + 1
                                }
                            } else {
                                selectedIndex = max(0, currentIndex - 1)
                            }
                        case .random:
                            selectedIndex = Int(arc4random_uniform(UInt32(self.items.count)))
                    }
                    
                    if let selectedIndex = selectedIndex {
                        self.currentItem = self.items[selectedIndex]
                        self.playedToEnd = false
                    } else {
                        self.currentItem = nil
                        self.playedToEnd = true
                    }
                    self.updateState()
                } else {
                    if self.initialItemIndex < self.items.count {
                        self.currentItem = self.items[self.initialItemIndex]
                    } else {
                        self.currentItem = nil
                    }
                    self.playedToEnd = false
                    self.updateState()
                }
        }
    }
    
    func setOrder(_ order: MusicPlaybackSettingsOrder) {
        if self.order != order {
            self.order = order
            self.updateState()
        }
    }
    
    func setLooping(_ looping: MusicPlaybackSettingsLooping) {
        if self.looping != looping {
            self.looping = looping
            self.updateState()
        }
    }
    
    private func updateState() {
        self.stateValue.set(.single(SharedMediaPlaylistState(loading: false, playedToEnd: self.playedToEnd, item: self.currentItem.flatMap({ InstantPageMediaPlaylistItem(webPage: self.webPage, item: $0) }), nextItem: nil, previousItem: nil, order: self.order, looping: self.looping)))
    }
    
    func onItemPlaybackStarted(_ item: SharedMediaPlaylistItem) {
    }
}
