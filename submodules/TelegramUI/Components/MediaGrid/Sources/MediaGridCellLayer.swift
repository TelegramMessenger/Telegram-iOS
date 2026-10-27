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
    private(set) var shownPixelWidth: CGFloat = 0.0
    private(set) var thumbnailPixelSize: CGFloat = 0.0

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
        self.contentsGravity = .resizeAspectFill
        self.contentsRect = rect
        self.contents = thumbnail.image
        self.isShowingThumbnail = true
        self.shownPixelWidth = rect.width * CGFloat(thumbnail.image.width)
        self.thumbnailPixelSize = thumbnail.pixelSize
    }

    open func setImage(_ image: UIImage?) {
        guard let image, let cgImage = image.cgImage else {
            self.clearImage()
            return
        }
        let width = MediaGridCellLayer.visiblePixelWidth(width: CGFloat(cgImage.width), height: CGFloat(cgImage.height), in: self.bounds.size)
        if self.isShowingThumbnail && width <= self.shownPixelWidth {
            return
        }
        self.contentsGravity = .resizeAspectFill
        self.contentsRect = CGRect(x: 0.0, y: 0.0, width: 1.0, height: 1.0)
        self.contentsScale = image.scale
        self.contents = cgImage
        self.isShowingThumbnail = false
        self.shownPixelWidth = width
        self.thumbnailPixelSize = 0.0
    }

    var sharpImage: UIImage? {
        guard !self.isShowingThumbnail, let contents = self.contents, CFGetTypeID(contents as CFTypeRef) == CGImage.typeID else {
            return nil
        }
        return UIImage(cgImage: contents as! CGImage, scale: self.contentsScale, orientation: .up)
    }

    static func visiblePixelWidth(width: CGFloat, height: CGFloat, in size: CGSize) -> CGFloat {
        guard size.width > 0.0, size.height > 0.0 else {
            return width
        }
        return min(width, height * size.width / size.height)
    }

    private func clearImage() {
        self.contents = nil
        self.contentsRect = CGRect(x: 0.0, y: 0.0, width: 1.0, height: 1.0)
        self.isShowingThumbnail = false
        self.shownPixelWidth = 0.0
        self.thumbnailPixelSize = 0.0
    }

    open func prepareForReuse() {
        self.imageRequest?.cancel()
        self.imageRequest = nil
        self.bindingToken += 1
        self.hasFinalImage = false
        self.isAwaitingSharpImage = false
        self.clearImage()
    }
}
