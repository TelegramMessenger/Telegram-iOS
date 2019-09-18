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
        
        UIGraphicsPushContext(context)
        UIBezierPath(roundedRect: CGRect(origin: CGPoint(x: mirror ? (-radius) : 0.0, y: 0.0), size: CGSize(width: radius * 2.0, height: radius * 2.0)), cornerRadius: radius).fill()
        UIGraphicsPopContext()
    })
}

final class NavigationModalFrame: ASDisplayNode {
    private let topShade: ASDisplayNode
    private let leftShade: ASDisplayNode
    private let rightShade: ASDisplayNode
    private let topLeftCorner: ASImageNode
    private let topRightCorner: ASImageNode
    
    private var currentMaxCornerRadius: CGFloat?
    
    private var progress: CGFloat = 1.0
    private var additionalProgress: CGFloat = 0.0
    private var validLayout: ContainerViewLayout?
    
    init(theme: NavigationControllerTheme) {
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
        
        self.addSubnode(self.topShade)
        self.addSubnode(self.leftShade)
        self.addSubnode(self.rightShade)
        self.addSubnode(self.topLeftCorner)
        self.addSubnode(self.topRightCorner)
    }
    
    func update(layout: ContainerViewLayout, transition: ContainedViewLayoutTransition) {
        self.validLayout = layout
        
        self.updateShades(layout: layout, progress: 1.0 - self.progress, additionalProgress: self.additionalProgress, transition: transition, completion: {})
    }
    
    func updateDismissal(transition: ContainedViewLayoutTransition, progress: CGFloat, additionalProgress: CGFloat, completion: @escaping () -> Void) {
        self.progress = progress
        self.additionalProgress = additionalProgress
        
        if let layout = self.validLayout {
            self.updateShades(layout: layout, progress: 1.0 - progress, additionalProgress: additionalProgress, transition: transition, completion: completion)
        } else {
            completion()
        }
    }
    
    private func updateShades(layout: ContainerViewLayout, progress: CGFloat, additionalProgress: CGFloat, transition: ContainedViewLayoutTransition, completion: @escaping () -> Void) {
        let sideInset: CGFloat = 16.0
        var topInset: CGFloat = 0.0
        if let statusBarHeight = layout.statusBarHeight {
            topInset += statusBarHeight
        }
        let additionalTopInset: CGFloat = 10.0
        
        let cornerRadius: CGFloat = 9.0
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
        let cornerSideOffset: CGFloat = progress * sideInset + additionalProgress * sideInset
        let cornerTopOffset: CGFloat = progress * topInset + additionalProgress * additionalTopInset
        transition.updateFrame(node: self.topLeftCorner, frame: CGRect(origin: CGPoint(x: cornerSideOffset, y: cornerTopOffset), size: CGSize(width: cornerSize, height: cornerSize)))
        transition.updateFrame(node: self.topRightCorner, frame: CGRect(origin: CGPoint(x: layout.size.width - cornerSideOffset - cornerSize, y: cornerTopOffset), size: CGSize(width: cornerSize, height: cornerSize)))
        
        let topShadeOffset: CGFloat = progress * topInset + additionalProgress * additionalTopInset
        let leftShadeOffset: CGFloat = progress * sideInset + additionalProgress * sideInset
        let rightShadeWidth: CGFloat = progress * sideInset + additionalProgress * sideInset
        let rightShadeOffset: CGFloat = layout.size.width - rightShadeWidth
        
        transition.updateFrame(node: self.topShade, frame: CGRect(origin: CGPoint(x: 0.0, y: 0.0), size: CGSize(width: layout.size.width, height: topShadeOffset)))
        transition.updateFrame(node: self.leftShade, frame: CGRect(origin: CGPoint(x: 0.0, y: 0.0), size: CGSize(width: leftShadeOffset, height: layout.size.height)))
        transition.updateFrame(node: self.rightShade, frame: CGRect(origin: CGPoint(x: rightShadeOffset, y: 0.0), size: CGSize(width: rightShadeWidth, height: layout.size.height)), completion: { _ in
            completion()
        })
    }
}
