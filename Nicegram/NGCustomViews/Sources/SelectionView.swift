import UIKit
import SnapKit

open class SelectionView: UIView {
    
    public struct State {
        let backgroundColor: UIColor
        let borderColor: UIColor
        let image: UIImage?
    }
    
    //  MARK: - UI Elements
    
    private let imageView = UIImageView()
    
    //  MARK: - Logic
    
    public var state: State = .normal {
        didSet {
            setState(state)
        }
    }
    
    //  MARK: - Lifecycle
    
    override public init(frame: CGRect) {
        super.init(frame: frame)
        
        layer.borderWidth = 1
        
        imageView.contentMode = .scaleAspectFit
        imageView.tintColor = .white
        
        addSubview(imageView)
        imageView.snp.makeConstraints { make in
            make.center.equalToSuperview()
        }
        
        snp.makeConstraints { make in
            make.size.equalTo(CGSize(width: 21.5, height: 21.5))
        }
    }
    
    required public init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    open override func layoutSubviews() {
        super.layoutSubviews()
        
        layer.cornerRadius = frame.height / 2
    }
    
    //  MARK: - Private Functions
    
    private func setState(_ state: State) {
        backgroundColor = state.backgroundColor
        layer.borderColor = state.borderColor.cgColor
        imageView.image = state.image
    }
}

public extension SelectionView.State {
    static var normal: SelectionView.State {
        return .init(backgroundColor: .clear, borderColor: .ngDarkGrey, image: nil)
    }
    
    static var selected: SelectionView.State {
        return .init(backgroundColor: .ngGreenTwo, borderColor: .clear, image: UIImage(named: "ng.checkmark"))
    }
}
