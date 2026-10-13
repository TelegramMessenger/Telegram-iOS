import Foundation
import LottieSettings
import UIKit
import Display
import ComponentFlow
import SwiftSignalKit
import TelegramCore
import TelegramPresentationData
import ViewControllerComponent
import SheetComponent
import BalancedTextComponent
import MultilineTextComponent
import BundleIconComponent
import ButtonComponent
import GlassBarButtonComponent
import PlainButtonComponent
import AccountContext
import Markdown
import TextFormat
import QrCode
import LottieComponent
import MtProtoKit
import SegmentControlComponent
import UrlEscaping

private func shareQrCode(sharedContext: SharedAccountContext, subject: QrCodeScreen.Subject, asImage: Bool, view: UIView) {
    let shareImpl: (Any) -> Void = { item in
        let activityController = UIActivityViewController(activityItems: [item], applicationActivities: nil)
        if let window = view.window {
            activityController.popoverPresentationController?.sourceView = window
            activityController.popoverPresentationController?.sourceRect = CGRect(origin: CGPoint(x: window.bounds.width / 2.0, y: window.bounds.size.height - 1.0), size: CGSize(width: 1.0, height: 1.0))
        }
        sharedContext.applicationBindings.presentNativeController(activityController)
    }
    if asImage {
        let _ = (qrCode(string: subject.link, color: .black, backgroundColor: .white, icon: subject.icon, ecl: subject.ecl)
                 |> map { _, generator -> UIImage? in
            let imageSize = CGSize(width: 768.0, height: 768.0)
            let context = generator(TransformImageArguments(corners: ImageCorners(), imageSize: imageSize, boundingSize: imageSize, intrinsicInsets: UIEdgeInsets(), scale: 1.0))
            return context?.generateImage()
        }
                 |> deliverOnMainQueue).start(next: { image in
            guard let image else {
                return
            }
            shareImpl(image)
        })
    } else {
        shareImpl(subject.link)
    }
}

private final class SheetContent: CombinedComponent {
    typealias EnvironmentType = ViewControllerComponentContainer.Environment
    
    let sharedContext: SharedAccountContext
    let subject: QrCodeScreen.Subject
    let dismiss: () -> Void
    
    init(
        sharedContext: SharedAccountContext,
        subject: QrCodeScreen.Subject,
        dismiss: @escaping () -> Void
    ) {
        self.sharedContext = sharedContext
        self.subject = subject
        self.dismiss = dismiss
    }
    
    static func ==(lhs: SheetContent, rhs: SheetContent) -> Bool {
        if lhs.sharedContext !== rhs.sharedContext {
            return false
        }
        return true
    }
    
    final class State: ComponentState {
        private let idleTimerExtensionDisposable = MetaDisposable()
        
        private var initialBrightness: CGFloat?
        private var brightnessArguments: (Double, Double, CGFloat, CGFloat)?
        private var animator: ConstantDisplayLinkAnimator?

        var selectedProxyExternalLink: Bool

        init(sharedContext: SharedAccountContext, subject: QrCodeScreen.Subject) {
            if case let .proxy(_, externalLink) = subject {
                self.selectedProxyExternalLink = externalLink
            } else {
                self.selectedProxyExternalLink = false
            }

            super.init()
            
            self.idleTimerExtensionDisposable.set(sharedContext.applicationBindings.pushIdleTimerExtension())
            
            self.animator = ConstantDisplayLinkAnimator(update: { [weak self] in
                self?.updateBrightness()
            })
            self.animator?.isPaused = true
            
            self.initialBrightness = UIScreen.main.brightness
            self.brightnessArguments = (CACurrentMediaTime(), 0.3, UIScreen.main.brightness, 1.0)
            self.updateBrightness()
        }
        
        deinit {
            self.idleTimerExtensionDisposable.dispose()
            self.animator?.invalidate()
            
            if UIScreen.main.brightness > 0.99, let initialBrightness = self.initialBrightness {
                self.brightnessArguments = (CACurrentMediaTime(), 0.3, UIScreen.main.brightness, initialBrightness)
                self.updateBrightness()
            }
        }
        
        private func updateBrightness() {
            if let (startTime, duration, initial, target) = self.brightnessArguments {
                self.animator?.isPaused = false
                
                let t = CGFloat(max(0.0, min(1.0, (CACurrentMediaTime() - startTime) / duration)))
                let value = initial + (target - initial) * t
                
                UIScreen.main.brightness = value
                
                if t >= 1.0 {
                    self.brightnessArguments = nil
                    self.animator?.isPaused = true
                }
            } else {
                self.animator?.isPaused = true
            }
        }
    }
    
    func makeState() -> State {
        return State(sharedContext: self.sharedContext, subject: self.subject)
    }
        
    static var body: Body {
        let qrCode = Child(PlainButtonComponent.self)
        let closeButton = Child(GlassBarButtonComponent.self)
        let title = Child(Text.self)
        let segmentControl = Child(SegmentControlComponent.self)
        let text = Child(BalancedTextComponent.self)
        
        let button = Child(ButtonComponent.self)
        let secondaryButton = Child(ButtonComponent.self)
        
        return { context in
            let environment = context.environment[EnvironmentType.self]
            let component = context.component
            let controller = environment.controller()
            
            let theme = environment.theme
            let strings = environment.strings
            let state = context.state

            let effectiveSubject: QrCodeScreen.Subject
            if case let .proxy(server, _) = component.subject {
                effectiveSubject = .proxy(server: server, externalLink: state.selectedProxyExternalLink)
            } else {
                effectiveSubject = component.subject
            }

            let titleString: String
            let textString: String
            switch component.subject {
            case let .invite(_, type):
                titleString = strings.InviteLink_QRCode_Title
                switch type {
                case .group:
                    textString = strings.InviteLink_QRCode_Info
                case .channel:
                    textString = strings.InviteLink_QRCode_InfoChannel
                case .groupCall:
                    textString = strings.InviteLink_QRCode_InfoGroupCall
                }
            case .chatFolder:
                titleString = strings.InviteLink_QRCodeFolder_Title
                textString = strings.InviteLink_QRCodeFolder_Text
            case .proxy:
                titleString = ""
                textString = strings.SocksProxySetup_ShareQRCodeInfo
            default:
                titleString = ""
                textString = ""
            }
            
            var contentSize = CGSize(width: context.availableSize.width, height: 38.0)
                             
            let closeButton = closeButton.update(
                component: GlassBarButtonComponent(
                    size: CGSize(width: 44.0, height: 44.0),
                    backgroundColor: nil,
                    isDark: theme.overallDarkAppearance,
                    state: .glass,
                    component: AnyComponentWithIdentity(id: "close", component: AnyComponent(
                        BundleIconComponent(
                            name: "Navigation/Close",
                            tintColor: theme.chat.inputPanel.panelControlColor
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
            
            let constrainedTitleWidth = context.availableSize.width - 16.0 * 2.0

            if case .proxy = component.subject {
                let constrainedSegmentWidth = min(constrainedTitleWidth, max(200.0, context.availableSize.width - 144.0))
                
                let theme = SegmentControlComponent.Theme(
                    backgroundColor: theme.rootController.navigationBar.segmentedBackgroundColor,
                    legacyBackgroundColor: theme.overallDarkAppearance ? theme.list.itemBlocksBackgroundColor : theme.rootController.navigationBar.segmentedBackgroundColor,
                    foregroundColor: theme.actionSheet.opaqueItemBackgroundColor,
                    textColor: theme.rootController.navigationBar.segmentedTextColor,
                    dividerColor: theme.rootController.navigationBar.segmentedDividerColor
                )
                
                let segmentControl = segmentControl.update(
                    component: SegmentControlComponent(
                        theme: theme,
                        items: [
                            SegmentControlComponent.Item(id: AnyHashable(false), title: strings.SocksProxySetup_QrCode_TgLink),
                            SegmentControlComponent.Item(id: AnyHashable(true), title: strings.SocksProxySetup_QrCode_TMeLink)
                        ],
                        selectedId: AnyHashable(state.selectedProxyExternalLink),
                        action: { id in
                            guard let externalLink = id.base as? Bool else {
                                return
                            }
                            if state.selectedProxyExternalLink != externalLink {
                                state.selectedProxyExternalLink = externalLink
                                state.updated(transition: ComponentTransition(animation: .curve(duration: 0.3, curve: .spring)))
                            }
                        }
                    ),
                    availableSize: CGSize(width: constrainedSegmentWidth, height: 36.0),
                    transition: .immediate
                )
                context.add(segmentControl
                    .position(CGPoint(x: context.availableSize.width / 2.0, y: contentSize.height))
                )
                contentSize.height += segmentControl.size.height
            } else {
                let title = title.update(
                    component: Text(text: titleString, font: Font.semibold(17.0), color: theme.list.itemPrimaryTextColor),
                    availableSize: CGSize(width: constrainedTitleWidth, height: context.availableSize.height),
                    transition: .immediate
                )
                context.add(title
                    .position(CGPoint(x: context.availableSize.width / 2.0, y: contentSize.height))
                )
                contentSize.height += title.size.height
            }
            contentSize.height += 13.0
            
            let qrCode = qrCode.update(
                component: PlainButtonComponent(
                    content: AnyComponent(
                        QrCodeComponent(
                            subject: effectiveSubject
                        )
                    ),
                    action: { [weak controller] in
                        if let view = controller?.view {
                            shareQrCode(sharedContext: component.sharedContext, subject: effectiveSubject, asImage: true, view: view)
                        }
                    },
                    animateScale: false
                ),
                availableSize: CGSize(width: 260.0, height: 260.0),
                transition: .immediate
            )
            context.add(qrCode
                .position(CGPoint(x: context.availableSize.width / 2.0, y: contentSize.height + qrCode.size.height / 2.0))
            )
            contentSize.height += qrCode.size.height
            contentSize.height += 17.0
            
            let textFont = Font.regular(15.0)
            let boldTextFont = Font.semibold(15.0)
            let textColor = theme.actionSheet.primaryTextColor
            let linkColor = theme.actionSheet.controlAccentColor
            let markdownAttributes = MarkdownAttributes(body: MarkdownAttributeSet(font: textFont, textColor: textColor), bold: MarkdownAttributeSet(font: boldTextFont, textColor: textColor), link: MarkdownAttributeSet(font: textFont, textColor: linkColor), linkAttribute: { contents in
                return (TelegramTextAttributes.URL, contents)
            })
                        
            let text = text.update(
                component: BalancedTextComponent(
                    text: .markdown(
                        text: textString,
                        attributes: markdownAttributes
                    ),
                    horizontalAlignment: .center,
                    maximumNumberOfLines: 0,
                    lineSpacing: 0.2
                ),
                availableSize: CGSize(width: constrainedTitleWidth, height: context.availableSize.height),
                transition: .immediate
            )
            context.add(text
                .position(CGPoint(x: context.availableSize.width / 2.0, y: contentSize.height + text.size.height / 2.0))
            )
            contentSize.height += text.size.height
            contentSize.height += 23.0
                                                
            let buttonInsets = ContainerViewLayout.concentricInsets(bottomInset: environment.safeInsets.bottom, innerDiameter: 52.0, sideInset: 30.0)
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
                        component: AnyComponent(MultilineTextComponent(text: .plain(NSMutableAttributedString(string: strings.InviteLink_QRCode_Share, font: Font.semibold(17.0), textColor: theme.list.itemCheckColors.foregroundColor, paragraphAlignment: .center))))
                    ),
                    isEnabled: true,
                    displaysProgress: false,
                    action: { [weak controller] in
                        if let view = controller?.view {
                            shareQrCode(sharedContext: component.sharedContext, subject: effectiveSubject, asImage: true, view: view)
                        }
                    }
                ),
                availableSize: CGSize(width: context.availableSize.width - buttonInsets.left - buttonInsets.right, height: 52.0),
                transition: .immediate
            )
            context.add(button
                .position(CGPoint(x: context.availableSize.width / 2.0, y: contentSize.height + button.size.height / 2.0))
            )
            contentSize.height += button.size.height

            if case .proxy = component.subject {
                contentSize.height += 8.0

                let buttonInsets = ContainerViewLayout.concentricInsets(bottomInset: environment.safeInsets.bottom, innerDiameter: 52.0, sideInset: 30.0)
                let secondaryButton = secondaryButton.update(
                    component: ButtonComponent(
                        background: ButtonComponent.Background(
                            style: .glass,
                            color: theme.list.itemAccentColor.withMultipliedAlpha(0.1),
                            foreground: theme.list.itemAccentColor,
                            pressedColor: theme.list.itemAccentColor.withMultipliedAlpha(0.8)
                        ),
                        content: AnyComponentWithIdentity(
                            id: AnyHashable(0),
                            component: AnyComponent(MultilineTextComponent(text: .plain(NSMutableAttributedString(string: strings.SocksProxySetup_ShareLink, font: Font.semibold(17.0), textColor: theme.list.itemAccentColor, paragraphAlignment: .center))))
                        ),
                        isEnabled: true,
                        displaysProgress: false,
                        action: { [weak controller] in
                            if let view = controller?.view {
                                shareQrCode(sharedContext: component.sharedContext, subject: effectiveSubject, asImage: false, view: view)
                            }
                        }
                    ),
                    availableSize: CGSize(width: context.availableSize.width - buttonInsets.left - buttonInsets.right, height: 52.0),
                    transition: .immediate
                )
                context.add(secondaryButton
                    .position(CGPoint(x: context.availableSize.width / 2.0, y: contentSize.height + secondaryButton.size.height / 2.0))
                )
                contentSize.height += secondaryButton.size.height
            }

            contentSize.height += buttonInsets.bottom

            return contentSize
        }
    }
}

private final class QrCodeSheetComponent: CombinedComponent {
    typealias EnvironmentType = ViewControllerComponentContainer.Environment
    
    private let sharedContext: SharedAccountContext
    private let subject: QrCodeScreen.Subject
    
    init(
        sharedContext: SharedAccountContext,
        subject: QrCodeScreen.Subject
    ) {
        self.sharedContext = sharedContext
        self.subject = subject
    }
    
    static func ==(lhs: QrCodeSheetComponent, rhs: QrCodeSheetComponent) -> Bool {
        if lhs.sharedContext !== rhs.sharedContext {
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
                    content: AnyComponent<EnvironmentType>(SheetContent(
                        sharedContext: context.component.sharedContext,
                        subject: context.component.subject,
                        dismiss: {
                            animateOut.invoke(Action { _ in
                                if let controller = controller() as? QrCodeScreen {
                                    controller.dismiss(completion: nil)
                                }
                            })
                        }
                    )),
                    style: .glass,
                    backgroundColor: .color(environment.theme.actionSheet.opaqueItemBackgroundColor),
                    followContentSizeChanges: true,
                    clipsContent: true,
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
                        regularMetricsSize: CGSize(width: 430.0, height: 900.0),
                        dismiss: { animated in
                            if animated {
                                animateOut.invoke(Action { _ in
                                    if let controller = controller() as? QrCodeScreen {
                                        controller.dismiss(completion: nil)
                                    }
                                })
                            } else {
                                if let controller = controller() as? QrCodeScreen {
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

public final class QrCodeScreen: ViewControllerComponentContainer {
    public enum SubjectType {
        case group
        case channel
        case groupCall
    }
    
    public enum Subject: Equatable {
        case peer(peer: EnginePeer)
        case invite(invite: ExportedInvitation, type: SubjectType)
        case chatFolder(slug: String)
        case proxy(server: ProxyServerSettings, externalLink: Bool)
        
        var link: String {
            switch self {
            case let .peer(peer):
                return "https://t.me/\(peer.addressName ?? "")"
            case let .invite(invite, _):
                return invite.link ?? ""
            case let .chatFolder(slug):
                if slug.hasPrefix("https://") {
                    return slug
                } else {
                    return "https://t.me/addlist/\(slug)"
                }
            case let .proxy(server, externalLink):
                var link: String
                let serverHost = server.host.addingPercentEncoding(withAllowedCharacters: CharacterSet.urlQueryValueAllowed) ?? ""
                switch server.connection {
                case let .mtp(secret):
                    let secret = MTProxySecret.parseData(secret)?.serializeToString() ?? ""
                    link = "\(externalLink ? "https://t.me/proxy" : "tg://proxy")?server=\(serverHost)&port=\(server.port)"
                    link += "&secret=\(secret.addingPercentEncoding(withAllowedCharacters: CharacterSet.urlQueryValueAllowed) ?? "")"
                case let .socks5(username, password):
                    link = "\(externalLink ? "https://t.me/socks" : "tg://socks")?server=\(serverHost)&port=\(server.port)"
                    if let username, !username.isEmpty {
                        link += "&user=\(username.addingPercentEncoding(withAllowedCharacters: CharacterSet.urlQueryValueAllowed) ?? "")"
                    }
                    if let password, !password.isEmpty {
                        link += "&pass=\(password.addingPercentEncoding(withAllowedCharacters: CharacterSet.urlQueryValueAllowed) ?? "")"
                    }
                case .web:
                    // Always the t.me form, regardless of `externalLink`: webProxySettingsLink
                    // only builds that one, and parseWebProxySettingsLink accepts it alongside
                    // tg://webproxy. The public frontend has no /webproxy route yet.
                    link = webProxySettingsLink(server) ?? ""
                }
                return link
            }
        }
        
        var ecl: String {
            switch self {
            case .peer, .invite, .chatFolder, .proxy:
                return "Q"
            }
        }

        var icon: QrCodeIcon {
            switch self {
            case .peer, .invite, .chatFolder:
                return .custom(UIImage(bundleImageName: "Chat/Links/QrLogo"))
            case .proxy:
                return .proxy
            }
        }
    }
        
    public init(
        context: AccountContext,
        updatedPresentationData: (initial: PresentationData, signal: Signal<PresentationData, NoError>)? = nil,
        subject: QrCodeScreen.Subject
    ) {
        super.init(
            context: context,
            component: QrCodeSheetComponent(
                sharedContext: context.sharedContext,
                subject: subject
            ),
            navigationBarAppearance: .none,
            statusBarStyle: .ignore,
            theme: .default,
            updatedPresentationData: updatedPresentationData
        )
        
        self.navigationPresentation = .flatModal
    }
    
    public init(
        sharedContext: SharedAccountContext,
        updatedPresentationData: (initial: PresentationData, signal: Signal<PresentationData, NoError>),
        subject: QrCodeScreen.Subject
    ) {        
        super.init(
            component: QrCodeSheetComponent(
                sharedContext: sharedContext,
                subject: subject
            ),
            navigationBarAppearance: .none,
            statusBarStyle: .ignore,
            presentationMode: .default,
            theme: .default,
            updatedPresentationData: updatedPresentationData
        )
        
        self.navigationPresentation = .flatModal
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

private final class QrCodeComponent: Component {
    let subject: QrCodeScreen.Subject
    
    init(
        subject: QrCodeScreen.Subject
    ) {
        self.subject = subject
    }

    static func ==(lhs: QrCodeComponent, rhs: QrCodeComponent) -> Bool {
        if lhs.subject != rhs.subject {
            return false
        }
        return true
    }

    final class View: UIView {
        private var component: QrCodeComponent?
        private var state: EmptyComponentState?
        
        private let imageNode: TransformImageNode
        private let icon = ComponentView<Empty>()
        
        private var qrCodeSize: Int?
                
        private var isUpdating = false
        
        override init(frame: CGRect) {
            self.imageNode = TransformImageNode()
            
            super.init(frame: frame)
            
            self.backgroundColor = UIColor.white
            self.clipsToBounds = true
            self.layer.cornerRadius = 24.0
            self.layer.allowsGroupOpacity = true
            
            self.addSubview(self.imageNode.view)
        }
        
        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }
        
        func update(component: QrCodeComponent, availableSize: CGSize, state: EmptyComponentState, environment: Environment<Empty>, transition: ComponentTransition) -> CGSize {
            self.isUpdating = true
            defer {
                self.isUpdating = false
            }
            let previousComponent = self.component
            self.component = component
            self.state = state

            var isProxy = false
            if case .proxy = component.subject {
                isProxy = true
            }

            if previousComponent?.subject != component.subject {
                self.imageNode.setSignal(qrCode(string: component.subject.link, color: .black, backgroundColor: .white, icon: isProxy ? .proxy : .cutout, ecl: component.subject.ecl) |> beforeNext { [weak self] size, _ in
                    guard let self else {
                        return
                    }
                    self.qrCodeSize = size
                    if !self.isUpdating {
                        self.state?.updated()
                    }
                } |> map { $0.1 }, attemptSynchronously: true)
            }
                        
            let size = CGSize(width: 256.0, height: 256.0)
            let imageSize = CGSize(width: 240.0, height: 240.0)
                        
            let makeImageLayout = self.imageNode.asyncLayout()
            let imageApply = makeImageLayout(TransformImageArguments(corners: ImageCorners(), imageSize: imageSize, boundingSize: imageSize, intrinsicInsets: UIEdgeInsets(), emptyColor: nil))
            let _ = imageApply()
            let imageFrame = CGRect(origin: CGPoint(x: (size.width - imageSize.width) / 2.0, y: (size.height - imageSize.height) / 2.0), size: imageSize)
            self.imageNode.frame = imageFrame
            
            if !isProxy, let qrCodeSize = self.qrCodeSize {
                let (_, cutoutFrame, _) = qrCodeCutout(size: qrCodeSize, dimensions: imageSize, scale: nil)
                
                let _ = self.icon.update(
                    transition: .immediate,
                    component: AnyComponent(LottieComponent(
                        content: LottieComponent.AppBundleContent(name: "PlaneLogo"),
                        loop: true,
                        lottieSettings: .noAccountFallback
                    )),
                    environment: {},
                    containerSize: cutoutFrame.size
                )
                if let iconView = self.icon.view {
                    if iconView.superview == nil {
                        self.addSubview(iconView)
                    }
                    iconView.bounds = CGRect(origin: CGPoint(), size: cutoutFrame.size)
                    iconView.center = imageFrame.center.offsetBy(dx: 0.0, dy: -1.0)
                }
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
