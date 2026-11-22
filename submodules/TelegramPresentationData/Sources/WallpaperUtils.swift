import Foundation
import UIKit
import TelegramCore

public extension TelegramWallpaper {
    var isEmpty: Bool {
        switch self {
        case .image:
            return false
        case .emoticon:
            return false
        case let .file(file):
            if self.isPattern, file.settings.colors.count == 1 && (file.settings.colors[0] == 0xffffff || file.settings.colors[0] == 0xffffffff) {
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
    
    var singleColor: UIColor? {
        switch self {
        case .image:
            return nil
        case .emoticon:
            return nil
        case let .file(file):
            if self.isPattern, file.settings.colors.count == 1 {
                return UIColor(rgb: file.settings.colors[0])
            } else {
                return nil
            }
        case let .color(color):
            return UIColor(rgb: color)
        default:
            return nil
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
    
    var isEmoticon: Bool {
        switch self {
        case .emoticon:
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
