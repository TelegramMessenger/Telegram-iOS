import Foundation
import Postbox
import TelegramCore

private let minimalStreamableSize: Int = 384 * 1024

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
    if size < minimalStreamableSize {
        return false
    }
    for attribute in media.attributes {
        if case let .Video(_, _, flags) = attribute {
            if flags.contains(.supportsStreaming) {
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
    if size < minimalStreamableSize {
        return false
    }
    for attribute in media.attributes {
        if case let .Video(_, _, flags) = attribute {
            if flags.contains(.supportsStreaming) {
                return true
            }
            break
        }
    }
    return false
}

public func isMediaStreamable(resource: MediaResource) -> Bool {
    if let size = resource.size, size >= minimalStreamableSize  {
        return true
    } else {
        return false
    }
}
