import Foundation
import UIKit
import Display
import TelegramCore
import TelegramPresentationData

public func generateGiftMessageBubbleBackgroundImage(fillColor: UIColor, wallpaper: TelegramWallpaper, size: CGSize) -> UIImage? {
    guard size.width > 0.0, size.height > 0.0 else {
        return nil
    }
    
    let fillImage = messageBubbleImage(
        maxCornerRadius: 14.0,
        minCornerRadius: 8.0,
        incoming: true,
        fillColor: fillColor,
        strokeColor: .clear,
        neighbors: .none,
        shadow: nil,
        wallpaper: wallpaper,
        knockout: false
    )
    let outlineImage = messageBubbleImage(
        maxCornerRadius: 14.0,
        minCornerRadius: 8.0,
        incoming: true,
        fillColor: .clear,
        strokeColor: .white,
        neighbors: .none,
        shadow: nil,
        wallpaper: wallpaper,
        knockout: false,
        onlyOutline: true
    )
    
    guard let gradientOutlineImage = generateImage(size, rotatedContext: { size, context in
        let bounds = CGRect(origin: .zero, size: size)
        context.clear(bounds)
        
        var locations: [CGFloat] = [0.0, 0.1, 0.5, 0.9, 1.0]
        let colors: [CGColor] = [
            UIColor.white.withAlphaComponent(0.5).cgColor,
            UIColor.white.withAlphaComponent(0.5).cgColor,
            UIColor.white.withAlphaComponent(0.0).cgColor,
            UIColor.white.withAlphaComponent(0.5).cgColor,
            UIColor.white.withAlphaComponent(0.5).cgColor
        ]
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        if let gradient = CGGradient(colorsSpace: colorSpace, colors: colors as CFArray, locations: &locations) {
            let angle: CGFloat = 45.0 * .pi / 180.0
            let direction = CGPoint(x: cos(angle), y: sin(angle))
            let center = CGPoint(x: size.width * 0.5, y: size.height * 0.5)
            let extent = abs(direction.x) * size.width * 0.5 + abs(direction.y) * size.height * 0.5
            context.drawLinearGradient(
                gradient,
                start: CGPoint(x: center.x - direction.x * extent, y: center.y - direction.y * extent),
                end: CGPoint(x: center.x + direction.x * extent, y: center.y + direction.y * extent),
                options: CGGradientDrawingOptions()
            )
        }
        
        UIGraphicsPushContext(context)
        outlineImage.draw(in: bounds, blendMode: .destinationIn, alpha: 1.0)
        UIGraphicsPopContext()
    }) else {
        return nil
    }
    
    return generateImage(size, rotatedContext: { size, context in
        let bounds = CGRect(origin: .zero, size: size)
        context.clear(bounds)
        
        UIGraphicsPushContext(context)
        fillImage.draw(in: bounds)
        gradientOutlineImage.draw(in: bounds)
        UIGraphicsPopContext()
    })
}
