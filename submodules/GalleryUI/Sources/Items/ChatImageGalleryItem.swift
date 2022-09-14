import Foundation
import UIKit
import Display
import AsyncDisplayKit
import SwiftSignalKit
import Postbox
import TelegramCore
import TelegramPresentationData
import AccountContext
import RadialStatusNode
import PhotoResources
import AppBundle
import StickerPackPreviewUI
import OverlayStatusController
import PresentationDataUtils
import ImageContentAnalysis
import TextSelectionNode
import Speak
import TranslateUI
import ShareController
import UndoUI

enum ChatMediaGalleryThumbnail: Equatable {
    case image(ImageMediaReference)
    case video(FileMediaReference)
    case file(FileMediaReference)
    
    static func ==(lhs: ChatMediaGalleryThumbnail, rhs: ChatMediaGalleryThumbnail) -> Bool {
        switch lhs {
            case let .image(lhsImage):
                if case let .image(rhsImage) = rhs, lhsImage.media.isEqual(to: rhsImage.media) {
                    return true
                } else {
                    return false
                }
            case let .video(lhsVideo):
                if case let .video(rhsVideo) = rhs, lhsVideo.media.isEqual(to: rhsVideo.media) {
                    return true
                } else {
                    return false
                }
            case let .file(lhsFile):
                if case let .file(rhsFile) = rhs, lhsFile.media.isEqual(to: rhsFile.media) {
                    return true
                } else {
                    return false
                }
        }
    }
}

final class ChatMediaGalleryThumbnailItem: GalleryThumbnailItem {
    private let account: Account
    private let thumbnail: ChatMediaGalleryThumbnail
    
    init?(account: Account, mediaReference: AnyMediaReference) {
        self.account = account
        if let imageReference = mediaReference.concrete(TelegramMediaImage.self) {
            self.thumbnail = .image(imageReference)
        } else if let fileReference = mediaReference.concrete(TelegramMediaFile.self) {
            if fileReference.media.isVideo {
                self.thumbnail = .video(fileReference)
            } else {
                self.thumbnail = .file(fileReference)
            }
        } else {
            return nil
        }
    }
    
    func isEqual(to: GalleryThumbnailItem) -> Bool {
        if let to = to as? ChatMediaGalleryThumbnailItem {
            return self.thumbnail == to.thumbnail
        } else {
            return false
        }
    }
    
    func image(synchronous: Bool) -> (Signal<(TransformImageArguments) -> DrawingContext?, NoError>, CGSize) {
        switch self.thumbnail {
            case let .image(imageReference):
                if let representation = largestImageRepresentation(imageReference.media.representations) {
                    return (mediaGridMessagePhoto(account: self.account, photoReference: imageReference), representation.dimensions.cgSize)
                } else {
                    return (.single({ _ in return nil }), CGSize(width: 128.0, height: 128.0))
                }
            case let .video(fileReference):
                if let representation = largestImageRepresentation(fileReference.media.previewRepresentations) {
                    return (mediaGridMessageVideo(postbox: self.account.postbox, videoReference: fileReference), representation.dimensions.cgSize)
                } else {
                    return (.single({ _ in return nil }), CGSize(width: 128.0, height: 128.0))
                }
            case let .file(fileReference):
                if let representation = smallestImageRepresentation(fileReference.media.previewRepresentations) {
                    return (chatWebpageSnippetFile(account: self.account, mediaReference: fileReference.abstract, representation: representation), representation.dimensions.cgSize)
                } else {
                    return (.single({ _ in return nil }), CGSize(width: 128.0, height: 128.0))
                }
        }
    }
}

class ChatImageGalleryItem: GalleryItem {
    var id: AnyHashable {
        return self.message.stableId
    }
    
    let context: AccountContext
    let presentationData: PresentationData
    let message: Message
    let location: MessageHistoryEntryLocation?
    let displayInfoOnTop: Bool
    let performAction: (GalleryControllerInteractionTapAction) -> Void
    let openActionOptions: (GalleryControllerInteractionTapAction, Message) -> Void
    let present: (ViewController, Any?) -> Void
    
    init(context: AccountContext, presentationData: PresentationData, message: Message, location: MessageHistoryEntryLocation?, displayInfoOnTop: Bool, performAction: @escaping (GalleryControllerInteractionTapAction) -> Void, openActionOptions: @escaping (GalleryControllerInteractionTapAction, Message) -> Void, present: @escaping (ViewController, Any?) -> Void) {
        self.context = context
        self.presentationData = presentationData
        self.message = message
        self.location = location
        self.displayInfoOnTop = displayInfoOnTop
        self.performAction = performAction
        self.openActionOptions = openActionOptions
        self.present = present
    }
    
    func node(synchronous: Bool) -> GalleryItemNode {
        let node = ChatImageGalleryItemNode(context: self.context, presentationData: self.presentationData, performAction: self.performAction, openActionOptions: self.openActionOptions, present: self.present)
        
        node.setMessage(self.message, displayInfo: !self.displayInfoOnTop)
        for media in self.message.media {
            if let invoice = media as? TelegramMediaInvoice, let extendedMedia = invoice.extendedMedia, case let .full(fullMedia) = extendedMedia, let image = fullMedia as? TelegramMediaImage {
                node.setImage(imageReference: .message(message: MessageReference(self.message), media: image))
            } else if let image = media as? TelegramMediaImage {
                node.setImage(imageReference: .message(message: MessageReference(self.message), media: image))
                break
            } else if let file = media as? TelegramMediaFile, file.mimeType.hasPrefix("image/") {
                node.setFile(context: self.context, fileReference: .message(message: MessageReference(self.message), media: file))
                break
            } else if let webpage = media as? TelegramMediaWebpage, case let .Loaded(content) = webpage.content {
                if let image = content.image {
                    node.setImage(imageReference: .message(message: MessageReference(self.message), media: image))
                    break
                } else if let file = content.file, file.mimeType.hasPrefix("image/") {
                    node.setFile(context: self.context, fileReference: .message(message: MessageReference(self.message), media: file))
                    break
                }
            }
        }
        
        if let location = self.location {
            node._title.set(.single(self.presentationData.strings.Items_NOfM("\(location.index + 1)", "\(location.count)").string))
        }
                
        if self.displayInfoOnTop {
            node.titleContentView?.setMessage(self.message, presentationData: self.presentationData, accountPeerId: self.context.account.peerId)
        }
        
        return node
    }
    
    func updateNode(node: GalleryItemNode, synchronous: Bool) {
        if let node = node as? ChatImageGalleryItemNode, let location = self.location {
            node._title.set(.single(self.presentationData.strings.Items_NOfM("\(location.index + 1)", "\(location.count)").string))
        
            if self.displayInfoOnTop {
                node.titleContentView?.setMessage(self.message, presentationData: self.presentationData, accountPeerId: self.context.account.peerId)
            }
            node.setMessage(self.message, displayInfo: !self.displayInfoOnTop)
        }
    }
    
    func thumbnailItem() -> (Int64, GalleryThumbnailItem)? {
        if let id = self.message.groupInfo?.stableId {
            var mediaReference: AnyMediaReference?
            for m in self.message.media {
                if let m = m as? TelegramMediaImage {
                    mediaReference = .message(message: MessageReference(self.message), media: m)
                } else if let m = m as? TelegramMediaFile {
                    mediaReference = .message(message: MessageReference(self.message), media: m)
                }
            }
            if let mediaReference = mediaReference {
                if let item = ChatMediaGalleryThumbnailItem(account: self.context.account, mediaReference: mediaReference) {
                    return (Int64(id), item)
                }
            }
        }
        return nil
    }
}

final class ChatImageGalleryItemNode: ZoomableContentGalleryItemNode {
    private let context: AccountContext
    private var message: Message?
    private let presentationData: PresentationData
    
    private let imageNode: TransformImageNode
    private var recognizedContentNode: RecognizedContentContainer?
    
    private let recognitionOverlayContentNode: ImageRecognitionOverlayContentNode
    
    private var tilingNode: TilingNode?
    fileprivate let _ready = Promise<Void>()
    fileprivate let _title = Promise<String>()
    fileprivate let _titleView = Promise<UIView?>()
    fileprivate let _rightBarButtonItems = Promise<[UIBarButtonItem]?>(nil)
    private let statusNodeContainer: HighlightableButtonNode
    private let statusNode: RadialStatusNode
    private let footerContentNode: ChatItemGalleryFooterContentNode
    fileprivate var titleContentView: GalleryTitleView?
    
    private var contextAndMedia: (AccountContext, AnyMediaReference)?
    
    private var fetchDisposable = MetaDisposable()
    private let statusDisposable = MetaDisposable()
    private let dataDisposable = MetaDisposable()
    private let recognitionDisposable = MetaDisposable()
    private var status: MediaResourceStatus?
    
    private let pagingEnabledPromise = ValuePromise<Bool>(true)
    
    init(context: AccountContext, presentationData: PresentationData, performAction: @escaping (GalleryControllerInteractionTapAction) -> Void, openActionOptions: @escaping (GalleryControllerInteractionTapAction, Message) -> Void, present: @escaping (ViewController, Any?) -> Void) {
        self.context = context
        self.presentationData = presentationData
        
        self.imageNode = TransformImageNode()
        self.imageNode.contentAnimations = .subsequentUpdates
        self.footerContentNode = ChatItemGalleryFooterContentNode(context: context, presentationData: presentationData, present: present)
        self.footerContentNode.performAction = performAction
        self.footerContentNode.openActionOptions = openActionOptions
        
        self.recognitionOverlayContentNode = ImageRecognitionOverlayContentNode(theme: presentationData.theme)
        
        self.statusNodeContainer = HighlightableButtonNode()
        self.statusNode = RadialStatusNode(backgroundNodeColor: UIColor(white: 0.0, alpha: 0.5))
        self.statusNode.frame = CGRect(origin: CGPoint(), size: CGSize(width: 50.0, height: 50.0))
        self.statusNode.isHidden = true
        
        super.init()
        
        self.clipsToBounds = true
        
        self.imageNode.imageUpdated = { [weak self] _ in
            self?._ready.set(.single(Void()))
        }
        
        self.imageNode.view.contentMode = .scaleAspectFill
        self.imageNode.clipsToBounds = true
        
        self.statusNodeContainer.addSubnode(self.statusNode)
        self.addSubnode(self.statusNodeContainer)
        
        self.statusNodeContainer.addTarget(self, action: #selector(self.statusPressed), forControlEvents: .touchUpInside)
        
        self.statusNodeContainer.isUserInteractionEnabled = false
        
        self.titleContentView = GalleryTitleView(frame: CGRect())
        self._titleView.set(.single(self.titleContentView))
        
        self.recognitionOverlayContentNode.action = { [weak self] active in
            if let strongSelf = self {
                let transition = ContainedViewLayoutTransition.animated(duration: 0.2, curve: .easeInOut)
                if let recognizedContentNode = strongSelf.recognizedContentNode {
                    strongSelf.imageNode.isUserInteractionEnabled = active
                    transition.updateAlpha(node: recognizedContentNode, alpha: active ? 1.0 : 0.0)
                    if active {
                        strongSelf.updateControlsVisibility(false)
                    } else {
                        recognizedContentNode.dismissSelection()
                        strongSelf.updateControlsVisibility(true)
                    }
                    strongSelf.pagingEnabledPromise.set(!active)
                }
            }
        }
    }
    
    override func isPagingEnabled() -> Signal<Bool, NoError> {
        return self.pagingEnabledPromise.get()
    }
    
    deinit {
        //self.fetchDisposable.dispose()
        self.statusDisposable.dispose()
        self.dataDisposable.dispose()
        self.recognitionDisposable.dispose()
    }
    
    override func ready() -> Signal<Void, NoError> {
        return self._ready.get()
    }
    
    override func screenFrameUpdated(_ frame: CGRect) {
        let center = frame.midX - self.frame.width / 2.0
        self.subnodeTransform = CATransform3DMakeTranslation(-center * 0.16, 0.0, 0.0)
    }
    
    override func containerLayoutUpdated(_ layout: ContainerViewLayout, navigationBarHeight: CGFloat, transition: ContainedViewLayoutTransition) {
        super.containerLayoutUpdated(layout, navigationBarHeight: navigationBarHeight, transition: transition)
        
        let statusSize = CGSize(width: 50.0, height: 50.0)
        transition.updateFrame(node: self.statusNodeContainer, frame: CGRect(origin: CGPoint(x: floor((layout.size.width - statusSize.width) / 2.0), y: floor((layout.size.height - statusSize.height) / 2.0)), size: statusSize))
        transition.updateFrame(node: self.statusNode, frame: CGRect(origin: CGPoint(), size: statusSize))
    }
    
    fileprivate func setMessage(_ message: Message, displayInfo: Bool) {
        self.message = message
        self.imageNode.captureProtected = message.isCopyProtected()
        self.footerContentNode.setMessage(message, displayInfo: displayInfo)
    }
    
    fileprivate func setImage(imageReference: ImageMediaReference) {
        if self.contextAndMedia == nil || !self.contextAndMedia!.1.media.isEqual(to: imageReference.media) {
            if let largestSize = largestRepresentationForPhoto(imageReference.media) {
                let displaySize = largestSize.dimensions.cgSize.fitted(CGSize(width: 1280.0, height: 1280.0)).dividedByScreenScale().integralFloor
                self.imageNode.asyncLayout()(TransformImageArguments(corners: ImageCorners(), imageSize: displaySize, boundingSize: displaySize, intrinsicInsets: UIEdgeInsets()))()
                let signal: Signal<(TransformImageArguments) -> DrawingContext?, NoError> = chatMessagePhotoInternal(photoData: chatMessagePhotoDatas(postbox: self.context.account.postbox, photoReference: imageReference, tryAdditionalRepresentations: true, synchronousLoad: false), synchronousLoad: false)
                |> map { [weak self] _, quality, generate -> (TransformImageArguments) -> DrawingContext? in
                    Queue.mainQueue().async {
                        guard let strongSelf = self else {
                            return
                        }
                        switch quality {
                        case .medium, .full:
                            strongSelf.statusNodeContainer.isHidden = true
                            
                            Queue.concurrentDefaultQueue().async {
                                if let message = strongSelf.message, !message.isCopyProtected() && !imageReference.media.flags.contains(.hasStickers) {
                                    strongSelf.recognitionDisposable.set((recognizedContent(engine: strongSelf.context.engine, image: { return generate(TransformImageArguments(corners: ImageCorners(), imageSize: displaySize, boundingSize: displaySize, intrinsicInsets: UIEdgeInsets()))?.generateImage() }, messageId: message.id)
                                    |> deliverOnMainQueue).start(next: { [weak self] results in
                                        if let strongSelf = self {
                                            strongSelf.recognizedContentNode?.removeFromSupernode()
                                            if !results.isEmpty {
                                                let size = strongSelf.imageNode.bounds.size
                                                let recognizedContentNode = RecognizedContentContainer(size: size, recognitions: results, presentationData: strongSelf.context.sharedContext.currentPresentationData.with { $0 }, present: { [weak self] c, a in
                                                    if let strongSelf = self {
                                                        strongSelf.galleryController()?.presentInGlobalOverlay(c, with: a)
                                                    }
                                                }, performAction: { [weak self] string, action in
                                                    guard let strongSelf = self else {
                                                        return
                                                    }
                                                    switch action {
                                                    case .copy:
                                                        UIPasteboard.general.string = string
                                                        if let controller = strongSelf.baseNavigationController()?.topViewController as? ViewController {
                                                            let presentationData = strongSelf.context.sharedContext.currentPresentationData.with({ $0 })
                                                            let tooltipController = UndoOverlayController(presentationData: presentationData, content: .copy(text: presentationData.strings.Conversation_TextCopied), elevatedLayout: true, animateInAsReplacement: false, action: { _ in return false })
                                                            controller.present(tooltipController, in: .window(.root))
                                                        }
                                                    case .share:
                                                        if let controller = strongSelf.baseNavigationController()?.topViewController as? ViewController {
                                                            let shareController = ShareController(context: strongSelf.context, subject: .text(string), externalShare: true, immediateExternalShare: false, updatedPresentationData: (strongSelf.context.sharedContext.currentPresentationData.with({ $0 }), strongSelf.context.sharedContext.presentationData))
                                                            controller.present(shareController, in: .window(.root))
                                                        }
                                                    case .lookup:
                                                        let controller = UIReferenceLibraryViewController(term: string)
                                                        if let window = strongSelf.baseNavigationController()?.view.window {
                                                            controller.popoverPresentationController?.sourceView = window
                                                            controller.popoverPresentationController?.sourceRect = CGRect(origin: CGPoint(x: window.bounds.width / 2.0, y: window.bounds.size.height - 1.0), size: CGSize(width: 1.0, height: 1.0))
                                                            window.rootViewController?.present(controller, animated: true)
                                                        }
                                                    case .speak:
                                                        let _ = speakText(context: strongSelf.context, text: string)
                                                    case .translate:
                                                        if let parentController = strongSelf.baseNavigationController()?.topViewController as? ViewController {
                                                            let controller = TranslateScreen(context: strongSelf.context, text: string, fromLanguage: nil)
                                                            controller.pushController = { [weak parentController] c in
                                                                (parentController?.navigationController as? NavigationController)?._keepModalDismissProgress = true
                                                                parentController?.push(c)
                                                            }
                                                            controller.presentController = { [weak parentController] c in
                                                                parentController?.present(c, in: .window(.root))
                                                            }
                                                            parentController.present(controller, in: .window(.root))
                                                        }
                                                    }
                                                })
                                                recognizedContentNode.barcodeAction = { [weak self] payload, rect in
                                                    guard let strongSelf = self, let message = strongSelf.message else {
                                                        return
                                                    }
                                                    strongSelf.footerContentNode.openActionOptions?(.url(url: payload, concealed: true), message)
                                                }
                                                recognizedContentNode.alpha = 0.0
                                                recognizedContentNode.frame = CGRect(origin: CGPoint(), size: size)
                                                recognizedContentNode.update(size: strongSelf.imageNode.bounds.size, transition: .immediate)
                                                strongSelf.imageNode.addSubnode(recognizedContentNode)
                                                strongSelf.recognizedContentNode = recognizedContentNode
                                                strongSelf.recognitionOverlayContentNode.transitionIn()
                                            }
                                        }
                                    }))
                                }
                            }
                            
                        case .none, .blurred:
                            strongSelf.statusNodeContainer.isHidden = false
                        }
                    }
                    return generate
                }
                self.imageNode.setSignal(signal)
                
                self.zoomableContent = (largestSize.dimensions.cgSize, self.imageNode)
                
                self.fetchDisposable.set(fetchedMediaResource(mediaBox: self.context.account.postbox.mediaBox, reference: imageReference.resourceReference(largestSize.resource)).start())
                self.setupStatus(resource: largestSize.resource)
            } else {
                self._ready.set(.single(Void()))
            }
            if imageReference.media.flags.contains(.hasStickers) {
                let rightBarButtonItem = UIBarButtonItem(image: generateTintedImage(image: UIImage(bundleImageName: "Media Gallery/Stickers"), color: .white), style: .plain, target: self, action: #selector(self.openStickersButtonPressed))
                self._rightBarButtonItems.set(.single([rightBarButtonItem]))
            } else {
                self._rightBarButtonItems.set(.single([]))
            }
        }
        self.contextAndMedia = (self.context, imageReference.abstract)
    }
    
    private func updateImageFromFile(path: String) {
        if let _ = self.tilingNode {
            self.tilingNode = nil
        }
        
        guard let dataProvider = CGDataProvider(url: URL(fileURLWithPath: path) as CFURL) else {
            self._ready.set(.single(Void()))
            return
        }
        
        var maybeImage: CGImage?
        
        if let image = CGImage(jpegDataProviderSource: dataProvider, decode: nil, shouldInterpolate: true, intent: .defaultIntent) {
            maybeImage = image
        } else if let image = CGImage(pngDataProviderSource: dataProvider, decode: nil, shouldInterpolate: true, intent: .defaultIntent) {
            maybeImage = image
        }
        
        guard let image = maybeImage else {
            self._ready.set(.single(Void()))
            return
        }
        
        let tilingNode = TilingNode(image: image, path: path)
        self.tilingNode = tilingNode
        
        let size = CGSize(width: image.width, height: image.height)
        self.zoomableContent = (size, tilingNode)
        
        self._ready.set(.single(Void()))
    }
    
    @objc func openStickersButtonPressed() {
        guard let (context, media) = self.contextAndMedia else {
            return
        }
        let presentationData = context.sharedContext.currentPresentationData.with { $0 }
        let topController = (self.baseNavigationController()?.topViewController as? ViewController)
        let progressSignal = Signal<Never, NoError> { subscriber in
            let controller = OverlayStatusController(theme: presentationData.theme, type: .loading(cancelled: nil))
            topController?.present(controller, in: .window(.root), with: nil)
            return ActionDisposable { [weak controller] in
                Queue.mainQueue().async() {
                    controller?.dismiss()
                }
            }
        }
        |> runOn(Queue.mainQueue())
        |> delay(0.15, queue: Queue.mainQueue())
        let progressDisposable = progressSignal.start()
        
        let signal = context.engine.stickers.stickerPacksAttachedToMedia(media: media)
        |> afterDisposed {
            Queue.mainQueue().async {
                progressDisposable.dispose()
            }
        }
        let _ = (signal
        |> deliverOnMainQueue).start(next: { [weak self] packs in
            guard let strongSelf = self, !packs.isEmpty else {
                return
            }
            let baseNavigationController = strongSelf.baseNavigationController()
            baseNavigationController?.view.endEditing(true)
            let controller = StickerPackScreen(context: context, mainStickerPack: packs[0], stickerPacks: packs, sendSticker: nil, actionPerformed: { actions in
                if let (info, items, action) = actions.first {
                    let animateInAsReplacement = false
                    switch action {
                    case .add:
                        topController?.present(UndoOverlayController(presentationData: presentationData, content: .stickersModified(title: presentationData.strings.StickerPackActionInfo_AddedTitle, text: presentationData.strings.StickerPackActionInfo_AddedText(info.title).string, undo: false, info: info, topItem: items.first, context: context), elevatedLayout: true, animateInAsReplacement: animateInAsReplacement, action: { _ in
                            return true
                        }), in: .window(.root))
                    case let .remove(positionInList):
                        topController?.present(UndoOverlayController(presentationData: presentationData, content: .stickersModified(title: presentationData.strings.StickerPackActionInfo_RemovedTitle, text: presentationData.strings.StickerPackActionInfo_RemovedText(info.title).string, undo: true, info: info, topItem: items.first, context: context), elevatedLayout: true, animateInAsReplacement: animateInAsReplacement, action: { action in
                            if case .undo = action {
                                let _ = context.engine.stickers.addStickerPackInteractively(info: info, items: items, positionInList: positionInList).start()
                            }
                            return true
                        }), in: .window(.root))
                    }
                }
            })
            (baseNavigationController?.topViewController as? ViewController)?.present(controller, in: .window(.root), with: nil)
        })
    }
    
    func setFile(context: AccountContext, fileReference: FileMediaReference) {
        if self.contextAndMedia == nil || !self.contextAndMedia!.1.media.isEqual(to: fileReference.media) {
            if var largestSize = fileReference.media.dimensions {
                var displaySize = largestSize.cgSize.dividedByScreenScale()
                if let previewDimensions = largestImageRepresentation(fileReference.media.previewRepresentations)?.dimensions {
                    let previewAspect = CGFloat(previewDimensions.width) / CGFloat(previewDimensions.height)
                    let aspect = displaySize.width / displaySize.height
                    if abs(previewAspect - 1.0 / aspect) < 0.1 {
                        displaySize = CGSize(width: displaySize.height, height: displaySize.width)
                        largestSize = PixelDimensions(width: largestSize.height, height: largestSize.width)
                    }
                }
                self.imageNode.asyncLayout()(TransformImageArguments(corners: ImageCorners(), imageSize: displaySize, boundingSize: displaySize, intrinsicInsets: UIEdgeInsets()))()
                
                /*if largestSize.width > 2600 || largestSize.height > 2600 {
                    self.dataDisposable.set((self.context.account.postbox.mediaBox.resourceData(fileReference.media.resource)
                    |> deliverOnMainQueue).start(next: { [weak self] data in
                        guard let strongSelf = self else {
                            return
                        }
                        if !data.complete {
                            return
                        }
                        strongSelf.updateImageFromFile(path: data.path)
                    }))
                } else {*/
                    self.imageNode.setSignal(chatMessageImageFile(account: context.account, fileReference: fileReference, thumbnail: false), dispatchOnDisplayLink: false)
                //}
                
                self.zoomableContent = (largestSize.cgSize, self.imageNode)
                self.setupStatus(resource: fileReference.media.resource)
            } else {
                self._ready.set(.single(Void()))
            }
        }
        self.contextAndMedia = (context, fileReference.abstract)
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
        let wasCaptureProtected = self.imageNode.captureProtected
        self.imageNode.captureProtected = false
        
        let contentNode = self.tilingNode ?? self.imageNode
        
        var transformedFrame = node.0.view.convert(node.0.view.bounds, to: contentNode.view)
        let transformedSuperFrame = node.0.view.convert(node.0.view.bounds, to: contentNode.view.superview)
        let transformedSelfFrame = node.0.view.convert(node.0.view.bounds, to: self.view)
        
        /*let projectedScale = CGPoint(x: contentNode.view.bounds.width / node.1.width, y: contentNode.view.bounds.height / node.1.height)
        let scaledLocalImageViewBounds = CGRect(x: -node.1.minX * projectedScale.x, y: -node.1.minY * projectedScale.y, width: node.0.bounds.width * projectedScale.x, height: node.0.bounds.height * projectedScale.y)*/
        
        let scaledLocalImageViewBounds = contentNode.view.bounds
        
        let transformedCopyViewFinalFrame = contentNode.view.convert(scaledLocalImageViewBounds, to: self.view)
        
        let (maybeSurfaceCopyView, _) = node.2()
        let (maybeCopyView, copyViewBackgrond) = node.2()
        copyViewBackgrond?.alpha = 0.0
        let surfaceCopyView = maybeSurfaceCopyView!
        let copyView = maybeCopyView!
        
        addToTransitionSurface(surfaceCopyView)
        
        var transformedSurfaceFrame: CGRect?
        var transformedSurfaceFinalFrame: CGRect?
        if let contentSurface = surfaceCopyView.superview {
            transformedSurfaceFrame = node.0.view.convert(node.0.view.bounds, to: contentSurface)
            transformedSurfaceFinalFrame = contentNode.view.convert(scaledLocalImageViewBounds, to: contentSurface)
        }
        
        if let transformedSurfaceFrame = transformedSurfaceFrame {
            surfaceCopyView.frame = transformedSurfaceFrame
        }
        
        //self.view.insertSubview(copyView, belowSubview: self.scrollNode.view)
        copyView.frame = transformedSelfFrame
        
        copyView.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.2, removeOnCompletion: false)
        
        surfaceCopyView.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.25, removeOnCompletion: false)
        
        let positionDuration: Double = 0.21
        
        copyView.layer.animatePosition(from: CGPoint(x: transformedSelfFrame.midX, y: transformedSelfFrame.midY), to: CGPoint(x: transformedCopyViewFinalFrame.midX, y: transformedCopyViewFinalFrame.midY), duration: positionDuration, timingFunction: kCAMediaTimingFunctionSpring, removeOnCompletion: false, completion: { [weak copyView, weak self] _ in
            copyView?.removeFromSuperview()
            
            if wasCaptureProtected {
                Queue.mainQueue().after(0.2) {
                    self?.imageNode.captureProtected = true
                }
            }
        })
        let scale = CGSize(width: transformedCopyViewFinalFrame.size.width / transformedSelfFrame.size.width, height: transformedCopyViewFinalFrame.size.height / transformedSelfFrame.size.height)
        copyView.layer.animate(from: NSValue(caTransform3D: CATransform3DIdentity), to: NSValue(caTransform3D: CATransform3DMakeScale(scale.width, scale.height, 1.0)), keyPath: "transform", timingFunction: kCAMediaTimingFunctionSpring, duration: 0.25, removeOnCompletion: false)
        
        if let transformedSurfaceFrame = transformedSurfaceFrame, let transformedSurfaceFinalFrame = transformedSurfaceFinalFrame {
            surfaceCopyView.layer.animatePosition(from: CGPoint(x: transformedSurfaceFrame.midX, y: transformedSurfaceFrame.midY), to: CGPoint(x: transformedSurfaceFinalFrame.midX, y: transformedSurfaceFinalFrame.midY), duration: positionDuration, timingFunction: kCAMediaTimingFunctionSpring, removeOnCompletion: false, completion: { [weak surfaceCopyView] _ in
                surfaceCopyView?.removeFromSuperview()
            })
            let scale = CGSize(width: transformedSurfaceFinalFrame.size.width / transformedSurfaceFrame.size.width, height: transformedSurfaceFinalFrame.size.height / transformedSurfaceFrame.size.height)
            surfaceCopyView.layer.animate(from: NSValue(caTransform3D: CATransform3DIdentity), to: NSValue(caTransform3D: CATransform3DMakeScale(scale.width, scale.height, 1.0)), keyPath: "transform", timingFunction: kCAMediaTimingFunctionSpring, duration: 0.25, removeOnCompletion: false)
        }
        
        contentNode.layer.animatePosition(from: CGPoint(x: transformedSuperFrame.midX, y: transformedSuperFrame.midY), to: contentNode.layer.position, duration: positionDuration, timingFunction: kCAMediaTimingFunctionSpring)
        contentNode.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.1)
        
        transformedFrame.origin = CGPoint()
        contentNode.layer.animateBounds(from: transformedFrame, to: contentNode.layer.bounds, duration: 0.25, timingFunction: kCAMediaTimingFunctionSpring)
        
        self.statusNodeContainer.layer.animatePosition(from: CGPoint(x: transformedSuperFrame.midX, y: transformedSuperFrame.midY), to: self.statusNodeContainer.position, duration: positionDuration, timingFunction: kCAMediaTimingFunctionSpring)
        self.statusNodeContainer.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.25, timingFunction: kCAMediaTimingFunctionSpring)
        self.statusNodeContainer.layer.animateScale(from: 0.5, to: 1.0, duration: 0.25, timingFunction: kCAMediaTimingFunctionSpring)
    }
    
    override func animateOut(to node: (ASDisplayNode, CGRect, () -> (UIView?, UIView?)), addToTransitionSurface: (UIView) -> Void, completion: @escaping () -> Void) {
        if let controller = self.baseNavigationController()?.topViewController as? ViewController {
            controller.window?.forEachController({ controller in
                if let controller = controller as? UndoOverlayController {
                    controller.dismissWithCommitAction()
                }
            })
            controller.forEachController({ controller in
                if let controller = controller as? UndoOverlayController {
                    controller.dismissWithCommitAction()
                }
                return true
            })
        }
        
        self.fetchDisposable.set(nil)
        
        let contentNode = self.tilingNode ?? self.imageNode
        
        var transformedFrame = node.0.view.convert(node.0.view.bounds, to: contentNode.view)
        let transformedSuperFrame = node.0.view.convert(node.0.view.bounds, to: contentNode.view.superview)
        let transformedSelfFrame = node.0.view.convert(node.0.view.bounds, to: self.view)
        let transformedCopyViewInitialFrame = contentNode.view.convert(contentNode.view.bounds, to: self.view)
        
        var positionCompleted = false
        var boundsCompleted = false
        var copyCompleted = false
        
        let (maybeSurfaceCopyView, _) = node.2()
        let (maybeCopyView, copyViewBackgrond) = node.2()
        copyViewBackgrond?.alpha = 0.0
        let surfaceCopyView = maybeSurfaceCopyView!
        let copyView = maybeCopyView!
        
        addToTransitionSurface(surfaceCopyView)
        
        var transformedSurfaceFrame: CGRect?
        var transformedSurfaceCopyViewInitialFrame: CGRect?
        if let contentSurface = surfaceCopyView.superview {
            transformedSurfaceFrame = node.0.view.convert(node.0.view.bounds, to: contentSurface)
            transformedSurfaceCopyViewInitialFrame = contentNode.view.convert(contentNode.view.bounds, to: contentSurface)
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
        
        contentNode.layer.animatePosition(from: contentNode.layer.position, to: CGPoint(x: transformedSuperFrame.midX, y: transformedSuperFrame.midY), duration: 0.25, timingFunction: kCAMediaTimingFunctionSpring, removeOnCompletion: false, completion: { _ in
            positionCompleted = true
            intermediateCompletion()
        })
        
        contentNode.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.08, removeOnCompletion: false)
        
        transformedFrame.origin = CGPoint()
        contentNode.layer.animateBounds(from: contentNode.layer.bounds, to: transformedFrame, duration: 0.25, timingFunction: kCAMediaTimingFunctionSpring, removeOnCompletion: false, completion: { _ in
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
    
    override func titleView() -> Signal<UIView?, NoError> {
        return self._titleView.get()
    }
    
    override func rightBarButtonItems() -> Signal<[UIBarButtonItem]?, NoError> {
        return self._rightBarButtonItems.get()
    }
    
    override func footerContent() -> Signal<(GalleryFooterContentNode?, GalleryOverlayContentNode?), NoError> {
        return .single((self.footerContentNode, self.recognitionOverlayContentNode))
    }
    
    @objc func statusPressed() {
        if let (_, mediaReference) = self.contextAndMedia, let status = self.status {
            var resource: MediaResourceReference?
            var statsCategory: MediaResourceStatsCategory?
            if let fileReference = mediaReference.concrete(TelegramMediaFile.self) {
                resource = fileReference.resourceReference(fileReference.media.resource)
                statsCategory = statsCategoryForFileWithAttributes(fileReference.media.attributes)
            } else if let imageReference = mediaReference.concrete(TelegramMediaImage.self ) {
                resource = (largestImageRepresentation(imageReference.media.representations)?.resource).flatMap(imageReference.resourceReference)
                statsCategory = .image
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
    
    override func adjustForPreviewing() {
        super.adjustForPreviewing()
        
        self.recognitionOverlayContentNode.isHidden = true
    }
    
    private func canDelete() -> Bool {
        guard let message = self.message else {
            return false
        }

        var canDelete = false
        if let peer = message.peers[message.id.peerId] {
            if peer is TelegramUser || peer is TelegramSecretChat {
                canDelete = true
            } else if let _ = peer as? TelegramGroup {
                canDelete = true
            } else if let channel = peer as? TelegramChannel {
                if message.flags.contains(.Incoming) {
                    canDelete = channel.hasPermission(.deleteAllMessages)
                } else {
                    canDelete = true
                }
            } else {
                canDelete = false
            }
        } else {
            canDelete = false
        }
        return canDelete
    }
    
    override var keyShortcuts: [KeyShortcut] {
        let strings = self.presentationData.strings
        
        var keyShortcuts: [KeyShortcut] = []
        keyShortcuts.append(
            KeyShortcut(
                title: strings.KeyCommand_Share,
                input: "S",
                modifiers: [.command],
                action: { [weak self] in
                    self?.footerContentNode.actionButtonPressed()
                }
            )
        )
        if self.canDelete() {
            keyShortcuts.append(
                KeyShortcut(
                    input: "\u{8}",
                    modifiers: [],
                    action: { [weak self] in
                        self?.footerContentNode.deleteButtonPressed()
                    }
                )
            )
        }
        return keyShortcuts
    }
}

/*private func tileRectForImage(_ mappedImage: CGImage, rect: CGRect) -> CGRect {
    let scaleX = CGFloat(mappedImage.width) / lowResolutionImage.size.width
    let scaleY = CGFloat(mappedImage.height) / lowResolutionImage.size.height
    
    let mappedX = rect.minX * scaleX
    let mappedY = rect.minY * scaleY
    let mappedWidth = rect.width * scaleX
    let mappedHeight = rect.height * scaleY
    
    return CGRect(x: mappedX, y: mappedY, width: mappedWidth, height: mappedHeight)
}*/

private func zoomScale(for zoomLevel: CGFloat) -> CGFloat {
    return pow(2.0, zoomLevel - 1.0)
}

private func zoomLevel(for zoomScale: CGFloat) -> CGFloat {
    return log2(zoomScale) + 1.0
}

private final class TilingLayer: CATiledLayer {
    override var contentsScale: CGFloat {
        get {
            return super.contentsScale
        } set(value) {
            super.contentsScale = value
        }
    }
}

class TilingView: UIView {
    let image: CGImage
    let path: String
    var cachedScaledImage: UIImage?
    
    let imageSize: CGSize
    let tileSize: CGSize
    var normalizedSize: CGSize?
    
    override static var layerClass: AnyClass {
        return TilingLayer.self
    }
    
    private var tiledLayer: TilingLayer {
        return self.layer as! TilingLayer
    }
    
    init(image: CGImage, path: String) {
        self.image = image
        self.path = path
        
        self.tileSize = CGSize(width: 256.0, height: 256.0)
        self.imageSize = CGSize(width: image.width, height: image.height)
        
        super.init(frame: CGRect())
        
        self.tiledLayer.contentsScale = UIScreenScale
        let scale = self.tiledLayer.contentsScale
        self.tiledLayer.tileSize = CGSize(width: self.tileSize.width * scale, height: self.tileSize.height * scale)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override var intrinsicContentSize: CGSize {
        return self.imageSize
    }
    
    func setMaximumZoomScale(_ value: CGFloat, normalizedSize: CGSize) {
        if self.normalizedSize != normalizedSize {
            self.normalizedSize = normalizedSize
            
            /*let options: [CFString: Any] = [
                kCGImageSourceCreateThumbnailFromImageIfAbsent: true,
                kCGImageSourceCreateThumbnailWithTransform: true,
                kCGImageSourceShouldCacheImmediately: false,
                kCGImageSourceThumbnailMaxPixelSize: Int(max(self.imageSize.width / 4.0, self.imageSize.height / 4.0))
            ]

            let startTime = CACurrentMediaTime()
            if let imageSource = CGImageSourceCreateWithURL(URL(fileURLWithPath: self.path) as CFURL, nil), let image = CGImageSourceCreateThumbnailAtIndex(imageSource, 0, options as CFDictionary) {
                self.cachedScaledImage = UIImage(cgImage: image)
            }
            print("create thumbnail: \((CACurrentMediaTime() - startTime) * 1000.0) ms")*/
        }
        
        let levels = max(1, Int(zoomLevel(for: value)))
        self.tiledLayer.levelsOfDetail = levels
        self.tiledLayer.levelsOfDetailBias = levels - 1
    }
    
    override func draw(_ rect: CGRect) {
        guard let normalizedSize = self.normalizedSize else {
            return
        }
        guard let context = UIGraphicsGetCurrentContext() else {
            return
        }
        let image = self.image
        let cachedScaledImage = self.cachedScaledImage
        let imageSize = self.imageSize
        context.setBlendMode(.copy)
        
        let contentScale = context.ctm.a
        let normalizedContentScale = contentScale / UIScreenScale
        
        let normalizedRect = rect
        
        let normalizationScale = imageSize.width / normalizedSize.width
        
        let normalizedCroppingRect = CGRect(origin: CGPoint(x: normalizedRect.minX * normalizationScale, y: normalizedRect.minY * normalizationScale), size: CGSize(width: normalizedRect.width * normalizationScale, height: normalizedRect.height * normalizationScale))
        
        let tileSizes: [CGFloat] = [
            //8192.0,
            //4096.0,
            2048.0,
            1024.0,
            512.0,
            256.0
        ]
        
        var maximumTileSize: CGFloat = tileSizes[0]
        for i in (0 ..< tileSizes.count).reversed() {
            if tileSizes[i] > normalizedCroppingRect.width {
                break
            }
            maximumTileSize = tileSizes[i]
        }
        
        let xMinTile = Int(floor(normalizedCroppingRect.minX / maximumTileSize))
        let xMaxTile = Int(ceil(normalizedCroppingRect.maxX / maximumTileSize))
        let yMinTile = Int(floor(normalizedCroppingRect.minY / maximumTileSize))
        let yMaxTile = Int(ceil(normalizedCroppingRect.maxY / maximumTileSize))
        
        for y in yMinTile ... yMaxTile {
            let imageMinY = floor(CGFloat(y) * maximumTileSize)
            var imageMaxY = ceil(CGFloat(y + 1) * maximumTileSize)
            imageMaxY = min(imageMaxY, imageSize.height)
            if imageMaxY <= imageMinY {
                continue
            }
            
            for x in xMinTile ... xMaxTile {
                let imageMinX = floor(CGFloat(x) * maximumTileSize)
                var imageMaxX = ceil(CGFloat(x + 1) * maximumTileSize)
                imageMaxX = min(imageMaxX, imageSize.width)
                if imageMaxX <= imageMinX {
                    continue
                }
                
                let imageRect = CGRect(origin: CGPoint(x: imageMinX, y: imageMinY), size: CGSize(width: imageMaxX - imageMinX, height: imageMaxY - imageMinY))
                
                let drawingRect = CGRect(origin: CGPoint(x: imageRect.minX / normalizationScale, y: imageRect.minY / normalizationScale), size: CGSize(width: imageRect.width / normalizationScale, height: imageRect.height / normalizationScale))
                
                var tileImage: CGImage?
                if normalizedContentScale < 1.1, let cachedScaledImage = cachedScaledImage {
                    let cachedScale = cachedScaledImage.size.width / self.imageSize.width
                    let scaledImageRect = CGRect(origin: CGPoint(x: imageRect.minX * cachedScale, y: imageRect.minY * cachedScale), size: CGSize(width: imageRect.width * cachedScale, height: imageRect.height * cachedScale))
                    tileImage = cachedScaledImage.cgImage!.cropping(to: scaledImageRect)
                } else {
                    tileImage = image.cropping(to: imageRect)
                }
                
                if let tileImage = tileImage {
                    var scaledSide = max(imageRect.width, imageRect.height)
                    let targetSide = max(drawingRect.width, drawingRect.height)
                    while true {
                        let maybeSide = round(scaledSide * 0.5)
                        if maybeSide < targetSide {
                            break
                        } else {
                            scaledSide = maybeSide
                        }
                    }
                    
                    /*let scaledSize = imageRect.size.fitted(CGSize(width: scaledSide, height: scaledSide))
                    let scaledImage = generateImage(scaledSize, contextGenerator: { size, scaledContext in
                        scaledContext.setBlendMode(.copy)
                        let startTime = CACurrentMediaTime()
                        scaledContext.draw(tileImage, in: CGRect(origin: CGPoint(), size: size))
                        print("draw scaled: \((CACurrentMediaTime() - startTime) * 1000.0) ms")
                    }, opaque: true, scale: UIScreenScale)
                    
                    if let scaledImage = scaledImage {
                        scaledImage.draw(in: drawingRect.insetBy(dx: -0.5, dy: -0.5), blendMode: .copy, alpha: 1.0)
                    }*/
                    
                    let startTime = CACurrentMediaTime()
                    context.translateBy(x: drawingRect.midX, y: drawingRect.midY)
                    context.scaleBy(x: 1.0, y: -1.0)
                    context.translateBy(x: -drawingRect.midX, y: -drawingRect.midY)
                    context.draw(tileImage, in: drawingRect.insetBy(dx: -0.5, dy: -0.5))
                    context.translateBy(x: drawingRect.midX, y: drawingRect.midY)
                    context.scaleBy(x: 1.0, y: -1.0)
                    context.translateBy(x: -drawingRect.midX, y: -drawingRect.midY)
                    print("draw direct: \((CACurrentMediaTime() - startTime) * 1000.0) ms")
                }
            }
        }
    }
    
    private func annotate(rect: CGRect, col: Int, row: Int, zoomLevel: CGFloat, scale: CGFloat, context: CGContext) {
        let lineWidth = 2.0 / scale
        let halfLineWidth = lineWidth / 2.0
        //let fontSize = 12.0 / scale
        
        //NSString *pointString = [NSString stringWithFormat:@"%@x(%@, %@) @%@x", @(zoomLevel), @(col), @(row), @([UIScreen mainScreen].scale)];
        //CGPoint textOrigin = CGPointMake(CGRectGetMinX(rect) + lineWidth, CGRectGetMinY(rect) + lineWidth);
        /*[pointString drawAtPoint:textOrigin withAttributes:@{
                                                             NSFontAttributeName: [UIFont boldSystemFontOfSize:fontSize],
                                                             NSForegroundColorAttributeName: [UIColor darkGrayColor]
                                                             }];*/
        context.setFillColor(UIColor.red.cgColor)
        context.setLineWidth(lineWidth)
        context.stroke(rect.insetBy(dx: halfLineWidth, dy: halfLineWidth))
    }
}

private final class TilingNode: ASDisplayNode {
    init(image: CGImage, path: String) {
        super.init()
        
        self.setViewBlock {
            return TilingView(image: image, path: path)
        }
    }
}

extension UIBezierPath {
    convenience init(rect: RecognizedContent.Rect, radius r: CGFloat) {
        let left  = CGFloat.pi
        let up    = CGFloat.pi * 1.5
        let down  = CGFloat.pi * 0.5
        let right = CGFloat.pi * 0.0
        
        self.init()
        
        addArc(withCenter: CGPoint(x: rect.topLeft.x + r, y: rect.topLeft.y + r), radius: r, startAngle: left, endAngle: up, clockwise: true)
        addArc(withCenter: CGPoint(x: rect.topRight.x - r, y: rect.topRight.y + r), radius: r, startAngle: up, endAngle: right, clockwise: true)
        addArc(withCenter: CGPoint(x: rect.bottomRight.x - r, y: rect.bottomRight.y - r), radius: r, startAngle: right, endAngle: down, clockwise: true)
        addArc(withCenter: CGPoint(x: rect.bottomLeft.x + r, y: rect.bottomLeft.y - r), radius: r, startAngle: down, endAngle: left, clockwise: true)
        close()
    }
}

private func generateMaskImage(size: CGSize, recognitions: [RecognizedContent]) -> UIImage? {
    return generateImage(size, opaque: false, rotatedContext: { size, c in
        let bounds = CGRect(origin: CGPoint(), size: size)
        c.clear(bounds)
        
        c.setFillColor(UIColor(rgb: 0x000000, alpha: 0.4).cgColor)
        c.fill(bounds)
        
        c.setBlendMode(.clear)
        for recognition in recognitions {
            let mappedRect = recognition.rect.convertTo(size: size, insets: UIEdgeInsets(top: -4.0, left: -2.0, bottom: -4.0, right: -2.0))
            let path = UIBezierPath(rect: mappedRect, radius: 3.5)
            c.addPath(path.cgPath)
            c.fillPath()
        }
    })
}

private class RecognizedContentContainer: ASDisplayNode {
    private let size: CGSize
    private let recognitions: [RecognizedContent]
    
    private let maskNode: ASImageNode
    private var selectionNode: RecognizedTextSelectionNode?
    
    var barcodeAction: ((String, CGRect) -> Void)?
    
    init(size: CGSize, recognitions: [RecognizedContent], presentationData: PresentationData, present: @escaping (ViewController, Any?) -> Void, performAction: @escaping (String, RecognizedTextSelectionAction) -> Void) {
        self.size = size
        self.recognitions = recognitions
        
        self.maskNode = ASImageNode()
        self.maskNode.image = generateMaskImage(size: size, recognitions: recognitions)
                
        super.init()
        
        let selectionNode = RecognizedTextSelectionNode(size: size, theme: RecognizedTextSelectionTheme(selection: presentationData.theme.chat.message.incoming.textSelectionColor, knob:  presentationData.theme.chat.message.incoming.textSelectionKnobColor, knobDiameter: 12.0), strings: presentationData.strings, recognitions: recognitions, updateIsActive: { _ in }, present: present, rootNode: self, performAction: { string, action in
            performAction(string, action)
        })
        self.selectionNode = selectionNode
        
        self.addSubnode(self.maskNode)
        self.addSubnode(selectionNode.highlightAreaNode)
        self.addSubnode(selectionNode)
    }
    
    func dismissSelection() {
        let _ = self.selectionNode?.dismissSelection()
    }
    
    override func didLoad() {
        super.didLoad()
        
        self.view.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(self.handleTap(_:))))
    }
    
    @objc private func handleTap(_ gestureRecognizer: UITapGestureRecognizer) {
        let location = gestureRecognizer.location(in: self.view)
        
        for recognition in self.recognitions {
            let mappedRect = recognition.rect.convertTo(size: self.bounds.size)
            if mappedRect.boundingFrame.contains(location) {
                if case let .qrCode(payload) = recognition.content {
                    self.barcodeAction?(payload, mappedRect.boundingFrame)
                }
                break
            }
        }
    }
    
    func update(size: CGSize, transition: ContainedViewLayoutTransition) {
        let bounds = CGRect(origin: CGPoint(), size: size)
        transition.updateFrame(node: self.maskNode, frame: bounds)
        if let selectionNode = self.selectionNode {
            transition.updateFrame(node: selectionNode, frame: bounds)
            selectionNode.highlightAreaNode.frame = bounds
        }
    }
    
    override func point(inside point: CGPoint, with event: UIEvent?) -> Bool {
        for recognition in self.recognitions {
            let mappedRect = recognition.rect.convertTo(size: self.bounds.size)
            if mappedRect.boundingFrame.insetBy(dx: -20.0, dy: -20.0).contains(point) {
                return true
            }
        }
        
        if (self.selectionNode?.dismissSelection() ?? false) {
            return true
        }

        return false
    }
}


private class ImageRecognitionOverlayContentNode: GalleryOverlayContentNode {
    private let backgroundNode: ASImageNode
    private let selectedBackgroundNode: ASImageNode
    private let iconNode: ASImageNode
    private let selectedIconNode: ASImageNode
    private let buttonNode: HighlightTrackingButtonNode
    
    var action: ((Bool) -> Void)?
    private var appeared = false
    
    init(theme: PresentationTheme) {
        self.backgroundNode = ASImageNode()
        self.backgroundNode.displaysAsynchronously = false
        
        self.selectedBackgroundNode = ASImageNode()
        self.selectedBackgroundNode.displaysAsynchronously = false
        self.selectedBackgroundNode.isHidden = true
        self.selectedBackgroundNode.image = generateFilledCircleImage(diameter: 32.0, color: .white)
        
        self.buttonNode = HighlightTrackingButtonNode()
        self.buttonNode.alpha = 0.0
        
        self.iconNode = ASImageNode()
        self.iconNode.displaysAsynchronously = false
        self.iconNode.image = generateTintedImage(image: UIImage(bundleImageName: "Media Gallery/LiveTextIcon"), color: .white)
        self.iconNode.contentMode = .center
        
        self.selectedIconNode = ASImageNode()
        self.selectedIconNode.displaysAsynchronously = false
        self.selectedIconNode.image = generateTintedImage(image: UIImage(bundleImageName: "Media Gallery/LiveTextIcon"), color: .black)
        self.selectedIconNode.contentMode = .center
        self.selectedIconNode.isHidden = true
        
        super.init()
        
        self.buttonNode.addTarget(self, action: #selector(self.buttonPressed), forControlEvents: .touchUpInside)
        self.addSubnode(self.buttonNode)
        self.buttonNode.addSubnode(self.backgroundNode)
        self.buttonNode.addSubnode(self.selectedBackgroundNode)
        self.buttonNode.addSubnode(self.iconNode)
        self.buttonNode.addSubnode(self.selectedIconNode)
    }
    
    @objc private func buttonPressed() {
        let newValue = !self.buttonNode.isSelected
        self.buttonNode.isSelected = newValue
        self.selectedBackgroundNode.isHidden = !newValue
        self.selectedIconNode.isHidden = !newValue
        
        self.action?(newValue)
        
        if self.interfaceIsHidden && !newValue {
            let transition = ContainedViewLayoutTransition.animated(duration: 0.2, curve: .easeInOut)
            transition.updateAlpha(node: self.buttonNode, alpha: 0.0)
        }
    }
    
    func transitionIn() {
        guard self.buttonNode.alpha.isZero else {
            return
        }
        self.appeared = true
        self.buttonNode.alpha = 1.0
        self.buttonNode.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.2)
    }
    
    private var interfaceIsHidden: Bool = false
    override func updateLayout(size: CGSize, metrics: LayoutMetrics, insets: UIEdgeInsets, isHidden: Bool, transition: ContainedViewLayoutTransition) {
        self.interfaceIsHidden = isHidden
        
        let buttonSize = CGSize(width: 32.0, height: 32.0)
        self.backgroundNode.frame = CGRect(origin: CGPoint(x: 12.0, y: 12.0), size: buttonSize)
        self.selectedBackgroundNode.frame = CGRect(origin: CGPoint(x: 12.0, y: 12.0), size: buttonSize)
        self.iconNode.frame = CGRect(origin: CGPoint(x: 12.0, y: 12.0), size: buttonSize)
        self.selectedIconNode.frame = CGRect(origin: CGPoint(x: 12.0, y: 12.0), size: buttonSize)
        
        if self.appeared {
            if !self.buttonNode.isSelected && isHidden {
                transition.updateAlpha(node: self.buttonNode, alpha: 0.0)
            } else {
                transition.updateAlpha(node: self.buttonNode, alpha: 1.0)
            }
        }
        
        transition.updateFrame(node: self.buttonNode, frame: CGRect(x: size.width - insets.right - buttonSize.width - 24.0, y: insets.top - 50.0, width: buttonSize.width + 24.0, height: buttonSize.height + 24.0))
    }
    
    override func animateIn(previousContentNode: GalleryOverlayContentNode?, transition: ContainedViewLayoutTransition) {
        guard self.appeared && (!self.interfaceIsHidden || self.buttonNode.isSelected) else {
            return
        }
        self.buttonNode.alpha = 1.0
        if let previousContentNode = previousContentNode as? ImageRecognitionOverlayContentNode, previousContentNode.appeared {
            
        } else {
            self.buttonNode.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.2)
        }
    }
    
    override func animateOut(nextContentNode: GalleryOverlayContentNode?, transition: ContainedViewLayoutTransition, completion: @escaping () -> Void) {
        let previousAlpha = self.buttonNode.alpha
        self.buttonNode.alpha = 0.0
        self.buttonNode.layer.animateAlpha(from: previousAlpha, to: 0.0, duration: 0.2)
        completion()
    }
    
    override func point(inside point: CGPoint, with event: UIEvent?) -> Bool {
        if self.buttonNode.alpha > 0.0 && self.buttonNode.frame.contains(point) {
            return true
        } else {
            return false
        }
    }
}
