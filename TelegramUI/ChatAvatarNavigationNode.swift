import Foundation
import AsyncDisplayKit
import Display

private let normalFont = UIFont(name: ".SFCompactRounded-Semibold", size: 16.0)!
private let smallFont = UIFont(name: ".SFCompactRounded-Semibold", size: 12.0)!

final class ChatAvatarNavigationNode: ASDisplayNode {
    let avatarNode: AvatarNode
    
    override init() {
        self.avatarNode = AvatarNode(font: normalFont)
        
        super.init()
        
        self.addSubnode(self.avatarNode)
    }
    
    override func calculateSizeThatFits(_ constrainedSize: CGSize) -> CGSize {
        if constrainedSize.height.isLessThanOrEqualTo(32.0) {
            return CGSize(width: 26.0, height: 26.0)
        } else {
            return CGSize(width: 37.0, height: 37.0)
        }
    }
    
    override func layout() {
        super.layout()
        
        let bounds = self.bounds
        if self.bounds.size.height.isLessThanOrEqualTo(26.0) {
            if !self.avatarNode.bounds.size.equalTo(bounds.size) {
                self.avatarNode.font = smallFont
            }
            self.avatarNode.frame = bounds.offsetBy(dx: 8.0, dy: 0.0)
        } else {
            if !self.avatarNode.bounds.size.equalTo(bounds.size) {
                self.avatarNode.font = normalFont
            }
            self.avatarNode.frame = bounds.offsetBy(dx: 10.0, dy: 1.0)
        }
    }
}
