import Foundation
import UIKit
import AsyncDisplayKit
import Display
import Postbox
import TelegramCore
import TelegramPresentationData
import SearchBarNode
import ComponentFlow
import ComponentDisplayAdapters
import HorizontalTabsComponent
import GlassBackgroundComponent

private let searchBarFont = Font.regular(17.0)

final class HashtagSearchNavigationContentNode: NavigationBarContentNode {
    private var theme: PresentationTheme
    private let strings: PresentationStrings
    private let hasCurrentChat: Bool
    private let hasTabs: Bool
    
    private let cancel: () -> Void
    
    var onReturn: (String) -> Void = { _ in }
    
    private let searchBar: SearchBarNode
    
    private let tabsBackgroundContainer: GlassBackgroundContainerView
    private let tabsBackgroundView: GlassBackgroundView
    private let tabSelector = ComponentView<Empty>()
    
    private var queryUpdated: ((String) -> Void)?
    var indexUpdated: ((Int) -> Void)?
    
    var selectedIndex: Int = 0 {
        didSet {
            if let (size, leftInset, rightInset) = self.validLayout {
                let _ = self.updateLayout(size: size, leftInset: leftInset, rightInset: rightInset, transition: .animated(duration: 0.35, curve: .spring))
            }
        }
    }
    
    var transitionFraction: CGFloat? {
        didSet {
            if self.transitionFraction != oldValue {
                if let (size, leftInset, rightInset) = self.validLayout {
                    let _ = self.updateLayout(size: size, leftInset: leftInset, rightInset: rightInset, transition: self.transitionFraction == nil ? .animated(duration: 0.35, curve: .spring) : .immediate)
                }
            }
        }
    }
    
    var isSearching: Bool = false {
        didSet {
            self.searchBar.activity = self.isSearching
        }
    }
    
    var query: String {
        get {
            return self.searchBar.text
        }
        set {
            self.searchBar.text = newValue
        }
    }
        
    init(theme: PresentationTheme, strings: PresentationStrings, initialQuery: String, hasCurrentChat: Bool, hasTabs: Bool, cancel: @escaping () -> Void) {
        self.theme = theme
        self.strings = strings
        self.hasCurrentChat = hasCurrentChat
        self.hasTabs = hasTabs
        
        self.cancel = cancel

        let icon: SearchBarNode.Icon
        if initialQuery.hasPrefix("$") {
            icon = .cashtag
        } else {
            icon = .hashtag
        }
        
        var initialQuery = initialQuery
        initialQuery.removeFirst()
        
        self.searchBar = SearchBarNode(theme: SearchBarNodeTheme(theme: theme, hasSeparator: false), presentationTheme: theme, strings: strings, fieldStyle: .glass, icon: icon, displayBackground: false)
        self.searchBar.text = initialQuery
        self.searchBar.placeholderString = NSAttributedString(string: strings.HashtagSearch_SearchPlaceholder, font: searchBarFont, textColor: theme.rootController.navigationSearchBar.inputPlaceholderTextColor)
        
        self.tabsBackgroundContainer = GlassBackgroundContainerView()
        self.tabsBackgroundView = GlassBackgroundView()
        
        super.init()
        
        self.tabsBackgroundContainer.contentView.addSubview(self.tabsBackgroundView)
        self.view.addSubview(self.tabsBackgroundContainer)
        
        self.searchBar.autocapitalization = .none
        
        if hasCurrentChat {
            self.addSubnode(self.searchBar)
        }
        
        self.searchBar.cancel = { [weak self] in
            self?.searchBar.deactivate(clear: false)
            self?.cancel()
        }
        
        self.searchBar.textUpdated = { [weak self] query, _ in
            self?.queryUpdated?(query)
        }
        
        self.searchBar.textReturned = { [weak self] query in
            self?.onReturn(query)
        }
    }
    
    override var mode: NavigationBarContentMode {
        return self.hasCurrentChat ? .replacement : .expansion
    }
    
    func updateTheme(_ theme: PresentationTheme) {
        self.theme = theme
        self.searchBar.updateThemeAndStrings(theme: SearchBarNodeTheme(theme: theme, hasSeparator: false), presentationTheme: theme, strings: self.strings)
    }
    
    func setQueryUpdated(_ f: @escaping (String) -> Void) {
        self.queryUpdated = f
    }
    
    override var nominalHeight: CGFloat {
        if self.hasCurrentChat {
            return 64.0 + 44.0
        } else {
            return 45.0
        }
    }
    
    private var validLayout: (CGSize, CGFloat, CGFloat)?
    
    override func updateLayout(size: CGSize, leftInset: CGFloat, rightInset: CGFloat, transition: ContainedViewLayoutTransition) -> CGSize {
        self.validLayout = (size, leftInset, rightInset)
        
        let sideInset: CGFloat = 6.0
        
        let searchBarFrame = CGRect(origin: CGPoint(x: 0.0, y: 6.0), size: CGSize(width: size.width, height: 44.0))
        self.searchBar.frame = searchBarFrame
        self.searchBar.updateLayout(boundingSize: searchBarFrame.size, leftInset: leftInset + sideInset, rightInset: rightInset + sideInset, transition: transition)
        
        if self.hasTabs {
            var items: [HorizontalTabsComponent.Tab] = []
            if self.hasCurrentChat {
                items.append(HorizontalTabsComponent.Tab(
                    id: AnyHashable(0),
                    content: .title(HorizontalTabsComponent.Tab.Title(text: self.strings.HashtagSearch_ThisChat, entities: [], enableAnimations: false)),
                    badge: nil,
                    action: { [weak self] in
                        guard let self else {
                            return
                        }
                        self.indexUpdated?(0)
                    },
                    contextAction: nil,
                    deleteAction: nil
                ))
            }
            
            items.append(HorizontalTabsComponent.Tab(
                id: AnyHashable(1),
                content: .title(HorizontalTabsComponent.Tab.Title(text: self.strings.HashtagSearch_MyMessages, entities: [], enableAnimations: false)),
                badge: nil,
                action: { [weak self] in
                    guard let self else {
                        return
                    }
                    self.indexUpdated?(1)
                },
                contextAction: nil,
                deleteAction: nil
            ))
            
            items.append(HorizontalTabsComponent.Tab(
                id: AnyHashable(2),
                content: .title(HorizontalTabsComponent.Tab.Title(text: self.strings.HashtagSearch_PublicPosts, entities: [], enableAnimations: false)),
                badge: nil,
                action: { [weak self] in
                    guard let self else {
                        return
                    }
                    self.indexUpdated?(2)
                },
                contextAction: nil,
                deleteAction: nil
            ))
            
            let tabSelectorSize = self.tabSelector.update(
                transition: ComponentTransition(transition),
                component: AnyComponent(HorizontalTabsComponent(
                    context: nil,
                    theme: self.theme,
                    tabs: items,
                    selectedTab: AnyHashable(self.selectedIndex),
                    isEditing: false
                )),
                environment: {},
                containerSize: CGSize(width: size.width - (leftInset + 16.0) * 2.0, height: 44.0)
            )
            let tabSelectorFrameOriginX = floorToScreenPixels((size.width - tabSelectorSize.width) / 2.0)
            let tabSelectorFrame = CGRect(origin: CGPoint(x: tabSelectorFrameOriginX, y: searchBarFrame.maxY + 10.0), size: tabSelectorSize)
            
            transition.updateFrame(view: self.tabsBackgroundContainer, frame: tabSelectorFrame)
            self.tabsBackgroundContainer.update(size: tabSelectorFrame.size, isDark: self.theme.overallDarkAppearance, transition: ComponentTransition(transition))
            
            transition.updateFrame(view: self.tabsBackgroundView, frame: CGRect(origin: CGPoint(), size: tabSelectorFrame.size))
            self.tabsBackgroundView.update(size: tabSelectorFrame.size, cornerRadius: tabSelectorFrame.height * 0.5, isDark: self.theme.overallDarkAppearance, tintColor: .init(kind: .panel), transition: ComponentTransition(transition))
            
            if let tabSelectorView = self.tabSelector.view as? HorizontalTabsComponent.View {
                if tabSelectorView.superview == nil {
                    self.tabsBackgroundView.contentView.addSubview(tabSelectorView)
                    tabSelectorView.setOverlayContainerView(overlayContainerView: self.view)
                }
                transition.updateFrame(view: tabSelectorView, frame: CGRect(origin: CGPoint(), size: tabSelectorFrame.size))
                
                var transitionFraction: CGFloat = 0.0
                if let transitionFractionValue = self.transitionFraction {
                    transitionFraction = -transitionFractionValue
                }
                tabSelectorView.updateTabSwitchFraction(fraction: transitionFraction, isDragging: false, transition: ComponentTransition(transition))
            }
        }
        
        return size
    }
    
    func activate() {
        self.searchBar.activate()
    }
    
    func deactivate() {
        self.searchBar.deactivate(clear: false)
    }
}
