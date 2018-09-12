import Foundation
import AsyncDisplayKit
import Display

final class TwoStepVerificationEmptyItem: ItemListControllerEmptyStateItem {
    let theme: PresentationTheme
    let strings: PresentationStrings
    let setup: () -> Void
    
    init(theme: PresentationTheme, strings: PresentationStrings, setup: @escaping () -> Void) {
        self.theme = theme
        self.strings = strings
        self.setup = setup
    }
    
    func isEqual(to: ItemListControllerEmptyStateItem) -> Bool {
        return to is TwoStepVerificationEmptyItem
    }
    
    func node(current: ItemListControllerEmptyStateItemNode?) -> ItemListControllerEmptyStateItemNode {
        if let current = current as? TwoStepVerificationEmptyItemNode {
            current.item = self
            return current
        } else {
            return TwoStepVerificationEmptyItemNode(item: self)
        }
    }
}

final class TwoStepVerificationEmptyItemNode: ItemListControllerEmptyStateItemNode {
    var item: TwoStepVerificationEmptyItem {
        didSet {
            if let (layout, navigationHeight) = self.validLayout {
                self.updateLayout(layout: layout, navigationBarHeight: navigationHeight, transition: .immediate)
            }
        }
    }

    
    private var validLayout: (ContainerViewLayout, CGFloat)?
    
    init(item: TwoStepVerificationEmptyItem) {
        self.item = item
        
        super.init()
        
        
    }
    
    override func updateLayout(layout: ContainerViewLayout, navigationBarHeight: CGFloat, transition: ContainedViewLayoutTransition) {
        self.validLayout = (layout, navigationBarHeight)
        
        var insets = layout.insets(options: [.statusBar])
        insets.top += navigationBarHeight
        
        
    }
}
