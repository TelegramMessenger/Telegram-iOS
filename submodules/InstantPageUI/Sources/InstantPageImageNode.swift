import Foundation
import UIKit
import AsyncDisplayKit
import Display
import Postbox
import TelegramCore
import SwiftSignalKit
import TelegramPresentationData
import AccountContext
import RadialStatusNode
import PhotoResources
import MediaResources
import LocationResources
import LiveLocationPositionNode
import AppBundle
import TelegramUIPreferences
import ContextUI

private struct FetchControls {
    let fetch: (Bool) -> Void
    let cancel: () -> Void
}

final class InstantPageImageNode: ASDisplayNode, InstantPageNode {
    private let context: AccountContext
    private let webPage: TelegramMediaWebpage
    private var theme: InstantPageTheme
    let media: InstantPageMedia
    let attributes: [InstantPageImageAttribute]
    private let interactive: Bool
    private let roundCorners: Bool
    private let fit: Bool
    private let openMedia: (InstantPageMedia) -> Void
    private let longPressMedia: (InstantPageMedia) -> Void
    
    private var fetchControls: FetchControls?

    private let pinchContainerNode: PinchSourceContainerNode
    private let imageNode: TransformImageNode
    private let statusNode: RadialStatusNode
    private let linkIconNode: ASImageNode
    private let pinNode: ChatMessageLiveLocationPositionNode
    
    private var currentSize: CGSize?
    
    private var fetchStatus: MediaResourceStatus?
    private var fetchedDisposable = MetaDisposable()
    private var statusDisposable = MetaDisposable()
    
    private var themeUpdated: Bool = false
    
    init(context: AccountContext, sourcePeerType: MediaAutoDownloadPeerType, theme: InstantPageTheme, webPage: TelegramMediaWebpage, media: InstantPageMedia, attributes: [InstantPageImageAttribute], interactive: Bool, roundCorners: Bool, fit: Bool, openMedia: @escaping (InstantPageMedia) -> Void, longPressMedia: @escaping (InstantPageMedia) -> Void, activatePinchPreview: ((PinchSourceContainerNode) -> Void)?, pinchPreviewFinished: ((InstantPageNode) -> Void)?) {
        self.context = context
        self.theme = theme
        self.webPage = webPage
        self.media = media
        self.attributes = attributes
        self.interactive = interactive
        self.roundCorners = roundCorners
        self.fit = fit
        self.openMedia = openMedia
        self.longPressMedia = longPressMedia

        self.pinchContainerNode = PinchSourceContainerNode()
        self.imageNode = TransformImageNode()
        self.statusNode = RadialStatusNode(backgroundNodeColor: UIColor(white: 0.0, alpha: 0.6))
        self.linkIconNode = ASImageNode()
        self.pinNode = ChatMessageLiveLocationPositionNode()
        
        super.init()

        self.pinchContainerNode.contentNode.addSubnode(self.imageNode)
        self.addSubnode(self.pinchContainerNode)
        
        if let image = media.media as? TelegramMediaImage, let largest = largestImageRepresentation(image.representations) {
            let imageReference = ImageMediaReference.webPage(webPage: WebpageReference(webPage), media: image)
            self.imageNode.setSignal(chatMessagePhoto(postbox: context.account.postbox, photoReference: imageReference))
            
            if !interactive || shouldDownloadMediaAutomatically(settings: context.sharedContext.currentAutomaticMediaDownloadSettings.with { $0 }, peerType: sourcePeerType, networkType: MediaAutoDownloadNetworkType(context.account.immediateNetworkType), authorPeerId: nil, contactsPeerIds: Set(), media: image) {
                self.fetchedDisposable.set(chatMessagePhotoInteractiveFetched(context: context, photoReference: imageReference, displayAtSize: nil, storeToDownloadsPeerType: nil).start())
            }
            
            self.fetchControls = FetchControls(fetch: { [weak self] manual in
                if let strongSelf = self {
                    strongSelf.fetchedDisposable.set(chatMessagePhotoInteractiveFetched(context: context, photoReference: imageReference, displayAtSize: nil, storeToDownloadsPeerType: nil).start())
                }
            }, cancel: {
                chatMessagePhotoCancelInteractiveFetch(account: context.account, photoReference: imageReference)
            })
            
            if interactive {
                self.statusDisposable.set((context.account.postbox.mediaBox.resourceStatus(largest.resource) |> deliverOnMainQueue).start(next: { [weak self] status in
                    displayLinkDispatcher.dispatch {
                        if let strongSelf = self {
                            strongSelf.fetchStatus = status
                            strongSelf.updateFetchStatus()
                        }
                    }
                }))
                
                if media.url != nil {
                    self.linkIconNode.image = UIImage(bundleImageName: "Instant View/ImageLink")
                    self.pinchContainerNode.contentNode.addSubnode(self.linkIconNode)
                }

                self.pinchContainerNode.contentNode.addSubnode(self.statusNode)
            }
        } else if let file = media.media as? TelegramMediaFile {
            let fileReference = FileMediaReference.webPage(webPage: WebpageReference(webPage), media: file)
            if file.mimeType.hasPrefix("image/") {
                if !interactive || shouldDownloadMediaAutomatically(settings: context.sharedContext.currentAutomaticMediaDownloadSettings.with { $0 }, peerType: sourcePeerType, networkType: MediaAutoDownloadNetworkType(context.account.immediateNetworkType), authorPeerId: nil, contactsPeerIds: Set(), media: file) {
                    _ = freeMediaFileInteractiveFetched(account: context.account, fileReference: fileReference).start()
                }
                self.imageNode.setSignal(instantPageImageFile(account: context.account, fileReference: fileReference, fetched: true))
            } else {
                self.imageNode.setSignal(chatMessageVideo(postbox: context.account.postbox, videoReference: fileReference))
            }
            if file.isVideo {
                self.statusNode.transitionToState(.play(.white), animated: false, completion: {})
                self.pinchContainerNode.contentNode.addSubnode(self.statusNode)
            }
        } else if let map = media.media as? TelegramMediaMap {
            self.addSubnode(self.pinNode)

            var dimensions = CGSize(width: 200.0, height: 100.0)
            for attribute in self.attributes {
                if let mapAttribute = attribute as? InstantPageMapAttribute {
                    dimensions = mapAttribute.dimensions
                    break
                }
            }
            let resource = MapSnapshotMediaResource(latitude: map.latitude, longitude: map.longitude, width: Int32(dimensions.width), height: Int32(dimensions.height))
            self.imageNode.setSignal(chatMapSnapshotImage(engine: context.engine, resource: resource))
        } else if let webPage = media.media as? TelegramMediaWebpage, case let .Loaded(content) = webPage.content, let image = content.image {
            let imageReference = ImageMediaReference.webPage(webPage: WebpageReference(webPage), media: image)
            self.imageNode.setSignal(chatMessagePhoto(postbox: context.account.postbox, photoReference: imageReference))
            self.fetchedDisposable.set(chatMessagePhotoInteractiveFetched(context: context, photoReference: imageReference, displayAtSize: nil, storeToDownloadsPeerType: nil).start())
            self.statusNode.transitionToState(.play(.white), animated: false, completion: {})
            self.pinchContainerNode.contentNode.addSubnode(self.statusNode)
        }

        if let activatePinchPreview = activatePinchPreview {
            self.pinchContainerNode.activate = { sourceNode in
                activatePinchPreview(sourceNode)
            }
            self.pinchContainerNode.animatedOut = { [weak self] in
                guard let strongSelf = self else {
                    return
                }
                pinchPreviewFinished?(strongSelf)
            }
        }
    }
    
    deinit {
        self.fetchedDisposable.dispose()
        self.statusDisposable.dispose()
    }
    
    override func didLoad() {
        super.didLoad()
        
        if self.interactive {
            let recognizer = TapLongTapOrDoubleTapGestureRecognizer(target: self, action: #selector(self.tapGesture(_:)))
            recognizer.delaysTouchesBegan = false
            self.view.addGestureRecognizer(recognizer)
        } else {
            self.view.isUserInteractionEnabled = false
        }
    }
    
    func updateIsVisible(_ isVisible: Bool) {    
    }
    
    func updateLayout(size: CGSize, transition: ContainedViewLayoutTransition) {
    }
    
    func update(strings: PresentationStrings, theme: InstantPageTheme) {
        if self.theme.imageTintColor != theme.imageTintColor {
            self.theme = theme
            self.themeUpdated = true
            self.setNeedsLayout()
        }
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
        
        if self.currentSize != size || self.themeUpdated {
            self.currentSize = size
            self.themeUpdated = false

            self.pinchContainerNode.frame = CGRect(origin: CGPoint(), size: size)
            self.pinchContainerNode.update(size: size, transition: .immediate)
            self.imageNode.frame = CGRect(origin: CGPoint(), size: size)
            
            let radialStatusSize: CGFloat = 50.0
            self.statusNode.frame = CGRect(x: floorToScreenPixels((size.width - radialStatusSize) / 2.0), y: floorToScreenPixels((size.height - radialStatusSize) / 2.0), width: radialStatusSize, height: radialStatusSize)
            
            if let image = self.media.media as? TelegramMediaImage, let largest = largestImageRepresentation(image.representations) {
                let imageSize = largest.dimensions.cgSize.aspectFilled(size)
                let boundingSize = size
                let radius: CGFloat = self.roundCorners ? floor(min(imageSize.width, imageSize.height) / 2.0) : 0.0
                let makeLayout = self.imageNode.asyncLayout()
                let apply = makeLayout(TransformImageArguments(corners: ImageCorners(radius: radius), imageSize: imageSize, boundingSize: boundingSize, intrinsicInsets: UIEdgeInsets(), emptyColor: self.theme.panelBackgroundColor))
                apply()
                
                self.linkIconNode.frame = CGRect(x: size.width - 38.0, y: 14.0, width: 24.0, height: 24.0)
            } else if let file = self.media.media as? TelegramMediaFile, let dimensions = file.dimensions {
                let emptyColor = file.mimeType.hasPrefix("image/") ? self.theme.imageTintColor : nil

                let imageSize = dimensions.cgSize.aspectFilled(size)
                let boundingSize = size
                let makeLayout = self.imageNode.asyncLayout()
                let apply = makeLayout(TransformImageArguments(corners: ImageCorners(), imageSize: imageSize, boundingSize: boundingSize, intrinsicInsets: UIEdgeInsets(), emptyColor: emptyColor))
                apply()
            } else if self.media.media is TelegramMediaMap {
                for attribute in self.attributes {
                    if let mapAttribute = attribute as? InstantPageMapAttribute {
                        let imageSize = mapAttribute.dimensions.aspectFilled(size)
                        let boundingSize = size
                        let radius: CGFloat = self.roundCorners ? floor(min(imageSize.width, imageSize.height) / 2.0) : 0.0
                        let makeLayout = self.imageNode.asyncLayout()
                        let apply = makeLayout(TransformImageArguments(corners: ImageCorners(radius: radius), imageSize: imageSize, boundingSize: boundingSize, intrinsicInsets: UIEdgeInsets()))
                        apply()
                        break
                    }
                }
                
                let makePinLayout = self.pinNode.asyncLayout()
                let theme = self.context.sharedContext.currentPresentationData.with { $0 }.theme
                let (pinSize, pinApply) = makePinLayout(self.context, theme, .location(nil))
                self.pinNode.frame = CGRect(origin: CGPoint(x: floor((size.width - pinSize.width) / 2.0), y: floor(size.height * 0.5 - 10.0 - pinSize.height / 2.0)), size: pinSize)
                pinApply()
            } else if let webPage = media.media as? TelegramMediaWebpage, case let .Loaded(content) = webPage.content, let image = content.image, let largest = largestImageRepresentation(image.representations) {
                let imageSize = largest.dimensions.cgSize.aspectFilled(size)
                let boundingSize = size
                let radius: CGFloat = self.roundCorners ? floor(min(imageSize.width, imageSize.height) / 2.0) : 0.0
                let makeLayout = self.imageNode.asyncLayout()
                let apply = makeLayout(TransformImageArguments(corners: ImageCorners(radius: radius), imageSize: imageSize, boundingSize: boundingSize, intrinsicInsets: UIEdgeInsets(), emptyColor: self.theme.pageBackgroundColor))
                apply()
            }
        }
    }
    
    func transitionNode(media: InstantPageMedia) -> (ASDisplayNode, CGRect, () -> (UIView?, UIView?))? {
        if media == self.media {
            let imageNode = self.imageNode
            return (self.imageNode, self.imageNode.bounds, { [weak imageNode] in
                return (imageNode?.view.snapshotContentTree(unhide: true), nil)
            })
        } else {
            return nil
        }
    }
    
    func updateHiddenMedia(media: InstantPageMedia?) {
        self.imageNode.isHidden = self.media == media
        self.statusNode.isHidden = self.imageNode.isHidden
    }
    
    @objc private func tapGesture(_ recognizer: TapLongTapOrDoubleTapGestureRecognizer) {
        switch recognizer.state {
            case .ended:
                if let (gesture, _) = recognizer.lastRecognizedGestureAndLocation {
                    if let fetchStatus = self.fetchStatus {
                        switch fetchStatus {
                            case .Local:
                                switch gesture {
                                    case .tap:
                                        if self.media.media is TelegramMediaImage && self.media.index == -1 {
                                            return
                                        }
                                        self.openMedia(self.media)
                                    case .longTap:
                                        self.longPressMedia(self.media)
                                    default:
                                        break
                                }
                            case .Remote, .Paused:
                                if case .tap = gesture {
                                    self.fetchControls?.fetch(true)
                                }
                            case .Fetching:
                                if case .tap = gesture {
                                    self.fetchControls?.cancel()
                                }
                        }
                    } else {
                        switch gesture {
                            case .tap:
                                if self.media.media is TelegramMediaImage && self.media.index == -1 {
                                    return
                                }
                                self.openMedia(self.media)
                            case .longTap:
                                self.longPressMedia(self.media)
                            default:
                                break
                        }
                    }
                }
            default:
                break
        }
    }
}
