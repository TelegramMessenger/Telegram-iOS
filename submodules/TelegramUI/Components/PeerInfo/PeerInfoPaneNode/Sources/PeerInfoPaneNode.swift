import SwiftSignalKit
import Postbox
import TelegramCore
import AsyncDisplayKit
import Display
import TelegramPresentationData

public enum PeerInfoPaneKey: Int32 {
    case members
    case stories
    case media
    case files
    case music
    case voice
    case links
    case gifs
    case groupsInCommon
    case recommended
    case savedMessagesChats
}

public struct PeerInfoStatusData: Equatable {
    public var text: String
    public var isActivity: Bool
    public var key: PeerInfoPaneKey?
    
    public init(
        text: String,
        isActivity: Bool,
        key: PeerInfoPaneKey?
    ) {
        self.text = text
        self.isActivity = isActivity
        self.key = key
    }
}

public protocol PeerInfoPaneNode: ASDisplayNode {
    var isReady: Signal<Bool, NoError> { get }
    
    var parentController: ViewController? { get set }

    var status: Signal<PeerInfoStatusData?, NoError> { get }
    var tabBarOffsetUpdated: ((ContainedViewLayoutTransition) -> Void)? { get set }
    var tabBarOffset: CGFloat { get }
    
    func update(size: CGSize, topInset: CGFloat, sideInset: CGFloat, bottomInset: CGFloat, visibleHeight: CGFloat, isScrollingLockedAtTop: Bool, expandProgress: CGFloat, presentationData: PresentationData, synchronous: Bool, transition: ContainedViewLayoutTransition)
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
