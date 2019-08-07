import Foundation
import AsyncDisplayKit
import Display
import TelegramPresentationData

private let textFont = Font.regular(17.0)

enum ContextActionNext {
    case none
    case item
    case separator
}

final class ContextActionNode: ASDisplayNode {
    private let action: ContextMenuActionItem
    private let getController: () -> ContextController?
    private let actionSelected: (ContextMenuActionResult) -> Void
    
    private let backgroundNode: ASDisplayNode
    private let highlightedBackgroundNode: ASDisplayNode
    private let separatorNode: ASDisplayNode
    private let textNode: ImmediateTextNode
    private let statusNode: ImmediateTextNode?
    private let iconNode: ASImageNode
    private let buttonNode: HighlightTrackingButtonNode
    
    init(theme: PresentationTheme, action: ContextMenuActionItem, getController: @escaping () -> ContextController?, actionSelected: @escaping (ContextMenuActionResult) -> Void) {
        self.action = action
        self.getController = getController
        self.actionSelected = actionSelected
        
        self.backgroundNode = ASDisplayNode()
        self.backgroundNode.isAccessibilityElement = false
        if theme.chatList.searchBarKeyboardColor == .dark {
            self.backgroundNode.backgroundColor = theme.actionSheet.itemBackgroundColor.withAlphaComponent(0.8)
        } else {
            self.backgroundNode.backgroundColor = UIColor(white: 1.0, alpha: 0.6)
        }
        self.highlightedBackgroundNode = ASDisplayNode()
        self.highlightedBackgroundNode.isAccessibilityElement = false
        if theme.chatList.searchBarKeyboardColor == .dark {
            self.highlightedBackgroundNode.backgroundColor = theme.actionSheet.opaqueItemHighlightedBackgroundColor
        } else {
            self.highlightedBackgroundNode.backgroundColor = UIColor(white: 0.8, alpha: 0.6)
        }
        self.highlightedBackgroundNode.alpha = 0.0
        
        self.separatorNode = ASDisplayNode()
        self.separatorNode.isAccessibilityElement = false
        self.separatorNode.backgroundColor = UIColor(white: 0.0, alpha: 0.1)
        
        self.textNode = ImmediateTextNode()
        self.textNode.isAccessibilityElement = false
        self.textNode.isUserInteractionEnabled = false
        self.textNode.displaysAsynchronously = false
        let textColor: UIColor
        switch action.textColor {
        case .primary:
            textColor = theme.actionSheet.primaryTextColor
        case .destructive:
            textColor = theme.actionSheet.destructiveActionTextColor
        }
        self.textNode.attributedText = NSAttributedString(string: action.text, font: textFont, textColor: textColor)
        
        switch action.textLayout {
        case .singleLine:
            self.textNode.maximumNumberOfLines = 1
            self.statusNode = nil
        case .twoLinesMax:
            self.textNode.maximumNumberOfLines = 2
            self.statusNode = nil
        case let .secondLineWithValue(value):
            self.textNode.maximumNumberOfLines = 1
            let statusNode = ImmediateTextNode()
            statusNode.isAccessibilityElement = false
            statusNode.isUserInteractionEnabled = false
            statusNode.displaysAsynchronously = false
            statusNode.attributedText = NSAttributedString(string: value, font: textFont, textColor: theme.actionSheet.secondaryTextColor)
            statusNode.maximumNumberOfLines = 1
            self.statusNode = statusNode
        }
        
        self.iconNode = ASImageNode()
        self.iconNode.isAccessibilityElement = false
        self.iconNode.displaysAsynchronously = false
        self.iconNode.displayWithoutProcessing = true
        self.iconNode.isUserInteractionEnabled = false
        self.iconNode.image = action.icon(theme)
        
        self.buttonNode = HighlightTrackingButtonNode()
        self.buttonNode.isAccessibilityElement = true
        self.buttonNode.accessibilityLabel = action.text
        
        super.init()
        
        self.addSubnode(self.backgroundNode)
        self.addSubnode(self.highlightedBackgroundNode)
        self.addSubnode(self.textNode)
        self.statusNode.flatMap(self.addSubnode)
        self.addSubnode(self.iconNode)
        self.addSubnode(self.separatorNode)
        self.addSubnode(self.buttonNode)
        
        self.buttonNode.highligthedChanged = { [weak self] highligted in
            guard let strongSelf = self else {
                return
            }
            if highligted {
                strongSelf.highlightedBackgroundNode.alpha = 1.0
            } else {
                strongSelf.highlightedBackgroundNode.alpha = 0.0
                strongSelf.highlightedBackgroundNode.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.3)
            }
        }
        self.buttonNode.addTarget(self, action: #selector(self.buttonPressed), forControlEvents: .touchUpInside)
    }
    
    func updateLayout(constrainedWidth: CGFloat, next: ContextActionNext) -> (CGSize, (CGSize, ContainedViewLayoutTransition) -> Void) {
        let sideInset: CGFloat = 16.0
        let verticalInset: CGFloat = 12.0
        
        let iconSize = self.iconNode.image.flatMap({ $0.size }) ?? CGSize()
        
        let standardIconWidth: CGFloat = 28.0
        var rightTextInset: CGFloat = 0.0
        if !iconSize.width.isZero {
            rightTextInset = max(iconSize.width, standardIconWidth) + sideInset
        }
        
        let textSize = self.textNode.updateLayout(CGSize(width: constrainedWidth - sideInset - rightTextInset, height: .greatestFiniteMagnitude))
        let statusSize = self.statusNode?.updateLayout(CGSize(width: constrainedWidth - sideInset - rightTextInset, height: .greatestFiniteMagnitude)) ?? CGSize()
        
        switch next {
        case .item:
            self.separatorNode.alpha = 1.0
        case .none, .separator:
            self.separatorNode.alpha = 0.0
        }
        
        if !statusSize.width.isZero, let statusNode = self.statusNode {
            let verticalSpacing: CGFloat = 2.0
            let combinedTextHeight = textSize.height + verticalSpacing + statusSize.height
            return (CGSize(width: max(textSize.width, statusSize.width) + sideInset + rightTextInset, height: verticalInset * 2.0 + combinedTextHeight), { size, transition in
                let verticalOrigin = floor((size.height - combinedTextHeight) / 2.0)
                transition.updateFrameAdditive(node: self.textNode, frame: CGRect(origin: CGPoint(x: sideInset, y: verticalOrigin), size: textSize))
                transition.updateFrameAdditive(node: statusNode, frame: CGRect(origin: CGPoint(x: sideInset, y: verticalOrigin + verticalSpacing + textSize.height), size: textSize))
                
                if !iconSize.width.isZero {
                    transition.updateFrameAdditive(node: self.iconNode, frame: CGRect(origin: CGPoint(x: size.width - standardIconWidth + floor((standardIconWidth - iconSize.width) / 2.0), y: floor((size.height - iconSize.height) / 2.0)), size: iconSize))
                }
                
                transition.updateFrame(node: self.backgroundNode, frame: CGRect(origin: CGPoint(x: 0.0, y: 0.0), size: CGSize(width: size.width, height: size.height)))
                transition.updateFrame(node: self.highlightedBackgroundNode, frame: CGRect(origin: CGPoint(x: 0.0, y: 0.0), size: CGSize(width: size.width, height: size.height)))
                transition.updateFrame(node: self.separatorNode, frame: CGRect(origin: CGPoint(x: 0.0, y: size.height - UIScreenPixel), size: CGSize(width: size.width, height: UIScreenPixel)))
                transition.updateFrame(node: self.buttonNode, frame: CGRect(origin: CGPoint(x: 0.0, y: 0.0), size: CGSize(width: size.width, height: size.height)))
            })
        } else {
            return (CGSize(width: textSize.width + sideInset + rightTextInset, height: verticalInset * 2.0 + textSize.height), { size, transition in
                let verticalOrigin = floor((size.height - textSize.height) / 2.0)
                transition.updateFrameAdditive(node: self.textNode, frame: CGRect(origin: CGPoint(x: sideInset, y: verticalOrigin), size: textSize))
                
                if !iconSize.width.isZero {
                    transition.updateFrameAdditive(node: self.iconNode, frame: CGRect(origin: CGPoint(x: size.width - sideInset - standardIconWidth + floor((standardIconWidth - iconSize.width) / 2.0), y: floor((size.height - iconSize.height) / 2.0)), size: iconSize))
                }
                
                transition.updateFrame(node: self.backgroundNode, frame: CGRect(origin: CGPoint(x: 0.0, y: 0.0), size: CGSize(width: size.width, height: size.height)))
                transition.updateFrame(node: self.highlightedBackgroundNode, frame: CGRect(origin: CGPoint(x: 0.0, y: 0.0), size: CGSize(width: size.width, height: size.height)))
                transition.updateFrame(node: self.separatorNode, frame: CGRect(origin: CGPoint(x: 0.0, y: size.height - UIScreenPixel), size: CGSize(width: size.width, height: UIScreenPixel)))
                transition.updateFrame(node: self.buttonNode, frame: CGRect(origin: CGPoint(x: 0.0, y: 0.0), size: CGSize(width: size.width, height: size.height)))
            })
        }
    }
    
    @objc private func buttonPressed() {
        guard let controller = self.getController() else {
            return
        }
        self.action.action(controller, { [weak self] result in
            self?.actionSelected(result)
        })
    }
}
