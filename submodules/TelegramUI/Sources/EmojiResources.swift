import Foundation
import UIKit
import Postbox
import TelegramCore
import Emoji

func messageIsElligibleForLargeEmoji(_ message: Message) -> Bool {
    if !message.text.isEmpty && message.text.containsOnlyEmoji {
        if !(message.textEntitiesAttribute?.entities.isEmpty ?? true) {
            return false
        }
        return true
    } else {
        return false
    }
}

func messageIsElligibleForLargeCustomEmoji(_ message: Message) -> Bool {
    let text = message.text.replacingOccurrences(of: "\n", with: "").replacingOccurrences(of: " ", with: "")
    guard !text.isEmpty && text.containsOnlyEmoji else {
        return false
    }
    let entities = message.textEntitiesAttribute?.entities ?? []
    guard entities.count > 0 else {
        return false
    }
    for entity in entities {
        if case let .CustomEmoji(_, fileId) = entity.type {
            if let _ = message.associatedMedia[MediaId(namespace: Namespaces.Media.CloudFile, id: fileId)] as? TelegramMediaFile {
                
            } else {
                return false
            }
        } else {
            return false
        }
    }
    return true
}
