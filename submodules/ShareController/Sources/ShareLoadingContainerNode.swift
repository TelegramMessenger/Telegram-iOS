import Foundation
import UIKit
import AsyncDisplayKit
import SwiftSignalKit
import Display
import Postbox
import TelegramPresentationData
import ActivityIndicator
import RadialStatusNode
import AnimatedStickerNode
import TelegramAnimatedStickerNode
import AppBundle
import TelegramUniversalVideoContent
import TelegramCore
import AccountContext

public enum ShareLoadingState {
    case preparing
    case progress(Float)
    case done
}

protocol ShareLoadingContainer: ASDisplayNode {
    var state: ShareLoadingState { get set }
}

public final class ShareLoadingContainerNode: ASDisplayNode, ShareContentContainerNode, ShareLoadingContainer {
    private var contentOffsetUpdated: ((CGFloat, ContainedViewLayoutTransition) -> Void)?
    
    private let theme: PresentationTheme
    private let activityIndicator: ActivityIndicator
    private let statusNode: RadialStatusNode
    private let doneStatusNode: RadialStatusNode
    
    public var state: ShareLoadingState = .preparing {
        didSet {
            switch self.state {
                case .preparing:
                    self.activityIndicator.isHidden = false
                    self.statusNode.isHidden = true
                case let .progress(value):
                    self.activityIndicator.isHidden = true
                    self.statusNode.isHidden = false
                    self.statusNode.transitionToState(.progress(color: self.theme.actionSheet.controlAccentColor, lineWidth: 2.0, value: max(0.12, CGFloat(value)), cancelEnabled: false, animateRotation: true), completion: {})
                case .done:
                    self.activityIndicator.isHidden = true
                    self.statusNode.isHidden = false
                    self.statusNode.transitionToState(.progress(color: self.theme.actionSheet.controlAccentColor, lineWidth: 2.0, value: 1.0, cancelEnabled: false, animateRotation: true), completion: {})
                    self.doneStatusNode.transitionToState(.check(self.theme.actionSheet.controlAccentColor), completion: {})
            }
        }
    }
    
    public init(theme: PresentationTheme, forceNativeAppearance: Bool) {
        self.theme = theme
        self.activityIndicator = ActivityIndicator(type: .custom(theme.actionSheet.controlAccentColor, !forceNativeAppearance ? 22.0 : 50.0, 2.0, forceNativeAppearance))
        self.statusNode = RadialStatusNode(backgroundNodeColor: .clear)
        self.doneStatusNode = RadialStatusNode(backgroundNodeColor: .clear)
        
        super.init()
        
        self.addSubnode(self.activityIndicator)
        self.addSubnode(self.statusNode)
        self.addSubnode(self.doneStatusNode)
        self.doneStatusNode.transitionToState(.progress(color: self.theme.actionSheet.controlAccentColor, lineWidth: 2.0, value: 0.0, cancelEnabled: false, animateRotation: true), completion: {})
    }
    
    public func activate() {
    }
    
    public func deactivate() {
    }
    
    public func setEnsurePeerVisibleOnLayout(_ peerId: PeerId?) {
    }
    
    public func setContentOffsetUpdated(_ f: ((CGFloat, ContainedViewLayoutTransition) -> Void)?) {
        self.contentOffsetUpdated = f
    }
    
    public func updateLayout(size: CGSize, isLandscape: Bool, bottomInset: CGFloat, transition: ContainedViewLayoutTransition) {
        let nodeHeight: CGFloat = 125.0
        
        let indicatorSize = self.activityIndicator.calculateSizeThatFits(size)
        let indicatorFrame = CGRect(origin: CGPoint(x: floor((size.width - indicatorSize.width) / 2.0), y: size.height - nodeHeight + floor((nodeHeight - indicatorSize.height) / 2.0)), size: indicatorSize)
        transition.updateFrame(node: self.activityIndicator, frame: indicatorFrame)
        let statusFrame = indicatorFrame
        transition.updateFrame(node: self.statusNode, frame: statusFrame)
        transition.updateFrame(node: self.doneStatusNode, frame: statusFrame)
        
        self.contentOffsetUpdated?(-size.height + 64.0, transition)
    }
    
    public func updateSelectedPeers() {
    }
}

public final class ShareProlongedLoadingContainerNode: ASDisplayNode, ShareContentContainerNode, ShareLoadingContainer {
    private var contentOffsetUpdated: ((CGFloat, ContainedViewLayoutTransition) -> Void)?
    
    private let theme: PresentationTheme
    private let strings: PresentationStrings
    
    private let animationNode: AnimatedStickerNode
    private let doneAnimationNode: AnimatedStickerNode
    private let progressTextNode: ImmediateTextNode
    
    private let progressBackgroundNode: ASDisplayNode
    private let progressForegroundNode: ASDisplayNode
    
    private let animationStatusDisposable = MetaDisposable()
        
    private var progressValue: CGFloat = 0.0
    private var targetProgressValue: CGFloat = 0.0
    private var animator: ConstantDisplayLinkAnimator?
    
    private var randomCompletionStart: CGFloat = .random(in: 0.94...0.97)
    private var isDone: Bool = false
    
    private var startTimestamp: Double?
    
    private var videoNode: UniversalVideoNode?
    
    public var state: ShareLoadingState = .preparing {
        didSet {
            switch self.state {
                case .preparing:
                    break
                case let .progress(value):
                    let currentTimestamp = CACurrentMediaTime()
                    if self.startTimestamp == nil {
                        self.startTimestamp = currentTimestamp
                    } else if let startTimestamp = self.startTimestamp, currentTimestamp - startTimestamp < 1.0, value > 0.5 && value < 0.9 {
                        self.randomCompletionStart = 0.8
                    }
                                
                    self.targetProgressValue = CGFloat(value) * self.randomCompletionStart
                
                    if self.animator == nil {
                        self.animator = ConstantDisplayLinkAnimator(update: { [weak self] in
                            if let strongSelf = self, strongSelf.targetProgressValue > strongSelf.progressValue {
                                let updatedProgress = strongSelf.progressValue + 0.005
                                strongSelf.progressValue = min(1.0, updatedProgress)
                                
                                if strongSelf.progressValue == 1.0 && !strongSelf.isDone {
                                    strongSelf.isDone = true
                                    strongSelf.animator?.invalidate()
                                    
                                    if let snapshotView = strongSelf.progressTextNode.view.snapshotContentTree() {
                                        snapshotView.frame = strongSelf.progressTextNode.frame
                                        strongSelf.view.addSubview(snapshotView)
                                        
                                        snapshotView.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.3, removeOnCompletion: false, completion: { [weak snapshotView] _ in
                                            snapshotView?.removeFromSuperview()
                                        })
                                        snapshotView.layer.animatePosition(from: CGPoint(), to: CGPoint(x: 0.0, y: -20.0), duration: 0.25, removeOnCompletion: false, additive: true)
                                        
                                        strongSelf.progressTextNode.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.3)
                                        strongSelf.progressTextNode.layer.animatePosition(from: CGPoint(x: 0.0, y: 20.0), to: CGPoint(), duration: 0.25, additive: true)
                                    }
                                }
                                
                                if let (size, isLandscape, bottomInset) = strongSelf.validLayout {
                                    strongSelf.updateLayout(size: size, isLandscape: isLandscape, bottomInset: bottomInset, transition: .immediate)
                                }
                            }
                        })
                        self.animator?.isPaused = false
                    }
                case .done:
                    if let (size, isLandscape, bottomInset) = self.validLayout {
                        self.updateLayout(size: size, isLandscape: isLandscape, bottomInset: bottomInset, transition: .animated(duration: 0.2, curve: .easeInOut))
                    }
                    self.animationNode.stopAtNearestLoop = true
                    self.animationNode.completed = { [weak self] _ in
                        if let strongSelf = self {
                            strongSelf.animationNode.visibility = false
                            strongSelf.doneAnimationNode.visibility = true
                            strongSelf.doneAnimationNode.isHidden = false
                        }
                    }
                    self.animationNode.frameUpdated = { [weak self] index, total in
                        if let strongSelf = self {
                            let progress = min(1.0, CGFloat(index) / CGFloat(total))
                            let delta = 1.0 - strongSelf.randomCompletionStart
                            strongSelf.targetProgressValue = strongSelf.randomCompletionStart + delta * progress * 0.5
                        }
                    }
                    self.doneAnimationNode.frameUpdated = { [weak self] index, total in
                        if let strongSelf = self {
                            let progress = min(1.0, CGFloat(index) / CGFloat(total) * 2.1)
                            let delta = 1.0 - strongSelf.randomCompletionStart
                            strongSelf.targetProgressValue = strongSelf.randomCompletionStart + delta * 0.5 + delta * progress * 0.5
                        }
                    }
                    self.doneAnimationNode.started = { [weak self] in
                        guard let strongSelf = self else {
                            return
                        }
                        strongSelf.animationNode.isHidden = true
                    }
            }
        }
    }
    
    private var elapsedTime: Double = 0.0
    public var completionDuration: Double {
        return self.elapsedTime + 3.0 + 0.15
    }
        
    public init(theme: PresentationTheme, strings: PresentationStrings, forceNativeAppearance: Bool, account: Account?, sharedContext: SharedAccountContext) {
        self.theme = theme
        self.strings = strings
        
        self.animationNode = DefaultAnimatedStickerNodeImpl()
        self.animationNode.setup(source: AnimatedStickerNodeLocalFileSource(name: "ShareProgress"), width: 384, height: 384, playbackMode: .loop, mode: .direct(cachePathPrefix: nil))
        self.animationNode.visibility = true
        
        self.doneAnimationNode = DefaultAnimatedStickerNodeImpl()
        self.doneAnimationNode.setup(source: AnimatedStickerNodeLocalFileSource(name: "ShareDone"), width: 384, height: 384, playbackMode: .once, mode: .direct(cachePathPrefix: nil))
        self.doneAnimationNode.visibility = false
        self.doneAnimationNode.isHidden = true
        
        self.progressTextNode = ImmediateTextNode()
        self.progressTextNode.textAlignment = .center
        
        self.progressBackgroundNode = ASDisplayNode()
        self.progressBackgroundNode.backgroundColor = theme.actionSheet.controlAccentColor.withMultipliedAlpha(0.2)
        self.progressBackgroundNode.cornerRadius = 3.0
        
        self.progressForegroundNode = ASDisplayNode()
        self.progressForegroundNode.backgroundColor = theme.actionSheet.controlAccentColor
        self.progressForegroundNode.cornerRadius = 3.0
        
        super.init()
        
        self.addSubnode(self.animationNode)
        self.addSubnode(self.doneAnimationNode)
        
        self.addSubnode(self.progressTextNode)
        
        self.addSubnode(self.progressBackgroundNode)
        self.addSubnode(self.progressForegroundNode)
        
        self.animationStatusDisposable.set((self.animationNode.status
        |> deliverOnMainQueue).start(next: { [weak self] status in
            if let strongSelf = self {
                strongSelf.elapsedTime = status.duration - status.timestamp
            }
        }))
        
        if let account = account, let path = getAppBundle().path(forResource: "BlankVideo", ofType: "m4v"), let size = fileSize(path) {
            let decoration = ChatBubbleVideoDecoration(corners: ImageCorners(), nativeSize: CGSize(width: 100.0, height: 100.0), contentMode: .aspectFit, backgroundColor: .black)
            
            let dummyFile = TelegramMediaFile(fileId: MediaId(namespace: 0, id: 1), partialReference: nil, resource: LocalFileReferenceMediaResource(localFilePath: path, randomId: 12345), previewRepresentations: [], videoThumbnails: [], immediateThumbnailData: nil, mimeType: "video/mp4", size: size, attributes: [.Video(duration: 1, size: PixelDimensions(width: 100, height: 100), flags: [])])
            
            let videoContent = NativeVideoContent(id: .message(1, MediaId(namespace: 0, id: 1)), fileReference: .standalone(media: dummyFile), streamVideo: .none, loopVideo: true, enableSound: false, fetchAutomatically: true, onlyFullSizeThumbnail: false, continuePlayingWithoutSoundOnLostAudioSession: false, placeholderColor: .black)
            
            let videoNode = UniversalVideoNode(postbox: account.postbox, audioSession: sharedContext.mediaManager.audioSession, manager: sharedContext.mediaManager.universalVideoManager, decoration: decoration, content: videoContent, priority: .embedded)
            videoNode.frame = CGRect(origin: CGPoint(), size: CGSize(width: 2.0, height: 2.0))
            videoNode.alpha = 0.01
            self.videoNode = videoNode
            
            self.addSubnode(videoNode)
            videoNode.canAttachContent = true
            videoNode.play()
        }
    }
    
    deinit {
        self.animationStatusDisposable.dispose()
    }
    
    public func activate() {
    }
    
    public func deactivate() {
    }
    
    public func setEnsurePeerVisibleOnLayout(_ peerId: PeerId?) {
    }
    
    public func setContentOffsetUpdated(_ f: ((CGFloat, ContainedViewLayoutTransition) -> Void)?) {
        self.contentOffsetUpdated = f
    }
    
    private var validLayout: (CGSize, Bool, CGFloat)?
    public func updateLayout(size: CGSize, isLandscape: Bool, bottomInset: CGFloat, transition: ContainedViewLayoutTransition) {
        self.validLayout = (size, isLandscape, bottomInset)
        
        let nodeHeight: CGFloat = 450.0
        
        let inset: CGFloat = 24.0
        let progressHeight: CGFloat = 6.0
        let spacing: CGFloat = 16.0
        
        let progress = self.progressValue
        
        let progressFrame = CGRect(x: inset, y: size.height - inset - progressHeight, width: size.width - inset * 2.0, height: progressHeight)
        self.progressBackgroundNode.frame = progressFrame
        let progressForegroundFrame = CGRect(x: progressFrame.minX, y: progressFrame.minY, width: floorToScreenPixels(progressFrame.width * progress), height: progressHeight)
        if !self.progressForegroundNode.frame.origin.x.isZero {
            transition.updateFrame(node: self.progressForegroundNode, frame: progressForegroundFrame, beginWithCurrentState: true)
        } else {
            self.progressForegroundNode.frame = progressForegroundFrame
        }
        
        let progressText: String
        if self.isDone {
            progressText = self.strings.Share_UploadDone
        } else {
            progressText = self.strings.Share_UploadProgress(Int(progress * 100.0)).string
        }
        
        self.progressTextNode.attributedText = NSAttributedString(string: progressText, font: Font.with(size: 17.0, design: .regular, weight: .semibold, traits: [.monospacedNumbers]), textColor: self.theme.actionSheet.primaryTextColor)
        let progressTextSize = self.progressTextNode.updateLayout(size)
        let progressTextFrame = CGRect(origin: CGPoint(x: floorToScreenPixels((size.width - progressTextSize.width) / 2.0), y: progressFrame.minY - spacing - 9.0 - progressTextSize.height), size: progressTextSize)
        self.progressTextNode.frame = progressTextFrame
        
        let imageSide: CGFloat = 160.0
        let imageSize = CGSize(width: imageSide, height: imageSide)
        
        let animationFrame = CGRect(origin: CGPoint(x: floor((size.width - imageSize.width) / 2.0), y: (progressTextFrame.minY - imageSize.height - 20.0)), size: imageSize)
        self.animationNode.frame = animationFrame
        self.animationNode.updateLayout(size: imageSize)
        
        self.doneAnimationNode.frame = animationFrame
        self.doneAnimationNode.updateLayout(size: imageSize)
        
        self.contentOffsetUpdated?(-size.height + nodeHeight * 0.5, transition)
    }
    
    public func updateSelectedPeers() {
    }
}
