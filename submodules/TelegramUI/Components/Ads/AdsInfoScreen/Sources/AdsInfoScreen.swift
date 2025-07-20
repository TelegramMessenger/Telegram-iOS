import Foundation
import UIKit
import Display
import AsyncDisplayKit
import ComponentFlow
import SwiftSignalKit
import Postbox
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
import PresentationDataUtils
import ContextUI
import UndoUI
import AdsReportScreen

private let moreTag = GenericComponentViewTag()

private final class ScrollContent: CombinedComponent {
    typealias EnvironmentType = (ViewControllerComponentContainer.Environment, ScrollChildEnvironment)
    
    let context: AccountContext
    let mode: AdsInfoScreen.Mode
    let openPremium: () -> Void
    let dismiss: () -> Void
    
    init(
        context: AccountContext,
        mode: AdsInfoScreen.Mode,
        openPremium: @escaping () -> Void,
        dismiss: @escaping () -> Void
    ) {
        self.context = context
        self.mode = mode
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
                adsText =  strings.AdsInfo_Bot_Ads_Text
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
                    component: AnyComponent(ParagraphComponent(
                        title: strings.AdsInfo_Respect_Title,
                        titleColor: textColor,
                        text: respectText,
                        textColor: secondaryTextColor,
                        accentColor: linkColor,
                        iconName: "Ads/Privacy",
                        iconColor: linkColor
                    ))
                )
            )
            if case .search = component.mode {
                
            } else {
                items.append(
                    AnyComponentWithIdentity(
                        id: "split",
                        component: AnyComponent(ParagraphComponent(
                            title: component.mode == .bot ? strings.AdsInfo_Bot_Split_Title : strings.AdsInfo_Split_Title,
                            titleColor: textColor,
                            text: component.mode == .bot ? strings.AdsInfo_Bot_Split_Text : strings.AdsInfo_Split_Text,
                            textColor: secondaryTextColor,
                            accentColor: linkColor,
                            iconName: "Ads/Split",
                            iconColor: linkColor
                        ))
                    )
                )
            }
            items.append(
                AnyComponentWithIdentity(
                    id: "ads",
                    component: AnyComponent(ParagraphComponent(
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
                    color: theme.overallDarkAppearance ? theme.list.itemModalBlocksBackgroundColor : theme.list.blocksBackgroundColor,
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
    
    class ExternalState {
        var contentHeight: CGFloat = 0.0
    }
    
    let context: AccountContext
    let mode: AdsInfoScreen.Mode
    let externalState: ExternalState
    let openPremium: () -> Void
    let openContextMenu: () -> Void
    let dismiss: () -> Void
    
    init(
        context: AccountContext,
        mode: AdsInfoScreen.Mode,
        externalState: ExternalState,
        openPremium: @escaping () -> Void,
        openContextMenu: @escaping () -> Void,
        dismiss: @escaping () -> Void
    ) {
        self.context = context
        self.mode = mode
        self.externalState = externalState
        self.openPremium = openPremium
        self.openContextMenu = openContextMenu
        self.dismiss = dismiss
    }
    
    static func ==(lhs: ContainerComponent, rhs: ContainerComponent) -> Bool {
        if lhs.context !== rhs.context {
            return false
        }
        if lhs.mode != rhs.mode {
            return false
        }
        return true
    }
    
    final class State: ComponentState {
        var topContentOffset: CGFloat?
        var bottomContentOffset: CGFloat?
        
        var cachedMoreImage: (UIImage, PresentationTheme)?
    }
    
    func makeState() -> State {
        return State()
    }
    
    static var body: Body {
        let background = Child(Rectangle.self)
        let scroll = Child(ScrollComponent<ViewControllerComponentContainer.Environment>.self)
        let scrollExternalState = ScrollComponent<EnvironmentType>.ExternalState()
        
        let moreButton = Child(Button.self)
        
        return { context in
            let environment = context.environment[EnvironmentType.self]
            let state = context.state
            
            let theme = environment.theme
            
            let openContextMenu = context.component.openContextMenu
            let dismiss = context.component.dismiss
                        
            let background = background.update(
                component: Rectangle(color: theme.overallDarkAppearance ? theme.list.modalBlocksBackgroundColor : theme.list.plainBackgroundColor),
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
                        mode: context.component.mode,
                        openPremium: context.component.openPremium,
                        dismiss: {
                            dismiss()
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
            context.component.externalState.contentHeight = scrollExternalState.contentHeight
            
            context.add(scroll
                .position(CGPoint(x: context.availableSize.width / 2.0, y: context.availableSize.height / 2.0))
            )
            
            if case .bot = context.component.mode {
                let moreImage: UIImage
                if let (image, theme) = state.cachedMoreImage, theme === environment.theme {
                    moreImage = image
                } else {
                    moreImage = generateMoreButtonImage(backgroundColor: UIColor(rgb: 0x808084, alpha: 0.1), foregroundColor: environment.theme.actionSheet.inputClearButtonColor)!
                    state.cachedMoreImage = (moreImage, environment.theme)
                }
                let moreButton = moreButton.update(
                    component: Button(
                        content: AnyComponent(Image(image: moreImage)),
                        action: {
                            openContextMenu()
                        }
                    ).tagged(moreTag),
                    availableSize: CGSize(width: 30.0, height: 30.0),
                    transition: .immediate
                )
                context.add(moreButton
                    .position(CGPoint(x: context.availableSize.width - 16.0 - moreButton.size.width / 2.0, y: 13.0 + moreButton.size.height / 2.0))
                )
            }
            
            return context.availableSize
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


public class AdsInfoScreen: ViewController {
    public enum Mode: Equatable {
        case channel
        case bot
        case search
    }
    
    final class Node: ViewControllerTracingNode, ASGestureRecognizerDelegate {
        private var presentationData: PresentationData
        private weak var controller: AdsInfoScreen?
                
        let dim: ASDisplayNode
        let wrappingView: UIView
        let containerView: UIView
        
        let contentView: ComponentHostView<ViewControllerComponentContainer.Environment>
        let footerContainerView: UIView
        let footerView: ComponentHostView<Empty>
        
        private var containerExternalState = ContainerComponent.ExternalState()
                        
        private(set) var isExpanded = false
        private var panGestureRecognizer: UIPanGestureRecognizer?
        private var panGestureArguments: (topInset: CGFloat, offset: CGFloat, scrollView: UIScrollView?)?
        
        private let hapticFeedback = HapticFeedback()
        
        private var currentIsVisible: Bool = false
        private var currentLayout: ContainerViewLayout?
                        
        init(context: AccountContext, controller: AdsInfoScreen) {
            self.presentationData = context.sharedContext.currentPresentationData.with { $0 }
            if controller.forceDark {
                self.presentationData = self.presentationData.withUpdated(theme: defaultDarkColorPresentationTheme)
            }
            self.presentationData = self.presentationData.withUpdated(theme: self.presentationData.theme.withModalBlocksBackground())
            
            self.controller = controller
            
            self.dim = ASDisplayNode()
            self.dim.alpha = 0.0
            self.dim.backgroundColor = UIColor(white: 0.0, alpha: 0.25)
            
            self.wrappingView = UIView()
            self.containerView = UIView()
            self.contentView = ComponentHostView()
            
            self.footerContainerView = UIView()
            self.footerView = ComponentHostView()
            
            super.init()
                                    
            self.containerView.clipsToBounds = true
            self.containerView.backgroundColor = self.presentationData.theme.overallDarkAppearance ? self.presentationData.theme.list.modalBlocksBackgroundColor : self.presentationData.theme.list.plainBackgroundColor
            
            self.addSubnode(self.dim)
            
            self.view.addSubview(self.wrappingView)
            self.wrappingView.addSubview(self.containerView)
            self.containerView.addSubview(self.contentView)
            
            self.containerView.addSubview(self.footerContainerView)
            self.footerContainerView.addSubview(self.footerView)
        }
        
        override func didLoad() {
            super.didLoad()
            
            let panRecognizer = UIPanGestureRecognizer(target: self, action: #selector(self.panGesture(_:)))
            panRecognizer.delegate = self.wrappedGestureRecognizerDelegate
            panRecognizer.delaysTouchesBegan = false
            panRecognizer.cancelsTouchesInView = true
            self.panGestureRecognizer = panRecognizer
            self.wrappingView.addGestureRecognizer(panRecognizer)
            
            self.dim.view.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(self.dimTapGesture(_:))))
            self.controller?.navigationBar?.updateBackgroundAlpha(0.0, transition: .immediate)
        }
        
        @objc func dimTapGesture(_ recognizer: UITapGestureRecognizer) {
            if case .ended = recognizer.state {
                self.controller?.dismiss(animated: true)
            }
        }
        
        override func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
            if let layout = self.currentLayout {
                if case .regular = layout.metrics.widthClass {
                    return false
                }
            }
            return true
        }
        
        func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool {
            if gestureRecognizer is UIPanGestureRecognizer && otherGestureRecognizer is UIPanGestureRecognizer {
                if let scrollView = otherGestureRecognizer.view as? UIScrollView {
                    if scrollView.contentSize.width > scrollView.contentSize.height {
                        return false
                    }
                }
                return true
            }
            return false
        }
        
        private var isDismissing = false
        func animateIn() {
            ContainedViewLayoutTransition.animated(duration: 0.3, curve: .linear).updateAlpha(node: self.dim, alpha: 1.0)
            
            let targetPosition = self.containerView.center
            let startPosition = targetPosition.offsetBy(dx: 0.0, dy: self.bounds.height)
            
            self.containerView.center = startPosition
            let transition = ContainedViewLayoutTransition.animated(duration: 0.4, curve: .spring)
            transition.animateView(allowUserInteraction: true, {
                self.containerView.center = targetPosition
            }, completion: { _ in
            })
        }
        
        func animateOut(completion: @escaping () -> Void = {}) {
            self.isDismissing = true
            
            let positionTransition: ContainedViewLayoutTransition = .animated(duration: 0.25, curve: .easeInOut)
            positionTransition.updatePosition(layer: self.containerView.layer, position: CGPoint(x: self.containerView.center.x, y: self.bounds.height + self.containerView.bounds.height / 2.0), completion: { [weak self] _ in
                self?.controller?.dismiss(animated: false, completion: completion)
            })
            let alphaTransition: ContainedViewLayoutTransition = .animated(duration: 0.25, curve: .easeInOut)
            alphaTransition.updateAlpha(node: self.dim, alpha: 0.0)
            
            self.controller?.updateModalStyleOverlayTransitionFactor(0.0, transition: positionTransition)
        }
        
        func requestLayout(transition: ComponentTransition) {
            guard let layout = self.currentLayout else {
                return
            }
            self.containerLayoutUpdated(layout: layout, forceUpdate: true, transition: transition)
        }
                
        private var dismissOffset: CGFloat?
        func containerLayoutUpdated(layout: ContainerViewLayout, forceUpdate: Bool = false, transition: ComponentTransition) {
            guard !self.isDismissing else {
                return
            }
            self.currentLayout = layout
            
            self.dim.frame = CGRect(origin: CGPoint(x: 0.0, y: -layout.size.height), size: CGSize(width: layout.size.width, height: layout.size.height * 3.0))
                                  
            let isLandscape = layout.orientation == .landscape
            
            var containerTopInset: CGFloat = 0.0
            let clipFrame: CGRect
            if layout.metrics.widthClass == .compact {
                self.dim.backgroundColor = UIColor(rgb: 0x000000, alpha: 0.25)
                if isLandscape {
                    self.containerView.layer.cornerRadius = 0.0
                } else {
                    self.containerView.layer.cornerRadius = 10.0
                }
                
                if #available(iOS 11.0, *) {
                    if layout.safeInsets.bottom.isZero {
                        self.containerView.layer.maskedCorners = [.layerMinXMinYCorner, .layerMaxXMinYCorner]
                    } else {
                        self.containerView.layer.maskedCorners = [.layerMinXMinYCorner, .layerMaxXMinYCorner, .layerMinXMaxYCorner, .layerMaxXMaxYCorner]
                    }
                }
                
                if isLandscape {
                    clipFrame = CGRect(origin: CGPoint(), size: layout.size)
                } else {
                    let coveredByModalTransition: CGFloat = 0.0
                    containerTopInset = 10.0
                    if let statusBarHeight = layout.statusBarHeight {
                        containerTopInset += statusBarHeight
                    }
                                        
                    let unscaledFrame = CGRect(origin: CGPoint(x: 0.0, y: containerTopInset - coveredByModalTransition * 10.0), size: CGSize(width: layout.size.width, height: layout.size.height - containerTopInset))
                    let maxScale: CGFloat = (layout.size.width - 16.0 * 2.0) / layout.size.width
                    let containerScale = 1.0 * (1.0 - coveredByModalTransition) + maxScale * coveredByModalTransition
                    let maxScaledTopInset: CGFloat = containerTopInset - 10.0
                    let scaledTopInset: CGFloat = containerTopInset * (1.0 - coveredByModalTransition) + maxScaledTopInset * coveredByModalTransition
                    let containerFrame = unscaledFrame.offsetBy(dx: 0.0, dy: scaledTopInset - (unscaledFrame.midY - containerScale * unscaledFrame.height / 2.0))
                    
                    clipFrame = CGRect(x: containerFrame.minX, y: containerFrame.minY, width: containerFrame.width, height: containerFrame.height)
                }
            } else {
                self.dim.backgroundColor = UIColor(rgb: 0x000000, alpha: 0.4)
                self.containerView.layer.cornerRadius = 10.0
  
                let verticalInset: CGFloat = 44.0
                
                let maxSide = max(layout.size.width, layout.size.height)
                let minSide = min(layout.size.width, layout.size.height)
                let containerSize = CGSize(width: min(layout.size.width - 20.0, floor(maxSide / 2.0)), height: min(layout.size.height, minSide) - verticalInset * 2.0)
                clipFrame = CGRect(origin: CGPoint(x: floor((layout.size.width - containerSize.width) / 2.0), y: floor((layout.size.height - containerSize.height) / 2.0)), size: containerSize)
            }
            
            transition.setFrame(view: self.containerView, frame: clipFrame)
            
            var effectiveExpanded = self.isExpanded
            if case .regular = layout.metrics.widthClass {
                effectiveExpanded = true
            }
        
            self.updated(transition: transition, forceUpdate: forceUpdate)
                        
            let contentHeight = self.containerExternalState.contentHeight
            if contentHeight > 0.0 && contentHeight < 400.0, let view = self.footerView.componentView as? FooterComponent.View {
                view.backgroundView.alpha = 0.0
                view.separator.opacity = 0.0
            }
            let edgeTopInset = isLandscape ? 0.0 : self.defaultTopInset

            let topInset: CGFloat
            if let (panInitialTopInset, panOffset, _) = self.panGestureArguments {
                if effectiveExpanded {
                    topInset = min(edgeTopInset, panInitialTopInset + max(0.0, panOffset))
                } else {
                    topInset = max(0.0, panInitialTopInset + min(0.0, panOffset))
                }
            } else if let dismissOffset = self.dismissOffset, !dismissOffset.isZero {
                topInset = edgeTopInset * dismissOffset
            } else {
                topInset = effectiveExpanded ? 0.0 : edgeTopInset
            }
            transition.setFrame(view: self.wrappingView, frame: CGRect(origin: CGPoint(x: 0.0, y: topInset), size: layout.size), completion: nil)
            
            let modalProgress = isLandscape ? 0.0 : (1.0 - topInset / self.defaultTopInset)
            self.controller?.updateModalStyleOverlayTransitionFactor(modalProgress, transition: transition.containedViewLayoutTransition)
            
            let footerHeight = self.footerHeight
            let convertedFooterFrame = self.view.convert(CGRect(origin: CGPoint(x: clipFrame.minX, y: clipFrame.maxY - footerHeight), size: CGSize(width: clipFrame.width, height: footerHeight)), to: self.containerView)
            transition.setFrame(view: self.footerContainerView, frame: convertedFooterFrame)
        }
        
        func updated(transition: ComponentTransition, forceUpdate: Bool = false) {
            guard let controller = self.controller, let layout = self.currentLayout else {
                return
            }
            let environment = ViewControllerComponentContainer.Environment(
                statusBarHeight: 0.0,
                navigationHeight: 0.0,
                safeInsets: UIEdgeInsets(top: layout.intrinsicInsets.top + layout.safeInsets.top, left: layout.safeInsets.left, bottom: layout.intrinsicInsets.bottom + layout.safeInsets.bottom, right: layout.safeInsets.right),
                additionalInsets: layout.additionalInsets,
                inputHeight: layout.inputHeight ?? 0.0,
                metrics: layout.metrics,
                deviceMetrics: layout.deviceMetrics,
                orientation: layout.metrics.orientation,
                isVisible: self.currentIsVisible,
                theme: self.presentationData.theme,
                strings: self.presentationData.strings,
                dateTimeFormat: self.presentationData.dateTimeFormat,
                controller: { [weak self] in
                    return self?.controller
                }
            )
            let contentSize = self.contentView.update(
                transition: transition,
                component: AnyComponent(
                    ContainerComponent(
                        context: controller.context,
                        mode: controller.mode,
                        externalState: self.containerExternalState,
                        openPremium: { [weak self] in
                            guard let self, let controller = self.controller else {
                                return
                            }
                            
                            let context = controller.context
                            let forceDark = controller.forceDark
                            let navigationController = controller.navigationController
                            controller.dismiss(animated: true)
                            
                            Queue.mainQueue().after(0.3) {
                                let controller = context.sharedContext.makePremiumIntroController(context: context, source: .ads, forceDark: forceDark, dismissed: nil)
                                navigationController?.pushViewController(controller, animated: true)
                            }
                        },
                        openContextMenu: { [weak self] in
                            guard let self else {
                                return
                            }
                            self.infoPressed()
                        },
                        dismiss: { [weak self] in
                            guard let self, let controller = self.controller else {
                                return
                            }
                            controller.dismiss(animated: true)
                        }
                    )
                ),
                environment: { environment },
                forceUpdate: forceUpdate,
                containerSize: self.containerView.bounds.size
            )
            self.contentView.frame = CGRect(origin: .zero, size: contentSize)
            
            let footerHeight = self.footerHeight
            let footerSize = self.footerView.update(
                transition: .immediate,
                component: AnyComponent(
                    FooterComponent(
                        context: controller.context,
                        theme: self.presentationData.theme,
                        title: self.presentationData.strings.AdsInfo_Understood,
                        showBackground: controller.mode != .search,
                        action: { [weak self] in
                            guard let self else {
                                return
                            }
                            self.buttonPressed()
                        }
                    )
                ),
                environment: {},
                containerSize: CGSize(width: self.containerView.bounds.width, height: footerHeight)
            )
            self.footerView.frame = CGRect(origin: .zero, size: footerSize)
        }
        
        private var didPlayAppearAnimation = false
        func updateIsVisible(isVisible: Bool) {
            if self.currentIsVisible == isVisible {
                return
            }
            self.currentIsVisible = isVisible
            
            guard let layout = self.currentLayout else {
                return
            }
            self.containerLayoutUpdated(layout: layout, transition: .immediate)
            
            if !self.didPlayAppearAnimation {
                self.didPlayAppearAnimation = true
                self.animateIn()
            }
        }
        
        private var footerHeight: CGFloat {
            guard let layout = self.currentLayout else {
                return 58.0
            }
                        
            var footerHeight: CGFloat = 8.0 + 50.0
            footerHeight += layout.intrinsicInsets.bottom > 0.0 ? layout.intrinsicInsets.bottom + 5.0 : 8.0
            return footerHeight
        }
        
        private var defaultTopInset: CGFloat {
            guard let layout = self.currentLayout, let controller = self.controller else {
                return 210.0
            }
            if case .compact = layout.metrics.widthClass {
                let bottomPanelPadding: CGFloat = 12.0
                let bottomInset: CGFloat = layout.intrinsicInsets.bottom > 0.0 ? layout.intrinsicInsets.bottom + 5.0 : bottomPanelPadding
                let panelHeight: CGFloat = bottomPanelPadding + 50.0 + bottomInset + 28.0
                
                var defaultTopInset = layout.size.height - layout.size.width - 128.0 - panelHeight
                
                let containerTopInset = 10.0 + (layout.statusBarHeight ?? 0.0)
                let contentHeight = self.containerExternalState.contentHeight
                let footerHeight = self.footerHeight
                if contentHeight > 0.0 {
                    if case .search = controller.mode {
                        return (layout.size.height - containerTopInset) - contentHeight
                    } else {
                        let delta = (layout.size.height - defaultTopInset - containerTopInset) - contentHeight - footerHeight - 16.0
                        if delta > 0.0 {
                            defaultTopInset += delta
                        }
                    }
                }
                return defaultTopInset
            } else {
                return 210.0
            }
        }
        
        private func findVerticalScrollView(view: UIView?) -> UIScrollView? {
            if let view = view {
                if let view = view as? UIScrollView, view.contentSize.height > view.contentSize.width {
                    return view
                }
                return findVerticalScrollView(view: view.superview)
            } else {
                return nil
            }
        }
        
        @objc func panGesture(_ recognizer: UIPanGestureRecognizer) {
            guard let layout = self.currentLayout, let controller = self.controller else {
                return
            }
            
            let isLandscape = layout.orientation == .landscape
            let edgeTopInset = isLandscape ? 0.0 : defaultTopInset
        
            switch recognizer.state {
                case .began:
                    let point = recognizer.location(in: self.view)
                    let currentHitView = self.hitTest(point, with: nil)
                    
                    var scrollView = self.findVerticalScrollView(view: currentHitView)
                    if scrollView?.frame.height == self.frame.width {
                        scrollView = nil
                    }
                    if scrollView?.isDescendant(of: self.view) == false {
                        scrollView = nil
                    }
                                
                    let topInset: CGFloat
                    if self.isExpanded {
                        topInset = 0.0
                    } else {
                        topInset = edgeTopInset
                    }
                
                    self.panGestureArguments = (topInset, 0.0, scrollView)
                case .changed:
                    guard let (topInset, panOffset, scrollView) = self.panGestureArguments else {
                        return
                    }
                    let contentOffset = scrollView?.contentOffset.y ?? 0.0
                    
                    var translation = recognizer.translation(in: self.view).y
                    if case .search = controller.mode {
                        translation = max(0.0, translation)
                    }

                    var currentOffset = topInset + translation
                
                    let epsilon = 1.0
                    if let scrollView = scrollView, contentOffset <= -scrollView.contentInset.top + epsilon {
                        scrollView.bounces = false
                        scrollView.setContentOffset(CGPoint(x: 0.0, y: -scrollView.contentInset.top), animated: false)
                    } else if let scrollView = scrollView {
                        translation = panOffset
                        currentOffset = topInset + translation
                        if self.isExpanded {
                            recognizer.setTranslation(CGPoint(), in: self.view)
                        } else if currentOffset > 0.0 {
                            scrollView.setContentOffset(CGPoint(x: 0.0, y: -scrollView.contentInset.top), animated: false)
                        }
                    }
                
                    if scrollView == nil {
                        translation = max(0.0, translation)
                    }
                    
                    self.panGestureArguments = (topInset, translation, scrollView)
                    
                    if !self.isExpanded {
                        if currentOffset > 0.0, let scrollView = scrollView {
                            scrollView.panGestureRecognizer.setTranslation(CGPoint(), in: scrollView)
                        }
                    }
                
                    var bounds = self.bounds
                    if self.isExpanded {
                        bounds.origin.y = -max(0.0, translation - edgeTopInset)
                    } else {
                        bounds.origin.y = -translation
                    }
                    bounds.origin.y = min(0.0, bounds.origin.y)
                    self.bounds = bounds
                
                    self.containerLayoutUpdated(layout: layout, transition: .immediate)
                case .ended:
                    guard let (currentTopInset, panOffset, scrollView) = self.panGestureArguments else {
                        return
                    }
                    self.panGestureArguments = nil
                
                    let contentOffset = scrollView?.contentOffset.y ?? 0.0
                
                    var translation = recognizer.translation(in: self.view).y
                    var velocity = recognizer.velocity(in: self.view)
                    if case .search = controller.mode {
                        translation = max(0.0, translation)
                        velocity.y = max(0.0, velocity.y)
                    }
                
                    if self.isExpanded {
                        if contentOffset > 0.1 {
                            velocity = CGPoint()
                        }
                    }
                
                    var bounds = self.bounds
                    if self.isExpanded {
                        bounds.origin.y = -max(0.0, translation - edgeTopInset)
                    } else {
                        bounds.origin.y = -translation
                    }
                    bounds.origin.y = min(0.0, bounds.origin.y)
                
                    scrollView?.bounces = true
                
                    let offset = currentTopInset + panOffset
                    let topInset: CGFloat = edgeTopInset

                    var dismissing = false
                    if bounds.minY < -60 || (bounds.minY < 0.0 && velocity.y > 300.0) || (self.isExpanded && bounds.minY.isZero && velocity.y > 1800.0) {
                        self.controller?.dismiss(animated: true, completion: nil)
                        dismissing = true
                    } else if self.isExpanded {
                        if velocity.y > 300.0 || offset > topInset / 2.0 {
                            self.isExpanded = false
                            if let scrollView = scrollView {
                                scrollView.setContentOffset(CGPoint(x: 0.0, y: -scrollView.contentInset.top), animated: false)
                            }
                            
                            let distance = topInset - offset
                            let initialVelocity: CGFloat = distance.isZero ? 0.0 : abs(velocity.y / distance)
                            let transition = ContainedViewLayoutTransition.animated(duration: 0.45, curve: .customSpring(damping: 124.0, initialVelocity: initialVelocity))

                            self.containerLayoutUpdated(layout: layout, transition: ComponentTransition(transition))
                        } else {
                            self.isExpanded = true
                            
                            self.containerLayoutUpdated(layout: layout, transition: ComponentTransition(.animated(duration: 0.3, curve: .easeInOut)))
                        }
                    } else if scrollView != nil, (velocity.y < -300.0 || offset < topInset / 2.0) {
                        let initialVelocity: CGFloat = offset.isZero ? 0.0 : abs(velocity.y / offset)
                        let transition = ContainedViewLayoutTransition.animated(duration: 0.45, curve: .customSpring(damping: 124.0, initialVelocity: initialVelocity))
                        self.isExpanded = true
                       
                        self.containerLayoutUpdated(layout: layout, transition: ComponentTransition(transition))
                    } else {
                        if let scrollView = scrollView {
                            scrollView.setContentOffset(CGPoint(x: 0.0, y: -scrollView.contentInset.top), animated: false)
                        }
                        
                        self.containerLayoutUpdated(layout: layout, transition: ComponentTransition(.animated(duration: 0.3, curve: .easeInOut)))
                    }
                    
                    if !dismissing {
                        var bounds = self.bounds
                        let previousBounds = bounds
                        bounds.origin.y = 0.0
                        self.bounds = bounds
                        self.layer.animateBounds(from: previousBounds, to: self.bounds, duration: 0.3, timingFunction: CAMediaTimingFunctionName.easeInEaseOut.rawValue)
                    }
                case .cancelled:
                    self.panGestureArguments = nil
                    
                    self.containerLayoutUpdated(layout: layout, transition: ComponentTransition(.animated(duration: 0.3, curve: .easeInOut)))
                default:
                    break
            }
        }
        
        func updateDismissOffset(_ offset: CGFloat) {
            guard self.isExpanded, let layout = self.currentLayout else {
                return
            }
            
            self.dismissOffset = offset
            self.containerLayoutUpdated(layout: layout, transition: .immediate)
        }
        
        func update(isExpanded: Bool, transition: ContainedViewLayoutTransition) {
            guard isExpanded != self.isExpanded else {
                return
            }
            self.dismissOffset = nil
            self.isExpanded = isExpanded
            
            guard let layout = self.currentLayout else {
                return
            }
            self.containerLayoutUpdated(layout: layout, transition: ComponentTransition(transition))
        }
        
        func displayUndo(_ content: UndoOverlayContent) {
            guard let controller = self.controller else {
                return
            }
            let presentationData = controller.context.sharedContext.currentPresentationData.with { $0 }
            controller.present(UndoOverlayController(presentationData: presentationData, content: content, elevatedLayout: false, animateInAsReplacement: false, action: { _ in
                    return true
            }), in: .current)
        }
        
        func infoPressed() {
            guard let referenceView = self.contentView.findTaggedView(tag: moreTag), let controller = self.controller, let message = controller.message, let adAttribute = message.adAttribute else {
                return
            }

            let context = controller.context
            let presentationData = controller.context.sharedContext.currentPresentationData.with { $0 }
            
            var actions: [ContextMenuItem] = []
            if adAttribute.sponsorInfo != nil || adAttribute.additionalInfo != nil {
                actions.append(.action(ContextMenuActionItem(text: presentationData.strings.Chat_ContextMenu_AdSponsorInfo, textColor: .primary, icon: { theme in
                    return generateTintedImage(image: UIImage(bundleImageName: "Chat/Context Menu/Channels"), color: theme.actionSheet.primaryTextColor)
                }, iconSource: nil, action: { [weak self] c, _ in
                    var subItems: [ContextMenuItem] = []
                    
                    subItems.append(.action(ContextMenuActionItem(text: presentationData.strings.Common_Back, textColor: .primary, icon: { theme in
                        return generateTintedImage(image: UIImage(bundleImageName: "Chat/Context Menu/Back"), color: theme.actionSheet.primaryTextColor)
                    }, iconSource: nil, iconPosition: .left, action: { c, _ in
                        c?.popItems()
                    })))
                    
                    subItems.append(.separator)
                    
                    if let sponsorInfo = adAttribute.sponsorInfo {
                        subItems.append(.action(ContextMenuActionItem(text: sponsorInfo, textColor: .primary, textLayout: .multiline, textFont: .custom(font: Font.regular(floor(presentationData.listsFontSize.baseDisplaySize * 0.8)), height: nil, verticalOffset: nil), badge: nil, icon: { theme in
                            return nil
                        }, iconSource: nil, action: { [weak self] c, _ in
                            c?.dismiss(completion: {
                                UIPasteboard.general.string = sponsorInfo
                                
                                self?.displayUndo(.copy(text: presentationData.strings.Chat_ContextMenu_AdSponsorInfoCopied))
                            })
                        })))
                    }
                    if let additionalInfo = adAttribute.additionalInfo {
                        subItems.append(.action(ContextMenuActionItem(text: additionalInfo, textColor: .primary, textLayout: .multiline, textFont: .custom(font: Font.regular(floor(presentationData.listsFontSize.baseDisplaySize * 0.8)), height: nil, verticalOffset: nil), badge: nil, icon: { theme in
                            return nil
                        }, iconSource: nil, action: { [weak self] c, _ in
                            c?.dismiss(completion: {
                                UIPasteboard.general.string = additionalInfo
                                
                                self?.displayUndo(.copy(text: presentationData.strings.Chat_ContextMenu_AdSponsorInfoCopied))
                            })
                        })))
                    }
                    
                    c?.pushItems(items: .single(ContextController.Items(content: .list(subItems))))
                })))
            }
            
            let removeAd = self.controller?.removeAd
            if adAttribute.canReport {
                actions.append(.action(ContextMenuActionItem(text: presentationData.strings.Chat_ContextMenu_ReportAd, textColor: .primary, textLayout: .twoLinesMax, textFont: .custom(font: Font.regular(presentationData.listsFontSize.baseDisplaySize - 1.0), height: nil, verticalOffset: nil), badge: nil, icon: { theme in
                    return generateTintedImage(image: UIImage(bundleImageName: "Chat/Context Menu/Restrict"), color: theme.actionSheet.primaryTextColor)
                }, iconSource: nil, action: { [weak self] _, f in
                    f(.default)
                    
                    guard let navigationController = self?.controller?.navigationController as? NavigationController else {
                        return
                    }
                                                            
                    let _ = (context.engine.messages.reportAdMessage(opaqueId: adAttribute.opaqueId, option: nil)
                    |> deliverOnMainQueue).start(next: { [weak navigationController] result in
                        if case let .options(title, options) = result {
                            Queue.mainQueue().after(0.2) {
                                navigationController?.pushViewController(
                                    AdsReportScreen(
                                        context: context,
                                        opaqueId: adAttribute.opaqueId,
                                        title: title,
                                        options: options,
                                        completed: {
                                           // removeAd?(adAttribute.opaqueId)
                                        }
                                    )
                                )
                            }
                        }
                    })
                })))
                
                actions.append(.separator)
                               
                actions.append(.action(ContextMenuActionItem(text: presentationData.strings.Chat_ContextMenu_RemoveAd, textColor: .primary, textLayout: .twoLinesMax, textFont: .custom(font: Font.regular(presentationData.listsFontSize.baseDisplaySize - 1.0), height: nil, verticalOffset: nil), badge: nil, icon: { theme in
                    return generateTintedImage(image: UIImage(bundleImageName: "Chat/Context Menu/Clear"), color: theme.actionSheet.primaryTextColor)
                }, iconSource: nil, action: { [weak self] c, _ in
                    c?.dismiss(completion: {
                        if context.isPremium {
                            removeAd?(adAttribute.opaqueId)
                        } else {
                            self?.presentNoAdsDemo()
                        }
                    })
                })))
            } else {
                if !actions.isEmpty {
                    actions.append(.separator)
                }
                actions.append(.action(ContextMenuActionItem(text: presentationData.strings.SponsoredMessageMenu_Hide, textColor: .primary, textLayout: .twoLinesMax, textFont: .custom(font: Font.regular(presentationData.listsFontSize.baseDisplaySize - 1.0), height: nil, verticalOffset: nil), badge: nil, icon: { theme in
                    return generateTintedImage(image: UIImage(bundleImageName: "Chat/Context Menu/Clear"), color: theme.actionSheet.primaryTextColor)
                }, iconSource: nil, action: { [weak self] c, _ in
                    c?.dismiss(completion: {
                        if context.isPremium {
                            removeAd?(adAttribute.opaqueId)
                        } else {
                            self?.presentNoAdsDemo()
                        }
                    })
                })))
            }
            
            let contextController = ContextController(presentationData: presentationData, source: .reference(AdsInfoContextReferenceContentSource(controller: controller, sourceView: referenceView, insets: .zero, contentInsets: .zero)), items: .single(ContextController.Items(content: .list(actions))), gesture: nil)
            controller.presentInGlobalOverlay(contextController)
        }
        
        func presentNoAdsDemo() {
            guard let controller = self.controller, let navigationController = controller.navigationController as? NavigationController else {
                return
            }
            let context = controller.context
            var replaceImpl: ((ViewController) -> Void)?
            let demoController = context.sharedContext.makePremiumDemoController(context: context, subject: .noAds, forceDark: false, action: {
                let controller = context.sharedContext.makePremiumIntroController(context: context, source: .ads, forceDark: false, dismissed: nil)
                replaceImpl?(controller)
            }, dismissed: nil)
            replaceImpl = { [weak demoController] c in
                demoController?.replace(with: c)
            }
            controller.dismiss(animated: true)
            Queue.mainQueue().after(0.4) {
                navigationController.pushViewController(demoController)
            }
        }
            
        func buttonPressed() {
            self.controller?.dismiss(animated: true)
        }
    }
    
    var node: Node {
        return self.displayNode as! Node
    }
    
    private let context: AccountContext
    private let mode: Mode
    private let message: Message?
    private let forceDark: Bool
    
    private var currentLayout: ContainerViewLayout?
    
    public var removeAd: (Data) -> Void = { _ in }
            
    public init(
        context: AccountContext,
        mode: Mode,
        message: Message? = nil,
        forceDark: Bool = false
    ) {
        self.context = context
        self.mode = mode
        self.message = message
        self.forceDark = forceDark
        
        super.init(navigationBarPresentationData: nil)
        
        self.navigationPresentation = .flatModal
        self.statusBar.statusBarStyle = .Ignore
        
        self.supportedOrientations = ViewControllerSupportedOrientations(regularSize: .all, compactSize: .portrait)
    }
        
    required public init(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override open func loadDisplayNode() {
        self.displayNode = Node(context: self.context, controller: self)
        self.displayNodeDidLoad()
        
        self.view.disablesInteractiveModalDismiss = true
    }
    
    public override func dismiss(animated flag: Bool, completion: (() -> Void)? = nil) {
        self.view.endEditing(true)
        if flag {
            self.node.animateOut(completion: {
                super.dismiss(animated: false, completion: {})
                completion?()
            })
        } else {
            super.dismiss(animated: false, completion: {})
            completion?()
        }
    }
    
    override open func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        self.node.updateIsVisible(isVisible: true)
    }
    
    override open func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
                
        self.node.updateIsVisible(isVisible: false)
    }
        
    override open func containerLayoutUpdated(_ layout: ContainerViewLayout, transition: ContainedViewLayoutTransition) {
        self.currentLayout = layout
        super.containerLayoutUpdated(layout, transition: transition)
                
        self.node.containerLayoutUpdated(layout: layout, transition: ComponentTransition(transition))
    }
}

private final class FooterComponent: Component {
    let context: AccountContext
    let theme: PresentationTheme
    let title: String
    let showBackground: Bool
    let action: () -> Void

    init(context: AccountContext, theme: PresentationTheme, title: String, showBackground: Bool, action: @escaping () -> Void) {
        self.context = context
        self.theme = theme
        self.title = title
        self.showBackground = showBackground
        self.action = action
    }

    static func ==(lhs: FooterComponent, rhs: FooterComponent) -> Bool {
        if lhs.context !== rhs.context {
            return false
        }
        if lhs.theme !== rhs.theme {
            return false
        }
        if lhs.title != rhs.title {
            return false
        }
        if lhs.showBackground != rhs.showBackground {
            return false
        }
        return true
    }

    final class View: UIView {
        let backgroundView: BlurredBackgroundView
        let separator = SimpleLayer()
        
        private let button = ComponentView<Empty>()
        
        private var component: FooterComponent?
        private weak var state: EmptyComponentState?
        
        override init(frame: CGRect) {
            self.backgroundView = BlurredBackgroundView(color: nil)
            
            super.init(frame: frame)
            
            self.backgroundView.clipsToBounds = true
            
            self.addSubview(self.backgroundView)
            self.layer.addSublayer(self.separator)
        }
        
        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }
        
        func update(component: FooterComponent, availableSize: CGSize, state: EmptyComponentState, environment: Environment<Empty>, transition: ComponentTransition) -> CGSize {
            self.component = component
            self.state = state
            
            let bounds = CGRect(origin: .zero, size: availableSize)
            
            self.backgroundView.updateColor(color: component.theme.rootController.tabBar.backgroundColor, transition: transition.containedViewLayoutTransition)
            self.backgroundView.update(size: bounds.size, transition: transition.containedViewLayoutTransition)
            transition.setFrame(view: self.backgroundView, frame: bounds)
            
            self.separator.backgroundColor = component.theme.rootController.tabBar.separatorColor.cgColor
            transition.setFrame(layer: self.separator, frame: CGRect(origin: .zero, size: CGSize(width: availableSize.width, height: UIScreenPixel)))
            
            self.backgroundView.isHidden = !component.showBackground
            self.separator.isHidden = !component.showBackground
            
            let buttonSize = self.button.update(
                transition: .immediate,
                component: AnyComponent(
                    SolidRoundedButtonComponent(
                        title: component.title,
                        theme: SolidRoundedButtonComponent.Theme(theme: component.theme),
                        font: .bold,
                        fontSize: 17.0,
                        height: 50.0,
                        cornerRadius: 10.0,
                        gloss: false,
                        animationName: nil,
                        iconPosition: .left,
                        action: {
                            component.action()
                        }
                    )
                ),
                environment: {},
                containerSize: CGSize(width: availableSize.width - 32.0, height: availableSize.height)
            )
            
            if let view = self.button.view {
                if view.superview == nil {
                    self.addSubview(view)
                }
                let buttonFrame = CGRect(origin: CGPoint(x: 16.0, y: 8.0), size: buttonSize)
                view.frame = buttonFrame
            }
                        
            return availableSize
        }
    }

    func makeView() -> View {
        return View(frame: CGRect())
    }

    func update(view: View, availableSize: CGSize, state: EmptyComponentState, environment: Environment<Empty>, transition: ComponentTransition) -> CGSize {
        return view.update(component: self, availableSize: availableSize, state: state, environment: environment, transition: transition)
    }
}

private func generateMoreButtonImage(backgroundColor: UIColor, foregroundColor: UIColor) -> UIImage? {
    return generateImage(CGSize(width: 30.0, height: 30.0), contextGenerator: { size, context in
        context.clear(CGRect(origin: CGPoint(), size: size))
        
        context.setFillColor(backgroundColor.cgColor)
        context.fillEllipse(in: CGRect(origin: CGPoint(), size: size))
        
        context.setFillColor(foregroundColor.cgColor)
        
        let circleSize = CGSize(width: 4.0, height: 4.0)
        context.fillEllipse(in: CGRect(origin: CGPoint(x: floorToScreenPixels((size.height - circleSize.width) / 2.0), y: floorToScreenPixels((size.height - circleSize.height) / 2.0)), size: circleSize))
        
        context.fillEllipse(in: CGRect(origin: CGPoint(x: floorToScreenPixels((size.height - circleSize.width) / 2.0) - circleSize.width - 3.0, y: floorToScreenPixels((size.height - circleSize.height) / 2.0)), size: circleSize))
        
        context.fillEllipse(in: CGRect(origin: CGPoint(x: floorToScreenPixels((size.height - circleSize.width) / 2.0) + circleSize.width + 3.0, y: floorToScreenPixels((size.height - circleSize.height) / 2.0)), size: circleSize))
    })
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
        return ContextControllerReferenceViewInfo(referenceView: self.sourceView, contentAreaInScreenSpace: UIScreen.main.bounds.inset(by: self.insets), insets: self.contentInsets)
    }
}
