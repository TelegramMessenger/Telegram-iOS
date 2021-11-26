import Foundation
import TelegramCore
import Postbox
import TelegramUIPreferences
import SwiftSignalKit
import UniversalMediaPlayer
import MusicAlbumArtResources

public enum SharedMediaPlaybackDataType {
    case music
    case voice
    case instantVideo
}

public enum SharedMediaPlaybackDataSource: Equatable {
    case telegramFile(reference: FileMediaReference, isCopyProtected: Bool)
    
    public static func ==(lhs: SharedMediaPlaybackDataSource, rhs: SharedMediaPlaybackDataSource) -> Bool {
        switch lhs {
        case let .telegramFile(lhsFileReference, lhsIsCopyProtected):
            if case let .telegramFile(rhsFileReference, rhsIsCopyProtected) = rhs {
                if !lhsFileReference.media.isEqual(to: rhsFileReference.media) {
                    return false
                }
                if lhsIsCopyProtected != rhsIsCopyProtected {
                    return false
                }
                return true
            } else {
                return false
            }
        }
    }
}

public struct SharedMediaPlaybackData: Equatable {
    public let type: SharedMediaPlaybackDataType
    public let source: SharedMediaPlaybackDataSource
    
    public init(type: SharedMediaPlaybackDataType, source: SharedMediaPlaybackDataSource) {
        self.type = type
        self.source = source
    }
    
    public static func ==(lhs: SharedMediaPlaybackData, rhs: SharedMediaPlaybackData) -> Bool {
        return lhs.type == rhs.type && lhs.source == rhs.source
    }
}

public struct SharedMediaPlaybackAlbumArt: Equatable {
    public let thumbnailResource: ExternalMusicAlbumArtResource
    public let fullSizeResource: ExternalMusicAlbumArtResource
    
    public init(thumbnailResource: ExternalMusicAlbumArtResource, fullSizeResource: ExternalMusicAlbumArtResource) {
        self.thumbnailResource = thumbnailResource
        self.fullSizeResource = fullSizeResource
    }
}

public enum SharedMediaPlaybackDisplayData: Equatable {
    case music(title: String?, performer: String?, albumArt: SharedMediaPlaybackAlbumArt?, long: Bool)
    case voice(author: Peer?, peer: Peer?)
    case instantVideo(author: Peer?, peer: Peer?, timestamp: Int32)
    
    public static func ==(lhs: SharedMediaPlaybackDisplayData, rhs: SharedMediaPlaybackDisplayData) -> Bool {
        switch lhs {
        case let .music(lhsTitle, lhsPerformer, lhsAlbumArt, lhsDuration):
            if case let .music(rhsTitle, rhsPerformer, rhsAlbumArt, rhsDuration) = rhs, lhsTitle == rhsTitle, lhsPerformer == rhsPerformer, lhsAlbumArt == rhsAlbumArt, lhsDuration == rhsDuration {
                return true
            } else {
                return false
            }
        case let .voice(lhsAuthor, lhsPeer):
            if case let .voice(rhsAuthor, rhsPeer) = rhs, arePeersEqual(lhsAuthor, rhsAuthor), arePeersEqual(lhsPeer, rhsPeer) {
                return true
            } else {
                return false
            }
        case let .instantVideo(lhsAuthor, lhsPeer, lhsTimestamp):
            if case let .instantVideo(rhsAuthor, rhsPeer, rhsTimestamp) = rhs, arePeersEqual(lhsAuthor, rhsAuthor), arePeersEqual(lhsPeer, rhsPeer), lhsTimestamp == rhsTimestamp {
                return true
            } else {
                return false
            }
        }
    }
}

public protocol SharedMediaPlaylistItem {
    var stableId: AnyHashable { get }
    var id: SharedMediaPlaylistItemId { get }
    var playbackData: SharedMediaPlaybackData? { get }
    var displayData: SharedMediaPlaybackDisplayData? { get }
}

public func arePlaylistItemsEqual(_ lhs: SharedMediaPlaylistItem?, _ rhs: SharedMediaPlaylistItem?) -> Bool {
    if lhs?.stableId != rhs?.stableId {
        return false
    }
    if lhs?.playbackData != rhs?.playbackData {
        return false
    }
    if lhs?.displayData != rhs?.displayData {
        return false
    }
    return true
}

public protocol SharedMediaPlaylistId {
    func isEqual(to: SharedMediaPlaylistId) -> Bool
}

public protocol SharedMediaPlaylistItemId {
    func isEqual(to: SharedMediaPlaylistItemId) -> Bool
}

public func areSharedMediaPlaylistItemIdsEqual(_ lhs: SharedMediaPlaylistItemId?, _ rhs: SharedMediaPlaylistItemId?) -> Bool {
    if let lhs = lhs, let rhs = rhs {
        return lhs.isEqual(to: rhs)
    } else if (lhs != nil) != (rhs != nil) {
        return false
    } else {
        return true
    }
}

public struct PeerMessagesMediaPlaylistItemId: SharedMediaPlaylistItemId {
    public let messageId: MessageId
    public let messageIndex: MessageIndex
    
    public init(messageId: MessageId, messageIndex: MessageIndex) {
        self.messageId = messageId
        self.messageIndex = messageIndex
    }
    
    public func isEqual(to: SharedMediaPlaylistItemId) -> Bool {
        if let to = to as? PeerMessagesMediaPlaylistItemId {
            if self.messageId != to.messageId || self.messageIndex != to.messageIndex {
                return false
            }
            return true
        }
        return false
    }
}

public protocol SharedMediaPlaylistLocation {
    func isEqual(to: SharedMediaPlaylistLocation) -> Bool
}

public protocol SharedMediaPlaylist: AnyObject {
    var id: SharedMediaPlaylistId { get }
    var location: SharedMediaPlaylistLocation { get }
    var state: Signal<SharedMediaPlaylistState, NoError> { get }
    var looping: MusicPlaybackSettingsLooping { get }
    var currentItemDisappeared: (() -> Void)? { get set }
    
    func control(_ action: SharedMediaPlaylistControlAction)
    func setOrder(_ order: MusicPlaybackSettingsOrder)
    func setLooping(_ looping: MusicPlaybackSettingsLooping)
    
    func onItemPlaybackStarted(_ item: SharedMediaPlaylistItem)
}

public enum SharedMediaPlayerPlaybackControlAction {
    case play
    case pause
    case togglePlayPause
}

public enum SharedMediaPlayerControlAction {
    case next
    case previous
    case playback(SharedMediaPlayerPlaybackControlAction)
    case seek(Double)
    case setOrder(MusicPlaybackSettingsOrder)
    case setLooping(MusicPlaybackSettingsLooping)
    case setBaseRate(AudioPlaybackRate)
}

public enum SharedMediaPlaylistControlAction {
    case next
    case previous
}

public final class SharedMediaPlaylistState: Equatable {
    public let loading: Bool
    public let playedToEnd: Bool
    public let item: SharedMediaPlaylistItem?
    public let nextItem: SharedMediaPlaylistItem?
    public let previousItem: SharedMediaPlaylistItem?
    public let order: MusicPlaybackSettingsOrder
    public let looping: MusicPlaybackSettingsLooping
    
    public init(loading: Bool, playedToEnd: Bool, item: SharedMediaPlaylistItem?, nextItem: SharedMediaPlaylistItem?, previousItem: SharedMediaPlaylistItem?, order: MusicPlaybackSettingsOrder, looping: MusicPlaybackSettingsLooping) {
        self.loading = loading
        self.playedToEnd = playedToEnd
        self.item = item
        self.nextItem = nextItem
        self.previousItem = previousItem
        self.order = order
        self.looping = looping
    }
    
    public static func ==(lhs: SharedMediaPlaylistState, rhs: SharedMediaPlaylistState) -> Bool {
        if lhs.loading != rhs.loading {
            return false
        }
        if !arePlaylistItemsEqual(lhs.item, rhs.item) {
            return false
        }
        if !arePlaylistItemsEqual(lhs.nextItem, rhs.nextItem) {
            return false
        }
        if !arePlaylistItemsEqual(lhs.previousItem, rhs.previousItem) {
            return false
        }
        if lhs.order != rhs.order {
            return false
        }
        if lhs.looping != rhs.looping {
            return false
        }
        return true
    }
}

public final class SharedMediaPlayerItemPlaybackState: Equatable {
    public let playlistId: SharedMediaPlaylistId
    public let playlistLocation: SharedMediaPlaylistLocation
    public let item: SharedMediaPlaylistItem
    public let previousItem: SharedMediaPlaylistItem?
    public let nextItem: SharedMediaPlaylistItem?
    public let status: MediaPlayerStatus
    public let order: MusicPlaybackSettingsOrder
    public let looping: MusicPlaybackSettingsLooping
    public let playerIndex: Int32
    
    public init(playlistId: SharedMediaPlaylistId, playlistLocation: SharedMediaPlaylistLocation, item: SharedMediaPlaylistItem, previousItem: SharedMediaPlaylistItem?, nextItem: SharedMediaPlaylistItem?, status: MediaPlayerStatus, order: MusicPlaybackSettingsOrder, looping: MusicPlaybackSettingsLooping, playerIndex: Int32) {
        self.playlistId = playlistId
        self.playlistLocation = playlistLocation
        self.item = item
        self.previousItem = previousItem
        self.nextItem = nextItem
        self.status = status
        self.order = order
        self.looping = looping
        self.playerIndex = playerIndex
    }
    
    public static func ==(lhs: SharedMediaPlayerItemPlaybackState, rhs: SharedMediaPlayerItemPlaybackState) -> Bool {
        if !lhs.playlistId.isEqual(to: rhs.playlistId) {
            return false
        }
        if !arePlaylistItemsEqual(lhs.item, rhs.item) {
            return false
        }
        if !arePlaylistItemsEqual(lhs.previousItem, rhs.previousItem) {
            return false
        }
        if !arePlaylistItemsEqual(lhs.nextItem, rhs.nextItem) {
            return false
        }
        if lhs.status != rhs.status {
            return false
        }
        if lhs.playerIndex != rhs.playerIndex {
            return false
        }
        if lhs.order != rhs.order {
            return false
        }
        if lhs.looping != rhs.looping {
            return false
        }
        return true
    }
}

public enum SharedMediaPlayerState: Equatable {
    case loading
    case item(SharedMediaPlayerItemPlaybackState)
    
    public static func ==(lhs: SharedMediaPlayerState, rhs: SharedMediaPlayerState) -> Bool {
        switch lhs {
        case .loading:
            if case .loading = rhs {
                return true
            } else {
                return false
            }
        case let .item(item):
            if case .item(item) = rhs {
                return true
            } else {
                return false
            }
        }
    }
}

public enum SharedMediaPlayerItemPlaybackStateOrLoading: Equatable {
    case state(SharedMediaPlayerItemPlaybackState)
    case loading
}
