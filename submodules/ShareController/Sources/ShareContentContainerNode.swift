import Foundation
import UIKit
import Display
import Postbox

public protocol ShareContentContainerNode: class {
    func activate()
    func deactivate()
    func setEnsurePeerVisibleOnLayout(_ peerId: PeerId?)
    func setContentOffsetUpdated(_ f: ((CGFloat, ContainedViewLayoutTransition) -> Void)?)
    func updateLayout(size: CGSize, bottomInset: CGFloat, transition: ContainedViewLayoutTransition)
    func updateSelectedPeers()
}
