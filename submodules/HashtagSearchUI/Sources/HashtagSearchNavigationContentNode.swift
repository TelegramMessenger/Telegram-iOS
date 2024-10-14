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
import TabSelectorComponent

private let searchBarFont = Font.regular(17.0)

final class HashtagSearchNavigationContentNode: NavigationBarContentNode {
    private var theme: PresentationTheme
    private let strings: PresentationStrings
    private let hasCurrentChat: Bool
    private let hasTabs: Bool
    
    private let cancel: () -> Void
    
    var onReturn: (String) -> Void = { _ in }
    
    private let searchBar: SearchBarNode
    private let tabSelector = ComponentView<Empty>()
    
    private var queryUpdated: ((String) -> Void)?
    var indexUpdated: ((Int) -> Void)?
    
    var selectedIndex: Int = 0 {
        didSet {
            if let (size, leftInset, rightInset) = self.validLayout {
                self.updateLayout(size: size, leftInset: leftInset, rightInset: rightInset, transition: .animated(duration: 0.35, curve: .spring))
            }
        }
    }
    
    var transitionFraction: CGFloat? {
        didSet {
            if self.transitionFraction != oldValue {
                if let (size, leftInset, rightInset) = self.validLayout {
                    self.updateLayout(size: size, leftInset: leftInset, rightInset: rightInset, transition: self.transitionFraction == nil ? .animated(duration: 0.35, curve: .spring) : .immediate)
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
        
        self.searchBar = SearchBarNode(theme: SearchBarNodeTheme(theme: theme, hasSeparator: false), strings: strings, fieldStyle: .modern, icon: icon, displayBackground: false)
        self.searchBar.text = initialQuery
        self.searchBar.placeholderString = NSAttributedString(string: strings.HashtagSearch_SearchPlaceholder, font: searchBarFont, textColor: theme.rootController.navigationSearchBar.inputPlaceholderTextColor)
        
        super.init()
        
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
        self.searchBar.updateThemeAndStrings(theme: SearchBarNodeTheme(theme: theme, hasSeparator: false), strings: self.strings)
    }
    
    func setQueryUpdated(_ f: @escaping (String) -> Void) {
        self.queryUpdated = f
    }
    
    override var nominalHeight: CGFloat {
        if self.hasCurrentChat {
            return 54.0 + 44.0
        } else {
            return 45.0
        }
    }
    
    private var validLayout: (CGSize, CGFloat, CGFloat)?
    
    override func updateLayout(size: CGSize, leftInset: CGFloat, rightInset: CGFloat, transition: ContainedViewLayoutTransition) {
        self.validLayout = (size, leftInset, rightInset)
        
        let sideInset: CGFloat = 6.0
        
        let searchBarFrame = CGRect(origin: CGPoint(x: 0.0, y: size.height - self.nominalHeight + 5.0), size: CGSize(width: size.width, height: 54.0))
        self.searchBar.frame = searchBarFrame
        self.searchBar.updateLayout(boundingSize: searchBarFrame.size, leftInset: leftInset + sideInset, rightInset: rightInset + sideInset, transition: transition)
        
        if self.hasTabs {
            var items: [TabSelectorComponent.Item] = []
            if self.hasCurrentChat {
                items.append(TabSelectorComponent.Item(id: AnyHashable(0), title: self.strings.HashtagSearch_ThisChat))
            }
            items.append(TabSelectorComponent.Item(id: AnyHashable(1), title: self.strings.HashtagSearch_MyMessages))
            items.append(TabSelectorComponent.Item(id: AnyHashable(2), title: self.strings.HashtagSearch_PublicPosts))
            
            let tabSelectorSize = self.tabSelector.update(
                transition: ComponentTransition(transition),
                component: AnyComponent(TabSelectorComponent(
                    colors: TabSelectorComponent.Colors(
                        foreground: self.theme.list.itemSecondaryTextColor,
                        selection: self.theme.list.itemAccentColor
                    ),
                    customLayout: TabSelectorComponent.CustomLayout(
                        font: Font.medium(14.0),
                        spacing: self.hasCurrentChat ? 24.0 : 8.0,
                        lineSelection: true
                    ),
                    items: items,
                    selectedId: AnyHashable(self.selectedIndex),
                    setSelectedId: { [weak self] id in
                        guard let self, let index = id.base as? Int else {
                            return
                        }
                        self.indexUpdated?(index)
                    },
                    transitionFraction: self.transitionFraction
                )),
                environment: {},
                containerSize: CGSize(width: size.width, height: 44.0)
            )
            let tabSelectorFrameOriginX = floorToScreenPixels((size.width - tabSelectorSize.width) / 2.0)
            let tabSelectorFrame = CGRect(origin: CGPoint(x: tabSelectorFrameOriginX, y: size.height - tabSelectorSize.height - 9.0), size: tabSelectorSize)
            if let tabSelectorView = self.tabSelector.view {
                if tabSelectorView.superview == nil {
                    self.view.addSubview(tabSelectorView)
                }
                transition.updateFrame(view: tabSelectorView, frame: tabSelectorFrame)
            }
        }
    }
    
    func activate() {
        self.searchBar.activate()
    }
    
    func deactivate() {
        self.searchBar.deactivate(clear: false)
    }
}
