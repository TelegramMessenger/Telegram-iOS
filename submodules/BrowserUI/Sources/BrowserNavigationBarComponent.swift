import Foundation
import UIKit
import Display
import ComponentFlow
import TelegramPresentationData
import ContextUI
import GlassBackgroundComponent
import EdgeEffect

final class BrowserNavigationBarEnvironment: Equatable {
    public let fraction: CGFloat
    
    public init(fraction: CGFloat) {
        self.fraction = fraction
    }
    
    public static func ==(lhs: BrowserNavigationBarEnvironment, rhs: BrowserNavigationBarEnvironment) -> Bool {
        if lhs.fraction != rhs.fraction {
            return false
        }
        return true
    }
}

final class BrowserNavigationBarComponent: Component {
    public class ExternalState {
        public fileprivate(set) var centerItemFrame: CGRect
        
        public init() {
            self.centerItemFrame = .zero
        }
    }
    
    let theme: PresentationTheme
    let topInset: CGFloat
    let height: CGFloat
    let sideInset: CGFloat
    let metrics: LayoutMetrics
    let externalState: ExternalState?
    let leftItems: [AnyComponentWithIdentity<Empty>]
    let rightItems: [AnyComponentWithIdentity<Empty>]
    let centerItem: AnyComponentWithIdentity<BrowserNavigationBarEnvironment>?
    let collapseFraction: CGFloat
    let activate: () -> Void
    
    init(
        theme: PresentationTheme,
        topInset: CGFloat,
        height: CGFloat,
        sideInset: CGFloat,
        metrics: LayoutMetrics,
        externalState: ExternalState?,
        leftItems: [AnyComponentWithIdentity<Empty>],
        rightItems: [AnyComponentWithIdentity<Empty>],
        centerItem: AnyComponentWithIdentity<BrowserNavigationBarEnvironment>?,
        collapseFraction: CGFloat,
        activate: @escaping () -> Void
    ) {
        self.theme = theme
        self.topInset = topInset
        self.height = height
        self.sideInset = sideInset
        self.metrics = metrics
        self.externalState = externalState
        self.leftItems = leftItems
        self.rightItems = rightItems
        self.centerItem = centerItem
        self.collapseFraction = collapseFraction
        self.activate = activate
    }
    
    static func ==(lhs: BrowserNavigationBarComponent, rhs: BrowserNavigationBarComponent) -> Bool {
        if lhs.theme !== rhs.theme {
            return false
        }
        if lhs.topInset != rhs.topInset {
            return false
        }
        if lhs.height != rhs.height {
            return false
        }
        if lhs.sideInset != rhs.sideInset {
            return false
        }
        if lhs.metrics != rhs.metrics {
            return false
        }
        if lhs.leftItems != rhs.leftItems {
            return false
        }
        if lhs.rightItems != rhs.rightItems {
            return false
        }
        if lhs.centerItem != rhs.centerItem {
            return false
        }
        if lhs.collapseFraction != rhs.collapseFraction {
            return false
        }
        return true
    }
    
    final class View: UIView {
        private var edgeEffectView = EdgeEffectView()
        private let containerView = GlassBackgroundContainerView()
      
        private var leftItemsBackground: GlassBackgroundView?
        private var leftItems: [AnyHashable: ComponentView<Empty>] = [:]
        
        private var rightItemsBackground: GlassBackgroundView?
        private var rightItems: [AnyHashable: ComponentView<Empty>] = [:]
       
        private var centerItems: [AnyHashable: ComponentView<BrowserNavigationBarEnvironment>] = [:]
        
        private let activateButton = HighlightTrackingButton()
                
        private var component: BrowserNavigationBarComponent?
        private weak var state: EmptyComponentState?
        
        override init(frame: CGRect) {
            super.init(frame: frame)
            
            self.addSubview(self.edgeEffectView)
            
            self.addSubview(self.containerView)
            self.activateButton.addTarget(self, action: #selector(self.activatePressed), for: .touchUpInside)
        }
        
        required init?(coder: NSCoder) {
            preconditionFailure()
        }
        
        @objc private func activatePressed() {
            guard let component = self.component else {
                return
            }
            component.activate()
        }
        
        func update(component: BrowserNavigationBarComponent, availableSize: CGSize, state: EmptyComponentState, environment: Environment<Empty>, transition: ComponentTransition) -> CGSize {
            self.component = component
            self.state = state
            
            var availableWidth = availableSize.width
            let sideInset: CGFloat = (component.metrics.isTablet ? 20.0 : 16.0) + component.sideInset
            
            let collapsedHeight: CGFloat = 54.0
            let expandedHeight = component.height
            let contentHeight: CGFloat = expandedHeight * (1.0 - component.collapseFraction) + collapsedHeight * component.collapseFraction
            let size = CGSize(width: availableSize.width, height: component.topInset + contentHeight)
            let verticalOffset: CGFloat = component.metrics.isTablet ? -2.0 : 0.0
            let itemSpacing: CGFloat = 0.0 //component.metrics.isTablet ? 26.0 : 8.0
            let panelHeight: CGFloat = 44.0
            
            var leftItemsBackground: GlassBackgroundView?
            var leftItemsBackgroundTransition = transition
            if !component.leftItems.isEmpty {
                if let current = self.leftItemsBackground {
                    leftItemsBackground = current
                } else {
                    leftItemsBackgroundTransition = .immediate
                    leftItemsBackground = GlassBackgroundView()
                    self.containerView.contentView.addSubview(leftItemsBackground!)
                    self.leftItemsBackground = leftItemsBackground
                    
                    transition.animateScale(view: leftItemsBackground!, from: 0.1, to: 1.0)
                    transition.animateAlpha(view: leftItemsBackground!, from: 0.0, to: 1.0)
                }
            }
            
            var rightItemsBackground: GlassBackgroundView?
            var rightItemsBackgroundTransition = transition
            if !component.rightItems.isEmpty {
                if let current = self.rightItemsBackground {
                    rightItemsBackground = current
                } else {
                    rightItemsBackgroundTransition = .immediate
                    rightItemsBackground = GlassBackgroundView()
                    self.containerView.contentView.addSubview(rightItemsBackground!)
                    self.rightItemsBackground = rightItemsBackground
                    
                    transition.animateScale(view: rightItemsBackground!, from: 0.1, to: 1.0)
                    transition.animateAlpha(view: rightItemsBackground!, from: 0.0, to: 1.0)
                }
            }
                        
            var validLeftItemIds: Set<AnyHashable> = Set()
            var leftItemTransitions: [AnyHashable: (CGSize, ComponentTransition)] = [:]
            var leftItemsWidth: CGFloat = 0.0
            for item in component.leftItems {
                validLeftItemIds.insert(item.id)
                var itemTransition = transition
                let itemView: ComponentView<Empty>
                if let current = self.leftItems[item.id] {
                    itemView = current
                } else {
                    itemTransition = .immediate
                    itemView = ComponentView<Empty>()
                    self.leftItems[item.id] = itemView
                }
                
                let itemSize = itemView.update(
                    transition: itemTransition,
                    component: item.component,
                    environment: {},
                    containerSize: CGSize(width: availableWidth, height: expandedHeight)
                )
                leftItemTransitions[item.id] = (itemSize, itemTransition)
                availableWidth -= itemSize.width
                leftItemsWidth += itemSize.width
            }
                        
            var validRightItemIds: Set<AnyHashable> = Set()
            var rightItemTransitions: [AnyHashable: (CGSize, ComponentTransition)] = [:]
            var rightItemsWidth: CGFloat = 0.0
            for item in component.rightItems {
                validRightItemIds.insert(item.id)
                var itemTransition = transition
                let itemView: ComponentView<Empty>
                if let current = self.rightItems[item.id] {
                    itemView = current
                } else {
                    itemTransition = .immediate
                    itemView = ComponentView<Empty>()
                    self.rightItems[item.id] = itemView
                }
                
                let itemSize = itemView.update(
                    transition: itemTransition,
                    component: item.component,
                    environment: {},
                    containerSize: CGSize(width: availableWidth, height: expandedHeight)
                )
                rightItemTransitions[item.id] = (itemSize, itemTransition)
                availableWidth -= itemSize.width
                rightItemsWidth += itemSize.width
            }
            
            var centerLeftInset = sideInset
            var leftItemX = 0.0
            for item in component.leftItems {
                guard let (itemSize, itemTransition) = leftItemTransitions[item.id], let itemView = self.leftItems[item.id]?.view else {
                    continue
                }
                let itemPosition = CGPoint(x: leftItemX + itemSize.width / 2.0, y: panelHeight * 0.5)
                let itemFrame = CGRect(origin: CGPoint(x: itemPosition.x - itemSize.width * 0.5, y: itemPosition.y - itemSize.height * 0.5), size: itemSize)
                if itemView.superview == nil {
                    leftItemsBackground?.contentView.addSubview(itemView)
                    transition.animateAlpha(view: itemView, from: 0.0, to: 1.0)
                    transition.animateScale(view: itemView, from: 0.01, to: 1.0)
                }
                itemTransition.setBounds(view: itemView, bounds: CGRect(origin: .zero, size: itemFrame.size))
                itemTransition.setPosition(view: itemView, position: itemFrame.center)
                
                leftItemX += itemSize.width + itemSpacing
                centerLeftInset += itemSize.width + itemSpacing
            }
            
            var centerRightInset = sideInset
            var rightItemX = rightItemsWidth
            for item in component.rightItems.reversed() {
                guard let (itemSize, itemTransition) = rightItemTransitions[item.id], let itemView = self.rightItems[item.id]?.view else {
                    continue
                }
                let itemPosition = CGPoint(x: rightItemX - itemSize.width / 2.0, y: panelHeight * 0.5)
                let itemFrame = CGRect(origin: CGPoint(x: itemPosition.x - itemSize.width * 0.5, y: itemPosition.y - itemSize.height * 0.5), size: itemSize)
                if itemView.superview == nil {
                    rightItemsBackground?.contentView.addSubview(itemView)
                    transition.animateAlpha(view: itemView, from: 0.0, to: 1.0)
                    transition.animateScale(view: itemView, from: 0.01, to: 1.0)
                }
                itemTransition.setBounds(view: itemView, bounds: CGRect(origin: .zero, size: itemFrame.size))
                itemTransition.setPosition(view: itemView, position: itemFrame.center)
                itemTransition.setScale(view: itemView, scale: 1.0 - 0.35 * component.collapseFraction)
                itemTransition.setAlpha(view: itemView, alpha: 1.0 - component.collapseFraction)
                
                rightItemX -= itemSize.width + itemSpacing
                centerRightInset += itemSize.width + itemSpacing
            }
            
            if let leftItemsBackground {
                let leftItemsFrame = CGRect(origin: CGPoint(x: sideInset - (leftItemsWidth / 2.0 * 0.35 * component.collapseFraction), y: component.topInset + contentHeight / 2.0 + verticalOffset - panelHeight / 2.0), size: CGSize(width: leftItemsWidth, height: panelHeight))
                leftItemsBackgroundTransition.setFrame(view: leftItemsBackground, frame: leftItemsFrame)
                leftItemsBackground.update(size: leftItemsFrame.size, cornerRadius: leftItemsFrame.height * 0.5, isDark: component.theme.overallDarkAppearance, tintColor: .init(kind: .panel), isInteractive: true, transition: leftItemsBackgroundTransition)
                
                leftItemsBackgroundTransition.setScale(view: leftItemsBackground, scale: 1.0 - 0.999 * component.collapseFraction)
                leftItemsBackgroundTransition.setAlpha(view: leftItemsBackground.contentView, alpha: 1.0 - component.collapseFraction)
            } else if let leftItemsBackground = self.leftItemsBackground {
                self.leftItemsBackground = nil
                leftItemsBackground.removeFromSuperview()
            }

            if let rightItemsBackground {
                let rightItemsFrame = CGRect(origin: CGPoint(x: availableSize.width - sideInset - rightItemsWidth * (1.0 - component.collapseFraction) + (rightItemsWidth / 2.0 * 0.35 * component.collapseFraction), y: component.topInset + contentHeight / 2.0 + verticalOffset - panelHeight / 2.0), size: CGSize(width: rightItemsWidth, height: panelHeight))
                rightItemsBackgroundTransition.setFrame(view: rightItemsBackground, frame: rightItemsFrame)
                rightItemsBackground.update(size: rightItemsFrame.size, cornerRadius: rightItemsFrame.height * 0.5, isDark: component.theme.overallDarkAppearance, tintColor: .init(kind: .panel), isInteractive: true, transition: rightItemsBackgroundTransition)
                
                rightItemsBackgroundTransition.setScale(view: rightItemsBackground, scale: 1.0 - 0.999 * component.collapseFraction)
                rightItemsBackgroundTransition.setAlpha(view: rightItemsBackground.contentView, alpha: 1.0 - component.collapseFraction)
            } else if let rightItemsBackground = self.rightItemsBackground {
                self.rightItemsBackground = nil
                rightItemsBackground.removeFromSuperview()
            }
            
            var removeLeftItemIds: [AnyHashable] = []
            for (id, item) in self.leftItems {
                if !validLeftItemIds.contains(id) {
                    removeLeftItemIds.append(id)
                    if let itemView = item.view {
                        transition.setScale(view: itemView, scale: 0.01)
                        transition.setAlpha(view: itemView, alpha: 0.0, completion: { _ in
                            itemView.removeFromSuperview()
                        })
                    }
                }
            }
            for id in removeLeftItemIds {
                self.leftItems.removeValue(forKey: id)
            }
            
            var removeRightItemIds: [AnyHashable] = []
            for (id, item) in self.rightItems {
                if !validRightItemIds.contains(id) {
                    removeRightItemIds.append(id)
                    if let itemView = item.view {
                        transition.setScale(view: itemView, scale: 0.01)
                        transition.setAlpha(view: itemView, alpha: 0.0, completion: { _ in
                            itemView.removeFromSuperview()
                        })
                    }
                }
            }
            for id in removeRightItemIds {
                self.rightItems.removeValue(forKey: id)
            }
            
            let maxCenterInset = max(centerLeftInset, centerRightInset)
            
            if !component.leftItems.isEmpty || !component.rightItems.isEmpty {
                availableWidth -= itemSpacing * CGFloat(max(0, component.leftItems.count - 1)) + itemSpacing * CGFloat(max(0, component.rightItems.count - 1)) + 30.0
            }
            availableWidth -= component.sideInset * 2.0
            
            let canCenter = availableWidth > 390.0
            availableWidth = min(390.0, availableWidth)
            
            let environment = BrowserNavigationBarEnvironment(fraction: component.collapseFraction)
            
            var centerX = maxCenterInset + (availableSize.width - maxCenterInset * 2.0) / 2.0
            if canCenter {
                centerX = availableSize.width / 2.0
            } else {
                centerX = centerLeftInset + (availableSize.width - centerLeftInset - centerRightInset) / 2.0
            }
            
            var validCenterItemIds: Set<AnyHashable> = Set()
            if let item = component.centerItem {
                validCenterItemIds.insert(item.id)
                
                var itemTransition = transition
                let itemView: ComponentView<BrowserNavigationBarEnvironment>
                if let current = self.centerItems[item.id] {
                    itemView = current
                } else {
                    itemTransition = .immediate
                    itemView = ComponentView<BrowserNavigationBarEnvironment>()
                    self.centerItems[item.id] = itemView
                }
                
                let itemSize = itemView.update(
                    transition: itemTransition,
                    component: item.component,
                    environment: { environment },
                    containerSize: CGSize(width: availableWidth, height: expandedHeight)
                )
                
                let itemPosition = CGPoint(x: centerX, y: component.topInset + contentHeight / 2.0 + verticalOffset)
                let itemFrame = CGRect(origin: CGPoint(x: itemPosition.x - itemSize.width * 0.5, y: itemPosition.y - itemSize.height * 0.5), size: itemSize)
                if let itemView = itemView.view {
                    if itemView.superview == nil {
                        self.containerView.contentView.addSubview(itemView)
                        transition.animateAlpha(view: itemView, from: 0.0, to: 1.0)
                    }
                    itemTransition.setBounds(view: itemView, bounds: CGRect(origin: .zero, size: itemFrame.size))
                    itemTransition.setPosition(view: itemView, position: itemFrame.center)
                    itemTransition.setScale(view: itemView, scale: 1.0 - 0.25 * component.collapseFraction)
                }
                component.externalState?.centerItemFrame = itemFrame
            }
            
            var removeCenterItemIds: [AnyHashable] = []
            for (id, item) in self.centerItems {
                if !validCenterItemIds.contains(id) {
                    removeCenterItemIds.append(id)
                    if let itemView = item.view {
                        transition.setAlpha(view: itemView, alpha: 0.0, completion: { _ in
                            itemView.removeFromSuperview()
                        })
                    }
                }
            }
            for id in removeCenterItemIds {
                self.centerItems.removeValue(forKey: id)
            }
            
            if component.collapseFraction == 1.0 {
                if self.activateButton.superview == nil {
                    self.addSubview(self.activateButton)
                }
                self.activateButton.frame = CGRect(origin: .zero, size: size)
            } else {
                self.activateButton.removeFromSuperview()
            }

            self.containerView.update(size: size, isDark: component.theme.overallDarkAppearance, transition: transition)
            transition.setFrame(view: self.containerView, frame: CGRect(origin: .zero, size: size))
            
            let edgeEffectHeight: CGFloat = 80.0
            let edgeEffectFrame = CGRect(origin: CGPoint(x: 0.0, y: 0.0), size: CGSize(width: size.width, height: edgeEffectHeight))
            transition.setFrame(view: self.edgeEffectView, frame: edgeEffectFrame)
            self.edgeEffectView.update(
                content: .clear,
                blur: true,
                rect: edgeEffectFrame,
                edge: .top,
                edgeSize: edgeEffectFrame.height,
                transition: transition
            )
            
            return size
        }
    }
    
    public func makeView() -> View {
        return View(frame: CGRect())
    }
    
    func update(view: View, availableSize: CGSize, state: EmptyComponentState, environment: Environment<Empty>, transition: ComponentTransition) -> CGSize {
        return view.update(component: self, availableSize: availableSize, state: state, environment: environment, transition: transition)
    }
}

final class LoadingProgressComponent: Component {
    let color: UIColor
    let height: CGFloat
    let value: CGFloat
    
    init(
        color: UIColor,
        height: CGFloat,
        value: CGFloat
    ) {
        self.color = color
        self.height = height
        self.value = value
    }
    
    static func ==(lhs: LoadingProgressComponent, rhs: LoadingProgressComponent) -> Bool {
        if lhs.color != rhs.color {
            return false
        }
        if lhs.height != rhs.height {
            return false
        }
        if lhs.value != rhs.value {
            return false
        }
        return true
    }

    final class View: UIView {
        private var lineView: UIView
        
        private var currentValue: Double = 0.0
        
        init() {
            self.lineView = UIView()
            self.lineView.clipsToBounds = true
            self.lineView.layer.cornerRadius = 1.0
            self.lineView.alpha = 0.0
            
            super.init(frame: CGRect())
       
            self.addSubview(self.lineView)
        }

        required init?(coder aDecoder: NSCoder) {
            preconditionFailure()
        }

        func update(component: LoadingProgressComponent, availableSize: CGSize, transition: ComponentTransition) -> CGSize {
            self.lineView.backgroundColor = component.color
        
            let value = component.value
            let frame = CGRect(origin: .zero, size: CGSize(width: availableSize.width * component.value, height: component.height))
            
            var animated = true
            if value < self.currentValue {
                if self.currentValue == 1.0 {
                    self.lineView.frame = CGRect(origin: .zero, size: CGSize(width: 0.0, height: component.height))
                } else {
                    animated = false
                }
            }
            
            self.currentValue = value
                
            let transition: ComponentTransition
            if animated && value > 0.0 {
                transition = .spring(duration: 0.7)
            } else {
                transition = .immediate
            }
            
            let alphaTransition: ComponentTransition
            if animated {
                alphaTransition = .easeInOut(duration: 0.3)
            } else {
                alphaTransition = .immediate
            }
            
            transition.setFrame(view: self.lineView, frame: frame)

            let alpha: CGFloat = value < 0.01 || value > 0.99 ? 0.0 : 1.0
            alphaTransition.setAlpha(view: self.lineView, alpha: alpha)
         
            return CGSize(width: availableSize.width, height: component.height)
        }
    }

    func makeView() -> View {
        return View()
    }

    func update(view: View, availableSize: CGSize, state: EmptyComponentState, environment: Environment<Empty>, transition: ComponentTransition) -> CGSize {
        return view.update(component: self, availableSize: availableSize, transition: transition)
    }
}
