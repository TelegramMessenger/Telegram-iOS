import Foundation
import UIKit
import AsyncDisplayKit
import Display
import TelegramPresentationData
import ItemListUI
import PresentationDataUtils
import SolidRoundedButtonNode
import AppBundle

final class DeleteAccountFooterItem: ItemListControllerFooterItem {
    let theme: PresentationTheme
    let title: String
    let secondaryTitle: String
    let action: () -> Void
    let secondaryAction: () -> Void
    
    init(theme: PresentationTheme, title: String, secondaryTitle: String, action: @escaping () -> Void, secondaryAction: @escaping () -> Void) {
        self.theme = theme
        self.title = title
        self.secondaryTitle = secondaryTitle
        self.action = action
        self.secondaryAction = secondaryAction
    }
    
    func isEqual(to: ItemListControllerFooterItem) -> Bool {
        if let item = to as? DeleteAccountFooterItem {
            return self.theme === item.theme && self.title == item.title && self.secondaryTitle == item.secondaryTitle
        } else {
            return false
        }
    }
    
    func node(current: ItemListControllerFooterItemNode?) -> ItemListControllerFooterItemNode {
        if let current = current as? DeleteAccountFooterItemNode {
            current.item = self
            return current
        } else {
            return DeleteAccountFooterItemNode(item: self)
        }
    }
}

final class DeleteAccountFooterItemNode: ItemListControllerFooterItemNode {
    private let backgroundNode: NavigationBackgroundNode
    private let separatorNode: ASDisplayNode
    private let clipNode: ASDisplayNode
    private let buttonNode: SolidRoundedButtonNode
    private let secondaryButtonNode: HighlightableButtonNode
    
    private var validLayout: ContainerViewLayout?
    
    var item: DeleteAccountFooterItem {
        didSet {
            self.updateItem()
            if let layout = self.validLayout {
                let _ = self.updateLayout(layout: layout, transition: .immediate)
            }
        }
    }
    
    init(item: DeleteAccountFooterItem) {
        self.item = item
        
        self.backgroundNode = NavigationBackgroundNode(color: item.theme.rootController.tabBar.backgroundColor)
        self.separatorNode = ASDisplayNode()
        
        self.clipNode = ASDisplayNode()
        self.clipNode.clipsToBounds = true
        
        self.buttonNode = SolidRoundedButtonNode(theme: SolidRoundedButtonTheme(backgroundColor: .black, foregroundColor: .white), height: 50.0, cornerRadius: 11.0, gloss: true)
        
        self.secondaryButtonNode = HighlightableButtonNode()
        
        super.init()
        
        self.addSubnode(self.backgroundNode)
        self.addSubnode(self.separatorNode)
        self.addSubnode(self.clipNode)
        self.clipNode.addSubnode(self.buttonNode)
        self.clipNode.addSubnode(self.secondaryButtonNode)
    
        self.secondaryButtonNode.addTarget(self, action: #selector(self.secondaryButtonPressed), forControlEvents: .touchUpInside)
        
        self.updateItem()
    }

    @objc private func secondaryButtonPressed() {
        self.item.secondaryAction()
    }
    
    private func updateItem() {
        self.backgroundNode.updateColor(color: self.item.theme.rootController.tabBar.backgroundColor, transition: .immediate)
        self.separatorNode.backgroundColor = self.item.theme.rootController.tabBar.separatorColor
        
        let backgroundColor = self.item.theme.list.itemCheckColors.fillColor
        let textColor = self.item.theme.list.itemCheckColors.foregroundColor
        
        self.buttonNode.updateTheme(SolidRoundedButtonTheme(backgroundColor: backgroundColor, foregroundColor: textColor), animated: false)
        self.buttonNode.title = self.item.title
                
        self.buttonNode.pressed = { [weak self] in
            self?.item.action()
        }
        
        self.secondaryButtonNode.setTitle(self.item.secondaryTitle, with: Font.regular(17.0), with: self.item.theme.list.itemAccentColor, for: .normal)
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
        let topInset: CGFloat = 9.0
        
        let bottomInset: CGFloat
        let spacing: CGFloat
        
        if layout.size.width > 320.0 {
            bottomInset = 23.0
            spacing = 23.0
        } else {
            bottomInset = 16.0
            spacing = 16.0
        }
        
        let insets = layout.insets(options: [.input])
        
        let secondaryButtonSize = self.secondaryButtonNode.measure(CGSize(width: buttonWidth, height: CGFloat.greatestFiniteMagnitude))
        
        var panelHeight: CGFloat = buttonHeight + topInset + spacing + secondaryButtonSize.height + bottomInset
        
        var buttonOffset: CGFloat = 0.0
        let totalPanelHeight: CGFloat
        
        if (self.buttonNode.title?.isEmpty ?? false) {
            buttonOffset = -buttonHeight - topInset
            self.buttonNode.alpha = 0.0
        } else {
            self.buttonNode.alpha = 1.0
        }
        
        if let inputHeight = layout.inputHeight, inputHeight > 0.0 {
            panelHeight += buttonOffset
            totalPanelHeight = panelHeight + insets.bottom
        } else {
            panelHeight += insets.bottom
            totalPanelHeight = panelHeight
        }
        
        let panelFrame = CGRect(origin: CGPoint(x: 0.0, y: layout.size.height - totalPanelHeight), size: CGSize(width: layout.size.width, height: panelHeight))
        
        transition.updateFrame(node: self.backgroundNode, frame: panelFrame)
        self.backgroundNode.update(size: panelFrame.size, transition: transition)
        
        transition.updateFrame(node: self.clipNode, frame: panelFrame)
        
        transition.updateFrame(node: self.buttonNode, frame: CGRect(origin: CGPoint(x: layout.safeInsets.left + buttonInset, y: topInset + buttonOffset), size: CGSize(width: buttonWidth, height: buttonHeight)))
        transition.updateFrame(node: self.secondaryButtonNode, frame: CGRect(origin: CGPoint(x: floorToScreenPixels((layout.size.width - secondaryButtonSize.width) / 2.0), y: topInset + buttonHeight + spacing + buttonOffset), size: secondaryButtonSize))
        
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
