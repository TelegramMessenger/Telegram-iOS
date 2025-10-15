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
import BalancedTextComponent
import MultilineTextComponent
import BundleIconComponent
import ButtonComponent
import AccountContext
import PresentationDataUtils
import TelegramUIPreferences
import UndoUI
import DeviceAccess

public func requireAgeVerification(context: AccountContext) -> Bool {
    if let value = context.currentAppConfiguration.with({ $0 }).data?["need_age_video_verification"] as? Bool, value {
        return true
    }
    return false
}

public func requireAgeVerification(context: AccountContext, peer: EnginePeer) -> Signal<Bool, NoError> {
    if requireAgeVerification(context: context), peer._asPeer().hasSensitiveContent(platform: "ios") {
        return context.engine.data.get(TelegramEngine.EngineData.Item.Configuration.ContentSettings())
        |> map { contentSettings in
            if !contentSettings.ignoreContentRestrictionReasons.contains("sensitive") {
                return true
            }
            return false
        }
    }
    return .single(false)
}

private final class SheetContent: CombinedComponent {
    typealias EnvironmentType = ViewControllerComponentContainer.Environment
    
    let context: AccountContext
    let dismiss: () -> Void
    
    init(
        context: AccountContext,
        dismiss: @escaping () -> Void
    ) {
        self.context = context
        self.dismiss = dismiss
    }
    
    static func ==(lhs: SheetContent, rhs: SheetContent) -> Bool {
        if lhs.context !== rhs.context {
            return false
        }
        return true
    }
    
    final class State: ComponentState {
        var cachedCloseImage: (UIImage, PresentationTheme)?
    }
    
    func makeState() -> State {
        return State()
    }
        
    static var body: Body {
        let background = Child(RoundedRectangle.self)
        let icon = Child(ZStack<Empty>.self)
        let closeButton = Child(Button.self)
        let title = Child(Text.self)
        let text = Child(BalancedTextComponent.self)
        
        let button = Child(ButtonComponent.self)
        
        return { context in
            let environment = context.environment[EnvironmentType.self]
            let component = context.component
            let state = context.state
            
            let presentationData = component.context.sharedContext.currentPresentationData.with { $0 }
            let theme = presentationData.theme
            let strings = presentationData.strings
                        
            var contentSize = CGSize(width: context.availableSize.width, height: 18.0)
                        
            let background = background.update(
                component: RoundedRectangle(color: theme.actionSheet.opaqueItemBackgroundColor, cornerRadius: 8.0),
                availableSize: CGSize(width: context.availableSize.width, height: 1000.0),
                transition: .immediate
            )
            context.add(background
                .position(CGPoint(x: context.availableSize.width / 2.0, y: background.size.height / 2.0))
            )

            let icon = icon.update(
                component: ZStack([
                    AnyComponentWithIdentity(
                        id: AnyHashable(0),
                        component: AnyComponent(RoundedRectangle(color: theme.list.itemCheckColors.fillColor, cornerRadius: 45.0, size: CGSize(width: 90.0, height: 90.0)))
                    ),
                    AnyComponentWithIdentity(
                        id: AnyHashable(1),
                        component: AnyComponent(BundleIconComponent(
                            name: "Settings/FaceVerification",
                            tintColor: theme.list.itemCheckColors.foregroundColor
                        ))
                    )
                ]),
                availableSize: CGSize(width: 90.0, height: 90.0),
                transition: .immediate
            )
            context.add(icon
                .position(CGPoint(x: context.availableSize.width / 2.0, y: icon.size.height / 2.0 + 31.0))
            )
            
            let closeImage: UIImage
            if let (image, cacheTheme) = state.cachedCloseImage, theme === cacheTheme {
                closeImage = image
            } else {
                closeImage = generateCloseButtonImage(backgroundColor: UIColor(rgb: 0x808084, alpha: 0.1), foregroundColor: theme.actionSheet.inputClearButtonColor)!
                state.cachedCloseImage = (closeImage, theme)
            }
            let closeButton = closeButton.update(
                component: Button(
                    content: AnyComponent(Image(image: closeImage)),
                    action: {
                        component.dismiss()
                    }
                ),
                availableSize: CGSize(width: 30.0, height: 30.0),
                transition: .immediate
            )
            context.add(closeButton
                .position(CGPoint(x: context.availableSize.width - closeButton.size.width, y: 28.0))
            )
            
            let constrainedTitleWidth = context.availableSize.width - 16.0 * 2.0
            
            contentSize.height += 124.0
            
            let title = title.update(
                component: Text(text: strings.AgeVerification_Title, font: Font.bold(24.0), color: theme.list.itemPrimaryTextColor),
                availableSize: CGSize(width: constrainedTitleWidth, height: context.availableSize.height),
                transition: .immediate
            )
            context.add(title
                .position(CGPoint(x: context.availableSize.width / 2.0, y: contentSize.height + title.size.height / 2.0))
            )
            contentSize.height += title.size.height
            contentSize.height += 13.0
                          
            let textFont = Font.regular(15.0)
            let boldTextFont = Font.semibold(15.0)
            let textColor = theme.actionSheet.primaryTextColor
            let linkColor = theme.actionSheet.controlAccentColor
            let markdownAttributes = MarkdownAttributes(body: MarkdownAttributeSet(font: textFont, textColor: textColor), bold: MarkdownAttributeSet(font: boldTextFont, textColor: textColor), link: MarkdownAttributeSet(font: textFont, textColor: linkColor), linkAttribute: { contents in
                return (TelegramTextAttributes.URL, contents)
            })
            
            var textString = environment.strings.AgeVerification_Text
            if let code = component.context.currentAppConfiguration.with({ $0 }).data?["verify_age_country"] as? String {
                let key = "AgeVerification.Text.\(code)"
                if let string = environment.strings.primaryComponent.dict[key] {
                    textString = string
                }
            }
            
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
                        
            let controller = environment.controller() as? AgeVerificationScreen
                        
            let button = button.update(
                component: ButtonComponent(
                    background: ButtonComponent.Background(
                        color: theme.list.itemCheckColors.fillColor,
                        foreground: theme.list.itemCheckColors.foregroundColor,
                        pressedColor: theme.list.itemCheckColors.fillColor.withMultipliedAlpha(0.9),
                        cornerRadius: 10.0
                    ),
                    content: AnyComponentWithIdentity(
                        id: AnyHashable(0),
                        component: AnyComponent(MultilineTextComponent(text: .plain(NSMutableAttributedString(string: strings.AgeVerification_Verify, font: Font.semibold(17.0), textColor: theme.list.itemCheckColors.foregroundColor, paragraphAlignment: .center))))
                    ),
                    isEnabled: true,
                    displaysProgress: false,
                    action: { [weak controller] in
                        controller?.complete(result: true)
                    }
                ),
                availableSize: CGSize(width: context.availableSize.width - 16.0 * 2.0, height: 50),
                transition: .immediate
            )
            context.add(button
                .clipsToBounds(true)
                .cornerRadius(10.0)
                .position(CGPoint(x: context.availableSize.width / 2.0, y: contentSize.height + button.size.height / 2.0))
            )
            contentSize.height += button.size.height
 
            contentSize.height += 48.0
            
            return contentSize
        }
    }
}

private final class AgeVerificationSheetComponent: CombinedComponent {
    typealias EnvironmentType = ViewControllerComponentContainer.Environment
    
    private let context: AccountContext
    
    init(
        context: AccountContext
    ) {
        self.context = context
    }
    
    static func ==(lhs: AgeVerificationSheetComponent, rhs: AgeVerificationSheetComponent) -> Bool {
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
                        dismiss: {
                            animateOut.invoke(Action { _ in
                                if let controller = controller() as? AgeVerificationScreen {
                                    controller.complete(result: false)
                                    controller.dismiss(completion: nil)
                                }
                            })
                        }
                    )),
                    backgroundColor: .color(environment.theme.list.modalBlocksBackgroundColor),
                    followContentSizeChanges: true,
                    clipsContent: true,
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
                                    if let controller = controller() as? AgeVerificationScreen {
                                        controller.complete(result: false)
                                        controller.dismiss(completion: nil)
                                    }
                                })
                            } else {
                                if let controller = controller() as? AgeVerificationScreen {
                                    controller.complete(result: false)
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

public final class AgeVerificationScreen: ViewControllerComponentContainer {
    private let context: AccountContext
    private let completion: (Bool, Signal<AgeVerificationAvailability, NoError>) -> Void
        
    private let promise = Promise<AgeVerificationAvailability>()
    
    public init(
        context: AccountContext,
        completion: @escaping (Bool, Signal<AgeVerificationAvailability, NoError>) -> Void
    ) {
        self.context = context
        self.completion = completion
                
        self.promise.set(ageVerificationAvailability(context: context))
        
        super.init(
            context: context,
            component: AgeVerificationSheetComponent(
                context: context
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
    
    private var didComplete = false
    fileprivate func complete(result: Bool) {
        guard !self.didComplete else {
            return
        }
        
        if result {
            let context = self.context
            let presentationData = context.sharedContext.currentPresentationData.with { $0 }
            DeviceAccess.authorizeAccess(to: .camera(.ageVerification), presentationData: presentationData, present: { c, a in
                c.presentationArguments = a
                context.sharedContext.mainWindow?.present(c, on: .root)
            }, openSettings: {
                context.sharedContext.applicationBindings.openSettings()
            }, { [weak self] granted in
                guard let self, granted else {
                    return
                }
                self.didComplete = true
                self.completion(true, self.promise.get())
                self.dismissAnimated()
            })
        } else {
            self.didComplete = true
            self.completion(false, self.promise.get())
        }
    }
    
    public func dismissAnimated() {
        if let view = self.node.hostView.findTaggedView(tag: SheetComponent<ViewControllerComponentContainer.Environment>.View.Tag()) as? SheetComponent<ViewControllerComponentContainer.Environment>.View {
            view.dismissAnimated()
        }
    }
}

func generateCloseButtonImage(backgroundColor: UIColor, foregroundColor: UIColor) -> UIImage? {
    return generateImage(CGSize(width: 30.0, height: 30.0), contextGenerator: { size, context in
        context.clear(CGRect(origin: CGPoint(), size: size))
        
        context.setFillColor(backgroundColor.cgColor)
        context.fillEllipse(in: CGRect(origin: CGPoint(), size: size))
        
        context.setLineWidth(2.0)
        context.setLineCap(.round)
        context.setStrokeColor(foregroundColor.cgColor)
        
        context.move(to: CGPoint(x: 10.0, y: 10.0))
        context.addLine(to: CGPoint(x: 20.0, y: 20.0))
        context.strokePath()
        
        context.move(to: CGPoint(x: 20.0, y: 10.0))
        context.addLine(to: CGPoint(x: 10.0, y: 20.0))
        context.strokePath()
    })
}

public func presentAgeVerification(context: AccountContext, parentController: ViewController, completion: @escaping () -> Void) {
    let presentationData = context.sharedContext.currentPresentationData.with { $0 }
    let _ = (contentSettingsConfiguration(network: context.account.network)
    |> deliverOnMainQueue).start(next: { [weak parentController] settings in
        if !settings.canAdjustSensitiveContent {
            let alertController = textAlertController(
                context: context,
                title: presentationData.strings.AgeVerification_Unavailable_Title,
                text: presentationData.strings.AgeVerification_Unavailable_Text,
                actions: []
            )
            parentController?.present(alertController, in: .window(.root))
            return
        }
        let miniappPromise = Promise<EnginePeer?>(nil)
        var useVerifyAgeBot = false
        if let value = context.currentAppConfiguration.with({ $0 }).data?["force_verify_age_bot"] as? Bool, value {
            useVerifyAgeBot = value
        }
        if useVerifyAgeBot, let verifyAgeBotUsername = context.currentAppConfiguration.with({ $0 }).data?["verify_age_bot_username"] as? String {
            miniappPromise.set(context.engine.peers.resolvePeerByName(name: verifyAgeBotUsername, referrer: nil)
            |> mapToSignal { result in
                if case let .result(peer) = result {
                    return .single(peer)
                }
                return .complete()
            })
        }
        let infoScreen = AgeVerificationScreen(context: context, completion: { [weak parentController] check, availability in
            if check {
                var requiredAge = 18
                if let value = context.currentAppConfiguration.with({ $0 }).data?["verify_age_min"] as? Double {
                    requiredAge = Int(value)
                }
                
                let success = { [weak parentController] in
                    completion()
        
                    let navigationController = parentController?.navigationController
                    Queue.mainQueue().after(2.0) {
                        let controller = UndoOverlayController(presentationData: presentationData, content: .actionSucceeded(title: presentationData.strings.AgeVerification_Success_Title, text: presentationData.strings.AgeVerification_Success_Text, cancel: nil, destructive: false), action: { _ in return true })
                        (navigationController?.viewControllers.last as? ViewController)?.present(controller, in: .current)
                    }
                }
                
                let failure = { [weak parentController] in
                    let controller = UndoOverlayController(presentationData: presentationData, content: .universal(animation: "anim_banned", scale: 0.066, colors: [:], title: presentationData.strings.AgeVerification_Fail_Title, text: presentationData.strings.AgeVerification_Fail_Text, customUndoText: nil, timeout: nil), action: { _ in return true })
                    parentController?.present(controller, in: .current)
                }
                
                let _ = (miniappPromise.get()
                |> take(1)
                |> deliverOnMainQueue).start(next: { peer in
                    if let peer, let parentController {
                        context.sharedContext.openWebApp(
                            context: context,
                            parentController: parentController,
                            updatedPresentationData: nil,
                            botPeer: peer,
                            chatPeer: nil,
                            threadId: nil,
                            buttonText: "",
                            url: "",
                            simple: true,
                            source: .generic,
                            skipTermsOfService: true,
                            payload: nil,
                            verifyAgeCompletion: { age in
                                if age >= requiredAge {
                                    success()
                                } else {
                                    failure()
                                }
                            }
                        )
                    } else {
                        let scanScreen = FaceScanScreen(context: context, availability: availability, completion: { age in
                            if age >= requiredAge {
                                success()
                            } else {
                                failure()
                            }
                        })
                        parentController?.push(scanScreen)
                    }
                })
            }
        })
        parentController?.push(infoScreen)
    })
}
