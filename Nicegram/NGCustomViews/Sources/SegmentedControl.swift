import UIKit

open class NGSegmentedControl: UISegmentedControl {
    
    //  MARK: - Public Properties
    
    public var cornersRoundingPercentage: CGFloat = 8 / 28 {
        didSet {
            layoutIfNeeded()
        }
    }
    
    public var selectedSegmentImage: UIImage? = UIImage(color: .ngDarkGrey) {
        didSet {
            layoutIfNeeded()
        }
    }
    
    public var segmentInset: CGFloat = 6 {
        didSet {
            layoutIfNeeded()
        }
    }
    
    public var valueChanged: ((Int) -> ())?
    
    //  MARK: - Lifecycle
    
    public override init(frame: CGRect) {
        super.init(frame: frame)
        
        commonInit()
    }
    
    public override init(items: [Any]?) {
        super.init(items: items)
        
        commonInit()
    }
    
    required public init?(coder: NSCoder) {
        super.init(coder: coder)
        
        commonInit()
    }
    
    func commonInit() {
        setTitleTextAttributes([.foregroundColor: UIColor.white], for: .normal)
        
        layer.borderColor = UIColor.ngGrey.cgColor
        layer.borderWidth = 1
        
        setDividerImage(UIImage(), forLeftSegmentState: .normal, rightSegmentState: .normal, barMetrics: .default)
        
        addTarget(self, action: #selector(onValueChanged), for: .valueChanged)
    }
    
    open override func layoutSubviews(){
        super.layoutSubviews()
        
        //background
        layer.cornerRadius = bounds.height * cornersRoundingPercentage
        //foreground
        let foregroundIndex = numberOfSegments
        if subviews.indices.contains(foregroundIndex), let foregroundImageView = subviews[foregroundIndex] as? UIImageView
        {
            foregroundImageView.bounds = foregroundImageView.bounds.insetBy(dx: segmentInset, dy: segmentInset)
            foregroundImageView.image = selectedSegmentImage    //substitute with our own colored image
            foregroundImageView.layer.removeAnimation(forKey: "SelectionBounds")    //this removes the weird scaling animation!
            foregroundImageView.layer.masksToBounds = true
            foregroundImageView.layer.cornerRadius = foregroundImageView.bounds.height * cornersRoundingPercentage
        }
    }
    
}

private extension NGSegmentedControl {
    @objc func onValueChanged() {
        valueChanged?(selectedSegmentIndex)
    }
}

public extension UIImage {
    
    //creates a UIImage given a UIColor
    convenience init?(color: UIColor, size: CGSize = CGSize(width: 1, height: 1)) {
        let rect = CGRect(origin: .zero, size: size)
        UIGraphicsBeginImageContextWithOptions(rect.size, false, 0.0)
        color.setFill()
        UIRectFill(rect)
        let image = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        
        guard let cgImage = image?.cgImage else { return nil }
        self.init(cgImage: cgImage)
    }
}
