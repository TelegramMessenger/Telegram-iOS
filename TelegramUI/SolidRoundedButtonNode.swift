import Foundation
import AsyncDisplayKit
import Display

private let textFont: UIFont = Font.regular(16.0)

final class SolidRoundedButtonNode: ASDisplayNode {
    private var theme: AuthorizationTheme
    
    private let buttonBackgroundNode: ASImageNode
    private let buttonNode: HighlightTrackingButtonNode
    private let labelNode: ImmediateTextNode
    
    private let buttonHeight: CGFloat
    private let buttonCornerRadius: CGFloat
    
    var pressed: (() -> Void)?
    var validLayout: CGFloat?
    
    var title: String? {
        didSet {
            if let width = self.validLayout {
                _ = self.updateLayout(width: width, transition: .immediate)
            }
        }
    }
    
    init(title: String? = nil, theme: AuthorizationTheme, height: CGFloat = 48.0, cornerRadius: CGFloat = 24.0) {
        self.theme = theme
        self.buttonHeight = height
        self.buttonCornerRadius = cornerRadius
        self.title = title
        
        self.buttonBackgroundNode = ASImageNode()
        self.buttonBackgroundNode.isLayerBacked = true
        self.buttonBackgroundNode.displayWithoutProcessing = true
        self.buttonBackgroundNode.displaysAsynchronously = false
        self.buttonBackgroundNode.image = generateStretchableFilledCircleImage(radius: cornerRadius, color: theme.accentColor)
        
        self.buttonNode = HighlightTrackingButtonNode()
        
        self.labelNode = ImmediateTextNode()
        self.labelNode.isUserInteractionEnabled = false
        
        super.init()
        
        self.addSubnode(self.buttonBackgroundNode)
        self.addSubnode(self.buttonNode)
        self.addSubnode(self.labelNode)
        
        self.buttonNode.addTarget(self, action: #selector(self.buttonPressed), forControlEvents: .touchUpInside)
        self.buttonNode.highligthedChanged = { [weak self] highlighted in
            if let strongSelf = self {
                if highlighted {
                    strongSelf.buttonBackgroundNode.layer.removeAnimation(forKey: "opacity")
                    strongSelf.buttonBackgroundNode.alpha = 0.55
                } else {
                    strongSelf.buttonBackgroundNode.alpha = 1.0
                    strongSelf.buttonBackgroundNode.layer.animateAlpha(from: 0.55, to: 1.0, duration: 0.2)
                }
            }
        }
    }
    
    func updateLayout(width: CGFloat, transition: ContainedViewLayoutTransition) -> CGFloat {
        self.validLayout = width
        
        let inset: CGFloat = 38.0
        let buttonSize = CGSize(width: width - inset * 2.0, height: self.buttonHeight)
        let buttonFrame = CGRect(origin: CGPoint(x: inset, y: 0.0), size: buttonSize)
        transition.updateFrame(node: self.buttonBackgroundNode, frame: buttonFrame)
        transition.updateFrame(node: self.buttonNode, frame: buttonFrame)
        
        if self.title != self.labelNode.attributedText?.string {
            self.labelNode.attributedText = NSAttributedString(string: self.title ?? "", font: Font.medium(17.0), textColor: self.theme.backgroundColor)
        }
        
        let labelSize = self.labelNode.updateLayout(buttonSize)
        let labelFrame = CGRect(origin: CGPoint(x: buttonFrame.minX + floor((buttonFrame.width - labelSize.width) / 2.0), y: buttonFrame.minY + floor((buttonFrame.height - labelSize.height) / 2.0)), size: labelSize)
        transition.updateFrame(node: self.labelNode, frame: labelFrame)
        
        return buttonSize.height
    }
    
    @objc private func buttonPressed() {
        self.pressed?()
    }
}
