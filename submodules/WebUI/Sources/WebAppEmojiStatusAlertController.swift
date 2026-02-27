import Foundation
import UIKit
import SwiftSignalKit
import AsyncDisplayKit
import Display
import Postbox
import ComponentFlow
import TelegramCore
import TelegramPresentationData
import TelegramUIPreferences
import AccountContext
import AppBundle
import AvatarNode
import EmojiTextAttachmentView
import TextFormat
import Markdown
import AlertComponent
import AvatarComponent
import MultilineTextComponent

func webAppEmojiStatusAlertController(
    context: AccountContext,
    accountPeer: EnginePeer,
    botName: String,
    icons: [TelegramMediaFile.Accessor],
    completion: @escaping (Bool, Bool) -> Void
) -> ViewController {
    let strings = context.sharedContext.currentPresentationData.with { $0 }.strings
        
    var content: [AnyComponentWithIdentity<AlertComponentEnvironment>] = []
    content.append(AnyComponentWithIdentity(
        id: "status",
        component: AnyComponent(
            AlertEmojiStatusComponent(context: context, peer: accountPeer, files: icons)
        )
    ))
    content.append(AnyComponentWithIdentity(
        id: "text",
        component: AnyComponent(
            AlertTextComponent(content: .plain(strings.WebApp_EmojiPermission_Text(botName, botName).string))
        )
    ))
    
    let alertController = AlertScreen(
        context: context,
        content: content,
        actions: [
            .init(title: strings.WebApp_EmojiPermission_Decline, action: {
                completion(false, false)
            }),
            .init(title: strings.WebApp_EmojiPermission_Allow, type: .default, action: {
                completion(true, false)
            })
        ]
    )
    alertController.dismissed = { byOutsideTap in
        if byOutsideTap {
            completion(false, true)
        }
    }
    return alertController
}

private final class AlertEmojiStatusComponent: Component {
    public typealias EnvironmentType = AlertComponentEnvironment
    
    let context: AccountContext
    let peer: EnginePeer
    let files: [TelegramMediaFile.Accessor]
    
    public init(
        context: AccountContext,
        peer: EnginePeer,
        files: [TelegramMediaFile.Accessor]
    ) {
        self.context = context
        self.peer = peer
        self.files = files
    }
    
    public static func ==(lhs: AlertEmojiStatusComponent, rhs: AlertEmojiStatusComponent) -> Bool {
        if lhs.context !== rhs.context {
            return false
        }
        if lhs.peer != rhs.peer {
            return false
        }
        if lhs.files != rhs.files {
            return false
        }
        return true
    }
    
    final class View: UIView {
        private let background = ComponentView<Empty>()
        private let title = ComponentView<Empty>()
        private let avatar = ComponentView<Empty>()
        
        private var animationLayer: InlineStickerItemLayer?
        
        private var currentIndex = 0
        private var switchingToNext = false
        
        private var timer: SwiftSignalKit.Timer?
        
        private var component: AlertEmojiStatusComponent?
        private weak var state: EmptyComponentState?
        
        func update(component: AlertEmojiStatusComponent, availableSize: CGSize, state: EmptyComponentState, environment: Environment<AlertComponentEnvironment>, transition: ComponentTransition) -> CGSize {
            self.component = component
            self.state = state
            
            let environment = environment[AlertComponentEnvironment.self]
            
            let titleSize = self.title.update(
                transition: transition,
                component: AnyComponent(MultilineTextComponent(
                    text: .plain(NSAttributedString(
                        string: component.peer.compactDisplayTitle,
                        font: Font.medium(15.0),
                        textColor: environment.theme.actionSheet.primaryTextColor
                    )),
                    maximumNumberOfLines: 0
                )),
                environment: {},
                containerSize: availableSize
            )
            
            let avatarSize = CGSize(width: 30.0, height: 30.0)
            let iconSize = CGSize(width: 20.0, height: 20.0)
            let avatarMargin: CGFloat = 1.0
            let avatarSpacing: CGFloat = 7.0
            let titleSpacing: CGFloat = 4.0
            let statusMargin: CGFloat = 12.0
            
            let backgroundSize = CGSize(width: avatarMargin + avatarSize.width + avatarSpacing + titleSize.width + titleSpacing + iconSize.width + statusMargin, height: 32.0)
            
            let _ = self.background.update(
                transition: transition,
                component: AnyComponent(FilledRoundedRectangleComponent(color: environment.theme.actionSheet.primaryTextColor.withMultipliedAlpha(0.1), cornerRadius: .minEdge, smoothCorners: false)),
                environment: {},
                containerSize: backgroundSize
            )
            let backgroundFrame = CGRect(origin: CGPoint(x: floorToScreenPixels((availableSize.width - backgroundSize.width) / 2.0), y: 0.0), size: backgroundSize)
            if let backgroundView = self.background.view {
                if backgroundView.superview == nil {
                    self.addSubview(backgroundView)
                }
                transition.setFrame(view: backgroundView, frame: backgroundFrame)
            }
            
            let _ = self.avatar.update(
                transition: transition,
                component: AnyComponent(AvatarComponent(
                    context: component.context,
                    theme: environment.theme,
                    peer: component.peer
                )),
                environment: {},
                containerSize: avatarSize
            )
            let avatarFrame = CGRect(origin: CGPoint(x: backgroundFrame.minX + avatarMargin, y: backgroundFrame.minY + avatarMargin), size: avatarSize)
            if let avatarView = self.avatar.view {
                if avatarView.superview == nil {
                    self.addSubview(avatarView)
                }
                transition.setFrame(view: avatarView, frame: avatarFrame)
            }
            
            let titleFrame = CGRect(origin: CGPoint(x: backgroundFrame.minX + avatarMargin + avatarSize.width + avatarSpacing, y: backgroundFrame.minY + floorToScreenPixels((backgroundSize.height - titleSize.height) / 2.0)), size: titleSize)
            if let titleView = self.title.view {
                if titleView.superview == nil {
                    self.addSubview(titleView)
                }
                transition.setFrame(view: titleView, frame: titleFrame)
            }
            
            if self.timer == nil {
                self.timer = SwiftSignalKit.Timer(timeout: 2.5, repeat: true, completion: { [weak self] in
                    guard let self else {
                        return
                    }
                    self.switchingToNext = true
                    self.state?.updated()
                }, queue: Queue.mainQueue())
                self.timer?.start()
            }
            
            let animationLayer: InlineStickerItemLayer
            var disappearingAnimationLayer: InlineStickerItemLayer?
            if let current = self.animationLayer, !self.switchingToNext {
                animationLayer = current
            } else {
                if self.switchingToNext {
                    self.currentIndex = (self.currentIndex + 1) % component.files.count
                    disappearingAnimationLayer = self.animationLayer
                    self.switchingToNext = false
                }
                let file = component.files[self.currentIndex]._parse()
                let emoji = ChatTextInputTextCustomEmojiAttribute(
                    interactivelySelectedFromPackId: nil,
                    fileId: file.fileId.id,
                    file: file
                )
                animationLayer = InlineStickerItemLayer(
                    context: .account(component.context),
                    userLocation: .other,
                    attemptSynchronousLoad: false,
                    emoji: emoji,
                    file: file,
                    cache: component.context.animationCache,
                    renderer: component.context.animationRenderer,
                    unique: true,
                    placeholderColor: environment.theme.list.mediaPlaceholderColor,
                    pointSize: iconSize,
                    loopCount: 1
                )
                animationLayer.isVisibleForAnimations = true
                animationLayer.dynamicColor = environment.theme.actionSheet.controlAccentColor
                self.layer.addSublayer(animationLayer)
                self.animationLayer = animationLayer
                
                animationLayer.animateAlpha(from: 0.0, to: 1.0, duration: 0.2)
                animationLayer.animatePosition(from: CGPoint(x: 0.0, y: 10.0), to: .zero, duration: 0.2, additive: true)
                animationLayer.animateScale(from: 0.01, to: 1.0, duration: 0.2)
            }
            
            animationLayer.frame = CGRect(origin: CGPoint(x: backgroundFrame.maxX - iconSize.width - statusMargin, y: backgroundFrame.minY + floorToScreenPixels((backgroundFrame.height - iconSize.height) / 2.0)), size: iconSize)
            
            if let disappearingAnimationLayer {
                disappearingAnimationLayer.animateAlpha(from: 1.0, to: 0.0, duration: 0.2, removeOnCompletion: false, completion: { _ in
                    disappearingAnimationLayer.removeFromSuperlayer()
                })
                disappearingAnimationLayer.animatePosition(from: .zero, to: CGPoint(x: 0.0, y: -10.0), duration: 0.2, removeOnCompletion: false, additive: true)
                disappearingAnimationLayer.animateScale(from: 1.0, to: 0.01, duration: 0.2, removeOnCompletion: false)
            }
            
            return CGSize(width: availableSize.width, height: backgroundSize.height + 12.0)
        }
    }
    
    public func makeView() -> View {
        return View(frame: CGRect())
    }
    
    public func update(view: View, availableSize: CGSize, state: EmptyComponentState, environment: Environment<AlertComponentEnvironment>, transition: ComponentTransition) -> CGSize {
        return view.update(component: self, availableSize: availableSize, state: state, environment: environment, transition: transition)
    }
}
