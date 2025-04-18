import Foundation
import UIKit
import Display
import GradientBackground

public enum AvatarBackground: Equatable {
    public static let defaultBackgrounds: [AvatarBackground] = [
        .gradient([0xFF5bd1ca, 0xFF538edb], false),
        .gradient([0xFF61dba8, 0xFF52abd6], false),
        .gradient([0xFFbdcb57, 0xFF4abe6e], false),
        .gradient([0xFFd971bf, 0xFF986ce9], false),
        .gradient([0xFFee8c56, 0xFFec628f], false),
        .gradient([0xFFf2994f, 0xFFe76667], false),
        .gradient([0xFFf0b948, 0xFFef7e4b], false),
        
        .gradient([0xFF94A3B0, 0xFF6C7B87], true),
        .gradient([0xFF949487, 0xFF707062], true),
        .gradient([0xFFB09F99, 0xFF8F7E72], true),
        .gradient([0xFFEBA15B, 0xFFA16730], true),
        .gradient([0xFFE8B948, 0xFFB87C30], true),
        .gradient([0xFF5E6F91, 0xFF415275], true),
        .gradient([0xFF565D61, 0xFF3B4347], true),
        .gradient([0xFF8F6655, 0xFF68443F], true),
        .gradient([0xFF1B1B1B, 0xFF000000], true),
        .gradient([0xFFAE72E3, 0xFF8854B5], true),
        .gradient([0xFFC269BE, 0xFF8B4384], true),
        .gradient([0xFF469CD3, 0xFF2E78A8], true),
        .gradient([0xFF5BCEC5, 0xFF36928E], true),
        .gradient([0xFF5FD66F, 0xFF319F76], true),
        .gradient([0xFF66B27A, 0xFF33786D], true),
        .gradient([0xFF6C9CF4, 0xFF5C6AEC], true),
        .gradient([0xFFDA76A8, 0xFFAE5891], true),
        .gradient([0xFFE66473, 0xFFA74559], true),
        .gradient([0xFFAF75BC, 0xFF895196], true),
        .gradient([0xFF438CB9, 0xFF2D6283], true),
        .gradient([0xFF81B6B2, 0xFF4B9A96], true),
        .gradient([0xFF66B27A, 0xFF33786D], true),
        .gradient([0xFFCAB560, 0xFF8C803C], true),
        .gradient([0xFFADB070, 0xFF6B7D54], true),
        .gradient([0xFFBC7051, 0xFF975547], true),
        .gradient([0xFFC7835E, 0xFF9E6345], true),
        .gradient([0xFFE68A3C, 0xFFD45393], true),
        .gradient([0xFF6BE2F2, 0xFF6675F7], true),
        .gradient([0xFFC56DF4, 0xFF6073F4], true),
        .gradient([0xFFEBC92F, 0xFF54B848], true)
    ]
    
    case gradient([UInt32], Bool)
    
    public var colors: [UInt32] {
        switch self {
        case let .gradient(colors, _):
            return colors
        }
    }
    
    public var isPremium: Bool {
        switch self {
        case let .gradient(_, isPremium):
            return isPremium
        }
    }
    
    public var isLight: Bool {
        switch self {
            case let .gradient(colors, _):
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
            case let .gradient(colors, _):
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
