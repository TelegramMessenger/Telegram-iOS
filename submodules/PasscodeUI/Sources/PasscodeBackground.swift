import Foundation
import UIKit
import AsyncDisplayKit
import Display
import ImageBlur
import FastBlur
import GradientBackground

protocol PasscodeBackground {
    var size: CGSize { get }
    var backgroundImage: UIImage? { get }
    var foregroundImage: UIImage? { get }
    
    func makeBackgroundNode() -> ASDisplayNode?
    func makeForegroundNode(backgroundNode: ASDisplayNode?) -> ASDisplayNode?
}

final class CustomPasscodeBackground: PasscodeBackground {
    private let colors: [UIColor]
    private let backgroundNode: GradientBackgroundNode
    let inverted: Bool
    
    public private(set) var size: CGSize
    public private(set) var backgroundImage: UIImage? = nil
    public private(set) var foregroundImage: UIImage? = nil
    
    init(size: CGSize, colors: [UIColor], inverted: Bool) {
        self.size = size
        self.colors = colors
        self.inverted = inverted
        self.backgroundNode = createGradientBackgroundNode(colors: self.colors)
    }
    
    func makeBackgroundNode() -> ASDisplayNode? {
        return self.backgroundNode
    }
    
    func makeForegroundNode(backgroundNode: ASDisplayNode?) -> ASDisplayNode? {
        if self.inverted, let backgroundNode = backgroundNode as? GradientBackgroundNode {
            return GradientBackgroundNode.CloneNode(parentNode: backgroundNode)
        } else {
            return nil
        }
    }
}

final class GradientPasscodeBackground: PasscodeBackground {
    public private(set) var size: CGSize
    public private(set) var backgroundImage: UIImage?
    public private(set) var foregroundImage: UIImage?
    
    init(size: CGSize, backgroundColors: (UIColor, UIColor), buttonColor: UIColor) {
        self.size = size
        self.backgroundImage = generateImage(CGSize(width: 8.0, height: size.height), contextGenerator: { size, context in
            let gradientColors = [backgroundColors.1.cgColor, backgroundColors.0.cgColor] as CFArray
            var locations: [CGFloat] = [0.0, 1.0]
            let colorSpace = CGColorSpaceCreateDeviceRGB()
            let gradient = CGGradient(colorsSpace: colorSpace, colors: gradientColors, locations: &locations)!
            context.drawLinearGradient(gradient, start: CGPoint(x: 0.0, y: 0.0), end: CGPoint(x: 0.0, y: size.height), options: CGGradientDrawingOptions())
        })!
        self.foregroundImage = generateImage(CGSize(width: 1.0, height: 1.0), contextGenerator: { size, context in
            let bounds = CGRect(origin: CGPoint(), size: size)
            context.clear(bounds)
            if buttonColor != UIColor.clear {
                context.setFillColor(buttonColor.cgColor)
            } else {
                context.setFillColor(UIColor.white.withAlphaComponent(0.5).cgColor)
            }
            context.fill(bounds)
        })!
    }
    
    func makeBackgroundNode() -> ASDisplayNode? {
        return nil
    }
    
    func makeForegroundNode(backgroundNode: ASDisplayNode?) -> ASDisplayNode? {
        return nil
    }
}

final class ImageBasedPasscodeBackground: PasscodeBackground {
    public private(set) var size: CGSize
    public private(set) var backgroundImage: UIImage?
    public private(set) var foregroundImage: UIImage?
    
    init(image: UIImage, size: CGSize) {
        self.size = size
        
        let contextSize = size.aspectFilled(CGSize(width: 320.0, height: 320.0))
        let foregroundContext = DrawingContext(size: contextSize, scale: 1.0)
        let bounds = CGRect(origin: CGPoint(), size: contextSize)
        
        let filledImageSize = image.size.aspectFilled(contextSize)
        let filledImageRect = CGRect(origin: CGPoint(x: (contextSize.width - filledImageSize.width) / 2.0, y: (contextSize.height - filledImageSize.height) / 2.0), size: filledImageSize)
        
        foregroundContext.withFlippedContext { c in
            c.interpolationQuality = .medium
            c.draw(image.cgImage!, in: filledImageRect)
        }
        telegramFastBlurMore(Int32(contextSize.width), Int32(contextSize.height), Int32(foregroundContext.bytesPerRow), foregroundContext.bytes)
        telegramFastBlurMore(Int32(contextSize.width), Int32(contextSize.height), Int32(foregroundContext.bytesPerRow), foregroundContext.bytes)
        telegramFastBlurMore(Int32(contextSize.width), Int32(contextSize.height), Int32(foregroundContext.bytesPerRow), foregroundContext.bytes)
        telegramBrightenImage(Int32(contextSize.width), Int32(contextSize.height), Int32(foregroundContext.bytesPerRow), foregroundContext.bytes)
        
        foregroundContext.withFlippedContext { c in
            c.setFillColor(UIColor(white: 1.0, alpha: 0.1).cgColor)
            c.fill(bounds)
        }
        self.foregroundImage = foregroundContext.generateImage()!
        
        let backgroundContext = DrawingContext(size: contextSize, scale: 1.0)
        backgroundContext.withFlippedContext { c in
            c.interpolationQuality = .medium
            c.draw(image.cgImage!, in: filledImageRect)
        }
        telegramFastBlurMore(Int32(contextSize.width), Int32(contextSize.height), Int32(backgroundContext.bytesPerRow), backgroundContext.bytes)
        telegramFastBlurMore(Int32(contextSize.width), Int32(contextSize.height), Int32(backgroundContext.bytesPerRow), backgroundContext.bytes)
        telegramFastBlurMore(Int32(contextSize.width), Int32(contextSize.height), Int32(foregroundContext.bytesPerRow), backgroundContext.bytes)
        
        backgroundContext.withFlippedContext { context in
            context.setFillColor(UIColor(white: 0.0, alpha: 0.35).cgColor)
            context.fill(bounds)
        }
        self.backgroundImage = backgroundContext.generateImage()!
    }

    func makeBackgroundNode() -> ASDisplayNode? {
        return nil
    }
    
    func makeForegroundNode(backgroundNode: ASDisplayNode?) -> ASDisplayNode? {
        return nil
    }
}
