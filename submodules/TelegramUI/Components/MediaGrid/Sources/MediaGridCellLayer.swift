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
    var isAwaitingSharpImage = false
    public private(set) var isShowingThumbnail = false
    public internal(set) var isBinding = false
    public internal(set) var imageRequestTime: CFTimeInterval = 0.0
    private(set) var sharpImage: UIImage?
    private(set) var isImageStale = false
    private(set) var thumbnailPixelWidth: CGFloat = 0.0
    private(set) var thumbnailPixelSize: CGFloat = 0.0
    private(set) var launchCoverage: CGFloat = 0.0

    public var displayedImage: UIImage? {
        return self.sharpImage
    }

    var hasImage: Bool {
        return self.isShowingThumbnail || self.sharpImage != nil
    }

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

    open func setThumbnail(_ thumbnail: MediaGridThumbnail, cellAspect: CGFloat) {
        let rect = thumbnail.contentsRect(fillingAspect: cellAspect)
        self.contentsRect = rect
        if !self.isShowingThumbnail || (self.contents as AnyObject?) !== thumbnail.image {
            self.contents = thumbnail.image
        }
        self.isShowingThumbnail = true
        self.sharpImage = nil
        self.launchCoverage = 0.0
        self.isImageStale = false
        self.thumbnailPixelWidth = rect.width * CGFloat(thumbnail.image.width)
        self.thumbnailPixelSize = thumbnail.pixelSize
    }

    open func setImage(_ image: UIImage?) {
        guard let image, let cgImage = image.cgImage else {
            self.clearImage()
            return
        }
        if self.isShowingThumbnail && MediaGridCellLayer.visiblePixelWidth(of: image, in: self.bounds.size) <= self.thumbnailPixelWidth {
            return
        }
        if self.isShowingThumbnail {
            self.contentsRect = CGRect(x: 0.0, y: 0.0, width: 1.0, height: 1.0)
        }
        self.contentsScale = image.scale
        self.contents = cgImage
        self.isShowingThumbnail = false
        self.sharpImage = image
        self.launchCoverage = 0.0
        self.isImageStale = false
        self.thumbnailPixelWidth = 0.0
        self.thumbnailPixelSize = 0.0
    }

    func setLaunchImage(_ launchImage: MediaGridLaunchImage) {
        self.isShowingThumbnail = false
        self.thumbnailPixelWidth = 0.0
        self.thumbnailPixelSize = 0.0
        self.setImage(UIImage(cgImage: launchImage.image, scale: 1.0, orientation: .up))
        self.launchCoverage = CGFloat(launchImage.coveredPixelWidth)
    }

    func shownPixelWidth(in size: CGSize) -> CGFloat {
        if self.isShowingThumbnail {
            return self.thumbnailPixelWidth
        }
        if let sharpImage = self.sharpImage {
            return MediaGridCellLayer.visiblePixelWidth(of: sharpImage, in: size)
        }
        return 0.0
    }

    func accepts(_ image: UIImage, isDegraded: Bool, in size: CGSize, targetPixelWidth: CGFloat) -> Bool {
        guard self.hasImage, !self.isImageStale else {
            return true
        }
        let width = MediaGridCellLayer.visiblePixelWidth(of: image, in: size)
        if self.isShowingThumbnail {
            return width > self.thumbnailPixelWidth
        }
        let current = min(self.shownPixelWidth(in: size), targetPixelWidth)
        return isDegraded ? width > current : width >= current
    }

    func markImageStale() {
        self.isImageStale = true
    }

    func resetBinding() {
        if let request = self.imageRequest {
            self.imageRequest = nil
            request.cancel()
        }
        self.bindingToken += 1
        self.hasFinalImage = false
        self.isAwaitingSharpImage = false
    }

    static func visiblePixelWidth(of image: UIImage, in size: CGSize) -> CGFloat {
        let width = image.size.width * image.scale
        let height = image.size.height * image.scale
        guard size.width > 0.0, size.height > 0.0 else {
            return width
        }
        return min(width, height * size.width / size.height)
    }

    func clearImage() {
        self.contents = nil
        self.contentsRect = CGRect(x: 0.0, y: 0.0, width: 1.0, height: 1.0)
        self.isShowingThumbnail = false
        self.sharpImage = nil
        self.launchCoverage = 0.0
        self.isImageStale = false
        self.thumbnailPixelWidth = 0.0
        self.thumbnailPixelSize = 0.0
    }

    open func prepareForReuse() {
    }
}
