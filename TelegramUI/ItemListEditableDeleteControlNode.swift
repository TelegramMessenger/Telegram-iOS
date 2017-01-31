import Foundation
import AsyncDisplayKit
import Display

private let deleteIndicator = generateImage(CGSize(width: 22.0, height: 26.0), contextGenerator: { size, context in
    context.clear(CGRect(origin: CGPoint(), size: size))
    context.setFillColor(UIColor(white: 0.0, alpha: 0.06).cgColor)
    context.fillEllipse(in: CGRect(origin: CGPoint(x: 0.0, y: 0.0), size: CGSize(width: 22.0, height: 22.0)))
    context.setFillColor(UIColor(0xfc2125).cgColor)
    context.fillEllipse(in: CGRect(origin: CGPoint(x: 0.0, y: 2.0), size: CGSize(width: 22.0, height: 22.0)))
    context.setFillColor(UIColor.white.cgColor)
    context.fill(CGRect(origin: CGPoint(x: floorToScreenPixels((size.width - 11.0) / 2.0), y: 2.0 + floorToScreenPixels((size.width - 1.0) / 2.0)), size: CGSize(width: 11.0, height: 1.0)))
})

final class ItemListEditableControlNode: ASDisplayNode {
    var tapped: (() -> Void)?
    private let iconNode: ASImageNode
    
    override init() {
        self.iconNode = ASImageNode()
        self.iconNode.isLayerBacked = true
        
        super.init()
        
        self.addSubnode(self.iconNode)
    }
    
    override func didLoad() {
        super.didLoad()
        
        self.view.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(self.tapGesture(_:))))
    }
    
    static func asyncLayout(_ node: ItemListEditableControlNode?) -> (_ height: CGFloat) -> (CGSize, () -> ItemListEditableControlNode) {
        return { height in
            let image = deleteIndicator
            
            let resultNode: ItemListEditableControlNode
            if let node = node {
                resultNode = node
            } else {
                resultNode = ItemListEditableControlNode()
                resultNode.iconNode.image = image
            }
            
            return (CGSize(width: 38.0, height: height), {
                if let image = image {
                    resultNode.iconNode.frame = CGRect(origin: CGPoint(x: 12.0, y: floor((height - image.size.height) / 2.0)), size: image.size)
                }
                return resultNode
            })
        }
    }
    
    @objc func tapGesture(_ recognizer: UITapGestureRecognizer) {
        if case .ended = recognizer.state {
            self.tapped?()
        }
    }
}
