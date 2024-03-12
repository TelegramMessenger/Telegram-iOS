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
    
    public struct CustomLayout: Equatable {
        public var font: UIFont
        public var spacing: CGFloat
        public var lineSelection: Bool
        
        public init(font: UIFont, spacing: CGFloat, lineSelection: Bool = false) {
            self.font = font
            self.spacing = spacing
            self.lineSelection = lineSelection
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
    public let customLayout: CustomLayout?
    public let items: [Item]
    public let selectedId: AnyHashable?
    public let setSelectedId: (AnyHashable) -> Void
    
    public init(
        colors: Colors,
        customLayout: CustomLayout? = nil,
        items: [Item],
        selectedId: AnyHashable?,
        setSelectedId: @escaping (AnyHashable) -> Void
    ) {
        self.colors = colors
        self.customLayout = customLayout
        self.items = items
        self.selectedId = selectedId
        self.setSelectedId = setSelectedId
    }
    
    public static func ==(lhs: TabSelectorComponent, rhs: TabSelectorComponent) -> Bool {
        if lhs.colors != rhs.colors {
            return false
        }
        if lhs.customLayout != rhs.customLayout {
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
            let selectionColorUpdated = component.colors.selection != self.component?.colors.selection
           
            self.component = component
            self.state = state
            
            let baseHeight: CGFloat = 28.0
            let innerInset: CGFloat = 12.0
            let spacing: CGFloat = component.customLayout?.spacing ?? 2.0
            
            let itemFont: UIFont
            var isLineSelection = false
            if let customLayout = component.customLayout {
                itemFont = customLayout.font
                isLineSelection = customLayout.lineSelection
            } else {
                itemFont = Font.semibold(14.0)
            }
            
            if selectionColorUpdated {
                if isLineSelection {
                    self.selectionView.image = generateImage(CGSize(width: 5.0, height: 3.0), rotatedContext: { size, context in
                        context.clear(CGRect(origin: CGPoint(), size: size))
                        context.setFillColor(component.colors.selection.cgColor)
                        context.fillEllipse(in: CGRect(origin: CGPoint(), size: CGSize(width: 4.0, height: 4.0)))
                        context.fillEllipse(in: CGRect(origin: CGPoint(x: size.width - 4.0, y: 0.0), size: CGSize(width: 4.0, height: 4.0)))
                        context.fill(CGRect(x: 2.0, y: 0.0, width: size.width - 4.0, height: 4.0))
                        context.fill(CGRect(x: 0.0, y: 2.0, width: size.width, height: 2.0))
                    })?.resizableImage(withCapInsets: UIEdgeInsets(top: 3.0, left: 3.0, bottom: 0.0, right: 3.0), resizingMode: .stretch)
                } else {
                    self.selectionView.image = generateStretchableFilledCircleImage(diameter: baseHeight, color: component.colors.selection)
                }
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
                        content: AnyComponent(Text(
                            text: item.title,
                            font: itemFont,
                            color: item.id == component.selectedId && isLineSelection ? component.colors.selection : component.colors.foreground
                        )),
                        effectAlignment: .center,
                        minSize: nil,
                        action: { [weak self] in
                            guard let self, let component = self.component else {
                                return
                            }
                            component.setSelectedId(itemId)
                        },
                        animateScale: !isLineSelection
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
                    itemTransition.setAlpha(view: itemTitleView, alpha: item.id == component.selectedId || isLineSelection ? 1.0 : 0.4)
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
                
                if isLineSelection {
                    var mappedSelectionFrame = selectedBackgroundRect.insetBy(dx: 12.0, dy: 0.0)
                    mappedSelectionFrame.origin.y = mappedSelectionFrame.maxY + 6.0
                    mappedSelectionFrame.size.height = 3.0
                    transition.setFrame(view: self.selectionView, frame: mappedSelectionFrame)
                } else {
                    transition.setFrame(view: self.selectionView, frame: selectedBackgroundRect)
                }
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
