import Foundation
import UIKit
import Display

final class AvatarLayer: SimpleLayer {
    var image: UIImage? {
        didSet {
            if let image = self.image {
                let imageSize = CGSize(width: 136.0, height: 136.0)
                let renderer = UIGraphicsImageRenderer(bounds: CGRect(origin: CGPoint(), size: imageSize), format: .preferred())
                let image = renderer.image { context in
                    context.cgContext.addEllipse(in: CGRect(origin: CGPoint(), size: imageSize))
                    context.cgContext.clip()
                    
                    context.cgContext.translateBy(x: imageSize.width * 0.5, y: imageSize.height * 0.5)
                    context.cgContext.scaleBy(x: 1.0, y: -1.0)
                    context.cgContext.translateBy(x: -imageSize.width * 0.5, y: -imageSize.height * 0.5)
                    context.cgContext.draw(image.cgImage!, in: CGRect(origin: CGPoint(), size: imageSize))
                }
                self.contents = image.cgImage
            } else {
                self.contents = nil
            }
        }
    }
    
    override init() {
        super.init()
    }
    
    override init(layer: Any) {
        super.init(layer: layer)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    func update(size: CGSize) {
    }
}
