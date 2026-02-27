import Foundation
import UIKit
import Display
import TelegramPresentationData
import ComponentFlow
import ComponentDisplayAdapters
import AppBundle
import MultilineTextComponent
import EmojiStatusComponent
import TelegramCore
import AccountContext

public final class PeerNameTextComponent: Component {
    public enum TextContent: Equatable {
        case name
        case custom(String)
    }

    public let context: AccountContext
    public let peer: EnginePeer?
    public let text: TextContent
    public let font: UIFont
    public let textColor: UIColor
    public let iconBackgroundColor: UIColor
    public let iconForegroundColor: UIColor
    public let strings: PresentationStrings
    
    public init(
        context: AccountContext,
        peer: EnginePeer?,
        text: TextContent,
        font: UIFont,
        textColor: UIColor,
        iconBackgroundColor: UIColor,
        iconForegroundColor: UIColor,
        strings: PresentationStrings
    ) {
        self.context = context
        self.peer = peer
        self.text = text
        self.font = font
        self.textColor = textColor
        self.iconBackgroundColor = iconBackgroundColor
        self.iconForegroundColor = iconForegroundColor
        self.strings = strings
    }
    
    public static func ==(lhs: PeerNameTextComponent, rhs: PeerNameTextComponent) -> Bool {
        if lhs.context !== rhs.context {
            return false
        }
        if lhs.peer != rhs.peer {
            return false
        }
        if lhs.text != rhs.text {
            return false
        }
        if lhs.font != rhs.font {
            return false
        }
        if lhs.textColor != rhs.textColor {
            return false
        }
        if lhs.iconBackgroundColor != rhs.iconBackgroundColor {
            return false
        }
        if lhs.iconForegroundColor != rhs.iconForegroundColor {
            return false
        }
        if lhs.strings !== rhs.strings {
            return false
        }
        return true
    }
    
    public final class View: HighlightTrackingButton {
        private let title = ComponentView<Empty>()
        private var icon: ComponentView<Empty>?
        
        private var component: PeerNameTextComponent?
        
        public override init(frame: CGRect) {
            super.init(frame: frame)
        }
        
        required public init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }
        
        func update(component: PeerNameTextComponent, availableSize: CGSize, state: EmptyComponentState, environment: Environment<Empty>, transition: ComponentTransition) -> CGSize {
            var iconContent: EmojiStatusComponent.Content?
            if let peer = component.peer {
                if peer.isScam {
                    iconContent = .text(color: UIColor(rgb: 0xeb5545), string: component.strings.Message_ScamAccount.uppercased())
                } else if peer.isFake {
                    iconContent = .text(color: UIColor(rgb: 0xeb5545), string: component.strings.Message_FakeAccount.uppercased())
                }
                
                if peer.isVerified {
                    iconContent = .verified(fillColor: component.iconBackgroundColor, foregroundColor: component.iconForegroundColor, sizeType: .compact)
                }
            }
            
            let titleText: String
            switch component.text {
            case .name:
                if let peer = component.peer {
                    titleText = peer.displayTitle(strings: component.strings, displayOrder: .firstLast)
                } else {
                    titleText = " "
                }
            case let .custom(value):
                titleText = value
            }

            let titleSize = self.title.update(
                transition: .immediate,
                component: AnyComponent(MultilineTextComponent(
                    text: .plain(NSAttributedString(string: titleText, font: component.font, textColor: .white)),
                    truncationType: .end,
                    maximumNumberOfLines: 1
                )),
                environment: {},
                containerSize: availableSize
            )

            let titleFrame = CGRect(origin: CGPoint(x: 0.0, y: 0.0), size: titleSize)
            if let titleView = self.title.view {
                if titleView.superview == nil {
                    titleView.layer.anchorPoint = CGPoint()
                    self.addSubview(titleView)
                }
                transition.setPosition(view: titleView, position: titleFrame.origin)
                titleView.bounds = CGRect(origin: CGPoint(), size: titleFrame.size)
            }
            
            var size = CGSize(width: titleFrame.maxX, height: titleSize.height)
            
            if let iconContent {
                let icon: ComponentView<Empty>
                if let current = self.icon {
                    icon = current
                } else {
                    icon = ComponentView<Empty>()
                    self.icon = icon
                }
                
                let containerSize = CGSize(width: 16.0, height: 16.0)
                let iconSize = icon.update(
                    transition: .immediate,
                    component: AnyComponent(EmojiStatusComponent(
                        context: component.context,
                        animationCache: component.context.animationCache,
                        animationRenderer: component.context.animationRenderer,
                        content: iconContent,
                        isVisibleForAnimations: true,
                        action: nil
                    )),
                    environment: {},
                    containerSize: containerSize
                )
                size.width += 3.0
                let iconFrame = CGRect(origin: CGPoint(x: size.width, y: floorToScreenPixels((titleSize.height - iconSize.height) * 0.5)), size: iconSize)
                if let iconView = icon.view {
                    if iconView.superview == nil {
                        self.addSubview(iconView)
                    }
                    transition.setFrame(view: iconView, frame: iconFrame)
                }
                size.width += iconSize.width
            } else if let icon = self.icon {
                self.icon = nil
                icon.view?.removeFromSuperview()
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
