import Foundation
import UIKit
import Display
import ComponentFlow
import AppBundle
import ComponentDisplayAdapters

public final class StoryActionsComponent: Component {
    public struct Item: Equatable {
        public enum Kind {
            case like
            case share
        }
        
        public let kind: Kind
        public let isActivated: Bool
        
        public init(kind: Kind, isActivated: Bool) {
            self.kind = kind
            self.isActivated = isActivated
        }
    }
    
    public let items: [Item]
    public let action: (Item) -> Void
    
    public init(
        items: [Item],
        action: @escaping (Item) -> Void
    ) {
        self.items = items
        self.action = action
    }
    
    public static func ==(lhs: StoryActionsComponent, rhs: StoryActionsComponent) -> Bool {
        if lhs.items != rhs.items {
            return false
        }
        return true
    }
    
    private final class ItemView: HighlightTrackingButton {
        let action: (Item) -> Void
        
        let maskBackgroundView = UIImageView()
        let iconView: UIImageView
        
        private var item: Item?
        
        init(action: @escaping (Item) -> Void) {
            self.action = action
            
            self.iconView = UIImageView()
            
            super.init(frame: CGRect())
            
            self.addSubview(self.iconView)
            
            self.highligthedChanged = { [weak self] highlighted in
                guard let self else {
                    return
                }
                
                let scale: CGFloat = highlighted ? 0.6 : 1.0
                
                let transition = Transition(animation: .curve(duration: highlighted ? 0.5 : 0.3, curve: .spring))
                transition.setSublayerTransform(view: self, transform: CATransform3DMakeScale(scale, scale, 1.0))
                transition.setScale(view: self.maskBackgroundView, scale: scale)
            }
            self.addTarget(self, action: #selector(self.pressed), for: .touchUpInside)
        }
        
        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }
        
        @objc private func pressed() {
            guard let item = self.item else {
                return
            }
            self.action(item)
        }
        
        func update(item: Item, size: CGSize, transition: Transition) {
            if self.item == item {
                return
            }
            self.item = item
            
            switch item.kind {
            case .like:
                self.iconView.image = UIImage(bundleImageName: "Media Gallery/InlineLike")?.withRenderingMode(.alwaysTemplate)
            case .share:
                self.iconView.image = UIImage(bundleImageName: "Media Gallery/InlineShare")?.withRenderingMode(.alwaysTemplate)
            }
            
            self.iconView.tintColor = item.isActivated ? UIColor(rgb: 0xFF6F66) : UIColor.white
            
            if let image = self.iconView.image {
                transition.setFrame(view: self.iconView, frame: CGRect(origin: CGPoint(x: floor((size.width - image.size.width) * 0.5), y: floor((size.height - image.size.height) * 0.5)), size: image.size))
            }
        }
    }
    
    public final class View: UIView {
        private let backgroundView: BlurredBackgroundView
        private let backgroundMaskView: UIView
        
        private var itemViews: [Item.Kind: ItemView] = [:]
        
        private var component: StoryActionsComponent?
        private weak var componentState: EmptyComponentState?
        
        override init(frame: CGRect) {
            self.backgroundView = BlurredBackgroundView(color: nil, enableBlur: true)
            self.backgroundMaskView = UIView()
            self.backgroundView.mask = self.backgroundMaskView
            
            super.init(frame: frame)
            
            self.addSubview(self.backgroundView)
        }
        
        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }
        
        func update(component: StoryActionsComponent, availableSize: CGSize, state: EmptyComponentState, environment: Environment<Empty>, transition: Transition) -> CGSize {
            self.component = component
            self.componentState = state
            
            var contentHeight: CGFloat = 0.0
            var validIds: [Item.Kind] = []
            for item in component.items {
                validIds.append(item.kind)
                
                let itemView: ItemView
                var itemTransition = transition
                if let current = self.itemViews[item.kind] {
                    itemView = current
                } else {
                    itemTransition = .immediate
                    itemView = ItemView(action: { [weak self] item in
                        self?.component?.action(item)
                    })
                    self.itemViews[item.kind] = itemView
                    self.addSubview(itemView)
                    
                    itemView.maskBackgroundView.image = generateFilledCircleImage(diameter: 44.0, color: .white)
                    self.backgroundMaskView.addSubview(itemView.maskBackgroundView)
                }
                
                if !contentHeight.isZero {
                    contentHeight += 10.0
                }
                let itemFrame = CGRect(origin: CGPoint(x: 0.0, y: contentHeight), size: CGSize(width: 44.0, height: 44.0))
                itemView.update(item: item, size: itemFrame.size, transition: itemTransition)
                itemTransition.setFrame(view: itemView, frame: itemFrame)
                itemTransition.setPosition(view: itemView.maskBackgroundView, position: itemFrame.center)
                itemTransition.setBounds(view: itemView.maskBackgroundView, bounds: CGRect(origin: CGPoint(), size: itemFrame.size))
                
                contentHeight += itemFrame.height
            }
            
            let contentSize = CGSize(width: 44.0, height: contentHeight)
            transition.setFrame(view: self.backgroundView, frame: CGRect(origin: CGPoint(), size: contentSize))
            self.backgroundView.updateColor(color: UIColor(white: 0.0, alpha: 0.3), transition: .immediate)
            self.backgroundView.update(size: contentSize, transition: transition.containedViewLayoutTransition)
            
            return contentSize
        }
    }
    
    public func makeView() -> View {
        return View(frame: CGRect())
    }
    
    public func update(view: View, availableSize: CGSize, state: EmptyComponentState, environment: Environment<Empty>, transition: Transition) -> CGSize {
        return view.update(component: self, availableSize: availableSize, state: state, environment: environment, transition: transition)
    }
}
