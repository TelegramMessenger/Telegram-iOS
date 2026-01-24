import Foundation
import UIKit
import AsyncDisplayKit
import Display
import GradientBackground
import EdgeEffect
import SwiftSignalKit
import ComponentFlow
import ComponentDisplayAdapters

final class WallpaperEdgeEffectNodeImpl: ASDisplayNode, WallpaperEdgeEffectNode {
    private struct Params: Equatable {
        let rect: CGRect
        let edge: WallpaperEdgeEffectEdge
        let blur: Bool
        let containerSize: CGSize
        
        init(rect: CGRect, edge: WallpaperEdgeEffectEdge, blur: Bool, containerSize: CGSize) {
            self.rect = rect
            self.edge = edge
            self.blur = blur
            self.containerSize = containerSize
        }
    }
    
    private var gradientNode: GradientBackgroundNode.CloneNode?
    private let patternImageLayer: EffectImageLayer.CloneLayer
    private let contentNode: ASDisplayNode
    
    private let containerNode: ASDisplayNode
    private let containerMaskingNode: ASDisplayNode
    private let overlayNode: ASDisplayNode
    private let maskView: UIImageView
    
    private var blurView: VariableBlurView?
    
    private weak var parentNode: WallpaperBackgroundNodeImpl?
    private var index: Int?
    private var params: Params?
    
    private var isInverted: Bool = false
    
    init(parentNode: WallpaperBackgroundNodeImpl) {
        self.parentNode = parentNode
        
        if let gradientBackgroundNode = parentNode.gradientBackgroundNode {
            self.gradientNode = GradientBackgroundNode.CloneNode(parentNode: gradientBackgroundNode, isDimmed: false)
        } else {
            self.gradientNode = nil
        }
        
        self.patternImageLayer = EffectImageLayer.CloneLayer(parentLayer: parentNode.patternImageLayer)
        
        self.contentNode = ASDisplayNode()
        
        self.containerNode = ASDisplayNode()
        self.containerNode.anchorPoint = CGPoint()
        self.containerNode.clipsToBounds = true
        
        self.containerMaskingNode = ASDisplayNode()
        self.containerMaskingNode.addSubnode(self.containerNode)
        
        self.overlayNode = ASDisplayNode()
        
        self.maskView = UIImageView()
        
        super.init()
        
        self.containerNode.addSubnode(self.contentNode)
        if let gradientNode = self.gradientNode {
            self.containerNode.addSubnode(gradientNode)
        }
        //self.containerMaskingNode.layer.addSublayer(self.patternImageLayer)
        
        self.addSubnode(self.containerMaskingNode)
        self.containerMaskingNode.view.mask = self.maskView
        
        self.containerNode.addSubnode(self.overlayNode)
        
        self.index = parentNode.edgeEffectNodes.add(Weak(self))
    }
    
    deinit {
        if let index = self.index, let parentNode = self.parentNode {
            parentNode.edgeEffectNodes.remove(index)
        }
    }
    
    func updateGradientNode() {
        if let gradientBackgroundNode = self.parentNode?.gradientBackgroundNode {
            if self.gradientNode == nil {
                let gradientNode = GradientBackgroundNode.CloneNode(parentNode: gradientBackgroundNode, isDimmed: false)
                self.gradientNode = gradientNode
                self.containerNode.insertSubnode(gradientNode, at: 0)
                
                if let params = self.params {
                    self.updateImpl(rect: params.rect, edge: params.edge, blur: params.blur, containerSize: params.containerSize, transition: .immediate)
                }
            }
        } else {
            if let gradientNode = self.gradientNode {
                self.gradientNode = nil
                gradientNode.removeFromSupernode()
            }
        }
    }
    
    func updatePattern(isInverted: Bool) {
        if self.isInverted != isInverted {
            self.isInverted = isInverted
            
            self.overlayNode.backgroundColor = isInverted ? .black : .clear
        }
    }
    
    func updateContents() {
        guard let parentNode = self.parentNode else {
            return
        }
        self.contentNode.contents = parentNode.contentNode.contents
        self.contentNode.backgroundColor = parentNode.contentNode.backgroundColor
        self.contentNode.alpha = parentNode.contentNode.alpha
        self.contentNode.isHidden = parentNode.contentNode.isHidden
    }
    
    func update(rect: CGRect, edge: WallpaperEdgeEffectEdge, blur: Bool, containerSize: CGSize, transition: ContainedViewLayoutTransition) {
        let params = Params(rect: rect, edge: edge, blur: blur, containerSize: containerSize)
        if self.params != params {
            self.params = params
            self.updateImpl(rect: params.rect, edge: params.edge, blur: params.blur, containerSize: params.containerSize, transition: transition)
        }
    }
    
    private func updateImpl(rect: CGRect, edge: WallpaperEdgeEffectEdge, blur: Bool, containerSize: CGSize, transition: ContainedViewLayoutTransition) {
        transition.updateFrame(node: self.containerMaskingNode, frame: CGRect(origin: CGPoint(), size: rect.size))
        transition.updateBounds(node: self.containerNode, bounds: CGRect(origin: CGPoint(x: rect.minX, y: rect.minY), size: rect.size))
        
        if self.maskView.image?.size.height != edge.size {
            let baseAlpha: CGFloat = 0.8
            let expSteps = 6
            let totalSteps = 18
            let expEndValue: CGFloat = 0.6
            
            var colors: [UIColor] = []
            for i in 0 ..< expSteps {
                let step = CGFloat(i) / CGFloat(expSteps - 1)
                colors.append(UIColor(white: 1.0, alpha: bezierPoint(0.42, 0.0, 0.58, 1.0, step) * expEndValue))
            }
            for i in 0 ..< (totalSteps - expSteps) {
                let step = CGFloat(i) / CGFloat((totalSteps - expSteps) - 1)
                colors.append(UIColor(white: 1.0, alpha: expEndValue * (1.0 - step) + 1.0 * step))
            }
            
            let locations: [CGFloat] = (0 ..< colors.count).map { i in
                return CGFloat(i) / CGFloat(colors.count - 1)
            }
            
            self.maskView.image = generateGradientImage(
                size: CGSize(width: 8.0, height: edge.size),
                colors: colors.map { $0.withMultipliedAlpha(baseAlpha) },
                locations: locations
            )?.stretchableImage(withLeftCapWidth: 0, topCapHeight: Int(edge.size))
        }
        
        let maskFrame = CGRect(origin: CGPoint(x: 0.0, y: 0.0), size: rect.size)
        ComponentTransition(transition).setPosition(view: self.maskView, position: maskFrame.center)
        ComponentTransition(transition).setBounds(view: self.maskView, bounds: CGRect(origin: CGPoint(), size: maskFrame.size))
        if case .top = edge.edge {
            self.maskView.transform = CGAffineTransformMakeScale(1.0, -1.0)
        } else {
            self.maskView.transform = CGAffineTransformIdentity
        }
        
        transition.updateFrame(node: self.overlayNode, frame: CGRect(origin: CGPoint(), size: containerSize))
        
        if let gradientNode = self.gradientNode {
            transition.updateFrame(node: gradientNode, frame: CGRect(origin: CGPoint(), size: containerSize))
        }
        transition.updateFrame(layer: self.patternImageLayer, frame: CGRect(origin: CGPoint(x: -rect.minX, y: -rect.minY), size: containerSize))
        
        transition.updateFrame(node: self.contentNode, frame: CGRect(origin: CGPoint(x: 0.0, y: 0.0), size: containerSize))
        
        if blur {
            let blurView: VariableBlurView
            if let current = self.blurView {
                blurView = current
            } else {
                let gradientMaskLayer = SimpleGradientLayer()
                let baseGradientAlpha: CGFloat = 1.0
                let numSteps = 8
                let firstStep = 1
                let firstLocation = 0.8
                gradientMaskLayer.colors = (0 ..< numSteps).map { i in
                    if i < firstStep {
                        return UIColor(white: 1.0, alpha: 1.0).cgColor
                    } else {
                        let step: CGFloat = CGFloat(i - firstStep) / CGFloat(numSteps - firstStep - 1)
                        let value: CGFloat = 1.0 - bezierPoint(0.42, 0.0, 0.58, 1.0, step)
                        return UIColor(white: 1.0, alpha: baseGradientAlpha * value).cgColor
                    }
                }
                gradientMaskLayer.locations = (0 ..< numSteps).map { i -> NSNumber in
                    if i < firstStep {
                        return 0.0 as NSNumber
                    } else {
                        let step: CGFloat = CGFloat(i - firstStep) / CGFloat(numSteps - firstStep - 1)
                        return (firstLocation + (1.0 - firstLocation) * step) as NSNumber
                    }
                }
                
                blurView = VariableBlurView(gradientMask: self.maskView.image ?? UIImage(), maxBlurRadius: 8.0)
                blurView.layer.mask = gradientMaskLayer
                self.view.insertSubview(blurView, at: 0)
                self.blurView = blurView
            }
            blurView.update(size: bounds.size, transition: transition)
            transition.updateFrame(view: blurView, frame: bounds)
            if let maskLayer = blurView.layer.mask {
                transition.updateFrame(layer: maskLayer, frame: bounds)
                maskLayer.transform = CATransform3DMakeScale(1.0, -1.0, 1.0)
            }
            blurView.transform = self.maskView.transform
        } else if let blurView = self.blurView {
            self.blurView = nil
            blurView.removeFromSuperview()
        }
    }
}
