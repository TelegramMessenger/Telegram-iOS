import Foundation
import UIKit
import AsyncDisplayKit
import Display
import TelegramPresentationData
import ItemListUI
import PresentationDataUtils
import SolidRoundedButtonNode
import AppBundle

final class IncreaseLimitFooterItem: ItemListControllerFooterItem {
    let theme: PresentationTheme
    let title: String
    let colorful: Bool
    let action: () -> Void
    
    init(theme: PresentationTheme, title: String, colorful: Bool, action: @escaping () -> Void) {
        self.theme = theme
        self.title = title
        self.colorful = colorful
        self.action = action
    }
    
    func isEqual(to: ItemListControllerFooterItem) -> Bool {
        if let item = to as? IncreaseLimitFooterItem {
            return self.theme === item.theme  && self.title == item.title
        } else {
            return false
        }
    }
    
    func node(current: ItemListControllerFooterItemNode?) -> ItemListControllerFooterItemNode {
        if let current = current as? IncreaseLimitFooterItemNode {
            current.item = self
            return current
        } else {
            return IncreaseLimitFooterItemNode(item: self)
        }
    }
}

final class IncreaseLimitFooterItemNode: ItemListControllerFooterItemNode {
    private let backgroundNode: NavigationBackgroundNode
    private let separatorNode: ASDisplayNode
    private let buttonNode: SolidRoundedButtonNode
    
    private var validLayout: ContainerViewLayout?
    
    var item: IncreaseLimitFooterItem {
        didSet {
            self.updateItem()
            if let layout = self.validLayout {
                let _ = self.updateLayout(layout: layout, transition: .immediate)
            }
        }
    }
    
    init(item: IncreaseLimitFooterItem) {
        self.item = item
        
        self.backgroundNode = NavigationBackgroundNode(color: item.theme.rootController.tabBar.backgroundColor)
        self.separatorNode = ASDisplayNode()
        
        self.buttonNode = SolidRoundedButtonNode(theme: SolidRoundedButtonTheme(backgroundColor: .black, foregroundColor: .white), height: 50.0, cornerRadius: 11.0)
        self.buttonNode.iconPosition = .right
        self.buttonNode.icon = UIImage(bundleImageName: "Premium/X2")
        
        super.init()
        
        self.addSubnode(self.backgroundNode)
        self.addSubnode(self.separatorNode)
        self.addSubnode(self.buttonNode)
        
        self.updateItem()
    }
    
    private func updateItem() {
        self.backgroundNode.updateColor(color: self.item.theme.rootController.tabBar.backgroundColor, transition: .immediate)
        self.separatorNode.backgroundColor = self.item.theme.rootController.tabBar.separatorColor
        
        let textColor: UIColor
        let backgroundColor = self.item.theme.list.itemCheckColors.fillColor
        let backgroundColors: [UIColor]
        let icon: UIImage?
        if self.item.colorful {
            textColor = .white
            backgroundColors = [
                UIColor(rgb: 0x0077ff),
                UIColor(rgb: 0x6b93ff),
                UIColor(rgb: 0x8878ff),
                UIColor(rgb: 0xe46ace)
            ]
            icon = UIImage(bundleImageName: "Premium/X2")
        } else {
            textColor = self.item.theme.list.itemCheckColors.foregroundColor
            backgroundColors = []
            icon = nil
        }
        
        self.buttonNode.updateTheme(SolidRoundedButtonTheme(backgroundColor: backgroundColor, backgroundColors: backgroundColors, foregroundColor: textColor), animated: true)
        self.buttonNode.title = self.item.title
        self.buttonNode.icon = icon
        
        self.buttonNode.pressed = { [weak self] in
            self?.item.action()
        }
    }
    
    override func updateBackgroundAlpha(_ alpha: CGFloat, transition: ContainedViewLayoutTransition) {
        transition.updateAlpha(node: self.backgroundNode, alpha: alpha)
        transition.updateAlpha(node: self.separatorNode, alpha: alpha)
    }
    
    override func updateLayout(layout: ContainerViewLayout, transition: ContainedViewLayoutTransition) -> CGFloat {
        self.validLayout = layout
        
        let buttonInset: CGFloat = 16.0
        let buttonWidth = layout.size.width - layout.safeInsets.left - layout.safeInsets.right - buttonInset * 2.0
        let buttonHeight = self.buttonNode.updateLayout(width: buttonWidth, transition: transition)
        let inset: CGFloat = 9.0
        
        let insets = layout.insets(options: [.input])
        
        var panelHeight: CGFloat = buttonHeight + inset * 2.0
        let totalPanelHeight: CGFloat
        if let inputHeight = layout.inputHeight, inputHeight > 0.0 {
            totalPanelHeight = panelHeight + insets.bottom
        } else {
            panelHeight += insets.bottom
            totalPanelHeight = panelHeight
        }
        
        let panelFrame = CGRect(origin: CGPoint(x: 0.0, y: layout.size.height - totalPanelHeight), size: CGSize(width: layout.size.width, height: panelHeight))
        transition.updateFrame(node: self.buttonNode, frame: CGRect(origin: CGPoint(x: layout.safeInsets.left + buttonInset, y: panelFrame.minY + inset), size: CGSize(width: buttonWidth, height: buttonHeight)))
        
        transition.updateFrame(node: self.backgroundNode, frame: panelFrame)
        self.backgroundNode.update(size: panelFrame.size, transition: transition)
        
        transition.updateFrame(node: self.separatorNode, frame: CGRect(origin: panelFrame.origin, size: CGSize(width: panelFrame.width, height: UIScreenPixel)))
        
        return panelHeight
    }
    
    override func point(inside point: CGPoint, with event: UIEvent?) -> Bool {
        if self.backgroundNode.frame.contains(point) {
            return true
        } else {
            return false
        }
    }
}
