import Foundation
import Postbox
import TelegramCore
import SyncCore

public func isMediaStreamable(message: Message, media: TelegramMediaFile) -> Bool {
    if message.containsSecretMedia {
        return false
    }
    if message.id.peerId.namespace == Namespaces.Peer.SecretChat {
        return false
    }
    guard let size = media.size else {
        return false
    }
    if size < 256 * 1024 {
        return false
    }
    for attribute in media.attributes {
        if case let .Video(video) = attribute {
            if video.flags.contains(.supportsStreaming) {
                return true
            }
            break
        }
    }
    #if DEBUG
    if let fileName = media.fileName, fileName.hasSuffix(".mkv") {
        return true
    }
    #endif
    return false
}

public func isMediaStreamable(media: TelegramMediaFile) -> Bool {
    guard let size = media.size else {
        return false
    }
    if size < 1 * 1024 * 1024 {
        return false
    }
    for attribute in media.attributes {
        if case let .Video(video) = attribute {
            if video.flags.contains(.supportsStreaming) {
                return true
            }
            break
        }
    }
    return false
}
