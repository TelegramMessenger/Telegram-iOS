import Foundation
import TelegramCore
import Postbox
import SwiftSignalKit

enum FileMediaResourcePlaybackStatus {
    case playing
    case paused
}

struct FileMediaResourceStatus {
    let mediaStatus: FileMediaResourceMediaStatus
    let fetchStatus: MediaResourceStatus
}

enum FileMediaResourceMediaStatus {
    case fetchStatus(MediaResourceStatus)
    case playbackStatus(FileMediaResourcePlaybackStatus)
}

private func internalMessageFileMediaPlaybackStatus(account: Account, file: TelegramMediaFile, message: Message, isRecentActions: Bool) -> Signal<MediaPlayerStatus?, NoError> {
    guard let playerType = peerMessageMediaPlayerType(message) else {
        return .single(nil)
    }
    
    if let (playlistId, itemId) = peerMessagesMediaPlaylistAndItemId(message, isRecentActions: isRecentActions) {
        if let mediaManager = account.telegramApplicationContext.mediaManager {
            return mediaManager.filteredPlaylistState(playlistId: playlistId, itemId: itemId, type: playerType)
            |> mapToSignal { state -> Signal<MediaPlayerStatus?, NoError> in
                return .single(state?.status)
            }
        } else {
            return .single(nil)
        }
    } else {
        return .single(nil)
    }
}

func messageFileMediaPlaybackStatus(account: Account, file: TelegramMediaFile, message: Message, isRecentActions: Bool) -> Signal<MediaPlayerStatus, NoError> {
    var duration = 0.0
    if let value = file.duration {
        duration = Double(value)
    }
    let defaultStatus = MediaPlayerStatus(generationTimestamp: 0.0, duration: duration, dimensions: CGSize(), timestamp: 0.0, baseRate: 1.0, seekId: 0, status: .paused)
    return internalMessageFileMediaPlaybackStatus(account: account, file: file, message: message, isRecentActions: isRecentActions) |> map { status in
        return status ?? defaultStatus
    }
}

func messageFileMediaResourceStatus(account: Account, file: TelegramMediaFile, message: Message, isRecentActions: Bool) -> Signal<FileMediaResourceStatus, NoError> {
    let playbackStatus = internalMessageFileMediaPlaybackStatus(account: account, file: file, message: message, isRecentActions: isRecentActions) |> map { status -> MediaPlayerPlaybackStatus? in
        return status?.status
    }
    
    if message.flags.isSending  {
        return combineLatest(messageMediaFileStatus(account: account, messageId: message.id, file: file), account.pendingMessageManager.pendingMessageStatus(message.id), playbackStatus)
        |> map { resourceStatus, pendingStatus, playbackStatus -> FileMediaResourceStatus in
            let mediaStatus: FileMediaResourceMediaStatus
            if let playbackStatus = playbackStatus {
                switch playbackStatus {
                    case .playing:
                        mediaStatus = .playbackStatus(.playing)
                    case .paused:
                        mediaStatus = .playbackStatus(.paused)
                    case let .buffering(_, whilePlaying):
                        if whilePlaying {
                            mediaStatus = .playbackStatus(.playing)
                        } else {
                            mediaStatus = .playbackStatus(.paused)
                        }
                }
            } else if let pendingStatus = pendingStatus {
                mediaStatus = .fetchStatus(.Fetching(isActive: pendingStatus.isRunning, progress: pendingStatus.progress))
            } else {
                mediaStatus = .fetchStatus(resourceStatus)
            }
            return FileMediaResourceStatus(mediaStatus: mediaStatus, fetchStatus: resourceStatus)
        }
    } else {
        return combineLatest(messageMediaFileStatus(account: account, messageId: message.id, file: file), playbackStatus)
        |> map { resourceStatus, playbackStatus -> FileMediaResourceStatus in
            let mediaStatus: FileMediaResourceMediaStatus
            if let playbackStatus = playbackStatus {
                switch playbackStatus {
                    case .playing:
                        mediaStatus = .playbackStatus(.playing)
                    case .paused:
                        mediaStatus = .playbackStatus(.paused)
                    case let .buffering(_, whilePlaying):
                        if whilePlaying {
                            mediaStatus = .playbackStatus(.playing)
                        } else {
                            mediaStatus = .playbackStatus(.paused)
                        }
                }
            } else {
                mediaStatus = .fetchStatus(resourceStatus)
            }
            return FileMediaResourceStatus(mediaStatus: mediaStatus, fetchStatus: resourceStatus)
        }
    }
}
