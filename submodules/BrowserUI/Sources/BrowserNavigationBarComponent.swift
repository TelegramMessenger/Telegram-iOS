import Foundation
import UIKit
import Display
import ComponentFlow
import BlurredBackgroundComponent
import ContextUI

final class BrowserNavigationBarComponent: CombinedComponent {
    let backgroundColor: UIColor
    let separatorColor: UIColor
    let textColor: UIColor
    let progressColor: UIColor
    let accentColor: UIColor
    let topInset: CGFloat
    let height: CGFloat
    let sideInset: CGFloat
    let leftItems: [AnyComponentWithIdentity<Empty>]
    let rightItems: [AnyComponentWithIdentity<Empty>]
    let centerItem: AnyComponentWithIdentity<Empty>?
    let readingProgress: CGFloat
    let loadingProgress: Double?
    let collapseFraction: CGFloat
    
    init(
        backgroundColor: UIColor,
        separatorColor: UIColor,
        textColor: UIColor,
        progressColor: UIColor,
        accentColor: UIColor,
        topInset: CGFloat,
        height: CGFloat,
        sideInset: CGFloat,
        leftItems: [AnyComponentWithIdentity<Empty>],
        rightItems: [AnyComponentWithIdentity<Empty>],
        centerItem: AnyComponentWithIdentity<Empty>?,
        readingProgress: CGFloat,
        loadingProgress: Double?,
        collapseFraction: CGFloat
    ) {
        self.backgroundColor = backgroundColor
        self.separatorColor = separatorColor
        self.textColor = textColor
        self.progressColor = progressColor
        self.accentColor = accentColor
        self.topInset = topInset
        self.height = height
        self.sideInset = sideInset
        self.leftItems = leftItems
        self.rightItems = rightItems
        self.centerItem = centerItem
        self.readingProgress = readingProgress
        self.loadingProgress = loadingProgress
        self.collapseFraction = collapseFraction
    }
    
    static func ==(lhs: BrowserNavigationBarComponent, rhs: BrowserNavigationBarComponent) -> Bool {
        if lhs.backgroundColor != rhs.backgroundColor {
            return false
        }
        if lhs.separatorColor != rhs.separatorColor {
            return false
        }
        if lhs.textColor != rhs.textColor {
            return false
        }
        if lhs.progressColor != rhs.progressColor {
            return false
        }
        if lhs.accentColor != rhs.accentColor {
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
        if lhs.leftItems != rhs.leftItems {
            return false
        }
        if lhs.rightItems != rhs.rightItems {
            return false
        }
        if lhs.centerItem != rhs.centerItem {
            return false
        }
        if lhs.readingProgress != rhs.readingProgress {
            return false
        }
        if lhs.loadingProgress != rhs.loadingProgress {
            return false
        }
        if lhs.collapseFraction != rhs.collapseFraction {
            return false
        }
        return true
    }
    
    static var body: Body {
        let background = Child(BlurredBackgroundComponent.self)
        let readingProgress = Child(Rectangle.self)
        let separator = Child(Rectangle.self)
        let loadingProgress = Child(LoadingProgressComponent.self)
        let leftItems = ChildMap(environment: Empty.self, keyedBy: AnyHashable.self)
        let rightItems = ChildMap(environment: Empty.self, keyedBy: AnyHashable.self)
        let centerItems = ChildMap(environment: Empty.self, keyedBy: AnyHashable.self)
        
        return { context in
            var availableWidth = context.availableSize.width
            let sideInset: CGFloat = 11.0 + context.component.sideInset
            
            let collapsedHeight: CGFloat = 24.0
            let expandedHeight = context.component.height
            let contentHeight: CGFloat = expandedHeight * (1.0 - context.component.collapseFraction) + collapsedHeight * context.component.collapseFraction
            let size = CGSize(width: context.availableSize.width, height: context.component.topInset + contentHeight)
            
            let background = background.update(
                component: BlurredBackgroundComponent(color: context.component.backgroundColor),
                availableSize: CGSize(width: size.width, height: size.height),
                transition: context.transition
            )
            
            let readingProgress = readingProgress.update(
                component: Rectangle(color: context.component.progressColor),
                availableSize: CGSize(width: size.width * context.component.readingProgress, height: size.height),
                transition: context.transition
            )
            
            let separator = separator.update(
                component: Rectangle(color: context.component.separatorColor, height: UIScreenPixel),
                availableSize: CGSize(width: size.width, height: size.height),
                transition: context.transition
            )
            
            let loadingProgressHeight: CGFloat = 2.0
            let loadingProgress = loadingProgress.update(
                component: LoadingProgressComponent(
                    color: context.component.accentColor,
                    height: loadingProgressHeight,
                    value: context.component.loadingProgress ?? 0.0
                ),
                availableSize: CGSize(width: size.width, height: size.height),
                transition: context.transition
            )
            
            var leftItemList: [_UpdatedChildComponent] = []
            for item in context.component.leftItems {
                let item = leftItems[item.id].update(
                    component: item.component,
                    availableSize: CGSize(width: availableWidth, height: expandedHeight),
                    transition: context.transition
                )
                leftItemList.append(item)
                availableWidth -= item.size.width
            }
                        
            var rightItemList: [_UpdatedChildComponent] = []
            for item in context.component.rightItems {
                let item = rightItems[item.id].update(
                    component: item.component,
                    availableSize: CGSize(width: availableWidth, height: expandedHeight),
                    transition: context.transition
                )
                rightItemList.append(item)
                availableWidth -= item.size.width
            }
            
            if !leftItemList.isEmpty || !rightItemList.isEmpty {
                availableWidth -= 32.0
            }
            
            let centerItem = context.component.centerItem.flatMap { item in
                centerItems[item.id].update(
                    component: item.component,
                    availableSize: CGSize(width: availableWidth, height: expandedHeight),
                    transition: context.transition
                )
            }
            if let centerItem = centerItem {
                availableWidth -= centerItem.size.width
            }
            
            context.add(background
                .position(CGPoint(x: size.width / 2.0, y: size.height / 2.0))
            )
            
            context.add(readingProgress
                .position(CGPoint(x: readingProgress.size.width / 2.0, y: size.height / 2.0))
            )
            
            context.add(separator
                .position(CGPoint(x: size.width / 2.0, y: size.height))
            )
            
            context.add(loadingProgress
                .position(CGPoint(x: size.width / 2.0, y: size.height - loadingProgressHeight / 2.0))
            )
            
            var centerLeftInset = sideInset
            var leftItemX = sideInset
            for item in leftItemList {
                context.add(item
                    .position(CGPoint(x: leftItemX + item.size.width / 2.0 - (item.size.width / 2.0 * 0.35 * context.component.collapseFraction), y: context.component.topInset + contentHeight / 2.0))
                    .scale(1.0 - 0.35 * context.component.collapseFraction)
                    .appear(.default(scale: false, alpha: true))
                    .disappear(.default(scale: false, alpha: true))
                )
                leftItemX -= item.size.width + 8.0
                centerLeftInset += item.size.width + 8.0
            }
    
            var centerRightInset = sideInset
            var rightItemX = context.availableSize.width - sideInset
            for item in rightItemList.reversed() {
                context.add(item
                    .position(CGPoint(x: rightItemX - item.size.width / 2.0 + (item.size.width / 2.0 * 0.35 * context.component.collapseFraction), y: context.component.topInset + contentHeight / 2.0))
                    .scale(1.0 - 0.35 * context.component.collapseFraction)
                    .opacity(1.0 - context.component.collapseFraction)
                    .appear(.default(scale: false, alpha: true))
                    .disappear(.default(scale: false, alpha: true))
                )
                rightItemX -= item.size.width + 8.0
                centerRightInset += item.size.width + 8.0
            }
            
            let maxCenterInset = max(centerLeftInset, centerRightInset)
            if let centerItem = centerItem {
                context.add(centerItem
                    .position(CGPoint(x: maxCenterInset + (context.availableSize.width - maxCenterInset * 2.0) / 2.0, y: context.component.topInset + contentHeight / 2.0))
                    .scale(1.0 - 0.35 * context.component.collapseFraction)
                    .appear(.default(scale: false, alpha: true))
                    .disappear(.default(scale: false, alpha: true))
                )
            }
            
            return size
        }
    }
}

private final class LoadingProgressComponent: Component {
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

        func update(component: LoadingProgressComponent, availableSize: CGSize, transition: Transition) -> CGSize {
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
                
            let transition: Transition
            if animated && value > 0.0 {
                transition = .spring(duration: 0.7)
            } else {
                transition = .immediate
            }
            
            let alphaTransition: Transition
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

    func update(view: View, availableSize: CGSize, state: EmptyComponentState, environment: Environment<Empty>, transition: Transition) -> CGSize {
        return view.update(component: self, availableSize: availableSize, transition: transition)
    }
}

final class ReferenceButtonComponent: Component {
    let content: AnyComponent<Empty>
    let tag: AnyObject?
    let action: () -> Void
    
    init(
        content: AnyComponent<Empty>,
        tag: AnyObject? = nil,
        action: @escaping () -> Void
    ) {
        self.content = content
        self.tag = tag
        self.action = action
    }
    
    static func ==(lhs: ReferenceButtonComponent, rhs: ReferenceButtonComponent) -> Bool {
        if lhs.content != rhs.content {
            return false
        }
        if lhs.tag !== rhs.tag {
            return false
        }
        return true
    }

    final class View: HighlightTrackingButton, ComponentTaggedView {
        private let sourceView: ContextControllerSourceView
        let referenceNode: ContextReferenceContentNode
        private let componentView: ComponentView<Empty>
        
        private var component: ReferenceButtonComponent?
        
        public func matches(tag: Any) -> Bool {
            if let component = self.component, let componentTag = component.tag {
                let tag = tag as AnyObject
                if componentTag === tag {
                    return true
                }
            }
            return false
        }
        
        init() {
            self.componentView = ComponentView()
            self.sourceView = ContextControllerSourceView()
            self.sourceView.animateScale = false
            self.referenceNode = ContextReferenceContentNode()
         
            super.init(frame: CGRect())
            
            self.sourceView.isUserInteractionEnabled = false
            self.addSubview(self.sourceView)
            self.sourceView.addSubnode(self.referenceNode)
            
            self.highligthedChanged = { [weak self] highlighted in
                if let strongSelf = self, let contentView = strongSelf.componentView.view {
                    if highlighted {
                        contentView.layer.removeAnimation(forKey: "opacity")
                        contentView.alpha = 0.4
                    } else {
                        contentView.alpha = 1.0
                        contentView.layer.animateAlpha(from: 0.4, to: 1.0, duration: 0.2)
                    }
                }
            }
            self.addTarget(self, action: #selector(self.pressed), for: .touchUpInside)
        }

        required init?(coder aDecoder: NSCoder) {
            preconditionFailure()
        }
        
        @objc private func pressed() {
            self.component?.action()
        }

        func update(component: ReferenceButtonComponent, availableSize: CGSize, transition: Transition) -> CGSize {
            self.component = component
            
            let componentSize = self.componentView.update(
                transition: transition,
                component: component.content,
                environment: {},
                containerSize: availableSize
            )
            if let componentView = self.componentView.view {
                if componentView.superview == nil {
                    self.referenceNode.view.addSubview(componentView)
                }
                transition.setFrame(view: componentView, frame: CGRect(origin: .zero, size: componentSize))
            }
            
            transition.setFrame(view: self.sourceView, frame: CGRect(origin: .zero, size: componentSize))
            self.referenceNode.frame = CGRect(origin: .zero, size: componentSize)
         
            return componentSize
        }
    }

    func makeView() -> View {
        return View()
    }

    func update(view: View, availableSize: CGSize, state: EmptyComponentState, environment: Environment<Empty>, transition: Transition) -> CGSize {
        return view.update(component: self, availableSize: availableSize, transition: transition)
    }
}
