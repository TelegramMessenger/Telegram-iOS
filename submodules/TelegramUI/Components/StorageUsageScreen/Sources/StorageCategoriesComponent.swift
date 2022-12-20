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
import Postbox
import CheckNode
import SolidRoundedButtonComponent

final class StorageCategoriesComponent: Component {
    struct CategoryData: Equatable {
        var key: AnyHashable
        var color: UIColor
        var title: String
        var size: Int64
        var sizeFraction: Double
        var isSelected: Bool
        var subcategories: [CategoryData]
        
        init(key: AnyHashable, color: UIColor, title: String, size: Int64, sizeFraction: Double, isSelected: Bool, subcategories: [CategoryData]) {
            self.key = key
            self.title = title
            self.color = color
            self.size = size
            self.sizeFraction = sizeFraction
            self.isSelected = isSelected
            self.subcategories = subcategories
        }
    }
    
    let theme: PresentationTheme
    let strings: PresentationStrings
    let categories: [CategoryData]
    let toggleCategorySelection: (AnyHashable) -> Void
    
    init(
        theme: PresentationTheme,
        strings: PresentationStrings,
        categories: [CategoryData],
        toggleCategorySelection: @escaping (AnyHashable) -> Void
    ) {
        self.theme = theme
        self.strings = strings
        self.categories = categories
        self.toggleCategorySelection = toggleCategorySelection
    }
    
    static func ==(lhs: StorageCategoriesComponent, rhs: StorageCategoriesComponent) -> Bool {
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
        private var itemViews: [AnyHashable: ComponentView<Empty>] = [:]
        private let button = ComponentView<Empty>()
        
        private var expandedCategory: AnyHashable?
        private var component: StorageCategoriesComponent?
        private weak var state: EmptyComponentState?
        
        override init(frame: CGRect) {
            super.init(frame: frame)
            
            self.clipsToBounds = true
            self.layer.cornerRadius = 10.0
        }
        
        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }
        
        func update(component: StorageCategoriesComponent, availableSize: CGSize, state: EmptyComponentState, environment: Environment<Empty>, transition: Transition) -> CGSize {
            self.component = component
            self.state = state
            
            var totalSelectedSize: Int64 = 0
            var hasDeselected = false
            for category in component.categories {
                if !category.subcategories.isEmpty {
                    for subcategory in category.subcategories {
                        if subcategory.isSelected {
                            totalSelectedSize += subcategory.size
                        } else {
                            hasDeselected = true
                        }
                    }
                } else {
                    if category.isSelected {
                        totalSelectedSize += category.size
                    } else {
                        hasDeselected = true
                    }
                }
            }
            
            var contentHeight: CGFloat = 0.0
            
            var validKeys = Set<AnyHashable>()
            for i in 0 ..< component.categories.count {
                let category = component.categories[i]
                validKeys.insert(category.key)
                
                var itemTransition = transition
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
                    component: AnyComponent(StorageCategoryItemComponent(
                        theme: component.theme,
                        strings: component.strings,
                        category: category,
                        isExpandedLevel: false,
                        isExpanded: self.expandedCategory == category.key,
                        hasNext: i != component.categories.count - 1,
                        action: { [weak self] key, actionType in
                            guard let self, let component = self.component else {
                                return
                            }
                            
                            switch actionType {
                            case .generic:
                                if let category = component.categories.first(where: { $0.key == key }), !category.subcategories.isEmpty {
                                    if self.expandedCategory == category.key {
                                        self.expandedCategory = nil
                                    } else {
                                        self.expandedCategory = category.key
                                    }
                                    self.state?.updated(transition: Transition(animation: .curve(duration: 0.4, curve: .spring)))
                                } else {
                                    component.toggleCategorySelection(key)
                                }
                            case .toggle:
                                component.toggleCategorySelection(key)
                            }
                        }
                    )),
                    environment: {},
                    containerSize: CGSize(width: availableSize.width, height: 1000.0)
                )
                let itemFrame = CGRect(origin: CGPoint(x: 0.0, y: contentHeight), size: itemSize)
                if let itemComponentView = itemView.view {
                    if itemComponentView.superview == nil {
                        self.addSubview(itemComponentView)
                    }
                    itemTransition.setFrame(view: itemComponentView, frame: itemFrame)
                }
                
                contentHeight += itemSize.height
            }
            
            var removeKeys: [AnyHashable] = []
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
            
            //TODO:localize
            let clearTitle: String
            let label: String?
            if totalSelectedSize == 0 {
                clearTitle = "Clear"
                label = nil
            } else if hasDeselected {
                clearTitle = "Clear Selected"
                label = dataSizeString(totalSelectedSize, formatting: DataSizeStringFormatting(strings: component.strings, decimalSeparator: "."))
            } else {
                clearTitle = "Clear All Cache"
                label = dataSizeString(totalSelectedSize, formatting: DataSizeStringFormatting(strings: component.strings, decimalSeparator: "."))
            }
            
            contentHeight += 8.0
            let buttonSize = self.button.update(
                transition: transition,
                component: AnyComponent(SolidRoundedButtonComponent(
                    title: clearTitle,
                    label: label,
                    theme: SolidRoundedButtonComponent.Theme(
                        backgroundColor: component.theme.list.itemCheckColors.fillColor,
                        backgroundColors: [],
                        foregroundColor: component.theme.list.itemCheckColors.foregroundColor
                    ),
                    font: .bold,
                    fontSize: 17.0,
                    height: 50.0,
                    cornerRadius: 10.0,
                    gloss: false,
                    isEnabled: totalSelectedSize != 0,
                    animationName: nil,
                    iconPosition: .right,
                    iconSpacing: 4.0,
                    action: {
                    }
                )),
                environment: {},
                containerSize: CGSize(width: availableSize.width - 16.0 * 2.0, height: 50.0)
            )
            let buttonFrame = CGRect(origin: CGPoint(x: 16.0, y: contentHeight), size: buttonSize)
            if let buttonView = button.view {
                if buttonView.superview == nil {
                    self.addSubview(buttonView)
                }
                transition.setFrame(view: buttonView, frame: buttonFrame)
            }
            contentHeight += buttonSize.height
            
            contentHeight += 16.0
            
            self.backgroundColor = component.theme.list.itemBlocksBackgroundColor
            
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
