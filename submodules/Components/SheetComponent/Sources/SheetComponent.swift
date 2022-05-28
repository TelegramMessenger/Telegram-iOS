import Foundation
import UIKit
import Display
import ComponentFlow
import ViewControllerComponent

public final class SheetComponentEnvironment: Equatable {
    public let isDisplaying: Bool
    public let dismiss: () -> Void
    
    public init(isDisplaying: Bool, dismiss: @escaping () -> Void) {
        self.isDisplaying = isDisplaying
        self.dismiss = dismiss
    }
    
    public static func ==(lhs: SheetComponentEnvironment, rhs: SheetComponentEnvironment) -> Bool {
        if lhs.isDisplaying != rhs.isDisplaying {
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
        private var dismiss: (() -> Void)?
        
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
                self.dismiss?()
            }
        }
        
        public func scrollViewDidScroll(_ scrollView: UIScrollView) {
        }
        
        public func scrollViewWillEndDragging(_ scrollView: UIScrollView, withVelocity velocity: CGPoint, targetContentOffset: UnsafeMutablePointer<CGPoint>) {
        }
        
        public func scrollViewWillBeginDragging(_ scrollView: UIScrollView) {
        }
        
        override public func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
            if !self.backgroundView.bounds.contains(self.convert(point, to: self.backgroundView)) {
                return self.dimView
            }
            
            return super.hitTest(point, with: event)
        }
        
        private func animateOut(completion: @escaping () -> Void) {
            self.isUserInteractionEnabled = false
            self.dimView.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.25, removeOnCompletion: false)
            self.scrollView.layer.animatePosition(from: CGPoint(), to: CGPoint(x: 0.0, y: self.bounds.height - self.scrollView.contentInset.top), duration: 0.25, timingFunction: CAMediaTimingFunctionName.easeIn.rawValue, removeOnCompletion: false, additive: true, completion: { _ in
                completion()
            })
        }
        
        func update(component: SheetComponent<ChildEnvironmentType>, availableSize: CGSize, state: EmptyComponentState, environment: Environment<EnvironmentType>, transition: Transition) -> CGSize {
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
            
            let contentSize = self.contentView.update(
                transition: transition,
                component: component.content,
                environment: {
                    environment[ChildEnvironmentType.self]
                },
                containerSize: CGSize(width: availableSize.width, height: .greatestFiniteMagnitude)
            )
            
            transition.setFrame(view: self.contentView, frame: CGRect(origin: CGPoint(), size: contentSize), completion: nil)
            transition.setFrame(view: self.backgroundView, frame: CGRect(origin: CGPoint(), size: CGSize(width: contentSize.width, height: contentSize.height + 1000.0)), completion: nil)
            transition.setFrame(view: self.scrollView, frame: CGRect(origin: CGPoint(), size: availableSize), completion: nil)
            self.scrollView.contentSize = contentSize
            self.scrollView.contentInset = UIEdgeInsets(top: max(0.0, availableSize.height - contentSize.height), left: 0.0, bottom: 0.0, right: 0.0)
            
            if environment[SheetComponentEnvironment.self].value.isDisplaying, !self.previousIsDisplaying, let _ = transition.userData(ViewControllerComponentContainer.AnimateInTransition.self) {
                self.dimView.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.3)
                self.scrollView.layer.animatePosition(from: CGPoint(x: 0.0, y: availableSize.height - self.scrollView.contentInset.top), to: CGPoint(), duration: 0.5, timingFunction: kCAMediaTimingFunctionSpring, additive: true, completion: nil)
            } else if !environment[SheetComponentEnvironment.self].value.isDisplaying, self.previousIsDisplaying, let _ = transition.userData(ViewControllerComponentContainer.AnimateOutTransition.self) {
                self.animateOut(completion: {})
            }
            self.previousIsDisplaying = environment[SheetComponentEnvironment.self].value.isDisplaying
            
            self.dismiss = environment[SheetComponentEnvironment.self].value.dismiss
            
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
