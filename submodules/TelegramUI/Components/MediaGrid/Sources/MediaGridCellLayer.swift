import Foundation
import UIKit
import QuartzCore

public enum MediaGridCellDetail {
    case full
    case compact
}

open class MediaGridCellLayer: CALayer {
    public private(set) var index: Int = -1

    var imageRequest: MediaGridImageRequest?
    var bindingToken: Int = 0
    var hasFinalImage = false
    var requestedQuality: MediaGridImageQuality = .full

    public override init() {
        super.init()
        self.masksToBounds = true
        self.contentsGravity = .resizeAspectFill
    }

    public override init(layer: Any) {
        super.init(layer: layer)
        if let other = layer as? MediaGridCellLayer {
            self.index = other.index
        }
    }

    public required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    open override func action(forKey event: String) -> CAAction? {
        return NSNull()
    }

    open func bind(index: Int, detail: MediaGridCellDetail) {
        self.index = index
    }

    open func setSelected(_ selected: Bool) {
    }

    open func setImage(_ image: UIImage?) {
        self.contentsGravity = .resizeAspectFill
        if let image {
            self.contentsScale = image.scale
            self.contents = image.cgImage
        } else {
            self.contents = nil
        }
    }

    open func prepareForReuse() {
        self.imageRequest?.cancel()
        self.imageRequest = nil
        self.bindingToken += 1
        self.hasFinalImage = false
        self.contents = nil
    }
}
