import Foundation
import UIKit
import Display
import SwiftSignalKit
import TelegramCore
import TelegramPresentationData
import PresentationDataUtils
import AccountContext
import ComponentFlow
import ViewControllerComponent
import MultilineTextComponent
import SolidRoundedButtonComponent
import BundleIconComponent
import AnimatedStickerComponent
import ActivityIndicatorComponent

private final class CreateExternalMediaStreamScreenComponent: CombinedComponent {
    typealias EnvironmentType = ViewControllerComponentContainer.Environment
    
    let context: AccountContext
    let peerId: EnginePeer.Id
    let mode: CreateExternalMediaStreamScreen.Mode
    let credentialsPromise: Promise<GroupCallStreamCredentials>?
    
    init(context: AccountContext, peerId: EnginePeer.Id, mode: CreateExternalMediaStreamScreen.Mode, credentialsPromise: Promise<GroupCallStreamCredentials>?) {
        self.context = context
        self.peerId = peerId
        self.mode = mode
        self.credentialsPromise = credentialsPromise
    }
    
    static func ==(lhs: CreateExternalMediaStreamScreenComponent, rhs: CreateExternalMediaStreamScreenComponent) -> Bool {
        if lhs.context !== rhs.context {
            return false
        }
        if lhs.peerId != rhs.peerId {
            return false
        }
        if lhs.mode != rhs.mode {
            return false
        }
        if lhs.credentialsPromise !== rhs.credentialsPromise {
            return false
        }
        return true
    }
    
    final class State: ComponentState {
        let context: AccountContext
        let peerId: EnginePeer.Id
        
        private(set) var credentials: GroupCallStreamCredentials?
        
        private var credentialsDisposable: Disposable?
        private let activeActionDisposable = MetaDisposable()
        
        init(context: AccountContext, peerId: EnginePeer.Id, credentialsPromise: Promise<GroupCallStreamCredentials>?) {
            self.context = context
            self.peerId = peerId
            
            super.init()
            
            let credentialsSignal: Signal<GroupCallStreamCredentials, NoError>
            if let credentialsPromise = credentialsPromise {
                credentialsSignal = credentialsPromise.get()
            } else {
                credentialsSignal = context.engine.calls.getGroupCallStreamCredentials(peerId: peerId, revokePreviousCredentials: false)
                |> `catch` { _ -> Signal<GroupCallStreamCredentials, NoError> in
                    return .never()
                }
            }
            self.credentialsDisposable = (credentialsSignal |> deliverOnMainQueue).start(next: { [weak self] result in
                guard let strongSelf = self else {
                    return
                }
                
                strongSelf.credentials = result
                strongSelf.updated(transition: .immediate)
            })
        }
        
        deinit {
            self.credentialsDisposable?.dispose()
            self.activeActionDisposable.dispose()
        }
        
        func copyCredentials(_ key: KeyPath<GroupCallStreamCredentials, String>) {
            guard let credentials = self.credentials else {
                return
            }
            UIPasteboard.general.string = credentials[keyPath: key]
        }
        
        func createAndJoinGroupCall(baseController: ViewController, completion: @escaping () -> Void) {
            guard let _ = self.context.sharedContext.callManager else {
                return
            }
            let startCall: (Bool) -> Void = { [weak self, weak baseController] endCurrentIfAny in
                guard let strongSelf = self, let baseController = baseController else {
                    return
                }
                
                var cancelImpl: (() -> Void)?
                let presentationData = strongSelf.context.sharedContext.currentPresentationData.with { $0 }
                let progressSignal = Signal<Never, NoError> { [weak baseController] subscriber in
                    let controller = OverlayStatusController(theme: presentationData.theme,  type: .loading(cancelled: {
                        cancelImpl?()
                    }))
                    baseController?.present(controller, in: .window(.root))
                    return ActionDisposable { [weak controller] in
                        Queue.mainQueue().async() {
                            controller?.dismiss()
                        }
                    }
                }
                |> runOn(Queue.mainQueue())
                |> delay(0.15, queue: Queue.mainQueue())
                let progressDisposable = progressSignal.start()
                let createSignal = strongSelf.context.engine.calls.createGroupCall(peerId: strongSelf.peerId, title: nil, scheduleDate: nil, isExternalStream: true)
                |> afterDisposed {
                    Queue.mainQueue().async {
                        progressDisposable.dispose()
                    }
                }
                cancelImpl = {
                    self?.activeActionDisposable.set(nil)
                }
                strongSelf.activeActionDisposable.set((createSignal
                |> deliverOnMainQueue).start(next: { info in
                    guard let strongSelf = self else {
                        return
                    }
                    strongSelf.context.joinGroupCall(peerId: strongSelf.peerId, invite: nil, requestJoinAsPeerId: { result in
                        result(nil)
                    }, activeCall: EngineGroupCallDescription(id: info.id, accessHash: info.accessHash, title: info.title, scheduleTimestamp: nil, subscribedToScheduled: false, isStream: info.isStream))
                    
                    completion()
                }, error: { [weak baseController] error in
                    guard let strongSelf = self else {
                        return
                    }
                    
                    let text: String
                    text = presentationData.strings.Login_UnknownError
                    baseController?.present(textAlertController(context: strongSelf.context, updatedPresentationData: nil, title: nil, text: text, actions: [TextAlertAction(type: .defaultAction, title: presentationData.strings.Common_OK, action: {})]), in: .window(.root))
                }))
            }
            
            startCall(true)
        }
    }
    
    func makeState() -> State {
        return State(context: self.context, peerId: self.peerId, credentialsPromise: self.credentialsPromise)
    }
    
    static var body: Body {
        let background = Child(Rectangle.self)
        
        let animation = Child(AnimatedStickerComponent.self)
        let text = Child(MultilineTextComponent.self)
        let bottomText = Child(MultilineTextComponent.self)
        let button = Child(SolidRoundedButtonComponent.self)
        
        let activityIndicator = Child(ActivityIndicatorComponent.self)
        
        let credentialsBackground = Child(RoundedRectangle.self)
        
        let credentialsStripe = Child(Rectangle.self)
        let credentialsURLTitle = Child(MultilineTextComponent.self)
        let credentialsURLText = Child(MultilineTextComponent.self)
        
        let credentialsKeyTitle = Child(MultilineTextComponent.self)
        let credentialsKeyText = Child(MultilineTextComponent.self)
        
        let credentialsCopyURLButton = Child(Button.self)
        let credentialsCopyKeyButton = Child(Button.self)
        
        return { context in
            let topInset: CGFloat = 16.0
            let sideInset: CGFloat = 16.0
            let credentialsSideInset: CGFloat = 16.0
            let credentialsTopInset: CGFloat = 9.0
            let credentialsTitleSpacing: CGFloat = 5.0
            
            let environment = context.environment[ViewControllerComponentContainer.Environment.self].value
            let state = context.state
            let mode = context.component.mode
            let controller = environment.controller
            
            let bottomInset: CGFloat
            if environment.safeInsets.bottom.isZero {
                bottomInset = 16.0
            } else {
                bottomInset = 42.0
            }
            
            let background = background.update(
                component: Rectangle(color: environment.theme.list.blocksBackgroundColor),
                availableSize: context.availableSize,
                transition: context.transition
            )
            
            let animation = animation.update(
                component: AnimatedStickerComponent(
                    account: state.context.account,
                    animation: AnimatedStickerComponent.Animation(
                        source: .bundle(name: "CreateStream"),
                        loop: true
                    ),
                    size: CGSize(width: 138.0, height: 138.0)
                ),
                availableSize: CGSize(width: 138.0, height: 138.0),
                transition: context.transition
            )
            
            let text = text.update(
                component: MultilineTextComponent(
                    text: .plain(NSAttributedString(string: environment.strings.CreateExternalStream_Text, font: Font.regular(15.0), textColor: environment.theme.list.itemSecondaryTextColor, paragraphAlignment: .center)),
                    horizontalAlignment: .center,
                    maximumNumberOfLines: 0,
                    lineSpacing: 0.1
                ),
                availableSize: CGSize(width: context.availableSize.width - sideInset * 2.0, height: context.availableSize.height),
                transition: context.transition
            )
            
            let bottomText = Condition(mode == .create) {
                bottomText.update(
                    component: MultilineTextComponent(
                        text: .plain(NSAttributedString(string: environment.strings.CreateExternalStream_StartStreamingInfo, font: Font.regular(15.0), textColor: environment.theme.list.itemSecondaryTextColor, paragraphAlignment: .center)),
                        horizontalAlignment: .center,
                        maximumNumberOfLines: 0,
                        lineSpacing: 0.1
                    ),
                    availableSize: CGSize(width: context.availableSize.width - sideInset * 2.0, height: context.availableSize.height),
                    transition: context.transition
                )
            }
            
            let button = button.update(
                component: SolidRoundedButtonComponent(
                    title: mode == .create ? environment.strings.CreateExternalStream_StartStreaming : environment.strings.Common_Close,
                    theme: SolidRoundedButtonComponent.Theme(theme: environment.theme),
                    font: .bold,
                    fontSize: 17.0,
                    height: 50.0,
                    cornerRadius: 10.0,
                    gloss: true,
                    action: { [weak state] in
                        guard let state = state, let controller = controller() else {
                            return
                        }
                        
                        switch mode {
                        case .create:
                            state.createAndJoinGroupCall(baseController: controller, completion: { [weak controller] in
                                controller?.dismiss()
                            })
                        case .view:
                            controller.dismiss()
                        }
                    }
                ),
                availableSize: CGSize(width: context.availableSize.width - sideInset * 2.0, height: 50.0),
                transition: context.transition
            )
            
            let credentialsItemHeight: CGFloat = 60.0
            let credentialsAreaSize = CGSize(width: context.availableSize.width - sideInset * 2.0, height: credentialsItemHeight * 2.0)
            
            context.add(background
                .position(CGPoint(x: context.availableSize.width / 2.0, y: context.availableSize.height / 2.0))
            )
            
            let animationFrame = CGRect(origin: CGPoint(x: floor((context.availableSize.width - animation.size.width) / 2.0), y: environment.navigationHeight + topInset), size: animation.size)
            
            context.add(animation
                .position(CGPoint(x: animationFrame.midX, y: animationFrame.midY))
            )
            
            let textFrame = CGRect(origin: CGPoint(x: floor((context.availableSize.width - text.size.width) / 2.0), y: animationFrame.maxY + 16.0), size: text.size)
            
            context.add(text
                .position(CGPoint(x: textFrame.midX, y: textFrame.midY))
            )
            
            let credentialsFrame = CGRect(origin: CGPoint(x: sideInset, y: textFrame.maxY + 30.0), size: credentialsAreaSize)
            
            if let credentials = context.state.credentials {
                let credentialsURLTitle = credentialsURLTitle.update(
                    component: MultilineTextComponent(
                        text: .plain(NSAttributedString(string: environment.strings.CreateExternalStream_ServerUrl, font: Font.regular(14.0), textColor: environment.theme.list.itemPrimaryTextColor, paragraphAlignment: .left)),
                        horizontalAlignment: .left,
                        maximumNumberOfLines: 1
                    ),
                    availableSize: CGSize(width: credentialsAreaSize.width - credentialsSideInset * 2.0, height: credentialsAreaSize.height),
                    transition: context.transition
                )
                
                let credentialsKeyTitle = credentialsKeyTitle.update(
                    component: MultilineTextComponent(
                        text: .plain(NSAttributedString(string: environment.strings.CreateExternalStream_StreamKey, font: Font.regular(14.0), textColor: environment.theme.list.itemPrimaryTextColor, paragraphAlignment: .left)),
                        horizontalAlignment: .left,
                        maximumNumberOfLines: 1
                    ),
                    availableSize: CGSize(width: credentialsAreaSize.width - credentialsSideInset * 2.0, height: credentialsAreaSize.height),
                    transition: context.transition
                )
                
                let credentialsURLText = credentialsURLText.update(
                    component: MultilineTextComponent(
                        text: .plain(NSAttributedString(string: credentials.url, font: Font.regular(16.0), textColor: environment.theme.list.itemAccentColor, paragraphAlignment: .left)),
                        horizontalAlignment: .left,
                        truncationType: .middle,
                        maximumNumberOfLines: 1
                    ),
                    availableSize: CGSize(width: credentialsAreaSize.width - credentialsSideInset * 2.0 - 22.0, height: credentialsAreaSize.height),
                    transition: context.transition
                )
                
                let credentialsKeyText = credentialsKeyText.update(
                    component: MultilineTextComponent(
                        text: .plain(NSAttributedString(string: credentials.streamKey, font: Font.regular(16.0), textColor: environment.theme.list.itemAccentColor, paragraphAlignment: .left)),
                        horizontalAlignment: .left,
                        truncationType: .middle,
                        maximumNumberOfLines: 1
                    ),
                    availableSize: CGSize(width: credentialsAreaSize.width - credentialsSideInset * 2.0 - 22.0, height: credentialsAreaSize.height),
                    transition: context.transition
                )
                
                let credentialsBackground = credentialsBackground.update(
                    component: RoundedRectangle(color: environment.theme.list.itemBlocksBackgroundColor, cornerRadius: 10.0),
                    availableSize: credentialsAreaSize,
                    transition: context.transition
                )
                
                let credentialsStripe = credentialsStripe.update(
                    component: Rectangle(color: environment.theme.list.itemPlainSeparatorColor),
                    availableSize: CGSize(width: credentialsAreaSize.width - credentialsSideInset, height: UIScreenPixel),
                    transition: context.transition
                )
                
                let credentialsCopyURLButton = credentialsCopyURLButton.update(
                    component: Button(
                        content: AnyComponent(BundleIconComponent(name: "Chat/Context Menu/Copy", tintColor: environment.theme.list.itemAccentColor)),
                        action: { [weak state] in
                            guard let state = state else {
                                return
                            }
                            state.copyCredentials(\.url)
                        }
                    ).minSize(CGSize(width: 44.0, height: 44.0)),
                    availableSize: CGSize(width: 44.0, height: 44.0),
                    transition: context.transition
                )
                
                let credentialsCopyKeyButton = credentialsCopyKeyButton.update(
                    component: Button(
                        content: AnyComponent(BundleIconComponent(name: "Chat/Context Menu/Copy", tintColor: environment.theme.list.itemAccentColor)),
                        action: { [weak state] in
                            guard let state = state else {
                                return
                            }
                            state.copyCredentials(\.streamKey)
                        }
                    ).minSize(CGSize(width: 44.0, height: 44.0)),
                    availableSize: CGSize(width: 44.0, height: 44.0),
                    transition: context.transition
                )
                
                context.add(credentialsBackground
                    .position(CGPoint(x: credentialsFrame.midX, y: credentialsFrame.midY))
                )
                
                context.add(credentialsStripe
                    .position(CGPoint(x: credentialsFrame.minX + credentialsSideInset + credentialsStripe.size.width / 2.0, y: credentialsFrame.minY + credentialsItemHeight))
                )
                
                context.add(credentialsURLTitle
                    .position(CGPoint(x: credentialsFrame.minX + credentialsSideInset + credentialsURLTitle.size.width / 2.0, y: credentialsFrame.minY + credentialsTopInset + credentialsURLTitle.size.height / 2.0))
                )
                context.add(credentialsURLText
                    .position(CGPoint(x: credentialsFrame.minX + credentialsSideInset + credentialsURLText.size.width / 2.0, y: credentialsFrame.minY + credentialsTopInset + credentialsTitleSpacing + credentialsURLTitle.size.height + credentialsURLText.size.height / 2.0))
                )
                context.add(credentialsCopyURLButton
                    .position(CGPoint(x: credentialsFrame.maxX - 12.0 - credentialsCopyURLButton.size.width / 2.0, y: credentialsFrame.minY + credentialsItemHeight / 2.0))
                )
                
                context.add(credentialsKeyTitle
                    .position(CGPoint(x: credentialsFrame.minX + credentialsSideInset + credentialsKeyTitle.size.width / 2.0, y: credentialsFrame.minY + credentialsItemHeight + credentialsTopInset + credentialsKeyTitle.size.height / 2.0))
                )
                context.add(credentialsKeyText
                    .position(CGPoint(x: credentialsFrame.minX + credentialsSideInset + credentialsKeyText.size.width / 2.0, y: credentialsFrame.minY + credentialsItemHeight + credentialsTopInset + credentialsTitleSpacing + credentialsKeyTitle.size.height + credentialsKeyText.size.height / 2.0))
                )
                context.add(credentialsCopyKeyButton
                    .position(CGPoint(x: credentialsFrame.maxX - 12.0 - credentialsCopyKeyButton.size.width / 2.0, y: credentialsFrame.minY + credentialsItemHeight + credentialsItemHeight / 2.0))
                )
            } else {
                let activityIndicator = activityIndicator.update(
                    component: ActivityIndicatorComponent(color: environment.theme.list.controlSecondaryColor),
                    availableSize: CGSize(width: 100.0, height: 100.0),
                    transition: context.transition
                )
                context.add(activityIndicator
                    .position(CGPoint(x: credentialsFrame.midX, y: credentialsFrame.midY))
                )
            }
            
            let buttonFrame = CGRect(origin: CGPoint(x: sideInset, y: context.availableSize.height - bottomInset - button.size.height), size: button.size)
            
            if let bottomText = bottomText {
                context.add(bottomText
                    .position(CGPoint(x: context.availableSize.width / 2.0, y: buttonFrame.minY - 14.0 - bottomText.size.height / 2.0))
                )
            }
            
            context.add(button
                .position(CGPoint(x: buttonFrame.midX, y: buttonFrame.midY))
            )
            
            return context.availableSize
        }
    }
}

public final class CreateExternalMediaStreamScreen: ViewControllerComponentContainer {
    public enum Mode {
        case create
        case view
    }
    
    private let context: AccountContext
    private let peerId: EnginePeer.Id
    private let mode: Mode
    
    public init(context: AccountContext, peerId: EnginePeer.Id, credentialsPromise: Promise<GroupCallStreamCredentials>?, mode: Mode) {
        self.context = context
        self.peerId = peerId
        self.mode = mode
        
        super.init(context: context, component: CreateExternalMediaStreamScreenComponent(context: context, peerId: peerId, mode: mode, credentialsPromise: credentialsPromise), navigationBarAppearance: .transparent, theme: defaultDarkPresentationTheme)
        
        self.navigationPresentation = .modal
        
        let presentationData = context.sharedContext.currentPresentationData.with { $0 }
        switch mode {
        case .create:
            self.title = presentationData.strings.CreateExternalStream_Title
        case .view:
            self.title = presentationData.strings.CreateExternalStream_StreamKeyTitle
        }
        
        self.navigationItem.leftBarButtonItem = UIBarButtonItem(title: presentationData.strings.Common_Cancel, style: .plain, target: self, action: #selector(self.cancelPressed))
        
        self.supportedOrientations = ViewControllerSupportedOrientations(regularSize: .all, compactSize: .portrait)
    }
    
    required public init(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    @objc private func cancelPressed() {
        self.dismiss()
    }
    
    override public func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
    }
    
    override public func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
    }
}
