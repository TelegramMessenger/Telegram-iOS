import Foundation
import UIKit
import AsyncDisplayKit
import Display
import SwiftSignalKit
import YuvConversion
import Accelerate
import AnimationCompression
import Metal
import MetalKit

@available(iOS 10.0, *)
final class CompressedAnimationRenderer: ASDisplayNode, AnimationRenderer {
    private final class View: UIView {
        static override var layerClass: AnyClass {
#if targetEnvironment(simulator)
            if #available(iOS 13.0, *) {
                return CAMetalLayer.self
            } else {
                preconditionFailure()
            }
#else
            return CAMetalLayer.self
#endif
        }

        init(device: MTLDevice) {
            super.init(frame: CGRect())
            
#if targetEnvironment(simulator)
            if #available(iOS 13.0, *) {
                let metalLayer = self.layer as! CAMetalLayer

                metalLayer.device = MTLCreateSystemDefaultDevice()
                metalLayer.pixelFormat = .bgra8Unorm
                metalLayer.framebufferOnly = true
                metalLayer.allowsNextDrawableTimeout = true
            }
#else
            let metalLayer = self.layer as! CAMetalLayer
            
            metalLayer.device = MTLCreateSystemDefaultDevice()
            metalLayer.pixelFormat = .bgra8Unorm
            metalLayer.framebufferOnly = true
            if #available(iOS 11.0, *) {
                metalLayer.allowsNextDrawableTimeout = true
            }
#endif
        }

        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }

        deinit {
        }
    }
    
    private var highlightedContentNode: ASDisplayNode?
    private var highlightedColor: UIColor?
    private var highlightReplacesContent = false
    
    private let renderer: CompressedImageRenderer
    
    override init() {
        self.renderer = CompressedImageRenderer(sharedContext: AnimationCompressor.SharedContext.shared)!
        
        super.init()
        
        self.setViewBlock({
            return View(device: AnimationCompressor.SharedContext.shared.device)
        })
    }
    
    override func didLoad() {
        super.didLoad()
        
        self.layer.isOpaque = false
        self.layer.backgroundColor = nil
    }
        
    func render(queue: Queue, width: Int, height: Int, bytesPerRow: Int, data: Data, type: AnimationRendererFrameType, mulAlpha: Bool, completion: @escaping () -> Void) {
        switch type {
        case .dct:
            self.renderer.renderIdct(metalLayer: self.layer, compressedImage: AnimationCompressor.CompressedImageData(data: data), completion: completion)
        case .argb:
            self.renderer.renderRgb(metalLayer: self.layer, width: width, height: height, bytesPerRow: bytesPerRow, data: data, completion: completion)
        case .yuva:
            self.renderer.renderYuva(metalLayer: self.layer, width: width, height: height, data: data, completion: completion)
        }
        
        /*assert(bytesPerRow > 0)
        queue.async { [weak self] in
            switch type {
            case .dct:
                break
            default:
                return
            }
            
            var image: UIImage?
            
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
                    }
                })
            }
            
            Queue.mainQueue().async {
                guard let strongSelf = self else {
                    return
                }
                strongSelf.contents = image?.cgImage
                strongSelf.updateHighlightedContentNode()
                if strongSelf.highlightedContentNode?.frame != strongSelf.bounds {
                    strongSelf.highlightedContentNode?.frame = strongSelf.bounds
                }
                completion()
            }
        }*/
    }
    
    private func updateHighlightedContentNode() {
        /*guard let highlightedContentNode = self.highlightedContentNode, let highlightedColor = self.highlightedColor else {
            return
        }
        if let contents = self.contents, CFGetTypeID(contents as CFTypeRef) == CGImage.typeID {
            (highlightedContentNode.view as! UIImageView).image = UIImage(cgImage: contents as! CGImage).withRenderingMode(.alwaysTemplate)
        }
        highlightedContentNode.tintColor = highlightedColor
        if self.highlightReplacesContent {
            self.contents = nil
        }*/
    }
            
    func setOverlayColor(_ color: UIColor?, replace: Bool, animated: Bool) {
        /*self.highlightReplacesContent = replace
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
        }*/
    }
}
