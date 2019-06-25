import Foundation
import UIKit
import AsyncDisplayKit
import Display
import TelegramPresentationData

final class InviteContactsCountPanelNode: ASDisplayNode {
    private let theme: PresentationTheme
    private let action: () -> Void
    
    private let separatorNode: ASDisplayNode
    private let labelNode: ImmediateTextNode
    private let badgeLabel: ImmediateTextNode
    private let badgeBackground: ASImageNode
    private let buttonNode: HighlightableButtonNode
    
    private var validLayout: (CGFloat, CGFloat)?
    
    var badge: String? {
        didSet {
            if self.badge != oldValue {
                if let badge = self.badge {
                    self.badgeLabel.attributedText = NSAttributedString(string: badge, font: Font.regular(14.0), textColor: self.theme.rootController.navigationBar.badgeTextColor, paragraphAlignment: .center)
                }
                
                if let (width, bottomInset) = self.validLayout {
                    let _ = self.updateLayout(width: width, bottomInset: bottomInset, transition: .immediate)
                }
            }
        }
    }
    
    init(theme: PresentationTheme, strings: PresentationStrings, action: @escaping () -> Void) {
        self.theme = theme
        self.action = action
        
        self.separatorNode = ASDisplayNode()
        self.separatorNode.backgroundColor = theme.rootController.navigationBar.separatorColor
        
        self.labelNode = ImmediateTextNode()
        self.badgeLabel = ImmediateTextNode()
        
        self.badgeBackground = ASImageNode()
        self.badgeBackground.isLayerBacked = true
        self.badgeBackground.displaysAsynchronously = false
        self.badgeBackground.displayWithoutProcessing = true
        
        self.badgeBackground.image = generateStretchableFilledCircleImage(diameter: 22.0, color: theme.rootController.navigationBar.accentTextColor)
        
        self.buttonNode = HighlightableButtonNode()
        
        super.init()
        
        self.backgroundColor = theme.rootController.navigationBar.backgroundColor
        
        self.addSubnode(self.labelNode)
        self.labelNode.attributedText = NSAttributedString(string: strings.Contacts_InviteToTelegram, font: Font.regular(17.0), textColor: theme.rootController.navigationBar.accentTextColor)
        
        self.addSubnode(self.badgeBackground)
        self.addSubnode(self.badgeLabel)
        self.addSubnode(self.separatorNode)
        self.addSubnode(self.buttonNode)
        
        self.buttonNode.addTarget(self, action: #selector(self.buttonPressed), forControlEvents: .touchUpInside)
        self.buttonNode.highligthedChanged = { [weak self] highlighted in
            if let strongSelf = self {
                if highlighted {
                    strongSelf.labelNode.layer.removeAnimation(forKey: "opacity")
                    strongSelf.labelNode.alpha = 0.4
                } else {
                    strongSelf.labelNode.alpha = 1.0
                    strongSelf.labelNode.layer.animateAlpha(from: 0.4, to: 1.0, duration: 0.2)
                }
            }
        }
    }
    
    func updateLayout(width: CGFloat, bottomInset: CGFloat, transition: ContainedViewLayoutTransition) -> CGFloat {
        self.validLayout = (width, bottomInset)
        
        let panelHeight: CGFloat = bottomInset + 44.0
        
        let titleSize = self.labelNode.updateLayout(CGSize(width: width, height: 100.0))
        let titleFrame = CGRect(origin: CGPoint(x: floor((width - titleSize.width) / 2.0), y: floor((44.0 - titleSize.height) / 2.0)), size: titleSize)
        transition.updateFrame(node: self.labelNode, frame: titleFrame)
        
        let badgeSize = self.badgeLabel.updateLayout(CGSize(width: 100.0, height: 100.0))
        
        let backgroundSize = CGSize(width: max(22.0, badgeSize.width + 10.0 + 1.0), height: 22.0)
        let backgroundFrame = CGRect(origin: CGPoint(x: titleFrame.maxX + 6.0, y: 11.0), size: backgroundSize)
        
        self.badgeBackground.frame = backgroundFrame
        self.badgeLabel.frame = CGRect(origin: CGPoint(x: floorToScreenPixels(backgroundFrame.midX - badgeSize.width / 2.0), y: backgroundFrame.minY + 3.0), size: badgeSize)
        
        transition.updateFrame(node: self.separatorNode, frame: CGRect(origin: CGPoint(x: 0.0, y: 0.0), size: CGSize(width: width, height: UIScreenPixel)))
        
        self.buttonNode.frame = CGRect(origin: CGPoint(), size: CGSize(width: width, height: 44.0))
        
        return panelHeight
    }
    
    @objc func buttonPressed() {
        self.action()
    }
}
