import Foundation
import UIKit
import ComponentFlow
import Display

public final class PrefixSectionGroupComponent: Component {
    public final class Item: Equatable {
        public let prefix: AnyComponentWithIdentity<Empty>
        public let content: AnyComponentWithIdentity<Empty>
        
        public init(prefix: AnyComponentWithIdentity<Empty>, content: AnyComponentWithIdentity<Empty>) {
            self.prefix = prefix
            self.content = content
        }
        
        public static func ==(lhs: Item, rhs: Item) -> Bool {
            if lhs.prefix != rhs.prefix {
                return false
            }
            if lhs.content != rhs.content {
                return false
            }
            
            return true
        }
    }
    
    public let items: [Item]
    public let backgroundColor: UIColor
    public let separatorColor: UIColor
    
    public init(
        items: [Item],
        backgroundColor: UIColor,
        separatorColor: UIColor
    ) {
        self.items = items
        self.backgroundColor = backgroundColor
        self.separatorColor = separatorColor
    }
    
    public static func ==(lhs: PrefixSectionGroupComponent, rhs: PrefixSectionGroupComponent) -> Bool {
        if lhs.items != rhs.items {
            return false
        }
        if lhs.backgroundColor != rhs.backgroundColor {
            return false
        }
        if lhs.separatorColor != rhs.separatorColor {
            return false
        }
        return true
    }
    
    public final class View: UIView {
        private let backgroundView: UIView
        private var itemViews: [AnyHashable: ComponentHostView<Empty>] = [:]
        private var separatorViews: [UIView] = []
        
        override init(frame: CGRect) {
            self.backgroundView = UIView()
            
            super.init(frame: frame)
            
            self.addSubview(self.backgroundView)
            self.backgroundView.layer.cornerRadius = 10.0
            self.backgroundView.layer.masksToBounds = true
        }
        
        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }
        
        func update(component: PrefixSectionGroupComponent, availableSize: CGSize, state: EmptyComponentState, environment: Environment<Empty>, transition: Transition) -> CGSize {
            let spacing: CGFloat = 16.0
            let sideInset: CGFloat = 16.0
            
            self.backgroundView.backgroundColor = component.backgroundColor
            
            var size = CGSize(width: availableSize.width, height: 0.0)
            
            var validIds: [AnyHashable] = []
            
            var maxPrefixSize = CGSize()
            var prefixItemSizes: [CGSize] = []
            for item in component.items {
                validIds.append(item.prefix.id)
                
                let itemView: ComponentHostView<Empty>
                var itemTransition = transition
                if let current = self.itemViews[item.prefix.id] {
                    itemView = current
                } else {
                    itemTransition = transition.withAnimation(.none)
                    itemView = ComponentHostView<Empty>()
                    self.itemViews[item.prefix.id] = itemView
                    self.addSubview(itemView)
                }
                let itemSize = itemView.update(
                    transition: itemTransition,
                    component: item.prefix.component,
                    environment: {},
                    containerSize: CGSize(width: size.width, height: .greatestFiniteMagnitude)
                )
                prefixItemSizes.append(itemSize)
                maxPrefixSize.width = max(maxPrefixSize.width, itemSize.width)
                maxPrefixSize.height = max(maxPrefixSize.height, itemSize.height)
            }
            
            var maxContentSize = CGSize()
            var contentItemSizes: [CGSize] = []
            for item in component.items {
                validIds.append(item.content.id)
                
                let itemView: ComponentHostView<Empty>
                var itemTransition = transition
                if let current = self.itemViews[item.content.id] {
                    itemView = current
                } else {
                    itemTransition = transition.withAnimation(.none)
                    itemView = ComponentHostView<Empty>()
                    self.itemViews[item.content.id] = itemView
                    self.addSubview(itemView)
                }
                let itemSize = itemView.update(
                    transition: itemTransition,
                    component: item.content.component,
                    environment: {},
                    containerSize: CGSize(width: size.width - maxPrefixSize.width - sideInset - spacing, height: .greatestFiniteMagnitude)
                )
                contentItemSizes.append(itemSize)
                maxContentSize.width = max(maxContentSize.width, itemSize.width)
                maxContentSize.height = max(maxContentSize.height, itemSize.height)
            }
            
            for i in 0 ..< component.items.count {
                let itemSize = CGSize(width: size.width, height: max(prefixItemSizes[i].height, contentItemSizes[i].height))
                let itemFrame = CGRect(origin: CGPoint(x: 0.0, y: size.height), size: itemSize)
                
                let prefixView = itemViews[component.items[i].prefix.id]!
                let contentView = itemViews[component.items[i].content.id]!
                
                prefixView.frame = CGRect(origin: CGPoint(x: sideInset, y: itemFrame.minY + floor((itemFrame.height - prefixItemSizes[i].height) / 2.0)), size: prefixItemSizes[i])
                
                contentView.frame = CGRect(origin: CGPoint(x: itemFrame.minX + sideInset + maxPrefixSize.width + spacing, y: itemFrame.minY + floor((itemFrame.height - contentItemSizes[i].height) / 2.0)), size: contentItemSizes[i])
                
                size.height += itemSize.height
                
                if i != component.items.count - 1 {
                    let separatorView: UIView
                    if self.separatorViews.count > i {
                        separatorView = self.separatorViews[i]
                    } else {
                        separatorView = UIView()
                        self.separatorViews.append(separatorView)
                        self.addSubview(separatorView)
                    }
                    separatorView.backgroundColor = component.separatorColor
                    separatorView.frame = CGRect(origin: CGPoint(x: itemFrame.minX + sideInset, y: itemFrame.maxY), size: CGSize(width: itemFrame.width - sideInset, height: UIScreenPixel))
                }
            }
            
            var removeIds: [AnyHashable] = []
            for (id, itemView) in self.itemViews {
                if !validIds.contains(id) {
                    removeIds.append(id)
                    itemView.removeFromSuperview()
                }
            }
            for id in removeIds {
                self.itemViews.removeValue(forKey: id)
            }
            
            if self.separatorViews.count > component.items.count - 1 {
                for i in (component.items.count - 1) ..< self.separatorViews.count {
                    self.separatorViews[i].removeFromSuperview()
                }
                self.separatorViews.removeSubrange((component.items.count - 1) ..< self.separatorViews.count)
            }
            
            transition.setFrame(view: self.backgroundView, frame: CGRect(origin: CGPoint(), size: size), completion: nil)
            
            return size
        }
    }
    
    public func makeView() -> View {
        return View(frame: CGRect())
    }
    
    public func update(view: View, availableSize: CGSize, state: EmptyComponentState, environment: Environment<Empty>, transition: Transition) -> CGSize {
        return view.update(component: self, availableSize: availableSize, state: state, environment: environment, transition: transition)
    }
}
