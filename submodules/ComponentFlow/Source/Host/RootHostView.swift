import Foundation
import UIKit

public final class RootHostView<EnvironmentType: Equatable>: UIViewController {
    private let content: AnyComponent<(NavigationLayout, EnvironmentType)>

    private var keyboardWillChangeFrameObserver: NSObjectProtocol?
    private var inputHeight: CGFloat = 0.0

    private let environment: Environment<EnvironmentType>
    private var componentView: ComponentHostView<(NavigationLayout, EnvironmentType)>

    private var scheduledTransition: Transition?

    public init(
        content: AnyComponent<(NavigationLayout, EnvironmentType)>,
        @EnvironmentBuilder environment: () -> Environment<EnvironmentType>
    ) {
        self.content = content

        self.environment = Environment<EnvironmentType>()
        self.componentView = ComponentHostView<(NavigationLayout, EnvironmentType)>()

        EnvironmentBuilder._environment = self.environment
        let _ = environment()
        EnvironmentBuilder._environment = nil

        super.init(nibName: nil, bundle: nil)

        NotificationCenter.default.addObserver(forName: UIApplication.keyboardWillChangeFrameNotification, object: nil, queue: nil, using: { [weak self] notification in
            guard let strongSelf = self else {
                return
            }
            guard let keyboardFrame = notification.userInfo?[UIApplication.keyboardFrameEndUserInfoKey] as? CGRect else {
                return
            }

            var duration: Double = (notification.userInfo?[UIResponder.keyboardAnimationDurationUserInfoKey] as? NSNumber)?.doubleValue ?? 0.0
            if duration > Double.ulpOfOne {
                duration = 0.5
            }
            let curve: UInt = (notification.userInfo?[UIResponder.keyboardAnimationCurveUserInfoKey] as? NSNumber)?.uintValue ?? 7

            let transition: Transition
            if curve == 7 {
                transition = Transition(animation: .curve(duration: duration, curve: .spring))
            } else {
                transition = Transition(animation: .curve(duration: duration, curve: .easeInOut))
            }

            strongSelf.updateKeyboardLayout(keyboardFrame: keyboardFrame, transition: transition)
        })
    }

    required public init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    deinit {
        self.keyboardWillChangeFrameObserver.flatMap(NotificationCenter.default.removeObserver)
    }

    private func updateKeyboardLayout(keyboardFrame: CGRect, transition: Transition) {
        self.inputHeight = max(0.0, self.view.bounds.height - keyboardFrame.minY)
        if self.componentView.isUpdating || true {
            if let _ = self.scheduledTransition {
                if case .curve = transition.animation {
                    self.scheduledTransition = transition
                }
            } else {
                self.scheduledTransition = transition
            }
            self.view.setNeedsLayout()
        } else {
            self.updateComponent(size: self.view.bounds.size, transition: transition)
        }
    }

    private func updateComponent(size: CGSize, transition: Transition) {
        self.environment._isUpdated = false

        transition.setFrame(view: self.componentView, frame: CGRect(origin: CGPoint(), size: size))
        let _ = self.componentView.update(
            transition: transition,
            component: self.content,
            environment: {
                NavigationLayout(
                    statusBarHeight: size.width > size.height ? 0.0 : 40.0,
                    inputHeight: self.inputHeight,
                    bottomNavigationHeight: 22.0
                )
                self.environment[EnvironmentType.self]
            },
            containerSize: size
        )
    }

    public func updateEnvironment(@EnvironmentBuilder environment: () -> Environment<EnvironmentType>) {
        EnvironmentBuilder._environment = self.environment
        let _ = environment()
        EnvironmentBuilder._environment = nil

        if self.environment.calculateIsUpdated() {
            if !self.view.bounds.size.width.isZero {
                self.updateComponent(size: self.view.bounds.size, transition: .immediate)
            }
        }
    }

    override public func viewDidLoad() {
        super.viewDidLoad()

        self.view.addSubview(self.componentView)

        if !self.view.bounds.size.width.isZero {
            self.updateComponent(size: self.view.bounds.size, transition: .immediate)
        }
    }

    override public func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()

        if let scheduledTransition = self.scheduledTransition {
            self.scheduledTransition = nil
            self.updateComponent(size: self.view.bounds.size, transition: scheduledTransition)
        }
    }

    override public func viewWillTransition(to size: CGSize, with coordinator: UIViewControllerTransitionCoordinator) {
        super.viewWillTransition(to: size, with: coordinator)

        self.updateComponent(size: size, transition: coordinator.isAnimated ? .easeInOut(duration: 0.3) : .immediate)
    }
}
