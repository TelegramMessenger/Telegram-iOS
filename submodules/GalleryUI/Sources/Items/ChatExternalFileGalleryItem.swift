import Foundation
import UIKit
import AsyncDisplayKit
import Postbox
import Display
import SwiftSignalKit
import WebKit
import TelegramCore
import TelegramPresentationData
import AccountContext
import RadialStatusNode
import ShareController

class ChatExternalFileGalleryItem: GalleryItem {
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
        let node = ChatExternalFileGalleryItemNode(context: self.context, presentationData: self.presentationData)
        
        for media in self.message.media {
            if let file = media as? TelegramMediaFile {
                node.setFile(context: context, fileReference: .message(message: MessageReference(self.message), media: file))
                break
            } else if let webpage = media as? TelegramMediaWebpage, case let .Loaded(content) = webpage.content {
                if let file = content.file {
                    node.setFile(context: context, fileReference: .message(message: MessageReference(self.message), media: file))
                    break
                }
            }
        }
        
        if let location = self.location {
            node._title.set(.single(self.presentationData.strings.Items_NOfM("\(location.index + 1)", "\(location.count)").string))
        }
        node.setMessage(self.message)
        
        return node
    }
    
    func updateNode(node: GalleryItemNode, synchronous: Bool) {
        if let node = node as? ChatExternalFileGalleryItemNode, let location = self.location {
            node._title.set(.single(self.presentationData.strings.Items_NOfM("\(location.index + 1)", "\(location.count)").string))
            node.setMessage(self.message)
        }
    }
    
    func thumbnailItem() -> (Int64, GalleryThumbnailItem)? {
        return nil
    }
}

class ChatExternalFileGalleryItemNode: GalleryItemNode {
    fileprivate let _title = Promise<String>()
    
    private let statusNodeContainer: HighlightableButtonNode
    private let statusNode: RadialStatusNode
    
    private let containerNode: ASDisplayNode
    private let fileNameNode: ImmediateTextNode
    private let actionTitleNode: ImmediateTextNode
    private let actionButtonNode: HighlightableButtonNode
    
    private var contextAndFile: (AccountContext, FileMediaReference)?
    private let dataDisposable = MetaDisposable()
    
    private var itemIsVisible = false
    
    private var message: Message?
    
    private let footerContentNode: ChatItemGalleryFooterContentNode
    
    private var fetchDisposable = MetaDisposable()
    private let statusDisposable = MetaDisposable()
    private var status: MediaResourceStatus?
    
    init(context: AccountContext, presentationData: PresentationData) {
        self.containerNode = ASDisplayNode()
        self.containerNode.backgroundColor = .white
        
        self.fileNameNode = ImmediateTextNode()
        self.containerNode.addSubnode(self.fileNameNode)
        
        self.actionTitleNode = ImmediateTextNode()
        self.actionTitleNode.attributedText = NSAttributedString(string: presentationData.strings.Conversation_LinkDialogOpen, font: Font.regular(17.0), textColor: presentationData.theme.list.itemAccentColor)
        self.containerNode.addSubnode(self.actionTitleNode)
        
        self.actionButtonNode = HighlightableButtonNode()
        self.containerNode.addSubnode(self.actionButtonNode)
        
        self.footerContentNode = ChatItemGalleryFooterContentNode(context: context, presentationData: presentationData)
        
        self.statusNodeContainer = HighlightableButtonNode()
        self.statusNode = RadialStatusNode(backgroundNodeColor: UIColor(white: 0.0, alpha: 0.5))
        self.statusNode.isHidden = true
        
        super.init()
        
        self.addSubnode(self.containerNode)
        
        self.statusNodeContainer.addSubnode(self.statusNode)
        self.addSubnode(self.statusNodeContainer)
        
        self.statusNodeContainer.addTarget(self, action: #selector(self.statusPressed), forControlEvents: .touchUpInside)
        
        self.statusNodeContainer.isUserInteractionEnabled = false
        
        self.actionButtonNode.addTarget(self, action: #selector(self.actionButtonPressed), forControlEvents: .touchUpInside)
        self.actionButtonNode.highligthedChanged = { [weak self] highlighted in
            if let strongSelf = self {
                if highlighted {
                    strongSelf.actionTitleNode.layer.removeAnimation(forKey: "opacity")
                    strongSelf.actionTitleNode.alpha = 0.4
                } else {
                    strongSelf.actionTitleNode.alpha = 1.0
                    strongSelf.actionTitleNode.layer.animateAlpha(from: 0.4, to: 1.0, duration: 0.2)
                }
            }
        }
    }
    
    deinit {
        self.dataDisposable.dispose()
        self.fetchDisposable.dispose()
        self.statusDisposable.dispose()
    }
    
    override func containerLayoutUpdated(_ layout: ContainerViewLayout, navigationBarHeight: CGFloat, transition: ContainedViewLayoutTransition) {
        super.containerLayoutUpdated(layout, navigationBarHeight: navigationBarHeight, transition: transition)
        
        let containerFrame = CGRect(origin: CGPoint(x: 0.0, y: navigationBarHeight), size: CGSize(width: layout.size.width, height: layout.size.height - navigationBarHeight - 44.0 - layout.insets(options: []).bottom))
        self.containerNode.frame = containerFrame
        
        let fileNameSize = self.fileNameNode.updateLayout(containerFrame.insetBy(dx: 10.0, dy: 0.0).size)
        let actionTitleSize = self.actionTitleNode.updateLayout(containerFrame.insetBy(dx: 10.0, dy: 0.0).size)
        
        let spacing: CGFloat = 4.0
        
        let contentHeight: CGFloat = fileNameSize.height + spacing + actionTitleSize.height
        
        let contentOrigin = floor((containerFrame.size.height - contentHeight) / 2.0)
        
        let fileNameFrame = CGRect(origin: CGPoint(x: floor((containerFrame.width - fileNameSize.width) / 2.0), y: contentOrigin), size: fileNameSize)
        transition.updateFrame(node: self.fileNameNode, frame: fileNameFrame)
        
        let actionTitleFrame = CGRect(origin: CGPoint(x: floor((containerFrame.width - actionTitleSize.width) / 2.0), y: fileNameFrame.maxY + spacing), size: actionTitleSize)
        transition.updateFrame(node: self.actionTitleNode, frame: actionTitleFrame)
        transition.updateFrame(node: self.actionButtonNode, frame: actionTitleFrame.insetBy(dx: -8.0, dy: -8.0))
        
        let statusSize = CGSize(width: 50.0, height: 50.0)
        transition.updateFrame(node: self.statusNodeContainer, frame: CGRect(origin: CGPoint(x: floor((layout.size.width - statusSize.width) / 2.0), y: floor((layout.size.height - statusSize.height) / 2.0)), size: statusSize))
        transition.updateFrame(node: self.statusNode, frame: CGRect(origin: CGPoint(), size: statusSize))
    }
    
    fileprivate func setMessage(_ message: Message) {
        self.message = message
        self.footerContentNode.setMessage(message)
    }
    
    override func navigationStyle() -> Signal<GalleryItemNodeNavigationStyle, NoError> {
        return .single(.dark)
    }
    
    func setFile(context: AccountContext, fileReference: FileMediaReference) {
        let updateFile = self.contextAndFile?.1.media != fileReference.media
        self.contextAndFile = (context, fileReference)
        if updateFile {
            self.fileNameNode.attributedText = NSAttributedString(string: fileReference.media.fileName ?? " ", font: Font.regular(17.0), textColor: .black)
            self.setupStatus(context: context, resource: fileReference.media.resource)
        }
    }
    
    private func setupStatus(context: AccountContext, resource: MediaResource) {
        self.statusDisposable.set((context.account.postbox.mediaBox.resourceStatus(resource)
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
    
    override func visibilityUpdated(isVisible: Bool) {
        super.visibilityUpdated(isVisible: isVisible)
        
        if self.itemIsVisible != isVisible {
            self.itemIsVisible = isVisible
            
            if isVisible {
            } else {
                self.fetchDisposable.set(nil)
            }
        }
    }
    
    override func title() -> Signal<String, NoError> {
        return self._title.get()
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
    
    override func footerContent() -> Signal<(GalleryFooterContentNode?, GalleryOverlayContentNode?), NoError> {
        return .single((self.footerContentNode, nil))
    }
    
    @objc func statusPressed() {
        if let (context, fileReference) = self.contextAndFile, let status = self.status {
            switch status {
                case .Fetching:
                    context.account.postbox.mediaBox.cancelInteractiveResourceFetch(fileReference.media.resource)
                case .Remote:
                    self.fetchDisposable.set(fetchedMediaResource(mediaBox: context.account.postbox.mediaBox, reference: fileReference.resourceReference(fileReference.media.resource)).start())
            default:
                break
            }
        }
    }
    
    @objc func actionButtonPressed() {
        if let (context, _) = self.contextAndFile, let message = self.message, let status = self.status, case .Local = status {
            let baseNavigationController = self.baseNavigationController()
            (baseNavigationController?.topViewController as? ViewController)?.present(ShareController(context: context, subject: .messages([message]), showInChat: nil, externalShare: true, immediateExternalShare: true), in: .window(.root))
        }
    }
}
