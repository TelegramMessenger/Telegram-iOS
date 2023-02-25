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

final class StoragePeerTypeItemComponent: Component {
    enum ActionType {
        case toggle
        case generic
    }
    
    let theme: PresentationTheme
    let iconName: String
    let title: String
    let subtitle: String?
    let value: String
    let hasNext: Bool
    let action: (View) -> Void
    
    init(
        theme: PresentationTheme,
        iconName: String,
        title: String,
        subtitle: String?,
        value: String,
        hasNext: Bool,
        action: @escaping (View) -> Void
    ) {
        self.theme = theme
        self.iconName = iconName
        self.title = title
        self.subtitle = subtitle
        self.value = value
        self.hasNext = hasNext
        self.action = action
    }
    
    static func ==(lhs: StoragePeerTypeItemComponent, rhs: StoragePeerTypeItemComponent) -> Bool {
        if lhs.theme !== rhs.theme {
            return false
        }
        if lhs.iconName != rhs.iconName {
            return false
        }
        if lhs.title != rhs.title {
            return false
        }
        if lhs.subtitle != rhs.subtitle {
            return false
        }
        if lhs.value != rhs.value {
            return false
        }
        if lhs.hasNext != rhs.hasNext {
            return false
        }
        return true
    }
    
    class View: HighlightTrackingButton {
        private let iconView: UIImageView
        private let title = ComponentView<Empty>()
        private var subtitle: ComponentView<Empty>?
        private let label = ComponentView<Empty>()
        private let separatorLayer: SimpleLayer
        private let arrowIconView: UIImageView
        
        private var component: StoragePeerTypeItemComponent?
        
        private var highlightBackgroundFrame: CGRect?
        private var highlightBackgroundLayer: SimpleLayer?
        
        var labelView: UIView? {
            return self.label.view
        }
        
        override init(frame: CGRect) {
            self.separatorLayer = SimpleLayer()
            self.iconView = UIImageView()
            self.arrowIconView = UIImageView()
            
            super.init(frame: frame)
            
            self.layer.addSublayer(self.separatorLayer)
            
            self.addSubview(self.iconView)
            self.addSubview(self.arrowIconView)
            
            self.highligthedChanged = { [weak self] isHighlighted in
                guard let self, let component = self.component, let highlightBackgroundFrame = self.highlightBackgroundFrame else {
                    return
                }
                
                if isHighlighted {
                    self.superview?.bringSubviewToFront(self)
                    
                    let highlightBackgroundLayer: SimpleLayer
                    if let current = self.highlightBackgroundLayer {
                        highlightBackgroundLayer = current
                    } else {
                        highlightBackgroundLayer = SimpleLayer()
                        self.highlightBackgroundLayer = highlightBackgroundLayer
                        self.layer.insertSublayer(highlightBackgroundLayer, above: self.separatorLayer)
                        highlightBackgroundLayer.backgroundColor = component.theme.list.itemHighlightedBackgroundColor.cgColor
                    }
                    highlightBackgroundLayer.frame = highlightBackgroundFrame
                    highlightBackgroundLayer.opacity = 1.0
                } else {
                    if let highlightBackgroundLayer = self.highlightBackgroundLayer {
                        self.highlightBackgroundLayer = nil
                        highlightBackgroundLayer.animateAlpha(from: 1.0, to: 0.0, duration: 0.25, removeOnCompletion: false, completion: { [weak highlightBackgroundLayer] _ in
                            highlightBackgroundLayer?.removeFromSuperlayer()
                        })
                    }
                }
            }
            self.addTarget(self, action: #selector(self.pressed), for: .touchUpInside)
        }
        
        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }
        
        @objc private func pressed() {
            guard let component = self.component else {
                return
            }
            component.action(self)
        }
        
        func setHasAssociatedMenu(_ hasAssociatedMenu: Bool) {
            let transition: Transition
            if hasAssociatedMenu {
                transition = .immediate
            } else {
                transition = .easeInOut(duration: 0.25)
            }
            if let view = self.label.view {
                transition.setAlpha(view: view, alpha: hasAssociatedMenu ? 0.5 : 1.0)
            }
            transition.setAlpha(view: self.arrowIconView, alpha: hasAssociatedMenu ? 0.5 : 1.0)
        }
        
        func update(component: StoragePeerTypeItemComponent, availableSize: CGSize, state: EmptyComponentState, environment: Environment<Empty>, transition: Transition) -> CGSize {
            let themeUpdated = self.component?.theme !== component.theme
            
            self.component = component
            
            let leftInset: CGFloat = 62.0
            let rightInset: CGFloat = 32.0
            
            var availableWidth: CGFloat = availableSize.width - leftInset - rightInset
            
            let labelSize = self.label.update(
                transition: transition,
                component: AnyComponent(Text(text: component.value, font: Font.regular(17.0), color: component.theme.list.itemSecondaryTextColor)),
                environment: {},
                containerSize: CGSize(width: availableWidth, height: 100.0)
            )
            availableWidth = max(1.0, availableWidth - labelSize.width - 4.0)
            
            let titleSize = self.title.update(
                transition: transition,
                component: AnyComponent(Text(text: component.title, font: Font.regular(17.0), color: component.theme.list.itemPrimaryTextColor)),
                environment: {},
                containerSize: CGSize(width: availableWidth, height: 100.0)
            )
            
            var subtitleSize: CGSize?
            if let subtitleValue = component.subtitle {
                let subtitle: ComponentView<Empty>
                if let current = self.subtitle {
                    subtitle = current
                } else {
                    subtitle = ComponentView()
                    self.subtitle = subtitle
                }
                
                let subtitleSizeValue = subtitle.update(
                    transition: transition,
                    component: AnyComponent(Text(text: subtitleValue, font: Font.regular(15.0), color: component.theme.list.itemSecondaryTextColor)),
                    environment: {},
                    containerSize: CGSize(width: availableWidth, height: 100.0)
                )
                subtitleSize = subtitleSizeValue
            } else {
                if let subtitle = self.subtitle {
                    self.subtitle = nil
                    subtitle.view?.removeFromSuperview()
                }
            }
            
            var height: CGFloat = 44.0
            if subtitleSize != nil {
                height = 60.0
            }
            
            let titleFrame: CGRect
            var subtitleFrame: CGRect?
            
            if let subtitleSize = subtitleSize {
                let spacing: CGFloat = 1.0
                let verticalSize: CGFloat = titleSize.height + subtitleSize.height + spacing
                
                titleFrame = CGRect(origin: CGPoint(x: leftInset, y: floor((height - verticalSize) / 2.0)), size: titleSize)
                subtitleFrame = CGRect(origin: CGPoint(x: leftInset, y: titleFrame.maxY + spacing), size: subtitleSize)
            } else {
                titleFrame = CGRect(origin: CGPoint(x: leftInset, y: floor((height - titleSize.height) / 2.0)), size: titleSize)
            }
            
            let labelFrame = CGRect(origin: CGPoint(x: availableSize.width - rightInset - labelSize.width, y: floor((height - labelSize.height) / 2.0)), size: labelSize)
            
            if let titleView = self.title.view {
                if titleView.superview == nil {
                    titleView.isUserInteractionEnabled = false
                    self.addSubview(titleView)
                }
                transition.setFrame(view: titleView, frame: titleFrame)
            }
            if let subtitleView = self.subtitle?.view, let subtitleFrame {
                if subtitleView.superview == nil {
                    subtitleView.isUserInteractionEnabled = false
                    self.addSubview(subtitleView)
                }
                transition.setFrame(view: subtitleView, frame: subtitleFrame)
            }
            if let labelView = self.label.view {
                if labelView.superview == nil {
                    labelView.isUserInteractionEnabled = false
                    self.addSubview(labelView)
                }
                transition.setFrame(view: labelView, frame: labelFrame)
            }
            
            if themeUpdated {
                self.separatorLayer.backgroundColor = component.theme.list.itemBlocksSeparatorColor.cgColor
                self.iconView.image = UIImage(bundleImageName: component.iconName)
                self.arrowIconView.image = PresentationResourcesItemList.disclosureOptionArrowsImage(component.theme)
            }
            
            if let image = self.iconView.image {
                transition.setFrame(view: self.iconView, frame: CGRect(origin: CGPoint(x: floor((leftInset - image.size.width) / 2.0), y: floor((height - image.size.height) / 2.0)), size: image.size))
            }
            if let image = self.arrowIconView.image {
                transition.setFrame(view: self.arrowIconView, frame: CGRect(origin: CGPoint(x: availableSize.width - rightInset + 5.0, y: floor((height - image.size.height) / 2.0)), size: image.size))
            }
            
            transition.setFrame(layer: self.separatorLayer, frame: CGRect(origin: CGPoint(x: leftInset, y: height), size: CGSize(width: availableSize.width - leftInset, height: UIScreenPixel)))
            transition.setAlpha(layer: self.separatorLayer, alpha: component.hasNext ? 1.0 : 0.0)
            
            self.highlightBackgroundFrame = CGRect(origin: CGPoint(), size: CGSize(width: availableSize.width, height: height + (component.hasNext ? UIScreenPixel : 0.0)))
            
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
