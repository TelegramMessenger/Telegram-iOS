import Foundation
import UIKit
import AsyncDisplayKit

open class ASImageNode: ASDisplayNode {
    public var image: UIImage? {
        didSet {
            if self.isNodeLoaded {
                if let image = self.image {
                    let capInsets = image.capInsets
                    if capInsets.left.isZero && capInsets.top.isZero {
                        ASDisplayNodeSetResizableContents(self, image)
                    } else {
                        self.contents = self.image?.cgImage
                    }
                } else {
                    self.contents = nil
                }
            }
        }
    }

    public var displayWithoutProcessing: Bool = true

    override public init() {
        super.init()
    }
}
