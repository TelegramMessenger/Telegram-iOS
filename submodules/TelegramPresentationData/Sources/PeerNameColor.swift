import Foundation
import UIKit
import TelegramCore

public extension PeerNameColor {
    var color: UIColor {
        return self.dashColors.0
    }
    
    var dashColors: (UIColor, UIColor?) {
        switch self {
        case .red:
            return (UIColor(rgb: 0xCC5049), nil)
        case .orange:
            return (UIColor(rgb: 0xD67722), nil)
        case .violet:
            return (UIColor(rgb: 0x955CDB), nil)
        case .green:
            return (UIColor(rgb: 0x40A920), nil)
        case .cyan:
            return (UIColor(rgb: 0x309EBA), nil)
        case .blue:
            return (UIColor(rgb: 0x368AD1), nil)
        case .pink:
            return (UIColor(rgb: 0xC7508B), nil)
        case .redDash:
            return (UIColor(rgb: 0xE15052), UIColor(rgb: 0xF9AE63))
        case .orangeDash:
            return (UIColor(rgb: 0xE0802B), UIColor(rgb: 0xFAC534))
        case .violetDash:
            return (UIColor(rgb: 0xA05FF3), UIColor(rgb: 0xF48FFF))
        case .greenDash:
            return (UIColor(rgb: 0x27A910), UIColor(rgb: 0xA7DC57))
        case .cyanDash:
            return (UIColor(rgb: 0x27ACCE), UIColor(rgb: 0x82E8D6))
        case .blueDash:
            return (UIColor(rgb: 0x3391D4), UIColor(rgb: 0x7DD3F0))
        case .other13:
            return (.black, nil)
        case .other14:
            return (.black, nil)
        case .other15:
            return (.black, nil)
        }
    }
}
