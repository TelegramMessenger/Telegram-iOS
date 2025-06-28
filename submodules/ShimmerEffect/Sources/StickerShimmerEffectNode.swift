import Foundation
import AsyncDisplayKit
import UIKit
import Display
import GenerateStickerPlaceholderImage

public class StickerShimmerEffectNode: ASDisplayNode {
    private var backdropNode: ASDisplayNode?
    private let backgroundNode: ASDisplayNode
    private let effectNode: ShimmerEffectForegroundNode
    private let foregroundNode: ASImageNode
    
    private var maskView: UIImageView?
    
    private var currentData: Data?
    private var currentBackgroundColor: UIColor?
    private var currentForegroundColor: UIColor?
    private var currentShimmeringColor: UIColor?
    private var currentSize = CGSize()
    
    public override init() {
        self.backgroundNode = ASDisplayNode()
        self.effectNode = ShimmerEffectForegroundNode()
        self.foregroundNode = ASImageNode()
        
        super.init()
        
        self.addSubnode(self.backgroundNode)
        self.addSubnode(self.effectNode)
        self.addSubnode(self.foregroundNode)
    }
        
    public var isEmpty: Bool {
        return self.currentData == nil
    }
    
    public func addBackdropNode(_ backdropNode: ASDisplayNode) {
        if let current = self.backdropNode {
            current.removeFromSupernode()
        }
        self.backdropNode = backdropNode
        self.insertSubnode(backdropNode, at: 0)
        
        backdropNode.isHidden = self.effectNode.isHidden
        
        self.effectNode.layer.compositingFilter = "screenBlendMode"
    }
    
    public func updateAbsoluteRect(_ rect: CGRect, within containerSize: CGSize) {
        self.effectNode.updateAbsoluteRect(rect, within: containerSize)
    }
    
    public func update(backgroundColor: UIColor?, foregroundColor: UIColor, shimmeringColor: UIColor, data: Data?, size: CGSize, enableEffect: Bool, imageSize: CGSize = CGSize(width: 512.0, height: 512.0)) {
        if data == nil {
            return
        }
        if self.currentData == data, let currentBackgroundColor = self.currentBackgroundColor, currentBackgroundColor.isEqual(backgroundColor), let currentForegroundColor = self.currentForegroundColor, currentForegroundColor.isEqual(foregroundColor), let currentShimmeringColor = self.currentShimmeringColor, currentShimmeringColor.isEqual(shimmeringColor), self.currentSize == size {
            return
        }
        
        self.currentBackgroundColor = backgroundColor
        self.currentForegroundColor = foregroundColor
        self.currentShimmeringColor = shimmeringColor
        self.currentData = data
        self.currentSize = size
        
        self.backgroundNode.backgroundColor = foregroundColor
        //self.backgroundNode.isHidden = true//!enableEffect
        
        if enableEffect {
            self.effectNode.update(backgroundColor: backgroundColor == nil ? .clear : foregroundColor, foregroundColor: shimmeringColor, horizontal: true, effectSize: nil, globalTimeOffset: true, duration: nil)
        }
        self.effectNode.isHidden = !enableEffect
        self.backdropNode?.isHidden = !enableEffect
        
        let bounds = CGRect(origin: CGPoint(), size: size)
        let image = generateStickerPlaceholderImage(data: data, size: size, imageSize: imageSize, backgroundColor: backgroundColor, foregroundColor: enableEffect ? .black : foregroundColor)
                        
        if backgroundColor == nil && enableEffect {
            self.foregroundNode.image = nil
            
            let maskView: UIImageView
            if let current = self.maskView {
                maskView = current
            } else {
                maskView = UIImageView()
                maskView.frame = bounds
                self.maskView = maskView
                self.view.mask = maskView
            }
            
        } else {
            self.foregroundNode.image = image
            
            if let _ = self.maskView {
                self.view.mask = nil
                self.maskView = nil
            }
        }
        
        self.maskView?.image = image
        
        self.backdropNode?.frame = bounds
        self.backgroundNode.frame = bounds
        self.foregroundNode.frame = bounds
        self.effectNode.frame = bounds
    }
}
