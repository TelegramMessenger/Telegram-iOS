import Foundation
import UIKit
import Display
import ComponentFlow
import TelegramPresentationData
import DynamicCornerRadiusView

public protocol ListSectionComponentChildView: AnyObject {
    var customUpdateIsHighlighted: ((Bool) -> Void)? { get set }
}

public final class ListSectionComponent: Component {
    public typealias ChildView = ListSectionComponentChildView
    
    public enum Background: Equatable {
        case none
        case all
        case range(from: AnyHashable, corners: DynamicCornerRadiusView.Corners)
    }
    
    public let theme: PresentationTheme
    public let background: Background
    public let header: AnyComponent<Empty>?
    public let footer: AnyComponent<Empty>?
    public let items: [AnyComponentWithIdentity<Empty>]
    
    public init(
        theme: PresentationTheme,
        background: Background = .all,
        header: AnyComponent<Empty>?,
        footer: AnyComponent<Empty>?,
        items: [AnyComponentWithIdentity<Empty>]
    ) {
        self.theme = theme
        self.background = background
        self.header = header
        self.footer = footer
        self.items = items
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
        return true
    }
    
    public final class View: UIView {
        private let contentView: UIView
        private let contentBackgroundView: DynamicCornerRadiusView
        
        private var header: ComponentView<Empty>?
        private var footer: ComponentView<Empty>?
        private var itemViews: [AnyHashable: ComponentView<Empty>] = [:]
        
        private var isHighlighted: Bool = false
        
        private var component: ListSectionComponent?
        
        public override init(frame: CGRect) {
            self.contentView = UIView()
            self.contentView.layer.cornerRadius = 11.0
            self.contentView.clipsToBounds = true
            
            self.contentBackgroundView = DynamicCornerRadiusView()
            
            super.init(frame: CGRect())
            
            self.addSubview(self.contentBackgroundView)
            self.addSubview(self.contentView)
        }
        
        required public init?(coder: NSCoder) {
            preconditionFailure()
        }
        
        private func updateIsHighlighted(isHighlighted: Bool) {
            if self.isHighlighted == isHighlighted {
                return
            }
            self.isHighlighted = isHighlighted
            
            guard let component = self.component else {
                return
            }
            
            let transition: Transition
            let backgroundColor: UIColor
            if isHighlighted {
                transition = .immediate
                backgroundColor = component.theme.list.itemHighlightedBackgroundColor
            } else {
                transition = .easeInOut(duration: 0.2)
                backgroundColor = component.theme.list.itemBlocksBackgroundColor
            }
            self.contentBackgroundView.updateColor(color: backgroundColor, transition: transition)
        }
        
        func update(component: ListSectionComponent, availableSize: CGSize, state: EmptyComponentState, environment: Environment<Empty>, transition: Transition) -> CGSize {
            self.component = component
            
            let backgroundColor: UIColor
            if self.isHighlighted {
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
            for item in component.items {
                validItemIds.append(item.id)
                
                let itemView: ComponentView<Empty>
                var itemTransition = transition
                if let current = self.itemViews[item.id] {
                    itemView = current
                } else {
                    itemTransition = itemTransition.withAnimation(.none)
                    itemView = ComponentView()
                    self.itemViews[item.id] = itemView
                }
                
                let itemSize = itemView.update(
                    transition: itemTransition,
                    component: item.component,
                    environment: {},
                    containerSize: CGSize(width: availableSize.width, height: availableSize.height)
                )
                let itemFrame = CGRect(origin: CGPoint(x: 0.0, y: innerContentHeight), size: itemSize)
                if let itemComponentView = itemView.view {
                    if itemComponentView.superview == nil {
                        self.contentView.addSubview(itemComponentView)
                        transition.animateAlpha(view: itemComponentView, from: 0.0, to: 1.0)
                        
                        if let itemComponentView = itemComponentView as? ChildView {
                            itemComponentView.customUpdateIsHighlighted = { [weak self] isHighlighted in
                                guard let self else {
                                    return
                                }
                                self.updateIsHighlighted(isHighlighted: isHighlighted)
                            }
                        }
                    }
                    itemTransition.setFrame(view: itemComponentView, frame: itemFrame)
                }
                innerContentHeight += itemSize.height
            }
            var removedItemIds: [AnyHashable] = []
            for (id, itemView) in self.itemViews {
                if !validItemIds.contains(id) {
                    removedItemIds.append(id)
                    
                    if let itemComponentView = itemView.view {
                        transition.setAlpha(view: itemComponentView, alpha: 0.0, completion: { [weak itemComponentView] _ in
                            itemComponentView?.removeFromSuperview()
                        })
                    }
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
            
            let backgroundFrame: CGRect
            var backgroundAlpha: CGFloat = 1.0
            switch component.background {
            case .none:
                backgroundFrame = contentFrame
                backgroundAlpha = 0.0
                self.contentBackgroundView.update(size: backgroundFrame.size, corners: DynamicCornerRadiusView.Corners(minXMinY: 11.0, maxXMinY: 11.0, minXMaxY: 11.0, maxXMaxY: 11.0), transition: transition)
            case .all:
                backgroundFrame = contentFrame
                self.contentBackgroundView.update(size: backgroundFrame.size, corners: DynamicCornerRadiusView.Corners(minXMinY: 11.0, maxXMinY: 11.0, minXMaxY: 11.0, maxXMaxY: 11.0), transition: transition)
            case let .range(from, corners):
                if let itemComponentView = self.itemViews[from]?.view, itemComponentView.frame.minY < contentFrame.height {
                    backgroundFrame = CGRect(origin: CGPoint(x: 0.0, y: contentFrame.minY + itemComponentView.frame.minY), size: CGSize(width: contentFrame.width, height: contentFrame.height - itemComponentView.frame.minY))
                } else {
                    backgroundFrame = CGRect(origin: CGPoint(x: contentFrame.minY, y: contentFrame.height), size: CGSize(width: contentFrame.width, height: 0.0))
                }
                self.contentBackgroundView.update(size: backgroundFrame.size, corners: corners, transition: transition)
            }
            transition.setFrame(view: self.contentBackgroundView, frame: backgroundFrame)
            transition.setAlpha(view: self.contentBackgroundView, alpha: backgroundAlpha)
            
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
