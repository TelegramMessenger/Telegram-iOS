import Foundation
import AsyncDisplayKit
import Display

private let searchBarFont = Font.regular(15.0)

final class ChatSearchNavigationContentNode: NavigationBarContentNode {
    private let searchBar: SearchBarNode
    private let interaction: ChatPanelInterfaceInteraction
    
    init(theme: PresentationTheme, strings: PresentationStrings, interaction: ChatPanelInterfaceInteraction) {
        self.interaction = interaction
        
        self.searchBar = SearchBarNode(theme: theme, strings: strings)
        self.searchBar.placeholderString = NSAttributedString(string: strings.Conversation_SearchPlaceholder, font: searchBarFont, textColor: theme.rootController.activeNavigationSearchBar.inputPlaceholderTextColor)
        
        super.init()
        
        self.addSubnode(self.searchBar)
        
        self.searchBar.cancel = { [weak self] in
            self?.searchBar.deactivate(clear: false)
            self?.interaction.dismissMessageSearch()
        }
        
        self.searchBar.textUpdated = { [weak self] query in
            self?.interaction.updateMessageSearch(query)
        }
    }
    
    override func layout() {
        super.layout()
        
        let size = self.bounds.size
        
        let searchBarFrame = CGRect(origin: CGPoint(x: 0.0, y: size.height - 64.0), size: CGSize(width: size.width, height: 64.0))
        self.searchBar.frame = searchBarFrame
    }
    
    func activate() {
        self.searchBar.activate()
    }
    
    func deactivate() {
        self.searchBar.deactivate(clear: false)
    }
}
