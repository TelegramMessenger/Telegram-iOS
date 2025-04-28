import Foundation
import UIKit
import Display
import ComponentFlow
import SwiftSignalKit

private let animationSpeed: TimeInterval = 50.0
private let animationDelay: TimeInterval = 2.5
private let spacing: CGFloat = 20.0

public final class MarqueeComponent: Component {
    public static let innerPadding: CGFloat = 16.0
    
    private final class MeasureState: Equatable {
        let attributedText: NSAttributedString
        let availableSize: CGSize
        let size: CGSize
        
        init(attributedText: NSAttributedString, availableSize: CGSize, size: CGSize) {
            self.attributedText = attributedText
            self.availableSize = availableSize
            self.size = size
        }

        static func ==(lhs: MeasureState, rhs: MeasureState) -> Bool {
            if !lhs.attributedText.isEqual(rhs.attributedText) {
                return false
            }
            if lhs.availableSize != rhs.availableSize {
                return false
            }
            if lhs.size != rhs.size {
                return false
            }
            return true
        }
    }
    
    public final class View: UIView {
        private var measureState: MeasureState?
        private let containerLayer = SimpleLayer()
        private let textLayer = SimpleLayer()
        private let duplicateTextLayer = SimpleLayer()
        private let gradientMaskLayer = SimpleGradientLayer()
        private var isAnimating = false
        private var isOverflowing = false
        
        private var component: MarqueeComponent?
                
        override init(frame: CGRect) {
            super.init(frame: frame)
            
            self.clipsToBounds = true
            self.containerLayer.masksToBounds = true
            self.layer.addSublayer(self.containerLayer)
            
            self.containerLayer.addSublayer(self.textLayer)
            self.containerLayer.addSublayer(self.duplicateTextLayer)
        }
        
        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }
                
        public func update(component: MarqueeComponent, availableSize: CGSize) -> CGSize {
            let previousComponent = self.component
            self.component = component
            
            let attributedText = component.attributedText
            if let measureState = self.measureState {
                if measureState.attributedText.isEqual(to: attributedText) && measureState.availableSize == availableSize {
                    return measureState.size
                }
            }
            
            var boundingRect = attributedText.boundingRect(with: CGSize(width: 10000, height: availableSize.height), options: .usesLineFragmentOrigin, context: nil)
            boundingRect.size.width = ceil(boundingRect.size.width)
            boundingRect.size.height = ceil(boundingRect.size.height)
            
            let measureState = MeasureState(attributedText: attributedText, availableSize: availableSize, size: boundingRect.size)
            self.measureState = measureState
            
            self.containerLayer.frame = CGRect(origin: CGPoint(x: 0.0, y: 0.0), size: CGSize(width: measureState.size.width + innerPadding * 2.0, height: measureState.size.height))
            
            let isOverflowing = boundingRect.width > availableSize.width
            
            let renderer = UIGraphicsImageRenderer(bounds: CGRect(origin: CGPoint(), size: measureState.size))
            let image = renderer.image { context in
                UIGraphicsPushContext(context.cgContext)
                measureState.attributedText.draw(at: CGPoint())
                UIGraphicsPopContext()
            }
            
            if isOverflowing {
                self.setupMarqueeTextLayers(textImage: image.cgImage!, textWidth: boundingRect.width, containerWidth: availableSize.width)
                self.setupGradientMask(size: CGSize(width: availableSize.width, height: boundingRect.height))
                self.startAnimation(force: previousComponent?.attributedText != attributedText)
            } else {
                self.stopAnimation()
                self.textLayer.frame = CGRect(origin: CGPoint(x: innerPadding, y: 0.0), size: boundingRect.size)
                self.textLayer.contents = image.cgImage
                self.duplicateTextLayer.frame = .zero
                self.duplicateTextLayer.contents = nil
                self.layer.mask = nil
            }
            
            return CGSize(width: min(measureState.size.width + innerPadding * 2.0, availableSize.width), height: measureState.size.height)
        }
        
        private func setupMarqueeTextLayers(textImage: CGImage, textWidth: CGFloat, containerWidth: CGFloat) {
            self.textLayer.frame = CGRect(x: innerPadding, y: 0, width: textWidth, height: self.containerLayer.bounds.height)
            self.textLayer.contents = textImage
            
            self.duplicateTextLayer.frame = CGRect(x: innerPadding + textWidth + spacing, y: 0, width: textWidth, height: self.containerLayer.bounds.height)
            self.duplicateTextLayer.contents = textImage
            
            self.containerLayer.frame = CGRect(origin: CGPoint(x: 0.0, y: 0.0), size: CGSize(width: textWidth * 2.0 + spacing, height: self.containerLayer.bounds.height))
        }
        
        private func setupGradientMask(size: CGSize) {
            self.gradientMaskLayer.frame = CGRect(origin: .zero, size: size)
            self.gradientMaskLayer.colors = [
                UIColor.clear.cgColor,
                UIColor.clear.cgColor,
                UIColor.black.cgColor,
                UIColor.black.cgColor,
                UIColor.clear.cgColor,
                UIColor.clear.cgColor
            ]
            self.gradientMaskLayer.startPoint = CGPoint(x: 0.0, y: 0.5)
            self.gradientMaskLayer.endPoint = CGPoint(x: 1.0, y: 0.5)
            
            let edgePercentage = innerPadding / size.width
            self.gradientMaskLayer.locations = [
                0.0,
                NSNumber(value: edgePercentage * 0.4),
                NSNumber(value: edgePercentage),
                NSNumber(value: 1.0 - edgePercentage),
                NSNumber(value: 1.0 - edgePercentage * 0.4),
                1.0
            ]
            
            self.layer.mask = self.gradientMaskLayer
        }
        
        private func startAnimation(force: Bool = false) {
            guard !self.isAnimating || force else {
                return
            }
            self.isAnimating = true

            self.containerLayer.removeAllAnimations()
            
            let distance = self.textLayer.frame.width + spacing
            let duration = distance / animationSpeed
            Queue.mainQueue().after(animationDelay, {
                guard self.isAnimating else {
                    return
                }
                self.containerLayer.animateBoundsOriginXAdditive(from: 0.0, to: distance, duration: duration, delay: 0.0, timingFunction: CAMediaTimingFunctionName.linear.rawValue, completion: { finished in
                    if finished {
                        self.isAnimating = false
                        self.startAnimation()
                    }
                })
            })
        }
        
        private func stopAnimation() {
            self.containerLayer.removeAllAnimations()
            self.isAnimating = false
        }
    }
    
    public let attributedText: NSAttributedString
    
    public init(attributedText: NSAttributedString) {
        self.attributedText = attributedText
    }

    public static func ==(lhs: MarqueeComponent, rhs: MarqueeComponent) -> Bool {
        if lhs.attributedText != rhs.attributedText {
            return false
        }
        return true
    }
    
    public func makeView() -> View {
        return View()
    }
    
    public func update(view: View, availableSize: CGSize, state: EmptyComponentState, environment: Environment<Empty>, transition: ComponentTransition) -> CGSize {
        return view.update(component: self, availableSize: availableSize)
    }
}
