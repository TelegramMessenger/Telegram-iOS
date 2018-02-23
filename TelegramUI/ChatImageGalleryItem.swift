import Foundation
import Display
import AsyncDisplayKit
import SwiftSignalKit
import Postbox
import TelegramCore

class ChatImageGalleryItem: GalleryItem {
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
        let node = ChatImageGalleryItemNode(account: self.account, theme: self.theme, strings: self.strings)
        
        for media in self.message.media {
            if let image = media as? TelegramMediaImage {
                node.setImage(image: image)
                break
            } else if let file = media as? TelegramMediaFile, file.mimeType.hasPrefix("image/") {
                node.setFile(account: account, file: file)
                break
            } else if let webpage = media as? TelegramMediaWebpage, case let .Loaded(content) = webpage.content {
                if let image = content.image {
                    node.setImage(image: image)
                    break
                } else if let file = content.file, file.mimeType.hasPrefix("image/") {
                    node.setFile(account: account, file: file)
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
        if let node = node as? ChatImageGalleryItemNode, let location = self.location {
            node._title.set(.single("\(location.index + 1) of \(location.count)"))
            
            node.setMessage(self.message)
        }
    }
}

final class ChatImageGalleryItemNode: ZoomableContentGalleryItemNode {
    private let account: Account
    private var message: Message?
    
    private let imageNode: TransformImageNode
    fileprivate let _ready = Promise<Void>()
    fileprivate let _title = Promise<String>()
    private let statusNodeContainer: HighlightableButtonNode
    private let statusNode: RadialStatusNode
    private let footerContentNode: ChatItemGalleryFooterContentNode
    
    private var accountAndMedia: (Account, Media)?
    
    private var fetchDisposable = MetaDisposable()
    private let statusDisposable = MetaDisposable()
    private var status: MediaResourceStatus?
    
    init(account: Account, theme: PresentationTheme, strings: PresentationStrings) {
        self.account = account
        
        self.imageNode = TransformImageNode()
        self.footerContentNode = ChatItemGalleryFooterContentNode(account: account, theme: theme, strings: strings)
        
        self.statusNodeContainer = HighlightableButtonNode()
        self.statusNode = RadialStatusNode(backgroundNodeColor: UIColor(white: 0.0, alpha: 0.5))
        self.statusNode.isHidden = true
        
        super.init()
        
        self.imageNode.imageUpdated = { [weak self] in
            self?._ready.set(.single(Void()))
        }
        
        self.imageNode.view.contentMode = .scaleAspectFill
        self.imageNode.clipsToBounds = true
        
        self.statusNodeContainer.addSubnode(self.statusNode)
        self.addSubnode(self.statusNodeContainer)
        
        self.statusNodeContainer.addTarget(self, action: #selector(self.statusPressed), forControlEvents: .touchUpInside)
        
        self.statusNodeContainer.isUserInteractionEnabled = false
    }
    
    deinit {
        self.fetchDisposable.dispose()
        self.statusDisposable.dispose()
    }
    
    override func ready() -> Signal<Void, NoError> {
        return self._ready.get()
    }
    
    override func containerLayoutUpdated(_ layout: ContainerViewLayout, navigationBarHeight: CGFloat, transition: ContainedViewLayoutTransition) {
        super.containerLayoutUpdated(layout, navigationBarHeight: navigationBarHeight, transition: transition)
        
        let statusSize = CGSize(width: 50.0, height: 50.0)
        transition.updateFrame(node: self.statusNodeContainer, frame: CGRect(origin: CGPoint(x: floor((layout.size.width - statusSize.width) / 2.0), y: floor((layout.size.height - statusSize.height) / 2.0)), size: statusSize))
        transition.updateFrame(node: self.statusNode, frame: CGRect(origin: CGPoint(), size: statusSize))
    }
    
    fileprivate func setMessage(_ message: Message) {
        self.footerContentNode.setMessage(message)
    }
    
    fileprivate func setImage(image: TelegramMediaImage) {
        if self.accountAndMedia == nil || !self.accountAndMedia!.1.isEqual(image) {
            if let largestSize = largestRepresentationForPhoto(image) {
                let displaySize = largestSize.dimensions.fitted(CGSize(width: 1280.0, height: 1280.0)).dividedByScreenScale().integralFloor
                self.imageNode.asyncLayout()(TransformImageArguments(corners: ImageCorners(), imageSize: displaySize, boundingSize: displaySize, intrinsicInsets: UIEdgeInsets()))()
                self.imageNode.setSignal(chatMessagePhoto(postbox: account.postbox, photo: image), dispatchOnDisplayLink: false)
                self.zoomableContent = (largestSize.dimensions, self.imageNode)
                self.fetchDisposable.set(account.postbox.mediaBox.fetchedResource(largestSize.resource, tag: TelegramMediaResourceFetchTag(statsCategory: .image)).start())
                self.setupStatus(resource: largestSize.resource)
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
                self.setupStatus(resource: file.resource)
            } else {
                self._ready.set(.single(Void()))
            }
        }
        self.accountAndMedia = (account, file)
    }
    
    private func setupStatus(resource: MediaResource) {
        self.statusDisposable.set((account.postbox.mediaBox.resourceStatus(resource)
            |> deliverOnMainQueue).start(next: { [weak self] status in
                if let strongSelf = self {
                    let previousStatus = strongSelf.status
                    strongSelf.status = status
                    switch status {
                        case .Remote:
                            strongSelf.statusNode.isHidden = false
                            strongSelf.statusNode.alpha = 1.0
                            strongSelf.statusNodeContainer.isUserInteractionEnabled = true
                            strongSelf.statusNode.transitionToState(.download(.white), completion: {})
                        case let .Fetching(isActive, progress):
                            strongSelf.statusNode.isHidden = false
                            strongSelf.statusNode.alpha = 1.0
                            strongSelf.statusNodeContainer.isUserInteractionEnabled = true
                            var actualProgress = progress
                            if isActive {
                                actualProgress = max(actualProgress, 0.027)
                            }
                            strongSelf.statusNode.transitionToState(.progress(color: .white, value: CGFloat(actualProgress), cancelEnabled: true), completion: {})
                        case .Local:
                            if let previousStatus = previousStatus, case .Fetching = previousStatus {
                                strongSelf.statusNode.transitionToState(.progress(color: .white, value: 1.0, cancelEnabled: true), completion: {
                                    if let strongSelf = self {
                                        strongSelf.statusNode.alpha = 0.0
                                        strongSelf.statusNodeContainer.isUserInteractionEnabled = false
                                        strongSelf.statusNode.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.2, completion: { _ in
                                            if let strongSelf = self {
                                                strongSelf.statusNode.transitionToState(.none, animated: false, completion: {})
                                            }
                                        })
                                    }
                                })
                            } else if !strongSelf.statusNode.isHidden && !strongSelf.statusNode.alpha.isZero {
                                strongSelf.statusNode.alpha = 0.0
                                strongSelf.statusNodeContainer.isUserInteractionEnabled = false
                                strongSelf.statusNode.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.2, completion: { _ in
                                    if let strongSelf = self {
                                        strongSelf.statusNode.transitionToState(.none, animated: false, completion: {})
                                    }
                                })
                            }
                    }
                }
            }))
    }
    
    override func animateIn(from node: (ASDisplayNode, () -> UIView?), addToTransitionSurface: (UIView) -> Void) {
        var transformedFrame = node.0.view.convert(node.0.view.bounds, to: self.imageNode.view)
        let transformedSuperFrame = node.0.view.convert(node.0.view.bounds, to: self.imageNode.view.superview)
        let transformedSelfFrame = node.0.view.convert(node.0.view.bounds, to: self.view)
        let transformedCopyViewFinalFrame = self.imageNode.view.convert(self.imageNode.view.bounds, to: self.view)
        
        let surfaceCopyView = node.1()!
        let copyView = node.1()!
        
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
        
        self.statusNodeContainer.layer.animatePosition(from: CGPoint(x: transformedSuperFrame.midX, y: transformedSuperFrame.midY), to: self.statusNodeContainer.position, duration: positionDuration, timingFunction: kCAMediaTimingFunctionSpring)
        self.statusNodeContainer.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.25, timingFunction: kCAMediaTimingFunctionSpring)
        self.statusNodeContainer.layer.animateScale(from: 0.5, to: 1.0, duration: 0.25, timingFunction: kCAMediaTimingFunctionSpring)
    }
    
    override func animateOut(to node: (ASDisplayNode, () -> UIView?), addToTransitionSurface: (UIView) -> Void, completion: @escaping () -> Void) {
        self.fetchDisposable.set(nil)
        
        var transformedFrame = node.0.view.convert(node.0.view.bounds, to: self.imageNode.view)
        let transformedSuperFrame = node.0.view.convert(node.0.view.bounds, to: self.imageNode.view.superview)
        let transformedSelfFrame = node.0.view.convert(node.0.view.bounds, to: self.view)
        let transformedCopyViewInitialFrame = self.imageNode.view.convert(self.imageNode.view.bounds, to: self.view)
        
        var positionCompleted = false
        var boundsCompleted = false
        var copyCompleted = false
        
        let copyView = node.1()!
        let surfaceCopyView = node.1()!
        
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
        
        copyView.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.18, removeOnCompletion: false)
        surfaceCopyView.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.1, removeOnCompletion: false)
        
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
        
        self.imageNode.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.2, removeOnCompletion: false)
        
        transformedFrame.origin = CGPoint()
        self.imageNode.layer.animateBounds(from: self.imageNode.layer.bounds, to: transformedFrame, duration: 0.25, timingFunction: kCAMediaTimingFunctionSpring, removeOnCompletion: false, completion: { _ in
            boundsCompleted = true
            intermediateCompletion()
        })
        
        self.statusNodeContainer.layer.animatePosition(from: self.statusNodeContainer.position, to: CGPoint(x: transformedSuperFrame.midX, y: transformedSuperFrame.midY), duration: 0.25, timingFunction: kCAMediaTimingFunctionSpring, removeOnCompletion: false)
        self.statusNodeContainer.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.15, timingFunction: kCAMediaTimingFunctionEaseIn, removeOnCompletion: false)
    }
    
    override func visibilityUpdated(isVisible: Bool) {
        super.visibilityUpdated(isVisible: isVisible)
        
        if let (account, media) = self.accountAndMedia, let file = media as? TelegramMediaFile {
            if isVisible {
                //self.fetchDisposable.set(account.postbox.mediaBox.fetchedResource(file.resource, tag: TelegramMediaResourceFetchTag(statsCategory: .image)).start())
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
    
    @objc func statusPressed() {
        if let (_, media) = self.accountAndMedia, let status = self.status {
            var resource: MediaResource?
            if let file = media as? TelegramMediaFile {
                resource = file.resource
            } else if let image = media as? TelegramMediaImage {
                resource = largestImageRepresentation(image.representations)?.resource
            }
            if let resource = resource {
                switch status {
                    case .Fetching:
                        self.account.postbox.mediaBox.cancelInteractiveResourceFetch(resource)
                    case .Remote:
                        self.fetchDisposable.set(self.account.postbox.mediaBox.fetchedResource(resource, tag: TelegramMediaResourceFetchTag(statsCategory: .generic)).start())
                    default:
                        break
                }
            }
        }
    }
}
