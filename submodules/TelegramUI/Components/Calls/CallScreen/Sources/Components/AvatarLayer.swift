import Foundation
import UIKit
import Display
import ComponentFlow

final class AvatarLayer: SimpleLayer {
    struct Params: Equatable {
        var size: CGSize
        var cornerRadius: CGFloat
        var isExpanded: Bool
        
        init(size: CGSize, cornerRadius: CGFloat, isExpanded: Bool) {
            self.size = size
            self.cornerRadius = cornerRadius
            self.isExpanded = isExpanded
        }
    }
    
    private(set) var params: Params?
    private var rasterizedImage: UIImage?
    private var isAnimating: Bool = false
    
    var image: UIImage? {
        didSet {
            if self.image !== oldValue {
                self.updateImage()
            }
        }
    }
    
    override init() {
        super.init()
        
        self.contentsGravity = .resizeAspectFill
        self.masksToBounds = true
    }
    
    override init(layer: Any) {
        super.init(layer: layer)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func updateImage() {
        guard let params else {
            return
        }
        
        if self.isAnimating || params.isExpanded {
            self.contents = self.image?.cgImage
        } else {
            self.contents = self.image.flatMap({ image -> UIImage? in
                let imageSize = CGSize(width: min(params.size.width, params.size.height), height: min(params.size.width, params.size.height))
                
                return generateImage(imageSize, contextGenerator: { size, context in
                    context.clear(CGRect(origin: CGPoint(), size: size))
                    if params.cornerRadius == size.width * 0.5 {
                        context.addEllipse(in: CGRect(origin: CGPoint(), size: size))
                    } else {
                        context.addPath(UIBezierPath(roundedRect: CGRect(origin: CGPoint(), size: size), cornerRadius: params.cornerRadius).cgPath)
                    }
                    context.clip()
                    
                    if let cgImage = image.cgImage {
                        context.draw(cgImage, in: CGRect(origin: CGPoint(), size: size))
                    }
                })
            })?.cgImage
        }
    }
    
    func update(size: CGSize, isExpanded: Bool, cornerRadius: CGFloat, transition: ComponentTransition) {
        let params = Params(size: size, cornerRadius: cornerRadius, isExpanded: isExpanded)
        if self.params == params {
            return
        }
        let previousCornerRadius = self.params?.cornerRadius
        self.params = params
        
        if previousCornerRadius != params.cornerRadius {
            self.masksToBounds = true
            self.isAnimating = true
            self.updateImage()
            
            if let previousCornerRadius, self.animation(forKey: "cornerRadius") == nil {
                self.cornerRadius = previousCornerRadius
            }
            transition.setCornerRadius(layer: self, cornerRadius: cornerRadius, completion: { [weak self] completed in
                guard let self, completed else {
                    return
                }
                
                self.isAnimating = false
                self.masksToBounds = false
                self.cornerRadius = 0.0
                
                self.updateImage()
            })
        }
    }
}
