import Foundation
import LottieSettings
import UIKit
import Display
import ComponentFlow
import SwiftSignalKit
import TelegramCore
import Markdown
import TextFormat
import TelegramPresentationData
import ViewControllerComponent
import ResizableSheetComponent
import BundleIconComponent
import BalancedTextComponent
import MultilineTextComponent
import AccountContext
import PresentationDataUtils
import ContextUI
import UndoUI
import GlassBarButtonComponent
import ButtonComponent
import AdsReportScreen
import LottieComponent

private let moreTag = GenericComponentViewTag()

private final class SheetContent: CombinedComponent {
    typealias EnvironmentType = ViewControllerComponentContainer.Environment

    let context: AccountContext
    let mode: AdsInfoScreen.Mode
    let bottomInset: CGFloat
    let openPremium: () -> Void

    init(
        context: AccountContext,
        mode: AdsInfoScreen.Mode,
        bottomInset: CGFloat,
        openPremium: @escaping () -> Void
    ) {
        self.context = context
        self.mode = mode
        self.bottomInset = bottomInset
        self.openPremium = openPremium
    }

    static func ==(lhs: SheetContent, rhs: SheetContent) -> Bool {
        if lhs.context !== rhs.context {
            return false
        }
        if lhs.mode != rhs.mode {
            return false
        }
        if lhs.bottomInset != rhs.bottomInset {
            return false
        }
        return true
    }

    final class State: ComponentState {
        var cachedIconImage: (UIImage, PresentationTheme)?
        var cachedChevronImage: (UIImage, PresentationTheme)?
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

            let theme = environment.theme.withModalBlocksBackground()
            let strings = environment.strings
            let presentationData = component.context.sharedContext.currentPresentationData.with { $0 }

            let sideInset: CGFloat = 16.0 + environment.safeInsets.left
            let textSideInset: CGFloat = 30.0 + environment.safeInsets.left

            let titleFont = Font.semibold(20.0)
            let textFont = Font.regular(15.0)

            let textColor = theme.actionSheet.primaryTextColor
            let secondaryTextColor = theme.actionSheet.secondaryTextColor
            let linkColor = theme.actionSheet.controlAccentColor

            let markdownAttributes = MarkdownAttributes(
                body: MarkdownAttributeSet(font: textFont, textColor: textColor),
                bold: MarkdownAttributeSet(font: textFont, textColor: textColor),
                link: MarkdownAttributeSet(font: textFont, textColor: linkColor),
                linkAttribute: { contents in
                    return (TelegramTextAttributes.URL, contents)
                }
            )

            let spacing: CGFloat = 16.0
            var contentSize = CGSize(width: context.availableSize.width, height: 30.0)

            let iconSize = CGSize(width: 90.0, height: 90.0)
            let gradientImage: UIImage

            if let (current, currentTheme) = state.cachedIconImage, currentTheme === theme {
                gradientImage = current
            } else {
                gradientImage = generateGradientFilledCircleImage(
                    diameter: iconSize.width,
                    colors: [
                        UIColor(rgb: 0x6e91ff).cgColor,
                        UIColor(rgb: 0x9472ff).cgColor,
                        UIColor(rgb: 0xcc6cdd).cgColor
                    ],
                    direction: .diagonal
                )!
                state.cachedIconImage = (gradientImage, theme)
            }

            let iconBackground = iconBackground.update(
                component: Image(image: gradientImage),
                availableSize: iconSize,
                transition: .immediate
            )
            context.add(iconBackground.position(CGPoint(x: context.availableSize.width / 2.0, y: contentSize.height + iconBackground.size.height / 2.0)))

            let icon = icon.update(
                component: BundleIconComponent(name: "Ads/AdsLogo", tintColor: .white),
                availableSize: CGSize(width: 90.0, height: 90.0),
                transition: .immediate
            )
            context.add(icon.position(CGPoint(x: context.availableSize.width / 2.0, y: contentSize.height + iconBackground.size.height / 2.0)))
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
            context.add(title.position(CGPoint(x: context.availableSize.width / 2.0, y: contentSize.height + title.size.height / 2.0)))
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
            context.add(text.position(CGPoint(x: context.availableSize.width / 2.0, y: contentSize.height + text.size.height / 2.0)))
            contentSize.height += text.size.height
            contentSize.height += spacing

            let premiumConfiguration = PremiumConfiguration.with(appConfiguration: component.context.currentAppConfiguration.with { $0 })

            let respectText: String
            let adsText: String
            let infoRawText: String
            switch component.mode {
            case .channel:
                respectText = strings.AdsInfo_Respect_Text
                adsText = strings.AdsInfo_Ads_Text("\(premiumConfiguration.minChannelRestrictAdsLevel)").string
                infoRawText = strings.AdsInfo_Launch_Text
            case .bot:
                respectText = strings.AdsInfo_Bot_Respect_Text
                adsText = strings.AdsInfo_Bot_Ads_Text
                infoRawText = strings.AdsInfo_Bot_Launch_Text
            case .search:
                respectText = strings.AdsInfo_Search_Respect_Text
                adsText = strings.AdsInfo_Search_Ads_Text
                infoRawText = strings.AdsInfo_Search_Launch_Text
            }

            var items: [AnyComponentWithIdentity<Empty>] = []
            items.append(
                AnyComponentWithIdentity(
                    id: "respect",
                    component: AnyComponent(
                        ParagraphComponent(
                            title: strings.AdsInfo_Respect_Title,
                            titleColor: textColor,
                            text: respectText,
                            textColor: secondaryTextColor,
                            accentColor: linkColor,
                            iconName: "Ads/Privacy",
                            iconColor: linkColor
                        )
                    )
                )
            )
            if case .search = component.mode {
            } else {
                items.append(
                    AnyComponentWithIdentity(
                        id: "split",
                        component: AnyComponent(
                            ParagraphComponent(
                                title: component.mode == .bot ? strings.AdsInfo_Bot_Split_Title : strings.AdsInfo_Split_Title,
                                titleColor: textColor,
                                text: component.mode == .bot ? strings.AdsInfo_Bot_Split_Text : strings.AdsInfo_Split_Text,
                                textColor: secondaryTextColor,
                                accentColor: linkColor,
                                iconName: "Ads/Split",
                                iconColor: linkColor
                            )
                        )
                    )
                )
            }
            items.append(
                AnyComponentWithIdentity(
                    id: "ads",
                    component: AnyComponent(
                        ParagraphComponent(
                            title: strings.AdsInfo_Ads_Title,
                            titleColor: textColor,
                            text: adsText,
                            textColor: secondaryTextColor,
                            accentColor: linkColor,
                            iconName: "Premium/BoostPerk/NoAds",
                            iconColor: linkColor,
                            action: {
                                component.openPremium()
                            }
                        )
                    )
                )
            )

            let list = list.update(
                component: List(items),
                availableSize: CGSize(width: context.availableSize.width - sideInset * 2.0, height: 10000.0),
                transition: context.transition
            )
            context.add(list.position(CGPoint(x: context.availableSize.width / 2.0, y: contentSize.height + list.size.height / 2.0)))
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

            if state.cachedChevronImage == nil || state.cachedChevronImage?.1 !== theme {
                state.cachedChevronImage = (generateTintedImage(image: UIImage(bundleImageName: "Settings/TextArrowRight"), color: linkColor)!, theme)
            }

            var infoString = infoRawText
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
                    highlightColor: linkColor.withAlphaComponent(0.1),
                    highlightInset: UIEdgeInsets(top: 0.0, left: 0.0, bottom: 0.0, right: -8.0),
                    highlightAction: { attributes in
                        if let _ = attributes[NSAttributedString.Key(rawValue: TelegramTextAttributes.URL)] {
                            return NSAttributedString.Key(rawValue: TelegramTextAttributes.URL)
                        } else {
                            return nil
                        }
                    },
                    tapAction: { _, _ in
                        component.context.sharedContext.openExternalUrl(
                            context: component.context,
                            urlContext: .generic,
                            url: strings.AdsInfo_Launch_Text_URL,
                            forceExternal: true,
                            presentationData: presentationData,
                            navigationController: nil,
                            dismissInput: {}
                        )
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
                    color: theme.overallDarkAppearance ? theme.list.itemModalBlocksBackgroundColor : theme.list.blocksBackgroundColor,
                    cornerRadius: 26.0
                ),
                availableSize: CGSize(width: context.availableSize.width - sideInset * 2.0, height: totalInfoHeight),
                transition: .immediate
            )
            context.add(infoBackground.position(CGPoint(x: context.availableSize.width / 2.0, y: contentSize.height + infoBackground.size.height / 2.0)))
            contentSize.height += infoPadding

            context.add(infoTitle.position(CGPoint(x: context.availableSize.width / 2.0, y: contentSize.height + infoTitle.size.height / 2.0)))
            contentSize.height += infoTitle.size.height
            contentSize.height += infoSpacing

            context.add(infoText.position(CGPoint(x: context.availableSize.width / 2.0, y: contentSize.height + infoText.size.height / 2.0)))
            contentSize.height += infoText.size.height
            contentSize.height += infoPadding
            contentSize.height += spacing - 5.0
            contentSize.height += component.bottomInset

            return contentSize
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

    init(
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
                    text: .plain(
                        NSAttributedString(
                            string: component.title,
                            font: Font.semibold(15.0),
                            textColor: component.titleColor,
                            paragraphAlignment: .natural
                        )
                    ),
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
                    highlightColor: accentColor.withAlphaComponent(0.1),
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
                component: BundleIconComponent(name: component.iconName, tintColor: component.iconColor),
                availableSize: CGSize(width: context.availableSize.width, height: context.availableSize.height),
                transition: .immediate
            )

            context.add(title.position(CGPoint(x: textSideInset + title.size.width / 2.0, y: textTopInset + title.size.height / 2.0)))
            context.add(text.position(CGPoint(x: textSideInset + text.size.width / 2.0, y: textTopInset + title.size.height + spacing + text.size.height / 2.0)))
            context.add(icon.position(CGPoint(x: 15.0, y: textTopInset + 18.0)))

            return CGSize(width: context.availableSize.width, height: textTopInset + title.size.height + text.size.height + 20.0)
        }
    }
}

private final class AdsInfoSheetComponent: CombinedComponent {
    typealias EnvironmentType = ViewControllerComponentContainer.Environment

    let context: AccountContext
    let mode: AdsInfoScreen.Mode
    let message: EngineMessage?

    init(
        context: AccountContext,
        mode: AdsInfoScreen.Mode,
        message: EngineMessage?
    ) {
        self.context = context
        self.mode = mode
        self.message = message
    }

    static func ==(lhs: AdsInfoSheetComponent, rhs: AdsInfoSheetComponent) -> Bool {
        if lhs.context !== rhs.context {
            return false
        }
        if lhs.mode != rhs.mode {
            return false
        }
        if lhs.message?.id != rhs.message?.id {
            return false
        }
        return true
    }

    static var body: Body {
        let sheet = Child(ResizableSheetComponent<(EnvironmentType)>.self)
        let animateOut = StoredActionSlot(Action<Void>.self)

        let moreButtonPlayOnce = ActionSlot<Void>()
        
        return { context in
            let environment = context.environment[EnvironmentType.self]
            let controller = environment.controller

            let dismiss: (Bool) -> Void = { animated in
                if animated {
                    animateOut.invoke(Action { _ in
                        if let controller = controller() {
                            controller.dismiss(completion: nil)
                        }
                    })
                } else if let controller = controller() {
                    controller.dismiss(completion: nil)
                }
            }

            let theme = environment.theme.withModalBlocksBackground()

            let bottomButtonInsets = ContainerViewLayout.concentricInsets(
                bottomInset: environment.safeInsets.bottom,
                innerDiameter: 52.0,
                sideInset: 30.0
            )
            let contentBottomInset = bottomButtonInsets.bottom + 52.0 + 16.0

            let defaultHeight: CGFloat?
            if case .search = context.component.mode {
                defaultHeight = nil
            } else {
                let footerBottomInset: CGFloat = environment.safeInsets.bottom > 0.0 ? environment.safeInsets.bottom + 5.0 : 12.0
                let panelHeight: CGFloat = 12.0 + 50.0 + footerBottomInset + 28.0
                let containerTopInset = environment.statusBarHeight + 10.0
                defaultHeight = max(0.0, context.availableSize.width + 128.0 + panelHeight - containerTopInset)
            }

            let rightItem: AnyComponent<Empty>?
            if case .bot = context.component.mode, context.component.message?.adAttribute != nil {
                rightItem = AnyComponent(
                    GlassBarButtonComponent(
                        size: CGSize(width: 44.0, height: 44.0),
                        backgroundColor: nil,
                        isDark: theme.overallDarkAppearance,
                        state: .glass,
                        component: AnyComponentWithIdentity(
                            id: "more",
                            component: AnyComponent(
                                LottieComponent(
                                    content: LottieComponent.AppBundleContent(
                                        name: "anim_morewide"
                                    ),
                                    color: theme.chat.inputPanel.panelControlColor,
                                    size: CGSize(width: 34.0, height: 34.0),
                                    playOnce: moreButtonPlayOnce,
                                    lottieSettings: context.component.context.lottieRenderingSettings
                                )
                            )
                        ),
                        action: { _ in
                            (controller() as? AdsInfoScreen)?.infoPressed()
                            moreButtonPlayOnce.invoke(Void())
                        },
                        tag: moreTag
                    )
                )
            } else {
                rightItem = nil
            }

            let sheet = sheet.update(
                component: ResizableSheetComponent<EnvironmentType>(
                    content: AnyComponent<EnvironmentType>(
                        SheetContent(
                            context: context.component.context,
                            mode: context.component.mode,
                            bottomInset: contentBottomInset,
                            openPremium: {
                                guard let controller = controller() as? AdsInfoScreen else {
                                    return
                                }
                                let navigationController = controller.navigationController
                                let accountContext = controller.context
                                let forceDark = controller.forceDark
                                dismiss(true)

                                Queue.mainQueue().after(0.3) {
                                    let premiumController = accountContext.sharedContext.makePremiumIntroController(
                                        context: accountContext,
                                        source: .ads,
                                        forceDark: forceDark,
                                        dismissed: nil
                                    )
                                    navigationController?.pushViewController(premiumController, animated: true)
                                }
                            }
                        )
                    ),
                    titleItem: nil,
                    leftItem: AnyComponent(
                        GlassBarButtonComponent(
                            size: CGSize(width: 44.0, height: 44.0),
                            backgroundColor: nil,
                            isDark: theme.overallDarkAppearance,
                            state: .glass,
                            component: AnyComponentWithIdentity(
                                id: "close",
                                component: AnyComponent(
                                    BundleIconComponent(
                                        name: "Navigation/Close",
                                        tintColor: theme.chat.inputPanel.panelControlColor
                                    )
                                )
                            ),
                            action: { _ in
                                dismiss(true)
                            }
                        )
                    ),
                    rightItem: rightItem,
                    hasTopEdgeEffect: false,
                    bottomItem: AnyComponent(
                        ButtonComponent(
                            background: ButtonComponent.Background(
                                style: .glass,
                                color: theme.list.itemCheckColors.fillColor,
                                foreground: theme.list.itemCheckColors.foregroundColor,
                                pressedColor: theme.list.itemCheckColors.fillColor.withMultipliedAlpha(0.9)
                            ),
                            content: AnyComponentWithIdentity(
                                id: AnyHashable(0),
                                component: AnyComponent(
                                    Text(
                                        text: environment.strings.AdsInfo_Understood,
                                        font: Font.semibold(17.0),
                                        color: theme.list.itemCheckColors.foregroundColor
                                    )
                                )
                            ),
                            action: {
                                dismiss(true)
                            }
                        )
                    ),
                    backgroundColor: .color(theme.overallDarkAppearance ? theme.list.modalBlocksBackgroundColor : theme.list.plainBackgroundColor),
                    defaultHeight: defaultHeight,
                    animateOut: animateOut
                ),
                environment: {
                    environment
                    ResizableSheetComponentEnvironment(
                        theme: theme,
                        statusBarHeight: environment.statusBarHeight,
                        safeInsets: environment.safeInsets,
                        inputHeight: 0.0,
                        metrics: environment.metrics,
                        deviceMetrics: environment.deviceMetrics,
                        isDisplaying: environment.value.isVisible,
                        isCentered: environment.metrics.widthClass == .regular,
                        screenSize: context.availableSize,
                        regularMetricsSize: CGSize(width: 430.0, height: 900.0),
                        dismiss: { animated in
                            dismiss(animated)
                        }
                    )
                },
                availableSize: context.availableSize,
                transition: context.transition
            )
            context.add(sheet.position(CGPoint(x: context.availableSize.width / 2.0, y: context.availableSize.height / 2.0)))

            return context.availableSize
        }
    }
}

public final class AdsInfoScreen: ViewControllerComponentContainer {
    public enum Mode: Equatable {
        case channel
        case bot
        case search
    }

    fileprivate let context: AccountContext
    fileprivate let mode: Mode
    fileprivate let message: EngineMessage?
    fileprivate let forceDark: Bool

    public var removeAd: (Data) -> Void = { _ in }

    public init(
        context: AccountContext,
        mode: Mode,
        message: EngineMessage? = nil,
        forceDark: Bool = false
    ) {
        self.context = context
        self.mode = mode
        self.message = message
        self.forceDark = forceDark

        super.init(
            context: context,
            component: AdsInfoSheetComponent(
                context: context,
                mode: mode,
                message: message
            ),
            navigationBarAppearance: .none,
            statusBarStyle: .ignore,
            theme: forceDark ? .dark : .default
        )

        self.statusBar.statusBarStyle = .Ignore
        self.navigationPresentation = .flatModal
        self.blocksBackgroundWhenInOverlay = true
        self.supportedOrientations = ViewControllerSupportedOrientations(regularSize: .all, compactSize: .portrait)
    }

    required public init(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    public override func viewDidLoad() {
        super.viewDidLoad()

        self.view.disablesInteractiveModalDismiss = true
    }

    public func dismissAnimated() {
        if let view = self.node.hostView.findTaggedView(tag: ResizableSheetComponent<ViewControllerComponentContainer.Environment>.View.Tag()) as? ResizableSheetComponent<ViewControllerComponentContainer.Environment>.View {
            view.dismissAnimated()
        }
    }

    fileprivate func displayUndo(_ content: UndoOverlayContent) {
        let presentationData = self.context.sharedContext.currentPresentationData.with { $0 }
        self.present(
            UndoOverlayController(
                presentationData: presentationData,
                content: content,
                elevatedLayout: false,
                animateInAsReplacement: false,
                action: { _ in
                    return true
                }
            ),
            in: .current
        )
    }

    fileprivate func infoPressed() {
        guard
            let referenceView = self.node.hostView.findTaggedView(tag: moreTag),
            let message = self.message,
            let adAttribute = message.adAttribute
        else {
            return
        }

        let context = self.context
        let presentationData = context.sharedContext.currentPresentationData.with { $0 }

        var actions: [ContextMenuItem] = []
        if adAttribute.sponsorInfo != nil || adAttribute.additionalInfo != nil {
            actions.append(
                .action(
                    ContextMenuActionItem(
                        text: presentationData.strings.Chat_ContextMenu_AdSponsorInfo,
                        textColor: .primary,
                        icon: { theme in
                            return generateTintedImage(image: UIImage(bundleImageName: "Chat/Context Menu/Channels"), color: theme.actionSheet.primaryTextColor)
                        },
                        iconSource: nil,
                        action: { [weak self] c, _ in
                            var subItems: [ContextMenuItem] = []

                            subItems.append(
                                .action(
                                    ContextMenuActionItem(
                                        text: presentationData.strings.Common_Back,
                                        textColor: .primary,
                                        icon: { theme in
                                            return generateTintedImage(image: UIImage(bundleImageName: "Chat/Context Menu/Back"), color: theme.actionSheet.primaryTextColor)
                                        },
                                        iconSource: nil,
                                        iconPosition: .left,
                                        action: { c, _ in
                                            c?.popItems()
                                        }
                                    )
                                )
                            )

                            subItems.append(.separator)

                            if let sponsorInfo = adAttribute.sponsorInfo {
                                subItems.append(
                                    .action(
                                        ContextMenuActionItem(
                                            text: sponsorInfo,
                                            textColor: .primary,
                                            textLayout: .multiline,
                                            textFont: .custom(font: Font.regular(floor(presentationData.listsFontSize.baseDisplaySize * 0.8)), height: nil, verticalOffset: nil),
                                            badge: nil,
                                            icon: { _ in
                                                return nil
                                            },
                                            iconSource: nil,
                                            action: { [weak self] c, _ in
                                                c?.dismiss(completion: {
                                                    UIPasteboard.general.string = sponsorInfo
                                                    self?.displayUndo(.copy(text: presentationData.strings.Chat_ContextMenu_AdSponsorInfoCopied))
                                                })
                                            }
                                        )
                                    )
                                )
                            }

                            if let additionalInfo = adAttribute.additionalInfo {
                                subItems.append(
                                    .action(
                                        ContextMenuActionItem(
                                            text: additionalInfo,
                                            textColor: .primary,
                                            textLayout: .multiline,
                                            textFont: .custom(font: Font.regular(floor(presentationData.listsFontSize.baseDisplaySize * 0.8)), height: nil, verticalOffset: nil),
                                            badge: nil,
                                            icon: { _ in
                                                return nil
                                            },
                                            iconSource: nil,
                                            action: { [weak self] c, _ in
                                                c?.dismiss(completion: {
                                                    UIPasteboard.general.string = additionalInfo
                                                    self?.displayUndo(.copy(text: presentationData.strings.Chat_ContextMenu_AdSponsorInfoCopied))
                                                })
                                            }
                                        )
                                    )
                                )
                            }

                            c?.pushItems(items: .single(ContextController.Items(content: .list(subItems))))
                        }
                    )
                )
            )
        }

        let removeAd = self.removeAd
        if adAttribute.canReport {
            actions.append(
                .action(
                    ContextMenuActionItem(
                        text: presentationData.strings.Chat_ContextMenu_ReportAd,
                        textColor: .primary,
                        textLayout: .twoLinesMax,
                        textFont: .custom(font: Font.regular(presentationData.listsFontSize.baseDisplaySize - 1.0), height: nil, verticalOffset: nil),
                        badge: nil,
                        icon: { theme in
                            return generateTintedImage(image: UIImage(bundleImageName: "Chat/Context Menu/Restrict"), color: theme.actionSheet.primaryTextColor)
                        },
                        iconSource: nil,
                        action: { [weak self] _, f in
                            f(.default)

                            guard let navigationController = self?.navigationController as? NavigationController else {
                                return
                            }

                            let _ = (
                                context.engine.messages.reportAdMessage(opaqueId: adAttribute.opaqueId, option: nil)
                                |> deliverOnMainQueue
                            ).start(next: { [weak navigationController] result in
                                if case let .options(title, options) = result {
                                    Queue.mainQueue().after(0.2) {
                                        navigationController?.pushViewController(
                                            AdsReportScreen(
                                                context: context,
                                                opaqueId: adAttribute.opaqueId,
                                                title: title,
                                                options: options,
                                                completed: {
                                                }
                                            )
                                        )
                                    }
                                }
                            })
                        }
                    )
                )
            )

            actions.append(.separator)

            actions.append(
                .action(
                    ContextMenuActionItem(
                        text: presentationData.strings.Chat_ContextMenu_RemoveAd,
                        textColor: .primary,
                        textLayout: .twoLinesMax,
                        textFont: .custom(font: Font.regular(presentationData.listsFontSize.baseDisplaySize - 1.0), height: nil, verticalOffset: nil),
                        badge: nil,
                        icon: { theme in
                            return generateTintedImage(image: UIImage(bundleImageName: "Chat/Context Menu/Clear"), color: theme.actionSheet.primaryTextColor)
                        },
                        iconSource: nil,
                        action: { [weak self] c, _ in
                            c?.dismiss(completion: {
                                if context.isPremium {
                                    removeAd(adAttribute.opaqueId)
                                } else {
                                    self?.presentNoAdsDemo()
                                }
                            })
                        }
                    )
                )
            )
        } else {
            if !actions.isEmpty {
                actions.append(.separator)
            }
            actions.append(
                .action(
                    ContextMenuActionItem(
                        text: presentationData.strings.SponsoredMessageMenu_Hide,
                        textColor: .primary,
                        textLayout: .twoLinesMax,
                        textFont: .custom(font: Font.regular(presentationData.listsFontSize.baseDisplaySize - 1.0), height: nil, verticalOffset: nil),
                        badge: nil,
                        icon: { theme in
                            return generateTintedImage(image: UIImage(bundleImageName: "Chat/Context Menu/Clear"), color: theme.actionSheet.primaryTextColor)
                        },
                        iconSource: nil,
                        action: { [weak self] c, _ in
                            c?.dismiss(completion: {
                                if context.isPremium {
                                    removeAd(adAttribute.opaqueId)
                                } else {
                                    self?.presentNoAdsDemo()
                                }
                            })
                        }
                    )
                )
            )
        }

        let contextController = makeContextController(
            presentationData: presentationData,
            source: .reference(
                AdsInfoContextReferenceContentSource(
                    controller: self,
                    sourceView: referenceView,
                    insets: .zero,
                    contentInsets: .zero
                )
            ),
            items: .single(ContextController.Items(content: .list(actions))),
            gesture: nil
        )
        self.presentInGlobalOverlay(contextController)
    }

    fileprivate func presentNoAdsDemo() {
        guard let navigationController = self.navigationController as? NavigationController else {
            return
        }

        let context = self.context
        var replaceImpl: ((ViewController) -> Void)?
        let demoController = context.sharedContext.makePremiumDemoController(
            context: context,
            subject: .noAds,
            forceDark: false,
            action: {
                let controller = context.sharedContext.makePremiumIntroController(context: context, source: .ads, forceDark: false, dismissed: nil)
                replaceImpl?(controller)
            },
            dismissed: nil
        )
        replaceImpl = { [weak demoController] controller in
            demoController?.replace(with: controller)
        }

        self.dismissAnimated()
        Queue.mainQueue().after(0.4) {
            navigationController.pushViewController(demoController)
        }
    }
}

private final class AdsInfoContextReferenceContentSource: ContextReferenceContentSource {
    let controller: ViewController
    let sourceView: UIView
    let insets: UIEdgeInsets
    let contentInsets: UIEdgeInsets

    init(controller: ViewController, sourceView: UIView, insets: UIEdgeInsets, contentInsets: UIEdgeInsets = UIEdgeInsets()) {
        self.controller = controller
        self.sourceView = sourceView
        self.insets = insets
        self.contentInsets = contentInsets
    }

    func transitionInfo() -> ContextControllerReferenceViewInfo? {
        return ContextControllerReferenceViewInfo(
            referenceView: self.sourceView,
            contentAreaInScreenSpace: UIScreen.main.bounds.inset(by: self.insets),
            insets: self.contentInsets
        )
    }
}
