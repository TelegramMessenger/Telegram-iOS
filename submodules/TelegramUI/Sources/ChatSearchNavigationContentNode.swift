import Foundation
import UIKit
import AsyncDisplayKit
import Display
import Postbox
import TelegramCore
import TelegramPresentationData
import SearchBarNode
import LocalizedPeerData
import SwiftSignalKit
import AccountContext
import ChatPresentationInterfaceState

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
        
        self.searchBar = SearchBarNode(theme: SearchBarNodeTheme(theme: theme, hasBackground: false, hasSeparator: false), strings: strings, fieldStyle: .modern)
        let placeholderText: String
        switch chatLocation {
        case .peer, .replyThread, .feed:
            placeholderText = strings.Conversation_SearchPlaceholder
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
        
        self.searchBar.clearTokens = { [weak self] in
            self?.interaction.toggleMembersSearch(false)
        }
        
        self.searchBar.tokensUpdated = { [weak self] tokens in
            if tokens.isEmpty {
                self?.interaction.toggleMembersSearch(false)
            }
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
            self.searchBar.updateThemeAndStrings(theme: SearchBarNodeTheme(theme: presentationInterfaceState.theme, hasBackground: false, hasSeparator: false), strings: presentationInterfaceState.strings)
            
            switch search.domain {
                case .everything:
                    self.searchBar.tokens = []
                    self.searchBar.prefixString = nil
                    let placeholderText: String
                    switch self.chatLocation {
                    case .peer, .replyThread, .feed:
                        placeholderText = self.strings.Conversation_SearchPlaceholder
                    }
                    self.searchBar.placeholderString = NSAttributedString(string: placeholderText, font: searchBarFont, textColor: theme.rootController.navigationSearchBar.inputPlaceholderTextColor)
                case .members:
                    self.searchBar.tokens = []
                    self.searchBar.prefixString = NSAttributedString(string: strings.Conversation_SearchByName_Prefix, font: searchBarFont, textColor: theme.rootController.navigationSearchBar.inputTextColor)
                    self.searchBar.placeholderString = nil
                case let .member(peer):
                    self.searchBar.tokens = [SearchBarToken(id: peer.id, icon: UIImage(bundleImageName: "Chat List/Search/User"), title: EnginePeer(peer).compactDisplayTitle, permanent: false)]
                    self.searchBar.prefixString = nil
                    self.searchBar.placeholderString = nil
            }
            
            if self.searchBar.text != search.query {
                self.searchBar.text = search.query
                self.interaction.updateMessageSearch(search.query)
            }
        }
    }
}
