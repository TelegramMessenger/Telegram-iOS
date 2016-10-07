import Foundation
import AsyncDisplayKit
import Postbox
import SwiftSignalKit
import Display
import TelegramCore

private struct FetchControls {
    let fetch: () -> Void
    let cancel: () -> Void
}

final class ChatMessageInteractiveMediaNode: ASTransformNode {
    private let imageNode: TransformImageNode
    private var progressNode: RadialProgressNode?
    private var tapRecognizer: UITapGestureRecognizer?
    
    private var media: Media?
    
    private let statusDisposable = MetaDisposable()
    private let fetchControls = Atomic<FetchControls?>(value: nil)
    private var fetchStatus: MediaResourceStatus?
    private let fetchDisposable = MetaDisposable()
    
    var activateLocalContent: () -> Void = { }
    
    init() {
        self.imageNode = TransformImageNode()
        
        super.init(layerBacked: false)
        
        self.imageNode.displaysAsynchronously = false
        self.addSubnode(self.imageNode)
    }
    
    deinit {
        self.statusDisposable.dispose()
        self.fetchDisposable.dispose()
    }
    
    override func didLoad() {
        let tapRecognizer = UITapGestureRecognizer(target: self, action: #selector(self.imageTap(_:)))
        self.imageNode.view.addGestureRecognizer(tapRecognizer)
        self.tapRecognizer = tapRecognizer
    }
    
    @objc func progressPressed() {
        if let fetchStatus = self.fetchStatus {
            switch fetchStatus {
                case .Fetching:
                    if let cancel = self.fetchControls.with({ return $0?.cancel }) {
                        cancel()
                    }
                case .Remote:
                    if let fetch = self.fetchControls.with({ return $0?.fetch }) {
                        fetch()
                    }
                case .Local:
                    break
            }
        }
    }
    
    @objc func imageTap(_ recognizer: UITapGestureRecognizer) {
        if case .ended = recognizer.state {
            if let file = media as? TelegramMediaFile, (file.isVideo || file.isAnimated || file.mimeType.hasPrefix("video/")) {
                self.activateLocalContent()
            } else {
                if let fetchStatus = self.fetchStatus, case .Local = fetchStatus {
                    self.activateLocalContent()
                } else {
                    self.progressPressed()
                }
            }
        }
    }
    
    func asyncLayout() -> (_ account: Account, _ media: Media, _ corners: ImageCorners, _ automaticDownload: Bool, _ constrainedSize: CGSize) -> (CGFloat, (CGSize) -> (CGFloat, (CGFloat) -> (CGSize, () -> Void))) {
        let currentMedia = self.media
        let imageLayout = self.imageNode.asyncLayout()
        
        return { account, media, corners, automaticDownload, constrainedSize in
            var initialBoundingSize: CGSize
            var nativeSize: CGSize
            
            if let image = media as? TelegramMediaImage, let dimensions = largestImageRepresentation(image.representations)?.dimensions {
                initialBoundingSize = dimensions.fitted(CGSize(width: min(200.0, constrainedSize.width - 60.0), height: 200.0))
                nativeSize = CGSize(width: floor(dimensions.width * 0.5), height: floor(dimensions.height * 0.5)).fitted(constrainedSize)
            } else if let file = media as? TelegramMediaFile, let dimensions = file.dimensions {
                initialBoundingSize = dimensions.fitted(CGSize(width: min(200.0, constrainedSize.width - 60.0), height: 200.0))
                nativeSize = CGSize(width: floor(dimensions.width * 0.5), height: floor(dimensions.height * 0.5)).fitted(constrainedSize)
            } else {
                initialBoundingSize = CGSize(width: 32.0, height: 32.0)
                nativeSize = initialBoundingSize
            }
            
            initialBoundingSize.width = max(initialBoundingSize.width, 60.0)
            initialBoundingSize.height = max(initialBoundingSize.height, 60.0)
            nativeSize.width = max(nativeSize.width, 60.0)
            nativeSize.height = max(nativeSize.height, 60.0)
            
            return (nativeSize.width, { constrainedSize in
                let boundingSize = initialBoundingSize.fitted(constrainedSize)
                
                var updateImageSignal: Signal<(TransformImageArguments) -> DrawingContext, NoError>?
                var updatedStatusSignal: Signal<MediaResourceStatus, NoError>?
                var updatedFetchControls: FetchControls?
                
                var mediaUpdated = false
                if let currentMedia = currentMedia {
                    mediaUpdated = !media.isEqual(currentMedia)
                } else {
                    mediaUpdated = true
                }
                
                if mediaUpdated {
                    if let image = media as? TelegramMediaImage {
                        updateImageSignal = chatMessagePhoto(account: account, photo: image)
                        updatedStatusSignal = chatMessagePhotoStatus(account: account, photo: image)
                        updatedFetchControls = FetchControls(fetch: { [weak self] in
                            if let strongSelf = self {
                                strongSelf.fetchDisposable.set(chatMessagePhotoInteractiveFetched(account: account, photo: image).start())
                            }
                        }, cancel: {
                                chatMessagePhotoCancelInteractiveFetch(account: account, photo: image)
                        })
                    } else if let file = media as? TelegramMediaFile {
                        updateImageSignal = chatMessageVideo(account: account, video: file)
                        updatedStatusSignal = chatMessageFileStatus(account: account, file: file)
                        updatedFetchControls = FetchControls(fetch: { [weak self] in
                            if let strongSelf = self {
                                strongSelf.fetchDisposable.set(chatMessageFileInteractiveFetched(account: account, file: file).start())
                            }
                        }, cancel: {
                            chatMessageFileCancelInteractiveFetch(account: account, file: file)
                        })
                    }
                }
                
                let arguments = TransformImageArguments(corners: corners, imageSize: boundingSize, boundingSize: boundingSize, intrinsicInsets: UIEdgeInsets())
                
                let imageFrame = CGRect(origin: CGPoint(x: -arguments.insets.left, y: -arguments.insets.top), size: arguments.drawingSize)
                
                return (boundingSize.width, { boundingWidth in
                    let adjustedWidth = boundingWidth
                    let adjustedHeight = boundingSize.aspectFitted(CGSize(width: adjustedWidth, height: CGFloat.greatestFiniteMagnitude)).height
                    let adjustedImageSize = CGSize(width: adjustedWidth, height: min(adjustedHeight, floorToScreenPixels(boundingSize.height * 1.4)))
                    
                    let adjustedArguments = TransformImageArguments(corners: corners, imageSize: nativeSize, boundingSize: adjustedImageSize, intrinsicInsets: UIEdgeInsets())
                    
                    let adjustedImageFrame = CGRect(origin: imageFrame.origin, size: adjustedArguments.drawingSize)
                    let imageApply = imageLayout(adjustedArguments)
                    
                    return (CGSize(width: adjustedImageSize.width, height: adjustedImageSize.height), { [weak self] in
                        if let strongSelf = self {
                            strongSelf.media = media
                            strongSelf.imageNode.frame = adjustedImageFrame
                            strongSelf.progressNode?.position = CGPoint(x: adjustedImageFrame.midX, y: adjustedImageFrame.midY)
                            
                            if let updateImageSignal = updateImageSignal {
                                strongSelf.imageNode.setSignal(account: account, signal: updateImageSignal)
                            }
                            
                            if let updatedStatusSignal = updatedStatusSignal {
                                strongSelf.statusDisposable.set((updatedStatusSignal |> deliverOnMainQueue).start(next: { [weak strongSelf] status in
                                    displayLinkDispatcher.dispatch {
                                        if let strongSelf = strongSelf {
                                            strongSelf.fetchStatus = status
                                            
                                            if let file = media as? TelegramMediaFile, (file.isVideo || file.mimeType.hasPrefix("video/")) {
                                                if let progressNode = strongSelf.progressNode {
                                                    progressNode.removeFromSupernode()
                                                    strongSelf.progressNode = nil
                                                }
                                            } else {
                                                if case .Local = status {
                                                    if let progressNode = strongSelf.progressNode {
                                                        progressNode.removeFromSupernode()
                                                        strongSelf.progressNode = nil
                                                    }
                                                } else {
                                                    if strongSelf.progressNode == nil {
                                                        let progressNode = RadialProgressNode()
                                                        progressNode.frame = CGRect(origin: CGPoint(), size: CGSize(width: 50.0, height: 50.0))
                                                        progressNode.position = strongSelf.imageNode.position
                                                        strongSelf.progressNode = progressNode
                                                        strongSelf.addSubnode(progressNode)
                                                    }
                                                }
                                                
                                                switch status {
                                                    case let .Fetching(progress):
                                                        strongSelf.progressNode?.state = .Fetching(progress: progress)
                                                    case .Local:
                                                        var state: RadialProgressState = .None
                                                        if let file = media as? TelegramMediaFile {
                                                            if file.isVideo {
                                                                state = .Play
                                                            }
                                                        }
                                                        strongSelf.progressNode?.state = state
                                                    case .Remote:
                                                        strongSelf.progressNode?.state = .Remote
                                                }
                                            }
                                        }
                                    }
                                }))
                            }
                            
                            if let updatedFetchControls = updatedFetchControls {
                                let _ = strongSelf.fetchControls.swap(updatedFetchControls)
                                if automaticDownload {
                                    if let image = media as? TelegramMediaImage {
                                        strongSelf.fetchDisposable.set(chatMessagePhotoInteractiveFetched(account: account, photo: image).start())
                                    }
                                }
                            }
                            
                            imageApply()
                        }
                    })
                })
            })
        }
    }
    
    static func asyncLayout(_ node: ChatMessageInteractiveMediaNode?) -> (_ account: Account, _ media: Media, _ corners: ImageCorners, _ automaticDownload: Bool, _ constrainedSize: CGSize) -> (CGFloat, (CGSize) -> (CGFloat, (CGFloat) -> (CGSize, () -> ChatMessageInteractiveMediaNode))) {
        let currentAsyncLayout = node?.asyncLayout()
        
        return { account, media, corners, automaticDownload, constrainedSize in
            var imageNode: ChatMessageInteractiveMediaNode
            var imageLayout: (_ account: Account, _ media: Media, _ corners: ImageCorners, _ automaticDownload: Bool, _ constrainedSize: CGSize) -> (CGFloat, (CGSize) -> (CGFloat, (CGFloat) -> (CGSize, () -> Void)))
            
            if let node = node, let currentAsyncLayout = currentAsyncLayout {
                imageNode = node
                imageLayout = currentAsyncLayout
            } else {
                imageNode = ChatMessageInteractiveMediaNode()
                imageLayout = imageNode.asyncLayout()
            }
            
            let (initialWidth, continueLayout) = imageLayout(account, media, corners, automaticDownload, constrainedSize)
            
            return (initialWidth, { constrainedSize in
                let (finalWidth, finalLayout) = continueLayout(constrainedSize)
                
                return (finalWidth, { boundingWidth in
                    let (finalSize, apply) = finalLayout(boundingWidth)
                    
                    return (finalSize, {
                        apply()
                        return imageNode
                    })
                })
            })
        }
    }
}

