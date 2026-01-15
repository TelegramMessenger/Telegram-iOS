import Foundation
import UIKit
import SwiftSignalKit
import AsyncDisplayKit
import Display
import Postbox
import TelegramCore
import TelegramPresentationData
import TelegramUIPreferences
import AccountContext
import AppBundle
import ComponentFlow
import AlertComponent
import AlertTransferHeaderComponent
import AvatarComponent

func photoUpdateConfirmationController(
    context: AccountContext,
    peer: EnginePeer,
    image: UIImage,
    text: String,
    doneTitle: String,
    isDark: Bool = true,
    commit: @escaping () -> Void
) -> ViewController {
    let presentationData = context.sharedContext.currentPresentationData.with { $0 }
    let strings = presentationData.strings
        
    var content: [AnyComponentWithIdentity<AlertComponentEnvironment>] = []
    content.append(AnyComponentWithIdentity(
        id: "header",
        component: AnyComponent(
            AlertTransferHeaderComponent(
                fromComponent: AnyComponentWithIdentity(id: "user", component: AnyComponent(
                    AvatarComponent(
                        context: context,
                        theme: presentationData.theme,
                        peer: peer
                    )
                )),
                toComponent: AnyComponentWithIdentity(id: "image", component: AnyComponent(
                    Image(
                        image: image,
                        size: CGSize(width: 60.0, height: 60.0),
                        cornerRadius: 30.0
                    )
                )),
                type: .transfer
            )
        )
    ))
    content.append(AnyComponentWithIdentity(
        id: "text",
        component: AnyComponent(
            AlertTextComponent(content: .plain(text))
        )
    ))
    
    var updatedPresentationData: (PresentationData, Signal<PresentationData, NoError>)
    if isDark {
        updatedPresentationData = (presentationData.withUpdated(theme: defaultDarkColorPresentationTheme), .single(presentationData.withUpdated(theme: defaultDarkColorPresentationTheme)))
    } else {
        updatedPresentationData = (presentationData, context.sharedContext.presentationData)
    }
    
    let alertController = AlertScreen(
        content: content,
        actions: [
            .init(title: strings.Common_Cancel),
            .init(title: doneTitle, type: .default, action: {
                commit()
            })
        ],
        updatedPresentationData: updatedPresentationData
    )
    return alertController
}

//private final class RoundImageComponent: Component {
//    let image: UIImage
//    
//    public init(
//        image: UIImage
//    ) {
//        self.image = image
//    }
//    
//    public static func ==(lhs: RoundImageComponent, rhs: RoundImageComponent) -> Bool {
//        if lhs.image !== rhs.image {
//            return false
//        }
//        return true
//    }
//    
//    public final class View: UIImageView {
//        private var component: RoundImageComponent?
//        private weak var state: EmptyComponentState?
//        
//        func update(component: RoundImageComponent, availableSize: CGSize, state: EmptyComponentState, environment: Environment<Empty>, transition: ComponentTransition) -> CGSize {
//            self.component = component
//            self.state = state
//            
//            self.clipsToBounds = true
//            self.image = component.image
//            self.layer.cornerRadius = 30.0
//            
//            return CGSize(width: 60.0, height: 60.0)
//        }
//    }
//    
//    public func makeView() -> View {
//        return View(frame: CGRect())
//    }
//    
//    public func update(view: View, availableSize: CGSize, state: EmptyComponentState, environment: Environment<Empty>, transition: ComponentTransition) -> CGSize {
//        return view.update(component: self, availableSize: availableSize, state: state, environment: environment, transition: transition)
//    }
//}
