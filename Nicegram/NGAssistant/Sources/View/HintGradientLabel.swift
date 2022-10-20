import UIKit

final class GradientLabel: UILabel {
    private var colors: [UIColor] = [
        UIColor(red: 0.69, green: 0.15, blue: 0.93, alpha: 1.0),
        UIColor(red: 0.11, green: 0.59, blue: 0.95, alpha: 1.0)
    ]
    private var startPoint: CGPoint = CGPoint(x: 0.0, y: 0.5)
    private var endPoint: CGPoint = CGPoint(x: 1.0, y: 0.5)
    private var textColorLayer: CAGradientLayer = CAGradientLayer()
    
    // MARK: - Life cycle
    override init(frame: CGRect) {
        super.init(frame: frame)
        setup()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setup()
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        applyColors()
    }
    
    // MARK: - Public functions
    func update(colors: [UIColor], startPoint: CGPoint, endPoint: CGPoint) {
        
        self.colors = colors
        self.startPoint = startPoint
        self.endPoint = endPoint
        applyColors()
    }
    
    // MARK: - Private functions
    private func setup() {
        
        isAccessibilityElement = true
        applyColors()
    }
    
    private func applyColors() {
        
        let gradient = getGradientLayer(bounds: self.bounds)
        textColor = gradientColor(bounds: self.bounds, gradientLayer: gradient)
    }
    
    private func getGradientLayer(bounds: CGRect) -> CAGradientLayer {
        
        textColorLayer.frame = bounds
        textColorLayer.colors = colors.map{ $0.cgColor }
        textColorLayer.startPoint = startPoint
        textColorLayer.endPoint = endPoint
        return textColorLayer
    }
}

extension UIView {
    func gradientColor(bounds: CGRect, gradientLayer: CAGradientLayer) -> UIColor? {
        UIGraphicsBeginImageContext(gradientLayer.bounds.size)
        guard let context = UIGraphicsGetCurrentContext() else {
            return nil
        }
        gradientLayer.render(in: context)
        guard let image = UIGraphicsGetImageFromCurrentImageContext() else {
            return nil
        }
        UIGraphicsEndImageContext()
        return UIColor(patternImage: image)
    }
}
