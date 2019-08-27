import Foundation
import UIKit
import AsyncDisplayKit

public enum ActionSheetButtonColor {
    case accent
    case destructive
    case disabled
}


public enum ActionSheetButtonFont {
    case `default`
    case bold
}

public class ActionSheetButtonItem: ActionSheetItem {
    public let title: String
    public let color: ActionSheetButtonColor
    public let font: ActionSheetButtonFont
    public let enabled: Bool
    public let action: () -> Void
    
    public init(title: String, color: ActionSheetButtonColor = .accent, font: ActionSheetButtonFont = .default, enabled: Bool = true, action: @escaping () -> Void) {
        self.title = title
        self.color = color
        self.font = font
        self.enabled = enabled
        self.action = action
    }
    
    public func node(theme: ActionSheetControllerTheme) -> ActionSheetItemNode {
        let node = ActionSheetButtonNode(theme: theme)
        node.setItem(self)
        return node
    }
    
    public func updateNode(_ node: ActionSheetItemNode) {
        guard let node = node as? ActionSheetButtonNode else {
            assertionFailure()
            return
        }
        
        node.setItem(self)
    }
}

public class ActionSheetButtonNode: ActionSheetItemNode {
    private let theme: ActionSheetControllerTheme
    
    public static let defaultFont: UIFont = Font.regular(20.0)
    public static let boldFont: UIFont = Font.medium(20.0)
    
    private var item: ActionSheetButtonItem?
    
    private let button: HighlightTrackingButton
    private let label: ASTextNode
    private let accessibilityArea: AccessibilityAreaNode
    
    override public init(theme: ActionSheetControllerTheme) {
        self.theme = theme
        
        self.button = HighlightTrackingButton()
        self.button.isAccessibilityElement = false
        
        self.label = ASTextNode()
        self.label.isUserInteractionEnabled = false
        self.label.maximumNumberOfLines = 1
        self.label.displaysAsynchronously = false
        self.label.truncationMode = .byTruncatingTail
        
        self.accessibilityArea = AccessibilityAreaNode()
        
        super.init(theme: theme)
        
        self.view.addSubview(self.button)
        
        self.label.isUserInteractionEnabled = false
        self.addSubnode(self.label)
        
        self.addSubnode(self.accessibilityArea)
        
        self.button.highligthedChanged = { [weak self] highlighted in
            if let strongSelf = self {
                if highlighted {
                    strongSelf.backgroundNode.backgroundColor = strongSelf.theme.itemHighlightedBackgroundColor
                } else {
                    UIView.animate(withDuration: 0.3, animations: {
                        strongSelf.backgroundNode.backgroundColor = strongSelf.theme.itemBackgroundColor
                    })
                }
            }
        }
        
        self.button.addTarget(self, action: #selector(self.buttonPressed), for: .touchUpInside)
        self.accessibilityArea.activate = { [weak self] in
            self?.buttonPressed()
            return true
        }
    }
    
    func setItem(_ item: ActionSheetButtonItem) {
        self.item = item
        
        let textColor: UIColor
        let textFont: UIFont
        switch item.color {
            case .accent:
                textColor = self.theme.standardActionTextColor
            case .destructive:
                textColor = self.theme.destructiveActionTextColor
            case .disabled:
                textColor = self.theme.disabledActionTextColor
        }
        switch item.font {
            case .default:
                textFont = ActionSheetButtonNode.defaultFont
            case .bold:
                textFont = ActionSheetButtonNode.boldFont
        }
        self.label.attributedText = NSAttributedString(string: item.title, font: textFont, textColor: textColor)
        self.label.isAccessibilityElement = false
        
        self.button.isEnabled = item.enabled
        
        self.accessibilityArea.accessibilityLabel = item.title
        
        var accessibilityTraits: UIAccessibilityTraits = [.button]
        if !item.enabled {
            accessibilityTraits.insert(.notEnabled)
        }
        self.accessibilityArea.accessibilityTraits = accessibilityTraits
        
        self.setNeedsLayout()
    }
    
    public override func calculateSizeThatFits(_ constrainedSize: CGSize) -> CGSize {
        return CGSize(width: constrainedSize.width, height: 57.0)
    }
    
    public override func layout() {
        super.layout()
        
        let size = self.bounds.size
        
        self.button.frame = CGRect(origin: CGPoint(), size: size)
        
        let labelSize = self.label.measure(CGSize(width: max(1.0, size.width - 10.0), height: size.height))
        self.label.frame = CGRect(origin: CGPoint(x: floorToScreenPixels((size.width - labelSize.width) / 2.0), y: floorToScreenPixels((size.height - labelSize.height) / 2.0)), size: labelSize)
        self.accessibilityArea.frame = CGRect(origin: CGPoint(), size: size)
    }
    
    @objc func buttonPressed() {
        if let item = self.item {
            item.action()
        }
    }
}
