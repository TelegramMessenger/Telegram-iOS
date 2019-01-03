import Foundation
import AsyncDisplayKit
import Display
import Postbox
import TelegramCore

private let searchBarFont = Font.regular(14.0)

final class WebSearchNavigationContentNode: NavigationBarContentNode {
    private let theme: PresentationTheme
    private let strings: PresentationStrings
    
    private let searchBar: SearchBarNode
    
    private var queryUpdated: ((String) -> Void)?
    
    init(theme: PresentationTheme, strings: PresentationStrings) {
        self.theme = theme
        self.strings = strings
        
        self.searchBar = SearchBarNode(theme: SearchBarNodeTheme(theme: theme, active: false), strings: strings)
        self.searchBar.hasCancelButton = false
        self.searchBar.placeholderString = NSAttributedString(string: strings.Common_Search, font: searchBarFont, textColor: theme.rootController.activeNavigationSearchBar.inputPlaceholderTextColor)
        
        super.init()
        
        self.addSubnode(self.searchBar)
        
        self.searchBar.textReturned = { [weak self] query in
            self?.queryUpdated?(query)
        }
        self.searchBar.textUpdated = { [weak self] query in
            if query.isEmpty {
                self?.queryUpdated?(query)
            }
        }
    }
    
    func setQueryUpdated(_ f: @escaping (String) -> Void) {
        self.queryUpdated = f
    }
    
    func setActivity(_ activity: Bool) {
        self.searchBar.activity = activity
    }
    
    func setQuery(_ query: String) {
        self.searchBar.text = query
    }
    
    override func layout() {
        super.layout()
        
        let size = self.bounds.size
        
        let searchBarFrame = CGRect(origin: CGPoint(), size: size)
        self.searchBar.frame = searchBarFrame
        self.searchBar.updateLayout(boundingSize: size, leftInset: 0.0, rightInset: 0.0, transition: .immediate)
    }
    
    func activate(select: Bool = false) {
        self.searchBar.activate()
        self.searchBar.selectAll()
    }
    
    func deactivate() {
        self.searchBar.deactivate(clear: false)
    }
}
