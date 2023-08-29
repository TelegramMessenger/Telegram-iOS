import Foundation
import UIKit
import Display
import ComponentFlow
import PlainButtonComponent

public final class TabSelectorComponent: Component {
    public struct Colors: Equatable {
        public var foreground: UIColor
        public var selection: UIColor

        public init(
            foreground: UIColor,
            selection: UIColor
        ) {
            self.foreground = foreground
            self.selection = selection
        }
    }
    
    public struct Item: Equatable {
        public var id: AnyHashable
        public var title: String

        public init(
            id: AnyHashable,
            title: String
        ) {
            self.id = id
            self.title = title
        }
    }

    public let colors: Colors
    public let items: [Item]
    public let selectedId: AnyHashable?
    public let setSelectedId: (AnyHashable) -> Void
    
    public init(
        colors: Colors,
        items: [Item],
        selectedId: AnyHashable?,
        setSelectedId: @escaping (AnyHashable) -> Void
    ) {
        self.colors = colors
        self.items = items
        self.selectedId = selectedId
        self.setSelectedId = setSelectedId
    }
    
    public static func ==(lhs: TabSelectorComponent, rhs: TabSelectorComponent) -> Bool {
        if lhs.colors != rhs.colors {
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
    
    private final class VisibleItem {
        let title = ComponentView<Empty>()
        
        init() {
        }
    }
    
    public final class View: UIView {
        private var component: TabSelectorComponent?
        private weak var state: EmptyComponentState?
        
        private let selectionView: UIImageView
        private var visibleItems: [AnyHashable: VisibleItem] = [:]
        
        override init(frame: CGRect) {
            self.selectionView = UIImageView()
            
            super.init(frame: frame)
            
            self.addSubview(self.selectionView)
        }
        
        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }
        
        deinit {
        }
        
        func update(component: TabSelectorComponent, availableSize: CGSize, state: EmptyComponentState, environment: Environment<Empty>, transition: Transition) -> CGSize {
            self.component = component
            self.state = state
            
            let baseHeight: CGFloat = 28.0
            let innerInset: CGFloat = 12.0
            let spacing: CGFloat = 2.0
            
            if self.selectionView.image == nil {
                self.selectionView.image = generateStretchableFilledCircleImage(diameter: baseHeight, color: component.colors.selection)
            }
            
            var contentWidth: CGFloat = 0.0
            var selectedBackgroundRect: CGRect?
            
            var validIds: [AnyHashable] = []
            for item in component.items {
                var itemTransition = transition
                let itemView: VisibleItem
                if let current = self.visibleItems[item.id] {
                    itemView = current
                } else {
                    itemView = VisibleItem()
                    self.visibleItems[item.id] = itemView
                    itemTransition = itemTransition.withAnimation(.none)
                }
                
                let itemId = item.id
                validIds.append(itemId)
                
                let itemSize = itemView.title.update(
                    transition: .immediate,
                    component: AnyComponent(PlainButtonComponent(
                        content: AnyComponent(Text(text: item.title, font: Font.semibold(14.0), color: component.colors.foreground)),
                        effectAlignment: .center,
                        minSize: nil,
                        action: { [weak self] in
                            guard let self, let component = self.component else {
                                return
                            }
                            component.setSelectedId(itemId)
                        }
                    )),
                    environment: {},
                    containerSize: CGSize(width: 200.0, height: 100.0)
                )
                
                if !contentWidth.isZero {
                    contentWidth += spacing
                }
                let itemTitleFrame = CGRect(origin: CGPoint(x: contentWidth + innerInset, y: floor((baseHeight - itemSize.height) * 0.5)), size: itemSize)
                let itemBackgroundRect = CGRect(origin: CGPoint(x: contentWidth, y: 0.0), size: CGSize(width: innerInset + itemSize.width + innerInset, height: baseHeight))
                contentWidth = itemBackgroundRect.maxX
                
                if item.id == component.selectedId {
                    selectedBackgroundRect = itemBackgroundRect
                }
                
                if let itemTitleView = itemView.title.view {
                    if itemTitleView.superview == nil {
                        itemTitleView.layer.anchorPoint = CGPoint()
                        self.addSubview(itemTitleView)
                    }
                    itemTransition.setPosition(view: itemTitleView, position: itemTitleFrame.origin)
                    itemTransition.setBounds(view: itemTitleView, bounds: CGRect(origin: CGPoint(), size: itemTitleFrame.size))
                    itemTransition.setAlpha(view: itemTitleView, alpha: item.id == component.selectedId ? 1.0 : 0.4)
                }
            }
            
            var removeIds: [AnyHashable] = []
            for (id, itemView) in self.visibleItems {
                if !validIds.contains(id) {
                    removeIds.append(id)
                    itemView.title.view?.removeFromSuperview()
                }
            }
            for id in removeIds {
                self.visibleItems.removeValue(forKey: id)
            }
            
            if let selectedBackgroundRect {
                self.selectionView.alpha = 1.0
                transition.setFrame(view: self.selectionView, frame: selectedBackgroundRect)
            } else {
                self.selectionView.alpha = 0.0
            }
            
            return CGSize(width: contentWidth, height: baseHeight)
        }
    }
    
    public func makeView() -> View {
        return View(frame: CGRect())
    }
    
    public func update(view: View, availableSize: CGSize, state: EmptyComponentState, environment: Environment<Empty>, transition: Transition) -> CGSize {
        return view.update(component: self, availableSize: availableSize, state: state, environment: environment, transition: transition)
    }
}
