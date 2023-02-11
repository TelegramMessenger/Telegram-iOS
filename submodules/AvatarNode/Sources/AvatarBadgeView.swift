import Foundation
import UIKit
import Display
import Accelerate

public final class AvatarBadgeView: UIImageView {
    enum OriginalContent: Equatable {
        case color(UIColor)
        case image(UIImage)
        
        static func ==(lhs: OriginalContent, rhs: OriginalContent) -> Bool {
            switch lhs {
            case let .color(color):
                if case .color(color) = rhs {
                    return true
                } else {
                    return false
                }
            case let .image(lhsImage):
                if case let .image(rhsImage) = rhs {
                    return lhsImage === rhsImage
                } else {
                    return false
                }
            }
        }
    }
    
    private struct Parameters: Equatable {
        var size: CGSize
        var text: String
    }
    
    private var originalContent: OriginalContent?
    private var parameters: Parameters?
    private var hasContent: Bool = false
    
    override public init(frame: CGRect) {
        super.init(frame: frame)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    func update(content: OriginalContent) {
        if self.originalContent != content || !self.hasContent {
            self.originalContent = content
            self.update()
        }
    }
    
    public func update(size: CGSize, text: String) {
        let parameters = Parameters(size: size, text: text)
        if self.parameters != parameters || !self.hasContent {
            self.parameters = parameters
            self.update()
        }
    }
    
    private func update() {
        guard let originalContent = self.originalContent, let parameters = self.parameters else {
            return
        }
        
        self.hasContent = true
        
        let blurredWidth = 16
        let blurredHeight = 16
        guard let blurredContext = DrawingContext(size: CGSize(width: CGFloat(blurredWidth), height: CGFloat(blurredHeight)), scale: 1.0, opaque: true) else {
            return
        }
        let blurredSize = CGSize(width: CGFloat(blurredWidth), height: CGFloat(blurredHeight))
        blurredContext.withContext { c in
            switch originalContent {
            case let .color(color):
                c.setFillColor(color.cgColor)
                c.fill(CGRect(origin: CGPoint(), size: blurredSize))
            case let .image(image):
                c.setFillColor(UIColor.black.cgColor)
                c.fill(CGRect(origin: CGPoint(), size: blurredSize))
                
                c.scaleBy(x: blurredSize.width / parameters.size.width, y: blurredSize.height / parameters.size.height)
                let offsetFactor: CGFloat = 1.0 - 0.6
                let imageFrame = CGRect(origin: CGPoint(x: parameters.size.width - image.size.width + offsetFactor * parameters.size.width, y: parameters.size.height - image.size.height + offsetFactor * parameters.size.height), size: image.size)
                
                UIGraphicsPushContext(c)
                image.draw(in: imageFrame)
                UIGraphicsPopContext()
            }
        }
        
        var rSum: Int64 = 0
        var gSum: Int64 = 0
        var bSum: Int64 = 0
        for y in 0 ..< blurredHeight {
            let row = blurredContext.bytes.assumingMemoryBound(to: UInt8.self).advanced(by: y * blurredContext.bytesPerRow)
            for x in 0 ..< blurredWidth {
                let pixel = row.advanced(by: x * 4)
                bSum += Int64(pixel.advanced(by: 0).pointee)
                gSum += Int64(pixel.advanced(by: 1).pointee)
                rSum += Int64(pixel.advanced(by: 2).pointee)
            }
        }
        let colorNorm = CGFloat(blurredWidth * blurredHeight)
        let invColorNorm: CGFloat = 1.0 / (255.0 * colorNorm)
        let aR = CGFloat(rSum) * invColorNorm
        let aG = CGFloat(gSum) * invColorNorm
        let aB = CGFloat(bSum) * invColorNorm
        let luminance: CGFloat = 0.299 * aR + 0.587 * aG + 0.114 * aB
        
        let isLightImage = luminance > 0.9
        
        var brightness: CGFloat = 1.0
        if isLightImage {
            brightness = 0.99
        } else {
            brightness = 0.94
        }
            
        var destinationBuffer = vImage_Buffer()
        destinationBuffer.width = UInt(blurredWidth)
        destinationBuffer.height = UInt(blurredHeight)
        destinationBuffer.data = blurredContext.bytes
        destinationBuffer.rowBytes = blurredContext.bytesPerRow
        
        vImageBoxConvolve_ARGB8888(
            &destinationBuffer,
            &destinationBuffer,
            nil,
            0, 0,
            UInt32(15),
            UInt32(15),
            nil,
            vImage_Flags(kvImageTruncateKernel | kvImageDoNotTile)
        )
        
        let divisor: Int32 = 0x1000

        let rwgt: CGFloat = 0.3086
        let gwgt: CGFloat = 0.6094
        let bwgt: CGFloat = 0.0820

        let adjustSaturation: CGFloat = 1.7

        let a = (1.0 - adjustSaturation) * rwgt + adjustSaturation
        let b = (1.0 - adjustSaturation) * rwgt
        let c = (1.0 - adjustSaturation) * rwgt
        let d = (1.0 - adjustSaturation) * gwgt
        let e = (1.0 - adjustSaturation) * gwgt + adjustSaturation
        let f = (1.0 - adjustSaturation) * gwgt
        let g = (1.0 - adjustSaturation) * bwgt
        let h = (1.0 - adjustSaturation) * bwgt
        let i = (1.0 - adjustSaturation) * bwgt + adjustSaturation

        let satMatrix: [CGFloat] = [
            a, b, c, 0,
            d, e, f, 0,
            g, h, i, 0,
            0, 0, 0, 1
        ]
        
        let brighnessMatrix: [CGFloat] = [
            brightness, 0, 0, 0,
            0, brightness, 0, 0,
            0, 0, brightness, 0,
            0, 0, 0, 1
        ]
        
        func matrixMul(a: [CGFloat], b: [CGFloat], result: inout [CGFloat]) {
            for i in 0 ..< 4 {
                for j in 0 ..< 4 {
                    var sum: CGFloat = 0.0
                    for k in 0 ..< 4 {
                        sum += a[i + k * 4] * b[k + j * 4]
                    }
                    result[i + j * 4] = sum
                }
            }
        }
        
        var resultMatrix = Array<CGFloat>(repeating: 0.0, count: 4 * 4)
        matrixMul(a: satMatrix, b: brighnessMatrix, result: &resultMatrix)

        var matrix: [Int16] = resultMatrix.map { value in
            return Int16(value * CGFloat(divisor))
        }

        vImageMatrixMultiply_ARGB8888(&destinationBuffer, &destinationBuffer, &matrix, divisor, nil, nil, vImage_Flags(kvImageDoNotTile))
        
        guard let blurredImage = blurredContext.generateImage() else {
            return
        }
        
        self.image = generateImage(parameters.size, rotatedContext: { size, context in
            UIGraphicsPushContext(context)
            
            context.clear(CGRect(origin: CGPoint(), size: size))
            
            context.setBlendMode(.copy)
            context.setFillColor(UIColor.black.cgColor)
            context.fillEllipse(in: CGRect(origin: CGPoint(), size: size))
            
            blurredImage.draw(in: CGRect(origin: CGPoint(), size: size), blendMode: .sourceIn, alpha: 1.0)
            
            context.setBlendMode(.normal)
            
            let textColor: UIColor
            if isLightImage {
                textColor = UIColor(white: 0.7, alpha: 1.0)
            } else {
                textColor = .white
            }
            
            var fontSize: CGFloat = floor(parameters.size.height * 0.48)
            while true {
                let string = NSAttributedString(string: parameters.text, font: Font.bold(fontSize), textColor: textColor)
                let stringBounds = string.boundingRect(with: CGSize(width: 100.0, height: 100.0), options: .usesLineFragmentOrigin, context: nil)
                
                if stringBounds.width <= size.width - 5.0 * 2.0 || fontSize <= 2.0 {
                    string.draw(at: CGPoint(x: stringBounds.minX + floorToScreenPixels((size.width - stringBounds.width) / 2.0), y: stringBounds.minY + floorToScreenPixels((size.height - stringBounds.height) / 2.0)))
                    break
                } else {
                    fontSize -= 1.0
                }
            }
            
            let lineWidth: CGFloat = 1.5
            let lineInset: CGFloat = 2.0
            let lineRadius: CGFloat = size.width * 0.5 - lineInset - lineWidth * 0.5
            context.setLineWidth(lineWidth)
            context.setStrokeColor(textColor.cgColor)
            context.setLineCap(.round)
            
            context.addArc(center: CGPoint(x: size.width * 0.5, y: size.height * 0.5), radius: lineRadius, startAngle: CGFloat.pi * 0.5, endAngle: -CGFloat.pi * 0.5, clockwise: false)
            context.strokePath()
            
            let sectionAngle: CGFloat = CGFloat.pi / 11.0
            
            for i in 0 ..< 10 {
                if i % 2 == 0 {
                    continue
                }
                
                let startAngle = CGFloat.pi * 0.5 - CGFloat(i) * sectionAngle - sectionAngle * 0.15
                let endAngle = startAngle - sectionAngle * 0.75
                
                context.addArc(center: CGPoint(x: size.width * 0.5, y: size.height * 0.5), radius: lineRadius, startAngle: startAngle, endAngle: endAngle, clockwise: true)
                context.strokePath()
            }
            
            /*if isLightImage {
                context.setLineWidth(UIScreenPixel)
                context.setStrokeColor(textColor.withMultipliedAlpha(1.0).cgColor)
                context.strokeEllipse(in: CGRect(origin: CGPoint(), size: size).insetBy(dx: UIScreenPixel * 0.5, dy: UIScreenPixel * 0.5))
            }*/
            
            UIGraphicsPopContext()
        })
    }
}
