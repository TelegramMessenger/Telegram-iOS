import Foundation
import UIKit
import AsyncDisplayKit
import SwiftSignalKit

private func generateCornerImage(radius: CGFloat, mirror: Bool) -> UIImage? {
    return generateImage(CGSize(width: radius, height: radius), rotatedContext: { size, context in
        context.setFillColor(UIColor.black.cgColor)
        context.fill(CGRect(origin: CGPoint(), size: size))
        context.setBlendMode(.copy)
        context.setFillColor(UIColor.clear.cgColor)
        context.fillEllipse(in: CGRect(origin: CGPoint(x: mirror ? (-radius) : 0.0, y: 0.0), size: CGSize(width: radius * 2.0, height: radius * 2.0)))
    })
}

final class NavigationModalFrame: ASDisplayNode {
    private let dim: ASDisplayNode
    private let topShade: ASDisplayNode
    private let leftShade: ASDisplayNode
    private let rightShade: ASDisplayNode
    private let topLeftCorner: ASImageNode
    private let topRightCorner: ASImageNode
    
    private var currentMaxCornerRadius: CGFloat?
    
    private var progress: CGFloat = 0.0
    private var validLayout: ContainerViewLayout?
    
    init(theme: NavigationControllerTheme) {
        self.dim = ASDisplayNode()
        self.dim.backgroundColor = UIColor(white: 0.0, alpha: 0.4)
        self.dim.alpha = 0.0
        
        self.topShade = ASDisplayNode()
        self.topShade.backgroundColor = .black
        self.leftShade = ASDisplayNode()
        self.leftShade.backgroundColor = .black
        self.rightShade = ASDisplayNode()
        self.rightShade.backgroundColor = .black
        
        self.topLeftCorner = ASImageNode()
        self.topLeftCorner.displaysAsynchronously = false
        self.topLeftCorner.displayWithoutProcessing = true
        self.topRightCorner = ASImageNode()
        self.topRightCorner.displaysAsynchronously = false
        self.topRightCorner.displayWithoutProcessing = true
        
        super.init()
        
        self.addSubnode(self.dim)
        self.addSubnode(self.topShade)
        self.addSubnode(self.leftShade)
        self.addSubnode(self.rightShade)
        self.addSubnode(self.topLeftCorner)
        self.addSubnode(self.topRightCorner)
    }
    
    func update(layout: ContainerViewLayout, transition: ContainedViewLayoutTransition) {
        self.validLayout = layout
        
        transition.updateFrame(node: self.dim, frame: CGRect(origin: CGPoint(), size: layout.size))
        
        self.updateShades(layout: layout, progress: 1.0 - self.progress, transition: transition)
    }
    
    func animateIn(transition: ContainedViewLayoutTransition) {
        transition.updateAlpha(node: self.dim, alpha: 1.0)
        
        if let layout = self.validLayout {
            self.updateShades(layout: layout, progress: 0.0, transition: .immediate)
            self.updateShades(layout: layout, progress: 1.0, transition: transition)
        }
    }
    
    func updateDismissal(transition: ContainedViewLayoutTransition, progress: CGFloat, completion: @escaping () -> Void) {
        self.progress = progress
        
        transition.updateAlpha(node: self.dim, alpha: 1.0 - progress, completion: { _ in
            completion()
        })
        if let layout = self.validLayout {
            self.updateShades(layout: layout, progress: 1.0 - progress, transition: transition)
        }
    }
    
    private func updateShades(layout: ContainerViewLayout, progress: CGFloat, transition: ContainedViewLayoutTransition) {
        let sideInset: CGFloat = 16.0
        var topInset: CGFloat = 0.0
        if let statusBarHeight = layout.statusBarHeight {
            topInset += statusBarHeight
        }
        
        let cornerRadius: CGFloat = 8.0
        let initialCornerRadius: CGFloat
        if !layout.safeInsets.top.isZero {
            initialCornerRadius = 40.0
        } else {
            initialCornerRadius = 0.0
        }
        if self.currentMaxCornerRadius != cornerRadius {
            self.topLeftCorner.image = generateCornerImage(radius: max(initialCornerRadius, cornerRadius), mirror: false)
            self.topRightCorner.image = generateCornerImage(radius: max(initialCornerRadius, cornerRadius), mirror: true)
        }
        
        let cornerSize = progress * cornerRadius + (1.0 - progress) * initialCornerRadius
        transition.updateFrame(node: self.topLeftCorner, frame: CGRect(origin: CGPoint(x: progress * sideInset, y: progress * topInset), size: CGSize(width: cornerSize, height: cornerSize)))
        transition.updateFrame(node: self.topRightCorner, frame: CGRect(origin: CGPoint(x: layout.size.width - progress * sideInset - cornerSize, y: progress * topInset), size: CGSize(width: cornerSize, height: cornerSize)))
        
        transition.updateFrame(node: self.topShade, frame: CGRect(origin: CGPoint(x: 0.0, y: (1.0 - progress) * (-topInset)), size: CGSize(width: layout.size.width, height: topInset)))
        transition.updateFrame(node: self.leftShade, frame: CGRect(origin: CGPoint(x: (1.0 - progress) * (-sideInset), y: 0.0), size: CGSize(width: sideInset, height: layout.size.height)))
        transition.updateFrame(node: self.rightShade, frame: CGRect(origin: CGPoint(x: layout.size.width - sideInset * progress, y: 0.0), size: CGSize(width: sideInset, height: layout.size.height)))
    }
}
