import Foundation
import UIKit
import Display
import AsyncDisplayKit
import LegacyComponents

private final class ChatRecordingVoiceActivityIndicatorNodeParameters: NSObject {
    let color: UIColor
    let progress: CGFloat
    
    init(color: UIColor, progress: CGFloat) {
        self.color = color
        self.progress = progress
    }
}

private class ChatRecordingVoiceActivityIndicatorNode: ChatTitleActivityIndicatorNode {
    override var duration: CFTimeInterval {
        return 0.7
    }
    
    override func drawParameters(forAsyncLayer layer: _ASDisplayLayer) -> NSObjectProtocol? {
        if let color = self.color {
            return ChatRecordingVoiceActivityIndicatorNodeParameters(color: color, progress: self.progress)
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
        
        guard let parameters = parameters as? ChatRecordingVoiceActivityIndicatorNodeParameters else {
            return
        }
        
        context.setStrokeColor(parameters.color.cgColor)
        context.setLineCap(.round)
        context.setLineWidth(2.0)
        
        let delta: CGFloat = 5.0
        let origin = CGPoint(x: 3.0, y: bounds.size.height / 2.0 + 1.0)
        let angle = 18.0 * CGFloat.pi / 180.0

        let progress = parameters.progress * delta
        
        var radius = progress
        var alpha = radius / (3.0 * delta)
        alpha = 1.0 - pow(cos(alpha * CGFloat.pi), 50)
        context.setAlpha(alpha)
        
        context.beginPath()
        context.addArc(center: origin, radius: radius, startAngle: -angle, endAngle: angle, clockwise: false)
        context.strokePath()

        radius = progress + delta
        alpha = radius / (3.0 * delta)
        alpha = 1.0 - pow(cos(alpha * CGFloat.pi), 10)
        context.setAlpha(alpha)
        
        context.beginPath()
        context.addArc(center: origin, radius: radius, startAngle: -angle, endAngle: angle, clockwise: false)
        context.strokePath()
        
        radius = progress + delta * 2.0
        alpha = radius / (3.0 * delta)
        alpha = 1.0 - pow(cos(alpha * CGFloat.pi), 10)
        context.setAlpha(alpha)
        
        context.beginPath()
        context.addArc(center: origin, radius: radius, startAngle: -angle, endAngle: angle, clockwise: false)
        context.strokePath()
    }
}

class ChatRecordingVoiceActivityContentNode: ChatTitleActivityContentNode {
    private let indicatorNode: ChatRecordingVoiceActivityIndicatorNode
    
    init(text: NSAttributedString, color: UIColor) {
        self.indicatorNode = ChatRecordingVoiceActivityIndicatorNode(color: color)
        
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
        self.textNode.frame = CGRect(origin: CGPoint(x: originX, y: offset), size: size)
        self.indicatorNode.frame = CGRect(origin: CGPoint(x: self.textNode.frame.minX - indicatorSize.width, y: 0.0), size: indicatorSize)
        return CGSize(width: size.width + indicatorSize.width, height: size.height)
    }
}
