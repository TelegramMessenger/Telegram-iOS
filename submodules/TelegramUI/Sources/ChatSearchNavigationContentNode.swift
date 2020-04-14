import Foundation
import UIKit
import AsyncDisplayKit
import Display
import Postbox
import TelegramCore
import SyncCore
import TelegramPresentationData
import SearchBarNode
import LocalizedPeerData
import SwiftSignalKit

private let searchBarFont = Font.regular(17.0)

final class ChatSearchNavigationContentNode: NavigationBarContentNode {
    private let theme: PresentationTheme
    private let strings: PresentationStrings
    private let chatLocation: ChatLocation
    
    private let searchBar: SearchBarNode
    private let interaction: ChatPanelInterfaceInteraction
    
    private var searchingActivityDisposable: Disposable?
    
    init(theme: PresentationTheme, strings: PresentationStrings, chatLocation: ChatLocation, interaction: ChatPanelInterfaceInteraction) {
        self.theme = theme
        self.strings = strings
        self.chatLocation = chatLocation
        self.interaction = interaction
        
        self.searchBar = SearchBarNode(theme: SearchBarNodeTheme(theme: theme, hasSeparator: false), strings: strings, fieldStyle: .modern)
        let placeholderText: String
        switch chatLocation {
            case .peer:
                placeholderText = strings.Conversation_SearchPlaceholder
            /*case .group:
                placeholderText = "Search this feed"*/
        }
        self.searchBar.placeholderString = NSAttributedString(string: placeholderText, font: searchBarFont, textColor: theme.rootController.navigationSearchBar.inputPlaceholderTextColor)
        
        super.init()
        
        self.addSubnode(self.searchBar)
        
        self.searchBar.cancel = { [weak self] in
            self?.searchBar.deactivate(clear: false)
            self?.interaction.dismissMessageSearch()
        }
        
        self.searchBar.textUpdated = { [weak self] query, _ in
            self?.interaction.updateMessageSearch(query)
        }
        
        self.searchBar.clearPrefix = { [weak self] in
            self?.interaction.toggleMembersSearch(false)
        }
        
        if let statuses = interaction.statuses {
            self.searchingActivityDisposable = (statuses.searching
            |> deliverOnMainQueue).start(next: { [weak self] value in
                self?.searchBar.activity = value
            })
        }
    }

    deinit {
        self.searchingActivityDisposable?.dispose()
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
    
    func update(presentationInterfaceState: ChatPresentationInterfaceState) {
        if let search = presentationInterfaceState.search {
            self.searchBar.updateThemeAndStrings(theme: SearchBarNodeTheme(theme: presentationInterfaceState.theme, hasSeparator: false), strings: presentationInterfaceState.strings)
            
            switch search.domain {
                case .everything:
                    self.searchBar.prefixString = nil
                    let placeholderText: String
                    switch self.chatLocation {
                        case .peer:
                            placeholderText = self.strings.Conversation_SearchPlaceholder
                        /*case .group:
                            placeholderText = "Search this feed"*/
                    }
                    self.searchBar.placeholderString = NSAttributedString(string: placeholderText, font: searchBarFont, textColor: theme.rootController.navigationSearchBar.inputPlaceholderTextColor)
                case .members:
                    self.searchBar.prefixString = NSAttributedString(string: strings.Conversation_SearchByName_Prefix, font: searchBarFont, textColor: theme.rootController.navigationSearchBar.inputTextColor)
                    self.searchBar.placeholderString = nil
                case let .member(peer):
                    let prefixString = NSMutableAttributedString()
                    prefixString.append(NSAttributedString(string: self.strings.Conversation_SearchByName_Prefix, font: searchBarFont, textColor: theme.rootController.navigationSearchBar.inputTextColor))
                    prefixString.append(NSAttributedString(string: "\(peer.compactDisplayTitle) ", font: searchBarFont, textColor: theme.rootController.navigationSearchBar.accentColor))
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
