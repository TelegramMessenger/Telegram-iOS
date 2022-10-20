import Foundation
import UIKit
import SegmentedControlNode
import TelegramPresentationData

public final class ItemListControllerSegmentedTitleView: UIView {
    private let segmentedControlNode: SegmentedControlNode
    
    public var theme: PresentationTheme {
        didSet {
            self.segmentedControlNode.updateTheme(SegmentedControlTheme(theme: self.theme))
        }
    }
    public var segments: [String] {
        didSet {
            if self.segments != oldValue {
                self.segmentedControlNode.items = self.segments.map { SegmentedControlItem(title: $0) }
                self.setNeedsLayout()
            }
        }
    }
    
    public var index: Int {
        get {
            return self.segmentedControlNode.selectedIndex
        }
        set {
            self.segmentedControlNode.selectedIndex = newValue
        }
    }
    
    public var indexUpdated: ((Int) -> Void)?
    
    public init(theme: PresentationTheme, segments: [String], selectedIndex: Int) {
        self.theme = theme
        self.segments = segments
        
        self.segmentedControlNode = SegmentedControlNode(theme: SegmentedControlTheme(theme: theme), items: segments.map { SegmentedControlItem(title: $0) }, selectedIndex: selectedIndex)
        
        super.init(frame: CGRect())
        
        self.segmentedControlNode.selectedIndexChanged = { [weak self] index in
            self?.indexUpdated?(index)
        }
        
        self.addSubnode(self.segmentedControlNode)
    }
    
    required public init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override public func layoutSubviews() {
        super.layoutSubviews()
        
        let size = self.bounds.size
        let controlSize = self.segmentedControlNode.updateLayout(.sizeToFit(maximumWidth: size.width, minimumWidth: 160.0, height: 32.0), transition: .immediate)
        self.segmentedControlNode.frame = CGRect(origin: CGPoint(x: floor((size.width - controlSize.width) / 2.0), y: floor((size.height - controlSize.height) / 2.0)), size: controlSize)
    }
}
