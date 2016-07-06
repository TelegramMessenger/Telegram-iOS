import Foundation
import UIKit

let deviceColorSpace = CGColorSpaceCreateDeviceRGB()
let deviceScale = UIScreen.main().scale

public func generateImage(_ size: CGSize, pixelGenerator: (CGSize, UnsafeMutablePointer<Int8>) -> Void) -> UIImage? {
    let scale = deviceScale
    let scaledSize = CGSize(width: size.width * scale, height: size.height * scale)
    let bytesPerRow = (4 * Int(scaledSize.width) + 15) & (~15)
    let length = bytesPerRow * Int(scaledSize.height)
    let bytes = UnsafeMutablePointer<Int8>(malloc(length)!)
    guard let provider = CGDataProvider(dataInfo: bytes, data: bytes, size: length, releaseData: { bytes, _, _ in
        free(bytes)
    })
    else {
        return nil
    }
    
    pixelGenerator(scaledSize, bytes)
    
    let bitmapInfo = CGBitmapInfo(rawValue: CGBitmapInfo.byteOrder32Little.rawValue | CGImageAlphaInfo.premultipliedFirst.rawValue)
    
    guard let image = CGImage(width: Int(scaledSize.width), height: Int(scaledSize.height), bitsPerComponent: 8, bitsPerPixel: 32, bytesPerRow: bytesPerRow, space: deviceColorSpace, bitmapInfo: bitmapInfo, provider: provider, decode: nil, shouldInterpolate: false, intent: .defaultIntent)
    else {
        return nil
    }
    
    return UIImage(cgImage: image, scale: scale, orientation: .up)
}

public func generateImage(_ size: CGSize, contextGenerator: (CGSize, CGContext) -> Void, opaque: Bool = false) -> UIImage? {
    let scale = deviceScale
    let scaledSize = CGSize(width: size.width * scale, height: size.height * scale)
    let bytesPerRow = (4 * Int(scaledSize.width) + 15) & (~15)
    let length = bytesPerRow * Int(scaledSize.height)
    let bytes = UnsafeMutablePointer<Int8>(malloc(length)!)
    
    guard let provider = CGDataProvider(dataInfo: bytes, data: bytes, size: length, releaseData: { bytes, _, _ in
        free(bytes)
    })
    else {
        return nil
    }
    
    let bitmapInfo = CGBitmapInfo(rawValue: CGBitmapInfo.byteOrder32Little.rawValue | (opaque ? CGImageAlphaInfo.noneSkipFirst.rawValue : CGImageAlphaInfo.premultipliedFirst.rawValue))
    
    guard let context = CGContext(data: bytes, width: Int(scaledSize.width), height: Int(scaledSize.height), bitsPerComponent: 8, bytesPerRow: bytesPerRow, space: deviceColorSpace, bitmapInfo: bitmapInfo.rawValue)
        else {
            return nil
    }
    
    context.scale(x: scale, y: scale)
    
    contextGenerator(size, context)
    
    guard let image = CGImage(width: Int(scaledSize.width), height: Int(scaledSize.height), bitsPerComponent: 8, bitsPerPixel: 32, bytesPerRow: bytesPerRow, space: deviceColorSpace, bitmapInfo: bitmapInfo, provider: provider, decode: nil, shouldInterpolate: false, intent: .defaultIntent)
    else {
        return nil
    }
    
    return UIImage(cgImage: image, scale: scale, orientation: .up)
}

public func generateFilledCircleImage(radius: CGFloat, color: UIColor?, backgroundColor: UIColor? = nil) -> UIImage? {
    return generateImage(CGSize(width: radius * 2.0, height: radius * 2.0), contextGenerator: { size, context in
        context.clear(CGRect(origin: CGPoint(), size: size))
        if let backgroundColor = backgroundColor {
            context.setFillColor(backgroundColor.cgColor)
            context.fill(CGRect(origin: CGPoint(), size: size))
        }
        
        if let color = color {
            context.setFillColor(color.cgColor)
        } else {
            context.setFillColor(UIColor.clear().cgColor)
            context.setBlendMode(.copy)
        }
        context.fillEllipse(in: CGRect(origin: CGPoint(), size: size))
    })
}

public func generateStretchableFilledCircleImage(radius: CGFloat, color: UIColor?, backgroundColor: UIColor? = nil) -> UIImage? {
    return generateFilledCircleImage(radius: radius, color: color, backgroundColor: backgroundColor)?.stretchableImage(withLeftCapWidth: Int(radius), topCapHeight: Int(radius))
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
    public let bytes: UnsafeMutablePointer<Int8>
    let provider: CGDataProvider?
    
    private var _context: CGContext?
    
    public func withContext(_ f: @noescape(CGContext) -> ()) {
        if self._context == nil {
            if let c = CGContext(data: bytes, width: Int(scaledSize.width), height: Int(scaledSize.height), bitsPerComponent: 8, bytesPerRow: bytesPerRow, space: deviceColorSpace, bitmapInfo: self.bitmapInfo.rawValue) {
                c.scale(x: scale, y: scale)
                self._context = c
            }
        }
        
        if let _context = self._context {
            _context.translate(x: self.size.width / 2.0, y: self.size.height / 2.0)
            _context.scale(x: 1.0, y: -1.0)
            _context.translate(x: -self.size.width / 2.0, y: -self.size.height / 2.0)
            
            f(_context)
            
            _context.translate(x: self.size.width / 2.0, y: self.size.height / 2.0)
            _context.scale(x: 1.0, y: -1.0)
            _context.translate(x: -self.size.width / 2.0, y: -self.size.height / 2.0)
        }
    }
    
    public func withFlippedContext(_ f: @noescape(CGContext) -> ()) {
        if self._context == nil {
            if let c = CGContext(data: bytes, width: Int(scaledSize.width), height: Int(scaledSize.height), bitsPerComponent: 8, bytesPerRow: bytesPerRow, space: deviceColorSpace, bitmapInfo: self.bitmapInfo.rawValue) {
                c.scale(x: scale, y: scale)
                self._context = c
            }
        }
        
        if let _context = self._context {
            f(_context)
        }
    }
    
    public init(size: CGSize, scale: CGFloat = deviceScale, clear: Bool = false) {
        self.size = size
        self.scale = scale
        self.scaledSize = CGSize(width: size.width * scale, height: size.height * scale)
        
        self.bytesPerRow = (4 * Int(scaledSize.width) + 15) & (~15)
        self.length = bytesPerRow * Int(scaledSize.height)
        
        self.bitmapInfo = CGBitmapInfo(rawValue: CGBitmapInfo.byteOrder32Little.rawValue | CGImageAlphaInfo.premultipliedFirst.rawValue)
        
        self.bytes = UnsafeMutablePointer<Int8>(malloc(length))
        if clear {
            memset(self.bytes, 0, self.length)
        }
        self.provider = CGDataProvider(dataInfo: bytes, data: bytes, size: length, releaseData: { bytes, _, _ in
            free(bytes)
        })
    }
    
    public func generateImage() -> UIImage? {
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
            let srcLine = UnsafeMutablePointer<UInt32>(self.bytes + y * self.bytesPerRow)
            let pixel = srcLine + x
            let colorValue = pixel.pointee
            return UIColor(UInt32(colorValue))
        } else {
            return UIColor.clear()
        }
    }
    
    public func blt(_ other: DrawingContext, at: CGPoint, mode: DrawingContextBltMode = .Alpha) {
        if abs(other.scale - self.scale) < CGFloat(FLT_EPSILON) {
            let srcX = 0
            var srcY = 0
            let dstX = Int(at.x * self.scale)
            var dstY = Int(at.y * self.scale)
            
            let width = min(Int(self.size.width * self.scale) - dstX, Int(other.size.width * self.scale))
            let height = min(Int(self.size.height * self.scale) - dstY, Int(other.size.height * self.scale))
            
            let maxDstX = dstX + width
            let maxDstY = dstY + height
            
            switch mode {
                case .Alpha:
                    while dstY < maxDstY {
                        let srcLine = UnsafeMutablePointer<UInt32>(other.bytes + srcY * other.bytesPerRow)
                        let dstLine = UnsafeMutablePointer<UInt32>(self.bytes + dstY * self.bytesPerRow)
                        
                        var dx = dstX
                        var sx = srcX
                        while dx < maxDstX {
                            let srcPixel = srcLine + sx
                            let dstPixel = dstLine + dx
                            
                            let baseColor = dstPixel.pointee
                            let baseR = (baseColor >> 16) & 0xff
                            let baseG = (baseColor >> 8) & 0xff
                            let baseB = baseColor & 0xff
                            
                            let alpha = srcPixel.pointee >> 24
                            
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

public enum ParsingError: ErrorProtocol {
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
        } else if c < 48 || c > 57 {
            throw ParsingError.Generic
        }
    }
    
    if index == begin {
        throw ParsingError.Generic
    }
    
    if let value = NSString(bytes: UnsafePointer<Void>(begin), length: index - begin, encoding: String.Encoding.utf8.rawValue)?.floatValue {
        return CGFloat(value)
    } else {
        throw ParsingError.Generic
    }
}

public func drawSvgPath(_ context: CGContext, path: StaticString) throws {
    var index: UnsafePointer<UInt8> = path.utf8Start
    let end = path.utf8Start.advanced(by: path.utf8CodeUnitCount)
    while index < end {
        let c = index.pointee
        index = index.successor()
        
        if c == 77 { // M
            let x = try readCGFloat(&index, end: end, separator: 44)
            let y = try readCGFloat(&index, end: end, separator: 32)
            
            //print("Move to \(x), \(y)")
            context.moveTo(x: x, y: y)
        } else if c == 76 { // L
            let x = try readCGFloat(&index, end: end, separator: 44)
            let y = try readCGFloat(&index, end: end, separator: 32)
            
            //print("Line to \(x), \(y)")
            context.addLineTo(x: x, y: y)
        } else if c == 67 { // C
            let x1 = try readCGFloat(&index, end: end, separator: 44)
            let y1 = try readCGFloat(&index, end: end, separator: 32)
            let x2 = try readCGFloat(&index, end: end, separator: 44)
            let y2 = try readCGFloat(&index, end: end, separator: 32)
            let x = try readCGFloat(&index, end: end, separator: 44)
            let y = try readCGFloat(&index, end: end, separator: 32)
            context.addCurveTo(cp1x: x1, cp1y: y1, cp2x: x2, cp2y: y2, endingAtX: x, y: y)
            
            //print("Line to \(x), \(y)")
            
        } else if c == 90 { // Z
            if index != end && index.pointee != 32 {
                throw ParsingError.Generic
            }
            
            //CGContextClosePath(context)
            context.fillPath()
            //CGContextBeginPath(context)
            //print("Close")
        }
    }
}
