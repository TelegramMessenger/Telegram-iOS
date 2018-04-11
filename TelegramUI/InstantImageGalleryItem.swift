import Foundation
import Display
import AsyncDisplayKit
import SwiftSignalKit
import Postbox
import TelegramCore

class InstantImageGalleryItem: GalleryItem {
    let account: Account
    let theme: PresentationTheme
    let strings: PresentationStrings
    let image: TelegramMediaImage
    let caption: String
    let location: InstantPageGalleryEntryLocation
    
    init(account: Account, theme: PresentationTheme, strings: PresentationStrings, image: TelegramMediaImage, caption: String, location: InstantPageGalleryEntryLocation) {
        self.account = account
        self.theme = theme
        self.strings = strings
        self.image = image
        self.caption = caption
        self.location = location
    }
    
    func node() -> GalleryItemNode {
        let node = InstantImageGalleryItemNode(account: self.account, theme: self.theme, strings: self.strings)
        
        node.setImage(image: self.image)
    
        node._title.set(.single("\(self.location.position + 1) of \(self.location.totalCount)"))
        
        node.setCaption(self.caption)
        
        return node
    }
    
    func updateNode(node: GalleryItemNode) {
        if let node = node as? InstantImageGalleryItemNode {
            node._title.set(.single("\(self.location.position + 1) of \(self.location.totalCount)"))
            
            node.setCaption(self.caption)
        }
    }
    
    func thumbnailItem() -> (Int64, GalleryThumbnailItem)? {
        return nil
    }
}

final class InstantImageGalleryItemNode: ZoomableContentGalleryItemNode {
    private let account: Account
    
    private let imageNode: TransformImageNode
    fileprivate let _ready = Promise<Void>()
    fileprivate let _title = Promise<String>()
    private let footerContentNode: InstantPageGalleryFooterContentNode
    
    private var accountAndMedia: (Account, Media)?
    
    private var fetchDisposable = MetaDisposable()
    
    init(account: Account, theme: PresentationTheme, strings: PresentationStrings) {
        self.account = account
        
        self.imageNode = TransformImageNode()
        self.footerContentNode = InstantPageGalleryFooterContentNode(account: account, theme: theme, strings: strings)
        
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
    
    fileprivate func setCaption(_ caption: String) {
        self.footerContentNode.setCaption(caption)
    }
    
    fileprivate func setImage(image: TelegramMediaImage) {
        if self.accountAndMedia == nil || !self.accountAndMedia!.1.isEqual(image) {
            if let largestSize = largestRepresentationForPhoto(image) {
                let displaySize = largestSize.dimensions.fitted(CGSize(width: 1280.0, height: 1280.0)).dividedByScreenScale().integralFloor
                self.imageNode.asyncLayout()(TransformImageArguments(corners: ImageCorners(), imageSize: displaySize, boundingSize: displaySize, intrinsicInsets: UIEdgeInsets()))()
                self.imageNode.setSignal(chatMessagePhoto(postbox: account.postbox, photo: image), dispatchOnDisplayLink: false)
                self.zoomableContent = (largestSize.dimensions, self.imageNode)
                self.fetchDisposable.set(account.postbox.mediaBox.fetchedResource(largestSize.resource, tag: TelegramMediaResourceFetchTag(statsCategory: .image)).start())
            } else {
                self._ready.set(.single(Void()))
            }
        }
        self.accountAndMedia = (account, image)
    }
    
    func setFile(account: Account, file: TelegramMediaFile) {
        if self.accountAndMedia == nil || !self.accountAndMedia!.1.isEqual(file) {
            if let largestSize = file.dimensions {
                let displaySize = largestSize.dividedByScreenScale()
                self.imageNode.asyncLayout()(TransformImageArguments(corners: ImageCorners(), imageSize: displaySize, boundingSize: displaySize, intrinsicInsets: UIEdgeInsets()))()
                self.imageNode.setSignal(chatMessageImageFile(account: account, file: file, thumbnail: false), dispatchOnDisplayLink: false)
                self.zoomableContent = (largestSize, self.imageNode)
            } else {
                self._ready.set(.single(Void()))
            }
        }
        self.accountAndMedia = (account, file)
    }
    
    override func animateIn(from node: (ASDisplayNode, () -> UIView?), addToTransitionSurface: (UIView) -> Void) {
        var transformedFrame = node.0.view.convert(node.0.view.bounds, to: self.imageNode.view)
        let transformedSuperFrame = node.0.view.convert(node.0.view.bounds, to: self.imageNode.view.superview)
        let transformedSelfFrame = node.0.view.convert(node.0.view.bounds, to: self.view)
        let transformedCopyViewFinalFrame = self.imageNode.view.convert(self.imageNode.view.bounds, to: self.view)
        
        let copyView = node.1()!
        
        self.view.insertSubview(copyView, belowSubview: self.scrollNode.view)
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
    
    override func animateOut(to node: (ASDisplayNode, () -> UIView?), addToTransitionSurface: (UIView) -> Void, completion: @escaping () -> Void) {
        var transformedFrame = node.0.view.convert(node.0.view.bounds, to: self.imageNode.view)
        let transformedSuperFrame = node.0.view.convert(node.0.view.bounds, to: self.imageNode.view.superview)
        let transformedSelfFrame = node.0.view.convert(node.0.view.bounds, to: self.view)
        let transformedCopyViewInitialFrame = self.imageNode.view.convert(self.imageNode.view.bounds, to: self.view)
        
        var positionCompleted = false
        var boundsCompleted = false
        var copyCompleted = false
        
        let copyView = node.1()!
        
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
                self.fetchDisposable.set(account.postbox.mediaBox.fetchedResource(file.resource, tag: TelegramMediaResourceFetchTag(statsCategory: .image)).start())
            } else {
                self.fetchDisposable.set(nil)
            }
        }
    }
    
    override func title() -> Signal<String, NoError> {
        return self._title.get()
    }
    
    override func footerContent() -> Signal<GalleryFooterContentNode?, NoError> {
        return .single(self.footerContentNode)
    }
}
