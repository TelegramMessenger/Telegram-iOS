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
        // The avatar's glass circle: a square as thick as the capsule the button sits in, centred on the button (the bar's
        // row draws a 44 pt circle around the 44 pt button; iPhone Duo's side column a 48 pt capsule).
        var companion: CGRect?
        var companionPressScale: CGFloat = 1.0
        if let avatarItem = self.avatarItem, let buttonView = self.navigationBar?.rightButtonView(for: avatarItem) {
            let button = buttonView.convert(buttonView.bounds, to: screenView)
            var side = button.height
            if let capsule = (self.navigationBar as? NavigationBarNode)?.rightButtonCapsule(for: avatarItem) {
                let capsuleFrame = capsule.container.convert(capsule.container.bounds, to: screenView)
                side = min(capsuleFrame.width, capsuleFrame.height)
                companionPressScale = capsule.pressScale
            }
            companion = CGRect(x: button.midX - side * 0.5, y: button.midY - side * 0.5, width: side, height: side)
        }
        // A tap's press, released on the pill's spring from the tap until now; the avatar circle's press is the bar's own
        // (UIKit's lift on that circle when the bar gave it up, 1 + 16/44 at full press on a 44 pt circle).
        var press = ExpansionPress.none
        if let tapTime = titleView.lastTapTime {
            let release = NavigationSpringCurve(from: 1.0, target: 0.0, spring: NavigationTransitionSpring(duration: 0.4, bounce: 0.5), overshoots: true, rest: .expansion)
            press.origin = release.value(at: CACurrentMediaTime() - tapTime)
        }
        if let companion {
            press.companion = max(0.0, (companionPressScale - 1.0) / (ExpansionChoreography.liftPoints / companion.width))
        }
        return NavigationExpansionSourceLoan(origin: origin, originTint: .init(kind: self.preferClearGlass ? .clear : .panel), isDark: self.isDark, companion: companion, companionPhotoDiameter: 38.0, companionView: self.avatarNode?.view, labels: expansionLabels, press: press)
    }

    func returnExpansionSource() {
        self.titleView?.reclaimExpansionLabels()
    }
}
