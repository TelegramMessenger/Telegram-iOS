import Foundation
import UIKit
import Display
import ComponentFlow
import AppBundle
import BalancedTextComponent
import AnimatedTextComponent
import LottieComponent

final class GalleryRateToastComponent: Component {
    let rate: Double
    let displayTooltip: String?
    
    init(rate: Double, displayTooltip: String?) {
        self.rate = rate
        self.displayTooltip = displayTooltip
    }
    
    static func ==(lhs: GalleryRateToastComponent, rhs: GalleryRateToastComponent) -> Bool {
        if lhs.rate != rhs.rate {
            return false
        }
        if lhs.displayTooltip != rhs.displayTooltip {
            return false
        }
        return true
    }
    
    final class View: UIView {
        private let background = ComponentView<Empty>()
        private let text = ComponentView<Empty>()
        private let arrows = ComponentView<Empty>()
        
        private var tooltipText: ComponentView<Empty>?
        private var tooltipAnimation: ComponentView<Empty>?
        
        private var tooltipIsHidden: Bool = false
        private var tooltipTimer: Foundation.Timer?
        
        private weak var state: EmptyComponentState?
        
        override init(frame: CGRect) {
            super.init(frame: frame)
        }
        
        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }
        
        deinit {
            self.tooltipTimer?.invalidate()
        }
        
        func update(component: GalleryRateToastComponent, availableSize: CGSize, state: EmptyComponentState, environment: Environment<Empty>, transition: ComponentTransition) -> CGSize {
            self.state = state
            
            let insets = UIEdgeInsets(top: 5.0, left: 11.0, bottom: 5.0, right: 16.0)
            let spacing: CGFloat = 5.0
            
            var rateString = String(format: "%.1f", component.rate)
            if rateString.hasSuffix(".0") {
                rateString = rateString.replacingOccurrences(of: ".0", with: "")
            }
            
            var textItems: [AnimatedTextComponent.Item] = []
            if let dotRange = rateString.range(of: ".") {
                textItems.append(AnimatedTextComponent.Item(id: AnyHashable("pre"), content: .text(String(rateString[rateString.startIndex ..< dotRange.lowerBound]))))
                textItems.append(AnimatedTextComponent.Item(id: AnyHashable("dot"), content: .text(".")))
                textItems.append(AnimatedTextComponent.Item(id: AnyHashable("post"), content: .text(String(rateString[dotRange.upperBound...]))))
            } else {
                textItems.append(AnimatedTextComponent.Item(id: AnyHashable("pre"), content: .text(rateString)))
            }
            textItems.append(AnimatedTextComponent.Item(id: AnyHashable("x"), content: .text("x")))
            
            let textSize = self.text.update(
                transition: transition,
                component: AnyComponent(AnimatedTextComponent(
                    font: Font.with(size: 17.0, design: .round, weight: .semibold, traits: [.monospacedNumbers]),
                    color: .white,
                    items: textItems
                )),
                environment: {},
                containerSize: CGSize(width: 100.0, height: 100.0)
            )
            
            var speedFraction = (component.rate - 1.0) / (2.5 - 1.0)
            speedFraction = max(0.0, min(1.0, speedFraction))
            let arrowsSize = self.arrows.update(
                transition: transition,
                component: AnyComponent(GalleryRateToastAnimationComponent(speedFraction: speedFraction)),
                environment: {},
                containerSize: CGSize(width: 200.0, height: 100.0)
            )
            
            let size = CGSize(width: insets.left + insets.right + textSize.width + arrowsSize.width, height: insets.top + insets.bottom + max(textSize.height, arrowsSize.height))
            
            let _ = self.background.update(
                transition: transition,
                component: AnyComponent(FilledRoundedRectangleComponent(
                    color: UIColor(white: 0.0, alpha: 0.5),
                    cornerRadius: .minEdge,
                    smoothCorners: false
                )),
                environment: {},
                containerSize: size
            )
            let backgroundFrame = CGRect(origin: CGPoint(x: floor((availableSize.width - size.width) * 0.5), y: 0.0), size: size)
            if let backgroundView = self.background.view {
                if backgroundView.superview == nil {
                    self.addSubview(backgroundView)
                }
                transition.setFrame(view: backgroundView, frame: backgroundFrame)
            }
            
            let textFrame = CGRect(origin: CGPoint(x: backgroundFrame.minX + insets.left, y: backgroundFrame.minY + floorToScreenPixels((size.height - textSize.height) * 0.5)), size: textSize)
            if let textView = self.text.view {
                if textView.superview == nil {
                    textView.layer.anchorPoint = CGPoint()
                    self.addSubview(textView)
                }
                transition.setPosition(view: textView, position: textFrame.origin)
                textView.bounds = CGRect(origin: CGPoint(), size: textFrame.size)
            }
            
            let arrowsFrame = CGRect(origin: CGPoint(x: textFrame.maxX + spacing, y: backgroundFrame.minY + floorToScreenPixels((size.height - arrowsSize.height) * 0.5)), size: arrowsSize)
            if let arrowsView = self.arrows.view {
                if arrowsView.superview == nil {
                    self.addSubview(arrowsView)
                }
                transition.setFrame(view: arrowsView, frame: arrowsFrame)
            }
            
            if let displayTooltip = component.displayTooltip {
                var tooltipTransition = transition
                
                let tooltipText: ComponentView<Empty>
                if let current = self.tooltipText {
                    tooltipText = current
                } else {
                    tooltipText = ComponentView()
                    self.tooltipText = tooltipText
                    tooltipTransition = tooltipTransition.withAnimation(.none)
                }
                
                let tooltipAnimation: ComponentView<Empty>
                if let current = self.tooltipAnimation {
                    tooltipAnimation = current
                } else {
                    tooltipAnimation = ComponentView()
                    self.tooltipAnimation = tooltipAnimation
                }
                
                let tooltipTextSize = tooltipText.update(
                    transition: .immediate,
                    component: AnyComponent(BalancedTextComponent(
                        text: .plain(NSAttributedString(string: displayTooltip, font: Font.regular(15.0), textColor: UIColor(white: 1.0, alpha: 0.8))),
                        horizontalAlignment: .center,
                        maximumNumberOfLines: 0
                    )),
                    environment: {},
                    containerSize: CGSize(width: availableSize.width - 8.0 * 2.0, height: 1000.0)
                )
                let tooltipTextFrame = CGRect(origin: CGPoint(x: floor((availableSize.width - tooltipTextSize.width) * 0.5), y: backgroundFrame.maxY + 10.0), size: tooltipTextSize)
                if let tooltipTextView = tooltipText.view {
                    if tooltipTextView.superview == nil {
                        self.addSubview(tooltipTextView)
                    }
                    tooltipTransition.setPosition(view: tooltipTextView, position: tooltipTextFrame.center)
                    tooltipTextView.bounds = CGRect(origin: CGPoint(), size: tooltipTextFrame.size)
                    
                    transition.setAlpha(view: tooltipTextView, alpha: self.tooltipIsHidden ? 0.0 : 1.0)
                }
                
                let tooltipAnimationSize = tooltipAnimation.update(
                    transition: .immediate,
                    component: AnyComponent(LottieComponent(
                        content: LottieComponent.AppBundleContent(name: "video_toast_speedup"),
                        color: .white,
                        startingPosition: .begin,
                        loop: false
                    )),
                    environment: {},
                    containerSize: CGSize(width: 60.0, height: 60.0)
                )
                let tooltipAnimationFrame = CGRect(origin: CGPoint(x: floor((availableSize.width - tooltipAnimationSize.width) * 0.5), y: tooltipTextFrame.maxY + 10.0), size: tooltipAnimationSize)
                if let tooltipAnimationView = tooltipAnimation.view {
                    if tooltipAnimationView.superview == nil {
                        self.addSubview(tooltipAnimationView)
                    }
                    tooltipTransition.setFrame(view: tooltipAnimationView, frame: tooltipAnimationFrame)
                    
                    transition.setAlpha(view: tooltipAnimationView, alpha: self.tooltipIsHidden ? 0.0 : 0.8)
                }
            } else {
                if let tooltipText = self.tooltipText {
                    self.tooltipText = nil
                    if let tooltipTextView = tooltipText.view {
                        transition.setAlpha(view: tooltipTextView, alpha: 0.0, completion: { [weak tooltipTextView] _ in
                            tooltipTextView?.removeFromSuperview()
                        })
                    }
                }
                if let tooltipAnimation = self.tooltipAnimation {
                    self.tooltipAnimation = nil
                    if let tooltipAnimationView = tooltipAnimation.view {
                        transition.setAlpha(view: tooltipAnimationView, alpha: 0.0, completion: { [weak tooltipAnimationView] _ in
                            tooltipAnimationView?.removeFromSuperview()
                        })
                    }
                }
            }
            
            if self.tooltipTimer == nil {
                self.tooltipTimer = Foundation.Timer.scheduledTimer(withTimeInterval: 2.0, repeats: false, block: { [weak self] _ in
                    guard let self else {
                        return
                    }
                    self.tooltipIsHidden = true
                    self.state?.updated(transition: .easeInOut(duration: 0.25), isLocal: true)
                })
            }
            
            return CGSize(width: availableSize.width, height: size.height)
        }
    }
    
    func makeView() -> View {
        return View(frame: CGRect())
    }
    
    func update(view: View, availableSize: CGSize, state: EmptyComponentState, environment: Environment<Empty>, transition: ComponentTransition) -> CGSize {
        return view.update(component: self, availableSize: availableSize, state: state, environment: environment, transition: transition)
    }
}
