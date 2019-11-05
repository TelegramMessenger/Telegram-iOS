import Foundation
import UIKit
import AsyncDisplayKit
import Display

enum InstantPageSettingsItemNodeStatus {
    case none
    case sameSection
    case otherSection
}

class InstantPageSettingsItemNode: ASDisplayNode {
    private let topSeparatorNode: ASDisplayNode
    private let bottomSeparatorNode: ASDisplayNode
    private let highlightedBackgroundNode: ASDisplayNode?
    private let highlightButtonNode: HighlightTrackingButtonNode?
    
    init(theme: InstantPageSettingsItemTheme, selectable: Bool) {
        self.topSeparatorNode = ASDisplayNode()
        self.topSeparatorNode.isLayerBacked = true
        self.topSeparatorNode.isHidden = true
        
        self.bottomSeparatorNode = ASDisplayNode()
        self.bottomSeparatorNode.isLayerBacked = true
        self.bottomSeparatorNode.isHidden = true
        
        if selectable {
            let highlightedBackgroundNode = ASDisplayNode()
            highlightedBackgroundNode.isLayerBacked = true
            highlightedBackgroundNode.alpha = 0.0
            self.highlightedBackgroundNode = highlightedBackgroundNode
            self.highlightButtonNode = HighlightTrackingButtonNode()
        } else {
            self.highlightedBackgroundNode = nil
            self.highlightButtonNode = nil
        }
        
        super.init()
        
        self.backgroundColor = theme.itemBackgroundColor
        
        self.addSubnode(self.topSeparatorNode)
        self.addSubnode(self.bottomSeparatorNode)
        if let highlightedBackgroundNode = self.highlightedBackgroundNode {
            self.addSubnode(highlightedBackgroundNode)
        }
        if let highlightButtonNode = self.highlightButtonNode {
            self.addSubnode(highlightButtonNode)
            highlightButtonNode.addTarget(self, action: #selector(self.buttonPressed), forControlEvents: .touchUpInside)
            highlightButtonNode.highligthedChanged = { [weak self] highlighted in
                if let strongSelf = self, let highlightedBackgroundNode = strongSelf.highlightedBackgroundNode {
                    if highlighted {
                        strongSelf.supernode?.view.bringSubviewToFront(strongSelf.view)
                        highlightedBackgroundNode.layer.removeAnimation(forKey: "opacity")
                        highlightedBackgroundNode.alpha = 1.0
                    } else {
                        highlightedBackgroundNode.alpha = 0.0
                        highlightedBackgroundNode.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.2)
                    }
                }
            }
        }
        
        self.updateTheme(theme)
    }
    
    func updateTheme(_ theme: InstantPageSettingsItemTheme) {
        self.backgroundColor = theme.itemBackgroundColor
        self.highlightedBackgroundNode?.backgroundColor = theme.itemHighlightedBackgroundColor
        self.topSeparatorNode.backgroundColor = theme.separatorColor
        self.bottomSeparatorNode.backgroundColor = theme.separatorColor
    }
    
    func updateInternalLayout(width: CGFloat, insets: UIEdgeInsets, previousItem: (InstantPageSettingsItemNodeStatus, InstantPageSettingsItemNode?), nextItem: (InstantPageSettingsItemNodeStatus, InstantPageSettingsItemNode?)) -> (height: CGFloat, separatorInset: CGFloat?) {
        return (44.0 + insets.top + insets.bottom, nil)
    }
    
    final func updateLayout(width: CGFloat, previousItem: (InstantPageSettingsItemNodeStatus, InstantPageSettingsItemNode?), nextItem: (InstantPageSettingsItemNodeStatus, InstantPageSettingsItemNode?)) -> CGFloat {
        let separatorHeight = UIScreenPixel
        
        let separatorInset: CGFloat = 0.0
        var highlightExtension: CGFloat = 0.0
        switch previousItem.0 {
            case .none:
                self.topSeparatorNode.isHidden = true
            case .sameSection:
                self.topSeparatorNode.isHidden = false
            case .otherSection:
                self.topSeparatorNode.isHidden = false
        }
        
        switch nextItem.0 {
            case .none:
                self.bottomSeparatorNode.isHidden = true
            case .sameSection:
                self.bottomSeparatorNode.isHidden = true
                highlightExtension = separatorHeight
            case .otherSection:
                self.bottomSeparatorNode.isHidden = false
        }
        
        let (internalHeight, internalSeparatorInset) = self.updateInternalLayout(width: width, insets: UIEdgeInsets(top: self.topSeparatorNode.isHidden ? 0.0 : separatorHeight, left: 0.0, bottom: self.bottomSeparatorNode.isHidden ? 0.0 : separatorHeight, right: 0.0), previousItem: previousItem, nextItem: nextItem)
        
        let finalSeparatorInset = internalSeparatorInset ?? separatorInset
        
        self.topSeparatorNode.frame = CGRect(origin: CGPoint(x: finalSeparatorInset, y: 0.0), size: CGSize(width: width - finalSeparatorInset, height: separatorHeight))
        
        self.bottomSeparatorNode.frame = CGRect(origin: CGPoint(x: 0.0, y: internalHeight - separatorHeight), size: CGSize(width: width, height: separatorHeight))
        
        if let highlightButtonNode = self.highlightButtonNode {
            highlightButtonNode.frame = CGRect(origin: CGPoint(x: 0.0, y: -highlightExtension), size: CGSize(width: width, height: internalHeight + highlightExtension))
        }
        if let highlightedBackgroundNode = self.highlightedBackgroundNode {
            highlightedBackgroundNode.frame = CGRect(origin: CGPoint(x: 0.0, y: 0.0), size: CGSize(width: width, height: internalHeight + highlightExtension))
        }
        
        return internalHeight
    }
    
    @objc func buttonPressed() {
        self.pressed()
    }
    
    func pressed() {
    }
}
