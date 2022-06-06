import Foundation
import UIKit
import Display
import AsyncDisplayKit
import SwiftSignalKit
import Postbox
import TelegramCore
import Lottie
import TelegramPresentationData
import AnimationUI
import AccountContext
import RadialStatusNode
import StickerResources
import AppBundle

class ChatAnimationGalleryItem: GalleryItem {
    var id: AnyHashable {
        return self.message.stableId
    }
    
    let context: AccountContext
    let presentationData: PresentationData
    let message: Message
    let location: MessageHistoryEntryLocation?
    
    init(context: AccountContext, presentationData: PresentationData, message: Message, location: MessageHistoryEntryLocation?) {
        self.context = context
        self.presentationData = presentationData
        self.message = message
        self.location = location
    }
    
    func node(synchronous: Bool) -> GalleryItemNode {
        let node = ChatAnimationGalleryItemNode(context: self.context, presentationData: self.presentationData)

        for media in self.message.media {
            if let file = media as? TelegramMediaFile {
                node.setFile(context: self.context, fileReference: .message(message: MessageReference(self.message), media: file))
                break
            }
        }
        
        node.setMessage(self.message)
        
        return node
    }
    
    func updateNode(node: GalleryItemNode, synchronous: Bool) {
        if let node = node as? ChatAnimationGalleryItemNode {
            node.setMessage(self.message)
        }
    }
    
    func thumbnailItem() -> (Int64, GalleryThumbnailItem)? {
        return nil
    }
}

private var backgroundButtonIcon: UIImage = {
    return generateImage(CGSize(width: 20.0, height: 20.0), rotatedContext: { size, context in
        let bounds = CGRect(origin: CGPoint(), size: size)
        context.clear(bounds)
        
        context.setLineWidth(1.0)
        context.setStrokeColor(UIColor.white.cgColor)
        context.setFillColor(UIColor.white.cgColor)
        context.strokeEllipse(in: bounds.insetBy(dx: 0.5, dy: 0.5))
        
        context.addEllipse(in: bounds.insetBy(dx: 0.5, dy: 0.5))
        context.clip()
        
        context.fill(CGRect(x: 0.0, y: 0.0, width: 10.0, height: 20.0))
    })!
}()

final class ChatAnimationGalleryItemNode: ZoomableContentGalleryItemNode {
    private let context: AccountContext
    private var presentationData: PresentationData
    private var message: Message?
    
    fileprivate let _title = Promise<String>()
    fileprivate let _rightBarButtonItems = Promise<[UIBarButtonItem]?>()
    
    private let containerNode: ASDisplayNode
    private let animationNode: AnimationNode
    
    private let statusNodeContainer: HighlightableButtonNode
    private let statusNode: RadialStatusNode
    private let footerContentNode: ChatItemGalleryFooterContentNode
    
    private var contextAndMedia: (AccountContext, AnyMediaReference)?
    
    private var disposable = MetaDisposable()
    private var fetchDisposable = MetaDisposable()
    private let statusDisposable = MetaDisposable()
    private var status: MediaResourceStatus?
    
    init(context: AccountContext, presentationData: PresentationData) {
        self.context = context
        self.presentationData = presentationData
        
        self.containerNode = ASDisplayNode()
        self.containerNode.backgroundColor = .black
        
        self.animationNode = AnimationNode()
        self.containerNode.addSubnode(self.animationNode)
       
        self.footerContentNode = ChatItemGalleryFooterContentNode(context: context, presentationData: presentationData)
        
        self.statusNodeContainer = HighlightableButtonNode()
        self.statusNode = RadialStatusNode(backgroundNodeColor: UIColor(white: 0.0, alpha: 0.5))
        self.statusNode.frame = CGRect(origin: CGPoint(), size: CGSize(width: 50.0, height: 50.0))
        self.statusNode.isHidden = true
        
        super.init()
        
        self.statusNodeContainer.addSubnode(self.statusNode)
        self.addSubnode(self.statusNodeContainer)
        
        self.statusNodeContainer.addTarget(self, action: #selector(self.statusPressed), forControlEvents: .touchUpInside)
        
        self.statusNodeContainer.isUserInteractionEnabled = false
    }
    
    deinit {
        self.disposable.dispose()
        self.fetchDisposable.dispose()
        self.statusDisposable.dispose()
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
    
    func setFile(context: AccountContext, fileReference: FileMediaReference) {
        if self.contextAndMedia == nil || !self.contextAndMedia!.1.media.isEqual(to: fileReference.media) {
            let signal = chatMessageAnimatedStickerBackingData(postbox: context.account.postbox, fileReference: fileReference, synchronousLoad: false)
            |> mapToSignal { value -> Signal<Data, NoError> in
                if value._1, let data = value._0 {
                    return .single(data)
                } else {
                    return .complete()
                }
            }
            self.disposable.set((signal |> deliverOnMainQueue).start(next: { [weak self] next in
                guard let strongSelf = self else {
                    return
                }
                if let json = try? JSONSerialization.jsonObject(with: next, options: []) as? [String: Any] {
                    let containerSize = CGSize(width: 640.0, height: 640.0)
                    strongSelf.animationNode.setAnimation(json: json)
                    strongSelf.zoomableContent = (containerSize, strongSelf.containerNode)
                    
                    if let animationSize = strongSelf.animationNode.preferredSize() {
                        let size = animationSize.fitted(containerSize)
                        strongSelf.animationNode.frame = CGRect(origin: CGPoint(x: floor((containerSize.width - size.width) / 2.0), y: floor((containerSize.height - size.height) / 2.0)), size: size)
                    }
                    
                    strongSelf.animationNode.loop()
                }
            }))
            self.setupStatus(resource: fileReference.media.resource)
            
            
            self._title.set(.single("\(fileReference.media.fileName ?? "") - \(dataSizeString(fileReference.media.size ?? 0, forceDecimal: false, formatting: DataSizeStringFormatting(presentationData: self.presentationData)))"))
            
            let speedItem = UIBarButtonItem(image: UIImage(bundleImageName: "Media Gallery/SlowDown"), style: .plain, target: self, action: #selector(self.toggleSpeedButtonPressed))
            let backgroundItem = UIBarButtonItem(image: backgroundButtonIcon, style: .plain, target: self, action: #selector(self.toggleBackgroundButtonPressed))
            self._rightBarButtonItems.set(.single([speedItem, backgroundItem]))
        }
        self.contextAndMedia = (context, fileReference.abstract)
    }
    
    @objc private func toggleSpeedButtonPressed() {
        if self.animationNode.speed == 1.0 {
            self.animationNode.speed = 0.1
        } else {
            self.animationNode.speed = 1.0
        }
    }
    
    @objc private func toggleBackgroundButtonPressed() {
        let transition = ContainedViewLayoutTransition.animated(duration: 0.2, curve: .easeInOut)
        if self.containerNode.backgroundColor == .white {
            transition.updateBackgroundColor(node: self.containerNode, color: .black)
        } else {
            transition.updateBackgroundColor(node: self.containerNode, color: .white)
        }
    }
    
    private func setupStatus(resource: MediaResource) {
        self.statusDisposable.set((self.context.account.postbox.mediaBox.resourceStatus(resource)
        |> deliverOnMainQueue).start(next: { [weak self] status in
            if let strongSelf = self {
                let previousStatus = strongSelf.status
                strongSelf.status = status
                switch status {
                    case .Remote, .Paused:
                        strongSelf.statusNode.isHidden = false
                        strongSelf.statusNode.alpha = 1.0
                        strongSelf.statusNodeContainer.isUserInteractionEnabled = true
                        strongSelf.statusNode.transitionToState(.download(.white), completion: {})
                    case let .Fetching(_, progress):
                        strongSelf.statusNode.isHidden = false
                        strongSelf.statusNode.alpha = 1.0
                        strongSelf.statusNodeContainer.isUserInteractionEnabled = true
                        let adjustedProgress = max(progress, 0.027)
                        strongSelf.statusNode.transitionToState(.progress(color: .white, lineWidth: nil, value: CGFloat(adjustedProgress), cancelEnabled: true, animateRotation: true), completion: {})
                    case .Local:
                        if let previousStatus = previousStatus, case .Fetching = previousStatus {
                            strongSelf.statusNode.transitionToState(.progress(color: .white, lineWidth: nil, value: 1.0, cancelEnabled: true, animateRotation: true), completion: {
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
    
    override func animateIn(from node: (ASDisplayNode, CGRect, () -> (UIView?, UIView?)), addToTransitionSurface: (UIView) -> Void, completion: @escaping () -> Void) {
        var transformedFrame = node.0.view.convert(node.0.view.bounds, to: self.containerNode.view)
        let transformedSuperFrame = node.0.view.convert(node.0.view.bounds, to: self.containerNode.view.superview)
        
        self.containerNode.layer.animatePosition(from: CGPoint(x: transformedSuperFrame.midX, y: transformedSuperFrame.midY), to: self.containerNode.layer.position, duration: 0.25, timingFunction: kCAMediaTimingFunctionSpring)
        
        transformedFrame.origin = CGPoint()
        
        let transform = CATransform3DScale(self.containerNode.layer.transform, transformedFrame.size.width / self.containerNode.layer.bounds.size.width, transformedFrame.size.height / self.containerNode.layer.bounds.size.height, 1.0)
        self.containerNode.layer.animate(from: NSValue(caTransform3D: transform), to: NSValue(caTransform3D: self.containerNode.layer.transform), keyPath: "transform", timingFunction: kCAMediaTimingFunctionSpring, duration: 0.25)
        
        self.statusNodeContainer.layer.animatePosition(from: CGPoint(x: transformedSuperFrame.midX, y: transformedSuperFrame.midY), to: self.statusNodeContainer.position, duration: 0.25, timingFunction: kCAMediaTimingFunctionSpring)
        self.statusNodeContainer.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.25, timingFunction: kCAMediaTimingFunctionSpring)
        self.statusNodeContainer.layer.animateScale(from: 0.5, to: 1.0, duration: 0.25, timingFunction: kCAMediaTimingFunctionSpring)
    }
    
    override func animateOut(to node: (ASDisplayNode, CGRect, () -> (UIView?, UIView?)), addToTransitionSurface: (UIView) -> Void, completion: @escaping () -> Void) {
        var transformedFrame = node.0.view.convert(node.0.view.bounds, to: self.containerNode.view)
        let transformedSuperFrame = node.0.view.convert(node.0.view.bounds, to: self.containerNode.view.superview)
        let transformedSelfFrame = node.0.view.convert(node.0.view.bounds, to: self.view)
        let transformedCopyViewInitialFrame = self.containerNode.view.convert(self.containerNode.view.bounds, to: self.view)
        
        var positionCompleted = false
        var boundsCompleted = false
        var copyCompleted = false
        
        let (maybeCopyView, copyViewBackgrond) = node.2()
        copyViewBackgrond?.alpha = 0.0
        let copyView = maybeCopyView!
        
        self.view.insertSubview(copyView, belowSubview: self.containerNode.view)
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
        
        self.containerNode.layer.animatePosition(from: self.containerNode.layer.position, to: CGPoint(x: transformedSuperFrame.midX, y: transformedSuperFrame.midY), duration: 0.25, timingFunction: kCAMediaTimingFunctionSpring, removeOnCompletion: false, completion: { _ in
            positionCompleted = true
            intermediateCompletion()
        })
        
        self.containerNode.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.25, removeOnCompletion: false)
        
        transformedFrame.origin = CGPoint()
        
        let transform = CATransform3DScale(self.containerNode.layer.transform, transformedFrame.size.width / self.containerNode.layer.bounds.size.width, transformedFrame.size.height / self.containerNode.layer.bounds.size.height, 1.0)
        self.containerNode.layer.animate(from: NSValue(caTransform3D: self.containerNode.layer.transform), to: NSValue(caTransform3D: transform), keyPath: "transform", timingFunction: kCAMediaTimingFunctionSpring, duration: 0.25, removeOnCompletion: false, completion: { _ in
            boundsCompleted = true
            intermediateCompletion()
        })
        
        self.statusNodeContainer.layer.animatePosition(from: self.statusNodeContainer.position, to: CGPoint(x: transformedSuperFrame.midX, y: transformedSuperFrame.midY), duration: 0.25, timingFunction: kCAMediaTimingFunctionSpring, removeOnCompletion: false)
        self.statusNodeContainer.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.15, timingFunction: CAMediaTimingFunctionName.easeIn.rawValue, removeOnCompletion: false)
    }
    
    override func visibilityUpdated(isVisible: Bool) {
        super.visibilityUpdated(isVisible: isVisible)
        
        if let (_, mediaReference) = self.contextAndMedia, let _ = mediaReference.concrete(TelegramMediaFile.self) {
            if isVisible {
            } else {
                self.fetchDisposable.set(nil)
            }
        }
    }
    
    override func title() -> Signal<String, NoError> {
        return self._title.get()
    }
    
    override func rightBarButtonItems() -> Signal<[UIBarButtonItem]?, NoError> {
        return self._rightBarButtonItems.get()
    }
    
    override func footerContent() -> Signal<(GalleryFooterContentNode?, GalleryOverlayContentNode?), NoError> {
        return .single((self.footerContentNode, nil))
    }
    
    @objc func statusPressed() {
        if let (_, mediaReference) = self.contextAndMedia, let status = self.status {
            var resource: MediaResourceReference?
            var statsCategory: MediaResourceStatsCategory?
            if let fileReference = mediaReference.concrete(TelegramMediaFile.self) {
                resource = fileReference.resourceReference(fileReference.media.resource)
                statsCategory = statsCategoryForFileWithAttributes(fileReference.media.attributes)
            }
            if let resource = resource {
                switch status {
                    case .Fetching:
                        self.context.account.postbox.mediaBox.cancelInteractiveResourceFetch(resource.resource)
                    case .Remote:
                        self.fetchDisposable.set(fetchedMediaResource(mediaBox: self.context.account.postbox.mediaBox, reference: resource, statsCategory: statsCategory ?? .generic).start())
                    default:
                        break
                }
            }
        }
    }
}
