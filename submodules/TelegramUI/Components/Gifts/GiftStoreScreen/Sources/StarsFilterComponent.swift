import Foundation
import UIKit
import Display
import ComponentFlow
import SwiftSignalKit
import PlainButtonComponent
import MultilineTextComponent
import BundleIconComponent
import TextFormat
import AccountContext
import TelegramPresentationData
import GlassBackgroundComponent
import CheckComponent

final class StarsFilterComponent: Component {
    let theme: PresentationTheme
    let text: String
    let isSelected: Bool
    let selectionUpdated: (Bool) -> Void
    
    init(
        theme: PresentationTheme,
        text: String,
        isSelected: Bool,
        selectionUpdated: @escaping (Bool) -> Void
    ) {
        self.theme = theme
        self.text = text
        self.isSelected = isSelected
        self.selectionUpdated = selectionUpdated
    }
    
    static func ==(lhs: StarsFilterComponent, rhs: StarsFilterComponent) -> Bool {
        if lhs.theme !== rhs.theme {
            return false
        }
        if lhs.text != rhs.text {
            return false
        }
        if lhs.isSelected != rhs.isSelected {
            return false
        }
        return true
    }
    
    final class View: UIView {
        private let backgroundView = GlassBackgroundView()
        private let button = HighlightTrackingButton()
        
        private let check = ComponentView<Empty>()
        private let text = ComponentView<Empty>()
        
        private var component: StarsFilterComponent?
        private weak var state: EmptyComponentState?
                
        override init(frame: CGRect) {
            super.init(frame: frame)
            
            self.addSubview(self.backgroundView)
            self.backgroundView.contentView.addSubview(self.button)
            
            self.button.addTarget(self, action: #selector(self.buttonPressed), for: .touchUpInside)
        }
        
        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }
        
        @objc private func buttonPressed() {
            guard let component = self.component else {
                return
            }
            component.selectionUpdated(!component.isSelected)
        }
        
        func update(component: StarsFilterComponent, availableSize: CGSize, state: EmptyComponentState, environment: Environment<Empty>, transition: ComponentTransition) -> CGSize {
            self.component = component
            self.state = state
            
            let inset: CGFloat = 16.0
            
            let textSize = self.text.update(
                transition: .immediate,
                component: AnyComponent(
                    Text(text: component.text, font: Font.regular(17.0), color: component.theme.list.itemPrimaryTextColor)
                ),
                environment: {},
                containerSize: CGSize(width: availableSize.width - 44.0, height: 52.0)
            )
            
            let checkTheme = CheckComponent.Theme(
                backgroundColor: component.theme.list.itemCheckColors.fillColor,
                strokeColor: component.theme.list.itemCheckColors.foregroundColor,
                borderColor: component.theme.list.itemCheckColors.strokeColor,
                overlayBorder: false,
                hasInset: false,
                hasShadow: false
            )
            let checkSize = self.check.update(
                transition: .immediate,
                component: AnyComponent(
                    CheckComponent(theme: checkTheme, selected: component.isSelected)
                ),
                environment: {},
                containerSize: CGSize(width: 22.0, height: 22.0)
            )
            
            let size = CGSize(width: inset + checkSize.width + inset + textSize.width + inset + 6.0, height: 52.0)
            
            let textFrame = CGRect(origin: CGPoint(x: inset + checkSize.width + inset, y: floorToScreenPixels((size.height - textSize.height) / 2.0)), size: textSize)
            if let textView = self.text.view {
                if textView.superview == nil {
                    self.backgroundView.contentView.addSubview(textView)
                    textView.isUserInteractionEnabled = false
                }
                transition.setFrame(view: textView, frame: textFrame)
            }
 
            let checkFrame = CGRect(origin: CGPoint(x: inset, y: floorToScreenPixels((size.height - checkSize.height) / 2.0)), size: checkSize)
            if let checkView = self.check.view {
                if checkView.superview == nil {
                    self.backgroundView.contentView.addSubview(checkView)
                    checkView.isUserInteractionEnabled = false
                }
                transition.setFrame(view: checkView, frame: checkFrame)
            }
                        
            self.button.frame = CGRect(origin: .zero, size: size)
            transition.setFrame(view: self.backgroundView, frame: CGRect(origin: .zero, size: size))
            self.backgroundView.update(size: size, cornerRadius: size.height * 0.5, isDark: component.theme.overallDarkAppearance, tintColor: .init(kind: .panel), isInteractive: true, transition: transition)
            
            return size
        }
    }
    
    public func makeView() -> View {
        return View(frame: CGRect())
    }
    
    public func update(view: View, availableSize: CGSize, state: EmptyComponentState, environment: Environment<Empty>, transition: ComponentTransition) -> CGSize {
        return view.update(component: self, availableSize: availableSize, state: state, environment: environment, transition: transition)
    }
}
