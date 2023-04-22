import Foundation
import UIKit
import AsyncDisplayKit
import Display
import TelegramCore
import SwiftSignalKit
import TelegramPresentationData
import AccountContext
import RadialStatusNode
import GalleryUI
import TelegramUniversalVideoContent

private struct FetchControls {
    let fetch: (Bool) -> Void
    let cancel: () -> Void
}

final class InstantPagePlayableVideoNode: ASDisplayNode, InstantPageNode, GalleryItemTransitionNode {
    private let context: AccountContext
    let media: InstantPageMedia
    let userLocation: MediaResourceUserLocation
    private let interactive: Bool
    private let openMedia: (InstantPageMedia) -> Void
    private var fetchControls: FetchControls?
    
    private let videoNode: UniversalVideoNode
    private let statusNode: RadialStatusNode
    
    private var currentSize: CGSize?
    
    private var fetchStatus: EngineMediaResource.FetchStatus?
    private var fetchedDisposable = MetaDisposable()
    private var statusDisposable = MetaDisposable()
    
    private var localIsVisible = false
    
    public var decoration: UniversalVideoDecoration? {
        return nil
    }
    
    init(context: AccountContext, userLocation: MediaResourceUserLocation, webPage: TelegramMediaWebpage, theme: InstantPageTheme, media: InstantPageMedia, interactive: Bool, openMedia: @escaping (InstantPageMedia) -> Void) {
        self.context = context
        self.userLocation = userLocation
        self.media = media
        self.interactive = interactive
        self.openMedia = openMedia
        
        var imageReference: ImageMediaReference?
        if case let .file(file) = media.media, let presentation = smallestImageRepresentation(file.previewRepresentations) {
            let image = TelegramMediaImage(imageId: EngineMedia.Id(namespace: 0, id: 0), representations: [presentation], immediateThumbnailData: file.immediateThumbnailData, reference: nil, partialReference: nil, flags: [])
            imageReference = ImageMediaReference.webPage(webPage: WebpageReference(webPage), media: image)
        }
        
        var streamVideo = false
        var fileValue: TelegramMediaFile?
        if case let .file(file) = media.media {
            streamVideo = isMediaStreamable(media: file)
            fileValue = file
        }
        
        self.videoNode = UniversalVideoNode(postbox: context.account.postbox, audioSession: context.sharedContext.mediaManager.audioSession, manager: context.sharedContext.mediaManager.universalVideoManager, decoration: GalleryVideoDecoration(), content: NativeVideoContent(id: .instantPage(webPage.webpageId, media.media.id!), userLocation: userLocation, fileReference: .webPage(webPage: WebpageReference(webPage), media: fileValue!), imageReference: imageReference, streamVideo: streamVideo ? .conservative : .none, loopVideo: true, enableSound: false, fetchAutomatically: true, placeholderColor: theme.pageBackgroundColor, storeAfterDownload: nil), priority: .embedded, autoplay: true)
        self.videoNode.isUserInteractionEnabled = false
        
        self.statusNode = RadialStatusNode(backgroundNodeColor: UIColor(white: 0.0, alpha: 0.6))
        
        super.init()
        
        self.addSubnode(self.videoNode)
        
        if case let .file(file) = media.media {
            self.fetchedDisposable.set(fetchedMediaResource(mediaBox: context.account.postbox.mediaBox, userLocation: userLocation, userContentType: .video, reference: AnyMediaReference.webPage(webPage: WebpageReference(webPage), media: file).resourceReference(file.resource)).start())
            
            self.statusDisposable.set((context.account.postbox.mediaBox.resourceStatus(file.resource) |> deliverOnMainQueue).start(next: { [weak self] status in
                displayLinkDispatcher.dispatch {
                    if let strongSelf = self {
                        strongSelf.fetchStatus = EngineMediaResource.FetchStatus(status)
                        strongSelf.updateFetchStatus()
                    }
                }
            }))
        }
    }
    
    deinit {
        self.fetchedDisposable.dispose()
    }
    
    func isAvailableForGalleryTransition() -> Bool {
        return true
    }
    
    func isAvailableForInstantPageTransition() -> Bool {
        return true
    }
    
    override func didLoad() {
        super.didLoad()
        
        if self.interactive {
            self.view.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(self.tapGesture(_:))))
        }
    }
    
    func updateIsVisible(_ isVisible: Bool) {
        if self.localIsVisible != isVisible {
            self.localIsVisible = isVisible
            
            self.videoNode.canAttachContent = isVisible
        }
    }
    
    func updateLayout(size: CGSize, transition: ContainedViewLayoutTransition) {
    }
    
    func update(strings: PresentationStrings, theme: InstantPageTheme) {
    }
    
    private func updateFetchStatus() {
        var state: RadialStatusNodeState = .none
        if let fetchStatus = self.fetchStatus {
            switch fetchStatus {
                case let .Fetching(_, progress):
                    let adjustedProgress = max(progress, 0.027)
                    state = .progress(color: .white, lineWidth: nil, value: CGFloat(adjustedProgress), cancelEnabled: true, animateRotation: true)
                case .Remote:
                    state = .download(.white)
                default:
                    break
            }
        }
        self.statusNode.transitionToState(state, completion: { [weak statusNode] in
            if state == .none {
                statusNode?.removeFromSupernode()
            }
        })
    }
    
    override func layout() {
        super.layout()
        
        let size = self.bounds.size
        
        if self.currentSize != size {
            self.currentSize = size
            
            self.videoNode.frame = CGRect(origin: CGPoint(), size: size)
            self.videoNode.updateLayout(size: size, transition: .immediate)
            
            let radialStatusSize: CGFloat = 50.0
            self.statusNode.frame = CGRect(x: floorToScreenPixels((size.width - radialStatusSize) / 2.0), y: floorToScreenPixels((size.height - radialStatusSize) / 2.0), width: radialStatusSize, height: radialStatusSize)
        }
    }
    
    func transitionNode(media: InstantPageMedia) -> (ASDisplayNode, CGRect, () -> (UIView?, UIView?))? {
        if media == self.media {
            return (self, self.bounds, { [weak self] in
                return (self?.view.snapshotContentTree(unhide: true), nil)
            })
        } else {
            return nil
        }
    }
    
    func updateHiddenMedia(media: InstantPageMedia?) {
        self.videoNode.isHidden = self.media == media
    }
    
    @objc func tapGesture(_ recognizer: UITapGestureRecognizer) {
        if case .ended = recognizer.state, let fetchStatus = self.fetchStatus {
            switch fetchStatus {
                case .Local:
                    self.openMedia(self.media)
                case .Remote, .Paused:
                    self.fetchControls?.fetch(true)
                case .Fetching:
                    self.fetchControls?.cancel()
            }
        }
    }
}
