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

private final class VideoChatScreenComponent: Component {
    typealias EnvironmentType = ViewControllerComponentContainer.Environment
    
    let call: PresentationGroupCall

    init(
        call: PresentationGroupCall
    ) {
        self.call = call
    }

    static func ==(lhs: VideoChatScreenComponent, rhs: VideoChatScreenComponent) -> Bool {
        return true
    }

    final class View: UIView {
        private var component: VideoChatScreenComponent?
        private var environment: ViewControllerComponentContainer.Environment?
        private weak var state: EmptyComponentState?
        private var isUpdating: Bool = false
        
        private let closeButton = ComponentView<Empty>()
        private let participants = ComponentView<Empty>()
        
        private var members: PresentationGroupCallMembers?
        private var membersDisposable: Disposable?
        
        override init(frame: CGRect) {
            super.init(frame: frame)
        }
        
        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }
        
        deinit {
            self.membersDisposable?.dispose()
        }
        
        func update(component: VideoChatScreenComponent, availableSize: CGSize, state: EmptyComponentState, environment: Environment<ViewControllerComponentContainer.Environment>, transition: ComponentTransition) -> CGSize {
            self.isUpdating = true
            defer {
                self.isUpdating = false
            }
            
            let environment = environment[ViewControllerComponentContainer.Environment.self].value
            let themeUpdated = self.environment?.theme !== environment.theme
            
            if self.component == nil {
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
            }
            
            self.component = component
            self.environment = environment
            self.state = state
            
            if themeUpdated {
                self.backgroundColor = .black
            }
            
            let closeButtonSize = self.closeButton.update(
                transition: transition,
                component: AnyComponent(PlainButtonComponent(
                    content: AnyComponent(Text(
                        text: "Leave", font: Font.regular(16.0), color: environment.theme.list.itemDestructiveColor)),
                    effectAlignment: .center,
                    minSize: CGSize(width: 44.0, height: 44.0),
                    contentInsets: UIEdgeInsets(),
                    action: { [weak self] in
                        guard let self, let component = self.component else {
                            return
                        }
                        
                        let _ = component.call.leave(terminateIfPossible: false).startStandalone()
                        
                        if let controller = self.environment?.controller() {
                            controller.dismiss()
                        }
                    },
                    animateAlpha: true,
                    animateScale: true,
                    animateContents: false
                )),
                environment: {},
                containerSize: CGSize(width: 100.0, height: 100.0)
            )
            let closeButtonFrame = CGRect(origin: CGPoint(x: availableSize.width - 16.0 - closeButtonSize.width, y: availableSize.height - environment.safeInsets.bottom - 16.0 - closeButtonSize.height), size: closeButtonSize)
            if let closeButtonView = self.closeButton.view {
                if closeButtonView.superview == nil {
                    self.addSubview(closeButtonView)
                }
                transition.setFrame(view: closeButtonView, frame: closeButtonFrame)
            }
            
            let participantsSize = self.participants.update(
                transition: transition,
                component: AnyComponent(VideoChatParticipantsComponent(
                    call: component.call,
                    members: self.members
                )),
                environment: {},
                containerSize: CGSize(width: availableSize.width, height: closeButtonFrame.minY - environment.statusBarHeight)
            )
            let participantsFrame = CGRect(origin: CGPoint(x: 0.0, y: environment.statusBarHeight), size: participantsSize)
            if let participantsView = self.participants.view {
                if participantsView.superview == nil {
                    self.addSubview(participantsView)
                }
                transition.setFrame(view: participantsView, frame: participantsFrame)
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

public final class VideoChatScreenV2Impl: ViewControllerComponentContainer, VoiceChatController {
    public let call: PresentationGroupCall
    public var currentOverlayController: VoiceChatOverlayController?
    public var parentNavigationController: NavigationController?
    
    public var onViewDidAppear: (() -> Void)?
    public var onViewDidDisappear: (() -> Void)?
    
    private var isDismissed: Bool = false
    private var didAppearOnce: Bool = false
    
    private var idleTimerExtensionDisposable: Disposable?

    public init(
        call: PresentationGroupCall
    ) {
        self.call = call

        super.init(
            context: call.accountContext,
            component: VideoChatScreenComponent(
                call: call
            ),
            navigationBarAppearance: .none,
            statusBarStyle: .ignore,
            presentationMode: .default,
            theme: .dark
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
        
        self.isDismissed = false
        
        if !self.didAppearOnce {
            self.didAppearOnce = true
            
            //self.controllerNode.animateIn()
            
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
        self.isDismissed = true
        
        self.onViewDidDisappear?()
    }

    public func dismiss(closing: Bool, manual: Bool) {
        self.dismiss()
    }
}
