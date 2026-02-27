import Foundation
import UIKit
import AsyncDisplayKit
import Display
import ComponentFlow
import TelegramCore
import TelegramPresentationData
import MultilineTextComponent
import MultilineTextWithEntitiesComponent
import Markdown
import TextFormat
import AccountContext

private let titleFont = Font.bold(17.0)
private let defaultTextFont = Font.regular(15.0)
private let defaultBoldTextFont = Font.semibold(15.0)
private let defaultItalicTextFont = Font.italic(15.0)
private let defaultBoldItalicTextFont = Font.with(size: 15.0, weight: .semibold, traits: [.italic])
private let defaultFixedTextFont = Font.monospace(15.0)
private let smallTextFont = Font.regular(14.0)
private let smallBoldTextFont = Font.semibold(14.0)
private let smallItalicTextFont = Font.italic(14.0)
private let smallBoldItalicTextFont = Font.with(size: 14.0, weight: .semibold, traits: [.italic])
private let smallFixedTextFont = Font.monospace(14.0)
private let backgroundInset: CGFloat = 8.0

public final class AlertTitleComponent: Component {
    public typealias EnvironmentType = AlertComponentEnvironment
    
    public enum Alignment {
        case `default`
        case center
    }
    
    let title: String
    let alignment: Alignment
    
    public init(
        title: String,
        alignment: Alignment = .default
    ) {
        self.title = title
        self.alignment = alignment
    }
    
    public static func ==(lhs: AlertTitleComponent, rhs: AlertTitleComponent) -> Bool {
        if lhs.title != rhs.title {
            return false
        }
        if lhs.alignment != rhs.alignment {
            return false
        }
        return true
    }
    
    public final class View: UIView {
        private let title = ComponentView<Empty>()
        
        private var component: AlertTitleComponent?
        private weak var state: EmptyComponentState?
        
        func update(component: AlertTitleComponent, availableSize: CGSize, state: EmptyComponentState, environment: Environment<AlertComponentEnvironment>, transition: ComponentTransition) -> CGSize {
            self.component = component
            self.state = state
            
            let environment = environment[AlertComponentEnvironment.self]
            
            let inset: CGFloat = -6.0
            let titleConstrainedSize = CGSize(width: availableSize.width - inset * 2.0, height: availableSize.height)
            let titleSize = self.title.update(
                transition: transition,
                component: AnyComponent(MultilineTextComponent(
                    text: .plain(NSAttributedString(
                        string: component.title,
                        font: titleFont,
                        textColor: environment.theme.actionSheet.primaryTextColor
                    )),
                    horizontalAlignment: component.alignment == .center ? .center : .natural,
                    maximumNumberOfLines: 0
                )),
                environment: {},
                containerSize: titleConstrainedSize
            )
            
            let titleOriginX: CGFloat
            switch component.alignment {
            case .default:
                titleOriginX = inset
            case .center:
                titleOriginX = floorToScreenPixels((availableSize.width - titleSize.width) / 2.0)
            }
            let titleFrame = CGRect(origin: CGPoint(x: titleOriginX, y: 0.0), size: titleSize)
            if let titleView = self.title.view {
                if titleView.superview == nil {
                    self.addSubview(titleView)
                }
                transition.setFrame(view: titleView, frame: titleFrame)
            }
            return CGSize(width: availableSize.width, height: titleSize.height)
        }
    }
    
    public func makeView() -> View {
        return View(frame: CGRect())
    }
    
    public func update(view: View, availableSize: CGSize, state: EmptyComponentState, environment: Environment<AlertComponentEnvironment>, transition: ComponentTransition) -> CGSize {
        return view.update(component: self, availableSize: availableSize, state: state, environment: environment, transition: transition)
    }
}

public final class AlertTextComponent: Component {
    public typealias EnvironmentType = AlertComponentEnvironment
    
    public enum Content: Equatable {
        case plain(String)
        case attributed(NSAttributedString)
        case textWithEntities(AccountContext, String, [MessageTextEntity])
        
        public static func ==(lhs: Content, rhs: Content) -> Bool {
            switch lhs {
            case let .plain(text):
                if case .plain(text) = rhs {
                    return true
                } else {
                    return false
                }
            case let .attributed(text):
                if case .attributed(text) = rhs {
                    return true
                } else {
                    return false
                }
            case let .textWithEntities(_, lhsText, lhsEntities):
                if case let .textWithEntities(_, rhsText, rhsEntities) = rhs {
                    return lhsText == rhsText && lhsEntities == rhsEntities
                } else {
                    return false
                }
            }
        }
    }
    
    public enum Alignment: Equatable {
        case `default`
        case center
    }
    
    public enum Color: Equatable {
        case primary
        case secondary
        case destructive
    }
    
    public enum TextStyle: Equatable {
        case `default`
        case small
        case bold
    }
    
    public enum Style: Equatable {
        case plain(TextStyle)
        case background(TextStyle)
    }
    
    let content: Content
    let alignment: Alignment
    let color: Color
    let style: Style
    let insets: UIEdgeInsets
    let action: ([NSAttributedString.Key: Any]) -> Void
    
    public init(
        content: Content,
        alignment: Alignment = .default,
        color: Color = .primary,
        style: Style = .plain(.default),
        insets: UIEdgeInsets = .zero,
        action: @escaping ([NSAttributedString.Key: Any]) -> Void = { _ in }
    ) {
        self.content = content
        self.alignment = alignment
        self.color = color
        self.style = style
        self.insets = insets
        self.action = action
    }
    
    public static func ==(lhs: AlertTextComponent, rhs: AlertTextComponent) -> Bool {
        if lhs.content != rhs.content {
            return false
        }
        if lhs.alignment != rhs.alignment {
            return false
        }
        if lhs.color != rhs.color {
            return false
        }
        if lhs.style != rhs.style {
            return false
        }
        if lhs.insets != rhs.insets {
            return false
        }
        return true
    }
    
    public final class View: UIView {
        private let background = ComponentView<Empty>()
        private let text = ComponentView<Empty>()
        
        private var component: AlertTextComponent?
        private weak var state: EmptyComponentState?
        
        func update(component: AlertTextComponent, availableSize: CGSize, state: EmptyComponentState, environment: Environment<AlertComponentEnvironment>, transition: ComponentTransition) -> CGSize {
            self.component = component
            self.state = state
            
            let environment = environment[AlertComponentEnvironment.self]
            
            let textColor: UIColor
            switch component.color {
            case .primary:
                textColor = environment.theme.actionSheet.primaryTextColor
            case .secondary:
                textColor = environment.theme.actionSheet.primaryTextColor.withMultipliedAlpha(0.35)
            case .destructive:
                textColor = environment.theme.actionSheet.destructiveActionTextColor
            }
            let linkColor = environment.theme.actionSheet.controlAccentColor
            
            let textFont: UIFont
            let boldTextFont: UIFont
            let italicTextFont: UIFont
            let fixedTextFont: UIFont
            switch component.style {
            case let .plain(textStyle), let .background(textStyle):
                switch textStyle {
                case .default:
                    textFont = defaultTextFont
                    boldTextFont = defaultBoldTextFont
                    italicTextFont = defaultItalicTextFont
                    fixedTextFont = defaultFixedTextFont
                case .small:
                    textFont = smallTextFont
                    boldTextFont = smallBoldTextFont
                    italicTextFont = smallItalicTextFont
                    fixedTextFont = smallFixedTextFont
                case .bold:
                    textFont = defaultBoldTextFont
                    boldTextFont = defaultBoldTextFont
                    italicTextFont = defaultBoldItalicTextFont
                    fixedTextFont = defaultFixedTextFont
                }
            }
            
            var finalText: NSAttributedString
            var context: AccountContext?
            switch component.content {
            case let .plain(text):
                let markdownAttributes = MarkdownAttributes(
                    body: MarkdownAttributeSet(font: textFont, textColor: textColor),
                    bold: MarkdownAttributeSet(font: boldTextFont, textColor: textColor),
                    link: MarkdownAttributeSet(font: textFont, textColor: linkColor),
                    linkAttribute: { contents in
                        return (TelegramTextAttributes.URL, contents)
                    }
                )
                finalText = parseMarkdownIntoAttributedString(text, attributes: markdownAttributes)
            case let .attributed(attributedText):
                finalText = attributedText
            case let .textWithEntities(accountContext, text, entities):
                context = accountContext
                finalText = stringWithAppliedEntities(text, entities: entities, baseColor: textColor, linkColor: linkColor, baseFont: textFont, linkFont: textFont, boldFont: boldTextFont, italicFont: italicTextFont, boldItalicFont: italicTextFont, fixedFont: fixedTextFont, blockQuoteFont: textFont, message: nil)
            }
            
            var hasCenterAlignment = component.alignment == .center
            switch component.style {
            case .background:
                hasCenterAlignment = true
            default:
                break
            }
            
            let inset: CGFloat = -6.0
            let textConstrainedSize = CGSize(width: availableSize.width - inset * 2.0, height: availableSize.height)
                        
            let textSize = self.text.update(
                transition: transition,
                component: AnyComponent(
                    MultilineTextWithEntitiesComponent(
                        context: context,
                        animationCache: context?.animationCache,
                        animationRenderer: context?.animationRenderer,
                        placeholderColor: textColor.withMultipliedAlpha(0.1),
                        text: .plain(finalText),
                        horizontalAlignment: hasCenterAlignment ? .center : .natural,
                        maximumNumberOfLines: 0,
                        lineSpacing: 0.2,
                        spoilerColor: textColor,
                        highlightColor: linkColor.withAlphaComponent(0.2),
                        manualVisibilityControl: true,
                        resetAnimationsOnVisibilityChange: true,
                        highlightAction: { attributes in
                            if let _ = attributes[NSAttributedString.Key(rawValue: TelegramTextAttributes.URL)] {
                                return NSAttributedString.Key(rawValue: TelegramTextAttributes.URL)
                            } else {
                                return nil
                            }
                        },
                        tapAction: { attributes, _ in
                            component.action(attributes)
                        }
                    )
                ),
                environment: {},
                containerSize: textConstrainedSize
            )
            
            var textOffset = CGPoint(x: inset, y: 0.0)
            if hasCenterAlignment {
                textOffset.x = floorToScreenPixels((availableSize.width - textSize.width) / 2.0)
            }
            var size = CGSize(width: availableSize.width, height: textSize.height)
            if case .background = component.style {
                let backgroundSize = CGSize(width: availableSize.width + 20.0, height: textSize.height + backgroundInset * 2.0)
                size = backgroundSize
                textOffset = CGPoint(x: textOffset.x, y: backgroundInset)
                
                let _ = self.background.update(
                    transition: transition,
                    component: AnyComponent(
                        FilledRoundedRectangleComponent(
                            color: textColor.withMultipliedAlpha(0.1),
                            cornerRadius: .value(10.0),
                            smoothCorners: true
                        )
                    ),
                    environment: {},
                    containerSize: backgroundSize
                )
                let backgroundFrame = CGRect(origin: CGPoint(x: -10.0, y: component.insets.top), size: backgroundSize)
                if let backgroundView = self.background.view {
                    if backgroundView.superview == nil {
                        self.addSubview(backgroundView)
                    }
                    transition.setFrame(view: backgroundView, frame: backgroundFrame)
                }
            }
            
            let textFrame = CGRect(origin: textOffset.offsetBy(dx: 0.0, dy: component.insets.top), size: textSize)
            if let textView = self.text.view {
                if textView.superview == nil {
                    self.addSubview(textView)
                }
                transition.setFrame(view: textView, frame: textFrame)
            }
            return CGSize(width: size.width, height: size.height + component.insets.top + component.insets.bottom)
        }
    }
    
    public func makeView() -> View {
        return View(frame: CGRect())
    }
    
    public func update(view: View, availableSize: CGSize, state: EmptyComponentState, environment: Environment<AlertComponentEnvironment>, transition: ComponentTransition) -> CGSize {
        return view.update(component: self, availableSize: availableSize, state: state, environment: environment, transition: transition)
    }
}
