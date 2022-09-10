import Foundation
import UIKit
import ComponentFlow
import Display
import ComponentDisplayAdapters

public final class BlurredBackgroundComponent: Component {
    public let color: UIColor
    public let tintContainerView: UIView?

    public init(
        color: UIColor,
        tintContainerView: UIView? = nil
    ) {
        self.color = color
        self.tintContainerView = tintContainerView
    }
    
    public static func ==(lhs: BlurredBackgroundComponent, rhs: BlurredBackgroundComponent) -> Bool {
        if lhs.color != rhs.color {
            return false
        }
        if lhs.tintContainerView !== rhs.tintContainerView {
            return false
        }
        return true
    }
    
    public final class View: BlurredBackgroundView {
        private var tintContainerView: UIView?
        private var vibrancyEffectView: UIVisualEffectView?
        
        public func update(component: BlurredBackgroundComponent, availableSize: CGSize, transition: Transition) -> CGSize {
            /*if self.tintContainerView !== component.tintContainerView {
                if let tintContainerView = self.tintContainerView {
                    self.tintContainerView = nil
                    if tintContainerView.superview === self {
                        tintContainerView.removeFromSuperview()
                    }
                }
                
                self.tintContainerView = component.tintContainerView
                
                if let tintContainerView = self.tintContainerView {
                    let vibrancyEffectView: UIVisualEffectView
                    if let current = self.vibrancyEffectView {
                        vibrancyEffectView = current
                    } else {
                        let blurEffect = UIBlurEffect(style: .extraLight)
                        let vibrancyEffect = UIVibrancyEffect(blurEffect: blurEffect)
                        vibrancyEffectView = UIVisualEffectView(effect: vibrancyEffect)
                        self.vibrancyEffectView = vibrancyEffectView
                        self.addSubview(vibrancyEffectView)
                    }
                    tintContainerView.backgroundColor = .white
                    vibrancyEffectView.contentView.addSubview(tintContainerView)
                } else {
                    if let vibrancyEffectView = self.vibrancyEffectView {
                        self.vibrancyEffectView = nil
                        vibrancyEffectView.removeFromSuperview()
                    }
                }
            }*/
            
            self.updateColor(color: component.color, transition: transition.containedViewLayoutTransition)
            
            /*if let _ = self.viewWithTag(123) {
            } else {
                let blurEffect = UIBlurEffect(style: .extraLight)
                
                
                /*let segmentedControl = UISegmentedControl(items: ["First Item", "Second Item"])
                segmentedControl.sizeToFit()
                segmentedControl.center = CGPoint(x: 250.0, y: 250.0)*/
                let testView = UIView(frame: CGRect(origin: CGPoint(x: 50.0, y: 100.0), size: CGSize(width: 250.0, height: 50.0)))
                testView.backgroundColor = .white
                
                let testView2 = UILabel()
                testView2.text = "Test 13245"
                testView2.font = Font.semibold(17.0)
                testView2.textColor = .black
                testView2.sizeToFit()
                
                testView2.center = CGPoint(x: 250.0 - testView.frame.minX, y: 490.0 - testView.frame.minY)

                let vibrancyEffect = UIVibrancyEffect(blurEffect: blurEffect)
                let vibrancyEffectView = UIVisualEffectView(effect: vibrancyEffect)
                //vibrancyEffectView.frame = CGRect(origin: CGPoint(), size: CGSize(width: 400.0, height: 300.0))
                vibrancyEffectView.tag = 123

                vibrancyEffectView.contentView.addSubview(testView)
                testView.addSubview(testView2)
                //vibrancyEffectView.contentView.addSubview(testView2)
                
                self.addSubview(vibrancyEffectView)
                
                /*let view = UIView()
                view.tag = 123
                view.layer.compositingFilter = "sourceOverCompositing"
                view.backgroundColor = .white
                view.frame = CGRect(origin: CGPoint(), size: CGSize(width: 100.0, height: 200.0))
                self.addSubview(view)*/
            }
            
            if let view = self.viewWithTag(123) {
                view.frame = CGRect(origin: CGPoint(), size: availableSize)
            }*/
            
            self.update(size: availableSize, transition: transition.containedViewLayoutTransition)
            
            if let tintContainerView = self.tintContainerView {
                transition.setFrame(view: tintContainerView, frame: CGRect(origin: CGPoint(), size: availableSize))
            }
            if let vibrancyEffectView = self.vibrancyEffectView {
                transition.setFrame(view: vibrancyEffectView, frame: CGRect(origin: CGPoint(), size: availableSize))
            }

            return availableSize
        }
    }
    
    public func makeView() -> View {
        return View(color: nil, enableBlur: true)
    }
    
    public func update(view: View, availableSize: CGSize, state: EmptyComponentState, environment: Environment<Empty>, transition: Transition) -> CGSize {
        return view.update(component: self, availableSize: availableSize, transition: transition)
    }
}
