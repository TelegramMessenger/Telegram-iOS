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
        let node = ChatVideoGalleryItemNode()
        
        for media in self.message.media {
            if let file = media as? TelegramMediaFile, (file.isVideo || file.mimeType.hasPrefix("video/")) {
                node.setFile(account: account, file: file)
                break
            }
        }
        
        if let location = self.location {
            node._title.set(.single("\(location.index + 1) of \(location.count)"))
        }
        
        return node
    }
    
    func updateNode(node: GalleryItemNode) {
        if let node = node as? ChatVideoGalleryItemNode, let location = self.location {
            node._title.set(.single("\(location.index + 1) of \(location.count)"))
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
    
    private var accountAndFile: (Account, TelegramMediaFile)?
    
    private var isCentral = false
    
    private let videoStatusDisposable = MetaDisposable()
    
    override init() {
        self.videoNode = MediaPlayerNode()
        self.snapshotNode = TransformImageNode()
        self.snapshotNode.backgroundColor = UIColor.black
        self.videoNode.snapshotNode = snapshotNode
        self.scrubberView = ChatVideoGalleryItemScrubberView()
        
        super.init()
        
        self.snapshotNode.imageUpdated = { [weak self] in
            self?._ready.set(.single(Void()))
        }
        
        self._titleView.set(.single(self.scrubberView))
        self.scrubberView.seek = { [weak self] timestamp in
            self?.player?.seek(timestamp: timestamp)
        }
    }
    
    deinit {
        self.videoStatusDisposable.dispose()
    }
    
    override func ready() -> Signal<Void, NoError> {
        return self._ready.get()
    }
    
    override func containerLayoutUpdated(_ layout: ContainerViewLayout, navigationBarHeight: CGFloat, transition: ContainedViewLayoutTransition) {
        super.containerLayoutUpdated(layout, navigationBarHeight: navigationBarHeight, transition: transition)
    }
    
    func setFile(account: Account, file: TelegramMediaFile) {
        if self.accountAndFile == nil || !self.accountAndFile!.1.isEqual(file) {
            if let largestSize = file.dimensions {
                self.snapshotNode.alphaTransitionOnFirstUpdate = false
                let displaySize = largestSize.dividedByScreenScale()
                self.snapshotNode.asyncLayout()(TransformImageArguments(corners: ImageCorners(), imageSize: displaySize, boundingSize: displaySize, intrinsicInsets: UIEdgeInsets()))()
                self.snapshotNode.setSignal(account: account, signal: chatMessageImageFile(account: account, file: file, progressive: true), dispatchOnDisplayLink: false)
                self.zoomableContent = (largestSize, self.videoNode)
            } else {
                self._ready.set(.single(Void()))
            }
            
            let shouldPlayVideo = self.accountAndFile?.1 != file
            self.accountAndFile = (account, file)
            if shouldPlayVideo && self.isCentral {
                self.playVideo()
            }
        }
    }
    
    private func playVideo() {
        if let (account, file) = self.accountAndFile {
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
                
                let player = MediaPlayer(account: account, resource: CloudFileMediaResource(location: file.location, size: file.size))
                player.attachPlayerNode(self.videoNode)
                self.player = player
                self.videoStatusDisposable.set((player.status |> deliverOnMainQueue).start(next: { [weak self] status in
                    if let strongSelf = self {
                        strongSelf.scrubberView.setStatus(status)
                    }
                }))
                player.play()
                
                
                self.zoomableContent = (dimensions, self.videoNode)
            }
        }
    }
    
    private func stopVideo() {
        self.player = nil
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
        
        self.videoNode.snapshotNode?.isHidden = true
        
        transformedFrame.origin = CGPoint()
        /*self.videoNode.layer.animateBounds(from: self.videoNode.layer.bounds, to: transformedFrame, duration: 0.25, timingFunction: kCAMediaTimingFunctionSpring, removeOnCompletion: false, completion: { _ in
            boundsCompleted = true
            intermediateCompletion()
        })*/
        
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
}
