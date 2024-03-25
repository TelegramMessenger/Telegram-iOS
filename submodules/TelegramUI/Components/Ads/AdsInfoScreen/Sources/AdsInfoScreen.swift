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
import ScrollComponent
import BundleIconComponent
import BalancedTextComponent
import MultilineTextComponent
import SolidRoundedButtonComponent
import AccountContext
import ScrollComponent

private final class ScrollContent: CombinedComponent {
    typealias EnvironmentType = (ViewControllerComponentContainer.Environment, ScrollChildEnvironment)
    
    let context: AccountContext
    let openMore: () -> Void
    let dismiss: () -> Void
    
    init(
        context: AccountContext,
        openMore: @escaping () -> Void,
        dismiss: @escaping () -> Void
    ) {
        self.context = context
        self.openMore = openMore
        self.dismiss = dismiss
    }
    
    static func ==(lhs: ScrollContent, rhs: ScrollContent) -> Bool {
        if lhs.context !== rhs.context {
            return false
        }
        return true
    }
    
    final class State: ComponentState {
        var cachedIconImage: (UIImage, PresentationTheme)?
        var cachedChevronImage: (UIImage, PresentationTheme)?
        
        let playOnce =  ActionSlot<Void>()
        private var didPlayAnimation = false
                
        func playAnimationIfNeeded() {
            guard !self.didPlayAnimation else {
                return
            }
            self.didPlayAnimation = true
            self.playOnce.invoke(Void())
        }
    }
    
    func makeState() -> State {
        return State()
    }
    
    static var body: Body {
        let iconBackground = Child(Image.self)
        let icon = Child(BundleIconComponent.self)
        
        let title = Child(BalancedTextComponent.self)
        let text = Child(BalancedTextComponent.self)
        let list = Child(List<Empty>.self)
        let actionButton = Child(SolidRoundedButtonComponent.self)
        
        let infoBackground = Child(RoundedRectangle.self)
        let infoTitle = Child(MultilineTextComponent.self)
        let infoText = Child(MultilineTextComponent.self)
        
        return { context in
//            let scrollEnvironment = context.environment[ScrollChildEnvironment.self].value
            let environment = context.environment[ViewControllerComponentContainer.Environment.self].value
            let component = context.component
            let state = context.state
            
            let theme = environment.theme
//            let strings = environment.strings
            
            let sideInset: CGFloat = 16.0 + environment.safeInsets.left
            let textSideInset: CGFloat = 30.0 + environment.safeInsets.left
            
            let titleFont = Font.semibold(20.0)
            let textFont = Font.regular(15.0)
            
            let textColor = theme.actionSheet.primaryTextColor
            let secondaryTextColor = theme.actionSheet.secondaryTextColor
            let linkColor = theme.actionSheet.controlAccentColor
            
            let markdownAttributes = MarkdownAttributes(body: MarkdownAttributeSet(font: textFont, textColor: textColor), bold: MarkdownAttributeSet(font: textFont, textColor: textColor), link: MarkdownAttributeSet(font: textFont, textColor: linkColor), linkAttribute: { contents in
                return (TelegramTextAttributes.URL, contents)
            })
            
            //TODO:localize
            
            let spacing: CGFloat = 16.0
            var contentSize = CGSize(width: context.availableSize.width, height: 30.0)
                                    
            let iconSize = CGSize(width: 90.0, height: 90.0)
            let gradientImage: UIImage
                            
            if let (current, currentTheme) = state.cachedIconImage, currentTheme === theme {
                gradientImage = current
            } else {
                gradientImage = generateGradientFilledCircleImage(diameter: iconSize.width, colors: [
                    UIColor(rgb: 0x6e91ff).cgColor,
                    UIColor(rgb: 0x9472ff).cgColor,
                    UIColor(rgb: 0xcc6cdd).cgColor
                ], direction: .diagonal)!
                context.state.cachedIconImage = (gradientImage, theme)
            }
            
            let iconBackground = iconBackground.update(
                component: Image(image: gradientImage),
                availableSize: iconSize,
                transition: .immediate
            )
            context.add(iconBackground
                .position(CGPoint(x: context.availableSize.width / 2.0, y: contentSize.height + iconBackground.size.height / 2.0))
            )
            
            let icon = icon.update(
                component: BundleIconComponent(name: "Ads/AdsLogo", tintColor: theme.list.itemCheckColors.foregroundColor),
                availableSize: CGSize(width: 90, height: 90),
                transition: .immediate
            )
            context.add(icon
                .position(CGPoint(x: context.availableSize.width / 2.0, y: contentSize.height + iconBackground.size.height / 2.0))
            )
            contentSize.height += iconSize.height
            contentSize.height += spacing + 1.0
            
            let title = title.update(
                component: BalancedTextComponent(
                    text: .plain(NSAttributedString(string: "About These Ads", font: titleFont, textColor: textColor)),
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
                    text: .plain(NSAttributedString(string: "Telegram Ads are very different from ads on other platforms. Ads such as this one:", font: textFont, textColor: secondaryTextColor)),
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
                    id: "respect",
                    component: AnyComponent(ParagraphComponent(
                        title: "Respect Your Privacy",
                        titleColor: textColor,
                        text: "Ads on Telegram do not use your personal information and are based on the channel in which you see them.",
                        textColor: secondaryTextColor,
                        accentColor: linkColor,
                        iconName: "Ads/Privacy",
                        iconColor: linkColor
                    ))
                )
            )
            items.append(
                AnyComponentWithIdentity(
                    id: "split",
                    component: AnyComponent(ParagraphComponent(
                        title: "Help the Channel Creator",
                        titleColor: textColor,
                        text: "50% of the revenue from Telegram Ads goes to the owner of the channel where they are displayed.",
                        textColor: secondaryTextColor,
                        accentColor: linkColor,
                        iconName: "Ads/Split",
                        iconColor: linkColor
                    ))
                )
            )
            items.append(
                AnyComponentWithIdentity(
                    id: "ads",
                    component: AnyComponent(ParagraphComponent(
                        title: "Can Be Removed",
                        titleColor: textColor,
                        text: "You can turn off ads by subscribing to [Telegram Premium](), and Level 30 channels can remove them for their subscribers.",
                        textColor: secondaryTextColor,
                        accentColor: linkColor,
                        iconName: "Premium/BoostPerk/NoAds",
                        iconColor: linkColor
                    ))
                )
            )
            
            let list = list.update(
                component: List(items),
                availableSize: CGSize(width: context.availableSize.width - sideInset, height: 10000.0),
                transition: context.transition
            )
            context.add(list
                .position(CGPoint(x: context.availableSize.width / 2.0, y: contentSize.height + list.size.height / 2.0))
            )
            contentSize.height += list.size.height
            contentSize.height += spacing - 9.0
            
            let infoTitleAttributedString = NSMutableAttributedString(string: "Can I Launch an Ad?", font: titleFont, textColor: textColor)
            let infoTitle = infoTitle.update(
                component: MultilineTextComponent(
                    text: .plain(infoTitleAttributedString),
                    horizontalAlignment: .center,
                    maximumNumberOfLines: 0,
                    lineSpacing: 0.2
                ),
                availableSize: CGSize(width: context.availableSize.width - sideInset * 3.5, height: context.availableSize.height),
                transition: .immediate
            )
            
            if state.cachedChevronImage == nil || state.cachedChevronImage?.1 !== environment.theme {
                state.cachedChevronImage = (generateTintedImage(image: UIImage(bundleImageName: "Settings/TextArrowRight"), color: linkColor)!, theme)
            }
            
            let infoString = "Anyone can create ads to display in this channel – with minimal budgets. Check out the Telegram Ad Platform for details. [Learn More >]()"
            let infoAttributedString = parseMarkdownIntoAttributedString(infoString, attributes: markdownAttributes).mutableCopy() as! NSMutableAttributedString
            if let range = infoAttributedString.string.range(of: ">"), let chevronImage = state.cachedChevronImage?.0 {
                infoAttributedString.addAttribute(.attachment, value: chevronImage, range: NSRange(range, in: infoAttributedString.string))
            }
            let infoText = infoText.update(
                component: MultilineTextComponent(
                    text: .plain(infoAttributedString),
                    horizontalAlignment: .center,
                    maximumNumberOfLines: 0,
                    lineSpacing: 0.2
                ),
                availableSize: CGSize(width: context.availableSize.width - sideInset * 3.5, height: context.availableSize.height),
                transition: .immediate
            )
            
            let infoPadding: CGFloat = 13.0
            let infoSpacing: CGFloat = 6.0
            let totalInfoHeight = infoPadding + infoTitle.size.height + infoSpacing + infoText.size.height + infoPadding
            
            let infoBackground = infoBackground.update(
                component: RoundedRectangle(
                    color: theme.list.blocksBackgroundColor,
                    cornerRadius: 10.0
                ),
                availableSize: CGSize(width: context.availableSize.width - sideInset * 2.0, height: totalInfoHeight),
                transition: .immediate
            )
            context.add(infoBackground
                .position(CGPoint(x: context.availableSize.width / 2.0, y: contentSize.height + infoBackground.size.height / 2.0))
            )
            contentSize.height += infoPadding
            
            context.add(infoTitle
                .position(CGPoint(x: context.availableSize.width / 2.0, y: contentSize.height + infoTitle.size.height / 2.0))
            )
            contentSize.height += infoTitle.size.height
            contentSize.height += infoSpacing
            
            context.add(infoText
                .position(CGPoint(x: context.availableSize.width / 2.0, y: contentSize.height + infoText.size.height / 2.0))
            )
            contentSize.height += infoText.size.height
            contentSize.height += infoPadding
            contentSize.height += spacing
            
            let actionButton = actionButton.update(
                component: SolidRoundedButtonComponent(
                    title: "Understood",
                    theme: SolidRoundedButtonComponent.Theme(
                        backgroundColor: theme.list.itemCheckColors.fillColor,
                        backgroundColors: [],
                        foregroundColor: theme.list.itemCheckColors.foregroundColor
                    ),
                    font: .bold,
                    fontSize: 17.0,
                    height: 50.0,
                    cornerRadius: 10.0,
                    gloss: false,
                    iconName: nil,
                    animationName: nil,
                    iconPosition: .left,
                    action: {
                        component.dismiss()
                    }
                ),
                availableSize: CGSize(width: context.availableSize.width - sideInset * 2.0, height: 50.0),
                transition: context.transition
            )
            context.add(actionButton
                .position(CGPoint(x: context.availableSize.width / 2.0, y: contentSize.height + actionButton.size.height / 2.0))
            )
            contentSize.height += actionButton.size.height
            contentSize.height += 22.0
                        
            contentSize.height += environment.safeInsets.bottom
            
            state.playAnimationIfNeeded()
            
            return contentSize
        }
    }
}

private final class ContainerComponent: CombinedComponent {
    typealias EnvironmentType = ViewControllerComponentContainer.Environment
    
    let context: AccountContext
    let openMore: () -> Void
    
    init(
        context: AccountContext,
        openMore: @escaping () -> Void
    ) {
        self.context = context
        self.openMore = openMore
    }
    
    static func ==(lhs: ContainerComponent, rhs: ContainerComponent) -> Bool {
        if lhs.context !== rhs.context {
            return false
        }
        return true
    }
    
    static var body: Body {
        let background = Child(Rectangle.self)
        let scroll = Child(ScrollComponent<ViewControllerComponentContainer.Environment>.self)
                
        return { context in
            let environment = context.environment[EnvironmentType.self]
            
            let controller = environment.controller
            
            let background = background.update(
                component: Rectangle(color: environment.theme.list.plainBackgroundColor),
                environment: {},
                availableSize: context.availableSize,
                transition: context.transition
            )
            context.add(background
                .position(CGPoint(x: context.availableSize.width / 2.0, y: context.availableSize.height / 2.0))
            )
            
            let scroll = scroll.update(
                component: ScrollComponent<EnvironmentType>(
                    content: AnyComponent(ScrollContent(
                        context: context.component.context,
                        openMore: context.component.openMore,
                        dismiss: {
                            controller()?.dismiss()
                        }
                    )),
                    contentInsets: UIEdgeInsets(top: 0.0, left: 0.0, bottom: 1.0, right: 0.0),
                    contentOffsetUpdated: { topContentOffset, bottomContentOffset in
//                        state?.topContentOffset = topContentOffset
//                        state?.bottomContentOffset = bottomContentOffset
//                        Queue.mainQueue().justDispatch {
//                            state?.updated(transition: .immediate)
//                        }
                    },
                    contentOffsetWillCommit: { targetContentOffset in
                    }
                ),
                environment: { environment },
                availableSize: context.availableSize,
                transition: context.transition
            )
//            let sheet = sheet.update(
//                component: SheetComponent<EnvironmentType>(
//                    content: AnyComponent<EnvironmentType>(ScrollContent(
//                        context: context.component.context,
//                        openMore: context.component.openMore,
//                        dismiss: {
//                            animateOut.invoke(Action { _ in
//                                if let controller = controller() {
//                                    controller.dismiss(completion: nil)
//                                }
//                            })
//                        }
//                    )),
//                    backgroundColor: .color(environment.theme.actionSheet.opaqueItemBackgroundColor),
//                    followContentSizeChanges: true,
//                    externalState: sheetExternalState,
//                    animateOut: animateOut
//                ),
//                environment: {
//                    environment
//                    SheetComponentEnvironment(
//                        isDisplaying: environment.value.isVisible,
//                        isCentered: environment.metrics.widthClass == .regular,
//                        hasInputHeight: !environment.inputHeight.isZero,
//                        regularMetricsSize: CGSize(width: 430.0, height: 900.0),
//                        dismiss: { animated in
//                            if animated {
//                                animateOut.invoke(Action { _ in
//                                    if let controller = controller() {
//                                        controller.dismiss(completion: nil)
//                                    }
//                                })
//                            } else {
//                                if let controller = controller() {
//                                    controller.dismiss(completion: nil)
//                                }
//                            }
//                        }
//                    )
//                },
//                availableSize: context.availableSize,
//                transition: context.transition
//            )
            
            context.add(scroll
                .position(CGPoint(x: context.availableSize.width / 2.0, y: context.availableSize.height / 2.0))
            )
             
            return context.availableSize
        }
    }
}

public final class AdsInfoScreen: ViewControllerComponentContainer {
    private let context: AccountContext
        
    public init(
        context: AccountContext
    ) {
        self.context = context
                
        super.init(
            context: context,
            component: ContainerComponent(
                context: context,
                openMore: {}
            ),
            navigationBarAppearance: .none,
            statusBarStyle: .ignore,
            theme: .default
        )
        
        self.navigationPresentation = .modal
    }
    
    required public init(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
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
    
    public init(
        title: String,
        titleColor: UIColor,
        text: String,
        textColor: UIColor,
        accentColor: UIColor,
        iconName: String,
        iconColor: UIColor
    ) {
        self.title = title
        self.titleColor = titleColor
        self.text = text
        self.textColor = textColor
        self.accentColor = accentColor
        self.iconName = iconName
        self.iconColor = iconColor
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
    
    static var body: Body {
        let title = Child(MultilineTextComponent.self)
        let text = Child(MultilineTextComponent.self)
        let icon = Child(BundleIconComponent.self)
        
        return { context in
            let component = context.component
            
            let leftInset: CGFloat = 40.0
            let rightInset: CGFloat = 32.0
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
                linkAttribute: { _ in
                    return nil
                }
            )
                        
            let text = text.update(
                component: MultilineTextComponent(
                    text: .markdown(text: component.text, attributes: markdownAttributes),
                    horizontalAlignment: .natural,
                    maximumNumberOfLines: 0,
                    lineSpacing: 0.2
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
                .position(CGPoint(x: 23.0, y: textTopInset + 18.0))
            )
        
            return CGSize(width: context.availableSize.width, height: textTopInset + title.size.height + text.size.height + 20.0)
        }
    }
}
