import Foundation
import UIKit

let deviceColorSpace = CGColorSpaceCreateDeviceRGB()
let deviceScale = UIScreen.mainScreen().scale

public func generateImage(size: CGSize, generator: (CGSize, UnsafeMutablePointer<Int8>) -> Void) -> UIImage? {
    let scale = deviceScale
    let scaledSize = CGSize(width: size.width * scale, height: size.height * scale)
    let bytesPerRow = (4 * Int(scaledSize.width) + 15) & (~15)
    let length = bytesPerRow * Int(scaledSize.height)
    let bytes = UnsafeMutablePointer<Int8>(malloc(length))
    let provider: CGDataProvider? = CGDataProviderCreateWithData(bytes, bytes, length, { bytes, _, _ in
        free(bytes)
    })
    
    generator(scaledSize, bytes)
    
    let bitmapInfo = CGBitmapInfo(rawValue: CGBitmapInfo.ByteOrder32Little.rawValue | CGImageAlphaInfo.PremultipliedFirst.rawValue)
    guard let image = CGImageCreate(Int(scaledSize.width), Int(scaledSize.height), 8, 32, bytesPerRow, deviceColorSpace, bitmapInfo, provider, nil, false, .RenderingIntentDefault)
        else {
            return nil
    }
    
    return UIImage(CGImage: image, scale: scale, orientation: .Up)
}

public func generateImage(size: CGSize, opaque: Bool = false, generator: (CGSize, CGContextRef) -> Void) -> UIImage? {
    let scale = deviceScale
    let scaledSize = CGSize(width: size.width * scale, height: size.height * scale)
    let bytesPerRow = (4 * Int(scaledSize.width) + 15) & (~15)
    let length = bytesPerRow * Int(scaledSize.height)
    let bytes = UnsafeMutablePointer<Int8>(malloc(length))
    let provider: CGDataProvider? = CGDataProviderCreateWithData(bytes, bytes, length, { bytes, _, _ in
        free(bytes)
    })
    
    let bitmapInfo = CGBitmapInfo(rawValue: CGBitmapInfo.ByteOrder32Little.rawValue | (opaque ? CGImageAlphaInfo.NoneSkipFirst.rawValue : CGImageAlphaInfo.PremultipliedFirst.rawValue))
    
    guard let context = CGBitmapContextCreate(bytes, Int(scaledSize.width), Int(scaledSize.height), 8, bytesPerRow, deviceColorSpace, bitmapInfo.rawValue)
        else {
            return nil
    }
    
    CGContextScaleCTM(context, scale, scale)
    
    generator(size, context)
    
    guard let image = CGImageCreate(Int(scaledSize.width), Int(scaledSize.height), 8, 32, bytesPerRow, deviceColorSpace, bitmapInfo, provider, nil, false, .RenderingIntentDefault)
        else {
            return nil
    }
    
    return UIImage(CGImage: image, scale: scale, orientation: .Up)
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
    
    public func withContext(@noescape f: (CGContext) -> ()) {
        if self._context == nil {
            let c = CGBitmapContextCreate(bytes, Int(scaledSize.width), Int(scaledSize.height), 8, bytesPerRow, deviceColorSpace, self.bitmapInfo.rawValue)
            CGContextScaleCTM(c, scale, scale)
            self._context = c
        }
        
        if let _context = self._context {
            CGContextTranslateCTM(_context, self.size.width / 2.0, self.size.height / 2.0)
            CGContextScaleCTM(_context, 1.0, -1.0)
            CGContextTranslateCTM(_context, -self.size.width / 2.0, -self.size.height / 2.0)
            
            f(_context)
            
            CGContextTranslateCTM(_context, self.size.width / 2.0, self.size.height / 2.0)
            CGContextScaleCTM(_context, 1.0, -1.0)
            CGContextTranslateCTM(_context, -self.size.width / 2.0, -self.size.height / 2.0)
        }
    }
    
    public func withFlippedContext(@noescape f: (CGContext) -> ()) {
        if self._context == nil {
            let c = CGBitmapContextCreate(bytes, Int(scaledSize.width), Int(scaledSize.height), 8, bytesPerRow, deviceColorSpace, self.bitmapInfo.rawValue)
            CGContextScaleCTM(c, scale, scale)
            self._context = c
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
        
        self.bitmapInfo = CGBitmapInfo(rawValue: CGBitmapInfo.ByteOrder32Little.rawValue | CGImageAlphaInfo.PremultipliedFirst.rawValue)
        
        self.bytes = UnsafeMutablePointer<Int8>(malloc(length))
        if clear {
            memset(self.bytes, 0, self.length)
        }
        self.provider = CGDataProviderCreateWithData(bytes, bytes, length, { bytes, _, _ in
            free(bytes)
        })
    }
    
    public func generateImage() -> UIImage? {
        if let image = CGImageCreate(Int(scaledSize.width), Int(scaledSize.height), 8, 32, bytesPerRow, deviceColorSpace, bitmapInfo, provider, nil, false, .RenderingIntentDefault) {
            return UIImage(CGImage: image, scale: scale, orientation: .Up)
        } else {
            return nil
        }
    }
    
    public func colorAt(point: CGPoint) -> UIColor {
        let x = Int(point.x * self.scale)
        let y = Int(point.y * self.scale)
        if x >= 0 && x < Int(self.scaledSize.width) && y >= 0 && y < Int(self.scaledSize.height) {
            let srcLine = UnsafeMutablePointer<UInt32>(self.bytes + y * self.bytesPerRow)
            let pixel = srcLine + x
            let colorValue = pixel.memory
            return UIColor(UInt32(colorValue))
        } else {
            return UIColor.clearColor()
        }
    }
    
    public func blt(other: DrawingContext, at: CGPoint, mode: DrawingContextBltMode = .Alpha) {
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
                            
                            let baseColor = dstPixel.memory
                            let baseR = (baseColor >> 16) & 0xff
                            let baseG = (baseColor >> 8) & 0xff
                            let baseB = baseColor & 0xff
                            
                            let alpha = srcPixel.memory >> 24
                            
                            let r = (baseR * alpha) / 255
                            let g = (baseG * alpha) / 255
                            let b = (baseB * alpha) / 255
                            
                            dstPixel.memory = (alpha << 24) | (r << 16) | (g << 8) | b
                            
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

public enum ParsingError: ErrorType {
    case Generic
}

public func readCGFloat(inout index: UnsafePointer<UInt8>, end: UnsafePointer<UInt8>, separator: UInt8) throws -> CGFloat {
    let begin = index
    var seenPoint = false
    while index <= end {
        let c = index.memory
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
    
    if let value = NSString(bytes: UnsafePointer<Void>(begin), length: index - begin, encoding: NSUTF8StringEncoding)?.floatValue {
        return CGFloat(value)
    } else {
        throw ParsingError.Generic
    }
}

public func drawSvgPath(context: CGContextRef, path: StaticString) throws {
    var index: UnsafePointer<UInt8> = path.utf8Start
    let end = path.utf8Start.advancedBy(path.byteSize)
    while index < end {
        let c = index.memory
        index = index.successor()
        
        if c == 77 { // M
            let x = try readCGFloat(&index, end: end, separator: 44)
            let y = try readCGFloat(&index, end: end, separator: 32)
            
            //print("Move to \(x), \(y)")
            CGContextMoveToPoint(context, x, y)
        } else if c == 76 { // L
            let x = try readCGFloat(&index, end: end, separator: 44)
            let y = try readCGFloat(&index, end: end, separator: 32)
            
            //print("Line to \(x), \(y)")
            CGContextAddLineToPoint(context, x, y)
        } else if c == 67 { // C
            let x1 = try readCGFloat(&index, end: end, separator: 44)
            let y1 = try readCGFloat(&index, end: end, separator: 32)
            let x2 = try readCGFloat(&index, end: end, separator: 44)
            let y2 = try readCGFloat(&index, end: end, separator: 32)
            let x = try readCGFloat(&index, end: end, separator: 44)
            let y = try readCGFloat(&index, end: end, separator: 32)
            CGContextAddCurveToPoint(context, x1, y1, x2, y2, x, y)
            
            //print("Line to \(x), \(y)")
            
        } else if c == 90 { // Z
            if index != end && index.memory != 32 {
                throw ParsingError.Generic
            }
            
            //CGContextClosePath(context)
            CGContextFillPath(context)
            //CGContextBeginPath(context)
            //print("Close")
        }
    }
}
