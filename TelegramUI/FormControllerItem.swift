import Foundation
import AsyncDisplayKit
import Display

protocol FormControllerEntry: Identifiable {
    func isEqual(to: Self) -> Bool
    func item(strings: PresentationStrings) -> FormControllerItem
}

enum FormControllerItemNeighbor {
    case none
    case spacer
    case item(FormControllerItem)
}

protocol FormControllerItem {
    func node() -> ASDisplayNode & FormControllerItemNode
    func update(node: ASDisplayNode & FormControllerItemNode, theme: PresentationTheme, strings: PresentationStrings, width: CGFloat, previousNeighbor: FormControllerItemNeighbor, nextNeighbor: FormControllerItemNeighbor, transition: ContainedViewLayoutTransition) -> CGFloat
}

protocol FormControllerItemNode {
}
