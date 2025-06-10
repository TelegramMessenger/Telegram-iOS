import Foundation
import UIKit
import AsyncDisplayKit
import Display
import SwiftSignalKit
import ComponentFlow
import SemanticStatusNode
import AnimatedTextComponent

public final class AdRemainingProgressComponent: Component {
    public let initialTimestamp: Int32
    public let minDisplayDuration: Int32
    public let maxDisplayDuration: Int32
    public let action: (Bool) -> Void
    
    public init(
        initialTimestamp: Int32,
        minDisplayDuration: Int32,
        maxDisplayDuration: Int32,
        action: @escaping (Bool) -> Void
    ) {
        self.initialTimestamp = initialTimestamp
        self.minDisplayDuration = minDisplayDuration
        self.maxDisplayDuration = maxDisplayDuration
        self.action = action
    }

    public static func ==(lhs: AdRemainingProgressComponent, rhs: AdRemainingProgressComponent) -> Bool {
        if lhs.initialTimestamp != rhs.initialTimestamp {
            return false
        }
        if lhs.minDisplayDuration != rhs.minDisplayDuration {
            return false
        }
        if lhs.maxDisplayDuration != rhs.maxDisplayDuration {
            return false
        }
        return true
    }

    public final class View: HighlightTrackingButton {
        private var component: AdRemainingProgressComponent?
        private weak var componentState: EmptyComponentState?

        private let node: SemanticStatusNode
        private var textComponent = ComponentView<Empty>()
        private var cancelIcon = UIImageView()
        
        private var progress: Double = 1.0
        
        override init(frame: CGRect) {
            self.node = SemanticStatusNode(backgroundNodeColor: .clear, foregroundNodeColor: .white)
            self.node.isUserInteractionEnabled = false
            
            self.cancelIcon.alpha = 0.0
            self.cancelIcon.isUserInteractionEnabled = false
            
            super.init(frame: frame)
            
            self.addSubview(self.node.view)
            self.addSubview(self.cancelIcon)
            
            self.addTarget(self, action: #selector(self.pressed), for: .touchUpInside)
            
            self.highligthedChanged = { [weak self] highlighted in
                if let self {
                    if highlighted {
                        self.layer.removeAnimation(forKey: "opacity")
                        self.alpha = 0.7
                    } else {
                        self.alpha = 1.0
                        self.layer.animateAlpha(from: 7, to: 1.0, duration: 0.2)
                    }
                }
            }
        }

        required init(coder: NSCoder) {
            preconditionFailure()
        }
        
        @objc private func pressed() {
            guard let component = self.component else {
                return
            }
            component.action(self.progress < .ulpOfOne)
        }
        
        override public func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
            return super.hitTest(point, with: event)
        }
        
        var timer: SwiftSignalKit.Timer?

        func update(component: AdRemainingProgressComponent, availableSize: CGSize, state: EmptyComponentState, environment: Environment<Empty>, transition: ComponentTransition) -> CGSize {
            if self.component == nil {
                self.timer = SwiftSignalKit.Timer(timeout: 0.25, repeat: true, completion: { [weak self] progress in
                    guard let self else {
                        return
                    }
                    self.componentState?.updated(transition: .easeInOut(duration: 0.2))
                }, queue: Queue.mainQueue())
                self.timer?.start()
            }
            
            self.component = component
            self.componentState = state
            
            let size = CGSize(width: 24.0, height: 24.0)
            let color = UIColor(rgb: 0x64d2ff)
            
            if self.cancelIcon.image == nil {
                self.cancelIcon.image = generateCancelIcon(color: color)
                self.node.foregroundNodeColor = color
            }
            
            var progress = 0.0
            let currentTimestamp = CFAbsoluteTimeGetCurrent()
            let minTimestamp = Double(component.initialTimestamp + component.minDisplayDuration)
            let initialTimestamp = Double(component.initialTimestamp)
            
            let remaining = min(9, max(1, minTimestamp - currentTimestamp))
            
            var textIsHidden = false
            if currentTimestamp >= initialTimestamp && currentTimestamp <= minTimestamp {
                progress = (minTimestamp - currentTimestamp) / (minTimestamp - initialTimestamp)
            } else {
                progress = 0
                textIsHidden = true
            }
            self.progress = progress
    
            let textSize = self.textComponent.update(
                transition: transition,
                component: AnyComponent(
                    AnimatedTextComponent(
                        font: Font.regular(14.0),
                        color: color,
                        items: [AnimatedTextComponent.Item(id: 0, content: .number(Int(remaining), minDigits: 1))]
                    )
                ),
                environment: {},
                containerSize: size
            )
            
            let iconTransition = ComponentTransition(animation: .curve(duration: 0.25, curve: .spring))
            if let textView = self.textComponent.view {
                if textView.superview == nil {
                    textView.isUserInteractionEnabled = false
                    self.addSubview(textView)
                }
                textView.frame = CGRect(origin: CGPoint(x: (size.width - textSize.width) / 2.0, y: (size.height - textSize.height) / 2.0), size: textSize)
                iconTransition.setAlpha(view: textView, alpha: textIsHidden ? 0.0 : 1.0)
                iconTransition.setAlpha(view: self.cancelIcon, alpha: textIsHidden ? 1.0 : 0.0)
            }
            
            if let icon = self.cancelIcon.image {
                self.cancelIcon.bounds = CGRect(origin: .zero, size: icon.size)
                
                var iconScale = 0.7
                var iconAlpha = 1.0
                var iconPosition = CGPoint(x: size.width / 2.0 + 10.0, y: size.height / 2.0 - 10.0)
                if progress > 0.8 {
                    iconScale = 0.01
                    iconAlpha = 0.0
                } else if progress < .ulpOfOne {
                    iconScale = 1.0
                    iconPosition = CGPoint(x: size.width / 2.0, y: size.height / 2.0)
                }
                iconTransition.setAlpha(view: self.cancelIcon, alpha: iconAlpha)
                iconTransition.setScale(view: self.cancelIcon, scale: iconScale)
                iconTransition.setPosition(view: self.cancelIcon, position: iconPosition)
            }
            
            self.node.frame = CGRect(origin: .zero, size: size)
            self.node.transitionToState(.progress(value: max(0.0, min(1.0, progress)), cancelEnabled: false, appearance: SemanticStatusNodeState.ProgressAppearance(inset: 1.0, lineWidth: 1.0 + UIScreenPixel), animateRotation: false), updateCutout: false)
                        
            return size
        }
    }

    public func makeView() -> View {
        return View(frame: CGRect())
    }

    public func update(view: View, availableSize: CGSize, state: EmptyComponentState, environment: Environment<Empty>, transition: ComponentTransition) -> CGSize {
        return view.update(component: self, availableSize: availableSize, state: state, environment: environment, transition: transition)
    }
}

private func generateCancelIcon(color: UIColor) -> UIImage? {
    return generateImage(CGSize(width: 12.0, height: 12.0), rotatedContext: { size, context in
        let bounds = CGRect(origin: CGPoint(), size: size)
        context.clear(bounds)
        
        let lineWidth = 2.0 - UIScreenPixel
        context.setLineWidth(lineWidth)
        context.setLineCap(.round)
        context.setStrokeColor(color.cgColor)
        
        context.move(to: CGPoint(x: lineWidth / 2.0, y: lineWidth / 2.0))
        context.addLine(to: CGPoint(x: size.width - lineWidth / 2.0, y: size.height - lineWidth / 2.0))
        
        context.strokePath()
        
        context.move(to: CGPoint(x: size.width - lineWidth / 2.0, y: lineWidth / 2.0))
        context.addLine(to: CGPoint(x: lineWidth / 2.0, y: size.height - lineWidth / 2.0))
        
        context.strokePath()
    })
}

