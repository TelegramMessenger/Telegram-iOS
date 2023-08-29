import Foundation
import UIKit
import Display
import TelegramCore
import TelegramPresentationData

public protocol ShareContentContainerNode: AnyObject {
    func activate()
    func deactivate()
    func setEnsurePeerVisibleOnLayout(_ peerId: EnginePeer.Id?)
    func setContentOffsetUpdated(_ f: ((CGFloat, ContainedViewLayoutTransition) -> Void)?)
    func updateLayout(size: CGSize, isLandscape: Bool, bottomInset: CGFloat, transition: ContainedViewLayoutTransition)
    func updateTheme(_ theme: PresentationTheme)
    func updateSelectedPeers(animated: Bool)
}
