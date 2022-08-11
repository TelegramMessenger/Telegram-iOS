import UIKit
import SnapKit

open class ImageContainer: UIView {
    
    public enum ImageSizeStrategy {
        case auto
        case size(CGSize)
    }
    
    //  MARK: - UI Elements

    private let imageView = UIImageView()
    
    //  MARK: - Public Properties

    public var imageSizeStrategy = ImageSizeStrategy.auto {
        didSet {
            updateImageSizeConstraint()
        }
    }
    
    open override var tintColor: UIColor! {
        didSet {
            imageView.tintColor = tintColor
        }
    }
    
    //  MARK: - Private Properties

    private var imageSizeConstraint: Constraint?
    
    //  MARK: - Lifecycle
    
    override public init(frame: CGRect) {
        super.init(frame: frame)
        
        imageView.contentMode = .scaleAspectFit
        imageView.tintColor = .white
        
        addSubview(imageView)
        
        imageView.snp.makeConstraints { make in
            make.center.equalToSuperview()
            make.leading.top.greaterThanOrEqualToSuperview()
            self.imageSizeConstraint = make.size.equalTo(CGSize.zero).priority(.high).constraint
        }
        updateImageSizeConstraint()
        
        snp.makeConstraints { make in
            make.width.height.equalTo(1).priority(1)
        }
    }
    
    required public init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    open override var intrinsicContentSize: CGSize {
        return imageView.intrinsicContentSize
    }
    
    //  MARK: - Public Functions
    
    open func display(image: UIImage?, backgroundColor: UIColor?) {
        imageView.image = image
        if let backgroundColor = backgroundColor {
            self.backgroundColor = backgroundColor
        }
    }
    
    open func configureImageView(_ c: (UIImageView) -> ()) {
        c(imageView)
    }
    
    //  MARK: - Private Functions

    private func updateImageSizeConstraint() {
        switch imageSizeStrategy {
        case .auto:
            NSLayoutConstraint.deactivate(imageSizeConstraint?.layoutConstraints ?? [])
        case .size(let cgSize):
            imageView.snp.updateConstraints { make in
                self.imageSizeConstraint = make.size.equalTo(cgSize).priority(.high).constraint
            }
            NSLayoutConstraint.activate(imageSizeConstraint?.layoutConstraints ?? [])
        }
    }
}
