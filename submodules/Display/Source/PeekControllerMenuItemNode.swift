import Foundation
import UIKit
import AsyncDisplayKit

public enum PeekControllerMenuItemColor {
    case accent
    case destructive
}

public enum PeekControllerMenuItemFont {
    case `default`
    case bold
}

public struct PeekControllerMenuItem {
    public let title: String
    public let color: PeekControllerMenuItemColor
    public let font: PeekControllerMenuItemFont
    public let action: (ASDisplayNode, CGRect) -> Bool
    
    public init(title: String, color: PeekControllerMenuItemColor, font: PeekControllerMenuItemFont = .default, action: @escaping (ASDisplayNode, CGRect) -> Bool) {
        self.title = title
        self.color = color
        self.font = font
        self.action = action
    }
}

final class PeekControllerMenuItemNode: HighlightTrackingButtonNode {
    private let item: PeekControllerMenuItem
    private let activatedAction: () -> Void
    
    private let separatorNode: ASDisplayNode
    private let highlightedBackgroundNode: ASDisplayNode
    private let textNode: ImmediateTextNode
    
    init(theme: PeekControllerTheme, item: PeekControllerMenuItem, activatedAction: @escaping () -> Void) {
        self.item = item
        self.activatedAction = activatedAction
        
        self.separatorNode = ASDisplayNode()
        self.separatorNode.isLayerBacked = true
        self.separatorNode.backgroundColor = theme.menuItemSeparatorColor
        
        self.highlightedBackgroundNode = ASDisplayNode()
        self.highlightedBackgroundNode.isLayerBacked = true
        self.highlightedBackgroundNode.backgroundColor = theme.menuItemHighligtedColor
        self.highlightedBackgroundNode.alpha = 0.0
        
        self.textNode = ImmediateTextNode()
        self.textNode.isUserInteractionEnabled = false
        self.textNode.displaysAsynchronously = false
        
        let textColor: UIColor
        let textFont: UIFont
        switch item.color {
            case .accent:
                textColor = theme.accentColor
            case .destructive:
                textColor = theme.destructiveColor
        }
        switch item.font {
            case .default:
                textFont = Font.regular(20.0)
            case .bold:
                textFont = Font.medium(20.0)
        }
        self.textNode.attributedText = NSAttributedString(string: item.title, font: textFont, textColor: textColor)
        
        super.init()
        
        self.addSubnode(self.separatorNode)
        self.addSubnode(self.highlightedBackgroundNode)
        self.addSubnode(self.textNode)
        
        self.highligthedChanged = { [weak self] highlighted in
            if let strongSelf = self {
                if highlighted {
                    strongSelf.view.superview?.bringSubviewToFront(strongSelf.view)
                    strongSelf.highlightedBackgroundNode.alpha = 1.0
                } else {
                    strongSelf.highlightedBackgroundNode.alpha = 0.0
                    strongSelf.highlightedBackgroundNode.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.3)
                }
            }
        }
        
        self.addTarget(self, action: #selector(self.buttonPressed), forControlEvents: .touchUpInside)
    }
    
    func updateLayout(width: CGFloat, transition: ContainedViewLayoutTransition) -> CGFloat {
        let height: CGFloat = 57.0
        transition.updateFrame(node: self.highlightedBackgroundNode, frame: CGRect(origin: CGPoint(), size: CGSize(width: width, height: height)))
        transition.updateFrame(node: self.separatorNode, frame: CGRect(origin: CGPoint(x: 0.0, y: height), size: CGSize(width: width, height: UIScreenPixel)))
        
        let textSize = self.textNode.updateLayout(CGSize(width: width - 10.0, height: height))
        transition.updateFrame(node: self.textNode, frame: CGRect(origin: CGPoint(x: floor((width - textSize.width) / 2.0), y: floor((height - textSize.height) / 2.0)), size: textSize))
        
        return height
    }
    
    @objc func buttonPressed() {
        if self.item.action(self, self.bounds) {
            self.activatedAction()
        }
    }
}
