import Foundation
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

private func shareQrCode(context: AccountContext, link: String, ecl: String, view: UIView) {
    let _ = (qrCode(string: link, color: .black, backgroundColor: .white, icon: .custom(UIImage(bundleImageName: "Chat/Links/QrLogo")), ecl: ecl)
    |> map { _, generator -> UIImage? in
        let imageSize = CGSize(width: 768.0, height: 768.0)
        let context = generator(TransformImageArguments(corners: ImageCorners(), imageSize: imageSize, boundingSize: imageSize, intrinsicInsets: UIEdgeInsets(), scale: 1.0))
        return context?.generateImage()
    }
    |> deliverOnMainQueue).start(next: { image in
        guard let image = image else {
            return
        }

        let activityController = UIActivityViewController(activityItems: [image], applicationActivities: nil)
        if let window = view.window {
            activityController.popoverPresentationController?.sourceView = window
            activityController.popoverPresentationController?.sourceRect = CGRect(origin: CGPoint(x: window.bounds.width / 2.0, y: window.bounds.size.height - 1.0), size: CGSize(width: 1.0, height: 1.0))
        }
        context.sharedContext.applicationBindings.presentNativeController(activityController)
    })
}

private final class SheetContent: CombinedComponent {
    typealias EnvironmentType = ViewControllerComponentContainer.Environment
    
    let context: AccountContext
    let subject: QrCodeScreen.Subject
    let dismiss: () -> Void
    
    init(
        context: AccountContext,
        subject: QrCodeScreen.Subject,
        dismiss: @escaping () -> Void
    ) {
        self.context = context
        self.subject = subject
        self.dismiss = dismiss
    }
    
    static func ==(lhs: SheetContent, rhs: SheetContent) -> Bool {
        if lhs.context !== rhs.context {
            return false
        }
        return true
    }
    
    final class State: ComponentState {
        private let idleTimerExtensionDisposable = MetaDisposable()
        
        private var initialBrightness: CGFloat?
        private var brightnessArguments: (Double, Double, CGFloat, CGFloat)?
        private var animator: ConstantDisplayLinkAnimator?
        
        init(context: AccountContext) {
            super.init()
            
            self.idleTimerExtensionDisposable.set(context.sharedContext.applicationBindings.pushIdleTimerExtension())
            
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
        return State(context: self.context)
    }
        
    static var body: Body {
        let qrCode = Child(PlainButtonComponent.self)
        let closeButton = Child(GlassBarButtonComponent.self)
        let title = Child(Text.self)
        let text = Child(BalancedTextComponent.self)
        
        let button = Child(ButtonComponent.self)
        
        return { context in
            let environment = context.environment[EnvironmentType.self]
            let component = context.component
            let controller = environment.controller()
            
            let theme = environment.theme
            let strings = environment.strings
                        
            let link = component.subject.link
            let ecl = component.subject.ecl
            
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
                        
            let title = title.update(
                component: Text(text: titleString, font: Font.semibold(17.0), color: theme.list.itemPrimaryTextColor),
                availableSize: CGSize(width: constrainedTitleWidth, height: context.availableSize.height),
                transition: .immediate
            )
            context.add(title
                .position(CGPoint(x: context.availableSize.width / 2.0, y: contentSize.height))
            )
            contentSize.height += title.size.height
            contentSize.height += 13.0
            
            let qrCode = qrCode.update(
                component: PlainButtonComponent(
                    content: AnyComponent(QrCodeComponent(context: component.context, link: link, ecl: ecl)),
                    action: { [weak controller] in
                        if let view = controller?.view {
                            shareQrCode(context: component.context, link: link, ecl: ecl, view: view)
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
                        pressedColor: theme.list.itemCheckColors.fillColor.withMultipliedAlpha(0.9),
                        cornerRadius: 10.0,
                    ),
                    content: AnyComponentWithIdentity(
                        id: AnyHashable(0),
                        component: AnyComponent(MultilineTextComponent(text: .plain(NSMutableAttributedString(string: strings.InviteLink_QRCode_Share, font: Font.semibold(17.0), textColor: theme.list.itemCheckColors.foregroundColor, paragraphAlignment: .center))))
                    ),
                    isEnabled: true,
                    displaysProgress: false,
                    action: { [weak controller] in
                        if let view = controller?.view {
                            shareQrCode(context: component.context, link: link, ecl: ecl, view: view)
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
            contentSize.height += buttonInsets.bottom
            
            return contentSize
        }
    }
}

private final class QrCodeSheetComponent: CombinedComponent {
    typealias EnvironmentType = ViewControllerComponentContainer.Environment
    
    private let context: AccountContext
    private let subject: QrCodeScreen.Subject
    
    init(
        context: AccountContext,
        subject: QrCodeScreen.Subject
    ) {
        self.context = context
        self.subject = subject
    }
    
    static func ==(lhs: QrCodeSheetComponent, rhs: QrCodeSheetComponent) -> Bool {
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
                    content: AnyComponent<EnvironmentType>(SheetContent(
                        context: context.component.context,
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
    
    public enum Subject {
        case peer(peer: EnginePeer)
        case invite(invite: ExportedInvitation, type: SubjectType)
        case chatFolder(slug: String)
        
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
            }
        }
        
        var ecl: String {
            switch self {
            case .peer:
                return "Q"
            case .invite:
                return "Q"
            case .chatFolder:
                return "Q"
            }
        }
    }
    
    private let context: AccountContext
    
    public init(
        context: AccountContext,
        updatedPresentationData: (initial: PresentationData, signal: Signal<PresentationData, NoError>)? = nil,
        subject: QrCodeScreen.Subject
    ) {
        self.context = context
        
        super.init(
            context: context,
            component: QrCodeSheetComponent(
                context: context,
                subject: subject
            ),
            navigationBarAppearance: .none,
            statusBarStyle: .ignore,
            theme: .default //
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
    let context: AccountContext
    let link: String
    let ecl: String
    
    init(
        context: AccountContext,
        link: String,
        ecl: String
    ) {
        self.context = context
        self.link = link
        self.ecl = ecl
    }

    static func ==(lhs: QrCodeComponent, rhs: QrCodeComponent) -> Bool {
        if lhs.context !== rhs.context {
            return false
        }
        if lhs.link != rhs.link {
            return false
        }
        if lhs.ecl != rhs.ecl {
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
            
            if previousComponent?.link != component.link {
                self.imageNode.setSignal(qrCode(string: component.link, color: .black, backgroundColor: .white, icon: .cutout, ecl: component.ecl) |> beforeNext { [weak self] size, _ in
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
            
            if let qrCodeSize = self.qrCodeSize {
                let (_, cutoutFrame, _) = qrCodeCutout(size: qrCodeSize, dimensions: imageSize, scale: nil)
                
                let _ = self.icon.update(
                    transition: .immediate,
                    component: AnyComponent(LottieComponent(
                        content: LottieComponent.AppBundleContent(name: "PlaneLogo"),
                        loop: true
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
