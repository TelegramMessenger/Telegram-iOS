import Foundation
import UIKit
import AsyncDisplayKit
import Display
import GlassBackgroundComponent
import ChatTitleView
import NavigationExpansionTransition
import ChatAvatarNavigationNode
import NavigationBarNode

/// The chat's side of the chat → profile expansion: its title pill grows into the profile; its avatar capsule flies to
/// the profile's avatar; its title and status cross into the profile's.
final class ChatExpansionSource: NavigationExpansionSourceProviding {
    private weak var titleView: ChatNavigationBarTitleView?
    private weak var avatarNode: ChatAvatarNavigationNode?
    private weak var navigationBar: NavigationBar?
    private let avatarItem: UIBarButtonItem?
    private let isDark: Bool
    private let preferClearGlass: Bool

    init(titleView: ChatNavigationBarTitleView, avatarNode: ChatAvatarNavigationNode?, avatarItem: UIBarButtonItem?, navigationBar: NavigationBar?, isDark: Bool, preferClearGlass: Bool) {
        self.titleView = titleView
        self.avatarNode = avatarNode
        self.avatarItem = avatarItem
        self.navigationBar = navigationBar
        self.isDark = isDark
        self.preferClearGlass = preferClearGlass
    }

    var expansionBarExclusions: NavigationBarTransitionExclusions {
        return NavigationBarTransitionExclusions(titlePill: true, nodes: self.avatarNode.flatMap { [$0] } ?? [])
    }

    func lendExpansionSource(in screenView: UIView) -> NavigationExpansionSourceLoan? {
        guard let titleView = self.titleView, let pillFrame = titleView.glassPillFrame, let labels = titleView.lendExpansionLabels() else {
            return nil
        }
        let origin = titleView.convert(pillFrame, to: screenView)
        let container = labels.rest
        func screen(_ frame: CGRect) -> CGRect {
            return container.convert(frame, to: screenView)
        }
        var expansionLabels: [NavigationExpansionLabel] = []
        let titleScreen = screen(labels.titleFrame)
        // The icons ride with the title: the rest of the container, in the title's coordinates.
        let restInTitle = CGRect(origin: CGPoint(x: -labels.titleFrame.minX, y: -labels.titleFrame.minY), size: labels.restFrame.size)
        expansionLabels.append(NavigationExpansionLabel(view: labels.title, textCenter: CGPoint(x: labels.titleFrame.width * 0.5, y: labels.titleFrame.height * 0.5), textSize: labels.titleFrame.size, screenCenter: CGPoint(x: titleScreen.midX, y: titleScreen.midY), coloring: labels.titleTintLayers.isEmpty ? .recolor(labels.titleColor) : .multiply(labels.titleTintLayers, labels.titleColor), accessories: [(container, restInTitle)]))
        if let status = labels.status {
            let statusScreen = screen(labels.statusFrame)
            expansionLabels.append(NavigationExpansionLabel(view: status, textCenter: CGPoint(x: labels.statusFrame.width * 0.5, y: labels.statusFrame.height * 0.5), textSize: labels.statusFrame.size, screenCenter: CGPoint(x: statusScreen.midX, y: statusScreen.midY), coloring: .recolor(labels.statusColor)))
        }
        var companion: CGRect?
        if let avatarItem = self.avatarItem, let buttonView = self.navigationBar?.rightButtonView(for: avatarItem) {
            companion = buttonView.convert(buttonView.bounds, to: screenView)
        }
        // A tap's press, released on the pill's spring from the tap until now; the avatar capsule's press is the bar's
        // own (UIKit's lift on that capsule when the bar gave it up, 1 + 16/44 at full press).
        var press = ExpansionPress.none
        if let tapTime = titleView.lastTapTime {
            let release = NavigationSpringCurve(from: 1.0, target: 0.0, spring: NavigationTransitionSpring(duration: 0.4, bounce: 0.5), overshoots: true, rest: .expansion)
            press.origin = release.value(at: CACurrentMediaTime() - tapTime)
        }
        if let state = (self.navigationBar as? NavigationBarNode)?.componentTransitionState, let scale = state.trailingPressScales.first {
            press.companion = max(0.0, (scale - 1.0) / (ExpansionChoreography.liftPoints / 44.0))
        }
        return NavigationExpansionSourceLoan(origin: origin, originTint: .init(kind: self.preferClearGlass ? .clear : .panel), isDark: self.isDark, companion: companion, companionPhotoDiameter: 38.0, companionView: self.avatarNode?.view, labels: expansionLabels, press: press)
    }

    func returnExpansionSource() {
        self.titleView?.reclaimExpansionLabels()
    }
}
