import Foundation
import UIKit
import Display
import AsyncDisplayKit
import ComponentFlow
import SwiftSignalKit
import ViewControllerComponent
import ComponentDisplayAdapters
import TelegramPresentationData
import AccountContext

private let handleWidth: CGFloat = 14.0
private let scrubberHeight: CGFloat = 39.0
private let borderHeight: CGFloat = 1.0 + UIScreenPixel
private let frameWidth: CGFloat = 24.0
private let minumumDuration: CGFloat = 1.0

final class VideoScrubberComponent: Component {
    typealias EnvironmentType = Empty
    
    let context: AccountContext
    let duration: Double
    let startPosition: Double
    let endPosition: Double
    let position: Double
    let frames: [UIImage]
    let framesUpdateTimestamp: Double
    let startPositionUpdated: (Double, Bool) -> Void
    let endPositionUpdated: (Double, Bool) -> Void
    let positionUpdated: (Double, Bool) -> Void
    
    init(
        context: AccountContext,
        duration: Double,
        startPosition: Double,
        endPosition: Double,
        position: Double,
        frames: [UIImage],
        framesUpdateTimestamp: Double,
        startPositionUpdated: @escaping (Double, Bool) -> Void,
        endPositionUpdated: @escaping (Double, Bool) -> Void,
        positionUpdated: @escaping (Double, Bool) -> Void
    ) {
        self.context = context
        self.duration = duration
        self.startPosition = startPosition
        self.endPosition = endPosition
        self.position = position
        self.frames = frames
        self.framesUpdateTimestamp = framesUpdateTimestamp
        self.startPositionUpdated = startPositionUpdated
        self.endPositionUpdated = endPositionUpdated
        self.positionUpdated = positionUpdated
    }
    
    static func ==(lhs: VideoScrubberComponent, rhs: VideoScrubberComponent) -> Bool {
        if lhs.context !== rhs.context {
            return false
        }
        if lhs.duration != rhs.duration {
            return false
        }
        if lhs.startPosition != rhs.startPosition {
            return false
        }
        if lhs.endPosition != rhs.endPosition {
            return false
        }
        if lhs.position != rhs.position {
            return false
        }
        if lhs.framesUpdateTimestamp != rhs.framesUpdateTimestamp {
            return false
        }
        return true
    }
    
    final class View: UIView, UITextFieldDelegate {
        private let leftHandleView = UIImageView()
        private let rightHandleView = UIImageView()
        private let borderView = UIImageView()
        private let cursorView = UIImageView()
        
        private let transparentFramesContainer = UIView()
        private let opaqueFramesContainer = UIView()
        
        private var transparentFrameLayers: [CALayer] = []
        private var opaqueFrameLayers: [CALayer] = []
        
        private var component: VideoScrubberComponent?
        private weak var state: EmptyComponentState?
        
        override init(frame: CGRect) {
            super.init(frame: frame)
            
            self.disablesInteractiveModalDismiss = true
            self.disablesInteractiveKeyboardGestureRecognizer = true
            
            let handleImage = generateImage(CGSize(width: handleWidth, height: scrubberHeight), rotatedContext: { size, context in
                context.clear(CGRect(origin: .zero, size: size))
                context.setFillColor(UIColor.white.cgColor)
                
                let path = UIBezierPath(roundedRect: CGRect(origin: .zero, size: CGSize(width: size.width * 2.0, height: size.height)), cornerRadius: 9.0)
                context.addPath(path.cgPath)
                context.fillPath()
                
                context.setBlendMode(.clear)
                let innerPath = UIBezierPath(roundedRect: CGRect(origin: CGPoint(x: handleWidth - 3.0, y: borderHeight), size: CGSize(width: handleWidth, height: size.height - borderHeight * 2.0)), cornerRadius: 2.0)
                context.addPath(innerPath.cgPath)
                context.fillPath()
                
                let holeSize = CGSize(width: 2.0, height: 11.0)
                let holePath = UIBezierPath(roundedRect: CGRect(origin: CGPoint(x: 5.0 - UIScreenPixel, y: (size.height - holeSize.height) / 2.0), size: holeSize), cornerRadius: holeSize.width / 2.0)
                context.addPath(holePath.cgPath)
                context.fillPath()
            })?.withRenderingMode(.alwaysTemplate)
            
            self.leftHandleView.image = handleImage
            self.leftHandleView.isUserInteractionEnabled = true
            self.leftHandleView.tintColor = .white
            
            self.rightHandleView.image = handleImage
            self.rightHandleView.transform = CGAffineTransform(scaleX: -1.0, y: 1.0)
            self.rightHandleView.isUserInteractionEnabled = true
            self.rightHandleView.tintColor = .white
            
            self.borderView.image = generateImage(CGSize(width: 1.0, height: scrubberHeight), rotatedContext: { size, context in
                context.clear(CGRect(origin: .zero, size: size))
                context.setFillColor(UIColor.white.cgColor)
                context.fill(CGRect(origin: .zero, size: CGSize(width: size.width, height: borderHeight)))
                context.fill(CGRect(origin: CGPoint(x: 0.0, y: size.height - borderHeight), size: CGSize(width: size.width, height: scrubberHeight)))
            })?.withRenderingMode(.alwaysTemplate)
            self.borderView.tintColor = .white
            
            self.transparentFramesContainer.alpha = 0.5
            self.transparentFramesContainer.clipsToBounds = true
            self.transparentFramesContainer.layer.cornerRadius = 9.0
            
            self.opaqueFramesContainer.clipsToBounds = true
            self.opaqueFramesContainer.layer.cornerRadius = 9.0
            
            self.addSubview(self.transparentFramesContainer)
            self.addSubview(self.opaqueFramesContainer)
            self.addSubview(self.leftHandleView)
            self.addSubview(self.rightHandleView)
            self.addSubview(self.borderView)
            self.addSubview(self.cursorView)
            
            self.leftHandleView.addGestureRecognizer(UIPanGestureRecognizer(target: self, action: #selector(self.handleLeftHandlePan(_:))))
            self.rightHandleView.addGestureRecognizer(UIPanGestureRecognizer(target: self, action: #selector(self.handleRightHandlePan(_:))))
            //self.rightHandleView.addGestureRecognizer(UIPanGestureRecognizer(target: self, action: #selector(self.handlePositionHandlePan(_:))))
        }
        
        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }
        
        private var isPanningHandle = false
        @objc private func handleLeftHandlePan(_ gestureRecognizer: UIPanGestureRecognizer) {
            guard let component = self.component else {
                return
            }
            let location = gestureRecognizer.location(in: self)
            let start = handleWidth / 2.0
            let end = self.frame.width - handleWidth
            let length = end - start
            let fraction = (location.x - start) / length
            var value = max(0.0, component.duration * fraction)
            if value > component.endPosition - minumumDuration {
                value = max(0.0, component.endPosition - minumumDuration)
            }
            
            var transition: Transition = .immediate
            switch gestureRecognizer.state {
            case .began, .changed:
                self.isPanningHandle = true
                component.startPositionUpdated(value, false)
                if case .began = gestureRecognizer.state {
                    transition = .easeInOut(duration: 0.25)
                }
            case .ended, .cancelled:
                self.isPanningHandle = false
                component.startPositionUpdated(value, true)
                transition = .easeInOut(duration: 0.25)
            default:
                break
            }
            self.state?.updated(transition: transition)
        }
        
        @objc private func handleRightHandlePan(_ gestureRecognizer: UIPanGestureRecognizer) {
            guard let component = self.component else {
                return
            }
            let location = gestureRecognizer.location(in: self)
            let start = handleWidth / 2.0
            let end = self.frame.width - handleWidth
            let length = end - start
            let fraction = (location.x - start) / length
            var value = min(component.duration, component.duration * fraction)
            if value < component.startPosition + minumumDuration {
                value = min(component.duration, component.startPosition + minumumDuration)
            }
            
            var transition: Transition = .immediate
            switch gestureRecognizer.state {
            case .began, .changed:
                self.isPanningHandle = true
                component.endPositionUpdated(value, false)
                if case .began = gestureRecognizer.state {
                    transition = .easeInOut(duration: 0.25)
                }
            case .ended, .cancelled:
                self.isPanningHandle = false
                component.endPositionUpdated(value, true)
                transition = .easeInOut(duration: 0.25)
            default:
                break
            }
            self.state?.updated(transition: transition)
        }
                
        func update(component: VideoScrubberComponent, availableSize: CGSize, state: EmptyComponentState, environment: Environment<EnvironmentType>, transition: Transition) -> CGSize {
            let previousFramesUpdateTimestamp = self.component?.framesUpdateTimestamp
            self.component = component
            self.state = state
            
            let scrubberSize = CGSize(width: availableSize.width, height: scrubberHeight)
            let bounds = CGRect(origin: .zero, size: scrubberSize)
            
            if component.framesUpdateTimestamp != previousFramesUpdateTimestamp {
                for i in 0 ..< component.frames.count {
                    let transparentFrameLayer: CALayer
                    let opaqueFrameLayer: CALayer
                    if i >= self.transparentFrameLayers.count {
                        transparentFrameLayer = SimpleLayer()
                        transparentFrameLayer.masksToBounds = true
                        transparentFrameLayer.contentsGravity = .resizeAspectFill
                        self.transparentFramesContainer.layer.addSublayer(transparentFrameLayer)
                        self.transparentFrameLayers.append(transparentFrameLayer)
                        opaqueFrameLayer = SimpleLayer()
                        opaqueFrameLayer.masksToBounds = true
                        opaqueFrameLayer.contentsGravity = .resizeAspectFill
                        self.opaqueFramesContainer.layer.addSublayer(opaqueFrameLayer)
                        self.opaqueFrameLayers.append(opaqueFrameLayer)
                    } else {
                        transparentFrameLayer = self.transparentFrameLayers[i]
                        opaqueFrameLayer = self.opaqueFrameLayers[i]
                    }
                    transparentFrameLayer.contents = component.frames[i].cgImage
                    if let contents = opaqueFrameLayer.contents, (contents as! CGImage) !== component.frames[i].cgImage, opaqueFrameLayer.animation(forKey: "contents") == nil {
                        opaqueFrameLayer.contents = component.frames[i].cgImage
                        opaqueFrameLayer.animate(from: contents as AnyObject, to: component.frames[i].cgImage! as AnyObject, keyPath: "contents", timingFunction: CAMediaTimingFunctionName.linear.rawValue, duration: 0.2)
                    } else {
                        opaqueFrameLayer.contents = component.frames[i].cgImage
                    }
                }
            }
            
            let trimColor = self.isPanningHandle ? UIColor(rgb: 0xf8d74a) : .white
            transition.setTintColor(view: self.leftHandleView, color: trimColor)
            transition.setTintColor(view: self.rightHandleView, color: trimColor)
            transition.setTintColor(view: self.borderView, color: trimColor)
                        
            let totalWidth = scrubberSize.width - handleWidth
            let leftHandlePositionFraction = component.duration > 0.0 ? component.startPosition / component.duration : 0.0
            let leftHandlePosition = floorToScreenPixels(handleWidth / 2.0 + totalWidth * leftHandlePositionFraction)
            
            let leftHandleFrame = CGRect(origin: CGPoint(x: leftHandlePosition - handleWidth / 2.0, y: 0.0), size: CGSize(width: handleWidth, height: scrubberSize.height))
            transition.setFrame(view: self.leftHandleView, frame: leftHandleFrame)

            let rightHandlePositionFraction = component.duration > 0.0 ? component.endPosition / component.duration : 1.0
            let rightHandlePosition = floorToScreenPixels(handleWidth / 2.0 + totalWidth * rightHandlePositionFraction)
            
            let rightHandleFrame = CGRect(origin: CGPoint(x: max(leftHandleFrame.maxX, rightHandlePosition - handleWidth / 2.0), y: 0.0), size: CGSize(width: handleWidth, height: scrubberSize.height))
            transition.setFrame(view: self.rightHandleView, frame: rightHandleFrame)
            
            let borderFrame = CGRect(origin: CGPoint(x: leftHandleFrame.maxX, y: 0.0), size: CGSize(width: rightHandleFrame.minX - leftHandleFrame.maxX, height: scrubberSize.height))
            transition.setFrame(view: self.borderView, frame: borderFrame)
            
            let handleInset: CGFloat = 7.0
            transition.setFrame(view: self.transparentFramesContainer, frame: bounds)
            transition.setFrame(view: self.opaqueFramesContainer, frame: CGRect(origin: CGPoint(x: leftHandleFrame.maxX - handleInset, y: 0.0), size: CGSize(width: rightHandleFrame.minX - leftHandleFrame.maxX + handleInset * 2.0, height: bounds.height)))
            transition.setBounds(view: self.opaqueFramesContainer, bounds: CGRect(origin: CGPoint(x: leftHandleFrame.maxX - handleInset, y: 0.0), size: CGSize(width: rightHandleFrame.minX - leftHandleFrame.maxX + handleInset * 2.0, height: bounds.height)))
            
            var frameAspectRatio = 0.66
            if let image = component.frames.first, image.size.height > 0.0 {
                frameAspectRatio = max(0.66, image.size.width / image.size.height)
            }
            let frameSize = CGSize(width: 39.0 * frameAspectRatio, height: 39.0)
            var frameOffset: CGFloat = 0.0
            for i in 0 ..< component.frames.count {
                if i < self.transparentFrameLayers.count {
                    let transparentFrameLayer = self.transparentFrameLayers[i]
                    let opaqueFrameLayer = self.opaqueFrameLayers[i]
                    let frame = CGRect(origin: CGPoint(x: frameOffset, y: 0.0), size: frameSize)
                    transparentFrameLayer.frame = frame
                    opaqueFrameLayer.frame = frame
                }
                frameOffset += frameSize.width
            }
            
            return scrubberSize
        }
    }

    public func makeView() -> View {
        return View(frame: CGRect())
    }
    
    public func update(view: View, availableSize: CGSize, state: State, environment: Environment<EnvironmentType>, transition: Transition) -> CGSize {
        return view.update(component: self, availableSize: availableSize, state: state, environment: environment, transition: transition)
    }
}
