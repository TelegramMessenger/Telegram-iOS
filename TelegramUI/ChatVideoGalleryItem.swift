import Foundation
import Display
import AsyncDisplayKit
import SwiftSignalKit
import Postbox
import TelegramCore

class ChatVideoGalleryItem: GalleryItem {
    let account: Account
    let theme: PresentationTheme
    let strings: PresentationStrings
    let message: Message
    let location: MessageHistoryEntryLocation?
    
    init(account: Account, theme: PresentationTheme, strings: PresentationStrings, message: Message, location: MessageHistoryEntryLocation?) {
        self.account = account
        self.theme = theme
        self.strings = strings
        self.message = message
        self.location = location
    }
    
    func node() -> GalleryItemNode {
        let node = ChatVideoGalleryItemNode(account: self.account, theme: self.theme, strings: self.strings)
        
        for media in self.message.media {
            if let file = media as? TelegramMediaFile, (file.isVideo || file.mimeType.hasPrefix("video/")) {
                node.setFile(account: account, stableId: self.message.stableId, file: file, loopVideo: file.isAnimated || self.message.containsSecretMedia)
                break
            } else if let webpage = media as? TelegramMediaWebpage, case let .Loaded(content) = webpage.content {
                if let file = content.file, (file.isVideo || file.mimeType.hasPrefix("video/")) {
                    node.setFile(account: account, stableId: self.message.stableId, file: file, loopVideo: file.isAnimated || self.message.containsSecretMedia)
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

private let pictureInPictureButtonImage = generateTintedImage(image: UIImage(bundleImageName: "Media Gallery/PictureInPictureButton"), color: .white)

final class ChatVideoGalleryItemNode: ZoomableContentGalleryItemNode {
    fileprivate let _ready = Promise<Void>()
    fileprivate let _title = Promise<String>()
    fileprivate let _titleView = Promise<UIView?>()
    fileprivate let _rightBarButtonItem = Promise<UIBarButtonItem?>()
    
    private var videoNode: TelegramVideoNode?
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
    
    init(account: Account, theme: PresentationTheme, strings: PresentationStrings) {
        self.scrubberView = ChatVideoGalleryItemScrubberView()
        
        self.progressButtonNode = HighlightableButtonNode()
        self.progressNode = RadialProgressNode(theme: RadialProgressTheme(backgroundColor: UIColor(white: 0.0, alpha: 0.6), foregroundColor: UIColor.white, icon: nil))
        
        self.footerContentNode = ChatItemGalleryFooterContentNode(account: account, theme: theme, strings: strings)
        
        super.init()
        
        self._titleView.set(.single(self.scrubberView))
        self.scrubberView.seek = { [weak self] timestamp in
            self?.videoNode?.seek(timestamp)
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
        
        self.message = message
        
        var rightBarButtonItem: UIBarButtonItem?
        for media in message.media {
            if let file = media as? TelegramMediaFile {
                if file.isVideo {
                    rightBarButtonItem = UIBarButtonItem(image: pictureInPictureButtonImage, style: .plain, target: self, action: #selector(self.pictureInPictureButtonPressed))
                    break
                }
            }
        }
        self._rightBarButtonItem.set(.single(rightBarButtonItem))
    }
    
    func setFile(account: Account, stableId: UInt32, file: TelegramMediaFile, loopVideo: Bool) {
        if self.accountAndFile == nil || !self.accountAndFile!.1.isEqual(file) || !self.accountAndFile!.2 != loopVideo {
            if let videoNode = self.videoNode {
                videoNode.pause()
                videoNode.removeFromSupernode()
                self.videoNode = nil
            }
            if let largestSize = file.dimensions {
                let videoNode = TelegramVideoNode(manager: account.telegramApplicationContext.mediaManager, account: account, source: .messageMedia(stableId: stableId, file: file), priority: 0, withSound: true)
                videoNode.setShouldAcquireContext(true)
                self.videoNode = videoNode
                self.scrubberView.setStatusSignal(videoNode.status)
                self.zoomableContent = (largestSize, videoNode)
                
                self._ready.set(.single(Void()))
            } else {
                self._ready.set(.single(Void()))
            }
            
            self.resourceStatus = nil
            self.fetchStatusDisposable.set((account.postbox.mediaBox.resourceStatus(file.resource) |> deliverOnMainQueue).start(next: { [weak self] status in
                if let strongSelf = self {
                    strongSelf.resourceStatus = status
                    switch status {
                        case let .Fetching(_, progress):
                            strongSelf.progressNode.state = .Fetching(progress: progress)
                            strongSelf.progressButtonNode.isHidden = false
                        case .Local:
                            strongSelf.progressNode.state = .Play
                            strongSelf.progressButtonNode.isHidden = strongSelf.videoNode != nil
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
            }
        }
    }
    
    private func playVideo() {
        if let videoNode = self.videoNode {
            videoNode.play()
        } else {
            if let (account, file, loop) = self.accountAndFile, let message = self.message {
                if let largestSize = file.dimensions {
                    let videoNode = TelegramVideoNode(manager: account.telegramApplicationContext.mediaManager, account: account, source: .messageMedia(stableId: message.stableId, file: file), priority: 0, withSound: true)
                    videoNode.setShouldAcquireContext(true)
                    self.scrubberView.setStatusSignal(videoNode.status)
                    self.videoNode = videoNode
                    self.zoomableContent = (largestSize, videoNode)
                    
                    self._ready.set(.single(Void()))
                } else {
                    self.scrubberView.setStatusSignal(nil)
                    self._ready.set(.single(Void()))
                }
                
                self.resourceStatus = nil
                self.fetchStatusDisposable.set((account.postbox.mediaBox.resourceStatus(file.resource) |> deliverOnMainQueue).start(next: { [weak self] status in
                    if let strongSelf = self {
                        strongSelf.resourceStatus = status
                        switch status {
                        case let .Fetching(_, progress):
                            strongSelf.progressNode.state = .Fetching(progress: progress)
                            strongSelf.progressButtonNode.isHidden = false
                        case .Local:
                            strongSelf.progressNode.state = .Play
                            strongSelf.progressButtonNode.isHidden = strongSelf.videoNode != nil
                        case .Remote:
                            strongSelf.progressNode.state = .Remote
                            strongSelf.progressButtonNode.isHidden = false
                        }
                    }
                }))
                if self.progressButtonNode.supernode == nil {
                    self.addSubnode(self.progressButtonNode)
                }
            }
        }
    }
    
    private func stopVideo() {
        if let videoNode = self.videoNode {
            videoNode.pause()
            self.progressButtonNode.isHidden = false
            
            self.videoNode = nil
            self.zoomableContent = nil
        }
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
    
    override func animateIn(from node: ASDisplayNode, addToTransitionSurface: (UIView) -> Void) {
        guard let videoNode = self.videoNode else {
            return
        }
        
        if let node = node as? TelegramVideoNode, let account = self.accountAndFile?.0 {
            var transformedFrame = node.view.convert(node.view.bounds, to: videoNode.view)
            let transformedSuperFrame = node.view.convert(node.view.bounds, to: videoNode.view.superview)
            
            videoNode.layer.animatePosition(from: CGPoint(x: transformedSuperFrame.midX, y: transformedSuperFrame.midY), to: videoNode.layer.position, duration: 0.25, timingFunction: kCAMediaTimingFunctionSpring)
            
            transformedFrame.origin = CGPoint()
            
            let transform = CATransform3DScale(videoNode.layer.transform, transformedFrame.size.width / videoNode.layer.bounds.size.width, transformedFrame.size.height / videoNode.layer.bounds.size.height, 1.0)
            videoNode.layer.animate(from: NSValue(caTransform3D: transform), to: NSValue(caTransform3D: videoNode.layer.transform), keyPath: "transform", timingFunction: kCAMediaTimingFunctionSpring, duration: 0.25)
            
            account.telegramApplicationContext.mediaManager.setOverlayVideoNode(nil)
        } else {
            var transformedFrame = node.view.convert(node.view.bounds, to: videoNode.view)
            let transformedSuperFrame = node.view.convert(node.view.bounds, to: videoNode.view.superview)
            
            videoNode.layer.animatePosition(from: CGPoint(x: transformedSuperFrame.midX, y: transformedSuperFrame.midY), to: videoNode.layer.position, duration: 0.25, timingFunction: kCAMediaTimingFunctionSpring)
            
            transformedFrame.origin = CGPoint()
            
            let transform = CATransform3DScale(videoNode.layer.transform, transformedFrame.size.width / videoNode.layer.bounds.size.width, transformedFrame.size.height / videoNode.layer.bounds.size.height, 1.0)
            videoNode.layer.animate(from: NSValue(caTransform3D: transform), to: NSValue(caTransform3D: videoNode.layer.transform), keyPath: "transform", timingFunction: kCAMediaTimingFunctionSpring, duration: 0.25)
        }
    }
    
    override func animateOut(to node: ASDisplayNode, addToTransitionSurface: (UIView) -> Void, completion: @escaping () -> Void) {
        guard let videoNode = self.videoNode else {
            completion()
            return
        }
        
        var transformedFrame = node.view.convert(node.view.bounds, to: videoNode.view)
        let transformedSuperFrame = node.view.convert(node.view.bounds, to: videoNode.view.superview)
        let transformedSelfFrame = node.view.convert(node.view.bounds, to: self.view)
        let transformedCopyViewInitialFrame = videoNode.view.convert(videoNode.view.bounds, to: self.view)
        
        var positionCompleted = false
        var boundsCompleted = false
        var copyCompleted = false
        
        let copyView = node.view.snapshotContentTree()!
        
        self.view.insertSubview(copyView, belowSubview: self.scrollNode.view)
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
        
        videoNode.layer.animatePosition(from: videoNode.layer.position, to: CGPoint(x: transformedSuperFrame.midX, y: transformedSuperFrame.midY), duration: 0.25, timingFunction: kCAMediaTimingFunctionSpring, removeOnCompletion: false, completion: { _ in
            positionCompleted = true
            intermediateCompletion()
        })
        
        videoNode.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.25, removeOnCompletion: false)
        
        self.progressNode.layer.animatePosition(from: self.progressNode.layer.position, to: CGPoint(x: transformedSelfFrame.midX, y: transformedSelfFrame.midY), duration: 0.25, timingFunction: kCAMediaTimingFunctionSpring, removeOnCompletion: false, completion: { _ in
            //positionCompleted = true
            //intermediateCompletion()
        })
        self.progressNode.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.25, removeOnCompletion: false)
        self.progressNode.layer.animateScale(from: 1.0, to: 0.2, duration: 0.25, removeOnCompletion: false)
        
        transformedFrame.origin = CGPoint()
        
        let transform = CATransform3DScale(videoNode.layer.transform, transformedFrame.size.width / videoNode.layer.bounds.size.width, transformedFrame.size.height / videoNode.layer.bounds.size.height, 1.0)
        videoNode.layer.animate(from: NSValue(caTransform3D: videoNode.layer.transform), to: NSValue(caTransform3D: transform), keyPath: "transform", timingFunction: kCAMediaTimingFunctionSpring, duration: 0.25, removeOnCompletion: false, completion: { _ in
            boundsCompleted = true
            intermediateCompletion()
        })
    }
    
    func animateOut(toOverlay node: ASDisplayNode, completion: @escaping () -> Void) {
        guard let videoNode = self.videoNode else {
            completion()
            return
        }
        
        var transformedFrame = node.view.convert(node.view.bounds, to: videoNode.view)
        let transformedSuperFrame = node.view.convert(node.view.bounds, to: videoNode.view.superview)
        let transformedSelfFrame = node.view.convert(node.view.bounds, to: self.view)
        let transformedCopyViewInitialFrame = videoNode.view.convert(videoNode.view.bounds, to: self.view)
        let transformedSelfTargetSuperFrame = videoNode.view.convert(videoNode.view.bounds, to: node.view.superview)
        
        var positionCompleted = false
        var boundsCompleted = false
        var copyCompleted = false
        var nodeCompleted = false
        
        let copyView = node.view.snapshotContentTree()!
        
        //self.view.insertSubview(copyView, belowSubview: self.scrollView)
        videoNode.isHidden = true
        copyView.frame = transformedSelfFrame
        
        let intermediateCompletion = { [weak copyView] in
            if positionCompleted && boundsCompleted && copyCompleted && nodeCompleted {
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
        
        videoNode.layer.animatePosition(from: videoNode.layer.position, to: CGPoint(x: transformedSuperFrame.midX, y: transformedSuperFrame.midY), duration: 0.25, timingFunction: kCAMediaTimingFunctionSpring, removeOnCompletion: false, completion: { _ in
            positionCompleted = true
            intermediateCompletion()
        })
        
        videoNode.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.25, removeOnCompletion: false)
        
        self.progressNode.layer.animatePosition(from: self.progressNode.layer.position, to: CGPoint(x: transformedSelfFrame.midX, y: transformedSelfFrame.midY), duration: 0.25, timingFunction: kCAMediaTimingFunctionSpring, removeOnCompletion: false, completion: { _ in
            //positionCompleted = true
            //intermediateCompletion()
        })
        self.progressNode.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.25, removeOnCompletion: false)
        self.progressNode.layer.animateScale(from: 1.0, to: 0.2, duration: 0.25, removeOnCompletion: false)
        
        transformedFrame.origin = CGPoint()
        
        let transform = CATransform3DScale(videoNode.layer.transform, transformedFrame.size.width / videoNode.layer.bounds.size.width, transformedFrame.size.height / videoNode.layer.bounds.size.height, 1.0)
        videoNode.layer.animate(from: NSValue(caTransform3D: videoNode.layer.transform), to: NSValue(caTransform3D: transform), keyPath: "transform", timingFunction: kCAMediaTimingFunctionSpring, duration: 0.25, removeOnCompletion: false, completion: { _ in
            boundsCompleted = true
            intermediateCompletion()
        })
        
        //node.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.25)
        let nodeTransform = CATransform3DScale(node.layer.transform, videoNode.layer.bounds.size.width / transformedFrame.size.width, videoNode.layer.bounds.size.height / transformedFrame.size.height, 1.0)
        node.layer.animatePosition(from: CGPoint(x: transformedSelfTargetSuperFrame.midX, y: transformedSelfTargetSuperFrame.midY), to: node.layer.position, duration: 0.25, timingFunction: kCAMediaTimingFunctionSpring)
        node.layer.animate(from: NSValue(caTransform3D: nodeTransform), to: NSValue(caTransform3D: node.layer.transform), keyPath: "transform", timingFunction: kCAMediaTimingFunctionSpring, duration: 0.25, removeOnCompletion: false, completion: { _ in
            nodeCompleted = true
            intermediateCompletion()
        })
    }
    
    override func title() -> Signal<String, NoError> {
        return .single("")
    }
    
    override func titleView() -> Signal<UIView?, NoError> {
        return self._titleView.get()
    }
    
    override func rightBarButtonItem() -> Signal<UIBarButtonItem?, NoError> {
        return self._rightBarButtonItem.get()
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
    
    @objc func pictureInPictureButtonPressed() {
        if let account = self.accountAndFile?.0, let message = self.message, let file = self.accountAndFile?.1 {
            let overlayNode = TelegramVideoNode(manager: account.telegramApplicationContext.mediaManager, account: account, source: TelegramVideoNodeSource.messageMedia(stableId: message.stableId, file: file), priority: 1, withSound: true, withOverlayControls: true)
            overlayNode.dismissed = { [weak account, weak overlayNode] in
                if let account = account, let overlayNode = overlayNode {
                    if overlayNode.supernode != nil {
                        account.telegramApplicationContext.mediaManager.setOverlayVideoNode(nil)
                    }
                }
            }
            let baseNavigationController = self.baseNavigationController()
            overlayNode.unembed = { [weak account, weak overlayNode, weak baseNavigationController] in
                if let account = account {
                    let gallery = GalleryController(account: account, messageId: message.id, replaceRootController: { controller, ready in
                        if let baseNavigationController = baseNavigationController {
                            baseNavigationController.replaceTopController(controller, animated: false, ready: ready)
                        }
                    }, baseNavigationController: baseNavigationController)
                    
                    (baseNavigationController?.topViewController as? ViewController)?.present(gallery, in: .window(.root), with: GalleryControllerPresentationArguments(transitionArguments: { _, _ in
                        if let overlayNode = overlayNode, let overlaySupernode = overlayNode.supernode {
                            return GalleryTransitionArguments(transitionNode: overlayNode, addToTransitionSurface: { _ in
                            })
                        }
                        return nil
                    }))
                }
            }
            overlayNode.setShouldAcquireContext(true)
            account.telegramApplicationContext.mediaManager.setOverlayVideoNode(overlayNode)
            if overlayNode.supernode != nil {
                self.beginCustomDismiss()
                self.animateOut(toOverlay: overlayNode, completion: { [weak self] in
                    self?.completeCustomDismiss()
                })
            }
        }
    }
    
    override func footerContent() -> Signal<GalleryFooterContentNode?, NoError> {
        return .single(self.footerContentNode)
    }
}
