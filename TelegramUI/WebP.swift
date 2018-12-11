import UIKit
import SwiftSignalKit
import LegacyComponents
import Display

private func scaleImage(_ image: UIImage, dimensions: CGSize) -> UIImage? {
    if #available(iOSApplicationExtension 10.0, *) {
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1.0
        let renderer = UIGraphicsImageRenderer(size: dimensions, format: format)
        return renderer.image { _ in
            image.draw(in: CGRect(origin: .zero, size: dimensions))
        }
    } else {
        return TGScaleImageToPixelSize(image, dimensions)
    }
}

func convertToWebP(image: UIImage, targetSize: CGSize?, quality: CGFloat) -> Signal<Data, NoError> {
    var image = image
    if let targetSize = targetSize, let scaledImage = scaleImage(image, dimensions: targetSize) {
        image = scaledImage
    }
    
    return Signal { subscriber in
        let context = DrawingContext(size: image.size, scale: 0.0, clear: true)
        context.withFlippedContext({ context in
            if let cgImage = image.cgImage {
                context.draw(cgImage, in: CGRect(x: 0.0, y: 0.0, width: image.size.width, height: image.size.height))
            }
        })
        let processedImage = context.generateImage()!
        if let data = try? UIImage.convert(toWebP: processedImage, quality: quality * 100.0) {
            subscriber.putNext(data)
        }
        subscriber.putCompletion()
        
        return EmptyDisposable
    } |> runOn(Queue.concurrentDefaultQueue())
}
