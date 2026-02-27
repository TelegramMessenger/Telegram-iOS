import Foundation
import UIKit
import Display
import AsyncDisplayKit
import Postbox
import TelegramCore
import SwiftSignalKit
import AccountContext
import TelegramPresentationData
import PresentationDataUtils
import ComponentFlow
import ViewControllerComponent
import SheetComponent
import MultilineTextComponent
import BalancedTextComponent
import BundleIconComponent
import Markdown
import TextFormat
import TelegramStringFormatting
import GlassBarButtonComponent
import ButtonComponent
import LottieComponent

private final class CocoonInfoSheetContent: CombinedComponent {
    typealias EnvironmentType = ViewControllerComponentContainer.Environment
    
    let context: AccountContext
    let animateOut: ActionSlot<Action<()>>
    let getController: () -> ViewController?
    
    init(
        context: AccountContext,
        animateOut: ActionSlot<Action<()>>,
        getController: @escaping () -> ViewController?
    ) {
        self.context = context
        self.animateOut = animateOut
        self.getController = getController
    }
    
    static func ==(lhs: CocoonInfoSheetContent, rhs: CocoonInfoSheetContent) -> Bool {
        if lhs.context !== rhs.context {
            return false
        }
        return true
    }
    
    final class State: ComponentState {
        private let context: AccountContext
        private let animateOut: ActionSlot<Action<()>>
        private let getController: () -> ViewController?
                
        fileprivate let playButtonAnimation = ActionSlot<Void>()
        private var didPlayAnimation = false
        
        var cachedDescription: String?
                
        init(
            context: AccountContext,
            animateOut: ActionSlot<Action<()>>,
            getController: @escaping () -> ViewController?
        ) {
            self.context = context
            self.animateOut = animateOut
            self.getController = getController
            
            super.init()
        }
        
        func playAnimationIfNeeded() {
            if !self.didPlayAnimation {
                self.didPlayAnimation = true
                self.playButtonAnimation.invoke(Void())
            }
        }
        
        func dismiss(animated: Bool) {
            guard let controller = self.getController() as? CocoonInfoScreen else {
                return
            }
            if animated {
                self.animateOut.invoke(Action { [weak controller] _ in
                    controller?.dismiss(completion: nil)
                })
            } else {
                controller.dismiss(animated: false)
            }
        }
    }
    
    func makeState() -> State {
        return State(context: self.context, animateOut: self.animateOut, getController: self.getController)
    }
    
    static var body: Body {
        let background = Child(GradientBackgroundComponent.self)
        let closeButton = Child(GlassBarButtonComponent.self)
        let icon = Child(BundleIconComponent.self)
        let logo = Child(BundleIconComponent.self)
        let text = Child(BalancedTextComponent.self)
        let list = Child(List<Empty>.self)
        let additionalText = Child(MultilineTextComponent.self)
        let button = Child(ButtonComponent.self)
        
        let navigateDisposable = MetaDisposable()
        
        return { context in
            let component = context.component
            let environment = context.environment[ViewControllerComponentContainer.Environment.self].value
            let state = context.state
            
            let theme = environment.theme
            let strings = environment.strings
            
            let sideInset: CGFloat = 30.0 + environment.safeInsets.left
            let textSideInset: CGFloat = 30.0 + environment.safeInsets.left
            
            let textFont = Font.regular(15.0)
            let boldTextFont = Font.semibold(15.0)
            
            let textColor = theme.actionSheet.primaryTextColor
            let secondaryTextColor = theme.actionSheet.secondaryTextColor
            let linkColor = theme.actionSheet.controlAccentColor
            
            let spacing: CGFloat = 16.0
            var contentSize = CGSize(width: context.availableSize.width, height: 28.0)
            
            let descriptionText: String
            if let cachedDescription = state.cachedDescription {
                descriptionText = cachedDescription
            } else {
                func updateText(_ input: String) -> String {
                    let pattern = #"\(([^()]*)\)"#
                    let boldPattern = #"\*\*(.*?)\*\*"#

                    let regex = try! NSRegularExpression(pattern: pattern)
                    let boldRegex = try! NSRegularExpression(pattern: boldPattern)

                    let nsInput = input as NSString
                    var result = input

                    let matches = regex.matches(in: input, range: NSRange(location: 0, length: nsInput.length))

                    for match in matches.reversed() {
                        let range = match.range(at: 1)
                        let inner = nsInput.substring(with: range)

                        let replacedInner = boldRegex.stringByReplacingMatches(
                            in: inner,
                            range: NSRange(location: 0, length: (inner as NSString).length),
                            withTemplate: "[$1]()"
                        )

                        result = (result as NSString).replacingCharacters(in: range, with: replacedInner)
                    }

                    return result
                }
                descriptionText = updateText(strings.CocoonInfo_Description)
                state.cachedDescription = descriptionText
            }
            
            let attributedText = parseMarkdownIntoAttributedString(
                descriptionText,
                attributes: MarkdownAttributes(
                    body: MarkdownAttributeSet(font: textFont, textColor: UIColor(rgb: 0xb8c9ef)),
                    bold: MarkdownAttributeSet(font: boldTextFont, textColor: UIColor(rgb: 0xb8c9ef)),
                    link: MarkdownAttributeSet(font: boldTextFont, textColor: UIColor(rgb: 0xffffff)),
                    linkAttribute: { _ in return nil }
                )
            )
            let text = text.update(
                component: BalancedTextComponent(
                    text: .plain(attributedText),
                    horizontalAlignment: .center,
                    maximumNumberOfLines: 0,
                    lineSpacing: 0.2
                ),
                availableSize: CGSize(width: context.availableSize.width - textSideInset * 2.0, height: context.availableSize.height),
                transition: .immediate
            )
                                            
            let background = background.update(
                component: GradientBackgroundComponent(
                    colors: [
                        UIColor(rgb: 0x061129),
                        UIColor(rgb: 0x08153d)
                    ]
                ),
                availableSize: CGSize(width: context.availableSize.width, height: text.size.height + 220.0),
                transition: context.transition
            )
            context.add(background
                .position(CGPoint(x: context.availableSize.width / 2.0, y: background.size.height / 2.0))
            )
            
            let icon = icon.update(
                component: BundleIconComponent(
                    name: "Premium/Cocoon", tintColor: nil
                ),
                availableSize: context.availableSize,
                transition: context.transition
            )
            context.add(icon
                .position(CGPoint(x: context.availableSize.width / 2.0, y: contentSize.height + icon.size.height / 2.0))
            )
            contentSize.height += icon.size.height
            contentSize.height += 14.0
        
            let logo = logo.update(
                component: BundleIconComponent(
                    name: "Premium/CocoonLogo", tintColor: nil
                ),
                availableSize: context.availableSize,
                transition: .immediate
            )
            context.add(logo
                .position(CGPoint(x: context.availableSize.width / 2.0, y: contentSize.height + logo.size.height / 2.0))
            )
            contentSize.height += logo.size.height
            contentSize.height += spacing - 8.0
            
            context.add(text
                .position(CGPoint(x: context.availableSize.width / 2.0, y: contentSize.height + text.size.height / 2.0))
            )
            contentSize.height += text.size.height
            contentSize.height += spacing + 31.0
            
            var items: [AnyComponentWithIdentity<Empty>] = []
            items.append(
                AnyComponentWithIdentity(
                    id: "private",
                    component: AnyComponent(ParagraphComponent(
                        title: strings.CocoonInfo_Private_Title,
                        titleColor: textColor,
                        text: strings.CocoonInfo_Private_Text,
                        textColor: secondaryTextColor,
                        accentColor: linkColor,
                        iconName: "Ads/Privacy",
                        iconColor: linkColor,
                        action: { _, _ in
                        }
                    ))
                )
            )
            items.append(
                AnyComponentWithIdentity(
                    id: "efficient",
                    component: AnyComponent(ParagraphComponent(
                        title: strings.CocoonInfo_Efficient_Title,
                        titleColor: textColor,
                        text: strings.CocoonInfo_Efficient_Text,
                        textColor: secondaryTextColor,
                        accentColor: linkColor,
                        iconName: "Premium/Stats",
                        iconColor: linkColor,
                        action: { _, _ in
                        }
                    ))
                )
            )
            items.append(
                AnyComponentWithIdentity(
                    id: "for_everyone",
                    component: AnyComponent(ParagraphComponent(
                        title: strings.CocoonInfo_ForEveryone_Title,
                        titleColor: textColor,
                        text: strings.CocoonInfo_ForEveryone_Text,
                        textColor: secondaryTextColor,
                        accentColor: linkColor,
                        iconName: "Chat/Input/Accessory Panels/Gift",
                        iconColor: linkColor,
                        action: { attributes, _ in
                            guard let link = attributes[NSAttributedString.Key(rawValue: TelegramTextAttributes.URL)] as? String, let controller = environment.controller() else {
                                return
                            }
                            switch link {
                            case "telegram":
                                component.context.sharedContext.handleTextLinkAction(context: component.context, peerId: nil, navigateDisposable: navigateDisposable, controller: controller, action: .tap, itemLink: .url(url: "https://t.me/cocoon", concealed: false))
                            case "web":
                                component.context.sharedContext.openExternalUrl(context: component.context, urlContext: .generic, url: "https://cocoon.org", forceExternal: true, presentationData: component.context.sharedContext.currentPresentationData.with { $0 }, navigationController: nil, dismissInput: {})
                            default:
                                break
                            }
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
            contentSize.height += spacing - 6.0
            
            let attributedAdditionalText = parseMarkdownIntoAttributedString(
                strings.CocoonInfo_IntergrateInfo,
                attributes: MarkdownAttributes(
                    body: MarkdownAttributeSet(font: Font.regular(13.0), textColor: secondaryTextColor),
                    bold: MarkdownAttributeSet(font: Font.semibold(13.0), textColor: secondaryTextColor),
                    link: MarkdownAttributeSet(font: Font.regular(13.0), textColor: linkColor),
                    linkAttribute: { contents in
                        return (TelegramTextAttributes.URL, contents)
                    }
                )
            )
            let additionalText = additionalText.update(
                component: MultilineTextComponent(
                    text: .plain(attributedAdditionalText),
                    horizontalAlignment: .center,
                    maximumNumberOfLines: 0,
                    lineSpacing: 0.2,
                    highlightColor: linkColor.withAlphaComponent(0.1),
                    highlightAction: { attributes in
                        if let _ = attributes[NSAttributedString.Key(rawValue: TelegramTextAttributes.URL)] {
                            return NSAttributedString.Key(rawValue: TelegramTextAttributes.URL)
                        } else {
                            return nil
                        }
                    },
                    tapAction: { _, _ in
                        guard let controller = environment.controller() else {
                            return
                        }
                        component.context.sharedContext.handleTextLinkAction(context: component.context, peerId: nil, navigateDisposable: navigateDisposable, controller: controller, action: .tap, itemLink: .url(url: "https://t.me/cocoon?direct", concealed: false))
                    }
                ),
                availableSize: CGSize(width: context.availableSize.width - textSideInset * 2.0, height: context.availableSize.height),
                transition: .immediate
            )
            context.add(additionalText
                .position(CGPoint(x: context.availableSize.width / 2.0, y: contentSize.height + additionalText.size.height / 2.0))
            )
            contentSize.height += additionalText.size.height
            contentSize.height += spacing + 6.0
            
            let closeButton = closeButton.update(
                component: GlassBarButtonComponent(
                    size: CGSize(width: 44.0, height: 44.0),
                    backgroundColor: UIColor(rgb: 0x071533),
                    isDark: true,
                    state: .tintedGlass,
                    component: AnyComponentWithIdentity(id: "close", component: AnyComponent(
                        BundleIconComponent(
                            name: "Navigation/Close",
                            tintColor: .white
                        )
                    )),
                    action: { [weak state] _ in
                        guard let state else {
                            return
                        }
                        state.dismiss(animated: true)
                    }
                ),
                availableSize: CGSize(width: 44.0, height: 44.0),
                transition: .immediate
            )
            context.add(closeButton
                .position(CGPoint(x: 16.0 + closeButton.size.width / 2.0, y: 16.0 + closeButton.size.height / 2.0))
            )
            
            
            var buttonTitle: [AnyComponentWithIdentity<Empty>] = []
            buttonTitle.append(AnyComponentWithIdentity(id: 0, component: AnyComponent(LottieComponent(
                content: LottieComponent.AppBundleContent(name: "anim_ok"),
                color: theme.list.itemCheckColors.foregroundColor,
                startingPosition: .begin,
                size: CGSize(width: 28.0, height: 28.0),
                playOnce: state.playButtonAnimation
            ))))
            buttonTitle.append(AnyComponentWithIdentity(id: 1, component: AnyComponent(ButtonTextContentComponent(
                text: strings.CocoonInfo_Understood,
                badge: 0,
                textColor: theme.list.itemCheckColors.foregroundColor,
                badgeBackground: theme.list.itemCheckColors.foregroundColor,
                badgeForeground: theme.list.itemCheckColors.fillColor
            ))))
            
            let button = button.update(
                component: ButtonComponent(
                    background: ButtonComponent.Background(
                        style: .glass,
                        color: theme.list.itemCheckColors.fillColor,
                        foreground: theme.list.itemCheckColors.foregroundColor,
                        pressedColor: theme.list.itemCheckColors.fillColor.withMultipliedAlpha(0.9)
                    ),
                    content: AnyComponentWithIdentity(
                        id: AnyHashable(0),
                        component: AnyComponent(HStack(buttonTitle, spacing: 2.0))
                    ),
                    isEnabled: true,
                    displaysProgress: false,
                    action: { [weak state] in
                        guard let state else {
                            return
                        }
                        state.dismiss(animated: true)
                    }
                ),
                availableSize: CGSize(width: context.availableSize.width - 30.0 * 2.0, height: 52.0),
                transition: .immediate
            )
            context.add(button
                .position(CGPoint(x: context.availableSize.width / 2.0, y: contentSize.height + button.size.height / 2.0))
            )
            contentSize.height += button.size.height
 
            contentSize.height += 30.0
            
            state.playAnimationIfNeeded()
            
            return contentSize
        }
    }
}

final class CocoonInfoSheetComponent: CombinedComponent {
    typealias EnvironmentType = ViewControllerComponentContainer.Environment
    
    let context: AccountContext
    
    init(
        context: AccountContext
    ) {
        self.context = context
    }
    
    static func ==(lhs: CocoonInfoSheetComponent, rhs: CocoonInfoSheetComponent) -> Bool {
        if lhs.context !== rhs.context {
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
                    content: AnyComponent<EnvironmentType>(CocoonInfoSheetContent(
                        context: context.component.context,
                        animateOut: animateOut,
                        getController: controller
                    )),
                    style: .glass,
                    backgroundColor: .color(environment.theme.actionSheet.opaqueItemBackgroundColor),
                    followContentSizeChanges: true,
                    clipsContent: true,
                    autoAnimateOut: false,
                    externalState: sheetExternalState,
                    animateOut: animateOut,
                    onPan: {
                    },
                    willDismiss: {
                    }
                ),
                environment: {
                    environment
                    SheetComponentEnvironment(
                        metrics: environment.metrics,
                        deviceMetrics: environment.deviceMetrics,
                        isDisplaying: environment.value.isVisible,
                        isCentered: environment.metrics.widthClass == .regular,
                        hasInputHeight: !environment.inputHeight.isZero,
                        regularMetricsSize: CGSize(width: 430.0, height: 900.0),
                        dismiss: { animated in
                            if animated {
                                if let controller = controller() as? CocoonInfoScreen {
                                    animateOut.invoke(Action { _ in
                                        controller.dismiss(completion: nil)
                                    })
                                }
                            } else {
                                if let controller = controller() as? CocoonInfoScreen {
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
                var sideInset: CGFloat = 0.0
                var bottomInset: CGFloat = max(environment.safeInsets.bottom, sheetExternalState.contentHeight)
                if case .regular = environment.metrics.widthClass {
                    sideInset = floor((context.availableSize.width - 430.0) / 2.0) - 12.0
                    bottomInset = (context.availableSize.height - sheetExternalState.contentHeight) / 2.0 + sheetExternalState.contentHeight
                }
                
                let layout = ContainerViewLayout(
                    size: context.availableSize,
                    metrics: environment.metrics,
                    deviceMetrics: environment.deviceMetrics,
                    intrinsicInsets: UIEdgeInsets(top: 0.0, left: 0.0, bottom: bottomInset, right: 0.0),
                    safeInsets: UIEdgeInsets(top: 0.0, left: max(sideInset, environment.safeInsets.left), bottom: 0.0, right: max(sideInset, environment.safeInsets.right)),
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

public final class CocoonInfoScreen: ViewControllerComponentContainer {
    private let context: AccountContext
    
    public init(
        context: AccountContext
    ) {
        self.context = context
        
        super.init(
            context: context,
            component: CocoonInfoSheetComponent(
                context: context
            ),
            navigationBarAppearance: .none,
            statusBarStyle: .ignore,
            theme: .default
        )
        
        self.navigationPresentation = .flatModal
        self.automaticallyControlPresentationContextLayout = false
    }
    
    required public init(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    deinit {
    }
    
    public override func viewDidLoad() {
        super.viewDidLoad()
        
        self.view.disablesInteractiveModalDismiss = true
    }
    
    public override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
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
    let action: (([NSAttributedString.Key: Any], Int) -> Void)?
    
    public init(
        title: String,
        titleColor: UIColor,
        text: String,
        textColor: UIColor,
        accentColor: UIColor,
        iconName: String,
        iconColor: UIColor,
        action: (([NSAttributedString.Key: Any], Int) -> Void)?
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
                    tapAction: { attributes, index in
                        component.action?(attributes, index)
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

private final class GradientBackgroundComponent: Component {
    let colors: [UIColor]
    
    init(
        colors: [UIColor]
    ) {
        self.colors = colors
    }
    
    static func ==(lhs: GradientBackgroundComponent, rhs: GradientBackgroundComponent) -> Bool {
        if lhs.colors != rhs.colors {
            return false
        }
        return true
    }
    
    public final class View: UIView {
        private let gradientLayer: CAGradientLayer
        
        private var component: GradientBackgroundComponent?
        
        override init(frame: CGRect) {
            self.gradientLayer = CAGradientLayer()
            
            super.init(frame: frame)
            
            self.layer.addSublayer(self.gradientLayer)
        }
        
        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }
        
        func update(component: GradientBackgroundComponent, availableSize: CGSize, state: EmptyComponentState, environment: Environment<Empty>, transition: ComponentTransition) -> CGSize {
            self.gradientLayer.frame = CGRect(origin: .zero, size: availableSize)
            
            var locations: [NSNumber] = []
            let delta = 1.0 / CGFloat(component.colors.count - 1)
            for i in 0 ..< component.colors.count {
                locations.append((delta * CGFloat(i)) as NSNumber)
            }

            self.gradientLayer.locations = locations
            self.gradientLayer.colors = component.colors.reversed().map { $0.cgColor }
            self.gradientLayer.type = .radial
            self.gradientLayer.startPoint = CGPoint(x: 0.5, y: 0.5)
            self.gradientLayer.endPoint = CGPoint(x: 1.0, y: 1.0)

            self.component = component
            
            return availableSize
        }
    }
    
    public func makeView() -> View {
        return View(frame: CGRect())
    }
    
    public func update(view: View, availableSize: CGSize, state: EmptyComponentState, environment: Environment<Empty>, transition: ComponentTransition) -> CGSize {
        return view.update(component: self, availableSize: availableSize, state: state, environment: environment, transition: transition)
    }
}
