import Foundation
import Postbox
import TelegramCore
import SyncCore
import SwiftSignalKit
import UIKit
import AsyncDisplayKit
import TelegramAudio
import UniversalMediaPlayer

public enum MediaManagerPlayerType {
    case voice
    case music
}

public protocol MediaManager: class {
    var audioSession: ManagedAudioSession { get }
    var galleryHiddenMediaManager: GalleryHiddenMediaManager { get }
    var universalVideoManager: UniversalVideoManager { get }
    var overlayMediaManager: OverlayMediaManager { get }
    
    var globalMediaPlayerState: Signal<(Account, SharedMediaPlayerItemPlaybackStateOrLoading, MediaManagerPlayerType)?, NoError> { get }
    var musicMediaPlayerState: Signal<(Account, SharedMediaPlayerItemPlaybackStateOrLoading)?, NoError> { get }
    var activeGlobalMediaPlayerAccountId: Signal<(AccountRecordId, Bool)?, NoError> { get }
    
    func setPlaylist(_ playlist: (Account, SharedMediaPlaylist)?, type: MediaManagerPlayerType, control: SharedMediaPlayerControlAction)
    func playlistControl(_ control: SharedMediaPlayerControlAction, type: MediaManagerPlayerType?)
    
    func filteredPlaylistState(accountId: AccountRecordId, playlistId: SharedMediaPlaylistId, itemId: SharedMediaPlaylistItemId, type: MediaManagerPlayerType) -> Signal<SharedMediaPlayerItemPlaybackState?, NoError>
    
    func setOverlayVideoNode(_ node: OverlayMediaItemNode?)
    
    func audioRecorder(beginWithTone: Bool, applicationBindings: TelegramApplicationBindings, beganWithTone: @escaping (Bool) -> Void) -> Signal<ManagedAudioRecorder?, NoError>
}

public enum GalleryHiddenMediaId: Hashable {
    case chat(AccountRecordId, MessageId, Media)
    
    public static func ==(lhs: GalleryHiddenMediaId, rhs: GalleryHiddenMediaId) -> Bool {
        switch lhs {
        case let .chat(lhsAccountId ,lhsMessageId, lhsMedia):
            if case let .chat(rhsAccountId, rhsMessageId, rhsMedia) = rhs, lhsAccountId == rhsAccountId, lhsMessageId == rhsMessageId, lhsMedia.isEqual(to: rhsMedia) {
                return true
            } else {
                return false
            }
        }
    }
    
    public func hash(into hasher: inout Hasher) {
        switch self {
        case let .chat(accountId, messageId, _):
            hasher.combine(accountId)
            hasher.combine(messageId)
        }
    }
}

public protocol GalleryHiddenMediaTarget: class {
    func getTransitionInfo(messageId: MessageId, media: Media) -> ((UIView) -> Void, ASDisplayNode, () -> (UIView?, UIView?))?
}

public protocol GalleryHiddenMediaManager: class {
    func hiddenIds() -> Signal<Set<GalleryHiddenMediaId>, NoError>
    func addSource(_ signal: Signal<GalleryHiddenMediaId?, NoError>) -> Int
    func removeSource(_ index: Int)
    func addTarget(_ target: GalleryHiddenMediaTarget)
    func removeTarget(_ target: GalleryHiddenMediaTarget)
    func findTarget(messageId: MessageId, media: Media) -> ((UIView) -> Void, ASDisplayNode, () -> (UIView?, UIView?))?
}

public protocol UniversalVideoManager: class {
    func attachUniversalVideoContent(content: UniversalVideoContent, priority: UniversalVideoPriority, create: () -> UniversalVideoContentNode & ASDisplayNode, update: @escaping (((UniversalVideoContentNode & ASDisplayNode), Bool)?) -> Void) -> (AnyHashable, Int32)
    func detachUniversalVideoContent(id: AnyHashable, index: Int32)
    func withUniversalVideoContent(id: AnyHashable, _ f: ((UniversalVideoContentNode & ASDisplayNode)?) -> Void)
    func addPlaybackCompleted(id: AnyHashable, _ f: @escaping () -> Void) -> Int
    func removePlaybackCompleted(id: AnyHashable, index: Int)
    func statusSignal(content: UniversalVideoContent) -> Signal<MediaPlayerStatus?, NoError>
    func bufferingStatusSignal(content: UniversalVideoContent) -> Signal<(IndexSet, Int)?, NoError>
}

public enum AudioRecordingState: Equatable {
    case paused(duration: Double)
    case recording(duration: Double, durationMediaTimestamp: Double)
    case stopped
}

public struct RecordedAudioData {
    public let compressedData: Data
    public let duration: Double
    public let waveform: Data?
    
    public init(compressedData: Data, duration: Double, waveform: Data?) {
        self.compressedData = compressedData
        self.duration = duration
        self.waveform = waveform
    }
}

public protocol ManagedAudioRecorder: class {
    var beginWithTone: Bool { get }
    var micLevel: Signal<Float, NoError> { get }
    var recordingState: Signal<AudioRecordingState, NoError> { get }
    
    func start()
    func stop()
    func takenRecordedData() -> Signal<RecordedAudioData?, NoError>
}
