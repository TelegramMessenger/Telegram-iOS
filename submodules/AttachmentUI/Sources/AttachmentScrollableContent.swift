import Foundation
import UIKit

public protocol AttachmentScrollableContent: AnyObject {
    var attachmentContentOffset: CGFloat { get }
    var attachmentBlocksContainerPan: Bool { get }
    func attachmentSetContentBounces(_ bounces: Bool)
    func attachmentScrollContentToTop()
    func attachmentSetContentHeldAtTop(_ held: Bool)
    func attachmentEndContentHold()
}
