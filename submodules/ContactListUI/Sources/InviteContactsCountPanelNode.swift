import Foundation
import UIKit
import AsyncDisplayKit
import Display
import TelegramPresentationData
import ComponentFlow
import ButtonComponent
import AnimatedTextComponent
import EdgeEffect

final class InviteContactsCountPanelNode: ASDisplayNode {
    private let theme: PresentationTheme
    private let strings: PresentationStrings
    private let action: () -> Void
    
    private let edgeEffectView = EdgeEffectView()
    private let button = ComponentView<Empty>()
        
    private var validLayout: (CGFloat, CGFloat, CGFloat, CGFloat)?
    
    var count: Int = 0 {
        didSet {
            if self.count != oldValue && self.count > 0 {
                if let (width, leftInset, rightInset, bottomInset) = self.validLayout {
                    let _ = self.updateLayout(width: width, leftInset: leftInset, rightInset: rightInset, bottomInset: bottomInset, transition: .immediate)
                }
            }
        }
    }
    
    init(theme: PresentationTheme, strings: PresentationStrings, action: @escaping () -> Void) {
        self.theme = theme
        self.strings = strings
        self.action = action

        super.init()
    }
    
    func updateLayout(width: CGFloat, leftInset: CGFloat, rightInset: CGFloat, bottomInset: CGFloat, transition: ContainedViewLayoutTransition) -> CGFloat {
        self.validLayout = (width, leftInset, rightInset, bottomInset)
        
        let buttonInsets = ContainerViewLayout.concentricInsets(bottomInset: bottomInset, innerDiameter: 52.0, sideInset: 30.0)
        let height: CGFloat = 52.0 + buttonInsets.bottom
        
        let edgeEffectHeight: CGFloat = height
        let edgeEffectFrame = CGRect(origin: CGPoint(x: 0.0, y: 0.0), size: CGSize(width: width, height: edgeEffectHeight))
        transition.updateFrame(view: self.edgeEffectView, frame: edgeEffectFrame)
        self.edgeEffectView.update(
            content: self.theme.list.plainBackgroundColor,
            blur: true,
            rect: edgeEffectFrame,
            edge: .bottom,
            edgeSize: edgeEffectFrame.height,
            transition: ComponentTransition(transition)
        )
        if self.edgeEffectView.superview == nil {
            self.view.addSubview(self.edgeEffectView)
        }
        
        let buttonTransition: ComponentTransition = .easeInOut(duration: 0.2)
        let buttonSize = self.button.update(
            transition: buttonTransition,
            component: AnyComponent(
                ButtonComponent(
                    background: ButtonComponent.Background(
                        style: .glass,
                        color: self.theme.list.itemCheckColors.fillColor,
                        foreground: self.theme.list.itemCheckColors.foregroundColor,
                        pressedColor: self.theme.list.itemCheckColors.fillColor.withMultipliedAlpha(0.9)
                    ),
                    content: AnyComponentWithIdentity(
                        id: AnyHashable(0),
                        component: AnyComponent(AnimatedTextComponent(
                            font: Font.with(size: 17.0, weight: .semibold, traits: .monospacedNumbers),
                            color: self.theme.list.itemCheckColors.foregroundColor,
                            items: [AnimatedTextComponent.Item(id: "text", content: .text(self.strings.Contacts_InviteContacts(Int32(max(1, self.count)))))],
                            noDelay: true
                        ))
                    ),
                    isEnabled: true,
                    action: { [weak self] in
                        guard let self else {
                            return
                        }
                        self.action()
                    }
                )
            ),
            environment: {},
            containerSize: CGSize(width: width - leftInset - rightInset - buttonInsets.left - buttonInsets.right, height: 52.0)
        )
        let buttonFrame = CGRect(origin: CGPoint(x: leftInset + buttonInsets.left, y: 0.0), size: buttonSize)
        if let buttonView = self.button.view {
            if buttonView.superview == nil {
                self.view.addSubview(buttonView)
            }
            transition.updateFrame(view: buttonView, frame: buttonFrame)
        }
        return height
    }
}
