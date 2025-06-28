import SwiftSignalKit
import Postbox
import TelegramCore
import AsyncDisplayKit
import UIKit
import Display
import TelegramPresentationData

public enum PeerInfoPaneKey: Int32 {
    case botPreview
    case members
    case stories
    case storyArchive
    case gifts
    case media
    case savedMessagesChats
    case savedMessages
    case files
    case music
    case voice
    case links
    case gifs
    case groupsInCommon
    case similarChannels
    case similarBots
}

public struct PeerInfoStatusData: Equatable {
    public var text: String
    public var isActivity: Bool
    public var isHiddenStatus: Bool
    public var key: PeerInfoPaneKey?
    
    public init(
        text: String,
        isActivity: Bool,
        isHiddenStatus: Bool = false,
        key: PeerInfoPaneKey?
    ) {
        self.text = text
        self.isActivity = isActivity
        self.isHiddenStatus = isHiddenStatus
        self.key = key
    }
}

public protocol PeerInfoPanelNodeNavigationContentNode: ASDisplayNode {
    func update(width: CGFloat, defaultHeight: CGFloat, insets: UIEdgeInsets, transition: ContainedViewLayoutTransition) -> CGFloat
}

public protocol PeerInfoPaneNode: ASDisplayNode {
    var isReady: Signal<Bool, NoError> { get }
    
    var parentController: ViewController? { get set }

    var status: Signal<PeerInfoStatusData?, NoError> { get }
    var tabBarOffsetUpdated: ((ContainedViewLayoutTransition) -> Void)? { get set }
    var tabBarOffset: CGFloat { get }
    
    var navigationContentNode: PeerInfoPanelNodeNavigationContentNode? { get }
    var externalDataUpdated: ((ContainedViewLayoutTransition) -> Void)? { get set }
    
    func update(size: CGSize, topInset: CGFloat, sideInset: CGFloat, bottomInset: CGFloat, deviceMetrics: DeviceMetrics, visibleHeight: CGFloat, isScrollingLockedAtTop: Bool, expandProgress: CGFloat, navigationHeight: CGFloat, presentationData: PresentationData, synchronous: Bool, transition: ContainedViewLayoutTransition)
    func scrollToTop() -> Bool
    func transferVelocity(_ velocity: CGFloat)
    func cancelPreviewGestures()
    func findLoadedMessage(id: MessageId) -> Message?
    func transitionNodeForGallery(messageId: MessageId, media: Media) -> (ASDisplayNode, CGRect, () -> (UIView?, UIView?))?
    func addToTransitionSurface(view: UIView)
    func updateHiddenMedia()
    func updateSelectedMessages(animated: Bool)
    func ensureMessageIsVisible(id: MessageId)
}

public extension PeerInfoPaneNode {
    var navigationContentNode: PeerInfoPanelNodeNavigationContentNode? {
        return nil
    }
    var externalDataUpdated: ((ContainedViewLayoutTransition) -> Void)? {
        get {
            return nil
        } set(value) {
        }
    }
}
