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
        context.move(to: CGPoint(x: position.x + 1.0, y: position.y - 1.0))
        context.addLine(to: CGPoint(x: position.x + 10.0, y: position.y - 10.0))
        context.addLine(to: CGPoint(x: position.x + 19.0, y: position.y - 1.0))
        context.strokePath()
    })
}

private let backgroundImage = generateBackgroundImage()
private let badgeImage = generateStretchableFilledCircleImage(diameter: 18.0, color: UIColor(0x007ee5), backgroundColor: nil)
private let badgeFont = Font.regular(13.0)

class ChatHistoryNavigationButtonNode: ASControlNode {
    private let imageNode: ASImageNode
    private let badgeBackgroundNode: ASImageNode
    private let badgeTextNode: ASTextNode
    
    var tapped: (() -> Void)?
    
    var badge: String = "" {
        didSet {
            if self.badge != oldValue {
                self.layoutBadge()
            }
        }
    }
    
    override init() {
        self.imageNode = ASImageNode()
        self.imageNode.displayWithoutProcessing = true
        self.imageNode.image = backgroundImage
        self.imageNode.isLayerBacked = true
        
        self.badgeBackgroundNode = ASImageNode()
        self.badgeBackgroundNode.isLayerBacked = true
        self.badgeBackgroundNode.displayWithoutProcessing = true
        self.badgeBackgroundNode.displaysAsynchronously = false
        self.badgeBackgroundNode.image = badgeImage
        
        self.badgeTextNode = ASTextNode()
        self.badgeTextNode.maximumNumberOfLines = 1
        self.badgeTextNode.isLayerBacked = true
        self.badgeTextNode.displaysAsynchronously = false
        
        super.init()
        
        self.addSubnode(self.imageNode)
        self.imageNode.frame = CGRect(origin: CGPoint(), size: CGSize(width: 38.0, height: 38.0))
        
        self.addSubnode(self.badgeBackgroundNode)
        self.addSubnode(self.badgeTextNode)
        
        self.frame = CGRect(origin: CGPoint(), size: CGSize(width: 38.0, height: 38.0))
        
        self.addTarget(self, action: #selector(onTap), forControlEvents: .touchUpInside)
    }
    
    @objc func onTap() {
        if let tapped = self.tapped {
            tapped()
        }
    }
    
    private func layoutBadge() {
        if !self.badge.isEmpty {
            self.badgeTextNode.attributedText = NSAttributedString(string: self.badge, font: badgeFont, textColor: .white)
            self.badgeBackgroundNode.isHidden = false
            self.badgeTextNode.isHidden = false
            
            let badgeSize = self.badgeTextNode.measure(CGSize(width: 200.0, height: 100.0))
            let backgroundSize = CGSize(width: max(18.0, badgeSize.width + 10.0 + 1.0), height: 18.0)
            let backgroundFrame = CGRect(origin: CGPoint(x: floor((38.0 - backgroundSize.width) / 2.0), y: -6.0), size: backgroundSize)
            self.badgeBackgroundNode.frame = backgroundFrame
            self.badgeTextNode.frame = CGRect(origin: CGPoint(x: floorToScreenPixels(backgroundFrame.midX - badgeSize.width / 2.0), y: -5.0), size: badgeSize)
        } else {
            self.badgeBackgroundNode.isHidden = true
            self.badgeTextNode.isHidden = true
        }
    }
}
