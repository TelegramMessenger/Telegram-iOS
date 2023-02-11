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
import TelegramStringFormatting
import CheckNode

private final class SubItemComponent: Component {
    let theme: PresentationTheme
    let strings: PresentationStrings
    let isIncoming: Bool
    let value: Int64
    let hasNext: Bool
    
    init(
        theme: PresentationTheme,
        strings: PresentationStrings,
        isIncoming: Bool,
        value: Int64,
        hasNext: Bool
    ) {
        self.theme = theme
        self.strings = strings
        self.isIncoming = isIncoming
        self.value = value
        self.hasNext = hasNext
    }
    
    static func ==(lhs: SubItemComponent, rhs: SubItemComponent) -> Bool {
        if lhs.theme !== rhs.theme {
            return false
        }
        if lhs.strings !== rhs.strings {
            return false
        }
        if lhs.isIncoming != rhs.isIncoming {
            return false
        }
        if lhs.value != rhs.value {
            return false
        }
        return true
    }
    
    class View: UIView {
        private let iconView: UIImageView
        private let title = ComponentView<Empty>()
        private let titleValue = ComponentView<Empty>()
        private let label = ComponentView<Empty>()
        private let separatorLayer: SimpleLayer
        
        private var component: SubItemComponent?
        
        private var highlightBackgroundFrame: CGRect?
        private var highlightBackgroundLayer: SimpleLayer?
        
        override init(frame: CGRect) {
            self.iconView = UIImageView()
            self.separatorLayer = SimpleLayer()
            
            super.init(frame: frame)
            
            self.layer.addSublayer(self.separatorLayer)
            
            self.addSubview(self.iconView)
            
            /*self.highligthedChanged = { [weak self] isHighlighted in
                guard let self, let component = self.component, let highlightBackgroundFrame = self.highlightBackgroundFrame else {
                    return
                }
                
                if isHighlighted {
                    self.superview?.bringSubviewToFront(self)
                    
                    let highlightBackgroundLayer: SimpleLayer
                    if let current = self.highlightBackgroundLayer {
                        highlightBackgroundLayer = current
                    } else {
                        highlightBackgroundLayer = SimpleLayer()
                        self.highlightBackgroundLayer = highlightBackgroundLayer
                        self.layer.insertSublayer(highlightBackgroundLayer, above: self.separatorLayer)
                        highlightBackgroundLayer.backgroundColor = component.theme.list.itemHighlightedBackgroundColor.cgColor
                    }
                    highlightBackgroundLayer.frame = highlightBackgroundFrame
                    highlightBackgroundLayer.opacity = 1.0
                } else {
                    if let highlightBackgroundLayer = self.highlightBackgroundLayer {
                        self.highlightBackgroundLayer = nil
                        highlightBackgroundLayer.animateAlpha(from: 1.0, to: 0.0, duration: 0.25, removeOnCompletion: false, completion: { [weak highlightBackgroundLayer] _ in
                            highlightBackgroundLayer?.removeFromSuperlayer()
                        })
                    }
                }
            }
            self.addTarget(self, action: #selector(self.pressed), for: .touchUpInside)
            self.isEnabled = false*/
        }
        
        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }
        
        @objc private func pressed() {
        }
        
        override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
            guard let result = super.hitTest(point, with: event) else {
                return nil
            }
            return result
        }
        
        func update(component: SubItemComponent, availableSize: CGSize, state: EmptyComponentState, environment: Environment<Empty>, transition: Transition) -> CGSize {
            let themeUpdated = self.component?.theme !== component.theme || self.component?.isIncoming != component.isIncoming
            
            self.component = component
            
            if themeUpdated {
                self.iconView.image = generateTintedImage(image: UIImage(bundleImageName: component.isIncoming ? "Settings/Menu/DataExpandedIn" : "Settings/Menu/DataExpandedOut"), color: component.theme.list.itemPrimaryTextColor)
            }
            
            var leftInset: CGFloat = 62.0
            var additionalLeftInset: CGFloat = 0.0
            
            additionalLeftInset += 45.0
            leftInset += additionalLeftInset
            
            let rightInset: CGFloat = 16.0
            
            var availableWidth: CGFloat = availableSize.width - leftInset - rightInset
            
            let fractionString: String = ""
            /*if component.category.sizeFraction != 0.0 {
                let fractionValue: Double = floor(component.category.sizeFraction * 100.0 * 10.0) / 10.0
                if fractionValue < 0.1 {
                    fractionString = "<0.1%"
                } else if abs(Double(Int(fractionValue)) - fractionValue) < 0.001 {
                    fractionString = "\(Int(fractionValue))%"
                } else {
                    fractionString = "\(fractionValue)%"
                }
            } else {
                fractionString = ""
            }*/
            
            let labelSize = self.label.update(
                transition: transition,
                component: AnyComponent(MultilineTextComponent(text: .plain(NSAttributedString(string: dataSizeString(Int(component.value), formatting: DataSizeStringFormatting(strings: component.strings, decimalSeparator: ".")), font: Font.regular(17.0), textColor: component.theme.list.itemSecondaryTextColor)))),
                environment: {},
                containerSize: CGSize(width: availableWidth, height: 100.0)
            )
            availableWidth = max(1.0, availableWidth - labelSize.width - 1.0)
            
            let titleValueSize = self.titleValue.update(
                transition: .immediate,
                component: AnyComponent(MultilineTextComponent(text: .plain(NSAttributedString(string: fractionString, font: Font.regular(17.0), textColor: component.theme.list.itemSecondaryTextColor)))),
                environment: {},
                containerSize: CGSize(width: availableWidth, height: 100.0)
            )
            availableWidth = max(1.0, availableWidth - titleValueSize.width - 4.0)
            
            let titleSize = self.title.update(
                transition: transition,
                component: AnyComponent(MultilineTextComponent(text: .plain(NSAttributedString(string: component.isIncoming ? component.strings.DataUsage_MediaDirectionIncoming : component.strings.DataUsage_MediaDirectionOutgoing, font: Font.regular(17.0), textColor: component.theme.list.itemPrimaryTextColor)))),
                environment: {},
                containerSize: CGSize(width: availableWidth, height: 100.0)
            )
            
            let height: CGFloat = 44.0
            
            let titleFrame = CGRect(origin: CGPoint(x: leftInset, y: floor((height - titleSize.height) / 2.0)), size: titleSize)
            let titleValueFrame = CGRect(origin: CGPoint(x: titleFrame.maxX + 4.0, y: floor((height - titleValueSize.height) / 2.0)), size: titleValueSize)
            
            let labelFrame = CGRect(origin: CGPoint(x: availableSize.width - rightInset - labelSize.width, y: floor((height - labelSize.height) / 2.0)), size: labelSize)
            
            if let image = self.iconView.image {
                transition.setFrame(view: self.iconView, frame: CGRect(origin: CGPoint(x: leftInset - additionalLeftInset + floor((additionalLeftInset - image.size.width) * 0.5), y: floor((height - image.size.height) * 0.5)), size: image.size))
            }
            
            if let titleView = self.title.view {
                if titleView.superview == nil {
                    titleView.isUserInteractionEnabled = false
                    self.addSubview(titleView)
                }
                transition.setFrame(view: titleView, frame: titleFrame)
            }
            if let titleValueView = self.titleValue.view {
                if titleValueView.superview == nil {
                    titleValueView.isUserInteractionEnabled = false
                    self.addSubview(titleValueView)
                }
                
                if titleValueView.bounds.size != titleValueFrame.size {
                    titleValueView.frame = titleValueFrame
                } else {
                    transition.setFrame(view: titleValueView, frame: titleValueFrame)
                }
            }
            if let labelView = self.label.view {
                if labelView.superview == nil {
                    labelView.isUserInteractionEnabled = false
                    self.addSubview(labelView)
                }
                transition.setFrame(view: labelView, frame: labelFrame)
            }
            
            if themeUpdated {
                self.separatorLayer.backgroundColor = component.theme.list.itemBlocksSeparatorColor.cgColor
            }
            transition.setFrame(layer: self.separatorLayer, frame: CGRect(origin: CGPoint(x: leftInset, y: height), size: CGSize(width: availableSize.width - leftInset, height: UIScreenPixel)))
            
            transition.setAlpha(layer: self.separatorLayer, alpha: (component.hasNext) ? 1.0 : 0.0)
            
            self.highlightBackgroundFrame = CGRect(origin: CGPoint(), size: CGSize(width: availableSize.width, height: height + ((component.hasNext) ? UIScreenPixel : 0.0)))
            
            return CGSize(width: availableSize.width, height: height)
        }
    }
    
    func makeView() -> View {
        return View(frame: CGRect())
    }
    
    func update(view: View, availableSize: CGSize, state: EmptyComponentState, environment: Environment<Empty>, transition: Transition) -> CGSize {
        return view.update(component: self, availableSize: availableSize, state: state, environment: environment, transition: transition)
    }
}

final class DataCategoryItemComponent: Component {
    let theme: PresentationTheme
    let strings: PresentationStrings
    let category: DataCategoriesComponent.CategoryData
    let isExpanded: Bool
    let hasNext: Bool
    let action: ((DataUsageScreenComponent.Category) -> Void)?
    
    init(
        theme: PresentationTheme,
        strings: PresentationStrings,
        category: DataCategoriesComponent.CategoryData,
        isExpanded: Bool,
        hasNext: Bool,
        action: ((DataUsageScreenComponent.Category) -> Void)?
    ) {
        self.theme = theme
        self.strings = strings
        self.category = category
        self.isExpanded = isExpanded
        self.hasNext = hasNext
        self.action = action
    }
    
    static func ==(lhs: DataCategoryItemComponent, rhs: DataCategoryItemComponent) -> Bool {
        if lhs.theme !== rhs.theme {
            return false
        }
        if lhs.strings !== rhs.strings {
            return false
        }
        if lhs.category != rhs.category {
            return false
        }
        if lhs.isExpanded != rhs.isExpanded {
            return false
        }
        if lhs.hasNext != rhs.hasNext {
            return false
        }
        return true
    }
    
    class View: HighlightTrackingButton {
        private let iconView: UIImageView
        private var expandIconView: UIImageView?
        private let title = ComponentView<Empty>()
        private let titleValue = ComponentView<Empty>()
        private let label = ComponentView<Empty>()
        private let separatorLayer: SimpleLayer
        
        private let subcategoryClippingContainer: UIView
        private var itemViews: [AnyHashable: ComponentView<Empty>] = [:]
        
        private var component: DataCategoryItemComponent?
        
        private var highlightBackgroundFrame: CGRect?
        private var highlightBackgroundLayer: SimpleLayer?
        
        override init(frame: CGRect) {
            self.iconView = UIImageView()
            self.separatorLayer = SimpleLayer()
            
            self.subcategoryClippingContainer = UIView()
            self.subcategoryClippingContainer.clipsToBounds = true
            
            super.init(frame: frame)
            
            self.addSubview(self.subcategoryClippingContainer)
            
            self.layer.addSublayer(self.separatorLayer)
            
            self.addSubview(self.iconView)
            
            self.highligthedChanged = { [weak self] isHighlighted in
                guard let self, let component = self.component, let highlightBackgroundFrame = self.highlightBackgroundFrame else {
                    return
                }
                
                if isHighlighted {
                    self.superview?.bringSubviewToFront(self)
                    
                    let highlightBackgroundLayer: SimpleLayer
                    if let current = self.highlightBackgroundLayer {
                        highlightBackgroundLayer = current
                    } else {
                        highlightBackgroundLayer = SimpleLayer()
                        self.highlightBackgroundLayer = highlightBackgroundLayer
                        self.layer.insertSublayer(highlightBackgroundLayer, above: self.separatorLayer)
                        highlightBackgroundLayer.backgroundColor = component.theme.list.itemHighlightedBackgroundColor.cgColor
                    }
                    highlightBackgroundLayer.frame = highlightBackgroundFrame
                    highlightBackgroundLayer.opacity = 1.0
                } else {
                    if let highlightBackgroundLayer = self.highlightBackgroundLayer {
                        self.highlightBackgroundLayer = nil
                        highlightBackgroundLayer.animateAlpha(from: 1.0, to: 0.0, duration: 0.25, removeOnCompletion: false, completion: { [weak highlightBackgroundLayer] _ in
                            highlightBackgroundLayer?.removeFromSuperlayer()
                        })
                    }
                }
            }
            self.addTarget(self, action: #selector(self.pressed), for: .touchUpInside)
        }
        
        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }
        
        @objc private func pressed() {
            guard let component = self.component else {
                return
            }
            component.action?(component.category.key)
        }
        
        @objc private func checkPressed() {
            guard let component = self.component else {
                return
            }
            component.action?(component.category.key)
        }
        
        override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
            guard let result = super.hitTest(point, with: event) else {
                return nil
            }
            if result === self.subcategoryClippingContainer {
                return self
            }
            return result
        }
        
        func update(component: DataCategoryItemComponent, availableSize: CGSize, state: EmptyComponentState, environment: Environment<Empty>, transition: Transition) -> CGSize {
            let themeUpdated = self.component?.theme !== component.theme || self.component?.category.color != component.category.color
            
            self.component = component
            
            
            if themeUpdated {
                let imageName: String
                switch component.category.key {
                case .photos:
                    imageName = "Settings/Menu/DataPhotos"
                case .videos:
                    imageName = "Settings/Menu/DataVideo"
                case .files:
                    imageName = "Settings/Menu/DataFiles"
                case .music:
                    imageName = "Settings/Menu/DataMusic"
                case .messages:
                    imageName = "Settings/Menu/DataMessages"
                case .stickers:
                    imageName = "Settings/Menu/DataStickers"
                case .voiceMessages:
                    imageName = "Settings/Menu/DataVoice"
                case .calls:
                    imageName = "Settings/Menu/DataCalls"
                case .totalIn:
                    imageName = "Settings/Menu/DataIn"
                case .totalOut:
                    imageName = "Settings/Menu/DataOut"
                }
                self.iconView.image = UIImage(bundleImageName: imageName)
            }
            
            var leftInset: CGFloat = 62.0
            let additionalLeftInset: CGFloat = 0.0
            leftInset += additionalLeftInset
            
            let rightInset: CGFloat = 16.0
            
            var availableWidth: CGFloat = availableSize.width - leftInset - rightInset
            
            if component.category.isSeparable {
                let expandIconView: UIImageView
                if let current = self.expandIconView {
                    expandIconView = current
                    if themeUpdated {
                        expandIconView.image = PresentationResourcesItemList.disclosureArrowImage(component.theme)
                    }
                } else {
                    expandIconView = UIImageView()
                    expandIconView.image = PresentationResourcesItemList.disclosureArrowImage(component.theme)
                    self.expandIconView = expandIconView
                    self.addSubview(expandIconView)
                }
                
                if let image = expandIconView.image {
                    availableWidth -= image.size.width + 6.0
                    transition.setBounds(view: expandIconView, bounds: CGRect(origin: CGPoint(), size: image.size))
                }
            } else if let expandIconView = self.expandIconView {
                self.expandIconView = nil
                expandIconView.removeFromSuperview()
            }
            
            let fractionString: String
            if component.category.sizeFraction != 0.0 {
                let fractionValue: Double = floor(component.category.sizeFraction * 100.0 * 10.0) / 10.0
                if fractionValue < 0.1 {
                    fractionString = "<0.1%"
                } else if abs(Double(Int(fractionValue)) - fractionValue) < 0.001 {
                    fractionString = "\(Int(fractionValue))%"
                } else {
                    fractionString = "\(fractionValue)%"
                }
            } else {
                fractionString = ""
            }
            
            let labelSize = self.label.update(
                transition: transition,
                component: AnyComponent(MultilineTextComponent(text: .plain(NSAttributedString(string: dataSizeString(Int(component.category.size), formatting: DataSizeStringFormatting(strings: component.strings, decimalSeparator: ".")), font: Font.regular(17.0), textColor: component.theme.list.itemSecondaryTextColor)))),
                environment: {},
                containerSize: CGSize(width: availableWidth, height: 100.0)
            )
            availableWidth = max(1.0, availableWidth - labelSize.width - 1.0)
            
            let titleValueSize = self.titleValue.update(
                transition: .immediate,
                component: AnyComponent(MultilineTextComponent(text: .plain(NSAttributedString(string: fractionString, font: Font.regular(17.0), textColor: component.theme.list.itemSecondaryTextColor)))),
                environment: {},
                containerSize: CGSize(width: availableWidth, height: 100.0)
            )
            availableWidth = max(1.0, availableWidth - titleValueSize.width - 4.0)
            
            let titleSize = self.title.update(
                transition: transition,
                component: AnyComponent(MultilineTextComponent(text: .plain(NSAttributedString(string: component.category.title, font: Font.regular(17.0), textColor: component.theme.list.itemPrimaryTextColor)))),
                environment: {},
                containerSize: CGSize(width: availableWidth, height: 100.0)
            )
            
            var height: CGFloat = 44.0
            
            let titleFrame = CGRect(origin: CGPoint(x: leftInset, y: floor((height - titleSize.height) / 2.0)), size: titleSize)
            let titleValueFrame = CGRect(origin: CGPoint(x: titleFrame.maxX + 4.0, y: floor((height - titleValueSize.height) / 2.0)), size: titleValueSize)
            
            var labelFrame = CGRect(origin: CGPoint(x: availableSize.width - rightInset - labelSize.width, y: floor((height - labelSize.height) / 2.0)), size: labelSize)
            
            if let expandIconView = self.expandIconView, let image = expandIconView.image {
                labelFrame.origin.x -= image.size.width - 6.0
                
                transition.setPosition(view: expandIconView, position: CGPoint(x: availableSize.width - rightInset + 6.0 - floor(image.size.width * 0.5), y: floor(height * 0.5)))
                let angle: CGFloat = component.isExpanded ? CGFloat.pi : 0.0
                transition.setTransform(view: expandIconView, transform: CATransform3DMakeRotation(CGFloat.pi * 0.5 - angle, 0.0, 0.0, 1.0))
            }
            
            if let image = self.iconView.image {
                transition.setFrame(view: self.iconView, frame: CGRect(origin: CGPoint(x: floor((leftInset - image.size.width) * 0.5), y: floor((height - image.size.height) * 0.5)), size: image.size))
            }
            
            if let titleView = self.title.view {
                if titleView.superview == nil {
                    titleView.isUserInteractionEnabled = false
                    self.addSubview(titleView)
                }
                transition.setFrame(view: titleView, frame: titleFrame)
            }
            if let titleValueView = self.titleValue.view {
                if titleValueView.superview == nil {
                    titleValueView.isUserInteractionEnabled = false
                    self.addSubview(titleValueView)
                }
                
                if titleValueView.bounds.size != titleValueFrame.size {
                    titleValueView.frame = titleValueFrame
                } else {
                    transition.setFrame(view: titleValueView, frame: titleValueFrame)
                }
            }
            if let labelView = self.label.view {
                if labelView.superview == nil {
                    labelView.isUserInteractionEnabled = false
                    self.addSubview(labelView)
                }
                transition.setFrame(view: labelView, frame: labelFrame)
            }
            
            if themeUpdated {
                self.separatorLayer.backgroundColor = component.theme.list.itemBlocksSeparatorColor.cgColor
            }
            transition.setFrame(layer: self.separatorLayer, frame: CGRect(origin: CGPoint(x: leftInset, y: height), size: CGSize(width: availableSize.width - leftInset, height: UIScreenPixel)))
            
            transition.setAlpha(layer: self.separatorLayer, alpha: (component.isExpanded || component.hasNext) ? 1.0 : 0.0)
            
            self.highlightBackgroundFrame = CGRect(origin: CGPoint(), size: CGSize(width: availableSize.width, height: height + ((component.isExpanded || component.hasNext) ? UIScreenPixel : 0.0)))
            
            var validKeys = Set<AnyHashable>()
            if component.isExpanded, component.category.isSeparable {
                struct SubItem {
                    var id: AnyHashable
                    var isIncoming: Bool
                    var value: Int64
                }
                let items: [SubItem] = [
                    SubItem(id: "in", isIncoming: true, value: component.category.incoming),
                    SubItem(id: "out", isIncoming: false, value: component.category.outgoing)
                ]
                
                for i in 0 ..< items.count {
                    let item = items[i]
                    validKeys.insert(item.id)
                    
                    var itemTransition = transition
                    let itemView: ComponentView<Empty>
                    if let current = self.itemViews[item.id] {
                        itemView = current
                    } else {
                        itemTransition = .immediate
                        itemView = ComponentView()
                        self.itemViews[item.id] = itemView
                    }
                    
                    itemView.parentState = state
                    let itemSize = itemView.update(
                        transition: itemTransition,
                        component: AnyComponent(SubItemComponent(
                            theme: component.theme,
                            strings: component.strings,
                            isIncoming: item.isIncoming,
                            value: item.value,
                            hasNext: i != items.count - 1
                        )),
                        environment: {},
                        containerSize: CGSize(width: availableSize.width, height: 1000.0)
                    )
                    let itemFrame = CGRect(origin: CGPoint(x: 0.0, y: height), size: itemSize)
                    if let itemComponentView = itemView.view {
                        if itemComponentView.superview == nil {
                            self.subcategoryClippingContainer.addSubview(itemComponentView)
                            if !transition.animation.isImmediate {
                                itemComponentView.alpha = 0.0
                                transition.setAlpha(view: itemComponentView, alpha: 1.0)
                            }
                        }
                        itemTransition.setFrame(view: itemComponentView, frame: itemFrame)
                    }
                    
                    height += itemSize.height
                }
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
            
            transition.setFrame(view: self.subcategoryClippingContainer, frame: CGRect(origin: CGPoint(), size: CGSize(width: availableSize.width, height: height)))
            
            self.isEnabled = component.action != nil
            
            return CGSize(width: availableSize.width, height: height)
        }
    }
    
    func makeView() -> View {
        return View(frame: CGRect())
    }
    
    func update(view: View, availableSize: CGSize, state: EmptyComponentState, environment: Environment<Empty>, transition: Transition) -> CGSize {
        return view.update(component: self, availableSize: availableSize, state: state, environment: environment, transition: transition)
    }
}
