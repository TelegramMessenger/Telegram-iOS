import Foundation
import UIKit
import Display
import ComponentFlow
import ViewControllerComponent
import AccountContext
import SheetComponent
import ButtonComponent
import PlainButtonComponent
import TelegramCore
import SwiftSignalKit
import MultilineTextComponent
import BalancedTextComponent
import TelegramStringFormatting
import AvatarNode
import TelegramPresentationData
import PhoneNumberFormat
import BundleIconComponent
import UndoUI
import LottieComponent

private final class PeerBadgeComponent: Component {
    let context: AccountContext
    let theme: PresentationTheme
    let strings: PresentationStrings
    let peer: EnginePeer
    
    init(
        context: AccountContext,
        theme: PresentationTheme,
        strings: PresentationStrings,
        peer: EnginePeer
    ) {
        self.context = context
        self.theme = theme
        self.strings = strings
        self.peer = peer
    }
    
    static func ==(lhs: PeerBadgeComponent, rhs: PeerBadgeComponent) -> Bool {
        if lhs.context !== rhs.context {
            return false
        }
        if lhs.theme !== rhs.theme {
            return false
        }
        if lhs.strings !== rhs.strings {
            return false
        }
        if lhs.peer != rhs.peer {
            return false
        }
        return true
    }
    
    final class View: UIView {
        private let background = ComponentView<Empty>()
        private let title = ComponentView<Empty>()
        private var avatarNode: AvatarNode?
        
        override init(frame: CGRect) {
            super.init(frame: frame)
        }
        
        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }
        
        func update(component: PeerBadgeComponent, availableSize: CGSize, state: EmptyComponentState, environment: Environment<Empty>, transition: ComponentTransition) -> CGSize {
            let height: CGFloat = 32.0
            let avatarPadding: CGFloat = 1.0
            
            let avatarDiameter = height - avatarPadding * 2.0
            let avatarTextSpacing: CGFloat = 4.0
            let rightTextInset: CGFloat = 12.0
            
            let titleSize = self.title.update(
                transition: .immediate,
                component: AnyComponent(MultilineTextComponent(
                    text: .plain(NSAttributedString(string: component.peer.displayTitle(strings: component.strings, displayOrder: .firstLast), font: Font.medium(15.0), textColor: component.theme.list.itemPrimaryTextColor))
                )),
                environment: {},
                containerSize: CGSize(width: availableSize.width - avatarPadding - avatarDiameter - avatarTextSpacing - rightTextInset, height: height)
            )
            let titleFrame = CGRect(origin: CGPoint(x: avatarPadding + avatarDiameter + avatarTextSpacing, y: floorToScreenPixels((height - titleSize.height) * 0.5)), size: titleSize)
            if let titleView = self.title.view {
                if titleView.superview == nil {
                    self.addSubview(titleView)
                }
                titleView.frame = titleFrame
            }
            
            let avatarNode: AvatarNode
            if let current = self.avatarNode {
                avatarNode = current
            } else {
                avatarNode = AvatarNode(font: avatarPlaceholderFont(size: 15.0))
                self.avatarNode = avatarNode
                self.addSubview(avatarNode.view)
            }
            
            let avatarFrame = CGRect(origin: CGPoint(x: avatarPadding, y: avatarPadding), size: CGSize(width: avatarDiameter, height: avatarDiameter))
            avatarNode.frame = avatarFrame
            avatarNode.updateSize(size: avatarFrame.size)
            avatarNode.setPeer(context: component.context, theme: component.theme, peer: component.peer)
            
            let size = CGSize(width: avatarPadding + avatarDiameter + avatarTextSpacing + titleSize.width + rightTextInset, height: height)
            
            let _ = self.background.update(
                transition: transition,
                component: AnyComponent(RoundedRectangle(color: component.theme.list.itemBlocksSeparatorColor.withAlphaComponent(0.3), cornerRadius: nil)),
                environment: {},
                containerSize: size
            )
            if let backgroundView = self.background.view {
                if backgroundView.superview == nil {
                    self.insertSubview(backgroundView, at: 0)
                }
                transition.setFrame(view: backgroundView, frame: CGRect(origin: CGPoint(), size: size))
            }
            
            return size
        }
    }
    
    func makeView() -> View {
        return View(frame: CGRect())
    }
    
    func update(view: View, availableSize: CGSize, state: EmptyComponentState, environment: Environment<Empty>, transition: ComponentTransition) -> CGSize {
        return view.update(component: self, availableSize: availableSize, state: state, environment: environment, transition: transition)
    }
}

private final class CollectibleItemInfoScreenContentComponent: Component {
    typealias EnvironmentType = ViewControllerComponentContainer.Environment
    
    let context: AccountContext
    let initialData: CollectibleItemInfoScreen.InitialData
    let dismiss: () -> Void
    
    init(
        context: AccountContext,
        initialData: CollectibleItemInfoScreen.InitialData,
        dismiss: @escaping () -> Void
    ) {
        self.context = context
        self.initialData = initialData
        self.dismiss = dismiss
    }
    
    static func ==(lhs: CollectibleItemInfoScreenContentComponent, rhs: CollectibleItemInfoScreenContentComponent) -> Bool {
        if lhs.context !== rhs.context {
            return false
        }
        return true
    }
    
    final class View: UIView {
        private let iconBackground = ComponentView<Empty>()
        private let icon = ComponentView<Empty>()
        private let title = ComponentView<Empty>()
        private let peerBadge = ComponentView<Empty>()
        private let text = ComponentView<Empty>()
        private let button = ComponentView<Empty>()
        private let copyButton = ComponentView<Empty>()
        
        private var component: CollectibleItemInfoScreenContentComponent?
        private var environment: EnvironmentType?
        
        private var currencySymbolIcon: UIImage?
        
        override init(frame: CGRect) {
            super.init(frame: frame)
        }
        
        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }
        
        func update(component: CollectibleItemInfoScreenContentComponent, availableSize: CGSize, state: EmptyComponentState, environment: Environment<EnvironmentType>, transition: ComponentTransition) -> CGSize {
            self.component = component
            
            let environment = environment[EnvironmentType.self].value
            self.environment = environment
            
            let sideInset: CGFloat = 16.0
            let contentSideInset: CGFloat = sideInset + 4.0
            
            var contentHeight: CGFloat = 0.0
            contentHeight += 30.0
            
            let iconBackgroundSize = self.iconBackground.update(
                transition: transition,
                component: AnyComponent(RoundedRectangle(color: environment.theme.list.itemCheckColors.fillColor, cornerRadius: nil)),
                environment: {},
                containerSize: CGSize(width: 90.0, height: 90.0)
            )
            let iconBackgroundFrame = CGRect(origin: CGPoint(x: floor((availableSize.width - iconBackgroundSize.width) * 0.5), y: contentHeight), size: iconBackgroundSize)
            if let iconBackgroundView = self.iconBackground.view {
                if iconBackgroundView.superview == nil {
                    self.addSubview(iconBackgroundView)
                }
                transition.setFrame(view: iconBackgroundView, frame: iconBackgroundFrame)
            }
            contentHeight += iconBackgroundSize.height
            contentHeight += 16.0
            
            let iconAnimationName: String
            switch component.initialData.subject {
            case .username:
                iconAnimationName = "anim_collectible_username"
            case .phoneNumber:
                iconAnimationName = "anim_collectible_generic"
            }
            let iconSize = self.icon.update(
                transition: transition,
                component: AnyComponent(LottieComponent(
                    content: LottieComponent.AppBundleContent(name: iconAnimationName),
                    loop: false
                )),
                environment: {},
                containerSize: CGSize(width: floor(iconBackgroundFrame.size.width * 0.8), height: floor(iconBackgroundFrame.size.height * 0.8))
            )
            let iconFrame = CGRect(origin: CGPoint(x: iconBackgroundFrame.minX + floor((iconBackgroundFrame.width - iconSize.width) * 0.5), y: iconBackgroundFrame.minY + floor((iconBackgroundFrame.height - iconSize.height) * 0.5)), size: iconSize)
            if let iconView = self.icon.view as? LottieComponent.View {
                if iconView.superview == nil {
                    self.addSubview(iconView)
                    iconView.playOnce(delay: 0.1)
                }
                transition.setFrame(view: iconView, frame: iconFrame)
            }
            
            let titleText = NSMutableAttributedString()
            let textText = NSMutableAttributedString()
            switch component.initialData.subject {
            case let .username(username):
                let rawTitleString = environment.strings.CollectibleItemInfo_UsernameTitle("@\(username.username)")
                titleText.append(NSAttributedString(string: rawTitleString.string, font: Font.semibold(16.0), textColor: environment.theme.list.itemPrimaryTextColor))
                for range in rawTitleString.ranges {
                    titleText.addAttributes([
                        .foregroundColor: environment.theme.list.itemAccentColor,
                        NSAttributedString.Key(rawValue: "URL"): ""
                    ], range: range.range)
                }
                
                let dateText = stringForDate(timestamp: username.info.purchaseDate, strings: environment.strings)
                
                let cryptoCurrencyText = formatTonAmountText(username.info.cryptoCurrencyAmount, dateTimeFormat: environment.dateTimeFormat)
                let currencyText = formatTonUsdValue(username.info.currencyAmount, divide: false, rate: 0.01, dateTimeFormat: environment.dateTimeFormat)
                
                let rawTextString = environment.strings.CollectibleItemInfo_UsernameText("@\(username.username)", environment.strings.CollectibleItemInfo_StoreName, dateText, "~\(cryptoCurrencyText)", currencyText)
                textText.append(NSAttributedString(string: rawTextString.string, font: Font.regular(15.0), textColor: environment.theme.list.itemPrimaryTextColor))
                for range in rawTextString.ranges {
                    switch range.index {
                    case 0:
                        textText.addAttribute(.font, value: Font.semibold(15.0), range: range.range)
                    case 1:
                        textText.addAttribute(.font, value: Font.semibold(15.0), range: range.range)
                    case 3:
                        textText.addAttribute(.font, value: Font.semibold(15.0), range: range.range)
                    default:
                        break
                    }
                }
            case let .phoneNumber(phoneNumber):
                let formattedPhoneNumber = formatPhoneNumber(context: component.context, number: phoneNumber.phoneNumber)
                
                let rawTitleString = environment.strings.CollectibleItemInfo_PhoneTitle("\(formattedPhoneNumber)")
                titleText.append(NSAttributedString(string: rawTitleString.string, font: Font.semibold(16.0), textColor: environment.theme.list.itemPrimaryTextColor))
                for range in rawTitleString.ranges {
                    titleText.addAttributes([
                        .foregroundColor: environment.theme.list.itemAccentColor,
                        NSAttributedString.Key(rawValue: "URL"): ""
                    ], range: range.range)
                }
                
                let dateText = stringForDate(timestamp: phoneNumber.info.purchaseDate, strings: environment.strings)
                
                let cryptoCurrencyText = formatTonAmountText(phoneNumber.info.cryptoCurrencyAmount, dateTimeFormat: environment.dateTimeFormat)
                let currencyText = formatTonUsdValue(phoneNumber.info.currencyAmount, divide: false, rate: 0.01, dateTimeFormat: environment.dateTimeFormat)
                
                let rawTextString = environment.strings.CollectibleItemInfo_PhoneText("\(formattedPhoneNumber)", environment.strings.CollectibleItemInfo_StoreName, dateText, "~\(cryptoCurrencyText)", currencyText)
                textText.append(NSAttributedString(string: rawTextString.string, font: Font.regular(15.0), textColor: environment.theme.list.itemPrimaryTextColor))
                for range in rawTextString.ranges {
                    switch range.index {
                    case 0:
                        textText.addAttribute(.font, value: Font.semibold(15.0), range: range.range)
                    case 1:
                        textText.addAttribute(.font, value: Font.semibold(15.0), range: range.range)
                    case 3:
                        textText.addAttribute(.font, value: Font.semibold(15.0), range: range.range)
                    default:
                        break
                    }
                }
            }
            
            let currencySymbolRange = (textText.string as NSString).range(of: "~")
            
            if self.currencySymbolIcon == nil {
                if let templateImage = UIImage(bundleImageName: "Peer Info/CollectibleTonSymbolInline") {
                    self.currencySymbolIcon = generateImage(CGSize(width: templateImage.size.width, height: templateImage.size.height + 2.0), contextGenerator: { size, context in
                        context.clear(CGRect(origin: CGPoint(), size: size))
                        if let cgImage = templateImage.cgImage {
                            context.draw(cgImage, in: CGRect(origin: CGPoint(x: 0.0, y: 2.0), size: templateImage.size))
                        }
                    })?.withRenderingMode(.alwaysTemplate)
                }
            }
            
            if currencySymbolRange.location != NSNotFound, let currencySymbolIcon = self.currencySymbolIcon {
                textText.replaceCharacters(in: currencySymbolRange, with: "$")
                textText.addAttribute(.attachment, value: currencySymbolIcon, range: currencySymbolRange)
                
                final class RunDelegateData {
                    let ascent: CGFloat
                    let descent: CGFloat
                    let width: CGFloat
                    
                    init(ascent: CGFloat, descent: CGFloat, width: CGFloat) {
                        self.ascent = ascent
                        self.descent = descent
                        self.width = width
                    }
                }
                let font = Font.semibold(15.0)
                let runDelegateData = RunDelegateData(
                    ascent: font.ascender,
                    descent: font.descender,
                    width: currencySymbolIcon.size.width + 4.0
                )
                var callbacks = CTRunDelegateCallbacks(
                    version: kCTRunDelegateCurrentVersion,
                    dealloc: { dataRef in
                        Unmanaged<RunDelegateData>.fromOpaque(dataRef).release()
                    },
                    getAscent: { dataRef in
                        let data = Unmanaged<RunDelegateData>.fromOpaque(dataRef)
                        return data.takeUnretainedValue().ascent
                    },
                    getDescent: { dataRef in
                        let data = Unmanaged<RunDelegateData>.fromOpaque(dataRef)
                        return data.takeUnretainedValue().descent
                    },
                    getWidth: { dataRef in
                        let data = Unmanaged<RunDelegateData>.fromOpaque(dataRef)
                        return data.takeUnretainedValue().width
                    }
                )
                
                if let runDelegate = CTRunDelegateCreate(&callbacks, Unmanaged.passRetained(runDelegateData).toOpaque()) {
                    textText.addAttribute(NSAttributedString.Key(rawValue: kCTRunDelegateAttributeName as String), value: runDelegate, range: currencySymbolRange)
                }
            }
            
            let titleSize = self.title.update(
                transition: .immediate,
                component: AnyComponent(BalancedTextComponent(
                    text: .plain(titleText),
                    horizontalAlignment: .center,
                    maximumNumberOfLines: 0,
                    lineSpacing: 0.185
                )),
                environment: {},
                containerSize: CGSize(width: availableSize.width - contentSideInset * 2.0, height: 1000.0)
            )
            let titleFrame = CGRect(origin: CGPoint(x: floor((availableSize.width - titleSize.width) * 0.5), y: contentHeight), size: titleSize)
            if let titleView = self.title.view {
                if titleView.superview == nil {
                    self.addSubview(titleView)
                }
                transition.setPosition(view: titleView, position: titleFrame.center)
                titleView.bounds = CGRect(origin: CGPoint(), size: titleFrame.size)
            }
            contentHeight += titleSize.height
            contentHeight += 7.0
            
            if let peer = component.initialData.peer {
                let peerBadgeSize = self.peerBadge.update(
                    transition: transition,
                    component: AnyComponent(PeerBadgeComponent(
                        context: component.context,
                        theme: environment.theme,
                        strings: environment.strings,
                        peer: peer
                    )),
                    environment: {},
                    containerSize: CGSize(width: availableSize.width - contentSideInset * 2.0, height: 1000.0)
                )
                let peerBadgeFrame = CGRect(origin: CGPoint(x: floor((availableSize.width - peerBadgeSize.width) * 0.5), y: contentHeight), size: peerBadgeSize)
                if let peerBadgeView = self.peerBadge.view {
                    if peerBadgeView.superview == nil {
                        self.addSubview(peerBadgeView)
                    }
                    transition.setFrame(view: peerBadgeView, frame: peerBadgeFrame)
                }
                contentHeight += peerBadgeSize.height
                contentHeight += 23.0
            }
            
            let textSize = self.text.update(
                transition: .immediate,
                component: AnyComponent(BalancedTextComponent(
                    text: .plain(textText),
                    horizontalAlignment: .center,
                    maximumNumberOfLines: 0,
                    lineSpacing: 0.185
                )),
                environment: {},
                containerSize: CGSize(width: availableSize.width - contentSideInset * 2.0, height: 1000.0)
            )
            let textFrame = CGRect(origin: CGPoint(x: floor((availableSize.width - textSize.width) * 0.5), y: contentHeight), size: textSize)
            if let textView = self.text.view {
                if textView.superview == nil {
                    self.addSubview(textView)
                }
                transition.setPosition(view: textView, position: textFrame.center)
                textView.bounds = CGRect(origin: CGPoint(), size: textFrame.size)
            }
            contentHeight += textSize.height
            contentHeight += 21.0
            
            let buttonSize = self.button.update(
                transition: transition,
                component: AnyComponent(ButtonComponent(
                    background: ButtonComponent.Background(
                        color: environment.theme.list.itemCheckColors.fillColor,
                        foreground: environment.theme.list.itemCheckColors.foregroundColor,
                        pressedColor: environment.theme.list.itemCheckColors.fillColor.withMultipliedAlpha(0.8)
                    ),
                    content: AnyComponentWithIdentity(id: AnyHashable(0 as Int), component: AnyComponent(
                        Text(text: environment.strings.CollectibleItemInfo_ButtonOpenInfo, font: Font.semibold(17.0), color: environment.theme.list.itemCheckColors.foregroundColor)
                    )),
                    isEnabled: true,
                    displaysProgress: false,
                    action: { [weak self] in
                        guard let self, let component = self.component else {
                            return
                        }
                        
                        switch component.initialData.subject {
                        case let .username(username):
                            component.context.sharedContext.applicationBindings.openUrl(username.info.url)
                        case let .phoneNumber(phoneNumber):
                            component.context.sharedContext.applicationBindings.openUrl(phoneNumber.info.url)
                        }
                        
                        component.dismiss()
                    }
                )),
                environment: {},
                containerSize: CGSize(width: availableSize.width - sideInset * 2.0, height: 50.0)
            )
            let buttonFrame = CGRect(origin: CGPoint(x: sideInset, y: contentHeight), size: buttonSize)
            if let buttonView = self.button.view {
                if buttonView.superview == nil {
                    self.addSubview(buttonView)
                }
                transition.setFrame(view: buttonView, frame: buttonFrame)
            }
            contentHeight += buttonSize.height
            contentHeight += 5.0
            
            let copyButtonTitle: String
            switch component.initialData.subject {
            case .username:
                copyButtonTitle = environment.strings.CollectibleItemInfo_ButtonCopyUsername
            case .phoneNumber:
                copyButtonTitle = environment.strings.CollectibleItemInfo_ButtonCopyPhone
            }
                
            let copyButtonSize = self.copyButton.update(
                transition: transition,
                component: AnyComponent(PlainButtonComponent(
                    content: AnyComponent(MultilineTextComponent(
                        text: .plain(NSAttributedString(string: copyButtonTitle, font: Font.regular(17.0), textColor: environment.theme.list.itemAccentColor))
                    )),
                    background: nil,
                    effectAlignment: .center,
                    minSize: CGSize(width: availableSize.width - sideInset * 2.0, height: 50.0),
                    contentInsets: UIEdgeInsets(),
                    action: { [weak self] in
                        guard let self, let component = self.component, let environment = self.environment else {
                            return
                        }
                        
                        let toastText: String
                        switch component.initialData.subject {
                        case let .username(username):
                            UIPasteboard.general.string = "https://t.me/\(username.username)"
                            toastText = environment.strings.Conversation_LinkCopied
                        case let .phoneNumber(phoneNumber):
                            let formattedPhoneNumber = formatPhoneNumber(context: component.context, number: phoneNumber.phoneNumber)
                            UIPasteboard.general.string = formattedPhoneNumber
                            toastText = environment.strings.Chat_ToastPhoneNumberCopied
                        }
                        
                        let presentationData = component.context.sharedContext.currentPresentationData.with { $0 }
                        environment.controller()?.present(UndoOverlayController(presentationData: presentationData, content: .linkCopied(title: nil, text: toastText), elevatedLayout: false, animateInAsReplacement: false, action: { _ in return false }), in: .window(.root))
                        
                        component.dismiss()
                    },
                    isEnabled: true,
                    animateAlpha: true,
                    animateScale: false,
                    animateContents: false
                )),
                environment: {},
                containerSize: CGSize(width: availableSize.width - sideInset * 2.0, height: 50.0)
            )
            let copyButtonFrame = CGRect(origin: CGPoint(x: sideInset, y: contentHeight), size: copyButtonSize)
            if let copyButtonView = self.copyButton.view {
                if copyButtonView.superview == nil {
                    self.addSubview(copyButtonView)
                }
                transition.setFrame(view: copyButtonView, frame: copyButtonFrame)
            }
            contentHeight += copyButtonSize.height - 9.0
            
            if environment.safeInsets.bottom.isZero {
                contentHeight += 16.0
            } else {
                contentHeight += environment.safeInsets.bottom + 14.0
            }
            
            return CGSize(width: availableSize.width, height: contentHeight)
        }
    }
    
    func makeView() -> View {
        return View(frame: CGRect())
    }
    
    func update(view: View, availableSize: CGSize, state: EmptyComponentState, environment: Environment<EnvironmentType>, transition: ComponentTransition) -> CGSize {
        return view.update(component: self, availableSize: availableSize, state: state, environment: environment, transition: transition)
    }
}

private final class CollectibleItemInfoScreenComponent: Component {
    typealias EnvironmentType = ViewControllerComponentContainer.Environment
    
    let context: AccountContext
    let initialData: CollectibleItemInfoScreen.InitialData
    
    init(
        context: AccountContext,
        initialData: CollectibleItemInfoScreen.InitialData
    ) {
        self.context = context
        self.initialData = initialData
    }
    
    static func ==(lhs: CollectibleItemInfoScreenComponent, rhs: CollectibleItemInfoScreenComponent) -> Bool {
        if lhs.context !== rhs.context {
            return false
        }
        return true
    }
    
    final class View: UIView {
        private let sheet = ComponentView<(ViewControllerComponentContainer.Environment, SheetComponentEnvironment)>()
        private let sheetAnimateOut = ActionSlot<Action<Void>>()
        
        private var component: CollectibleItemInfoScreenComponent?
        private var environment: EnvironmentType?
        
        override init(frame: CGRect) {
            super.init(frame: frame)
        }
        
        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }
        
        func update(component: CollectibleItemInfoScreenComponent, availableSize: CGSize, state: EmptyComponentState, environment: Environment<ViewControllerComponentContainer.Environment>, transition: ComponentTransition) -> CGSize {
            self.component = component
            
            let environment = environment[ViewControllerComponentContainer.Environment.self].value
            self.environment = environment
            
            let sheetEnvironment = SheetComponentEnvironment(
                isDisplaying: environment.isVisible,
                isCentered: environment.metrics.widthClass == .regular,
                hasInputHeight: !environment.inputHeight.isZero,
                regularMetricsSize: CGSize(width: 430.0, height: 900.0),
                dismiss: { [weak self] _ in
                    guard let self, let environment = self.environment else {
                        return
                    }
                    self.sheetAnimateOut.invoke(Action { _ in
                        if let controller = environment.controller() {
                            controller.dismiss(completion: nil)
                        }
                    })
                }
            )
            let _ = self.sheet.update(
                transition: transition,
                component: AnyComponent(SheetComponent(
                    content: AnyComponent(CollectibleItemInfoScreenContentComponent(
                        context: component.context,
                        initialData: component.initialData,
                        dismiss: { [weak self] in
                            guard let self else {
                                return
                            }
                            self.sheetAnimateOut.invoke(Action { [weak self] _ in
                                if let controller = environment.controller() {
                                    controller.dismiss(completion: nil)
                                }
                                
                                guard let self else {
                                    return
                                }
                                //TODO:open info
                                let _ = self
                            })
                        }
                    )),
                    backgroundColor: .color(environment.theme.list.plainBackgroundColor),
                    animateOut: self.sheetAnimateOut
                )),
                environment: {
                    environment
                    sheetEnvironment
                },
                containerSize: availableSize
            )
            if let sheetView = self.sheet.view {
                if sheetView.superview == nil {
                    self.addSubview(sheetView)
                }
                transition.setFrame(view: sheetView, frame: CGRect(origin: CGPoint(), size: availableSize))
            }
            
            return availableSize
        }
    }
    
    func makeView() -> View {
        return View(frame: CGRect())
    }
    
    func update(view: View, availableSize: CGSize, state: EmptyComponentState, environment: Environment<ViewControllerComponentContainer.Environment>, transition: ComponentTransition) -> CGSize {
        return view.update(component: self, availableSize: availableSize, state: state, environment: environment, transition: transition)
    }
}

public class CollectibleItemInfoScreen: ViewControllerComponentContainer {
    fileprivate enum ResolvedSubject {
        struct Username {
            var username: String
            var info: TelegramCollectibleItemInfo
            
            init(username: String, info: TelegramCollectibleItemInfo) {
                self.username = username
                self.info = info
            }
        }
        
        struct PhoneNumber {
            var phoneNumber: String
            var info: TelegramCollectibleItemInfo
            
            init(phoneNumber: String, info: TelegramCollectibleItemInfo) {
                self.phoneNumber = phoneNumber
                self.info = info
            }
        }
        
        case username(Username)
        case phoneNumber(PhoneNumber)
    }
    
    public final class InitialData: CollectibleItemInfoScreenInitialData {
        fileprivate let peer: EnginePeer?
        fileprivate let subject: ResolvedSubject
        
        fileprivate init(peer: EnginePeer?, subject: ResolvedSubject) {
            self.peer = peer
            self.subject = subject
        }
        
        public var collectibleItemInfo: TelegramCollectibleItemInfo {
            switch self.subject {
            case let .username(username):
                return username.info
            case let .phoneNumber(phoneNumber):
                return phoneNumber.info
            }
        }
    }
    
    public init(context: AccountContext, initialData: InitialData) {
        super.init(context: context, component: CollectibleItemInfoScreenComponent(
            context: context,
            initialData: initialData
        ), navigationBarAppearance: .none)
        
        self.statusBar.statusBarStyle = .Ignore
        self.navigationPresentation = .flatModal
        self.blocksBackgroundWhenInOverlay = true
    }
    
    required public init(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    public static func initialData(context: AccountContext, peerId: EnginePeer.Id, subject: CollectibleItemInfoScreenSubject) -> Signal<CollectibleItemInfoScreenInitialData?, NoError> {
        switch subject {
        case let .username(username):
            return combineLatest(
                context.engine.data.get(
                    TelegramEngine.EngineData.Item.Peer.Peer(id: peerId)
                ),
                context.engine.peers.getCollectibleUsernameInfo(username: username)
            )
            |> map { peer, result -> CollectibleItemInfoScreenInitialData? in
                guard let result else {
                    return nil
                }
                return InitialData(peer: peer, subject: .username(ResolvedSubject.Username(
                    username: username,
                    info: result
                )))
            }
        case let .phoneNumber(phoneNumber):
            return combineLatest(
                context.engine.data.get(
                    TelegramEngine.EngineData.Item.Peer.Peer(id: peerId)
                ),
                context.engine.peers.getCollectiblePhoneNumberInfo(phoneNumber: phoneNumber)
            )
            |> map { peer, result -> CollectibleItemInfoScreenInitialData? in
                guard let result else {
                    return nil
                }
                return InitialData(peer: peer, subject: .phoneNumber(ResolvedSubject.PhoneNumber(
                    phoneNumber: phoneNumber,
                    info: result
                )))
            }
        }
    }
    
    deinit {
    }
    
    override public func containerLayoutUpdated(_ layout: ContainerViewLayout, transition: ContainedViewLayoutTransition) {
        super.containerLayoutUpdated(layout, transition: transition)
    }
    
    override public func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        self.view.disablesInteractiveModalDismiss = true
    }
}
