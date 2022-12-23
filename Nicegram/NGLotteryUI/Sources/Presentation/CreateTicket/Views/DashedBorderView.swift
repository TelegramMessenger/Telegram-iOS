import SnapKit
import UIKit

class DashedBorderView: UIView {
    
    //  MARK: - UI Elements

    private let wrappedView: UIView
    private let borderLayer: CAShapeLayer
    
    //  MARK: - Logic
    
    private let cornerRadius: CGFloat
    
    //  MARK: - Lifecycle
    
    init(wrappedVew: UIView, cornerRadius: CGFloat) {
        self.wrappedView = wrappedVew
        self.cornerRadius = cornerRadius
        self.borderLayer = CAShapeLayer()
        
        super.init(frame: .zero)
        
        addSubview(wrappedVew)
        wrappedVew.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
        
        borderLayer.strokeColor = UIColor.white.withAlphaComponent(0.15).cgColor
        borderLayer.lineDashPattern = [5, 5]
        borderLayer.fillColor = nil
        self.layer.addSublayer(borderLayer)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        
        borderLayer.frame = self.bounds
        borderLayer.path = UIBezierPath(roundedRect: self.bounds, cornerRadius: self.cornerRadius).cgPath
    }
}
