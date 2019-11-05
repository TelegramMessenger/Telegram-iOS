import Foundation
import TelegramCore

public extension TelegramWallpaper {
    var isEmpty: Bool {
        switch self {
        case .image:
            return false
        case let .file(file):
            if file.isPattern, file.settings.color == 0xffffff {
                return true
            } else {
                return false
            }
        case let .color(color):
            return color == 0xffffff
        default:
            return false
        }
    }
    
    var isBuiltin: Bool {
        switch self {
        case .builtin:
            return true
        default:
            return false
        }
    }
}
