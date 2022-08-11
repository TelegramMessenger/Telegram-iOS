import UIKit
import SnapKit

open class GradientView: UIView {
    
    //  MARK: - UI Elements
    
    private let gradientLayer = CAGradientLayer()
    
    //  MARK: - Public Properties

    public var colors: [UIColor] {
        get { return ((gradientLayer.colors as? [CGColor]) ?? []).map({ UIColor(cgColor: $0) }) }
        set { gradientLayer.colors = newValue.map(\.cgColor) }
    }
    
    public var startPoint: CGPoint {
        get { gradientLayer.startPoint }
        set { gradientLayer.startPoint = newValue }
    }
    
    public var endPoint: CGPoint {
        get { gradientLayer.endPoint }
        set { gradientLayer.endPoint = newValue }
    }
    
    //  MARK: - Lifecycle
    
    override public init(frame: CGRect) {
        super.init(frame: frame)
        
        layer.addSublayer(gradientLayer)
    }
    
    required public init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    open override func layoutSubviews() {
        super.layoutSubviews()
        
        gradientLayer.frame = self.bounds
    }
}
