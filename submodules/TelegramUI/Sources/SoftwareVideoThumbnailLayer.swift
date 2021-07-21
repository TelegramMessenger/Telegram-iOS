import Foundation
import UIKit
import TelegramCore
import Postbox
import SwiftSignalKit
import Display
import PhotoResources
import TelegramPresentationData
import AsyncDisplayKit

private final class SoftwareVideoThumbnailLayerNullAction: NSObject, CAAction {
    @objc func run(forKey event: String, object anObject: Any, arguments dict: [AnyHashable : Any]?) {
    }
}

final class SoftwareVideoThumbnailNode: ASDisplayNode {
    private let usePlaceholder: Bool
    private var placeholder: MultiplexedVideoPlaceholderNode?
    private var theme: PresentationTheme?
    private var asolutePosition: (CGRect, CGSize)?
    
    var disposable = MetaDisposable()
    
    var ready: (() -> Void)? {
        didSet {
            if self.layer.contents != nil {
                self.ready?()
            }
        }
    }
    
    init(account: Account, fileReference: FileMediaReference, synchronousLoad: Bool, usePlaceholder: Bool = false, existingPlaceholder: MultiplexedVideoPlaceholderNode? = nil) {
        self.usePlaceholder = usePlaceholder
        if usePlaceholder {
            self.placeholder = existingPlaceholder
        } else {
            self.placeholder = nil
        }
        
        super.init()
        
        if !usePlaceholder {
            self.isLayerBacked = true
        }
        
        if let placeholder = self.placeholder {
            self.addSubnode(placeholder)
        }
        
        self.backgroundColor = UIColor.clear
        self.layer.contentsGravity = .resizeAspectFill
        self.layer.masksToBounds = true
        
        if let dimensions = fileReference.media.dimensions {
            self.disposable.set((mediaGridMessageVideo(postbox: account.postbox, videoReference: fileReference, synchronousLoad: synchronousLoad, nilForEmptyResult: true)
                |> deliverOnMainQueue).start(next: { [weak self] transform in
                var boundingSize = dimensions.cgSize.aspectFilled(CGSize(width: 93.0, height: 93.0))
                let imageSize = boundingSize
                boundingSize.width = min(200.0, boundingSize.width)
                
                if let image = transform(TransformImageArguments(corners: ImageCorners(), imageSize: imageSize, boundingSize: boundingSize, intrinsicInsets: UIEdgeInsets(), resizeMode: .fill(.clear)))?.generateImage() {
                    Queue.mainQueue().async {
                        if let strongSelf = self {
                            strongSelf.contents = image.cgImage
                            if let placeholder = strongSelf.placeholder {
                                strongSelf.placeholder = nil
                                placeholder.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.2, removeOnCompletion: false, completion: { [weak placeholder] _ in
                                    placeholder?.removeFromSupernode()
                                })
                            }
                            strongSelf.ready?()
                        }
                    }
                } else {
                    Queue.mainQueue().async {
                        guard let strongSelf = self else {
                            return
                        }
                        if strongSelf.usePlaceholder && strongSelf.placeholder == nil {
                            let placeholder = MultiplexedVideoPlaceholderNode()
                            strongSelf.placeholder = placeholder
                            strongSelf.addSubnode(placeholder)
                            placeholder.frame = strongSelf.bounds
                            if let theme = strongSelf.theme {
                                placeholder.update(size: strongSelf.bounds.size, theme: theme)
                            }
                            if let (absoluteRect, containerSize) = strongSelf.asolutePosition {
                                placeholder.updateAbsoluteRect(absoluteRect, within: containerSize)
                            }
                        }
                    }
                }
            }))
        }
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    deinit {
        self.disposable.dispose()
    }
    
    func update(theme: PresentationTheme, size: CGSize) {
        if self.usePlaceholder {
            self.theme = theme
        }
        if let placeholder = self.placeholder {
            placeholder.frame = CGRect(origin: CGPoint(), size: size)
            placeholder.update(size: size, theme: theme)
        }
    }
    
    func updateAbsoluteRect(_ absoluteRect: CGRect, within containerSize: CGSize) {
        self.asolutePosition = (absoluteRect, containerSize)
        if let placeholder = self.placeholder {
            placeholder.updateAbsoluteRect(absoluteRect, within: containerSize)
        }
    }
    
    /*override func action(forKey event: String) -> CAAction? {
        return SoftwareVideoThumbnailLayerNullAction()
    }*/
}
