import Foundation
import UIKit
import Display
import ComponentFlow
import TelegramCore
import EmojiStatusComponent
import AccountContext

public final class EmojiActionIconComponent: Component {
    public let context: AccountContext
    public let color: UIColor
    public let fileId: Int64?
    public let file: TelegramMediaFile?
    
    public init(
        context: AccountContext,
        color: UIColor,
        fileId: Int64?,
        file: TelegramMediaFile?
    ) {
        self.context = context
        self.color = color
        self.fileId = fileId
        self.file = file
    }
    
    public static func ==(lhs: EmojiActionIconComponent, rhs: EmojiActionIconComponent) -> Bool {
        if lhs.context !== rhs.context {
            return false
        }
        if lhs.color != rhs.color {
            return false
        }
        if lhs.fileId != rhs.fileId {
            return false
        }
        if lhs.file != rhs.file {
            return false
        }
        return true
    }
    
    public final class View: UIView {
        private var icon: ComponentView<Empty>?
        
        func update(component: EmojiActionIconComponent, availableSize: CGSize, state: EmptyComponentState, environment: Environment<Empty>, transition: ComponentTransition) -> CGSize {
            let size = CGSize(width: 24.0, height: 24.0)
            
            var iconSize = size
            let content: EmojiStatusComponent.AnimationContent?
            if let file = component.file {
                if let dimensions = file.dimensions {
                    iconSize = dimensions.cgSize.aspectFitted(size)
                }
                content = .file(file: file)
            } else if let fileId = component.fileId {
                content = .customEmoji(fileId: fileId)
            } else {
                content = nil
            }
            
            if let content {
                let icon: ComponentView<Empty>
                if let current = self.icon {
                    icon = current
                } else {
                    icon = ComponentView()
                    self.icon = icon
                }
             
                let _ = icon.update(
                    transition: .immediate,
                    component: AnyComponent(EmojiStatusComponent(
                        context: component.context,
                        animationCache: component.context.animationCache,
                        animationRenderer: component.context.animationRenderer,
                        content: .animation(
                            content: content,
                            size: iconSize,
                            placeholderColor: .lightGray,
                            themeColor: component.color,
                            loopMode: .forever
                        ),
                        isVisibleForAnimations: false,
                        action: nil
                    )),
                    environment: {},
                    containerSize: iconSize
                )
                let iconFrame = CGRect(origin: CGPoint(x: floor((size.width - iconSize.width) * 0.5), y: floor((size.height - iconSize.height) * 0.5)), size: iconSize)
                if let iconView = icon.view {
                    if iconView.superview == nil {
                        self.addSubview(iconView)
                    }
                    iconView.frame = iconFrame
                }
            } else {
                if let icon = self.icon {
                    self.icon = nil
                    icon.view?.removeFromSuperview()
                }
            }
            
            return size
        }
    }
    
    public func makeView() -> View {
        return View(frame: CGRect())
    }
    
    public func update(view: View, availableSize: CGSize, state: EmptyComponentState, environment: Environment<Empty>, transition: ComponentTransition) -> CGSize {
        return view.update(component: self, availableSize: availableSize, state: state, environment: environment, transition: transition)
    }
}
