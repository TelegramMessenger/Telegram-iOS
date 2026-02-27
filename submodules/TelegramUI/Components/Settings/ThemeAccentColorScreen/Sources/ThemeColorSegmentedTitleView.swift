import Foundation
import UIKit
import SegmentedControlNode
import TelegramPresentationData

final class ThemeColorSegmentedTitleView: UIView {
    private let segmentedControlNode: SegmentedControlNode
    
    var theme: PresentationTheme {
        didSet {
            self.segmentedControlNode.updateTheme(SegmentedControlTheme(theme: self.theme))
        }
    }
    
    var index: Int {
        get {
            return self.segmentedControlNode.selectedIndex
        }
        set {
            self.segmentedControlNode.selectedIndex = newValue
        }
    }
    
    func setIndex(_ index: Int, animated: Bool) {
        self.segmentedControlNode.setSelectedIndex(index, animated: animated)
    }
    
    var sectionUpdated: ((ThemeColorSection) -> Void)?
    var shouldUpdateSection: ((ThemeColorSection, @escaping (Bool) -> Void) -> Void)?
    
    init(theme: PresentationTheme, strings: PresentationStrings, selectedSection: ThemeColorSection) {
        self.theme = theme
        
        let sections = [strings.Theme_Colors_Background, strings.Theme_Colors_Accent, strings.Theme_Colors_Messages]
        self.segmentedControlNode = SegmentedControlNode(theme: SegmentedControlTheme(theme: theme), items: sections.map { SegmentedControlItem(title: $0) }, selectedIndex: selectedSection.rawValue)
        
        super.init(frame: CGRect())
        
        self.segmentedControlNode.selectedIndexChanged = { [weak self] index in
            if let section = ThemeColorSection(rawValue: index) {
                self?.sectionUpdated?(section)
            }
        }
        
        self.segmentedControlNode.selectedIndexShouldChange = { [weak self] index, f in
            if let section = ThemeColorSection(rawValue: index) {
                self?.shouldUpdateSection?(section, f)
            } else {
                f(false)
            }
        }
        
        self.addSubnode(self.segmentedControlNode)
    }
    
    required public init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        
        let size = self.bounds.size
        let controlSize = self.segmentedControlNode.updateLayout(.stretchToFill(width: size.width + 20.0), transition: .immediate)
        self.segmentedControlNode.frame = CGRect(origin: CGPoint(x: floor((size.width - controlSize.width) / 2.0), y: floor((size.height - controlSize.height) / 2.0)), size: controlSize)
    }
}
