import Foundation
import UIKit
import Display
import ComponentFlow
import MultilineTextComponent

final class StoryContentCaptionComponent: Component {
    final class ExternalState {
        fileprivate(set) var isExpanded: Bool = false
        
        init() {
        }
    }
    
    final class TransitionHint {
        enum Kind {
            case isExpandedUpdated
        }
        
        let kind: Kind
        
        init(kind: Kind) {
            self.kind = kind
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
    
    private struct ItemLayout {
        var containerSize: CGSize
        var visibleTextHeight: CGFloat
        var verticalInset: CGFloat
        
        init(
            containerSize: CGSize,
            visibleTextHeight: CGFloat,
            verticalInset: CGFloat
        ) {
            self.containerSize = containerSize
            self.visibleTextHeight = visibleTextHeight
            self.verticalInset = verticalInset
        }
    }

    final class View: UIView, UIScrollViewDelegate {
        private let scrollViewContainer: UIView
        private let scrollView: UIScrollView
        
        private let scrollMaskContainer: UIView
        private let scrollFullMaskView: UIView
        private let scrollCenterMaskView: UIView
        private let scrollBottomMaskView: UIImageView
        
        private let shadowGradientLayer: SimpleGradientLayer
        private let shadowPlainLayer: SimpleLayer
        
        private let text = ComponentView<Empty>()

        private var component: StoryContentCaptionComponent?
        private weak var state: EmptyComponentState?
        
        private var itemLayout: ItemLayout?
        
        private var ignoreScrolling: Bool = false
        private var ignoreExternalState: Bool = false
        
        override init(frame: CGRect) {
            self.shadowGradientLayer = SimpleGradientLayer()
            self.shadowPlainLayer = SimpleLayer()
            
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
            
            self.layer.addSublayer(self.shadowGradientLayer)
            self.layer.addSublayer(self.shadowPlainLayer)

            self.scrollViewContainer.addSubview(self.scrollView)
            self.scrollView.delegate = self
            self.addSubview(self.scrollViewContainer)
            
            self.scrollViewContainer.mask = self.scrollMaskContainer
            
            let tapRecognizer = UITapGestureRecognizer(target: self, action: #selector(self.tapGesture(_:)))
            self.addGestureRecognizer(tapRecognizer)
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
        
        @objc private func tapGesture(_ recognizer: UITapGestureRecognizer) {
            if case .ended = recognizer.state {
                self.expand(transition: Transition(animation: .curve(duration: 0.4, curve: .spring)))
            }
        }
        
        func scrollViewDidScroll(_ scrollView: UIScrollView) {
            if !self.ignoreScrolling {
                self.updateScrolling(transition: .immediate)
            }
        }
        
        func expand(transition: Transition) {
            self.ignoreScrolling = true
            transition.setBounds(view: self.scrollView, bounds: CGRect(origin: CGPoint(x: 0.0, y: max(0.0, self.scrollView.contentSize.height - self.scrollView.bounds.height)), size: self.scrollView.bounds.size))
            self.ignoreScrolling = false
            
            self.updateScrolling(transition: transition)
        }
        
        func collapse(transition: Transition) {
            self.ignoreScrolling = true
            transition.setBounds(view: self.scrollView, bounds: CGRect(origin: CGPoint(), size: self.scrollView.bounds.size))
            self.ignoreScrolling = false
            
            self.updateScrolling(transition: transition)
        }
        
        private func updateScrolling(transition: Transition) {
            guard let component = self.component, let itemLayout = self.itemLayout else {
                return
            }
            
            var edgeDistance = self.scrollView.contentSize.height - self.scrollView.bounds.maxY
            edgeDistance = max(0.0, min(7.0, edgeDistance))
            
            let edgeDistanceFraction = edgeDistance / 7.0
            transition.setAlpha(view: self.scrollFullMaskView, alpha: 1.0 - edgeDistanceFraction)
            
            let shadowOverflow: CGFloat = 26.0
            let shadowFrame = CGRect(origin: CGPoint(x: 0.0, y:  -self.scrollView.contentOffset.y + itemLayout.containerSize.height - itemLayout.visibleTextHeight - itemLayout.verticalInset - shadowOverflow), size: CGSize(width: itemLayout.containerSize.width, height: itemLayout.visibleTextHeight + itemLayout.verticalInset + shadowOverflow))
            transition.setFrame(layer: self.shadowGradientLayer, frame: shadowFrame)
            transition.setFrame(layer: self.shadowPlainLayer, frame: CGRect(origin: CGPoint(x: shadowFrame.minX, y: shadowFrame.maxY), size: CGSize(width: shadowFrame.width, height: self.scrollView.contentSize.height + 1000.0)))
            
            let expandDistance: CGFloat = 50.0
            var expandFraction: CGFloat = self.scrollView.contentOffset.y / expandDistance
            expandFraction = max(0.0, min(1.0, expandFraction))
            if self.scrollView.contentSize.height < self.scrollView.bounds.height + expandDistance {
                expandFraction = 0.0
            }
            
            let isExpanded = expandFraction > 0.0
            
            if component.externalState.isExpanded != isExpanded {
                component.externalState.isExpanded = isExpanded
                
                if !self.ignoreExternalState {
                    self.state?.updated(transition: transition.withUserData(TransitionHint(kind: .isExpandedUpdated)))
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
                    maximumNumberOfLines: 0
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
            
            self.itemLayout = ItemLayout(
                containerSize: availableSize,
                visibleTextHeight: visibleTextHeight,
                verticalInset: verticalInset
            )
            
            self.ignoreScrolling = true
            
            if self.scrollView.contentSize != scrollContentSize {
                self.scrollView.contentSize = scrollContentSize
            }
            transition.setFrame(view: self.scrollView, frame: CGRect(origin: CGPoint(x: 0.0, y: 0.0), size: CGSize(width: availableSize.width, height: availableSize.height)))
            transition.setFrame(view: self.scrollViewContainer, frame: CGRect(origin: CGPoint(x: 0.0, y: 0.0), size: CGSize(width: availableSize.width, height: availableSize.height)))
            
            if self.shadowGradientLayer.colors == nil {
                var locations: [NSNumber] = []
                var colors: [CGColor] = []
                let numStops = 10
                let baseAlpha: CGFloat = 0.3
                for i in 0 ..< numStops {
                    let step = 1.0 - CGFloat(i) / CGFloat(numStops - 1)
                    locations.append((1.0 - step) as NSNumber)
                    let alphaStep: CGFloat = pow(step, 1.2)
                    colors.append(UIColor.black.withAlphaComponent(alphaStep * baseAlpha).cgColor)
                }
                
                self.shadowGradientLayer.startPoint = CGPoint(x: 0.0, y: 1.0)
                self.shadowGradientLayer.endPoint = CGPoint(x: 0.0, y: 0.0)
                
                self.shadowGradientLayer.locations = locations
                self.shadowGradientLayer.colors = colors
                self.shadowGradientLayer.type = .axial
                
                self.shadowPlainLayer.backgroundColor = UIColor(white: 0.0, alpha: baseAlpha).cgColor
            }
            
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
