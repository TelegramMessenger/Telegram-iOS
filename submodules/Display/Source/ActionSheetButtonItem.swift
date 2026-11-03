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
        node.requestLayoutUpdate()
    }
}

public class ActionSheetButtonNode: ActionSheetItemNode {
    private let theme: ActionSheetControllerTheme
    
    private let defaultFont: UIFont
    private let boldFont: UIFont
    
    private var item: ActionSheetButtonItem?
    
    private let button: HighlightTrackingButton
    private let label: ImmediateTextNode
    private let accessibilityArea: AccessibilityAreaNode
    
    private var pointerInteraction: PointerInteraction?
        
    override public init(theme: ActionSheetControllerTheme) {
        self.theme = theme
        
        self.defaultFont = Font.regular(floor(theme.baseFontSize * 20.0 / 17.0))
        self.boldFont = Font.medium(floor(theme.baseFontSize * 20.0 / 17.0))
        
        self.button = HighlightTrackingButton()
        self.button.isAccessibilityElement = false
        
        self.label = ImmediateTextNode()
        self.label.isUserInteractionEnabled = false
        self.label.maximumNumberOfLines = 1
        self.label.displaysAsynchronously = false
        self.label.truncationType = .end
        
        self.accessibilityArea = AccessibilityAreaNode()
        
        super.init(theme: theme)
        
        self.view.addSubview(self.button)
        
        self.label.isUserInteractionEnabled = false
        self.addSubnode(self.label)
        
        self.addSubnode(self.accessibilityArea)
        
        self.button.highligthedChanged = { [weak self] highlighted in
            if let strongSelf = self {
                strongSelf.setHighlighted(highlighted, animated: true)
            }
        }
        
        self.button.addTarget(self, action: #selector(self.buttonPressed), for: .touchUpInside)
        self.accessibilityArea.activate = { [weak self] in
            self?.buttonPressed()
            return true
        }
    }
    
    override func setHighlighted(_ highlighted: Bool, animated: Bool) {
        self.highlightedUpdated(highlighted)
        if highlighted {
            self.backgroundNode.backgroundColor = self.theme.itemHighlightedBackgroundColor
        } else {
            if animated {
                UIView.animate(withDuration: 0.3, animations: {
                    self.backgroundNode.backgroundColor = self.theme.itemBackgroundColor
                })
            } else {
                self.backgroundNode.backgroundColor = self.theme.itemBackgroundColor
            }
        }
    }
    
    override func performAction() {
        self.buttonPressed()
    }
    
    public override func didLoad() {
        super.didLoad()
        
        self.pointerInteraction = PointerInteraction(node: self, style: .hover, willEnter: { [weak self] in
            if let strongSelf = self {
                strongSelf.setHighlighted(true, animated: false)
            }
        }, willExit: { [weak self] in
            if let strongSelf = self {
                strongSelf.setHighlighted(false, animated: false)
            }
        })
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
                textFont = Font.regular(floor(theme.baseFontSize * 20.0 / 17.0))
            case .bold:
                textFont = Font.medium(floor(theme.baseFontSize * 20.0 / 17.0))
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
    }
    
    public override func updateLayout(constrainedSize: CGSize, transition: ContainedViewLayoutTransition) -> CGSize {
        let size = CGSize(width: constrainedSize.width, height: 57.0)
        
        self.button.frame = CGRect(origin: CGPoint(), size: size)
        
        let labelSize = self.label.updateLayout(CGSize(width: max(1.0, size.width - 10.0), height: size.height))
        self.label.frame = CGRect(origin: CGPoint(x: floorToScreenPixels((size.width - labelSize.width) / 2.0), y: floorToScreenPixels((size.height - labelSize.height) / 2.0)), size: labelSize)
        self.accessibilityArea.frame = CGRect(origin: CGPoint(), size: size)
        
        self.updateInternalLayout(size, constrainedSize: constrainedSize)
        return size
    }
    
    @objc func buttonPressed() {
        if let item = self.item {
            item.action()
        }
    }
}
