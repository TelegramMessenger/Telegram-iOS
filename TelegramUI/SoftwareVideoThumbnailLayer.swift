import Foundation
import UIKit
import TelegramCore
import Postbox
import SwiftSignalKit

final class SoftwareVideoThumbnailLayer: CALayer {
    var disposable: Disposable?
    
    var ready: (() -> Void)? {
        didSet {
            if self.contents != nil {
                self.ready?()
            }
        }
    }
    
    init(account: Account, fileReference: FileMediaReference) {
        super.init()
        
        self.backgroundColor = UIColor.clear.cgColor
        self.contentsGravity = "resizeAspectFill"
        self.masksToBounds = true
        
        if let dimensions = fileReference.media.dimensions {
            self.disposable = (mediaGridMessageVideo(postbox: account.postbox, videoReference: fileReference) |> deliverOn(account.graphicsThreadPool)).start(next: { [weak self] transform in
                var boundingSize = dimensions.aspectFilled(CGSize(width: 93.0, height: 93.0))
                let imageSize = boundingSize
                boundingSize.width = min(200.0, boundingSize.width)
                
                if let image = transform(TransformImageArguments(corners: ImageCorners(), imageSize: imageSize, boundingSize: boundingSize, intrinsicInsets: UIEdgeInsets(), resizeMode: .fill(.clear)))?.generateImage() {
                    Queue.mainQueue().async {
                        if let strongSelf = self {
                            strongSelf.contents = image.cgImage
                            strongSelf.ready?()
                        }
                    }
                }
            })
        }
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    deinit {
        self.disposable?.dispose()
    }
    
    override func action(forKey event: String) -> CAAction? {
        return NSNull()
    }
}
