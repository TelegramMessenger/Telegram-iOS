import Foundation
import UIKit
import AsyncDisplayKit
import Display
import ComponentFlow
import AccountContext
import TelegramPresentationData
import GlassBackgroundComponent
import HorizontalTabsComponent

/// The For you | Added tabs: the same glass `HorizontalTabsComponent` the Peer Info media tabs use
/// (`PeerInfoPaneContainerNode`), on a `GlassBackgroundView` inside a `GlassBackgroundContainerView`,
/// in its `.fill` layout so the capsule spans the width between the insets and each tab gets half.
/// `ChatListNavigationBar`'s tabs slot takes an `ASDisplayNode` and gives it a full-width, 46 pt frame.
final class NewsSegmentNode: ASDisplayNode {
    static let height: CGFloat = 46.0
    private static let tabsHeight: CGFloat = 40.0

    private let backgroundContainer = GlassBackgroundContainerView()
    private let backgroundView = GlassBackgroundView()
    private let tabs = ComponentView<Empty>()

    override init() {
        super.init()
        self.backgroundContainer.contentView.addSubview(self.backgroundView)
        self.view.addSubview(self.backgroundContainer)
    }

    /// `action` also fires for the already selected tab; the screen scrolls that list to the top.
    /// `tabSwitchFraction` is a swipe between the lists in progress, as a signed fraction of the width (negative
    /// towards the next tab): the selection follows it, as Peer Info's does.
    func update(context: AccountContext, width: CGFloat, leftInset: CGFloat, rightInset: CGFloat, theme: PresentationTheme, strings: PresentationStrings, selectedIndex: Int, tabSwitchFraction: CGFloat, isSwitchingByDragging: Bool, liftWhileSwitching: Bool, action: @escaping (Int) -> Void, transition: ComponentTransition) {
        let titles = [strings.News_Segment_ForYou, strings.News_Segment_Added]
        let tabsSize = self.tabs.update(
            transition: transition,
            component: AnyComponent(HorizontalTabsComponent(
                context: context,
                theme: theme,
                tabs: titles.enumerated().map { index, title -> HorizontalTabsComponent.Tab in
                    return HorizontalTabsComponent.Tab(
                        id: AnyHashable(index),
                        content: .title(HorizontalTabsComponent.Tab.Title(text: title, entities: [], enableAnimations: false)),
                        badge: nil,
                        action: {
                            action(index)
                        }
                    )
                },
                selectedTab: AnyHashable(selectedIndex),
                isEditing: false,
                layout: .fill,
                liftWhileSwitching: liftWhileSwitching
            )),
            environment: {},
            containerSize: CGSize(width: max(1.0, width - leftInset - rightInset), height: NewsSegmentNode.tabsHeight)
        )

        let frame = CGRect(origin: CGPoint(x: leftInset, y: floor((NewsSegmentNode.height - tabsSize.height) * 0.5)), size: tabsSize)
        transition.setFrame(view: self.backgroundContainer, frame: frame)
        self.backgroundContainer.update(size: frame.size, isDark: theme.overallDarkAppearance, transition: transition)
        transition.setFrame(view: self.backgroundView, frame: CGRect(origin: CGPoint(), size: frame.size))
        self.backgroundView.update(size: frame.size, cornerRadius: frame.height * 0.5, isDark: theme.overallDarkAppearance, tintColor: .init(kind: .panel), transition: transition)

        if let tabsView = self.tabs.view as? HorizontalTabsComponent.View {
            if tabsView.superview == nil {
                self.backgroundView.contentView.addSubview(tabsView)
                // The selected pill lifts out of the capsule while switching; give it room above the glass.
                tabsView.setOverlayContainerView(overlayContainerView: self.view)
            }
            transition.setFrame(view: tabsView, frame: CGRect(origin: CGPoint(), size: frame.size))
        }
        self.updateTabSwitchFraction(tabSwitchFraction, isDragging: isSwitchingByDragging, transition: transition)
    }

    /// Mid-swipe, without laying the tabs out again.
    func updateTabSwitchFraction(_ fraction: CGFloat, isDragging: Bool, transition: ComponentTransition) {
        if let tabsView = self.tabs.view as? HorizontalTabsComponent.View {
            tabsView.updateTabSwitchFraction(fraction: fraction, isDragging: isDragging, transition: transition)
        }
    }
}
