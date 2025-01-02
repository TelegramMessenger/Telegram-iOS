import Foundation
import UIKit
import Display
import GradientBackground

public enum AvatarBackground: Equatable {
    public static let defaultBackgrounds: [AvatarBackground] = [
        .gradient([0xFF5A7FFF, 0xFF2CA0F2, 0xFF4DFF89, 0xFF6BFCEB]),
        .gradient([0xFFFF011D, 0xFFFF530D, 0xFFFE64DC, 0xFFFFDC61]),
        .gradient([0xFFFE64DC, 0xFFFF6847, 0xFFFFDD02, 0xFFFFAE10]),
        .gradient([0xFF84EC00, 0xFF00B7C2, 0xFF00C217, 0xFFFFE600]),
        .gradient([0xFF86B0FF, 0xFF35FFCF, 0xFF69FFFF, 0xFF76DEFF]),
        .gradient([0xFFFAE100, 0xFFFF54EE, 0xFFFC2B78, 0xFFFF52D9]),
        .gradient([0xFF73A4FF, 0xFF5F55FF, 0xFFFF49F8, 0xFFEC76FF]),
    ]
    
    case gradient([UInt32])
    
    public var colors: [UInt32] {
        switch self {
        case let .gradient(colors):
            return colors
        }
    }
    
    public var isLight: Bool {
        switch self {
            case let .gradient(colors):
                if colors.count == 1 {
                    return UIColor(rgb: colors.first!).lightness > 0.99
                } else if colors.count == 2 {
                    return UIColor(rgb: colors.first!).lightness > 0.99 || UIColor(rgb: colors.last!).lightness > 0.99
                } else {
                    var lightCount = 0
                    for color in colors {
                        if UIColor(rgb: color).lightness > 0.99 {
                            lightCount += 1
                        }
                    }
                    return lightCount >= 2
                }
        }
    }
    
    public func generateImage(size: CGSize) -> UIImage {
        switch self {
            case let .gradient(colors):
                if colors.count == 1 {
                    return generateSingleColorImage(size: size, color: UIColor(rgb: colors.first!))!
                } else if colors.count == 2 {
                    return generateGradientImage(size: size, colors: colors.map { UIColor(rgb: $0) }, locations: [0.0, 1.0])!
                } else {
                    return GradientBackgroundNode.generatePreview(size: size, colors: colors.map { UIColor(rgb: $0) })
                }
        }
    }
}
