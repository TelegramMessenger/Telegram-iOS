import Foundation
import UIKit
import Display
import ComponentFlow
import ViewControllerComponent

public final class SheetComponentEnvironment: Equatable {
    public let isDisplaying: Bool
    public let isCentered: Bool
    public let dismiss: (Bool) -> Void
    
    public init(isDisplaying: Bool, isCentered: Bool, dismiss: @escaping (Bool) -> Void) {
        self.isDisplaying = isDisplaying
        self.isCentered = isCentered
        self.dismiss = dismiss
    }
    
    public static func ==(lhs: SheetComponentEnvironment, rhs: SheetComponentEnvironment) -> Bool {
        if lhs.isDisplaying != rhs.isDisplaying {
            return false
        }
        if lhs.isCentered != rhs.isCentered {
            return false
        }
        return true
    }
}

public final class SheetComponent<ChildEnvironmentType: Equatable>: Component {
    public typealias EnvironmentType = (ChildEnvironmentType, SheetComponentEnvironment)
    
    public let content: AnyComponent<ChildEnvironmentType>
    public let backgroundColor: UIColor
    public let animateOut: ActionSlot<Action<()>>
    
    public init(content: AnyComponent<ChildEnvironmentType>, backgroundColor: UIColor, animateOut: ActionSlot<Action<()>>) {
        self.content = content
        self.backgroundColor = backgroundColor
        self.animateOut = animateOut
    }
    
    public static func ==(lhs: SheetComponent, rhs: SheetComponent) -> Bool {
        if lhs.content != rhs.content {
            return false
        }
        if lhs.backgroundColor != rhs.backgroundColor {
            return false
        }
        if lhs.animateOut != rhs.animateOut {
            return false
        }
        
        return true
    }
    
    public final class View: UIView, UIScrollViewDelegate {
        private let dimView: UIView
        private let scrollView: UIScrollView
        private let backgroundView: UIView
        private let contentView: ComponentHostView<ChildEnvironmentType>
        
        private var previousIsDisplaying: Bool = false
        private var dismiss: ((Bool) -> Void)?
        
        override init(frame: CGRect) {
            self.dimView = UIView()
            self.dimView.backgroundColor = UIColor(white: 0.0, alpha: 0.4)
            
            self.scrollView = UIScrollView()
            self.scrollView.delaysContentTouches = false
            if #available(iOSApplicationExtension 11.0, iOS 11.0, *) {
                self.scrollView.contentInsetAdjustmentBehavior = .never
            }
            self.scrollView.showsVerticalScrollIndicator = false
            self.scrollView.showsHorizontalScrollIndicator = false
            self.scrollView.alwaysBounceVertical = true
            
            self.backgroundView = UIView()
            self.backgroundView.layer.cornerRadius = 10.0
            self.backgroundView.layer.masksToBounds = true
            
            self.contentView = ComponentHostView<ChildEnvironmentType>()
            
            super.init(frame: frame)
            
            self.scrollView.delegate = self
            
            self.addSubview(self.dimView)
            self.scrollView.addSubview(self.backgroundView)
            self.scrollView.addSubview(self.contentView)
            self.addSubview(self.scrollView)
            
            self.dimView.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(self.dimViewTapGesture(_:))))
        }
        
        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }
        
        @objc private func dimViewTapGesture(_ recognizer: UITapGestureRecognizer) {
            if case .ended = recognizer.state {
                self.dismiss?(true)
            }
        }
        
        private var scrollingOut = false
        public func scrollViewWillEndDragging(_ scrollView: UIScrollView, withVelocity velocity: CGPoint, targetContentOffset: UnsafeMutablePointer<CGPoint>) {
            let contentOffset = (scrollView.contentOffset.y + scrollView.contentInset.top - scrollView.contentSize.height) * -1.0
            let dismissalOffset = scrollView.contentSize.height - scrollView.contentInset.top  + scrollView.contentSize.height
            let delta = dismissalOffset - contentOffset
            
            let initialVelocity = !delta.isZero ? velocity.y / delta : 0.0
            
            let currentContentOffset = scrollView.contentOffset
            targetContentOffset.pointee = currentContentOffset
            if velocity.y > 300.0 {
                self.animateOut(initialVelocity: initialVelocity, completion: {
                    self.dismiss?(false)
                })
            } else {
                if contentOffset < scrollView.contentSize.height * 0.1 {
                    if contentOffset < 0.0 {
                        
                    } else {
                        scrollView.setContentOffset(CGPoint(x: 0.0, y: scrollView.contentSize.height - scrollView.contentInset.top), animated: true)
                    }
                } else {
                    self.animateOut(initialVelocity: initialVelocity, completion: {
                        self.dismiss?(false)
                    })
                }
            }
        }
               
        private var ignoreScrolling: Bool = false
        public func scrollViewDidScroll(_ scrollView: UIScrollView) {
            guard !self.ignoreScrolling else {
                return
            }
            let contentOffset = (scrollView.contentOffset.y + scrollView.contentInset.top - scrollView.contentSize.height) * -1.0
            if contentOffset >= scrollView.contentSize.height {
                self.dismiss?(false)
            }
        }
        
        override public func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
            if !self.backgroundView.bounds.contains(self.convert(point, to: self.backgroundView)) {
                return self.dimView
            }
            
            return super.hitTest(point, with: event)
        }
        
        private func animateIn() {
            self.dimView.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.3)
            
            let transition = ContainedViewLayoutTransition.animated(duration: 0.4, curve: .spring)
            let targetPosition = self.scrollView.center
            self.scrollView.center = targetPosition.offsetBy(dx: 0.0, dy: self.scrollView.contentSize.height)
            transition.animateView(allowUserInteraction: true, {
                self.scrollView.center = targetPosition
            })
        }
        
        private func animateOut(initialVelocity: CGFloat? = nil, completion: @escaping () -> Void) {
            self.isUserInteractionEnabled = false
            self.dimView.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.3, removeOnCompletion: false)
            
            if let initialVelocity = initialVelocity {
                let transition = ContainedViewLayoutTransition.animated(duration: 0.35, curve: .customSpring(damping: 124.0, initialVelocity: initialVelocity))
                
                let contentOffset = (self.scrollView.contentOffset.y + self.scrollView.contentInset.top - self.scrollView.contentSize.height) * -1.0
                let dismissalOffset = self.scrollView.contentSize.height + abs(self.contentView.frame.minY)
                let delta = dismissalOffset - contentOffset
                
                transition.updatePosition(layer: self.scrollView.layer, position: CGPoint(x: self.scrollView.center.x, y: self.scrollView.center.y + delta), completion: { _ in
                    completion()
                })
            } else {
                self.scrollView.layer.animatePosition(from: CGPoint(), to: CGPoint(x: 0.0, y: self.scrollView.contentSize.height + abs(self.contentView.frame.minY)), duration: 0.25, timingFunction: CAMediaTimingFunctionName.easeInEaseOut.rawValue, removeOnCompletion: false, additive: true, completion: { _ in
                    completion()
                })
            }
        }
        
        private var currentAvailableSize: CGSize?
        func update(component: SheetComponent<ChildEnvironmentType>, availableSize: CGSize, state: EmptyComponentState, environment: Environment<EnvironmentType>, transition: Transition) -> CGSize {
            let sheetEnvironment = environment[SheetComponentEnvironment.self].value
            component.animateOut.connect { [weak self] completion in
                guard let strongSelf = self else {
                    return
                }
                strongSelf.animateOut {
                    completion(Void())
                }
            }
            
            if self.backgroundView.backgroundColor != component.backgroundColor {
                self.backgroundView.backgroundColor = component.backgroundColor
            }
            
            transition.setFrame(view: self.dimView, frame: CGRect(origin: CGPoint(), size: availableSize), completion: nil)
            
            let containerSize: CGSize
            if sheetEnvironment.isCentered {
                let verticalInset: CGFloat = 44.0
                let maxSide = max(availableSize.width, availableSize.height)
                let minSide = min(availableSize.width, availableSize.height)
                containerSize = CGSize(width: min(availableSize.width - 20.0, floor(maxSide / 2.0)), height: min(availableSize.height, minSide) - verticalInset * 2.0)
            } else {
                containerSize = CGSize(width: availableSize.width, height: .greatestFiniteMagnitude)
            }
            
            let contentSize = self.contentView.update(
                transition: transition,
                component: component.content,
                environment: {
                    environment[ChildEnvironmentType.self]
                },
                containerSize: containerSize
            )
            
            self.ignoreScrolling = true

            if sheetEnvironment.isCentered {
                let y: CGFloat = floorToScreenPixels((availableSize.height - contentSize.height) / 2.0)
                transition.setFrame(view: self.contentView, frame: CGRect(origin: CGPoint(x: floorToScreenPixels((availableSize.width - contentSize.width) / 2.0), y: -y), size: contentSize), completion: nil)
                transition.setFrame(view: self.backgroundView, frame: CGRect(origin: CGPoint(x: floorToScreenPixels((availableSize.width - contentSize.width) / 2.0), y: -y), size: contentSize), completion: nil)
            } else {
                transition.setFrame(view: self.contentView, frame: CGRect(origin: .zero, size: contentSize), completion: nil)
                transition.setFrame(view: self.backgroundView, frame: CGRect(origin: .zero, size: CGSize(width: contentSize.width, height: contentSize.height + 1000.0)), completion: nil)
            }
            transition.setFrame(view: self.scrollView, frame: CGRect(origin: CGPoint(), size: availableSize), completion: nil)
            
            self.scrollView.contentSize = contentSize
            self.scrollView.contentInset = UIEdgeInsets(top: max(0.0, availableSize.height - contentSize.height) + contentSize.height, left: 0.0, bottom: 0.0, right: 0.0)
            self.ignoreScrolling = false
            
            if let currentAvailableSize = self.currentAvailableSize, currentAvailableSize.height != availableSize.height {
                self.scrollView.contentOffset = CGPoint(x: 0.0, y: -(availableSize.height - contentSize.height))
            }
            self.currentAvailableSize = availableSize
            
            if environment[SheetComponentEnvironment.self].value.isDisplaying, !self.previousIsDisplaying, let _ = transition.userData(ViewControllerComponentContainer.AnimateInTransition.self) {
                self.animateIn()
            } else if !environment[SheetComponentEnvironment.self].value.isDisplaying, self.previousIsDisplaying, let _ = transition.userData(ViewControllerComponentContainer.AnimateOutTransition.self) {
                self.animateOut(completion: {})
            }
            self.previousIsDisplaying = sheetEnvironment.isDisplaying
            self.dismiss = sheetEnvironment.dismiss
            
            return availableSize
        }
    }
    
    public func makeView() -> View {
        return View(frame: CGRect())
    }
    
    public func update(view: View, availableSize: CGSize, state: EmptyComponentState, environment: Environment<EnvironmentType>, transition: Transition) -> CGSize {
        return view.update(component: self, availableSize: availableSize, state: state, environment: environment, transition: transition)
    }
}
