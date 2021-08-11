import Foundation
import UIKit
import AsyncDisplayKit
import Display
import Postbox
import TelegramCore
import TelegramPresentationData
import SearchBarNode

private let searchBarFont = Font.regular(17.0)

final class LocationSearchNavigationContentNode: NavigationBarContentNode {
    private var presentationData: PresentationData
    
    private let searchBar: SearchBarNode
    private let interaction: LocationPickerInteraction
    
    init(presentationData: PresentationData, interaction: LocationPickerInteraction) {
        self.presentationData = presentationData
        self.interaction = interaction
        
        self.searchBar = SearchBarNode(theme: SearchBarNodeTheme(theme: presentationData.theme, hasSeparator: false), strings: presentationData.strings, fieldStyle: .modern)
        self.searchBar.placeholderString = NSAttributedString(string: presentationData.strings.Map_Search, font: searchBarFont, textColor: presentationData.theme.rootController.navigationSearchBar.inputPlaceholderTextColor)
        
        super.init()
        
        self.addSubnode(self.searchBar)
        
        self.searchBar.cancel = { [weak self] in
            self?.searchBar.deactivate(clear: false)
            self?.interaction.dismissSearch()
        }
        self.searchBar.textUpdated = { [weak self] query, _ in
            self?.interaction.updateSearchQuery(query)
        }
    }
    
    override var nominalHeight: CGFloat {
        return 56.0
    }
    
    override func updateLayout(size: CGSize, leftInset: CGFloat, rightInset: CGFloat, transition: ContainedViewLayoutTransition) {
        let searchBarFrame = CGRect(origin: CGPoint(x: 0.0, y: size.height - self.nominalHeight), size: CGSize(width: size.width, height: 56.0))
        self.searchBar.frame = searchBarFrame
        self.searchBar.updateLayout(boundingSize: searchBarFrame.size, leftInset: leftInset, rightInset: rightInset, transition: transition)
    }
    
    func activate() {
        self.searchBar.activate()
    }
    
    func deactivate() {
        self.searchBar.deactivate(clear: false)
    }
    
    func updateActivity(_ activity: Bool) {
        self.searchBar.activity = activity
    }
    
    func updatePresentationData(_ presentationData: PresentationData) {
        self.presentationData = presentationData
        self.searchBar.updateThemeAndStrings(theme: SearchBarNodeTheme(theme: presentationData.theme, hasSeparator: false), strings: presentationData.strings)
    }
}
