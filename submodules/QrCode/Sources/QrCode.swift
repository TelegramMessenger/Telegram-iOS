import Foundation
import UIKit
import CoreImage
import CoreGraphics
import SwiftSignalKit
import Display

public enum QrCodeIcon {
    case none
    case cutout
    case proxy
    case custom(UIImage?)
}

private func floorToContextPixels(_ value: CGFloat, scale: CGFloat? = UIScreenScale) -> CGFloat {
    let scale = scale ?? UIScreenScale
    return floor(value * scale) / scale
}

private func roundToContextPixels(_ value: CGFloat, scale: CGFloat? = UIScreenScale) -> CGFloat {
    let scale = scale ?? UIScreenScale
    return round(value * scale) / scale
}

public func qrCodeCutout(size: Int, dimensions: CGSize, scale: CGFloat?) -> (Int, CGRect, CGFloat) {
    var cutoutSize = Int(round(CGFloat(size) * 0.297))
    if size == 39 {
        cutoutSize = 11
    } else if cutoutSize % 2 == 0 {
        cutoutSize += 1
    }
    cutoutSize = min(23, cutoutSize)
    
    let quadSize = floorToContextPixels(dimensions.width / CGFloat(size), scale: scale)
    let cutoutSide = quadSize * CGFloat(cutoutSize - 2)
    let cutoutRect = CGRect(x: floorToContextPixels((dimensions.width - cutoutSide) / 2.0, scale: scale), y: floorToContextPixels((dimensions.height - cutoutSide) / 2.0, scale: scale), width: cutoutSide, height: cutoutSide)
    
    return (cutoutSize, cutoutRect, quadSize)
}

public func qrCode(string: String, color: UIColor, backgroundColor: UIColor? = nil, icon: QrCodeIcon, ecl: String = "M") -> Signal<(Int, (TransformImageArguments) -> DrawingContext?), NoError> {
    return Signal<(Data, Int, Int), NoError> { subscriber in
        if let data = string.data(using: .isoLatin1, allowLossyConversion: false), let filter = CIFilter(name: "CIQRCodeGenerator") {
            filter.setValue(data, forKey: "inputMessage")
            filter.setValue(ecl, forKey: "inputCorrectionLevel")
            
            if let output = filter.outputImage {
                let size = Int(output.extent.width)
                let bytesPerRow = DeviceGraphicsContextSettings.shared.bytesPerRow(forWidth: Int(size))
                let length = bytesPerRow * size
                let bitmapInfo = CGBitmapInfo(rawValue: CGBitmapInfo.byteOrder32Little.rawValue | CGImageAlphaInfo.noneSkipFirst.rawValue)
                
                guard let bytes = malloc(length)?.assumingMemoryBound(to: UInt8.self) else {
                    return EmptyDisposable
                }
                let data = Data(bytesNoCopy: bytes, count: length, deallocator: .free)
                
                guard let context = CGContext(data: bytes, width: size, height: size, bitsPerComponent: 8, bytesPerRow: bytesPerRow, space: deviceColorSpace, bitmapInfo: bitmapInfo.rawValue) else {
                    return EmptyDisposable
                }
                
                let ciContext = CIContext(cgContext: context, options: nil)
                ciContext.draw(output, in: CGRect(x: 0, y: 0, width: size, height: size), from: output.extent)

                subscriber.putNext((data, size, bytesPerRow))
            }
        }
        subscriber.putCompletion()
        return EmptyDisposable
    }
    |> map { data, size, bytesPerRow in
        return (size, { arguments in
            let context = DrawingContext(size: arguments.drawingSize, scale: arguments.scale ?? 0.0, clear: true)

            let drawingRect = arguments.drawingRect
            let fittedSize = arguments.imageSize.aspectFilled(arguments.boundingSize).fitted(arguments.imageSize)
            let fittedRect = CGRect(origin: CGPoint(x: drawingRect.origin.x + (drawingRect.size.width - fittedSize.width) / 2.0, y: drawingRect.origin.y + (drawingRect.size.height - fittedSize.height) / 2.0), size: fittedSize)
                
            let (cutoutSize, clipRect, side) = qrCodeCutout(size: size, dimensions: fittedSize, scale: arguments.scale)
            let padding: CGFloat = roundToContextPixels((arguments.drawingSize.width - CGFloat(side * CGFloat(size))) / 2.0, scale: arguments.scale)
            
            let cutout: (Int, Int)?
            if case .none = icon {
                cutout = nil
            } else {
                let start = (size - cutoutSize) / 2
                cutout = (start, start + cutoutSize - 1)
            }
            func valueAt(x: Int, y: Int) -> Bool {
                if x >= 0 && x < size && y >= 0 && y < size {
                    if let cutout = cutout, x > cutout.0 && x < cutout.1 && y > cutout.0 && y < cutout.1 {
                        return false
                    }
                    
                    return data.withUnsafeBytes { bytes -> Bool in
                        if let value = bytes.baseAddress?.advanced(by: y * bytesPerRow + x * 4).assumingMemoryBound(to: UInt8.self).pointee {
                            return value < 255
                        } else {
                            return false
                        }
                    }
                } else {
                    return false
                }
            }
            
            let squareSize = CGSize(width: side, height: side)
            let tmpContext = DrawingContext(size: CGSize(width: squareSize.width * 4.0, height: squareSize.height), scale: arguments.scale ?? 0.0, clear: true)
            tmpContext.withContext { c in
                if let backgroundColor = backgroundColor {
                    c.setFillColor(backgroundColor.cgColor)
                    c.fill(CGRect(origin: CGPoint(), size: squareSize))
                }
                c.setFillColor(color.cgColor)
                
                let outerRadius = squareSize.width / 3.0
                var path = UIBezierPath(roundedRect: CGRect(origin: CGPoint(), size: squareSize), byRoundingCorners: .allCorners, cornerRadii: CGSize(width: outerRadius, height: outerRadius))
                c.addPath(path.cgPath)
                c.fillPath()

                c.fill(CGRect(origin: CGPoint(x: squareSize.width * 2.0, y: 0.0), size: squareSize))
                
                c.fill(CGRect(origin: CGPoint(x: squareSize.width, y: 0.0), size: squareSize))
                if let backgroundColor = backgroundColor {
                    c.setFillColor(backgroundColor.cgColor)
                } else {
                    c.setBlendMode(.clear)
                }
                
                let innerRadius = squareSize.width / 4.0
                path = UIBezierPath(roundedRect: CGRect(origin: CGPoint(x: squareSize.width, y: 0.0), size: squareSize), byRoundingCorners: .allCorners, cornerRadii: CGSize(width: innerRadius, height: innerRadius))
                c.addPath(path.cgPath)
                c.fillPath()
                
                c.fill(CGRect(origin: CGPoint(x: squareSize.width * 3.0, y: 0.0), size: squareSize))
            }
            
            let scaledSquareSize = Int(squareSize.width * tmpContext.scale)
            let scaledPadding = Int(padding * tmpContext.scale)
            let halfLen = scaledSquareSize * 4 / 2
            let blockLen = scaledSquareSize * 4 * 2
            
            func drawAt(x: Int, y: Int, fill: Bool, corners: UIRectCorner) {
                if !fill && corners.isEmpty {
                    return
                }
                
                for i in 0 ..< scaledSquareSize {
                    var dst = context.bytes.advanced(by: (scaledPadding + y * scaledSquareSize + i) * context.bytesPerRow + (scaledPadding + x * scaledSquareSize) * 4)
                    let srcOffset = (fill ? 0 : scaledSquareSize * 4)
                    let src = tmpContext.bytes.advanced(by: i * tmpContext.bytesPerRow + srcOffset)
                    
                    if corners.contains(i < scaledSquareSize / 2 ? .topLeft : .bottomLeft) {
                        memcpy(dst, src, halfLen)
                    } else {
                        memcpy(dst, src + blockLen, halfLen)
                    }
                    dst += halfLen
                    if corners.contains(i < scaledSquareSize / 2 ? .topRight : .bottomRight) {
                        memcpy(dst, src + halfLen, halfLen)
                    } else {
                        memcpy(dst, src + blockLen + halfLen, halfLen)
                    }
                }
            }
            
            context.withContext { c in
                if let backgroundColor = backgroundColor {
                    c.setFillColor(backgroundColor.cgColor)
                    c.fill(arguments.drawingRect)
                }
                
                var markerSize: Int = 0
                for i in 1 ..< size {
                    if !valueAt(x: i, y: 1) {
                        markerSize = i - 1
                        break
                    }
                }
                
                for y in 0 ..< size {
                    for x in 0 ..< size {
                        if (y < markerSize + 1 && (x < markerSize + 1 || x > size - markerSize - 2)) || (y > size - markerSize - 2 && x < markerSize + 1) {
                            continue
                        }
                        
                        var corners: UIRectCorner = []
                        if valueAt(x: x, y: y) {
                            corners = .allCorners
                            if valueAt(x: x, y: y - 1) {
                                corners.remove(.topLeft)
                                corners.remove(.topRight)
                            }
                            if valueAt(x: x, y: y + 1) {
                                corners.remove(.bottomLeft)
                                corners.remove(.bottomRight)
                            }
                            if valueAt(x: x - 1, y: y) {
                                corners.remove(.topLeft)
                                corners.remove(.bottomLeft)
                            }
                            if valueAt(x: x + 1, y: y) {
                                corners.remove(.topRight)
                                corners.remove(.bottomRight)
                            }
                            drawAt(x: x, y: y, fill: true, corners: corners)
                        } else {
                            if valueAt(x: x - 1, y: y - 1) && valueAt(x: x - 1, y: y) && valueAt(x: x, y: y - 1) {
                                corners.insert(.topLeft)
                            }
                            if valueAt(x: x + 1, y: y - 1) && valueAt(x: x + 1, y: y) && valueAt(x: x, y: y - 1) {
                                corners.insert(.topRight)
                            }
                            if valueAt(x: x - 1, y: y + 1) && valueAt(x: x - 1, y: y) && valueAt(x: x, y: y + 1) {
                                corners.insert(.bottomLeft)
                            }
                            if valueAt(x: x + 1, y: y + 1) && valueAt(x: x + 1, y: y) && valueAt(x: x, y: y + 1) {
                                corners.insert(.bottomRight)
                            }
                            drawAt(x: x, y: y, fill: false, corners: corners)
                        }
                    }
                }
                
                c.translateBy(x: padding, y: padding)
                
                c.setLineWidth(squareSize.width)
                c.setStrokeColor(color.cgColor)
                c.setFillColor(color.cgColor)
                
                let markerSide = floorToContextPixels(CGFloat(markerSize - 1) * squareSize.width * 1.05, scale: arguments.scale)
                
                func drawMarker(x: CGFloat, y: CGFloat) {
                    var path = UIBezierPath(roundedRect: CGRect(x: x + squareSize.width / 2.0, y: y + squareSize.width / 2.0, width: markerSide, height: markerSide), cornerRadius: markerSide / 3.5)
                    c.addPath(path.cgPath)
                    c.strokePath()
                    
                    let dotSide = markerSide - squareSize.width * 3.0
                    path = UIBezierPath(roundedRect: CGRect(x: x + squareSize.width * 2.0, y: y + squareSize.height * 2.0, width: dotSide, height: dotSide), cornerRadius: dotSide / 3.5)
                    c.addPath(path.cgPath)
                    c.fillPath()
                }
                
                drawMarker(x: squareSize.width, y: squareSize.height)
                drawMarker(x: CGFloat(size - 2) * squareSize.width - markerSide, y: squareSize.height)
                drawMarker(x: squareSize.width, y: CGFloat(size - 2) * squareSize.height - markerSide)
                
                c.translateBy(x: -padding, y: -padding)
                

                switch icon {
                case .proxy:
                    let iconScale = clipRect.size.width * 0.01111
                    let iconSize = CGSize(width: 65.0 * iconScale, height: 79.0 * iconScale)
                    let point = CGPoint(x: fittedRect.midX - iconSize.width / 2.0, y: fittedRect.midY - iconSize.height / 2.0)
                    c.translateBy(x: point.x, y: point.y)
                    c.scaleBy(x: iconScale, y: iconScale)
                    c.setFillColor(color.cgColor)
                    let _ = try? drawSvgPath(c, path: "M0.0,40 C0,20.3664202 20.1230605,0.0 32.5,0.0 C44.8769395,0.0 65,20.3664202 65,40 C65,47.217934 65,55.5505326 65,64.9977957 L32.5,79 L0.0,64.9977957 C0.0,55.0825772 0.0,46.7499786 0.0,40 Z")
                    
                    if let backgroundColor = backgroundColor {
                        c.setFillColor(backgroundColor.cgColor)
                    } else {
                        c.setBlendMode(.clear)
                        c.setFillColor(UIColor.clear.cgColor)
                    }
                    let _ = try? drawSvgPath(c, path: "M7.03608247,43.556701 L18.9836689,32.8350515 L32.5,39.871134 L45.8888139,32.8350515 L57.9639175,43.556701 L57.9639175,60.0 L32.5,71.0 L7.03608247,60.0 Z")
                    
                    c.setBlendMode(.normal)
                    c.setFillColor(color.cgColor)
                    let _ = try? drawSvgPath(c, path: "M24.1237113,50.5927835 L40.8762887,50.5927835 L40.8762887,60.9793814 L32.5,64.0928525 L24.1237113,60.9793814 Z")
                case let .custom(image):
                    if let image = image {
                        let fittedSize = image.size.aspectFitted(clipRect.size)
                        let fittedRect = CGRect(origin: CGPoint(x: fittedRect.midX - fittedSize.width / 2.0, y: fittedRect.midY - fittedSize.height / 2.0), size: fittedSize)
                        c.translateBy(x: fittedRect.midX, y: fittedRect.midY)
                        c.scaleBy(x: 1.0, y: -1.0)
                        c.translateBy(x: -fittedRect.midX, y: -fittedRect.midY)
                        c.draw(image.cgImage!, in: fittedRect)
                    }
                    break
                default:
                    break
                }
            }
            
            return context
        })
    }
}
