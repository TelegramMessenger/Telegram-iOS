import Foundation
import UIKit
import AsyncDisplayKit
import Display
import ComponentFlow
import ViewControllerComponent
import Postbox
import TelegramCore
import AccountContext
import PlainButtonComponent
import SwiftSignalKit
import LottieComponent
import BundleIconComponent
import ContextUI
import TelegramPresentationData

private final class VideoChatScreenComponent: Component {
    typealias EnvironmentType = ViewControllerComponentContainer.Environment
    
    let initialData: VideoChatScreenV2Impl.InitialData
    let call: PresentationGroupCall

    init(
        initialData: VideoChatScreenV2Impl.InitialData,
        call: PresentationGroupCall
    ) {
        self.initialData = initialData
        self.call = call
    }

    static func ==(lhs: VideoChatScreenComponent, rhs: VideoChatScreenComponent) -> Bool {
        return true
    }
    
    private struct PanGestureState {
        var offsetFraction: CGFloat
        
        init(offsetFraction: CGFloat) {
            self.offsetFraction = offsetFraction
        }
    }

    final class View: UIView {
        private let containerView: UIView
        
        private var component: VideoChatScreenComponent?
        private var environment: ViewControllerComponentContainer.Environment?
        private weak var state: EmptyComponentState?
        private var isUpdating: Bool = false
        
        private var panGestureState: PanGestureState?
        private var notifyDismissedInteractivelyOnPanGestureApply: Bool = false
        private var completionOnPanGestureApply: (() -> Void)?
        
        private let title = ComponentView<Empty>()
        private let navigationLeftButton = ComponentView<Empty>()
        private let navigationRightButton = ComponentView<Empty>()
        
        private let videoButton = ComponentView<Empty>()
        private let leaveButton = ComponentView<Empty>()
        private let microphoneButton = ComponentView<Empty>()
        
        private let participants = ComponentView<Empty>()
        
        private var peer: EnginePeer?
        private var callState: PresentationGroupCallState?
        private var stateDisposable: Disposable?
        
        private var members: PresentationGroupCallMembers?
        private var membersDisposable: Disposable?
        
        override init(frame: CGRect) {
            self.containerView = UIView()
            self.containerView.clipsToBounds = true
            
            super.init(frame: frame)
            
            self.backgroundColor = nil
            self.isOpaque = false
            
            self.addSubview(self.containerView)
            
            self.addGestureRecognizer(UIPanGestureRecognizer(target: self, action: #selector(self.panGesture(_:))))
            
            self.panGestureState = PanGestureState(offsetFraction: 1.0)
        }
        
        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }
        
        deinit {
            self.stateDisposable?.dispose()
            self.membersDisposable?.dispose()
        }
        
        func animateIn() {
            self.panGestureState = PanGestureState(offsetFraction: 1.0)
            self.state?.updated(transition: .immediate)
            
            self.panGestureState = nil
            self.state?.updated(transition: .spring(duration: 0.5))
        }
        
        func animateOut(completion: @escaping () -> Void) {
            self.panGestureState = PanGestureState(offsetFraction: 1.0)
            self.completionOnPanGestureApply = completion
            self.state?.updated(transition: .spring(duration: 0.5))
        }
        
        @objc private func panGesture(_ recognizer: UIPanGestureRecognizer) {
            switch recognizer.state {
            case .began, .changed:
                if !self.bounds.height.isZero && !self.notifyDismissedInteractivelyOnPanGestureApply {
                    let translation = recognizer.translation(in: self)
                    self.panGestureState = PanGestureState(offsetFraction: translation.y / self.bounds.height)
                    self.state?.updated(transition: .immediate)
                }
            case .cancelled, .ended:
                if !self.bounds.height.isZero {
                    let translation = recognizer.translation(in: self)
                    let panGestureState = PanGestureState(offsetFraction: translation.y / self.bounds.height)
                    
                    let velocity = recognizer.velocity(in: self)
                    
                    self.panGestureState = nil
                    if abs(panGestureState.offsetFraction) > 0.6 || abs(velocity.y) >= 100.0 {
                        self.panGestureState = PanGestureState(offsetFraction: panGestureState.offsetFraction < 0.0 ? -1.0 : 1.0)
                        self.notifyDismissedInteractivelyOnPanGestureApply = true
                    }
                    
                    self.state?.updated(transition: .spring(duration: 0.4))
                }
            default:
                break
            }
        }
        
        private func openMoreMenu() {
            guard let sourceView = self.navigationLeftButton.view else {
                return
            }
            guard let component = self.component, let environment = self.environment, let controller = environment.controller() else {
                return
            }
            
            var items: [ContextMenuItem] = []
            let text: String
            let isScheduled = component.call.schedulePending
            if case let .channel(channel) = self.peer, case .broadcast = channel.info {
                text = isScheduled ? environment.strings.VoiceChat_CancelLiveStream : environment.strings.VoiceChat_EndLiveStream
            } else {
                text = isScheduled ? environment.strings.VoiceChat_CancelVoiceChat : environment.strings.VoiceChat_EndVoiceChat
            }
            items.append(.action(ContextMenuActionItem(text: text, textColor: .destructive, icon: { theme in
                return generateTintedImage(image: UIImage(bundleImageName: "Chat/Context Menu/Clear"), color: theme.actionSheet.destructiveActionTextColor)
            }, action: { _, f in
                f(.dismissWithoutContent)

                /*guard let strongSelf = self else {
                    return
                }

                let action: () -> Void = {
                    guard let strongSelf = self else {
                        return
                    }

                    let _ = (strongSelf.call.leave(terminateIfPossible: true)
                    |> filter { $0 }
                    |> take(1)
                    |> deliverOnMainQueue).start(completed: {
                        self?.controller?.dismiss()
                    })
                }

                let title: String
                let text: String
                if let channel = strongSelf.peer as? TelegramChannel, case .broadcast = channel.info {
                    title = isScheduled ? strongSelf.presentationData.strings.LiveStream_CancelConfirmationTitle : strongSelf.presentationData.strings.LiveStream_EndConfirmationTitle
                    text = isScheduled ? strongSelf.presentationData.strings.LiveStream_CancelConfirmationText : strongSelf.presentationData.strings.LiveStream_EndConfirmationText
                } else {
                    title = isScheduled ? strongSelf.presentationData.strings.VoiceChat_CancelConfirmationTitle : strongSelf.presentationData.strings.VoiceChat_EndConfirmationTitle
                    text = isScheduled ? strongSelf.presentationData.strings.VoiceChat_CancelConfirmationText : strongSelf.presentationData.strings.VoiceChat_EndConfirmationText
                }

                let alertController = textAlertController(context: strongSelf.context, forceTheme: strongSelf.darkTheme, title: title, text: text, actions: [TextAlertAction(type: .defaultAction, title: strongSelf.presentationData.strings.Common_Cancel, action: {}), TextAlertAction(type: .genericAction, title: isScheduled ? strongSelf.presentationData.strings.VoiceChat_CancelConfirmationEnd : strongSelf.presentationData.strings.VoiceChat_EndConfirmationEnd, action: {
                    action()
                })])
                strongSelf.controller?.present(alertController, in: .window(.root))*/
            })))

            let presentationData = component.call.accountContext.sharedContext.currentPresentationData.with({ $0 }).withUpdated(theme: environment.theme)
            let contextController = ContextController(presentationData: presentationData, source: .reference(VoiceChatContextReferenceContentSource(controller: controller, sourceView: sourceView)), items: .single(ContextController.Items(content: .list(items))), gesture: nil)
            controller.presentInGlobalOverlay(contextController)
        }
        
        func update(component: VideoChatScreenComponent, availableSize: CGSize, state: EmptyComponentState, environment: Environment<ViewControllerComponentContainer.Environment>, transition: ComponentTransition) -> CGSize {
            self.isUpdating = true
            defer {
                self.isUpdating = false
            }
            
            let environment = environment[ViewControllerComponentContainer.Environment.self].value
            let themeUpdated = self.environment?.theme !== environment.theme
            
            if self.component == nil {
                self.peer = component.initialData.peer
                self.members = component.initialData.members
                self.callState = component.initialData.callState
                
                self.membersDisposable = (component.call.members
                |> deliverOnMainQueue).startStrict(next: { [weak self] members in
                    guard let self else {
                        return
                    }
                    if self.members != members {
                        self.members = members
                        
                        if !self.isUpdating {
                            self.state?.updated(transition: .immediate)
                        }
                    }
                })
                
                self.stateDisposable = (component.call.state
                |> deliverOnMainQueue).startStrict(next: { [weak self] callState in
                    guard let self else {
                        return
                    }
                    if self.callState != callState {
                        self.callState = callState
                        
                        if !self.isUpdating {
                            self.state?.updated(transition: .immediate)
                        }
                    }
                })
            }
            
            self.component = component
            self.environment = environment
            self.state = state
            
            if themeUpdated {
                self.containerView.backgroundColor = .black
            }
            
            var containerOffset: CGFloat = 0.0
            if let panGestureState = self.panGestureState {
                containerOffset = panGestureState.offsetFraction * availableSize.height
                self.containerView.layer.cornerRadius = environment.deviceMetrics.screenCornerRadius
            }
            
            transition.setFrame(view: self.containerView, frame: CGRect(origin: CGPoint(x: 0.0, y: containerOffset), size: availableSize), completion: { [weak self] completed in
                guard let self, completed else {
                    return
                }
                if self.panGestureState == nil {
                    self.containerView.layer.cornerRadius = 0.0
                }
                if self.notifyDismissedInteractivelyOnPanGestureApply {
                    self.notifyDismissedInteractivelyOnPanGestureApply = false
                    
                    if let controller = self.environment?.controller() as? VideoChatScreenV2Impl {
                        controller.superDismiss()
                    }
                }
                if let completionOnPanGestureApply = self.completionOnPanGestureApply {
                    self.completionOnPanGestureApply = nil
                    DispatchQueue.main.async {
                        completionOnPanGestureApply()
                    }
                }
            })
            
            let sideInset: CGFloat = environment.safeInsets.left + 14.0
            
            let topInset: CGFloat = environment.statusBarHeight + 2.0
            let navigationBarHeight: CGFloat = 61.0
            let navigationHeight = topInset + navigationBarHeight
            
            let navigationButtonAreaWidth: CGFloat = 40.0
            let navigationButtonDiameter: CGFloat = 28.0
            
            let navigationLeftButtonSize = self.navigationLeftButton.update(
                transition: .immediate,
                component: AnyComponent(PlainButtonComponent(
                    content: AnyComponent(LottieComponent(
                        content: LottieComponent.AppBundleContent(
                            name: "anim_profilemore"
                        ),
                        color: .white
                    )),
                    background: AnyComponent(Circle(
                        fillColor: UIColor(white: 1.0, alpha: 0.1),
                        size: CGSize(width: navigationButtonDiameter, height: navigationButtonDiameter)
                    )),
                    effectAlignment: .center,
                    action: { [weak self] in
                        guard let self else {
                            return
                        }
                        self.openMoreMenu()
                    }
                )),
                environment: {},
                containerSize: CGSize(width: navigationButtonDiameter, height: navigationButtonDiameter)
            )
            
            let navigationRightButtonSize = self.navigationRightButton.update(
                transition: .immediate,
                component: AnyComponent(PlainButtonComponent(
                    content: AnyComponent(Image(
                        image: closeButtonImage(dark: false)
                    )),
                    background: AnyComponent(Circle(
                        fillColor: UIColor(white: 1.0, alpha: 0.1),
                        size: CGSize(width: navigationButtonDiameter, height: navigationButtonDiameter)
                    )),
                    effectAlignment: .center,
                    action: { [weak self] in
                        guard let self else {
                            return
                        }
                        self.environment?.controller()?.dismiss()
                    }
                )),
                environment: {},
                containerSize: CGSize(width: navigationButtonDiameter, height: navigationButtonDiameter)
            )
            
            let navigationLeftButtonFrame = CGRect(origin: CGPoint(x: sideInset + floor((navigationButtonAreaWidth - navigationLeftButtonSize.width) * 0.5), y: topInset + floor((navigationBarHeight - navigationLeftButtonSize.height) * 0.5)), size: navigationLeftButtonSize)
            if let navigationLeftButtonView = self.navigationLeftButton.view {
                if navigationLeftButtonView.superview == nil {
                    self.containerView.addSubview(navigationLeftButtonView)
                }
                transition.setFrame(view: navigationLeftButtonView, frame: navigationLeftButtonFrame)
            }
            
            let navigationRightButtonFrame = CGRect(origin: CGPoint(x: availableSize.width - sideInset - navigationButtonAreaWidth + floor((navigationButtonAreaWidth - navigationRightButtonSize.width) * 0.5), y: topInset + floor((navigationBarHeight - navigationRightButtonSize.height) * 0.5)), size: navigationRightButtonSize)
            if let navigationRightButtonView = self.navigationRightButton.view {
                if navigationRightButtonView.superview == nil {
                    self.containerView.addSubview(navigationRightButtonView)
                }
                transition.setFrame(view: navigationRightButtonView, frame: navigationRightButtonFrame)
            }
            
            let titleSize = self.title.update(
                transition: transition,
                component: AnyComponent(VideoChatTitleComponent(
                    title: self.peer?.debugDisplayTitle ?? " ",
                    status: .idle(count: self.members?.totalCount ?? 1),
                    strings: environment.strings
                )),
                environment: {},
                containerSize: CGSize(width: availableSize.width - sideInset * 2.0 - navigationButtonAreaWidth * 2.0 - 4.0 * 2.0, height: 100.0)
            )
            let titleFrame = CGRect(origin: CGPoint(x: floor((availableSize.width - titleSize.width) * 0.5), y: topInset + floor((navigationBarHeight - titleSize.height) * 0.5)), size: titleSize)
            if let titleView = self.title.view {
                if titleView.superview == nil {
                    self.containerView.addSubview(titleView)
                }
                transition.setFrame(view: titleView, frame: titleFrame)
            }
            
            let actionButtonDiameter: CGFloat = 56.0
            let microphoneButtonDiameter: CGFloat = 116.0
            
            let maxActionMicrophoneButtonSpacing: CGFloat = 38.0
            let buttonsSideInset: CGFloat = 42.0
            
            let buttonsWidth: CGFloat = actionButtonDiameter * 2.0 + microphoneButtonDiameter
            let remainingButtonsSpace: CGFloat = availableSize.width - buttonsSideInset * 2.0 - buttonsWidth
            let actionMicrophoneButtonSpacing = min(maxActionMicrophoneButtonSpacing, floor(remainingButtonsSpace * 0.5))
            
            let microphoneButtonFrame = CGRect(origin: CGPoint(x: floor((availableSize.width - microphoneButtonDiameter) * 0.5), y: availableSize.height - 48.0 - environment.safeInsets.bottom - microphoneButtonDiameter), size: CGSize(width: microphoneButtonDiameter, height: microphoneButtonDiameter))
            let leftActionButtonFrame = CGRect(origin: CGPoint(x: microphoneButtonFrame.minX - actionMicrophoneButtonSpacing - actionButtonDiameter, y: microphoneButtonFrame.minY + floor((microphoneButtonFrame.height - actionButtonDiameter) * 0.5)), size: CGSize(width: actionButtonDiameter, height: actionButtonDiameter))
            let rightActionButtonFrame = CGRect(origin: CGPoint(x: microphoneButtonFrame.maxX + actionMicrophoneButtonSpacing, y: microphoneButtonFrame.minY + floor((microphoneButtonFrame.height - actionButtonDiameter) * 0.5)), size: CGSize(width: actionButtonDiameter, height: actionButtonDiameter))
            
            let participantsSize = self.participants.update(
                transition: transition,
                component: AnyComponent(VideoChatParticipantsComponent(
                    call: component.call,
                    members: self.members,
                    theme: environment.theme,
                    strings: environment.strings,
                    sideInset: sideInset
                )),
                environment: {},
                containerSize: CGSize(width: availableSize.width, height: microphoneButtonFrame.minY - navigationHeight)
            )
            let participantsFrame = CGRect(origin: CGPoint(x: 0.0, y: navigationHeight), size: participantsSize)
            if let participantsView = self.participants.view {
                if participantsView.superview == nil {
                    self.containerView.addSubview(participantsView)
                }
                transition.setFrame(view: participantsView, frame: participantsFrame)
            }
            
            let micButtonContent: VideoChatMicButtonComponent.Content
            let actionButtonMicrophoneState: VideoChatActionButtonComponent.MicrophoneState
            if let callState = self.callState {
                switch callState.networkState {
                case .connecting:
                    micButtonContent = .connecting
                    actionButtonMicrophoneState = .connecting
                case .connected:
                    if let _ = callState.muteState {
                        micButtonContent = .muted
                        actionButtonMicrophoneState = .muted
                    } else {
                        micButtonContent = .unmuted
                        actionButtonMicrophoneState = .unmuted
                    }
                }
            } else {
                micButtonContent = .connecting
                actionButtonMicrophoneState = .connecting
            }
            
            let _ = self.microphoneButton.update(
                transition: transition,
                component: AnyComponent(PlainButtonComponent(
                    content: AnyComponent(VideoChatMicButtonComponent(
                        content: micButtonContent
                    )),
                    effectAlignment: .center,
                    action: { [weak self] in
                        guard let self, let component = self.component else {
                            return
                        }
                        guard let callState = self.callState else {
                            return
                        }
                        if let muteState = callState.muteState {
                            if muteState.canUnmute {
                                component.call.setIsMuted(action: .unmuted)
                            }
                        } else {
                            component.call.setIsMuted(action: .muted(isPushToTalkActive: false))
                        }
                    },
                    animateAlpha: false,
                    animateScale: false
                )),
                environment: {},
                containerSize: CGSize(width: microphoneButtonDiameter, height: microphoneButtonDiameter)
            )
            if let microphoneButtonView = self.microphoneButton.view {
                if microphoneButtonView.superview == nil {
                    self.containerView.addSubview(microphoneButtonView)
                }
                transition.setPosition(view: microphoneButtonView, position: microphoneButtonFrame.center)
                transition.setBounds(view: microphoneButtonView, bounds: CGRect(origin: CGPoint(), size: microphoneButtonFrame.size))
            }
            
            let _ = self.videoButton.update(
                transition: transition,
                component: AnyComponent(PlainButtonComponent(
                    content: AnyComponent(VideoChatActionButtonComponent(
                        content: .video(isActive: false),
                        microphoneState: actionButtonMicrophoneState
                    )),
                    effectAlignment: .center,
                    action: {
                        
                    },
                    animateAlpha: false
                )),
                environment: {},
                containerSize: CGSize(width: actionButtonDiameter, height: actionButtonDiameter)
            )
            if let videoButtonView = self.videoButton.view {
                if videoButtonView.superview == nil {
                    self.containerView.addSubview(videoButtonView)
                }
                transition.setPosition(view: videoButtonView, position: leftActionButtonFrame.center)
                transition.setBounds(view: videoButtonView, bounds: CGRect(origin: CGPoint(), size: leftActionButtonFrame.size))
            }
            
            let _ = self.leaveButton.update(
                transition: transition,
                component: AnyComponent(PlainButtonComponent(
                    content: AnyComponent(VideoChatActionButtonComponent(
                        content: .leave,
                        microphoneState: actionButtonMicrophoneState
                    )),
                    effectAlignment: .center,
                    action: { [weak self] in
                        guard let self, let component = self.component else {
                            return
                        }
                        let _ = component.call.leave(terminateIfPossible: false).startStandalone()
                        
                        if let controller = self.environment?.controller() as? VideoChatScreenV2Impl {
                            controller.dismiss(closing: true, manual: false)
                        }
                    },
                    animateAlpha: false
                )),
                environment: {},
                containerSize: CGSize(width: actionButtonDiameter, height: actionButtonDiameter)
            )
            if let leaveButtonView = self.leaveButton.view {
                if leaveButtonView.superview == nil {
                    self.containerView.addSubview(leaveButtonView)
                }
                transition.setPosition(view: leaveButtonView, position: rightActionButtonFrame.center)
                transition.setBounds(view: leaveButtonView, bounds: CGRect(origin: CGPoint(), size: rightActionButtonFrame.size))
            }
            
            return availableSize
        }
    }

    func makeView() -> View {
        return View()
    }

    func update(view: View, availableSize: CGSize, state: EmptyComponentState, environment: Environment<EnvironmentType>, transition: ComponentTransition) -> CGSize {
        return view.update(component: self, availableSize: availableSize, state: state, environment: environment, transition: transition)
    }
}

final class VideoChatScreenV2Impl: ViewControllerComponentContainer, VoiceChatController {
    final class InitialData {
        let peer: EnginePeer?
        let members: PresentationGroupCallMembers?
        let callState: PresentationGroupCallState
        
        init(
            peer: EnginePeer?,
            members: PresentationGroupCallMembers?,
            callState: PresentationGroupCallState
        ) {
            self.peer = peer
            self.members = members
            self.callState = callState
        }
    }
    
    public let call: PresentationGroupCall
    public var currentOverlayController: VoiceChatOverlayController?
    public var parentNavigationController: NavigationController?
    
    public var onViewDidAppear: (() -> Void)?
    public var onViewDidDisappear: (() -> Void)?
    
    private var isDismissed: Bool = true
    private var didAppearOnce: Bool = false
    private var isAnimatingDismiss: Bool = false
    
    private var idleTimerExtensionDisposable: Disposable?

    public init(
        initialData: InitialData,
        call: PresentationGroupCall
    ) {
        self.call = call

        let theme = customizeDefaultDarkPresentationTheme(
            theme: defaultDarkPresentationTheme,
            editing: false,
            title: nil,
            accentColor: UIColor(rgb: 0x3E88F7),
            backgroundColors: [],
            bubbleColors: [],
            animateBubbleColors: false
        )
        
        super.init(
            context: call.accountContext,
            component: VideoChatScreenComponent(
                initialData: initialData,
                call: call
            ),
            navigationBarAppearance: .none,
            statusBarStyle: .default,
            presentationMode: .default,
            theme: .custom(theme)
        )
    }
    
    required init(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    deinit {
        self.idleTimerExtensionDisposable?.dispose()
    }
    
    override public func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        if self.isDismissed {
            self.isDismissed = false
            
            if let componentView = self.node.hostView.componentView as? VideoChatScreenComponent.View {
                componentView.animateIn()
            }
        }
        
        if !self.didAppearOnce {
            self.didAppearOnce = true
            
            self.idleTimerExtensionDisposable?.dispose()
            self.idleTimerExtensionDisposable = self.call.accountContext.sharedContext.applicationBindings.pushIdleTimerExtension()
        }
        
        self.onViewDidAppear?()
    }
    
    override public func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        
        self.idleTimerExtensionDisposable?.dispose()
        self.idleTimerExtensionDisposable = nil
        
        self.didAppearOnce = false
        if !self.isDismissed {
            self.isDismissed = true
        }
        
        self.onViewDidDisappear?()
    }

    public func dismiss(closing: Bool, manual: Bool) {
        self.dismiss()
    }
    
    override public func dismiss(completion: (() -> Void)? = nil) {
        if !self.isAnimatingDismiss {
            if let componentView = self.node.hostView.componentView as? VideoChatScreenComponent.View {
                self.isAnimatingDismiss = true
                componentView.animateOut(completion: { [weak self] in
                    guard let self else {
                        return
                    }
                    self.isAnimatingDismiss = false
                    self.superDismiss()
                })
            } else {
                self.superDismiss()
            }
        }
    }
    
    func superDismiss() {
        super.dismiss()
    }
    
    static func initialData(call: PresentationGroupCall) -> Signal<InitialData, NoError> {
        return combineLatest(
            call.accountContext.engine.data.get(
                TelegramEngine.EngineData.Item.Peer.Peer(id: call.peerId)
            ),
            call.members |> take(1),
            call.state |> take(1)
        )
        |> map { peer, members, callState -> InitialData in
            return InitialData(
                peer: peer,
                members: members,
                callState: callState
            )
        }
    }
}
