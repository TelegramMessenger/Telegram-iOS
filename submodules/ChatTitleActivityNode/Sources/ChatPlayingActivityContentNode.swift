import Foundation
import UIKit
import Display
import AsyncDisplayKit
import LegacyComponents

private func interpolate(from: CGFloat, to: CGFloat, value: CGFloat) -> CGFloat {
    return (1.0 - value) * from + value * to
}

private final class ChatPlayingActivityIndicatorNodeParameters: NSObject {
    let color: UIColor
    let progress: CGFloat
    
    init(color: UIColor, progress: CGFloat) {
        self.color = color
        self.progress = progress
    }
}

private class ChatPlayingActivityIndicatorNode: ChatTitleActivityIndicatorNode {
    override var duration: CFTimeInterval {
        return 0.9
    }
    
    override func drawParameters(forAsyncLayer layer: _ASDisplayLayer) -> NSObjectProtocol? {
        if let color = self.color {
            return ChatPlayingActivityIndicatorNodeParameters(color: color, progress: self.progress)
        } else {
            return nil
        }
    }
    
    @objc override class func draw(_ bounds: CGRect, withParameters parameters: Any?, isCancelled: () -> Bool, isRasterizing: Bool) {
        let context = UIGraphicsGetCurrentContext()!
        
        if !isRasterizing {
            context.setBlendMode(.copy)
            context.setFillColor(UIColor.clear.cgColor)
            context.fill(bounds)
        }
        
        guard let parameters = parameters as? ChatPlayingActivityIndicatorNodeParameters else {
            return
        }
        
        let color = parameters.color.withAlphaComponent(parameters.color.alpha * 0.5)
        context.setFillColor(color.cgColor)
        
        let distance: CGFloat = 4.0
        var origin = CGPoint(x: (bounds.size.width - distance * 2.0) / 2.0 + 4.0, y: bounds.size.height / 2.0 + 1.0)
        var radius: CGFloat = 1.0
        
        let dotsProgress = CGFloat(Int(parameters.progress * 100.0) % 50) / 50.0
        let dotsX: CGFloat = 1.5 + origin.x - distance * dotsProgress
        
        context.fillEllipse(in: CGRect(x: dotsX - radius, y: origin.y - radius, width: radius * 2.0, height: radius * 2.0))
        context.fillEllipse(in: CGRect(x: dotsX - radius + distance, y: origin.y - radius, width: radius * 2.0, height: radius * 2.0))
        
        context.setAlpha(dotsProgress)
        context.fillEllipse(in: CGRect(x: dotsX - radius + distance * 2.0, y: origin.y - radius, width: radius * 2.0, height: radius * 2.0))
        context.setAlpha(1.0)
        
        let angle: CGFloat = 42.0 * CGFloat.pi / 180.0
        radius = 3.5
        
        let closing = Int(parameters.progress * 4) % 2 == 1
        var bite = CGFloat(Int(parameters.progress * 100.0) % 25) / 25.0
        if closing {
            bite = 1.0 - bite
        }
        
        var startAngle = interpolate(from: 0.0, to: -angle, value: bite)
        var endAngle = interpolate(from: 0.0, to: angle, value: bite)
        if bite < CGFloat.ulpOfOne {
            startAngle = CGFloat.pi * 2
            endAngle = 0.0
        }
        
        origin.x = radius + 4.5
        
        context.setAlpha(1.0)
        context.setFillColor(parameters.color.cgColor)
        
        context.beginPath()
        context.move(to: origin)
        context.addArc(center: origin, radius: radius, startAngle: startAngle, endAngle: endAngle, clockwise: true)
        context.fillPath()
    }
}

class ChatPlayingActivityContentNode: ChatTitleActivityContentNode {
    private let indicatorNode: ChatPlayingActivityIndicatorNode
    
    init(text: NSAttributedString, color: UIColor) {
        self.indicatorNode = ChatPlayingActivityIndicatorNode(color: color)
        
        super.init(text: text)
        
        self.addSubnode(self.indicatorNode)
    }
    
    override func updateLayout(_ constrainedSize: CGSize, offset: CGFloat, alignment: NSTextAlignment) -> CGSize {
        let size = self.textNode.updateLayout(constrainedSize)
        let indicatorSize = CGSize(width: 24.0, height: 16.0)
        let originX: CGFloat
        if case .center = alignment {
            originX = floorToScreenPixels((indicatorSize.width - size.width) / 2.0)
        } else {
            originX = indicatorSize.width
        }
        self.textNode.frame = CGRect(origin: CGPoint(x: originX, y: 0.0), size: size)
        self.indicatorNode.frame = CGRect(origin: CGPoint(x: self.textNode.frame.minX - indicatorSize.width, y: 0.0), size: indicatorSize)
        return CGSize(width: size.width + indicatorSize.width, height: size.height)
    }
}
