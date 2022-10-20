import Foundation
import UIKit
import Display
import AsyncDisplayKit
import SwiftSignalKit
import Postbox
import TelegramCore
import TelegramPresentationData
import AccountContext
import PhotoResources
import GalleryUI

private struct InstantImageGalleryThumbnailItem: GalleryThumbnailItem {
    let account: Account
    let mediaReference: AnyMediaReference
    
    func image(synchronous: Bool) -> (Signal<(TransformImageArguments) -> DrawingContext?, NoError>, CGSize) {
        if let imageReferene = mediaReference.concrete(TelegramMediaImage.self), let representation = largestImageRepresentation(imageReferene.media.representations) {
            return (mediaGridMessagePhoto(account: self.account, photoReference: imageReferene), representation.dimensions.cgSize)
        } else if let fileReference = mediaReference.concrete(TelegramMediaFile.self), let dimensions = fileReference.media.dimensions {
                return (mediaGridMessageVideo(postbox: account.postbox, videoReference: fileReference), dimensions.cgSize)
            } else {
            return (.single({ _ in return nil }), CGSize(width: 128.0, height: 128.0))
        }
    }
    
    func isEqual(to: GalleryThumbnailItem) -> Bool {
        if let to = to as? InstantImageGalleryThumbnailItem {
            return self.mediaReference == to.mediaReference
        } else {
            return false
        }
    }
}

class InstantImageGalleryItem: GalleryItem {
    var id: AnyHashable {
        return self.itemId
    }
    
    let itemId: AnyHashable
    
    let context: AccountContext
    let presentationData: PresentationData
    let imageReference: ImageMediaReference
    let caption: NSAttributedString
    let credit: NSAttributedString
    let location: InstantPageGalleryEntryLocation?
    let openUrl: (InstantPageUrlItem) -> Void
    let openUrlOptions: (InstantPageUrlItem) -> Void
    
    init(context: AccountContext, presentationData: PresentationData, itemId: AnyHashable, imageReference: ImageMediaReference, caption: NSAttributedString, credit: NSAttributedString, location: InstantPageGalleryEntryLocation?, openUrl: @escaping (InstantPageUrlItem) -> Void, openUrlOptions: @escaping (InstantPageUrlItem) -> Void) {
        self.itemId = itemId
        self.context = context
        self.presentationData = presentationData
        self.imageReference = imageReference
        self.caption = caption
        self.credit = credit
        self.location = location
        self.openUrl = openUrl
        self.openUrlOptions = openUrlOptions
    }
    
    func node(synchronous: Bool) -> GalleryItemNode {
        let node = InstantImageGalleryItemNode(context: self.context, presentationData: self.presentationData, openUrl: self.openUrl, openUrlOptions: self.openUrlOptions)
        
        node.setImage(imageReference: self.imageReference)
    
        if let location = self.location {
            node._title.set(.single(self.presentationData.strings.Items_NOfM("\(location.position + 1)", "\(location.totalCount)").string))
        }
        
        node.setCaption(self.caption, credit: self.credit)
        
        return node
    }
    
    func updateNode(node: GalleryItemNode, synchronous: Bool) {
        if let node = node as? InstantImageGalleryItemNode {
            if let location = self.location {
                node._title.set(.single(self.presentationData.strings.Items_NOfM("\(location.position + 1)", "\(location.totalCount)").string))
            }
            
            node.setCaption(self.caption, credit: self.credit)
        }
    }
    
    func thumbnailItem() -> (Int64, GalleryThumbnailItem)? {
        return (0, InstantImageGalleryThumbnailItem(account: self.context.account, mediaReference: imageReference.abstract))
    }
}

final class InstantImageGalleryItemNode: ZoomableContentGalleryItemNode {
    private let context: AccountContext
    
    private let imageNode: TransformImageNode
    fileprivate let _ready = Promise<Void>()
    fileprivate let _title = Promise<String>()
    private let footerContentNode: InstantPageGalleryFooterContentNode
    
    private var contextAndMedia: (AccountContext, AnyMediaReference)?
    
    private var fetchDisposable = MetaDisposable()
    
    init(context: AccountContext, presentationData: PresentationData, openUrl: @escaping (InstantPageUrlItem) -> Void, openUrlOptions: @escaping (InstantPageUrlItem) -> Void) {
        self.context = context
        
        self.imageNode = TransformImageNode()
        self.footerContentNode = InstantPageGalleryFooterContentNode(context: context, presentationData: presentationData)
        self.footerContentNode.openUrl = openUrl
        self.footerContentNode.openUrlOptions = openUrlOptions
        
        super.init()
        
        self.imageNode.imageUpdated = { [weak self] _ in
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
    
    fileprivate func setCaption(_ caption: NSAttributedString, credit: NSAttributedString) {
        self.footerContentNode.setCaption(caption, credit: credit)
    }
    
    fileprivate func setImage(imageReference: ImageMediaReference) {
        if self.contextAndMedia == nil || !self.contextAndMedia!.1.media.isEqual(to: imageReference.media) {
            if let largestSize = largestRepresentationForPhoto(imageReference.media) {
                let displaySize = largestSize.dimensions.cgSize.fitted(CGSize(width: 1280.0, height: 1280.0)).dividedByScreenScale().integralFloor
                self.imageNode.asyncLayout()(TransformImageArguments(corners: ImageCorners(), imageSize: displaySize, boundingSize: displaySize, intrinsicInsets: UIEdgeInsets(), emptyColor: .black))()
                self.imageNode.setSignal(chatMessagePhoto(postbox: self.context.account.postbox, photoReference: imageReference), dispatchOnDisplayLink: false)
                self.zoomableContent = (largestSize.dimensions.cgSize, self.imageNode)
                self.fetchDisposable.set(fetchedMediaResource(mediaBox: self.context.account.postbox.mediaBox, reference: imageReference.resourceReference(largestSize.resource)).start())
            } else {
                self._ready.set(.single(Void()))
            }
        }
        self.contextAndMedia = (self.context, imageReference.abstract)
        self.footerContentNode.setShareMedia(imageReference.abstract)
    }
    
    func setFile(context: AccountContext, fileReference: FileMediaReference) {
        if self.contextAndMedia == nil || !self.contextAndMedia!.1.media.isEqual(to: fileReference.media) {
            if let largestSize = fileReference.media.dimensions {
                let displaySize = largestSize.cgSize.dividedByScreenScale()
                self.imageNode.asyncLayout()(TransformImageArguments(corners: ImageCorners(), imageSize: displaySize, boundingSize: displaySize, intrinsicInsets: UIEdgeInsets()))()
                self.imageNode.setSignal(chatMessageImageFile(account: context.account, fileReference: fileReference, thumbnail: false), dispatchOnDisplayLink: false)
                self.zoomableContent = (largestSize.cgSize, self.imageNode)
            } else {
                self._ready.set(.single(Void()))
            }
        }
        self.contextAndMedia = (context, fileReference.abstract)
        self.footerContentNode.setShareMedia(fileReference.abstract)
    }
    
    override func animateIn(from node: (ASDisplayNode, CGRect, () -> (UIView?, UIView?)), addToTransitionSurface: (UIView) -> Void, completion: @escaping () -> Void) {
        var transformedFrame = node.0.view.convert(node.0.view.bounds, to: self.imageNode.view)
        let transformedSuperFrame = node.0.view.convert(node.0.view.bounds, to: self.imageNode.view.superview)
        let transformedSelfFrame = node.0.view.convert(node.0.view.bounds, to: self.view)
        let transformedCopyViewFinalFrame = self.imageNode.view.convert(self.imageNode.view.bounds, to: self.view)
        
        let surfaceCopyView = node.2().0!
        let copyView = node.2().0!
        
        addToTransitionSurface(surfaceCopyView)
        
        var transformedSurfaceFrame: CGRect?
        var transformedSurfaceFinalFrame: CGRect?
        if let contentSurface = surfaceCopyView.superview {
            transformedSurfaceFrame = node.0.view.convert(node.0.view.bounds, to: contentSurface)
            transformedSurfaceFinalFrame = self.imageNode.view.convert(self.imageNode.view.bounds, to: contentSurface)
        }
        
        if let transformedSurfaceFrame = transformedSurfaceFrame {
            surfaceCopyView.frame = transformedSurfaceFrame
        }
        
        self.view.insertSubview(copyView, belowSubview: self.scrollNode.view)
        copyView.frame = transformedSelfFrame
        
        copyView.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.2, removeOnCompletion: false)
        
        surfaceCopyView.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.25, removeOnCompletion: false)
        
        let positionDuration: Double = 0.21
        
        copyView.layer.animatePosition(from: CGPoint(x: transformedSelfFrame.midX, y: transformedSelfFrame.midY), to: CGPoint(x: transformedCopyViewFinalFrame.midX, y: transformedCopyViewFinalFrame.midY), duration: positionDuration, timingFunction: kCAMediaTimingFunctionSpring, removeOnCompletion: false, completion: { [weak copyView] _ in
            copyView?.removeFromSuperview()
        })
        let scale = CGSize(width: transformedCopyViewFinalFrame.size.width / transformedSelfFrame.size.width, height: transformedCopyViewFinalFrame.size.height / transformedSelfFrame.size.height)
        copyView.layer.animate(from: NSValue(caTransform3D: CATransform3DIdentity), to: NSValue(caTransform3D: CATransform3DMakeScale(scale.width, scale.height, 1.0)), keyPath: "transform", timingFunction: kCAMediaTimingFunctionSpring, duration: 0.25, removeOnCompletion: false)
        
        if let transformedSurfaceFrame = transformedSurfaceFrame, let transformedSurfaceFinalFrame = transformedSurfaceFinalFrame {
            surfaceCopyView.layer.animatePosition(from: CGPoint(x: transformedSurfaceFrame.midX, y: transformedSurfaceFrame.midY), to: CGPoint(x: transformedCopyViewFinalFrame.midX, y: transformedCopyViewFinalFrame.midY), duration: positionDuration, timingFunction: kCAMediaTimingFunctionSpring, removeOnCompletion: false, completion: { [weak surfaceCopyView] _ in
                surfaceCopyView?.removeFromSuperview()
            })
            let scale = CGSize(width: transformedSurfaceFinalFrame.size.width / transformedSurfaceFrame.size.width, height: transformedSurfaceFinalFrame.size.height / transformedSurfaceFrame.size.height)
            surfaceCopyView.layer.animate(from: NSValue(caTransform3D: CATransform3DIdentity), to: NSValue(caTransform3D: CATransform3DMakeScale(scale.width, scale.height, 1.0)), keyPath: "transform", timingFunction: kCAMediaTimingFunctionSpring, duration: 0.25, removeOnCompletion: false)
        }
        
        self.imageNode.layer.animatePosition(from: CGPoint(x: transformedSuperFrame.midX, y: transformedSuperFrame.midY), to: self.imageNode.layer.position, duration: positionDuration, timingFunction: kCAMediaTimingFunctionSpring)
        self.imageNode.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.1)
        
        transformedFrame.origin = CGPoint()
        self.imageNode.layer.animateBounds(from: transformedFrame, to: self.imageNode.layer.bounds, duration: 0.25, timingFunction: kCAMediaTimingFunctionSpring)
        
        /*self.statusNodeContainer.layer.animatePosition(from: CGPoint(x: transformedSuperFrame.midX, y: transformedSuperFrame.midY), to: self.statusNodeContainer.position, duration: positionDuration, timingFunction: kCAMediaTimingFunctionSpring)
        self.statusNodeContainer.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.25, timingFunction: kCAMediaTimingFunctionSpring)
        self.statusNodeContainer.layer.animateScale(from: 0.5, to: 1.0, duration: 0.25, timingFunction: kCAMediaTimingFunctionSpring)*/
    }
    
    override func animateOut(to node: (ASDisplayNode, CGRect, () -> (UIView?, UIView?)), addToTransitionSurface: (UIView) -> Void, completion: @escaping () -> Void) {
        self.fetchDisposable.set(nil)
        
        var transformedFrame = node.0.view.convert(node.0.view.bounds, to: self.imageNode.view)
        let transformedSuperFrame = node.0.view.convert(node.0.view.bounds, to: self.imageNode.view.superview)
        let transformedSelfFrame = node.0.view.convert(node.0.view.bounds, to: self.view)
        let transformedCopyViewInitialFrame = self.imageNode.view.convert(self.imageNode.view.bounds, to: self.view)
        
        var positionCompleted = false
        var boundsCompleted = false
        var copyCompleted = false
        
        let copyView = node.2().0!
        let surfaceCopyView = node.2().0!
        
        addToTransitionSurface(surfaceCopyView)
        
        var transformedSurfaceFrame: CGRect?
        var transformedSurfaceCopyViewInitialFrame: CGRect?
        if let contentSurface = surfaceCopyView.superview {
            transformedSurfaceFrame = node.0.view.convert(node.0.view.bounds, to: contentSurface)
            transformedSurfaceCopyViewInitialFrame = self.imageNode.view.convert(self.imageNode.view.bounds, to: contentSurface)
        }
        
        self.view.insertSubview(copyView, belowSubview: self.scrollNode.view)
        copyView.frame = transformedSelfFrame
        
        let intermediateCompletion = { [weak copyView, weak surfaceCopyView] in
            if positionCompleted && boundsCompleted && copyCompleted {
                copyView?.removeFromSuperview()
                surfaceCopyView?.removeFromSuperview()
                completion()
            }
        }
        
        copyView.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.08, removeOnCompletion: false)
        surfaceCopyView.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.025, removeOnCompletion: false)
        
        copyView.layer.animatePosition(from: CGPoint(x: transformedCopyViewInitialFrame.midX, y: transformedCopyViewInitialFrame.midY), to: CGPoint(x: transformedSelfFrame.midX, y: transformedSelfFrame.midY), duration: 0.25, timingFunction: kCAMediaTimingFunctionSpring, removeOnCompletion: false)
        let scale = CGSize(width: transformedCopyViewInitialFrame.size.width / transformedSelfFrame.size.width, height: transformedCopyViewInitialFrame.size.height / transformedSelfFrame.size.height)
        copyView.layer.animate(from: NSValue(caTransform3D: CATransform3DMakeScale(scale.width, scale.height, 1.0)), to: NSValue(caTransform3D: CATransform3DIdentity), keyPath: "transform", timingFunction: kCAMediaTimingFunctionSpring, duration: 0.25, removeOnCompletion: false, completion: { _ in
            copyCompleted = true
            intermediateCompletion()
        })
        
        if let transformedSurfaceFrame = transformedSurfaceFrame, let transformedCopyViewInitialFrame = transformedSurfaceCopyViewInitialFrame {
            surfaceCopyView.layer.animatePosition(from: CGPoint(x: transformedCopyViewInitialFrame.midX, y: transformedCopyViewInitialFrame.midY), to: CGPoint(x: transformedSurfaceFrame.midX, y: transformedSurfaceFrame.midY), duration: 0.25, timingFunction: kCAMediaTimingFunctionSpring, removeOnCompletion: false)
            let scale = CGSize(width: transformedCopyViewInitialFrame.size.width / transformedSurfaceFrame.size.width, height: transformedCopyViewInitialFrame.size.height / transformedSurfaceFrame.size.height)
            surfaceCopyView.layer.animate(from: NSValue(caTransform3D: CATransform3DMakeScale(scale.width, scale.height, 1.0)), to: NSValue(caTransform3D: CATransform3DIdentity), keyPath: "transform", timingFunction: kCAMediaTimingFunctionSpring, duration: 0.25, removeOnCompletion: false)
        }
        
        self.imageNode.layer.animatePosition(from: self.imageNode.layer.position, to: CGPoint(x: transformedSuperFrame.midX, y: transformedSuperFrame.midY), duration: 0.25, timingFunction: kCAMediaTimingFunctionSpring, removeOnCompletion: false, completion: { _ in
            positionCompleted = true
            intermediateCompletion()
        })
        
        self.imageNode.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.08, removeOnCompletion: false)
        
        transformedFrame.origin = CGPoint()
        self.imageNode.layer.animateBounds(from: self.imageNode.layer.bounds, to: transformedFrame, duration: 0.25, timingFunction: kCAMediaTimingFunctionSpring, removeOnCompletion: false, completion: { _ in
            boundsCompleted = true
            intermediateCompletion()
        })
        
        /*self.statusNodeContainer.layer.animatePosition(from: self.statusNodeContainer.position, to: CGPoint(x: transformedSuperFrame.midX, y: transformedSuperFrame.midY), duration: 0.25, timingFunction: kCAMediaTimingFunctionSpring, removeOnCompletion: false)
        self.statusNodeContainer.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.15, timingFunction: CAMediaTimingFunctionName.easeIn.rawValue, removeOnCompletion: false)*/
    }
    
    override func visibilityUpdated(isVisible: Bool) {
        super.visibilityUpdated(isVisible: isVisible)
        
        if let (context, media) = self.contextAndMedia, let fileReference = media.concrete(TelegramMediaFile.self) {
            if isVisible {
                self.fetchDisposable.set(fetchedMediaResource(mediaBox: context.account.postbox.mediaBox, reference: fileReference.resourceReference(fileReference.media.resource)).start())
            } else {
                self.fetchDisposable.set(nil)
            }
        }
    }
    
    override func title() -> Signal<String, NoError> {
        return self._title.get()
    }
    
    override func footerContent() -> Signal<(GalleryFooterContentNode?, GalleryOverlayContentNode?), NoError> {
        return .single((self.footerContentNode, nil))
    }
}
