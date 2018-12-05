import Foundation
import AsyncDisplayKit
import Display
import Postbox
import TelegramCore

private let searchBarFont = Font.regular(14.0)

final class WebSearchNavigationContentNode: NavigationBarContentNode {
    private let theme: PresentationTheme
    private let strings: PresentationStrings
    
    private let cancel: () -> Void
    
    private let searchBar: SearchBarNode
    
    private var queryUpdated: ((String) -> Void)?
    
    init(theme: PresentationTheme, strings: PresentationStrings, cancel: @escaping () -> Void) {
        self.theme = theme
        self.strings = strings
        
        self.cancel = cancel
        
        self.searchBar = SearchBarNode(theme: SearchBarNodeTheme(theme: theme, active: false), strings: strings)
        let placeholderText = strings.Common_Search
        self.searchBar.placeholderString = NSAttributedString(string: placeholderText, font: searchBarFont, textColor: theme.rootController.activeNavigationSearchBar.inputPlaceholderTextColor)
        
        super.init()
        
        self.addSubnode(self.searchBar)
        
        self.searchBar.cancel = { [weak self] in
            self?.searchBar.deactivate(clear: false)
            self?.cancel()
        }
        
        self.searchBar.textUpdated = { [weak self] query in
            self?.queryUpdated?(query)
        }
    }
    
    func setQueryUpdated(_ f: @escaping (String) -> Void) {
        self.queryUpdated = f
    }
    
    override func layout() {
        super.layout()
        
        let size = self.bounds.size
        
        let searchBarFrame = CGRect(origin: CGPoint(), size: size)
        self.searchBar.frame = searchBarFrame
        self.searchBar.updateLayout(boundingSize: size, leftInset: 0.0, rightInset: 0.0, transition: .immediate)
    }
    
    func activate() {
        self.searchBar.activate()
    }
    
    func deactivate() {
        self.searchBar.deactivate(clear: false)
    }
}
