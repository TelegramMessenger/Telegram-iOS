import Foundation
import AsyncDisplayKit

final class ContextMenuActionNode: ASDisplayNode {
    private let textNode: ASTextNode
    private let action: () -> Void
    private let button: HighlightTrackingButton
    
    var dismiss: (() -> Void)?
    
    init(action: ContextMenuAction) {
        self.textNode = ASTextNode()
        switch action.content {
            case let .text(title):
                self.textNode.attributedText = NSAttributedString(string: title, font: Font.regular(14.0), textColor: UIColor.white)
        }
        self.action = action.action
        
        self.button = HighlightTrackingButton()
        
        super.init()
        
        self.backgroundColor = UIColor(white: 0.0, alpha: 0.8)
        self.addSubnode(self.textNode)
        
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
        let textSize = self.textNode.measure(constrainedSize)
        return CGSize(width: textSize.width + 36.0, height: 54.0)
    }
    
    override func layout() {
        super.layout()
        
        self.button.frame = self.bounds
        self.textNode.frame = CGRect(origin: CGPoint(x: floor((self.bounds.size.width - self.textNode.calculatedSize.width) / 2.0), y: floor((self.bounds.size.height - self.textNode.calculatedSize.height) / 2.0)), size: self.textNode.calculatedSize)
    }
}
