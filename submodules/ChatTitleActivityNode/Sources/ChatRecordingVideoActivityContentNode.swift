import Foundation
import UIKit
import Display
import AsyncDisplayKit
import LegacyComponents

private final class ChatRecordingVideoActivityIndicatorNodeParameters: NSObject {
    let color: UIColor
    let progress: CGFloat
    
    init(color: UIColor, progress: CGFloat) {
        self.color = color
        self.progress = progress
    }
}

private class ChatRecordingVideoActivityIndicatorNode: ChatTitleActivityIndicatorNode {
    override var duration: CFTimeInterval {
        return 0.9
    }
    
    override var timingFunction: CAMediaTimingFunction {
        return CAMediaTimingFunction(name: CAMediaTimingFunctionName.easeInEaseOut)
    }
    
    override func drawParameters(forAsyncLayer layer: _ASDisplayLayer) -> NSObjectProtocol? {
        if let color = self.color {
            return ChatRecordingVideoActivityIndicatorNodeParameters(color: color, progress: self.progress)
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
        
        guard let parameters = parameters as? ChatRecordingVideoActivityIndicatorNodeParameters else {
            return
        }
        
        context.setFillColor(parameters.color.cgColor)
       
        var progress = parameters.progress
        if progress < 0.5 {
            progress /= 0.5
        } else {
            progress = (1.0 - progress) / 0.5
        }
        
        let alpha = 1.0 - progress * 0.6
        let radius = 3.5 - progress * 0.66
        
        context.setAlpha(alpha)
        context.fillEllipse(in: CGRect(x: 16.0 - radius, y: 9.0 - radius, width: radius * 2.0, height: radius * 2.0))
    }
}

class ChatRecordingVideoActivityContentNode: ChatTitleActivityContentNode {
    private let indicatorNode: ChatRecordingVideoActivityIndicatorNode
    
    init(text: NSAttributedString, color: UIColor) {
        self.indicatorNode = ChatRecordingVideoActivityIndicatorNode(color: color)
        
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
