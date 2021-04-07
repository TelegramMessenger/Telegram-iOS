import Foundation
import UIKit
import Postbox
import TelegramCore
import SyncCore

enum WallpaperPreviewMediaContent: Equatable {
    case file(TelegramMediaFile, UIColor?, UIColor?, Int32?, Bool, Bool)
    case color(UIColor)
    case gradient(UIColor, UIColor, Int32?)
    case themeSettings(TelegramThemeSettings)
}

final class WallpaperPreviewMedia: Media {
    var id: MediaId? {
        return nil
    }
    let peerIds: [PeerId] = []
    
    let content: WallpaperPreviewMediaContent
    
    init(content: WallpaperPreviewMediaContent) {
        self.content = content
    }
    
    init(decoder: PostboxDecoder) {
        self.content = .color(.clear)
    }
    
    func encode(_ encoder: PostboxEncoder) {
    }
    
    public func isEqual(to other: Media) -> Bool {
        guard let other = other as? WallpaperPreviewMedia else {
            return false
        }
        
        if self.content != other.content {
            return false
        }
        
        return true
    }
    
    public func isSemanticallyEqual(to other: Media) -> Bool {
        return self.isEqual(to: other)
    }
}
