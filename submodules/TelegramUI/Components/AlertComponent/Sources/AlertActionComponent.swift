import Foundation
import UIKit
import AsyncDisplayKit
import Display
import ComponentFlow
import SwiftSignalKit
import AccountContext
import TelegramPresentationData
import MultilineTextComponent
import GlassBackgroundComponent
import ActivityIndicatorComponent

private let titleFont = Font.medium(17.0)
private let boldTitleFont = Font.semibold(17.0)

final class AlertActionComponent: Component {
    typealias EnvironmentType = AlertComponentEnvironment
    
    static let actionHeight: CGFloat = 48.0
    
    struct Theme: Equatable {
        enum Font {
            case regular
            case bold
        }
        
        let background: UIColor
        let foreground: UIColor
        let secondary: UIColor
        let font: Font
    }
    
    let theme: Theme
    let title: String
    let isHighlighted: Bool
    let isEnabled: Signal<Bool, NoError>
    let progress: Signal<Bool, NoError>
    
    init(
        theme: Theme,
        title: String,
        isHighlighted: Bool,
        isEnabled: Signal<Bool, NoError>,
        progress: Signal<Bool, NoError>
    ) {
        self.theme = theme
        self.title = title
        self.isHighlighted = isHighlighted
        self.isEnabled = isEnabled
        self.progress = progress
    }
    
    static func ==(lhs: AlertActionComponent, rhs: AlertActionComponent) -> Bool {
        if lhs.theme != rhs.theme {
            return false
        }
        if lhs.title != rhs.title {
            return false
        }
        if lhs.isHighlighted != rhs.isHighlighted {
            return false
        }
        return true
    }
    
    final class View: UIView {
        private let backgroundView = UIView()
        private let title = ComponentView<Empty>()
        private var activity: ComponentView<Empty>?
                
        private var component: AlertActionComponent?
        private weak var state: EmptyComponentState?
        
        private var isEnabledDisposable: Disposable?
        private var isEnabled = true
        
        private var progressDisposable: Disposable?
        private var hasProgress = false
        
        private var isUpdating = false
                
        override init(frame: CGRect) {
            super.init(frame: frame)
            
            self.backgroundView.clipsToBounds = true
            self.addSubview(self.backgroundView)
        }
        
        required init?(coder: NSCoder) {
            preconditionFailure()
        }
        
        deinit {
            self.isEnabledDisposable?.dispose()
            self.progressDisposable?.dispose()
        }
        
        func update(component: AlertActionComponent, availableSize: CGSize, state: EmptyComponentState, environment: Environment<AlertComponentEnvironment>, transition: ComponentTransition) -> CGSize {
            self.isUpdating = true
            defer {
                self.isUpdating = false
            }
            if self.component == nil {
                self.isEnabledDisposable = (component.isEnabled
                |> deliverOnMainQueue).start(next: { [weak self] isEnabled in
                    guard let self else {
                        return
                    }
                    self.isEnabled = isEnabled
                    if !self.isUpdating {
                        self.state?.updated(transition: .easeInOut(duration: 0.25))
                    }
                })
                
                self.progressDisposable = (component.progress
                |> deliverOnMainQueue).start(next: { [weak self] hasProgress in
                    guard let self else {
                        return
                    }
                    self.hasProgress = hasProgress
                    if !self.isUpdating {
                        self.state?.updated(transition: .easeInOut(duration: 0.25))
                    }
                })
            }
            self.component = component
            self.state = state
            
            let attributedString = NSMutableAttributedString(string: component.title, font: component.theme.font == .bold ? boldTitleFont : titleFont, textColor: .white, paragraphAlignment: .center)
            if let range = attributedString.string.range(of: "$") {
                attributedString.addAttribute(.attachment, value: UIImage(bundleImageName: "Item List/PremiumIcon")!, range: NSRange(range, in: attributedString.string))
                attributedString.addAttribute(.foregroundColor, value: UIColor.white, range: NSRange(range, in: attributedString.string))
                attributedString.addAttribute(.baselineOffset, value: 2.0, range: NSRange(range, in: attributedString.string))
            }
                  
            let titlePadding: CGFloat = 16.0
            let titleSize = self.title.update(
                transition: .immediate,
                component: AnyComponent(MultilineTextComponent(
                    text: .plain(attributedString),
                    horizontalAlignment: .center,
                    maximumNumberOfLines: 1,
                    tintColor: component.theme.foreground
                )),
                environment: {},
                containerSize: CGSize(width: availableSize.width - titlePadding * 2.0, height: availableSize.height)
            )
            if let titleView = self.title.view {
                if titleView.superview == nil {
                    self.addSubview(titleView)
                }
                titleView.bounds = CGRect(origin: .zero, size: titleSize)
                transition.setAlpha(view: titleView, alpha: self.hasProgress ? 0.0 : 1.0)
            }
            
            if self.hasProgress {
                let activity: ComponentView<Empty>
                if let current = self.activity {
                    activity = current
                } else {
                    activity = ComponentView()
                    self.activity = activity
                }
                let activitySize = CGSize(width: 18.0, height: 18.0)
                let _ = activity.update(
                    transition: transition,
                    component: AnyComponent(ActivityIndicatorComponent(color: component.theme.secondary)),
                    environment: {},
                    containerSize: activitySize
                )
                if let activityView = activity.view {
                    activityView.bounds = CGRect(origin: .zero, size: activitySize)
                }
            } else if let activity = self.activity {
                self.activity = nil
                if let activityView = activity.view {
                    transition.setAlpha(view: activityView, alpha: 0.0, completion: { _ in
                        activityView.removeFromSuperview()
                    })
                }
            }
            
            let buttonAlpha: CGFloat
            if self.isEnabled {
                buttonAlpha = component.isHighlighted ? 0.35 : 1.0
            } else {
                buttonAlpha = 0.2
            }
            
            transition.setBackgroundColor(view: self.backgroundView, color: component.theme.background)
            transition.setAlpha(view: self.backgroundView, alpha: buttonAlpha)
            self.backgroundView.layer.cornerRadius = availableSize.height * 0.5
            
            return CGSize(width: titleSize.width + titlePadding * 2.0, height: availableSize.height)
        }
        
        func applySize(size: CGSize, transition: ComponentTransition) {
            transition.setFrame(view: self.backgroundView, frame: CGRect(origin: .zero, size: size))
            
            if let titleView = self.title.view {
                let titleSize = titleView.bounds.size
                let titleFrame = CGRect(origin: CGPoint(x: floorToScreenPixels((size.width - titleSize.width) / 2.0), y: floorToScreenPixels((size.height - titleSize.height) / 2.0)), size: titleSize)
                transition.setFrame(view: titleView, frame: titleFrame)
            }
            
            if let activityView = self.activity?.view {
                var activityTransition = transition
                if activityView.superview == nil {
                    self.addSubview(activityView)
                    transition.animateAlpha(view: activityView, from: 0.0, to: 1.0)
                    activityTransition = .immediate
                }
                let activitySize = activityView.bounds.size
                let activityFrame = CGRect(origin: CGPoint(x: floorToScreenPixels((size.width - activitySize.width) / 2.0), y: floorToScreenPixels((size.height - activitySize.height) / 2.0)), size: activitySize)
                activityTransition.setPosition(view: activityView, position: activityFrame.center)
                activityView.transform = CGAffineTransformMakeScale(0.7, 0.7)
            }
        }
    }
    
    func makeView() -> View {
        return View(frame: CGRect())
    }
    
    func update(view: View, availableSize: CGSize, state: EmptyComponentState, environment: Environment<AlertComponentEnvironment>, transition: ComponentTransition) -> CGSize {
        return view.update(component: self, availableSize: availableSize, state: state, environment: environment, transition: transition)
    }
}
