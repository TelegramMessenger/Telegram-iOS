import Foundation
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
        return CAMediaTimingFunction(name: kCAMediaTimingFunctionEaseInEaseOut)
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
        
        let origin = CGPoint(x: 11.0 / 2.0 - 1.0, y: 21.0 / 2.0 + 1.0)
        let size = CGSize(width: 26.0 / 2.0, height: 8.0 / 2.0)
        let radius: CGFloat = 1.25
        
        var dotsColor = parameters.color
        context.setFillColor(dotsColor.cgColor)
        
        var path = UIBezierPath(roundedRect: CGRect(origin: origin, size: size), cornerRadius: radius)
        path.fill(with: .normal, alpha: 1.0)
        
        dotsColor = parameters.color.withAlphaComponent(0.3)
        context.setFillColor(dotsColor.cgColor)
        
        let progress = interpolate(from: 0.0, to: size.width, value: parameters.progress)
        
        dotsColor = parameters.color
        context.setFillColor(dotsColor.cgColor)
        
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
    
    override func updateLayout(_ constrainedSize: CGSize, alignment: NSTextAlignment) -> CGSize {
        let size = self.textNode.updateLayout(constrainedSize)
        let indicatorSize = CGSize(width: 24.0, height: 16.0)
        self.textNode.bounds = CGRect(origin: CGPoint(), size: size)
        if case .center = alignment {
            self.textNode.position = CGPoint(x: indicatorSize.width / 2.0, y: size.height / 2.0)
        } else {
            self.textNode.position = CGPoint(x: indicatorSize.width + size.width / 2.0, y: size.height / 2.0)
        }
        self.indicatorNode.frame = CGRect(origin: CGPoint(x: self.textNode.frame.minX - indicatorSize.width, y: 0.0), size: indicatorSize)
        return CGSize(width: size.width + indicatorSize.width, height: size.height)
    }
}
