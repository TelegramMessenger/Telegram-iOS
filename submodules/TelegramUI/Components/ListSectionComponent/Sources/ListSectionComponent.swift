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
    public let displaySeparators: Bool
    public let extendsItemHighlightToSection: Bool
    
    public init(
        theme: PresentationTheme,
        background: Background = .all,
        header: AnyComponent<Empty>?,
        footer: AnyComponent<Empty>?,
        items: [AnyComponentWithIdentity<Empty>],
        displaySeparators: Bool = true,
        extendsItemHighlightToSection: Bool = false
    ) {
        self.theme = theme
        self.background = background
        self.header = header
        self.footer = footer
        self.items = items
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
        if lhs.displaySeparators != rhs.displaySeparators {
            return false
        }
        if lhs.extendsItemHighlightToSection != rhs.extendsItemHighlightToSection {
            return false
        }
        return true
    }
    
    private final class ItemView: UIView {
        let contents = ComponentView<Empty>()
        let separatorLayer = SimpleLayer()
        let highlightLayer = SimpleLayer()
        
        override init(frame: CGRect) {
            super.init(frame: frame)
        }
        
        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }
    }
    
    public final class View: UIView {
        private let contentView: UIView
        private let contentSeparatorContainerLayer: SimpleLayer
        private let contentHighlightContainerLayer: SimpleLayer
        private let contentItemContainerView: UIView
        private let contentBackgroundView: DynamicCornerRadiusView
        
        private var header: ComponentView<Empty>?
        private var footer: ComponentView<Empty>?
        private var itemViews: [AnyHashable: ItemView] = [:]
        
        private var highlightedItemId: AnyHashable?
        
        private var component: ListSectionComponent?
        
        public override init(frame: CGRect) {
            self.contentView = UIView()
            self.contentView.clipsToBounds = true
            
            self.contentSeparatorContainerLayer = SimpleLayer()
            self.contentHighlightContainerLayer = SimpleLayer()
            self.contentItemContainerView = UIView()
            
            self.contentBackgroundView = DynamicCornerRadiusView()
            
            super.init(frame: CGRect())
            
            self.addSubview(self.contentBackgroundView)
            self.addSubview(self.contentView)
            
            self.contentView.layer.addSublayer(self.contentSeparatorContainerLayer)
            self.contentView.layer.addSublayer(self.contentHighlightContainerLayer)
            self.contentView.addSubview(self.contentItemContainerView)
        }
        
        required public init?(coder: NSCoder) {
            preconditionFailure()
        }
        
        private func updateHighlightedItem(itemId: AnyHashable?) {
            if self.highlightedItemId == itemId {
                return
            }
            let previousHighlightedItemId = self.highlightedItemId
            self.highlightedItemId = itemId
            
            guard let component = self.component else {
                return
            }
            
            if component.extendsItemHighlightToSection {
                let transition: Transition
                let backgroundColor: UIColor
                if itemId != nil {
                    transition = .immediate
                    backgroundColor = component.theme.list.itemHighlightedBackgroundColor
                } else {
                    transition = .easeInOut(duration: 0.2)
                    backgroundColor = component.theme.list.itemBlocksBackgroundColor
                }
                
                self.contentBackgroundView.updateColor(color: backgroundColor, transition: transition)
            } else {
                if let previousHighlightedItemId, let previousItemView = self.itemViews[previousHighlightedItemId] {
                    Transition.easeInOut(duration: 0.2).setBackgroundColor(layer: previousItemView.highlightLayer, color: .clear)
                }
                if let itemId, let itemView = self.itemViews[itemId] {
                    Transition.immediate.setBackgroundColor(layer: itemView.highlightLayer, color: component.theme.list.itemHighlightedBackgroundColor)
                }
            }
        }
        
        func update(component: ListSectionComponent, availableSize: CGSize, state: EmptyComponentState, environment: Environment<Empty>, transition: Transition) -> CGSize {
            self.component = component
            
            let backgroundColor: UIColor
            if self.highlightedItemId != nil && component.extendsItemHighlightToSection {
                backgroundColor = component.theme.list.itemHighlightedBackgroundColor
            } else {
                backgroundColor = component.theme.list.itemBlocksBackgroundColor
            }
            self.contentBackgroundView.updateColor(color: backgroundColor, transition: transition)
            
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
            
            var innerContentHeight: CGFloat = 0.0
            var validItemIds: [AnyHashable] = []
            for i in 0 ..< component.items.count {
                let item = component.items[i]
                let itemId = item.id
                validItemIds.append(itemId)
                
                let itemView: ItemView
                var itemTransition = transition
                if let current = self.itemViews[itemId] {
                    itemView = current
                } else {
                    itemTransition = itemTransition.withAnimation(.none)
                    itemView = ItemView()
                    self.itemViews[itemId] = itemView
                }
                
                let itemSize = itemView.contents.update(
                    transition: itemTransition,
                    component: item.component,
                    environment: {},
                    containerSize: CGSize(width: availableSize.width, height: availableSize.height)
                )
                let itemFrame = CGRect(origin: CGPoint(x: 0.0, y: innerContentHeight), size: itemSize)
                if let itemComponentView = itemView.contents.view {
                    if itemComponentView.superview == nil {
                        itemView.addSubview(itemComponentView)
                        self.contentItemContainerView.addSubview(itemView)
                        self.contentSeparatorContainerLayer.addSublayer(itemView.separatorLayer)
                        self.contentHighlightContainerLayer.addSublayer(itemView.highlightLayer)
                        transition.animateAlpha(view: itemView, from: 0.0, to: 1.0)
                        transition.animateAlpha(layer: itemView.separatorLayer, from: 0.0, to: 1.0)
                        transition.animateAlpha(layer: itemView.highlightLayer, from: 0.0, to: 1.0)
                        
                        if let itemComponentView = itemComponentView as? ChildView {
                            itemComponentView.customUpdateIsHighlighted = { [weak self] isHighlighted in
                                guard let self else {
                                    return
                                }
                                self.updateHighlightedItem(itemId: isHighlighted ? itemId : nil)
                            }
                        }
                    }
                    var separatorInset: CGFloat = 0.0
                    if let itemComponentView = itemComponentView as? ChildView {
                        separatorInset = itemComponentView.separatorInset
                    }
                    itemTransition.setFrame(view: itemView, frame: itemFrame)
                    
                    let itemSeparatorTopOffset: CGFloat = i == 0 ? 0.0 : -UIScreenPixel
                    let itemHighlightFrame = CGRect(origin: CGPoint(x: itemFrame.minX, y: itemFrame.minY + itemSeparatorTopOffset), size: CGSize(width: itemFrame.width, height: itemFrame.height - itemSeparatorTopOffset))
                    itemTransition.setFrame(layer: itemView.highlightLayer, frame: itemHighlightFrame)
                    
                    itemTransition.setFrame(view: itemComponentView, frame: CGRect(origin: CGPoint(), size: itemFrame.size))
                    
                    let itemSeparatorFrame = CGRect(origin: CGPoint(x: separatorInset, y: itemFrame.maxY - UIScreenPixel), size: CGSize(width: availableSize.width - separatorInset, height: UIScreenPixel))
                    itemTransition.setFrame(layer: itemView.separatorLayer, frame: itemSeparatorFrame)
                    
                    let separatorAlpha: CGFloat
                    if component.displaySeparators {
                        if i != component.items.count - 1 {
                            separatorAlpha = 1.0
                        } else {
                            separatorAlpha = 0.0
                        }
                    } else {
                        separatorAlpha = 0.0
                    }
                    itemTransition.setAlpha(layer: itemView.separatorLayer, alpha: separatorAlpha)
                    itemView.separatorLayer.backgroundColor = component.theme.list.itemBlocksSeparatorColor.cgColor
                }
                innerContentHeight += itemSize.height
            }
            var removedItemIds: [AnyHashable] = []
            for (id, itemView) in self.itemViews {
                if !validItemIds.contains(id) {
                    removedItemIds.append(id)
                    
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
            
            if innerContentHeight != 0.0 && contentHeight != 0.0 {
                contentHeight += 7.0
            }
            
            let contentFrame = CGRect(origin: CGPoint(x: 0.0, y: contentHeight), size: CGSize(width: availableSize.width, height: innerContentHeight))
            transition.setFrame(view: self.contentView, frame: contentFrame)
            
            transition.setFrame(view: self.contentItemContainerView, frame: CGRect(origin: CGPoint(), size: contentFrame.size))
            transition.setFrame(layer: self.contentSeparatorContainerLayer, frame: CGRect(origin: CGPoint(), size: contentFrame.size))
            transition.setFrame(layer: self.contentHighlightContainerLayer, frame: CGRect(origin: CGPoint(), size: contentFrame.size))
            
            let backgroundFrame: CGRect
            var backgroundAlpha: CGFloat = 1.0
            var contentCornerRadius: CGFloat = 11.0
            switch component.background {
            case let .none(clipped):
                backgroundFrame = contentFrame
                backgroundAlpha = 0.0
                self.contentBackgroundView.update(size: backgroundFrame.size, corners: DynamicCornerRadiusView.Corners(minXMinY: 11.0, maxXMinY: 11.0, minXMaxY: 11.0, maxXMaxY: 11.0), transition: transition)
                if !clipped {
                    contentCornerRadius = 0.0
                }
            case .all:
                backgroundFrame = contentFrame
                self.contentBackgroundView.update(size: backgroundFrame.size, corners: DynamicCornerRadiusView.Corners(minXMinY: 11.0, maxXMinY: 11.0, minXMaxY: 11.0, maxXMaxY: 11.0), transition: transition)
            case let .range(from, corners):
                if let itemView = self.itemViews[from], itemView.frame.minY < contentFrame.height {
                    backgroundFrame = CGRect(origin: CGPoint(x: 0.0, y: contentFrame.minY + itemView.frame.minY), size: CGSize(width: contentFrame.width, height: contentFrame.height - itemView.frame.minY))
                } else {
                    backgroundFrame = CGRect(origin: CGPoint(x: contentFrame.minY, y: contentFrame.height), size: CGSize(width: contentFrame.width, height: 0.0))
                }
                self.contentBackgroundView.update(size: backgroundFrame.size, corners: corners, transition: transition)
            }
            transition.setFrame(view: self.contentBackgroundView, frame: backgroundFrame)
            transition.setAlpha(view: self.contentBackgroundView, alpha: backgroundAlpha)
            transition.setCornerRadius(layer: self.contentView.layer, cornerRadius: contentCornerRadius)

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
    
    public func update(view: View, availableSize: CGSize, state: EmptyComponentState, environment: Environment<Empty>, transition: Transition) -> CGSize {
        return view.update(component: self, availableSize: availableSize, state: state, environment: environment, transition: transition)
    }
}
