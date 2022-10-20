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

private let normalFont = avatarPlaceholderFont(size: 16.0)
private let smallFont = avatarPlaceholderFont(size: 12.0)

private let maxVideoLoopCount = 3

final class ChatAvatarNavigationNode: ASDisplayNode {
    private var context: AccountContext?
    
    private let containerNode: ContextControllerSourceNode
    let avatarNode: AvatarNode
    private var videoNode: UniversalVideoNode?
    
    private var videoContent: NativeVideoContent?
    private let playbackStartDisposable = MetaDisposable()
    private var cachedDataDisposable = MetaDisposable()
    private var hierarchyTrackingLayer: HierarchyTrackingLayer?
    private var videoLoopCount = 0
    
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
    var contextActionIsEnabled: Bool = true {
        didSet {
            if self.contextActionIsEnabled != oldValue {
                self.containerNode.isGestureEnabled = self.contextActionIsEnabled
            }
        }
    }
        
    override init() {
        self.containerNode = ContextControllerSourceNode()
        self.avatarNode = AvatarNode(font: normalFont)
        
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
        self.playbackStartDisposable.dispose()
    }
    
    override func didLoad() {
        super.didLoad()
        self.view.isOpaque = false
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
                let cachedPeerData = peerView.cachedData
                if let cachedPeerData = cachedPeerData as? CachedUserData {
                    if let photo = cachedPeerData.photo, let video = smallestVideoRepresentation(photo.videoRepresentations), let peerReference = PeerReference(peer._asPeer()) {
                        let videoId = photo.id?.id ?? peer.id.id._internalGetInt64Value()
                        let videoFileReference = FileMediaReference.avatarList(peer: peerReference, media: TelegramMediaFile(fileId: MediaId(namespace: Namespaces.Media.LocalFile, id: 0), partialReference: nil, resource: video.resource, previewRepresentations: photo.representations, videoThumbnails: [], immediateThumbnailData: photo.immediateThumbnailData, mimeType: "video/mp4", size: nil, attributes: [.Animated, .Video(duration: 0, size: video.dimensions, flags: [])]))
                        let videoContent = NativeVideoContent(id: .profileVideo(videoId, "header"), fileReference: videoFileReference, streamVideo: isMediaStreamable(resource: video.resource) ? .conservative : .none, loopVideo: true, enableSound: false, fetchAutomatically: true, onlyFullSizeThumbnail: false, useLargeThumbnail: true, autoFetchFullSizeThumbnail: true, startTimestamp: video.startTimestamp, continuePlayingWithoutSoundOnLostAudioSession: false, placeholderColor: .clear, captureProtected: false)
                        if videoContent.id != strongSelf.videoContent?.id {
                            strongSelf.videoNode?.removeFromSupernode()
                            strongSelf.videoContent = videoContent
                        }
                        
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
                        strongSelf.videoContent = nil
                        
                        strongSelf.hierarchyTrackingLayer?.removeFromSuperlayer()
                        strongSelf.hierarchyTrackingLayer = nil
                    }
                                            
                    strongSelf.updateVideoVisibility()
                } else {
                    let _ = context.engine.peers.fetchAndUpdateCachedPeerData(peerId: peer.id).start()
                }
            }))
        } else {
            self.cachedDataDisposable.set(nil)
            self.videoContent = nil
            
            self.videoNode?.removeFromSupernode()
            self.videoNode = nil
            
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
        guard let context = self.context else {
            return
        }
        
        let isVisible = self.trackingIsInHierarchy
        if isVisible, let videoContent = self.videoContent, self.videoLoopCount != maxVideoLoopCount {
            if self.videoNode == nil {
                let mediaManager = context.sharedContext.mediaManager
                let videoNode = UniversalVideoNode(postbox: context.account.postbox, audioSession: mediaManager.audioSession, manager: mediaManager.universalVideoManager, decoration: GalleryVideoDecoration(), content: videoContent, priority: .minimal)
                videoNode.clipsToBounds = true
                videoNode.isUserInteractionEnabled = false
                videoNode.isHidden = true
                videoNode.playbackCompleted = { [weak self] in
                    if let strongSelf = self {
                        strongSelf.videoLoopCount += 1
                        if strongSelf.videoLoopCount == maxVideoLoopCount {
                            if let videoNode = strongSelf.videoNode {
                                strongSelf.videoNode = nil
                                videoNode.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.2, removeOnCompletion: false, completion: { [weak videoNode] _ in
                                    videoNode?.removeFromSupernode()
                                })
                            }
                        }
                    }
                }
                
                if let _ = videoContent.startTimestamp {
                    self.playbackStartDisposable.set((videoNode.status
                    |> map { status -> Bool in
                        if let status = status, case .playing = status.status {
                            return true
                        } else {
                            return false
                        }
                    }
                    |> filter { playing in
                        return playing
                    }
                    |> take(1)
                    |> deliverOnMainQueue).start(completed: { [weak self] in
                        if let strongSelf = self {
                            Queue.mainQueue().after(0.15) {
                                strongSelf.videoNode?.isHidden = false
                            }
                        }
                    }))
                } else {
                    self.playbackStartDisposable.set(nil)
                    videoNode.isHidden = false
                }
                videoNode.layer.cornerRadius = self.avatarNode.frame.size.width / 2.0
                if #available(iOS 13.0, *) {
                    videoNode.layer.cornerCurve = .circular
                }
                
                videoNode.canAttachContent = true
                videoNode.play()
                
                self.containerNode.insertSubnode(videoNode, aboveSubnode: self.avatarNode)
                self.videoNode = videoNode
            }
        } else if let videoNode = self.videoNode {
            self.videoNode = nil
            videoNode.removeFromSupernode()
        }
        
        if let videoNode = self.videoNode {
            videoNode.updateLayout(size: self.avatarNode.frame.size, transition: .immediate)
            videoNode.frame = self.avatarNode.frame
        }
    }
}
