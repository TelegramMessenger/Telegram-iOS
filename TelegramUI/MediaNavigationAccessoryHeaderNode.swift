import Foundation
import AsyncDisplayKit
import Display

private let closeButtonImage = generateImage(CGSize(width: 12.0, height: 12.0), contextGenerator: { size, context in
    context.clear(CGRect(origin: CGPoint(), size: size))
    context.setStrokeColor(UIColor(0x9099A2).cgColor)
    context.setLineWidth(2.0)
    context.setLineCap(.round)
    context.move(to: CGPoint(x: 1.0, y: 1.0))
    context.addLine(to: CGPoint(x: size.width - 1.0, y: size.height - 1.0))
    context.strokePath()
    context.move(to: CGPoint(x: size.width - 1.0, y: 1.0))
    context.addLine(to: CGPoint(x: 1.0, y: size.height - 1.0))
    context.strokePath()
})

final class MediaNavigationAccessoryHeaderNode: ASDisplayNode {
    private let titleNode: TextNode
    private let subtitleNode: TextNode
    
    private let closeButton: HighlightableButtonNode
    
    var close: (() -> Void)?
    
    override init() {
        self.titleNode = TextNode()
        self.subtitleNode = TextNode()
        
        self.closeButton = HighlightableButtonNode()
        self.closeButton.setImage(closeButtonImage, for: [])
        self.closeButton.hitTestSlop = UIEdgeInsetsMake(-8.0, -8.0, -8.0, -8.0)
        self.closeButton.displaysAsynchronously = false
        
        super.init()
        
        self.addSubnode(self.titleNode)
        self.addSubnode(self.subtitleNode)
        self.addSubnode(self.closeButton)
        
        self.closeButton.addTarget(self, action: #selector(self.closeButtonPressed), forControlEvents: .touchUpInside)
    }
    
    func updateLayout(size: CGSize, transition: ContainedViewLayoutTransition) {
        let closeButtonSize = self.closeButton.measure(CGSize(width: 100.0, height: 100.0))
        transition.updateFrame(node: self.closeButton, frame: CGRect(origin: CGPoint(x: bounds.size.width - 18.0 - closeButtonSize.width, y: 12.0), size: closeButtonSize))
    }
    
    @objc func closeButtonPressed() {
        if let close = self.close {
            close()
        }
    }
}
