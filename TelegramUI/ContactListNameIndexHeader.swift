import Display

final class ContactListNameIndexHeader: Equatable, ListViewItemHeader {
    let id: Int64
    let letter: unichar
    let stickDirection: ListViewItemHeaderStickDirection = .top
    
    let height: CGFloat = 29.0
    
    init(letter: unichar) {
        self.letter = letter
        self.id = Int64(letter)
    }
    
    func node() -> ListViewItemHeaderNode {
        return ContactListNameIndexHeaderNode(letter: self.letter)
    }
    
    static func ==(lhs: ContactListNameIndexHeader, rhs: ContactListNameIndexHeader) -> Bool {
        return lhs.id == rhs.id
    }
}

final class ContactListNameIndexHeaderNode: ListViewItemHeaderNode {
    private let letter: unichar
    
    private let sectionHeaderNode: ListSectionHeaderNode
    
    init(letter: unichar) {
        self.letter = letter
        
        self.sectionHeaderNode = ListSectionHeaderNode()
        
        super.init()
        
        if let scalar = UnicodeScalar(letter) {
            self.sectionHeaderNode.title = "\(Character(scalar))"
        }
        
        self.addSubnode(self.sectionHeaderNode)
    }
    
    override func layout() {
        self.sectionHeaderNode.frame = CGRect(origin: CGPoint(), size: self.bounds.size)
    }
}
