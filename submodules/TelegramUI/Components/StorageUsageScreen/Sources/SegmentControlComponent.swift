import Foundation
import UIKit
import Display
import AsyncDisplayKit
import ComponentFlow
import SwiftSignalKit
import ViewControllerComponent
import ComponentDisplayAdapters
import TelegramPresentationData
import AccountContext
import TelegramCore
import MultilineTextComponent
import EmojiStatusComponent
import Postbox
import TelegramStringFormatting
import CheckNode
import SegmentedControlNode

final class SegmentControlComponent: Component {
    struct Item: Equatable {
        var id: AnyHashable
        var title: String
    }
    
    let theme: PresentationTheme
    let items: [Item]
    let selectedId: AnyHashable?
    let action: (AnyHashable) -> Void
    
    init(
        theme: PresentationTheme,
        items: [Item],
        selectedId: AnyHashable?,
        action: @escaping (AnyHashable) -> Void
    ) {
        self.theme = theme
        self.items = items
        self.selectedId = selectedId
        self.action = action
    }
    
    static func ==(lhs: SegmentControlComponent, rhs: SegmentControlComponent) -> Bool {
        if lhs.theme !== rhs.theme {
            return false
        }
        if lhs.items != rhs.items {
            return false
        }
        if lhs.selectedId != rhs.selectedId {
            return false
        }
        return true
    }
    
    class View: UIView {
        private let title = ComponentView<Empty>()
        
        private var component: SegmentControlComponent?
        
        private var segmentedNode: SegmentedControlNode?
        
        override init(frame: CGRect) {
            super.init(frame: frame)
        }
        
        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }
        
        func update(component: SegmentControlComponent, availableSize: CGSize, state: EmptyComponentState, environment: Environment<Empty>, transition: Transition) -> CGSize {
            let themeUpdated = self.component?.theme !== component.theme
            
            self.component = component

            let segmentedNode: SegmentedControlNode
            if let current = self.segmentedNode {
                segmentedNode = current
                
                if themeUpdated {
                    segmentedNode.updateTheme(SegmentedControlTheme(theme: component.theme))
                }
            } else {
                let mappedItems: [SegmentedControlItem] = component.items.map { item -> SegmentedControlItem in
                    return SegmentedControlItem(title: item.title)
                }
                segmentedNode = SegmentedControlNode(theme: SegmentedControlTheme(theme: component.theme), items: mappedItems, selectedIndex: component.items.firstIndex(where: { $0.id == component.selectedId }) ?? 0)
                self.segmentedNode = segmentedNode
                self.addSubnode(segmentedNode)
                
                segmentedNode.selectedIndexChanged = { [weak self] index in
                    guard let self, let component = self.component else {
                        return
                    }
                    self.component?.action(component.items[index].id)
                }
            }
            
            let controlSize = segmentedNode.updateLayout(SegmentedControlLayout.sizeToFit(maximumWidth: availableSize.width, minimumWidth: min(availableSize.width, 296.0), height: 31.0), transition: transition.containedViewLayoutTransition)
            
            transition.containedViewLayoutTransition.updateFrame(node: segmentedNode, frame: CGRect(origin: CGPoint(x: 0.0, y: 0.0), size: controlSize))
            
            return controlSize
        }
    }
    
    func makeView() -> View {
        return View(frame: CGRect())
    }
    
    func update(view: View, availableSize: CGSize, state: EmptyComponentState, environment: Environment<Empty>, transition: Transition) -> CGSize {
        return view.update(component: self, availableSize: availableSize, state: state, environment: environment, transition: transition)
    }
}
