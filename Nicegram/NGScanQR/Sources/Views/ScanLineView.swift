import UIKit
import SnapKit
import NGCustomViews
import NGExtensions

class ScanLineView: UIView {
    
    //  MARK: - UI Elements

    private let lineView = GradientView()
    private let shadowView = GradientView()
    
    //  MARK: - Lifecycle
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        
        lineView.colors = .defaultGradient
        lineView.startPoint = CGPoint(x: 0, y: 0.5)
        lineView.endPoint = CGPoint(x: 1, y: 0.5)
        
        shadowView.colors = [
            UIColor(red: 0.744, green: 0.332, blue: 0.928, alpha: 0.15),
            UIColor(red: 0.306, green: 0.675, blue: 0.954, alpha: 0)
        ]
        
        addSubview(lineView)
        addSubview(shadowView)
        
        lineView.snp.makeConstraints { make in
            make.leading.top.trailing.equalToSuperview()
            make.height.equalTo(1)
        }
        
        shadowView.snp.makeConstraints { make in
            make.top.equalTo(lineView.snp.bottom)
            make.leading.trailing.bottom.equalToSuperview()
        }
        
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
