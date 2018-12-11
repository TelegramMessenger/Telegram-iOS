import Foundation
import AsyncDisplayKit
import Display
import Postbox
import TelegramCore

private let searchBarFont = Font.regular(14.0)

final class ChatSearchNavigationContentNode: NavigationBarContentNode {
    private let theme: PresentationTheme
    private let strings: PresentationStrings
    private let chatLocation: ChatLocation
    
    private let searchBar: SearchBarNode
    private let interaction: ChatPanelInterfaceInteraction
    
    init(theme: PresentationTheme, strings: PresentationStrings, chatLocation: ChatLocation, interaction: ChatPanelInterfaceInteraction) {
        self.theme = theme
        self.strings = strings
        self.chatLocation = chatLocation
        self.interaction = interaction
        
        self.searchBar = SearchBarNode(theme: SearchBarNodeTheme(theme: theme), strings: strings)
        let placeholderText: String
        switch chatLocation {
            case .peer:
                placeholderText = strings.Conversation_SearchPlaceholder
            case .group:
                placeholderText = "Search this feed"
        }
        self.searchBar.placeholderString = NSAttributedString(string: placeholderText, font: searchBarFont, textColor: theme.rootController.activeNavigationSearchBar.inputPlaceholderTextColor)
        
        super.init()
        
        self.addSubnode(self.searchBar)
        
        self.searchBar.cancel = { [weak self] in
            self?.searchBar.deactivate(clear: false)
            self?.interaction.dismissMessageSearch()
        }
        
        self.searchBar.textUpdated = { [weak self] query in
            self?.interaction.updateMessageSearch(query)
        }
        
        self.searchBar.clearPrefix = { [weak self] in
            self?.interaction.toggleMembersSearch(false)
        }
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
    
    func update(presentationInterfaceState: ChatPresentationInterfaceState) {
        if let search = presentationInterfaceState.search {
            self.searchBar.updateThemeAndStrings(theme: SearchBarNodeTheme(theme: presentationInterfaceState.theme), strings: presentationInterfaceState.strings)
            
            switch search.domain {
                case .everything:
                    self.searchBar.prefixString = nil
                    let placeholderText: String
                    switch self.chatLocation {
                        case .peer:
                            placeholderText = self.strings.Conversation_SearchPlaceholder
                        case .group:
                            placeholderText = "Search this feed"
                    }
                    self.searchBar.placeholderString = NSAttributedString(string: placeholderText, font: searchBarFont, textColor: theme.rootController.activeNavigationSearchBar.inputPlaceholderTextColor)
                case .members:
                    self.searchBar.prefixString = NSAttributedString(string: strings.Conversation_SearchByName_Prefix, font: searchBarFont, textColor: theme.rootController.activeNavigationSearchBar.inputTextColor)
                    self.searchBar.placeholderString = nil
                case let .member(peer):
                    let prefixString = NSMutableAttributedString()
                    prefixString.append(NSAttributedString(string: self.strings.Conversation_SearchByName_Prefix, font: searchBarFont, textColor: theme.rootController.activeNavigationSearchBar.inputTextColor))
                    prefixString.append(NSAttributedString(string: "\(peer.compactDisplayTitle) ", font: searchBarFont, textColor: theme.rootController.activeNavigationSearchBar.accentColor))
                    self.searchBar.prefixString = prefixString
                    self.searchBar.placeholderString = nil
            }
            
            if self.searchBar.text != search.query {
                self.searchBar.text = search.query
                self.interaction.updateMessageSearch(search.query)
            }
        }
    }
}
