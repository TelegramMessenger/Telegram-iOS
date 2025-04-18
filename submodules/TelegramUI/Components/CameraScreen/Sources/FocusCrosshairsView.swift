import Foundation
import UIKit

final class FocusCrosshairsView: UIView {
    private let indicatorView: UIImageView
    
    override init(frame: CGRect) {
        self.indicatorView = UIImageView()
        
        super.init(frame: frame)
        
        self.addSubview(self.indicatorView)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    func update(pointOfInterest: CGPoint) {
        
    }
}
