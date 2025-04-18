import Foundation
import UIKit
import AsyncDisplayKit

public class ActionSheetSwitchItem: ActionSheetItem {
    public let title: String
    public let isOn: Bool
    public let action: (Bool) -> Void
    
    public init(title: String, isOn: Bool, action: @escaping (Bool) -> Void) {
        self.title = title
        self.isOn = isOn
        self.action = action
    }
    
    public func node(theme: ActionSheetControllerTheme) -> ActionSheetItemNode {
        let node = ActionSheetSwitchNode(theme: theme)
        node.setItem(self)
        return node
    }
    
    public func updateNode(_ node: ActionSheetItemNode) {
        guard let node = node as? ActionSheetSwitchNode else {
            assertionFailure()
            return
        }
        
        node.setItem(self)
        node.requestLayoutUpdate()
    }
}

public class ActionSheetSwitchNode: ActionSheetItemNode {
    private let theme: ActionSheetControllerTheme
    
    private var item: ActionSheetSwitchItem?
    
    private let button: HighlightTrackingButton
    private let label: ImmediateTextNode
    private let switchNode: SwitchNode
    
    private let accessibilityArea: AccessibilityAreaNode
    
    override public init(theme: ActionSheetControllerTheme) {
        self.theme = theme
        
        self.button = HighlightTrackingButton()
        self.button.isAccessibilityElement = false
        
        self.label = ImmediateTextNode()
        self.label.isUserInteractionEnabled = false
        self.label.maximumNumberOfLines = 1
        self.label.displaysAsynchronously = false
        self.label.truncationType = .end
        self.label.isAccessibilityElement = false
        
        self.switchNode = SwitchNode()
        self.switchNode.frameColor = theme.switchFrameColor
        self.switchNode.contentColor = theme.switchContentColor
        self.switchNode.handleColor = theme.switchHandleColor
        self.switchNode.isAccessibilityElement = false
        
        self.accessibilityArea = AccessibilityAreaNode()
        
        super.init(theme: theme)
        
        self.view.addSubview(self.button)
        
        self.label.isUserInteractionEnabled = false
        self.addSubnode(self.label)
        self.addSubnode(self.switchNode)
        
        self.addSubnode(self.accessibilityArea)
        
        self.button.addTarget(self, action: #selector(self.buttonPressed), for: .touchUpInside)
        self.switchNode.valueUpdated = { [weak self] value in
            self?.item?.action(value)
        }
        
        self.accessibilityArea.activate = { [weak self] in
            self?.buttonPressed()
            return true
        }
    }
    
    func setItem(_ item: ActionSheetSwitchItem) {
        self.item = item
        
        let defaultFont = Font.regular(floor(theme.baseFontSize * 20.0 / 17.0))
        
        self.label.attributedText = NSAttributedString(string: item.title, font: defaultFont, textColor: self.theme.primaryTextColor)
        self.label.isAccessibilityElement = false
        
        self.switchNode.isOn = item.isOn
        
        self.accessibilityArea.accessibilityLabel = item.title
        
        var accessibilityTraits: UIAccessibilityTraits = [.button]
        if item.isOn {
            accessibilityTraits.insert(.selected)
        }
        self.accessibilityArea.accessibilityTraits = accessibilityTraits
    }
    
    public override func updateLayout(constrainedSize: CGSize, transition: ContainedViewLayoutTransition) -> CGSize {
        let size = CGSize(width: constrainedSize.width, height: 57.0)
       
        self.button.frame = CGRect(origin: CGPoint(), size: size)
        
        let labelSize = self.label.updateLayout(CGSize(width: max(1.0, size.width - 51.0 - 16.0 * 2.0), height: size.height))
        self.label.frame = CGRect(origin: CGPoint(x: 16.0, y: floorToScreenPixels((size.height - labelSize.height) / 2.0)), size: labelSize)
        
        let switchSize = CGSize(width: 51.0, height: 31.0)
        self.switchNode.frame = CGRect(origin: CGPoint(x: size.width - 16.0 - switchSize.width, y: floor((size.height - switchSize.height) / 2.0)), size: switchSize)
        
        self.accessibilityArea.frame = CGRect(origin: CGPoint(), size: size)
        
        self.updateInternalLayout(size, constrainedSize: constrainedSize)
        return size
    }
    
    @objc func buttonPressed() {
        let value = !self.switchNode.isOn
        self.switchNode.setOn(value, animated: true)
        self.item?.action(value)
    }
}
