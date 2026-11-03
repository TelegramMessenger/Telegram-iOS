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
        let alpha: CGFloat
        let blur: Bool
        let containerSize: CGSize
        
        init(rect: CGRect, edge: WallpaperEdgeEffectEdge, alpha: CGFloat, blur: Bool, containerSize: CGSize) {
            self.rect = rect
            self.edge = edge
            self.alpha = alpha
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
        self.containerMaskingNode.layer.allowsGroupOpacity = true
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
                    self.updateImpl(rect: params.rect, edge: params.edge, alpha: params.alpha, blur: params.blur, containerSize: params.containerSize, transition: .immediate)
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
        self.contentNode.contentMode = parentNode.contentNode.contentMode
        self.contentNode.backgroundColor = parentNode.contentNode.backgroundColor
        self.contentNode.alpha = parentNode.contentNode.alpha
        self.contentNode.isHidden = parentNode.contentNode.isHidden
    }
    
    func update(rect: CGRect, edge: WallpaperEdgeEffectEdge, alpha: CGFloat, blur: Bool, containerSize: CGSize, transition: ContainedViewLayoutTransition) {
        let params = Params(rect: rect, edge: edge, alpha: alpha, blur: blur, containerSize: containerSize)
        if self.params != params {
            self.params = params
            self.updateImpl(rect: params.rect, edge: params.edge, alpha: params.alpha, blur: params.blur, containerSize: params.containerSize, transition: transition)
        }
    }
    
    private func updateImpl(rect: CGRect, edge: WallpaperEdgeEffectEdge, alpha: CGFloat, blur: Bool, containerSize: CGSize, transition: ContainedViewLayoutTransition) {
        transition.updateFrame(node: self.containerMaskingNode, frame: CGRect(origin: CGPoint(), size: rect.size))
        transition.updateBounds(node: self.containerNode, bounds: CGRect(origin: CGPoint(x: rect.minX, y: rect.minY), size: rect.size))
        
        if self.maskView.image?.size.height != edge.size {
            self.maskView.image = EdgeEffectView.generateEdgeGradient(baseHeight: edge.size, isInverted: edge.edge == .bottom)
        }
        
        self.containerMaskingNode.alpha = alpha
        
        let maskFrame = CGRect(origin: CGPoint(x: 0.0, y: 0.0), size: rect.size)
        ComponentTransition(transition).setPosition(view: self.maskView, position: maskFrame.center)
        ComponentTransition(transition).setBounds(view: self.maskView, bounds: CGRect(origin: CGPoint(), size: maskFrame.size))
        
        transition.updateFrame(node: self.overlayNode, frame: CGRect(origin: CGPoint(), size: containerSize))
        
        if let gradientNode = self.gradientNode {
            transition.updateFrame(node: gradientNode, frame: CGRect(origin: CGPoint(), size: containerSize))
        }
        transition.updateFrame(layer: self.patternImageLayer, frame: CGRect(origin: CGPoint(x: -rect.minX, y: -rect.minY), size: containerSize))
        
        transition.updateFrame(node: self.contentNode, frame: CGRect(origin: CGPoint(x: 0.0, y: 0.0), size: containerSize))
        
        if blur {
            let blurHeight: CGFloat = max(edge.size, bounds.height - 24.0)
            let blurFrame = CGRect(origin: CGPoint(x: 0.0, y: edge.edge == .bottom ? (bounds.height - blurHeight) : 0.0), size: CGSize(width: bounds.width, height: blurHeight))
            let blurView: VariableBlurView
            if let current = self.blurView {
                blurView = current
            } else {
                blurView = VariableBlurView(maxBlurRadius: 1.0)
                self.view.addSubview(blurView)
                self.blurView = blurView
            }
            blurView.update(
                size: blurFrame.size,
                constantHeight: edge.size,
                isInverted: edge.edge == .bottom,
                gradient: EdgeEffectView.generateEdgeGradientData(baseHeight: edge.size),
                transition: transition
            )
            transition.updateFrame(view: blurView, frame: blurFrame)
        } else if let blurView = self.blurView {
            self.blurView = nil
            blurView.removeFromSuperview()
        }
    }
}
