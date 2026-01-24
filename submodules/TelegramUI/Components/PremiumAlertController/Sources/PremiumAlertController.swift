import Foundation
import UIKit
import SwiftSignalKit
import AsyncDisplayKit
import Display
import Postbox
import TelegramCore
import TelegramPresentationData
import AccountContext
import ComponentFlow
import AlertComponent
import PremiumStarComponent

public func premiumAlertController(
    context: AccountContext,
    parentController: ViewController,
    title: String? = nil,
    text: String
) -> ViewController {
    let presentationData = context.sharedContext.currentPresentationData.with { $0 }
    let strings = presentationData.strings
    
    var content: [AnyComponentWithIdentity<AlertComponentEnvironment>] = []
    content.append(AnyComponentWithIdentity(
        id: "header",
        component: AnyComponent(
            AlertPremiumStarComponent()
        )
    ))
    
    let title = strings.PremiumNeeded_Title
    content.append(AnyComponentWithIdentity(
        id: "title",
        component: AnyComponent(
            AlertTitleComponent(title: title)
        )
    ))
    content.append(AnyComponentWithIdentity(
        id: "text",
        component: AnyComponent(
            AlertTextComponent(content: .plain(text))
        )
    ))
    
    let alertController = AlertScreen(
        context: context,
        content: content,
        actions: [
            .init(title: strings.Common_Cancel),
            .init(title: strings.PremiumNeeded_Subscribe, type: .default, action: { [weak parentController] in
                let controller = context.sharedContext.makePremiumIntroController(context: context, source: .nameColor, forceDark: false, dismissed: nil)
                parentController?.push(controller)
            })
        ]
    )
    return alertController
}

private final class AlertPremiumStarComponent: Component {
    public typealias EnvironmentType = AlertComponentEnvironment
        
    public init() {
    }
    
    public static func ==(lhs: AlertPremiumStarComponent, rhs: AlertPremiumStarComponent) -> Bool {
        return true
    }
    
    public final class View: UIView {
        private let clippingView = UIView()
        private let icon = ComponentView<Empty>()
        
        private var component: AlertPremiumStarComponent?
        private weak var state: EmptyComponentState?
        
        func update(component: AlertPremiumStarComponent, availableSize: CGSize, state: EmptyComponentState, environment: Environment<AlertComponentEnvironment>, transition: ComponentTransition) -> CGSize {
            self.component = component
            self.state = state
            
            let environment = environment[AlertComponentEnvironment.self]
            
            let starHeight: CGFloat = 105.0
            let starSize = self.icon.update(
                transition: .immediate,
                component: AnyComponent(
                    PremiumStarComponent(
                        theme: environment.theme,
                        isIntro: false,
                        isVisible: true,
                        hasIdleAnimations: true,
                        colors: [
                            UIColor(rgb: 0x6a94ff),
                            UIColor(rgb: 0x9472fd),
                            UIColor(rgb: 0xe26bd3)
                        ]
                    )
                ),
                environment: {},
                containerSize: CGSize(width: availableSize.width + 60.0, height: 200.0)
            )
            if let view = self.icon.view {
                if view.superview == nil {
                    self.addSubview(self.clippingView)
                    self.clippingView.addSubview(view)
                }
                view.frame = CGRect(origin: CGPoint(x: 0.0, y: -24.0), size: starSize)
            }
            
            self.clippingView.clipsToBounds = true
            self.clippingView.layer.cornerRadius = 35.0
            self.clippingView.frame = CGRect(origin: CGPoint(x: -30.0, y: -22.0), size: CGSize(width: starSize.width, height: starSize.height))
           
            return CGSize(width: availableSize.width, height: starHeight + 10.0)
        }
    }
    
    public func makeView() -> View {
        return View(frame: CGRect())
    }
    
    public func update(view: View, availableSize: CGSize, state: EmptyComponentState, environment: Environment<AlertComponentEnvironment>, transition: ComponentTransition) -> CGSize {
        return view.update(component: self, availableSize: availableSize, state: state, environment: environment, transition: transition)
    }
}
