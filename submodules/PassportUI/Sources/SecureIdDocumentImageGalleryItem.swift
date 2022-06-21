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

class SecureIdDocumentGalleryItem: GalleryItem {
    var id: AnyHashable {
        return self.itemId
    }
    
    let itemId: AnyHashable
    
    let context: AccountContext
    let theme: PresentationTheme
    let strings: PresentationStrings
    let secureIdContext: SecureIdAccessContext
    let resource: TelegramMediaResource
    let caption: String
    let location: SecureIdDocumentGalleryEntryLocation
    let delete: () -> Void
    
    init(context: AccountContext, theme: PresentationTheme, strings: PresentationStrings, secureIdContext: SecureIdAccessContext, itemId: AnyHashable, resource: TelegramMediaResource, caption: String, location: SecureIdDocumentGalleryEntryLocation, delete: @escaping () -> Void) {
        self.itemId = itemId
        self.context = context
        self.theme = theme
        self.strings = strings
        self.secureIdContext = secureIdContext
        self.resource = resource
        self.caption = caption
        self.location = location
        self.delete = delete
    }
    
    func node(synchronous: Bool) -> GalleryItemNode {
        let node = SecureIdDocumentGalleryItemNode(context: self.context, theme: self.theme, strings: self.strings)
        
        node.setResource(secureIdContext: self.secureIdContext, resource: self.resource)
        
        node._title.set(.single(self.strings.Items_NOfM("\(self.location.position + 1)", "\(self.location.totalCount)").string))
        
        node.setCaption(self.caption)
        node.delete = self.delete
        
        return node
    }
    
    func updateNode(node: GalleryItemNode, synchronous: Bool) {
        if let node = node as? SecureIdDocumentGalleryItemNode {
            node._title.set(.single(self.strings.Items_NOfM("\(self.location.position + 1)", "\(self.location.totalCount)").string))
            
            node.setCaption(self.caption)
            node.delete = self.delete
        }
    }
    
    func thumbnailItem() -> (Int64, GalleryThumbnailItem)? {
        return nil
    }
}

final class SecureIdDocumentGalleryItemNode: ZoomableContentGalleryItemNode {
    private let context: AccountContext
    
    private let imageNode: TransformImageNode
    fileprivate let _ready = Promise<Void>()
    fileprivate let _title = Promise<String>()
    private let footerContentNode: SecureIdDocumentGalleryFooterContentNode
    
    private var contextAndMedia: (AccountContext, SecureIdAccessContext, TelegramMediaResource)?
    
    private var fetchDisposable = MetaDisposable()
    
    var delete: (() -> Void)? {
        didSet {
            self.footerContentNode.delete = self.delete
        }
    }
    
    init(context: AccountContext, theme: PresentationTheme, strings: PresentationStrings) {
        self.context = context
        
        self.imageNode = TransformImageNode()
        self.footerContentNode = SecureIdDocumentGalleryFooterContentNode(context: context, theme: theme, strings: strings)
        
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
    
    fileprivate func setCaption(_ caption: String) {
        self.footerContentNode.setup(caption: caption)
    }
    
    fileprivate func setResource(secureIdContext: SecureIdAccessContext, resource: TelegramMediaResource) {
        if self.contextAndMedia == nil || !self.contextAndMedia!.2.isEqual(to: resource) {
            let displaySize = CGSize(width: 1280.0, height: 1280.0)
            //self.imageNode.asyncLayout()(TransformImageArguments(corners: ImageCorners(), imageSize: displaySize, boundingSize: displaySize, intrinsicInsets: UIEdgeInsets()))()
            self.imageNode.setSignal(securePhotoInternal(account: context.account, resource: resource, accessContext: secureIdContext) |> beforeNext { [weak self] value in
                Queue.mainQueue().async {
                    if let strongSelf = self {
                        if let size = value.0(), strongSelf.zoomableContent?.0 != size {
                            strongSelf.imageNode.asyncLayout()(TransformImageArguments(corners: ImageCorners(), imageSize: size, boundingSize: size, intrinsicInsets: UIEdgeInsets()))()
                            strongSelf.zoomableContent = (size, strongSelf.imageNode)
                        }
                    }
                }
            } |> map { value in
                return value.1
            })
            self.zoomableContent = (displaySize, self.imageNode)
            self.fetchDisposable.set(context.account.postbox.mediaBox.fetchedResource(resource, parameters: nil).start())
        }
        self.contextAndMedia = (context, secureIdContext, resource)
    }
    
    override func animateIn(from node: (ASDisplayNode, CGRect, () -> (UIView?, UIView?)), addToTransitionSurface: (UIView) -> Void, completion: @escaping () -> Void) {
        var transformedFrame = node.0.view.convert(node.0.view.bounds, to: self.imageNode.view)
        let transformedSuperFrame = node.0.view.convert(node.0.view.bounds, to: self.imageNode.view.superview)
        let transformedSelfFrame = node.0.view.convert(node.0.view.bounds, to: self.view)
        let transformedCopyViewFinalFrame = self.imageNode.view.convert(self.imageNode.view.bounds, to: self.view)
        
        let copyView = node.2().0!
        
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
    
    override func animateOut(to node: (ASDisplayNode, CGRect, () -> (UIView?, UIView?)), addToTransitionSurface: (UIView) -> Void, completion: @escaping () -> Void) {
        var transformedFrame = node.0.view.convert(node.0.view.bounds, to: self.imageNode.view)
        let transformedSuperFrame = node.0.view.convert(node.0.view.bounds, to: self.imageNode.view.superview)
        let transformedSelfFrame = node.0.view.convert(node.0.view.bounds, to: self.view)
        let transformedCopyViewInitialFrame = self.imageNode.view.convert(self.imageNode.view.bounds, to: self.view)
        
        var positionCompleted = false
        var boundsCompleted = false
        var copyCompleted = false
        
        let copyView = node.2().0!
        
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
    }
    
    override func title() -> Signal<String, NoError> {
        return self._title.get()
    }
    
    override func footerContent() -> Signal<(GalleryFooterContentNode?, GalleryOverlayContentNode?), NoError> {
        return .single((self.footerContentNode, nil))
    }
}

