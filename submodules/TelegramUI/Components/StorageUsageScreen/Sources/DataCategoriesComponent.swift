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
import CheckNode
import SolidRoundedButtonComponent

final class DataCategoriesComponent: Component {
    struct CategoryData: Equatable {
        var key: DataUsageScreenComponent.Category
        var color: UIColor
        var title: String
        var size: Int64
        var sizeFraction: Double
        var incoming: Int64
        var outgoing: Int64
        var isSeparable: Bool
        var isExpanded: Bool
        
        init(key: DataUsageScreenComponent.Category, color: UIColor, title: String, size: Int64, sizeFraction: Double, incoming: Int64, outgoing: Int64, isSeparable: Bool, isExpanded: Bool) {
            self.key = key
            self.title = title
            self.color = color
            self.size = size
            self.sizeFraction = sizeFraction
            self.incoming = incoming
            self.outgoing = outgoing
            self.isSeparable = isSeparable
            self.isExpanded = isExpanded
        }
    }
    
    let theme: PresentationTheme
    let strings: PresentationStrings
    let categories: [CategoryData]
    let toggleCategoryExpanded: ((DataUsageScreenComponent.Category) -> Void)?
    
    init(
        theme: PresentationTheme,
        strings: PresentationStrings,
        categories: [CategoryData],
        toggleCategoryExpanded: ((DataUsageScreenComponent.Category) -> Void)?
    ) {
        self.theme = theme
        self.strings = strings
        self.categories = categories
        self.toggleCategoryExpanded = toggleCategoryExpanded
    }
    
    static func ==(lhs: DataCategoriesComponent, rhs: DataCategoriesComponent) -> Bool {
        if lhs.theme !== rhs.theme {
            return false
        }
        if lhs.strings !== rhs.strings {
            return false
        }
        if lhs.categories != rhs.categories {
            return false
        }
        return true
    }
    
    class View: UIView {
        private let containerView: UIView
        private var itemViews: [DataUsageScreenComponent.Category: ComponentView<Empty>] = [:]
        
        private var component: DataCategoriesComponent?
        private weak var state: EmptyComponentState?
        
        override init(frame: CGRect) {
            self.containerView = UIView()
            
            super.init(frame: frame)
            
            self.clipsToBounds = true
            self.layer.cornerRadius = 10.0
            
            self.addSubview(self.containerView)
        }
        
        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }
        
        func update(component: DataCategoriesComponent, availableSize: CGSize, state: EmptyComponentState, environment: Environment<Empty>, transition: Transition) -> CGSize {
            self.component = component
            self.state = state
            
            var itemsTransition = transition
            if let animationHint = transition.userData(DataUsageScreenComponent.AnimationHint.self) {
                switch animationHint.value {
                case .clearedItems, .modeChanged:
                    if let copyView = self.containerView.snapshotView(afterScreenUpdates: false) {
                        itemsTransition = .immediate
                        
                        self.addSubview(copyView)
                        self.containerView.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.16)
                        copyView.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.2, removeOnCompletion: false, completion: { [weak copyView] _ in
                            copyView?.removeFromSuperview()
                        })
                    }
                }
            }
            
            var contentHeight: CGFloat = 0.0
            
            var validKeys = Set<DataUsageScreenComponent.Category>()
            for i in 0 ..< component.categories.count {
                let category = component.categories[i]
                validKeys.insert(category.key)
                
                var itemTransition = itemsTransition
                let itemView: ComponentView<Empty>
                if let current = self.itemViews[category.key] {
                    itemView = current
                } else {
                    itemTransition = .immediate
                    itemView = ComponentView()
                    itemView.parentState = state
                    self.itemViews[category.key] = itemView
                }
                
                let itemSize = itemView.update(
                    transition: itemTransition,
                    component: AnyComponent(DataCategoryItemComponent(
                        theme: component.theme,
                        strings: component.strings,
                        category: category,
                        isExpanded: category.isExpanded,
                        hasNext: i != component.categories.count - 1,
                        action: component.toggleCategoryExpanded == nil ? nil : { [weak self] key in
                            guard let self, let component = self.component else {
                                return
                            }
                            component.toggleCategoryExpanded?(key)
                        }
                    )),
                    environment: {},
                    containerSize: CGSize(width: availableSize.width, height: 1000.0)
                )
                let itemFrame = CGRect(origin: CGPoint(x: 0.0, y: contentHeight), size: itemSize)
                if let itemComponentView = itemView.view {
                    if itemComponentView.superview == nil {
                        self.containerView.addSubview(itemComponentView)
                    }
                    itemTransition.setFrame(view: itemComponentView, frame: itemFrame)
                }
                
                contentHeight += itemSize.height
            }
            
            var removeKeys: [DataUsageScreenComponent.Category] = []
            for (key, itemView) in self.itemViews {
                if !validKeys.contains(key) {
                    if let itemComponentView = itemView.view {
                        transition.setAlpha(view: itemComponentView, alpha: 0.0, completion: { [weak itemComponentView] _ in
                            itemComponentView?.removeFromSuperview()
                        })
                    }
                    removeKeys.append(key)
                }
            }
            for key in removeKeys {
                self.itemViews.removeValue(forKey: key)
            }
            
            self.backgroundColor = component.theme.list.itemBlocksBackgroundColor
            self.containerView.backgroundColor = component.theme.list.itemBlocksBackgroundColor
            
            self.containerView.frame = CGRect(origin: CGPoint(), size: CGSize(width: availableSize.width, height: contentHeight))
            
            return CGSize(width: availableSize.width, height: contentHeight)
        }
    }
    
    func makeView() -> View {
        return View(frame: CGRect())
    }
    
    func update(view: View, availableSize: CGSize, state: EmptyComponentState, environment: Environment<Empty>, transition: Transition) -> CGSize {
        return view.update(component: self, availableSize: availableSize, state: state, environment: environment, transition: transition)
    }
}
