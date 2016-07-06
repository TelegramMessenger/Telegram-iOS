import UIKit
import AsyncDisplayKit

public class ActionSheetButtonNode: ActionSheetItemNode {
    public static let defaultFont: UIFont = Font.regular(20.0)
    
    private let action: () -> Void
    
    private let button: HighlightTrackingButton
    private let label: UILabel
    private var calculatedLabelSize: CGSize?
    
    public init(title: AttributedString, action: () -> Void) {
        self.action = action
        
        self.button = HighlightTrackingButton()
        self.label = UILabel()
        
        super.init()
        
        self.view.addSubview(self.button)
        
        self.label.attributedText = title
        self.label.numberOfLines = 1
        self.label.isUserInteractionEnabled = false
        self.view.addSubview(self.label)
        
        self.button.highligthedChanged = { [weak self] highlighted in
            if let strongSelf = self {
                if highlighted {
                    strongSelf.backgroundNode.backgroundColor = ActionSheetItemNode.highlightedBackgroundColor
                } else {
                    UIView.animate(withDuration: 0.3, animations: {
                        strongSelf.backgroundNode.backgroundColor = ActionSheetItemNode.defaultBackgroundColor
                    })
                }
            }
        }
        
        self.button.addTarget(self, action: #selector(self.buttonPressed), for: .touchUpInside)
    }
    
    public override func calculateSizeThatFits(_ constrainedSize: CGSize) -> CGSize {
        self.label.sizeToFit()
        self.calculatedLabelSize = self.label.frame.size
        
        return CGSize(width: constrainedSize.width, height: 57.0)
    }
    
    public override func layout() {
        super.layout()
        
        self.button.frame = CGRect(origin: CGPoint(), size: self.calculatedSize)
        
        if let calculatedLabelSize = self.calculatedLabelSize {
            self.label.frame = CGRect(origin: CGPoint(x: floorToScreenPixels((self.calculatedSize.width - calculatedLabelSize.width) / 2.0), y: floorToScreenPixels((self.calculatedSize.height - calculatedLabelSize.height) / 2.0)), size: calculatedLabelSize)
        }
    }
    
    @objc func buttonPressed() {
        self.action()
    }
}
