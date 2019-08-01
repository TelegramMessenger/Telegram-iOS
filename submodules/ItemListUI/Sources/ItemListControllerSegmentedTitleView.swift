import Foundation
import UIKit

public final class ItemListControllerSegmentedTitleView: UIView {
    public var segments: [String] {
        didSet {
            if self.segments != oldValue {
                self.control.removeAllSegments()
                var index = 0
                for segment in self.segments {
                    self.control.insertSegment(withTitle: segment, at: index, animated: false)
                    index += 1
                }
                self.setNeedsLayout()
            }
        }
    }
    
    public var index: Int {
        didSet {
            self.control.selectedSegmentIndex = self.index
        }
    }
    
    private let control: UISegmentedControl
    
    public var indexUpdated: ((Int) -> Void)?
    
    public var color: UIColor {
        didSet {
            self.control.tintColor = self.color
        }
    }
    
    public init(segments: [String], index: Int, color: UIColor) {
        self.segments = segments
        self.index = index
        self.color = color
        
        self.control = UISegmentedControl(items: segments)
        self.control.selectedSegmentIndex = index
        self.control.tintColor = color
        
        super.init(frame: CGRect())
        
        self.addSubview(self.control)
        self.control.addTarget(self, action: #selector(indexChanged), for: .valueChanged)
    }
    
    required public init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override public func layoutSubviews() {
        super.layoutSubviews()
        
        let size = self.bounds.size
        
        var controlSize = self.control.sizeThatFits(size)
        controlSize.width = min(size.width, max(160.0, controlSize.width))
        self.control.frame = CGRect(origin: CGPoint(x: floor((size.width - controlSize.width) / 2.0), y: floor((size.height - controlSize.height) / 2.0)), size: controlSize)
    }
    
    @objc private func indexChanged() {
        self.indexUpdated?(self.control.selectedSegmentIndex)
    }
}
