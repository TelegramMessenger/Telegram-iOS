import Foundation
import Postbox

public final class ChatUpdatingMessageMedia: Equatable {
    public let text: String
    public let entities: TextEntitiesMessageAttribute?
    public let disableUrlPreview: Bool
    public let media: RequestEditMessageMedia
    public let progress: Float
    
    init(text: String, entities: TextEntitiesMessageAttribute?, disableUrlPreview: Bool, media: RequestEditMessageMedia, progress: Float) {
        self.text = text
        self.entities = entities
        self.disableUrlPreview = disableUrlPreview
        self.media = media
        self.progress = progress
    }
    
    public static func ==(lhs: ChatUpdatingMessageMedia, rhs: ChatUpdatingMessageMedia) -> Bool {
        if lhs.text != rhs.text {
            return false
        }
        if lhs.entities != rhs.entities {
            return false
        }
        if lhs.disableUrlPreview != rhs.disableUrlPreview {
            return false
        }
        if lhs.media != rhs.media {
            return false
        }
        if lhs.progress != rhs.progress {
            return false
        }
        return true
    }
    
    func withProgress(_ progress: Float) -> ChatUpdatingMessageMedia {
        return ChatUpdatingMessageMedia(text: self.text, entities: self.entities, disableUrlPreview: self.disableUrlPreview, media: self.media, progress: progress)
    }
}
