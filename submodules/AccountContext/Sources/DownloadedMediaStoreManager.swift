import Foundation
import TelegramCore
import TelegramUIPreferences
import SwiftSignalKit

public protocol DownloadedMediaStoreManager: AnyObject {
    func store(_ media: AnyMediaReference, timestamp: Int32, peerId: EnginePeer.Id)
}

public func storeDownloadedMedia(storeManager: DownloadedMediaStoreManager?, media: AnyMediaReference, peerId: EnginePeer.Id) -> Signal<Never, NoError> {
    guard case let .message(message, _) = media, let timestamp = message.timestamp, let incoming = message.isIncoming, incoming, let secret = message.isSecret, !secret else {
        return .complete()
    }
    
    return Signal { [weak storeManager] subscriber in
        storeManager?.store(media, timestamp: timestamp, peerId: peerId)
        subscriber.putCompletion()
        return EmptyDisposable
    }
}
