import UIKit

public extension UIImage {
    func convertedToJpeg(compressionQuality: CGFloat = 1) -> UIImage {
        guard let jpegData = jpegData(compressionQuality: compressionQuality) else {
            return self
        }
        return UIImage(data: jpegData) ?? self
    }
}
