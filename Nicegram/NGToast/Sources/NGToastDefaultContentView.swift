import UIKit

open class NGToastDefaultContentView: UIView {
    private let imageView = UIImageView()
    private let label = UILabel()
    
    public override init(frame: CGRect) {
        super.init(frame: frame)
        
        imageView.contentMode = .scaleAspectFit
        imageView.tintColor = .white
        
        label.font = .systemFont(ofSize: 16, weight: .regular)
        label.textColor = .white
        label.numberOfLines = 0
        
        let stack = UIStackView(arrangedSubviews: [imageView, label])
        stack.spacing = 13
        stack.alignment = .center
        imageView.setContentHuggingPriority(.required, for: .horizontal)
        imageView.setContentCompressionResistancePriority(.required, for: .horizontal)
        
        addSubview(stack)
        stack.snp.makeConstraints { make in
            make.edges.equalToSuperview().inset(UIEdgeInsets(top: 12, left: 12, bottom: 12, right: 12))
        }
    }
    
    required public init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    open override func layoutSubviews() {
        super.layoutSubviews()
        
        layer.cornerRadius = frame.height * 12 / 68
    }
    
    public func display(image: UIImage?, title: String?) {
        imageView.image = image
        imageView.isHidden = (image == nil)
        
        label.text = title
    }
}
