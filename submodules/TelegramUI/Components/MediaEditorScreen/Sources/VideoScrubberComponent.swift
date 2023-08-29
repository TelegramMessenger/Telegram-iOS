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

private class VideoFrameLayer: SimpleShapeLayer {
    private let stripeLayer = SimpleShapeLayer()
    
    override func layoutSublayers() {
        super.layoutSublayers()
        
        if self.stripeLayer.superlayer == nil {
            self.stripeLayer.backgroundColor = UIColor(rgb: 0x000000, alpha: 0.3).cgColor
            self.addSublayer(self.stripeLayer)
        }
        self.stripeLayer.frame = CGRect(x: self.bounds.width - UIScreenPixel, y: 0.0, width: UIScreenPixel, height: self.bounds.height)
    }
}

private final class HandleView: UIImageView {
    var hitTestSlop = UIEdgeInsets()
    
    override func point(inside point: CGPoint, with event: UIEvent?) -> Bool {
        return self.bounds.inset(by: self.hitTestSlop).contains(point)
    }
}

final class VideoScrubberComponent: Component {
    typealias EnvironmentType = Empty
    
    let context: AccountContext
    let generationTimestamp: Double
    let duration: Double
    let startPosition: Double
    let endPosition: Double
    let position: Double
    let maxDuration: Double
    let isPlaying: Bool
    let frames: [UIImage]
    let framesUpdateTimestamp: Double
    let trimUpdated: (Double, Double, Bool, Bool) -> Void
    let positionUpdated: (Double, Bool) -> Void
    
    init(
        context: AccountContext,
        generationTimestamp: Double,
        duration: Double,
        startPosition: Double,
        endPosition: Double,
        position: Double,
        maxDuration: Double,
        isPlaying: Bool,
        frames: [UIImage],
        framesUpdateTimestamp: Double,
        trimUpdated: @escaping (Double, Double, Bool, Bool) -> Void,
        positionUpdated: @escaping (Double, Bool) -> Void
    ) {
        self.context = context
        self.generationTimestamp = generationTimestamp
        self.duration = duration
        self.startPosition = startPosition
        self.endPosition = endPosition
        self.position = position
        self.maxDuration = maxDuration
        self.isPlaying = isPlaying
        self.frames = frames
        self.framesUpdateTimestamp = framesUpdateTimestamp
        self.trimUpdated = trimUpdated
        self.positionUpdated = positionUpdated
    }
    
    static func ==(lhs: VideoScrubberComponent, rhs: VideoScrubberComponent) -> Bool {
        if lhs.context !== rhs.context {
            return false
        }
        if lhs.generationTimestamp != rhs.generationTimestamp {
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
        if lhs.maxDuration != rhs.maxDuration {
            return false
        }
        if lhs.isPlaying != rhs.isPlaying {
            return false
        }
        if lhs.framesUpdateTimestamp != rhs.framesUpdateTimestamp {
            return false
        }
        return true
    }
    
    final class View: UIView, UITextFieldDelegate {
        private let leftHandleView = HandleView()
        private let rightHandleView = HandleView()
        private let borderView = UIImageView()
        private let zoneView = HandleView()
        private let cursorView = HandleView()
        
        private let transparentFramesContainer = UIView()
        private let opaqueFramesContainer = UIView()
        
        private var transparentFrameLayers: [VideoFrameLayer] = []
        private var opaqueFrameLayers: [VideoFrameLayer] = []
        
        private var component: VideoScrubberComponent?
        private weak var state: EmptyComponentState?
        private var scrubberSize: CGSize?
        
        private var isPanningTrimHandle = false
        private var isPanningPositionHandle = false
        
        private var displayLink: SharedDisplayLinkDriver.Link?
        private var positionAnimation: (start: Double, from: Double, to: Double, ended: Bool)?
        
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
                
                context.setBlendMode(.clear)
                let holeSize = CGSize(width: 2.0, height: 11.0)
                let holePath = UIBezierPath(roundedRect: CGRect(origin: CGPoint(x: 5.0 - UIScreenPixel, y: (size.height - holeSize.height) / 2.0), size: holeSize), cornerRadius: holeSize.width / 2.0)
                context.addPath(holePath.cgPath)
                context.fillPath()
            })?.withRenderingMode(.alwaysTemplate)
            
            let positionImage = generateImage(CGSize(width: handleWidth, height: 50.0), rotatedContext: { size, context in
                context.clear(CGRect(origin: .zero, size: size))
                context.setFillColor(UIColor.white.cgColor)
                context.setShadow(offset: .zero, blur: 2.0, color: UIColor(rgb: 0x000000, alpha: 0.55).cgColor)
                
                let path = UIBezierPath(roundedRect: CGRect(origin: CGPoint(x: 6.0, y: 4.0), size: CGSize(width: 2.0, height: 42.0)), cornerRadius: 1.0)
                context.addPath(path.cgPath)
                context.fillPath()
            })
            
            self.zoneView.image = UIImage()
            self.zoneView.isUserInteractionEnabled = true
            self.zoneView.hitTestSlop = UIEdgeInsets(top: -8.0, left: 0.0, bottom: -8.0, right: 0.0)
            
            self.leftHandleView.image = handleImage
            self.leftHandleView.isUserInteractionEnabled = true
            self.leftHandleView.tintColor = .white
            self.leftHandleView.hitTestSlop = UIEdgeInsets(top: -8.0, left: -9.0, bottom: -8.0, right: -9.0)
            
            self.rightHandleView.image = handleImage
            self.rightHandleView.transform = CGAffineTransform(scaleX: -1.0, y: 1.0)
            self.rightHandleView.isUserInteractionEnabled = true
            self.rightHandleView.tintColor = .white
            self.rightHandleView.hitTestSlop = UIEdgeInsets(top: -8.0, left: -9.0, bottom: -8.0, right: -9.0)
            
            self.cursorView.image = positionImage
            self.cursorView.isUserInteractionEnabled = true
            self.cursorView.hitTestSlop = UIEdgeInsets(top: -8.0, left: -9.0, bottom: -8.0, right: -9.0)
            
            self.borderView.image = generateImage(CGSize(width: 1.0, height: scrubberHeight), rotatedContext: { size, context in
                context.clear(CGRect(origin: .zero, size: size))
                context.setFillColor(UIColor.white.cgColor)
                context.fill(CGRect(origin: .zero, size: CGSize(width: size.width, height: borderHeight)))
                context.fill(CGRect(origin: CGPoint(x: 0.0, y: size.height - borderHeight), size: CGSize(width: size.width, height: scrubberHeight)))
            })?.withRenderingMode(.alwaysTemplate)
            self.borderView.tintColor = .white
            self.borderView.isUserInteractionEnabled = false
            
            self.transparentFramesContainer.alpha = 0.5
            self.transparentFramesContainer.clipsToBounds = true
            self.transparentFramesContainer.layer.cornerRadius = 9.0
            
            self.opaqueFramesContainer.clipsToBounds = true
            self.opaqueFramesContainer.layer.cornerRadius = 9.0
            
            self.addSubview(self.transparentFramesContainer)
            self.addSubview(self.opaqueFramesContainer)
            self.addSubview(self.zoneView)
            self.addSubview(self.leftHandleView)
            self.addSubview(self.rightHandleView)
            self.addSubview(self.borderView)
            self.addSubview(self.cursorView)
            
            self.zoneView.addGestureRecognizer(UIPanGestureRecognizer(target: self, action: #selector(self.handleZoneHandlePan(_:))))
            self.leftHandleView.addGestureRecognizer(UIPanGestureRecognizer(target: self, action: #selector(self.handleLeftHandlePan(_:))))
            self.rightHandleView.addGestureRecognizer(UIPanGestureRecognizer(target: self, action: #selector(self.handleRightHandlePan(_:))))
            self.cursorView.addGestureRecognizer(UIPanGestureRecognizer(target: self, action: #selector(self.handlePositionHandlePan(_:))))
            
            self.displayLink = SharedDisplayLinkDriver.shared.add { [weak self] in
                self?.updateCursorPosition()
            }
            self.displayLink?.isPaused = true
        }
        
        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }
        
        deinit {
            self.displayLink?.invalidate()
        }
        
        @objc private func handleZoneHandlePan(_ gestureRecognizer: UIPanGestureRecognizer) {
            guard let component = self.component else {
                return
            }
            let translation = gestureRecognizer.translation(in: self)
            
            let start = handleWidth / 2.0
            let end = self.frame.width - handleWidth / 2.0
            let length = end - start
            
            let delta = translation.x / length
            
            let duration = component.endPosition - component.startPosition
            let startValue = max(0.0, min(component.duration - duration, component.startPosition + delta * component.duration))
            let endValue = startValue + duration
            
            var transition: Transition = .immediate
            switch gestureRecognizer.state {
            case .began, .changed:
                self.isPanningTrimHandle = true
                component.trimUpdated(startValue, endValue, false, false)
                if case .began = gestureRecognizer.state {
                    transition = .easeInOut(duration: 0.25)
                }
            case .ended, .cancelled:
                self.isPanningTrimHandle = false
                component.trimUpdated(startValue, endValue, false, true)
                transition = .easeInOut(duration: 0.25)
            default:
                break
            }
            
            gestureRecognizer.setTranslation(.zero, in: self)
            self.state?.updated(transition: transition)
        }
        
        @objc private func handleLeftHandlePan(_ gestureRecognizer: UIPanGestureRecognizer) {
            guard let component = self.component else {
                return
            }
            let location = gestureRecognizer.location(in: self)
            let start = handleWidth / 2.0
            let end = self.frame.width - handleWidth / 2.0
            let length = end - start
            let fraction = (location.x - start) / length
            
            var startValue = max(0.0, component.duration * fraction)
            if startValue > component.endPosition - minumumDuration {
                startValue = max(0.0, component.endPosition - minumumDuration)
            }
            var endValue = component.endPosition
            if endValue - startValue > component.maxDuration {
                let delta = (endValue - startValue) - component.maxDuration
                endValue -= delta
            }
            
            var transition: Transition = .immediate
            switch gestureRecognizer.state {
            case .began, .changed:
                self.isPanningTrimHandle = true
                component.trimUpdated(startValue, endValue, false, false)
                if case .began = gestureRecognizer.state {
                    transition = .easeInOut(duration: 0.25)
                }
            case .ended, .cancelled:
                self.isPanningTrimHandle = false
                component.trimUpdated(startValue, endValue, false, true)
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
            let end = self.frame.width - handleWidth / 2.0
            let length = end - start
            let fraction = (location.x - start) / length
           
            var endValue = min(component.duration, component.duration * fraction)
            if endValue < component.startPosition + minumumDuration {
                endValue = min(component.duration, component.startPosition + minumumDuration)
            }
            var startValue = component.startPosition
            if endValue - startValue > component.maxDuration {
                let delta = (endValue - startValue) - component.maxDuration
                startValue += delta
            }
            
            var transition: Transition = .immediate
            switch gestureRecognizer.state {
            case .began, .changed:
                self.isPanningTrimHandle = true
                component.trimUpdated(startValue, endValue, true, false)
                if case .began = gestureRecognizer.state {
                    transition = .easeInOut(duration: 0.25)
                }
            case .ended, .cancelled:
                self.isPanningTrimHandle = false
                component.trimUpdated(startValue, endValue, true, true)
                transition = .easeInOut(duration: 0.25)
            default:
                break
            }
            self.state?.updated(transition: transition)
        }
        
        @objc private func handlePositionHandlePan(_ gestureRecognizer: UIPanGestureRecognizer) {
            guard let component = self.component else {
                return
            }
            let location = gestureRecognizer.location(in: self)
            let start = handleWidth
            let end = self.frame.width - handleWidth
            let length = end - start
            let fraction = (location.x - start) / length
            
            let position = max(component.startPosition, min(component.endPosition, component.duration * fraction))
            let transition: Transition = .immediate
            switch gestureRecognizer.state {
            case .began, .changed:
                self.isPanningPositionHandle = true
                component.positionUpdated(position, false)
            case .ended, .cancelled:
                self.isPanningPositionHandle = false
                component.positionUpdated(position, true)
            default:
                break
            }
            self.state?.updated(transition: transition)
        }
        
        private func cursorFrame(size: CGSize, position: Double, duration : Double) -> CGRect {
            let cursorPadding: CGFloat = 8.0
            let cursorPositionFraction = duration > 0.0 ? position / duration : 0.0
            let cursorPosition = floorToScreenPixels(handleWidth + handleWidth / 2.0 - cursorPadding + (size.width - handleWidth * 3.0 + cursorPadding * 2.0) * cursorPositionFraction)
            var cursorFrame = CGRect(origin: CGPoint(x: cursorPosition - handleWidth / 2.0, y: -5.0 - UIScreenPixel), size: CGSize(width: handleWidth, height: 50.0))
            cursorFrame.origin.x = max(self.leftHandleView.frame.maxX - cursorPadding, cursorFrame.origin.x)
            cursorFrame.origin.x = min(self.rightHandleView.frame.minX + cursorPadding, cursorFrame.origin.x)
            return cursorFrame
        }
        
        private func updateCursorPosition() {
            guard let component = self.component, let scrubberSize = self.scrubberSize else {
                return
            }
            let timestamp = CACurrentMediaTime()
            
            let updatedPosition: Double
            if let (start, from, to, _) = self.positionAnimation {
                let duration = to - from
                let fraction = duration > 0.0 ? (timestamp - start) / duration : 0.0
                updatedPosition = max(component.startPosition, min(component.endPosition, from + (to - from) * fraction))
                if fraction >= 1.0 {
                    self.positionAnimation = (start, from, to, true)
                }
            } else {
                let advance = component.isPlaying ? timestamp - component.generationTimestamp : 0.0
                updatedPosition = max(component.startPosition, min(component.endPosition, component.position + advance))
            }
            self.cursorView.frame = cursorFrame(size: scrubberSize, position: updatedPosition, duration: component.duration)
        }
                
        func update(component: VideoScrubberComponent, availableSize: CGSize, state: EmptyComponentState, environment: Environment<EnvironmentType>, transition: Transition) -> CGSize {
            let previousFramesUpdateTimestamp = self.component?.framesUpdateTimestamp
            self.component = component
            self.state = state
            
            let scrubberSize = CGSize(width: availableSize.width, height: scrubberHeight)
            self.scrubberSize = scrubberSize
            
            let bounds = CGRect(origin: .zero, size: scrubberSize)
            
            if component.framesUpdateTimestamp != previousFramesUpdateTimestamp {
                for i in 0 ..< component.frames.count {
                    let transparentFrameLayer: VideoFrameLayer
                    let opaqueFrameLayer: VideoFrameLayer
                    if i >= self.transparentFrameLayers.count {
                        transparentFrameLayer = VideoFrameLayer()
                        transparentFrameLayer.masksToBounds = true
                        transparentFrameLayer.contentsGravity = .resizeAspectFill
                        self.transparentFramesContainer.layer.addSublayer(transparentFrameLayer)
                        self.transparentFrameLayers.append(transparentFrameLayer)
                        opaqueFrameLayer = VideoFrameLayer()
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
            
            let trimColor = self.isPanningTrimHandle ? UIColor(rgb: 0xf8d74a) : .white
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
            
            let zoneFrame = CGRect(x: leftHandleFrame.maxX, y: 0.0, width: rightHandleFrame.minX - leftHandleFrame.maxX, height: scrubberSize.height)
            transition.setFrame(view: self.zoneView, frame: zoneFrame)
                        
            if self.isPanningPositionHandle || !component.isPlaying {
                self.positionAnimation = nil
                self.displayLink?.isPaused = true
                transition.setFrame(view: self.cursorView, frame: cursorFrame(size: scrubberSize, position: component.position, duration: component.duration))
            } else {
                if let (_, _, end, ended) = self.positionAnimation {
                    if ended, component.position >= component.startPosition && component.position < end - 1.0 {
                        self.positionAnimation = (CACurrentMediaTime(), component.position, component.endPosition, false)
                    }
                } else {
                    self.positionAnimation = (CACurrentMediaTime(), component.position, component.endPosition, false)
                }
                self.displayLink?.isPaused = false
                self.updateCursorPosition()
            }
            transition.setAlpha(view: self.cursorView, alpha: self.isPanningTrimHandle ? 0.0 : 1.0)
            
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
        
        override func point(inside point: CGPoint, with event: UIEvent?) -> Bool {
            let hitTestSlop = UIEdgeInsets(top: -8.0, left: -9.0, bottom: -8.0, right: -9.0)
            return self.bounds.inset(by: hitTestSlop).contains(point)
        }
    }

    public func makeView() -> View {
        return View(frame: CGRect())
    }
    
    public func update(view: View, availableSize: CGSize, state: State, environment: Environment<EnvironmentType>, transition: Transition) -> CGSize {
        return view.update(component: self, availableSize: availableSize, state: state, environment: environment, transition: transition)
    }
}
