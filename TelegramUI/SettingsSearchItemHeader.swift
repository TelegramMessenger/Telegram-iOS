import Foundation
import Display

final class SettingsSearchItemHeader: ListViewItemHeader {
    let id: Int64
    let icon: UIImage

    let stickDirection: ListViewItemHeaderStickDirection = .top
    let height: CGFloat = 29.0
    
    init(id: Int64, icon: UIImage) {
        self.id = id
        self.icon = icon
    }
    
    func node() -> ListViewItemHeaderNode {
        return SettingsSearchItemHeaderNode(icon : self.icon)
    }
}

final class SettingsSearchItemHeaderNode: ListViewItemHeaderNode {
    private let iconNode: ASImageNode
    
    init(icon: UIImage) {
        self.iconNode = ASImageNode()
        
        super.init()
        
        self.iconNode.image = icon
        
        self.addSubnode(self.iconNode)
    }
    
    override func updateLayout(size: CGSize, leftInset: CGFloat, rightInset: CGFloat) {
        self.iconNode.frame = CGRect(origin: CGPoint(x: 0.0, y: 0.0), size: CGSize(width: 10.0, height: 10.0))
    }
    
    override func animateRemoved(duration: Double) {
        self.alpha = 0.0
        self.layer.animateAlpha(from: 1.0, to: 0.0, duration: duration, removeOnCompletion: false)
    }
}
