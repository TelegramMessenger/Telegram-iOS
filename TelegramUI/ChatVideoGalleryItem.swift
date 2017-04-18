import Foundation
import Display
import AsyncDisplayKit
import SwiftSignalKit
import Postbox
import TelegramCore

class ChatVideoGalleryItem: GalleryItem {
    let account: Account
    let message: Message
    let location: MessageHistoryEntryLocation?
    
    init(account: Account, message: Message, location: MessageHistoryEntryLocation?) {
        self.account = account
        self.message = message
        self.location = location
    }
    
    func node() -> GalleryItemNode {
        let node = ChatVideoGalleryItemNode(account: self.account)
        
        for media in self.message.media {
            if let file = media as? TelegramMediaFile, (file.isVideo || file.mimeType.hasPrefix("video/")) {
                node.setFile(account: account, file: file, loopVideo: file.isAnimated || self.message.containsSecretMedia)
                break
            } else if let webpage = media as? TelegramMediaWebpage, case let .Loaded(content) = webpage.content {
                if let file = content.file, (file.isVideo || file.mimeType.hasPrefix("video/")) {
                    node.setFile(account: account, file: file, loopVideo: file.isAnimated || self.message.containsSecretMedia)
                    break
                }
            }
        }
        
        if let location = self.location {
            node._title.set(.single("\(location.index + 1) of \(location.count)"))
        }
        node.setMessage(self.message)
        
        return node
    }
    
    func updateNode(node: GalleryItemNode) {
        if let node = node as? ChatVideoGalleryItemNode, let location = self.location {
            node._title.set(.single("\(location.index + 1) of \(location.count)"))
            node.setMessage(self.message)
        }
    }
}

final class ChatVideoGalleryItemNode: ZoomableContentGalleryItemNode {
    fileprivate let _ready = Promise<Void>()
    fileprivate let _title = Promise<String>()
    fileprivate let _titleView = Promise<UIView?>()
    
    private var player: MediaPlayer?
    private let snapshotNode: TransformImageNode
    private let videoNode: MediaPlayerNode
    private let scrubberView: ChatVideoGalleryItemScrubberView
    
    private let progressButtonNode: HighlightableButtonNode
    private let progressNode: RadialProgressNode
    
    private var accountAndFile: (Account, TelegramMediaFile, Bool)?
    private var message: Message?
    
    private var isCentral = false
    
    private let fetchStatusDisposable = MetaDisposable()
    private let fetchDisposable = MetaDisposable()
    private var resourceStatus: MediaResourceStatus?
    
    private let footerContentNode: ChatItemGalleryFooterContentNode
    
    init(account: Account) {
        self.videoNode = MediaPlayerNode()
        self.snapshotNode = TransformImageNode()
        self.snapshotNode.backgroundColor = UIColor.black
        self.videoNode.snapshotNode = snapshotNode
        self.scrubberView = ChatVideoGalleryItemScrubberView()
        
        self.progressButtonNode = HighlightableButtonNode()
        self.progressNode = RadialProgressNode(theme: RadialProgressTheme(backgroundColor: UIColor(white: 0.0, alpha: 0.6), foregroundColor: UIColor.white, icon: nil))
        
        self.footerContentNode = ChatItemGalleryFooterContentNode(account: account)
        
        super.init()
        
        self.snapshotNode.imageUpdated = { [weak self] in
            self?._ready.set(.single(Void()))
        }
        
        self._titleView.set(.single(self.scrubberView))
        self.scrubberView.seek = { [weak self] timestamp in
            self?.player?.seek(timestamp: timestamp)
        }
        
        self.progressButtonNode.addSubnode(self.progressNode)
        self.progressButtonNode.addTarget(self, action: #selector(progressButtonPressed), forControlEvents: .touchUpInside)
    }
    
    deinit {
        self.fetchStatusDisposable.dispose()
        self.fetchDisposable.dispose()
    }
    
    override func ready() -> Signal<Void, NoError> {
        return self._ready.get()
    }
    
    override func containerLayoutUpdated(_ layout: ContainerViewLayout, navigationBarHeight: CGFloat, transition: ContainedViewLayoutTransition) {
        super.containerLayoutUpdated(layout, navigationBarHeight: navigationBarHeight, transition: transition)
        
        let progressDiameter: CGFloat = 50.0
        let progressFrame = CGRect(origin: CGPoint(x: floor((layout.size.width - progressDiameter) / 2.0), y: floor((layout.size.height - progressDiameter) / 2.0)), size: CGSize(width: progressDiameter, height: progressDiameter))
        transition.updateFrame(node: self.progressButtonNode, frame: progressFrame)
        transition.updateFrame(node: self.progressNode, frame: CGRect(origin: CGPoint(), size: progressFrame.size))
    }
    
    fileprivate func setMessage(_ message: Message) {
        self.footerContentNode.setMessage(message)
    }
    
    func setFile(account: Account, file: TelegramMediaFile, loopVideo: Bool) {
        if self.accountAndFile == nil || !self.accountAndFile!.1.isEqual(file) || !self.accountAndFile!.2 != loopVideo {
            if let largestSize = file.dimensions {
                self.snapshotNode.alphaTransitionOnFirstUpdate = false
                let displaySize = largestSize.dividedByScreenScale()
                self.snapshotNode.asyncLayout()(TransformImageArguments(corners: ImageCorners(), imageSize: displaySize, boundingSize: displaySize, intrinsicInsets: UIEdgeInsets()))()
                self.snapshotNode.setSignal(account: account, signal: chatMessageImageFile(account: account, file: file, progressive: true), dispatchOnDisplayLink: false)
                self.zoomableContent = (largestSize, self.videoNode)
            } else {
                self._ready.set(.single(Void()))
            }
            
            self.resourceStatus = nil
            self.fetchStatusDisposable.set((account.postbox.mediaBox.resourceStatus(file.resource) |> deliverOnMainQueue).start(next: { [weak self] status in
                if let strongSelf = self {
                    strongSelf.resourceStatus = status
                    switch status {
                        case let .Fetching(progress):
                            strongSelf.progressNode.state = .Fetching(progress: progress)
                            strongSelf.progressButtonNode.isHidden = false
                        case .Local:
                            strongSelf.progressNode.state = .Play
                            strongSelf.progressButtonNode.isHidden = strongSelf.player != nil
                        case .Remote:
                            strongSelf.progressNode.state = .Remote
                            strongSelf.progressButtonNode.isHidden = false
                    }
                }
            }))
            if self.progressButtonNode.supernode == nil {
                self.addSubnode(self.progressButtonNode)
            }
            
            let shouldPlayVideo = self.accountAndFile?.1 != file
            self.accountAndFile = (account, file, loopVideo)
            if shouldPlayVideo && self.isCentral {
                self.progressButtonPressed()
                //self.playVideo()
            }
        }
    }
    
    private func playVideo() {
        if let (account, file, loopVideo) = self.accountAndFile {
            var dimensions: CGSize? = file.dimensions
            if dimensions == nil || dimensions!.width.isLessThanOrEqualTo(0.0) || dimensions!.height.isLessThanOrEqualTo(0.0) {
                dimensions = largestImageRepresentation(file.previewRepresentations)?.dimensions.aspectFitted(CGSize(width: 1920, height: 1080))
            }
            if dimensions == nil || dimensions!.width.isLessThanOrEqualTo(0.0) || dimensions!.height.isLessThanOrEqualTo(0.0) {
                dimensions = CGSize(width: 1920, height: 1080)
            }
            
            if let dimensions = dimensions, !dimensions.width.isLessThanOrEqualTo(0.0) && !dimensions.height.isLessThanOrEqualTo(0.0) {
                /*let source = VideoPlayerSource(account: account, resource: CloudFileMediaResource(location: file.location, size: file.size))
                self.videoNode.player = VideoPlayer(source: source)*/
                
                let player = MediaPlayer(audioSessionManager: (account.applicationContext as! TelegramApplicationContext).mediaManager.audioSession, postbox: account.postbox, resource: file.resource, streamable: false, video: true, preferSoftwareDecoding: false, enableSound: true)
                if loopVideo {
                    player.actionAtEnd = .loop
                }
                player.attachPlayerNode(self.videoNode)
                self.progressButtonNode.isHidden = true
                self.player = player
                self.scrubberView.setStatusSignal(player.status)
                player.play()
                
                self.zoomableContent = (dimensions, self.videoNode)
            }
        }
    }
    
    private func stopVideo() {
        self.player = nil
        self.progressButtonNode.isHidden = false
    }
    
    override func centralityUpdated(isCentral: Bool) {
        super.centralityUpdated(isCentral: isCentral)
        
        if self.isCentral != isCentral {
            self.isCentral = isCentral
            if isCentral {
                self.playVideo()
            } else {
                self.stopVideo()
            }
        }
    }
    
    override func animateIn(from node: ASDisplayNode) {
        var transformedFrame = node.view.convert(node.view.bounds, to: self.videoNode.view)
        let transformedSuperFrame = node.view.convert(node.view.bounds, to: self.videoNode.view.superview)
        
        self.videoNode.layer.animatePosition(from: CGPoint(x: transformedSuperFrame.midX, y: transformedSuperFrame.midY), to: self.videoNode.layer.position, duration: 0.25, timingFunction: kCAMediaTimingFunctionSpring)
        
        transformedFrame.origin = CGPoint()
        
        let transform = CATransform3DScale(self.videoNode.layer.transform, transformedFrame.size.width / self.videoNode.layer.bounds.size.width, transformedFrame.size.height / self.videoNode.layer.bounds.size.height, 1.0)
        self.videoNode.layer.animate(from: NSValue(caTransform3D: transform), to: NSValue(caTransform3D: self.videoNode.layer.transform), keyPath: "transform", timingFunction: kCAMediaTimingFunctionSpring, duration: 0.25)
    }
    
    override func animateOut(to node: ASDisplayNode, completion: @escaping () -> Void) {
        var transformedFrame = node.view.convert(node.view.bounds, to: self.videoNode.view)
        let transformedSuperFrame = node.view.convert(node.view.bounds, to: self.videoNode.view.superview)
        let transformedSelfFrame = node.view.convert(node.view.bounds, to: self.view)
        let transformedCopyViewInitialFrame = self.videoNode.view.convert(self.videoNode.view.bounds, to: self.view)
        
        var positionCompleted = false
        var boundsCompleted = false
        var copyCompleted = false
        
        let copyView = node.view.snapshotContentTree()!
        
        self.view.insertSubview(copyView, belowSubview: self.scrollView)
        copyView.frame = transformedSelfFrame
        
        let intermediateCompletion = { [weak copyView] in
            if positionCompleted && boundsCompleted && copyCompleted {
                copyView?.removeFromSuperview()
                completion()
            }
        }
        
        copyView.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.1, removeOnCompletion: false)
        
        copyView.layer.animatePosition(from: CGPoint(x: transformedCopyViewInitialFrame.midX, y: transformedCopyViewInitialFrame.midY), to: CGPoint(x: transformedSelfFrame.midX, y: transformedSelfFrame.midY), duration: 0.25, timingFunction: kCAMediaTimingFunctionSpring, removeOnCompletion: false)
        let scale = CGSize(width: transformedCopyViewInitialFrame.size.width / transformedSelfFrame.size.width, height: transformedCopyViewInitialFrame.size.height / transformedSelfFrame.size.height)
        copyView.layer.animate(from: NSValue(caTransform3D: CATransform3DMakeScale(scale.width, scale.height, 1.0)), to: NSValue(caTransform3D: CATransform3DIdentity), keyPath: "transform", timingFunction: kCAMediaTimingFunctionSpring, duration: 0.25, removeOnCompletion: false, completion: { _ in
            copyCompleted = true
            intermediateCompletion()
        })
        
        self.videoNode.layer.animatePosition(from: self.videoNode.layer.position, to: CGPoint(x: transformedSuperFrame.midX, y: transformedSuperFrame.midY), duration: 0.25, timingFunction: kCAMediaTimingFunctionSpring, removeOnCompletion: false, completion: { _ in
            positionCompleted = true
            intermediateCompletion()
        })
        
        self.videoNode.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.25, removeOnCompletion: false)
        
        self.progressNode.layer.animatePosition(from: self.progressNode.layer.position, to: CGPoint(x: transformedSelfFrame.midX, y: transformedSelfFrame.midY), duration: 0.25, timingFunction: kCAMediaTimingFunctionSpring, removeOnCompletion: false, completion: { _ in
            //positionCompleted = true
            //intermediateCompletion()
        })
        self.progressNode.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.25, removeOnCompletion: false)
        self.progressNode.layer.animateScale(from: 1.0, to: 0.2, duration: 0.25, removeOnCompletion: false)
        
        self.videoNode.snapshotNode?.isHidden = true
        
        transformedFrame.origin = CGPoint()
        
        let transform = CATransform3DScale(self.videoNode.layer.transform, transformedFrame.size.width / self.videoNode.layer.bounds.size.width, transformedFrame.size.height / self.videoNode.layer.bounds.size.height, 1.0)
        self.videoNode.layer.animate(from: NSValue(caTransform3D: self.videoNode.layer.transform), to: NSValue(caTransform3D: transform), keyPath: "transform", timingFunction: kCAMediaTimingFunctionSpring, duration: 0.25, removeOnCompletion: false, completion: { _ in
            boundsCompleted = true
            intermediateCompletion()
        })
    }
    
    override func title() -> Signal<String, NoError> {
        //return self._title.get()
        return .single("")
    }
    
    override func titleView() -> Signal<UIView?, NoError> {
        return self._titleView.get()
    }
    
    private func activateVideo() {
        if let (account, file, _) = self.accountAndFile {
            if let resourceStatus = self.resourceStatus {
                switch resourceStatus {
                    case .Fetching:
                        break
                    case .Local:
                        self.playVideo()
                    case .Remote:
                        self.fetchDisposable.set(account.postbox.mediaBox.fetchedResource(file.resource, tag: TelegramMediaResourceFetchTag(statsCategory: .video)).start())
                }
            }
        }
    }
    
    @objc func progressButtonPressed() {
        if let (account, file, _) = self.accountAndFile {
            if let resourceStatus = self.resourceStatus {
                switch resourceStatus {
                    case .Fetching:
                        account.postbox.mediaBox.cancelInteractiveResourceFetch(file.resource)
                    case .Local:
                        self.playVideo()
                    case .Remote:
                        self.fetchDisposable.set(account.postbox.mediaBox.fetchedResource(file.resource, tag: TelegramMediaResourceFetchTag(statsCategory: .video)).start())
                }
            }
        }
    }
    
    override func footerContent() -> Signal<GalleryFooterContentNode?, NoError> {
        return .single(self.footerContentNode)
    }
}
