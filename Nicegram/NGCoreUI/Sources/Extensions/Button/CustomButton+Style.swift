import NGImageContainer
import UIKit

public extension CustomButton {
    func applyStyle(font: UIFont?, foregroundColor: UIColor, backgroundColor: UIColor, cornerRadius: CGFloat, spacing: CGFloat, insets: UIEdgeInsets, imagePosition: CustomButton.ImagePosition, imageSizeStrategy: ImageContainer.ImageSizeStrategy) {
        self.foregroundColor = foregroundColor
        self.backgroundColor = backgroundColor
        self.layer.cornerRadius = cornerRadius
        self.spacing = spacing
        self.insets = insets
        self.imagePosition = imagePosition
        self.imageSizeStrategy = imageSizeStrategy
        
        configureTitleLabel { l in
            if let font {
                l.font = font
            }
        }
    }
}

public extension ImageContainer.ImageSizeStrategy {
    static func size(width: CGFloat, height: CGFloat) -> ImageContainer.ImageSizeStrategy {
        return .size(CGSize(width: width, height: height))
    }
}
