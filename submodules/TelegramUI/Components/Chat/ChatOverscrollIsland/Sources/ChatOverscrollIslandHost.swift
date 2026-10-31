import Foundation
import UIKit
import Display
import ComponentFlow
import AccountContext
import TelegramPresentationData
import ChatOverscrollIslandLayout

/// The bubble-free mode's "next channel" island, held by the input panel it grows out of: the panel passes the glass
/// container its controls live in (glass added there merges with theirs while the two touch, the way drops do) and the
/// frame there of the control the island grows from. The host places the island; the island never sets its own frame.
public final class ChatOverscrollIslandHost {
    private struct State {
        let context: AccountContext
        let content: ChatOverscrollIslandContent
        let progress: CGFloat
        let theme: PresentationTheme
        let preferClearGlass: Bool
    }

    private var view: ChatOverscrollIslandView?
    private var state: State?
    private var isFullyExpanded = false

    public init() {
    }

    public var isActive: Bool {
        return self.view != nil
    }

    /// Shows the island at `progress` (0: a drop resting in the control's top edge, 1: pulled far enough to switch).
    public func update(context: AccountContext, content: ChatOverscrollIslandContent, progress: CGFloat, theme: PresentationTheme, preferClearGlass: Bool, container: UIView, anchorFrame: CGRect) {
        let view: ChatOverscrollIslandView
        if let current = self.view {
            view = current
        } else {
            view = ChatOverscrollIslandView()
            self.view = view
            self.isFullyExpanded = false
        }
        if view.superview !== container {
            container.addSubview(view)
        }
        let state = State(context: context, content: content, progress: progress, theme: theme, preferClearGlass: preferClearGlass)
        self.state = state
        self.layout(view: view, state: state, container: container, anchorFrame: anchorFrame)

        let isFullyExpanded = progress >= 1.0
        if self.isFullyExpanded != isFullyExpanded {
            self.isFullyExpanded = isFullyExpanded
            if isFullyExpanded {
                // A small spring as it lets go of the control, the way a drop does.
                view.layer.animateSpring(from: 0.92 as NSNumber, to: 1.0 as NSNumber, keyPath: "transform.scale", duration: 0.5, initialVelocity: 0.0, damping: 70.0)
            }
        }
    }

    /// Re-places a showing island after the panel's own layout moved its control or container.
    public func updateAnchor(container: UIView, anchorFrame: CGRect) {
        guard let view = self.view, let state = self.state else {
            return
        }
        if view.superview !== container {
            container.addSubview(view)
        }
        self.layout(view: view, state: state, container: container, anchorFrame: anchorFrame)
    }

    /// Moves a showing island next to `snapshotView`, an on-screen snapshot of `panelView` with its bounds, just above
    /// it, and sinks it there. Not into it: glass does not render inside a snapshot view. `container` and
    /// `anchorFrame` are where it stands now.
    public func handOver(to snapshotView: UIView, panelView: UIView, container: UIView, anchorFrame: CGRect?) {
        guard let view = self.view, view.superview === container, let hostView = snapshotView.superview else {
            return
        }
        let center = snapshotView.convert(container.convert(view.center, to: panelView), to: hostView)
        let hostAnchorFrame = anchorFrame.flatMap { snapshotView.convert(container.convert($0, to: panelView), to: hostView) }
        hostView.insertSubview(view, aboveSubview: snapshotView)
        view.center = center
        self.dismiss(anchorFrame: hostAnchorFrame, animated: true)
    }

    /// Sinks the island back into the control it grew out of (`anchorFrame`, or where it stands without one), then
    /// removes it; without animation it goes at once.
    public func dismiss(anchorFrame: CGRect?, animated: Bool) {
        guard let view = self.view else {
            return
        }
        let state = self.state
        self.view = nil
        self.state = nil
        self.isFullyExpanded = false

        guard animated, let state else {
            view.removeFromSuperview()
            return
        }
        let diameter = ChatOverscrollIslandMetrics.dropDiameter
        let targetFrame = anchorFrame.flatMap(chatOverscrollIslandSinkFrame(anchorFrame:)) ?? CGRect(x: view.center.x - diameter * 0.5, y: view.center.y - diameter * 0.5, width: diameter, height: diameter)
        let transition = ComponentTransition(animation: .curve(duration: 0.3, curve: .spring))
        transition.setBounds(view: view, bounds: CGRect(origin: CGPoint(), size: targetFrame.size))
        transition.setPosition(view: view, position: CGPoint(x: targetFrame.midX, y: targetFrame.midY))
        view.update(size: targetFrame.size, isDark: state.theme.overallDarkAppearance, preferClearGlass: state.preferClearGlass, contentAlpha: 0.0, isVisible: false, transition: transition, contentTransition: ComponentTransition(animation: .curve(duration: 0.08, curve: .easeInOut)))
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.32, execute: { [weak view] in
            view?.removeFromSuperview()
        })
    }

    private func layout(view: ChatOverscrollIslandView, state: State, container: UIView, anchorFrame: CGRect) {
        view.updateContent(context: state.context, content: state.content, theme: state.theme, maxWidth: chatOverscrollIslandMaxWidth(containerWidth: container.bounds.width))
        let frame = chatOverscrollIslandFrame(progress: state.progress, anchorFrame: anchorFrame, fullWidth: view.widths.full)
        // Bounds and position rather than `frame`: the spring above scales the layer, and `frame` under a transform
        // is not the frame the island is given.
        view.bounds = CGRect(origin: CGPoint(), size: frame.size)
        view.center = CGPoint(x: frame.midX, y: frame.midY)
        view.update(size: frame.size, isDark: state.theme.overallDarkAppearance, preferClearGlass: state.preferClearGlass, contentAlpha: chatOverscrollIslandContentAlpha(progress: state.progress), isVisible: true, transition: .immediate, contentTransition: .immediate)
    }
}
