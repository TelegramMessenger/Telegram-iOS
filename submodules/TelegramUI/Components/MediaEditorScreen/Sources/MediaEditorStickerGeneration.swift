import Foundation
import UIKit
import CoreImage
import Vision
import ImagePlayground
import SwiftSignalKit
import ImageTransparency
import MediaEditor

@available(iOS 17.0, *)
private func cutoutSubject(from cgImage: CGImage) -> UIImage? {
    let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
    let request = VNGenerateForegroundInstanceMaskRequest()
    guard let _ = try? handler.perform([request]), let observation = request.results?.first else {
        return nil
    }
    guard let pixelBuffer = try? observation.generateMaskedImage(ofInstances: observation.allInstances, from: handler, croppedToInstancesExtent: true) else {
        return nil
    }
    let ciImage = CIImage(cvPixelBuffer: pixelBuffer)
    guard let result = CIContext(options: nil).createCGImage(ciImage, from: ciImage.extent) else {
        return nil
    }
    return UIImage(cgImage: result)
}

private func stickerContent(from image: UIImage) -> DrawingStickerEntity.Content? {
    guard let cgImage = image.cgImage else {
        return nil
    }
    if imageHasTransparency(image) {
        return .image(image, .sticker)
    }
    if #available(iOS 17.0, *), let cutout = cutoutSubject(from: cgImage) {
        return .image(cutout, .sticker)
    }
    return .image(image, .rectangle)
}

@available(iOS 18.1, *)
private final class StickerPlaygroundDelegate: NSObject, ImagePlaygroundViewController.Delegate {
    private let completion: (URL?) -> Void

    init(completion: @escaping (URL?) -> Void) {
        self.completion = completion
    }

    func imagePlaygroundViewController(_ imagePlaygroundViewController: ImagePlaygroundViewController, didCreateImageAt imageURL: URL) {
        imagePlaygroundViewController.dismiss(animated: true)
        self.completion(imageURL)
    }

    func imagePlaygroundViewControllerDidCancel(_ imagePlaygroundViewController: ImagePlaygroundViewController) {
        imagePlaygroundViewController.dismiss(animated: true)
        self.completion(nil)
    }
}

private var stickerPlaygroundDelegateKey: UInt8 = 0

extension MediaEditorScreenImpl {
    func presentStickerGeneration(completion: @escaping (DrawingStickerEntity.Content) -> Void) {
        guard #available(iOS 18.1, *), ImagePlaygroundViewController.isAvailable else {
            return
        }
        let playgroundController = ImagePlaygroundViewController()
        playgroundController.overrideUserInterfaceStyle = .dark
        let delegate = StickerPlaygroundDelegate(completion: { url in
            guard let url else {
                return
            }
            let _ = (Signal<DrawingStickerEntity.Content?, NoError> { subscriber in
                let content = UIImage(contentsOfFile: url.path).flatMap(stickerContent(from:))
                subscriber.putNext(content)
                subscriber.putCompletion()
                return EmptyDisposable
            }
            |> runOn(Queue.concurrentDefaultQueue())
            |> deliverOnMainQueue).start(next: { content in
                if let content {
                    completion(content)
                }
            })
        })
        objc_setAssociatedObject(playgroundController, &stickerPlaygroundDelegateKey, delegate, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
        playgroundController.delegate = delegate
        self.view.window?.rootViewController?.present(playgroundController, animated: true)
    }
}
