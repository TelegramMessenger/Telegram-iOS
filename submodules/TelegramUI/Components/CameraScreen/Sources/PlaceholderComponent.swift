import Foundation
import UIKit
import Display
import ComponentFlow
import SwiftSignalKit
import TelegramCore
import AccountContext
import BundleIconComponent
import MultilineTextComponent
import ButtonComponent
import LottieComponent

final class PlaceholderComponent: Component {
    typealias EnvironmentType = Empty
    
    enum Mode {
        case request
        case denied
    }
    
    let context: AccountContext
    let mode: Mode
    let action: () -> Void
    
    init(
        context: AccountContext,
        mode: Mode,
        action: @escaping () -> Void
    ) {
        self.context = context
        self.mode = mode
        self.action = action
    }
    
    static func ==(lhs: PlaceholderComponent, rhs: PlaceholderComponent) -> Bool {
        if lhs.context !== rhs.context {
            return false
        }
        if lhs.mode != rhs.mode {
            return false
        }
        return true
    }
    
    public final class View: UIView {
        private let animation = ComponentView<Empty>()
        private let title = ComponentView<Empty>()
        private let text = ComponentView<Empty>()
        private let button = ComponentView<Empty>()
                
        private var component: PlaceholderComponent?
        private weak var state: EmptyComponentState?
        
        override init(frame: CGRect) {
            super.init(frame: frame)
            
            self.backgroundColor = UIColor(rgb: 0x1c1c1e)
        }
        
        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }
        
        func update(component: PlaceholderComponent, availableSize: CGSize, state: EmptyComponentState, environment: Environment<Empty>, transition: Transition) -> CGSize {
            self.component = component
            self.state = state
            
            let sideInset: CGFloat = 36.0
            let animationHeight: CGFloat = 120.0
            
            let presentationData = component.context.sharedContext.currentPresentationData.with { $0 }
            let title = presentationData.strings.Story_Camera_AccessPlaceholderTitle
            let text = presentationData.strings.Story_Camera_AccessPlaceholderText
            let buttonTitle = presentationData.strings.Story_Camera_AccessOpenSettings
            
            let animationSize = self.animation.update(
                transition: .immediate,
                component: AnyComponent(LottieComponent(
                    content: LottieComponent.AppBundleContent(name: "Photos")
                )),
                environment: {},
                containerSize: CGSize(width: animationHeight, height: animationHeight)
            )
            
            let titleSize = self.title.update(
                transition: .immediate,
                component: AnyComponent(
                    MultilineTextComponent(
                        text: .plain(NSAttributedString(string: title, font: Font.semibold(17.0), textColor: UIColor.white)),
                        horizontalAlignment: .center,
                        maximumNumberOfLines: 0
                    )
                ),
                environment: {},
                containerSize: CGSize(width: availableSize.width - sideInset * 3.0, height: availableSize.height)
            )
            
            let textSize = self.text.update(
                transition: .immediate,
                component: AnyComponent(
                    MultilineTextComponent(
                        text: .plain(NSAttributedString(string: text, font: Font.regular(15.0), textColor: UIColor(rgb: 0x98989f))),
                        horizontalAlignment: .center,
                        maximumNumberOfLines: 0
                    )
                ),
                environment: {},
                containerSize: CGSize(width: availableSize.width - sideInset * 2.0, height: availableSize.height)
            )
            
            let buttonSize = self.button.update(
                transition: .immediate,
                component: AnyComponent(
                    ButtonComponent(
                        background: ButtonComponent.Background(
                            color: UIColor(rgb: 0x007aff),
                            foreground: .white,
                            pressedColor: UIColor(rgb: 0x007aff, alpha: 0.55)
                        ),
                        content: AnyComponentWithIdentity(
                            id: buttonTitle,
                            component: AnyComponent(ButtonTextContentComponent(
                                text: buttonTitle,
                                badge: 0,
                                textColor: .white,
                                badgeBackground: .clear,
                                badgeForeground: .clear
                            ))
                        ),
                        isEnabled: true,
                        displaysProgress: false,
                        action: { [weak self] in
                            if let self {
                                self.component?.action()
                            }
                        }
                    )
                ),
                environment: {},
                containerSize: CGSize(width: 240.0, height: 50.0)
            )
            
            let titleSpacing: CGFloat = 12.0
            let textSpacing: CGFloat = 14.0
            let buttonSpacing: CGFloat = 18.0
            let totalHeight = animationSize.height + titleSpacing + titleSize.height + textSpacing + textSize.height + buttonSpacing + buttonSize.height
            
            var originY = floorToScreenPixels((availableSize.height - totalHeight) / 2.0)
            let animationFrame = CGRect(
                origin: CGPoint(
                    x: floorToScreenPixels((availableSize.width - animationSize.width) / 2.0),
                    y: originY
                ),
                size: animationSize
            )
            if let view = self.animation.view as? LottieComponent.View {
                if view.superview == nil {
                    self.addSubview(view)
                    Queue.mainQueue().justDispatch {
                        view.playOnce()
                    }
                }
                view.frame = animationFrame
            }
            originY += animationSize.height + titleSpacing
            
            let titleFrame = CGRect(
                origin: CGPoint(
                    x: floorToScreenPixels((availableSize.width - titleSize.width) / 2.0),
                    y: originY
                ),
                size: titleSize
            )
            if let view = self.title.view {
                if view.superview == nil {
                    self.addSubview(view)
                }
                view.frame = titleFrame
            }
            originY += titleSize.height + textSpacing
            
            let textFrame = CGRect(
                origin: CGPoint(
                    x: floorToScreenPixels((availableSize.width - textSize.width) / 2.0),
                    y: originY
                ),
                size: textSize
            )
            if let view = self.text.view {
                if view.superview == nil {
                    self.addSubview(view)
                }
                view.frame = textFrame
            }
            originY += textSize.height + buttonSpacing
            
            let buttonFrame = CGRect(
                origin: CGPoint(
                    x: floorToScreenPixels((availableSize.width - buttonSize.width) / 2.0),
                    y: originY
                ),
                size: buttonSize
            )
            if let view = self.button.view {
                if view.superview == nil {
                    self.addSubview(view)
                }
                view.frame = buttonFrame
            }
           
            return availableSize
        }
    }
    
    func makeView() -> View {
        return View()
    }
    
    public func update(view: View, availableSize: CGSize, state: EmptyComponentState, environment: Environment<Empty>, transition: Transition) -> CGSize {
        return view.update(component: self, availableSize: availableSize, state: state, environment: environment, transition: transition)
    }
}
