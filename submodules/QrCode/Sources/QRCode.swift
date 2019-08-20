import Foundation
import UIKit
import CoreImage
import SwiftSignalKit
import Display

public func qrCode(string: String, color: UIColor, backgroundColor: UIColor? = nil, scale: CGFloat = 0.0) -> Signal<(TransformImageArguments) -> DrawingContext?, NoError> {
    return Signal<CIImage, NoError> { subscriber in
        if let data = string.data(using: .isoLatin1, allowLossyConversion: false), let filter = CIFilter(name: "CIQRCodeGenerator") {
            filter.setValue(data, forKey: "inputMessage")
            filter.setValue("M", forKey: "inputCorrectionLevel")
            
            if let output = filter.outputImage {
                subscriber.putNext(output)
            }
        }
        subscriber.putCompletion()
        return EmptyDisposable
    }
    |> map { inputImage in
        return { arguments in
            let context = DrawingContext(size: arguments.drawingSize, scale: scale, clear: true)
            
            let drawingRect = arguments.drawingRect
            let fittedSize = arguments.imageSize.aspectFilled(arguments.boundingSize).fitted(arguments.imageSize)
            let fittedRect = CGRect(origin: CGPoint(x: drawingRect.origin.x + (drawingRect.size.width - fittedSize.width) / 2.0, y: drawingRect.origin.y + (drawingRect.size.height - fittedSize.height) / 2.0), size: fittedSize)
            
            let scale = arguments.drawingRect.size.width / inputImage.extent.width * context.scale
            let transformed = inputImage.transformed(by: CGAffineTransform.init(scaleX: scale, y: scale))
            
            let codeScale = 43.0 / inputImage.extent.width
            
            let invertFilter = CIFilter(name: "CIColorInvert")
            invertFilter?.setValue(transformed, forKey: kCIInputImageKey)
            let alphaFilter = CIFilter(name: "CIMaskToAlpha")
            alphaFilter?.setValue(invertFilter?.outputImage, forKey: kCIInputImageKey)
            
            var image: CGImage?
            let ciContext = CIContext(options: nil)
            if let finalImage = alphaFilter?.outputImage, let cgImage = ciContext.createCGImage(finalImage, from: finalImage.extent) {
                image = cgImage
            }
            
            context.withContext { c in
                if let backgroundColor = backgroundColor {
                    c.setFillColor(backgroundColor.cgColor)
                    c.fill(drawingRect)
                }
                
                c.setBlendMode(.normal)
                if let image = image {
                    c.saveGState()
                    c.translateBy(x: fittedRect.midX, y: fittedRect.midY)
                    c.scaleBy(x: 1.0, y: -1.0)
                    c.translateBy(x: -fittedRect.midX, y: -fittedRect.midY)
                    
                    c.clip(to: fittedRect, mask: image)
                    c.setFillColor(color.cgColor)
                    c.fill(fittedRect)
                    c.restoreGState()
                }
                if let backgroundColor = backgroundColor {
                    c.setFillColor(backgroundColor.cgColor)
                } else {
                    c.setBlendMode(.clear)
                    c.setFillColor(UIColor.clear.cgColor)
                }
                
                let clipSide = 81.0 * fittedRect.width / 267.0 * codeScale
                c.fill(CGRect(x: fittedRect.midX - clipSide / 2.0, y: fittedRect.midY - clipSide / 2.0, width: clipSide, height: clipSide))
                c.setBlendMode(.normal)
                
                let iconScale = fittedRect.width / 308.0 * codeScale
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
            }
            return context
        }
    }
}
