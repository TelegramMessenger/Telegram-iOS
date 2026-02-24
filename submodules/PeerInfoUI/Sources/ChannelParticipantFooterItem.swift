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
import SolidRoundedButtonNode

final class ChannelParticipantFooterItem: ItemListControllerFooterItem {
    let theme: PresentationTheme
    let title: String
    let displayProgress: Bool
    let action: () -> Void
    
    init(theme: PresentationTheme, title: String, displayProgress: Bool = false, action: @escaping () -> Void) {
        self.theme = theme
        self.title = title
        self.displayProgress = displayProgress
        self.action = action
    }
    
    func isEqual(to: ItemListControllerFooterItem) -> Bool {
        if let item = to as? ChannelParticipantFooterItem {
            return self.theme === item.theme && self.title == item.title && self.displayProgress == item.displayProgress
        } else {
            return false
        }
    }
    
    func node(current: ItemListControllerFooterItemNode?) -> ItemListControllerFooterItemNode {
        if let current = current as? ChannelParticipantFooterItemNode {
            current.item = self
            return current
        } else {
            return ChannelParticipantFooterItemNode(item: self)
        }
    }
}

final class ChannelParticipantFooterItemNode: ItemListControllerFooterItemNode {
    private let edgeEffectView = EdgeEffectView()
    private let button = ComponentView<Empty>()
    
    private var validLayout: ContainerViewLayout?
    
    var item: ChannelParticipantFooterItem {
        didSet {
            self.updateItem()
            if let layout = self.validLayout {
                let _ = self.updateLayout(layout: layout, transition: .immediate)
            }
        }
    }
    
    init(item: ChannelParticipantFooterItem) {
        self.item = item
        
        super.init()
        
        self.updateItem()
    }
    
    private func updateItem() {
        if let layout = self.validLayout {
            let _ = self.updateLayout(layout: layout, transition: .immediate)
        }
    }
    
    override func updateLayout(layout: ContainerViewLayout, transition: ContainedViewLayoutTransition) -> CGFloat {
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
        
        let buttonSize = self.button.update(
            transition: .immediate,
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
                        component: AnyComponent(Text(text: self.item.title, font: Font.semibold(17.0), color: self.item.theme.list.itemCheckColors.foregroundColor))
                    ),
                    displaysProgress: self.item.displayProgress,
                    action: { [weak self] in
                        self?.item.action()
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
