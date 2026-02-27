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
import PhotoResources
import ComponentFlow
import AlertComponent
import AlertCheckComponent
import BundleIconComponent

public func addWebAppToAttachmentController(context: AccountContext, peerName: String, icons: [AttachMenuBots.Bot.IconName: TelegramMediaFile], requestWriteAccess: Bool, completion: @escaping (Bool) -> Void) -> ViewController {
    let presentationData = context.sharedContext.currentPresentationData.with { $0 }
    let strings = presentationData.strings
        
    let checkState = AlertCheckComponent.ExternalState()
    
    var content: [AnyComponentWithIdentity<AlertComponentEnvironment>] = []
    content.append(AnyComponentWithIdentity(
        id: "header",
        component: AnyComponent(
            AlertWebAppAttachmentHeaderComponent(context: context, icons: icons)
        )
    ))
    content.append(AnyComponentWithIdentity(
        id: "title",
        component: AnyComponent(
            AlertTitleComponent(title: strings.WebApp_AddToAttachmentTitle)
        )
    ))
    content.append(AnyComponentWithIdentity(
        id: "text",
        component: AnyComponent(
            AlertTextComponent(content: .plain(strings.WebApp_AddToAttachmentText(peerName).string))
        )
    ))
    if requestWriteAccess {
        content.append(AnyComponentWithIdentity(
            id: "check",
            component: AnyComponent(
                AlertCheckComponent(title: strings.WebApp_AddToAttachmentAllowMessages(peerName).string, initialValue: false, externalState: checkState)
            )
        ))
    }
    
    let alertController = AlertScreen(
        context: context,
        content: content,
        actions: [
            .init(title: strings.Common_Cancel),
            .init(title: strings.WebApp_AddToAttachmentAdd, type: .default, action: {
                completion(requestWriteAccess && checkState.value)
            })
        ]
    )
    return alertController
}

private final class AlertWebAppAttachmentHeaderComponent: Component {
    public typealias EnvironmentType = AlertComponentEnvironment
    
    let context: AccountContext
    let icons: [AttachMenuBots.Bot.IconName: TelegramMediaFile]
    
    public init(
        context: AccountContext,
        icons: [AttachMenuBots.Bot.IconName: TelegramMediaFile]
    ) {
        self.context = context
        self.icons = icons
    }
    
    public static func ==(lhs: AlertWebAppAttachmentHeaderComponent, rhs: AlertWebAppAttachmentHeaderComponent) -> Bool {
        return true
    }
    
    public final class View: UIView {
        private let appIcon = ComponentView<Empty>()
        private let icon = ComponentView<Empty>()
        
        private var appIconImage: UIImage?
        private var appIconDisposable: Disposable?
        
        private var component: AlertWebAppAttachmentHeaderComponent?
        private weak var state: EmptyComponentState?
        
        deinit {
            self.appIconDisposable?.dispose()
        }
        
        func update(component: AlertWebAppAttachmentHeaderComponent, availableSize: CGSize, state: EmptyComponentState, environment: Environment<AlertComponentEnvironment>, transition: ComponentTransition) -> CGSize {
            if self.component == nil {
                var peerIcon: TelegramMediaFile?
                if let icon = component.icons[.iOSStatic] {
                    peerIcon = icon
                } else if let icon = component.icons[.default] {
                    peerIcon = icon
                }
                
                if let peerIcon {
                    let _ = freeMediaFileInteractiveFetched(account: component.context.account, userLocation: .other, fileReference: .standalone(media: peerIcon)).start()
                    self.appIconDisposable = (svgIconImageFile(account: component.context.account, fileReference: .standalone(media: peerIcon))
                    |> deliverOnMainQueue).start(next: { [weak self] transform in
                        if let self {
                            let availableSize = CGSize(width: 48.0, height: 48.0)
                            let arguments = TransformImageArguments(corners: ImageCorners(), imageSize: availableSize, boundingSize: availableSize, intrinsicInsets: UIEdgeInsets())
                            let drawingContext = transform(arguments)
                            self.appIconImage = drawingContext?.generateImage()?.withRenderingMode(.alwaysTemplate)
                            
                            self.state?.updated()
                        }
                    })
                }
            }
            
            self.component = component
            self.state = state
            
            let environment = environment[AlertComponentEnvironment.self]
            
            let appIconSize = CGSize(width: 42.0, height: 42.0)
            let _ = self.appIcon.update(
                transition: .immediate,
                component: AnyComponent(
                    Image(image: self.appIconImage, tintColor: environment.theme.actionSheet.controlAccentColor)
                ),
                environment: {},
                containerSize: appIconSize
            )
            let iconSize = self.icon.update(
                transition: .immediate,
                component: AnyComponent(
                    BundleIconComponent(name: "Chat/Attach Menu/BotPlus", tintColor: environment.theme.actionSheet.controlAccentColor)
                ),
                environment: {},
                containerSize: availableSize
            )
            
            let totalWidth: CGFloat = 42.0 + iconSize.width
            
            let appIconFrame = CGRect(origin: CGPoint(x: floorToScreenPixels((availableSize.width - totalWidth) / 2.0) - 2.0, y: 3.0), size: appIconSize)
            if let imageView = self.appIcon.view {
                if imageView.superview == nil {
                    self.addSubview(imageView)
                }
                imageView.frame = appIconFrame
            }

            let iconFrame = CGRect(origin: CGPoint(x: floorToScreenPixels((availableSize.width - totalWidth) / 2.0) + appIconSize.width, y: 0.0), size: iconSize)
            if let imageView = self.icon.view {
                if imageView.superview == nil {
                    self.addSubview(imageView)
                }
                imageView.frame = iconFrame
            }
            
            return CGSize(width: availableSize.width, height: appIconSize.height + 17.0)
        }
    }
    
    public func makeView() -> View {
        return View(frame: CGRect())
    }
    
    public func update(view: View, availableSize: CGSize, state: EmptyComponentState, environment: Environment<AlertComponentEnvironment>, transition: ComponentTransition) -> CGSize {
        return view.update(component: self, availableSize: availableSize, state: state, environment: environment, transition: transition)
    }
}
