import Foundation
import Display
import AsyncDisplayKit
import SwiftSignalKit
import Postbox
import TelegramCore

class ChatImageGalleryItem: GalleryItem {
    let account: Account
    let message: Message
    let location: MessageHistoryEntryLocation?
    
    init(account: Account, message: Message, location: MessageHistoryEntryLocation?) {
        self.account = account
        self.message = message
        self.location = location
    }
    
    func node() -> GalleryItemNode {
        let node = ChatImageGalleryItemNode()
        
        for media in self.message.media {
            if let image = media as? TelegramMediaImage {
                node.setImage(account: account, image: image)
                break
            } else if let file = media as? TelegramMediaFile, file.mimeType.hasPrefix("image/") {
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
        if let node = node as? ChatImageGalleryItemNode, let location = self.location {
            node._title.set(.single("\(location.index + 1) of \(location.count)"))
        }
    }
}

final class ChatImageGalleryItemNode: ZoomableContentGalleryItemNode {
    private let imageNode: TransformImageNode
    fileprivate let _ready = Promise<Void>()
    fileprivate let _title = Promise<String>()
    
    private var accountAndMedia: (Account, Media)?
    
    private var fetchDisposable = MetaDisposable()
    
    override init() {
        self.imageNode = TransformImageNode()
        
        super.init()
        
        self.imageNode.imageUpdated = { [weak self] in
            self?._ready.set(.single(Void()))
        }
        
        self.imageNode.view.contentMode = .scaleAspectFill
        self.imageNode.clipsToBounds = true
        
        /*self.imageNode.layer.shadowRadius = 80.0
        self.imageNode.layer.shadowColor = UIColor(white: 0.0, alpha: 1.0).cgColor
        self.imageNode.layer.shadowOffset = CGSize(width: 0.0, height: 40.0)
        self.imageNode.layer.shadowOpacity = 0.5*/
    }
    
    deinit {
        self.fetchDisposable.dispose()
    }
    
    override func ready() -> Signal<Void, NoError> {
        return self._ready.get()
    }
    
    override func containerLayoutUpdated(_ layout: ContainerViewLayout, navigationBarHeight: CGFloat, transition: ContainedViewLayoutTransition) {
        super.containerLayoutUpdated(layout, navigationBarHeight: navigationBarHeight, transition: transition)
    }
    
    fileprivate func setImage(account: Account, image: TelegramMediaImage) {
        if self.accountAndMedia == nil || !self.accountAndMedia!.1.isEqual(image) {
            if let largestSize = largestRepresentationForPhoto(image) {
                let displaySize = largestSize.dimensions.fitted(CGSize(width: 1280.0, height: 1280.0)).dividedByScreenScale().integralFloor
                self.imageNode.alphaTransitionOnFirstUpdate = false
                self.imageNode.asyncLayout()(TransformImageArguments(corners: ImageCorners(), imageSize: displaySize, boundingSize: displaySize, intrinsicInsets: UIEdgeInsets()))()
                self.imageNode.setSignal(account: account, signal: chatMessagePhoto(account: account, photo: image), dispatchOnDisplayLink: false)
                self.zoomableContent = (largestSize.dimensions, self.imageNode)
                self.fetchDisposable.set(account.postbox.mediaBox.fetchedResource(largestSize.resource).start())
            } else {
                self._ready.set(.single(Void()))
            }
        }
        self.accountAndMedia = (account, image)
    }
    
    func setFile(account: Account, file: TelegramMediaFile) {
        if self.accountAndMedia == nil || !self.accountAndMedia!.1.isEqual(file) {
            if let largestSize = file.dimensions {
                self.imageNode.alphaTransitionOnFirstUpdate = false
                let displaySize = largestSize.dividedByScreenScale()
                self.imageNode.asyncLayout()(TransformImageArguments(corners: ImageCorners(), imageSize: displaySize, boundingSize: displaySize, intrinsicInsets: UIEdgeInsets()))()
                self.imageNode.setSignal(account: account, signal: chatMessageImageFile(account: account, file: file, progressive: true), dispatchOnDisplayLink: false)
                self.zoomableContent = (largestSize, self.imageNode)
            } else {
                self._ready.set(.single(Void()))
            }
        }
        self.accountAndMedia = (account, file)
    }
    
    override func animateIn(from node: ASDisplayNode) {
        var transformedFrame = node.view.convert(node.view.bounds, to: self.imageNode.view)
        let transformedSuperFrame = node.view.convert(node.view.bounds, to: self.imageNode.view.superview)
        let transformedSelfFrame = node.view.convert(node.view.bounds, to: self.view)
        let transformedCopyViewFinalFrame = self.imageNode.view.convert(self.imageNode.view.bounds, to: self.view)
        
        let copyView = node.view.snapshotContentTree()!
        
        self.view.insertSubview(copyView, belowSubview: self.scrollView)
        copyView.frame = transformedSelfFrame
        
        copyView.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.25, removeOnCompletion: false, completion: { [weak copyView] _ in
            copyView?.removeFromSuperview()
        })
        
        copyView.layer.animatePosition(from: CGPoint(x: transformedSelfFrame.midX, y: transformedSelfFrame.midY), to: CGPoint(x: transformedCopyViewFinalFrame.midX, y: transformedCopyViewFinalFrame.midY), duration: 0.25, timingFunction: kCAMediaTimingFunctionSpring, removeOnCompletion: false)
        let scale = CGSize(width: transformedCopyViewFinalFrame.size.width / transformedSelfFrame.size.width, height: transformedCopyViewFinalFrame.size.height / transformedSelfFrame.size.height)
        copyView.layer.animate(from: NSValue(caTransform3D: CATransform3DIdentity), to: NSValue(caTransform3D: CATransform3DMakeScale(scale.width, scale.height, 1.0)), keyPath: "transform", timingFunction: kCAMediaTimingFunctionSpring, duration: 0.25, removeOnCompletion: false)
        
        self.imageNode.layer.animatePosition(from: CGPoint(x: transformedSuperFrame.midX, y: transformedSuperFrame.midY), to: self.imageNode.layer.position, duration: 0.25, timingFunction: kCAMediaTimingFunctionSpring)
        self.imageNode.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.1)
        
        transformedFrame.origin = CGPoint()
        self.imageNode.layer.animateBounds(from: transformedFrame, to: self.imageNode.layer.bounds, duration: 0.25, timingFunction: kCAMediaTimingFunctionSpring)
    }
    
    override func animateOut(to node: ASDisplayNode, completion: @escaping () -> Void) {
        var transformedFrame = node.view.convert(node.view.bounds, to: self.imageNode.view)
        let transformedSuperFrame = node.view.convert(node.view.bounds, to: self.imageNode.view.superview)
        let transformedSelfFrame = node.view.convert(node.view.bounds, to: self.view)
        let transformedCopyViewInitialFrame = self.imageNode.view.convert(self.imageNode.view.bounds, to: self.view)
        
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
        
        self.imageNode.layer.animatePosition(from: self.imageNode.layer.position, to: CGPoint(x: transformedSuperFrame.midX, y: transformedSuperFrame.midY), duration: 0.25, timingFunction: kCAMediaTimingFunctionSpring, removeOnCompletion: false, completion: { _ in
            positionCompleted = true
            intermediateCompletion()
        })
        
        self.imageNode.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.25, removeOnCompletion: false)
        
        transformedFrame.origin = CGPoint()
        self.imageNode.layer.animateBounds(from: self.imageNode.layer.bounds, to: transformedFrame, duration: 0.25, timingFunction: kCAMediaTimingFunctionSpring, removeOnCompletion: false, completion: { _ in
            boundsCompleted = true
            intermediateCompletion()
        })
    }
    
    override func visibilityUpdated(isVisible: Bool) {
        super.visibilityUpdated(isVisible: isVisible)
        
        if let (account, media) = self.accountAndMedia, let file = media as? TelegramMediaFile {
            if isVisible {
                self.fetchDisposable.set(account.postbox.mediaBox.fetchedResource(file.resource).start())
            } else {
                self.fetchDisposable.set(nil)
            }
        }
    }
    
    override func title() -> Signal<String, NoError> {
        return self._title.get()
    }
}
