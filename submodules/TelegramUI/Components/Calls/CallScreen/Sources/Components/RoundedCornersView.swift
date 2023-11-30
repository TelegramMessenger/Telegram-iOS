import Foundation
import UIKit
import Display
import ComponentFlow

final class RoundedCornersView: UIImageView {
    private let color: UIColor
    private var currentCornerRadius: CGFloat?
    private var cornerImage: UIImage?
    
    init(color: UIColor) {
        self.color = color
        
        super.init(image: nil)
        
        if #available(iOS 13.0, *) {
            self.layer.cornerCurve = .circular
        }
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func applyStaticCornerRadius() {
        guard let cornerRadius = self.currentCornerRadius else {
            return
        }
        if let cornerImage = self.cornerImage, cornerImage.size.height == cornerRadius * 2.0 {
        } else {
            let size = CGSize(width: cornerRadius * 2.0, height: cornerRadius * 2.0)
            self.cornerImage = generateStretchableFilledCircleImage(diameter: size.width, color: self.color)
        }
        self.image = self.cornerImage
        self.clipsToBounds = false
        self.backgroundColor = nil
        self.layer.cornerRadius = 0.0
    }
    
    func update(cornerRadius: CGFloat, transition: Transition) {
        if self.currentCornerRadius == cornerRadius {
            return
        }
        let previousCornerRadius = self.currentCornerRadius
        self.currentCornerRadius = cornerRadius
        if transition.animation.isImmediate {
            self.applyStaticCornerRadius()
        } else {
            self.image = nil
            self.clipsToBounds = true
            self.backgroundColor = self.color
            if let previousCornerRadius, self.layer.animation(forKey: "cornerRadius") == nil {
                self.layer.cornerRadius = previousCornerRadius
            }
            transition.setCornerRadius(layer: self.layer, cornerRadius: cornerRadius, completion: { [weak self] completed in
                guard let self, completed else {
                    return
                }
                self.applyStaticCornerRadius()
            })
        }
    }
}
