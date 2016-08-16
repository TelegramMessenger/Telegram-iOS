import Foundation
import AsyncDisplayKit
import Display

private func generateBackgroundImage() -> UIImage? {
    return generateImage(CGSize(width: 38.0, height: 38.0), contextGenerator: { size, context in
        context.clear(CGRect(origin: CGPoint(), size: size))
        context.setFillColor(UIColor.white.cgColor)
        context.fillEllipse(in: CGRect(origin: CGPoint(x: 0.5, y: 0.5), size: CGSize(width: size.width - 1.0, height: size.height - 1.0)))
        context.setLineWidth(0.5)
        context.setStrokeColor(UIColor(0x000000, 0.15).cgColor)
        context.strokeEllipse(in: CGRect(origin: CGPoint(x: 0.25, y: 0.25), size: CGSize(width: size.width - 0.5, height: size.height - 0.5)))
        context.setStrokeColor(UIColor(0x88888D).cgColor)
        context.setLineWidth(1.5)
        
        let position = CGPoint(x: 9.0 - 0.5, y: 23.0)
        context.moveTo(x: position.x + 1.0, y: position.y - 1.0)
        context.addLineTo(x: position.x + 10.0, y: position.y - 10.0)
        context.addLineTo(x: position.x + 19.0, y: position.y - 1.0)
        context.strokePath()
    })
}

private let backgroundImage = generateBackgroundImage()

class ChatHistoryNavigationButtonNode: ASControlNode {
    private let imageNode: ASImageNode
    
    var tapped: (() -> Void)?
    
    override init() {
        self.imageNode = ASImageNode()
        self.imageNode.displayWithoutProcessing = true
        self.imageNode.image = backgroundImage
        self.imageNode.isLayerBacked = true
        
        super.init()
        
        self.addSubnode(self.imageNode)
        self.imageNode.frame = CGRect(origin: CGPoint(), size: CGSize(width: 38.0, height: 38.0))
        
        self.frame = CGRect(origin: CGPoint(), size: CGSize(width: 38.0, height: 38.0))
        
        self.addTarget(self, action: #selector(onTap), forControlEvents: .touchUpInside)
    }
    
    @objc func onTap() {
        if let tapped = self.tapped {
            tapped()
        }
    }
}
