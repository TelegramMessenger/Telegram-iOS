import Foundation
import UIKit
import AsyncDisplayKit
import Display
import ComponentFlow
import TelegramPresentationData
import ItemListUI
import PresentationDataUtils
import ButtonComponent
import EdgeEffect

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
    private let edgeEffectView = EdgeEffectView()
    private let button = ComponentView<Empty>()

    private var validLayout: ContainerViewLayout?
    
    private var currentIsLoading = false
    var item: CreateGiveawayFooterItem {
        didSet {
            if let layout = self.validLayout {
                let _ = self.updateLayout(layout: layout, transition: .immediate)
            }
        }
    }
    
    init(item: CreateGiveawayFooterItem) {
        self.item = item
                
        super.init()
    }
        
    override func updateBackgroundAlpha(_ alpha: CGFloat, transition: ContainedViewLayoutTransition) {
    }
    
    override func updateLayout(layout: ContainerViewLayout, transition: ContainedViewLayoutTransition) -> CGFloat {
        let hadLayout = self.validLayout != nil
        self.validLayout = layout
        
        let buttonInsets = ContainerViewLayout.concentricInsets(bottomInset: layout.intrinsicInsets.bottom, innerDiameter: 52.0, sideInset: 30.0)
        let height: CGFloat = 52.0 + buttonInsets.bottom
        
        let edgeEffectHeight: CGFloat = height
        let edgeEffectFrame = CGRect(origin: CGPoint(x: 0.0, y: layout.size.height - edgeEffectHeight), size: CGSize(width: layout.size.width, height: edgeEffectHeight))
        transition.updateFrame(view: self.edgeEffectView, frame: edgeEffectFrame)
        self.edgeEffectView.update(
            content: self.item.theme.list.plainBackgroundColor,
            blur: true,
            rect: edgeEffectFrame,
            edge: .bottom,
            edgeSize: edgeEffectFrame.height,
            transition: ComponentTransition(transition)
        )
        if self.edgeEffectView.superview == nil {
            self.view.addSubview(self.edgeEffectView)
        }
        
        var buttonTransition: ComponentTransition = .easeInOut(duration: 0.2)
        if !hadLayout {
            buttonTransition = .immediate
        }
        let buttonSize = self.button.update(
            transition: buttonTransition,
            component: AnyComponent(
                ButtonComponent(
                    background: ButtonComponent.Background(
                        style: .glass,
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
            containerSize: CGSize(width: layout.size.width - layout.safeInsets.left - layout.safeInsets.right - buttonInsets.left - buttonInsets.right, height: 52.0)
        )
        let buttonFrame = CGRect(origin: CGPoint(x: layout.safeInsets.left + buttonInsets.left, y: layout.size.height - buttonInsets.bottom - buttonSize.height), size: buttonSize)
        if let buttonView = self.button.view {
            if buttonView.superview == nil {
                self.view.addSubview(buttonView)
            }
            transition.updateFrame(view: buttonView, frame: buttonFrame)
        }
        
        return height
    }
    
    override func point(inside point: CGPoint, with event: UIEvent?) -> Bool {
        if self.edgeEffectView.frame.contains(point) {
            return true
        } else {
            return false
        }
    }
}
