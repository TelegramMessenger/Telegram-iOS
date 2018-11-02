import Foundation
import AsyncDisplayKit
import Display
import Postbox
import TelegramCore
import SwiftSignalKit

final class InstantPageImageNode: ASDisplayNode, InstantPageNode {
    private let account: Account
    let media: InstantPageMedia
    let attributes: [InstantPageImageAttribute]
    let url: InstantPageUrlItem?
    private let interactive: Bool
    private let roundCorners: Bool
    private let fit: Bool
    private let openMedia: (InstantPageMedia) -> Void
    private let openUrl: (InstantPageUrlItem) -> Void
    
    private let imageNode: TransformImageNode
    private let pinNode: ChatMessageLiveLocationPositionNode
    
    private var currentSize: CGSize?
    
    private var fetchedDisposable = MetaDisposable()
    
    init(account: Account, webPage: TelegramMediaWebpage, media: InstantPageMedia, attributes: [InstantPageImageAttribute], url: InstantPageUrlItem? = nil, interactive: Bool, roundCorners: Bool, fit: Bool, openMedia: @escaping (InstantPageMedia) -> Void, openUrl: @escaping (InstantPageUrlItem) -> Void = { _ in }) {
        self.account = account
        self.media = media
        self.attributes = attributes
        self.url = url
        self.interactive = interactive
        self.roundCorners = roundCorners
        self.fit = fit
        self.openMedia = openMedia
        self.openUrl = openUrl
        
        self.imageNode = TransformImageNode()
        self.pinNode = ChatMessageLiveLocationPositionNode()
        
        super.init()
        
        self.addSubnode(self.imageNode)
        
        if let image = media.media as? TelegramMediaImage {
            let imageReference = ImageMediaReference.webPage(webPage: WebpageReference(webPage), media: image)
            self.imageNode.setSignal(chatMessagePhoto(postbox: account.postbox, photoReference: imageReference))
            self.fetchedDisposable.set(chatMessagePhotoInteractiveFetched(account: account, photoReference: imageReference, storeToDownloadsPeerType: nil).start())
        } else if let file = media.media as? TelegramMediaFile {
            let fileReference = FileMediaReference.webPage(webPage: WebpageReference(webPage), media: file)
            if file.mimeType.hasPrefix("image/") {
                _ = freeMediaFileInteractiveFetched(account: account, fileReference: fileReference).start()
                self.imageNode.setSignal(chatMessageImageFile(account: account, fileReference: fileReference, thumbnail: false, fetched: true))
            } else {
                self.imageNode.setSignal(chatMessageVideo(postbox: account.postbox, videoReference: fileReference))
            }
        } else if let map = media.media as? TelegramMediaMap {
            self.addSubnode(self.pinNode)
            
            var zoom: Int32 = 12
            var dimensions = CGSize(width: 200, height: 100)
            for attribute in self.attributes {
                if let mapAttribute = attribute as? InstantPageMapAttribute {
                    zoom = mapAttribute.zoom
                    dimensions = mapAttribute.dimensions
                    break
                }
            }
            let resource = MapSnapshotMediaResource(latitude: map.latitude, longitude: map.longitude, width: Int32(dimensions.width), height: Int32(dimensions.height))
            self.imageNode.setSignal(chatMapSnapshotImage(account: account, resource: resource))
        }
    }
    
    deinit {
        self.fetchedDisposable.dispose()
    }
    
    override func didLoad() {
        super.didLoad()
        
        if self.interactive {
            self.view.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(self.tapGesture(_:))))
        }
    }
    
    func updateIsVisible(_ isVisible: Bool) {    
    }
    
    func update(strings: PresentationStrings, theme: InstantPageTheme) {
    }
    
    override func layout() {
        super.layout()
        
        let size = self.bounds.size
        
        if self.currentSize != size {
            self.currentSize = size
            
            self.imageNode.frame = CGRect(origin: CGPoint(), size: size)
            
            if let image = self.media.media as? TelegramMediaImage, let largest = largestImageRepresentation(image.representations) {
                let imageSize = largest.dimensions.aspectFilled(size)
                let boundingSize = size
                let radius: CGFloat = self.roundCorners ? floor(min(imageSize.width, imageSize.height) / 2.0) : 0.0
                let makeLayout = self.imageNode.asyncLayout()
                let apply = makeLayout(TransformImageArguments(corners: ImageCorners(radius: radius), imageSize: imageSize, boundingSize: boundingSize, intrinsicInsets: UIEdgeInsets()))
                apply()
            } else if let file = self.media.media as? TelegramMediaFile, let dimensions = file.dimensions {
                let imageSize = dimensions.aspectFilled(size)
                let boundingSize = size
                let makeLayout = self.imageNode.asyncLayout()
                let apply = makeLayout(TransformImageArguments(corners: ImageCorners(), imageSize: imageSize, boundingSize: boundingSize, intrinsicInsets: UIEdgeInsets()))
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
                let theme = self.account.telegramApplicationContext.currentPresentationData.with { $0 }.theme
                let (pinSize, pinApply) = makePinLayout(self.account, theme, nil, false)
                self.pinNode.frame = CGRect(origin: CGPoint(x: floor((size.width - pinSize.width) / 2.0), y: floor(size.height * 0.5 - 10.0 - pinSize.height / 2.0)), size: pinSize)
                pinApply()
            }
        }
    }
    
    func transitionNode(media: InstantPageMedia) -> (ASDisplayNode, () -> UIView?)? {
        if media == self.media {
            let imageNode = self.imageNode
            return (self.imageNode, { [weak imageNode] in
                return imageNode?.view.snapshotContentTree(unhide: true)
            })
        } else {
            return nil
        }
    }
    
    func updateHiddenMedia(media: InstantPageMedia?) {
        self.imageNode.isHidden = self.media == media
    }
    
    @objc func tapGesture(_ recognizer: UITapGestureRecognizer) {
        if case .ended = recognizer.state {
            if let url = self.url {
                self.openUrl(url)
            } else {
                self.openMedia(self.media)
            }
        }
    }
}
