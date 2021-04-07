import Foundation
import UIKit
import AsyncDisplayKit
import Display
import TelegramPresentationData
import MergeLists

public protocol FormControllerEntry: Identifiable {
    associatedtype ItemParams
    
    func isEqual(to: Self) -> Bool
    func item(params: ItemParams, strings: PresentationStrings) -> FormControllerItem
}

public enum FormControllerItemNeighbor {
    case none
    case spacer
    case item(FormControllerItemNode)
}

public struct FormControllerItemPreLayout {
    let aligningInset: CGFloat
}

public struct FormControllerItemLayoutParams {
    let maxAligningInset: CGFloat
}

public protocol FormControllerItem {
    func node() -> ASDisplayNode & FormControllerItemNode
    func update(node: ASDisplayNode & FormControllerItemNode, theme: PresentationTheme, strings: PresentationStrings, dateTimeFormat: PresentationDateTimeFormat, width: CGFloat, previousNeighbor: FormControllerItemNeighbor, nextNeighbor: FormControllerItemNeighbor, transition: ContainedViewLayoutTransition) -> (FormControllerItemPreLayout, (FormControllerItemLayoutParams) -> CGFloat)
}

public protocol FormControllerItemNode {
    var preventsTouchesToOtherItems: Bool { get }
    func touchesToOtherItemsPrevented()
}
