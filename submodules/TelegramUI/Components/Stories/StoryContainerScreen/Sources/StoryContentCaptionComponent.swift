import Foundation
import UIKit
import Display
import ComponentFlow
import MultilineTextComponent

final class StoryContentCaptionComponent: Component {
    final class ExternalState {
        fileprivate(set) var expandFraction: CGFloat = 0.0
        
        init() {
        }
    }
    
    let externalState: ExternalState
    let text: String
    
    init(
        externalState: ExternalState,
        text: String
    ) {
        self.externalState = externalState
        self.text = text
    }

    static func ==(lhs: StoryContentCaptionComponent, rhs: StoryContentCaptionComponent) -> Bool {
        if lhs.text != rhs.text {
            return false
        }
        return true
    }

    final class View: UIView, UIScrollViewDelegate {
        private let scrollViewContainer: UIView
        private let scrollView: UIScrollView
        
        private let scrollMaskContainer: UIView
        private let scrollFullMaskView: UIView
        private let scrollCenterMaskView: UIView
        private let scrollBottomMaskView: UIImageView
        
        private let text = ComponentView<Empty>()

        private var component: StoryContentCaptionComponent?
        private weak var state: EmptyComponentState?
        
        private var ignoreScrolling: Bool = false
        private var ignoreExternalState: Bool = false
        
        override init(frame: CGRect) {
            self.scrollViewContainer = UIView()
            
            self.scrollView = UIScrollView()
            self.scrollView.canCancelContentTouches = true
            self.scrollView.delaysContentTouches = false
            self.scrollView.showsVerticalScrollIndicator = false
            self.scrollView.contentInsetAdjustmentBehavior = .never
            self.scrollView.alwaysBounceVertical = false
            
            self.scrollMaskContainer = UIView()
            
            self.scrollFullMaskView = UIView()
            self.scrollFullMaskView.backgroundColor = .white
            self.scrollFullMaskView.alpha = 0.0
            self.scrollMaskContainer.addSubview(self.scrollFullMaskView)
            
            self.scrollCenterMaskView = UIView()
            self.scrollCenterMaskView.backgroundColor = .white
            self.scrollMaskContainer.addSubview(self.scrollCenterMaskView)
            
            self.scrollBottomMaskView = UIImageView(image: generateGradientImage(size: CGSize(width: 8.0, height: 8.0), colors: [
                UIColor(white: 1.0, alpha: 1.0),
                UIColor(white: 1.0, alpha: 0.0)
            ], locations: [0.0, 1.0]))
            self.scrollMaskContainer.addSubview(self.scrollBottomMaskView)

            super.init(frame: frame)

            self.scrollViewContainer.addSubview(self.scrollView)
            self.scrollView.delegate = self
            self.addSubview(self.scrollViewContainer)
            
            self.scrollViewContainer.mask = self.scrollMaskContainer
        }
        
        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }
        
        override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
            if !self.bounds.contains(point) {
                return nil
            }
            if let textView = self.text.view {
                let textLocalPoint = self.convert(point, to: textView)
                if textLocalPoint.y >= -7.0 {
                    return self.scrollView
                }
            }
            
            return nil
        }
        
        func scrollViewDidScroll(_ scrollView: UIScrollView) {
            if !self.ignoreScrolling {
                self.updateScrolling(transition: .immediate)
            }
        }
        
        func collapse(transition: Transition) {
            self.ignoreScrolling = true
            transition.setBounds(view: self.scrollView, bounds: CGRect(origin: CGPoint(), size: self.scrollView.bounds.size))
            self.ignoreScrolling = false
            
            self.updateScrolling(transition: transition)
        }
        
        private func updateScrolling(transition: Transition) {
            guard let component = self.component else {
                return
            }
            
            var edgeDistance = self.scrollView.contentSize.height - self.scrollView.bounds.maxY
            edgeDistance = max(0.0, min(7.0, edgeDistance))
            
            let edgeDistanceFraction = edgeDistance / 7.0
            transition.setAlpha(view: self.scrollFullMaskView, alpha: 1.0 - edgeDistanceFraction)
            
            let expandDistance: CGFloat = 50.0
            var expandFraction: CGFloat = self.scrollView.contentOffset.y / expandDistance
            expandFraction = max(0.0, min(1.0, expandFraction))
            if self.scrollView.contentSize.height < self.scrollView.bounds.height + expandDistance {
                expandFraction = 0.0
            }
            if component.externalState.expandFraction != expandFraction {
                component.externalState.expandFraction = expandFraction
                
                if !self.ignoreExternalState {
                    self.state?.updated(transition: transition)
                }
            }
        }
        
        func update(component: StoryContentCaptionComponent, availableSize: CGSize, state: EmptyComponentState, environment: Environment<Empty>, transition: Transition) -> CGSize {
            self.ignoreExternalState = true
            
            self.component = component
            self.state = state
            
            let sideInset: CGFloat = 16.0
            let verticalInset: CGFloat = 7.0
            let textContainerSize = CGSize(width: availableSize.width - sideInset * 2.0 - 50.0, height: availableSize.height - verticalInset * 2.0)
            
            let textSize = self.text.update(
                transition: .immediate,
                component: AnyComponent(MultilineTextComponent(
                    text: .plain(NSAttributedString(string: component.text, font: Font.regular(16.0), textColor: .white)),
                    maximumNumberOfLines: 0,
                    textShadowColor: UIColor(white: 0.0, alpha: 0.3)
                )),
                environment: {},
                containerSize: textContainerSize
            )
            
            let maxHeight: CGFloat = 50.0
            let visibleTextHeight = min(maxHeight, textSize.height)
            let textOverflowHeight: CGFloat = textSize.height - visibleTextHeight
            let scrollContentSize = CGSize(width: availableSize.width, height: availableSize.height + textOverflowHeight)
            
            if let textView = self.text.view {
                if textView.superview == nil {
                    self.scrollView.addSubview(textView)
                }
                textView.frame = CGRect(origin: CGPoint(x: sideInset, y: availableSize.height - visibleTextHeight - verticalInset), size: textSize)
            }
            
            self.ignoreScrolling = true
            
            if self.scrollView.contentSize != scrollContentSize {
                self.scrollView.contentSize = scrollContentSize
            }
            transition.setFrame(view: self.scrollView, frame: CGRect(origin: CGPoint(x: 0.0, y: 0.0), size: CGSize(width: availableSize.width, height: availableSize.height)))
            transition.setFrame(view: self.scrollViewContainer, frame: CGRect(origin: CGPoint(x: 0.0, y: 0.0), size: CGSize(width: availableSize.width, height: availableSize.height)))
            
            self.ignoreScrolling = false
            self.updateScrolling(transition: transition)
            
            let gradientEdgeHeight: CGFloat = 18.0
            
            transition.setFrame(view: self.scrollFullMaskView, frame: CGRect(origin: CGPoint(), size: CGSize(width: availableSize.width, height: availableSize.height)))
            transition.setFrame(view: self.scrollCenterMaskView, frame: CGRect(origin: CGPoint(), size: CGSize(width: availableSize.width, height: availableSize.height - gradientEdgeHeight)))
            transition.setFrame(view: self.scrollBottomMaskView, frame: CGRect(origin: CGPoint(x: 0.0, y: availableSize.height - gradientEdgeHeight), size: CGSize(width: availableSize.width, height: gradientEdgeHeight)))
            
            self.ignoreExternalState = false
            
            return availableSize
        }
    }

    func makeView() -> View {
        return View(frame: CGRect())
    }
    
    func update(view: View, availableSize: CGSize, state: EmptyComponentState, environment: Environment<Empty>, transition: Transition) -> CGSize {
        return view.update(component: self, availableSize: availableSize, state: state, environment: environment, transition: transition)
    }
}
