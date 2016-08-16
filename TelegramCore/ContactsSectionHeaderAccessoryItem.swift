import Foundation
import AsyncDisplayKit
import Display

enum ContactsSectionHeader: Equatable {
    case letter(String)
    case title(String)
}

func ==(lhs: ContactsSectionHeader, rhs: ContactsSectionHeader) -> Bool {
    switch lhs {
        case let .letter(letter):
            if case .letter(letter) = rhs {
                return true
            } else {
                return false
            }
        case let .title(title):
            if case .title(title) = rhs {
                return true
            } else {
                return false
            }
    }
}

final class ContactsSectionHeaderAccessoryItem: ListViewAccessoryItem {
    private let sectionHeader: ContactsSectionHeader
    
    init(sectionHeader: ContactsSectionHeader) {
        self.sectionHeader = sectionHeader
    }
    
    func isEqualToItem(_ other: ListViewAccessoryItem) -> Bool {
        if let other = other as? ContactsSectionHeaderAccessoryItem, self.sectionHeader == other.sectionHeader {
            return true
        } else {
            return false
        }
    }
    
    func node() -> ListViewAccessoryItemNode {
        return ContactsSectionHeaderAccessoryItemNode(sectionHeader: self.sectionHeader)
    }
}

private final class ContactsSectionHeaderAccessoryItemNode: ListViewAccessoryItemNode {
    private let sectionHeader: ContactsSectionHeader
    private let sectionHeaderNode: ListSectionHeaderNode
    
    init(sectionHeader: ContactsSectionHeader) {
        self.sectionHeader = sectionHeader
        self.sectionHeaderNode = ListSectionHeaderNode()
        
        super.init()
        
        switch sectionHeader {
            case let .letter(letter):
                self.sectionHeaderNode.title = letter
            case let .title(title):
                self.sectionHeaderNode.title = title
        }
        
        self.addSubnode(self.sectionHeaderNode)
    }
    
    override func layout() {
        self.sectionHeaderNode.frame = CGRect(origin: CGPoint(), size: self.bounds.size)
    }
}
