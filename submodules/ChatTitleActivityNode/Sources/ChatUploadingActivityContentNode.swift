import Foundation
import UIKit
import Display
import AsyncDisplayKit
import LegacyComponents

private func interpolate(from: CGFloat, to: CGFloat, value: CGFloat) -> CGFloat {
    return (1.0 - value) * from + value * to
}

private final class ChatUploadingActivityIndicatorNodeParameters: NSObject {
    let color: UIColor
    let progress: CGFloat
    
    init(color: UIColor, progress: CGFloat) {
        self.color = color
        self.progress = progress
    }
}

private class ChatUploadingActivityIndicatorNode: ChatTitleActivityIndicatorNode {
    override var duration: CFTimeInterval {
        return 1.75
    }
    
    override var timingFunction: CAMediaTimingFunction {
        return CAMediaTimingFunction(name: CAMediaTimingFunctionName.easeInEaseOut)
    }
    
    override func drawParameters(forAsyncLayer layer: _ASDisplayLayer) -> NSObjectProtocol? {
        if let color = self.color {
            return ChatUploadingActivityIndicatorNodeParameters(color: color, progress: self.progress)
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
        
        guard let parameters = parameters as? ChatUploadingActivityIndicatorNodeParameters else {
            return
        }
        
        let origin = CGPoint(x: 4.0 + UIScreenPixel, y: 7.0)
        let size = CGSize(width: 13.0, height: 4.0)
        let radius: CGFloat = 1.25
        
        var color = parameters.color.withAlphaComponent(parameters.color.alpha * 0.3)
        context.setFillColor(color.cgColor)
        
        var path = UIBezierPath(roundedRect: CGRect(origin: origin, size: size), cornerRadius: radius)
        path.fill(with: .normal, alpha: 1.0)
        path.addClip()
        
        let progress = interpolate(from: 0.0, to: size.width * 2.0, value: parameters.progress)
        
        color = parameters.color
        context.setFillColor(color.cgColor)
        
        path = UIBezierPath(roundedRect: CGRect(origin: origin.offsetBy(dx: -size.width + progress, dy: 0.0), size: size), cornerRadius: radius)
        path.fill(with: .normal, alpha: 1.0)
    }
}

class ChatUploadingActivityContentNode: ChatTitleActivityContentNode {
    private let indicatorNode: ChatUploadingActivityIndicatorNode
    
    init(text: NSAttributedString, color: UIColor) {
        self.indicatorNode = ChatUploadingActivityIndicatorNode(color: color)
        
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
