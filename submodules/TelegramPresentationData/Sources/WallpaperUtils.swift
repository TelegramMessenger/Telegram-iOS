import Foundation
import UIKit
import TelegramCore

public extension TelegramWallpaper {
    var isEmpty: Bool {
        switch self {
        case .image:
            return false
        case let .file(_, _, _, _, _, _, _, _, settings):
            if self.isPattern, settings.colors.count == 1 && (settings.colors[0] == 0xffffff || settings.colors[0] == 0xffffffff) {
                return true
            } else {
                return false
            }
        case let .color(color):
            return color == 0xffffff || color == 0xffffffff
        default:
            return false
        }
    }
    
    var isColorOrGradient: Bool {
        switch self {
        case .color, .gradient:
            return true
        default:
            return false
        }
    }
    
    var isPattern: Bool {
        switch self {
        case let .file(file):
            return file.isPattern || file.file.mimeType == "application/x-tgwallpattern"
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
    
    var dimensions: CGSize? {
        if case let .file(file) = self {
            return file.file.dimensions?.cgSize
        } else {
            return nil
        }
    }
}
