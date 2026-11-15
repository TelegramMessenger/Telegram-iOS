import Foundation
import UIKit
import AsyncDisplayKit

public enum ActionSheetCheckboxStyle {
    case `default`
    case alignRight
}

public class ActionSheetCheckboxItem: ActionSheetItem {
    public let title: String
    public let label: String
    public let value: Bool
    public let style: ActionSheetCheckboxStyle
    public let action: (Bool) -> Void
    
    public init(title: String, label: String, value: Bool, style: ActionSheetCheckboxStyle = .default, action: @escaping (Bool) -> Void) {
        self.title = title
        self.label = label
        self.value = value
        self.style = style
        self.action = action
    }
    
    public func node(theme: ActionSheetControllerTheme) -> ActionSheetItemNode {
        let node = ActionSheetCheckboxItemNode(theme: theme)
        node.setItem(self)
        return node
    }
    
    public func updateNode(_ node: ActionSheetItemNode) {
        guard let node = node as? ActionSheetCheckboxItemNode else {
            assertionFailure()
            return
        }
        
        node.setItem(self)
        node.requestLayoutUpdate()
    }
}

public class ActionSheetCheckboxItemNode: ActionSheetItemNode {
    private let theme: ActionSheetControllerTheme
    
    private var item: ActionSheetCheckboxItem?
    private var usesVerticalTextLayout = false
    
    private let button: HighlightTrackingButton
    private let titleNode: ImmediateTextNode
    private let labelNode: ImmediateTextNode
    private let checkNode: ASImageNode
    
    private let accessibilityArea: AccessibilityAreaNode
    
    override public init(theme: ActionSheetControllerTheme) {
        self.theme = theme
        
        self.button = HighlightTrackingButton()
        self.button.isAccessibilityElement = false
        
        self.titleNode = ImmediateTextNode()
        self.titleNode.maximumNumberOfLines = 0
        self.titleNode.isUserInteractionEnabled = false
        self.titleNode.displaysAsynchronously = false
        self.titleNode.isAccessibilityElement = false
        
        self.labelNode = ImmediateTextNode()
        self.labelNode.maximumNumberOfLines = 0
        self.labelNode.isUserInteractionEnabled = false
        self.labelNode.displaysAsynchronously = false
        self.labelNode.isAccessibilityElement = false
        
        self.checkNode = ASImageNode()
        self.checkNode.isUserInteractionEnabled = false
        self.checkNode.displaysAsynchronously = false
        self.checkNode.image = generateImage(CGSize(width: 14.0, height: 12.0), rotatedContext: { size, context in
            context.clear(CGRect(origin: CGPoint(), size: size))
            context.setStrokeColor(theme.controlAccentColor.cgColor)
            context.setLineWidth(2.0 - UIScreenPixel)
            context.setLineCap(.round)
            context.move(to: CGPoint(x: 13.0, y: 1.0))
            context.addLine(to: CGPoint(x: 5.0, y: 11.0))
            context.addLine(to: CGPoint(x: 1.0, y: 7.0))
            context.strokePath()
        })
        self.checkNode.isAccessibilityElement = false
        
        self.accessibilityArea = AccessibilityAreaNode()
        
        super.init(theme: theme)
        
        self.view.addSubview(self.button)
        self.addSubnode(self.titleNode)
        self.addSubnode(self.labelNode)
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
        
        self.accessibilityArea.activate = { [weak self] in
            self?.buttonPressed()
            return true
        }
        
        self.button.addTarget(self, action: #selector(self.buttonPressed), for: .touchUpInside)
    }
    
    func setItem(_ item: ActionSheetCheckboxItem) {
        self.item = item
        
        let baseFontSize = floor(theme.baseFontSize * 20.0 / 17.0)
        let scaledFontSize = UIFontMetrics(forTextStyle: .body).scaledValue(for: baseFontSize)
        let defaultFont = Font.regular(scaledFontSize)
        self.usesVerticalTextLayout = !item.label.isEmpty && scaledFontSize > baseFontSize * 1.2
        
        self.titleNode.attributedText = NSAttributedString(string: item.title, font: defaultFont, textColor: self.theme.primaryTextColor)
        self.labelNode.attributedText = NSAttributedString(string: item.label, font: defaultFont, textColor: self.theme.secondaryTextColor)
        self.checkNode.isHidden = !item.value
        
        self.accessibilityArea.accessibilityLabel = item.title
        self.accessibilityArea.accessibilityValue = item.label.isEmpty ? nil : item.label
        
        var accessibilityTraits: UIAccessibilityTraits = [.button]
        if item.value {
            accessibilityTraits.insert(.selected)
        }
        self.accessibilityArea.accessibilityTraits = accessibilityTraits
    }
    
    public override func updateLayout(constrainedSize: CGSize, transition: ContainedViewLayoutTransition) -> CGSize {
        var titleOrigin: CGFloat = 50.0
        var checkOrigin: CGFloat = 27.0
        var rightInset: CGFloat = 15.0
        if let item = self.item, item.style == .alignRight {
            titleOrigin = 24.0
            checkOrigin = constrainedSize.width - 22.0
            rightInset = 50.0
        }

        let contentWidth = max(1.0, constrainedSize.width - titleOrigin - rightInset)
        let labelSize: CGSize
        let titleSize: CGSize
        let textHeight: CGFloat
        if self.usesVerticalTextLayout {
            titleSize = self.titleNode.updateLayout(CGSize(width: contentWidth, height: constrainedSize.height))
            labelSize = self.labelNode.updateLayout(CGSize(width: contentWidth, height: constrainedSize.height))
            textHeight = titleSize.height + 4.0 + labelSize.height
        } else {
            labelSize = self.labelNode.updateLayout(CGSize(width: contentWidth * 0.45, height: constrainedSize.height))
            titleSize = self.titleNode.updateLayout(CGSize(width: max(1.0, contentWidth - labelSize.width - 8.0), height: constrainedSize.height))
            textHeight = max(titleSize.height, labelSize.height)
        }
        let size = CGSize(width: constrainedSize.width, height: max(57.0, textHeight + 28.0))

        self.button.frame = CGRect(origin: CGPoint(), size: size)
        
        if self.usesVerticalTextLayout {
            let textOrigin = floorToScreenPixels((size.height - textHeight) / 2.0)
            self.titleNode.frame = CGRect(origin: CGPoint(x: titleOrigin, y: textOrigin), size: titleSize)
            self.labelNode.frame = CGRect(origin: CGPoint(x: titleOrigin, y: textOrigin + titleSize.height + 4.0), size: labelSize)
        } else {
            self.titleNode.frame = CGRect(origin: CGPoint(x: titleOrigin, y: floorToScreenPixels((size.height - titleSize.height) / 2.0)), size: titleSize)
            self.labelNode.frame = CGRect(origin: CGPoint(x: size.width - 15.0 - labelSize.width, y: floorToScreenPixels((size.height - labelSize.height) / 2.0)), size: labelSize)
        }
        
        if let image = self.checkNode.image {
            self.checkNode.frame = CGRect(origin: CGPoint(x: floor(checkOrigin - (image.size.width / 2.0)), y: floor((size.height - image.size.height) / 2.0)), size: image.size)
        }
        
        self.accessibilityArea.frame = CGRect(origin: CGPoint(), size: size)
        
        self.updateInternalLayout(size, constrainedSize: constrainedSize)
        return size
    }
    
    @objc func buttonPressed() {
        if let item = self.item {
            item.action(!item.value)
        }
    }
}
