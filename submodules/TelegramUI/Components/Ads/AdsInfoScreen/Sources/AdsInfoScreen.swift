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
import BlurredBackgroundComponent

private final class ScrollContent: CombinedComponent {
    typealias EnvironmentType = (ViewControllerComponentContainer.Environment, ScrollChildEnvironment)
    
    let context: AccountContext
    let openPremium: () -> Void
    let dismiss: () -> Void
    
    init(
        context: AccountContext,
        openPremium: @escaping () -> Void,
        dismiss: @escaping () -> Void
    ) {
        self.context = context
        self.openPremium = openPremium
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
        
        let infoBackground = Child(RoundedRectangle.self)
        let infoTitle = Child(MultilineTextComponent.self)
        let infoText = Child(MultilineTextComponent.self)
        
        let spaceRegex = try? NSRegularExpression(pattern: "\\[(.*?)\\]", options: [])
                
        return { context in
            let environment = context.environment[ViewControllerComponentContainer.Environment.self].value
            let component = context.component
            let state = context.state
            
            let theme = environment.theme
            let strings = environment.strings
            let presentationData = context.component.context.sharedContext.currentPresentationData.with { $0 }
            
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
                    text: .plain(NSAttributedString(string: strings.AdsInfo_Title, font: titleFont, textColor: textColor)),
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
                    text: .plain(NSAttributedString(string: strings.AdsInfo_Info, font: textFont, textColor: secondaryTextColor)),
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
            
            let premiumConfiguration = PremiumConfiguration.with(appConfiguration: component.context.currentAppConfiguration.with { $0 })
            var items: [AnyComponentWithIdentity<Empty>] = []
            items.append(
                AnyComponentWithIdentity(
                    id: "respect",
                    component: AnyComponent(ParagraphComponent(
                        title: strings.AdsInfo_Respect_Title,
                        titleColor: textColor,
                        text: strings.AdsInfo_Respect_Text,
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
                        title: strings.AdsInfo_Split_Title,
                        titleColor: textColor,
                        text: strings.AdsInfo_Split_Text,
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
                        title: strings.AdsInfo_Ads_Title,
                        titleColor: textColor,
                        text: strings.AdsInfo_Ads_Text("\(premiumConfiguration.minChannelRestrictAdsLevel)").string,
                        textColor: secondaryTextColor,
                        accentColor: linkColor,
                        iconName: "Premium/BoostPerk/NoAds",
                        iconColor: linkColor,
                        action: {
                            component.openPremium()
                        }
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
            contentSize.height += spacing - 9.0
            
            let infoTitleAttributedString = NSMutableAttributedString(string: strings.AdsInfo_Launch_Title, font: titleFont, textColor: textColor)
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
            
            var infoString = strings.AdsInfo_Launch_Text
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
            }
            let infoText = infoText.update(
                component: MultilineTextComponent(
                    text: .plain(infoAttributedString),
                    horizontalAlignment: .center,
                    maximumNumberOfLines: 0,
                    lineSpacing: 0.2,
                    highlightAction: { attributes in
                        if let _ = attributes[NSAttributedString.Key(rawValue: TelegramTextAttributes.URL)] {
                            return NSAttributedString.Key(rawValue: TelegramTextAttributes.URL)
                        } else {
                            return nil
                        }
                    },
                    tapAction: { _, _ in
                        component.context.sharedContext.openExternalUrl(context: component.context, urlContext: .generic, url: strings.AdsInfo_Launch_Text_URL, forceExternal: true, presentationData: presentationData, navigationController: nil, dismissInput: {})
                    }
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
            
            contentSize.height += 12.0 + 50.0
            if environment.safeInsets.bottom > 0 {
                contentSize.height += environment.safeInsets.bottom + 5.0
            } else {
                contentSize.height += 12.0
            }
            
            state.playAnimationIfNeeded()
            
            return contentSize
        }
    }
}

private final class ContainerComponent: CombinedComponent {
    typealias EnvironmentType = ViewControllerComponentContainer.Environment
    
    let context: AccountContext
    let openPremium: () -> Void
    
    init(
        context: AccountContext,
        openPremium: @escaping () -> Void
    ) {
        self.context = context
        self.openPremium = openPremium
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
        let background = Child(Rectangle.self)
        let scroll = Child(ScrollComponent<ViewControllerComponentContainer.Environment>.self)
        let bottomPanel = Child(BlurredBackgroundComponent.self)
        let bottomSeparator = Child(Rectangle.self)
        let actionButton = Child(SolidRoundedButtonComponent.self)
        let scrollExternalState = ScrollComponent<EnvironmentType>.ExternalState()
        
        return { context in
            let environment = context.environment[EnvironmentType.self]
            let theme = environment.theme
            let strings = environment.strings
            let state = context.state
            
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
                        openPremium: context.component.openPremium,
                        dismiss: {
                            controller()?.dismiss()
                        }
                    )),
                    externalState: scrollExternalState,
                    contentInsets: UIEdgeInsets(top: 0.0, left: 0.0, bottom: 1.0, right: 0.0),
                    contentOffsetUpdated: { [weak state] topContentOffset, bottomContentOffset in
                        state?.topContentOffset = topContentOffset
                        state?.bottomContentOffset = bottomContentOffset
                        Queue.mainQueue().justDispatch {
                            state?.updated(transition: .immediate)
                        }
                    },
                    contentOffsetWillCommit: { targetContentOffset in
                    }
                ),
                environment: { environment },
                availableSize: context.availableSize,
                transition: context.transition
            )
            
            context.add(scroll
                .position(CGPoint(x: context.availableSize.width / 2.0, y: context.availableSize.height / 2.0))
            )
            
            let buttonHeight: CGFloat = 50.0
            let bottomPanelPadding: CGFloat = 12.0
            let bottomInset: CGFloat = environment.safeInsets.bottom > 0.0 ? environment.safeInsets.bottom + 5.0 : bottomPanelPadding
            let bottomPanelHeight = bottomPanelPadding + buttonHeight + bottomInset
            
            let bottomPanelAlpha: CGFloat
            if scrollExternalState.contentHeight > context.availableSize.height {
                if let bottomContentOffset = state.bottomContentOffset {
                    bottomPanelAlpha = min(16.0, bottomContentOffset) / 16.0
                } else {
                    bottomPanelAlpha = 1.0
                }
            } else {
                bottomPanelAlpha = 0.0
            }
            
            let bottomPanel = bottomPanel.update(
                component: BlurredBackgroundComponent(
                    color: theme.rootController.tabBar.backgroundColor
                ),
                availableSize: CGSize(width: context.availableSize.width, height: bottomPanelHeight),
                transition: context.transition
            )
            let bottomSeparator = bottomSeparator.update(
                component: Rectangle(
                    color: theme.rootController.tabBar.separatorColor
                ),
                availableSize: CGSize(width: context.availableSize.width, height: UIScreenPixel),
                transition: context.transition
            )
            
            context.add(bottomPanel
                .position(CGPoint(x: context.availableSize.width / 2.0, y: context.availableSize.height - bottomPanel.size.height / 2.0))
                .opacity(bottomPanelAlpha)
            )
            context.add(bottomSeparator
                .position(CGPoint(x: context.availableSize.width / 2.0, y: context.availableSize.height - bottomPanel.size.height))
                .opacity(bottomPanelAlpha)
            )
            
            let sideInset: CGFloat = 16.0 + environment.safeInsets.left
            let actionButton = actionButton.update(
                component: SolidRoundedButtonComponent(
                    title: strings.AdsInfo_Understood,
                    theme: SolidRoundedButtonComponent.Theme(
                        backgroundColor: theme.list.itemCheckColors.fillColor,
                        backgroundColors: [],
                        foregroundColor: theme.list.itemCheckColors.foregroundColor
                    ),
                    font: .bold,
                    fontSize: 17.0,
                    height: buttonHeight,
                    cornerRadius: 10.0,
                    gloss: false,
                    iconName: nil,
                    animationName: nil,
                    iconPosition: .left,
                    action: {
                        controller()?.dismiss()
                    }
                ),
                availableSize: CGSize(width: context.availableSize.width - sideInset * 2.0, height: 50.0),
                transition: context.transition
            )
            context.add(actionButton
                .position(CGPoint(x: context.availableSize.width / 2.0, y: context.availableSize.height - bottomPanelHeight + bottomPanelPadding + actionButton.size.height / 2.0))
            )
             
            return context.availableSize
        }
    }
}

public final class AdsInfoScreen: ViewControllerComponentContainer {
    private let context: AccountContext
        
    public init(
        context: AccountContext,
        forceDark: Bool = false
    ) {
        self.context = context
                
        var openPremiumImpl: (() -> Void)?
        super.init(
            context: context,
            component: ContainerComponent(
                context: context,
                openPremium: {
                    openPremiumImpl?()
                }
            ),
            navigationBarAppearance: .none,
            statusBarStyle: .ignore,
            theme: forceDark ? .dark : .default
        )
        
        self.navigationPresentation = .modal
        
        openPremiumImpl = { [weak self] in
            guard let self else {
                return
            }
            
            let navigationController = self.navigationController
            self.dismiss()
            
            Queue.mainQueue().after(0.3) {
                let controller = context.sharedContext.makePremiumIntroController(context: context, source: .ads, forceDark: false, dismissed: nil)
                navigationController?.pushViewController(controller, animated: true)
            }
        }
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
    
    static var body: Body {
        let title = Child(MultilineTextComponent.self)
        let text = Child(MultilineTextComponent.self)
        let icon = Child(BundleIconComponent.self)
        
        return { context in
            let component = context.component
            
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
                        
            let text = text.update(
                component: MultilineTextComponent(
                    text: .markdown(text: component.text, attributes: markdownAttributes),
                    horizontalAlignment: .natural,
                    maximumNumberOfLines: 0,
                    lineSpacing: 0.2,
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
