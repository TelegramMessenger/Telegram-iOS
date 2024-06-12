import Foundation
import UIKit
import Display
import ComponentFlow

final class RoundedCornersView: UIImageView {
    private let color: UIColor
    private let smoothCorners: Bool
    
    private var currentCornerRadius: CGFloat?
    private var cornerImage: UIImage?
    
    init(color: UIColor, smoothCorners: Bool = false) {
        self.color = color
        self.smoothCorners = smoothCorners
        
        super.init(image: nil)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func applyStaticCornerRadius() {
        guard let cornerRadius = self.currentCornerRadius else {
            return
        }
        if cornerRadius == 0.0 {
            if let cornerImage = self.cornerImage, cornerImage.size.width == 1.0 {
            } else {
                self.cornerImage = generateImage(CGSize(width: 1.0, height: 1.0), rotatedContext: { size, context in
                    context.setFillColor(self.color.cgColor)
                    context.fill(CGRect(origin: CGPoint(), size: size))
                })?.stretchableImage(withLeftCapWidth: Int(cornerRadius) + 5, topCapHeight: Int(cornerRadius) + 5)
            }
        } else {
            if self.smoothCorners {
                let size = CGSize(width: cornerRadius * 2.0 + 10.0, height: cornerRadius * 2.0 + 10.0)
                if let cornerImage = self.cornerImage, cornerImage.size == size {
                } else {
                    self.cornerImage = generateImage(size, rotatedContext: { size, context in
                        context.clear(CGRect(origin: CGPoint(), size: size))
                        context.addPath(UIBezierPath(roundedRect: CGRect(origin: CGPoint(), size: size), cornerRadius: cornerRadius).cgPath)
                        context.setFillColor(self.color.cgColor)
                        context.fillPath()
                    })?.stretchableImage(withLeftCapWidth: Int(cornerRadius) + 5, topCapHeight: Int(cornerRadius) + 5)
                }
            } else {
                let size = CGSize(width: cornerRadius * 2.0, height: cornerRadius * 2.0)
                if let cornerImage = self.cornerImage, cornerImage.size == size {
                } else {
                    self.cornerImage = generateStretchableFilledCircleImage(diameter: size.width, color: self.color)
                }
            }
        }
        self.image = self.cornerImage
        self.clipsToBounds = false
        self.backgroundColor = nil
        self.layer.cornerRadius = 0.0
    }
    
    func update(cornerRadius: CGFloat, transition: ComponentTransition) {
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
            if #available(iOS 13.0, *) {
                if self.smoothCorners {
                    self.layer.cornerCurve = .continuous
                } else {
                    self.layer.cornerCurve = .circular
                }
                    
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
