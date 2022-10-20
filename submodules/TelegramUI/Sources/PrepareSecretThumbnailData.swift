import Foundation
import UIKit
import Postbox
import Display

func prepareSecretThumbnailData(_ data: MediaResourceData) -> (CGSize, Data)? {
    if data.complete, let image = UIImage(contentsOfFile: data.path) {
        if image.size.width < 100 && image.size.height < 100 {
            if let resultData = try? Data(contentsOf: URL(fileURLWithPath: data.path)) {
                return (image.size, resultData)
            }
        }
        let scaledSize = image.size.fitted(CGSize(width: 90.0, height: 90.0))
        if let scaledImage = generateScaledImage(image: image, size: scaledSize, scale: 1.0), let scaledData = scaledImage.jpegData(compressionQuality: 0.4) {
            return (scaledSize, scaledData)
        }
    }
    return nil
}
