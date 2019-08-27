import Foundation
import UIKit
import AsyncDisplayKit
import Display

public final class ShareActionButtonNode: HighlightTrackingButtonNode {
    private let badgeLabel: TextNode
    private var badgeText: NSAttributedString?
    private let badgeBackground: ASImageNode
    
    public var badgeBackgroundColor: UIColor {
        didSet {
            self.badgeBackground.image = generateStretchableFilledCircleImage(diameter: 22.0, color: self.badgeBackgroundColor)
        }
    }
    
    public var badgeTextColor: UIColor {
        didSet {
            self.setNeedsLayout()
        }
    }
    
    public var badge: String? {
        didSet {
            if self.badge != oldValue {
                if let badge = self.badge {
                    self.badgeText = NSAttributedString(string: badge, font: Font.regular(14.0), textColor: self.badgeTextColor, paragraphAlignment: .center)
                    self.badgeLabel.isHidden = false
                    self.badgeBackground.isHidden = false
                } else {
                    self.badgeText = nil
                    self.badgeLabel.isHidden = true
                    self.badgeBackground.isHidden = true
                }
                
                self.setNeedsLayout()
            }
        }
    }
    
    public init(badgeBackgroundColor: UIColor, badgeTextColor: UIColor) {
        self.badgeBackgroundColor = badgeBackgroundColor
        self.badgeTextColor = badgeTextColor
        
        self.badgeLabel = TextNode()
        self.badgeLabel.isHidden = true
        self.badgeLabel.isUserInteractionEnabled = false
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
    
    override public func layout() {
        super.layout()
        
        if !self.badgeLabel.isHidden {
            let (badgeLayout, badgeApply) = TextNode.asyncLayout(self.badgeLabel)(TextNodeLayoutArguments(attributedString: self.badgeText, backgroundColor: nil, maximumNumberOfLines: 1, truncationType: .end, constrainedSize: CGSize(width: 100.0, height: 100.0), alignment: .left, lineSpacing: 0.0, cutout: nil, insets: UIEdgeInsets()))
            let _ = badgeApply()
            
            let backgroundSize = CGSize(width: max(22.0, badgeLayout.size.width + 10.0 + 1.0), height: 22.0)
            let backgroundFrame = CGRect(origin: CGPoint(x: self.titleNode.frame.maxX + 6.0, y: self.bounds.size.height - 39.0), size: backgroundSize)
            
            self.badgeBackground.frame = backgroundFrame
            self.badgeLabel.frame = CGRect(origin: CGPoint(x: floorToScreenPixels(backgroundFrame.midX - badgeLayout.size.width / 2.0), y: backgroundFrame.minY + 3.0), size: badgeLayout.size)
        }
    }
}
