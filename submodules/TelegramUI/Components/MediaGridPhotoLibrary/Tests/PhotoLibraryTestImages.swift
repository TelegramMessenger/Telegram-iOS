import UIKit

enum PhotoLibraryTestImages {
    static let sampleImage: UIImage = {
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1.0
        return UIGraphicsImageRenderer(size: CGSize(width: 1.0, height: 1.0), format: format).image { context in
            UIColor.gray.setFill()
            context.fill(CGRect(x: 0.0, y: 0.0, width: 1.0, height: 1.0))
        }
    }()

    static func distinctImage(_ value: Int, side: CGFloat = 2.0) -> UIImage {
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1.0
        return UIGraphicsImageRenderer(size: CGSize(width: side, height: side), format: format).image { context in
            UIColor(white: CGFloat(value % 256) / 255.0, alpha: 1.0).setFill()
            context.fill(CGRect(x: 0.0, y: 0.0, width: side, height: side))
        }
    }
}
