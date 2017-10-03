import Foundation
import TelegramCore
import Postbox
import SwiftSignalKit

enum FileMediaResourcePlaybackStatus {
    case playing
    case paused
}

enum FileMediaResourceStatus {
    case fetchStatus(MediaResourceStatus)
    case playbackStatus(FileMediaResourcePlaybackStatus)
}

func messageFileMediaResourceStatus(account: Account, file: TelegramMediaFile, message: Message) -> Signal<FileMediaResourceStatus, NoError> {
    let playbackStatus: Signal<MediaPlayerPlaybackStatus?, NoError>
    if let applicationContext = account.applicationContext as? TelegramApplicationContext, let (playlistId, itemId) = peerMessageAudioPlaylistAndItemIds(message) {
        playbackStatus = applicationContext.mediaManager.filteredPlaylistPlayerStateAndStatus(playlistId: playlistId, itemId: itemId)
            |> mapToSignal { status -> Signal<MediaPlayerPlaybackStatus?, NoError> in
                if let status = status, let playbackStatus = status.status {
                    return playbackStatus
                        |> map { playbackStatus -> MediaPlayerPlaybackStatus? in
                            return playbackStatus.status
                        }
                        |> distinctUntilChanged(isEqual: { lhs, rhs in
                            return lhs == rhs
                        })
                } else {
                    return .single(nil)
                }
        }
    } else {
        playbackStatus = .single(nil)
    }
    
    if message.flags.isSending {
        return combineLatest(messageMediaFileStatus(account: account, messageId: message.id, file: file), account.pendingMessageManager.pendingMessageStatus(message.id), playbackStatus)
            |> map { resourceStatus, pendingStatus, playbackStatus -> FileMediaResourceStatus in
                if let playbackStatus = playbackStatus {
                    switch playbackStatus {
                    case .playing:
                        return .playbackStatus(.playing)
                    case .paused:
                        return .playbackStatus(.paused)
                    case let .buffering(whilePlaying):
                        if whilePlaying {
                            return .playbackStatus(.playing)
                        } else {
                            return .playbackStatus(.paused)
                        }
                    }
                } else if let pendingStatus = pendingStatus {
                    return .fetchStatus(.Fetching(isActive: pendingStatus.isRunning, progress: pendingStatus.progress))
                } else {
                    return .fetchStatus(resourceStatus)
                }
        }
    } else {
        return combineLatest(messageMediaFileStatus(account: account, messageId: message.id, file: file), playbackStatus)
            |> map { resourceStatus, playbackStatus -> FileMediaResourceStatus in
                if let playbackStatus = playbackStatus {
                    switch playbackStatus {
                    case .playing:
                        return .playbackStatus(.playing)
                    case .paused, .buffering:
                        return .playbackStatus(.paused)
                    }
                } else {
                    return .fetchStatus(resourceStatus)
                }
        }
    }
}
