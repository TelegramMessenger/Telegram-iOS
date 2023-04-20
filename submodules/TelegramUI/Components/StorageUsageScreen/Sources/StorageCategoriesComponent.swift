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

final class StorageCategoriesComponent: Component {
    struct CategoryData: Equatable {
        var key: StorageUsageScreenComponent.Category
        var color: UIColor
        var title: String
        var size: Int64
        var sizeFraction: Double
        var isSelected: Bool
        var subcategories: [CategoryData]
        
        init(key: StorageUsageScreenComponent.Category, color: UIColor, title: String, size: Int64, sizeFraction: Double, isSelected: Bool, subcategories: [CategoryData]) {
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
    let isOtherExpanded: Bool
    let displayAction: Bool
    let toggleCategorySelection: (StorageUsageScreenComponent.Category) -> Void
    let toggleOtherExpanded: () -> Void
    let clearAction: () -> Void
    
    init(
        theme: PresentationTheme,
        strings: PresentationStrings,
        categories: [CategoryData],
        isOtherExpanded: Bool,
        displayAction: Bool,
        toggleCategorySelection: @escaping (StorageUsageScreenComponent.Category) -> Void,
        toggleOtherExpanded: @escaping () -> Void,
        clearAction: @escaping () -> Void
    ) {
        self.theme = theme
        self.strings = strings
        self.categories = categories
        self.isOtherExpanded = isOtherExpanded
        self.displayAction = displayAction
        self.toggleCategorySelection = toggleCategorySelection
        self.toggleOtherExpanded = toggleOtherExpanded
        self.clearAction = clearAction
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
        if lhs.isOtherExpanded != rhs.isOtherExpanded {
            return false
        }
        if lhs.displayAction != rhs.displayAction {
            return false
        }
        return true
    }
    
    class View: UIView {
        private var itemViews: [StorageUsageScreenComponent.Category: ComponentView<Empty>] = [:]
        private let button = ComponentView<Empty>()
        
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
            
            let expandedCategory: StorageUsageScreenComponent.Category? = component.isOtherExpanded ? .other : nil
            
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
            
            var validKeys = Set<StorageUsageScreenComponent.Category>()
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
                        isExpanded: expandedCategory == category.key,
                        hasNext: i != component.categories.count - 1,
                        action: { [weak self] key, actionType in
                            guard let self, let component = self.component else {
                                return
                            }
                            
                            switch actionType {
                            case .generic:
                                if let category = component.categories.first(where: { $0.key == key }), !category.subcategories.isEmpty {
                                    component.toggleOtherExpanded()
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
            
            var removeKeys: [StorageUsageScreenComponent.Category] = []
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
            
            if component.displayAction {
                let clearTitle: String
                let label: String?
                if totalSelectedSize == 0 {
                    clearTitle = component.strings.StorageManagement_ClearSelected
                    label = nil
                } else if hasDeselected {
                    clearTitle = component.strings.StorageManagement_ClearSelected
                    label = dataSizeString(totalSelectedSize, formatting: DataSizeStringFormatting(strings: component.strings, decimalSeparator: "."))
                } else {
                    clearTitle = component.strings.StorageManagement_ClearAll
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
                        action: { [weak self] in
                            guard let self, let component = self.component else {
                                return
                            }
                            component.clearAction()
                        }
                    )),
                    environment: {},
                    containerSize: CGSize(width: availableSize.width - 16.0 * 2.0, height: 50.0)
                )
                let buttonFrame = CGRect(origin: CGPoint(x: 16.0, y: contentHeight), size: buttonSize)
                if let buttonView = self.button.view {
                    if buttonView.superview == nil {
                        self.addSubview(buttonView)
                    }
                    transition.setFrame(view: buttonView, frame: buttonFrame)
                }
                contentHeight += buttonSize.height
                
                contentHeight += 16.0
            } else {
                if let buttonView = self.button.view {
                    buttonView.removeFromSuperview()
                }
            }
            
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
