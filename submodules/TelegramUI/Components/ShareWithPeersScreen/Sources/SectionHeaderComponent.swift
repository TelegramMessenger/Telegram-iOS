import Foundation
import UIKit
import Display
import ComponentFlow
import TelegramPresentationData
import MultilineTextComponent

final class SectionHeaderComponent: Component {
    let theme: PresentationTheme
    let style: ShareWithPeersScreenComponent.Style
    let title: String
    let actionTitle: String?
    let action: (() -> Void)?
    
    init(
        theme: PresentationTheme,
        style: ShareWithPeersScreenComponent.Style,
        title: String,
        actionTitle: String?,
        action: (() -> Void)?
    ) {
        self.theme = theme
        self.style = style
        self.title = title
        self.actionTitle = actionTitle
        self.action = action
    }
    
    static func ==(lhs: SectionHeaderComponent, rhs: SectionHeaderComponent) -> Bool {
        if lhs.theme !== rhs.theme {
            return false
        }
        if lhs.style != rhs.style {
            return false
        }
        if lhs.title != rhs.title {
            return false
        }
        if lhs.actionTitle != rhs.actionTitle {
            return false
        }
        return true
    }
    
    final class View: UIView {        
        private let title = ComponentView<Empty>()
        private let backgroundView: BlurredBackgroundView
        private let action = ComponentView<Empty>()
        
        private var component: SectionHeaderComponent?
        private weak var state: EmptyComponentState?
        
        override init(frame: CGRect) {            
            self.backgroundView = BlurredBackgroundView(color: .clear, enableBlur: true)
            
            super.init(frame: frame)
            
            self.addSubview(self.backgroundView)
        }
        
        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }
        
        func update(component: SectionHeaderComponent, availableSize: CGSize, state: EmptyComponentState, environment: Environment<Empty>, transition: Transition) -> CGSize {
            let themeUpdated = self.component?.theme !== component.theme
            
            self.component = component
            self.state = state
            
            let height: CGFloat = 28.0
            let leftInset: CGFloat = 16.0
            let rightInset: CGFloat = 0.0
            
            let previousTitleFrame = self.title.view?.frame
            
            if themeUpdated {
                switch component.style {
                case .plain:
                    self.backgroundView.isHidden = false
                    self.backgroundView.updateColor(color: component.theme.rootController.navigationBar.blurredBackgroundColor, transition: .immediate)
                case .blocks:
                    self.backgroundView.isHidden = true
                }
            }
            
            let titleSize = self.title.update(
                transition: .immediate,
                component: AnyComponent(MultilineTextComponent(
                    text: .plain(NSAttributedString(string: component.title, font: Font.regular(13.0), textColor: component.theme.list.itemSecondaryTextColor))
                )),
                environment: {},
                containerSize: CGSize(width: availableSize.width - leftInset - rightInset, height: 100.0)
            )
            
            let titleFrame = CGRect(origin: CGPoint(x: leftInset, y: floor((height - titleSize.height) / 2.0)), size: titleSize)
            if let titleView = self.title.view {
                if titleView.superview == nil {
                    titleView.isUserInteractionEnabled = false
                    self.addSubview(titleView)
                }
                titleView.frame = titleFrame
                if let previousTitleFrame, previousTitleFrame.origin.x != titleFrame.origin.x {
                    transition.animatePosition(view: titleView, from: CGPoint(x: previousTitleFrame.origin.x - titleFrame.origin.x, y: 0.0), to: CGPoint(), additive: true)
                }
            }
            
            if let actionTitle = component.actionTitle {
                let actionSize = self.action.update(
                    transition: .immediate,
                    component: AnyComponent(
                        Button(content: AnyComponent(MultilineTextComponent(
                            text: .plain(NSAttributedString(string: actionTitle, font: Font.regular(13.0), textColor: component.theme.list.itemSecondaryTextColor))
                        )), action: { [weak self] in
                            if let self, let component = self.component {
                                component.action?()
                            }
                        })
                    ),
                    environment: {},
                    containerSize: CGSize(width: availableSize.width - leftInset - rightInset, height: 100.0)
                )
                if let view = self.action.view {
                    if view.superview == nil {
                        self.addSubview(view)
                        if !transition.animation.isImmediate {
                            view.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.2)
                            view.layer.animateScale(from: 0.01, to: 1.0, duration: 0.2)
                        }
                    }
                    let actionFrame = CGRect(origin: CGPoint(x: availableSize.width - leftInset - actionSize.width, y: floor((height - titleSize.height) / 2.0)), size: actionSize)
                    view.frame = actionFrame
                }
            } else if let view = self.action.view, view.superview != nil {
                if !transition.animation.isImmediate {
                    view.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.2, removeOnCompletion: false, completion: { finished in
                        if finished {
                            view.removeFromSuperview()
                            view.layer.removeAllAnimations()
                        }
                    })
                    view.layer.animateScale(from: 1.0, to: 0.01, duration: 0.2, removeOnCompletion: false)
                } else {
                    view.removeFromSuperview()
                }
            }
            
            let size = CGSize(width: availableSize.width, height: height)
            
            transition.setFrame(view: self.backgroundView, frame: CGRect(origin: CGPoint(), size: size))
            self.backgroundView.update(size: size, transition: transition.containedViewLayoutTransition)
            
            return size
        }
    }
    
    func makeView() -> View {
        return View(frame: CGRect())
    }
    
    func update(view: View, availableSize: CGSize, state: EmptyComponentState, environment: Environment<Empty>, transition: Transition) -> CGSize {
        return view.update(component: self, availableSize: availableSize, state: state, environment: environment, transition: transition)
    }
}
