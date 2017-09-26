import Foundation
import AsyncDisplayKit
import Display

private let badgeBackgroundImage = generateStretchableFilledCircleImage(diameter: 22.0, color: UIColor(rgb: 0x007ee5))

final class ShareActionButtonNode: HighlightTrackingButtonNode {
    private let badgeLabel: ASTextNode
    private let badgeBackground: ASImageNode
    
    var badge: String? {
        didSet {
            if self.badge != oldValue {
                if let badge = self.badge {
                    self.badgeLabel.attributedText = NSAttributedString(string: badge, font: Font.regular(14.0), textColor: .white, paragraphAlignment: .center)
                    self.badgeLabel.isHidden = false
                    self.badgeBackground.isHidden = false
                } else {
                    self.badgeLabel.attributedText = nil
                    self.badgeLabel.isHidden = true
                    self.badgeBackground.isHidden = true
                }
                
                self.setNeedsLayout()
            }
        }
    }
    
    override init() {
        self.badgeLabel = ASTextNode()
        self.badgeLabel.isHidden = true
        self.badgeLabel.isLayerBacked = true
        self.badgeLabel.displaysAsynchronously = false
        
        self.badgeBackground = ASImageNode()
        self.badgeBackground.isHidden = true
        self.badgeBackground.isLayerBacked = true
        self.badgeBackground.displaysAsynchronously = false
        self.badgeBackground.displayWithoutProcessing = true
        
        self.badgeBackground.image = badgeBackgroundImage
        
        super.init()
        
        self.addSubnode(self.badgeBackground)
        self.addSubnode(self.badgeLabel)
        
        /*self.highligthedChanged = { [weak self] value in
            if highlighted {
                strongSelf.backgroundNode.backgroundColor = ActionSheetItemNode.highlightedBackgroundColor
            } else {
                UIView.animate(withDuration: 0.3, animations: {
                    strongSelf.backgroundNode.backgroundColor = ActionSheetItemNode.defaultBackgroundColor
                })
            }
        }*/
    }
    
    override func layout() {
        super.layout()
        
        if !self.badgeLabel.isHidden {
            let badgeSize = self.badgeLabel.measure(CGSize(width: 100.0, height: 100.0))
            
            let backgroundSize = CGSize(width: max(22.0, badgeSize.width + 10.0 + 1.0), height: 22.0)
            let backgroundFrame = CGRect(origin: CGPoint(x: self.titleNode.frame.maxX + 6.0, y: self.bounds.size.height - 38.0), size: backgroundSize)
            
            self.badgeBackground.frame = backgroundFrame
            self.badgeLabel.frame = CGRect(origin: CGPoint(x: floorToScreenPixels(backgroundFrame.midX - badgeSize.width / 2.0), y: backgroundFrame.minY + 2.0), size: badgeSize)
        }
    }
}
