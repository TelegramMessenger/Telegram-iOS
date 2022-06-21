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
    
    var cancel: (() -> Void)?
    
    init(theme: PresentationTheme, strings: PresentationStrings, attachment: Bool) {
        self.theme = theme
        self.strings = strings
        
        self.searchBar = SearchBarNode(theme: SearchBarNodeTheme(theme: theme, hasSeparator: false), strings: strings, fieldStyle: .modern, displayBackground: !attachment)
        self.searchBar.hasCancelButton = attachment
        self.searchBar.placeholderString = NSAttributedString(string: attachment ? strings.Attachment_SearchWeb : strings.Common_Search, font: searchBarFont, textColor: theme.rootController.navigationSearchBar.inputPlaceholderTextColor)
        
        super.init()
        
        self.addSubnode(self.searchBar)
        
        self.searchBar.textUpdated = { [weak self] query, _ in
            self?.queryUpdated?(query)
        }
        self.searchBar.cancel = { [weak self] in
            self?.cancel?()
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
