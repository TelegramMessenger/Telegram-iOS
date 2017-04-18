import Foundation
import UIKit

final class ItemListControllerSegmentedTitleView: UIView {
    let segments: [String]
    var index: Int {
        didSet {
            self.control.selectedSegmentIndex = self.index
        }
    }
    
    private let control: UISegmentedControl
    
    var indexUpdated: ((Int) -> Void)?
    
    init(segments: [String], index: Int) {
        self.segments = segments
        self.index = index
        
        self.control = UISegmentedControl(items: segments)
        self.control.selectedSegmentIndex = index
        
        super.init(frame: CGRect())
        
        self.addSubview(self.control)
        self.control.addTarget(self, action: #selector(indexChanged), for: .valueChanged)
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        
        let size = self.bounds.size
        
        var controlSize = self.control.sizeThatFits(size)
        controlSize.width = min(size.width, max(200.0, controlSize.width))
        self.control.frame = CGRect(origin: CGPoint(x: floor((size.width - controlSize.width) / 2.0), y: floor((size.height - controlSize.height) / 2.0)), size: controlSize)
    }
    
    @objc func indexChanged() {
        self.indexUpdated?(self.control.selectedSegmentIndex)
    }
}
