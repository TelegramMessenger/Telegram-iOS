import UIKit
import SnapKit
import NGButton

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

public extension CustomButton {
    func setGradientBackground(
        colors: [UIColor],
        startPoint: CGPoint = CGPoint(x: 0, y: 0.5),
        endPoint: CGPoint = CGPoint(x: 1, y: 0.5)
    ) {
        let gradientView = GradientView()
        gradientView.colors = colors
        gradientView.startPoint = startPoint
        gradientView.endPoint = endPoint
        self.backgroundView = gradientView
    }
}
