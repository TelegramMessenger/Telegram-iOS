import UIKit
import SwiftSignalKit
import LegacyComponents
import Display
import WebPBinding

private func scaleImage(_ image: UIImage, size: CGSize, boundiingSize: CGSize) -> UIImage? {
    if #available(iOSApplicationExtension 10.0, iOS 10.0, *) {
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1.0
        let renderer = UIGraphicsImageRenderer(size: size, format: format)
        return renderer.image { _ in
            image.draw(in: CGRect(origin: .zero, size: size))
        }
    } else {
        return TGScaleImageToPixelSize(image, size)
    }
}

func convertToWebP(image: UIImage, targetSize: CGSize?, targetBoundingSize: CGSize?, quality: CGFloat) -> Signal<Data, NoError> {
    var image = image
    if let targetSize = targetSize, let scaledImage = scaleImage(image, size: targetSize, boundiingSize: targetSize) {
        image = scaledImage
    }
    
    return Signal { subscriber in
        if let data = try? WebP.convert(toWebP: image, quality: quality * 100.0) {
            subscriber.putNext(data)
        }
        subscriber.putCompletion()
        
        return EmptyDisposable
    } |> runOn(Queue.concurrentDefaultQueue())
}
