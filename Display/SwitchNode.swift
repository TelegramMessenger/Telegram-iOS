import Foundation
import AsyncDisplayKit

open class SwitchNode: ASDisplayNode {
    override public init() {
        super.init(viewBlock: {
            return UISwitch()
        }, didLoad: nil)
    }
}
