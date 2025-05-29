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
import AvatarStoryIndicatorComponent
import ComponentDisplayAdapters

private let normalFont = avatarPlaceholderFont(size: 16.0)
private let smallFont = avatarPlaceholderFont(size: 12.0)

public final class ChatAvatarNavigationNode: ASDisplayNode {
    private var context: AccountContext?
    
    private let containerNode: ContextControllerSourceNode
    public let avatarNode: AvatarNode
    private var avatarVideoNode: AvatarVideoNode?
    
    public private(set) var avatarStoryView: ComponentView<Empty>?
    public var storyData: (hasUnseen: Bool, hasUnseenCloseFriends: Bool)?
    
    public let statusView: ComponentView<Empty>
    private var starView: StarView?
    
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
    
    public var contextAction: ((ASDisplayNode, ContextGesture?) -> Void)?
    public var contextActionIsEnabled: Bool = false {
        didSet {
            if self.contextActionIsEnabled != oldValue {
                self.containerNode.isGestureEnabled = self.contextActionIsEnabled
            }
        }
    }
        
    override public init() {
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
        
        #if DEBUG
        //self.hasUnseenStories = true
        #endif
    }
    
    deinit {
        self.cachedDataDisposable.dispose()
    }
    
    override public func didLoad() {
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
        
        if let peer, peer.isSubscription {
            let starView: StarView
            if let current = self.starView {
                starView = current
            } else {
                starView = StarView()
                self.starView = starView
                self.containerNode.view.addSubview(starView)
            }
            starView.outlineColor = theme.rootController.navigationBar.opaqueBackgroundColor
            
            let starSize = CGSize(width: 15.0, height: 15.0)
            let starFrame = CGRect(origin: CGPoint(x: self.containerNode.bounds.width - starSize.width + 1.0, y: self.containerNode.bounds.height - starSize.height + 1.0), size: starSize)
            starView.frame = starFrame
        } else if let starView = self.starView {
            self.starView = nil
            starView.removeFromSuperview()
        }
        
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
                            strongSelf.avatarNode.contentNode.addSubnode(videoNode)
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
    
    public func updateStoryView(transition: ContainedViewLayoutTransition, theme: PresentationTheme) {
        if let storyData = self.storyData {
            let avatarStoryView: ComponentView<Empty>
            if let current = self.avatarStoryView {
                avatarStoryView = current
            } else {
                avatarStoryView = ComponentView()
                self.avatarStoryView = avatarStoryView
            }
            
            let _ = avatarStoryView.update(
                transition: ComponentTransition(transition),
                component: AnyComponent(AvatarStoryIndicatorComponent(
                    hasUnseen: storyData.hasUnseen,
                    hasUnseenCloseFriendsItems: storyData.hasUnseenCloseFriends,
                    colors: AvatarStoryIndicatorComponent.Colors(theme: theme),
                    activeLineWidth: 1.0,
                    inactiveLineWidth: 1.0,
                    counters: nil
                )),
                environment: {},
                containerSize: self.avatarNode.bounds.insetBy(dx: 2.0, dy: 2.0).size
            )
            if let avatarStoryComponentView = avatarStoryView.view {
                if avatarStoryComponentView.superview == nil {
                    self.containerNode.view.insertSubview(avatarStoryComponentView, at: 0)
                }
                avatarStoryComponentView.frame = self.avatarNode.frame
            }
        } else {
            if let avatarStoryView = self.avatarStoryView {
                self.avatarStoryView = nil
                avatarStoryView.view?.removeFromSuperview()
            }
        }
    }
    
    override public func calculateSizeThatFits(_ constrainedSize: CGSize) -> CGSize {
        return CGSize(width: 37.0, height: 37.0)
    }
    
    public func onLayout() {
    }

    public final class SnapshotState {
        fileprivate let snapshotView: UIView?
        fileprivate let snapshotStatusView: UIView?

        fileprivate init(snapshotView: UIView?, snapshotStatusView: UIView?) {
            self.snapshotView = snapshotView
            self.snapshotStatusView = snapshotStatusView
        }
    }

    public func prepareSnapshotState() -> SnapshotState {
        let snapshotView = self.avatarNode.view.snapshotView(afterScreenUpdates: false)
        let snapshotStatusView = self.statusView.view?.snapshotView(afterScreenUpdates: false)
        return SnapshotState(
            snapshotView: snapshotView,
            snapshotStatusView: snapshotStatusView
        )
    }

    public func animateFromSnapshot(_ snapshotState: SnapshotState) {
        self.avatarNode.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.16)
        self.avatarNode.layer.animateScale(from: 0.1, to: 1.0, duration: 0.4, timingFunction: kCAMediaTimingFunctionSpring, removeOnCompletion: true)
        
        self.statusView.view?.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.16)
        self.statusView.view?.layer.animateScale(from: 0.1, to: 1.0, duration: 0.4, timingFunction: kCAMediaTimingFunctionSpring, removeOnCompletion: true)

        if let snapshotView = snapshotState.snapshotView {
            snapshotView.frame = self.frame
            self.containerNode.view.insertSubview(snapshotView, at: 0)

            snapshotView.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.2, removeOnCompletion: false, completion: { [weak snapshotView] _ in
                snapshotView?.removeFromSuperview()
            })
            snapshotView.layer.animateScale(from: 1.0, to: 0.1, duration: 0.4, timingFunction: kCAMediaTimingFunctionSpring, removeOnCompletion: false)
        }
        if let snapshotStatusView = snapshotState.snapshotStatusView {
            snapshotStatusView.frame = CGRect(origin: CGPoint(x: floor((self.containerNode.bounds.width - snapshotStatusView.bounds.width) / 2.0), y: floor((self.containerNode.bounds.height - snapshotStatusView.bounds.height) / 2.0)), size: snapshotStatusView.bounds.size)
            self.containerNode.view.insertSubview(snapshotStatusView, at: 0)

            snapshotStatusView.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.2, removeOnCompletion: false, completion: { [weak snapshotStatusView] _ in
                snapshotStatusView?.removeFromSuperview()
            })
            snapshotStatusView.layer.animateScale(from: 1.0, to: 0.1, duration: 0.4, timingFunction: kCAMediaTimingFunctionSpring, removeOnCompletion: false)
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

private class StarView: UIView {
    let outline = SimpleLayer()
    let foreground = SimpleLayer()
    
    var outlineColor: UIColor = .white {
        didSet {
            self.outline.layerTintColor = self.outlineColor.cgColor
        }
    }
    
    override init(frame: CGRect) {
        self.outline.contents = UIImage(bundleImageName: "Premium/Stars/StarMediumOutline")?.cgImage
        self.foreground.contents = UIImage(bundleImageName: "Premium/Stars/StarMedium")?.cgImage
        
        super.init(frame: frame)
        
        self.layer.addSublayer(self.outline)
        self.layer.addSublayer(self.foreground)
    }
    
    required init?(coder: NSCoder) {
        preconditionFailure()
    }
    
    override func layoutSubviews() {
        self.outline.frame = self.bounds
        self.foreground.frame = self.bounds
    }
}
