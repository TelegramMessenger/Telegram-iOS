import Foundation
import UIKit
import Postbox
import TelegramCore

public enum WallpaperPreviewMediaContent: Equatable {
    case file(file: TelegramMediaFile, colors: [UInt32], rotation: Int32?, intensity: Int32?, Bool, Bool)
    case image(representations: [TelegramMediaImageRepresentation])
    case color(UIColor)
    case gradient([UInt32], Int32?)
    case themeSettings(TelegramThemeSettings)
    case emoticon(String)
}

public final class WallpaperPreviewMedia: Media {
    public var id: MediaId? {
        return nil
    }
    public let peerIds: [PeerId] = []
    
    public let content: WallpaperPreviewMediaContent
    
    public init(content: WallpaperPreviewMediaContent) {
        self.content = content
    }
    
    public init(decoder: PostboxDecoder) {
        self.content = .color(.clear)
    }
    
    public func encode(_ encoder: PostboxEncoder) {
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

private extension UIColor {
    convenience init(rgb: UInt32) {
        self.init(red: CGFloat((rgb >> 16) & 0xff) / 255.0, green: CGFloat((rgb >> 8) & 0xff) / 255.0, blue: CGFloat(rgb & 0xff) / 255.0, alpha: 1.0)
    }
}

public extension WallpaperPreviewMedia {
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
        case let .emoticon(emoticon):
            self.init(content: .emoticon(emoticon))
        default:
            return nil
        }
    }
}

public final class UniqueGiftPreviewMedia: Media {
    public var id: MediaId? {
        return nil
    }
    public let peerIds: [PeerId] = []
    
    public let content: StarGift.UniqueGift?
    
    public init(content: StarGift.UniqueGift) {
        self.content = content
    }
    
    public init(decoder: PostboxDecoder) {
        self.content = nil
    }
    
    public func encode(_ encoder: PostboxEncoder) {
    }
    
    public func isEqual(to other: Media) -> Bool {
        guard let other = other as? UniqueGiftPreviewMedia else {
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
