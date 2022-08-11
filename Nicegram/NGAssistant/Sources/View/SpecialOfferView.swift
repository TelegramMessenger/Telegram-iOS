import UIKit
import SnapKit
import NGCustomViews

struct SpecialOfferViewModel {
    let id: String
    let image: UIImage?
    let title: String
}

class SpecialOfferView: UIControl {
    
    //  MARK: - UI Elements

    private let gradientView = GradientView()
    private let imageView = UIImageView()
    private let titleLabel = UILabel()
    private let arrowImageView = UIImageView()
    
    //  MARK: - Handlers
    
    var onTap: (() -> ())?
    
    //  MARK: - Lifecycle
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        
        self.addTarget(self, action: #selector(tapped), for: .touchUpInside)
        
        layer.cornerRadius = 10
        clipsToBounds = true
        
        gradientView.colors = .defaultGradient
        gradientView.startPoint = CGPoint(x: 0, y: 0.5)
        gradientView.endPoint = CGPoint(x: 1, y: 0.5)
        
        imageView.tintColor = .white
        imageView.contentMode = .scaleAspectFit
        
        titleLabel.font = .systemFont(ofSize: 16, weight: .semibold)
        titleLabel.textColor = .white
        
        arrowImageView.image = UIImage(named: "ng.item.arrow")?.withRenderingMode(.alwaysTemplate)
        arrowImageView.contentMode = .scaleAspectFit
        arrowImageView.tintColor = UIColor(hexString: "#DFDFE0")
        
        let stack = UIStackView(arrangedSubviews: [imageView, titleLabel, arrowImageView])
        stack.spacing = 12
        stack.alignment = .center
        
        addSubview(gradientView)
        addSubview(stack)
        
        gradientView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
        
        stack.snp.makeConstraints { make in
            make.top.bottom.trailing.equalToSuperview().inset(16)
            make.leading.equalToSuperview().inset(12)
        }
        
        arrowImageView.snp.makeConstraints {
            $0.height.equalTo(15.0)
            $0.width.equalTo(8.5)
        }
        
        imageView.snp.contentHuggingHorizontalPriority = 1000
        arrowImageView.snp.contentHuggingHorizontalPriority = 1000
        
        arrowImageView.snp.contentCompressionResistanceHorizontalPriority = 750
        imageView.snp.contentCompressionResistanceHorizontalPriority = 749
        titleLabel.snp.contentCompressionResistanceHorizontalPriority = 748
    }
    
    required init?(coder: NSCoder) {
        fatalError()
    }
    
    override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        return self.point(inside: point, with: event) ? self : nil
    }
    
    //  MARK: - Public Functions

    func display(_ item: SpecialOfferViewModel) {
        imageView.image = item.image
        imageView.isHidden = (item.image == nil)
        
        titleLabel.text = item.title
    }
}

private extension SpecialOfferView {
    @objc func tapped() {
        onTap?()
    }
}
