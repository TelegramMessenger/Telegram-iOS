import Foundation
import AsyncDisplayKit

final private class ContextMenuActionButton: HighlightTrackingButton {
    override func convert(_ point: CGPoint, from view: UIView?) -> CGPoint {
        if view is UIWindow {
            return super.convert(point, from: nil)
        } else {
            return super.convert(point, from: view)
        }
    }
}

final class ContextMenuActionNode: ASDisplayNode {
    private let textNode: ASTextNode?
    private let iconNode: ASImageNode?
    private let action: () -> Void
    private let button: ContextMenuActionButton
    
    var dismiss: (() -> Void)?
    
    init(action: ContextMenuAction) {
        switch action.content {
            case let .text(title):
                let textNode = ASTextNode()
                textNode.isLayerBacked = true
                textNode.displaysAsynchronously = false
                textNode.attributedText = NSAttributedString(string: title, font: Font.regular(14.0), textColor: UIColor.white)
                
                self.textNode = textNode
                self.iconNode = nil
            case let .icon(image):
                let iconNode = ASImageNode()
                iconNode.displaysAsynchronously = false
                iconNode.displayWithoutProcessing = true
                iconNode.image = image
                
                self.iconNode = iconNode
                self.textNode = nil
        }
        self.action = action.action
        
        self.button = ContextMenuActionButton()
        
        super.init()
        
        self.backgroundColor = UIColor(white: 0.0, alpha: 0.8)
        if let textNode = self.textNode {
            self.addSubnode(textNode)
        }
        if let iconNode = self.iconNode {
            self.addSubnode(iconNode)
        }
        
        self.button.highligthedChanged = { [weak self] highlighted in
            self?.backgroundColor = highlighted ? UIColor(white: 0.0, alpha: 0.4) : UIColor(white: 0.0, alpha: 0.8)
        }
        self.view.addSubview(self.button)
    }
    
    override func didLoad() {
        super.didLoad()
        
        self.button.addTarget(self, action: #selector(self.buttonPressed), for: [.touchUpInside])
    }
    
    @objc private func buttonPressed() {
        self.backgroundColor = UIColor(white: 0.0, alpha: 0.4)
        
        self.action()
        if let dismiss = self.dismiss {
            dismiss()
        }
    }
    
    override func calculateSizeThatFits(_ constrainedSize: CGSize) -> CGSize {
        if let textNode = self.textNode {
            let textSize = textNode.measure(constrainedSize)
            return CGSize(width: textSize.width + 36.0, height: 54.0)
        } else if let iconNode = self.iconNode, let image = iconNode.image {
            return CGSize(width: image.size.width + 36.0, height: 54.0)
        } else {
            return CGSize(width: 36.0, height: 54.0)
        }
    }
    
    override func layout() {
        super.layout()
        
        self.button.frame = self.bounds
        if let textNode = self.textNode {
            textNode.frame = CGRect(origin: CGPoint(x: floor((self.bounds.size.width - textNode.calculatedSize.width) / 2.0), y: floor((self.bounds.size.height - textNode.calculatedSize.height) / 2.0)), size: textNode.calculatedSize)
        }
        if let iconNode = self.iconNode, let image = iconNode.image {
            let iconSize = image.size
            iconNode.frame = CGRect(origin: CGPoint(x: floor((self.bounds.size.width - iconSize.width) / 2.0), y: floor((self.bounds.size.height - iconSize.height) / 2.0)), size: iconSize)
        }
    }
}
