import Foundation
import AsyncDisplayKit
import Display
import TelegramPresentationData

enum ContextActionSibling {
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
    private let textNode: ImmediateTextNode
    private let statusNode: ImmediateTextNode?
    private let iconNode: ASImageNode
    private let buttonNode: HighlightTrackingButtonNode
    
    init(presentationData: PresentationData, action: ContextMenuActionItem, getController: @escaping () -> ContextController?, actionSelected: @escaping (ContextMenuActionResult) -> Void) {
        self.action = action
        self.getController = getController
        self.actionSelected = actionSelected
        
        let textFont = Font.regular(presentationData.listsFontSize.baseDisplaySize)
        
        self.backgroundNode = ASDisplayNode()
        self.backgroundNode.isAccessibilityElement = false
        self.backgroundNode.backgroundColor = presentationData.theme.contextMenu.itemBackgroundColor
        self.highlightedBackgroundNode = ASDisplayNode()
        self.highlightedBackgroundNode.isAccessibilityElement = false
        self.highlightedBackgroundNode.backgroundColor = presentationData.theme.contextMenu.itemHighlightedBackgroundColor
        self.highlightedBackgroundNode.alpha = 0.0
        
        self.textNode = ImmediateTextNode()
        self.textNode.isAccessibilityElement = false
        self.textNode.isUserInteractionEnabled = false
        self.textNode.displaysAsynchronously = false
        let textColor: UIColor
        switch action.textColor {
        case .primary:
            textColor = presentationData.theme.contextMenu.primaryColor
        case .destructive:
            textColor = presentationData.theme.contextMenu.destructiveColor
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
            statusNode.attributedText = NSAttributedString(string: value, font: textFont, textColor: presentationData.theme.contextMenu.secondaryColor)
            statusNode.maximumNumberOfLines = 1
            self.statusNode = statusNode
        }
        
        self.iconNode = ASImageNode()
        self.iconNode.isAccessibilityElement = false
        self.iconNode.displaysAsynchronously = false
        self.iconNode.displayWithoutProcessing = true
        self.iconNode.isUserInteractionEnabled = false
        self.iconNode.image = action.icon(presentationData.theme)
        
        self.buttonNode = HighlightTrackingButtonNode()
        self.buttonNode.isAccessibilityElement = true
        self.buttonNode.accessibilityLabel = action.text
        
        super.init()
        
        self.addSubnode(self.backgroundNode)
        self.addSubnode(self.highlightedBackgroundNode)
        self.addSubnode(self.textNode)
        self.statusNode.flatMap(self.addSubnode)
        self.addSubnode(self.iconNode)
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
    
    func updateLayout(constrainedWidth: CGFloat, previous: ContextActionSibling, next: ContextActionSibling) -> (CGSize, (CGSize, ContainedViewLayoutTransition) -> Void) {
        let sideInset: CGFloat = 16.0
        let iconSideInset: CGFloat = 12.0
        let verticalInset: CGFloat = 12.0
        
        let iconSize = self.iconNode.image.flatMap({ $0.size }) ?? CGSize()
        
        let standardIconWidth: CGFloat = 32.0
        var rightTextInset: CGFloat = sideInset
        if !iconSize.width.isZero {
            rightTextInset = max(iconSize.width, standardIconWidth) + iconSideInset + sideInset
        }
        
        let textSize = self.textNode.updateLayout(CGSize(width: constrainedWidth - sideInset - rightTextInset, height: .greatestFiniteMagnitude))
        let statusSize = self.statusNode?.updateLayout(CGSize(width: constrainedWidth - sideInset - rightTextInset, height: .greatestFiniteMagnitude)) ?? CGSize()
        
        if !statusSize.width.isZero, let statusNode = self.statusNode {
            let verticalSpacing: CGFloat = 2.0
            let combinedTextHeight = textSize.height + verticalSpacing + statusSize.height
            return (CGSize(width: max(textSize.width, statusSize.width) + sideInset + rightTextInset, height: verticalInset * 2.0 + combinedTextHeight), { size, transition in
                let verticalOrigin = floor((size.height - combinedTextHeight) / 2.0)
                transition.updateFrameAdditive(node: self.textNode, frame: CGRect(origin: CGPoint(x: sideInset, y: verticalOrigin), size: textSize))
                transition.updateFrameAdditive(node: statusNode, frame: CGRect(origin: CGPoint(x: sideInset, y: verticalOrigin + verticalSpacing + textSize.height), size: textSize))
                
                if !iconSize.width.isZero {
                    transition.updateFrameAdditive(node: self.iconNode, frame: CGRect(origin: CGPoint(x: size.width - standardIconWidth - iconSideInset + floor((standardIconWidth - iconSize.width) / 2.0), y: floor((size.height - iconSize.height) / 2.0)), size: iconSize))
                }
                
                transition.updateFrame(node: self.backgroundNode, frame: CGRect(origin: CGPoint(x: 0.0, y: 0.0), size: CGSize(width: size.width, height: size.height)))
                transition.updateFrame(node: self.highlightedBackgroundNode, frame: CGRect(origin: CGPoint(x: 0.0, y: 0.0), size: CGSize(width: size.width, height: size.height)))
                transition.updateFrame(node: self.buttonNode, frame: CGRect(origin: CGPoint(x: 0.0, y: 0.0), size: CGSize(width: size.width, height: size.height)))
            })
        } else {
            return (CGSize(width: textSize.width + sideInset + rightTextInset, height: verticalInset * 2.0 + textSize.height), { size, transition in
                let verticalOrigin = floor((size.height - textSize.height) / 2.0)
                transition.updateFrameAdditive(node: self.textNode, frame: CGRect(origin: CGPoint(x: sideInset, y: verticalOrigin), size: textSize))
                
                if !iconSize.width.isZero {
                    transition.updateFrameAdditive(node: self.iconNode, frame: CGRect(origin: CGPoint(x: size.width - standardIconWidth - iconSideInset + floor((standardIconWidth - iconSize.width) / 2.0), y: floor((size.height - iconSize.height) / 2.0)), size: iconSize))
                }
                
                transition.updateFrame(node: self.backgroundNode, frame: CGRect(origin: CGPoint(x: 0.0, y: 0.0), size: CGSize(width: size.width, height: size.height)))
                transition.updateFrame(node: self.highlightedBackgroundNode, frame: CGRect(origin: CGPoint(x: 0.0, y: 0.0), size: CGSize(width: size.width, height: size.height)))
                transition.updateFrame(node: self.buttonNode, frame: CGRect(origin: CGPoint(x: 0.0, y: 0.0), size: CGSize(width: size.width, height: size.height)))
            })
        }
    }
    
    func updateTheme(presentationData: PresentationData) {
        self.backgroundNode.backgroundColor = presentationData.theme.contextMenu.itemBackgroundColor
        self.highlightedBackgroundNode.backgroundColor = presentationData.theme.contextMenu.itemHighlightedBackgroundColor
        
        let textColor: UIColor
        switch action.textColor {
        case .primary:
            textColor = presentationData.theme.contextMenu.primaryColor
        case .destructive:
            textColor = presentationData.theme.contextMenu.destructiveColor
        }
        
        let textFont = Font.regular(presentationData.listsFontSize.baseDisplaySize)
        
        self.textNode.attributedText = NSAttributedString(string: self.action.text, font: textFont, textColor: textColor)
        
        switch self.action.textLayout {
        case let .secondLineWithValue(value):
            self.statusNode?.attributedText = NSAttributedString(string: value, font: textFont, textColor: presentationData.theme.contextMenu.secondaryColor)
        default:
            break
        }
        
        self.iconNode.image = self.action.icon(presentationData.theme)
    }
    
    @objc private func buttonPressed() {
        self.performAction()
    }
    
    func performAction() {
        guard let controller = self.getController() else {
            return
        }
        self.action.action(controller, { [weak self] result in
            self?.actionSelected(result)
        })
    }
    
    func setIsHighlighted(_ value: Bool) {
        if value {
            self.highlightedBackgroundNode.alpha = 1.0
        } else {
            self.highlightedBackgroundNode.alpha = 0.0
        }
    }
}
