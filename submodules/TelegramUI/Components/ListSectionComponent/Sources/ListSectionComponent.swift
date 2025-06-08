import Foundation
import UIKit
import Display
import ComponentFlow
import TelegramPresentationData
import DynamicCornerRadiusView

public protocol ListSectionComponentChildView: AnyObject {
    var customUpdateIsHighlighted: ((Bool) -> Void)? { get set }
    var separatorInset: CGFloat { get }
}

public final class ListSectionContentView: UIView {
    public final class ItemView: UIView {
        public let contents = ComponentView<Empty>()
        public let separatorLayer = SimpleLayer()
        public let highlightLayer = SimpleLayer()
        
        override public init(frame: CGRect) {
            super.init(frame: frame)
        }
        
        required public init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }
    }
    
    public final class ReadyItem {
        public let id: AnyHashable
        public let itemView: ItemView
        public let size: CGSize
        public let transition: ComponentTransition
        
        public init(id: AnyHashable, itemView: ItemView, size: CGSize, transition: ComponentTransition) {
            self.id = id
            self.itemView = itemView
            self.size = size
            self.transition = transition
        }
    }
    
    public final class Configuration {
        public let theme: PresentationTheme
        public let isModal: Bool
        public let displaySeparators: Bool
        public let extendsItemHighlightToSection: Bool
        public let background: ListSectionComponent.Background
        
        public init(
            theme: PresentationTheme,
            isModal: Bool = false,
            displaySeparators: Bool,
            extendsItemHighlightToSection: Bool,
            background: ListSectionComponent.Background
        ) {
            self.theme = theme
            self.isModal = isModal
            self.displaySeparators = displaySeparators
            self.extendsItemHighlightToSection = extendsItemHighlightToSection
            self.background = background
        }
    }
    
    public struct UpdateResult {
        public var size: CGSize
        public var backgroundFrame: CGRect
        
        public init(size: CGSize, backgroundFrame: CGRect) {
            self.size = size
            self.backgroundFrame = backgroundFrame
        }
    }
    
    private let contentSeparatorContainerLayer: SimpleLayer
    private let contentHighlightContainerLayer: SimpleLayer
    private let contentItemContainerView: UIView
    
    public let externalContentBackgroundView: DynamicCornerRadiusView
    public var automaticallyLayoutExternalContentBackgroundView = true
    
    public var itemViews: [AnyHashable: ItemView] = [:]
    private var highlightedItemId: AnyHashable?
    
    private var configuration: Configuration?
    
    public override init(frame: CGRect) {
        self.contentSeparatorContainerLayer = SimpleLayer()
        self.contentHighlightContainerLayer = SimpleLayer()
        self.contentItemContainerView = UIView()
        
        self.externalContentBackgroundView = DynamicCornerRadiusView()
        
        super.init(frame: CGRect())
        
        self.layer.addSublayer(self.contentSeparatorContainerLayer)
        self.layer.addSublayer(self.contentHighlightContainerLayer)
        self.addSubview(self.contentItemContainerView)
    }
    
    required public init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func updateHighlightedItem(itemId: AnyHashable?) {
        guard let configuration = self.configuration else {
            return
        }
        
        if self.highlightedItemId == itemId {
            return
        }
        let previousHighlightedItemId = self.highlightedItemId
        self.highlightedItemId = itemId
        
        if configuration.extendsItemHighlightToSection {
            let transition: ComponentTransition
            let backgroundColor: UIColor
            if itemId != nil {
                transition = .immediate
                backgroundColor = configuration.theme.list.itemHighlightedBackgroundColor
            } else {
                transition = .easeInOut(duration: 0.2)
                backgroundColor = configuration.isModal ? configuration.theme.list.itemModalBlocksBackgroundColor : configuration.theme.list.itemBlocksBackgroundColor
            }
            
            self.externalContentBackgroundView.updateColor(color: backgroundColor, transition: transition)
        } else {
            if let previousHighlightedItemId, let previousItemView = self.itemViews[previousHighlightedItemId] {
                ComponentTransition.easeInOut(duration: 0.2).setBackgroundColor(layer: previousItemView.highlightLayer, color: .clear)
            }
            if let itemId, let itemView = self.itemViews[itemId] {
                ComponentTransition.immediate.setBackgroundColor(layer: itemView.highlightLayer, color: configuration.theme.list.itemHighlightedBackgroundColor)
            }
        }
    }
    
    public func update(configuration: Configuration, width: CGFloat, leftInset: CGFloat, readyItems: [ReadyItem], transition: ComponentTransition) -> UpdateResult {
        self.configuration = configuration
        
        switch configuration.background {
        case .all, .range:
            self.clipsToBounds = true
        case let .none(clipped):
            self.clipsToBounds = clipped
        }
        
        let backgroundColor: UIColor
        if self.highlightedItemId != nil && configuration.extendsItemHighlightToSection {
            backgroundColor = configuration.theme.list.itemHighlightedBackgroundColor
        } else {
            backgroundColor = configuration.isModal ? configuration.theme.list.itemModalBlocksBackgroundColor : configuration.theme.list.itemBlocksBackgroundColor
        }
        self.externalContentBackgroundView.updateColor(color: backgroundColor, transition: transition)
        
        var innerContentHeight: CGFloat = 0.0
        var validItemIds: [AnyHashable] = []
        for index in 0 ..< readyItems.count {
            let readyItem = readyItems[index]
            validItemIds.append(readyItem.id)
            
            let itemFrame = CGRect(origin: CGPoint(x: leftInset, y: innerContentHeight), size: readyItem.size)
            if let itemComponentView = readyItem.itemView.contents.view {
                var isAdded = false
                if itemComponentView.superview == nil {
                    isAdded = true
                    readyItem.itemView.addSubview(itemComponentView)
                    self.contentItemContainerView.addSubview(readyItem.itemView)
                    self.contentSeparatorContainerLayer.addSublayer(readyItem.itemView.separatorLayer)
                    self.contentHighlightContainerLayer.addSublayer(readyItem.itemView.highlightLayer)
                    transition.animateAlpha(view: readyItem.itemView, from: 0.0, to: 1.0)
                    transition.animateAlpha(layer: readyItem.itemView.separatorLayer, from: 0.0, to: 1.0)
                    transition.animateAlpha(layer: readyItem.itemView.highlightLayer, from: 0.0, to: 1.0)
                    
                    let itemId = readyItem.id
                    if let itemComponentView = itemComponentView as? ListSectionComponentChildView {
                        itemComponentView.customUpdateIsHighlighted = { [weak self] isHighlighted in
                            guard let self else {
                                return
                            }
                            self.updateHighlightedItem(itemId: isHighlighted ? itemId : nil)
                        }
                    }
                }
                var separatorInset: CGFloat = 0.0
                if let itemComponentView = itemComponentView as? ListSectionComponentChildView {
                    separatorInset = itemComponentView.separatorInset
                }
                
                let itemSeparatorFrame = CGRect(origin: CGPoint(x: separatorInset, y: itemFrame.maxY - UIScreenPixel), size: CGSize(width: width - separatorInset, height: UIScreenPixel))
                
                if isAdded && itemComponentView is ListSubSectionComponent.View {
                    readyItem.itemView.frame = itemFrame
                    readyItem.itemView.clipsToBounds = true
                    readyItem.itemView.frame = CGRect(origin: CGPoint(x: itemFrame.minX, y: itemFrame.minY), size: CGSize(width: itemFrame.width, height: 0.0))
                    let itemView = readyItem.itemView
                    transition.setFrame(view: readyItem.itemView, frame: itemFrame, completion: { [weak itemView] completed in
                        if completed {
                            itemView?.clipsToBounds = false
                        }
                    })
                    
                    readyItem.itemView.separatorLayer.frame = CGRect(origin: CGPoint(x: itemSeparatorFrame.minX, y: itemFrame.minY), size: CGSize(width: itemSeparatorFrame.width, height: 0.0))
                    transition.setFrame(layer: readyItem.itemView.separatorLayer, frame: itemSeparatorFrame)
                } else {
                    readyItem.transition.setFrame(view: readyItem.itemView, frame: itemFrame)
                    readyItem.transition.setFrame(layer: readyItem.itemView.separatorLayer, frame: itemSeparatorFrame)
                }
                
                let itemSeparatorTopOffset: CGFloat = index == 0 ? 0.0 : -UIScreenPixel
                let itemHighlightFrame = CGRect(origin: CGPoint(x: itemFrame.minX, y: itemFrame.minY + itemSeparatorTopOffset), size: CGSize(width: itemFrame.width, height: itemFrame.height - itemSeparatorTopOffset))
                readyItem.transition.setFrame(layer: readyItem.itemView.highlightLayer, frame: itemHighlightFrame)
                
                readyItem.transition.setFrame(view: itemComponentView, frame: CGRect(origin: CGPoint(), size: itemFrame.size))
                
                let separatorAlpha: CGFloat
                if configuration.displaySeparators {
                    if index != readyItems.count - 1 {
                        separatorAlpha = 1.0
                    } else {
                        separatorAlpha = 0.0
                    }
                } else {
                    separatorAlpha = 0.0
                }
                readyItem.transition.setAlpha(layer: readyItem.itemView.separatorLayer, alpha: separatorAlpha)
                readyItem.itemView.separatorLayer.backgroundColor = configuration.theme.list.itemBlocksSeparatorColor.cgColor
            }
            innerContentHeight += readyItem.size.height
        }
        
        var removedItemIds: [AnyHashable] = []
        for (id, itemView) in self.itemViews {
            if !validItemIds.contains(id) {
                removedItemIds.append(id)
                
                if let itemComponentView = itemView.contents.view, itemComponentView is ListSubSectionComponent.View {
                    itemView.clipsToBounds = true
                    transition.setFrame(view: itemView, frame: CGRect(origin: itemView.frame.origin, size: CGSize(width: itemView.bounds.width, height: 0.0)))
                    transition.setFrame(layer: itemView.separatorLayer, frame: CGRect(origin: CGPoint(x: itemView.separatorLayer.frame.minX, y: itemView.frame.minY), size: itemView.separatorLayer.bounds.size))
                }
                
                transition.setAlpha(view: itemView, alpha: 0.0, completion: { [weak itemView] _ in
                    itemView?.removeFromSuperview()
                })
                let separatorLayer = itemView.separatorLayer
                transition.setAlpha(layer: separatorLayer, alpha: 0.0, completion: { [weak separatorLayer] _ in
                    separatorLayer?.removeFromSuperlayer()
                })
                let highlightLayer = itemView.highlightLayer
                transition.setAlpha(layer: highlightLayer, alpha: 0.0, completion: { [weak highlightLayer] _ in
                    highlightLayer?.removeFromSuperlayer()
                })
            }
        }
        for id in removedItemIds {
            self.itemViews.removeValue(forKey: id)
        }
        
        let size = CGSize(width: width, height: innerContentHeight)
        
        transition.setFrame(view: self.contentItemContainerView, frame: CGRect(origin: CGPoint(), size: size))
        transition.setFrame(layer: self.contentSeparatorContainerLayer, frame: CGRect(origin: CGPoint(), size: size))
        transition.setFrame(layer: self.contentHighlightContainerLayer, frame: CGRect(origin: CGPoint(), size: size))
        
        let backgroundFrame: CGRect
        var backgroundAlpha: CGFloat = 1.0
        var contentCornerRadius: CGFloat = 11.0
        switch configuration.background {
        case let .none(clipped):
            backgroundFrame = CGRect(origin: CGPoint(x: 0.0, y: 0.0), size: size)
            backgroundAlpha = 0.0
            self.externalContentBackgroundView.update(size: backgroundFrame.size, corners: DynamicCornerRadiusView.Corners(minXMinY: 11.0, maxXMinY: 11.0, minXMaxY: 11.0, maxXMaxY: 11.0), transition: transition)
            if !clipped {
                contentCornerRadius = 0.0
            }
        case .all:
            backgroundFrame = CGRect(origin: CGPoint(x: 0.0, y: 0.0), size: size)
            self.externalContentBackgroundView.update(size: backgroundFrame.size, corners: DynamicCornerRadiusView.Corners(minXMinY: 11.0, maxXMinY: 11.0, minXMaxY: 11.0, maxXMaxY: 11.0), transition: transition)
        case let .range(from, corners):
            if let itemView = self.itemViews[from], itemView.frame.minY < size.height {
                backgroundFrame = CGRect(origin: CGPoint(x: 0.0, y: itemView.frame.minY), size: CGSize(width: size.width, height: size.height - itemView.frame.minY))
            } else {
                backgroundFrame = CGRect(origin: CGPoint(x: 0.0, y: size.height), size: CGSize(width: size.width, height: 0.0))
            }
            self.externalContentBackgroundView.update(size: backgroundFrame.size, corners: corners, transition: transition)
        }
        if self.automaticallyLayoutExternalContentBackgroundView {
            transition.setFrame(view: self.externalContentBackgroundView, frame: backgroundFrame)
        }
        transition.setAlpha(view: self.externalContentBackgroundView, alpha: backgroundAlpha)
        transition.setCornerRadius(layer: self.layer, cornerRadius: contentCornerRadius)
        
        return UpdateResult(
            size: size,
            backgroundFrame: backgroundFrame
        )
    }
}

public final class ListSectionComponent: Component {
    public typealias ChildView = ListSectionComponentChildView
    
    public enum Background: Equatable {
        case none(clipped: Bool)
        case all
        case range(from: AnyHashable, corners: DynamicCornerRadiusView.Corners)
    }
    
    public let theme: PresentationTheme
    public let background: Background
    public let header: AnyComponent<Empty>?
    public let footer: AnyComponent<Empty>?
    public let items: [AnyComponentWithIdentity<Empty>]
    public let isModal: Bool
    public let displaySeparators: Bool
    public let extendsItemHighlightToSection: Bool
    
    public init(
        theme: PresentationTheme,
        background: Background = .all,
        header: AnyComponent<Empty>?,
        footer: AnyComponent<Empty>?,
        items: [AnyComponentWithIdentity<Empty>],
        isModal: Bool = false,
        displaySeparators: Bool = true,
        extendsItemHighlightToSection: Bool = false
    ) {
        self.theme = theme
        self.background = background
        self.header = header
        self.footer = footer
        self.items = items
        self.isModal = isModal
        self.displaySeparators = displaySeparators
        self.extendsItemHighlightToSection = extendsItemHighlightToSection
    }
    
    public static func ==(lhs: ListSectionComponent, rhs: ListSectionComponent) -> Bool {
        if lhs.theme !== rhs.theme {
            return false
        }
        if lhs.background != rhs.background {
            return false
        }
        if lhs.header != rhs.header {
            return false
        }
        if lhs.footer != rhs.footer {
            return false
        }
        if lhs.items != rhs.items {
            return false
        }
        if lhs.isModal != rhs.isModal {
            return false
        }
        if lhs.displaySeparators != rhs.displaySeparators {
            return false
        }
        if lhs.extendsItemHighlightToSection != rhs.extendsItemHighlightToSection {
            return false
        }
        return true
    }
    
    public final class View: UIView {
        private let contentView: ListSectionContentView
        
        public var contentViewImpl: UIView {
            return self.contentView
        }
        
        private var header: ComponentView<Empty>?
        private var footer: ComponentView<Empty>?
        
        private var component: ListSectionComponent?
        
        public override init(frame: CGRect) {
            self.contentView = ListSectionContentView()
            
            super.init(frame: CGRect())
            
            self.addSubview(self.contentView.externalContentBackgroundView)
            self.addSubview(self.contentView)
        }
        
        required public init?(coder: NSCoder) {
            preconditionFailure()
        }
        
        public func itemView(id: AnyHashable) -> UIView? {
            return self.contentView.itemViews[id]?.contents.view
        }
        
        func update(component: ListSectionComponent, availableSize: CGSize, state: EmptyComponentState, environment: Environment<Empty>, transition: ComponentTransition) -> CGSize {
            self.component = component
            
            let headerSideInset: CGFloat = 16.0
            
            var contentHeight: CGFloat = 0.0
            
            if let headerValue = component.header {
                let header: ComponentView<Empty>
                var headerTransition = transition
                if let current = self.header {
                    header = current
                } else {
                    headerTransition = headerTransition.withAnimation(.none)
                    header = ComponentView()
                    self.header = header
                }
                
                let headerSize = header.update(
                    transition: headerTransition,
                    component: headerValue,
                    environment: {},
                    containerSize: CGSize(width: availableSize.width - headerSideInset * 2.0, height: availableSize.height)
                )
                if let headerView = header.view {
                    if headerView.superview == nil {
                        self.addSubview(headerView)
                    }
                    headerTransition.setFrame(view: headerView, frame: CGRect(origin: CGPoint(x: headerSideInset, y: contentHeight), size: headerSize))
                }
                contentHeight += headerSize.height
            } else {
                if let header = self.header {
                    self.header = nil
                    header.view?.removeFromSuperview()
                }
            }
            
            var readyItems: [ListSectionContentView.ReadyItem] = []
            for i in 0 ..< component.items.count {
                let item = component.items[i]
                let itemId = item.id
                
                let itemView: ListSectionContentView.ItemView
                var itemTransition = transition
                if let current = self.contentView.itemViews[itemId] {
                    itemView = current
                } else {
                    itemTransition = itemTransition.withAnimation(.none)
                    itemView = ListSectionContentView.ItemView()
                    self.contentView.itemViews[itemId] = itemView
                    itemView.contents.parentState = state
                }
                
                let itemSize = itemView.contents.update(
                    transition: itemTransition,
                    component: item.component,
                    environment: {},
                    containerSize: CGSize(width: availableSize.width, height: availableSize.height)
                )
                
                readyItems.append(ListSectionContentView.ReadyItem(
                    id: itemId,
                    itemView: itemView,
                    size: itemSize,
                    transition: itemTransition
                ))
            }
            
            let contentResult = self.contentView.update(
                configuration: ListSectionContentView.Configuration(
                    theme: component.theme,
                    isModal: component.isModal,
                    displaySeparators: component.displaySeparators,
                    extendsItemHighlightToSection: component.extendsItemHighlightToSection,
                    background: component.background
                ),
                width: availableSize.width,
                leftInset: 0.0,
                readyItems: readyItems,
                transition: transition
            )
            let innerContentHeight = contentResult.size.height
            
            if innerContentHeight != 0.0 && contentHeight != 0.0 {
                contentHeight += 7.0
            }
            
            let contentFrame = CGRect(origin: CGPoint(x: 0.0, y: contentHeight), size: CGSize(width: availableSize.width, height: innerContentHeight))
            transition.setFrame(view: self.contentView, frame: contentFrame)
            transition.setFrame(view: self.contentView.externalContentBackgroundView, frame: contentResult.backgroundFrame.offsetBy(dx: contentFrame.minX, dy: contentFrame.minY))

            contentHeight += innerContentHeight
            
            if let footerValue = component.footer {
                let footer: ComponentView<Empty>
                var footerTransition = transition
                if let current = self.footer {
                    footer = current
                } else {
                    footerTransition = footerTransition.withAnimation(.none)
                    footer = ComponentView()
                    self.footer = footer
                }
                
                let footerSize = footer.update(
                    transition: footerTransition,
                    component: footerValue,
                    environment: {},
                    containerSize: CGSize(width: availableSize.width - headerSideInset * 2.0, height: availableSize.height)
                )
                if contentHeight != 0.0 {
                    contentHeight += 7.0
                }
                if let footerView = footer.view {
                    if footerView.superview == nil {
                        self.addSubview(footerView)
                    }
                    footerTransition.setFrame(view: footerView, frame: CGRect(origin: CGPoint(x: headerSideInset, y: contentHeight), size: footerSize))
                }
                contentHeight += footerSize.height
            } else {
                if let footer = self.footer {
                    self.footer = nil
                    footer.view?.removeFromSuperview()
                }
            }
            
            return CGSize(width: availableSize.width, height: contentHeight)
        }
    }
    
    public func makeView() -> View {
        return View(frame: CGRect())
    }
    
    public func update(view: View, availableSize: CGSize, state: EmptyComponentState, environment: Environment<Empty>, transition: ComponentTransition) -> CGSize {
        return view.update(component: self, availableSize: availableSize, state: state, environment: environment, transition: transition)
    }
}

public final class ListSubSectionComponent: Component {
    public typealias ChildView = ListSectionComponentChildView
    
    public let theme: PresentationTheme
    public let leftInset: CGFloat
    public let items: [AnyComponentWithIdentity<Empty>]
    public let isModal: Bool
    public let displaySeparators: Bool
    
    public init(
        theme: PresentationTheme,
        leftInset: CGFloat,
        items: [AnyComponentWithIdentity<Empty>],
        isModal: Bool = false,
        displaySeparators: Bool = true
    ) {
        self.theme = theme
        self.leftInset = leftInset
        self.items = items
        self.isModal = isModal
        self.displaySeparators = displaySeparators
    }
    
    public static func ==(lhs: ListSubSectionComponent, rhs: ListSubSectionComponent) -> Bool {
        if lhs.theme !== rhs.theme {
            return false
        }
        if lhs.leftInset != rhs.leftInset {
            return false
        }
        if lhs.items != rhs.items {
            return false
        }
        if lhs.isModal != rhs.isModal {
            return false
        }
        if lhs.displaySeparators != rhs.displaySeparators {
            return false
        }
        return true
    }
    
    public final class View: UIView, ListSectionComponent.ChildView {
        private let contentView: ListSectionContentView
        
        private var component: ListSubSectionComponent?
        
        public var customUpdateIsHighlighted: ((Bool) -> Void)?
        public var separatorInset: CGFloat = 0.0
        
        public override init(frame: CGRect) {
            self.contentView = ListSectionContentView()
            
            super.init(frame: CGRect())
            
            self.addSubview(self.contentView)
        }
        
        required public init?(coder: NSCoder) {
            preconditionFailure()
        }
        
        public func itemView(id: AnyHashable) -> UIView? {
            return self.contentView.itemViews[id]?.contents.view
        }
        
        func update(component: ListSubSectionComponent, availableSize: CGSize, state: EmptyComponentState, environment: Environment<Empty>, transition: ComponentTransition) -> CGSize {
            self.component = component
            
            var contentHeight: CGFloat = 0.0
            
            var readyItems: [ListSectionContentView.ReadyItem] = []
            for i in 0 ..< component.items.count {
                let item = component.items[i]
                let itemId = item.id
                
                let itemView: ListSectionContentView.ItemView
                var itemTransition = transition
                if let current = self.contentView.itemViews[itemId] {
                    itemView = current
                } else {
                    itemTransition = itemTransition.withAnimation(.none)
                    itemView = ListSectionContentView.ItemView()
                    self.contentView.itemViews[itemId] = itemView
                    itemView.contents.parentState = state
                }
                
                let itemSize = itemView.contents.update(
                    transition: itemTransition,
                    component: item.component,
                    environment: {},
                    containerSize: CGSize(width: availableSize.width - component.leftInset, height: availableSize.height)
                )
                
                readyItems.append(ListSectionContentView.ReadyItem(
                    id: itemId,
                    itemView: itemView,
                    size: itemSize,
                    transition: itemTransition
                ))
            }
            
            let contentResult = self.contentView.update(
                configuration: ListSectionContentView.Configuration(
                    theme: component.theme,
                    isModal: component.isModal,
                    displaySeparators: component.displaySeparators,
                    extendsItemHighlightToSection: false,
                    background: .none(clipped: false)
                ),
                width: availableSize.width - component.leftInset,
                leftInset: 0.0,
                readyItems: readyItems,
                transition: transition
            )
            let innerContentHeight = contentResult.size.height
            
            let contentFrame = CGRect(origin: CGPoint(x: component.leftInset, y: contentHeight), size: CGSize(width: availableSize.width - component.leftInset, height: innerContentHeight))
            transition.setFrame(view: self.contentView, frame: contentFrame)
            transition.setFrame(view: self.contentView.externalContentBackgroundView, frame: contentResult.backgroundFrame.offsetBy(dx: contentFrame.minX, dy: contentFrame.minY))

            contentHeight += innerContentHeight
            
            self.separatorInset = component.leftInset
            
            return CGSize(width: availableSize.width, height: contentHeight)
        }
    }
    
    public func makeView() -> View {
        return View(frame: CGRect())
    }
    
    public func update(view: View, availableSize: CGSize, state: EmptyComponentState, environment: Environment<Empty>, transition: ComponentTransition) -> CGSize {
        return view.update(component: self, availableSize: availableSize, state: state, environment: environment, transition: transition)
    }
}

