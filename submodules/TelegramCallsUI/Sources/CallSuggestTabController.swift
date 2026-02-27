import Foundation
import UIKit
import SwiftSignalKit
import AsyncDisplayKit
import Display
import TelegramCore
import TelegramPresentationData
import TelegramUIPreferences
import AccountContext
import AppBundle
import ComponentFlow
import AlertComponent
import BundleIconComponent

public func callSuggestTabController(sharedContext: SharedAccountContext) -> ViewController {
    let strings = sharedContext.currentPresentationData.with { $0 }.strings
        
    var content: [AnyComponentWithIdentity<AlertComponentEnvironment>] = []
    content.append(AnyComponentWithIdentity(
        id: "header",
        component: AnyComponent(
            AlertCallSuggestHeaderComponent()
        )
    ))
    content.append(AnyComponentWithIdentity(
        id: "title",
        component: AnyComponent(
            AlertTitleComponent(title: strings.Calls_CallTabTitle)
        )
    ))
    content.append(AnyComponentWithIdentity(
        id: "text",
        component: AnyComponent(
            AlertTextComponent(content: .plain(strings.Calls_CallTabDescription))
        )
    ))
    
    let alertController = AlertScreen(
        sharedContext: sharedContext,
        content: content,
        actions: [
            .init(title: strings.Common_NotNow),
            .init(title: strings.Calls_AddTab, type: .default, action: {
                let _ = updateCallListSettingsInteractively(accountManager: sharedContext.accountManager, {
                    $0.withUpdatedShowTab(true)
                }).start()
            })
        ]
    )
    return alertController
}

private final class AlertCallSuggestHeaderComponent: Component {
    public typealias EnvironmentType = AlertComponentEnvironment
        
    public init() {
    }
    
    public static func ==(lhs: AlertCallSuggestHeaderComponent, rhs: AlertCallSuggestHeaderComponent) -> Bool {
        return true
    }
    
    public final class View: UIView {
        private let image = ComponentView<Empty>()
        private let accentImage = ComponentView<Empty>()
        
        private var component: AlertCallSuggestHeaderComponent?
        private weak var state: EmptyComponentState?
        
        func update(component: AlertCallSuggestHeaderComponent, availableSize: CGSize, state: EmptyComponentState, environment: Environment<AlertComponentEnvironment>, transition: ComponentTransition) -> CGSize {
            self.component = component
            self.state = state
            
            let environment = environment[AlertComponentEnvironment.self]
            
            let imageSize = self.image.update(
                transition: .immediate,
                component: AnyComponent(
                    BundleIconComponent(name: "Call List/AlertIcon", tintColor: environment.theme.actionSheet.primaryTextColor.withMultipliedAlpha(0.2))
                ),
                environment: {},
                containerSize: availableSize
            )
            let imageFrame = CGRect(origin: CGPoint(x: floorToScreenPixels((availableSize.width - imageSize.width) / 2.0), y: 0.0), size: imageSize)
            if let imageView = self.image.view {
                if imageView.superview == nil {
                    self.addSubview(imageView)
                }
                imageView.frame = imageFrame
            }
            
            let _ = self.accentImage.update(
                transition: .immediate,
                component: AnyComponent(
                    BundleIconComponent(name: "Call List/AlertAccentIcon", tintColor: environment.theme.actionSheet.controlAccentColor)
                ),
                environment: {},
                containerSize: availableSize
            )
            let accentImageFrame = CGRect(origin: CGPoint(x: floorToScreenPixels((availableSize.width - imageSize.width) / 2.0), y: 0.0), size: imageSize)
            if let accentImageView = self.accentImage.view {
                if accentImageView.superview == nil {
                    self.addSubview(accentImageView)
                }
                accentImageView.frame = accentImageFrame
            }
            
            return CGSize(width: availableSize.width, height: imageSize.height)
        }
    }
    
    public func makeView() -> View {
        return View(frame: CGRect())
    }
    
    public func update(view: View, availableSize: CGSize, state: EmptyComponentState, environment: Environment<AlertComponentEnvironment>, transition: ComponentTransition) -> CGSize {
        return view.update(component: self, availableSize: availableSize, state: state, environment: environment, transition: transition)
    }
}
