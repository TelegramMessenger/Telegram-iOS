import UIKit

open class PaddingLabel: UILabel {
    
    //  MARK: - Public Properties

    var horizontalPadding: CGFloat
    var verticalPadding: CGFloat

    //  MARK: - Lifecycle
    
    public init(horizontal: CGFloat, vertical: CGFloat) {
        self.horizontalPadding = horizontal
        self.verticalPadding = vertical
        super.init(frame: .zero)
    }
    
    required public init?(coder: NSCoder) {
        self.horizontalPadding = 0
        self.verticalPadding = 0
        
        super.init(coder: coder)
    }
    
    open override var intrinsicContentSize: CGSize {
        let size = super.intrinsicContentSize
        return .init(width: size.width + horizontalPadding, height: size.height + verticalPadding)
    }

}
