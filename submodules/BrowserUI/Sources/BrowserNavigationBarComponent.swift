import Foundation
import UIKit
import Display
import ComponentFlow
import BlurredBackgroundComponent
import ContextUI

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

final class BrowserNavigationBarComponent: CombinedComponent {
    public class ExternalState {
        public fileprivate(set) var centerItemFrame: CGRect
        
        public init() {
            self.centerItemFrame = .zero
        }
    }
    
    let backgroundColor: UIColor
    let separatorColor: UIColor
    let textColor: UIColor
    let progressColor: UIColor
    let accentColor: UIColor
    let topInset: CGFloat
    let height: CGFloat
    let sideInset: CGFloat
    let metrics: LayoutMetrics
    let externalState: ExternalState?
    let leftItems: [AnyComponentWithIdentity<Empty>]
    let rightItems: [AnyComponentWithIdentity<Empty>]
    let centerItem: AnyComponentWithIdentity<BrowserNavigationBarEnvironment>?
    let readingProgress: CGFloat
    let loadingProgress: Double?
    let collapseFraction: CGFloat
    let activate: () -> Void
    
    init(
        backgroundColor: UIColor,
        separatorColor: UIColor,
        textColor: UIColor,
        progressColor: UIColor,
        accentColor: UIColor,
        topInset: CGFloat,
        height: CGFloat,
        sideInset: CGFloat,
        metrics: LayoutMetrics,
        externalState: ExternalState?,
        leftItems: [AnyComponentWithIdentity<Empty>],
        rightItems: [AnyComponentWithIdentity<Empty>],
        centerItem: AnyComponentWithIdentity<BrowserNavigationBarEnvironment>?,
        readingProgress: CGFloat,
        loadingProgress: Double?,
        collapseFraction: CGFloat,
        activate: @escaping () -> Void
    ) {
        self.backgroundColor = backgroundColor
        self.separatorColor = separatorColor
        self.textColor = textColor
        self.progressColor = progressColor
        self.accentColor = accentColor
        self.topInset = topInset
        self.height = height
        self.sideInset = sideInset
        self.metrics = metrics
        self.externalState = externalState
        self.leftItems = leftItems
        self.rightItems = rightItems
        self.centerItem = centerItem
        self.readingProgress = readingProgress
        self.loadingProgress = loadingProgress
        self.collapseFraction = collapseFraction
        self.activate = activate
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
        let background = Child(Rectangle.self)
        let readingProgress = Child(Rectangle.self)
        let separator = Child(Rectangle.self)
        let loadingProgress = Child(LoadingProgressComponent.self)
        let leftItems = ChildMap(environment: Empty.self, keyedBy: AnyHashable.self)
        let rightItems = ChildMap(environment: Empty.self, keyedBy: AnyHashable.self)
        let centerItems = ChildMap(environment: BrowserNavigationBarEnvironment.self, keyedBy: AnyHashable.self)
        let activate = Child(Button.self)
        
        return { context in
            var availableWidth = context.availableSize.width
            let sideInset: CGFloat = (context.component.metrics.isTablet ? 20.0 : 16.0) + context.component.sideInset
            
            let collapsedHeight: CGFloat = 24.0
            let expandedHeight = context.component.height
            let contentHeight: CGFloat = expandedHeight * (1.0 - context.component.collapseFraction) + collapsedHeight * context.component.collapseFraction
            let size = CGSize(width: context.availableSize.width, height: context.component.topInset + contentHeight)
            let verticalOffset: CGFloat = context.component.metrics.isTablet ? -2.0 : 0.0
            let itemSpacing: CGFloat = context.component.metrics.isTablet ? 26.0 : 8.0
            
            let background = background.update(
                component: Rectangle(color: context.component.backgroundColor.withAlphaComponent(1.0)),
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
                    
            context.add(background
                .position(CGPoint(x: size.width / 2.0, y: size.height / 2.0))
            )
            
            var readingProgressAlpha = context.component.collapseFraction
            if leftItemList.isEmpty && rightItemList.isEmpty {
                readingProgressAlpha = 0.0
            }
            context.add(readingProgress
                .position(CGPoint(x: readingProgress.size.width / 2.0, y: size.height / 2.0))
                .opacity(readingProgressAlpha)
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
                    .position(CGPoint(x: leftItemX + item.size.width / 2.0 - (item.size.width / 2.0 * 0.35 * context.component.collapseFraction), y: context.component.topInset + contentHeight / 2.0 + verticalOffset))
                    .scale(1.0 - 0.35 * context.component.collapseFraction)
                    .opacity(1.0 - context.component.collapseFraction)
                    .appear(.default(scale: true, alpha: true))
                    .disappear(.default(scale: true, alpha: true))
                )
                leftItemX += item.size.width + itemSpacing
                centerLeftInset += item.size.width + itemSpacing
            }
    
            var centerRightInset = sideInset - 5.0
            var rightItemX = context.availableSize.width - (sideInset - 5.0)
            for item in rightItemList.reversed() {
                context.add(item
                    .position(CGPoint(x: rightItemX - item.size.width / 2.0 + (item.size.width / 2.0 * 0.35 * context.component.collapseFraction), y: context.component.topInset + contentHeight / 2.0 + verticalOffset))
                    .scale(1.0 - 0.35 * context.component.collapseFraction)
                    .opacity(1.0 - context.component.collapseFraction)
                    .appear(.default(scale: true, alpha: true))
                    .disappear(.default(scale: true, alpha: true))
                )
                rightItemX -= item.size.width + itemSpacing
                centerRightInset += item.size.width + itemSpacing
            }
            
            let maxCenterInset = max(centerLeftInset, centerRightInset)
            
            if !leftItemList.isEmpty || !rightItemList.isEmpty {
                availableWidth -= itemSpacing * CGFloat(max(0, leftItemList.count - 1)) + itemSpacing * CGFloat(max(0, rightItemList.count - 1)) + 30.0
            }
            availableWidth -= context.component.sideInset * 2.0
            
            let canCenter = availableWidth > 660.0
            availableWidth = min(660.0, availableWidth)
            
            let environment = BrowserNavigationBarEnvironment(fraction: context.component.collapseFraction)
            
            let centerItem = context.component.centerItem.flatMap { item in
                centerItems[item.id].update(
                    component: item.component,
                    environment: { environment },
                    availableSize: CGSize(width: availableWidth, height: expandedHeight),
                    transition: context.transition
                )
            }
            
            var centerX = maxCenterInset + (context.availableSize.width - maxCenterInset * 2.0) / 2.0
            if "".isEmpty {
                if canCenter {
                    centerX = context.availableSize.width / 2.0
                } else {
                    centerX = centerLeftInset + (context.availableSize.width - centerLeftInset - centerRightInset) / 2.0
                }
            }
            if let centerItem = centerItem {
                let centerItemPosition = CGPoint(x: centerX, y: context.component.topInset + contentHeight / 2.0 + verticalOffset)
                context.add(centerItem
                    .position(centerItemPosition)
                    .scale(1.0 - 0.35 * context.component.collapseFraction)
                    .appear(.default(scale: false, alpha: true))
                    .disappear(.default(scale: false, alpha: true))
                )
                
                context.component.externalState?.centerItemFrame = centerItem.size.centered(around: centerItemPosition)
            }
            
            if context.component.collapseFraction == 1.0 {
                let activateAction = context.component.activate
                let activate = activate.update(
                    component: Button(
                        content: AnyComponent(Rectangle(color: UIColor(rgb: 0x000000, alpha: 0.001))),
                        action: {
                            activateAction()
                        }
                    ),
                    availableSize: size,
                    transition: .immediate
                )
                context.add(activate
                    .position(CGPoint(x: size.width / 2.0, y: size.height / 2.0))
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
        let componentView: ComponentView<Empty>
        
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

        func update(component: ReferenceButtonComponent, availableSize: CGSize, transition: ComponentTransition) -> CGSize {
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

    func update(view: View, availableSize: CGSize, state: EmptyComponentState, environment: Environment<Empty>, transition: ComponentTransition) -> CGSize {
        return view.update(component: self, availableSize: availableSize, transition: transition)
    }
}
