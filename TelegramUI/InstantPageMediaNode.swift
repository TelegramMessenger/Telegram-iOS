import Foundation
import AsyncDisplayKit
import Display
import Postbox
import TelegramCore
import SwiftSignalKit

final class InstantPageMediaNode: ASDisplayNode, InstantPageNode {
    private let account: Account
    let media: InstantPageMedia
    private let arguments: InstantPageMediaArguments
    
    private let imageNode: TransformImageNode
    
    private var currentSize: CGSize?
    
    private var fetchedDisposable = MetaDisposable()
    
    init(account: Account, media: InstantPageMedia, arguments: InstantPageMediaArguments) {
        self.account = account
        self.media = media
        self.arguments = arguments
        
        self.imageNode = TransformImageNode()
        
        super.init()
        
        self.imageNode.alphaTransitionOnFirstUpdate = true
        self.addSubnode(self.imageNode)
        
        if let image = media.media as? TelegramMediaImage {
            self.imageNode.setSignal(account: account, signal: chatMessagePhoto(account: account, photo: image))
            self.fetchedDisposable.set(chatMessagePhotoInteractiveFetched(account: account, photo: image).start())
        }
    }
    
    deinit {
        self.fetchedDisposable.dispose()
    }
    
    func updateIsVisible(_ isVisible: Bool) {
        
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
                var radius: CGFloat = 0.0
                
                switch arguments {
                    case let .image(_, roundCorners, fit):
                        radius = roundCorners ? floor(min(size.width, size.height) / 2.0) : 0.0
                    default:
                        break
                }
                let makeLayout = self.imageNode.asyncLayout()
                let apply = makeLayout(TransformImageArguments(corners: ImageCorners(), imageSize: imageSize, boundingSize: boundingSize, intrinsicInsets: UIEdgeInsets()))
                apply()
            }
        }
    }
}

/*- (void)layoutSubviews {
    [super layoutSubviews];
    
    CGSize size = self.bounds.size;
    _button.frame = self.bounds;
    CGSize overlaySize = _overlayView.bounds.size;
    _overlayView.frame = CGRectMake(CGFloor((size.width - overlaySize.width) / 2.0f), CGFloor((size.height - overlaySize.height) / 2.0f), overlaySize.width, overlaySize.height);
    _imageView.frame = self.bounds;
    
    _videoView.frame = self.bounds;
    
    if (!CGSizeEqualToSize(_currentSize, size)) {
        _currentSize = size;
        
        if ([_media.media isKindOfClass:[TGImageMediaAttachment class]]) {
            TGImageMediaAttachment *image = _media.media;
            CGSize imageSize = TGFillSize([image dimensions], size);
            CGSize boundingSize = size;
            
            CGFloat radius = 0.0f;
            if ([_arguments isKindOfClass:[TGInstantPageImageMediaArguments class]]) {
                TGInstantPageImageMediaArguments *imageArguments = (TGInstantPageImageMediaArguments *)_arguments;
                if (imageArguments.fit) {
                    _imageView.contentMode = UIViewContentModeScaleAspectFit;
                    imageSize = TGFitSize([image dimensions], size);
                    boundingSize = imageSize;
                }
                radius = imageArguments.roundCorners ? CGFloor(MIN(size.width, size.height) / 2.0f) : 0.0f;
            }
            [_imageView setArguments:[[TransformImageArguments alloc] initWithImageSize:imageSize boundingSize:boundingSize cornerRadius:radius]];
        } else if ([_media.media isKindOfClass:[TGVideoMediaAttachment class]]) {
            TGVideoMediaAttachment *video = _media.media;
            CGSize imageSize = TGFillSize([video dimensions], size);
            [_imageView setArguments:[[TransformImageArguments alloc] initWithImageSize:imageSize boundingSize:size cornerRadius:0.0f]];
        }
    }
}*/
