import AsyncDisplayKit
import Display
import TelegramPresentationData

final class PeerInfoScreenHeaderItem: PeerInfoScreenItem {
    let id: AnyHashable
    let text: String
    
    init(id: AnyHashable, text: String) {
        self.id = id
        self.text = text
    }
    
    func node() -> PeerInfoScreenItemNode {
        return PeerInfoScreenHeaderItemNode()
    }
}

private final class PeerInfoScreenHeaderItemNode: PeerInfoScreenItemNode {
    private let textNode: ImmediateTextNode
    
    private var item: PeerInfoScreenHeaderItem?
    
    override init() {
        self.textNode = ImmediateTextNode()
        self.textNode.displaysAsynchronously = false
        self.textNode.isUserInteractionEnabled = false
        
        super.init()
        
        self.addSubnode(self.textNode)
    }
    
    override func update(width: CGFloat, presentationData: PresentationData, item: PeerInfoScreenItem, topItem: PeerInfoScreenItem?, bottomItem: PeerInfoScreenItem?, transition: ContainedViewLayoutTransition) -> CGFloat {
        guard let item = item as? PeerInfoScreenHeaderItem else {
            return 10.0
        }
        
        self.item = item
        
        let sideInset: CGFloat = 16.0
        let verticalInset: CGFloat = 7.0
        
        self.textNode.maximumNumberOfLines = 0
        self.textNode.attributedText = NSAttributedString(string: item.text, font: Font.regular(13.0), textColor: presentationData.theme.list.freeTextColor)
        
        let textSize = self.textNode.updateLayout(CGSize(width: width - sideInset * 2.0, height: .greatestFiniteMagnitude))
        
        let textFrame = CGRect(origin: CGPoint(x: sideInset, y: verticalInset), size: textSize)
        
        let height = textSize.height + verticalInset * 2.0
        
        transition.updateFrame(node: self.textNode, frame: textFrame)
        
        return height
    }
}
