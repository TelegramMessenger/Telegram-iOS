import Foundation
import UIKit
import AsyncDisplayKit
import Display
import Postbox
import TelegramCore
import AvatarNode
import AccountContext
import SwiftSignalKit
import TelegramPresentationData
import PhotoResources
import PeerAvatarGalleryUI
import TelegramStringFormatting
import PhoneNumberFormat
import ActivityIndicator
import TelegramUniversalVideoContent
import GalleryUI
import UniversalMediaPlayer
import RadialStatusNode
import TelegramUIPreferences
import PeerInfoAvatarListNode
import AnimationUI
import ContextUI
import ManagedAnimationNode

enum PeerInfoHeaderButtonKey: Hashable {
    case message
    case discussion
    case call
    case videoCall
    case voiceChat
    case mute
    case more
    case addMember
    case search
    case leave
    case stop
}

enum PeerInfoHeaderButtonIcon {
    case message
    case call
    case videoCall
    case voiceChat
    case mute
    case unmute
    case more
    case addMember
    case search
    case leave
    case stop
}

final class PeerInfoHeaderButtonNode: HighlightableButtonNode {
    let key: PeerInfoHeaderButtonKey
    private let action: (PeerInfoHeaderButtonNode, ContextGesture?) -> Void
    let referenceNode: ContextReferenceContentNode
    let containerNode: ContextControllerSourceNode
    private let backgroundNode: ASDisplayNode
    private let iconNode: ASImageNode
    private let textNode: ImmediateTextNode
    private var animationNode: AnimationNode?
    
    private var theme: PresentationTheme?
    private var icon: PeerInfoHeaderButtonIcon?
    private var isActive: Bool?
    
    init(key: PeerInfoHeaderButtonKey, action: @escaping (PeerInfoHeaderButtonNode, ContextGesture?) -> Void) {
        self.key = key
        self.action = action
        
        self.referenceNode = ContextReferenceContentNode()
        self.containerNode = ContextControllerSourceNode()
        self.containerNode.animateScale = false
        
        self.backgroundNode = ASDisplayNode()
        self.backgroundNode.cornerRadius = 11.0
        
        self.iconNode = ASImageNode()
        self.iconNode.displaysAsynchronously = false
        self.iconNode.displayWithoutProcessing = true
        self.iconNode.isUserInteractionEnabled = false
        
        self.textNode = ImmediateTextNode()
        self.textNode.displaysAsynchronously = false
        self.textNode.isUserInteractionEnabled = false
        
        super.init()
        
        self.accessibilityTraits = .button
        
        self.containerNode.addSubnode(self.referenceNode)
        self.referenceNode.addSubnode(self.backgroundNode)
        self.referenceNode.addSubnode(self.iconNode)
        self.addSubnode(self.containerNode)
        self.addSubnode(self.textNode)
        
        self.highligthedChanged = { [weak self] highlighted in
            if let strongSelf = self {
                if highlighted {
                    strongSelf.layer.removeAnimation(forKey: "opacity")
                    strongSelf.alpha = 0.4
                } else {
                    strongSelf.alpha = 1.0
                    strongSelf.layer.animateAlpha(from: 0.4, to: 1.0, duration: 0.2)
                }
            }
        }
        
        self.containerNode.activated = { [weak self] gesture, _ in
            if let strongSelf = self {
                strongSelf.action(strongSelf, gesture)
            }
        }
        
        self.addTarget(self, action: #selector(self.buttonPressed), forControlEvents: .touchUpInside)
    }
    
    @objc private func buttonPressed() {
        switch self.icon {
            case .voiceChat, .more, .leave:
                self.animationNode?.playOnce()
            default:
                break
        }
        self.action(self, nil)
    }
    
    func update(size: CGSize, text: String, icon: PeerInfoHeaderButtonIcon, isActive: Bool, isExpanded: Bool, presentationData: PresentationData, transition: ContainedViewLayoutTransition) {
        let previousIcon = self.icon
        let themeUpdated = self.theme != presentationData.theme
        let iconUpdated = self.icon != icon
        let isActiveUpdated = self.isActive != isActive
        self.isActive = isActive
        
        let iconSize = CGSize(width: 40.0, height: 40.0)
        
        if themeUpdated || iconUpdated {
            self.theme = presentationData.theme
            self.icon = icon
            
            var isGestureEnabled = false
            if [.mute, .voiceChat, .more].contains(icon) {
                isGestureEnabled = true
            }
            self.containerNode.isGestureEnabled = isGestureEnabled
                        
            let animationName: String?
            var colors: [String: UIColor] = [:]
            var playOnce = false
            var seekToEnd = false
            let iconColor = presentationData.theme.list.itemAccentColor
            switch icon {
                case .voiceChat:
                    animationName = "anim_profilevc"
                    colors = ["Line 3.Group 1.Stroke 1": iconColor,
                              "Line 1.Group 1.Stroke 1": iconColor,
                              "Line 2.Group 1.Stroke 1": iconColor]
                case .mute:
                    animationName = "anim_profileunmute"
                    colors = ["Middle.Group 1.Fill 1": iconColor,
                              "Top.Group 1.Fill 1": iconColor,
                              "Bottom.Group 1.Fill 1": iconColor,
                              "EXAMPLE.Group 1.Fill 1": iconColor,
                              "Line.Group 1.Stroke 1": iconColor]
                    if previousIcon == .unmute {
                        playOnce = true
                    } else {
                        seekToEnd = true
                    }
                case .unmute:
                    animationName = "anim_profilemute"
                    colors = ["Middle.Group 1.Fill 1": iconColor,
                              "Top.Group 1.Fill 1": iconColor,
                              "Bottom.Group 1.Fill 1": iconColor,
                              "EXAMPLE.Group 1.Fill 1": iconColor,
                              "Line.Group 1.Stroke 1": iconColor]
                    if previousIcon == .mute {
                        playOnce = true
                    } else {
                        seekToEnd = true
                    }
                case .more:
                    animationName = "anim_profilemore"
                    colors = ["Point 2.Group 1.Fill 1": iconColor,
                              "Point 3.Group 1.Fill 1": iconColor,
                              "Point 1.Group 1.Fill 1": iconColor]
                case .leave:
                    animationName = "anim_profileleave"
                    colors = ["Arrow.Group 2.Stroke 1": iconColor,
                              "Door.Group 1.Stroke 1": iconColor,
                              "Arrow.Group 1.Stroke 1": iconColor]
                default:
                    animationName = nil
            }
            
            if let animationName = animationName {
                let animationNode: AnimationNode
                if let current = self.animationNode {
                    animationNode = current
                    animationNode.setAnimation(name: animationName, colors: colors)
                } else {
                    animationNode = AnimationNode(animation: animationName, colors: colors, scale: 1.0)
                    self.referenceNode.addSubnode(animationNode)
                    self.animationNode = animationNode
                }
            } else if let animationNode = self.animationNode {
                self.animationNode = nil
                animationNode.removeFromSupernode()
            }
            
            if playOnce {
                self.animationNode?.play()
            } else if seekToEnd {
                self.animationNode?.seekToEnd()
            }
                        
            self.backgroundNode.backgroundColor = presentationData.theme.list.itemBlocksBackgroundColor
            transition.updateFrame(node: self.backgroundNode, frame: CGRect(origin: CGPoint(), size: size))
            self.iconNode.image = generateImage(iconSize, contextGenerator: { size, context in
                context.clear(CGRect(origin: CGPoint(), size: size))
                context.setBlendMode(.normal)
                context.setFillColor(iconColor.cgColor)
                let imageName: String?
                switch icon {
                case .message:
                    imageName = "Peer Info/ButtonMessage"
                case .call:
                    imageName = "Peer Info/ButtonCall"
                case .videoCall:
                    imageName = "Peer Info/ButtonVideo"
                case .voiceChat:
                    imageName = nil
                case .mute:
                    imageName = nil
                case .unmute:
                    imageName = nil
                case .more:
                    imageName = nil
                case .addMember:
                    imageName = "Peer Info/ButtonAddMember"
                case .search:
                    imageName = "Peer Info/ButtonSearch"
                case .leave:
                    imageName = nil
                case .stop:
                    imageName = "Peer Info/ButtonStop"
                }
                if let imageName = imageName, let image = generateTintedImage(image: UIImage(bundleImageName: imageName), color: .white) {
                    let imageRect = CGRect(origin: CGPoint(x: floor((size.width - image.size.width) / 2.0), y: floor((size.height - image.size.height) / 2.0)), size: image.size)
                    context.clip(to: imageRect, mask: image.cgImage!)
                    context.fill(imageRect)
                }
            })
        }
        
        if isActiveUpdated {
            let alphaTransition = ContainedViewLayoutTransition.animated(duration: 0.2, curve: .easeInOut)
            alphaTransition.updateAlpha(node: self.iconNode, alpha: isActive ? 1.0 : 0.3)
            if let animationNode = self.animationNode {
                alphaTransition.updateAlpha(node: animationNode, alpha: isActive ? 1.0 : 0.3)
            }
            alphaTransition.updateAlpha(node: self.textNode, alpha: isActive ? 1.0 : 0.3)
        }
        
        self.textNode.attributedText = NSAttributedString(string: text.lowercased(), font: Font.regular(11.0), textColor: presentationData.theme.list.itemAccentColor)
        self.accessibilityLabel = text
        let titleSize = self.textNode.updateLayout(CGSize(width: 120.0, height: .greatestFiniteMagnitude))
        
        transition.updateFrame(node: self.containerNode, frame: CGRect(origin: CGPoint(), size: size))
        transition.updateFrame(node: self.backgroundNode, frame: CGRect(origin: CGPoint(), size: size))
        transition.updateFrame(node: self.iconNode, frame: CGRect(origin: CGPoint(x: floor((size.width - iconSize.width) / 2.0), y: 1.0), size: iconSize))
        if let animationNode = self.animationNode {
            transition.updateFrame(node: animationNode, frame: CGRect(origin: CGPoint(x: floor((size.width - iconSize.width) / 2.0), y: 1.0), size: iconSize))
        }
        transition.updateFrameAdditiveToCenter(node: self.textNode, frame: CGRect(origin: CGPoint(x: floor((size.width - titleSize.width) / 2.0), y: size.height - titleSize.height - 9.0), size: titleSize))
        
        self.referenceNode.frame = self.containerNode.bounds
    }
}

final class PeerInfoHeaderNavigationTransition {
    let sourceNavigationBar: NavigationBar
    let sourceTitleView: ChatTitleView
    let sourceTitleFrame: CGRect
    let sourceSubtitleFrame: CGRect
    let fraction: CGFloat
    
    init(sourceNavigationBar: NavigationBar, sourceTitleView: ChatTitleView, sourceTitleFrame: CGRect, sourceSubtitleFrame: CGRect, fraction: CGFloat) {
        self.sourceNavigationBar = sourceNavigationBar
        self.sourceTitleView = sourceTitleView
        self.sourceTitleFrame = sourceTitleFrame
        self.sourceSubtitleFrame = sourceSubtitleFrame
        self.fraction = fraction
    }
}

final class PeerInfoAvatarTransformContainerNode: ASDisplayNode {
    let context: AccountContext
    
    private let containerNode: ContextControllerSourceNode
    
    let avatarNode: AvatarNode
    fileprivate var videoNode: UniversalVideoNode?
    private var videoContent: NativeVideoContent?
    private var videoStartTimestamp: Double?
    
    var isExpanded: Bool = false
    var canAttachVideo: Bool = true {
        didSet {
            if oldValue != self.canAttachVideo {
                self.videoNode?.canAttachContent = !self.isExpanded && self.canAttachVideo
            }
        }
    }
    
    var tapped: (() -> Void)?
    var contextAction: ((ASDisplayNode, ContextGesture?) -> Void)?
    
    private var isFirstAvatarLoading = true
    var item: PeerInfoAvatarListItem?
    
    private let playbackStartDisposable = MetaDisposable()
    
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
    }
    
    deinit {
        self.playbackStartDisposable.dispose()
    }
    
    @objc private func tapGesture(_ recognizer: UITapGestureRecognizer) {
        if case .ended = recognizer.state {
            self.tapped?()
        }
    }
        
    func updateTransitionFraction(_ fraction: CGFloat, transition: ContainedViewLayoutTransition) {
        if let videoNode = self.videoNode {
            if case .immediate = transition, fraction == 1.0 {
                return
            }
            if fraction > 0.0 {
                self.videoNode?.pause()
            } else {
                self.videoNode?.play()
            }
            transition.updateAlpha(node: videoNode, alpha: 1.0 - fraction)
        }
    }
        
    var removedPhotoResourceIds = Set<String>()
    func update(peer: Peer?, item: PeerInfoAvatarListItem?, theme: PresentationTheme, avatarSize: CGFloat, isExpanded: Bool, isSettings: Bool) {
        if let peer = peer {
            let previousItem = self.item
            var item = item
            self.item = item
            
            var overrideImage: AvatarNodeImageOverride?
            if peer.isDeleted {
                overrideImage = .deletedIcon
            } else if let previousItem = previousItem, item == nil {
                if case let .image(_, representations, _, _) = previousItem, let rep = representations.last {
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
            
            self.avatarNode.setPeer(context: self.context, theme: theme, peer: EnginePeer(peer), overrideImage: overrideImage, synchronousLoad: self.isFirstAvatarLoading, displayDimensions: CGSize(width: avatarSize, height: avatarSize), storeUnrounded: true)
            self.isFirstAvatarLoading = false
            
            self.containerNode.frame = CGRect(origin: CGPoint(x: -avatarSize / 2.0, y: -avatarSize / 2.0), size: CGSize(width: avatarSize, height: avatarSize))
            self.avatarNode.frame = self.containerNode.bounds
            self.avatarNode.font = avatarPlaceholderFont(size: floor(avatarSize * 16.0 / 37.0))

            if let item = item {
                let representations: [ImageRepresentationWithReference]
                let videoRepresentations: [VideoRepresentationWithReference]
                let immediateThumbnailData: Data?
                var videoId: Int64
                switch item {
                case .custom:
                    representations = []
                    videoRepresentations = []
                    immediateThumbnailData = nil
                    videoId = 0
                case let .topImage(topRepresentations, videoRepresentationsValue, immediateThumbnail):
                    representations = topRepresentations
                    videoRepresentations = videoRepresentationsValue
                    immediateThumbnailData = immediateThumbnail
                    videoId = peer.id.id._internalGetInt64Value()
                    if let resource = videoRepresentations.first?.representation.resource as? CloudPhotoSizeMediaResource {
                        videoId = videoId &+ resource.photoId
                    }
                case let .image(reference, imageRepresentations, videoRepresentationsValue, immediateThumbnail):
                    representations = imageRepresentations
                    videoRepresentations = videoRepresentationsValue
                    immediateThumbnailData = immediateThumbnail
                    if case let .cloud(imageId, _, _) = reference {
                        videoId = imageId
                    } else {
                        videoId = peer.id.id._internalGetInt64Value()
                    }
                }
                
                self.containerNode.isGestureEnabled = !isSettings
                
                if let video = videoRepresentations.last, let peerReference = PeerReference(peer) {
                    let videoFileReference = FileMediaReference.avatarList(peer: peerReference, media: TelegramMediaFile(fileId: MediaId(namespace: Namespaces.Media.LocalFile, id: 0), partialReference: nil, resource: video.representation.resource, previewRepresentations: representations.map { $0.representation }, videoThumbnails: [], immediateThumbnailData: immediateThumbnailData, mimeType: "video/mp4", size: nil, attributes: [.Animated, .Video(duration: 0, size: video.representation.dimensions, flags: [])]))
                    let videoContent = NativeVideoContent(id: .profileVideo(videoId, nil), fileReference: videoFileReference, streamVideo: isMediaStreamable(resource: video.representation.resource) ? .conservative : .none, loopVideo: true, enableSound: false, fetchAutomatically: true, onlyFullSizeThumbnail: false, useLargeThumbnail: true, autoFetchFullSizeThumbnail: true, startTimestamp: video.representation.startTimestamp, continuePlayingWithoutSoundOnLostAudioSession: false, placeholderColor: .clear, captureProtected: peer.isCopyProtectionEnabled)
                    if videoContent.id != self.videoContent?.id {
                        self.videoNode?.removeFromSupernode()
                        
                        let mediaManager = self.context.sharedContext.mediaManager
                        let videoNode = UniversalVideoNode(postbox: self.context.account.postbox, audioSession: mediaManager.audioSession, manager: mediaManager.universalVideoManager, decoration: GalleryVideoDecoration(), content: videoContent, priority: .embedded)
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
                        
                        let maskPath = UIBezierPath(ovalIn: CGRect(origin: CGPoint(), size: self.avatarNode.frame.size))
                        let shape = CAShapeLayer()
                        shape.path = maskPath.cgPath
                        videoNode.layer.mask = shape
                                                            
                        self.containerNode.addSubnode(videoNode)
                    }
                } else if let videoNode = self.videoNode {
                    self.videoContent = nil
                    self.videoNode = nil
                    
                    videoNode.removeFromSupernode()
                }
            } else if let videoNode = self.videoNode {
                self.videoContent = nil
                self.videoNode = nil
                
                videoNode.removeFromSupernode()
                
                self.containerNode.isGestureEnabled = false
            }
            
            if let videoNode = self.videoNode {
                if self.canAttachVideo {
                    videoNode.updateLayout(size: self.avatarNode.frame.size, transition: .immediate)
                }
                videoNode.frame = self.avatarNode.frame
                
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
    }
}

final class PeerInfoEditingAvatarOverlayNode: ASDisplayNode {
    private let context: AccountContext
    
    private let imageNode: ImageNode
    private let updatingAvatarOverlay: ASImageNode
    private let iconNode: ASImageNode
    private var statusNode: RadialStatusNode
    
    private var currentRepresentation: TelegramMediaImageRepresentation?
    
    init(context: AccountContext) {
        self.context = context
        
        self.imageNode = ImageNode(enableEmpty: true)
        
        self.updatingAvatarOverlay = ASImageNode()
        self.updatingAvatarOverlay.displayWithoutProcessing = true
        self.updatingAvatarOverlay.displaysAsynchronously = false
        self.updatingAvatarOverlay.alpha = 0.0
        
        self.statusNode = RadialStatusNode(backgroundNodeColor: UIColor(rgb: 0x000000, alpha: 0.6))
        self.statusNode.isUserInteractionEnabled = false
        
        self.iconNode = ASImageNode()
        self.iconNode.image = generateTintedImage(image: UIImage(bundleImageName: "Avatar/EditAvatarIconLarge"), color: .white)
        self.iconNode.alpha = 0.0
        
        super.init()
        
        self.imageNode.frame = CGRect(origin: CGPoint(x: -50.0, y: -50.0), size: CGSize(width: 100.0, height: 100.0))
        self.updatingAvatarOverlay.frame = self.imageNode.frame
        
        let radialStatusSize: CGFloat = 50.0
        let imagePosition = self.imageNode.position
        self.statusNode.frame = CGRect(origin: CGPoint(x: floor(imagePosition.x - radialStatusSize / 2.0), y: floor(imagePosition.y - radialStatusSize / 2.0)), size: CGSize(width: radialStatusSize, height: radialStatusSize))
        
        if let image = self.iconNode.image {
            self.iconNode.frame = CGRect(origin: CGPoint(x: floor(imagePosition.x - image.size.width / 2.0), y: floor(imagePosition.y - image.size.height / 2.0)), size: image.size)
        }
        
        self.addSubnode(self.imageNode)
        self.addSubnode(self.updatingAvatarOverlay)
        self.addSubnode(self.statusNode)
    }
    
    func updateTransitionFraction(_ fraction: CGFloat, transition: ContainedViewLayoutTransition) {
        transition.updateAlpha(node: self, alpha: 1.0 - fraction)
    }
    
    func update(peer: Peer?, item: PeerInfoAvatarListItem?, updatingAvatar: PeerInfoUpdatingAvatar?, uploadProgress: CGFloat?, theme: PresentationTheme, avatarSize: CGFloat, isEditing: Bool) {
        guard let peer = peer else {
            return
        }
        
        self.imageNode.frame = CGRect(origin: CGPoint(x: -avatarSize / 2.0, y: -avatarSize / 2.0), size: CGSize(width: avatarSize, height: avatarSize))
        self.updatingAvatarOverlay.frame = self.imageNode.frame
        
        let transition = ContainedViewLayoutTransition.animated(duration: 0.2, curve: .linear)
        
        if canEditPeerInfo(context: self.context, peer: peer) {
            var overlayHidden = true
            if let updatingAvatar = updatingAvatar {
                overlayHidden = false
                
                self.statusNode.transitionToState(.progress(color: .white, lineWidth: nil, value: max(0.027, uploadProgress ?? 0.0), cancelEnabled: true, animateRotation: true))
                
                if case let .image(representation) = updatingAvatar {
                    if representation != self.currentRepresentation {
                        self.currentRepresentation = representation
                        if let signal = peerAvatarImage(account: context.account, peerReference: nil, authorOfMessage: nil, representation: representation, displayDimensions: CGSize(width: avatarSize, height: avatarSize), emptyColor: nil, synchronousLoad: false, provideUnrounded: false) {
                            self.imageNode.setSignal(signal |> map { $0?.0 })
                        }
                    }
                }
                
                transition.updateAlpha(node: self.updatingAvatarOverlay, alpha: 1.0)
            } else {
                let targetOverlayAlpha: CGFloat = 0.0
                if self.updatingAvatarOverlay.alpha != targetOverlayAlpha {
                    let update = {
                        self.statusNode.transitionToState(.none)
                        self.currentRepresentation = nil
                        self.imageNode.setSignal(.single(nil))
                        transition.updateAlpha(node: self.updatingAvatarOverlay, alpha: overlayHidden ? 0.0 : 1.0)
                    }
                    Queue.mainQueue().after(0.3) {
                        update()
                    }
                }
            }
            if !overlayHidden && self.updatingAvatarOverlay.image == nil {
                self.updatingAvatarOverlay.image = generateFilledCircleImage(diameter: avatarSize, color: UIColor(white: 0.0, alpha: 0.4), backgroundColor: nil)
            }
        } else {
            self.statusNode.transitionToState(.none)
            self.currentRepresentation = nil
            transition.updateAlpha(node: self.iconNode, alpha: 0.0)
            transition.updateAlpha(node: self.updatingAvatarOverlay, alpha: 0.0)
        }
    }
}

final class PeerInfoEditingAvatarNode: ASDisplayNode {
    private let context: AccountContext
    let avatarNode: AvatarNode
    fileprivate var videoNode: UniversalVideoNode?
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
    func update(peer: Peer?, item: PeerInfoAvatarListItem?, updatingAvatar: PeerInfoUpdatingAvatar?, uploadProgress: CGFloat?, theme: PresentationTheme, avatarSize: CGFloat, isEditing: Bool) {
        guard let peer = peer else {
            return
        }
        
        let canEdit = canEditPeerInfo(context: self.context, peer: peer)

        let previousItem = self.item
        var item = item
        self.item = item
                        
        let overrideImage: AvatarNodeImageOverride?
        if canEdit, peer.profileImageRepresentations.isEmpty {
            overrideImage = .editAvatarIcon(forceNone: true)
        } else if let previousItem = previousItem, item == nil {
            if case let .image(_, representations, _, _) = previousItem, let rep = representations.last {
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
        self.avatarNode.setPeer(context: self.context, theme: theme, peer: EnginePeer(peer), overrideImage: overrideImage, synchronousLoad: false, displayDimensions: CGSize(width: avatarSize, height: avatarSize))
        self.avatarNode.frame = CGRect(origin: CGPoint(x: -avatarSize / 2.0, y: -avatarSize / 2.0), size: CGSize(width: avatarSize, height: avatarSize))
        
        if let item = item {
            let representations: [ImageRepresentationWithReference]
            let videoRepresentations: [VideoRepresentationWithReference]
            let immediateThumbnailData: Data?
            var id: Int64
            switch item {
                case .custom:
                    representations = []
                    videoRepresentations = []
                    immediateThumbnailData = nil
                    id = 0
                case let .topImage(topRepresentations, videoRepresentationsValue, immediateThumbnail):
                    representations = topRepresentations
                    videoRepresentations = videoRepresentationsValue
                    immediateThumbnailData = immediateThumbnail
                    id = peer.id.id._internalGetInt64Value()
                    if let resource = videoRepresentations.first?.representation.resource as? CloudPhotoSizeMediaResource {
                        id = id &+ resource.photoId
                    }
                case let .image(reference, imageRepresentations, videoRepresentationsValue, immediateThumbnail):
                    representations = imageRepresentations
                    videoRepresentations = videoRepresentationsValue
                    immediateThumbnailData = immediateThumbnail
                    if case let .cloud(imageId, _, _) = reference {
                        id = imageId
                    } else {
                        id = peer.id.id._internalGetInt64Value()
                    }
            }
            
            if let video = videoRepresentations.last, let peerReference = PeerReference(peer) {
                let videoFileReference = FileMediaReference.avatarList(peer: peerReference, media: TelegramMediaFile(fileId: MediaId(namespace: Namespaces.Media.LocalFile, id: 0), partialReference: nil, resource: video.representation.resource, previewRepresentations: representations.map { $0.representation }, videoThumbnails: [], immediateThumbnailData: immediateThumbnailData, mimeType: "video/mp4", size: nil, attributes: [.Animated, .Video(duration: 0, size: video.representation.dimensions, flags: [])]))
                let videoContent = NativeVideoContent(id: .profileVideo(id, nil), fileReference: videoFileReference, streamVideo: isMediaStreamable(resource: video.representation.resource) ? .conservative : .none, loopVideo: true, enableSound: false, fetchAutomatically: true, onlyFullSizeThumbnail: false, useLargeThumbnail: true, autoFetchFullSizeThumbnail: true, startTimestamp: video.representation.startTimestamp, continuePlayingWithoutSoundOnLostAudioSession: false, placeholderColor: .clear, captureProtected: peer.isCopyProtectionEnabled)
                if videoContent.id != self.videoContent?.id {
                    self.videoNode?.removeFromSupernode()
                    
                    let mediaManager = self.context.sharedContext.mediaManager
                    let videoNode = UniversalVideoNode(postbox: self.context.account.postbox, audioSession: mediaManager.audioSession, manager: mediaManager.universalVideoManager, decoration: GalleryVideoDecoration(), content: videoContent, priority: .gallery)
                    videoNode.isUserInteractionEnabled = false
                    self.videoStartTimestamp = video.representation.startTimestamp
                    self.videoContent = videoContent
                    self.videoNode = videoNode
                    
                    let maskPath = UIBezierPath(ovalIn: CGRect(origin: CGPoint(), size: self.avatarNode.frame.size))
                    let shape = CAShapeLayer()
                    shape.path = maskPath.cgPath
                    videoNode.layer.mask = shape
                    
                    self.insertSubnode(videoNode, aboveSubnode: self.avatarNode)
                }
            } else if let videoNode = self.videoNode {
                self.videoStartTimestamp = nil
                self.videoContent = nil
                self.videoNode = nil
                
                videoNode.removeFromSupernode()
            }
        } else if let videoNode = self.videoNode {
            self.videoStartTimestamp = nil
            self.videoContent = nil
            self.videoNode = nil
            
            videoNode.removeFromSupernode()
        }
        
        if let videoNode = self.videoNode {
            if self.canAttachVideo {
                videoNode.updateLayout(size: self.avatarNode.frame.size, transition: .immediate)
            }
            videoNode.frame = self.avatarNode.frame
            
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

final class PeerInfoAvatarListNode: ASDisplayNode {
    private let isSettings: Bool
    let pinchSourceNode: PinchSourceContainerNode
    let avatarContainerNode: PeerInfoAvatarTransformContainerNode
    let listContainerTransformNode: ASDisplayNode
    let listContainerNode: PeerInfoAvatarListContainerNode
    
    let isReady = Promise<Bool>()
   
    var arguments: (Peer?, PresentationTheme, CGFloat, Bool)?
    var item: PeerInfoAvatarListItem?
    
    var itemsUpdated: (([PeerInfoAvatarListItem]) -> Void)?
    var animateOverlaysFadeIn: (() -> Void)?
    
    init(context: AccountContext, readyWhenGalleryLoads: Bool, isSettings: Bool) {
        self.isSettings = isSettings

        self.pinchSourceNode = PinchSourceContainerNode()
        
        self.avatarContainerNode = PeerInfoAvatarTransformContainerNode(context: context)
        self.listContainerTransformNode = ASDisplayNode()
        self.listContainerNode = PeerInfoAvatarListContainerNode(context: context)
        self.listContainerNode.clipsToBounds = true
        self.listContainerNode.isHidden = true
        
        super.init()

        self.addSubnode(self.pinchSourceNode)
        self.pinchSourceNode.contentNode.addSubnode(self.avatarContainerNode)
        self.listContainerTransformNode.addSubnode(self.listContainerNode)
        self.pinchSourceNode.contentNode.addSubnode(self.listContainerTransformNode)
        
        let avatarReady = (self.avatarContainerNode.avatarNode.ready
        |> mapToSignal { _ -> Signal<Bool, NoError> in
            return .complete()
        }
        |> then(.single(true)))
        
        let galleryReady = self.listContainerNode.isReady.get()
        |> filter { value in
            return value
        }
        |> take(1)
        
        let combinedSignal: Signal<Bool, NoError>
        if readyWhenGalleryLoads {
            combinedSignal = combineLatest(queue: .mainQueue(),
                avatarReady,
                galleryReady
            )
            |> map { lhs, rhs in
                return lhs && rhs
            }
        } else {
            combinedSignal = avatarReady
        }
        
        self.isReady.set(combinedSignal
        |> filter { value in
            return value
        }
        |> take(1))
        
        self.listContainerNode.itemsUpdated = { [weak self] items in
            if let strongSelf = self {
                strongSelf.item = items.first
                strongSelf.itemsUpdated?(items)
                if let (peer, theme, avatarSize, isExpanded) = strongSelf.arguments {
                    strongSelf.avatarContainerNode.update(peer: peer, item: strongSelf.item, theme: theme, avatarSize: avatarSize, isExpanded: isExpanded, isSettings: strongSelf.isSettings)
                }
            }
        }

        self.pinchSourceNode.activate = { [weak self] sourceNode in
            guard let strongSelf = self, let (_, _, _, isExpanded) = strongSelf.arguments, isExpanded else {
                return
            }
            let pinchController = PinchController(sourceNode: sourceNode, getContentAreaInScreenSpace: {
                return UIScreen.main.bounds
            })
            context.sharedContext.mainWindow?.presentInGlobalOverlay(pinchController)
            
            strongSelf.listContainerNode.bottomShadowNode.alpha = 0.0
        }

        self.pinchSourceNode.animatedOut = { [weak self] in
            guard let strongSelf = self else {
                return
            }
            strongSelf.animateOverlaysFadeIn?()
        }
    }
    
    func update(size: CGSize, avatarSize: CGFloat, isExpanded: Bool, peer: Peer?, theme: PresentationTheme, transition: ContainedViewLayoutTransition) {
        self.arguments = (peer, theme, avatarSize, isExpanded)
        self.pinchSourceNode.update(size: size, transition: transition)
        self.pinchSourceNode.frame = CGRect(origin: CGPoint(), size: size)
        self.avatarContainerNode.update(peer: peer, item: self.item, theme: theme, avatarSize: avatarSize, isExpanded: isExpanded, isSettings: self.isSettings)
    }
    
    override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        if !self.listContainerNode.isHidden {
            if let result = self.listContainerNode.view.hitTest(self.view.convert(point, to: self.listContainerNode.view), with: event) {
                return result
            }
        } else {
            if let result = self.avatarContainerNode.avatarNode.view.hitTest(self.view.convert(point, to: self.avatarContainerNode.avatarNode.view), with: event) {
                return result
            }
        }
        
        return super.hitTest(point, with: event)
    }
    
    func animateAvatarCollapse(transition: ContainedViewLayoutTransition) {
        if let currentItemNode = self.listContainerNode.currentItemNode, case .animated = transition {
            if let _ = self.avatarContainerNode.videoNode {

            } else if let unroundedImage = self.avatarContainerNode.avatarNode.unroundedImage {
                let avatarCopyView = UIImageView()
                avatarCopyView.image = unroundedImage
                avatarCopyView.frame = self.avatarContainerNode.avatarNode.frame
                avatarCopyView.center = currentItemNode.imageNode.position
                currentItemNode.view.addSubview(avatarCopyView)
                let scale = currentItemNode.imageNode.bounds.height / avatarCopyView.bounds.height
                avatarCopyView.layer.transform = CATransform3DMakeScale(scale, scale, scale)
                avatarCopyView.alpha = 0.0
                transition.updateAlpha(layer: avatarCopyView.layer, alpha: 1.0, completion: { [weak avatarCopyView] _ in
                    Queue.mainQueue().after(0.1, {
                        avatarCopyView?.removeFromSuperview()
                    })
                })
            }
        }
    }
}

private enum MoreIconNodeState: Equatable {
    case more
    case search
    case moreToSearch(Float)
}

private final class MoreIconNode: ManagedAnimationNode {
    private let duration: Double = 0.21
    private var iconState: MoreIconNodeState = .more
    
    init() {
        super.init(size: CGSize(width: 30.0, height: 30.0))
        
        self.trackTo(item: ManagedAnimationItem(source: .local("anim_moretosearch"), frames: .range(startFrame: 0, endFrame: 0), duration: 0.0))
    }
        
    func play() {
        if case .more = self.iconState {
            self.trackTo(item: ManagedAnimationItem(source: .local("anim_moredots"), frames: .range(startFrame: 0, endFrame: 46), duration: 0.76))
        }
    }
    
    func enqueueState(_ state: MoreIconNodeState, animated: Bool) {
        guard self.iconState != state else {
            return
        }
        
        let previousState = self.iconState
        self.iconState = state
        
        let source = ManagedAnimationSource.local("anim_moretosearch")
        
        let totalLength: Int = 90
        if animated {
            switch previousState {
                case .more:
                    switch state {
                        case .more:
                            break
                        case .search:
                            self.trackTo(item: ManagedAnimationItem(source: source, frames: .range(startFrame: 0, endFrame: totalLength), duration: self.duration))
                        case let .moreToSearch(progress):
                            let frame = Int(progress * Float(totalLength))
                            let duration = self.duration * Double(progress)
                            self.trackTo(item: ManagedAnimationItem(source: source, frames: .range(startFrame: 0, endFrame: frame), duration: duration))
                    }
                case .search:
                    switch state {
                        case .more:
                            self.trackTo(item: ManagedAnimationItem(source: source, frames: .range(startFrame: totalLength, endFrame: 0), duration: self.duration))
                        case .search:
                            break
                        case let .moreToSearch(progress):
                            let frame = Int(progress * Float(totalLength))
                            let duration = self.duration * Double((1.0 - progress))
                            self.trackTo(item: ManagedAnimationItem(source: source, frames: .range(startFrame: totalLength, endFrame: frame), duration: duration))
                    }
                case let .moreToSearch(currentProgress):
                    let currentFrame = Int(currentProgress * Float(totalLength))
                    switch state {
                        case .more:
                            let duration = self.duration * Double(currentProgress)
                            self.trackTo(item: ManagedAnimationItem(source: source, frames: .range(startFrame: currentFrame, endFrame: 0), duration: duration))
                        case .search:
                            let duration = self.duration * (1.0 - Double(currentProgress))
                            self.trackTo(item: ManagedAnimationItem(source: source, frames: .range(startFrame: currentFrame, endFrame: totalLength), duration: duration))
                        case let .moreToSearch(progress):
                            let frame = Int(progress * Float(totalLength))
                            let duration = self.duration * Double(abs(currentProgress - progress))
                            self.trackTo(item: ManagedAnimationItem(source: source, frames: .range(startFrame: currentFrame, endFrame: frame), duration: duration))
                    }
            }
        } else {
            switch state {
                case .more:
                    self.trackTo(item: ManagedAnimationItem(source: source, frames: .range(startFrame: 0, endFrame: 0), duration: 0.0))
                case .search:
                    self.trackTo(item: ManagedAnimationItem(source: source, frames: .range(startFrame: totalLength, endFrame: totalLength), duration: 0.0))
                case let .moreToSearch(progress):
                    let frame = Int(progress * Float(totalLength))
                    self.trackTo(item: ManagedAnimationItem(source: source, frames: .range(startFrame: frame, endFrame: frame), duration: 0.0))
            }
        }
    }
}

final class PeerInfoHeaderNavigationButton: HighlightableButtonNode {
    let containerNode: ContextControllerSourceNode
    let contextSourceNode: ContextReferenceContentNode
    private let regularTextNode: ImmediateTextNode
    private let whiteTextNode: ImmediateTextNode
    private let iconNode: ASImageNode
    private var animationNode: MoreIconNode?
    
    private var key: PeerInfoHeaderNavigationButtonKey?
    private var theme: PresentationTheme?
    
    var isWhite: Bool = false {
        didSet {
            if self.isWhite != oldValue {
                if case .qrCode = self.key, let theme = self.theme {
                    self.iconNode.image = self.isWhite ? generateTintedImage(image: PresentationResourcesRootController.navigationQrCodeIcon(theme), color: .white) : PresentationResourcesRootController.navigationQrCodeIcon(theme)
                }
                
                self.regularTextNode.isHidden = self.isWhite
                self.whiteTextNode.isHidden = !self.isWhite
            }
        }
    }
    
    var action: ((ASDisplayNode, ContextGesture?) -> Void)?
    
    init() {
        self.contextSourceNode = ContextReferenceContentNode()
        self.containerNode = ContextControllerSourceNode()
        self.containerNode.animateScale = false
        
        self.regularTextNode = ImmediateTextNode()
        self.whiteTextNode = ImmediateTextNode()
        self.whiteTextNode.isHidden = true
        
        self.iconNode = ASImageNode()
        self.iconNode.displaysAsynchronously = false
        self.iconNode.displayWithoutProcessing = true
        
        super.init(pointerStyle: .default)
        
        self.isAccessibilityElement = true
        self.accessibilityTraits = .button
        
        self.containerNode.addSubnode(self.contextSourceNode)
        self.contextSourceNode.addSubnode(self.regularTextNode)
        self.contextSourceNode.addSubnode(self.whiteTextNode)
        self.contextSourceNode.addSubnode(self.iconNode)

        self.addSubnode(self.containerNode)
        
        self.containerNode.activated = { [weak self] gesture, _ in
            guard let strongSelf = self else {
                return
            }
            strongSelf.action?(strongSelf.contextSourceNode, gesture)
        }
        
        self.addTarget(self, action: #selector(self.pressed), forControlEvents: .touchUpInside)
    }
    
    @objc private func pressed() {
        self.animationNode?.play()
        self.action?(self.contextSourceNode, nil)
    }
    
    func update(key: PeerInfoHeaderNavigationButtonKey, presentationData: PresentationData, height: CGFloat) -> CGSize {
        let textSize: CGSize
        let isFirstTime = self.key == nil
        if self.key != key || self.theme !== presentationData.theme {
            self.key = key
            self.theme = presentationData.theme
            
            let text: String
            var icon: UIImage?
            var isBold = false
            var isGestureEnabled = false
            var isAnimation = false
            var animationState: MoreIconNodeState = .more
            switch key {
                case .edit:
                    text = presentationData.strings.Common_Edit
                case .done, .cancel, .selectionDone:
                    text = presentationData.strings.Common_Done
                    isBold = true
                case .select:
                    text = presentationData.strings.Common_Select
                case .search:
                    text = ""
                    icon = nil// PresentationResourcesRootController.navigationCompactSearchIcon(presentationData.theme)
                    isAnimation = true
                    animationState = .search
                case .editPhoto:
                    text = presentationData.strings.Settings_EditPhoto
                case .editVideo:
                    text = presentationData.strings.Settings_EditVideo
                case .more:
                    text = ""
                    icon = nil// PresentationResourcesRootController.navigationMoreCircledIcon(presentationData.theme)
                    isGestureEnabled = true
                    isAnimation = true
                    animationState = .more
                case .qrCode:
                    text = ""
                    icon = PresentationResourcesRootController.navigationQrCodeIcon(presentationData.theme)
                case .moreToSearch:
                    text = ""
            }
            self.accessibilityLabel = text
            self.containerNode.isGestureEnabled = isGestureEnabled
            
            let font: UIFont = isBold ? Font.semibold(17.0) : Font.regular(17.0)
            
            self.regularTextNode.attributedText = NSAttributedString(string: text, font: font, textColor: presentationData.theme.rootController.navigationBar.accentTextColor)
            self.whiteTextNode.attributedText = NSAttributedString(string: text, font: font, textColor: .white)
            self.iconNode.image = icon
            
            if isAnimation {
                self.iconNode.isHidden = true
                let animationNode: MoreIconNode
                if let current = self.animationNode {
                    animationNode = current
                } else {
                    animationNode = MoreIconNode()
                    self.animationNode = animationNode
                    self.contextSourceNode.addSubnode(animationNode)
                }
                animationNode.customColor = presentationData.theme.rootController.navigationBar.accentTextColor
                animationNode.enqueueState(animationState, animated: !isFirstTime)
            } else {
                self.iconNode.isHidden = false
                if let current = self.animationNode {
                    self.animationNode = nil
                    current.removeFromSupernode()
                }
            }
            
            textSize = self.regularTextNode.updateLayout(CGSize(width: 200.0, height: .greatestFiniteMagnitude))
            let _ = self.whiteTextNode.updateLayout(CGSize(width: 200.0, height: .greatestFiniteMagnitude))
        } else {
            textSize = self.regularTextNode.bounds.size
        }
        
        let inset: CGFloat = 0.0
        
        let textFrame = CGRect(origin: CGPoint(x: inset, y: floor((height - textSize.height) / 2.0)), size: textSize)
        self.regularTextNode.frame = textFrame
        self.whiteTextNode.frame = textFrame
        
        if let animationNode = self.animationNode {
            let animationSize = CGSize(width: 30.0, height: 30.0)
            
            animationNode.frame = CGRect(origin: CGPoint(x: inset, y: floor((height - animationSize.height) / 2.0)), size: animationSize)
            
            let size = CGSize(width: animationSize.width + inset * 2.0, height: height)
            self.containerNode.frame = CGRect(origin: CGPoint(), size: size)
            self.contextSourceNode.frame = CGRect(origin: CGPoint(), size: size)
            return size
        } else if let image = self.iconNode.image {
            self.iconNode.frame = CGRect(origin: CGPoint(x: inset, y: floor((height - image.size.height) / 2.0)), size: image.size)
            
            let size = CGSize(width: image.size.width + inset * 2.0, height: height)
            self.containerNode.frame = CGRect(origin: CGPoint(), size: size)
            self.contextSourceNode.frame = CGRect(origin: CGPoint(), size: size)
            return size
        } else {
            let size = CGSize(width: textSize.width + inset * 2.0, height: height)
            self.containerNode.frame = CGRect(origin: CGPoint(), size: size)
            self.contextSourceNode.frame = CGRect(origin: CGPoint(), size: size)
            return size
        }
    }
}

enum PeerInfoHeaderNavigationButtonKey {
    case edit
    case done
    case cancel
    case select
    case selectionDone
    case search
    case editPhoto
    case editVideo
    case more
    case qrCode
    case moreToSearch
}

struct PeerInfoHeaderNavigationButtonSpec: Equatable {
    let key: PeerInfoHeaderNavigationButtonKey
    let isForExpandedView: Bool
}

final class PeerInfoHeaderNavigationButtonContainerNode: ASDisplayNode {
    private var presentationData: PresentationData?
    private(set) var leftButtonNodes: [PeerInfoHeaderNavigationButtonKey: PeerInfoHeaderNavigationButton] = [:]
    private(set) var rightButtonNodes: [PeerInfoHeaderNavigationButtonKey: PeerInfoHeaderNavigationButton] = [:]
    
    private var currentLeftButtons: [PeerInfoHeaderNavigationButtonSpec] = []
    private var currentRightButtons: [PeerInfoHeaderNavigationButtonSpec] = []
    
    var isWhite: Bool = false {
        didSet {
            if self.isWhite != oldValue {
                for (_, buttonNode) in self.leftButtonNodes {
                    buttonNode.isWhite = self.isWhite
                }
                for (_, buttonNode) in self.rightButtonNodes {
                    buttonNode.isWhite = self.isWhite
                }
            }
        }
    }
    
    var performAction: ((PeerInfoHeaderNavigationButtonKey, ContextReferenceContentNode?, ContextGesture?) -> Void)?
    
    func update(size: CGSize, presentationData: PresentationData, leftButtons: [PeerInfoHeaderNavigationButtonSpec], rightButtons: [PeerInfoHeaderNavigationButtonSpec], expandFraction: CGFloat, transition: ContainedViewLayoutTransition) {
        let maximumExpandOffset: CGFloat = 14.0
        let expandOffset: CGFloat = -expandFraction * maximumExpandOffset
        
        if self.currentLeftButtons != leftButtons || presentationData.strings !== self.presentationData?.strings {
            self.currentLeftButtons = leftButtons
            
            var nextRegularButtonOrigin = 16.0
            var nextExpandedButtonOrigin = 16.0
            for spec in leftButtons.reversed() {
                let buttonNode: PeerInfoHeaderNavigationButton
                var wasAdded = false
                if let current = self.leftButtonNodes[spec.key] {
                    buttonNode = current
                } else {
                    wasAdded = true
                    buttonNode = PeerInfoHeaderNavigationButton()
                    self.leftButtonNodes[spec.key] = buttonNode
                    self.addSubnode(buttonNode)
                    buttonNode.isWhite = self.isWhite
                    buttonNode.action = { [weak self] _, gesture in
                        guard let strongSelf = self, let buttonNode = strongSelf.leftButtonNodes[spec.key] else {
                            return
                        }
                        strongSelf.performAction?(spec.key, buttonNode.contextSourceNode, gesture)
                    }
                }
                let buttonSize = buttonNode.update(key: spec.key, presentationData: presentationData, height: size.height)
                var nextButtonOrigin = spec.isForExpandedView ? nextExpandedButtonOrigin : nextRegularButtonOrigin
                let buttonFrame = CGRect(origin: CGPoint(x: nextButtonOrigin, y: expandOffset + (spec.isForExpandedView ? maximumExpandOffset : 0.0)), size: buttonSize)
                nextButtonOrigin += buttonSize.width + 4.0
                if spec.isForExpandedView {
                    nextExpandedButtonOrigin = nextButtonOrigin
                } else {
                    nextRegularButtonOrigin = nextButtonOrigin
                }
                let alphaFactor: CGFloat = spec.isForExpandedView ? expandFraction : (1.0 - expandFraction)
                if wasAdded {
                    buttonNode.frame = buttonFrame
                    buttonNode.alpha = 0.0
                    transition.updateAlpha(node: buttonNode, alpha: alphaFactor * alphaFactor)
                } else {
                    transition.updateFrameAdditiveToCenter(node: buttonNode, frame: buttonFrame)
                    transition.updateAlpha(node: buttonNode, alpha: alphaFactor * alphaFactor)
                }
            }
            var removeKeys: [PeerInfoHeaderNavigationButtonKey] = []
            for (key, _) in self.leftButtonNodes {
                if !leftButtons.contains(where: { $0.key == key }) {
                    removeKeys.append(key)
                }
            }
            for key in removeKeys {
                if let buttonNode = self.leftButtonNodes.removeValue(forKey: key) {
                    buttonNode.removeFromSupernode()
                }
            }
        } else {
            var nextRegularButtonOrigin = 16.0
            var nextExpandedButtonOrigin = 16.0
            for spec in leftButtons.reversed() {
                if let buttonNode = self.leftButtonNodes[spec.key] {
                    let buttonSize = buttonNode.bounds.size
                    var nextButtonOrigin = spec.isForExpandedView ? nextExpandedButtonOrigin : nextRegularButtonOrigin
                    let buttonFrame = CGRect(origin: CGPoint(x: nextButtonOrigin, y: expandOffset + (spec.isForExpandedView ? maximumExpandOffset : 0.0)), size: buttonSize)
                    nextButtonOrigin += buttonSize.width + 4.0
                    if spec.isForExpandedView {
                        nextExpandedButtonOrigin = nextButtonOrigin
                    } else {
                        nextRegularButtonOrigin = nextButtonOrigin
                    }
                    transition.updateFrameAdditiveToCenter(node: buttonNode, frame: buttonFrame)
                    let alphaFactor: CGFloat = spec.isForExpandedView ? expandFraction : (1.0 - expandFraction)
                    
                    var buttonTransition = transition
                    if case let .animated(duration, curve) = buttonTransition, alphaFactor == 0.0 {
                        buttonTransition = .animated(duration: duration * 0.25, curve: curve)
                    }
                    buttonTransition.updateAlpha(node: buttonNode, alpha: alphaFactor * alphaFactor)
                }
            }
        }
        
        if self.currentRightButtons != rightButtons || presentationData.strings !== self.presentationData?.strings {
            self.currentRightButtons = rightButtons
            
            var nextRegularButtonOrigin = size.width - 16.0
            var nextExpandedButtonOrigin = size.width - 16.0
            for spec in rightButtons.reversed() {
                let buttonNode: PeerInfoHeaderNavigationButton
                var wasAdded = false
                
                var key = spec.key
                if key == .more || key == .search {
                    key = .moreToSearch
                }
                
                if let current = self.rightButtonNodes[key] {
                    buttonNode = current
                } else {
                    wasAdded = true
                    buttonNode = PeerInfoHeaderNavigationButton()
                    self.rightButtonNodes[key] = buttonNode
                    self.addSubnode(buttonNode)
                    buttonNode.isWhite = self.isWhite
                }
                buttonNode.action = { [weak self] _, gesture in
                    guard let strongSelf = self, let buttonNode = strongSelf.rightButtonNodes[key] else {
                        return
                    }
                    strongSelf.performAction?(spec.key, buttonNode.contextSourceNode, gesture)
                }
                let buttonSize = buttonNode.update(key: spec.key, presentationData: presentationData, height: size.height)
                var nextButtonOrigin = spec.isForExpandedView ? nextExpandedButtonOrigin : nextRegularButtonOrigin
                let buttonFrame = CGRect(origin: CGPoint(x: nextButtonOrigin - buttonSize.width, y: expandOffset + (spec.isForExpandedView ? maximumExpandOffset : 0.0)), size: buttonSize)
                nextButtonOrigin -= buttonSize.width + 4.0
                if spec.isForExpandedView {
                    nextExpandedButtonOrigin = nextButtonOrigin
                } else {
                    nextRegularButtonOrigin = nextButtonOrigin
                }
                let alphaFactor: CGFloat = spec.isForExpandedView ? expandFraction : (1.0 - expandFraction)
                if wasAdded {
                    if key == .moreToSearch {
                        buttonNode.layer.animateScale(from: 0.001, to: 1.0, duration: 0.2)
                    }
                    
                    buttonNode.frame = buttonFrame
                    buttonNode.alpha = 0.0
                    transition.updateAlpha(node: buttonNode, alpha: alphaFactor * alphaFactor)
                } else {
                    transition.updateFrameAdditiveToCenter(node: buttonNode, frame: buttonFrame)
                    transition.updateAlpha(node: buttonNode, alpha: alphaFactor * alphaFactor)
                }
            }
            var removeKeys: [PeerInfoHeaderNavigationButtonKey] = []
            for (key, _) in self.rightButtonNodes {
                if key == .moreToSearch {
                    if !rightButtons.contains(where: { $0.key == .more || $0.key == .search }) {
                        removeKeys.append(key)
                    }
                } else if !rightButtons.contains(where: { $0.key == key }) {
                    removeKeys.append(key)
                }
            }
            for key in removeKeys {
                if let buttonNode = self.rightButtonNodes.removeValue(forKey: key) {
                    if key == .moreToSearch {
                        buttonNode.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.2, removeOnCompletion: false, completion: { [weak buttonNode] _ in
                            buttonNode?.removeFromSupernode()
                        })
                        buttonNode.layer.animateScale(from: 1.0, to: 0.001, duration: 0.2, removeOnCompletion: false)
                    } else {
                        buttonNode.removeFromSupernode()
                    }
                }
            }
        } else {
            var nextRegularButtonOrigin = size.width - 16.0
            var nextExpandedButtonOrigin = size.width - 16.0
                        
            for spec in rightButtons.reversed() {
                var key = spec.key
                if key == .more || key == .search {
                    key = .moreToSearch
                }
                
                if let buttonNode = self.rightButtonNodes[key] {
                    let buttonSize = buttonNode.bounds.size
                    var nextButtonOrigin = spec.isForExpandedView ? nextExpandedButtonOrigin : nextRegularButtonOrigin
                    let buttonFrame = CGRect(origin: CGPoint(x: nextButtonOrigin - buttonSize.width, y: expandOffset + (spec.isForExpandedView ? maximumExpandOffset : 0.0)), size: buttonSize)
                    nextButtonOrigin -= buttonSize.width + 4.0
                    if spec.isForExpandedView {
                        nextExpandedButtonOrigin = nextButtonOrigin
                    } else {
                        nextRegularButtonOrigin = nextButtonOrigin
                    }
                    transition.updateFrameAdditiveToCenter(node: buttonNode, frame: buttonFrame)
                    let alphaFactor: CGFloat = spec.isForExpandedView ? expandFraction : (1.0 - expandFraction)
                    
                    var buttonTransition = transition
                    if case let .animated(duration, curve) = buttonTransition, alphaFactor == 0.0 {
                        buttonTransition = .animated(duration: duration * 0.25, curve: curve)
                    }
                    buttonTransition.updateAlpha(node: buttonNode, alpha: alphaFactor * alphaFactor)
                }
            }
        }
        self.presentationData = presentationData
    }
}

final class PeerInfoHeaderRegularContentNode: ASDisplayNode {
    
}

enum PeerInfoHeaderTextFieldNodeKey: Equatable {
    case firstName
    case lastName
    case title
    case description
}

protocol PeerInfoHeaderTextFieldNode: ASDisplayNode {
    var text: String { get }
    
    func update(width: CGFloat, safeInset: CGFloat, isSettings: Bool, hasPrevious: Bool, hasNext: Bool, placeholder: String, isEnabled: Bool, presentationData: PresentationData, updateText: String?) -> CGFloat
}

final class PeerInfoHeaderSingleLineTextFieldNode: ASDisplayNode, PeerInfoHeaderTextFieldNode, UITextFieldDelegate {
    private let backgroundNode: ASDisplayNode
    private let textNode: TextFieldNode
    private let measureTextNode: ImmediateTextNode
    private let clearIconNode: ASImageNode
    private let clearButtonNode: HighlightableButtonNode
    private let topSeparator: ASDisplayNode
    private let maskNode: ASImageNode
    
    private var theme: PresentationTheme?
    
    var text: String {
        return self.textNode.textField.text ?? ""
    }
    
    override init() {
        self.backgroundNode = ASDisplayNode()
        
        self.textNode = TextFieldNode()
        self.measureTextNode = ImmediateTextNode()
        self.measureTextNode.maximumNumberOfLines = 0
        
        self.clearIconNode = ASImageNode()
        self.clearIconNode.isLayerBacked = true
        self.clearIconNode.displayWithoutProcessing = true
        self.clearIconNode.displaysAsynchronously = false
        self.clearIconNode.isHidden = true
        
        self.clearButtonNode = HighlightableButtonNode()
        self.clearButtonNode.isHidden = true
        
        self.topSeparator = ASDisplayNode()
        
        self.maskNode = ASImageNode()
        self.maskNode.isUserInteractionEnabled = false
        
        super.init()
        
        self.addSubnode(self.backgroundNode)
        self.addSubnode(self.textNode)
        self.addSubnode(self.clearIconNode)
        self.addSubnode(self.clearButtonNode)
        self.addSubnode(self.topSeparator)
        self.addSubnode(self.maskNode)
        
        self.textNode.textField.delegate = self
        
        self.clearButtonNode.addTarget(self, action: #selector(self.clearButtonPressed), forControlEvents: .touchUpInside)
        self.clearButtonNode.highligthedChanged = { [weak self] highlighted in
            if let strongSelf = self {
                if highlighted {
                    strongSelf.clearIconNode.layer.removeAnimation(forKey: "opacity")
                    strongSelf.clearIconNode.alpha = 0.4
                } else {
                    strongSelf.clearIconNode.alpha = 1.0
                    strongSelf.clearIconNode.layer.animateAlpha(from: 0.4, to: 1.0, duration: 0.2)
                }
            }
        }
    }
    
    @objc private func clearButtonPressed() {
        self.textNode.textField.text = ""
        self.updateClearButtonVisibility()
    }
    
    @objc func textFieldDidBeginEditing(_ textField: UITextField) {
        self.updateClearButtonVisibility()
    }
    
    @objc func textFieldDidEndEditing(_ textField: UITextField) {
        self.updateClearButtonVisibility()
    }
    
    private func updateClearButtonVisibility() {
        let isHidden = !self.textNode.textField.isFirstResponder || self.text.isEmpty
        self.clearIconNode.isHidden = isHidden
        self.clearButtonNode.isHidden = isHidden
        self.clearButtonNode.isAccessibilityElement = isHidden
    }
    
    func update(width: CGFloat, safeInset: CGFloat, isSettings: Bool, hasPrevious: Bool, hasNext: Bool, placeholder: String, isEnabled: Bool, presentationData: PresentationData, updateText: String?) -> CGFloat {
        let titleFont = Font.regular(presentationData.listsFontSize.itemListBaseFontSize)
        self.textNode.textField.font = titleFont
        
        if self.theme !== presentationData.theme {
            self.theme = presentationData.theme
            
            self.backgroundNode.backgroundColor = presentationData.theme.list.itemBlocksBackgroundColor
            
            self.textNode.textField.textColor = presentationData.theme.list.itemPrimaryTextColor
            self.textNode.textField.keyboardAppearance = presentationData.theme.rootController.keyboardColor.keyboardAppearance
            self.textNode.textField.tintColor = presentationData.theme.list.itemAccentColor
            
            self.clearIconNode.image = PresentationResourcesItemList.itemListClearInputIcon(presentationData.theme)
        }
        
        let attributedPlaceholderText = NSAttributedString(string: placeholder, font: titleFont, textColor: presentationData.theme.list.itemPlaceholderTextColor)
        if self.textNode.textField.attributedPlaceholder == nil || !self.textNode.textField.attributedPlaceholder!.isEqual(to: attributedPlaceholderText) {
            self.textNode.textField.attributedPlaceholder = attributedPlaceholderText
            self.textNode.textField.accessibilityHint = attributedPlaceholderText.string
        }
        
        if let updateText = updateText {
            self.textNode.textField.text = updateText
        }
        
        if !hasPrevious {
            self.topSeparator.isHidden = true
        }
        self.topSeparator.backgroundColor = presentationData.theme.list.itemBlocksSeparatorColor
        let separatorX = safeInset + (hasPrevious ? 16.0 : 0.0)
        self.topSeparator.frame = CGRect(origin: CGPoint(x: separatorX, y: 0.0), size: CGSize(width: width - separatorX - safeInset, height: UIScreenPixel))
        
        let measureText = "|"
        let attributedMeasureText = NSAttributedString(string: measureText, font: titleFont, textColor: .black)
        self.measureTextNode.attributedText = attributedMeasureText
        let measureTextSize = self.measureTextNode.updateLayout(CGSize(width: width - safeInset * 2.0 - 16.0 * 2.0 - 38.0, height: .greatestFiniteMagnitude))
        
        let height = measureTextSize.height + 22.0
        
        let buttonSize = CGSize(width: 38.0, height: height)
        self.clearButtonNode.frame = CGRect(origin: CGPoint(x: width - safeInset - buttonSize.width, y: 0.0), size: buttonSize)
        if let image = self.clearIconNode.image {
            self.clearIconNode.frame = CGRect(origin: CGPoint(x: width - safeInset - buttonSize.width + floor((buttonSize.width - image.size.width) / 2.0), y: floor((height - image.size.height) / 2.0)), size: image.size)
        }
        
        self.backgroundNode.frame = CGRect(origin: CGPoint(x: safeInset, y: 0.0), size: CGSize(width: max(1.0, width - safeInset * 2.0), height: height))
        self.textNode.frame = CGRect(origin: CGPoint(x: safeInset + 16.0, y: floor((height - 40.0) / 2.0)), size: CGSize(width: max(1.0, width - safeInset * 2.0 - 16.0 * 2.0 - 38.0), height: 40.0))
        
        let hasCorners = safeInset > 0.0 && (!hasPrevious || !hasNext)
        let hasTopCorners = hasCorners && !hasPrevious
        let hasBottomCorners = hasCorners && !hasNext
        
        self.maskNode.image = hasCorners ? PresentationResourcesItemList.cornersImage(presentationData.theme, top: hasTopCorners, bottom: hasBottomCorners) : nil
        self.maskNode.frame = CGRect(origin: CGPoint(x: safeInset, y: 0.0), size: CGSize(width: width - safeInset - safeInset, height: height))
        
        self.textNode.isUserInteractionEnabled = isEnabled
        self.textNode.alpha = isEnabled ? 1.0 : 0.6
        
        return height
    }
}

final class PeerInfoHeaderMultiLineTextFieldNode: ASDisplayNode, PeerInfoHeaderTextFieldNode, ASEditableTextNodeDelegate {
    private let backgroundNode: ASDisplayNode
    private let textNode: EditableTextNode
    private let textNodeContainer: ASDisplayNode
    private let measureTextNode: ImmediateTextNode
    private let clearIconNode: ASImageNode
    private let clearButtonNode: HighlightableButtonNode
    private let topSeparator: ASDisplayNode
    private let maskNode: ASImageNode
    
    private let requestUpdateHeight: () -> Void
    
    private var fontSize: PresentationFontSize?
    private var theme: PresentationTheme?
    private var currentParams: (width: CGFloat, safeInset: CGFloat)?
    private var currentMeasuredHeight: CGFloat?
    
    var text: String {
        return self.textNode.attributedText?.string ?? ""
    }
    
    init(requestUpdateHeight: @escaping () -> Void) {
        self.requestUpdateHeight = requestUpdateHeight
        
        self.backgroundNode = ASDisplayNode()
        
        self.textNode = EditableTextNode()
        self.textNode.clipsToBounds = false
        self.textNode.textView.clipsToBounds = false
        self.textNode.textContainerInset = UIEdgeInsets()
        
        self.textNodeContainer = ASDisplayNode()
        self.measureTextNode = ImmediateTextNode()
        self.measureTextNode.maximumNumberOfLines = 0
        self.measureTextNode.isUserInteractionEnabled = false
        self.measureTextNode.lineSpacing = 0.1
        self.topSeparator = ASDisplayNode()
        
        self.clearIconNode = ASImageNode()
        self.clearIconNode.isLayerBacked = true
        self.clearIconNode.displayWithoutProcessing = true
        self.clearIconNode.displaysAsynchronously = false
        self.clearIconNode.isHidden = true
        
        self.clearButtonNode = HighlightableButtonNode()
        self.clearButtonNode.isHidden = true
        
        self.maskNode = ASImageNode()
        self.maskNode.isUserInteractionEnabled = false
        
        super.init()
        
        self.addSubnode(self.backgroundNode)
        self.textNodeContainer.addSubnode(self.textNode)
        self.addSubnode(self.textNodeContainer)
        self.addSubnode(self.clearIconNode)
        self.addSubnode(self.clearButtonNode)
        self.addSubnode(self.topSeparator)
        self.addSubnode(self.maskNode)
    
        self.clearButtonNode.addTarget(self, action: #selector(self.clearButtonPressed), forControlEvents: .touchUpInside)
        self.clearButtonNode.highligthedChanged = { [weak self] highlighted in
            if let strongSelf = self {
                if highlighted {
                    strongSelf.clearIconNode.layer.removeAnimation(forKey: "opacity")
                    strongSelf.clearIconNode.alpha = 0.4
                } else {
                    strongSelf.clearIconNode.alpha = 1.0
                    strongSelf.clearIconNode.layer.animateAlpha(from: 0.4, to: 1.0, duration: 0.2)
                }
            }
        }
    }
        
    @objc private func clearButtonPressed() {
        guard let theme = self.theme else {
            return
        }
        let font: UIFont
        if let fontSize = self.fontSize {
            font = Font.regular(fontSize.itemListBaseFontSize)
        } else {
            font = Font.regular(17.0)
        }
        let attributedText = NSAttributedString(string: "", font: font, textColor: theme.list.itemPrimaryTextColor)
        self.textNode.attributedText = attributedText
        self.requestUpdateHeight()
        self.updateClearButtonVisibility()
    }
    
    func update(width: CGFloat, safeInset: CGFloat, isSettings: Bool, hasPrevious: Bool, hasNext: Bool, placeholder: String, isEnabled: Bool, presentationData: PresentationData, updateText: String?) -> CGFloat {
        self.currentParams = (width, safeInset)
        
        self.fontSize = presentationData.listsFontSize
        let titleFont = Font.regular(presentationData.listsFontSize.itemListBaseFontSize)
        
        if self.theme !== presentationData.theme {
            self.theme = presentationData.theme
            
            self.backgroundNode.backgroundColor = presentationData.theme.list.itemBlocksBackgroundColor
            
            let textColor = presentationData.theme.list.itemPrimaryTextColor
            self.textNode.typingAttributes = [NSAttributedString.Key.font.rawValue: titleFont, NSAttributedString.Key.foregroundColor.rawValue: textColor]
            self.textNode.keyboardAppearance = presentationData.theme.rootController.keyboardColor.keyboardAppearance
            self.textNode.tintColor = presentationData.theme.list.itemAccentColor
            
            self.textNode.clipsToBounds = true
            self.textNode.delegate = self
            self.textNode.hitTestSlop = UIEdgeInsets(top: -5.0, left: -5.0, bottom: -5.0, right: -5.0)
            
            self.clearIconNode.image = PresentationResourcesItemList.itemListClearInputIcon(presentationData.theme)
        }
        
        self.topSeparator.backgroundColor = presentationData.theme.list.itemBlocksSeparatorColor
        
        let separatorX = safeInset + (hasPrevious ? 16.0 : 0.0)
        self.topSeparator.frame = CGRect(origin: CGPoint(x: separatorX, y: 0.0), size: CGSize(width: width - separatorX - safeInset, height: UIScreenPixel))
        
        let attributedPlaceholderText = NSAttributedString(string: placeholder, font: titleFont, textColor: presentationData.theme.list.itemPlaceholderTextColor)
        if self.textNode.attributedPlaceholderText == nil || !self.textNode.attributedPlaceholderText!.isEqual(to: attributedPlaceholderText) {
            self.textNode.attributedPlaceholderText = attributedPlaceholderText
        }
        
        if let updateText = updateText {
            let attributedText = NSAttributedString(string: updateText, font: titleFont, textColor: presentationData.theme.list.itemPrimaryTextColor)
            self.textNode.attributedText = attributedText
        }
        
        var measureText = self.textNode.attributedText?.string ?? ""
        if measureText.hasSuffix("\n") || measureText.isEmpty {
           measureText += "|"
        }
        let attributedMeasureText = NSAttributedString(string: measureText, font: titleFont, textColor: .gray)
        self.measureTextNode.attributedText = attributedMeasureText
        let measureTextSize = self.measureTextNode.updateLayout(CGSize(width: width - safeInset * 2.0 - 16.0 * 2.0 - 38.0, height: .greatestFiniteMagnitude))
        self.measureTextNode.frame = CGRect(origin: CGPoint(), size: measureTextSize)
        self.currentMeasuredHeight = measureTextSize.height
        
        let height = measureTextSize.height + 22.0
        
        let buttonSize = CGSize(width: 38.0, height: height)
        self.clearButtonNode.frame = CGRect(origin: CGPoint(x: width - safeInset - buttonSize.width, y: 0.0), size: buttonSize)
        if let image = self.clearIconNode.image {
            self.clearIconNode.frame = CGRect(origin: CGPoint(x: width - safeInset - buttonSize.width + floor((buttonSize.width - image.size.width) / 2.0), y: floor((height - image.size.height) / 2.0)), size: image.size)
        }
        
        let textNodeFrame = CGRect(origin: CGPoint(x: safeInset + 16.0, y: 10.0), size: CGSize(width: width - safeInset * 2.0 - 16.0 * 2.0 - 38.0, height: max(height, 1000.0)))
        self.textNodeContainer.frame = textNodeFrame
        self.textNode.frame = CGRect(origin: CGPoint(), size: textNodeFrame.size)
        
        self.backgroundNode.frame = CGRect(origin: CGPoint(x: safeInset, y: 0.0), size: CGSize(width: max(1.0, width - safeInset * 2.0), height: height))
        
        let hasCorners = safeInset > 0.0 && (!hasPrevious || !hasNext)
        let hasTopCorners = hasCorners && !hasPrevious
        let hasBottomCorners = hasCorners && !hasNext
        
        self.maskNode.image = hasCorners ? PresentationResourcesItemList.cornersImage(presentationData.theme, top: hasTopCorners, bottom: hasBottomCorners) : nil
        self.maskNode.frame = CGRect(origin: CGPoint(x: safeInset, y: 0.0), size: CGSize(width: width - safeInset - safeInset, height: height))
        
        return height
    }
    
    func editableTextNodeDidBeginEditing(_ editableTextNode: ASEditableTextNode) {
        self.updateClearButtonVisibility()
    }
    
    func editableTextNodeDidFinishEditing(_ editableTextNode: ASEditableTextNode) {
        self.updateClearButtonVisibility()
    }
    
    private func updateClearButtonVisibility() {
        let isHidden = !self.textNode.isFirstResponder() || self.text.isEmpty
        self.clearIconNode.isHidden = isHidden
        self.clearButtonNode.isHidden = isHidden
        self.clearButtonNode.isAccessibilityElement = isHidden
    }
    
    func editableTextNode(_ editableTextNode: ASEditableTextNode, shouldChangeTextIn range: NSRange, replacementText text: String) -> Bool {
        guard let theme = self.theme else {
            return true
        }
        let updatedText = (editableTextNode.textView.text as NSString).replacingCharacters(in: range, with: text)
        if updatedText.count > 255 {
            let attributedText = NSAttributedString(string: String(updatedText[updatedText.startIndex..<updatedText.index(updatedText.startIndex, offsetBy: 255)]), font: Font.regular(17.0), textColor: theme.list.itemPrimaryTextColor)
            self.textNode.attributedText = attributedText
            self.requestUpdateHeight()
            
            return false
        } else {
            return true
        }
    }
    
    func editableTextNodeDidUpdateText(_ editableTextNode: ASEditableTextNode) {
        if let (width, safeInset) = self.currentParams {
            var measureText = self.textNode.attributedText?.string ?? ""
            if measureText.hasSuffix("\n") || measureText.isEmpty {
               measureText += "|"
            }
            let attributedMeasureText = NSAttributedString(string: measureText, font: Font.regular(17.0), textColor: .black)
            self.measureTextNode.attributedText = attributedMeasureText
            let measureTextSize = self.measureTextNode.updateLayout(CGSize(width: width - safeInset * 2.0 - 16.0 * 2.0 - 38.0, height: .greatestFiniteMagnitude))
            if let currentMeasuredHeight = self.currentMeasuredHeight, abs(measureTextSize.height - currentMeasuredHeight) > 0.1 {
                self.requestUpdateHeight()
            }
        }
    }
    
    func editableTextNodeShouldPaste(_ editableTextNode: ASEditableTextNode) -> Bool {
        let text: String? = UIPasteboard.general.string
        if let _ = text {
            return true
        } else {
            return false
        }
    }
}

final class PeerInfoHeaderEditingContentNode: ASDisplayNode {
    private let context: AccountContext
    private let requestUpdateLayout: () -> Void
    
    var requestEditing: (() -> Void)?
    
    let avatarNode: PeerInfoEditingAvatarNode
    let avatarTextNode: ImmediateTextNode
    let avatarButtonNode: HighlightableButtonNode
    
    var itemNodes: [PeerInfoHeaderTextFieldNodeKey: PeerInfoHeaderTextFieldNode] = [:]
    
    init(context: AccountContext, requestUpdateLayout: @escaping () -> Void) {
        self.context = context
        self.requestUpdateLayout = requestUpdateLayout
        
        self.avatarNode = PeerInfoEditingAvatarNode(context: context)
        
        self.avatarTextNode = ImmediateTextNode()
        self.avatarButtonNode = HighlightableButtonNode()
        
        super.init()
        
        self.addSubnode(self.avatarNode)
        self.avatarButtonNode.addSubnode(self.avatarTextNode)
        
        self.avatarButtonNode.addTarget(self, action: #selector(textPressed), forControlEvents: .touchUpInside)
    }
    
    @objc private func textPressed() {
        self.requestEditing?()
    }
    
    func editingTextForKey(_ key: PeerInfoHeaderTextFieldNodeKey) -> String? {
        return self.itemNodes[key]?.text
    }
    
    func shakeTextForKey(_ key: PeerInfoHeaderTextFieldNodeKey) {
        self.itemNodes[key]?.layer.addShakeAnimation()
    }
    
    func update(width: CGFloat, safeInset: CGFloat, statusBarHeight: CGFloat, navigationHeight: CGFloat, isModalOverlay: Bool, peer: Peer?, cachedData: CachedPeerData?, isContact: Bool, isSettings: Bool, presentationData: PresentationData, transition: ContainedViewLayoutTransition) -> CGFloat {
        let avatarSize: CGFloat = isModalOverlay ? 200.0 : 100.0
        let avatarFrame = CGRect(origin: CGPoint(x: floor((width - avatarSize) / 2.0), y: statusBarHeight + 13.0), size: CGSize(width: avatarSize, height: avatarSize))
        transition.updateFrameAdditiveToCenter(node: self.avatarNode, frame: CGRect(origin: avatarFrame.center, size: CGSize()))
        
        var contentHeight: CGFloat = statusBarHeight + 10.0 + avatarSize + 20.0
        
        if canEditPeerInfo(context: self.context, peer: peer)  {
            if self.avatarButtonNode.supernode == nil {
                self.addSubnode(self.avatarButtonNode)
            }
            self.avatarTextNode.attributedText = NSAttributedString(string: presentationData.strings.Settings_SetNewProfilePhotoOrVideo, font: Font.regular(17.0), textColor: presentationData.theme.list.itemAccentColor)
            self.avatarButtonNode.accessibilityLabel = self.avatarTextNode.attributedText?.string
            
            let avatarTextSize = self.avatarTextNode.updateLayout(CGSize(width: width, height: 32.0))
            transition.updateFrame(node: self.avatarTextNode, frame: CGRect(origin: CGPoint(), size: avatarTextSize))
            transition.updateFrame(node: self.avatarButtonNode, frame: CGRect(origin: CGPoint(x: floorToScreenPixels((width - avatarTextSize.width) / 2.0), y: contentHeight - 1.0), size: avatarTextSize))
            contentHeight += 32.0
        }
        
        var fieldKeys: [PeerInfoHeaderTextFieldNodeKey] = []
        if let user = peer as? TelegramUser {
            if !user.isDeleted {
                fieldKeys.append(.firstName)
                if user.botInfo == nil {
                    fieldKeys.append(.lastName)
                }
            }
        } else if let _ = peer as? TelegramGroup {
            fieldKeys.append(.title)
            if canEditPeerInfo(context: self.context, peer: peer) {
                fieldKeys.append(.description)
            }
        } else if let _ = peer as? TelegramChannel {
            fieldKeys.append(.title)
            if canEditPeerInfo(context: self.context, peer: peer) {
                fieldKeys.append(.description)
            }
        }
        var hasPrevious = false
        for key in fieldKeys {
            let itemNode: PeerInfoHeaderTextFieldNode
            var updateText: String?
            if let current = self.itemNodes[key] {
                itemNode = current
            } else {
                var isMultiline = false
                switch key {
                case .firstName:
                    updateText = (peer as? TelegramUser)?.firstName ?? ""
                case .lastName:
                    updateText = (peer as? TelegramUser)?.lastName ?? ""
                case .title:
                    updateText = peer?.debugDisplayTitle ?? ""
                case .description:
                    isMultiline = true
                    if let cachedData = cachedData as? CachedChannelData {
                        updateText = cachedData.about ?? ""
                    } else if let cachedData = cachedData as? CachedGroupData {
                        updateText = cachedData.about ?? ""
                    } else {
                        updateText = ""
                    }
                }
                if isMultiline {
                    itemNode = PeerInfoHeaderMultiLineTextFieldNode(requestUpdateHeight: { [weak self] in
                        self?.requestUpdateLayout()
                    })
                } else {
                    itemNode = PeerInfoHeaderSingleLineTextFieldNode()
                }
                self.itemNodes[key] = itemNode
                self.addSubnode(itemNode)
            }
            let placeholder: String
            var isEnabled = true
            switch key {
            case .firstName:
                placeholder = presentationData.strings.UserInfo_FirstNamePlaceholder
                isEnabled = isContact || isSettings
            case .lastName:
                placeholder = presentationData.strings.UserInfo_LastNamePlaceholder
                isEnabled = isContact || isSettings
            case .title:
                if let channel = peer as? TelegramChannel, case .broadcast = channel.info {
                    placeholder = presentationData.strings.GroupInfo_ChannelListNamePlaceholder
                } else {
                    placeholder = presentationData.strings.GroupInfo_GroupNamePlaceholder
                }
                isEnabled = canEditPeerInfo(context: self.context, peer: peer)
            case .description:
                placeholder = presentationData.strings.Channel_Edit_AboutItem
                isEnabled = canEditPeerInfo(context: self.context, peer: peer)
            }
            let itemHeight = itemNode.update(width: width, safeInset: safeInset, isSettings: isSettings, hasPrevious: hasPrevious, hasNext: key != fieldKeys.last, placeholder: placeholder, isEnabled: isEnabled, presentationData: presentationData, updateText: updateText)
            transition.updateFrame(node: itemNode, frame: CGRect(origin: CGPoint(x: 0.0, y: contentHeight), size: CGSize(width: width, height: itemHeight)))
            contentHeight += itemHeight
            hasPrevious = true
        }
        var removeKeys: [PeerInfoHeaderTextFieldNodeKey] = []
        for (key, _) in self.itemNodes {
            if !fieldKeys.contains(key) {
                removeKeys.append(key)
            }
        }
        for key in removeKeys {
            if let itemNode = self.itemNodes.removeValue(forKey: key) {
                itemNode.removeFromSupernode()
            }
        }
        
        return contentHeight
    }
}

private let TitleNodeStateRegular = 0
private let TitleNodeStateExpanded = 1

final class PeerInfoHeaderNode: ASDisplayNode {
    private var context: AccountContext
    private var presentationData: PresentationData?
    private var state: PeerInfoState?
    private var peer: Peer?
    private var avatarSize: CGFloat?
    
    private let isOpenedFromChat: Bool
    private let isSettings: Bool
    private let videoCallsEnabled: Bool
    
    private(set) var isAvatarExpanded: Bool
    var skipCollapseCompletion = false
    var ignoreCollapse = false
    
    let avatarListNode: PeerInfoAvatarListNode
    
    let buttonsContainerNode: SparseNode
    let regularContentNode: PeerInfoHeaderRegularContentNode
    let editingContentNode: PeerInfoHeaderEditingContentNode
    let avatarOverlayNode: PeerInfoEditingAvatarOverlayNode
    let titleNodeContainer: ASDisplayNode
    let titleNodeRawContainer: ASDisplayNode
    let titleNode: MultiScaleTextNode
    let titleCredibilityIconNode: ASImageNode
    let titleExpandedCredibilityIconNode: ASImageNode
    let subtitleNodeContainer: ASDisplayNode
    let subtitleNodeRawContainer: ASDisplayNode
    let subtitleNode: MultiScaleTextNode
    let panelSubtitleNode: MultiScaleTextNode
    let nextPanelSubtitleNode: MultiScaleTextNode
    let usernameNodeContainer: ASDisplayNode
    let usernameNodeRawContainer: ASDisplayNode
    let usernameNode: MultiScaleTextNode
    var buttonNodes: [PeerInfoHeaderButtonKey: PeerInfoHeaderButtonNode] = [:]
    let backgroundNode: NavigationBackgroundNode
    let expandedBackgroundNode: NavigationBackgroundNode
    let separatorNode: ASDisplayNode
    let navigationBackgroundNode: ASDisplayNode
    let navigationBackgroundBackgroundNode: ASDisplayNode
    var navigationTitle: String?
    let navigationTitleNode: ImmediateTextNode
    let navigationSeparatorNode: ASDisplayNode
    let navigationButtonContainer: PeerInfoHeaderNavigationButtonContainerNode
    
    var performButtonAction: ((PeerInfoHeaderButtonKey, ContextGesture?) -> Void)?
    var requestAvatarExpansion: ((Bool, [AvatarGalleryEntry], AvatarGalleryEntry?, (ASDisplayNode, CGRect, () -> (UIView?, UIView?))?) -> Void)?
    var requestOpenAvatarForEditing: ((Bool) -> Void)?
    var cancelUpload: (() -> Void)?
    var requestUpdateLayout: ((Bool) -> Void)?
    var animateOverlaysFadeIn: (() -> Void)?
    
    var displayAvatarContextMenu: ((ASDisplayNode, ContextGesture?) -> Void)?
    var displayCopyContextMenu: ((ASDisplayNode, Bool, Bool) -> Void)?
    
    var displayPremiumIntro: ((UIView, Bool) -> Void)?
    
    var navigationTransition: PeerInfoHeaderNavigationTransition?
    
    var backgroundAlpha: CGFloat = 1.0
    var updateHeaderAlpha: ((CGFloat, ContainedViewLayoutTransition) -> Void)?
    
    init(context: AccountContext, avatarInitiallyExpanded: Bool, isOpenedFromChat: Bool, isMediaOnly: Bool, isSettings: Bool) {
        self.context = context
        self.isAvatarExpanded = avatarInitiallyExpanded
        self.isOpenedFromChat = isOpenedFromChat
        self.isSettings = isSettings
        self.videoCallsEnabled = true
        
        self.avatarListNode = PeerInfoAvatarListNode(context: context, readyWhenGalleryLoads: avatarInitiallyExpanded, isSettings: isSettings)
        
        self.titleNodeContainer = ASDisplayNode()
        self.titleNodeRawContainer = ASDisplayNode()
        self.titleNode = MultiScaleTextNode(stateKeys: [TitleNodeStateRegular, TitleNodeStateExpanded])
        self.titleNode.displaysAsynchronously = false
        
        self.titleCredibilityIconNode = ASImageNode()
        self.titleCredibilityIconNode.displaysAsynchronously = false
        self.titleCredibilityIconNode.displayWithoutProcessing = true
        self.titleNode.stateNode(forKey: TitleNodeStateRegular)?.addSubnode(self.titleCredibilityIconNode)
        
        self.titleExpandedCredibilityIconNode = ASImageNode()
        self.titleExpandedCredibilityIconNode.displaysAsynchronously = false
        self.titleExpandedCredibilityIconNode.displayWithoutProcessing = true
        self.titleNode.stateNode(forKey: TitleNodeStateExpanded)?.addSubnode(self.titleExpandedCredibilityIconNode)
        
        self.subtitleNodeContainer = ASDisplayNode()
        self.subtitleNodeRawContainer = ASDisplayNode()
        self.subtitleNode = MultiScaleTextNode(stateKeys: [TitleNodeStateRegular, TitleNodeStateExpanded])
        self.subtitleNode.displaysAsynchronously = false

        self.panelSubtitleNode = MultiScaleTextNode(stateKeys: [TitleNodeStateRegular, TitleNodeStateExpanded])
        self.panelSubtitleNode.displaysAsynchronously = false
        
        self.nextPanelSubtitleNode = MultiScaleTextNode(stateKeys: [TitleNodeStateRegular, TitleNodeStateExpanded])
        self.nextPanelSubtitleNode.displaysAsynchronously = false
        
        self.usernameNodeContainer = ASDisplayNode()
        self.usernameNodeRawContainer = ASDisplayNode()
        self.usernameNode = MultiScaleTextNode(stateKeys: [TitleNodeStateRegular, TitleNodeStateExpanded])
        self.usernameNode.displaysAsynchronously = false
        
        self.buttonsContainerNode = SparseNode()
        self.buttonsContainerNode.clipsToBounds = true
        
        self.regularContentNode = PeerInfoHeaderRegularContentNode()
        var requestUpdateLayoutImpl: (() -> Void)?
        self.editingContentNode = PeerInfoHeaderEditingContentNode(context: context, requestUpdateLayout: {
            requestUpdateLayoutImpl?()
        })
        self.editingContentNode.alpha = 0.0
        
        self.avatarOverlayNode = PeerInfoEditingAvatarOverlayNode(context: context)
        self.avatarOverlayNode.isUserInteractionEnabled = false
        
        self.navigationBackgroundNode = ASDisplayNode()
        self.navigationBackgroundNode.isHidden = true
        self.navigationBackgroundNode.isUserInteractionEnabled = false

        self.navigationBackgroundBackgroundNode = ASDisplayNode()
        self.navigationBackgroundBackgroundNode.isUserInteractionEnabled = false
        
        self.navigationTitleNode = ImmediateTextNode()
        
        self.navigationSeparatorNode = ASDisplayNode()
        
        self.navigationButtonContainer = PeerInfoHeaderNavigationButtonContainerNode()
        
        self.backgroundNode = NavigationBackgroundNode(color: .clear)
        self.backgroundNode.isHidden = true
        self.backgroundNode.isUserInteractionEnabled = false
        self.expandedBackgroundNode = NavigationBackgroundNode(color: .clear)
        self.expandedBackgroundNode.isHidden = false
        self.expandedBackgroundNode.isUserInteractionEnabled = false
        
        self.separatorNode = ASDisplayNode()
        self.separatorNode.isLayerBacked = true
        
        super.init()
        
        requestUpdateLayoutImpl = { [weak self] in
            self?.requestUpdateLayout?(false)
        }
        
        
        if !isMediaOnly {
            self.addSubnode(self.buttonsContainerNode)
        }
        self.addSubnode(self.backgroundNode)
        self.addSubnode(self.expandedBackgroundNode)
        self.titleNodeContainer.addSubnode(self.titleNode)
        self.subtitleNodeContainer.addSubnode(self.subtitleNode)
        self.subtitleNodeContainer.addSubnode(self.panelSubtitleNode)
//        self.subtitleNodeContainer.addSubnode(self.nextPanelSubtitleNode)
        self.usernameNodeContainer.addSubnode(self.usernameNode)

        self.regularContentNode.addSubnode(self.avatarListNode)
        self.regularContentNode.addSubnode(self.avatarListNode.listContainerNode.controlsClippingOffsetNode)
        self.regularContentNode.addSubnode(self.titleNodeContainer)
        self.regularContentNode.addSubnode(self.subtitleNodeContainer)
        self.regularContentNode.addSubnode(self.subtitleNodeRawContainer)
        self.regularContentNode.addSubnode(self.usernameNodeContainer)
        self.regularContentNode.addSubnode(self.usernameNodeRawContainer)
        
        self.addSubnode(self.regularContentNode)
        self.addSubnode(self.editingContentNode)
        self.addSubnode(self.avatarOverlayNode)
        self.addSubnode(self.navigationBackgroundNode)
        self.navigationBackgroundNode.addSubnode(self.navigationBackgroundBackgroundNode)
        self.navigationBackgroundNode.addSubnode(self.navigationTitleNode)
        self.navigationBackgroundNode.addSubnode(self.navigationSeparatorNode)
        self.addSubnode(self.navigationButtonContainer)
        self.addSubnode(self.separatorNode)
        
        self.avatarListNode.avatarContainerNode.tapped = { [weak self] in
            self?.initiateAvatarExpansion(gallery: false, first: false)
        }
        self.avatarListNode.avatarContainerNode.contextAction = { [weak self] node, gesture in
            self?.displayAvatarContextMenu?(node, gesture)
        }
        
        self.editingContentNode.avatarNode.tapped = { [weak self] confirm in
            self?.initiateAvatarExpansion(gallery: true, first: true)
        }
        self.editingContentNode.requestEditing = { [weak self] in
            self?.requestOpenAvatarForEditing?(true)
        }
        
        self.avatarListNode.itemsUpdated = { [weak self] items in
            guard let strongSelf = self, let state = strongSelf.state, let peer = strongSelf.peer, let presentationData = strongSelf.presentationData, let avatarSize = strongSelf.avatarSize else {
                return
            }
            strongSelf.editingContentNode.avatarNode.update(peer: peer, item: strongSelf.avatarListNode.item, updatingAvatar: state.updatingAvatar, uploadProgress: state.avatarUploadProgress, theme: presentationData.theme, avatarSize: avatarSize, isEditing: state.isEditing)
        }

        self.avatarListNode.animateOverlaysFadeIn = { [weak self] in
            guard let strongSelf = self else {
                return
            }
            strongSelf.navigationButtonContainer.layer.animateAlpha(from: 0.0, to: strongSelf.navigationButtonContainer.alpha, duration: 0.25)
            strongSelf.avatarListNode.listContainerNode.topShadowNode.layer.animateAlpha(from: 0.0, to: strongSelf.avatarListNode.listContainerNode.topShadowNode.alpha, duration: 0.25)
            
            strongSelf.avatarListNode.listContainerNode.bottomShadowNode.alpha = 1.0
            strongSelf.avatarListNode.listContainerNode.bottomShadowNode.layer.animateAlpha(from: 0.0, to: strongSelf.avatarListNode.listContainerNode.bottomShadowNode.alpha, duration: 0.25)
            strongSelf.avatarListNode.listContainerNode.controlsContainerNode.layer.animateAlpha(from: 0.0, to: strongSelf.avatarListNode.listContainerNode.controlsContainerNode.alpha, duration: 0.25)
            
            strongSelf.titleNode.layer.animateAlpha(from: 0.0, to: strongSelf.titleNode.alpha, duration: 0.25)
            strongSelf.subtitleNode.layer.animateAlpha(from: 0.0, to: strongSelf.subtitleNode.alpha, duration: 0.25)

            strongSelf.animateOverlaysFadeIn?()
        }
    }
    
    override func didLoad() {
        super.didLoad()
        
        let usernameGestureRecognizer = UILongPressGestureRecognizer(target: self, action: #selector(self.handleUsernameLongPress(_:)))
        self.usernameNodeRawContainer.view.addGestureRecognizer(usernameGestureRecognizer)
        
        let phoneGestureRecognizer = UILongPressGestureRecognizer(target: self, action: #selector(self.handlePhoneLongPress(_:)))
        self.subtitleNodeRawContainer.view.addGestureRecognizer(phoneGestureRecognizer)
        
        let premiumGestureRecognizer = UITapGestureRecognizer(target: self, action: #selector(self.handleStarTap(_:)))
        self.titleCredibilityIconNode.view.addGestureRecognizer(premiumGestureRecognizer)
        
        let expandedPremiumGestureRecognizer = UITapGestureRecognizer(target: self, action: #selector(self.handleStarTap(_:)))
        self.titleExpandedCredibilityIconNode.view.addGestureRecognizer(expandedPremiumGestureRecognizer)
    }
    
    @objc private func handleUsernameLongPress(_ gestureRecognizer: UILongPressGestureRecognizer) {
        if gestureRecognizer.state == .began {
            self.displayCopyContextMenu?(self.usernameNodeRawContainer, !self.isAvatarExpanded, true)
        }
    }
    
    @objc private func handlePhoneLongPress(_ gestureRecognizer: UILongPressGestureRecognizer) {
        if gestureRecognizer.state == .began {
            self.displayCopyContextMenu?(self.subtitleNodeRawContainer, true, !self.isAvatarExpanded)
        }
    }
    
    @objc private func handleStarTap(_ gestureRecognizer: UITapGestureRecognizer) {
        guard let view = gestureRecognizer.view, self.currentCredibilityIcon == .premium else {
            return
        }
        self.displayPremiumIntro?(view, view == self.titleExpandedCredibilityIconNode.view)
    }
    
    func initiateAvatarExpansion(gallery: Bool, first: Bool) {
        if let peer = self.peer, peer.profileImageRepresentations.isEmpty && gallery {
            self.requestOpenAvatarForEditing?(false)
            return
        }
        if self.isAvatarExpanded || gallery {
            if let currentEntry = self.avatarListNode.listContainerNode.currentEntry, let firstEntry = self.avatarListNode.listContainerNode.galleryEntries.first {
                let entry = first ? firstEntry : currentEntry
                self.requestAvatarExpansion?(true, self.avatarListNode.listContainerNode.galleryEntries, entry, self.avatarTransitionArguments(entry: currentEntry))
            }
        } else if let entry = self.avatarListNode.listContainerNode.galleryEntries.first {
            let _ = self.avatarListNode.avatarContainerNode.avatarNode
            self.requestAvatarExpansion?(false, self.avatarListNode.listContainerNode.galleryEntries, nil, self.avatarTransitionArguments(entry: entry))
        } else {
            self.cancelUpload?()
        }
    }
    
    func avatarTransitionArguments(entry: AvatarGalleryEntry) -> (ASDisplayNode, CGRect, () -> (UIView?, UIView?))? {
        if self.isAvatarExpanded {
            if let avatarNode = self.avatarListNode.listContainerNode.currentItemNode?.imageNode {
                return (avatarNode, avatarNode.bounds, { [weak avatarNode] in
                    return (avatarNode?.view.snapshotContentTree(unhide: true), nil)
                })
            } else {
                return nil
            }
        } else if entry == self.avatarListNode.listContainerNode.galleryEntries.first {
            let avatarNode = self.avatarListNode.avatarContainerNode.avatarNode
            return (avatarNode, avatarNode.bounds, { [weak avatarNode] in
                return (avatarNode?.view.snapshotContentTree(unhide: true), nil)
            })
        } else {
            return nil
        }
    }
    
    func addToAvatarTransitionSurface(view: UIView) {
        if self.isAvatarExpanded {
            self.avatarListNode.listContainerNode.view.addSubview(view)
        } else {
            self.view.addSubview(view)
        }
    }
    
    func updateAvatarIsHidden(entry: AvatarGalleryEntry?) {
        if let entry = entry {
            self.avatarListNode.avatarContainerNode.avatarNode.isHidden = entry == self.avatarListNode.listContainerNode.galleryEntries.first
            self.editingContentNode.avatarNode.isHidden = entry == self.avatarListNode.listContainerNode.galleryEntries.first
        } else {
            self.avatarListNode.avatarContainerNode.avatarNode.isHidden = false
            self.editingContentNode.avatarNode.isHidden = false
        }
        self.avatarListNode.listContainerNode.updateEntryIsHidden(entry: entry)
    }
        
    private enum CredibilityIcon {
        case none
        case premium
        case verified
        case fake
        case scam
    }
    
    private var currentCredibilityIcon: CredibilityIcon?
    
    private var currentPanelStatusData: PeerInfoStatusData?
    func update(width: CGFloat, containerHeight: CGFloat, containerInset: CGFloat, statusBarHeight: CGFloat, navigationHeight: CGFloat, isModalOverlay: Bool, isMediaOnly: Bool, contentOffset: CGFloat, paneContainerY: CGFloat, presentationData: PresentationData, peer: Peer?, cachedData: CachedPeerData?, notificationSettings: TelegramPeerNotificationSettings?, statusData: PeerInfoStatusData?, panelStatusData: (PeerInfoStatusData?, PeerInfoStatusData?, CGFloat?), isSecretChat: Bool, isContact: Bool, isSettings: Bool, state: PeerInfoState, metrics: LayoutMetrics, transition: ContainedViewLayoutTransition, additive: Bool) -> CGFloat {
        self.state = state
        self.peer = peer
        self.avatarListNode.listContainerNode.peer = peer
        
        let previousPanelStatusData = self.currentPanelStatusData
        self.currentPanelStatusData = panelStatusData.0
        
        let avatarSize: CGFloat = isModalOverlay ? 200.0 : 100.0
        self.avatarSize = avatarSize
        
        var contentOffset = contentOffset
        
        if isMediaOnly {
            if isModalOverlay {
                contentOffset = 312.0
            } else {
                contentOffset = 212.0
            }
        }
        
        let themeUpdated = self.presentationData?.theme !== presentationData.theme
        self.presentationData = presentationData
        
        let premiumConfiguration = PremiumConfiguration.with(appConfiguration: self.context.currentAppConfiguration.with { $0 })
        
        let credibilityIcon: CredibilityIcon
        if let peer = peer {
            if peer.isFake {
                credibilityIcon = .fake
            } else if peer.isScam {
                credibilityIcon = .scam
            } else if peer.isVerified {
                credibilityIcon = .verified
            } else if peer.isPremium && !premiumConfiguration.isPremiumDisabled && (peer.id != self.context.account.peerId || self.isSettings) {
                credibilityIcon = .premium
            } else {
                credibilityIcon = .none
            }
        } else {
            credibilityIcon = .none
        }
        
        if themeUpdated || self.currentCredibilityIcon != credibilityIcon {
            self.currentCredibilityIcon = credibilityIcon
            let image: UIImage?
            var expandedImage: UIImage?
            
            if case .fake = credibilityIcon {
                image = PresentationResourcesChatList.fakeIcon(presentationData.theme, strings: presentationData.strings, type: .regular)
            } else if case .scam = credibilityIcon {
                image = PresentationResourcesChatList.scamIcon(presentationData.theme, strings: presentationData.strings, type: .regular)
            } else if case .verified = credibilityIcon {
                if let backgroundImage = UIImage(bundleImageName: "Peer Info/VerifiedIconBackground"), let foregroundImage = UIImage(bundleImageName: "Peer Info/VerifiedIconForeground") {
                    image = generateImage(backgroundImage.size, contextGenerator: { size, context in
                        if let backgroundCgImage = backgroundImage.cgImage, let foregroundCgImage = foregroundImage.cgImage {
                            context.clear(CGRect(origin: CGPoint(), size: size))
                            context.saveGState()
                            context.clip(to: CGRect(origin: .zero, size: size), mask: backgroundCgImage)

                            context.setFillColor(presentationData.theme.list.itemCheckColors.fillColor.cgColor)
                            context.fill(CGRect(origin: CGPoint(), size: size))
                            context.restoreGState()
                            
                            context.clip(to: CGRect(origin: .zero, size: size), mask: foregroundCgImage)
                            context.setFillColor(presentationData.theme.list.itemCheckColors.foregroundColor.cgColor)
                            context.fill(CGRect(origin: CGPoint(), size: size))
                        }
                    }, opaque: false)
                    expandedImage = generateImage(backgroundImage.size, contextGenerator: { size, context in
                        if let backgroundCgImage = backgroundImage.cgImage, let foregroundCgImage = foregroundImage.cgImage {
                            context.clear(CGRect(origin: CGPoint(), size: size))
                            context.saveGState()
                            context.clip(to: CGRect(origin: .zero, size: size), mask: backgroundCgImage)
                            context.setFillColor(UIColor(rgb: 0xffffff, alpha: 0.75).cgColor)
                            context.fill(CGRect(origin: CGPoint(), size: size))
                            context.restoreGState()
                            
                            context.clip(to: CGRect(origin: .zero, size: size), mask: foregroundCgImage)
                            context.setBlendMode(.clear)
                            context.fill(CGRect(origin: CGPoint(), size: size))
                        }
                    }, opaque: false)
                } else {
                    image = nil
                }
            } else if case .premium = credibilityIcon {
                if let sourceImage = UIImage(bundleImageName: "Peer Info/PremiumIcon") {
                    image = generateImage(sourceImage.size, contextGenerator: { size, context in
                        if let cgImage = sourceImage.cgImage {
                            context.clear(CGRect(origin: CGPoint(), size: size))
                            context.clip(to: CGRect(origin: .zero, size: size), mask: cgImage)
                            
                            context.setFillColor(presentationData.theme.list.itemCheckColors.fillColor.cgColor)
                            context.fill(CGRect(origin: CGPoint(), size: size))
                        }
                    }, opaque: false)
                    expandedImage = generateImage(sourceImage.size, contextGenerator: { size, context in
                        if let cgImage = sourceImage.cgImage {
                            context.clear(CGRect(origin: CGPoint(), size: size))
                            context.clip(to: CGRect(origin: .zero, size: size), mask: cgImage)
                            context.setFillColor(UIColor(rgb: 0xffffff, alpha: 0.75).cgColor)
                            context.fill(CGRect(origin: CGPoint(), size: size))
                        }
                    }, opaque: false)
                } else {
                    image = nil
                }
            } else {
                image = nil
            }
            
            self.titleCredibilityIconNode.image = image
            self.titleExpandedCredibilityIconNode.image = expandedImage ?? image
        }
        
        self.regularContentNode.alpha = state.isEditing ? 0.0 : 1.0
        self.buttonsContainerNode.alpha = self.regularContentNode.alpha
        self.editingContentNode.alpha = state.isEditing ? 1.0 : 0.0
        
        let editingContentHeight = self.editingContentNode.update(width: width, safeInset: containerInset, statusBarHeight: statusBarHeight, navigationHeight: navigationHeight, isModalOverlay: isModalOverlay, peer: state.isEditing ? peer : nil, cachedData: cachedData, isContact: isContact, isSettings: isSettings, presentationData: presentationData, transition: transition)
        transition.updateFrame(node: self.editingContentNode, frame: CGRect(origin: CGPoint(x: 0.0, y: -contentOffset), size: CGSize(width: width, height: editingContentHeight)))
        
        let avatarOverlayFarme = self.editingContentNode.convert(self.editingContentNode.avatarNode.frame, to: self)
        transition.updateFrame(node: self.avatarOverlayNode, frame: avatarOverlayFarme)
        
        var transitionSourceHeight: CGFloat = 0.0
        var transitionFraction: CGFloat = 0.0
        var transitionSourceAvatarFrame = CGRect()
        var transitionSourceTitleFrame = CGRect()
        var transitionSourceSubtitleFrame = CGRect()
        
        self.backgroundNode.updateColor(color: presentationData.theme.rootController.navigationBar.blurredBackgroundColor, transition: .immediate)
        
        let headerBackgroundColor: UIColor = presentationData.theme.list.blocksBackgroundColor
        var effectiveSeparatorAlpha: CGFloat
        if let navigationTransition = self.navigationTransition, let sourceAvatarNode = (navigationTransition.sourceNavigationBar.rightButtonNode.singleCustomNode as? ChatAvatarNavigationNode)?.avatarNode {
            transitionSourceHeight = navigationTransition.sourceNavigationBar.backgroundNode.bounds.height
            transitionFraction = navigationTransition.fraction
            transitionSourceAvatarFrame = sourceAvatarNode.view.convert(sourceAvatarNode.view.bounds, to: navigationTransition.sourceNavigationBar.view)
            transitionSourceTitleFrame = navigationTransition.sourceTitleFrame
            transitionSourceSubtitleFrame = navigationTransition.sourceSubtitleFrame

            self.expandedBackgroundNode.updateColor(color: presentationData.theme.rootController.navigationBar.blurredBackgroundColor.mixedWith(headerBackgroundColor, alpha: 1.0 - transitionFraction), forceKeepBlur: true, transition: transition)
            effectiveSeparatorAlpha = transitionFraction
            
            if self.isAvatarExpanded, case .animated = transition, transitionFraction == 1.0 {
                self.avatarListNode.animateAvatarCollapse(transition: transition)
            }
        } else {
            let contentOffset = max(0.0, contentOffset - 140.0)
            let backgroundTransitionFraction: CGFloat = max(0.0, min(1.0, contentOffset / 30.0))

            self.expandedBackgroundNode.updateColor(color: presentationData.theme.rootController.navigationBar.opaqueBackgroundColor.mixedWith(headerBackgroundColor, alpha: 1.0 - backgroundTransitionFraction), forceKeepBlur: true, transition: transition)
            effectiveSeparatorAlpha = backgroundTransitionFraction
        }
        
        self.avatarListNode.avatarContainerNode.updateTransitionFraction(transitionFraction, transition: transition)
        self.avatarListNode.listContainerNode.currentItemNode?.updateTransitionFraction(transitionFraction, transition: transition)
        self.avatarOverlayNode.updateTransitionFraction(transitionFraction, transition: transition)
        
        if self.navigationTitle != presentationData.strings.EditProfile_Title || themeUpdated {
            self.navigationTitleNode.attributedText = NSAttributedString(string: presentationData.strings.EditProfile_Title, font: Font.semibold(17.0), textColor: presentationData.theme.rootController.navigationBar.primaryTextColor)
        }
        
        let navigationTitleSize = self.navigationTitleNode.updateLayout(CGSize(width: width, height: navigationHeight))
        self.navigationTitleNode.frame = CGRect(origin: CGPoint(x: floorToScreenPixels((width - navigationTitleSize.width) / 2.0), y: navigationHeight - 44.0 + floorToScreenPixels((44.0 - navigationTitleSize.height) / 2.0)), size: navigationTitleSize)
        
        self.navigationBackgroundNode.frame = CGRect(origin: CGPoint(), size: CGSize(width: width, height: navigationHeight))
        self.navigationBackgroundBackgroundNode.frame = CGRect(origin: CGPoint(), size: CGSize(width: width, height: navigationHeight))
        self.navigationSeparatorNode.frame = CGRect(origin: CGPoint(x: 0.0, y: navigationHeight), size: CGSize(width: width, height: UIScreenPixel))
        self.navigationBackgroundBackgroundNode.backgroundColor = presentationData.theme.rootController.navigationBar.opaqueBackgroundColor
        self.navigationSeparatorNode.backgroundColor = presentationData.theme.rootController.navigationBar.separatorColor

        let navigationSeparatorAlpha: CGFloat = state.isEditing && self.isSettings ? min(1.0, contentOffset / (navigationHeight * 0.5)) : 0.0
        transition.updateAlpha(node: self.navigationBackgroundBackgroundNode, alpha: 1.0 - navigationSeparatorAlpha)
        transition.updateAlpha(node: self.navigationSeparatorNode, alpha: navigationSeparatorAlpha)

        self.separatorNode.backgroundColor = presentationData.theme.list.itemBlocksSeparatorColor
        
        let expandedAvatarControlsHeight: CGFloat = 61.0
        let expandedAvatarListHeight = min(width, containerHeight - expandedAvatarControlsHeight)
        let expandedAvatarListSize = CGSize(width: width, height: expandedAvatarListHeight)
        
        let buttonKeys: [PeerInfoHeaderButtonKey] = self.isSettings ? [] : peerInfoHeaderButtons(peer: peer, cachedData: cachedData, isOpenedFromChat: self.isOpenedFromChat, isExpanded: true, videoCallsEnabled: width > 320.0 && self.videoCallsEnabled, isSecretChat: isSecretChat, isContact: isContact)
        
        var isPremium = false
        var isVerified = false
        var isFake = false
        let smallTitleString: NSAttributedString
        let titleString: NSAttributedString
        let smallSubtitleString: NSAttributedString
        let subtitleString: NSAttributedString
        var panelSubtitleString: NSAttributedString?
        var nextPanelSubtitleString: NSAttributedString?
        let usernameString: NSAttributedString
        if let peer = peer {
            isPremium = peer.isPremium
            isVerified = peer.isVerified
            isFake = peer.isFake || peer.isScam
        }
        
        if let peer = peer {
            var title: String
            if peer.id == self.context.account.peerId && !self.isSettings {
                title = presentationData.strings.Conversation_SavedMessages
            } else if peer.id == self.context.account.peerId && !self.isSettings {
                title = presentationData.strings.DialogList_Replies
            } else {
                title = EnginePeer(peer).displayTitle(strings: presentationData.strings, displayOrder: presentationData.nameDisplayOrder)
            }
            title = title.replacingOccurrences(of: "\u{1160}", with: "").replacingOccurrences(of: "\u{3164}", with: "")
            if title.isEmpty {
                if let peer = peer as? TelegramUser, let phone = peer.phone {
                    title = formatPhoneNumber(phone)
                } else if let addressName = peer.addressName {
                    title = "@\(addressName)"
                } else {
                    title = " "
                }
            }

            titleString = NSAttributedString(string: title, font: Font.medium(29.0), textColor: presentationData.theme.list.itemPrimaryTextColor)
            smallTitleString = NSAttributedString(string: title, font: Font.semibold(28.0), textColor: .white)
            if self.isSettings, let user = peer as? TelegramUser {
                var subtitle = formatPhoneNumber(user.phone ?? "")
                
                if let addressName = user.addressName, !addressName.isEmpty {
                    subtitle = "\(subtitle) • @\(addressName)"
                }
                smallSubtitleString = NSAttributedString(string: subtitle, font: Font.regular(15.0), textColor: UIColor(rgb: 0xffffff, alpha: 0.7))
                subtitleString = NSAttributedString(string: subtitle, font: Font.regular(17.0), textColor: presentationData.theme.list.itemSecondaryTextColor)
                usernameString = NSAttributedString(string: "", font: Font.regular(15.0), textColor: presentationData.theme.list.itemSecondaryTextColor)
            } else if let statusData = statusData {
                let subtitleColor: UIColor
                if statusData.isActivity {
                    subtitleColor = presentationData.theme.list.itemAccentColor
                } else {
                    subtitleColor = presentationData.theme.list.itemSecondaryTextColor
                }
                smallSubtitleString = NSAttributedString(string: statusData.text, font: Font.regular(15.0), textColor: UIColor(rgb: 0xffffff, alpha: 0.7))
                subtitleString = NSAttributedString(string: statusData.text, font: Font.regular(17.0), textColor: subtitleColor)
                usernameString = NSAttributedString(string: "", font: Font.regular(15.0), textColor: presentationData.theme.list.itemSecondaryTextColor)

                let (maybePanelStatusData, maybeNextPanelStatusData, _) = panelStatusData
                if let panelStatusData = maybePanelStatusData {
                    let subtitleColor: UIColor
                    if panelStatusData.isActivity {
                        subtitleColor = presentationData.theme.list.itemAccentColor
                    } else {
                        subtitleColor = presentationData.theme.list.itemSecondaryTextColor
                    }
                    panelSubtitleString = NSAttributedString(string: panelStatusData.text, font: Font.regular(17.0), textColor: subtitleColor)
                }
                if let nextPanelStatusData = maybeNextPanelStatusData {
                    nextPanelSubtitleString = NSAttributedString(string: nextPanelStatusData.text, font: Font.regular(17.0), textColor: presentationData.theme.list.itemSecondaryTextColor)
                }
            } else {
                subtitleString = NSAttributedString(string: " ", font: Font.regular(15.0), textColor: presentationData.theme.list.itemSecondaryTextColor)
                smallSubtitleString = subtitleString
                usernameString = NSAttributedString(string: "", font: Font.regular(15.0), textColor: presentationData.theme.list.itemSecondaryTextColor)
            }
        } else {
            titleString = NSAttributedString(string: " ", font: Font.semibold(24.0), textColor: presentationData.theme.list.itemPrimaryTextColor)
            smallTitleString = titleString
            subtitleString = NSAttributedString(string: " ", font: Font.regular(15.0), textColor: presentationData.theme.list.itemSecondaryTextColor)
            smallSubtitleString = subtitleString
            usernameString = NSAttributedString(string: "", font: Font.regular(15.0), textColor: presentationData.theme.list.itemSecondaryTextColor)
        }
        
        let textSideInset: CGFloat = 36.0
        let expandedAvatarHeight: CGFloat = expandedAvatarListSize.height
        
        let titleConstrainedSize = CGSize(width: width - textSideInset * 2.0 - (isPremium || isVerified || isFake ? 20.0 : 0.0), height: .greatestFiniteMagnitude)
        
        let titleNodeLayout = self.titleNode.updateLayout(states: [
            TitleNodeStateRegular: MultiScaleTextState(attributedText: titleString, constrainedSize: titleConstrainedSize),
            TitleNodeStateExpanded: MultiScaleTextState(attributedText: smallTitleString, constrainedSize: titleConstrainedSize)
        ], mainState: TitleNodeStateRegular)
        self.titleNode.accessibilityLabel = titleString.string
        
        let subtitleNodeLayout = self.subtitleNode.updateLayout(states: [
            TitleNodeStateRegular: MultiScaleTextState(attributedText: subtitleString, constrainedSize: titleConstrainedSize),
            TitleNodeStateExpanded: MultiScaleTextState(attributedText: smallSubtitleString, constrainedSize: titleConstrainedSize)
        ], mainState: TitleNodeStateRegular)
        self.subtitleNode.accessibilityLabel = subtitleString.string
        
        if let previousPanelStatusData = previousPanelStatusData, let currentPanelStatusData = panelStatusData.0, let previousPanelStatusDataKey = previousPanelStatusData.key, let currentPanelStatusDataKey = currentPanelStatusData.key, previousPanelStatusDataKey != currentPanelStatusDataKey {
            if let snapshotView = self.panelSubtitleNode.view.snapshotContentTree() {
                let direction: CGFloat = previousPanelStatusDataKey.rawValue > currentPanelStatusDataKey.rawValue ? 1.0 : -1.0
                
                self.panelSubtitleNode.view.superview?.addSubview(snapshotView)
                snapshotView.frame = self.panelSubtitleNode.frame
                snapshotView.layer.animatePosition(from: CGPoint(), to: CGPoint(x: 100.0 * direction, y: 0.0), duration: 0.4, timingFunction: kCAMediaTimingFunctionSpring, removeOnCompletion: false, additive: true, completion: { [weak snapshotView] _ in
                    snapshotView?.removeFromSuperview()
                })
                snapshotView.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.3, removeOnCompletion: false)
                
                self.panelSubtitleNode.layer.animatePosition(from: CGPoint(x: 100.0 * direction * -1.0, y: 0.0), to: CGPoint(), duration: 0.4, timingFunction: kCAMediaTimingFunctionSpring, additive: true)
                self.panelSubtitleNode.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.3)
            }
        }
        
        let panelSubtitleNodeLayout = self.panelSubtitleNode.updateLayout(states: [
            TitleNodeStateRegular: MultiScaleTextState(attributedText: panelSubtitleString ?? subtitleString, constrainedSize: titleConstrainedSize),
            TitleNodeStateExpanded: MultiScaleTextState(attributedText: panelSubtitleString ?? subtitleString, constrainedSize: titleConstrainedSize)
        ], mainState: TitleNodeStateRegular)
        self.panelSubtitleNode.accessibilityLabel = (panelSubtitleString ?? subtitleString).string
        
        let nextPanelSubtitleNodeLayout = self.nextPanelSubtitleNode.updateLayout(states: [
            TitleNodeStateRegular: MultiScaleTextState(attributedText: nextPanelSubtitleString ?? subtitleString, constrainedSize: titleConstrainedSize),
            TitleNodeStateExpanded: MultiScaleTextState(attributedText: nextPanelSubtitleString ?? subtitleString, constrainedSize: titleConstrainedSize)
        ], mainState: TitleNodeStateRegular)
        if let _ = nextPanelSubtitleString {
            self.nextPanelSubtitleNode.isHidden = false
        }
        
        let usernameNodeLayout = self.usernameNode.updateLayout(states: [
            TitleNodeStateRegular: MultiScaleTextState(attributedText: usernameString, constrainedSize: CGSize(width: titleConstrainedSize.width, height: titleConstrainedSize.height)),
            TitleNodeStateExpanded: MultiScaleTextState(attributedText: usernameString, constrainedSize: CGSize(width: width - titleNodeLayout[TitleNodeStateExpanded]!.size.width - 8.0, height: titleConstrainedSize.height))
        ], mainState: TitleNodeStateRegular)
        self.usernameNode.accessibilityLabel = usernameString.string
        
        let avatarFrame = CGRect(origin: CGPoint(x: floor((width - avatarSize) / 2.0), y: statusBarHeight + 13.0), size: CGSize(width: avatarSize, height: avatarSize))
        let avatarCenter = CGPoint(x: (1.0 - transitionFraction) * avatarFrame.midX + transitionFraction * transitionSourceAvatarFrame.midX, y: (1.0 - transitionFraction) * avatarFrame.midY + transitionFraction * transitionSourceAvatarFrame.midY)
        
        let titleSize = titleNodeLayout[TitleNodeStateRegular]!.size
        let titleExpandedSize = titleNodeLayout[TitleNodeStateExpanded]!.size
        let subtitleSize = subtitleNodeLayout[TitleNodeStateRegular]!.size
        let _ = panelSubtitleNodeLayout[TitleNodeStateRegular]!.size
        let _ = nextPanelSubtitleNodeLayout[TitleNodeStateRegular]!.size
        let usernameSize = usernameNodeLayout[TitleNodeStateRegular]!.size
        
        var titleHorizontalOffset: CGFloat = 0.0
        if let image = self.titleCredibilityIconNode.image {
            titleHorizontalOffset = -(image.size.width + 4.0) / 2.0
            transition.updateFrame(node: self.titleCredibilityIconNode, frame: CGRect(origin: CGPoint(x: titleSize.width + 4.0, y: floor((titleSize.height - image.size.height) / 2.0) + 1.0), size: image.size))
            transition.updateFrame(node: self.titleExpandedCredibilityIconNode, frame: CGRect(origin: CGPoint(x: titleExpandedSize.width + 4.0, y: floor((titleExpandedSize.height - image.size.height) / 2.0) + 1.0), size: image.size))
        }
        
        var titleFrame: CGRect
        let subtitleFrame: CGRect
        let usernameFrame: CGRect
        let usernameSpacing: CGFloat = 4.0
        
        transition.updateFrame(node: self.avatarListNode.listContainerNode.bottomShadowNode, frame: CGRect(origin: CGPoint(x: 0.0, y: expandedAvatarHeight - 70.0), size: CGSize(width: width, height: 70.0)))
        
        if self.isAvatarExpanded {
            let minTitleSize = CGSize(width: titleSize.width * 0.7, height: titleSize.height * 0.7)
            let minTitleFrame = CGRect(origin: CGPoint(x: 16.0, y: expandedAvatarHeight - 58.0 - UIScreenPixel + (subtitleSize.height.isZero ? 10.0 : 0.0)), size: minTitleSize)

            titleFrame = CGRect(origin: CGPoint(x: minTitleFrame.midX - titleSize.width / 2.0, y: minTitleFrame.midY - titleSize.height / 2.0), size: titleSize)
            subtitleFrame = CGRect(origin: CGPoint(x: 16.0, y: minTitleFrame.maxY + 2.0), size: subtitleSize)
            usernameFrame = CGRect(origin: CGPoint(x: width - usernameSize.width - 16.0, y: minTitleFrame.midY - usernameSize.height / 2.0), size: usernameSize)
        } else {
            titleFrame = CGRect(origin: CGPoint(x: floorToScreenPixels((width - titleSize.width) / 2.0), y: avatarFrame.maxY + 7.0 + (subtitleSize.height.isZero ? 11.0 : 0.0) + 11.0), size: titleSize)
                        
            let totalSubtitleWidth = subtitleSize.width + usernameSpacing + usernameSize.width
            if usernameSize.width == 0.0 {
                subtitleFrame = CGRect(origin: CGPoint(x: floorToScreenPixels((width - subtitleSize.width) / 2.0), y: titleFrame.maxY + 1.0), size: subtitleSize)
                usernameFrame = CGRect(origin: CGPoint(x: floorToScreenPixels((width - usernameSize.width) / 2.0), y: subtitleFrame.maxY + 1.0), size: usernameSize)
            } else {
                subtitleFrame = CGRect(origin: CGPoint(x: floorToScreenPixels((width - totalSubtitleWidth) / 2.0), y: titleFrame.maxY + 1.0), size: subtitleSize)
                usernameFrame = CGRect(origin: CGPoint(x: subtitleFrame.maxX + usernameSpacing, y: titleFrame.maxY + 1.0), size: usernameSize)
            }
        }
        
        let singleTitleLockOffset: CGFloat = (peer?.id == self.context.account.peerId || subtitleSize.height.isZero) ? 8.0 : 0.0
        
        let titleLockOffset: CGFloat = 7.0 + singleTitleLockOffset
        let titleMaxLockOffset: CGFloat = 7.0
        var titleCollapseOffset = titleFrame.midY - statusBarHeight - titleLockOffset
        if case .regular = metrics.widthClass {
            titleCollapseOffset -= 7.0
        }
        let titleOffset = -min(titleCollapseOffset, contentOffset)
        let titleCollapseFraction = max(0.0, min(1.0, contentOffset / titleCollapseOffset))
        
        let titleMinScale: CGFloat = 0.6
        let subtitleMinScale: CGFloat = 0.8
        let avatarMinScale: CGFloat = 0.7
        
        let apparentTitleLockOffset = (1.0 - titleCollapseFraction) * 0.0 + titleCollapseFraction * titleMaxLockOffset

        let paneAreaExpansionDistance: CGFloat = 32.0
        let effectiveAreaExpansionFraction: CGFloat
        if state.isEditing {
            effectiveAreaExpansionFraction = 0.0
        } else if isSettings {
            var paneAreaExpansionDelta = (self.frame.maxY - navigationHeight) - contentOffset
            paneAreaExpansionDelta = max(0.0, min(paneAreaExpansionDelta, paneAreaExpansionDistance))
            effectiveAreaExpansionFraction = 1.0 - paneAreaExpansionDelta / paneAreaExpansionDistance
        } else {
            var paneAreaExpansionDelta = (paneContainerY - navigationHeight) - contentOffset
            paneAreaExpansionDelta = max(0.0, min(paneAreaExpansionDelta, paneAreaExpansionDistance))
            effectiveAreaExpansionFraction = 1.0 - paneAreaExpansionDelta / paneAreaExpansionDistance
        }
        
        let secondarySeparatorAlpha = 1.0 - effectiveAreaExpansionFraction
        if self.navigationTransition == nil && !self.isSettings && effectiveSeparatorAlpha == 1.0 && secondarySeparatorAlpha < 1.0 {
            effectiveSeparatorAlpha = secondarySeparatorAlpha
        }
        transition.updateAlpha(node: self.separatorNode, alpha: effectiveSeparatorAlpha)
        
        self.titleNode.update(stateFractions: [
            TitleNodeStateRegular: self.isAvatarExpanded ? 0.0 : 1.0,
            TitleNodeStateExpanded: self.isAvatarExpanded ? 1.0 : 0.0
        ], transition: transition)
        
        let subtitleAlpha: CGFloat
        var subtitleOffset: CGFloat = 0.0
        let panelSubtitleAlpha: CGFloat
        var panelSubtitleOffset: CGFloat = 0.0
        if self.isSettings {
            subtitleAlpha = 1.0 - titleCollapseFraction
            panelSubtitleAlpha = 0.0
        } else {
            if (panelSubtitleString ?? subtitleString).string != subtitleString.string {
                subtitleAlpha = 1.0 - effectiveAreaExpansionFraction
                panelSubtitleAlpha = effectiveAreaExpansionFraction
                subtitleOffset = -effectiveAreaExpansionFraction * 5.0
                panelSubtitleOffset = (1.0 - effectiveAreaExpansionFraction) * 5.0
            } else {
                subtitleAlpha = 1.0
                panelSubtitleAlpha = 0.0
            }
        }
        self.subtitleNode.update(stateFractions: [
            TitleNodeStateRegular: self.isAvatarExpanded ? 0.0 : 1.0,
            TitleNodeStateExpanded: self.isAvatarExpanded ? 1.0 : 0.0
        ], alpha: subtitleAlpha, transition: transition)

        self.panelSubtitleNode.update(stateFractions: [
            TitleNodeStateRegular: self.isAvatarExpanded ? 0.0 : 1.0,
            TitleNodeStateExpanded: self.isAvatarExpanded ? 1.0 : 0.0
        ], alpha: panelSubtitleAlpha, transition: transition)
        
        self.nextPanelSubtitleNode.update(stateFractions: [
            TitleNodeStateRegular: self.isAvatarExpanded ? 0.0 : 1.0,
            TitleNodeStateExpanded: self.isAvatarExpanded ? 1.0 : 0.0
        ], alpha: panelSubtitleAlpha, transition: transition)
        
        self.usernameNode.update(stateFractions: [
            TitleNodeStateRegular: self.isAvatarExpanded ? 0.0 : 1.0,
            TitleNodeStateExpanded: self.isAvatarExpanded ? 1.0 : 0.0
        ], alpha: subtitleAlpha, transition: transition)
        
        let avatarScale: CGFloat
        let avatarOffset: CGFloat
        if self.navigationTransition != nil {
            avatarScale = ((1.0 - transitionFraction) * avatarFrame.width + transitionFraction * transitionSourceAvatarFrame.width) / avatarFrame.width
            avatarOffset = 0.0
        } else {
            avatarScale = 1.0 * (1.0 - titleCollapseFraction) + avatarMinScale * titleCollapseFraction
            avatarOffset = apparentTitleLockOffset + 0.0 * (1.0 - titleCollapseFraction) + 10.0 * titleCollapseFraction
        }
                
        if self.isAvatarExpanded {
            self.avatarListNode.listContainerNode.isHidden = false
            if !transitionSourceAvatarFrame.width.isZero {
                transition.updateCornerRadius(node: self.avatarListNode.listContainerNode, cornerRadius: transitionFraction * transitionSourceAvatarFrame.width / 2.0)
                transition.updateCornerRadius(node: self.avatarListNode.listContainerNode.controlsClippingNode, cornerRadius: transitionFraction * transitionSourceAvatarFrame.width / 2.0)
            } else {
                transition.updateCornerRadius(node: self.avatarListNode.listContainerNode, cornerRadius: 0.0)
                transition.updateCornerRadius(node: self.avatarListNode.listContainerNode.controlsClippingNode, cornerRadius: 0.0)
            }
        } else if self.avatarListNode.listContainerNode.cornerRadius != avatarSize / 2.0 {
            transition.updateCornerRadius(node: self.avatarListNode.listContainerNode.controlsClippingNode, cornerRadius: avatarSize / 2.0)
            transition.updateCornerRadius(node: self.avatarListNode.listContainerNode, cornerRadius: avatarSize / 2.0, completion: { [weak self] _ in
                guard let strongSelf = self else {
                    return
                }
                strongSelf.avatarListNode.avatarContainerNode.canAttachVideo = true
                strongSelf.avatarListNode.listContainerNode.isHidden = true
                if !strongSelf.skipCollapseCompletion {
                    DispatchQueue.main.async {
                        strongSelf.avatarListNode.listContainerNode.isCollapsing = false
                    }
                }
            })
        }
        
        self.avatarListNode.update(size: CGSize(), avatarSize: avatarSize, isExpanded: self.isAvatarExpanded, peer: peer, theme: presentationData.theme, transition: transition)
        self.editingContentNode.avatarNode.update(peer: peer, item: self.avatarListNode.item, updatingAvatar: state.updatingAvatar, uploadProgress: state.avatarUploadProgress, theme: presentationData.theme, avatarSize: avatarSize, isEditing: state.isEditing)
        self.avatarOverlayNode.update(peer: peer, item: self.avatarListNode.item, updatingAvatar: state.updatingAvatar, uploadProgress: state.avatarUploadProgress, theme: presentationData.theme, avatarSize: avatarSize, isEditing: state.isEditing)
        if additive {
            transition.updateSublayerTransformScaleAdditive(node: self.avatarListNode.avatarContainerNode, scale: avatarScale)
            transition.updateSublayerTransformScaleAdditive(node: self.avatarOverlayNode, scale: avatarScale)
        } else {
            transition.updateSublayerTransformScale(node: self.avatarListNode.avatarContainerNode, scale: avatarScale)
            transition.updateSublayerTransformScale(node: self.avatarOverlayNode, scale: avatarScale)
        }
        let apparentAvatarFrame: CGRect
        let controlsClippingFrame: CGRect
        if self.isAvatarExpanded {
            let expandedAvatarCenter = CGPoint(x: expandedAvatarListSize.width / 2.0, y: expandedAvatarListSize.height / 2.0 - contentOffset / 2.0)
            apparentAvatarFrame = CGRect(origin: CGPoint(x: expandedAvatarCenter.x * (1.0 - transitionFraction) + transitionFraction * avatarCenter.x, y: expandedAvatarCenter.y * (1.0 - transitionFraction) + transitionFraction * avatarCenter.y), size: CGSize())
            if !transitionSourceAvatarFrame.width.isZero {
                let expandedFrame = CGRect(origin: CGPoint(x: 0.0, y: 0.0), size: expandedAvatarListSize)
                controlsClippingFrame = CGRect(origin: CGPoint(x: transitionFraction * transitionSourceAvatarFrame.minX + (1.0 - transitionFraction) * expandedFrame.minX, y: transitionFraction * transitionSourceAvatarFrame.minY + (1.0 - transitionFraction) * expandedFrame.minY), size: CGSize(width: transitionFraction * transitionSourceAvatarFrame.width + (1.0 - transitionFraction) * expandedFrame.width, height: transitionFraction * transitionSourceAvatarFrame.height + (1.0 - transitionFraction) * expandedFrame.height))
            } else {
                controlsClippingFrame = CGRect(origin: CGPoint(x: 0.0, y: 0.0), size: expandedAvatarListSize)
            }
        } else {
            apparentAvatarFrame = CGRect(origin: CGPoint(x: avatarCenter.x - avatarFrame.width / 2.0, y: -contentOffset + avatarOffset + avatarCenter.y - avatarFrame.height / 2.0), size: avatarFrame.size)
            controlsClippingFrame = apparentAvatarFrame
        }
        transition.updateFrameAdditive(node: self.avatarListNode, frame: CGRect(origin: apparentAvatarFrame.center, size: CGSize()))
        transition.updateFrameAdditive(node: self.avatarOverlayNode, frame: CGRect(origin: apparentAvatarFrame.center, size: CGSize()))
        
        let avatarListContainerFrame: CGRect
        let avatarListContainerScale: CGFloat
        if self.isAvatarExpanded {
            if !transitionSourceAvatarFrame.width.isZero {
                let neutralAvatarListContainerSize = expandedAvatarListSize
                let avatarListContainerSize = CGSize(width: neutralAvatarListContainerSize.width * (1.0 - transitionFraction) + transitionSourceAvatarFrame.width * transitionFraction, height: neutralAvatarListContainerSize.height * (1.0 - transitionFraction) + transitionSourceAvatarFrame.height * transitionFraction)
                avatarListContainerFrame = CGRect(origin: CGPoint(x: -avatarListContainerSize.width / 2.0, y: -avatarListContainerSize.height / 2.0), size: avatarListContainerSize)
            } else {
                avatarListContainerFrame = CGRect(origin: CGPoint(x: -expandedAvatarListSize.width / 2.0, y: -expandedAvatarListSize.height / 2.0), size: expandedAvatarListSize)
            }
            avatarListContainerScale = 1.0 + max(0.0, -contentOffset / avatarListContainerFrame.height)
        } else {
            avatarListContainerFrame = CGRect(origin: CGPoint(x: -apparentAvatarFrame.width / 2.0, y: -apparentAvatarFrame.height / 2.0), size: apparentAvatarFrame.size)
            avatarListContainerScale = avatarScale
        }
        transition.updateFrame(node: self.avatarListNode.listContainerNode, frame: avatarListContainerFrame)
        let innerScale = avatarListContainerFrame.height / expandedAvatarListSize.height
        let innerDeltaX = (avatarListContainerFrame.width - expandedAvatarListSize.width) / 2.0
        let innerDeltaY = (avatarListContainerFrame.height - expandedAvatarListSize.height) / 2.0
        transition.updateSublayerTransformScale(node: self.avatarListNode.listContainerNode, scale: innerScale)
        transition.updateFrameAdditive(node: self.avatarListNode.listContainerNode.contentNode, frame: CGRect(origin: CGPoint(x: innerDeltaX + expandedAvatarListSize.width / 2.0, y: innerDeltaY + expandedAvatarListSize.height / 2.0), size: CGSize()))
        
        transition.updateFrameAdditive(node: self.avatarListNode.listContainerNode.controlsClippingOffsetNode, frame: CGRect(origin: controlsClippingFrame.center, size: CGSize()))
        transition.updateFrame(node: self.avatarListNode.listContainerNode.controlsClippingNode, frame: CGRect(origin: CGPoint(x: -controlsClippingFrame.width / 2.0, y: -controlsClippingFrame.height / 2.0), size: controlsClippingFrame.size))
        transition.updateFrameAdditive(node: self.avatarListNode.listContainerNode.controlsContainerNode, frame: CGRect(origin: CGPoint(x: -controlsClippingFrame.minX, y: -controlsClippingFrame.minY), size: CGSize(width: expandedAvatarListSize.width, height: expandedAvatarListSize.height)))
        
        transition.updateFrame(node: self.avatarListNode.listContainerNode.topShadowNode, frame: CGRect(origin: CGPoint(), size: CGSize(width: expandedAvatarListSize.width, height: navigationHeight + 20.0)))
        transition.updateFrame(node: self.avatarListNode.listContainerNode.stripContainerNode, frame: CGRect(origin: CGPoint(x: 0.0, y: statusBarHeight < 25.0 ? (statusBarHeight + 2.0) : (statusBarHeight - 3.0)), size: CGSize(width: expandedAvatarListSize.width, height: 2.0)))
        transition.updateFrame(node: self.avatarListNode.listContainerNode.highlightContainerNode, frame: CGRect(origin: CGPoint(x: 0.0, y: 0.0), size: CGSize(width: expandedAvatarListSize.width, height: expandedAvatarListSize.height)))
        transition.updateAlpha(node: self.avatarListNode.listContainerNode.controlsContainerNode, alpha: self.isAvatarExpanded ? (1.0 - transitionFraction) : 0.0)
        
        if additive {
            transition.updateSublayerTransformScaleAdditive(node: self.avatarListNode.listContainerTransformNode, scale: avatarListContainerScale)
        } else {
            transition.updateSublayerTransformScale(node: self.avatarListNode.listContainerTransformNode, scale: avatarListContainerScale)
        }
        
        self.avatarListNode.listContainerNode.update(size: expandedAvatarListSize, peer: peer, isExpanded: self.isAvatarExpanded, transition: transition)
        if self.avatarListNode.listContainerNode.isCollapsing && !self.ignoreCollapse {
            self.avatarListNode.avatarContainerNode.canAttachVideo = false
        }
        
        let panelWithAvatarHeight: CGFloat = 40.0 + avatarSize
        
        let rawHeight: CGFloat
        let height: CGFloat
        let maxY: CGFloat
        if self.isAvatarExpanded {
            rawHeight = expandedAvatarHeight
            height = max(navigationHeight, rawHeight - contentOffset)
            maxY = height
        } else {
            rawHeight = navigationHeight + panelWithAvatarHeight
            height = navigationHeight + max(0.0, panelWithAvatarHeight - contentOffset)
            maxY = navigationHeight + panelWithAvatarHeight - contentOffset
        }
        
        let apparentHeight = (1.0 - transitionFraction) * height + transitionFraction * transitionSourceHeight
        
        if !titleSize.width.isZero && !titleSize.height.isZero {
            if self.navigationTransition != nil {
                var neutralTitleScale: CGFloat = 1.0
                var neutralSubtitleScale: CGFloat = 1.0
                if self.isAvatarExpanded {
                    neutralTitleScale = 0.7
                    neutralSubtitleScale = 1.0
                }
                                
                let titleScale = (transitionFraction * transitionSourceTitleFrame.height + (1.0 - transitionFraction) * titleFrame.height * neutralTitleScale) / (titleFrame.height)
                let subtitleScale = max(0.01, min(10.0, (transitionFraction * transitionSourceSubtitleFrame.height + (1.0 - transitionFraction) * subtitleFrame.height * neutralSubtitleScale) / (subtitleFrame.height)))
                
                var titleFrame = titleFrame
                if !self.isAvatarExpanded {
                    titleFrame = titleFrame.offsetBy(dx: self.isAvatarExpanded ? 0.0 : titleHorizontalOffset * titleScale, dy: 0.0)
                }
                
                let titleCenter = CGPoint(x: transitionFraction * transitionSourceTitleFrame.midX + (1.0 - transitionFraction) * titleFrame.midX, y: transitionFraction * transitionSourceTitleFrame.midY + (1.0 - transitionFraction) * titleFrame.midY)
                let subtitleCenter = CGPoint(x: transitionFraction * transitionSourceSubtitleFrame.midX + (1.0 - transitionFraction) * subtitleFrame.midX, y: transitionFraction * transitionSourceSubtitleFrame.midY + (1.0 - transitionFraction) * subtitleFrame.midY)
                
                let rawTitleFrame = CGRect(origin: CGPoint(x: titleCenter.x - titleFrame.size.width * neutralTitleScale / 2.0, y: titleCenter.y - titleFrame.size.height * neutralTitleScale / 2.0), size: CGSize(width: titleFrame.size.width * neutralTitleScale, height: titleFrame.size.height * neutralTitleScale))
                self.titleNodeRawContainer.frame = rawTitleFrame
                transition.updateFrameAdditiveToCenter(node: self.titleNodeContainer, frame: CGRect(origin: rawTitleFrame.center, size: CGSize()))
                transition.updateFrame(node: self.titleNode, frame: CGRect(origin: CGPoint(), size: CGSize()))
                let rawSubtitleFrame = CGRect(origin: CGPoint(x: subtitleCenter.x - subtitleFrame.size.width / 2.0, y: subtitleCenter.y - subtitleFrame.size.height / 2.0), size: subtitleFrame.size)
                self.subtitleNodeRawContainer.frame = rawSubtitleFrame
                transition.updateFrameAdditiveToCenter(node: self.subtitleNodeContainer, frame: CGRect(origin: rawSubtitleFrame.center, size: CGSize()))
                transition.updateFrame(node: self.subtitleNode, frame: CGRect(origin: CGPoint(x: 0.0, y: subtitleOffset), size: CGSize()))
                transition.updateFrame(node: self.panelSubtitleNode, frame: CGRect(origin: CGPoint(x: 0.0, y: panelSubtitleOffset), size: CGSize()))
                transition.updateFrame(node: self.nextPanelSubtitleNode, frame: CGRect(origin: CGPoint(x: 0.0, y: panelSubtitleOffset), size: CGSize()))
                transition.updateFrame(node: self.usernameNode, frame: CGRect(origin: CGPoint(), size: CGSize()))
                transition.updateSublayerTransformScale(node: self.titleNodeContainer, scale: titleScale)
                transition.updateSublayerTransformScale(node: self.subtitleNodeContainer, scale: subtitleScale)
                transition.updateSublayerTransformScale(node: self.usernameNodeContainer, scale: subtitleScale)
            } else {
                let titleScale: CGFloat
                let subtitleScale: CGFloat
                var subtitleOffset: CGFloat = 0.0
                if self.isAvatarExpanded {
                    titleScale = 0.7
                    subtitleScale = 1.0
                } else {
                    titleScale = (1.0 - titleCollapseFraction) * 1.0 + titleCollapseFraction * titleMinScale
                    subtitleScale = (1.0 - titleCollapseFraction) * 1.0 + titleCollapseFraction * subtitleMinScale
                    subtitleOffset = titleCollapseFraction * -2.0
                }
                
                let rawTitleFrame = titleFrame.offsetBy(dx: self.isAvatarExpanded ? 0.0 : titleHorizontalOffset * titleScale, dy: 0.0)
                self.titleNodeRawContainer.frame = rawTitleFrame
                transition.updateFrame(node: self.titleNode, frame: CGRect(origin: CGPoint(), size: CGSize()))
                let rawSubtitleFrame = subtitleFrame
                self.subtitleNodeRawContainer.frame = rawSubtitleFrame
                let rawUsernameFrame = usernameFrame
                self.usernameNodeRawContainer.frame = rawUsernameFrame
                if self.isAvatarExpanded {
                    transition.updateFrameAdditive(node: self.titleNodeContainer, frame: CGRect(origin: rawTitleFrame.center, size: CGSize()).offsetBy(dx: 0.0, dy: titleOffset + apparentTitleLockOffset))
                    transition.updateFrameAdditive(node: self.subtitleNodeContainer, frame: CGRect(origin: rawSubtitleFrame.center, size: CGSize()).offsetBy(dx: 0.0, dy: titleOffset))
                    transition.updateFrameAdditive(node: self.usernameNodeContainer, frame: CGRect(origin: rawUsernameFrame.center, size: CGSize()).offsetBy(dx: 0.0, dy: titleOffset))
                } else {
                    transition.updateFrameAdditiveToCenter(node: self.titleNodeContainer, frame: CGRect(origin: rawTitleFrame.center, size: CGSize()).offsetBy(dx: 0.0, dy: titleOffset + apparentTitleLockOffset))
                    
                    var subtitleCenter = rawSubtitleFrame.center
                    subtitleCenter.x = rawTitleFrame.center.x + (subtitleCenter.x - rawTitleFrame.center.x) * subtitleScale
                    subtitleCenter.y += subtitleOffset
                    transition.updateFrameAdditiveToCenter(node: self.subtitleNodeContainer, frame: CGRect(origin: subtitleCenter, size: CGSize()).offsetBy(dx: 0.0, dy: titleOffset))
                    
                    var usernameCenter = rawUsernameFrame.center
                    usernameCenter.x = rawTitleFrame.center.x + (usernameCenter.x - rawTitleFrame.center.x) * subtitleScale
                    transition.updateFrameAdditiveToCenter(node: self.usernameNodeContainer, frame: CGRect(origin: usernameCenter, size: CGSize()).offsetBy(dx: 0.0, dy: titleOffset))
                }
                transition.updateFrame(node: self.subtitleNode, frame: CGRect(origin: CGPoint(x: 0.0, y: subtitleOffset), size: CGSize()))
                transition.updateFrame(node: self.panelSubtitleNode, frame: CGRect(origin: CGPoint(x: 0.0, y: panelSubtitleOffset), size: CGSize()))
                transition.updateFrame(node: self.nextPanelSubtitleNode, frame: CGRect(origin: CGPoint(x: 0.0, y: panelSubtitleOffset), size: CGSize()))
                transition.updateFrame(node: self.usernameNode, frame: CGRect(origin: CGPoint(), size: CGSize()))
                transition.updateSublayerTransformScaleAdditive(node: self.titleNodeContainer, scale: titleScale)
                transition.updateSublayerTransformScaleAdditive(node: self.subtitleNodeContainer, scale: subtitleScale)
                transition.updateSublayerTransformScaleAdditive(node: self.usernameNodeContainer, scale: subtitleScale)
            }
        }
        
        let buttonSpacing: CGFloat = 8.0
        let buttonSideInset = max(16.0, containerInset)
        var buttonRightOrigin = CGPoint(x: width - buttonSideInset, y: maxY + 25.0 - navigationHeight - UIScreenPixel)
        let buttonWidth = (width - buttonSideInset * 2.0 + buttonSpacing) / CGFloat(buttonKeys.count) - buttonSpacing
        
        let apparentButtonSize = CGSize(width: buttonWidth, height: 58.0)
        let buttonsAlpha: CGFloat = 1.0
        let buttonsVerticalOffset: CGFloat = 0.0
        
        let buttonsAlphaTransition = transition
        
        for buttonKey in buttonKeys.reversed() {
            let buttonNode: PeerInfoHeaderButtonNode
            var wasAdded = false
            if let current = self.buttonNodes[buttonKey] {
                buttonNode = current
            } else {
                wasAdded = true
                buttonNode = PeerInfoHeaderButtonNode(key: buttonKey, action: { [weak self] buttonNode, gesture in
                    self?.buttonPressed(buttonNode, gesture: gesture)
                })
                self.buttonNodes[buttonKey] = buttonNode
                self.buttonsContainerNode.addSubnode(buttonNode)
            }
            
            let buttonFrame = CGRect(origin: CGPoint(x: buttonRightOrigin.x - apparentButtonSize.width, y: buttonRightOrigin.y), size: apparentButtonSize)
            let buttonTransition: ContainedViewLayoutTransition = wasAdded ? .immediate : transition
            
            let apparentButtonFrame = buttonFrame.offsetBy(dx: 0.0, dy: buttonsVerticalOffset)
            if additive {
                buttonTransition.updateFrameAdditiveToCenter(node: buttonNode, frame: apparentButtonFrame)
            } else {
                buttonTransition.updateFrame(node: buttonNode, frame: apparentButtonFrame)
            }
            let buttonText: String
            let buttonIcon: PeerInfoHeaderButtonIcon
            switch buttonKey {
            case .message:
                buttonText = presentationData.strings.PeerInfo_ButtonMessage
                buttonIcon = .message
            case .discussion:
                buttonText = presentationData.strings.PeerInfo_ButtonDiscuss
                buttonIcon = .message
            case .call:
                buttonText = presentationData.strings.PeerInfo_ButtonCall
                buttonIcon = .call
            case .videoCall:
                buttonText = presentationData.strings.PeerInfo_ButtonVideoCall
                buttonIcon = .videoCall
            case .voiceChat:
                if let channel = peer as? TelegramChannel, case .broadcast = channel.info {
                    buttonText = presentationData.strings.PeerInfo_ButtonLiveStream
                } else {
                    buttonText = presentationData.strings.PeerInfo_ButtonVoiceChat
                }
                buttonIcon = .voiceChat
            case .mute:
                if let notificationSettings = notificationSettings, case .muted = notificationSettings.muteState {
                    buttonText = presentationData.strings.PeerInfo_ButtonUnmute
                    buttonIcon = .unmute
                } else {
                    buttonText = presentationData.strings.PeerInfo_ButtonMute
                    buttonIcon = .mute
                }
            case .more:
                buttonText = presentationData.strings.PeerInfo_ButtonMore
                buttonIcon = .more
            case .addMember:
                buttonText = presentationData.strings.PeerInfo_ButtonAddMember
                buttonIcon = .addMember
            case .search:
                buttonText = presentationData.strings.PeerInfo_ButtonSearch
                buttonIcon = .search
            case .leave:
                buttonText = presentationData.strings.PeerInfo_ButtonLeave
                buttonIcon = .leave
            case .stop:
                buttonText = presentationData.strings.PeerInfo_ButtonStop
                buttonIcon = .stop
            }
            
            var isActive = true
            if let highlightedButton = state.highlightedButton {
                isActive = buttonKey == highlightedButton
            }
            
            buttonNode.update(size: buttonFrame.size, text: buttonText, icon: buttonIcon, isActive: isActive, isExpanded: false, presentationData: presentationData, transition: buttonTransition)
            
            if wasAdded {
                buttonNode.alpha = 0.0
            }
            buttonsAlphaTransition.updateAlpha(node: buttonNode, alpha: buttonsAlpha)
            
            if case .mute = buttonKey, buttonNode.containerNode.alpha.isZero, additive {
                if case let .animated(duration, curve) = transition {
                    ContainedViewLayoutTransition.animated(duration: duration * 0.3, curve: curve).updateAlpha(node: buttonNode.containerNode, alpha: 1.0)
                } else {
                    transition.updateAlpha(node: buttonNode.containerNode, alpha: 1.0)
                }
            } else {
                transition.updateAlpha(node: buttonNode.containerNode, alpha: 1.0)
            }
            buttonRightOrigin.x -= apparentButtonSize.width + buttonSpacing
        }
        
        for key in self.buttonNodes.keys {
            if !buttonKeys.contains(key) {
                if let buttonNode = self.buttonNodes[key] {
                    self.buttonNodes.removeValue(forKey: key)
                    transition.updateAlpha(node: buttonNode, alpha: 0.0) { [weak buttonNode] _ in
                        buttonNode?.removeFromSupernode()
                    }
                }
            }
        }
        
        let resolvedRegularHeight: CGFloat
        if self.isAvatarExpanded {
            resolvedRegularHeight = expandedAvatarListSize.height
        } else {
            resolvedRegularHeight = panelWithAvatarHeight + navigationHeight
        }
        
        let backgroundFrame: CGRect
        let separatorFrame: CGRect
        
        let resolvedHeight: CGFloat
        
        if state.isEditing {
            resolvedHeight = editingContentHeight
            backgroundFrame = CGRect(origin: CGPoint(x: 0.0, y: -2000.0 + max(navigationHeight, resolvedHeight - contentOffset)), size: CGSize(width: width, height: 2000.0))
            separatorFrame = CGRect(origin: CGPoint(x: 0.0, y: max(navigationHeight, resolvedHeight - contentOffset)), size: CGSize(width: width, height: UIScreenPixel))
        } else {
            resolvedHeight = resolvedRegularHeight
            backgroundFrame = CGRect(origin: CGPoint(x: 0.0, y: -2000.0 + apparentHeight), size: CGSize(width: width, height: 2000.0))
            separatorFrame = CGRect(origin: CGPoint(x: 0.0, y: apparentHeight), size: CGSize(width: width, height: UIScreenPixel))
        }
        
        transition.updateFrame(node: self.regularContentNode, frame: CGRect(origin: CGPoint(), size: CGSize(width: width, height: resolvedHeight)))
        transition.updateFrame(node: self.buttonsContainerNode, frame: CGRect(origin: CGPoint(x: 0.0, y: navigationHeight + UIScreenPixel), size: CGSize(width: width, height: resolvedHeight - navigationHeight + 180.0)))
        
        if additive {
            transition.updateFrameAdditive(node: self.backgroundNode, frame: backgroundFrame)
            self.backgroundNode.update(size: self.backgroundNode.bounds.size, transition: transition)
            transition.updateFrameAdditive(node: self.expandedBackgroundNode, frame: backgroundFrame)
            self.expandedBackgroundNode.update(size: self.expandedBackgroundNode.bounds.size, transition: transition)
            transition.updateFrameAdditive(node: self.separatorNode, frame: separatorFrame)
        } else {
            transition.updateFrame(node: self.backgroundNode, frame: backgroundFrame)
            self.backgroundNode.update(size: self.backgroundNode.bounds.size, transition: transition)
            transition.updateFrame(node: self.expandedBackgroundNode, frame: backgroundFrame)
            self.expandedBackgroundNode.update(size: self.expandedBackgroundNode.bounds.size, transition: transition)
            transition.updateFrame(node: self.separatorNode, frame: separatorFrame)
        }
        
        return resolvedHeight
    }
    
    private func buttonPressed(_ buttonNode: PeerInfoHeaderButtonNode, gesture: ContextGesture?) {
        self.performButtonAction?(buttonNode.key, gesture)
    }
    
    override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        guard let result = super.hitTest(point, with: event) else {
            return nil
        }
        if result.isDescendant(of: self.navigationButtonContainer.view) {
            return result
        }
        if !self.backgroundNode.frame.contains(point) {
            return nil
        }
        
        if self.currentCredibilityIcon == .premium && !(self.state?.isEditing ?? false) {
            let iconFrame = self.titleCredibilityIconNode.view.convert(self.titleCredibilityIconNode.bounds, to: self.view)
            let expandedIconFrame = self.titleExpandedCredibilityIconNode.view.convert(self.titleExpandedCredibilityIconNode.bounds, to: self.view)
            if expandedIconFrame.contains(point) && self.isAvatarExpanded {
                return self.titleExpandedCredibilityIconNode.view
            } else if iconFrame.contains(point) {
                return self.titleCredibilityIconNode.view
            }
        }
        
        if result == self.view || result == self.regularContentNode.view || result == self.editingContentNode.view {
            return nil
        }
        return result
    }
    
    func updateIsAvatarExpanded(_ isAvatarExpanded: Bool, transition: ContainedViewLayoutTransition) {
        if self.isAvatarExpanded != isAvatarExpanded {
            self.isAvatarExpanded = isAvatarExpanded
            if isAvatarExpanded {
                self.avatarListNode.listContainerNode.selectFirstItem()
            }
            if case .animated = transition, !isAvatarExpanded {
                self.avatarListNode.animateAvatarCollapse(transition: transition)
            }
        }
    }
}
