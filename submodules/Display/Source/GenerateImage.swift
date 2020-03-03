import Foundation
import UIKit
import Accelerate

public let deviceColorSpace: CGColorSpace = {
    if #available(iOSApplicationExtension 9.3, iOS 9.3, *) {
        if let colorSpace = CGColorSpace(name: CGColorSpace.displayP3) {
            return colorSpace
        } else {
            return CGColorSpaceCreateDeviceRGB()
        }
    } else {
        return CGColorSpaceCreateDeviceRGB()
    }
}()

private let grayscaleColorSpace = CGColorSpaceCreateDeviceGray()

let deviceScale = UIScreen.main.scale

public func generateImagePixel(_ size: CGSize, scale: CGFloat, pixelGenerator: (CGSize, UnsafeMutablePointer<UInt8>, Int) -> Void) -> UIImage? {
    let scaledSize = CGSize(width: size.width * scale, height: size.height * scale)
    let bytesPerRow = (4 * Int(scaledSize.width) + 15) & (~15)
    let length = bytesPerRow * Int(scaledSize.height)
    let bytes = malloc(length)!.assumingMemoryBound(to: UInt8.self)
    guard let provider = CGDataProvider(dataInfo: bytes, data: bytes, size: length, releaseData: { bytes, _, _ in
        free(bytes)
    })
    else {
        return nil
    }
    
    pixelGenerator(scaledSize, bytes, bytesPerRow)
    
    let bitmapInfo = CGBitmapInfo(rawValue: CGBitmapInfo.byteOrder32Little.rawValue | CGImageAlphaInfo.premultipliedFirst.rawValue)
    
    guard let image = CGImage(width: Int(scaledSize.width), height: Int(scaledSize.height), bitsPerComponent: 8, bitsPerPixel: 32, bytesPerRow: bytesPerRow, space: deviceColorSpace, bitmapInfo: bitmapInfo, provider: provider, decode: nil, shouldInterpolate: false, intent: .defaultIntent)
    else {
        return nil
    }
    
    return UIImage(cgImage: image, scale: scale, orientation: .up)
}

private func withImageBytes(image: UIImage, _ f: (UnsafePointer<UInt8>, Int, Int, Int) -> Void) {
    let selectedScale = image.scale
    let scaledSize = CGSize(width: image.size.width * selectedScale, height: image.size.height * selectedScale)
    let bytesPerRow = (4 * Int(scaledSize.width) + 15) & (~15)
    let length = bytesPerRow * Int(scaledSize.height)
    let bytes = malloc(length)!.assumingMemoryBound(to: UInt8.self)
    memset(bytes, 0, length)
    
    let bitmapInfo = CGBitmapInfo(rawValue: CGBitmapInfo.byteOrder32Little.rawValue | CGImageAlphaInfo.premultipliedFirst.rawValue)
    
    guard let context = CGContext(data: bytes, width: Int(scaledSize.width), height: Int(scaledSize.height), bitsPerComponent: 8, bytesPerRow: bytesPerRow, space: deviceColorSpace, bitmapInfo: bitmapInfo.rawValue) else {
        return
    }
    
    context.scaleBy(x: selectedScale, y: selectedScale)
    context.draw(image.cgImage!, in: CGRect(origin: CGPoint(), size: image.size))
    
    f(bytes, Int(scaledSize.width), Int(scaledSize.height), bytesPerRow)
}

public func generateGrayscaleAlphaMaskImage(image: UIImage) -> UIImage? {
    let selectedScale = image.scale
    let scaledSize = CGSize(width: image.size.width * selectedScale, height: image.size.height * selectedScale)
    let bytesPerRow = (1 * Int(scaledSize.width) + 15) & (~15)
    let length = bytesPerRow * Int(scaledSize.height)
    let bytes = malloc(length)!.assumingMemoryBound(to: UInt8.self)
    memset(bytes, 0, length)
    
    guard let provider = CGDataProvider(dataInfo: bytes, data: bytes, size: length, releaseData: { bytes, _, _ in
        free(bytes)
    })
        else {
            return nil
    }
    
    let bitmapInfo = CGBitmapInfo(rawValue: CGImageAlphaInfo.none.rawValue)
    
    guard let context = CGContext(data: bytes, width: Int(scaledSize.width), height: Int(scaledSize.height), bitsPerComponent: 8, bytesPerRow: bytesPerRow, space: grayscaleColorSpace, bitmapInfo: bitmapInfo.rawValue) else {
        return nil
    }
    
    context.scaleBy(x: selectedScale, y: selectedScale)
    
    withImageBytes(image: image, { pixels, width, height, imageBytesPerRow in
        var src = vImage_Buffer(data: UnsafeMutableRawPointer(mutating: pixels), height: vImagePixelCount(height), width: vImagePixelCount(width), rowBytes: imageBytesPerRow)
        
        let permuteMap: [UInt8] = [3, 2, 1, 0]
        vImagePermuteChannels_ARGB8888(&src, &src, permuteMap, vImage_Flags(kvImageDoNotTile))
        vImageUnpremultiplyData_ARGB8888(&src, &src, vImage_Flags(kvImageDoNotTile))
        
        for y in 0 ..< Int(scaledSize.height) {
            let srcRowBytes = pixels.advanced(by: y * imageBytesPerRow)
            let dstRowBytes = bytes.advanced(by: y * bytesPerRow)
            for x in 0 ..< Int(scaledSize.width) {
                let a = srcRowBytes.advanced(by: x * 4 + 0).pointee
                dstRowBytes.advanced(by: x).pointee = 0xff &- a
            }
        }
    })
    
    guard let image = CGImage(width: Int(scaledSize.width), height: Int(scaledSize.height), bitsPerComponent: 8, bitsPerPixel: 8, bytesPerRow: bytesPerRow, space: grayscaleColorSpace, bitmapInfo: bitmapInfo, provider: provider, decode: nil, shouldInterpolate: false, intent: .defaultIntent)
        else {
            return nil
    }
    
    return UIImage(cgImage: image, scale: selectedScale, orientation: .up)
}

public func generateImage(_ size: CGSize, contextGenerator: (CGSize, CGContext) -> Void, opaque: Bool = false, scale: CGFloat? = nil) -> UIImage? {
    let selectedScale = scale ?? deviceScale
    let scaledSize = CGSize(width: size.width * selectedScale, height: size.height * selectedScale)
    let bytesPerRow = (4 * Int(scaledSize.width) + 15) & (~15)
    let length = bytesPerRow * Int(scaledSize.height)
    let bytes = malloc(length)!.assumingMemoryBound(to: Int8.self)
    
    guard let provider = CGDataProvider(dataInfo: bytes, data: bytes, size: length, releaseData: { bytes, _, _ in
        free(bytes)
    })
    else {
        return nil
    }
    
    let bitmapInfo = CGBitmapInfo(rawValue: CGBitmapInfo.byteOrder32Little.rawValue | (opaque ? CGImageAlphaInfo.noneSkipFirst.rawValue : CGImageAlphaInfo.premultipliedFirst.rawValue))
    
    guard let context = CGContext(data: bytes, width: Int(scaledSize.width), height: Int(scaledSize.height), bitsPerComponent: 8, bytesPerRow: bytesPerRow, space: deviceColorSpace, bitmapInfo: bitmapInfo.rawValue) else {
        return nil
    }
    
    context.scaleBy(x: selectedScale, y: selectedScale)
    
    contextGenerator(size, context)
    
    guard let image = CGImage(width: Int(scaledSize.width), height: Int(scaledSize.height), bitsPerComponent: 8, bitsPerPixel: 32, bytesPerRow: bytesPerRow, space: deviceColorSpace, bitmapInfo: bitmapInfo, provider: provider, decode: nil, shouldInterpolate: false, intent: .defaultIntent)
    else {
        return nil
    }
    
    return UIImage(cgImage: image, scale: selectedScale, orientation: .up)
}

public func generateImage(_ size: CGSize, opaque: Bool = false, scale: CGFloat? = nil, rotatedContext: (CGSize, CGContext) -> Void) -> UIImage? {
    let selectedScale = scale ?? deviceScale
    let scaledSize = CGSize(width: size.width * selectedScale, height: size.height * selectedScale)
    let bytesPerRow = (4 * Int(scaledSize.width) + 15) & (~15)
    let length = bytesPerRow * Int(scaledSize.height)
    let bytes = malloc(length)!.assumingMemoryBound(to: Int8.self)
    
    guard let provider = CGDataProvider(dataInfo: bytes, data: bytes, size: length, releaseData: { bytes, _, _ in
        free(bytes)
    }) else {
        return nil
    }
    
    let bitmapInfo = CGBitmapInfo(rawValue: CGBitmapInfo.byteOrder32Little.rawValue | (opaque ? CGImageAlphaInfo.noneSkipFirst.rawValue : CGImageAlphaInfo.premultipliedFirst.rawValue))
    
    guard let context = CGContext(data: bytes, width: Int(scaledSize.width), height: Int(scaledSize.height), bitsPerComponent: 8, bytesPerRow: bytesPerRow, space: deviceColorSpace, bitmapInfo: bitmapInfo.rawValue) else {
        return nil
    }
    
    context.scaleBy(x: selectedScale, y: selectedScale)
    context.translateBy(x: size.width / 2.0, y: size.height / 2.0)
    context.scaleBy(x: 1.0, y: -1.0)
    context.translateBy(x: -size.width / 2.0, y: -size.height / 2.0)
    
    rotatedContext(size, context)
    
    guard let image = CGImage(width: Int(scaledSize.width), height: Int(scaledSize.height), bitsPerComponent: 8, bitsPerPixel: 32, bytesPerRow: bytesPerRow, space: deviceColorSpace, bitmapInfo: bitmapInfo, provider: provider, decode: nil, shouldInterpolate: false, intent: .defaultIntent)
        else {
            return nil
    }
    
    return UIImage(cgImage: image, scale: selectedScale, orientation: .up)
}

public func generateFilledCircleImage(diameter: CGFloat, color: UIColor?, strokeColor: UIColor? = nil, strokeWidth: CGFloat? = nil, backgroundColor: UIColor? = nil) -> UIImage? {
    return generateImage(CGSize(width: diameter, height: diameter), contextGenerator: { size, context in
        context.clear(CGRect(origin: CGPoint(), size: size))
        if let backgroundColor = backgroundColor {
            context.setFillColor(backgroundColor.cgColor)
            context.fill(CGRect(origin: CGPoint(), size: size))
        }
        
        if let strokeColor = strokeColor, let strokeWidth = strokeWidth {
            context.setFillColor(strokeColor.cgColor)
            context.fillEllipse(in: CGRect(origin: CGPoint(), size: size))
            
            if let color = color {
                context.setFillColor(color.cgColor)
            } else {
                context.setFillColor(UIColor.clear.cgColor)
                context.setBlendMode(.copy)
            }
            context.fillEllipse(in: CGRect(origin: CGPoint(x: strokeWidth, y: strokeWidth), size: CGSize(width: size.width - strokeWidth * 2.0, height: size.height - strokeWidth * 2.0)))
        } else {
            if let color = color {
                context.setFillColor(color.cgColor)
            } else {
                context.setFillColor(UIColor.clear.cgColor)
                context.setBlendMode(.copy)
            }
            context.fillEllipse(in: CGRect(origin: CGPoint(), size: size))
        }
    })
}

public func generateAdjustedStretchableFilledCircleImage(diameter: CGFloat, color: UIColor) -> UIImage? {
    let corner: CGFloat = diameter / 2.0
    return generateImage(CGSize(width: diameter + 2.0, height: diameter + 2.0), contextGenerator: { size, context in
        context.clear(CGRect(origin: CGPoint(), size: size))
        context.setFillColor(color.cgColor)
        context.move(to: CGPoint(x: 0.0, y: corner))
        context.addArc(tangent1End: CGPoint(x: 0.0, y: 0.0), tangent2End: CGPoint(x: corner, y: 0.0), radius: corner)
        context.addLine(to: CGPoint(x: size.width - corner, y: 0.0))
        context.addArc(tangent1End: CGPoint(x: size.width, y: 0.0), tangent2End: CGPoint(x: size.width, y: corner), radius: corner)
        context.addLine(to: CGPoint(x: size.width, y: size.height - corner))
        context.addArc(tangent1End: CGPoint(x: size.width, y: size.height), tangent2End: CGPoint(x: size.width - corner, y: size.height), radius: corner)
        context.addLine(to: CGPoint(x: corner, y: size.height))
        context.addArc(tangent1End: CGPoint(x: 0.0, y: size.height), tangent2End: CGPoint(x: 0.0, y: size.height - corner), radius: corner)
        context.closePath()
        context.fillPath()
    })?.stretchableImage(withLeftCapWidth: Int(diameter / 2) + 1, topCapHeight: Int(diameter / 2) + 1)
}

public func generateCircleImage(diameter: CGFloat, lineWidth: CGFloat, color: UIColor?, strokeColor: UIColor? = nil, strokeWidth: CGFloat? = nil, backgroundColor: UIColor? = nil) -> UIImage? {
    return generateImage(CGSize(width: diameter, height: diameter), contextGenerator: { size, context in
        context.clear(CGRect(origin: CGPoint(), size: size))
        if let backgroundColor = backgroundColor {
            context.setFillColor(backgroundColor.cgColor)
            context.fill(CGRect(origin: CGPoint(), size: size))
        }
        
        if let color = color {
            context.setStrokeColor(color.cgColor)
        } else {
            context.setStrokeColor(UIColor.clear.cgColor)
            context.setBlendMode(.copy)
        }
        context.setLineWidth(lineWidth)
        context.strokeEllipse(in: CGRect(origin: CGPoint(x: lineWidth / 2.0, y: lineWidth / 2.0), size: CGSize(width: size.width - lineWidth, height: size.height - lineWidth)))
    })
}

public func generateStretchableFilledCircleImage(radius: CGFloat, color: UIColor?, backgroundColor: UIColor? = nil) -> UIImage? {
    let intRadius = Int(radius)
    let cap = intRadius == 1 ? 2 : intRadius
    return generateFilledCircleImage(diameter: radius * 2.0, color: color, backgroundColor: backgroundColor)?.stretchableImage(withLeftCapWidth: cap, topCapHeight: cap)
}

public func generateStretchableFilledCircleImage(diameter: CGFloat, color: UIColor?, strokeColor: UIColor? = nil, strokeWidth: CGFloat? = nil, backgroundColor: UIColor? = nil) -> UIImage? {
    let intRadius = Int(diameter / 2.0)
    let intDiameter = Int(diameter)
    let cap: Int
    if intDiameter == 3 {
        cap = 1
    } else if intDiameter == 2 {
        cap = 3
    } else if intRadius == 1 {
        cap = 2
    } else {
        cap = intRadius
    }
    
    return generateFilledCircleImage(diameter: diameter, color: color, strokeColor: strokeColor, strokeWidth: strokeWidth, backgroundColor: backgroundColor)?.stretchableImage(withLeftCapWidth: cap, topCapHeight: cap)
}

public func generateVerticallyStretchableFilledCircleImage(radius: CGFloat, color: UIColor?, backgroundColor: UIColor? = nil) -> UIImage? {
    return generateImage(CGSize(width: radius * 2.0, height: radius * 2.0 + radius), contextGenerator: { size, context in
        context.clear(CGRect(origin: CGPoint(), size: size))
        if let backgroundColor = backgroundColor {
            context.setFillColor(backgroundColor.cgColor)
            context.fill(CGRect(origin: CGPoint(), size: size))
        }
        
        if let color = color {
            context.setFillColor(color.cgColor)
        } else {
            context.setFillColor(UIColor.clear.cgColor)
            context.setBlendMode(.copy)
        }
        context.fillEllipse(in: CGRect(origin: CGPoint(), size: CGSize(width: radius + radius, height: radius + radius)))
        context.fillEllipse(in: CGRect(origin: CGPoint(x: 0.0, y: radius), size: CGSize(width: radius + radius, height: radius + radius)))
    })?.stretchableImage(withLeftCapWidth: Int(radius), topCapHeight: Int(radius))
}

public func generateSmallHorizontalStretchableFilledCircleImage(diameter: CGFloat, color: UIColor?, backgroundColor: UIColor? = nil) -> UIImage? {
    return generateImage(CGSize(width: diameter + 1.0, height: diameter), contextGenerator: { size, context in
        context.clear(CGRect(origin: CGPoint(), size: size))
        
        if let subImage = generateImage(CGSize(width: diameter + 1.0, height: diameter), contextGenerator: { size, context in
            context.clear(CGRect(origin: CGPoint(), size: size))
            context.setFillColor(UIColor.black.cgColor)
            context.fillEllipse(in: CGRect(origin: CGPoint(), size: CGSize(width: diameter, height: diameter)))
            context.fill(CGRect(origin: CGPoint(x: diameter / 2.0, y: 0.0), size: CGSize(width: 1.0, height: diameter)))
            context.fillEllipse(in: CGRect(origin: CGPoint(x: 1.0, y: 0.0), size: CGSize(width: diameter, height: diameter)))
        }) {
            if let backgroundColor = backgroundColor {
                context.setFillColor(backgroundColor.cgColor)
                context.fill(CGRect(origin: CGPoint(), size: size))
            }
            
            if let color = color {
                context.setFillColor(color.cgColor)
            } else {
                context.setFillColor(UIColor.clear.cgColor)
                context.setBlendMode(.copy)
            }
            
            context.clip(to: CGRect(origin: CGPoint(), size: size), mask: subImage.cgImage!)
            context.fill(CGRect(origin: CGPoint(), size: size))
        }
    })?.stretchableImage(withLeftCapWidth: Int(diameter / 2), topCapHeight: Int(diameter / 2))
}

public func generateTintedImage(image: UIImage?, color: UIColor, backgroundColor: UIColor? = nil) -> UIImage? {
    guard let image = image else {
        return nil
    }
    
    let imageSize = image.size

    UIGraphicsBeginImageContextWithOptions(imageSize, backgroundColor != nil, image.scale)
    if let context = UIGraphicsGetCurrentContext() {
        if let backgroundColor = backgroundColor {
            context.setFillColor(backgroundColor.cgColor)
            context.fill(CGRect(origin: CGPoint(), size: imageSize))
        }
        
        let imageRect = CGRect(origin: CGPoint(), size: imageSize)
        context.saveGState()
        context.translateBy(x: imageRect.midX, y: imageRect.midY)
        context.scaleBy(x: 1.0, y: -1.0)
        context.translateBy(x: -imageRect.midX, y: -imageRect.midY)
        context.clip(to: imageRect, mask: image.cgImage!)
        context.setFillColor(color.cgColor)
        context.fill(imageRect)
        context.restoreGState()
    }
    
    let tintedImage = UIGraphicsGetImageFromCurrentImageContext()!
    UIGraphicsEndImageContext()
    
    return tintedImage
}

public func generateGradientTintedImage(image: UIImage?, colors: [UIColor]) -> UIImage? {
    guard let image = image else {
        return nil
    }
    
    let imageSize = image.size

    UIGraphicsBeginImageContextWithOptions(imageSize, false, image.scale)
    if let context = UIGraphicsGetCurrentContext() {
        let imageRect = CGRect(origin: CGPoint(), size: imageSize)
        context.saveGState()
        context.translateBy(x: imageRect.midX, y: imageRect.midY)
        context.scaleBy(x: 1.0, y: -1.0)
        context.translateBy(x: -imageRect.midX, y: -imageRect.midY)
        context.clip(to: imageRect, mask: image.cgImage!)
        
        let gradientColors = colors.map { $0.cgColor } as CFArray
        let delta: CGFloat = 1.0 / (CGFloat(colors.count) - 1.0)
        
        var locations: [CGFloat] = []
        for i in 0 ..< colors.count {
            locations.append(delta * CGFloat(i))
        }
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let gradient = CGGradient(colorsSpace: colorSpace, colors: gradientColors, locations: &locations)!
        
        context.drawLinearGradient(gradient, start: CGPoint(x: 0.0, y: imageRect.height), end: CGPoint(x: 0.0, y: 0.0), options: CGGradientDrawingOptions())
        
        context.restoreGState()
    }
    
    let tintedImage = UIGraphicsGetImageFromCurrentImageContext()!
    UIGraphicsEndImageContext()
    
    return tintedImage
}

public func generateScaledImage(image: UIImage?, size: CGSize, opaque: Bool = true, scale: CGFloat? = nil) -> UIImage? {
    guard let image = image else {
        return nil
    }
    
    return generateImage(size, contextGenerator: { size, context in
        if !opaque {
            context.clear(CGRect(origin: CGPoint(), size: size))
        }
        context.draw(image.cgImage!, in: CGRect(origin: CGPoint(), size: size))
    }, opaque: opaque, scale: scale)
}

private func generateSingleColorImage(size: CGSize, color: UIColor) -> UIImage? {
    return generateImage(size, contextGenerator: { size, context in
        context.setFillColor(color.cgColor)
        context.fill(CGRect(origin: CGPoint(), size: size))
    })
}

public enum DrawingContextBltMode {
    case Alpha
}

public class DrawingContext {
    public let size: CGSize
    public let scale: CGFloat
    private let scaledSize: CGSize
    public let bytesPerRow: Int
    private let bitmapInfo: CGBitmapInfo
    public let length: Int
    public let bytes: UnsafeMutableRawPointer
    let provider: CGDataProvider?
    
    private var _context: CGContext?
    
    public func withContext(_ f: (CGContext) -> ()) {
        if self._context == nil {
            if let c = CGContext(data: bytes, width: Int(scaledSize.width), height: Int(scaledSize.height), bitsPerComponent: 8, bytesPerRow: bytesPerRow, space: deviceColorSpace, bitmapInfo: self.bitmapInfo.rawValue) {
                c.scaleBy(x: scale, y: scale)
                self._context = c
            }
        }
        
        if let _context = self._context {
            _context.translateBy(x: self.size.width / 2.0, y: self.size.height / 2.0)
            _context.scaleBy(x: 1.0, y: -1.0)
            _context.translateBy(x: -self.size.width / 2.0, y: -self.size.height / 2.0)
            
            f(_context)
            
            _context.translateBy(x: self.size.width / 2.0, y: self.size.height / 2.0)
            _context.scaleBy(x: 1.0, y: -1.0)
            _context.translateBy(x: -self.size.width / 2.0, y: -self.size.height / 2.0)
        }
    }
    
    public func withFlippedContext(_ f: (CGContext) -> ()) {
        if self._context == nil {
            if let c = CGContext(data: bytes, width: Int(scaledSize.width), height: Int(scaledSize.height), bitsPerComponent: 8, bytesPerRow: bytesPerRow, space: deviceColorSpace, bitmapInfo: self.bitmapInfo.rawValue) {
                c.scaleBy(x: scale, y: scale)
                self._context = c
            }
        }
        
        if let _context = self._context {
            f(_context)
        }
    }
    
    public init(size: CGSize, scale: CGFloat = 0.0, premultiplied: Bool = true, clear: Bool = false) {
        let actualScale: CGFloat
        if scale.isZero {
            actualScale = deviceScale
        } else {
            actualScale = scale
        }
        self.size = size
        self.scale = actualScale
        self.scaledSize = CGSize(width: size.width * actualScale, height: size.height * actualScale)
        
        self.bytesPerRow = (4 * Int(scaledSize.width) + 15) & (~15)
        self.length = bytesPerRow * Int(scaledSize.height)
        
        if premultiplied {
            self.bitmapInfo = CGBitmapInfo(rawValue: CGBitmapInfo.byteOrder32Little.rawValue | CGImageAlphaInfo.premultipliedFirst.rawValue)
        } else {
            self.bitmapInfo = CGBitmapInfo(rawValue: CGBitmapInfo.byteOrder32Little.rawValue | CGImageAlphaInfo.first.rawValue)
        }
        
        self.bytes = malloc(length)!
        if clear {
            memset(self.bytes, 0, self.length)
        }
        self.provider = CGDataProvider(dataInfo: bytes, data: bytes, size: length, releaseData: { bytes, _, _ in
            free(bytes)
        })
        
        assert(self.bytesPerRow % 16 == 0)
        assert(Int64(Int(bitPattern: self.bytes)) % 16 == 0)
    }
    
    public func generateImage() -> UIImage? {
        if self.scaledSize.width.isZero || self.scaledSize.height.isZero {
            return nil
        }
        if let image = CGImage(width: Int(scaledSize.width), height: Int(scaledSize.height), bitsPerComponent: 8, bitsPerPixel: 32, bytesPerRow: bytesPerRow, space: deviceColorSpace, bitmapInfo: bitmapInfo, provider: provider!, decode: nil, shouldInterpolate: false, intent: .defaultIntent) {
            return UIImage(cgImage: image, scale: scale, orientation: .up)
        } else {
            return nil
        }
    }
    
    public func colorAt(_ point: CGPoint) -> UIColor {
        let x = Int(point.x * self.scale)
        let y = Int(point.y * self.scale)
        if x >= 0 && x < Int(self.scaledSize.width) && y >= 0 && y < Int(self.scaledSize.height) {
            let srcLine = self.bytes.advanced(by: y * self.bytesPerRow).assumingMemoryBound(to: UInt32.self)
            let pixel = srcLine + x
            let colorValue = pixel.pointee
            return UIColor(rgb: UInt32(colorValue))
        } else {
            return UIColor.clear
        }
    }
    
    public func blt(_ other: DrawingContext, at: CGPoint, mode: DrawingContextBltMode = .Alpha) {
        if abs(other.scale - self.scale) < CGFloat.ulpOfOne {
            let srcX = 0
            var srcY = 0
            let dstX = Int(at.x * self.scale)
            var dstY = Int(at.y * self.scale)
            if dstX < 0 || dstY < 0 {
                return
            }
            
            let width = min(Int(self.size.width * self.scale) - dstX, Int(other.size.width * self.scale))
            let height = min(Int(self.size.height * self.scale) - dstY, Int(other.size.height * self.scale))
            
            let maxDstX = dstX + width
            let maxDstY = dstY + height
            
            switch mode {
                case .Alpha:
                    while dstY < maxDstY {
                        let srcLine = other.bytes.advanced(by: max(0, srcY) * other.bytesPerRow).assumingMemoryBound(to: UInt32.self)
                        let dstLine = self.bytes.advanced(by: max(0, dstY) * self.bytesPerRow).assumingMemoryBound(to: UInt32.self)
                        
                        var dx = dstX
                        var sx = srcX
                        while dx < maxDstX {
                            let srcPixel = srcLine + sx
                            let dstPixel = dstLine + dx
                            
                            let baseColor = dstPixel.pointee
                            let baseAlpha = (baseColor >> 24) & 0xff
                            let baseR = (baseColor >> 16) & 0xff
                            let baseG = (baseColor >> 8) & 0xff
                            let baseB = baseColor & 0xff
                            
                            let alpha = min(baseAlpha, srcPixel.pointee >> 24)
                            
                            let r = (baseR * alpha) / 255
                            let g = (baseG * alpha) / 255
                            let b = (baseB * alpha) / 255
                            
                            dstPixel.pointee = (alpha << 24) | (r << 16) | (g << 8) | b
                            
                            dx += 1
                            sx += 1
                        }
                        
                        dstY += 1
                        srcY += 1
                    }
            }
        }
    }
}

public enum ParsingError: Error {
    case Generic
}

public func readCGFloat(_ index: inout UnsafePointer<UInt8>, end: UnsafePointer<UInt8>, separator: UInt8) throws -> CGFloat {
    let begin = index
    var seenPoint = false
    while index <= end {
        let c = index.pointee
        index = index.successor()
        
        if c == 46 { // .
            if seenPoint {
                throw ParsingError.Generic
            } else {
                seenPoint = true
            }
        } else if c == separator {
            break
        } else if !((c >= 48 && c <= 57) || c == 45 || c == 101 || c == 69) {
            throw ParsingError.Generic
        }
    }
    
    if index == begin {
        throw ParsingError.Generic
    }
    
    if let value = NSString(bytes: UnsafeRawPointer(begin), length: index - begin, encoding: String.Encoding.utf8.rawValue)?.floatValue {
        return CGFloat(value)
    } else {
        throw ParsingError.Generic
    }
}

public func drawSvgPath(_ context: CGContext, path: StaticString, strokeOnMove: Bool = false) throws {
    var index: UnsafePointer<UInt8> = path.utf8Start
    let end = path.utf8Start.advanced(by: path.utf8CodeUnitCount)
    while index < end {
        let c = index.pointee
        index = index.successor()
        
        if c == 77 { // M
            let x = try readCGFloat(&index, end: end, separator: 44)
            let y = try readCGFloat(&index, end: end, separator: 32)
            
            //print("Move to \(x), \(y)")
            context.move(to: CGPoint(x: x, y: y))
        } else if c == 76 { // L
            let x = try readCGFloat(&index, end: end, separator: 44)
            let y = try readCGFloat(&index, end: end, separator: 32)
            
            //print("Line to \(x), \(y)")
            context.addLine(to: CGPoint(x: x, y: y))
            
            if strokeOnMove {
                context.strokePath()
                context.move(to: CGPoint(x: x, y: y))
            }
        } else if c == 67 { // C
            let x1 = try readCGFloat(&index, end: end, separator: 44)
            let y1 = try readCGFloat(&index, end: end, separator: 32)
            let x2 = try readCGFloat(&index, end: end, separator: 44)
            let y2 = try readCGFloat(&index, end: end, separator: 32)
            let x = try readCGFloat(&index, end: end, separator: 44)
            let y = try readCGFloat(&index, end: end, separator: 32)
            context.addCurve(to: CGPoint(x: x, y: y), control1: CGPoint(x: x1, y: y1), control2: CGPoint(x: x2, y: y2))
            
            //print("Line to \(x), \(y)")
            if strokeOnMove {
                context.strokePath()
                context.move(to: CGPoint(x: x, y: y))
            }
        } else if c == 90 { // Z
            if index != end && index.pointee != 32 {
                throw ParsingError.Generic
            }
            
            //CGContextClosePath(context)
            context.fillPath()
            //CGContextBeginPath(context)
            //print("Close")
        } else if c == 83 { // S
            if index != end && index.pointee != 32 {
                throw ParsingError.Generic
            }
            
            //CGContextClosePath(context)
            context.strokePath()
            //CGContextBeginPath(context)
            //print("Close")
        } else if c == 32 { // space
            continue
        } else {
            throw ParsingError.Generic
        }
    }
}
