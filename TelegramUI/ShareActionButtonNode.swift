import Foundation
import AsyncDisplayKit
import Display

final class ShareActionButtonNode: HighlightTrackingButtonNode {
    private let badgeTextColor: UIColor
    
    private let badgeLabel: ASTextNode
    private let badgeBackground: ASImageNode
    
    var badge: String? {
        didSet {
            if self.badge != oldValue {
                if let badge = self.badge {
                    self.badgeLabel.attributedText = NSAttributedString(string: badge, font: Font.regular(14.0), textColor: self.badgeTextColor, paragraphAlignment: .center)
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
    
    init(badgeBackgroundColor: UIColor, badgeTextColor: UIColor) {
        self.badgeTextColor = badgeTextColor
        
        self.badgeLabel = ASTextNode()
        self.badgeLabel.isHidden = true
        self.badgeLabel.isLayerBacked = true
        self.badgeLabel.displaysAsynchronously = false
        
        self.badgeBackground = ASImageNode()
        self.badgeBackground.isHidden = true
        self.badgeBackground.isLayerBacked = true
        self.badgeBackground.displaysAsynchronously = false
        self.badgeBackground.displayWithoutProcessing = true
        
        self.badgeBackground.image = generateStretchableFilledCircleImage(diameter: 22.0, color: badgeBackgroundColor)
        
        super.init()
        
        self.addSubnode(self.badgeBackground)
        self.addSubnode(self.badgeLabel)
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
