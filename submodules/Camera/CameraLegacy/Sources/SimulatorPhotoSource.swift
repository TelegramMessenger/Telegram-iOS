#if targetEnvironment(simulator)
import Foundation
import UIKit
import SwiftSignalKit
import Camera

private let simulatorPhotoCounter = Atomic<Int>(value: 0)

func simulatorSyntheticPhoto(position: Camera.Position) -> Signal<PhotoCaptureResult, NoError> {
    let index = simulatorPhotoCounter.modify { $0 + 1 }
    let isFront = position == .front
    return Signal<PhotoCaptureResult, NoError>.single(.began)
    |> then(
        Signal<PhotoCaptureResult, NoError> { subscriber in
            let image = simulatorSyntheticPhotoImage(index: index, mirrored: isFront)
            subscriber.putNext(.finished(image, nil, CACurrentMediaTime()))
            subscriber.putCompletion()
            return EmptyDisposable
        }
        |> runOn(Queue.concurrentDefaultQueue())
        |> delay(0.3, queue: Queue.concurrentDefaultQueue())
    )
}

private func simulatorSyntheticPhotoImage(index: Int, mirrored: Bool) -> UIImage {
    let size = CGSize(width: 1080.0, height: 1440.0)
    let hues: [CGFloat] = [0.0, 0.08, 0.16, 0.33, 0.5, 0.6, 0.75, 0.88]
    let hue = hues[(index - 1) % hues.count]
    let format = UIGraphicsImageRendererFormat()
    format.scale = 1.0
    format.opaque = true
    return UIGraphicsImageRenderer(size: size, format: format).image { rendererContext in
        let context = rendererContext.cgContext
        if mirrored {
            context.translateBy(x: size.width, y: 0.0)
            context.scaleBy(x: -1.0, y: 1.0)
        }
        let colors = [UIColor(hue: hue, saturation: 0.8, brightness: 0.95, alpha: 1.0).cgColor, UIColor(hue: hue, saturation: 0.9, brightness: 0.35, alpha: 1.0).cgColor] as CFArray
        var locations: [CGFloat] = [0.0, 1.0]
        if let gradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: colors, locations: &locations) {
            context.drawLinearGradient(gradient, start: .zero, end: CGPoint(x: size.width, y: size.height), options: [])
        }
        let text = "\(index)" as NSString
        let attributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 520.0, weight: .bold),
            .foregroundColor: UIColor(white: 1.0, alpha: 0.9)
        ]
        let textSize = text.size(withAttributes: attributes)
        text.draw(at: CGPoint(x: (size.width - textSize.width) / 2.0, y: (size.height - textSize.height) / 2.0), withAttributes: attributes)
    }
}
#endif
