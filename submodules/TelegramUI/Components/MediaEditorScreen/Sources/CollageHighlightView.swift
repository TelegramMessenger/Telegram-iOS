import Foundation
import UIKit
import Display

final class CollageHighlightView: UIView {
    private let borderLayer = SimpleLayer()
    private let gradientView = UIImageView()
    
    override public init(frame: CGRect) {
        super.init(frame: frame)
                
        self.borderLayer.cornerRadius = 12.0
        self.borderLayer.borderWidth = 4.0
        self.borderLayer.borderColor = UIColor.white.cgColor
        
        self.layer.mask = self.borderLayer
        
        self.addSubview(self.gradientView)
    }
    
    required public init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
        
    func update(size: CGSize, corners: CACornerMask, completion: @escaping () -> Void) {
        self.borderLayer.maskedCorners = corners
        self.borderLayer.frame = CGRect(origin: .zero, size: size)
        
        let color = UIColor.white.withAlphaComponent(0.7)
        
        let gradientWidth = size.width * 3.0
        self.gradientView.image = generateGradientImage(
            size: CGSize(width: gradientWidth, height: 24.0),
            colors: [UIColor.white.withAlphaComponent(0.0), color, color, color, UIColor.white.withAlphaComponent(0.0)],
            locations: [0.0, 0.2, 0.5, 0.8, 1.0],
            direction: .horizontal
        )
        
        self.gradientView.frame = CGRect(origin: CGPoint(x: -gradientWidth, y: 0.0), size: CGSize(width: gradientWidth, height: size.height))
        self.gradientView.layer.animatePosition(from: .zero, to: CGPoint(x: gradientWidth * 2.0, y: 0.0), duration: 1.4, additive: true, completion: { _ in
            completion()
        })
    }
}
