import Foundation
import UIKit
import Display
import AsyncDisplayKit

private let titleFont = Font.regular(17.0)

private func generateDisclosureIconImage(color: UIColor) -> UIImage? {
    return generateImage(CGSize(width: 8.0, height: 14.0), contextGenerator: { size, context -> Void in
        context.clear(CGRect(origin: CGPoint(), size: size))
        context.setFillColor(color.cgColor)
        let _ = try? drawSvgPath(context, path: "M6.36396103,7.4746212 L7.4246212,6.41396103 L1.06066017,0.0500000007 L0,1.11066017 L6.36396103,7.4746212 Z M1.06066017,12.9697384 L7.4246212,6.60577736 L6.36396103,5.54511719 L0,11.9090782 L1.06066017,12.9697384 L1.06066017,12.9697384 Z")
    })
}

private let disclosureIconImage = generateDisclosureIconImage(color: UIColor(0xc6c6ca))

class ListControllerDisclosureActionItem: ListControllerGroupableItem {
    fileprivate let title: String
    private let action: () -> ()
    
    let selectable: Bool = true

    init(title: String, action: @escaping () -> ()) {
        self.title = title
        self.action = action
    }
    
    func setupNode(async: @escaping (@escaping () -> Void) -> Void, completion: @escaping (ListControllerGroupableItemNode) -> Void) {
        let node = ListControllerDisclosureActionItemNode()
        completion(node)
    }
    
    func selected() {
        self.action()
    }
}

class ListControllerDisclosureActionItemNode: ListControllerGroupableItemNode {
    let label: TextNode
    let disclosureIcon: ASDisplayNode
    
    override init() {
        self.label = TextNode()
        self.label.isLayerBacked = true
        
        self.disclosureIcon = ASDisplayNode()
        if let disclosureIconImage = disclosureIconImage {
            self.disclosureIcon.frame = CGRect(origin: CGPoint(), size: disclosureIconImage.size)
            self.disclosureIcon.contents = disclosureIconImage.cgImage
        }
        self.disclosureIcon.isLayerBacked = true
        
        super.init()
        
        self.addSubnode(self.label)
        self.addSubnode(self.disclosureIcon)
    }
    
    override func asyncLayoutContent() -> (_ item: ListControllerGroupableItem, _ width: CGFloat) -> (CGSize, () -> Void) {
        let layoutLabel = TextNode.asyncLayout(self.label)
        return { item, width in
            if let item = item as? ListControllerDisclosureActionItem {
                let (labelLayout, labelApply) = layoutLabel(NSAttributedString(string: item.title, font: titleFont, textColor: UIColor.black), nil, 1, .end, CGSize(width: width - 20, height: CGFloat.greatestFiniteMagnitude), nil)
                return (CGSize(width: width, height: 44.0), { [weak self] in
                    if let strongSelf = self {
                        let _ = labelApply()
                        let disclosureSize = strongSelf.disclosureIcon.bounds.size
                        strongSelf.disclosureIcon.frame = CGRect(origin: CGPoint(x: width - 15.0 - disclosureSize.width, y: floorToScreenPixels((44.0 - disclosureSize.height) / 2.0)), size: disclosureSize)
                        
                        strongSelf.label.frame = CGRect(origin: CGPoint(x: 16.0, y: floorToScreenPixels((44.0 - labelLayout.size.height) / 2.0 + 0.5)), size: labelLayout.size)
                    }
                })
            } else {
                return (CGSize(width: width, height: 0.0), {
                })
            }
        }
    }
}
