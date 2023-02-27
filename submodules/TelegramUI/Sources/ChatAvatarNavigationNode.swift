import Foundation
import UIKit
import AsyncDisplayKit
import Display
import SwiftSignalKit
import Postbox
import TelegramCore
import AvatarNode
import ContextUI
import TelegramPresentationData
import TelegramUniversalVideoContent
import UniversalMediaPlayer
import GalleryUI
import HierarchyTrackingLayer
import AccountContext
import ComponentFlow
import EmojiStatusComponent
import AvatarVideoNode

private let normalFont = avatarPlaceholderFont(size: 16.0)
private let smallFont = avatarPlaceholderFont(size: 12.0)

final class ChatAvatarNavigationNode: ASDisplayNode {
    private var context: AccountContext?
    
    private let containerNode: ContextControllerSourceNode
    let avatarNode: AvatarNode
    private var avatarVideoNode: AvatarVideoNode?
    
    let statusView: ComponentView<Empty>
    
    private var cachedDataDisposable = MetaDisposable()
    private var hierarchyTrackingLayer: HierarchyTrackingLayer?
    
    private var trackingIsInHierarchy: Bool = false {
        didSet {
            if self.trackingIsInHierarchy != oldValue {
                Queue.mainQueue().justDispatch {
                    self.updateVideoVisibility()
                }
            }
        }
    }
    
    var contextAction: ((ASDisplayNode, ContextGesture?) -> Void)?
    var contextActionIsEnabled: Bool = false {
        didSet {
            if self.contextActionIsEnabled != oldValue {
                self.containerNode.isGestureEnabled = self.contextActionIsEnabled
            }
        }
    }
        
    override init() {
        self.containerNode = ContextControllerSourceNode()
        self.containerNode.isGestureEnabled = false
        self.avatarNode = AvatarNode(font: normalFont)
        self.statusView = ComponentView()
        
        super.init()
        
        self.addSubnode(self.containerNode)
        self.containerNode.addSubnode(self.avatarNode)
        
        self.containerNode.activated = { [weak self] gesture, _ in
            guard let strongSelf = self else {
                return
            }
            strongSelf.contextAction?(strongSelf.containerNode, gesture)
        }
        
        self.containerNode.frame = CGRect(origin: CGPoint(), size: CGSize(width: 37.0, height: 37.0)).offsetBy(dx: 10.0, dy: 1.0)
        self.avatarNode.frame = self.containerNode.bounds
    }
    
    deinit {
        self.cachedDataDisposable.dispose()
    }
    
    override func didLoad() {
        super.didLoad()
        self.view.isOpaque = false
    }
    
    public func setStatus(context: AccountContext, content: EmojiStatusComponent.Content) {
        let statusSize = self.statusView.update(
            transition: .immediate,
            component: AnyComponent(EmojiStatusComponent(
                context: context,
                animationCache: context.animationCache,
                animationRenderer: context.animationRenderer,
                content: content,
                isVisibleForAnimations: true,
                action: nil
            )),
            environment: {},
            containerSize: CGSize(width: 32.0, height: 32.0)
        )
        if let statusComponentView = self.statusView.view {
            if statusComponentView.superview == nil {
                self.containerNode.view.addSubview(statusComponentView)
            }
            
            statusComponentView.frame = CGRect(origin: CGPoint(x: floor((self.containerNode.bounds.width - statusSize.width) / 2.0), y: floor((self.containerNode.bounds.height - statusSize.height) / 2.0)), size: statusSize)
        }
        
        self.avatarNode.isHidden = true
    }
    
    public func setPeer(context: AccountContext, theme: PresentationTheme, peer: EnginePeer?, authorOfMessage: MessageReference? = nil, overrideImage: AvatarNodeImageOverride? = nil, emptyColor: UIColor? = nil, clipStyle: AvatarNodeClipStyle = .round, synchronousLoad: Bool = false, displayDimensions: CGSize = CGSize(width: 60.0, height: 60.0), storeUnrounded: Bool = false) {
        self.context = context
        self.avatarNode.setPeer(context: context, theme: theme, peer: peer, authorOfMessage: authorOfMessage, overrideImage: overrideImage, emptyColor: emptyColor, clipStyle: clipStyle, synchronousLoad: synchronousLoad, displayDimensions: displayDimensions, storeUnrounded: storeUnrounded)
        
        if let peer = peer, peer.isPremium {
            self.cachedDataDisposable.set((context.account.postbox.peerView(id: peer.id)
            |> deliverOnMainQueue).start(next: { [weak self] peerView in
                guard let strongSelf = self else {
                    return
                }
                let cachedPeerData = peerView.cachedData as? CachedUserData
                var personalPhoto: TelegramMediaImage?
                var profilePhoto: TelegramMediaImage?
                var isKnown = false
                
                if let cachedPeerData = cachedPeerData {
                    if case let .known(maybePersonalPhoto) = cachedPeerData.personalPhoto {
                        personalPhoto = maybePersonalPhoto
                        isKnown = true
                    }
                    if case let .known(maybePhoto) = cachedPeerData.photo {
                        profilePhoto = maybePhoto
                        isKnown = true
                    }
                }
                
                if isKnown {
                    let photo = personalPhoto ?? profilePhoto
                    if let photo = photo, !photo.videoRepresentations.isEmpty || photo.emojiMarkup != nil {
                        let videoNode: AvatarVideoNode
                        if let current = strongSelf.avatarVideoNode {
                            videoNode = current
                        } else {
                            videoNode = AvatarVideoNode(context: context)
                            strongSelf.avatarNode.addSubnode(videoNode)
                            strongSelf.avatarVideoNode = videoNode
                        }
                        videoNode.update(peer: peer, photo: photo, size: CGSize(width: 37.0, height: 37.0))
                        
                        if strongSelf.hierarchyTrackingLayer == nil {
                            let hierarchyTrackingLayer = HierarchyTrackingLayer()
                            hierarchyTrackingLayer.didEnterHierarchy = { [weak self] in
                                guard let strongSelf = self else {
                                    return
                                }
                                strongSelf.trackingIsInHierarchy = true
                            }
                            
                            hierarchyTrackingLayer.didExitHierarchy = { [weak self] in
                                guard let strongSelf = self else {
                                    return
                                }
                                strongSelf.trackingIsInHierarchy = false
                            }
                            strongSelf.hierarchyTrackingLayer = hierarchyTrackingLayer
                            strongSelf.layer.addSublayer(hierarchyTrackingLayer)
                        }
                    } else {
                        if let avatarVideoNode = strongSelf.avatarVideoNode {
                            avatarVideoNode.removeFromSupernode()
                            strongSelf.avatarVideoNode = nil
                        }
                        strongSelf.hierarchyTrackingLayer?.removeFromSuperlayer()
                        strongSelf.hierarchyTrackingLayer = nil
                    }
                    strongSelf.updateVideoVisibility()
                } else {
                    if let photo = peer.largeProfileImage, photo.hasVideo {
                        let _ = context.engine.peers.fetchAndUpdateCachedPeerData(peerId: peer.id).start()
                    }
                }
            }))
        } else {
            self.cachedDataDisposable.set(nil)
            
            self.avatarVideoNode?.removeFromSupernode()
            self.avatarVideoNode = nil
            
            self.hierarchyTrackingLayer?.removeFromSuperlayer()
            self.hierarchyTrackingLayer = nil
        }
    }
    
    override func calculateSizeThatFits(_ constrainedSize: CGSize) -> CGSize {
        return CGSize(width: 37.0, height: 37.0)
    }
    
    func onLayout() {
    }

    final class SnapshotState {
        fileprivate let snapshotView: UIView?

        fileprivate init(snapshotView: UIView?) {
            self.snapshotView = snapshotView
        }
    }

    func prepareSnapshotState() -> SnapshotState {
        let snapshotView = self.avatarNode.view.snapshotView(afterScreenUpdates: false)
        return SnapshotState(
            snapshotView: snapshotView
        )
    }

    func animateFromSnapshot(_ snapshotState: SnapshotState) {
        self.avatarNode.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.3)
        self.avatarNode.layer.animateScale(from: 0.1, to: 1.0, duration: 0.5, timingFunction: kCAMediaTimingFunctionSpring, removeOnCompletion: true)

        if let snapshotView = snapshotState.snapshotView {
            snapshotView.frame = self.frame
            self.containerNode.view.addSubview(snapshotView)

            snapshotView.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.3, removeOnCompletion: false, completion: { [weak snapshotView] _ in
                snapshotView?.removeFromSuperview()
            })
            snapshotView.layer.animateScale(from: 1.0, to: 0.1, duration: 0.5, timingFunction: kCAMediaTimingFunctionSpring, removeOnCompletion: false)
        }
    }
    
    private func updateVideoVisibility() {
        let isVisible = self.trackingIsInHierarchy
        self.avatarVideoNode?.updateVisibility(isVisible)
      
        if let videoNode = self.avatarVideoNode {
            videoNode.updateLayout(size: self.avatarNode.frame.size, cornerRadius: self.avatarNode.frame.size.width / 2.0, transition: .immediate)
            videoNode.frame = self.avatarNode.bounds
        }
    }
}
