import Foundation
import UIKit
import Display
import AsyncDisplayKit
import SwiftSignalKit
import TelegramPresentationData
import AccountContext
import ContextUI
import TelegramCore
import TextFormat
import ReactionSelectionNode
import ViewControllerComponent
import ComponentFlow
import ComponentDisplayAdapters
import ChatMessageBackground
import WallpaperBackgroundNode
import MultilineTextWithEntitiesComponent
import ReactionButtonListComponent
import MultilineTextComponent

private final class EffectIcon: Component {
    enum Content: Equatable {
        case file(TelegramMediaFile)
        case text(String)
    }
    
    let context: AccountContext
    let content: Content
    
    init(
        context: AccountContext,
        content: Content
    ) {
        self.context = context
        self.content = content
    }
    
    static func ==(lhs: EffectIcon, rhs: EffectIcon) -> Bool {
        if lhs.context !== rhs.context {
            return false
        }
        if lhs.content != rhs.content {
            return false
        }
        return true
    }
    
    final class View: UIView {
        private var fileView: ReactionIconView?
        private var textView: ComponentView<Empty>?
        
        override init(frame: CGRect) {
            super.init(frame: frame)
        }
        
        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }
        
        func update(component: EffectIcon, availableSize: CGSize, state: EmptyComponentState, environment: Environment<Empty>, transition: Transition) -> CGSize {
            if case let .file(file) = component.content {
                let fileView: ReactionIconView
                if let current = self.fileView {
                    fileView = current
                } else {
                    fileView = ReactionIconView()
                    self.fileView = fileView
                    self.addSubview(fileView)
                }
                fileView.update(
                    size: availableSize,
                    context: component.context,
                    file: file,
                    fileId: file.fileId.id,
                    animationCache: component.context.animationCache,
                    animationRenderer: component.context.animationRenderer,
                    tintColor: nil,
                    placeholderColor: UIColor(white: 0.0, alpha: 0.1),
                    animateIdle: false,
                    reaction: .custom(file.fileId.id),
                    transition: .immediate
                )
                fileView.frame = CGRect(origin: CGPoint(), size: availableSize)
            } else {
                if let fileView = self.fileView {
                    self.fileView = nil
                    fileView.removeFromSuperview()
                }
            }
            
            if case let .text(text) = component.content {
                let textView: ComponentView<Empty>
                if let current = self.textView {
                    textView = current
                } else {
                    textView = ComponentView()
                    self.textView = textView
                }
                let textSize = textView.update(
                    transition: .immediate,
                    component: AnyComponent(MultilineTextComponent(
                        text: .plain(NSAttributedString(string: text, font: Font.regular(10.0), textColor: .black))
                    )),
                    environment: {},
                    containerSize: CGSize(width: 100.0, height: 100.0)
                )
                let textFrame = CGRect(origin: CGPoint(x: floorToScreenPixels((availableSize.width - textSize.width) * 0.5), y: floorToScreenPixels((availableSize.height - textSize.height) * 0.5)), size: textSize)
                if let textComponentView = textView.view {
                    if textComponentView.superview == nil {
                        self.addSubview(textComponentView)
                    }
                    textComponentView.frame = textFrame
                }
            } else {
                if let textView = self.textView {
                    self.textView = nil
                    textView.view?.removeFromSuperview()
                }
            }
            
            return availableSize
        }
    }
    
    func makeView() -> View {
        return View(frame: CGRect())
    }
    
    func update(view: View, availableSize: CGSize, state: EmptyComponentState, environment: Environment<Empty>, transition: Transition) -> CGSize {
        return view.update(component: self, availableSize: availableSize, state: state, environment: environment, transition: transition)
    }
}

final class MessageItemView: UIView {
    private let backgroundWallpaperNode: ChatMessageBubbleBackdrop
    private let backgroundNode: ChatMessageBackground
    
    private let text = ComponentView<Empty>()
    
    private var effectIcon: ComponentView<Empty>?
    var effectIconView: UIView? {
        return self.effectIcon?.view
    }
    
    private var chatTheme: ChatPresentationThemeData?
    private var currentSize: CGSize?
    
    override init(frame: CGRect) {
        self.backgroundWallpaperNode = ChatMessageBubbleBackdrop()
        self.backgroundNode = ChatMessageBackground()
        self.backgroundNode.backdropNode = self.backgroundWallpaperNode
        
        super.init(frame: frame)
        
        self.addSubview(self.backgroundWallpaperNode.view)
        self.addSubview(self.backgroundNode.view)
    }
    
    required init(coder: NSCoder) {
        preconditionFailure()
    }
    
    func update(
        context: AccountContext,
        presentationData: PresentationData,
        backgroundNode: WallpaperBackgroundNode?,
        textString: NSAttributedString,
        textInsets: UIEdgeInsets,
        explicitBackgroundSize: CGSize?,
        maxTextWidth: CGFloat,
        effect: AvailableMessageEffects.MessageEffect?,
        transition: Transition
    ) -> CGSize {
        var effectIconSize: CGSize?
        if let effect {
            let effectIcon: ComponentView<Empty>
            if let current = self.effectIcon {
                effectIcon = current
            } else {
                effectIcon = ComponentView()
                self.effectIcon = effectIcon
            }
            let effectIconContent: EffectIcon.Content
            if let staticIcon = effect.staticIcon {
                effectIconContent = .file(staticIcon)
            } else {
                effectIconContent = .text(effect.emoticon)
            }
            effectIconSize = effectIcon.update(
                transition: .immediate,
                component: AnyComponent(EffectIcon(
                    context: context,
                    content: effectIconContent
                )),
                environment: {},
                containerSize: CGSize(width: 8.0, height: 8.0)
            )
        }
        
        var textCutout: TextNodeCutout?
        if let effectIconSize {
            textCutout = TextNodeCutout(bottomRight: CGSize(width: effectIconSize.width + 4.0, height: effectIconSize.height))
        }
        
        let textSize = self.text.update(
            transition: .immediate,
            component: AnyComponent(MultilineTextWithEntitiesComponent(
                context: context,
                animationCache: context.animationCache,
                animationRenderer: context.animationRenderer,
                placeholderColor: presentationData.theme.chat.message.stickerPlaceholderColor.withWallpaper,
                text: .plain(textString),
                maximumNumberOfLines: 0,
                lineSpacing: 0.0,
                cutout: textCutout,
                insets: UIEdgeInsets()
            )),
            environment: {},
            containerSize: CGSize(width: maxTextWidth, height: 20000.0)
        )
        
        let size = CGSize(width: textSize.width + textInsets.left + textInsets.right, height: textSize.height + textInsets.top + textInsets.bottom)
        
        let textFrame = CGRect(origin: CGPoint(x: textInsets.left, y: textInsets.top), size: textSize)
        if let textView = self.text.view {
            if textView.superview == nil {
                self.addSubview(textView)
            }
            textView.frame = textFrame
        }
        
        let chatTheme: ChatPresentationThemeData
        if let current = self.chatTheme, current.theme === presentationData.theme {
            chatTheme = current
        } else {
            chatTheme = ChatPresentationThemeData(theme: presentationData.theme, wallpaper: presentationData.chatWallpaper)
            self.chatTheme = chatTheme
        }
        
        let themeGraphics = PresentationResourcesChat.principalGraphics(theme: presentationData.theme, wallpaper: presentationData.chatWallpaper, bubbleCorners: presentationData.chatBubbleCorners)
        self.backgroundWallpaperNode.setType(
            type: .outgoing(.None),
            theme: chatTheme,
            essentialGraphics: themeGraphics,
            maskMode: true,
            backgroundNode: backgroundNode
        )
        self.backgroundNode.setType(
            type: .outgoing(.None),
            highlighted: false,
            graphics: themeGraphics,
            maskMode: true,
            hasWallpaper: true,
            transition: transition.containedViewLayoutTransition,
            backgroundNode: backgroundNode
        )
        
        let backgroundSize = explicitBackgroundSize ?? size
        
        let previousSize = self.currentSize
        self.currentSize = backgroundSize
        
        if let effectIcon = self.effectIcon, let effectIconSize {
            if let effectIconView = effectIcon.view {
                var animateIn = false
                if effectIconView.superview == nil {
                    animateIn = true
                    self.addSubview(effectIconView)
                }
                let effectIconFrame = CGRect(origin: CGPoint(x: backgroundSize.width - textInsets.right + 2.0 -  effectIconSize.width, y: backgroundSize.height - textInsets.bottom - 2.0 - effectIconSize.height), size: effectIconSize)
                if animateIn {
                    if let previousSize {
                        let previousEffectIconFrame = CGRect(origin: CGPoint(x: previousSize.width - textInsets.right + 2.0 - effectIconSize.width, y: previousSize.height - textInsets.bottom - 2.0 - effectIconSize.height), size: effectIconSize)
                        effectIconView.frame = previousEffectIconFrame
                    } else {
                        effectIconView.frame = effectIconFrame
                    }
                    transition.animateAlpha(view: effectIconView, from: 0.0, to: 1.0)
                    if !transition.animation.isImmediate {
                        effectIconView.layer.animateSpring(from: 0.001 as NSNumber, to: 1.0 as NSNumber, keyPath: "transform.scale", duration: 0.4)
                    }
                }
                
                transition.setFrame(view: effectIconView, frame: effectIconFrame)
            }
        } else {
            if let effectIcon = self.effectIcon {
                self.effectIcon = nil
                
                if let effectIconView = effectIcon.view {
                    let effectIconSize = effectIconView.bounds.size
                    let effectIconFrame = CGRect(origin: CGPoint(x: backgroundSize.width - textInsets.right -  effectIconSize.width, y: backgroundSize.height - textInsets.bottom - effectIconSize.height), size: effectIconSize)
                    transition.setFrame(view: effectIconView, frame: effectIconFrame)
                    transition.setScale(view: effectIconView, scale: 0.001)
                    transition.setAlpha(view: effectIconView, alpha: 0.0, completion: { [weak effectIconView] _ in
                        effectIconView?.removeFromSuperview()
                    })
                }
            }
        }
        
        let backgroundAlpha: CGFloat
        if explicitBackgroundSize != nil {
            backgroundAlpha = 0.0
        } else {
            backgroundAlpha = 1.0
        }
        
        transition.setFrame(view: self.backgroundWallpaperNode.view, frame: CGRect(origin: CGPoint(), size: backgroundSize))
        transition.setAlpha(view: self.backgroundWallpaperNode.view, alpha: backgroundAlpha)
        self.backgroundWallpaperNode.updateFrame(CGRect(origin: CGPoint(), size: backgroundSize), transition: transition.containedViewLayoutTransition)
        transition.setFrame(view: self.backgroundNode.view, frame: CGRect(origin: CGPoint(), size: backgroundSize))
        transition.setAlpha(view: self.backgroundNode.view, alpha: backgroundAlpha)
        self.backgroundNode.updateLayout(size: backgroundSize, transition: transition.containedViewLayoutTransition)
        
        return backgroundSize
    }
}
