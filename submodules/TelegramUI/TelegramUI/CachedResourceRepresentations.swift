import Foundation
import UIKit
import Postbox
import SwiftSignalKit

final class CachedStickerAJpegRepresentation: CachedMediaResourceRepresentation {
    let size: CGSize?
    let keepDuration: CachedMediaRepresentationKeepDuration = .general
    
    var uniqueId: String {
        if let size = self.size {
            return "sticker-ajpeg-\(Int(size.width))x\(Int(size.height))"
        } else {
            return "sticker-ajpeg"
        }
    }
    
    init(size: CGSize?) {
        self.size = size
    }
    
    func isEqual(to: CachedMediaResourceRepresentation) -> Bool {
        if let to = to as? CachedStickerAJpegRepresentation {
            return self.size == to.size
        } else {
            return false
        }
    }
}

enum CachedScaledImageRepresentationMode: Int32 {
    case fill = 0
    case aspectFit = 1
}

final class CachedScaledImageRepresentation: CachedMediaResourceRepresentation {
    let keepDuration: CachedMediaRepresentationKeepDuration = .general
    
    let size: CGSize
    let mode: CachedScaledImageRepresentationMode
    
    var uniqueId: String {
        return "scaled-image-\(Int(self.size.width))x\(Int(self.size.height))-\(self.mode.rawValue)"
    }
    
    init(size: CGSize, mode: CachedScaledImageRepresentationMode) {
        self.size = size
        self.mode = mode
    }
    
    func isEqual(to: CachedMediaResourceRepresentation) -> Bool {
        if let to = to as? CachedScaledImageRepresentation {
            return self.size == to.size && self.mode == to.mode
        } else {
            return false
        }
    }
}

final class CachedVideoFirstFrameRepresentation: CachedMediaResourceRepresentation {
    let keepDuration: CachedMediaRepresentationKeepDuration = .general
    
    var uniqueId: String {
        return "first-frame"
    }
    
    func isEqual(to: CachedMediaResourceRepresentation) -> Bool {
        if to is CachedVideoFirstFrameRepresentation {
            return true
        } else {
            return false
        }
    }
}

final class CachedScaledVideoFirstFrameRepresentation: CachedMediaResourceRepresentation {
    let keepDuration: CachedMediaRepresentationKeepDuration = .general
    
    let size: CGSize
    
    var uniqueId: String {
        return "scaled-frame-\(Int(self.size.width))x\(Int(self.size.height))"
    }
    
    init(size: CGSize) {
        self.size = size
    }
    
    func isEqual(to: CachedMediaResourceRepresentation) -> Bool {
        if let to = to as? CachedScaledVideoFirstFrameRepresentation {
            return self.size == to.size
        } else {
            return false
        }
    }
}

final class CachedBlurredWallpaperRepresentation: CachedMediaResourceRepresentation {
    let keepDuration: CachedMediaRepresentationKeepDuration = .general
    
    var uniqueId: String {
        return "blurred-wallpaper"
    }
    
    func isEqual(to: CachedMediaResourceRepresentation) -> Bool {
        if to is CachedBlurredWallpaperRepresentation {
            return true
        } else {
            return false
        }
    }
}

final class CachedPatternWallpaperMaskRepresentation: CachedMediaResourceRepresentation {
    let keepDuration: CachedMediaRepresentationKeepDuration = .general
    
    let size: CGSize?
    
    var uniqueId: String {
        if let size = self.size {
            return "pattern-wallpaper-mask-\(Int(size.width))x\(Int(size.height))"
        } else {
            return "pattern-wallpaper-mask"
        }
    }
    
    init(size: CGSize?) {
        self.size = size
    }
    
    func isEqual(to: CachedMediaResourceRepresentation) -> Bool {
        if let to = to as? CachedPatternWallpaperMaskRepresentation {
            return self.size == to.size
        } else {
            return false
        }
    }
}


final class CachedPatternWallpaperRepresentation: CachedMediaResourceRepresentation {
    let keepDuration: CachedMediaRepresentationKeepDuration = .general
    
    let color: Int32
    let intensity: Int32
    
    var uniqueId: String {
        return "pattern-wallpaper-\(self.color)-\(self.intensity)"
    }
    
    init(color: Int32, intensity: Int32) {
        self.color = color
        self.intensity = intensity
    }
    
    func isEqual(to: CachedMediaResourceRepresentation) -> Bool {
        if let to = to as? CachedPatternWallpaperRepresentation {
            return self.color == to.color && self.intensity == intensity
        } else {
            return false
        }
    }
}

final class CachedAlbumArtworkRepresentation: CachedMediaResourceRepresentation {
    let keepDuration: CachedMediaRepresentationKeepDuration = .general
    
    let size: CGSize?
    
    var uniqueId: String {
        if let size = self.size {
            return "album-artwork-\(Int(size.width))x\(Int(size.height))"
        } else {
            return "album-artwork"
        }
    }
    
    init(size: CGSize) {
        self.size = size
    }
    
    func isEqual(to: CachedMediaResourceRepresentation) -> Bool {
        if let to = to as? CachedAlbumArtworkRepresentation {
            return self.size == to.size
        } else {
            return false
        }
    }
}

final class CachedEmojiThumbnailRepresentation: CachedMediaResourceRepresentation {
    let keepDuration: CachedMediaRepresentationKeepDuration = .general
    
    let outline: Bool
    
    var uniqueId: String {
        return "emoji-thumb-\(self.outline ? 1 : 0)"
    }
    
    init(outline: Bool) {
        self.outline = outline
    }
    
    func isEqual(to: CachedMediaResourceRepresentation) -> Bool {
        if let to = to as? CachedEmojiThumbnailRepresentation {
            return self.outline == to.outline
        } else {
            return false
        }
    }
}

final class CachedEmojiRepresentation: CachedMediaResourceRepresentation {
    let keepDuration: CachedMediaRepresentationKeepDuration = .general
    
    let tile: UInt8
    let outline: Bool
    
    var uniqueId: String {
        return "emoji-\(Int(self.tile))-\(self.outline ? 1 : 0)"
    }
    
    init(tile: UInt8, outline: Bool) {
        self.tile = tile
        self.outline = outline
    }
    
    func isEqual(to: CachedMediaResourceRepresentation) -> Bool {
        if let to = to as? CachedEmojiRepresentation {
            return self.tile == to.tile && self.outline == to.outline
        } else {
            return false
        }
    }
}

public enum EmojiFitzModifier: Int32, Equatable {
    case type12
    case type3
    case type4
    case type5
    case type6
    
    public init?(emoji: String) {
        switch emoji.unicodeScalars.first?.value {
            case 0x1f3fb:
                self = .type12
            case 0x1f3fc:
                self = .type3
            case 0x1f3fd:
                self = .type4
            case 0x1f3fe:
                self = .type5
            case 0x1f3ff:
                self = .type6
            default:
                return nil
        }
    }
}

final class CachedAnimatedStickerFirstFrameRepresentation: CachedMediaResourceRepresentation {
    let keepDuration: CachedMediaRepresentationKeepDuration = .general
    
    let width: Int32
    let height: Int32
    let fitzModifier: EmojiFitzModifier?
    
    init(width: Int32, height: Int32, fitzModifier: EmojiFitzModifier? = nil) {
        self.width = width
        self.height = height
        self.fitzModifier = fitzModifier
    }
    
    var uniqueId: String {
        let version: Int = 1
        if let fitzModifier = self.fitzModifier {
            return "animated-sticker-first-frame-\(self.width)x\(self.height)-fitz\(fitzModifier.rawValue)-v\(version)"
        } else {
            return "animated-sticker-first-frame-\(self.width)x\(self.height)-v\(version)"
        }
    }
    
    func isEqual(to: CachedMediaResourceRepresentation) -> Bool {
        if let other = to as? CachedAnimatedStickerFirstFrameRepresentation {
            if other.width != self.width {
                return false
            }
            if other.height != self.height {
                return false
            }
            if other.fitzModifier != self.fitzModifier {
                return false
            }
            return true
        } else {
            return false
        }
    }
}

final class CachedAnimatedStickerRepresentation: CachedMediaResourceRepresentation {
    let keepDuration: CachedMediaRepresentationKeepDuration = .shortLived
    
    let width: Int32
    let height: Int32
    let fitzModifier: EmojiFitzModifier?
    
    var uniqueId: String {
        let version: Int = 8
        if let fitzModifier = self.fitzModifier {
            return "animated-sticker-\(self.width)x\(self.height)-fitz\(fitzModifier.rawValue)-v\(version)"
        } else {
            return "animated-sticker-\(self.width)x\(self.height)-v\(version)"
        }
    }
    
    init(width: Int32, height: Int32, fitzModifier: EmojiFitzModifier? = nil) {
        self.width = width
        self.height = height
        self.fitzModifier = fitzModifier
    }
    
    func isEqual(to: CachedMediaResourceRepresentation) -> Bool {
        if let other = to as? CachedAnimatedStickerRepresentation {
            if other.width != self.width {
                return false
            }
            if other.height != self.height {
                return false
            }
            if other.fitzModifier != self.fitzModifier {
                return false
            }
            return true
        } else {
            return false
        }
    }
}
