import Foundation
import UIKit
import AsyncDisplayKit
import SwiftSignalKit

private enum CornerType {
    case topLeft
    case topRight
    case bottomLeft
    case bottomRight
}

private func generateCornerImage(radius: CGFloat, type: CornerType) -> UIImage? {
    return generateImage(CGSize(width: radius, height: radius), rotatedContext: { size, context in
        context.setFillColor(UIColor.black.cgColor)
        context.fill(CGRect(origin: CGPoint(), size: size))
        context.setBlendMode(.copy)
        context.setFillColor(UIColor.clear.cgColor)
        
        UIGraphicsPushContext(context)
        let origin: CGPoint
        switch type {
        case .topLeft:
            origin = CGPoint()
        case .topRight:
            origin = CGPoint(x: -radius, y: 0.0)
        case .bottomLeft:
            origin = CGPoint(x: 0.0, y: -radius)
        case .bottomRight:
            origin = CGPoint(x: -radius, y: -radius)
        }
        UIBezierPath(roundedRect: CGRect(origin: origin, size: CGSize(width: radius * 2.0, height: radius * 2.0)), cornerRadius: radius).fill()
        UIGraphicsPopContext()
    })
}

public final class NavigationModalFrame: ASDisplayNode {
    private let topShade: ASDisplayNode
    private let leftShade: ASDisplayNode
    private let rightShade: ASDisplayNode
    private let bottomShade: ASDisplayNode
    private let topLeftCorner: ASImageNode
    private let topRightCorner: ASImageNode
    private let bottomLeftCorner: ASImageNode
    private let bottomRightCorner: ASImageNode
    
    private var currentCornerImageRadii: CornerRadii?
    
    private var progress: CGFloat = 1.0
    private var additionalProgress: CGFloat = 0.0
    private var validLayout: ContainerViewLayout?
    
    override public init() {
        self.topShade = ASDisplayNode()
        self.topShade.backgroundColor = .black
        self.leftShade = ASDisplayNode()
        self.leftShade.backgroundColor = .black
        self.rightShade = ASDisplayNode()
        self.rightShade.backgroundColor = .black
        self.bottomShade = ASDisplayNode()
        self.bottomShade.backgroundColor = .black
        
        self.topLeftCorner = ASImageNode()
        self.topLeftCorner.displaysAsynchronously = false
        self.topRightCorner = ASImageNode()
        self.topRightCorner.displaysAsynchronously = false
        self.bottomLeftCorner = ASImageNode()
        self.bottomLeftCorner.displaysAsynchronously = false
        self.bottomRightCorner = ASImageNode()
        self.bottomRightCorner.displaysAsynchronously = false
        
        super.init()
        
        self.addSubnode(self.topShade)
        self.addSubnode(self.leftShade)
        self.addSubnode(self.rightShade)
        self.addSubnode(self.bottomShade)
        self.addSubnode(self.topLeftCorner)
        self.addSubnode(self.topRightCorner)
        self.addSubnode(self.bottomLeftCorner)
        self.addSubnode(self.bottomRightCorner)
    }
    
    public func update(layout: ContainerViewLayout, transition: ContainedViewLayoutTransition) {
        self.validLayout = layout
        
        self.updateShades(layout: layout, progress: 1.0 - self.progress, additionalProgress: self.additionalProgress, transition: transition, completion: {})
    }
    
    public func updateDismissal(transition: ContainedViewLayoutTransition, progress: CGFloat, additionalProgress: CGFloat, completion: @escaping () -> Void) {
        self.progress = progress
        self.additionalProgress = additionalProgress
        
        if let layout = self.validLayout {
            self.updateShades(layout: layout, progress: 1.0 - progress, additionalProgress: additionalProgress, transition: transition, completion: completion)
        } else {
            completion()
        }
    }
    
    /// Dismisses the frame and removes it. Dismissed, its corners stand on the screen's own, as large as the screen
    /// rounds them; removed then, they would be cut off at once wherever the screen is not rounded quite like them (a
    /// recording is not rounded at all). So they shrink into the screen's corners first, which on the screen stays
    /// inside the corners it rounds.
    public func dismissAndRemove(transition: ContainedViewLayoutTransition) {
        self.updateDismissal(transition: transition, progress: 1.0, additionalProgress: 0.0, completion: { [weak self] in
            guard let self else {
                return
            }
            guard transition.isAnimated, let layout = self.validLayout else {
                self.removeFromSupernode()
                return
            }
            let shrink = ContainedViewLayoutTransition.animated(duration: 0.2, curve: .easeInOut)
            let size = layout.size
            shrink.updateFrame(node: self.topLeftCorner, frame: CGRect(origin: CGPoint(), size: CGSize()), beginWithCurrentState: true)
            shrink.updateFrame(node: self.topRightCorner, frame: CGRect(origin: CGPoint(x: size.width, y: 0.0), size: CGSize()), beginWithCurrentState: true)
            shrink.updateFrame(node: self.bottomLeftCorner, frame: CGRect(origin: CGPoint(x: 0.0, y: size.height), size: CGSize()), beginWithCurrentState: true)
            shrink.updateFrame(node: self.bottomRightCorner, frame: CGRect(origin: CGPoint(x: size.width, y: size.height), size: CGSize()), beginWithCurrentState: true, completion: { [weak self] _ in
                self?.removeFromSupernode()
            })
        })
    }
    
    private func updateShades(layout: ContainerViewLayout, progress: CGFloat, additionalProgress: CGFloat, transition: ContainedViewLayoutTransition, completion: @escaping () -> Void) {
        let sideInset: CGFloat = 16.0
        var topInset: CGFloat = 0.0
        if let statusBarHeight = layout.statusBarHeight {
            topInset += statusBarHeight
        }
        let additionalTopInset: CGFloat = 10.0
        
        let contentScale = (layout.size.width - sideInset * 2.0) / layout.size.width
        let bottomInset: CGFloat = layout.size.height - contentScale * layout.size.height - topInset
        
        let cornerRadius: CGFloat = 38.0
        let initialCornerRadii: CornerRadii
        if case .iPhoneDuo = layout.deviceMetrics {
            // iPhone Duo: the screen is rounded in every posture although the top safe inset can be 0 (folded, the
            // status area is at the side), and the folded screen's corners differ: 8pt on the hinge side, 59pt
            // outside. Each corner starts from its own screen corner.
            initialCornerRadii = layout.screenCornerRadii
        } else if !layout.safeInsets.top.isZero {
            initialCornerRadii = CornerRadii(uniform: layout.deviceMetrics.screenCornerRadius)
        } else {
            initialCornerRadii = CornerRadii(uniform: 0.0)
        }
        let cornerImageRadii = initialCornerRadii.mapRadii { max($0, cornerRadius) }
        if self.currentCornerImageRadii != cornerImageRadii {
            self.currentCornerImageRadii = cornerImageRadii
            self.topLeftCorner.image = generateCornerImage(radius: cornerImageRadii.topLeft, type: .topLeft)
            self.topRightCorner.image = generateCornerImage(radius: cornerImageRadii.topRight, type: .topRight)
            self.bottomLeftCorner.image = generateCornerImage(radius: cornerImageRadii.bottomLeft, type: .bottomLeft)
            self.bottomRightCorner.image = generateCornerImage(radius: cornerImageRadii.bottomRight, type: .bottomRight)
        }
        
        let cornerSizes = initialCornerRadii.mapRadii { progress * cornerRadius + (1.0 - progress) * $0 }
        let cornerSideOffset: CGFloat = progress * sideInset + additionalProgress * sideInset
        let cornerTopOffset: CGFloat = progress * topInset + additionalProgress * additionalTopInset
        let cornerBottomOffset: CGFloat = progress * bottomInset
        transition.updateFrame(node: self.topLeftCorner, frame: CGRect(origin: CGPoint(x: cornerSideOffset, y: cornerTopOffset), size: CGSize(width: cornerSizes.topLeft, height: cornerSizes.topLeft)), beginWithCurrentState: true)
        transition.updateFrame(node: self.topRightCorner, frame: CGRect(origin: CGPoint(x: layout.size.width - cornerSideOffset - cornerSizes.topRight, y: cornerTopOffset), size: CGSize(width: cornerSizes.topRight, height: cornerSizes.topRight)), beginWithCurrentState: true)
        transition.updateFrame(node: self.bottomLeftCorner, frame: CGRect(origin: CGPoint(x: cornerSideOffset, y: layout.size.height - cornerBottomOffset - cornerSizes.bottomLeft), size: CGSize(width: cornerSizes.bottomLeft, height: cornerSizes.bottomLeft)), beginWithCurrentState: true)
        transition.updateFrame(node: self.bottomRightCorner, frame: CGRect(origin: CGPoint(x: layout.size.width - cornerSideOffset - cornerSizes.bottomRight, y: layout.size.height - cornerBottomOffset - cornerSizes.bottomRight), size: CGSize(width: cornerSizes.bottomRight, height: cornerSizes.bottomRight)), beginWithCurrentState: true)
        
        let topShadeOffset: CGFloat = progress * topInset + additionalProgress * additionalTopInset
        let bottomShadeOffset: CGFloat = progress * bottomInset
        let leftShadeOffset: CGFloat = progress * sideInset + additionalProgress * sideInset
        let rightShadeWidth: CGFloat = progress * sideInset + additionalProgress * sideInset
        let rightShadeOffset: CGFloat = layout.size.width - rightShadeWidth
        
        transition.updateFrame(node: self.topShade, frame: CGRect(origin: CGPoint(x: 0.0, y: 0.0), size: CGSize(width: layout.size.width, height: topShadeOffset)), beginWithCurrentState: true)
        transition.updateFrame(node: self.bottomShade, frame: CGRect(origin: CGPoint(x: 0.0, y: layout.size.height - bottomShadeOffset), size: CGSize(width: layout.size.width, height: bottomShadeOffset)))
        transition.updateFrame(node: self.leftShade, frame: CGRect(origin: CGPoint(x: 0.0, y: 0.0), size: CGSize(width: leftShadeOffset, height: layout.size.height)), beginWithCurrentState: true)
        transition.updateFrame(node: self.rightShade, frame: CGRect(origin: CGPoint(x: rightShadeOffset, y: 0.0), size: CGSize(width: rightShadeWidth, height: layout.size.height)), beginWithCurrentState: true, completion: { _ in
            completion()
        })
    }
}
