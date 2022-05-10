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
import BundleIconComponent
import SolidRoundedButtonComponent
import Markdown

private final class LimitSheetContent: CombinedComponent {
    typealias EnvironmentType = ViewControllerComponentContainer.Environment
    
    let context: AccountContext
    let subject: PremiumLimitScreen.Subject
    let action: () -> Void
    let dismiss: () -> Void
    
    init(context: AccountContext, subject: PremiumLimitScreen.Subject, action: @escaping () -> Void, dismiss: @escaping () -> Void) {
        self.context = context
        self.subject = subject
        self.action = action
        self.dismiss = dismiss
    }
    
    static func ==(lhs: LimitSheetContent, rhs: LimitSheetContent) -> Bool {
        if lhs.context !== rhs.context {
            return false
        }
        if lhs.subject != rhs.subject {
            return false
        }
        return true
    }
    
    final class State: ComponentState {
        private let context: AccountContext
        
        private var disposable: Disposable?
        var limits: EngineConfiguration.UserLimits
        var premiumLimits: EngineConfiguration.UserLimits
        
        init(context: AccountContext, subject: PremiumLimitScreen.Subject) {
            self.context = context
            self.limits = EngineConfiguration.UserLimits.defaultValue
            self.premiumLimits = EngineConfiguration.UserLimits.defaultValue
            
            super.init()
            
            self.disposable = (context.engine.data.get(
                TelegramEngine.EngineData.Item.Configuration.UserLimits(isPremium: false),
                TelegramEngine.EngineData.Item.Configuration.UserLimits(isPremium: true)
            ) |> deliverOnMainQueue).start(next: { [weak self] result in
                if let strongSelf = self {
                    let (limits, premiumLimits) = result
                    strongSelf.limits = limits
                    strongSelf.premiumLimits = premiumLimits
                    strongSelf.updated(transition: .immediate)
                }
            })
        }
        
        deinit {
            self.disposable?.dispose()
        }
    }
    
    func makeState() -> State {
        return State(context: self.context, subject: self.subject)
    }
    
    static var body: Body {
        let badgeBackground = Child(RoundedRectangle.self)
        let badgeIcon = Child(BundleIconComponent.self)
        let badgeText = Child(MultilineTextComponent.self)
        
        let title = Child(MultilineTextComponent.self)
        let text = Child(MultilineTextComponent.self)
        
        let button = Child(SolidRoundedButtonComponent.self)
        
        return { context in
            let environment = context.environment[ViewControllerComponentContainer.Environment.self].value
            let component = context.component
            let theme = environment.theme
            let strings = environment.strings
            
            let state = context.state
            let subject = component.subject
            
            let sideInset: CGFloat = 16.0 + environment.safeInsets.left
            let textSideInset: CGFloat = 24.0 + environment.safeInsets.left
            
            let iconName: String
            let badgeString: String
            let string: String
            switch subject {
                case .folders:
                    let limit = state.limits.maxFoldersCount
                    let premiumLimit = state.premiumLimits.maxFoldersCount
                    iconName = "Premium/Folder"
                    badgeString = "\(limit)"
                    string = strings.Premium_MaxFoldersCountText("\(limit)", "\(premiumLimit)").string
                case .chatsInFolder:
                    let limit = state.limits.maxFolderChatsCount
                    let premiumLimit = state.premiumLimits.maxFolderChatsCount
                    iconName = "Premium/Chat"
                    badgeString = "\(limit)"
                    string = strings.Premium_MaxChatsInFolderCountText("\(limit)", "\(premiumLimit)").string
                case .pins:
                    let limit = state.limits.maxPinnedChatCount
                    let premiumLimit = state.premiumLimits.maxPinnedChatCount
                    iconName = "Premium/Pin"
                    badgeString = "\(limit)"
                    string = strings.Premium_MaxPinsText("\(limit)", "\(premiumLimit)").string
                case .files:
                    let limit = 2048 * 1024 * 1024 //state.limits.maxPinnedChatCount
                    let premiumLimit = 4096 * 1024 * 1024 //state.premiumLimits.maxPinnedChatCount
                    iconName = "Premium/File"
                    badgeString = dataSizeString(limit, formatting: DataSizeStringFormatting(strings: environment.strings, decimalSeparator: environment.dateTimeFormat.decimalSeparator))
                    string = strings.Premium_MaxFileSizeText(dataSizeString(premiumLimit, formatting: DataSizeStringFormatting(strings: environment.strings, decimalSeparator: environment.dateTimeFormat.decimalSeparator))).string
            }
            
            let badgeIcon = badgeIcon.update(
                component: BundleIconComponent(
                    name: iconName,
                    tintColor: .white
                ),
                availableSize: context.availableSize,
                transition: .immediate
            )
            
            let badgeText = badgeText.update(
                component: MultilineTextComponent(
                    text: .plain(NSAttributedString(
                        string: badgeString,
                        font: Font.with(size: 24.0, design: .round, weight: .semibold, traits: []),
                        textColor: .white,
                        paragraphAlignment: .center
                    )),
                    horizontalAlignment: .center,
                    maximumNumberOfLines: 1
                ),
                availableSize: context.availableSize,
                transition: .immediate
            )
            
            let badgeBackground = badgeBackground.update(
                component: RoundedRectangle(
                    colors: [UIColor(rgb: 0xa34fcf), UIColor(rgb: 0xc8498a), UIColor(rgb: 0xff7a23)],
                    cornerRadius: 23.5
                ),
                availableSize: CGSize(width: badgeText.size.width + 67.0, height: 47.0),
                transition: .immediate
            )
            
            let title = title.update(
                component: MultilineTextComponent(
                    text: .plain(NSAttributedString(
                        string: strings.Premium_LimitReached,
                        font: Font.semibold(17.0),
                        textColor: theme.actionSheet.primaryTextColor,
                        paragraphAlignment: .center
                    )),
                    horizontalAlignment: .center,
                    maximumNumberOfLines: 1
                ),
                availableSize: CGSize(width: context.availableSize.width - sideInset * 2.0, height: CGFloat.greatestFiniteMagnitude),
                transition: .immediate
            )
            
            let textFont = Font.regular(17.0)
            let boldTextFont = Font.semibold(17.0)
            let textColor = theme.actionSheet.primaryTextColor
            let markdownAttributes = MarkdownAttributes(body: MarkdownAttributeSet(font: textFont, textColor: textColor), bold: MarkdownAttributeSet(font: boldTextFont, textColor: textColor), link: MarkdownAttributeSet(font: textFont, textColor: textColor), linkAttribute: { _ in
                return nil
            })
                        
            let text = text.update(
                component: MultilineTextComponent(
                    text: .markdown(text: string, attributes: markdownAttributes),
                    horizontalAlignment: .center,
                    maximumNumberOfLines: 0,
                    lineSpacing: 0.0
                ),
                availableSize: CGSize(width: context.availableSize.width - textSideInset * 2.0, height: context.availableSize.height),
                transition: .immediate
            )
            
            let button = button.update(
                component: SolidRoundedButtonComponent(
                    title: strings.Premium_IncreaseLimit,
                    theme: SolidRoundedButtonComponent.Theme(
                        backgroundColor: .black,
                        backgroundColors: [UIColor(rgb: 0x407af0), UIColor(rgb: 0x9551e8), UIColor(rgb: 0xbf499a), UIColor(rgb: 0xf17b30)],
                        foregroundColor: .white
                    ),
                    font: .bold,
                    fontSize: 17.0,
                    height: 50.0,
                    cornerRadius: 10.0,
                    gloss: false,
                    iconName: "Premium/X2",
                    iconPosition: .right,
                    action: { [weak component] in
                        guard let component = component else {
                            return
                        }
                        component.dismiss()
                        component.action()
                    }
                ),
                availableSize: CGSize(width: context.availableSize.width - sideInset * 2.0, height: 50.0),
                transition: context.transition
            )
            
            let width = context.availableSize.width
            
            let badgeFrame = CGRect(origin: CGPoint(x: floor((context.availableSize.width - badgeBackground.size.width) / 2.0), y: 33.0), size: badgeBackground.size)
            context.add(badgeBackground
                .position(CGPoint(x: badgeFrame.midX, y: badgeFrame.midY))
            )
            
            let badgeIconFrame = CGRect(origin: CGPoint(x: badgeFrame.minX + 18.0, y: badgeFrame.minY + floor((badgeFrame.height - badgeIcon.size.height) / 2.0)), size: badgeIcon.size)
            context.add(badgeIcon
                .position(CGPoint(x: badgeIconFrame.midX, y: badgeIconFrame.midY))
            )
            
            let badgeTextFrame = CGRect(origin: CGPoint(x: badgeFrame.maxX - badgeText.size.width - 15.0, y: badgeFrame.minY + floor((badgeFrame.height - badgeText.size.height) / 2.0)), size: badgeText.size)
            context.add(badgeText
                .position(CGPoint(x: badgeTextFrame.midX, y: badgeTextFrame.midY))
            )
                        
            context.add(title
                    .position(CGPoint(x: width / 2.0, y: 28.0))
            )
            context.add(text
                .position(CGPoint(x: width / 2.0, y: 228.0))
            )
            
            let buttonFrame = CGRect(origin: CGPoint(x: sideInset, y: 228.0 + ceil(text.size.height / 2.0) + 38.0), size: button.size)
            context.add(button
                .position(CGPoint(x: buttonFrame.midX, y: buttonFrame.midY))
            )
          
            let contentSize = CGSize(width: context.availableSize.width, height: buttonFrame.maxY + 5.0 + environment.safeInsets.bottom)
            
            return contentSize
        }
    }
}

private final class LimitSheetComponent: CombinedComponent {
    typealias EnvironmentType = ViewControllerComponentContainer.Environment
    
    let context: AccountContext
    let subject: PremiumLimitScreen.Subject
    let action: () -> Void
    
    init(context: AccountContext, subject: PremiumLimitScreen.Subject, action: @escaping () -> Void) {
        self.context = context
        self.subject = subject
        self.action = action
    }
    
    static func ==(lhs: LimitSheetComponent, rhs: LimitSheetComponent) -> Bool {
        if lhs.context !== rhs.context {
            return false
        }
        if lhs.subject != rhs.subject {
            return false
        }
        
        return true
    }
    
    static var body: Body {
        let sheet = Child(SheetComponent<EnvironmentType>.self)
        let animateOut = StoredActionSlot(Action<Void>.self)
        
        return { context in
            let environment = context.environment[EnvironmentType.self]
            
            let controller = environment.controller
            
            let sheet = sheet.update(
                component: SheetComponent<EnvironmentType>(
                    content: AnyComponent<EnvironmentType>(LimitSheetContent(
                        context: context.component.context,
                        subject: context.component.subject,
                        action: context.component.action,
                        dismiss: {
                            animateOut.invoke(Action { _ in
                                if let controller = controller() {
                                    controller.dismiss(completion: nil)
                                }
                            })
                        }
                    )),
                    backgroundColor: environment.theme.actionSheet.opaqueItemBackgroundColor,
                    animateOut: animateOut
                ),
                environment: {
                    environment
                    SheetComponentEnvironment(
                        isDisplaying: environment.value.isVisible,
                        dismiss: {
                            animateOut.invoke(Action { _ in
                                if let controller = controller() {
                                    controller.dismiss(completion: nil)
                                }
                            })
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

public class PremiumLimitScreen: ViewControllerComponentContainer {
    public enum Subject {
        case folders
        case chatsInFolder
        case pins
        case files
    }
    
    public init(context: AccountContext, subject: PremiumLimitScreen.Subject, action: @escaping () -> Void) {
        super.init(context: context, component: LimitSheetComponent(context: context, subject: subject, action: action), navigationBarAppearance: .none)
        
        self.navigationPresentation = .flatModal
    }
    
    required public init(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    public override func viewDidLoad() {
        super.viewDidLoad()
        
        self.view.disablesInteractiveModalDismiss = true
    }
}
