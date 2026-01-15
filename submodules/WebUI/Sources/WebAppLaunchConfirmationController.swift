import Foundation
import UIKit
import SwiftSignalKit
import AsyncDisplayKit
import Display
import ComponentFlow
import Postbox
import TelegramCore
import TelegramPresentationData
import TelegramUIPreferences
import AccountContext
import AppBundle
import EmojiStatusComponent
import AlertComponent
import AlertCheckComponent
import AvatarComponent
import MultilineTextComponent
import BundleIconComponent
import PlainButtonComponent

public func webAppLaunchConfirmationController(
    context: AccountContext,
    updatedPresentationData: (initial: PresentationData, signal: Signal<PresentationData, NoError>)?,
    peer: EnginePeer,
    requestWriteAccess: Bool = false,
    completion: @escaping (Bool) -> Void,
    showMore: (() -> Void)?,
    openTerms: @escaping () -> Void
) -> ViewController {
    let presentationData = context.sharedContext.currentPresentationData.with { $0 }
    let strings = presentationData.strings
            
    let checkState = AlertCheckComponent.ExternalState()
    
    var content: [AnyComponentWithIdentity<AlertComponentEnvironment>] = []
    content.append(AnyComponentWithIdentity(
        id: "header",
        component: AnyComponent(
            AlertWebAppHeaderComponent(context: context, peer: peer, showMore: showMore)
        )
    ))
    content.append(AnyComponentWithIdentity(
        id: "text",
        component: AnyComponent(
            AlertTextComponent(content: .plain(strings.WebApp_LaunchTermsConfirmation))
        )
    ))
    if requestWriteAccess {
        content.append(AnyComponentWithIdentity(
            id: "check",
            component: AnyComponent(
                AlertCheckComponent(title: strings.WebApp_AddToAttachmentAllowMessages(peer.compactDisplayTitle).string, initialValue: false, externalState: checkState)
            )
        ))
    }
    
    let alertController = AlertScreen(
        context: context,
        configuration: AlertScreen.Configuration(actionAlignment: .vertical),
        content: content,
        actions: [
            .init(title: strings.WebApp_LaunchOpenApp, type: .default, action: {
                completion(requestWriteAccess && checkState.value)
            }),
            .init(title: strings.Common_Cancel)
        ]
    )
    return alertController
}

private final class AlertWebAppHeaderComponent: Component {
    public typealias EnvironmentType = AlertComponentEnvironment
    
    let context: AccountContext
    let peer: EnginePeer
    let showMore: (() -> Void)?
    
    public init(
        context: AccountContext,
        peer: EnginePeer,
        showMore: (() -> Void)?
    ) {
        self.context = context
        self.peer = peer
        self.showMore = showMore
    }
    
    public static func ==(lhs: AlertWebAppHeaderComponent, rhs: AlertWebAppHeaderComponent) -> Bool {
        return true
    }
    
    public final class View: UIView {
        private let avatar = ComponentView<Empty>()
        private let title = ComponentView<Empty>()
        private let titleIcon = ComponentView<Empty>()
        private let showMore = ComponentView<Empty>()
                
        private var component: AlertWebAppHeaderComponent?
        private weak var state: EmptyComponentState?
        
        func update(component: AlertWebAppHeaderComponent, availableSize: CGSize, state: EmptyComponentState, environment: Environment<AlertComponentEnvironment>, transition: ComponentTransition) -> CGSize {
            self.component = component
            self.state = state
            
            let environment = environment[AlertComponentEnvironment.self]
            
            var contentHeight: CGFloat = 0.0
            let avatarSize = self.avatar.update(
                transition: .immediate,
                component: AnyComponent(
                    AvatarComponent(
                        context: component.context,
                        theme: environment.theme,
                        peer: component.peer
                    )
                ),
                environment: {},
                containerSize: CGSize(width: 60.0, height: 60.0)
            )
            let avatarFrame = CGRect(origin: CGPoint(x: floorToScreenPixels((availableSize.width - avatarSize.width) / 2.0), y: contentHeight), size: avatarSize)
            if let avatarView = self.avatar.view {
                if avatarView.superview == nil {
                    self.addSubview(avatarView)
                }
                avatarView.frame = avatarFrame
            }
            contentHeight += avatarSize.height
            contentHeight += 17.0
            
            let titleSize = self.title.update(
                transition: .immediate,
                component: AnyComponent(
                    MultilineTextComponent(
                        text: .plain(NSAttributedString(
                            string: component.peer.compactDisplayTitle,
                            font: Font.bold(17.0),
                            textColor: environment.theme.actionSheet.primaryTextColor
                        )),
                        horizontalAlignment: .natural,
                        maximumNumberOfLines: 0
                    )
                ),
                environment: {},
                containerSize: CGSize(width: availableSize.width - 32.0, height: availableSize.height)
            )
            
            var totalWidth = titleSize.width

            var statusContent: EmojiStatusComponent.Content?
            if component.peer.isScam {
                statusContent = .text(color: environment.theme.list.itemDestructiveColor, string: environment.strings.Message_ScamAccount.uppercased())
            } else if component.peer.isFake {
                statusContent = .text(color: environment.theme.list.itemDestructiveColor, string: environment.strings.Message_FakeAccount.uppercased())
            } else if component.peer.isVerified {
                statusContent = .verified(fillColor: environment.theme.list.itemCheckColors.fillColor, foregroundColor: environment.theme.list.itemCheckColors.foregroundColor, sizeType: .large)
            }
            if let statusContent {
                let titleIconSize = self.titleIcon.update(
                    transition: .immediate,
                    component: AnyComponent(EmojiStatusComponent(
                        context: component.context,
                        animationCache: component.context.animationCache,
                        animationRenderer: component.context.animationRenderer,
                        content: statusContent,
                        isVisibleForAnimations: true,
                        action: {
                        }
                    )),
                    environment: {},
                    containerSize: CGSize(width: 20.0, height: 20.0)
                )
                totalWidth += titleIconSize.width + 2.0
                if let titleIconView = self.titleIcon.view {
                    if titleIconView.superview == nil {
                        self.addSubview(titleIconView)
                    }
                    transition.setFrame(view: titleIconView, frame: CGRect(origin: CGPoint(x: floorToScreenPixels((availableSize.width - totalWidth) / 2.0) + titleSize.width + 2.0, y: contentHeight), size: titleIconSize))
                }
            }
            
            let titleFrame = CGRect(origin: CGPoint(x: floorToScreenPixels((availableSize.width - totalWidth) / 2.0), y: contentHeight), size: titleSize)
            if let titleView = self.title.view {
                if titleView.superview == nil {
                    self.addSubview(titleView)
                }
                titleView.frame = titleFrame
            }
            contentHeight += titleSize.height
            
            if let showMore = component.showMore {
                contentHeight += 6.0
                
                let showMoreSize = self.showMore.update(
                    transition: .immediate,
                    component: AnyComponent(
                        PlainButtonComponent(
                            content: AnyComponent(
                                HStack([
                                    AnyComponentWithIdentity(id: "label", component: AnyComponent(MultilineTextComponent(text: .plain(NSAttributedString(string: environment.strings.WebApp_LaunchMoreInfo, font: Font.regular(14.0), textColor: environment.theme.actionSheet.controlAccentColor))))),
                                    AnyComponentWithIdentity(id: "arrow", component: AnyComponent(BundleIconComponent(name: "Item List/InlineTextRightArrow", tintColor: environment.theme.actionSheet.controlAccentColor)))
                                ], spacing: 3.0)
                            ),
                            action: {
                                showMore()
                            },
                            animateScale: false
                        )
                    ),
                    environment: {},
                    containerSize: availableSize
                )
                let showMoreFrame = CGRect(origin: CGPoint(x: floorToScreenPixels((availableSize.width - showMoreSize.width) / 2.0), y: contentHeight), size: showMoreSize)
                if let showMoreView = self.showMore.view {
                    if showMoreView.superview == nil {
                        self.addSubview(showMoreView)
                    }
                    showMoreView.frame = showMoreFrame
                }
                contentHeight += showMoreSize.height
            }
            contentHeight += 12.0
            
            return CGSize(width: availableSize.width, height: contentHeight)
        }
    }
    
    public func makeView() -> View {
        return View(frame: CGRect())
    }
    
    public func update(view: View, availableSize: CGSize, state: EmptyComponentState, environment: Environment<AlertComponentEnvironment>, transition: ComponentTransition) -> CGSize {
        return view.update(component: self, availableSize: availableSize, state: state, environment: environment, transition: transition)
    }
}
