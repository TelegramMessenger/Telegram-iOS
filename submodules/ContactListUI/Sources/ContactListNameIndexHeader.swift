import Foundation
import Display
import UIKit
import TelegramPresentationData
import ListSectionHeaderNode

final class ContactListNameIndexHeader: Equatable, ListViewItemHeader {
    let id: ListViewItemNode.HeaderId
    let theme: PresentationTheme
    let letter: unichar
    let stickDirection: ListViewItemHeaderStickDirection = .top
    public let stickOverInsets: Bool = true
    
    let height: CGFloat = 29.0
    
    init(theme: PresentationTheme, letter: unichar) {
        self.theme = theme
        self.letter = letter
        self.id = ListViewItemNode.HeaderId(space: 0, id: Int64(letter))
    }

    func combinesWith(other: ListViewItemHeader) -> Bool {
        if let other = other as? ContactListNameIndexHeader, self.id == other.id {
            return true
        } else {
            return false
        }
    }
    
    func node(synchronousLoad: Bool) -> ListViewItemHeaderNode {
        return ContactListNameIndexHeaderNode(theme: self.theme, letter: self.letter)
    }
    
    func updateNode(_ node: ListViewItemHeaderNode, previous: ListViewItemHeader?, next: ListViewItemHeader?) {
        
    }
    
    static func ==(lhs: ContactListNameIndexHeader, rhs: ContactListNameIndexHeader) -> Bool {
        return lhs.id == rhs.id
    }
}

final class ContactListNameIndexHeaderNode: ListViewItemHeaderNode {
    private var theme: PresentationTheme
    private let letter: unichar
    
    private let sectionHeaderNode: ListSectionHeaderNode
    
    init(theme: PresentationTheme, letter: unichar) {
        self.theme = theme
        self.letter = letter
        
        self.sectionHeaderNode = ListSectionHeaderNode(theme: theme)
        
        super.init()
        
        if let scalar = UnicodeScalar(letter) {
            self.sectionHeaderNode.title = "\(Character(scalar))"
        }
        
        self.addSubnode(self.sectionHeaderNode)
    }
    
    func updateTheme(theme: PresentationTheme) {
        self.theme = theme
        self.sectionHeaderNode.updateTheme(theme: theme)
    }
    
    override func updateLayout(size: CGSize, leftInset: CGFloat, rightInset: CGFloat) {
        self.sectionHeaderNode.frame = CGRect(origin: CGPoint(), size: size)
        self.sectionHeaderNode.updateLayout(size: size, leftInset: leftInset, rightInset: rightInset)
    }
}
