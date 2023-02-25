import Foundation
import UIKit
import Display
import ComponentFlow
import ViewControllerComponent
import SwiftSignalKit

public final class SheetComponentEnvironment: Equatable {
    public let isDisplaying: Bool
    public let isCentered: Bool
    public let hasInputHeight: Bool
    public let regularMetricsSize: CGSize?
    public let dismiss: (Bool) -> Void
    
    public init(isDisplaying: Bool, isCentered: Bool, hasInputHeight: Bool, regularMetricsSize: CGSize?, dismiss: @escaping (Bool) -> Void) {
        self.isDisplaying = isDisplaying
        self.isCentered = isCentered
        self.hasInputHeight = hasInputHeight
        self.regularMetricsSize = regularMetricsSize
        self.dismiss = dismiss
    }
    
    public static func ==(lhs: SheetComponentEnvironment, rhs: SheetComponentEnvironment) -> Bool {
        if lhs.isDisplaying != rhs.isDisplaying {
            return false
        }
        if lhs.isCentered != rhs.isCentered {
            return false
        }
        if lhs.hasInputHeight != rhs.hasInputHeight {
            return false
        }
        if lhs.regularMetricsSize != rhs.regularMetricsSize {
            return false
        }
        return true
    }
}

public final class SheetComponent<ChildEnvironmentType: Equatable>: Component {
    public typealias EnvironmentType = (ChildEnvironmentType, SheetComponentEnvironment)
    
    public enum BackgroundColor: Equatable {
        public enum BlurStyle: Equatable {
            case light
            case dark
        }
        
        case color(UIColor)
        case blur(BlurStyle)
    }
    
    public let content: AnyComponent<ChildEnvironmentType>
    public let backgroundColor: BackgroundColor
    public let animateOut: ActionSlot<Action<()>>
    
    public init(
        content: AnyComponent<ChildEnvironmentType>,
        backgroundColor: BackgroundColor,
        animateOut: ActionSlot<Action<()>>
    ) {
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
    
    private class ScrollView: UIScrollView {
        var ignoreScroll = false
        override func setContentOffset(_ contentOffset: CGPoint, animated: Bool) {
            guard !self.ignoreScroll else {
                return
            }
            if animated && abs(contentOffset.y - self.contentOffset.y) > 200.0 {
                return
            }
            super.setContentOffset(contentOffset, animated: animated)
        }
    }
        
    public final class View: UIView, UIScrollViewDelegate {
        private let dimView: UIView
        private let scrollView: ScrollView
        private let backgroundView: UIView
        private var effectView: UIVisualEffectView?
        private let contentView: ComponentHostView<ChildEnvironmentType>
        
        private var previousIsDisplaying: Bool = false
        private var dismiss: ((Bool) -> Void)?
        
        private var keyboardWillShowObserver: AnyObject?
        
        override init(frame: CGRect) {
            self.dimView = UIView()
            self.dimView.backgroundColor = UIColor(white: 0.0, alpha: 0.4)
            
            self.scrollView = ScrollView()
            self.scrollView.delaysContentTouches = false
            if #available(iOSApplicationExtension 11.0, iOS 11.0, *) {
                self.scrollView.contentInsetAdjustmentBehavior = .never
            }
            self.scrollView.showsVerticalScrollIndicator = false
            self.scrollView.showsHorizontalScrollIndicator = false
            self.scrollView.alwaysBounceVertical = true
            
            self.backgroundView = UIView()
            self.backgroundView.layer.cornerRadius = 12.0
            self.backgroundView.layer.masksToBounds = true
            
            self.contentView = ComponentHostView<ChildEnvironmentType>()
            
            super.init(frame: frame)
            
            self.scrollView.delegate = self
            
            self.addSubview(self.dimView)
            self.scrollView.addSubview(self.backgroundView)
            self.scrollView.addSubview(self.contentView)
            self.addSubview(self.scrollView)
            
            self.dimView.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(self.dimViewTapGesture(_:))))
                        
            self.keyboardWillShowObserver = NotificationCenter.default.addObserver(forName: UIResponder.keyboardWillShowNotification, object: nil, queue: nil, using: { [weak self] _ in
                if let strongSelf = self {
                    strongSelf.scrollView.ignoreScroll = true
                    Queue.mainQueue().after(0.1, {
                        strongSelf.scrollView.ignoreScroll = false
                    })
                }
            })
        }
                                                                                              
        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }
        
        deinit {
            if let keyboardFrameChangeObserver = self.keyboardWillShowObserver {
                NotificationCenter.default.removeObserver(keyboardFrameChangeObserver)
            }
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
        
        private var currentHasInputHeight = false
        private var currentAvailableSize: CGSize?
        func update(component: SheetComponent<ChildEnvironmentType>, availableSize: CGSize, state: EmptyComponentState, environment: Environment<EnvironmentType>, transition: Transition) -> CGSize {
            let previousHasInputHeight = self.currentHasInputHeight
            let sheetEnvironment = environment[SheetComponentEnvironment.self].value
            component.animateOut.connect { [weak self] completion in
                guard let strongSelf = self else {
                    return
                }
                strongSelf.animateOut {
                    completion(Void())
                }
            }
            
            self.currentHasInputHeight = sheetEnvironment.hasInputHeight
            
            switch component.backgroundColor {
                case let .blur(style):
                    self.backgroundView.isHidden = true
                    if self.effectView == nil {
                        let effectView = UIVisualEffectView(effect: UIBlurEffect(style: style == .dark ? .dark : .light))
                        effectView.layer.cornerRadius = self.backgroundView.layer.cornerRadius
                        effectView.layer.masksToBounds = true
                        self.backgroundView.superview?.insertSubview(effectView, aboveSubview: self.backgroundView)
                        self.effectView = effectView
                    }
                case let .color(color):
                    self.backgroundView.backgroundColor = color
                    self.backgroundView.isHidden = false
                    self.effectView?.removeFromSuperview()
                    self.effectView = nil
            }
                        
            transition.setFrame(view: self.dimView, frame: CGRect(origin: CGPoint(), size: availableSize), completion: nil)
            
            var containerSize: CGSize
            if sheetEnvironment.isCentered {
                let verticalInset: CGFloat = 44.0
                let maxSide = max(availableSize.width, availableSize.height)
                let minSide = min(availableSize.width, availableSize.height)
                containerSize = CGSize(width: min(availableSize.width - 20.0, floor(maxSide / 2.0)), height: min(availableSize.height, minSide) - verticalInset * 2.0)
                if let regularMetricsSize = sheetEnvironment.regularMetricsSize {
                    containerSize = regularMetricsSize
                }
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
                if let effectView = self.effectView {
                    transition.setFrame(view: effectView, frame: CGRect(origin: CGPoint(x: floorToScreenPixels((availableSize.width - contentSize.width) / 2.0), y: -y), size: contentSize), completion: nil)
                }
            } else {
                transition.setFrame(view: self.contentView, frame: CGRect(origin: .zero, size: contentSize), completion: nil)
                transition.setFrame(view: self.backgroundView, frame: CGRect(origin: .zero, size: CGSize(width: contentSize.width, height: contentSize.height + 1000.0)), completion: nil)
                if let effectView = self.effectView {
                    transition.setFrame(view: effectView, frame: CGRect(origin: .zero, size: CGSize(width: contentSize.width, height: contentSize.height + 1000.0)), completion: nil)
                }
            }
            transition.setFrame(view: self.scrollView, frame: CGRect(origin: CGPoint(), size: availableSize), completion: nil)
            
            self.scrollView.contentSize = contentSize
            self.scrollView.contentInset = UIEdgeInsets(top: max(0.0, availableSize.height - contentSize.height) + contentSize.height, left: 0.0, bottom: 0.0, right: 0.0)
            self.ignoreScrolling = false
            
            if let currentAvailableSize = self.currentAvailableSize, currentAvailableSize.height != availableSize.height {
                self.scrollView.contentOffset = CGPoint(x: 0.0, y: -(availableSize.height - contentSize.height))
            }
            if self.currentHasInputHeight != previousHasInputHeight {
                transition.setBounds(view: self.scrollView, bounds: CGRect(origin: CGPoint(x: 0.0, y: -(availableSize.height - contentSize.height)), size: self.scrollView.bounds.size))
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
