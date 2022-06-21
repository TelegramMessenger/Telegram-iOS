import Foundation
import UIKit
import AsyncDisplayKit

public enum ToolbarActionOption {
    case left
    case right
    case middle
}

public final class ToolbarTheme {
    public let barBackgroundColor: UIColor
    public let barSeparatorColor: UIColor
    public let barTextColor: UIColor
    public let barSelectedTextColor: UIColor

    public init(barBackgroundColor: UIColor, barSeparatorColor: UIColor, barTextColor: UIColor, barSelectedTextColor: UIColor) {
        self.barBackgroundColor = barBackgroundColor
        self.barSeparatorColor = barSeparatorColor
        self.barTextColor = barTextColor
        self.barSelectedTextColor = barSelectedTextColor
    }
}

public final class ToolbarNode: ASDisplayNode {
    private var theme: ToolbarTheme
    private let displaySeparator: Bool
    public var left: () -> Void
    public var right: () -> Void
    public var middle: () -> Void

    private let backgroundNode: NavigationBackgroundNode
    private let separatorNode: ASDisplayNode
    private let leftTitle: ImmediateTextNode
    private let leftButton: HighlightTrackingButtonNode
    private let rightTitle: ImmediateTextNode
    private let rightButton: HighlightTrackingButtonNode
    private let middleTitle: ImmediateTextNode
    private let middleButton: HighlightTrackingButtonNode
    
    public init(theme: ToolbarTheme, displaySeparator: Bool = false, left: @escaping () -> Void = {}, right: @escaping () -> Void = {}, middle: @escaping () -> Void = {}) {
        self.theme = theme
        self.displaySeparator = displaySeparator
        self.left = left
        self.right = right
        self.middle = middle

        self.backgroundNode = NavigationBackgroundNode(color: theme.barBackgroundColor)
        
        self.separatorNode = ASDisplayNode()
        self.separatorNode.isLayerBacked = true
        
        self.leftTitle = ImmediateTextNode()
        self.leftTitle.displaysAsynchronously = false
        self.leftButton = HighlightTrackingButtonNode()
        self.rightTitle = ImmediateTextNode()
        self.rightTitle.displaysAsynchronously = false
        self.rightButton = HighlightTrackingButtonNode()
        self.middleTitle = ImmediateTextNode()
        self.middleTitle.displaysAsynchronously = false
        self.middleButton = HighlightTrackingButtonNode()
        
        super.init()
        
        self.isAccessibilityContainer = false

        self.addSubnode(self.backgroundNode)
        
        self.addSubnode(self.leftTitle)
        self.addSubnode(self.leftButton)
        self.addSubnode(self.rightTitle)
        self.addSubnode(self.rightButton)
        self.addSubnode(self.middleTitle)
        self.addSubnode(self.middleButton)

        if self.displaySeparator {
            self.addSubnode(self.separatorNode)
        }
        
        self.updateTheme(theme)
        
        self.leftButton.addTarget(self, action: #selector(self.leftPressed), forControlEvents: .touchUpInside)
        self.leftButton.highligthedChanged = { [weak self] highlighted in
            if let strongSelf = self {
                if highlighted {
                    strongSelf.leftTitle.layer.removeAnimation(forKey: "opacity")
                    strongSelf.leftTitle.alpha = 0.4
                } else {
                    strongSelf.leftTitle.alpha = 1.0
                    strongSelf.leftTitle.layer.animateAlpha(from: 0.4, to: 1.0, duration: 0.2)
                }
            }
        }
        self.leftButton.accessibilityTraits = .button
        self.rightButton.addTarget(self, action: #selector(self.rightPressed), forControlEvents: .touchUpInside)
        self.rightButton.highligthedChanged = { [weak self] highlighted in
            if let strongSelf = self {
                if highlighted {
                    strongSelf.rightTitle.layer.removeAnimation(forKey: "opacity")
                    strongSelf.rightTitle.alpha = 0.4
                } else {
                    strongSelf.rightTitle.alpha = 1.0
                    strongSelf.rightTitle.layer.animateAlpha(from: 0.4, to: 1.0, duration: 0.2)
                }
            }
        }
        self.rightButton.accessibilityTraits = .button
        self.middleButton.addTarget(self, action: #selector(self.middlePressed), forControlEvents: .touchUpInside)
        self.middleButton.highligthedChanged = { [weak self] highlighted in
            if let strongSelf = self {
                if highlighted {
                    strongSelf.middleTitle.layer.removeAnimation(forKey: "opacity")
                    strongSelf.middleTitle.alpha = 0.4
                } else {
                    strongSelf.middleTitle.alpha = 1.0
                    strongSelf.middleTitle.layer.animateAlpha(from: 0.4, to: 1.0, duration: 0.2)
                }
            }
        }
        self.middleButton.accessibilityTraits = .button
    }
    
    public func updateTheme(_ theme: ToolbarTheme) {
        self.separatorNode.backgroundColor = theme.barSeparatorColor
        self.backgroundNode.updateColor(color: theme.barBackgroundColor, transition: .immediate)
    }
    
    public func updateLayout(size: CGSize, leftInset: CGFloat, rightInset: CGFloat, additionalSideInsets: UIEdgeInsets, bottomInset: CGFloat, toolbar: Toolbar, transition: ContainedViewLayoutTransition) {
        transition.updateFrame(node: self.backgroundNode, frame: CGRect(origin: CGPoint(), size: size))
        self.backgroundNode.update(size: size, transition: transition)
        transition.updateFrame(node: self.separatorNode, frame: CGRect(origin: CGPoint(x: 0.0, y: 0.0), size: CGSize(width: size.width, height: UIScreenPixel)))
        
        var sideInset: CGFloat = 16.0
        
        self.leftTitle.attributedText = NSAttributedString(string: toolbar.leftAction?.title ?? "", font: Font.regular(17.0), textColor: (toolbar.leftAction?.isEnabled ?? false) ? self.theme.barSelectedTextColor : self.theme.barTextColor)
        self.leftButton.accessibilityLabel = toolbar.leftAction?.title
        
        self.rightTitle.attributedText = NSAttributedString(string: toolbar.rightAction?.title ?? "", font: Font.regular(17.0), textColor: (toolbar.rightAction?.isEnabled ?? false) ? self.theme.barSelectedTextColor : self.theme.barTextColor)
        self.rightButton.accessibilityLabel = toolbar.rightAction?.title

        let middleColor: UIColor
        if let middleAction = toolbar.middleAction {
            if middleAction.isEnabled {
                switch middleAction.color {
                case .accent:
                    middleColor = self.theme.barSelectedTextColor
                case let .custom(color):
                    middleColor = color
                }
            } else {
                middleColor = self.theme.barTextColor
            }
        } else {
            middleColor = self.theme.barTextColor
        }
        self.middleTitle.attributedText = NSAttributedString(string: toolbar.middleAction?.title ?? "", font: Font.regular(17.0), textColor: middleColor)
        self.middleButton.accessibilityLabel = toolbar.middleAction?.title
        
        var size = size
        if additionalSideInsets.right > 0.0 {
            size = CGSize(width: size.width - additionalSideInsets.right, height: size.height)
            sideInset = 8.0
        }
        
        let leftSize = self.leftTitle.updateLayout(size)
        let rightSize = self.rightTitle.updateLayout(size)
        let middleSize = self.middleTitle.updateLayout(size)
        
        let leftFrame = CGRect(origin: CGPoint(x: leftInset + sideInset, y: floor((size.height - bottomInset - leftSize.height) / 2.0)), size: leftSize)
        let rightFrame = CGRect(origin: CGPoint(x: size.width - rightInset - sideInset - rightSize.width, y: floor((size.height - bottomInset - rightSize.height) / 2.0)), size: rightSize)
        let middleFrame = CGRect(origin: CGPoint(x: floor((size.width - middleSize.width) / 2.0), y: floor((size.height - bottomInset - middleSize.height) / 2.0)), size: middleSize)
        
        if leftFrame.size == self.leftTitle.frame.size {
            transition.updateFrame(node: self.leftTitle, frame: leftFrame)
        } else {
            self.leftTitle.frame = leftFrame
        }
        
        if rightFrame.size == self.rightTitle.frame.size {
            transition.updateFrame(node: self.rightTitle, frame: rightFrame)
        } else {
            self.rightTitle.frame = rightFrame
        }
        
        if middleFrame.size == self.middleTitle.frame.size {
            transition.updateFrame(node: self.middleTitle, frame: middleFrame)
        } else {
            self.middleTitle.frame = middleFrame
        }
        
        self.leftButton.isEnabled = toolbar.leftAction?.isEnabled ?? false
        self.rightButton.isEnabled = toolbar.rightAction?.isEnabled ?? false
        self.middleButton.isEnabled = toolbar.middleAction?.isEnabled ?? false
        
        self.leftButton.frame = CGRect(origin: CGPoint(x: leftInset, y: 0.0), size: CGSize(width: leftSize.width + sideInset * 2.0, height: size.height - bottomInset))
        self.rightButton.frame = CGRect(origin: CGPoint(x: size.width - rightInset - sideInset * 2.0 - rightSize.width, y: 0.0), size: CGSize(width: rightSize.width + sideInset * 2.0, height: size.height - bottomInset))
        self.middleButton.frame = CGRect(origin: CGPoint(x: floor((size.width - middleSize.width) / 2.0), y: 0.0), size: CGSize(width: middleSize.width + sideInset * 2.0, height: size.height - bottomInset))
    }
    
    @objc private func leftPressed() {
        self.left()
    }
    
    @objc private func rightPressed() {
        self.right()
    }
    
    @objc private func middlePressed() {
        self.middle()
    }
}
