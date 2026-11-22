import Foundation
import UIKit
import Display
import ComponentFlow
import NavigationBarComponent

/// The wallet's header bar, a `NavigationBarComponent` the screen draws itself (its Display bar only holds the iPhone Duo
/// side column's back), as a navigation transition source: in a push or pop the transition lifts the bar above both
/// screens and its glass morphs with the other screen's capsules, as a Display bar's does.
///
/// The view is as large as the bar and takes only the bar's touches.
final class WalletNavigationHeaderView: UIView, NavigationBarComponentTransitionSource {
    /// What a navigation transition lifts: the bar, filling it.
    private let contentView = UIView()
    private let bar = ComponentView<Empty>()
    private var component: NavigationBarComponent?
    private var isContentLifted = false
    private var transitionRole: NavigationBarTransitionRole?
    private let glassHold = NavigationBarGlassHold()
    var transitionContentFrameUpdated: ((CGRect) -> Void)?

    var barView: NavigationBarComponent.View? {
        return self.bar.view as? NavigationBarComponent.View
    }

    override init(frame: CGRect) {
        super.init(frame: frame)
        self.addSubview(self.contentView)
        self.glassHold.changed = { [weak self] in
            self?.applyGlassVisibility()
        }
    }

    required init?(coder: NSCoder) {
        preconditionFailure()
    }

    /// Lays the bar out at `width`; the caller frames this view to the returned size.
    func update(component: NavigationBarComponent, width: CGFloat, transition: ComponentTransition) -> CGSize {
        self.component = component
        let size = self.bar.update(
            transition: transition,
            component: AnyComponent(component),
            environment: {},
            containerSize: CGSize(width: width, height: 44.0)
        )
        if let barView = self.bar.view {
            if barView.superview == nil {
                self.contentView.addSubview(barView)
            }
            transition.setFrame(view: barView, frame: CGRect(origin: CGPoint(), size: size))
        }
        // While a transition holds the content, it places it and is told where it now goes.
        let contentFrame = CGRect(origin: CGPoint(), size: size)
        if self.isContentLifted {
            self.transitionContentFrameUpdated?(contentFrame)
        } else {
            transition.setFrame(view: self.contentView, frame: contentFrame)
        }
        self.glassHold.barLaidOut(content: component.primaryContent, rowFrame: contentFrame)
        self.applyGlassVisibility()
        return size
    }

    override func didMoveToWindow() {
        super.didMoveToWindow()
        if self.window == nil {
            self.glassHold.barLeftHierarchy()
        } else {
            self.glassHold.barEnteredHierarchy()
        }
    }

    override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        if self.glassHold.isHeld, event.flatMap({ $0.type == .touches }) ?? true, self.bounds.contains(point) {
            // A touch on the bar while the transition's glass finishes above it: it hands over now, so the touch finds
            // the bar's own capsules.
            self.glassHold.interrupt()
        }
        let result = super.hitTest(point, with: event)
        return (result === self || result === self.contentView) ? nil : result
    }

    // MARK: Navigation transitions

    func takeView() -> NavigationBarTransitionTakeViewInfo? {
        guard !self.isContentLifted, self.component != nil, self.alpha >= 1.0, !self.isHidden, self.contentView.superview === self else {
            return nil
        }
        self.isContentLifted = true
        return NavigationBarTransitionTakeViewInfo(containingView: self, contentView: self.contentView)
    }

    func putBack() {
        guard self.isContentLifted else {
            return
        }
        self.isContentLifted = false
        self.transitionContentFrameUpdated = nil
        self.updateTransition(role: nil, fraction: 0.0, transition: .immediate)
        self.addSubview(self.contentView)
        self.contentView.frame = CGRect(origin: CGPoint(), size: self.bounds.size)
    }

    func updateTransition(role: NavigationBarTransitionRole?, fraction: CGFloat, transition: ContainedViewLayoutTransition) {
        // In a role the transition draws the capsules; the screen's own title and balance ride its screen.
        self.transitionRole = role
        self.applyGlassVisibility()
    }

    func holdGlass(_ held: Bool, interrupted: (() -> Void)?) -> Bool {
        self.glassHold.hold(held, interrupted: interrupted, content: self.component?.primaryContent, rowFrame: CGRect(origin: CGPoint(), size: self.bounds.size))
        self.applyGlassVisibility()
        return true
    }

    private func applyGlassVisibility() {
        self.barView?.plattersDetached = self.transitionRole != nil || self.glassHold.isHeld
    }

    var componentTransitionState: NavigationBarComponentTransitionState? {
        guard let component = self.component, let content = component.primaryContent, let barView = self.barView else {
            return nil
        }
        // The header floats over the card with no backdrop of its own.
        return NavigationBarComponentTransitionState(
            content: content,
            theme: component.theme,
            strings: component.strings,
            rowFrame: CGRect(origin: CGPoint(), size: self.bounds.size),
            rowAlpha: 1.0,
            leftInset: component.leftInset,
            rightInset: component.rightInset,
            trailingButtonsInset: component.trailingButtonsInset,
            sideColumnFrame: nil,
            hidesSideColumnButtons: false,
            backdropHeight: 0.0,
            backdropColor: nil,
            backdropAlpha: 0.0,
            backdropExtension: 0.0,
            leadingPressScale: barView.detachedLeftPressScale,
            leadingPressGlow: barView.detachedLeftPressGlow,
            trailingPressScales: barView.detachedRightPressScales,
            trailingPressGlows: barView.detachedRightPressGlows
        )
    }
}
