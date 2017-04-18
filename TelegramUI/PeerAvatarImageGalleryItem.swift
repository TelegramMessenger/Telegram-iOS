import Foundation
import Display
import AsyncDisplayKit
import SwiftSignalKit
import Postbox
import TelegramCore

class PeerAvatarImageGalleryItem: GalleryItem {
    let account: Account
    let entry: AvatarGalleryEntry
    
    init(account: Account, entry: AvatarGalleryEntry) {
        self.account = account
        self.entry = entry
    }
    
    func node() -> GalleryItemNode {
        let node = PeerAvatarImageGalleryItemNode(account: self.account)
        
        /*if let location = self.location {
            node._title.set(.single("\(location.index + 1) of \(location.count)"))
        }*/
        
        node.setEntry(self.entry)
        
        return node
    }
    
    func updateNode(node: GalleryItemNode) {
        if let node = node as? PeerAvatarImageGalleryItemNode {
            /*if let location = self.location {
                node._title.set(.single("\(location.index + 1) of \(location.count)"))
            }*/
            
            node.setEntry(self.entry)
        }
    }
}

final class PeerAvatarImageGalleryItemNode: ZoomableContentGalleryItemNode {
    private let account: Account
    
    private var entry: AvatarGalleryEntry?
    
    private let imageNode: TransformImageNode
    fileprivate let _ready = Promise<Void>()
    fileprivate let _title = Promise<String>()
    //private let footerContentNode: ChatItemGalleryFooterContentNode
    
    private var fetchDisposable = MetaDisposable()
    
    init(account: Account) {
        self.account = account
        
        self.imageNode = TransformImageNode()
        //self.footerContentNode = ChatItemGalleryFooterContentNode(account: account)
        
        super.init()
        
        self.imageNode.imageUpdated = { [weak self] in
            self?._ready.set(.single(Void()))
        }
        
        self.imageNode.view.contentMode = .scaleAspectFill
        self.imageNode.clipsToBounds = true
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
    
    fileprivate func setEntry(_ entry: AvatarGalleryEntry) {
        if self.entry != entry {
            self.entry = entry
            
            if let largestSize = largestImageRepresentation(entry.representations) {
                let displaySize = largestSize.dimensions.fitted(CGSize(width: 1280.0, height: 1280.0)).dividedByScreenScale().integralFloor
                self.imageNode.alphaTransitionOnFirstUpdate = false
                self.imageNode.asyncLayout()(TransformImageArguments(corners: ImageCorners(), imageSize: displaySize, boundingSize: displaySize, intrinsicInsets: UIEdgeInsets()))()
                self.imageNode.setSignal(account: account, signal: chatAvatarGalleryPhoto(account: account, representations: entry.representations), dispatchOnDisplayLink: false)
                self.zoomableContent = (largestSize.dimensions, self.imageNode)
                self.fetchDisposable.set(account.postbox.mediaBox.fetchedResource(largestSize.resource, tag: TelegramMediaResourceFetchTag(statsCategory: .generic)).start())
            } else {
                self._ready.set(.single(Void()))
            }
        }
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
        self.imageNode.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.07)
        
        transformedFrame.origin = CGPoint()
        //self.imageNode.layer.animateBounds(from: transformedFrame, to: self.imageNode.layer.bounds, duration: 0.25, timingFunction: kCAMediaTimingFunctionSpring)
        
        let transform = CATransform3DScale(self.imageNode.layer.transform, transformedFrame.size.width / self.imageNode.layer.bounds.size.width, transformedFrame.size.height / self.imageNode.layer.bounds.size.height, 1.0)
        self.imageNode.layer.animate(from: NSValue(caTransform3D: transform), to: NSValue(caTransform3D: self.imageNode.layer.transform), keyPath: "transform", timingFunction: kCAMediaTimingFunctionSpring, duration: 0.25)
        
        self.imageNode.clipsToBounds = true
        self.imageNode.layer.animate(from: (self.imageNode.frame.width / 2.0) as NSNumber, to: 0.0 as NSNumber, keyPath: "cornerRadius", timingFunction: kCAMediaTimingFunctionDefault, duration: 0.18, removeOnCompletion: false, completion: { [weak self] value in
            if value {
                self?.imageNode.clipsToBounds = false
            }
        })
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
        
        let durationFactor = 1.0
        
        copyView.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.1 * durationFactor, removeOnCompletion: false)
        
        copyView.layer.animatePosition(from: CGPoint(x: transformedCopyViewInitialFrame.midX, y: transformedCopyViewInitialFrame.midY), to: CGPoint(x: transformedSelfFrame.midX, y: transformedSelfFrame.midY), duration: 0.25 * durationFactor, timingFunction: kCAMediaTimingFunctionSpring, removeOnCompletion: false)
        let scale = CGSize(width: transformedCopyViewInitialFrame.size.width / transformedSelfFrame.size.width, height: transformedCopyViewInitialFrame.size.height / transformedSelfFrame.size.height)
        copyView.layer.animate(from: NSValue(caTransform3D: CATransform3DMakeScale(scale.width, scale.height, 1.0)), to: NSValue(caTransform3D: CATransform3DIdentity), keyPath: "transform", timingFunction: kCAMediaTimingFunctionSpring, duration: 0.25 * durationFactor, removeOnCompletion: false, completion: { _ in
            copyCompleted = true
            intermediateCompletion()
        })
        
        self.imageNode.layer.animatePosition(from: self.imageNode.layer.position, to: CGPoint(x: transformedSuperFrame.midX, y: transformedSuperFrame.midY), duration: 0.25 * durationFactor, timingFunction: kCAMediaTimingFunctionSpring, removeOnCompletion: false, completion: { _ in
            positionCompleted = true
            intermediateCompletion()
        })
        
        self.imageNode.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.25 * durationFactor, removeOnCompletion: false)
        
        transformedFrame.origin = CGPoint()
        
        /*self.imageNode.layer.animateBounds(from: self.imageNode.layer.bounds, to: transformedFrame, duration: 0.25 * durationFactor, timingFunction: kCAMediaTimingFunctionSpring, removeOnCompletion: false, completion: { _ in
            boundsCompleted = true
            intermediateCompletion()
        })*/
        
        let transform = CATransform3DScale(self.imageNode.layer.transform, transformedFrame.size.width / self.imageNode.layer.bounds.size.width, transformedFrame.size.height / self.imageNode.layer.bounds.size.height, 1.0)
        self.imageNode.layer.animate(from: NSValue(caTransform3D: self.imageNode.layer.transform), to: NSValue(caTransform3D: transform), keyPath: "transform", timingFunction: kCAMediaTimingFunctionSpring, duration: 0.25 * durationFactor, removeOnCompletion: false, completion: { _ in
            boundsCompleted = true
            intermediateCompletion()
        })
        
        self.imageNode.clipsToBounds = true
        self.imageNode.layer.animate(from: 0.0 as NSNumber, to: (self.imageNode.frame.width / 2.0) as NSNumber, keyPath: "cornerRadius", timingFunction: kCAMediaTimingFunctionDefault, duration: 0.18 * durationFactor, removeOnCompletion: false)
    }
    
    override func visibilityUpdated(isVisible: Bool) {
        super.visibilityUpdated(isVisible: isVisible)
        
        /*if let (account, media) = self.accountAndEntry, let file = media as? TelegramMediaFile {
            if isVisible {
                self.fetchDisposable.set(account.postbox.mediaBox.fetchedResource(file.resource).start())
            } else {
                self.fetchDisposable.set(nil)
            }
        }*/
    }
    
    override func title() -> Signal<String, NoError> {
        return self._title.get()
    }
    
    /*override func footerContent() -> Signal<GalleryFooterContentNode?, NoError> {
        return .single(self.footerContentNode)
    }*/
}
