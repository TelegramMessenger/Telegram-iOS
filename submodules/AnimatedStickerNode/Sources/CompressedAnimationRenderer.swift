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
import MetalImageView

@available(iOS 10.0, *)
final class CompressedAnimationRenderer: ASDisplayNode, AnimationRenderer {
    private final class View: UIView {
        static override var layerClass: AnyClass {
            return MetalImageLayer.self
        }

        init(device: MTLDevice) {
            super.init(frame: CGRect())
            
            (self.layer as! MetalImageLayer).renderer.device = device
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
    
    var currentFrameImage: UIImage? {
        return nil
    }
    
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
            self.renderer.renderIdct(layer: self.layer as! MetalImageLayer, compressedImage: AnimationCompressor.CompressedImageData(data: data), completion: { [weak self] in
                self?.updateHighlightedContentNode()
                completion()
            })
        case .argb:
            self.renderer.renderRgb(layer: self.layer as! MetalImageLayer, width: width, height: height, bytesPerRow: bytesPerRow, data: data, completion: { [weak self] in
                self?.updateHighlightedContentNode()
                completion()
            })
        case .yuva:
            self.renderer.renderYuva(layer: self.layer as! MetalImageLayer, width: width, height: height, data: data, completion: { [weak self] in
                self?.updateHighlightedContentNode()
                completion()
            })
        }
    }
    
    private func updateHighlightedContentNode() {
        guard let highlightedContentNode = self.highlightedContentNode, let highlightedColor = self.highlightedColor else {
            return
        }
        if let contents = self.contents, CFGetTypeID(contents as CFTypeRef) == CGImage.typeID {
            (highlightedContentNode.view as! UIImageView).image = UIImage(cgImage: contents as! CGImage).withRenderingMode(.alwaysTemplate)
        }
        highlightedContentNode.tintColor = highlightedColor
        if self.highlightReplacesContent {
            self.contents = nil
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
