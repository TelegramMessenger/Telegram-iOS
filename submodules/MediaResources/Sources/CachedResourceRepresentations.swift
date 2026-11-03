import Foundation
import UIKit
import SwiftSignalKit
import TelegramCore

public final class CachedStickerAJpegRepresentation: EngineMediaResourceRepresentation {
    public let size: CGSize?
    public let keepDuration: EngineCachedMediaRepresentationKeepDuration = .general
    
    public var uniqueId: String {
        if let size = self.size {
            return "sticker-ajpeg-\(Int(size.width))x\(Int(size.height))"
        } else {
            return "sticker-ajpeg"
        }
    }
    
    public init(size: CGSize?) {
        self.size = size
    }
    
    public func isEqual(to: EngineRawCachedMediaResourceRepresentation) -> Bool {
        if let to = to as? CachedStickerAJpegRepresentation {
            return self.size == to.size
        } else {
            return false
        }
    }
}

public enum CachedScaledImageRepresentationMode: Int32 {
    case fill = 0
    case aspectFit = 1
}

public final class CachedScaledImageRepresentation: EngineMediaResourceRepresentation {
    public let keepDuration: EngineCachedMediaRepresentationKeepDuration = .general
    
    public let size: CGSize
    public let mode: CachedScaledImageRepresentationMode
    
    public var uniqueId: String {
        return "scaled-image-\(Int(self.size.width))x\(Int(self.size.height))-\(self.mode.rawValue)"
    }
    
    public init(size: CGSize, mode: CachedScaledImageRepresentationMode) {
        self.size = size
        self.mode = mode
    }
    
    public func isEqual(to: EngineRawCachedMediaResourceRepresentation) -> Bool {
        if let to = to as? CachedScaledImageRepresentation {
            return self.size == to.size && self.mode == to.mode
        } else {
            return false
        }
    }
}

public final class CachedVideoFirstFrameRepresentation: EngineMediaResourceRepresentation {
    public let keepDuration: EngineCachedMediaRepresentationKeepDuration = .general
    
    public var uniqueId: String {
        return "first-frame"
    }
    
    public init() {
    }
    
    public func isEqual(to: EngineRawCachedMediaResourceRepresentation) -> Bool {
        if to is CachedVideoFirstFrameRepresentation {
            return true
        } else {
            return false
        }
    }
}

public final class CachedVideoPrefixFirstFrameRepresentation: EngineMediaResourceRepresentation {
    public let keepDuration: EngineCachedMediaRepresentationKeepDuration = .general
    
    public var uniqueId: String {
        return "prefix-first-frame"
    }
    
    public let prefixLength: Int32
    
    public init(prefixLength: Int32) {
        self.prefixLength = prefixLength
    }
    
    public func isEqual(to: EngineRawCachedMediaResourceRepresentation) -> Bool {
        if let to = to as? CachedVideoPrefixFirstFrameRepresentation {
            if self.prefixLength != to.prefixLength {
                return false
            }
            return true
        } else {
            return false
        }
    }
}

public final class CachedScaledVideoFirstFrameRepresentation: EngineMediaResourceRepresentation {
    public let keepDuration: EngineCachedMediaRepresentationKeepDuration = .general
    
    public let size: CGSize
    
    public var uniqueId: String {
        return "scaled-frame-\(Int(self.size.width))x\(Int(self.size.height))"
    }
    
    public init(size: CGSize) {
        self.size = size
    }
    
    public func isEqual(to: EngineRawCachedMediaResourceRepresentation) -> Bool {
        if let to = to as? CachedScaledVideoFirstFrameRepresentation {
            return self.size == to.size
        } else {
            return false
        }
    }
}

public final class CachedBlurredWallpaperRepresentation: EngineMediaResourceRepresentation {
    public let keepDuration: EngineCachedMediaRepresentationKeepDuration = .general
    
    public var uniqueId: String {
        return "blurred-wallpaper"
    }
    
    public init() {
    }
    
    public func isEqual(to: EngineRawCachedMediaResourceRepresentation) -> Bool {
        if to is CachedBlurredWallpaperRepresentation {
            return true
        } else {
            return false
        }
    }
}

public final class CachedAlbumArtworkRepresentation: EngineMediaResourceRepresentation {
    public let keepDuration: EngineCachedMediaRepresentationKeepDuration = .general
    
    public let size: CGSize?
    
    public var uniqueId: String {
        if let size = self.size {
            return "album-artwork-\(Int(size.width))x\(Int(size.height))"
        } else {
            return "album-artwork"
        }
    }
    
    public init(size: CGSize) {
        self.size = size
    }
    
    public func isEqual(to: EngineRawCachedMediaResourceRepresentation) -> Bool {
        if let to = to as? CachedAlbumArtworkRepresentation {
            return self.size == to.size
        } else {
            return false
        }
    }
}

public final class CachedEmojiThumbnailRepresentation: EngineMediaResourceRepresentation {
    public let keepDuration: EngineCachedMediaRepresentationKeepDuration = .general
    
    public let outline: Bool
    
    public var uniqueId: String {
        return "emoji-thumb-\(self.outline ? 1 : 0)"
    }
    
    public init(outline: Bool) {
        self.outline = outline
    }
    
    public func isEqual(to: EngineRawCachedMediaResourceRepresentation) -> Bool {
        if let to = to as? CachedEmojiThumbnailRepresentation {
            return self.outline == to.outline
        } else {
            return false
        }
    }
}

public final class CachedEmojiRepresentation: EngineMediaResourceRepresentation {
    public let keepDuration: EngineCachedMediaRepresentationKeepDuration = .general
    
    public let tile: UInt8
    public let outline: Bool
    
    public var uniqueId: String {
        return "emoji-\(Int(self.tile))-\(self.outline ? 1 : 0)"
    }
    
    public init(tile: UInt8, outline: Bool) {
        self.tile = tile
        self.outline = outline
    }
    
    public func isEqual(to: EngineRawCachedMediaResourceRepresentation) -> Bool {
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

public final class CachedAnimatedStickerFirstFrameRepresentation: EngineMediaResourceRepresentation {
    public let keepDuration: EngineCachedMediaRepresentationKeepDuration = .general
    
    public let width: Int32
    public let height: Int32
    public let fitzModifier: EmojiFitzModifier?
    
    public init(width: Int32, height: Int32, fitzModifier: EmojiFitzModifier? = nil) {
        self.width = width
        self.height = height
        self.fitzModifier = fitzModifier
    }
    
    public var uniqueId: String {
        let version: Int = 1
        if let fitzModifier = self.fitzModifier {
            return "animated-sticker-first-frame-\(self.width)x\(self.height)-fitz\(fitzModifier.rawValue)-v\(version)"
        } else {
            return "animated-sticker-first-frame-\(self.width)x\(self.height)-v\(version)"
        }
    }
    
    public func isEqual(to: EngineRawCachedMediaResourceRepresentation) -> Bool {
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

public final class CachedAnimatedStickerRepresentation: EngineMediaResourceRepresentation {
    public let keepDuration: EngineCachedMediaRepresentationKeepDuration = .shortLived
    
    public let width: Int32
    public let height: Int32
    public let fitzModifier: EmojiFitzModifier?
    
    public var uniqueId: String {
        let version: Int = 8
        if let fitzModifier = self.fitzModifier {
            return "animated-sticker-\(self.width)x\(self.height)-fitz\(fitzModifier.rawValue)-v\(version)"
        } else {
            return "animated-sticker-\(self.width)x\(self.height)-v\(version)"
        }
    }
    
    public init(width: Int32, height: Int32, fitzModifier: EmojiFitzModifier? = nil) {
        self.width = width
        self.height = height
        self.fitzModifier = fitzModifier
    }
    
    public func isEqual(to: EngineRawCachedMediaResourceRepresentation) -> Bool {
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

public final class CachedVideoStickerRepresentation: EngineMediaResourceRepresentation {
    public let keepDuration: EngineCachedMediaRepresentationKeepDuration = .shortLived
    
    public let width: Int32
    public let height: Int32
    
    public var uniqueId: String {
        let version: Int = 3
        return "video-sticker-\(self.width)x\(self.height)-v\(version)"
        
    }
    
    public init(width: Int32, height: Int32) {
        self.width = width
        self.height = height
    }
    
    public func isEqual(to: EngineRawCachedMediaResourceRepresentation) -> Bool {
        if let other = to as? CachedVideoStickerRepresentation {
            if other.width != self.width {
                return false
            }
            if other.height != self.height {
                return false
            }
            return true
        } else {
            return false
        }
    }
}

public final class CachedPreparedPatternWallpaperRepresentation: EngineMediaResourceRepresentation {
    public let keepDuration: EngineCachedMediaRepresentationKeepDuration = .general
    
    public var uniqueId: String {
        return "prepared-pattern-wallpaper"
    }
    
    public init() {
    }
    
    public func isEqual(to: EngineRawCachedMediaResourceRepresentation) -> Bool {
        if to is CachedPreparedPatternWallpaperRepresentation {
            return true
        } else {
            return false
        }
    }
}


public final class CachedPreparedSvgRepresentation: EngineMediaResourceRepresentation {
    public let keepDuration: EngineCachedMediaRepresentationKeepDuration = .general
    
    public var uniqueId: String {
        return "prepared-svg"
    }
    
    public init() {
    }
    
    public func isEqual(to: EngineRawCachedMediaResourceRepresentation) -> Bool {
        if to is CachedPreparedSvgRepresentation {
            return true
        } else {
            return false
        }
    }
}

public final class CachedPassImageRepresentation: EngineRawCachedMediaResourceRepresentation {
    public let keepDuration: EngineCachedMediaRepresentationKeepDuration = .general
    
    public let language: String
    public let scale: Int
    public let layoutVersion: Int
    
    public var uniqueId: String {
        return "pass-image-v\(self.layoutVersion)-\(self.scale)x-\(self.language)"
    }
    
    public init(language: String, scale: Int, layoutVersion: Int) {
        self.language = String(language.filter { ($0.isASCII && $0.isLetter) || $0 == "-" }.prefix(16))
        self.scale = scale
        self.layoutVersion = layoutVersion
    }
    
    public func isEqual(to: EngineRawCachedMediaResourceRepresentation) -> Bool {
        if let to = to as? CachedPassImageRepresentation {
            return self.language == to.language && self.scale == to.scale && self.layoutVersion == to.layoutVersion
        } else {
            return false
        }
    }
}
