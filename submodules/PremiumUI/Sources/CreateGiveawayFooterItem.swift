import Foundation
import UIKit
import AsyncDisplayKit
import Display
import ComponentFlow
import TelegramPresentationData
import ItemListUI
import PresentationDataUtils
import ButtonComponent

final class CreateGiveawayFooterItem: ItemListControllerFooterItem {
    let theme: PresentationTheme
    let title: String
    let badgeCount: Int32
    let isLoading: Bool
    let action: () -> Void
    
    init(theme: PresentationTheme, title: String, badgeCount: Int32, isLoading: Bool, action: @escaping () -> Void) {
        self.theme = theme
        self.title = title
        self.badgeCount = badgeCount
        self.isLoading = isLoading
        self.action = action
    }
    
    func isEqual(to: ItemListControllerFooterItem) -> Bool {
        if let item = to as? CreateGiveawayFooterItem {
            return self.theme === item.theme && self.title == item.title && self.badgeCount == item.badgeCount && self.isLoading == item.isLoading
        } else {
            return false
        }
    }
    
    func node(current: ItemListControllerFooterItemNode?) -> ItemListControllerFooterItemNode {
        if let current = current as? CreateGiveawayFooterItemNode {
            current.item = self
            return current
        } else {
            return CreateGiveawayFooterItemNode(item: self)
        }
    }
}

final class CreateGiveawayFooterItemNode: ItemListControllerFooterItemNode {
    private let backgroundNode: NavigationBackgroundNode
    private let separatorNode: ASDisplayNode
    private let button = ComponentView<Empty>()

    private var validLayout: ContainerViewLayout?
    
    private var currentIsLoading = false
    var item: CreateGiveawayFooterItem {
        didSet {
            self.updateItem()
            if let layout = self.validLayout {
                let _ = self.updateLayout(layout: layout, transition: .immediate)
            }
        }
    }
    
    init(item: CreateGiveawayFooterItem) {
        self.item = item
        
        self.backgroundNode = NavigationBackgroundNode(color: item.theme.rootController.tabBar.backgroundColor)
        self.separatorNode = ASDisplayNode()
        
        super.init()
        
        self.addSubnode(self.backgroundNode)
        self.addSubnode(self.separatorNode)
        
        self.updateItem()
    }
        
    private func updateItem() {
        self.backgroundNode.updateColor(color: self.item.theme.rootController.tabBar.backgroundColor, transition: .immediate)
        self.separatorNode.backgroundColor = self.item.theme.rootController.tabBar.separatorColor
    }
    
    override func updateBackgroundAlpha(_ alpha: CGFloat, transition: ContainedViewLayoutTransition) {
        transition.updateAlpha(node: self.backgroundNode, alpha: alpha)
        transition.updateAlpha(node: self.separatorNode, alpha: alpha)
    }
    
    override func updateLayout(layout: ContainerViewLayout, transition: ContainedViewLayoutTransition) -> CGFloat {
        let hadLayout = self.validLayout != nil
        self.validLayout = layout
        
        let buttonInset: CGFloat = 16.0
        let buttonWidth = layout.size.width - layout.safeInsets.left - layout.safeInsets.right - buttonInset * 2.0
        let inset: CGFloat = 9.0
        
        let insets = layout.insets(options: [.input])
        
        var panelHeight: CGFloat = 50.0 + inset * 2.0
        let totalPanelHeight: CGFloat
        if let inputHeight = layout.inputHeight, inputHeight > 0.0 {
            totalPanelHeight = panelHeight + insets.bottom
        } else {
            totalPanelHeight = panelHeight + insets.bottom
            panelHeight += insets.bottom
        }
        
        let panelFrame = CGRect(origin: CGPoint(x: 0.0, y: layout.size.height - totalPanelHeight), size: CGSize(width: layout.size.width, height: panelHeight))
        
        var buttonTransition: ComponentTransition = .easeInOut(duration: 0.2)
        if !hadLayout {
            buttonTransition = .immediate
        }
        let buttonSize = self.button.update(
            transition: buttonTransition,
            component: AnyComponent(
                ButtonComponent(
                    background: ButtonComponent.Background(
                        color: self.item.theme.list.itemCheckColors.fillColor,
                        foreground: self.item.theme.list.itemCheckColors.foregroundColor,
                        pressedColor: self.item.theme.list.itemCheckColors.fillColor.withMultipliedAlpha(0.9)
                    ),
                    content: AnyComponentWithIdentity(
                        id: AnyHashable(0),
                        component: AnyComponent(ButtonTextContentComponent(
                            text: self.item.title,
                            badge: Int(self.item.badgeCount),
                            textColor: self.item.theme.list.itemCheckColors.foregroundColor,
                            badgeBackground: self.item.theme.list.itemCheckColors.foregroundColor,
                            badgeForeground: self.item.theme.list.itemCheckColors.fillColor,
                            badgeStyle: .roundedRectangle,
                            badgeIconName: "Premium/BoostButtonIcon",
                            combinedAlignment: true
                        ))
                    ),
                    isEnabled: true,
                    displaysProgress: self.item.isLoading,
                    action: { [weak self] in
                        guard let self else {
                            return
                        }
                        self.item.action()
                    }
                )
            ),
            environment: {},
            containerSize: CGSize(width: buttonWidth, height: 50.0)
        )
        if let view = self.button.view {
            if view.superview == nil {
                self.view.addSubview(view)
            }
            transition.updateFrame(view: view, frame: CGRect(origin: CGPoint(x: layout.safeInsets.left + buttonInset, y: panelFrame.minY + inset), size: buttonSize))
        }
        
        
        transition.updateFrame(node: self.backgroundNode, frame: panelFrame)
        self.backgroundNode.update(size: panelFrame.size, transition: transition)
        
        transition.updateFrame(node: self.separatorNode, frame: CGRect(origin: panelFrame.origin, size: CGSize(width: panelFrame.width, height: UIScreenPixel)))
        
        return totalPanelHeight
    }
    
    override func point(inside point: CGPoint, with event: UIEvent?) -> Bool {
        if self.backgroundNode.frame.contains(point) {
            return true
        } else {
            return false
        }
    }
}
