import Foundation
import UIKit
import Display
import ComponentFlow
import ComponentDisplayAdapters
import TelegramPresentationData

final class StorageUsagePanelEnvironment: Equatable {
    let theme: PresentationTheme
    let strings: PresentationStrings
    let containerInsets: UIEdgeInsets
    
    init(
        theme: PresentationTheme,
        strings: PresentationStrings,
        containerInsets: UIEdgeInsets
    ) {
        self.theme = theme
        self.strings = strings
        self.containerInsets = containerInsets
    }

    static func ==(lhs: StorageUsagePanelEnvironment, rhs: StorageUsagePanelEnvironment) -> Bool {
        if lhs.theme !== rhs.theme {
            return false
        }
        if lhs.strings !== rhs.strings {
            return false
        }
        if lhs.containerInsets != rhs.containerInsets {
            return false
        }
        return true
    }
}

private final class StorageUsageHeaderItemComponent: CombinedComponent {
    let theme: PresentationTheme
    let title: String
    
    init(
        theme: PresentationTheme,
        title: String
    ) {
        self.theme = theme
        self.title = title
    }
    
    static func ==(lhs: StorageUsageHeaderItemComponent, rhs: StorageUsageHeaderItemComponent) -> Bool {
        if lhs.theme !== rhs.theme {
            return false
        }
        if lhs.title != rhs.title {
            return false
        }
        return true
    }
    
    static var body: Body {
        let text = Child(Text.self)
        
        return { context in
            let text = text.update(
                component: Text(text: context.component.title, font: Font.semibold(15.0), color: context.component.theme.list.itemAccentColor),
                availableSize: context.availableSize,
                transition: .immediate
            )
            
            context.add(text.position(CGPoint(x: text.size.width * 0.5, y: text.size.height * 0.5)))
            
            return text.size
        }
    }
}

private final class StorageUsageHeaderComponent: Component {
    struct Item: Equatable {
        let id: AnyHashable
        let title: String

        init(
            id: AnyHashable,
            title: String
        ) {
            self.id = id
            self.title = title
        }
    }

    let theme: PresentationTheme
    let items: [Item]
    
    init(
        theme: PresentationTheme,
        items: [Item]
    ) {
        self.theme = theme
        self.items = items
    }
    
    static func ==(lhs: StorageUsageHeaderComponent, rhs: StorageUsageHeaderComponent) -> Bool {
        if lhs.theme !== rhs.theme {
            return false
        }
        if lhs.items != rhs.items {
            return false
        }
        return true
    }
    
    class View: UIView {
        private var component: StorageUsageHeaderComponent?
        
        private var visibleItems: [AnyHashable: ComponentView<Empty>] = [:]
        private let activeItemLayer: SimpleLayer
        
        override init(frame: CGRect) {
            self.activeItemLayer = SimpleLayer()
            self.activeItemLayer.cornerRadius = 2.0
            self.activeItemLayer.maskedCorners = [.layerMinXMinYCorner, .layerMaxXMinYCorner]
            
            super.init(frame: frame)
            
            self.layer.addSublayer(self.activeItemLayer)
        }
        
        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }
        
        func update(component: StorageUsageHeaderComponent, availableSize: CGSize, state: EmptyComponentState, environment: Environment<Empty>, transition: Transition) -> CGSize {
            let themeUpdated = self.component?.theme !== component.theme
            
            self.component = component
            
            var validIds = Set<AnyHashable>()
            for item in component.items {
                validIds.insert(item.id)
                
                let itemView: ComponentView<Empty>
                var itemTransition = transition
                if let current = self.visibleItems[item.id] {
                    itemView = current
                } else {
                    itemTransition = .immediate
                    itemView = ComponentView()
                    self.visibleItems[item.id] = itemView
                }
                let itemSize = itemView.update(
                    transition: itemTransition,
                    component: AnyComponent(StorageUsageHeaderItemComponent(
                        theme: component.theme,
                        title: item.title
                    )),
                    environment: {},
                    containerSize: availableSize
                )
                let itemFrame = CGRect(origin: CGPoint(x: 34.0, y: floor((availableSize.height - itemSize.height) / 2.0)), size: itemSize)
                if let itemComponentView = itemView.view {
                    if itemComponentView.superview == nil {
                        self.addSubview(itemComponentView)
                    }
                    itemTransition.setFrame(view: itemComponentView, frame: itemFrame)
                }
                
                transition.setFrame(layer: self.activeItemLayer, frame: CGRect(origin: CGPoint(x: itemFrame.minX, y: availableSize.height - 3.0), size: CGSize(width: itemFrame.width, height: 3.0)))
            }
            
            if themeUpdated {
                self.activeItemLayer.backgroundColor = component.theme.list.itemAccentColor.cgColor
            }
            
            var removeIds: [AnyHashable] = []
            for (id, itemView) in self.visibleItems {
                if !validIds.contains(id) {
                    removeIds.append(id)
                    if let itemComponentView = itemView.view {
                        itemComponentView.removeFromSuperview()
                    }
                }
            }
            for id in removeIds {
                self.visibleItems.removeValue(forKey: id)
            }
            
            return availableSize
        }
    }
    
    func makeView() -> View {
        return View(frame: CGRect())
    }
    
    func update(view: View, availableSize: CGSize, state: EmptyComponentState, environment: Environment<Empty>, transition: Transition) -> CGSize {
        return view.update(component: self, availableSize: availableSize, state: state, environment: environment, transition: transition)
    }
}

final class StorageUsagePanelContainerComponent: Component {
    struct Item: Equatable {
        let id: AnyHashable
        let title: String
        let panel: AnyComponent<StorageUsagePanelEnvironment>

        init(
            id: AnyHashable,
            title: String,
            panel: AnyComponent<StorageUsagePanelEnvironment>
        ) {
            self.id = id
            self.title = title
            self.panel = panel
        }
    }

    let theme: PresentationTheme
    let strings: PresentationStrings
    let insets: UIEdgeInsets
    let items: [Item]
    
    init(
        theme: PresentationTheme,
        strings: PresentationStrings,
        insets: UIEdgeInsets,
        items: [Item]
    ) {
        self.theme = theme
        self.strings = strings
        self.insets = insets
        self.items = items
    }
    
    static func ==(lhs: StorageUsagePanelContainerComponent, rhs: StorageUsagePanelContainerComponent) -> Bool {
        if lhs.theme !== rhs.theme {
            return false
        }
        if lhs.strings !== rhs.strings {
            return false
        }
        if lhs.insets != rhs.insets {
            return false
        }
        if lhs.items != rhs.items {
            return false
        }
        return true
    }
    
    class View: UIView {
        private let topPanelBackgroundView: BlurredBackgroundView
        private let topPanelSeparatorLayer: SimpleLayer
        private let header = ComponentView<Empty>()
        
        private var component: StorageUsagePanelContainerComponent?
        
        private var visiblePanels: [AnyHashable: ComponentView<StorageUsagePanelEnvironment>] = [:]
        private var currentId: AnyHashable?
        
        override init(frame: CGRect) {
            self.topPanelBackgroundView = BlurredBackgroundView(color: nil, enableBlur: true)
            self.topPanelSeparatorLayer = SimpleLayer()
            
            super.init(frame: frame)
            
            self.addSubview(self.topPanelBackgroundView)
            self.layer.addSublayer(self.topPanelSeparatorLayer)
        }
        
        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }
        
        func update(component: StorageUsagePanelContainerComponent, availableSize: CGSize, state: EmptyComponentState, environment: Environment<Empty>, transition: Transition) -> CGSize {
            let themeUpdated = self.component?.theme !== component.theme
            
            self.component = component
            
            if themeUpdated {
                self.backgroundColor = component.theme.list.itemBlocksBackgroundColor
                self.topPanelBackgroundView.updateColor(color: component.theme.list.itemBlocksBackgroundColor.withAlphaComponent(0.8), transition: .immediate)
                self.topPanelSeparatorLayer.backgroundColor = component.theme.list.itemBlocksSeparatorColor.cgColor
            }
            
            let topPanelFrame = CGRect(origin: CGPoint(), size: CGSize(width: availableSize.width, height: 44.0))
            transition.setFrame(view: self.topPanelBackgroundView, frame: topPanelFrame)
            self.topPanelBackgroundView.update(size: topPanelFrame.size, transition: transition.containedViewLayoutTransition)
            
            transition.setFrame(layer: self.topPanelSeparatorLayer, frame: CGRect(origin: CGPoint(x: 0.0, y: topPanelFrame.maxY), size: CGSize(width: availableSize.width, height: UIScreenPixel)))
            
            let _ = self.header.update(
                transition: transition,
                component: AnyComponent(StorageUsageHeaderComponent(
                    theme: component.theme,
                    items: component.items.map { item -> StorageUsageHeaderComponent.Item in
                        return StorageUsageHeaderComponent.Item(
                            id: item.id,
                            title: item.title
                        )
                    }
                )),
                environment: {},
                containerSize: topPanelFrame.size
            )
            if let headerView = self.header.view {
                if headerView.superview == nil {
                    self.addSubview(headerView)
                }
                transition.setFrame(view: headerView, frame: topPanelFrame)
            }
            
            if let currentIdValue = self.currentId, !component.items.contains(where: { $0.id == currentIdValue }) {
                self.currentId = nil
            }
            if self.currentId == nil {
                self.currentId = component.items.first?.id
            }
            
            let childEnvironment = StorageUsagePanelEnvironment(
                theme: component.theme,
                strings: component.strings,
                containerInsets: UIEdgeInsets(top: topPanelFrame.height, left: component.insets.left, bottom: component.insets.bottom, right: component.insets.right)
            )
            
            var validIds = Set<AnyHashable>()
            if let currentId = self.currentId, let panelItem = component.items.first(where: { $0.id == currentId }) {
                validIds.insert(panelItem.id)
                
                let panel: ComponentView<StorageUsagePanelEnvironment>
                var panelTransition = transition
                if let current = self.visiblePanels[panelItem.id] {
                    panel = current
                } else {
                    panelTransition = .immediate
                    panel = ComponentView()
                    self.visiblePanels[panelItem.id] = panel
                }
                let _ = panel.update(
                    transition: panelTransition,
                    component: panelItem.panel,
                    environment: {
                        childEnvironment
                    },
                    containerSize: availableSize
                )
                if let panelView = panel.view {
                    if panelView.superview == nil {
                        self.insertSubview(panelView, belowSubview: self.topPanelBackgroundView)
                    }
                    panelTransition.setFrame(view: panelView, frame: CGRect(origin: CGPoint(), size: availableSize))
                }
            }
            
            var removeIds: [AnyHashable] = []
            for (id, panel) in self.visiblePanels {
                if !validIds.contains(id) {
                    removeIds.append(id)
                    if let panelView = panel.view {
                        panelView.removeFromSuperview()
                    }
                }
            }
            for id in removeIds {
                self.visiblePanels.removeValue(forKey: id)
            }
            
            return availableSize
        }
    }
    
    func makeView() -> View {
        return View(frame: CGRect())
    }
    
    func update(view: View, availableSize: CGSize, state: EmptyComponentState, environment: Environment<Empty>, transition: Transition) -> CGSize {
        return view.update(component: self, availableSize: availableSize, state: state, environment: environment, transition: transition)
    }
}
