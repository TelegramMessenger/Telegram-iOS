import UIKit
import NGExtensions

class ScanView: UIView {
    
    //  MARK: - UI Elements

    private let imageView = UIImageView()
    
    //  MARK: - UI Elements
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        
        imageView.image = UIImage(named: "ScanQR")
        
        addSubview(imageView)
        imageView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
