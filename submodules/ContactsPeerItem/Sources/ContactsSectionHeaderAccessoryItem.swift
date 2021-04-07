import Foundation
import UIKit
import AsyncDisplayKit
import Display
import TelegramPresentationData
import ListSectionHeaderNode

public enum ContactsSectionHeader: Equatable {
    case letter(String)
    case title(String)
}

public final class ContactsSectionHeaderAccessoryItem: ListViewAccessoryItem {
    private let sectionHeader: ContactsSectionHeader
    private let theme: PresentationTheme
    
    public init(sectionHeader: ContactsSectionHeader, theme: PresentationTheme) {
        self.sectionHeader = sectionHeader
        self.theme = theme
    }
    
    public func isEqualToItem(_ other: ListViewAccessoryItem) -> Bool {
        if let other = other as? ContactsSectionHeaderAccessoryItem, self.sectionHeader == other.sectionHeader, self.theme === other.theme {
            return true
        } else {
            return false
        }
    }
    
    public func node(synchronous: Bool) -> ListViewAccessoryItemNode {
        return ContactsSectionHeaderAccessoryItemNode(sectionHeader: self.sectionHeader, theme: self.theme)
    }
}

public final class ContactsSectionHeaderAccessoryItemNode: ListViewAccessoryItemNode {
    private let sectionHeader: ContactsSectionHeader
    private let sectionHeaderNode: ListSectionHeaderNode
    private var theme: PresentationTheme
    
    public init(sectionHeader: ContactsSectionHeader, theme: PresentationTheme) {
        self.sectionHeader = sectionHeader
        self.theme = theme
        self.sectionHeaderNode = ListSectionHeaderNode(theme: theme)
        
        super.init()
        
        switch sectionHeader {
            case let .letter(letter):
                self.sectionHeaderNode.title = letter
            case let .title(title):
                self.sectionHeaderNode.title = title
        }
        
        self.addSubnode(self.sectionHeaderNode)
    }
    
    public func updateTheme(theme: PresentationTheme) {
        self.theme = theme
        self.sectionHeaderNode.updateTheme(theme: theme)
    }
    
    override public func updateLayout(size: CGSize, leftInset: CGFloat, rightInset: CGFloat) {
        self.sectionHeaderNode.frame = CGRect(origin: CGPoint(), size: size)
        self.sectionHeaderNode.updateLayout(size: size, leftInset: leftInset, rightInset: rightInset)
    }
}
