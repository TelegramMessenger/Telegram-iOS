import Foundation
import Display
import UIKit
import TelegramPresentationData
import ListSectionHeaderNode

final class ContactListNameIndexHeader: Equatable, ListViewItemHeader {
    let id: Int64
    let theme: PresentationTheme
    let letter: unichar
    let stickDirection: ListViewItemHeaderStickDirection = .top
    
    let height: CGFloat = 29.0
    
    init(theme: PresentationTheme, letter: unichar) {
        self.theme = theme
        self.letter = letter
        self.id = Int64(letter)
    }
    
    func node() -> ListViewItemHeaderNode {
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
