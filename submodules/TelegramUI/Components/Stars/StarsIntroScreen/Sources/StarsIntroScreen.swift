import Foundation
import UIKit
import Display
import ComponentFlow
import SwiftSignalKit
import TelegramCore
import Markdown
import TextFormat
import TelegramPresentationData
import ViewControllerComponent
import BundleIconComponent
import BalancedTextComponent
import MultilineTextComponent
import ButtonComponent
import AccountContext
import SheetComponent
import BlurredBackgroundComponent
import PremiumStarComponent

private final class SheetContent: CombinedComponent {
    typealias EnvironmentType = ViewControllerComponentContainer.Environment
    
    let context: AccountContext
    let openExamples: () -> Void
    let dismiss: () -> Void
    
    init(
        context: AccountContext,
        openExamples: @escaping () -> Void,
        dismiss: @escaping () -> Void
    ) {
        self.context = context
        self.openExamples = openExamples
        self.dismiss = dismiss
    }
    
    static func ==(lhs: SheetContent, rhs: SheetContent) -> Bool {
        if lhs.context !== rhs.context {
            return false
        }
        return true
    }
        
    static var body: Body {
        let star = Child(PremiumStarComponent.self)
        let title = Child(BalancedTextComponent.self)
        let text = Child(BalancedTextComponent.self)
        let list = Child(List<Empty>.self)
        let actionButton = Child(ButtonComponent.self)
                                
        return { context in
            let environment = context.environment[ViewControllerComponentContainer.Environment.self].value
            let component = context.component
            
            let theme = environment.theme
            let strings = environment.strings
            
            let sideInset: CGFloat = 16.0 + environment.safeInsets.left
            let textSideInset: CGFloat = 30.0 + environment.safeInsets.left
            
            let titleFont = Font.semibold(20.0)
            let textFont = Font.regular(15.0)
            
            let textColor = theme.actionSheet.primaryTextColor
            let secondaryTextColor = theme.actionSheet.secondaryTextColor
            let linkColor = theme.actionSheet.controlAccentColor
                                    
            let spacing: CGFloat = 16.0
            var contentSize = CGSize(width: context.availableSize.width, height: 152.0)
                                    
            let star = star.update(
                component: PremiumStarComponent(
                    theme: environment.theme,
                    isIntro: true,
                    isVisible: true,
                    hasIdleAnimations: true,
                    colors: [
                        UIColor(rgb: 0xe57d02),
                        UIColor(rgb: 0xf09903),
                        UIColor(rgb: 0xf9b004),
                        UIColor(rgb: 0xfdd219)
                    ],
                    particleColor: UIColor(rgb: 0xf9b004),
                    backgroundColor: environment.theme.actionSheet.opaqueItemBackgroundColor
                ),
                availableSize: CGSize(width: min(414.0, context.availableSize.width), height: 220.0),
                transition: context.transition
            )
            context.add(star
                .position(CGPoint(x: context.availableSize.width / 2.0, y: 79.0))
            )
            
            let title = title.update(
                component: BalancedTextComponent(
                    text: .plain(NSAttributedString(string: strings.Stars_Info_Title, font: titleFont, textColor: textColor)),
                    horizontalAlignment: .center,
                    maximumNumberOfLines: 0,
                    lineSpacing: 0.1
                ),
                availableSize: CGSize(width: context.availableSize.width - textSideInset * 2.0, height: context.availableSize.height),
                transition: .immediate
            )
            context.add(title
                .position(CGPoint(x: context.availableSize.width / 2.0, y: contentSize.height + title.size.height / 2.0))
            )
            contentSize.height += title.size.height
            contentSize.height += spacing - 8.0
            
            let text = text.update(
                component: BalancedTextComponent(
                    text: .plain(NSAttributedString(string: strings.Stars_Info_Description, font: textFont, textColor: secondaryTextColor)),
                    horizontalAlignment: .center,
                    maximumNumberOfLines: 0,
                    lineSpacing: 0.2
                ),
                availableSize: CGSize(width: context.availableSize.width - textSideInset * 2.0, height: context.availableSize.height),
                transition: .immediate
            )
            context.add(text
                .position(CGPoint(x: context.availableSize.width / 2.0, y: contentSize.height + text.size.height / 2.0))
            )
            contentSize.height += text.size.height
            contentSize.height += spacing
            
            var items: [AnyComponentWithIdentity<Empty>] = []
            items.append(
                AnyComponentWithIdentity(
                    id: "gift",
                    component: AnyComponent(ParagraphComponent(
                        title: strings.Stars_Info_Gift_Title,
                        titleColor: textColor,
                        text: strings.Stars_Info_Gift_Text,
                        textColor: secondaryTextColor,
                        accentColor: linkColor,
                        iconName: "Premium/StarsPerk/Gift",
                        iconColor: linkColor
                    ))
                )
            )
            items.append(
                AnyComponentWithIdentity(
                    id: "miniapp",
                    component: AnyComponent(ParagraphComponent(
                        title: strings.Stars_Info_Miniapp_Title,
                        titleColor: textColor,
                        text: strings.Stars_Info_Miniapp_Text,
                        textColor: secondaryTextColor,
                        accentColor: linkColor,
                        iconName: "Premium/StarsPerk/Miniapp",
                        iconColor: linkColor,
                        action: {
                            component.openExamples()
                        }
                    ))
                )
            )
            items.append(
                AnyComponentWithIdentity(
                    id: "media",
                    component: AnyComponent(ParagraphComponent(
                        title: strings.Stars_Info_Media_Title,
                        titleColor: textColor,
                        text: strings.Stars_Info_Media_Text,
                        textColor: secondaryTextColor,
                        accentColor: linkColor,
                        iconName: "Premium/StarsPerk/Media",
                        iconColor: linkColor
                    ))
                )
            )
            items.append(
                AnyComponentWithIdentity(
                    id: "reaction",
                    component: AnyComponent(ParagraphComponent(
                        title: strings.Stars_Info_Reaction_Title,
                        titleColor: textColor,
                        text: strings.Stars_Info_Reaction_Text,
                        textColor: secondaryTextColor,
                        accentColor: linkColor,
                        iconName: "Premium/StarsPerk/Reaction",
                        iconColor: linkColor
                    ))
                )
            )
            
            let list = list.update(
                component: List(items),
                availableSize: CGSize(width: context.availableSize.width - sideInset * 2.0, height: 10000.0),
                transition: context.transition
            )
            context.add(list
                .position(CGPoint(x: context.availableSize.width / 2.0, y: contentSize.height + list.size.height / 2.0))
            )
            contentSize.height += list.size.height
            contentSize.height += spacing
            
            let buttonHeight: CGFloat = 50.0
            let bottomPanelPadding: CGFloat = 12.0
            let bottomInset: CGFloat = environment.safeInsets.bottom > 0.0 ? environment.safeInsets.bottom + 5.0 : bottomPanelPadding
            
            contentSize.height += bottomPanelPadding
            
            let controller = environment.controller() as? StarsIntroScreen
            let actionButton = actionButton.update(
                component: ButtonComponent(
                    background: ButtonComponent.Background(
                        color: environment.theme.list.itemCheckColors.fillColor,
                        foreground: environment.theme.list.itemCheckColors.foregroundColor,
                        pressedColor: environment.theme.list.itemCheckColors.fillColor.withMultipliedAlpha(0.8)
                    ),
                    content: AnyComponentWithIdentity(id: AnyHashable(0 as Int), component: AnyComponent(
                        Text(text: strings.Stars_Info_Done, font: Font.semibold(17.0), color: environment.theme.list.itemCheckColors.foregroundColor)
                    )),
                    isEnabled: true,
                    displaysProgress: false,
                    action: {
                        controller?.dismissAnimated()
                    }
                ),
                availableSize: CGSize(width: context.availableSize.width - sideInset * 2.0, height: buttonHeight),
                transition: context.transition
            )
            context.add(actionButton
                .position(CGPoint(x: context.availableSize.width / 2.0, y: contentSize.height + actionButton.size.height / 2.0))
                .cornerRadius(10.0)
            )
            contentSize.height += actionButton.size.height + bottomInset
      
            return contentSize
        }
    }
}

private final class ContainerComponent: CombinedComponent {
    typealias EnvironmentType = ViewControllerComponentContainer.Environment
    
    let context: AccountContext
    let openExamples: () -> Void
    
    init(
        context: AccountContext,
        openExamples: @escaping () -> Void
    ) {
        self.context = context
        self.openExamples = openExamples
    }
    
    static func ==(lhs: ContainerComponent, rhs: ContainerComponent) -> Bool {
        if lhs.context !== rhs.context {
            return false
        }
        return true
    }
    
    final class State: ComponentState {
        var topContentOffset: CGFloat?
        var bottomContentOffset: CGFloat?
    }
    
    func makeState() -> State {
        return State()
    }
    
    static var body: Body {
        let sheet = Child(SheetComponent<(EnvironmentType)>.self)
        let animateOut = StoredActionSlot(Action<Void>.self)
                
        return { context in
            let environment = context.environment[EnvironmentType.self]
            
            let controller = environment.controller
            
            let sheet = sheet.update(
                component: SheetComponent<EnvironmentType>(
                    content: AnyComponent(SheetContent(
                        context: context.component.context,
                        openExamples: context.component.openExamples,
                        dismiss: {
                            controller()?.dismiss()
                        }
                    )),
                    backgroundColor: .color(environment.theme.actionSheet.opaqueItemBackgroundColor),
                    followContentSizeChanges: true,
                    clipsContent: true,
                    animateOut: animateOut
                ),
                environment: {
                    environment
                    SheetComponentEnvironment(
                        isDisplaying: environment.value.isVisible,
                        isCentered: environment.metrics.widthClass == .regular,
                        hasInputHeight: !environment.inputHeight.isZero,
                        regularMetricsSize: CGSize(width: 430.0, height: 900.0),
                        dismiss: { animated in
                            if animated {
                                animateOut.invoke(Action { _ in
                                    if let controller = controller() {
                                        controller.dismiss(completion: nil)
                                    }
                                })
                            } else {
                                if let controller = controller() {
                                    controller.dismiss(completion: nil)
                                }
                            }
                        }
                    )
                },
                availableSize: context.availableSize,
                transition: context.transition
            )
            
            context.add(sheet
                .position(CGPoint(x: context.availableSize.width / 2.0, y: context.availableSize.height / 2.0))
            )
            
            return context.availableSize
        }
    }
}

public final class StarsIntroScreen: ViewControllerComponentContainer {
    private let context: AccountContext
        
    public init(
        context: AccountContext,
        forceDark: Bool = false
    ) {
        self.context = context
                
        var openExamplesImpl: (() -> Void)?
        super.init(
            context: context,
            component: ContainerComponent(
                context: context,
                openExamples: {
                    openExamplesImpl?()
                }
            ),
            navigationBarAppearance: .none,
            statusBarStyle: .ignore,
            theme: forceDark ? .dark : .default
        )
        
        self.navigationPresentation = .flatModal
        
        openExamplesImpl = { [weak self] in
            guard let self else {
                return
            }
            let _ = (context.sharedContext.makeMiniAppListScreenInitialData(context: context)
            |> deliverOnMainQueue).startStandalone(next: { [weak self] initialData in
                guard let self, let navigationController = self.navigationController as? NavigationController else {
                    return
                }
                navigationController.pushViewController(context.sharedContext.makeMiniAppListScreen(context: context, initialData: initialData))
            })
        }
    }
    
    required public init(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    public func dismissAnimated() {
        if let view = self.node.hostView.findTaggedView(tag: SheetComponent<ViewControllerComponentContainer.Environment>.View.Tag()) as? SheetComponent<ViewControllerComponentContainer.Environment>.View {
            view.dismissAnimated()
        }
    }
}

private final class ParagraphComponent: CombinedComponent {
    let title: String
    let titleColor: UIColor
    let text: String
    let textColor: UIColor
    let accentColor: UIColor
    let iconName: String
    let iconColor: UIColor
    let action: () -> Void
    
    public init(
        title: String,
        titleColor: UIColor,
        text: String,
        textColor: UIColor,
        accentColor: UIColor,
        iconName: String,
        iconColor: UIColor,
        action: @escaping () -> Void = {}
    ) {
        self.title = title
        self.titleColor = titleColor
        self.text = text
        self.textColor = textColor
        self.accentColor = accentColor
        self.iconName = iconName
        self.iconColor = iconColor
        self.action = action
    }
    
    static func ==(lhs: ParagraphComponent, rhs: ParagraphComponent) -> Bool {
        if lhs.title != rhs.title {
            return false
        }
        if lhs.titleColor != rhs.titleColor {
            return false
        }
        if lhs.text != rhs.text {
            return false
        }
        if lhs.textColor != rhs.textColor {
            return false
        }
        if lhs.accentColor != rhs.accentColor {
            return false
        }
        if lhs.iconName != rhs.iconName {
            return false
        }
        if lhs.iconColor != rhs.iconColor {
            return false
        }
        return true
    }
    
    final class State: ComponentState {
        var cachedChevronImage: (UIImage, UIColor)?
    }
    
    func makeState() -> State {
        return State()
    }
    
    static var body: Body {
        let title = Child(MultilineTextComponent.self)
        let text = Child(MultilineTextComponent.self)
        let icon = Child(BundleIconComponent.self)
        
        return { context in
            let component = context.component
            let state = context.state
            
            let leftInset: CGFloat = 32.0
            let rightInset: CGFloat = 24.0
            let textSideInset: CGFloat = leftInset + 8.0
            let spacing: CGFloat = 5.0
            
            let textTopInset: CGFloat = 9.0
            
            let title = title.update(
                component: MultilineTextComponent(
                    text: .plain(NSAttributedString(
                        string: component.title,
                        font: Font.semibold(15.0),
                        textColor: component.titleColor,
                        paragraphAlignment: .natural
                    )),
                    horizontalAlignment: .center,
                    maximumNumberOfLines: 1
                ),
                availableSize: CGSize(width: context.availableSize.width - leftInset - rightInset, height: CGFloat.greatestFiniteMagnitude),
                transition: .immediate
            )
            
            let textFont = Font.regular(15.0)
            let boldTextFont = Font.semibold(15.0)
            let textColor = component.textColor
            let accentColor = component.accentColor
            let markdownAttributes = MarkdownAttributes(
                body: MarkdownAttributeSet(font: textFont, textColor: textColor),
                bold: MarkdownAttributeSet(font: boldTextFont, textColor: textColor),
                link: MarkdownAttributeSet(font: textFont, textColor: accentColor),
                linkAttribute: { contents in
                    return (TelegramTextAttributes.URL, contents)
                }
            )
            
            if state.cachedChevronImage == nil || state.cachedChevronImage?.1 != accentColor {
                state.cachedChevronImage = (generateTintedImage(image: UIImage(bundleImageName: "Settings/TextArrowRight"), color: accentColor)!, accentColor)
            }
            let textAttributedString = parseMarkdownIntoAttributedString(component.text, attributes: markdownAttributes).mutableCopy() as! NSMutableAttributedString
            if let range = textAttributedString.string.range(of: ">"), let chevronImage = state.cachedChevronImage?.0 {
                textAttributedString.addAttribute(.attachment, value: chevronImage, range: NSRange(range, in: textAttributedString.string))
            }
            
            let text = text.update(
                component: MultilineTextComponent(
                    text: .plain(textAttributedString),
                    horizontalAlignment: .natural,
                    maximumNumberOfLines: 0,
                    lineSpacing: 0.2,
                    highlightColor: accentColor.withAlphaComponent(0.1),
                    highlightInset: UIEdgeInsets(top: 0.0, left: 0.0, bottom: 0.0, right: -8.0),
                    highlightAction: { attributes in
                        if let _ = attributes[NSAttributedString.Key(rawValue: TelegramTextAttributes.URL)] {
                            return NSAttributedString.Key(rawValue: TelegramTextAttributes.URL)
                        } else {
                            return nil
                        }
                    },
                    tapAction: { _, _ in
                        component.action()
                    }
                ),
                availableSize: CGSize(width: context.availableSize.width - leftInset - rightInset, height: context.availableSize.height),
                transition: .immediate
            )
            
            let icon = icon.update(
                component: BundleIconComponent(
                    name: component.iconName,
                    tintColor: component.iconColor
                ),
                availableSize: CGSize(width: context.availableSize.width, height: context.availableSize.height),
                transition: .immediate
            )
         
            context.add(title
                .position(CGPoint(x: textSideInset + title.size.width / 2.0, y: textTopInset + title.size.height / 2.0))
            )
            
            context.add(text
                .position(CGPoint(x: textSideInset + text.size.width / 2.0, y: textTopInset + title.size.height + spacing + text.size.height / 2.0))
            )
            
            context.add(icon
                .position(CGPoint(x: 15.0, y: textTopInset + 18.0))
            )
        
            return CGSize(width: context.availableSize.width, height: textTopInset + title.size.height + text.size.height + 20.0)
        }
    }
}
