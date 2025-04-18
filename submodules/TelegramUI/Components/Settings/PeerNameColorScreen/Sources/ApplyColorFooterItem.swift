import Foundation
import UIKit
import AsyncDisplayKit
import Display
import TelegramPresentationData
import ItemListUI
import PresentationDataUtils
import SolidRoundedButtonNode
import AppBundle

final class ApplyColorFooterItem: ItemListControllerFooterItem {
    let theme: PresentationTheme
    let title: String
    let locked: Bool
    let inProgress: Bool
    let action: () -> Void
    
    init(theme: PresentationTheme, title: String, locked: Bool, inProgress: Bool, action: @escaping () -> Void) {
        self.theme = theme
        self.title = title
        self.locked = locked
        self.inProgress = inProgress
        self.action = action
    }
    
    func isEqual(to: ItemListControllerFooterItem) -> Bool {
        if let item = to as? ApplyColorFooterItem {
            return self.theme === item.theme && self.title == item.title && self.locked == item.locked && self.inProgress == item.inProgress
        } else {
            return false
        }
    }
    
    func node(current: ItemListControllerFooterItemNode?) -> ItemListControllerFooterItemNode {
        if let current = current as? ApplyColorFooterItemNode {
            current.item = self
            return current
        } else {
            return ApplyColorFooterItemNode(item: self)
        }
    }
}

final class ApplyColorFooterItemNode: ItemListControllerFooterItemNode {
    private let backgroundNode: NavigationBackgroundNode
    private let separatorNode: ASDisplayNode
    private let buttonNode: SolidRoundedButtonNode
    
    private var validLayout: ContainerViewLayout?
    
    var item: ApplyColorFooterItem {
        didSet {
            self.updateItem()
            if let layout = self.validLayout {
                let _ = self.updateLayout(layout: layout, transition: .immediate)
            }
        }
    }
    
    init(item: ApplyColorFooterItem) {
        self.item = item
        
        self.backgroundNode = NavigationBackgroundNode(color: item.theme.rootController.tabBar.backgroundColor)
        self.separatorNode = ASDisplayNode()
        
        self.buttonNode = SolidRoundedButtonNode(theme: SolidRoundedButtonTheme(backgroundColor: .black, foregroundColor: .white), height: 50.0, cornerRadius: 11.0)
        self.buttonNode.icon = item.locked ? UIImage(bundleImageName: "Chat/Stickers/Lock") : nil
        self.buttonNode.progressType = .embedded
        
        super.init()
        
        self.addSubnode(self.backgroundNode)
        self.addSubnode(self.separatorNode)
        self.addSubnode(self.buttonNode)
        
        self.updateItem()
    }
    
    private var inProgress = false
    private func updateItem() {
        self.backgroundNode.updateColor(color: self.item.theme.rootController.tabBar.backgroundColor, transition: .immediate)
        self.separatorNode.backgroundColor = self.item.theme.rootController.tabBar.separatorColor
        
        let backgroundColor = self.item.theme.list.itemCheckColors.fillColor
        let textColor = self.item.theme.list.itemCheckColors.foregroundColor
    
        self.buttonNode.updateTheme(SolidRoundedButtonTheme(backgroundColor: backgroundColor, backgroundColors: [], foregroundColor: textColor), animated: true)
        self.buttonNode.title = self.item.title
        self.buttonNode.icon = self.item.locked ? UIImage(bundleImageName: "Chat/Stickers/Lock") : nil
        
        self.buttonNode.pressed = { [weak self] in
            self?.item.action()
        }
        
        if self.inProgress != self.item.inProgress {
            self.inProgress = self.item.inProgress
            
            if self.item.inProgress {
                self.buttonNode.transitionToProgress()
            } else {
                self.buttonNode.transitionFromProgress()
            }
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
