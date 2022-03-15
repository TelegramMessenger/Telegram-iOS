import Foundation
import UIKit
import Display
import AsyncDisplayKit
import TelegramPresentationData
import SearchBarNode
import AppBundle

private let searchBarFont = Font.regular(17.0)

private extension SearchBarNodeTheme {
    convenience init(navigationBarTheme: BrowserNavigationBarTheme) {
        self.init(background: navigationBarTheme.backgroundColor, separator: .clear, inputFill: navigationBarTheme.searchBarFieldColor, primaryText: navigationBarTheme.searchBarTextColor, placeholder: navigationBarTheme.searchBarPlaceholderColor, inputIcon: navigationBarTheme.searchBarIconColor, inputClear: navigationBarTheme.searchBarClearColor, accent: navigationBarTheme.buttonColor, keyboard: navigationBarTheme.searchBarKeyboardColor)
    }
}

final class BrowserNavigationBarSearchContentNode: ASDisplayNode, BrowserNavigationBarContentNode {
    private var theme: BrowserNavigationBarTheme
    private let strings: PresentationStrings
    private var state: BrowserState
    private var interaction: BrowserInteraction?
    
    private let searchBar: SearchBarNode
    
    init(theme: BrowserNavigationBarTheme, strings: PresentationStrings, state: BrowserState, interaction: BrowserInteraction?) {
        self.theme = theme
        self.strings = strings
        self.state = state
        self.interaction = interaction
        
        let searchBarTheme = SearchBarNodeTheme(navigationBarTheme: self.theme)
        self.searchBar = SearchBarNode(theme: searchBarTheme, strings: strings, fieldStyle: .modern)
        self.searchBar.placeholderString = NSAttributedString(string: "Search on this page", font: searchBarFont, textColor: searchBarTheme.placeholder)
        
        super.init()
        
        self.backgroundColor = theme.backgroundColor
        
        self.addSubnode(self.searchBar)
        
        self.searchBar.cancel = { [weak self] in
            self?.searchBar.deactivate(clear: false)
            self?.interaction?.dismissSearch()
        }
        
        self.searchBar.textUpdated = { [weak self] query, _ in
            self?.interaction?.updateSearchQuery(query)
        }
    }
    
    override func didLoad() {
        super.didLoad()
        
        self.searchBar.activate()
    }
    
    func updateState(_ state: BrowserState) {
        guard let searchState = state.search else {
            return
        }
        
        self.searchBar.text = searchState.query
    }
    
    func updateTheme(_ theme: BrowserNavigationBarTheme) {
        guard self.theme !== theme else {
            return
        }
        self.theme = theme
        
        self.backgroundColor = theme.backgroundColor
        self.searchBar.updateThemeAndStrings(theme: SearchBarNodeTheme(navigationBarTheme: self.theme), strings: self.strings)
    }
    
    func updateLayout(size: CGSize, transition: ContainedViewLayoutTransition) {
        self.searchBar.updateLayout(boundingSize: size, leftInset: 0.0, rightInset: 0.0, transition: .immediate)
        self.searchBar.frame = CGRect(origin: CGPoint(), size: size)
    }
}
