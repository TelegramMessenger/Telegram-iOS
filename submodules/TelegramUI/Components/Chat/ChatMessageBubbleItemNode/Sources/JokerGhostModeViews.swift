import Foundation
import UIKit
import AsyncDisplayKit
import Display

public class JokerDeletedMessageMark: ASDisplayNode {
    private let iconNode: ASImageNode

    public override init() {
        self.iconNode = ASImageNode()
        self.iconNode.contentMode = .scaleAspectFit
        self.iconNode.displaysAsynchronously = false
        self.iconNode.isLayerBacked = true

        super.init()
        self.isOpaque = false
        self.isUserInteractionEnabled = false
        self.alpha = 0.0

        self.addSubnode(self.iconNode)
        if let image = UIImage(systemName: "xmark.circle.fill")?.withTintColor(UIColor(red: 0.86, green: 0.18, blue: 0.18, alpha: 0.95), renderingMode: .alwaysOriginal) {
            self.iconNode.image = image
        }
    }

    override public func layout() {
        super.layout()
        self.iconNode.frame = self.bounds
    }

    public func setDeletedMarkVisible(_ visible: Bool, frame: CGRect) {
        self.alpha = visible ? 1.0 : 0.0
        self.frame = frame
        if visible, self.bounds.size != frame.size {
            self.iconNode.frame = self.bounds
        }
    }
}
