import Foundation
import UIKit
import AsyncDisplayKit
import Display
import TelegramPresentationData
import ItemListUI
import PresentationDataUtils
import ComponentFlow
import ButtonComponent
import EdgeEffect
import ComponentDisplayAdapters
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
    private let edgeEffectView = EdgeEffectView()
    private let button = ComponentView<Empty>()
    private let secondaryButton = ComponentView<Empty>()
    
    private var validLayout: ContainerViewLayout?
    
    var item: DeleteAccountFooterItem {
        didSet {
            if let layout = self.validLayout {
                let _ = self.updateLayout(layout: layout, transition: .immediate)
            }
        }
    }
    
    init(item: DeleteAccountFooterItem) {
        self.item = item
        
        super.init()
        
        self.view.addSubview(self.edgeEffectView)
    }
    
    override func updateBackgroundAlpha(_ alpha: CGFloat, transition: ContainedViewLayoutTransition) {
    }
    
    override func updateLayout(layout: ContainerViewLayout, transition: ContainedViewLayoutTransition) -> CGFloat {
        self.validLayout = layout
        
        let theme = self.item.theme
        let hasSecondaryButton = !self.item.title.isEmpty
        let insets = layout.insets(options: [.input])
        let isInputVisible = (layout.inputHeight ?? 0.0) > 0.0
        
        let buttonHeight: CGFloat = 52.0
        let buttonSpacing: CGFloat = 8.0
        let buttonInsets = ContainerViewLayout.concentricInsets(bottomInset: layout.intrinsicInsets.bottom, innerDiameter: buttonHeight, sideInset: 30.0)
        let buttonWidth = layout.size.width - layout.safeInsets.left - layout.safeInsets.right - buttonInsets.left - buttonInsets.right
        
        var buttonMaxY: CGFloat
        if isInputVisible {
            buttonMaxY = layout.size.height - insets.bottom - buttonSpacing
        } else {
            buttonMaxY = layout.size.height - buttonInsets.bottom
        }
        
        if hasSecondaryButton {
            let secondaryButtonSize = self.secondaryButton.update(
                transition: .immediate,
                component: AnyComponent(
                    ButtonComponent(
                        background: ButtonComponent.Background(
                            style: .glass,
                            color: theme.list.itemAccentColor.withMultipliedAlpha(0.1),
                            foreground: theme.list.itemAccentColor,
                            pressedColor: theme.list.itemAccentColor.withMultipliedAlpha(0.8)
                        ),
                        content: AnyComponentWithIdentity(
                            id: AnyHashable(self.item.secondaryTitle),
                            component: AnyComponent(Text(text: self.item.secondaryTitle, font: Font.semibold(17.0), color: theme.list.itemAccentColor))
                        ),
                        action: { [weak self] in
                            self?.item.secondaryAction()
                        }
                    )
                ),
                environment: {},
                containerSize: CGSize(width: buttonWidth, height: buttonHeight)
            )
            let secondaryButtonFrame = CGRect(origin: CGPoint(x: layout.safeInsets.left + buttonInsets.left, y: buttonMaxY - secondaryButtonSize.height), size: secondaryButtonSize)
            if let secondaryButtonView = self.secondaryButton.view {
                if secondaryButtonView.superview == nil {
                    self.view.addSubview(secondaryButtonView)
                }
                secondaryButtonView.isHidden = false
                transition.updateFrame(view: secondaryButtonView, frame: secondaryButtonFrame)
            }
            buttonMaxY = secondaryButtonFrame.minY - buttonSpacing
        } else {
            self.secondaryButton.view?.isHidden = true
        }
        
        let buttonTitle = hasSecondaryButton ? self.item.title : self.item.secondaryTitle
        let buttonSize = self.button.update(
            transition: .immediate,
            component: AnyComponent(
                ButtonComponent(
                    background: ButtonComponent.Background(
                        style: .glass,
                        color: theme.list.itemCheckColors.fillColor,
                        foreground: theme.list.itemCheckColors.foregroundColor,
                        pressedColor: theme.list.itemCheckColors.fillColor.withMultipliedAlpha(0.9)
                    ),
                    content: AnyComponentWithIdentity(
                        id: AnyHashable(buttonTitle),
                        component: AnyComponent(Text(text: buttonTitle, font: Font.semibold(17.0), color: theme.list.itemCheckColors.foregroundColor))
                    ),
                    action: { [weak self] in
                        guard let self else {
                            return
                        }
                        if self.item.title.isEmpty {
                            self.item.secondaryAction()
                        } else {
                            self.item.action()
                        }
                    }
                )
            ),
            environment: {},
            containerSize: CGSize(width: buttonWidth, height: buttonHeight)
        )
        let buttonFrame = CGRect(origin: CGPoint(x: layout.safeInsets.left + buttonInsets.left, y: buttonMaxY - buttonSize.height), size: buttonSize)
        if let buttonView = self.button.view {
            if buttonView.superview == nil {
                self.view.addSubview(buttonView)
            }
            transition.updateFrame(view: buttonView, frame: buttonFrame)
        }
        
        let height = layout.size.height - buttonFrame.minY
        
        let edgeEffectFrame = CGRect(origin: CGPoint(x: 0.0, y: buttonFrame.minY), size: CGSize(width: layout.size.width, height: height))
        transition.updateFrame(view: self.edgeEffectView, frame: edgeEffectFrame)
        self.edgeEffectView.update(
            content: theme.list.blocksBackgroundColor,
            blur: true,
            rect: edgeEffectFrame,
            edge: .bottom,
            edgeSize: min(edgeEffectFrame.height, buttonHeight + buttonInsets.bottom),
            transition: ComponentTransition(transition)
        )
        
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
