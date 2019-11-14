import Foundation
import UIKit
import AsyncDisplayKit

private final class ASImageNodeView: UIImageView {
    
}

open class ASImageNode: ASDisplayNode {
    public var image: UIImage? {
        didSet {
            if self.isNodeLoaded {
                (self.view as? ASImageNodeView)?.image = self.image
            }
        }
    }

    override public init() {
        super.init()

        self.setViewBlock({
            return ASImageNodeView(frame: CGRect())
        })
    }

    override open func didLoad() {
        super.didLoad()

        (self.view as? ASImageNodeView)?.image = self.image
    }
}
