import Foundation
import UIKit
import AsyncDisplayKit
import ContextUI
import TelegramPresentationData
import AccountContext
import AvatarNode
import UniversalMediaPlayer
import Display
import ComponentFlow
import UniversalMediaPlayer
import AvatarVideoNode
import SwiftSignalKit
import TelegramUniversalVideoContent
import PeerInfoAvatarListNode
import Postbox
import TelegramCore
import EmojiStatusComponent
import GalleryUI
import HierarchyTrackingLayer

final class PeerInfoAvatarTransformContainerNode: ASDisplayNode {
    let context: AccountContext
    
    let containerNode: ContextControllerSourceNode
    
    let avatarNode: AvatarNode
    private(set) var avatarStoryView: ComponentView<Empty>?
    var videoNode: UniversalVideoNode?
    var markupNode: AvatarVideoNode?
    var iconView: ComponentView<Empty>?
    private var videoContent: NativeVideoContent?
    private var videoStartTimestamp: Double?
    
    private let hierarchyTrackingLayer = HierarchyTrackingLayer()
    
    var isExpanded: Bool = false
    var canAttachVideo: Bool = true {
        didSet {
            if oldValue != self.canAttachVideo {
                self.videoNode?.canAttachContent = !self.isExpanded && self.canAttachVideo
            }
        }
    }
    
    var tapped: (() -> Void)?
    var emojiTapped: (() -> Void)?
    var contextAction: ((ASDisplayNode, ContextGesture?) -> Void)?
    
    private var isFirstAvatarLoading = true
    var item: PeerInfoAvatarListItem?
    
    private let playbackStartDisposable = MetaDisposable()
    
    var storyData: (totalCount: Int, unseenCount: Int, hasUnseenCloseFriends: Bool)?
    var storyProgress: Float?
    
    init(context: AccountContext) {
        self.context = context
        self.containerNode = ContextControllerSourceNode()
        
        let avatarFont = avatarPlaceholderFont(size: floor(100.0 * 16.0 / 37.0))
        self.avatarNode = AvatarNode(font: avatarFont)
        
        super.init()
        
        self.addSubnode(self.containerNode)
        self.containerNode.addSubnode(self.avatarNode)
        self.containerNode.frame = CGRect(origin: CGPoint(x: -50.0, y: -50.0), size: CGSize(width: 100.0, height: 100.0))
        self.avatarNode.frame = self.containerNode.bounds
        
        let tapGestureRecognizer = UITapGestureRecognizer(target: self, action: #selector(self.tapGesture(_:)))
        self.avatarNode.view.addGestureRecognizer(tapGestureRecognizer)
       
        self.containerNode.activated = { [weak self] gesture, _ in
            guard let strongSelf = self else {
                return
            }
            tapGestureRecognizer.isEnabled = false
            tapGestureRecognizer.isEnabled = true
            strongSelf.contextAction?(strongSelf.containerNode, gesture)
        }

        self.hierarchyTrackingLayer.isInHierarchyUpdated = { [weak self] value in
            guard let self else {
                return
            }
            
            if value {
                self.updateFromParams()
            } else {
                self.videoNode?.removeFromSupernode()
                self.videoNode = nil
                self.videoContent = nil
            }
        }
        self.layer.addSublayer(self.hierarchyTrackingLayer)
    }
    
    deinit {
        self.playbackStartDisposable.dispose()
    }
    
    func updateStoryView(transition: ContainedViewLayoutTransition, theme: PresentationTheme, peer: Peer?) {
        var colors = AvatarNode.Colors(theme: theme)
        
        let regularNavigationContentsSecondaryColor: UIColor
        if case let .starGift(_, _, _, _, _, innerColorValue, outerColorValue, _, _) = peer?.emojiStatus?.content {
            let innerColor = UIColor(rgb: UInt32(bitPattern: innerColorValue))
            let outerColor = UIColor(rgb: UInt32(bitPattern: outerColorValue))
            regularNavigationContentsSecondaryColor = UIColor(white: 1.0, alpha: 0.6).blitOver(innerColor.withMultiplied(hue: 1.0, saturation: 2.2, brightness: 1.5), alpha: 1.0)
                    
            let baseBackgroundColor = UIColor(white: 1.0, alpha: 0.75)
    
            let topColor = baseBackgroundColor.blendOver(background: innerColor.mixedWith(outerColor, alpha: 0.1)).withMultiplied(hue: 1.0, saturation: 1.2, brightness: 1.5)
            let bottomColor = baseBackgroundColor.blendOver(background: outerColor).withMultiplied(hue: 1.0, saturation: 1.2, brightness: 1.5)
        
            colors.unseenColors = [topColor, bottomColor]
            colors.unseenCloseFriendsColors = colors.unseenColors
            colors.seenColors = colors.unseenColors
        } else if let profileColor = peer?.profileColor {
            let backgroundColors = self.context.peerNameColors.getProfile(profileColor, dark: theme.overallDarkAppearance)
            regularNavigationContentsSecondaryColor = UIColor(white: 1.0, alpha: 0.6).blitOver(backgroundColors.main.withMultiplied(hue: 1.0, saturation: 2.2, brightness: 1.5), alpha: 1.0)
            
            let storyColors = self.context.peerNameColors.getProfile(profileColor, dark: theme.overallDarkAppearance, subject: .stories)
            
            var unseenColors: [UIColor] = [storyColors.main]
            if let secondary = storyColors.secondary {
                unseenColors.insert(secondary, at: 0)
            }
            colors.unseenColors = unseenColors
            colors.unseenCloseFriendsColors = colors.unseenColors
            colors.seenColors = colors.unseenColors
        } else {
            regularNavigationContentsSecondaryColor = theme.list.controlSecondaryColor
        }
        
        colors.seenColors = [
            regularNavigationContentsSecondaryColor,
            regularNavigationContentsSecondaryColor
        ]
        
        var storyStats: AvatarNode.StoryStats?
        if let storyData = self.storyData {
            storyStats = AvatarNode.StoryStats(
                totalCount: storyData.totalCount,
                unseenCount: storyData.unseenCount,
                hasUnseenCloseFriendsItems: storyData.hasUnseenCloseFriends,
                progress: self.storyProgress
            )
        } else if let storyProgress = self.storyProgress {
            storyStats = AvatarNode.StoryStats(
                totalCount: 1,
                unseenCount: 1,
                hasUnseenCloseFriendsItems: false,
                progress: storyProgress
            )
        }
        
        var isForum = false
        if let peer, let channel = peer as? TelegramChannel, channel.isForumOrMonoForum {
            isForum = true
        }
        
        self.avatarNode.setStoryStats(storyStats: storyStats, presentationParams: AvatarNode.StoryPresentationParams(
            colors: colors,
            lineWidth: 3.0,
            inactiveLineWidth: 1.5,
            forceRoundedRect: isForum
        ), transition: ComponentTransition(transition))
    }
    
    @objc private func tapGesture(_ recognizer: UITapGestureRecognizer) {
        if case .ended = recognizer.state {
            self.tapped?()
        }
    }
    
    @objc private func emojiTapGesture(_ recognizer: UITapGestureRecognizer) {
        if case .ended = recognizer.state {
            self.emojiTapped?()
        }
    }
        
    func updateTransitionFraction(_ fraction: CGFloat, transition: ContainedViewLayoutTransition) {
        if let videoNode = self.videoNode {
            if case .immediate = transition, fraction == 1.0 {
                return
            }
            if fraction > 0.0 {
                videoNode.pause()
            } else {
                videoNode.play()
            }
            transition.updateAlpha(node: videoNode, alpha: 1.0 - fraction)
        }
        if let markupNode = self.markupNode {
            if case .immediate = transition, fraction == 1.0 {
                return
            }
            if fraction > 0.0 {
                markupNode.updateVisibility(false)
            } else {
                markupNode.updateVisibility(true)
            }
            transition.updateAlpha(node: markupNode, alpha: 1.0 - fraction)
        }
    }

    private struct Params {
        let peer: Peer?
        let threadId: Int64?
        let threadInfo: EngineMessageHistoryThread.Info?
        let item: PeerInfoAvatarListItem?
        let theme: PresentationTheme
        let avatarSize: CGFloat
        let isExpanded: Bool
        let isSettings: Bool

        init(peer: Peer?, threadId: Int64?, threadInfo: EngineMessageHistoryThread.Info?, item: PeerInfoAvatarListItem?, theme: PresentationTheme, avatarSize: CGFloat, isExpanded: Bool, isSettings: Bool) {
            self.peer = peer
            self.threadId = threadId
            self.threadInfo = threadInfo
            self.item = item
            self.theme = theme
            self.avatarSize = avatarSize
            self.isExpanded = isExpanded
            self.isSettings = isSettings
        }
    }
        
    var removedPhotoResourceIds = Set<String>()
    private var params: Params?

    private func updateFromParams() {
        guard let params = self.params else {
            return
        }

        self.update(
            peer: params.peer,
            threadId: params.threadId,
            threadInfo: params.threadInfo,
            item: params.item,
            theme: params.theme,
            avatarSize: params.avatarSize,
            isExpanded: params.isExpanded,
            isSettings: params.isSettings
        )
    }

    func update(peer: Peer?, threadId: Int64?, threadInfo: EngineMessageHistoryThread.Info?, item: PeerInfoAvatarListItem?, theme: PresentationTheme, avatarSize: CGFloat, isExpanded: Bool, isSettings: Bool) {
        self.params = Params(peer: peer, threadId: threadId, threadInfo: threadInfo, item: item, theme: theme, avatarSize: avatarSize, isExpanded: isExpanded, isSettings: isSettings)

        if let peer = peer {
            let previousItem = self.item
            var item = item
            self.item = item
            
            var overrideImage: AvatarNodeImageOverride?
            if peer.isDeleted {
                overrideImage = .deletedIcon
            } else if let previousItem = previousItem, item == nil {
                if case let .image(_, representations, _, _, _, _) = previousItem, let rep = representations.last {
                    self.removedPhotoResourceIds.insert(rep.representation.resource.id.stringRepresentation)
                }
                overrideImage = AvatarNodeImageOverride.none
                item = nil
            } else if let rep = peer.profileImageRepresentations.last, self.removedPhotoResourceIds.contains(rep.resource.id.stringRepresentation) {
                overrideImage = AvatarNodeImageOverride.none
                item = nil
            }
            
            if let _ = overrideImage {
                self.containerNode.isGestureEnabled = false
            } else if peer.profileImageRepresentations.isEmpty {
                self.containerNode.isGestureEnabled = false
            } else {
                self.containerNode.isGestureEnabled = false
            }
            
            self.avatarNode.imageNode.animateFirstTransition = !isSettings
            self.avatarNode.setPeer(context: self.context, theme: theme, peer: EnginePeer(peer), overrideImage: overrideImage, clipStyle: .none, synchronousLoad: self.isFirstAvatarLoading, displayDimensions: CGSize(width: avatarSize, height: avatarSize), storeUnrounded: true)
            
            if let threadInfo = threadInfo {
                self.avatarNode.isHidden = true
                
                let iconView: ComponentView<Empty>
                if let current = self.iconView {
                    iconView = current
                } else {
                    iconView = ComponentView()
                    self.iconView = iconView
                }
                let content: EmojiStatusComponent.Content
                if threadId == 1 {
                    content = .image(image: PresentationResourcesChat.chatGeneralThreadIcon(theme), tintColor: nil)
                } else if let iconFileId = threadInfo.icon {
                    content = .animation(content: .customEmoji(fileId: iconFileId), size: CGSize(width: avatarSize, height: avatarSize), placeholderColor: theme.list.mediaPlaceholderColor, themeColor: theme.list.itemAccentColor, loopMode: .forever)
                } else {
                    content = .topic(title: String(threadInfo.title.prefix(1)), color: threadInfo.iconColor, size: CGSize(width: avatarSize, height: avatarSize))
                }
                let _ = iconView.update(
                    transition: .immediate,
                    component: AnyComponent(EmojiStatusComponent(
                        context: self.context,
                        animationCache: self.context.animationCache,
                        animationRenderer: self.context.animationRenderer,
                        content: content,
                        isVisibleForAnimations: true,
                        action: nil
                    )),
                    environment: {},
                    containerSize: CGSize(width: avatarSize, height: avatarSize)
                )
                if let iconComponentView = iconView.view {
                    iconComponentView.isUserInteractionEnabled = true
                    if iconComponentView.superview == nil {
                        iconComponentView.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(self.emojiTapGesture(_:))))
                        self.avatarNode.view.superview?.addSubview(iconComponentView)
                    }
                    iconComponentView.frame = CGRect(origin: CGPoint(), size: CGSize(width: avatarSize, height: avatarSize))
                }
            }
            
            var isForum = false
            let avatarCornerRadius: CGFloat
            if let channel = peer as? TelegramChannel, channel.isForumOrMonoForum {
                avatarCornerRadius = floor(avatarSize * 0.25)
                isForum = true
            } else {
                avatarCornerRadius = avatarSize / 2.0
            }
            if self.avatarNode.layer.cornerRadius != 0.0 {
                ContainedViewLayoutTransition.animated(duration: 0.3, curve: .easeInOut).updateCornerRadius(layer: self.avatarNode.contentNode.layer, cornerRadius: avatarCornerRadius)
            } else {
                self.avatarNode.contentNode.layer.cornerRadius = avatarCornerRadius
            }
            self.avatarNode.contentNode.layer.masksToBounds = true
            
            self.isFirstAvatarLoading = false
            
            self.containerNode.frame = CGRect(origin: CGPoint(x: -avatarSize / 2.0, y: -avatarSize / 2.0), size: CGSize(width: avatarSize, height: avatarSize))
            self.avatarNode.frame = self.containerNode.bounds
            self.avatarNode.font = avatarPlaceholderFont(size: floor(avatarSize * 16.0 / 37.0))

            if let item = item {
                let representations: [ImageRepresentationWithReference]
                let videoRepresentations: [VideoRepresentationWithReference]
                let immediateThumbnailData: Data?
                var videoId: Int64
                let markup: TelegramMediaImage.EmojiMarkup?
                switch item {
                case .custom:
                    representations = []
                    videoRepresentations = []
                    immediateThumbnailData = nil
                    videoId = 0
                    markup = nil
                case let .topImage(topRepresentations, videoRepresentationsValue, immediateThumbnail):
                    representations = topRepresentations
                    videoRepresentations = videoRepresentationsValue
                    immediateThumbnailData = immediateThumbnail
                    videoId = peer.id.id._internalGetInt64Value()
                    if let resource = videoRepresentations.first?.representation.resource as? CloudPhotoSizeMediaResource {
                        videoId = videoId &+ resource.photoId
                    }
                    markup = nil
                case let .image(reference, imageRepresentations, videoRepresentationsValue, immediateThumbnail, _, markupValue):
                    representations = imageRepresentations
                    videoRepresentations = videoRepresentationsValue
                    immediateThumbnailData = immediateThumbnail
                    if case let .cloud(imageId, _, _) = reference {
                        videoId = imageId
                    } else {
                        videoId = peer.id.id._internalGetInt64Value()
                    }
                    markup = markupValue
                }
                
                self.containerNode.isGestureEnabled = !isSettings
                
                if let markup {
                    if let videoNode = self.videoNode {
                        self.videoContent = nil
                        self.videoStartTimestamp = nil
                        self.videoNode = nil
                                  
                        videoNode.removeFromSupernode()
                    }
                    
                    let markupNode: AvatarVideoNode
                    if let current = self.markupNode {
                        markupNode = current
                    } else {
                        markupNode = AvatarVideoNode(context: self.context)
                        self.avatarNode.contentNode.addSubnode(markupNode)
                        self.markupNode = markupNode
                    }
                    markupNode.update(markup: markup, size: CGSize(width: 320.0, height: 320.0))
                    markupNode.updateVisibility(true)
                } else if threadInfo == nil, let video = videoRepresentations.last, let peerReference = PeerReference(peer) {
                    let videoFileReference = FileMediaReference.avatarList(peer: peerReference, media: TelegramMediaFile(fileId: MediaId(namespace: Namespaces.Media.LocalFile, id: 0), partialReference: nil, resource: video.representation.resource, previewRepresentations: representations.map { $0.representation }, videoThumbnails: [], immediateThumbnailData: immediateThumbnailData, mimeType: "video/mp4", size: nil, attributes: [.Animated, .Video(duration: 0, size: video.representation.dimensions, flags: [], preloadSize: nil, coverTime: nil, videoCodec: nil)], alternativeRepresentations: []))
                    let videoContent = NativeVideoContent(id: .profileVideo(videoId, nil), userLocation: .other, fileReference: videoFileReference, streamVideo: isMediaStreamable(resource: video.representation.resource) ? .conservative : .none, loopVideo: true, enableSound: false, fetchAutomatically: true, onlyFullSizeThumbnail: false, useLargeThumbnail: true, autoFetchFullSizeThumbnail: true, startTimestamp: video.representation.startTimestamp, continuePlayingWithoutSoundOnLostAudioSession: false, placeholderColor: .clear, captureProtected: peer.isCopyProtectionEnabled, storeAfterDownload: nil)
                    if videoContent.id != self.videoContent?.id {
                        self.videoNode?.removeFromSupernode()
                        
                        if self.hierarchyTrackingLayer.isInHierarchy {
                            let mediaManager = self.context.sharedContext.mediaManager
                            let videoNode = UniversalVideoNode(context: self.context, postbox: self.context.account.postbox, audioSession: mediaManager.audioSession, manager: mediaManager.universalVideoManager, decoration: GalleryVideoDecoration(), content: videoContent, priority: .embedded)
                            videoNode.isUserInteractionEnabled = false
                            videoNode.isHidden = true
                            
                            if let startTimestamp = video.representation.startTimestamp {
                                self.videoStartTimestamp = startTimestamp
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
                                self.videoStartTimestamp = nil
                                self.playbackStartDisposable.set(nil)
                                videoNode.isHidden = false
                            }
                            
                            self.videoContent = videoContent
                            self.videoNode = videoNode
                            
                            let maskPath: UIBezierPath
                            if isForum {
                                maskPath = UIBezierPath(roundedRect: CGRect(origin: CGPoint(), size: self.avatarNode.frame.size), cornerRadius: avatarCornerRadius)
                            } else {
                                maskPath = UIBezierPath(ovalIn: CGRect(origin: CGPoint(), size: self.avatarNode.frame.size))
                            }
                            let shape = CAShapeLayer()
                            shape.path = maskPath.cgPath
                            videoNode.layer.mask = shape
                            
                            self.avatarNode.contentNode.addSubnode(videoNode)
                        }
                    }
                } else {
                    if let markupNode = self.markupNode {
                        self.markupNode = nil
                        markupNode.removeFromSupernode()
                    }
                    if let videoNode = self.videoNode {
                        self.videoStartTimestamp = nil
                        self.videoContent = nil
                        self.videoNode = nil
                        
                        videoNode.removeFromSupernode()
                    }
                }
            } else  {
                if let markupNode = self.markupNode {
                    self.markupNode = nil
                    markupNode.removeFromSupernode()
                }
                if let videoNode = self.videoNode {
                    self.videoStartTimestamp = nil
                    self.videoContent = nil
                    self.videoNode = nil
                    
                    videoNode.removeFromSupernode()
                }
                self.containerNode.isGestureEnabled = false
            }
            
            if let markupNode = self.markupNode {
                markupNode.frame = self.avatarNode.bounds
                markupNode.updateLayout(size: self.avatarNode.bounds.size, cornerRadius: avatarCornerRadius, transition: .immediate)
            }
            
            if let videoNode = self.videoNode {
                if self.canAttachVideo {
                    videoNode.updateLayout(size: self.avatarNode.frame.size, transition: .immediate)
                }
                videoNode.frame = self.avatarNode.contentNode.bounds
                
                if isExpanded == videoNode.canAttachContent {
                    self.isExpanded = isExpanded
                    let update = {
                        videoNode.canAttachContent = !self.isExpanded && self.canAttachVideo
                        if videoNode.canAttachContent {
                            videoNode.play()
                        }
                    }
                    if isExpanded {
                        DispatchQueue.main.async {
                            update()
                        }
                    } else {
                        update()
                    }
                }
            }
        }
        
        self.updateStoryView(transition: .immediate, theme: theme, peer: peer)
    }
}
