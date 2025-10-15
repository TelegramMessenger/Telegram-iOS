import Foundation
import UIKit
import Display
import ComponentFlow
import TelegramCore
import TelegramPresentationData
import MultilineTextComponent
import BundleIconComponent
import TabSelectorComponent
import EmojiTextAttachmentView
import TextFormat
import AccountContext

public final class CollectionTabItemComponent: Component {
    public typealias EnvironmentType = TabSelectorComponent.ItemEnvironment
    
    public enum Icon: Equatable {
        case collection(TelegramMediaFile)
        case add
    }
    
    public let context: AccountContext
    public let icon: Icon?
    public let title: String
    public let theme: PresentationTheme
    
    public init(
        context: AccountContext,
        icon: Icon?,
        title: String,
        theme: PresentationTheme
    ) {
        self.context = context
        self.icon = icon
        self.title = title
        self.theme = theme
    }
    
    public static func ==(lhs: CollectionTabItemComponent, rhs: CollectionTabItemComponent) -> Bool {
        if lhs.icon != rhs.icon {
            return false
        }
        if lhs.title != rhs.title {
            return false
        }
        if lhs.theme !== rhs.theme {
            return false
        }
        return true
    }
    
    public final class View: UIView {
        private let title = ComponentView<Empty>()
        private let icon = ComponentView<Empty>()
        private var iconLayer: InlineStickerItemLayer?
                
        private var component: CollectionTabItemComponent?
                
        func update(component: CollectionTabItemComponent, availableSize: CGSize, state: State, environment: Environment<EnvironmentType>, transition: ComponentTransition) -> CGSize {
            self.component = component
            
            let environment = environment[EnvironmentType.self].value
                        
            let iconSpacing: CGFloat = 3.0
            
            let normalColor = component.theme.list.itemSecondaryTextColor
            let selectedColor = component.theme.list.freeTextColor
            let effectiveColor = normalColor.mixedWith(selectedColor, alpha: environment.selectionFraction)
            
            let titleSize = self.title.update(
                transition: .immediate,
                component: AnyComponent(MultilineTextComponent(
                    text: .plain(NSAttributedString(string: component.title, font: Font.medium(14.0), textColor: effectiveColor))
                )),
                environment: {},
                containerSize: CGSize(width: availableSize.width, height: 100.0)
            )
                        
            var iconOffset: CGFloat = 0.0
            var iconSize = CGSize()
            if let icon = component.icon  {
                switch icon {
                case let .collection(file):
                    iconSize = CGSize(width: 16.0, height: 16.0)
                    
                    let iconLayer: InlineStickerItemLayer
                    if let current = self.iconLayer {
                        iconLayer = current
                    } else {
                        iconLayer = InlineStickerItemLayer(
                            context: component.context,
                            userLocation: .other,
                            attemptSynchronousLoad: true,
                            emoji: ChatTextInputTextCustomEmojiAttribute(interactivelySelectedFromPackId: nil, fileId: file.fileId.id, file: file),
                            file: file,
                            cache: component.context.animationCache,
                            renderer: component.context.animationRenderer,
                            placeholderColor: component.theme.list.mediaPlaceholderColor,
                            pointSize: iconSize,
                            loopCount: 1
                        )
                        self.layer.addSublayer(iconLayer)
                        self.iconLayer = iconLayer
                    }
                    let iconFrame = CGRect(origin: CGPoint(x: iconOffset, y: floorToScreenPixels((titleSize.height - iconSize.height) * 0.5)), size: iconSize)
                    iconLayer.frame = iconFrame
                case .add:
                    iconSize = self.icon.update(
                        transition: .immediate,
                        component: AnyComponent(BundleIconComponent(
                            name: "Chat/Input/Media/PanelBadgeAdd",
                            tintColor: component.theme.list.itemSecondaryTextColor
                        )),
                        environment: {},
                        containerSize: CGSize(width: 100.0, height: 100.0)
                    )
                    let iconFrame = CGRect(origin: CGPoint(x: iconOffset, y: floorToScreenPixels((titleSize.height - iconSize.height) * 0.5)), size: iconSize)
                    if let iconView = self.icon.view {
                        if iconView.superview == nil {
                            iconView.isUserInteractionEnabled = false
                            self.addSubview(iconView)
                        }
                        iconView.frame = iconFrame
                    }
                }
                                
                iconOffset += iconSize.width + iconSpacing
            } else {
                if let iconLayer = self.iconLayer {
                    self.iconLayer = nil
                    iconLayer.animateAlpha(from: 1.0, to: 0.0, duration: 0.2, removeOnCompletion: false, completion: { _ in
                        iconLayer.removeFromSuperlayer()
                    })
                    iconLayer.animateScale(from: 1.0, to: 0.01, duration: 0.2, removeOnCompletion: false)
                }
                if let iconView = self.icon.view {
                    iconView.removeFromSuperview()
                }
            }
            
            let titleFrame = CGRect(origin: CGPoint(x: iconOffset, y: 0.0), size: titleSize)
            if let titleView = self.title.view {
                if titleView.superview == nil {
                    titleView.isUserInteractionEnabled = false
                    self.addSubview(titleView)
                }
                titleView.frame = titleFrame
            }
                        
            let size: CGSize
            if let _ = component.icon {
                size = CGSize(width: iconSize.width + iconSpacing + titleSize.width, height: titleSize.height)
            } else {
                size = titleSize
            }
             
            return size
        }
    }
    
    public func makeView() -> View {
        return View(frame: CGRect())
    }
    
    public func update(view: View, availableSize: CGSize, state: State, environment: Environment<EnvironmentType>, transition: ComponentTransition) -> CGSize {
        return view.update(component: self, availableSize: availableSize, state: state, environment: environment, transition: transition)
    }
}
