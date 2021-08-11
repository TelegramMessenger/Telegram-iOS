import Foundation
import UIKit
import AsyncDisplayKit
import Display
import Postbox
import TelegramCore
import TelegramPresentationData
import ItemListUI
import PresentationDataUtils
import SearchBarNode

private let searchBarFont = Font.regular(17.0)

final class GroupInfoSearchNavigationContentNode: NavigationBarContentNode, ItemListControllerSearchNavigationContentNode {
    private var theme: PresentationTheme
    private let strings: PresentationStrings
    private let searchMode: ChannelMembersSearchMode
    
    private let cancel: () -> Void
    
    private let searchBar: SearchBarNode
    
    private var queryUpdated: ((String) -> Void)?
    var activity: Bool = false {
        didSet {
            searchBar.activity = activity
        }
    }
    init(theme: PresentationTheme, strings: PresentationStrings, mode: ChannelMembersSearchMode, cancel: @escaping () -> Void, updateActivity: @escaping(@escaping(Bool)->Void) -> Void) {
        self.theme = theme
        self.strings = strings
        self.searchMode = mode
        
        self.cancel = cancel
        
        self.searchBar = SearchBarNode(theme: SearchBarNodeTheme(theme: theme, hasSeparator: false), strings: strings, fieldStyle: .modern, displayBackground: false)
        
        super.init()
        
        self.addSubnode(self.searchBar)
        
        self.searchBar.cancel = { [weak self] in
            self?.searchBar.deactivate(clear: false)
            self?.cancel()
        }
        
        self.searchBar.textUpdated = { [weak self] query, _ in
            self?.queryUpdated?(query)
        }
        
        updateActivity({ [weak self] value in
            self?.activity = value
        })
        
        self.updatePlaceholder()
    }
    
    func setQueryUpdated(_ f: @escaping (String) -> Void) {
        self.queryUpdated = f
    }
    
    func updateTheme(_ theme: PresentationTheme) {
        self.theme = theme
        self.searchBar.updateThemeAndStrings(theme: SearchBarNodeTheme(theme: self.theme), strings: self.strings)
        self.updatePlaceholder()
    }
    
    func updatePlaceholder() {
        let placeholderText: String
        switch self.searchMode {
            case .searchBanned:
                placeholderText = self.strings.GroupInfo_Permissions_SearchPlaceholder
            default:
                placeholderText = self.strings.Conversation_SearchByName_Placeholder
        }
        self.searchBar.placeholderString = NSAttributedString(string: placeholderText, font: searchBarFont, textColor: self.theme.rootController.navigationSearchBar.inputPlaceholderTextColor)
    }
    
    override var nominalHeight: CGFloat {
        return 54.0
    }
    
    override func updateLayout(size: CGSize, leftInset: CGFloat, rightInset: CGFloat, transition: ContainedViewLayoutTransition) {
        let searchBarFrame = CGRect(origin: CGPoint(x: 0.0, y: size.height - self.nominalHeight), size: CGSize(width: size.width, height: 54.0))
        self.searchBar.frame = searchBarFrame
        self.searchBar.updateLayout(boundingSize: searchBarFrame.size, leftInset: leftInset, rightInset: rightInset, transition: transition)
    }
    
    func activate() {
        self.searchBar.activate()
    }
    
    func deactivate() {
        self.searchBar.deactivate(clear: false)
    }
}

