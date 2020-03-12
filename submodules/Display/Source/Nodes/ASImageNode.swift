import Foundation
import UIKit
import AsyncDisplayKit

open class ASImageNode: ASDisplayNode {
    public var image: UIImage? {
        didSet {
            if let image = self.image {
                let capInsets = image.capInsets
                if capInsets.left.isZero && capInsets.top.isZero {
                    self.contentsScale = image.scale
                    self.contents = image.cgImage
                } else {
                    ASDisplayNodeSetResizableContents(self, image)
                }
            } else {
                self.contents = nil
            }
            if self.image?.size != oldValue?.size {
                self.invalidateCalculatedLayout()
            }
        }
    }

    public var displayWithoutProcessing: Bool = true

    override public init() {
        super.init()
    }
    
    override public func calculateSizeThatFits(_ contrainedSize: CGSize) -> CGSize {
        return self.image?.size ?? CGSize()
    }
}
