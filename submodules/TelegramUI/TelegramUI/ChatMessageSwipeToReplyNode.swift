import Foundation
import UIKit
import Display
import AsyncDisplayKit
import AppBundle

final class ChatMessageSwipeToReplyNode: ASDisplayNode {
    private let backgroundNode: ASImageNode
    
    init(fillColor: UIColor, strokeColor: UIColor, foregroundColor: UIColor) {
        self.backgroundNode = ASImageNode()
        self.backgroundNode.isLayerBacked = true
        self.backgroundNode.image = generateImage(CGSize(width: 33.0, height: 33.0), rotatedContext: { size, context in
            context.clear(CGRect(origin: CGPoint(), size: size))
            context.setFillColor(fillColor.cgColor)
            context.fillEllipse(in: CGRect(origin: CGPoint(), size: size))
            
            let lineWidth: CGFloat = 1.0
            let halfLineWidth = lineWidth / 2.0
            var strokeAlpha: CGFloat = 0.0
            strokeColor.getRed(nil, green: nil, blue: nil, alpha: &strokeAlpha)
            if !strokeAlpha.isZero {
                context.setStrokeColor(strokeColor.cgColor)
                context.setLineWidth(lineWidth)
                context.strokeEllipse(in: CGRect(origin: CGPoint(x: halfLineWidth, y: halfLineWidth), size: CGSize(width: size.width - lineWidth, height: size.width - lineWidth)))
            }
            
            if let image = UIImage(bundleImageName: "Chat/Message/ShareIcon") {
                let imageRect = CGRect(origin: CGPoint(x: floor((size.width - image.size.width) / 2.0), y: floor((size.height - image.size.height) / 2.0)), size: image.size)
                
                context.translateBy(x: imageRect.midX, y: imageRect.midY)
                context.scaleBy(x: -1.0, y: -1.0)
                context.translateBy(x: -imageRect.midX, y: -imageRect.midY)
                context.clip(to: imageRect, mask: image.cgImage!)
                context.setFillColor(foregroundColor.cgColor)
                context.fill(imageRect)
            }
        })
        
        super.init()
        
        self.addSubnode(self.backgroundNode)
        self.backgroundNode.frame = CGRect(origin: CGPoint(), size: CGSize(width: 33.0, height: 33.0))
    }
}
