import Foundation
import UIKit
import AsyncDisplayKit
import Display
import ComponentFlow
import AccountContext
import TelegramPresentationData
import GlassBackgroundComponent
import LottieSettings
import HorizontalTabsComponent
import NewsFeedSupport

/// The For you | Added tabs: the same glass `HorizontalTabsComponent` the Peer Info media tabs use
/// (`PeerInfoPaneContainerNode`), on a `GlassBackgroundView` inside a `GlassBackgroundContainerView`, in its `.fill`
/// layout so each tab gets half. The header sizes and places it as the mockup's island (Feed2 FeedScreen.swift:216-249).
final class NewsSegmentNode: ASDisplayNode {
    private let backgroundContainer = GlassBackgroundContainerView(spacing: NewsRefreshMetrics.pullSpacing)
    private let backgroundView = GlassBackgroundView()
    /// The pull-to-refresh drop: in the same glass container as the island, so they merge on iOS 26.
    let refreshDrop = NewsRefreshDrop()
    /// Room below the island for the drop, so the container never clips it (spec §8.1).
    static let dropRoom: CGFloat = 240.0
    private let tabs = ComponentView<Empty>()
    /// Measures the tabs' natural width in the `.fit` layout; never shown.
    private let measuringTabs = ComponentView<Empty>()
    private var fittingWidthCache: (theme: PresentationTheme, strings: PresentationStrings, width: CGFloat)?

    override init() {
        super.init()
        // Behind the island's glass: below iOS 26 the drop slides out from under it.
        self.backgroundContainer.contentView.addSubview(self.refreshDrop.glassView)
        self.backgroundContainer.contentView.addSubview(self.backgroundView)
        self.view.addSubview(self.backgroundContainer)
    }

    private func tabsComponent(context: AccountContext, theme: PresentationTheme, strings: PresentationStrings, selectedIndex: Int, layout: HorizontalTabsComponent.Layout, liftWhileSwitching: Bool, action: @escaping (Int) -> Void) -> HorizontalTabsComponent {
        let titles = [strings.News_Segment_ForYou, strings.News_Segment_Added]
        return HorizontalTabsComponent(
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
            layout: layout,
            liftWhileSwitching: liftWhileSwitching
        )
    }

    /// The tabs' natural width (titles and the capsule's padding); the island is at least 228 and grows to this.
    func fittingWidth(context: AccountContext, theme: PresentationTheme, strings: PresentationStrings) -> CGFloat {
        if let cache = self.fittingWidthCache, cache.theme === theme, cache.strings === strings {
            return cache.width
        }
        let size = self.measuringTabs.update(
            transition: .immediate,
            component: AnyComponent(self.tabsComponent(context: context, theme: theme, strings: strings, selectedIndex: 0, layout: .fit, liftWhileSwitching: false, action: { _ in })),
            environment: {},
            containerSize: CGSize(width: 1000.0, height: NewsHeaderMetrics.islandHeight)
        )
        self.fittingWidthCache = (theme, strings, size.width)
        return size.width
    }

    /// `action` also fires for the already selected tab; the screen scrolls that list to the top.
    /// `tabSwitchFraction` is a swipe between the lists in progress, as a signed fraction of the width (negative
    /// towards the next tab): the selection follows it, as Peer Info's does.
    func update(context: AccountContext, size: CGSize, theme: PresentationTheme, strings: PresentationStrings, selectedIndex: Int, tabSwitchFraction: CGFloat, isSwitchingByDragging: Bool, liftWhileSwitching: Bool, action: @escaping (Int) -> Void, transition: ComponentTransition) {
        let tabsSize = self.tabs.update(
            transition: transition,
            component: AnyComponent(self.tabsComponent(context: context, theme: theme, strings: strings, selectedIndex: selectedIndex, layout: .fill, liftWhileSwitching: liftWhileSwitching, action: action)),
            environment: {},
            containerSize: size
        )

        let frame = CGRect(origin: CGPoint(), size: tabsSize)
        let containerFrame = CGRect(origin: CGPoint(), size: CGSize(width: frame.width, height: frame.height + NewsSegmentNode.dropRoom))
        transition.setFrame(view: self.backgroundContainer, frame: containerFrame)
        self.backgroundContainer.update(size: containerFrame.size, isDark: theme.overallDarkAppearance, transition: transition)
        transition.setFrame(view: self.backgroundView, frame: CGRect(origin: CGPoint(), size: frame.size))
        self.backgroundView.update(size: frame.size, cornerRadius: frame.height * 0.5, isDark: theme.overallDarkAppearance, tintColor: .init(kind: .panel), transition: transition)

        if let tabsView = self.tabs.view as? HorizontalTabsComponent.View {
            if tabsView.superview == nil {
                self.backgroundView.contentView.addSubview(tabsView)
                // The selected pill lifts out of the capsule while switching; give it room above the glass.
                tabsView.setOverlayContainerView(overlayContainerView: self.view)
            }
            // Not while a transition has them (`lendTabs`): it places them.
            if tabsView.superview === self.backgroundView.contentView {
                transition.setFrame(view: tabsView, frame: CGRect(origin: CGPoint(), size: frame.size))
            }
        }
        self.updateTabSwitchFraction(tabSwitchFraction, isDragging: isSwitchingByDragging, transition: transition)
    }

    /// The island's glass capsule, in this node's view: in a navigation transition it is the title pill that morphs with
    /// the other screen's (a chat's header).
    var islandFrame: CGRect {
        return self.backgroundView.frame
    }

    /// While a navigation transition draws the island, the island hides.
    var isIslandDetached: Bool = false {
        didSet {
            if self.isIslandDetached != oldValue {
                self.backgroundContainer.isHidden = self.isIslandDetached
            }
        }
    }

    /// Lends the island's tabs, live (their lens is a visual effect, which no copy of them shows, and a screen that is
    /// arriving has not been drawn to copy), to a navigation transition that draws the island while it is detached:
    /// they move into `container` at the island's size until `reclaimTabs()`.
    func lendTabs(to container: UIView) {
        guard let tabsView = self.tabs.view else {
            return
        }
        container.addSubview(tabsView)
        tabsView.frame = CGRect(origin: CGPoint(), size: self.backgroundView.bounds.size)
    }

    /// Takes the tabs back from a transition.
    func reclaimTabs() {
        guard let tabsView = self.tabs.view, tabsView.superview != nil, tabsView.superview !== self.backgroundView.contentView else {
            return
        }
        self.backgroundView.contentView.addSubview(tabsView)
        tabsView.frame = CGRect(origin: CGPoint(), size: self.backgroundView.bounds.size)
    }

    /// The refresh drop for `pose`, below the island (spec §2).
    func updateRefreshDrop(pose: NewsRefreshDropPose, theme: PresentationTheme, lottieSettings: LottieRenderingSettings) {
        self.refreshDrop.update(pose: pose, islandSize: self.bounds.size, theme: theme, lottieSettings: lottieSettings)
    }

    /// Mid-swipe, without laying the tabs out again.
    func updateTabSwitchFraction(_ fraction: CGFloat, isDragging: Bool, transition: ComponentTransition) {
        if let tabsView = self.tabs.view as? HorizontalTabsComponent.View {
            tabsView.updateTabSwitchFraction(fraction: fraction, isDragging: isDragging, transition: transition)
        }
    }
}
