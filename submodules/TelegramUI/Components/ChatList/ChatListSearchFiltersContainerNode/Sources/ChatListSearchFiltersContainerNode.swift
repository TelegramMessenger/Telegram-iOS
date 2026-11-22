import Foundation
import UIKit
import AsyncDisplayKit
import Display
import TelegramCore
import TelegramPresentationData
import AccountContext
import GlassBackgroundComponent
import ComponentFlow
import ComponentDisplayAdapters
import HorizontalTabsComponent
import BundleIconComponent

public enum ChatListSearchFilterEntryId: Hashable {
    case filter(Int64)
}

public enum ChatListSearchFilterEntry: Equatable {
    case filter(ChatListSearchFilter)
    
    public var id: ChatListSearchFilterEntryId {
        switch self {
        case let .filter(filter):
            return .filter(filter.id)
        }
    }
}

/// The search filter bar: the tabs of the chat list's folder bar (`HorizontalTabsComponent`) on a glass panel.
public final class ChatListSearchFiltersContainerNode: ASDisplayNode {
    private let backgroundContainer: GlassBackgroundContainerView
    private let backgroundView: GlassBackgroundView
    private let tabs = ComponentView<Empty>()
    
    public var filterPressed: ((ChatListSearchFilter) -> Void)?
    
    override public init() {
        self.backgroundContainer = GlassBackgroundContainerView()
        self.backgroundView = GlassBackgroundView()
        self.backgroundContainer.contentView.addSubview(self.backgroundView)
        
        super.init()
        
        self.view.addSubview(self.backgroundContainer)
    }
    
    public func update(size: CGSize, sideInset: CGFloat, filters: [ChatListSearchFilterEntry], displayGlobalPostsNewBadge: Bool, selectedFilter: ChatListSearchFilterEntryId?, transitionFraction: CGFloat, presentationData: PresentationData, transition proposedTransition: ContainedViewLayoutTransition) {
        // The bar appears laid out: the tabs would otherwise scale in from nothing and the glass grow from a point.
        let isFirstTime = self.tabs.view == nil
        let componentTransition: ComponentTransition = isFirstTime ? .immediate : ComponentTransition(proposedTransition)
        
        componentTransition.setFrame(view: self.backgroundContainer, frame: CGRect(origin: CGPoint(), size: size))
        self.backgroundContainer.update(size: size, isDark: presentationData.theme.overallDarkAppearance, transition: componentTransition)
        componentTransition.setFrame(view: self.backgroundView, frame: CGRect(origin: CGPoint(), size: size))
        self.backgroundView.update(size: size, cornerRadius: size.height * 0.5, isDark: presentationData.theme.overallDarkAppearance, tintColor: .init(kind: .panel), isInteractive: true, transition: componentTransition)
        
        let color = presentationData.theme.chat.inputPanel.panelControlColor
        
        let tabs = filters.map { entry -> HorizontalTabsComponent.Tab in
            let filter: ChatListSearchFilter
            switch entry {
            case let .filter(value):
                filter = value
            }
            
            let title: String
            var iconName: String?
            var badge: HorizontalTabsComponent.Tab.Badge?
            switch filter {
            case .chats, .topics:
                title = presentationData.strings.ChatList_Search_FilterChats
            case .channels:
                title = presentationData.strings.ChatList_Search_FilterChannels
            case .apps:
                title = presentationData.strings.ChatList_Search_FilterApps
            case .globalPosts:
                title = presentationData.strings.ChatList_Search_FilterGlobalPosts
                if displayGlobalPostsNewBadge {
                    badge = HorizontalTabsComponent.Tab.Badge(title: presentationData.strings.ChatList_ContextMenuBadgeNew, isAccent: true)
                }
            case .media:
                title = presentationData.strings.ChatList_Search_FilterMedia
            case .downloads:
                title = presentationData.strings.ChatList_Search_FilterDownloads
            case .links:
                title = presentationData.strings.ChatList_Search_FilterLinks
            case .files:
                title = presentationData.strings.ChatList_Search_FilterFiles
            case .music:
                title = presentationData.strings.ChatList_Search_FilterMusic
            case .voice, .instantVideo:
                title = presentationData.strings.ChatList_Search_FilterVoice
            case .publicPosts:
                title = presentationData.strings.ChatList_Search_FilterPublicPosts
            case let .peer(peerId, isGroup, displayTitle, _):
                title = displayTitle
                if isGroup {
                    iconName = "Chat List/Search/Group"
                } else if peerId.namespace == Namespaces.Peer.CloudChannel {
                    iconName = "Chat List/Search/Channel"
                } else {
                    iconName = "Chat List/Search/User"
                }
            case let .date(_, _, displayTitle):
                title = displayTitle
                iconName = "Chat List/Search/Calendar"
            }
            
            let content: HorizontalTabsComponent.Tab.Content
            if let iconName {
                content = .custom(AnyComponent(HStack<Empty>([
                    AnyComponentWithIdentity(id: 0, component: AnyComponent(BundleIconComponent(name: iconName, tintColor: color))),
                    AnyComponentWithIdentity(id: 1, component: AnyComponent(Text(text: title, font: Font.medium(15.0), color: color)))
                ], spacing: 6.0)))
            } else {
                content = .title(HorizontalTabsComponent.Tab.Title(text: title, entities: [], enableAnimations: false))
            }
            
            return HorizontalTabsComponent.Tab(
                id: AnyHashable(entry.id),
                content: content,
                badge: badge,
                action: { [weak self] in
                    self?.filterPressed?(filter)
                },
                // A suggested peer or date is drawn as icon + text (`.custom`): VoiceOver reads the text.
                accessibilityLabel: title
            )
        }
        
        // Suggested peers and dates replace the filters, and then no tab is selected.
        var selectedTab: HorizontalTabsComponent.Tab.Id?
        if let selectedFilter, filters.contains(where: { $0.id == selectedFilter }) {
            selectedTab = AnyHashable(selectedFilter)
        }
        
        let tabsSize = self.tabs.update(
            transition: componentTransition,
            component: AnyComponent(HorizontalTabsComponent(
                context: nil,
                theme: presentationData.theme,
                tabs: tabs,
                selectedTab: selectedTab,
                isEditing: false,
                layout: .fill
            )),
            environment: {},
            containerSize: CGSize(width: size.width - sideInset * 2.0, height: size.height)
        )
        if let tabsView = self.tabs.view as? HorizontalTabsComponent.View {
            if tabsView.superview == nil {
                self.backgroundView.contentView.addSubview(tabsView)
                tabsView.setOverlayContainerView(overlayContainerView: self.backgroundContainer.contentView)
            }
            componentTransition.setFrame(view: tabsView, frame: CGRect(origin: CGPoint(x: sideInset, y: 0.0), size: tabsSize))
            
            // Mid-swipe the pill follows the finger; it settles with the transition.
            let isDragging = transitionFraction != 0.0
            tabsView.updateTabSwitchFraction(fraction: transitionFraction, isDragging: isDragging, transition: isDragging ? .immediate : componentTransition)
        }
    }
}
