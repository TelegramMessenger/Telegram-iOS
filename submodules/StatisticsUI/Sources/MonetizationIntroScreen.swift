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
import SheetComponent
import BundleIconComponent
import BalancedTextComponent
import MultilineTextComponent
import SolidRoundedButtonComponent
import LottieComponent
import AccountContext

private final class SheetContent: CombinedComponent {
    typealias EnvironmentType = ViewControllerComponentContainer.Environment
    
    let context: AccountContext
    let mode: MonetizationIntroScreen.Mode
    let openMore: () -> Void
    let dismiss: () -> Void
    
    init(
        context: AccountContext,
        mode: MonetizationIntroScreen.Mode,
        openMore: @escaping () -> Void,
        dismiss: @escaping () -> Void
    ) {
        self.context = context
        self.mode = mode
        self.openMore = openMore
        self.dismiss = dismiss
    }
    
    static func ==(lhs: SheetContent, rhs: SheetContent) -> Bool {
        if lhs.context !== rhs.context {
            return false
        }
        if lhs.mode != rhs.mode {
            return false
        }
        return true
    }
    
    final class State: ComponentState {
        var cachedIconImage: (UIImage, PresentationTheme)?
        var cachedChevronImage: (UIImage, PresentationTheme)?
        var cachedTonImage: (UIImage, PresentationTheme)?
        
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
        let list = Child(List<Empty>.self)
        let actionButton = Child(SolidRoundedButtonComponent.self)
        
        let infoBackground = Child(RoundedRectangle.self)
        let infoTitle = Child(MultilineTextComponent.self)
        let infoText = Child(MultilineTextComponent.self)
        
        let spaceRegex = try? NSRegularExpression(pattern: "\\[(.*?)\\]", options: [])
        
        return { context in
            let environment = context.environment[EnvironmentType.self]
            let component = context.component
            let state = context.state
            
            let theme = environment.theme
            let strings = environment.strings
            
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
                        
            let spacing: CGFloat = 16.0
            var contentSize = CGSize(width: context.availableSize.width, height: 32.0)
                                    
            let iconSize = CGSize(width: 90.0, height: 90.0)
            let gradientImage: UIImage
                            
            if let (current, currentTheme) = state.cachedIconImage, currentTheme === theme {
                gradientImage = current
            } else {
                gradientImage = generateGradientFilledCircleImage(diameter: iconSize.width, colors: [
                    UIColor(rgb: 0x4bbb45).cgColor,
                    UIColor(rgb: 0x9ad164).cgColor
                ])!
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
                component: BundleIconComponent(name: "Ads/MonetizationLogo", tintColor: theme.list.itemCheckColors.foregroundColor),
                availableSize: CGSize(width: 90, height: 90),
                transition: .immediate
            )
            
            context.add(icon
                .position(CGPoint(x: context.availableSize.width / 2.0, y: contentSize.height + iconBackground.size.height / 2.0))
            )
            contentSize.height += iconSize.height
            contentSize.height += spacing + 5.0
            
            let title = title.update(
                component: BalancedTextComponent(
                    text: .plain(NSAttributedString(string: component.mode == .bot ?  strings.Monetization_Intro_Bot_Title : strings.Monetization_Intro_Title, font: titleFont, textColor: textColor)),
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
            contentSize.height += spacing - 2.0
            
            var items: [AnyComponentWithIdentity<Empty>] = []
            items.append(
                AnyComponentWithIdentity(
                    id: "ads",
                    component: AnyComponent(ParagraphComponent(
                        title: strings.Monetization_Intro_Ads_Title,
                        titleColor: textColor,
                        text: component.mode == .bot ? strings.Monetization_Intro_Bot_Ads_Text : strings.Monetization_Intro_Ads_Text,
                        textColor: secondaryTextColor,
                        iconName: "Ads/Ads",
                        iconColor: linkColor
                    ))
                )
            )
            items.append(
                AnyComponentWithIdentity(
                    id: "split",
                    component: AnyComponent(ParagraphComponent(
                        title: strings.Monetization_Intro_Split_Title,
                        titleColor: textColor,
                        text: strings.Monetization_Intro_Split_Text,
                        textColor: secondaryTextColor,
                        iconName: "Ads/Split",
                        iconColor: linkColor
                    ))
                )
            )
            items.append(
                AnyComponentWithIdentity(
                    id: "withdrawal",
                    component: AnyComponent(ParagraphComponent(
                        title: strings.Monetization_Intro_Withdrawal_Title,
                        titleColor: textColor,
                        text: strings.Monetization_Intro_Withdrawal_Text,
                        textColor: secondaryTextColor,
                        iconName: "Ads/Withdrawal",
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
            contentSize.height += spacing - 13.0
            
            if state.cachedTonImage == nil || state.cachedTonImage?.1 !== environment.theme {
                state.cachedTonImage = (generateTintedImage(image: UIImage(bundleImageName: "Ads/TonAbout"), color: linkColor)!, theme)
            }
            
            let infoTitleString = strings.Monetization_Intro_Info_Title.replacingOccurrences(of: "#", with: " # ")
            let infoTitleAttributedString = NSMutableAttributedString(string: infoTitleString, font: titleFont, textColor: textColor)
            let range = (infoTitleAttributedString.string as NSString).range(of: "#")
            if range.location != NSNotFound, let icon = state.cachedTonImage?.0 {
                infoTitleAttributedString.addAttribute(.attachment, value: icon, range: range)
                infoTitleAttributedString.addAttribute(.foregroundColor, value: linkColor, range: range)
                infoTitleAttributedString.addAttribute(.baselineOffset, value: 1.0, range: range)
            }
            let infoTitle = infoTitle.update(
                component: MultilineTextComponent(
                    text: .plain(infoTitleAttributedString),
                    horizontalAlignment: .center
                ),
                availableSize: CGSize(width: context.availableSize.width - textSideInset * 2.0, height: context.availableSize.height),
                transition: .immediate
            )
            
            if state.cachedChevronImage == nil || state.cachedChevronImage?.1 !== environment.theme {
                state.cachedChevronImage = (generateTintedImage(image: UIImage(bundleImageName: "Settings/TextArrowRight"), color: linkColor)!, theme)
            }
            
            let presentationData = component.context.sharedContext.currentPresentationData.with { $0 }
            var infoString = strings.Monetization_Intro_Info_Text
            if let spaceRegex {
                let nsRange = NSRange(infoString.startIndex..., in: infoString)
                let matches = spaceRegex.matches(in: infoString, options: [], range: nsRange)
                var modifiedString = infoString
                
                for match in matches.reversed() {
                    let matchRange = Range(match.range, in: infoString)!
                    let matchedSubstring = String(infoString[matchRange])
                    let replacedSubstring = matchedSubstring.replacingOccurrences(of: " ", with: "\u{00A0}")
                    modifiedString.replaceSubrange(matchRange, with: replacedSubstring)
                }
                infoString = modifiedString
            }

            let infoAttributedString = parseMarkdownIntoAttributedString(infoString, attributes: markdownAttributes).mutableCopy() as! NSMutableAttributedString
            if let range = infoAttributedString.string.range(of: ">"), let chevronImage = state.cachedChevronImage?.0 {
                infoAttributedString.addAttribute(.attachment, value: chevronImage, range: NSRange(range, in: infoAttributedString.string))
                infoAttributedString.addAttribute(.baselineOffset, value: 1.0, range: NSRange(range, in: infoAttributedString.string))
            }
            let infoText = infoText.update(
                component: MultilineTextComponent(
                    text: .plain(infoAttributedString),
                    horizontalAlignment: .center,
                    maximumNumberOfLines: 0,
                    lineSpacing: 0.2,
                    highlightColor: linkColor.withMultipliedAlpha(0.1),
                    highlightInset: UIEdgeInsets(top: 0.0, left: 0.0, bottom: 0.0, right: -8.0),
                    highlightAction: { attributes in
                        if let _ = attributes[NSAttributedString.Key(rawValue: TelegramTextAttributes.URL)] {
                            return NSAttributedString.Key(rawValue: TelegramTextAttributes.URL)
                        } else {
                            return nil
                        }
                    },
                    tapAction: { _, _ in
                        component.context.sharedContext.openExternalUrl(context: component.context, urlContext: .generic, url: strings.Monetization_Intro_Info_Text_URL, forceExternal: true, presentationData: presentationData, navigationController: nil, dismissInput: {})
                    }
                ),
                availableSize: CGSize(width: context.availableSize.width - (textSideInset + sideInset - 2.0) * 2.0, height: context.availableSize.height),
                transition: .immediate
            )
            
            let infoPadding: CGFloat = 17.0
            let infoSpacing: CGFloat = 12.0
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
                    title: strings.Monetization_Intro_Understood,
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

private final class SheetContainerComponent: CombinedComponent {
    typealias EnvironmentType = ViewControllerComponentContainer.Environment
    
    let context: AccountContext
    let mode: MonetizationIntroScreen.Mode
    let openMore: () -> Void
    
    init(
        context: AccountContext,
        mode: MonetizationIntroScreen.Mode,
        openMore: @escaping () -> Void
    ) {
        self.context = context
        self.mode = mode
        self.openMore = openMore
    }
    
    static func ==(lhs: SheetContainerComponent, rhs: SheetContainerComponent) -> Bool {
        if lhs.context !== rhs.context {
            return false
        }
        if lhs.mode != rhs.mode {
            return false
        }
        return true
    }
    
    static var body: Body {
        let sheet = Child(SheetComponent<EnvironmentType>.self)
        let animateOut = StoredActionSlot(Action<Void>.self)
        
        let sheetExternalState = SheetComponent<EnvironmentType>.ExternalState()
        
        return { context in
            let environment = context.environment[EnvironmentType.self]
            
            let controller = environment.controller
            
            let sheet = sheet.update(
                component: SheetComponent<EnvironmentType>(
                    content: AnyComponent<EnvironmentType>(SheetContent(
                        context: context.component.context,
                        mode: context.component.mode,
                        openMore: context.component.openMore,
                        dismiss: {
                            animateOut.invoke(Action { _ in
                                if let controller = controller() {
                                    controller.dismiss(completion: nil)
                                }
                            })
                        }
                    )),
                    backgroundColor: .color(environment.theme.actionSheet.opaqueItemBackgroundColor),
                    followContentSizeChanges: true,
                    externalState: sheetExternalState,
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
            
            if let controller = controller(), !controller.automaticallyControlPresentationContextLayout {
                let layout = ContainerViewLayout(
                    size: context.availableSize,
                    metrics: environment.metrics,
                    deviceMetrics: environment.deviceMetrics,
                    intrinsicInsets: UIEdgeInsets(top: 0.0, left: 0.0, bottom: max(environment.safeInsets.bottom, sheetExternalState.contentHeight), right: 0.0),
                    safeInsets: UIEdgeInsets(top: 0.0, left: environment.safeInsets.left, bottom: 0.0, right: environment.safeInsets.right),
                    additionalInsets: .zero,
                    statusBarHeight: environment.statusBarHeight,
                    inputHeight: nil,
                    inputHeightIsInteractivellyChanging: false,
                    inVoiceOver: false
                )
                controller.presentationContext.containerLayoutUpdated(layout, transition: context.transition.containedViewLayoutTransition)
            }
            
            return context.availableSize
        }
    }
}


final class MonetizationIntroScreen: ViewControllerComponentContainer {
    private let context: AccountContext
    private var openMore: (() -> Void)?
    
    enum Mode: Equatable {
        case channel
        case bot
    }
    
    init(
        context: AccountContext,
        mode: Mode,
        openMore: @escaping () -> Void
    ) {
        self.context = context
        self.openMore = openMore
                
        super.init(
            context: context,
            component: SheetContainerComponent(
                context: context,
                mode: mode,
                openMore: openMore
            ),
            navigationBarAppearance: .none,
            statusBarStyle: .ignore,
            theme: .default
        )
        
        self.navigationPresentation = .flatModal
    }
    
    required public init(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        self.view.disablesInteractiveModalDismiss = true
    }
    
    func dismissAnimated() {
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
    let iconName: String
    let iconColor: UIColor
    
    public init(
        title: String,
        titleColor: UIColor,
        text: String,
        textColor: UIColor,
        iconName: String,
        iconColor: UIColor
    ) {
        self.title = title
        self.titleColor = titleColor
        self.text = text
        self.textColor = textColor
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
            
            let leftInset: CGFloat = 64.0
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
            let markdownAttributes = MarkdownAttributes(
                body: MarkdownAttributeSet(font: textFont, textColor: textColor),
                bold: MarkdownAttributeSet(font: boldTextFont, textColor: textColor),
                link: MarkdownAttributeSet(font: textFont, textColor: textColor),
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
                .position(CGPoint(x: 47.0, y: textTopInset + 18.0))
            )
        
            return CGSize(width: context.availableSize.width, height: textTopInset + title.size.height + text.size.height + 18.0)
        }
    }
}
