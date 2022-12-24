import Foundation
import UIKit
import Display
import AsyncDisplayKit
import ComponentFlow
import SwiftSignalKit
import ViewControllerComponent
import ComponentDisplayAdapters
import TelegramPresentationData
import AccountContext
import TelegramCore
import MultilineTextComponent
import EmojiStatusComponent
import Postbox
import TelegramStringFormatting
import CheckNode
import SolidRoundedButtonComponent

final class StorageUsageScreenSelectionPanelComponent: Component {
    let theme: PresentationTheme
    let title: String
    let label: String?
    let isEnabled: Bool
    let insets: UIEdgeInsets
    let action: () -> Void
    
    init(
        theme: PresentationTheme,
        title: String,
        label: String?,
        isEnabled: Bool,
        insets: UIEdgeInsets,
        action: @escaping () -> Void
    ) {
        self.theme = theme
        self.title = title
        self.label = label
        self.isEnabled = isEnabled
        self.insets = insets
        self.action = action
    }
    
    static func ==(lhs: StorageUsageScreenSelectionPanelComponent, rhs: StorageUsageScreenSelectionPanelComponent) -> Bool {
        if lhs.theme !== rhs.theme {
            return false
        }
        if lhs.title != rhs.title {
            return false
        }
        if lhs.label != rhs.label {
            return false
        }
        if lhs.isEnabled != rhs.isEnabled {
            return false
        }
        if lhs.insets != rhs.insets {
            return false
        }
        return true
    }
    
    class View: UIView {
        private let backgroundView: BlurredBackgroundView
        private let separatorLayer: SimpleLayer
        private let actionButton = ComponentView<Empty>()
        
        private var component: StorageUsageScreenSelectionPanelComponent?
        
        override init(frame: CGRect) {
            self.backgroundView = BlurredBackgroundView(color: nil, enableBlur: true)
            self.separatorLayer = SimpleLayer()
            
            super.init(frame: frame)
            
            self.addSubview(self.backgroundView)
            self.layer.addSublayer(self.separatorLayer)
        }
        
        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }
        
        func update(component: StorageUsageScreenSelectionPanelComponent, availableSize: CGSize, state: EmptyComponentState, environment: Environment<Empty>, transition: Transition) -> CGSize {
            let themeUpdated = self.component?.theme !== component.theme
            self.component = component
            
            let topInset: CGFloat = 8.0
            
            let bottomInset: CGFloat
            if component.insets.bottom == 0.0 {
                bottomInset = topInset
            } else {
                bottomInset = component.insets.bottom + 10.0
            }
            
            let height: CGFloat = topInset + 50.0 + bottomInset

            if themeUpdated {
                self.backgroundView.updateColor(color: component.theme.rootController.navigationBar.blurredBackgroundColor, transition: .immediate)
                self.separatorLayer.backgroundColor = component.theme.rootController.navigationBar.separatorColor.cgColor
            }
            
            
            let backgroundFrame = CGRect(origin: CGPoint(x: 0.0, y: 0.0), size: CGSize(width: availableSize.width, height: height))
            transition.setFrame(view: self.backgroundView, frame: backgroundFrame)
            self.backgroundView.update(size: backgroundFrame.size, transition: transition.containedViewLayoutTransition)
            
            transition.setFrame(layer: self.separatorLayer, frame: CGRect(origin: CGPoint(x: 0.0, y: -UIScreenPixel), size: CGSize(width: availableSize.width, height: UIScreenPixel)))
            
            let actionButtonSize = self.actionButton.update(
                transition: transition,
                component: AnyComponent(SolidRoundedButtonComponent(
                    title: component.title,
                    label: component.label,
                    theme: SolidRoundedButtonComponent.Theme(
                        backgroundColor: component.theme.list.itemCheckColors.fillColor,
                        backgroundColors: [],
                        foregroundColor: component.theme.list.itemCheckColors.foregroundColor
                    ),
                    font: .bold,
                    fontSize: 17.0,
                    height: 50.0,
                    cornerRadius: 10.0,
                    gloss: false,
                    isEnabled: component.isEnabled,
                    animationName: nil,
                    iconPosition: .right,
                    iconSpacing: 4.0,
                    action: { [weak self] in
                        guard let self else {
                            return
                        }
                        self.component?.action()
                    }
                )),
                environment: {},
                containerSize: CGSize(width: availableSize.width - component.insets.left - component.insets.right, height: 50.0)
            )
            if let actionButtonView = self.actionButton.view {
                if actionButtonView.superview == nil {
                    self.addSubview(actionButtonView)
                }
                transition.setFrame(view: actionButtonView, frame: CGRect(origin: CGPoint(x: component.insets.left, y: topInset), size: actionButtonSize))
            }
            
            return CGSize(width: availableSize.width, height: height)
        }
    }
    
    func makeView() -> View {
        return View(frame: CGRect())
    }
    
    func update(view: View, availableSize: CGSize, state: EmptyComponentState, environment: Environment<Empty>, transition: Transition) -> CGSize {
        return view.update(component: self, availableSize: availableSize, state: state, environment: environment, transition: transition)
    }
}
