import Foundation
import CoreGraphics

public struct MediaGridThumbnail {
    public let image: CGImage
    public let contentsRect: CGRect

    public init(image: CGImage, contentsRect: CGRect) {
        self.image = image
        self.contentsRect = contentsRect
    }

    public var pixelSize: CGFloat {
        return max(self.contentsRect.width * CGFloat(self.image.width), self.contentsRect.height * CGFloat(self.image.height))
    }

    public func contentsRect(fillingAspect aspect: CGFloat) -> CGRect {
        let rect = self.contentsRect
        let pixelWidth = rect.width * CGFloat(self.image.width)
        let pixelHeight = rect.height * CGFloat(self.image.height)
        guard aspect > 0.0, pixelWidth > 0.0, pixelHeight > 0.0 else {
            return rect
        }
        let current = pixelWidth / pixelHeight
        if current > aspect {
            let width = rect.width * aspect / current
            return CGRect(x: rect.minX + (rect.width - width) / 2.0, y: rect.minY, width: width, height: rect.height)
        } else if current < aspect {
            let height = rect.height * current / aspect
            return CGRect(x: rect.minX, y: rect.minY + (rect.height - height) / 2.0, width: rect.width, height: height)
        }
        return rect
    }
}
