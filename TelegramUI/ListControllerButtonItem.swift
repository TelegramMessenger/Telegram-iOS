import Foundation
import UIKit
import Display

private let titleFont = Font.regular(17.0)

class ListControllerButtonItem: ListControllerGroupableItem {
    fileprivate let title: String
    fileprivate let action: () -> ()
    fileprivate let color: UIColor
    
    let selectable: Bool = true
    
    init(title: String, action: @escaping () -> (), color: UIColor = .blue) {
        self.title = title
        self.action = action
        self.color = color
    }
    
    func setupNode(async: @escaping (@escaping () -> Void) -> Void, completion: @escaping (ListControllerGroupableItemNode) -> Void) {
        let node = ListControllerButtonItemNode()
        completion(node)
    }
    
    func selected() {
        self.action()
    }
}

class ListControllerButtonItemNode: ListControllerGroupableItemNode {
    let label: TextNode
    
    override init() {
        self.label = TextNode()
        
        super.init()
        
        self.label.isLayerBacked = true
        self.addSubnode(self.label)
    }
    
    override func asyncLayoutContent() -> (_ item: ListControllerGroupableItem, _ width: CGFloat) -> (CGSize, () -> Void) {
        let layoutLabel = TextNode.asyncLayout(self.label)
        return { item, width in
            if let item = item as? ListControllerButtonItem {
                let (labelLayout, labelApply) = layoutLabel(NSAttributedString(string: item.title, font: titleFont, textColor: item.color), nil, 1, .end, CGSize(width: width - 20, height: CGFloat.greatestFiniteMagnitude), nil)
                return (CGSize(width: width, height: 44.0), { [weak self] in
                    if let strongSelf = self {
                        let _ = labelApply()
                        
                        strongSelf.label.frame = CGRect(origin: CGPoint(x: 16.0, y: floorToScreenPixels((44.0 - labelLayout.size.height) / 2.0)), size: labelLayout.size)
                    }
                })
            } else {
                return (CGSize(width: width, height: 0.0), {
                })
            }
        }
    }
}
