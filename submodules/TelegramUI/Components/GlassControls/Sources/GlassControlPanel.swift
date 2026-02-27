import Foundation
import UIKit
import Display
import TelegramPresentationData
import ComponentFlow
import GlassBackgroundComponent

public final class GlassControlPanelComponent: Component {
    public final class Item: Equatable {
        public let items: [GlassControlGroupComponent.Item]
        public let background: GlassControlGroupComponent.Background
        public let keepWide: Bool

        public init(items: [GlassControlGroupComponent.Item], background: GlassControlGroupComponent.Background, keepWide: Bool = false) {
            self.items = items
            self.background = background
            self.keepWide = keepWide
        }
        
        public static func ==(lhs: Item, rhs: Item) -> Bool {
            if lhs.items != rhs.items {
                return false
            }
            if lhs.background != rhs.background {
                return false
            }
            if lhs.keepWide != rhs.keepWide {
                return false
            }
            return true
        }
    }

    public let theme: PresentationTheme
    public let preferClearGlass: Bool
    public let leftItem: Item?
    public let rightItem: Item?
    public let centralItem: Item?
    public let centerAlignmentIfPossible: Bool
    public let isDark: Bool?
    public let tag: AnyObject?

    public init(
        theme: PresentationTheme,
        preferClearGlass: Bool = false,
        leftItem: Item?,
        centralItem: Item?,
        rightItem: Item?,
        centerAlignmentIfPossible: Bool = false,
        isDark: Bool? = nil,
        tag: AnyObject? = nil
    ) {
        self.theme = theme
        self.preferClearGlass = preferClearGlass
        self.leftItem = leftItem
        self.centralItem = centralItem
        self.rightItem = rightItem
        self.centerAlignmentIfPossible = centerAlignmentIfPossible
        self.isDark = isDark
        self.tag = tag
    }

    public static func ==(lhs: GlassControlPanelComponent, rhs: GlassControlPanelComponent) -> Bool {
        if lhs.theme !== rhs.theme {
            return false
        }
        if lhs.preferClearGlass != rhs.preferClearGlass {
            return false
        }
        if lhs.leftItem != rhs.leftItem {
            return false
        }
        if lhs.centralItem != rhs.centralItem {
            return false
        }
        if lhs.rightItem != rhs.rightItem {
            return false
        }
        if lhs.centerAlignmentIfPossible != rhs.centerAlignmentIfPossible {
            return false
        }
        if lhs.isDark != rhs.isDark {
            return false
        }
        if lhs.tag !== rhs.tag {
            return false
        }
        return true
    }

    public final class View: UIView, ComponentTaggedView {
        public func matches(tag: Any) -> Bool {
            if let component = self.component, let componentTag = component.tag {
                let tag = tag as AnyObject
                if componentTag === tag {
                    return true
                }
            }
            return false
        }
        
        private let glassContainerView: GlassBackgroundContainerView
        
        private var leftItemComponent: ComponentView<Empty>?
        private var centralItemComponent: ComponentView<Empty>?
        private var rightItemComponent: ComponentView<Empty>?
        
        private var component: GlassControlPanelComponent?
        private weak var state: EmptyComponentState?

        public var leftItemView: GlassControlGroupComponent.View? {
            return self.leftItemComponent?.view as? GlassControlGroupComponent.View
        }

        public var centerItemView: GlassControlGroupComponent.View? {
            return self.centralItemComponent?.view as? GlassControlGroupComponent.View
        }

        public var rightItemView: GlassControlGroupComponent.View? {
            return self.rightItemComponent?.view as? GlassControlGroupComponent.View
        }

        override public init(frame: CGRect) {
            self.glassContainerView = GlassBackgroundContainerView()
            
            super.init(frame: frame)
            
            self.addSubview(self.glassContainerView)
        }
        
        required public init(coder aDecoder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }
        
        func update(component: GlassControlPanelComponent, availableSize: CGSize, state: EmptyComponentState, environment: Environment<Empty>, transition: ComponentTransition) -> CGSize {
            self.component = component
            self.state = state
            
            let alphaTransition: ComponentTransition = transition.animation.isImmediate ? .immediate : .easeInOut(duration: 0.2)
            let minSpacing: CGFloat = 8.0
            
            var leftItemFrame: CGRect?
            if let leftItem = component.leftItem {
                let leftItemComponent: ComponentView<Empty>
                var leftItemTransition = transition
                if let current = self.leftItemComponent {
                    leftItemComponent = current
                } else {
                    leftItemComponent = ComponentView()
                    self.leftItemComponent = leftItemComponent
                    leftItemTransition = transition.withAnimation(.none)
                }
                
                let leftItemSize = leftItemComponent.update(
                    transition: leftItemTransition,
                    component: AnyComponent(GlassControlGroupComponent(
                        theme: component.theme,
                        preferClearGlass: component.preferClearGlass,
                        background: leftItem.background,
                        items: leftItem.items,
                        minWidth: availableSize.height
                    )),
                    environment: {},
                    containerSize: CGSize(width: availableSize.width, height: availableSize.height)
                )
                let leftItemFrameValue = CGRect(origin: CGPoint(x: 0.0, y: 0.0), size: leftItemSize)
                leftItemFrame = leftItemFrameValue
                if let leftItemComponentView = leftItemComponent.view {
                    var animateIn = false
                    if leftItemComponentView.superview == nil {
                        animateIn = true
                        self.glassContainerView.contentView.addSubview(leftItemComponentView)
                        ComponentTransition.immediate.setScale(view: leftItemComponentView, scale: 0.001)
                    }
                    leftItemTransition.setPosition(view: leftItemComponentView, position: leftItemFrameValue.center)
                    leftItemTransition.setBounds(view: leftItemComponentView, bounds: CGRect(origin: CGPoint(), size: leftItemFrameValue.size))
                    if animateIn {
                        alphaTransition.animateAlpha(view: leftItemComponentView, from: 0.0, to: 1.0)
                        transition.setScale(view: leftItemComponentView, scale: 1.0)
                    }
                }
            } else if let leftItemComponent = self.leftItemComponent {
                self.leftItemComponent = nil
                if let leftItemComponentView = leftItemComponent.view {
                    transition.setScale(view: leftItemComponentView, scale: 0.001)
                    alphaTransition.setAlpha(view: leftItemComponentView, alpha: 0.0, completion: { [weak leftItemComponentView] _ in
                        leftItemComponentView?.removeFromSuperview()
                    })
                }
            }
            
            var rightItemFrame: CGRect?
            if let rightItem = component.rightItem {
                let rightItemComponent: ComponentView<Empty>
                var rightItemTransition = transition
                if let current = self.rightItemComponent {
                    rightItemComponent = current
                } else {
                    rightItemComponent = ComponentView()
                    self.rightItemComponent = rightItemComponent
                    rightItemTransition = transition.withAnimation(.none)
                }
                
                let rightItemSize = rightItemComponent.update(
                    transition: rightItemTransition,
                    component: AnyComponent(GlassControlGroupComponent(
                        theme: component.theme,
                        preferClearGlass: component.preferClearGlass,
                        background: rightItem.background,
                        items: rightItem.items,
                        minWidth: availableSize.height
                    )),
                    environment: {},
                    containerSize: CGSize(width: availableSize.width, height: availableSize.height)
                )
                let rightItemFrameValue = CGRect(origin: CGPoint(x: availableSize.width - rightItemSize.width, y: 0.0), size: rightItemSize)
                rightItemFrame = rightItemFrameValue
                if let rightItemComponentView = rightItemComponent.view {
                    var animateIn = false
                    if rightItemComponentView.superview == nil {
                        animateIn = true
                        self.glassContainerView.contentView.addSubview(rightItemComponentView)
                        ComponentTransition.immediate.setScale(view: rightItemComponentView, scale: 0.001)
                    }
                    rightItemTransition.setPosition(view: rightItemComponentView, position: rightItemFrameValue.center)
                    rightItemTransition.setBounds(view: rightItemComponentView, bounds: CGRect(origin: CGPoint(), size: rightItemFrameValue.size))
                    if animateIn {
                        alphaTransition.animateAlpha(view: rightItemComponentView, from: 0.0, to: 1.0)
                        transition.setScale(view: rightItemComponentView, scale: 1.0)
                    }
                }
            } else if let rightItemComponent = self.rightItemComponent {
                self.rightItemComponent = nil
                if let rightItemComponentView = rightItemComponent.view {
                    transition.setScale(view: rightItemComponentView, scale: 0.001)
                    alphaTransition.setAlpha(view: rightItemComponentView, alpha: 0.0, completion: { [weak rightItemComponentView] _ in
                        rightItemComponentView?.removeFromSuperview()
                    })
                }
            }
            
            if let centralItem = component.centralItem {
                let centralItemComponent: ComponentView<Empty>
                var centralItemTransition = transition
                if let current = self.centralItemComponent {
                    centralItemComponent = current
                } else {
                    centralItemComponent = ComponentView()
                    self.centralItemComponent = centralItemComponent
                    centralItemTransition = transition.withAnimation(.none)
                }
                
                var maxCentralItemSize = CGSize(width: availableSize.width, height: availableSize.height)
                var centralRightInset: CGFloat = 0.0
                if let rightItemFrame {
                    centralRightInset = availableSize.width - rightItemFrame.minX + minSpacing
                }
                var centralLeftInset: CGFloat = 0.0
                if let leftItemFrame {
                    centralLeftInset = leftItemFrame.maxX + minSpacing
                }
                
                if centralRightInset <= 48.0 && centralLeftInset <= 48.0 {
                    let maxInset = max(centralRightInset, centralLeftInset)
                    centralLeftInset = maxInset
                    centralRightInset = maxInset
                }
                
                maxCentralItemSize.width = max(1.0, availableSize.width - centralLeftInset - centralRightInset)
                
                let centralItemSize = centralItemComponent.update(
                    transition: centralItemTransition,
                    component: AnyComponent(GlassControlGroupComponent(
                        theme: component.theme,
                        preferClearGlass: component.preferClearGlass,
                        background: centralItem.background,
                        items: centralItem.items,
                        minWidth: centralItem.keepWide ? 165.0 : availableSize.height
                    )),
                    environment: {},
                    containerSize: maxCentralItemSize
                )
                var centralItemFrameValue = CGRect(origin: CGPoint(x: centralLeftInset + floor((availableSize.width - centralLeftInset - centralRightInset - centralItemSize.width) * 0.5), y: 0.0), size: centralItemSize)
                if component.centerAlignmentIfPossible {
                    let maxInset = max(centralLeftInset, centralRightInset)
                    if availableSize.width - maxInset * 2.0 > centralItemSize.width {
                        centralItemFrameValue.origin.x = maxInset + floor((availableSize.width - maxInset * 2.0 - centralItemSize.width) * 0.5)
                    }
                }
                
                if let centralItemComponentView = centralItemComponent.view {
                    var animateIn = false
                    if centralItemComponentView.superview == nil {
                        animateIn = true
                        self.glassContainerView.contentView.addSubview(centralItemComponentView)
                        ComponentTransition.immediate.setScale(view: centralItemComponentView, scale: 0.001)
                    }
                    centralItemTransition.setPosition(view: centralItemComponentView, position: centralItemFrameValue.center)
                    centralItemTransition.setBounds(view: centralItemComponentView, bounds: CGRect(origin: CGPoint(), size: centralItemFrameValue.size))
                    if animateIn {
                        alphaTransition.animateAlpha(view: centralItemComponentView, from: 0.0, to: 1.0)
                        transition.setScale(view: centralItemComponentView, scale: 1.0)
                    }
                }
            } else if let centralItemComponent = self.centralItemComponent {
                self.centralItemComponent = nil
                if let centralItemComponentView = centralItemComponent.view {
                    transition.setScale(view: centralItemComponentView, scale: 0.001)
                    alphaTransition.setAlpha(view: centralItemComponentView, alpha: 0.0, completion: { [weak centralItemComponentView] _ in
                        centralItemComponentView?.removeFromSuperview()
                    })
                }
            }
            
            transition.setFrame(view: self.glassContainerView, frame: CGRect(origin: CGPoint(), size: availableSize))
            self.glassContainerView.update(size: availableSize, isDark: component.isDark ?? component.theme.overallDarkAppearance, transition: transition)
            
            return availableSize
        }
    }

    public func makeView() -> View {
        return View(frame: CGRect())
    }
    
    public func update(view: View, availableSize: CGSize, state: EmptyComponentState, environment: Environment<Empty>, transition: ComponentTransition) -> CGSize {
        return view.update(component: self, availableSize: availableSize, state: state, environment: environment, transition: transition)
    }
}
