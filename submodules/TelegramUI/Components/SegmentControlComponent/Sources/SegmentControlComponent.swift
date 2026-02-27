import Foundation
import UIKit
import Display
import AsyncDisplayKit
import ComponentFlow
import ComponentDisplayAdapters
import TelegramPresentationData
import SegmentedControlNode

public final class SegmentControlComponent: Component {
    public struct Item: Equatable {
        var id: AnyHashable
        var title: String
        
        public init(id: AnyHashable, title: String) {
            self.id = id
            self.title = title
        }
    }
    
    let theme: PresentationTheme
    let items: [Item]
    let selectedId: AnyHashable?
    let action: (AnyHashable) -> Void
    
    public init(
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
    
    public static func ==(lhs: SegmentControlComponent, rhs: SegmentControlComponent) -> Bool {
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
    
    class SegmentedControlView: UISegmentedControl {
        var foregroundColor: UIColor? {
            didSet {
                self.resetChrome()
            }
        }
        
        override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
            super.touchesBegan(touches, with: event)
            self.resetChrome()
        }
        
        override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
            super.touchesEnded(touches, with: event)
            self.resetChrome()
        }
        
        func resetChrome() {
            for case let view as UIImageView in self.subviews {
                view.isHidden = true
            }
            if let selectorView = self.subviews.last, let loupe = selectorView.subviews.first, let innerLoupe = loupe.subviews.first {
                for view in innerLoupe.subviews {
                    if type(of: view) == UIView.self {
                        view.backgroundColor = self.foregroundColor
                    }
                }
            }
        }
                
        override func layoutSubviews() {
            super.layoutSubviews()
            
            self.resetChrome()
        }
    }
    
    public class View: UIView {
        private let title = ComponentView<Empty>()
        
        private var component: SegmentControlComponent?
        
        private var nativeSegmentedView: SegmentedControlView?
        private var legacySegmentedNode: SegmentedControlNode?
        
        public override init(frame: CGRect) {
            super.init(frame: frame)
        }
        
        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }
        
        func update(component: SegmentControlComponent, availableSize: CGSize, state: EmptyComponentState, environment: Environment<Empty>, transition: ComponentTransition) -> CGSize {
            let themeUpdated = self.component?.theme !== component.theme
            
            self.component = component
            
            var controlSize = CGSize()
            if #available(iOS 26.0, *) {
                let segmentedView: SegmentedControlView
                if let current = self.nativeSegmentedView {
                    segmentedView = current
                } else {
                    let mappedActions: [UIAction] = component.items.map { item -> UIAction in
                        return UIAction(title: item.title, handler: { [weak self] _ in
                            guard let self, let component = self.component else {
                                return
                            }
                            component.action(item.id)
                        })
                    }
                    segmentedView = SegmentedControlView(frame: .zero, actions: mappedActions)
                    segmentedView.selectedSegmentIndex = component.items.firstIndex(where: { $0.id == component.selectedId }) ?? 0
                    self.nativeSegmentedView = segmentedView
                    self.addSubview(segmentedView)
                }
                
                if themeUpdated {
                    let backgroundColor = component.theme.rootController.navigationBar.segmentedBackgroundColor
                    segmentedView.setTitleTextAttributes([
                        .font: Font.semibold(14.0),
                        .foregroundColor: component.theme.rootController.navigationBar.segmentedTextColor
                    ], for: .normal)
                    segmentedView.foregroundColor = component.theme.rootController.navigationBar.segmentedForegroundColor
                    segmentedView.backgroundColor = backgroundColor
                }
                
                controlSize = segmentedView.sizeThatFits(availableSize)
                controlSize.width = min(availableSize.width - 32.0, max(300.0, controlSize.width))
                controlSize.height = 36.0
                segmentedView.frame = CGRect(origin: .zero, size: controlSize)
            } else {
                let segmentedNode: SegmentedControlNode
                if let current = self.legacySegmentedNode {
                    segmentedNode = current
                    
                    if themeUpdated {
                        let backgroundColor = component.theme.overallDarkAppearance ? component.theme.list.itemBlocksBackgroundColor : component.theme.rootController.navigationBar.segmentedBackgroundColor
                        let controlTheme = SegmentedControlTheme(backgroundColor: backgroundColor, foregroundColor: component.theme.rootController.navigationBar.segmentedForegroundColor, shadowColor: .clear, textColor: component.theme.rootController.navigationBar.segmentedTextColor, dividerColor: component.theme.rootController.navigationBar.segmentedDividerColor)
                        segmentedNode.updateTheme(controlTheme)
                    }
                } else {
                    let mappedItems: [SegmentedControlItem] = component.items.map { item -> SegmentedControlItem in
                        return SegmentedControlItem(title: item.title)
                    }
                    let backgroundColor = component.theme.overallDarkAppearance ? component.theme.list.itemBlocksBackgroundColor : component.theme.rootController.navigationBar.segmentedBackgroundColor
                    let controlTheme = SegmentedControlTheme(backgroundColor: backgroundColor, foregroundColor: component.theme.rootController.navigationBar.segmentedForegroundColor, shadowColor: .clear, textColor: component.theme.rootController.navigationBar.segmentedTextColor, dividerColor: component.theme.rootController.navigationBar.segmentedDividerColor)
                    segmentedNode = SegmentedControlNode(theme: controlTheme, items: mappedItems, selectedIndex: component.items.firstIndex(where: { $0.id == component.selectedId }) ?? 0, cornerRadius: 18.0)
                    self.legacySegmentedNode = segmentedNode
                    self.addSubnode(segmentedNode)
                    
                    segmentedNode.selectedIndexChanged = { [weak self] index in
                        guard let self, let component = self.component else {
                            return
                        }
                        component.action(component.items[index].id)
                    }
                }
                
                controlSize = segmentedNode.updateLayout(SegmentedControlLayout.sizeToFit(maximumWidth: availableSize.width, minimumWidth: min(availableSize.width, 300.0), height: 36.0), transition: transition.containedViewLayoutTransition)
                transition.containedViewLayoutTransition.updateFrame(node: segmentedNode, frame: CGRect(origin: CGPoint(x: 0.0, y: 0.0), size: controlSize))
            }
            
            return controlSize
        }
    }
    
    public func makeView() -> View {
        return View(frame: CGRect())
    }
    
    public func update(view: View, availableSize: CGSize, state: EmptyComponentState, environment: Environment<Empty>, transition: ComponentTransition) -> CGSize {
        return view.update(component: self, availableSize: availableSize, state: state, environment: environment, transition: transition)
    }
}
