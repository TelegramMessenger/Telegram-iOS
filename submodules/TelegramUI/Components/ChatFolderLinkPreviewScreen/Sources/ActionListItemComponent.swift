import Foundation
import UIKit
import Display
import AsyncDisplayKit
import ComponentFlow
import MultilineTextComponent
import TelegramPresentationData

final class ActionListItemComponent: Component {
    let theme: PresentationTheme
    let sideInset: CGFloat
    let iconName: String?
    let title: String
    let hasNext: Bool
    let action: () -> Void
    
    init(
        theme: PresentationTheme,
        sideInset: CGFloat,
        iconName: String?,
        title: String,
        hasNext: Bool,
        action: @escaping () -> Void
    ) {
        self.theme = theme
        self.sideInset = sideInset
        self.iconName = iconName
        self.title = title
        self.hasNext = hasNext
        self.action = action
    }
    
    static func ==(lhs: ActionListItemComponent, rhs: ActionListItemComponent) -> Bool {
        if lhs.theme !== rhs.theme {
            return false
        }
        if lhs.sideInset != rhs.sideInset {
            return false
        }
        if lhs.iconName != rhs.iconName {
            return false
        }
        if lhs.title != rhs.title {
            return false
        }
        if lhs.hasNext != rhs.hasNext {
            return false
        }
        return true
    }
    
    final class View: UIView {
        private let containerButton: HighlightTrackingButton
        
        private let title = ComponentView<Empty>()
        private let iconView: UIImageView
        private let separatorLayer: SimpleLayer
        
        private var highlightBackgroundFrame: CGRect?
        private var highlightBackgroundLayer: SimpleLayer?
        
        private var component: ActionListItemComponent?
        private weak var state: EmptyComponentState?
        
        override init(frame: CGRect) {
            self.separatorLayer = SimpleLayer()
            
            self.containerButton = HighlightTrackingButton()
            
            self.iconView = UIImageView()
            
            super.init(frame: frame)
            
            self.layer.addSublayer(self.separatorLayer)
            self.addSubview(self.containerButton)
            
            self.containerButton.addSubview(self.iconView)
            
            self.containerButton.highligthedChanged = { [weak self] isHighlighted in
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
            self.containerButton.addTarget(self, action: #selector(self.pressed), for: .touchUpInside)
        }
        
        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }
        
        @objc private func pressed() {
            guard let component = self.component else {
                return
            }
            component.action()
        }
        
        func update(component: ActionListItemComponent, availableSize: CGSize, state: EmptyComponentState, environment: Environment<Empty>, transition: Transition) -> CGSize {
            let themeUpdated = self.component?.theme !== component.theme
            
            if self.component?.iconName != component.iconName {
                if let iconName = component.iconName {
                    self.iconView.image = UIImage(bundleImageName: iconName)?.withRenderingMode(.alwaysTemplate)
                } else {
                    self.iconView.image = nil
                }
            }
            if themeUpdated {
                self.iconView.tintColor = component.theme.list.itemAccentColor
            }
            
            self.component = component
            self.state = state
            
            let contextInset: CGFloat = 0.0
            
            let height: CGFloat = 44.0
            let verticalInset: CGFloat = 1.0
            let leftInset: CGFloat = 62.0 + component.sideInset
            let rightInset: CGFloat = contextInset * 2.0 + 8.0 + component.sideInset
            
            let previousTitleFrame = self.title.view?.frame
            
            let titleSize = self.title.update(
                transition: .immediate,
                component: AnyComponent(MultilineTextComponent(
                    text: .plain(NSAttributedString(string: component.title, font: Font.regular(17.0), textColor: component.theme.list.itemAccentColor))
                )),
                environment: {},
                containerSize: CGSize(width: availableSize.width - leftInset - rightInset, height: 100.0)
            )
            
            let centralContentHeight: CGFloat = titleSize.height
            
            let titleFrame = CGRect(origin: CGPoint(x: leftInset, y: floor((height - verticalInset * 2.0 - centralContentHeight) / 2.0)), size: titleSize)
            if let titleView = self.title.view {
                if titleView.superview == nil {
                    titleView.isUserInteractionEnabled = false
                    self.containerButton.addSubview(titleView)
                }
                titleView.frame = titleFrame
                if let previousTitleFrame, previousTitleFrame.origin.x != titleFrame.origin.x {
                    transition.animatePosition(view: titleView, from: CGPoint(x: previousTitleFrame.origin.x - titleFrame.origin.x, y: 0.0), to: CGPoint(), additive: true)
                }
            }
            
            if let iconImage = self.iconView.image {
                transition.setFrame(view: self.iconView, frame: CGRect(origin: CGPoint(x: floor((leftInset - iconImage.size.width) / 2.0), y: floor((height - iconImage.size.height) / 2.0)), size: iconImage.size))
            }
            
            if themeUpdated {
                self.separatorLayer.backgroundColor = component.theme.list.itemPlainSeparatorColor.cgColor
            }
            transition.setFrame(layer: self.separatorLayer, frame: CGRect(origin: CGPoint(x: leftInset, y: height), size: CGSize(width: availableSize.width - leftInset, height: UIScreenPixel)))
            self.separatorLayer.isHidden = !component.hasNext
            
            self.highlightBackgroundFrame = CGRect(origin: CGPoint(), size: CGSize(width: availableSize.width, height: height + ((component.hasNext) ? UIScreenPixel : 0.0)))
            
            let containerFrame = CGRect(origin: CGPoint(x: contextInset, y: verticalInset), size: CGSize(width: availableSize.width - contextInset * 2.0, height: height - verticalInset * 2.0))
            transition.setFrame(view: self.containerButton, frame: containerFrame)
            
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
