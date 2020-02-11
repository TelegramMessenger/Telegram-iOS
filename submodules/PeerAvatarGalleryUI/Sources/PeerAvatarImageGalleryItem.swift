import Foundation
import UIKit
import Display
import AsyncDisplayKit
import SwiftSignalKit
import Postbox
import TelegramCore
import SyncCore
import TelegramPresentationData
import AccountContext
import RadialStatusNode
import ShareController
import PhotoResources
import GalleryUI

private struct PeerAvatarImageGalleryThumbnailItem: GalleryThumbnailItem {
    let account: Account
    let peer: Peer
    let content: [ImageRepresentationWithReference]
    
    init(account: Account, peer: Peer, content: [ImageRepresentationWithReference]) {
        self.account = account
        self.peer = peer
        self.content = content
    }
    
    var image: (Signal<(TransformImageArguments) -> DrawingContext?, NoError>, CGSize) {
        if let representation = largestImageRepresentation(self.content.map({ $0.representation })) {
            return (avatarGalleryThumbnailPhoto(account: self.account, representations: self.content), representation.dimensions.cgSize)
        } else {
            return (.single({ _ in return nil }), CGSize(width: 128.0, height: 128.0))
        }
    }
    
    func isEqual(to: GalleryThumbnailItem) -> Bool {
        if let to = to as? PeerAvatarImageGalleryThumbnailItem {
            return self.content == to.content
        } else {
            return false
        }
    }
}

class PeerAvatarImageGalleryItem: GalleryItem {
    let context: AccountContext
    let peer: Peer
    let presentationData: PresentationData
    let entry: AvatarGalleryEntry
    let delete: (() -> Void)?
    
    init(context: AccountContext, peer: Peer, presentationData: PresentationData, entry: AvatarGalleryEntry, delete: (() -> Void)?) {
        self.context = context
        self.peer = peer
        self.presentationData = presentationData
        self.entry = entry
        self.delete = delete
    }
    
    func node() -> GalleryItemNode {
        let node = PeerAvatarImageGalleryItemNode(context: self.context, presentationData: self.presentationData, peer: self.peer)
        
        if let indexData = self.entry.indexData {
            node._title.set(.single(self.presentationData.strings.Items_NOfM("\(indexData.position + 1)", "\(indexData.totalCount)").0))
        }
        
        node.setEntry(self.entry)
        node.footerContentNode.delete = self.delete
        
        return node
    }
    
    func updateNode(node: GalleryItemNode) {
        if let node = node as? PeerAvatarImageGalleryItemNode {
            if let indexData = self.entry.indexData {
                node._title.set(.single(self.presentationData.strings.Items_NOfM("\(indexData.position + 1)", "\(indexData.totalCount)").0))
            }
            
            node.setEntry(self.entry)
            node.footerContentNode.delete = self.delete
        }
    }
    
    func thumbnailItem() -> (Int64, GalleryThumbnailItem)? {
        let content: [ImageRepresentationWithReference]
        switch self.entry {
            case let .topImage(representations, _):
                content = representations
            case let .image(_, representations, _, _, _, _):
                content = representations
        }
        
        return (0, PeerAvatarImageGalleryThumbnailItem(account: self.context.account, peer: self.peer, content: content))
    }
}

final class PeerAvatarImageGalleryItemNode: ZoomableContentGalleryItemNode {
    private let context: AccountContext
    private let peer: Peer
    
    private var entry: AvatarGalleryEntry?
    
    private let imageNode: TransformImageNode
    fileprivate let _ready = Promise<Void>()
    fileprivate let _title = Promise<String>()
    private let statusNodeContainer: HighlightableButtonNode
    private let statusNode: RadialStatusNode
    fileprivate let footerContentNode: AvatarGalleryItemFooterContentNode
    
    private let fetchDisposable = MetaDisposable()
    private let statusDisposable = MetaDisposable()
    private var status: MediaResourceStatus?
    
    init(context: AccountContext, presentationData: PresentationData, peer: Peer) {
        self.context = context
        self.peer = peer
        
        self.imageNode = TransformImageNode()
        self.footerContentNode = AvatarGalleryItemFooterContentNode(context: context, presentationData: presentationData)
        
        self.statusNodeContainer = HighlightableButtonNode()
        self.statusNode = RadialStatusNode(backgroundNodeColor: UIColor(white: 0.0, alpha: 0.5))
        self.statusNode.isHidden = true
        
        super.init()
        
        self.imageNode.imageUpdated = { [weak self] _ in
            self?._ready.set(.single(Void()))
        }
        
        self.imageNode.contentAnimations = .subsequentUpdates
        self.imageNode.view.contentMode = .scaleAspectFill
        self.imageNode.clipsToBounds = true
        
        self.statusNodeContainer.addSubnode(self.statusNode)
        self.addSubnode(self.statusNodeContainer)
        
        self.statusNodeContainer.addTarget(self, action: #selector(self.statusPressed), forControlEvents: .touchUpInside)
        self.statusNodeContainer.isUserInteractionEnabled = false
        
        self.footerContentNode.share = { [weak self] interaction in
            if let strongSelf = self, let entry = strongSelf.entry, !entry.representations.isEmpty {
                let shareController = ShareController(context: strongSelf.context, subject: .image(entry.representations), preferredAction: .saveToCameraRoll)
                interaction.presentController(shareController, nil)
            }
        }
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
    
    fileprivate func setEntry(_ entry: AvatarGalleryEntry) {
        if self.entry != entry {
            self.entry = entry
            
            self.footerContentNode.setEntry(entry)
            
            if let largestSize = largestImageRepresentation(entry.representations.map({ $0.representation })) {
                let displaySize = largestSize.dimensions.cgSize.fitted(CGSize(width: 1280.0, height: 1280.0)).dividedByScreenScale().integralFloor
                self.imageNode.asyncLayout()(TransformImageArguments(corners: ImageCorners(), imageSize: displaySize, boundingSize: displaySize, intrinsicInsets: UIEdgeInsets()))()
                let representations: [ImageRepresentationWithReference]
                switch entry {
                    case let .topImage(topRepresentations, _):
                        representations = topRepresentations
                    case let .image(_, imageRepresentations, _, _, _, _):
                        representations = imageRepresentations
                }
                self.imageNode.setSignal(chatAvatarGalleryPhoto(account: self.context.account, representations: representations), dispatchOnDisplayLink: false)
                self.zoomableContent = (largestSize.dimensions.cgSize, self.imageNode)
                if let largestIndex = representations.firstIndex(where: { $0.representation == largestSize }) {
                    self.fetchDisposable.set(fetchedMediaResource(mediaBox: self.context.account.postbox.mediaBox, reference: representations[largestIndex].reference).start())
                }
                
                self.statusDisposable.set((self.context.account.postbox.mediaBox.resourceStatus(largestSize.resource)
                |> deliverOnMainQueue).start(next: { [weak self] status in
                    if let strongSelf = self {
                        let previousStatus = strongSelf.status
                        strongSelf.status = status
                        switch status {
                            case .Remote:
                                strongSelf.statusNode.isHidden = false
                                strongSelf.statusNodeContainer.isUserInteractionEnabled = true
                                strongSelf.statusNode.transitionToState(.download(.white), completion: {})
                            case let .Fetching(_, progress):
                                strongSelf.statusNode.isHidden = false
                                strongSelf.statusNodeContainer.isUserInteractionEnabled = true
                                let adjustedProgress = max(progress, 0.027)
                                strongSelf.statusNode.transitionToState(.progress(color: .white, lineWidth: nil, value: CGFloat(adjustedProgress), cancelEnabled: true), completion: {})
                            case .Local:
                                if let previousStatus = previousStatus, case .Fetching = previousStatus {
                                    strongSelf.statusNode.transitionToState(.progress(color: .white, lineWidth: nil, value: 1.0, cancelEnabled: true), completion: {
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
            } else {
                self._ready.set(.single(Void()))
            }
        }
    }
    
    override func animateIn(from node: (ASDisplayNode, CGRect, () -> (UIView?, UIView?)), addToTransitionSurface: (UIView) -> Void) {
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
        self.imageNode.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.07)
        
        transformedFrame.origin = CGPoint()
        //self.imageNode.layer.animateBounds(from: transformedFrame, to: self.imageNode.layer.bounds, duration: 0.25, timingFunction: kCAMediaTimingFunctionSpring)
        
        let transform = CATransform3DScale(self.imageNode.layer.transform, transformedFrame.size.width / self.imageNode.layer.bounds.size.width, transformedFrame.size.height / self.imageNode.layer.bounds.size.height, 1.0)
        self.imageNode.layer.animate(from: NSValue(caTransform3D: transform), to: NSValue(caTransform3D: self.imageNode.layer.transform), keyPath: "transform", timingFunction: kCAMediaTimingFunctionSpring, duration: 0.25)
        
        self.imageNode.clipsToBounds = true
        self.imageNode.layer.animate(from: (self.imageNode.frame.width / 2.0) as NSNumber, to: 0.0 as NSNumber, keyPath: "cornerRadius", timingFunction: CAMediaTimingFunctionName.default.rawValue, duration: 0.18, removeOnCompletion: false, completion: { [weak self] value in
            if value {
                self?.imageNode.clipsToBounds = false
            }
        })
        
        self.statusNodeContainer.layer.animatePosition(from: CGPoint(x: transformedSuperFrame.midX, y: transformedSuperFrame.midY), to: self.statusNodeContainer.position, duration: 0.25, timingFunction: kCAMediaTimingFunctionSpring)
        self.statusNodeContainer.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.25, timingFunction: kCAMediaTimingFunctionSpring)
        self.statusNodeContainer.layer.animateScale(from: 0.5, to: 1.0, duration: 0.25, timingFunction: kCAMediaTimingFunctionSpring)
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
        
        let transform = CATransform3DScale(self.imageNode.layer.transform, transformedFrame.size.width / self.imageNode.layer.bounds.size.width, transformedFrame.size.height / self.imageNode.layer.bounds.size.height, 1.0)
        self.imageNode.layer.animate(from: NSValue(caTransform3D: self.imageNode.layer.transform), to: NSValue(caTransform3D: transform), keyPath: "transform", timingFunction: kCAMediaTimingFunctionSpring, duration: 0.25 * durationFactor, removeOnCompletion: false, completion: { _ in
            boundsCompleted = true
            intermediateCompletion()
        })
        
        self.imageNode.clipsToBounds = true
        self.imageNode.layer.animate(from: 0.0 as NSNumber, to: (self.imageNode.frame.width / 2.0) as NSNumber, keyPath: "cornerRadius", timingFunction: CAMediaTimingFunctionName.default.rawValue, duration: 0.18 * durationFactor, removeOnCompletion: false)
        
        self.statusNodeContainer.layer.animatePosition(from: self.statusNodeContainer.position, to: CGPoint(x: transformedSuperFrame.midX, y: transformedSuperFrame.midY), duration: 0.25, timingFunction: kCAMediaTimingFunctionSpring, removeOnCompletion: false)
        self.statusNodeContainer.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.15, timingFunction: CAMediaTimingFunctionName.easeIn.rawValue, removeOnCompletion: false)
    }
    
    override func visibilityUpdated(isVisible: Bool) {
        super.visibilityUpdated(isVisible: isVisible)
    }
    
    override func title() -> Signal<String, NoError> {
        return self._title.get()
    }
    
    @objc func statusPressed() {
        if let entry = self.entry, let largestSize = largestImageRepresentation(entry.representations.map({ $0.representation })), let status = self.status {
            switch status {
                case .Fetching:
                    self.context.account.postbox.mediaBox.cancelInteractiveResourceFetch(largestSize.resource)
                case .Remote:
                    let representations: [ImageRepresentationWithReference]
                    switch entry {
                        case let .topImage(topRepresentations, _):
                            representations = topRepresentations
                        case let .image(_, imageRepresentations, _, _, _, _):
                            representations = imageRepresentations
                    }
                    
                    if let largestIndex = representations.firstIndex(where: { $0.representation == largestSize }) {
                        self.fetchDisposable.set(fetchedMediaResource(mediaBox: self.context.account.postbox.mediaBox, reference: representations[largestIndex].reference).start())
                    }
                default:
                    break
            }
        }
    }
    
    override func footerContent() -> Signal<(GalleryFooterContentNode?, GalleryOverlayContentNode?), NoError> {
        return .single((self.footerContentNode, nil))
    }
}
