import Foundation
import UIKit
import Postbox
import TelegramCore

enum WallpaperPreviewMediaContent: Equatable {
    case file(file: TelegramMediaFile, colors: [UInt32], rotation: Int32?, intensity: Int32?, Bool, Bool)
    case image(representations: [TelegramMediaImageRepresentation])
    case color(UIColor)
    case gradient([UInt32], Int32?)
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

extension WallpaperPreviewMedia {
    convenience init?(wallpaper: TelegramWallpaper) {
        switch wallpaper {
        case let .color(color):
            self.init(content: .color(UIColor(rgb: color)))
        case let .gradient(gradient):
            self.init(content: .gradient(gradient.colors, gradient.settings.rotation))
        case let .file(file):
            self.init(content: .file(file: file.file, colors: file.settings.colors, rotation: file.settings.rotation, intensity: file.settings.intensity, false, false))
        case let .image(representations, _):
            self.init(content: .image(representations: representations))
        default:
            return nil
        }
    }
}
