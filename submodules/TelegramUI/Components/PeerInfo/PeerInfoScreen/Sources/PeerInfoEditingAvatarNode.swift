import Foundation
import UIKit
import AsyncDisplayKit
import TelegramPresentationData
import AccountContext
import AvatarNode
import UniversalMediaPlayer
import PeerInfoAvatarListNode
import AvatarVideoNode
import TelegramUniversalVideoContent
import SwiftSignalKit
import Postbox
import TelegramCore
import Display
import GalleryUI

final class PeerInfoEditingAvatarNode: ASDisplayNode {
    private let context: AccountContext
    let avatarNode: AvatarNode
    fileprivate var videoNode: UniversalVideoNode?
    fileprivate var markupNode: AvatarVideoNode?
    private var videoContent: NativeVideoContent?
    private var videoStartTimestamp: Double?
    var item: PeerInfoAvatarListItem?
    
    var tapped: ((Bool) -> Void)?
        
    var canAttachVideo: Bool = true
    
    init(context: AccountContext) {
        self.context = context
        let avatarFont = avatarPlaceholderFont(size: floor(100.0 * 16.0 / 37.0))
        self.avatarNode = AvatarNode(font: avatarFont)
    
        super.init()
        
        self.addSubnode(self.avatarNode)
        self.avatarNode.frame = CGRect(origin: CGPoint(x: -50.0, y: -50.0), size: CGSize(width: 100.0, height: 100.0))
    
        self.avatarNode.view.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(self.tapGesture(_:))))
    }
    
    @objc private func tapGesture(_ recognizer: UITapGestureRecognizer) {
        if case .ended = recognizer.state {
            self.tapped?(false)
        }
    }
    
    func reset() {
        guard let videoNode = self.videoNode else {
            return
        }
        videoNode.isHidden = true
        videoNode.seek(self.videoStartTimestamp ?? 0.0)
        Queue.mainQueue().after(0.15) {
            videoNode.isHidden = false
        }
    }
    
    var removedPhotoResourceIds = Set<String>()
    func update(peer: Peer?, threadData: MessageHistoryThreadData?, chatLocation: ChatLocation, item: PeerInfoAvatarListItem?, updatingAvatar: PeerInfoUpdatingAvatar?, uploadProgress: AvatarUploadProgress?, theme: PresentationTheme, avatarSize: CGFloat, isEditing: Bool) {
        guard let peer = peer else {
            return
        }
        
        let canEdit = canEditPeerInfo(context: self.context, peer: peer, chatLocation: chatLocation, threadData: threadData)

        let previousItem = self.item
        var item = item
        self.item = item
                        
        let overrideImage: AvatarNodeImageOverride?
        if canEdit, peer.profileImageRepresentations.isEmpty {
            overrideImage = .editAvatarIcon(forceNone: true)
        } else if let previousItem = previousItem, item == nil {
            if case let .image(_, representations, _, _, _, _) = previousItem, let rep = representations.last {
                self.removedPhotoResourceIds.insert(rep.representation.resource.id.stringRepresentation)
            }
            overrideImage = canEdit ? .editAvatarIcon(forceNone: true) : AvatarNodeImageOverride.none
            item = nil
        } else if let representation = peer.profileImageRepresentations.last, self.removedPhotoResourceIds.contains(representation.resource.id.stringRepresentation) {
            overrideImage = canEdit ? .editAvatarIcon(forceNone: true) : AvatarNodeImageOverride.none
            item = nil
        } else {
            overrideImage = item == nil && canEdit ? .editAvatarIcon(forceNone: true) : nil
        }
        self.avatarNode.font = avatarPlaceholderFont(size: floor(avatarSize * 16.0 / 37.0))
        self.avatarNode.setPeer(context: self.context, theme: theme, peer: EnginePeer(peer), overrideImage: overrideImage, clipStyle: .none, synchronousLoad: false, displayDimensions: CGSize(width: avatarSize, height: avatarSize))
        self.avatarNode.frame = CGRect(origin: CGPoint(x: -avatarSize / 2.0, y: -avatarSize / 2.0), size: CGSize(width: avatarSize, height: avatarSize))
        
        var isForum = false
        let avatarCornerRadius: CGFloat
        if let channel = peer as? TelegramChannel, channel.isForumOrMonoForum {
            isForum = true
            avatarCornerRadius = floor(avatarSize * 0.25)
        } else {
            avatarCornerRadius = avatarSize / 2.0
        }
        if self.avatarNode.layer.cornerRadius != 0.0 {
            ContainedViewLayoutTransition.animated(duration: 0.3, curve: .easeInOut).updateCornerRadius(layer: self.avatarNode.layer, cornerRadius: avatarCornerRadius)
        } else {
            self.avatarNode.layer.cornerRadius = avatarCornerRadius
        }
        self.avatarNode.layer.masksToBounds = true
        
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
            } else if threadData == nil, let video = videoRepresentations.last, let peerReference = PeerReference(peer) {
                if let markupNode = self.markupNode {
                    self.markupNode = nil
                    markupNode.removeFromSupernode()
                }
                
                let videoFileReference = FileMediaReference.avatarList(peer: peerReference, media: TelegramMediaFile(fileId: MediaId(namespace: Namespaces.Media.LocalFile, id: 0), partialReference: nil, resource: video.representation.resource, previewRepresentations: representations.map { $0.representation }, videoThumbnails: [], immediateThumbnailData: immediateThumbnailData, mimeType: "video/mp4", size: nil, attributes: [.Animated, .Video(duration: 0, size: video.representation.dimensions, flags: [], preloadSize: nil, coverTime: nil, videoCodec: nil)], alternativeRepresentations: []))
                let videoContent = NativeVideoContent(id: .profileVideo(videoId, nil), userLocation: .other, fileReference: videoFileReference, streamVideo: isMediaStreamable(resource: video.representation.resource) ? .conservative : .none, loopVideo: true, enableSound: false, fetchAutomatically: true, onlyFullSizeThumbnail: false, useLargeThumbnail: true, autoFetchFullSizeThumbnail: true, startTimestamp: video.representation.startTimestamp, continuePlayingWithoutSoundOnLostAudioSession: false, placeholderColor: .clear, captureProtected: peer.isCopyProtectionEnabled, storeAfterDownload: nil)
                if videoContent.id != self.videoContent?.id {
                    self.videoNode?.removeFromSupernode()
                    
                    let mediaManager = self.context.sharedContext.mediaManager
                    let videoNode = UniversalVideoNode(context: self.context, postbox: self.context.account.postbox, audioSession: mediaManager.audioSession, manager: mediaManager.universalVideoManager, decoration: GalleryVideoDecoration(), content: videoContent, priority: .gallery)
                    videoNode.isUserInteractionEnabled = false
                    self.videoStartTimestamp = video.representation.startTimestamp
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
            } else {
                if let markupNode = self.markupNode {
                    self.markupNode = nil
                    markupNode.removeFromSupernode()
                }
                if let videoNode = self.videoNode {
                    self.videoStartTimestamp = nil
                    self.videoContent = nil
                    self.videoNode = nil
                    
                    DispatchQueue.main.async {
                        videoNode.removeFromSupernode()
                    }
                }
            }
        } else if let videoNode = self.videoNode {
            self.videoStartTimestamp = nil
            self.videoContent = nil
            self.videoNode = nil
            
            videoNode.removeFromSupernode()
        }
        
        if let markupNode = self.markupNode {
            markupNode.frame = self.avatarNode.bounds
            markupNode.updateLayout(size: self.avatarNode.bounds.size, cornerRadius: avatarCornerRadius, transition: .immediate)
        }
        
        if let videoNode = self.videoNode {
            if self.canAttachVideo {
                videoNode.updateLayout(size: self.avatarNode.bounds.size, transition: .immediate)
            }
            videoNode.frame = self.avatarNode.bounds
            
            if isEditing != videoNode.canAttachContent {
                videoNode.canAttachContent = isEditing && self.canAttachVideo
            }
        }
    }
    
    override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        if self.avatarNode.frame.contains(point) {
            return self.avatarNode.view
        }
        return super.hitTest(point, with: event)
    }
}
