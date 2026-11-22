import Foundation
import UIKit
import AsyncDisplayKit
import Display
import ChatTitleView
import ChatListHeaderComponent
import NavigationExpansionTransition

/// The chat side list header's side of the expansion into a profile, as `ChatExpansionSource` is the chat header's: its
/// title pill grows into the profile, its avatar flies to the profile's avatar, its title and status cross into the
/// profile's.
final class ChatListSideListExpansionSource: NavigationExpansionSourceProviding {
    private weak var titleView: ChatTitleComponent.View?
    private weak var avatarButtonNode: ASDisplayNode?
    private weak var avatarView: UIView?
    private weak var barView: ChatListNavigationBar.View?
    private let isDark: Bool

    init(titleView: ChatTitleComponent.View, barView: ChatListNavigationBar.View?, avatarButtonNode: ASDisplayNode?, avatarView: UIView?, isDark: Bool) {
        self.titleView = titleView
        self.barView = barView
        self.avatarButtonNode = avatarButtonNode
        self.avatarView = avatarView
        self.isDark = isDark
    }

    var expansionBarExclusions: NavigationBarTransitionExclusions {
        return NavigationBarTransitionExclusions(titlePill: true, nodes: self.avatarButtonNode.flatMap { [$0] } ?? [])
    }

    func lendExpansionSource(in screenView: UIView) -> NavigationExpansionSourceLoan? {
        guard let titleView = self.titleView, let pillFrame = titleView.glassPillFrame, let labels = titleView.lendExpansionLabels() else {
            return nil
        }
        self.barView?.updateExpansionContentStaysInScreen(true)
        let origin = titleView.convert(pillFrame, to: screenView)
        let container = labels.rest
        var expansionLabels: [NavigationExpansionLabel] = []
        let titleScreen = container.convert(labels.titleFrame, to: screenView)
        // The icons ride with the title: the rest of the container, in the title's coordinates.
        let restInTitle = CGRect(origin: CGPoint(x: -labels.titleFrame.minX, y: -labels.titleFrame.minY), size: labels.restFrame.size)
        expansionLabels.append(NavigationExpansionLabel(view: labels.title, textCenter: CGPoint(x: labels.titleFrame.width * 0.5, y: labels.titleFrame.height * 0.5), textSize: labels.titleFrame.size, screenCenter: CGPoint(x: titleScreen.midX, y: titleScreen.midY), coloring: labels.titleTintLayers.isEmpty ? .recolor(labels.titleColor) : .multiply(labels.titleTintLayers, labels.titleColor), accessories: [(container, restInTitle)]))
        if let status = labels.status {
            let statusScreen = container.convert(labels.statusFrame, to: screenView)
            expansionLabels.append(NavigationExpansionLabel(view: status, textCenter: CGPoint(x: labels.statusFrame.width * 0.5, y: labels.statusFrame.height * 0.5), textSize: labels.statusFrame.size, screenCenter: CGPoint(x: statusScreen.midX, y: statusScreen.midY), coloring: .recolor(labels.statusColor)))
        }
        var companion: CGRect?
        if let avatarButtonNode = self.avatarButtonNode, avatarButtonNode.isNodeLoaded {
            companion = avatarButtonNode.view.convert(avatarButtonNode.view.bounds, to: screenView)
        }
        return NavigationExpansionSourceLoan(origin: origin, originTint: .init(kind: .panel), isDark: self.isDark, companion: companion, companionPhotoDiameter: 38.0, companionView: self.avatarView, labels: expansionLabels, press: .none)
    }

    func returnExpansionSource() {
        self.titleView?.reclaimExpansionLabels()
        self.barView?.updateExpansionContentStaysInScreen(false)
    }
}
