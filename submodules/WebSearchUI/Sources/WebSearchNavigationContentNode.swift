import Foundation
import UIKit
import AsyncDisplayKit
import Display
import TelegramCore
import TelegramPresentationData
import SearchBarNode

private let searchBarFont = Font.regular(17.0)

final class WebSearchNavigationContentNode: NavigationBarContentNode {
    private let theme: PresentationTheme
    private let strings: PresentationStrings
    
    private let searchBar: SearchBarNode
    
    private var queryUpdated: ((String) -> Void)?
    
    init(theme: PresentationTheme, strings: PresentationStrings) {
        self.theme = theme
        self.strings = strings
        
        self.searchBar = SearchBarNode(theme: SearchBarNodeTheme(theme: theme, hasSeparator: false), strings: strings, fieldStyle: .modern)
        self.searchBar.hasCancelButton = false
        self.searchBar.placeholderString = NSAttributedString(string: strings.Common_Search, font: searchBarFont, textColor: theme.rootController.navigationSearchBar.inputPlaceholderTextColor)
        
        super.init()
        
        self.addSubnode(self.searchBar)
        
        self.searchBar.textReturned = { [weak self] query in
            self?.queryUpdated?(query)
        }
        self.searchBar.textUpdated = { [weak self] query, _ in
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
    
    override var nominalHeight: CGFloat {
        return 56.0
    }
    
    override func updateLayout(size: CGSize, leftInset: CGFloat, rightInset: CGFloat, transition: ContainedViewLayoutTransition) {
        let searchBarFrame = CGRect(origin: CGPoint(x: 0.0, y: size.height - self.nominalHeight), size: CGSize(width: size.width, height: 56.0))
        self.searchBar.frame = searchBarFrame
        self.searchBar.updateLayout(boundingSize: searchBarFrame.size, leftInset: leftInset, rightInset: rightInset, transition: transition)
    }
    
    func activate(select: Bool = false) {
        self.searchBar.activate()
        self.searchBar.selectAll()
    }
    
    func deactivate() {
        self.searchBar.deactivate(clear: false)
    }
}
