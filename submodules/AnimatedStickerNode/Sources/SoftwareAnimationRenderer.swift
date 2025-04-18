import Foundation
import UIKit
import AsyncDisplayKit
import Display
import SwiftSignalKit
import YuvConversion
import Accelerate

final class SoftwareAnimationRenderer: ASDisplayNode, AnimationRenderer {
    private let templateImageSupport: Bool
    
    private var highlightedContentNode: ASDisplayNode?
    private var highlightedColor: UIColor?
    private var highlightReplacesContent = false
    public var renderAsTemplateImage: Bool = false
    
    public private(set) var currentFrameImage: UIImage?
    
    init(templateImageSupport: Bool) {
        self.templateImageSupport = templateImageSupport
        
        super.init()
        
        if templateImageSupport {
            self.setViewBlock({
                return UIImageView()
            })
        }
    }
        
    func render(queue: Queue, width: Int, height: Int, bytesPerRow: Int, data: Data, type: AnimationRendererFrameType, mulAlpha: Bool, completion: @escaping () -> Void, averageColor: ((UIColor) -> Void)?) {
        assert(bytesPerRow > 0)
        let renderAsTemplateImage = self.renderAsTemplateImage
        queue.async { [weak self] in
            switch type {
            case .argb:
                let calculatedBytesPerRow = DeviceGraphicsContextSettings.shared.bytesPerRow(forWidth: Int(width))
                assert(bytesPerRow == calculatedBytesPerRow)
            case .yuva:
                break
            case .dct:
                break
            }
            
            var image: UIImage?
            var averageColorValue: UIColor?
            
            autoreleasepool {
                image = generateImagePixel(CGSize(width: CGFloat(width), height: CGFloat(height)), scale: 1.0, pixelGenerator: { _, pixelData, contextBytesPerRow in
                    switch type {
                    case .yuva:
                        data.withUnsafeBytes { bytes -> Void in
                            guard let baseAddress = bytes.baseAddress else {
                                return
                            }
                            if bytesPerRow <= 0 || height <= 0 || width <= 0 || bytesPerRow * height > bytes.count {
                                assert(false)
                                return
                            }
                            decodeYUVAToRGBA(baseAddress.assumingMemoryBound(to: UInt8.self), pixelData, Int32(width), Int32(height), Int32(contextBytesPerRow))
                        }
                    case .argb:
                        var data = data
                        data.withUnsafeMutableBytes { bytes -> Void in
                            guard let baseAddress = bytes.baseAddress else {
                                return
                            }
                            if mulAlpha {
                                var srcData = vImage_Buffer(data: baseAddress.assumingMemoryBound(to: UInt8.self), height: vImagePixelCount(height), width: vImagePixelCount(width), rowBytes: bytesPerRow)
                                var destData = vImage_Buffer(data: pixelData, height: vImagePixelCount(height), width: vImagePixelCount(width), rowBytes: bytesPerRow)
                                
                                let permuteMap: [UInt8] = [3, 2, 1, 0]
                                vImagePermuteChannels_ARGB8888(&srcData, &destData, permuteMap, vImage_Flags(kvImageDoNotTile))
                                vImagePremultiplyData_ARGB8888(&destData, &destData, vImage_Flags(kvImageDoNotTile))
                                vImagePermuteChannels_ARGB8888(&destData, &destData, permuteMap, vImage_Flags(kvImageDoNotTile))
                            } else {
                                memcpy(pixelData, baseAddress.assumingMemoryBound(to: UInt8.self), bytes.count)
                            }
                        }
                    case .dct:
                        break
                    }
                })
                if renderAsTemplateImage {
                    image = image?.withRenderingMode(.alwaysTemplate)
                }
                
                if averageColor != nil {
                    let blurredWidth = 16
                    let blurredHeight = 16
                    let blurredBytesPerRow = blurredWidth * 4
                    guard let context = DrawingContext(size: CGSize(width: CGFloat(blurredWidth), height: CGFloat(blurredHeight)), scale: 1.0, opaque: true, bytesPerRow: blurredBytesPerRow) else {
                        return
                    }
                    
                    let size = CGSize(width: CGFloat(blurredWidth), height: CGFloat(blurredHeight))
                    
                    if let image, let cgImage = image.cgImage {
                        context.withFlippedContext { c in
                            c.setFillColor(UIColor.white.cgColor)
                            c.fill(CGRect(origin: CGPoint(), size: size))
                            c.draw(cgImage, in: CGRect(origin: CGPoint(x: -size.width / 2.0, y: -size.height / 2.0), size: CGSize(width: size.width * 1.8, height: size.height * 1.8)))
                        }
                    }
                        
                    var destinationBuffer = vImage_Buffer()
                    destinationBuffer.width = UInt(blurredWidth)
                    destinationBuffer.height = UInt(blurredHeight)
                    destinationBuffer.data = context.bytes
                    destinationBuffer.rowBytes = context.bytesPerRow
                    
                    vImageBoxConvolve_ARGB8888(&destinationBuffer,
                                               &destinationBuffer,
                                               nil,
                                               0, 0,
                                               UInt32(15),
                                               UInt32(15),
                                               nil,
                                               vImage_Flags(kvImageTruncateKernel))
                    
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

                    var matrix: [Int16] = satMatrix.map { value in
                        return Int16(value * CGFloat(divisor))
                    }

                    vImageMatrixMultiply_ARGB8888(&destinationBuffer, &destinationBuffer, &matrix, divisor, nil, nil, vImage_Flags(kvImageDoNotTile))
                    
                    context.withFlippedContext { c in
                        c.setFillColor(UIColor.white.withMultipliedAlpha(0.1).cgColor)
                        c.fill(CGRect(origin: CGPoint(), size: size))
                    }
                    
                    var sumR: UInt64 = 0
                    var sumG: UInt64 = 0
                    var sumB: UInt64 = 0
                    var sumA: UInt64 = 0
                    
                    for y in 0 ..< blurredHeight {
                        let row = context.bytes.assumingMemoryBound(to: UInt8.self).advanced(by: y * blurredBytesPerRow)
                        for x in 0 ..< blurredWidth {
                            let pixel = row.advanced(by: x * 4)
                            sumB += UInt64(pixel.advanced(by: 0).pointee)
                            sumG += UInt64(pixel.advanced(by: 1).pointee)
                            sumR += UInt64(pixel.advanced(by: 2).pointee)
                            sumA += UInt64(pixel.advanced(by: 3).pointee)
                        }
                    }
                    sumR /= UInt64(blurredWidth * blurredHeight)
                    sumG /= UInt64(blurredWidth * blurredHeight)
                    sumB /= UInt64(blurredWidth * blurredHeight)
                    sumA /= UInt64(blurredWidth * blurredHeight)
                    sumA = 255
                    
                    averageColorValue = UIColor(red: CGFloat(sumR) / 255.0, green: CGFloat(sumG) / 255.0, blue: CGFloat(sumB) / 255.0, alpha: CGFloat(sumA) / 255.0)
                }
            }
            
            Queue.mainQueue().async {
                guard let strongSelf = self else {
                    return
                }
                strongSelf.currentFrameImage = image
                if strongSelf.templateImageSupport {
                    (strongSelf.view as? UIImageView)?.image = image
                } else {
                    strongSelf.contents = image?.cgImage
                }
                strongSelf.updateHighlightedContentNode()
                if strongSelf.highlightedContentNode?.frame != strongSelf.bounds {
                    strongSelf.highlightedContentNode?.frame = strongSelf.bounds
                }
                completion()
                
                if let averageColor, let averageColorValue {
                    averageColor(averageColorValue)
                }
            }
        }
    }
    
    private func updateHighlightedContentNode() {
        guard let highlightedContentNode = self.highlightedContentNode, let highlightedColor = self.highlightedColor else {
            return
        }
        (highlightedContentNode.view as! UIImageView).image = self.currentFrameImage?.withRenderingMode(.alwaysTemplate)
        highlightedContentNode.tintColor = highlightedColor
        if self.highlightReplacesContent {
            if self.templateImageSupport {
                (self.view as? UIImageView)?.image = nil
            } else {
                self.contents = nil
            }
        }
    }
            
    func setOverlayColor(_ color: UIColor?, replace: Bool, animated: Bool) {
        self.highlightReplacesContent = replace
        var updated = false
        if let current = self.highlightedColor, let color = color {
            updated = !current.isEqual(color)
        } else if (self.highlightedColor != nil) != (color != nil) {
            updated = true
        }
        
        if !updated {
            return
        }
        
        self.highlightedColor = color
        
        if let _ = color {
            if let highlightedContentNode = self.highlightedContentNode {
                highlightedContentNode.alpha = 1.0
            } else {
                let highlightedContentNode = ASDisplayNode(viewBlock: {
                    return UIImageView()
                }, didLoad: nil)
                highlightedContentNode.displaysAsynchronously = false
                
                self.highlightedContentNode = highlightedContentNode
                highlightedContentNode.frame = self.bounds
                self.addSubnode(highlightedContentNode)
            }
            self.updateHighlightedContentNode()
        } else if let highlightedContentNode = self.highlightedContentNode {
            highlightedContentNode.alpha = 0.0
            highlightedContentNode.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.3, completion: { [weak self] completed in
                guard let strongSelf = self, completed else {
                    return
                }
                strongSelf.highlightedContentNode?.removeFromSupernode()
                strongSelf.highlightedContentNode = nil
            })
        }
    }
}
