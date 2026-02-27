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
import ButtonComponent
import Markdown
import GlassBarButtonComponent
import PremiumUI
import ScrollComponent
import LottieComponent
import EdgeEffect
import InfoParagraphComponent

final class PageComponent<ChildEnvironment: Equatable>: CombinedComponent {
    typealias EnvironmentType = ChildEnvironment
    
    private let content: AnyComponent<ChildEnvironment>
    private let title: String
    private let text: String
    private let textColor: UIColor
    
    init(
        content: AnyComponent<ChildEnvironment>,
        title: String,
        text: String,
        textColor: UIColor
    ) {
        self.content = content
        self.title = title
        self.text = text
        self.textColor = textColor
    }
    
    static func ==(lhs: PageComponent<ChildEnvironment>, rhs: PageComponent<ChildEnvironment>) -> Bool {
        if lhs.content != rhs.content {
            return false
        }
        if lhs.title != rhs.title {
            return false
        }
        if lhs.text != rhs.text {
            return false
        }
        if lhs.textColor != rhs.textColor {
            return false
        }
        return true
    }
    
    static var body: Body {
        let children = ChildMap(environment: ChildEnvironment.self, keyedBy: AnyHashable.self)
        let title = Child(MultilineTextComponent.self)
        let text = Child(MultilineTextComponent.self)

        return { context in
            let availableSize = context.availableSize
            let component = context.component
            
            let sideInset: CGFloat = 16.0
            let textSideInset: CGFloat = 24.0
            
            let textColor = component.textColor
            let textFont = Font.regular(17.0)
            let boldTextFont = Font.semibold(17.0)
            
            let content = children["main"].update(
                component: component.content,
                environment: {
                    context.environment[ChildEnvironment.self]
                },
                availableSize: CGSize(width: availableSize.width, height: availableSize.width),
                transition: context.transition
            )
                        
            let title = title.update(
                component: MultilineTextComponent(
                    text: .plain(NSAttributedString(
                        string: component.title,
                        font: boldTextFont,
                        textColor: component.textColor,
                        paragraphAlignment: .center
                    )),
                    horizontalAlignment: .center,
                    maximumNumberOfLines: 1
                ),
                availableSize: CGSize(width: context.availableSize.width - sideInset * 2.0, height: CGFloat.greatestFiniteMagnitude),
                transition: .immediate
            )
            
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
                    horizontalAlignment: .center,
                    maximumNumberOfLines: 0,
                    lineSpacing: 0.0
                ),
                availableSize: CGSize(width: context.availableSize.width - textSideInset * 2.0, height: context.availableSize.height),
                transition: .immediate
            )
            
            context.add(title
                .position(CGPoint(x: context.availableSize.width / 2.0, y: content.size.height + 40.0))
            )
            context.add(text
                .position(CGPoint(x: context.availableSize.width / 2.0, y: content.size.height + 60.0 + text.size.height / 2.0))
            )
            context.add(content
                .position(CGPoint(x: content.size.width / 2.0, y: content.size.height / 2.0))
            )
        
            return availableSize
        }
    }
}

private final class DemoSheetContent: CombinedComponent {
    typealias EnvironmentType = ViewControllerComponentContainer.Environment
    
    let context: AccountContext
    let action: () -> Void
    let dismiss: () -> Void
    
    init(
        context: AccountContext,
        action: @escaping () -> Void,
        dismiss: @escaping () -> Void
    ) {
        self.context = context
        self.action = action
        self.dismiss = dismiss
    }
    
    static func ==(lhs: DemoSheetContent, rhs: DemoSheetContent) -> Bool {
        if lhs.context !== rhs.context {
            return false
        }
        return true
    }
    
    final class State: ComponentState {
        private let context: AccountContext
        
        private var disposable: Disposable?
        private(set) var promoConfiguration: PremiumPromoConfiguration?
        
        fileprivate let playButtonAnimation = ActionSlot<Void>()
        private var didPlayAnimation = false
        
        init(context: AccountContext) {
            self.context = context
            
            super.init()
            
            self.disposable = (self.context.engine.data.get(TelegramEngine.EngineData.Item.Configuration.PremiumPromo())
            |> deliverOnMainQueue).start(next: { [weak self] promoConfiguration in
                guard let self else {
                    return
                }
                self.promoConfiguration = promoConfiguration
                self.updated(transition: .immediate)
            })
        }
        
        deinit {
            self.disposable?.dispose()
        }
        
        func playAnimationIfNeeded() {
            if !self.didPlayAnimation {
                self.didPlayAnimation = true
                self.playButtonAnimation.invoke(Void())
            }
        }
    }
    
    func makeState() -> State {
        return State(context: self.context)
    }
    
    static var body: Body {
        let closeButton = Child(GlassBarButtonComponent.self)
        let background = Child(PremiumGradientBackgroundComponent.self)
        let demo = Child(PhoneDemoComponent.self)
        let scroll = Child(ScrollComponent<Empty>.self)
        let bottomEdgeEffect = Child(EdgeEffectComponent.self)
        let button = Child(ButtonComponent.self)
        
        return { context in
            let environment = context.environment[ViewControllerComponentContainer.Environment.self].value
            let component = context.component
            let theme = environment.theme
            let strings = environment.strings
            
            let state = context.state
                                
            var contentSize = CGSize(width: context.availableSize.width, height: context.availableSize.width)
            
            let remainingHeight = 365.0
            let scroll = scroll.update(
                component: ScrollComponent<Empty>(
                    content: AnyComponent(
                        GiftDemoListComponent(
                            context: context.component.context,
                            theme: environment.theme
                        )
                    ),
                    contentInsets: UIEdgeInsets(top: 0.0, left: 0.0, bottom: 80.0, right: 0.0),
                    contentOffsetUpdated: { _, _ in },
                    contentOffsetWillCommit: { _ in }
                ),
                availableSize: CGSize(width: context.availableSize.width, height: remainingHeight),
                transition: context.transition
            )
            context.add(scroll
                .position(CGPoint(x: context.availableSize.width / 2.0, y: contentSize.height + scroll.size.height / 2.0))
            )
            
            let background = background.update(
                component: PremiumGradientBackgroundComponent(colors: [
                    UIColor(rgb: 0x0077ff),
                    UIColor(rgb: 0x6b93ff),
                    UIColor(rgb: 0x8878ff),
                    UIColor(rgb: 0xe46ace)
                ]),
                availableSize: CGSize(width: context.availableSize.width, height: context.availableSize.width),
                transition: .immediate
            )
            context.add(background
                .position(CGPoint(x: context.availableSize.width / 2.0, y: background.size.height / 2.0))
            )
            
            let demo = demo.update(
                component: PhoneDemoComponent(
                    context: component.context,
                    position: .top,
                    model: .island,
                    videoFile: state.promoConfiguration?.videos["gifts"],
                    decoration: .badgeStars
                ),
                environment: { DemoPageEnvironment(isDisplaying: true, isCentral: true, position: 0.0) },
                availableSize: CGSize(width: context.availableSize.width, height: context.availableSize.width),
                transition: context.transition
            )
            context.add(demo
                .position(CGPoint(x: context.availableSize.width / 2.0, y: demo.size.height / 2.0))
            )
            
            let closeButton = closeButton.update(
                component: GlassBarButtonComponent(
                    size: CGSize(width: 44.0, height: 44.0),
                    backgroundColor: UIColor(rgb: 0x7f76f4),
                    isDark: false,
                    state: .tintedGlass,
                    component: AnyComponentWithIdentity(id: "close", component: AnyComponent(
                        BundleIconComponent(
                            name: "Navigation/Close",
                            tintColor: .white
                        )
                    )),
                    action: { _ in
                        component.dismiss()
                    }
                ),
                availableSize: CGSize(width: 44.0, height: 44.0),
                transition: .immediate
            )
            context.add(closeButton
                .position(CGPoint(x: 16.0 + closeButton.size.width / 2.0, y: 16.0 + closeButton.size.height / 2.0))
            )
            
            contentSize.height += remainingHeight
            
            let bottomEdgeEffectHeight = 108.0
            let bottomEdgeEffect = bottomEdgeEffect.update(
                component: EdgeEffectComponent(
                    color: environment.theme.actionSheet.opaqueItemBackgroundColor,
                    blur: true,
                    alpha: 1.0,
                    size: CGSize(width: context.availableSize.width, height: bottomEdgeEffectHeight),
                    edge: .bottom,
                    edgeSize: bottomEdgeEffectHeight
                ),
                availableSize: CGSize(width: context.availableSize.width, height: bottomEdgeEffectHeight),
                transition: context.transition
            )
            context.add(bottomEdgeEffect
                .position(CGPoint(x: context.availableSize.width / 2.0, y: contentSize.height - bottomEdgeEffect.size.height / 2.0))
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
                text: strings.Gift_Demo_Understood,
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
                        pressedColor: theme.list.itemCheckColors.fillColor.withMultipliedAlpha(0.9),
                        cornerRadius: 10.0,
                    ),
                    content: AnyComponentWithIdentity(
                        id: AnyHashable(0),
                        component: AnyComponent(HStack(buttonTitle, spacing: 2.0))
                    ),
                    action: {
                        component.dismiss()
                    }
                ),
                availableSize: CGSize(width: context.availableSize.width - 30.0 * 2.0, height: 52.0),
                transition: .immediate
            )
            context.add(button
                .position(CGPoint(x: context.availableSize.width / 2.0, y: contentSize.height - button.size.height / 2.0 - 30.0))
            )
            
            state.playAnimationIfNeeded()
            
            return contentSize
        }
    }
}


private final class DemoSheetComponent: CombinedComponent {
    typealias EnvironmentType = ViewControllerComponentContainer.Environment
    
    let context: AccountContext
    let action: () -> Void
    
    init(context: AccountContext, action: @escaping () -> Void) {
        self.context = context
        self.action = action
    }
    
    static func ==(lhs: DemoSheetComponent, rhs: DemoSheetComponent) -> Bool {
        if lhs.context !== rhs.context {
            return false
        }
        return true
    }
    
    static var body: Body {
        let sheet = Child(SheetComponent<(EnvironmentType)>.self)
        let animateOut = StoredActionSlot(Action<Void>.self)
        
        return { context in
            let environment = context.environment[EnvironmentType.self]
            
            let controller = environment.controller
            
            let sheet = sheet.update(
                component: SheetComponent<EnvironmentType>(
                    content: AnyComponent<EnvironmentType>(DemoSheetContent(
                        context: context.component.context,
                        action: context.component.action,
                        dismiss: {
                            animateOut.invoke(Action { _ in
                                if let controller = controller() {
                                    controller.dismiss(completion: nil)
                                }
                            })
                        }
                    )),
                    style: .glass,
                    backgroundColor: .color(environment.theme.actionSheet.opaqueItemBackgroundColor),
                    followContentSizeChanges: true,
                    animateOut: animateOut
                ),
                environment: {
                    environment
                    SheetComponentEnvironment(
                        metrics: environment.metrics,
                        deviceMetrics: environment.deviceMetrics,
                        isDisplaying: environment.value.isVisible,
                        isCentered: environment.metrics.widthClass == .regular,
                        hasInputHeight: !environment.inputHeight.isZero,
                        regularMetricsSize: nil,
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

public class GiftDemoScreen: ViewControllerComponentContainer {
    public init(context: AccountContext, action: @escaping () -> Void = {}) {
        super.init(context: context, component: DemoSheetComponent(context: context, action: action), navigationBarAppearance: .none, theme: .default)
        
        self.supportedOrientations = ViewControllerSupportedOrientations(regularSize: .all, compactSize: .portrait)
        
        self.navigationPresentation = .flatModal
    }
    
    required public init(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
        
    public override func viewDidLoad() {
        super.viewDidLoad()
        
        self.view.disablesInteractiveModalDismiss = true
    }
    
    public func dismissAnimated() {
        if let view = self.node.hostView.findTaggedView(tag: SheetComponent<ViewControllerComponentContainer.Environment>.View.Tag()) as? SheetComponent<ViewControllerComponentContainer.Environment>.View {
            view.dismissAnimated()
        }
    }
}

private final class GiftDemoListComponent: CombinedComponent {
    typealias EnvironmentType = (Empty, ScrollChildEnvironment)
    
    let context: AccountContext
    let theme: PresentationTheme
    
    init(context: AccountContext, theme: PresentationTheme) {
        self.context = context
        self.theme = theme
    }
    
    static func ==(lhs: GiftDemoListComponent, rhs: GiftDemoListComponent) -> Bool {
        if lhs.context !== rhs.context {
            return false
        }
        if lhs.theme !== rhs.theme {
            return false
        }
        return true
    }
    
    static var body: Body {
        let title = Child(MultilineTextComponent.self)
        let description = Child(BalancedTextComponent.self)
        let list = Child(List<Empty>.self)
        
        return { context in
            let theme = context.component.theme
            let strings = context.component.context.sharedContext.currentPresentationData.with { $0 }.strings
            
            let titleColor = theme.list.itemPrimaryTextColor
            let textColor = theme.list.itemSecondaryTextColor
            let iconColor = theme.list.itemAccentColor
            
            var contentSize = CGSize(width: context.availableSize.width, height: 32.0)
        
            let title = title.update(
                component: MultilineTextComponent(text: .plain(NSAttributedString(string: strings.Gift_Demo_Title, font: Font.bold(25.0), textColor: titleColor))),
                availableSize: context.availableSize,
                transition: context.transition
            )
            context.add(title
                .position(CGPoint(x: context.availableSize.width / 2.0, y: contentSize.height + title.size.height * 0.5))
            )
            contentSize.height += title.size.height
            contentSize.height += 9.0
            
            let description = description.update(
                component: BalancedTextComponent(
                    text: .plain(NSAttributedString(string: strings.Gift_Demo_Description, font: Font.regular(15.0), textColor: textColor)),
                    horizontalAlignment: .center,
                    maximumNumberOfLines: 0,
                    lineSpacing: 0.2
                ),
                availableSize: context.availableSize,
                transition: context.transition
            )
            context.add(description
                .position(CGPoint(x: context.availableSize.width / 2.0, y: contentSize.height + description.size.height * 0.5))
            )
            contentSize.height += description.size.height
            contentSize.height += 26.0
            
            var items: [AnyComponentWithIdentity<Empty>] = []
            items.append(
                AnyComponentWithIdentity(
                    id: "unique",
                    component: AnyComponent(InfoParagraphComponent(
                        title: strings.Gift_Demo_Unique_Title,
                        titleColor: titleColor,
                        text: strings.Gift_Demo_Unique_Text,
                        textColor: textColor,
                        accentColor: iconColor,
                        iconName: "Premium/Collectible/Unique",
                        iconColor: iconColor
                    ))
                )
            )
            items.append(
                AnyComponentWithIdentity(
                    id: "tradable",
                    component: AnyComponent(InfoParagraphComponent(
                        title: strings.Gift_Demo_Tradable_Title,
                        titleColor: titleColor,
                        text: strings.Gift_Demo_Tradable_Text,
                        textColor: textColor,
                        accentColor: iconColor,
                        iconName: "Premium/Collectible/Transferable",
                        iconColor: iconColor
                    ))
                )
            )
            items.append(
                AnyComponentWithIdentity(
                    id: "wearable",
                    component: AnyComponent(InfoParagraphComponent(
                        title: strings.Gift_Demo_Wearable_Title,
                        titleColor: titleColor,
                        text: strings.Gift_Demo_Wearable_Text,
                        textColor: textColor,
                        accentColor: iconColor,
                        iconName: "Premium/Collectible/Tradable",
                        iconColor: iconColor
                    ))
                )
            )
            
            let list = list.update(
                component: List(items),
                availableSize: CGSize(width: context.availableSize.width - 32.0 * 2.0, height: 10000.0),
                transition: context.transition
            )
            context.add(list
                .position(CGPoint(x: context.availableSize.width / 2.0, y: contentSize.height + list.size.height / 2.0))
            )
            contentSize.height += list.size.height
            contentSize.height += 88.0
            
            return CGSize(width: context.availableSize.width, height: contentSize.height)
        }
    }
}
