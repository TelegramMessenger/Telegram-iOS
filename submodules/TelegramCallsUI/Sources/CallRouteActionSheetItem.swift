import Foundation
import UIKit
import AsyncDisplayKit
import Display

public class CallRouteActionSheetItem: ActionSheetItem {
    public let title: String
    public let icon: UIImage?
    public let selected: Bool
    public let action: () -> Void
    
    public init(title: String, icon: UIImage?, selected: Bool, action: @escaping () -> Void) {
        self.title = title
        self.icon = icon
        self.selected = selected
        self.action = action
    }
    
    public func node(theme: ActionSheetControllerTheme) -> ActionSheetItemNode {
        let node = CallRouteActionSheetItemNode(theme: theme)
        node.setItem(self)
        return node
    }
    
    public func updateNode(_ node: ActionSheetItemNode) {
        guard let node = node as? CallRouteActionSheetItemNode else {
            assertionFailure()
            return
        }
        
        node.setItem(self)
        node.requestLayoutUpdate()
    }
}

public class CallRouteActionSheetItemNode: ActionSheetItemNode {
    private let theme: ActionSheetControllerTheme
    
    private let defaultFont: UIFont
    
    private var item: CallRouteActionSheetItem?
    
    private let button: HighlightTrackingButton
    private let label: ASTextNode
    private let iconNode: ASImageNode
    private let checkNode: ASImageNode
    
    private let accessibilityArea: AccessibilityAreaNode
    
    override public init(theme: ActionSheetControllerTheme) {
        self.theme = theme
        self.defaultFont = Font.regular(floor(theme.baseFontSize * 20.0 / 17.0))
        
        self.button = HighlightTrackingButton()
        self.button.isAccessibilityElement = false
        
        self.label = ASTextNode()
        self.label.isUserInteractionEnabled = false
        self.label.maximumNumberOfLines = 1
        self.label.displaysAsynchronously = false
        self.label.truncationMode = .byTruncatingTail
        self.label.isAccessibilityElement = false
        
        self.iconNode = ASImageNode()
        self.iconNode.isUserInteractionEnabled = false
        self.iconNode.displayWithoutProcessing = true
        self.iconNode.displaysAsynchronously = false
        self.iconNode.isAccessibilityElement = false
        
        self.checkNode = ASImageNode()
        self.checkNode.isUserInteractionEnabled = false
        self.checkNode.displayWithoutProcessing = true
        self.checkNode.displaysAsynchronously = false
        self.checkNode.image = generateImage(CGSize(width: 14.0, height: 11.0), rotatedContext: { size, context in
            context.clear(CGRect(origin: CGPoint(), size: size))
            context.setStrokeColor(theme.controlAccentColor.cgColor)
            context.setLineWidth(2.0)
            context.move(to: CGPoint(x: 12.0, y: 1.0))
            context.addLine(to: CGPoint(x: 4.16482734, y: 9.0))
            context.addLine(to: CGPoint(x: 1.0, y: 5.81145833))
            context.strokePath()
        })
        self.checkNode.isAccessibilityElement = false
        
        self.accessibilityArea = AccessibilityAreaNode()
        
        super.init(theme: theme)
        
        self.view.addSubview(self.button)
        
        self.label.isUserInteractionEnabled = false
        self.addSubnode(self.label)
        self.addSubnode(self.iconNode)
        self.addSubnode(self.checkNode)
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
    
    func setItem(_ item: CallRouteActionSheetItem) {
        self.item = item
        
        let defaultFont = Font.regular(floor(theme.baseFontSize * 20.0 / 17.0))
        
        self.label.attributedText = NSAttributedString(string: item.title, font: defaultFont, textColor: self.theme.standardActionTextColor)
        if let icon = item.icon {
            self.iconNode.image = generateTintedImage(image: icon, color: self.theme.standardActionTextColor)
        } else {
            self.iconNode.isHidden = true
        }
        self.checkNode.isHidden = !item.selected
        
        var accessibilityTraits: UIAccessibilityTraits = [.button]
        if item.selected {
            accessibilityTraits.insert(.selected)
        }
        self.accessibilityArea.accessibilityTraits = accessibilityTraits
        self.accessibilityArea.accessibilityLabel = item.title
    }
    
    public override func updateLayout(constrainedSize: CGSize, transition: ContainedViewLayoutTransition) -> CGSize {
        let size = CGSize(width: constrainedSize.width, height: 57.0)
        
        self.button.frame = CGRect(origin: CGPoint(), size: size)
        
        let labelSize = self.label.measure(CGSize(width: max(1.0, size.width - 10.0), height: size.height))
        self.label.frame = CGRect(origin: CGPoint(x: floorToScreenPixels((size.width - labelSize.width) / 2.0), y: floorToScreenPixels((size.height - labelSize.height) / 2.0)), size: labelSize)
        
        if let image = self.iconNode.image {
            self.iconNode.frame = CGRect(origin: CGPoint(x: 12.0, y: floor((size.height - image.size.height) / 2.0)), size: image.size)
        }
        
        if let image = self.checkNode.image {
            self.checkNode.frame = CGRect(origin: CGPoint(x: size.width - image.size.width - 13.0, y: floor((size.height - image.size.height) / 2.0)), size: image.size)
        }
        
        self.updateInternalLayout(size, constrainedSize: constrainedSize)
        return size
    }
    
    @objc func buttonPressed() {
        if let item = self.item {
            item.action()
        }
    }
}
