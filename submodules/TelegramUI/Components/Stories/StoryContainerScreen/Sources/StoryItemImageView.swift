import Foundation
import UIKit
import AccountContext
import TelegramCore
import Postbox
import SwiftSignalKit
import ComponentFlow
import TinyThumbnail
import ImageBlur
import MediaResources
import Display

final class StoryItemImageView: UIView {
    private let contentView: UIImageView
    private var captureProtectedContentLayer: CaptureProtectedContentLayer?
    
    private var currentMedia: EngineMedia?
    private var disposable: Disposable?
    private var fetchDisposable: Disposable?
    
    private(set) var isContentLoaded: Bool = false
    var didLoadContents: (() -> Void)?
    
    private var isCaptureProtected: Bool = false
    
    override init(frame: CGRect) {
        self.contentView = UIImageView()
        self.contentView.contentMode = .scaleAspectFill
        
        super.init(frame: frame)
        
        self.addSubview(self.contentView)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    deinit {
        self.disposable?.dispose()
    }
    
    private func updateImage(image: UIImage) {
        if self.isCaptureProtected {
            let captureProtectedContentLayer: CaptureProtectedContentLayer
            if let current = self.captureProtectedContentLayer {
                captureProtectedContentLayer = current
            } else {
                captureProtectedContentLayer = CaptureProtectedContentLayer()
                
                captureProtectedContentLayer.videoGravity = .resizeAspectFill
                if #available(iOS 13.0, *) {
                    captureProtectedContentLayer.preventsCapture = true
                    captureProtectedContentLayer.preventsDisplaySleepDuringVideoPlayback = false
                }
                
                captureProtectedContentLayer.frame = self.contentView.frame
                self.captureProtectedContentLayer = captureProtectedContentLayer
                self.layer.addSublayer(captureProtectedContentLayer)
            }
            if let cmSampleBuffer = image.cmSampleBuffer {
                captureProtectedContentLayer.enqueue(cmSampleBuffer)
            }
        } else {
            self.contentView.image = image
        }
    }
    
    func update(context: AccountContext, peer: EnginePeer, storyId: Int32, media: EngineMedia, size: CGSize, isCaptureProtected: Bool, attemptSynchronous: Bool, transition: Transition) {
        self.isCaptureProtected = isCaptureProtected
        
        var dimensions: CGSize?
        
        let isMediaUpdated: Bool
        if let currentMedia = self.currentMedia {
            isMediaUpdated = !currentMedia._asMedia().isSemanticallyEqual(to: media._asMedia())
        } else {
            isMediaUpdated = true
        }
        
        switch media {
        case let .image(image):
            if let representation = largestImageRepresentation(image.representations) {
                dimensions = representation.dimensions.cgSize
                
                if isMediaUpdated {
                    if attemptSynchronous, let path = context.account.postbox.mediaBox.completedResourcePath(id: representation.resource.id, pathExtension: nil) {
                        if #available(iOS 15.0, *) {
                            if let image = UIImage(contentsOfFile: path)?.preparingForDisplay() {
                                self.updateImage(image: image)
                            }
                        } else {
                            if let image = UIImage(contentsOfFile: path)?.precomposed() {
                                self.updateImage(image: image)
                            }
                        }
                        self.isContentLoaded = true
                        self.didLoadContents?()
                    } else {
                        if let thumbnailData = image.immediateThumbnailData.flatMap(decodeTinyThumbnail), let thumbnailImage = UIImage(data: thumbnailData) {
                            self.contentView.image = blurredImage(thumbnailImage, radius: 10.0, iterations: 3)
                        }
                        
                        if let peerReference = PeerReference(peer._asPeer()) {
                            self.fetchDisposable = fetchedMediaResource(mediaBox: context.account.postbox.mediaBox, userLocation: .peer(peer.id), userContentType: .image, reference: .media(media: .story(peer: peerReference, id: storyId, media: media._asMedia()), resource: representation.resource), ranges: nil).start()
                        }
                        self.disposable = (context.account.postbox.mediaBox.resourceData(representation.resource, option: .complete(waitUntilFetchStatus: false))
                        |> map { result -> UIImage? in
                            if result.complete {
                                if #available(iOS 15.0, *) {
                                    if let image = UIImage(contentsOfFile: result.path)?.preparingForDisplay() {
                                        return image
                                    } else {
                                        return nil
                                    }
                                } else {
                                    if let image = UIImage(contentsOfFile: result.path)?.precomposed() {
                                        return image
                                    } else {
                                        return nil
                                    }
                                }
                            } else {
                                return nil
                            }
                        }
                        |> deliverOnMainQueue).start(next: { [weak self] image in
                            guard let self else {
                                return
                            }
                            if let image {
                                self.updateImage(image: image)
                                self.isContentLoaded = true
                                self.didLoadContents?()
                            }
                        })
                    }
                }
            }
        case let .file(file):
            dimensions = file.dimensions?.cgSize
            
            if isMediaUpdated {
                let cachedPath = context.account.postbox.mediaBox.cachedRepresentationCompletePath(file.resource.id, representation: CachedVideoFirstFrameRepresentation())
                
                if attemptSynchronous, FileManager.default.fileExists(atPath: cachedPath) {
                    if #available(iOS 15.0, *) {
                        if let image = UIImage(contentsOfFile: cachedPath)?.preparingForDisplay() {
                            self.updateImage(image: image)
                        }
                    } else {
                        if let image = UIImage(contentsOfFile: cachedPath)?.precomposed() {
                            self.updateImage(image: image)
                        }
                    }
                    self.isContentLoaded = true
                    self.didLoadContents?()
                } else {
                    if let thumbnailData = file.immediateThumbnailData.flatMap(decodeTinyThumbnail), let thumbnailImage = UIImage(data: thumbnailData) {
                        self.contentView.image = blurredImage(thumbnailImage, radius: 10.0, iterations: 3)
                    }
                    
                    self.disposable = (context.account.postbox.mediaBox.cachedResourceRepresentation(file.resource, representation: CachedVideoFirstFrameRepresentation(), complete: true, fetch: true, attemptSynchronously: false)
                    |> map { result -> UIImage? in
                        if result.complete {
                            if #available(iOS 15.0, *) {
                                if let image = UIImage(contentsOfFile: result.path)?.preparingForDisplay() {
                                    return image
                                } else {
                                    return nil
                                }
                            } else {
                                if let image = UIImage(contentsOfFile: result.path)?.precomposed() {
                                    return image
                                } else {
                                    return nil
                                }
                            }
                        } else {
                            return nil
                        }
                    }
                    |> deliverOnMainQueue).start(next: { [weak self] image in
                        guard let self else {
                            return
                        }
                        if let image {
                            self.updateImage(image: image)
                            self.isContentLoaded = true
                            self.didLoadContents?()
                        }
                    })
                }
            }
        default:
            break
        }
        self.currentMedia = media
        
        if let dimensions {
            let filledSize = dimensions.aspectFilled(size)
            let contentFrame = CGRect(origin: CGPoint(x: floor((size.width - filledSize.width) * 0.5), y: floor((size.height - filledSize.height) * 0.5)), size: filledSize)
            transition.setFrame(view: self.contentView, frame: contentFrame)
            
            if let captureProtectedContentLayer = self.captureProtectedContentLayer {
                transition.setFrame(layer: captureProtectedContentLayer, frame: contentFrame)
            }
        }
    }
}
