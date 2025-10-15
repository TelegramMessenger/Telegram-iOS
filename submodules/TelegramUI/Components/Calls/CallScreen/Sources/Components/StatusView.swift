import Foundation
import UIKit
import Display
import ComponentFlow
import TelegramPresentationData

private func addRoundedRectPath(context: CGContext, rect: CGRect, radius: CGFloat) {
    context.saveGState()
    context.translateBy(x: rect.minX, y: rect.minY)
    context.scaleBy(x: radius, y: radius)
    let fw = rect.width / radius
    let fh = rect.height / radius
    context.move(to: CGPoint(x: fw, y: fh / 2.0))
    context.addArc(tangent1End: CGPoint(x: fw, y: fh), tangent2End: CGPoint(x: fw/2, y: fh), radius: 1.0)
    context.addArc(tangent1End: CGPoint(x: 0, y: fh), tangent2End: CGPoint(x: 0, y: fh/2), radius: 1)
    context.addArc(tangent1End: CGPoint(x: 0, y: 0), tangent2End: CGPoint(x: fw/2, y: 0), radius: 1)
    context.addArc(tangent1End: CGPoint(x: fw, y: 0), tangent2End: CGPoint(x: fw, y: fh/2), radius: 1)
    context.closePath()
    context.restoreGState()
}

private func stringForDuration(_ duration: Int) -> String {
    let hours = duration / 3600
    let minutes = duration / 60 % 60
    let seconds = duration % 60
    let durationString: String
    if hours > 0 {
        durationString = String(format: "%d:%02d:%02d", hours, minutes, seconds)
    } else {
        durationString = String(format: "%d:%02d", minutes, seconds)
    }
    return durationString
}


private final class AnimatedDotsLayer: SimpleLayer {
    private let dotLayers: [SimpleLayer]
    
    let size: CGSize
    
    override init() {
        self.dotLayers = (0 ..< 3).map { _ in
            SimpleLayer()
        }
        
        let dotSpacing: CGFloat = 1.0
        let dotSize = CGSize(width: 5.0, height: 5.0)
        
        self.size = CGSize(width: CGFloat(self.dotLayers.count) * dotSize.width + CGFloat(self.dotLayers.count - 1) * dotSpacing, height: dotSize.height)
        
        super.init()
        
        let dotImage = UIGraphicsImageRenderer(size: dotSize).image(actions: { context in
            context.cgContext.setFillColor(UIColor.white.cgColor)
            context.cgContext.fillEllipse(in: CGRect(origin: CGPoint(), size: dotSize))
        })
        
        var nextX: CGFloat = 0.0
        for dotLayer in self.dotLayers {
            dotLayer.contents = dotImage.cgImage
            dotLayer.frame = CGRect(origin: CGPoint(x: nextX, y: 0.0), size: dotSize)
            nextX += dotSpacing + dotSize.width
            self.addSublayer(dotLayer)
        }
        
        self.didEnterHierarchy = { [weak self] in
            self?.updateAnimations()
        }
    }
    
    override init(layer: Any) {
        self.dotLayers = []
        self.size = CGSize()
        
        super.init(layer: layer)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func updateAnimations() {
        if self.dotLayers[0].animation(forKey: "dotAnimation") != nil {
            return
        }
        
        let animationDuration: Double = 0.6
        for i in 0 ..< self.dotLayers.count {
            let dotLayer = self.dotLayers[i]
            
            let animation = CABasicAnimation(keyPath: "transform.scale")
            animation.duration = animationDuration
            animation.fromValue = 0.3
            animation.toValue = 1.0
            animation.timingFunction = CAMediaTimingFunction(name: .linear)
            animation.autoreverses = true
            animation.repeatCount = .infinity
            animation.timeOffset = CGFloat(self.dotLayers.count - 1 - i) * animationDuration * 0.33
            
            dotLayer.add(animation, forKey: "dotAnimation")
        }
    }
}

private final class SignalStrengthView: UIView {
    let barViews: [UIImageView]
    
    let size: CGSize
    
    override init(frame: CGRect) {
        self.barViews = (0 ..< 4).map { _ in
            return UIImageView()
        }
        
        let itemWidth: CGFloat = 3.0
        let itemHeight: CGFloat = 12.0
        let itemSpacing: CGFloat = 2.0
        
        self.size = CGSize(width: CGFloat(self.barViews.count) * itemWidth + CGFloat(self.barViews.count - 1) * itemSpacing, height: itemHeight)
        
        super.init(frame: frame)
        
        let itemImage = UIGraphicsImageRenderer(size: CGSize(width: itemWidth, height: itemWidth)).image(actions: { context in
            context.cgContext.setFillColor(UIColor.white.cgColor)
            addRoundedRectPath(context: context.cgContext, rect: CGRect(origin: CGPoint(), size: CGSize(width: itemWidth, height: itemWidth)), radius: 1.0)
            context.cgContext.fillPath()
        }).stretchableImage(withLeftCapWidth: Int(itemWidth * 0.5), topCapHeight: Int(itemWidth * 0.5))
        
        var nextX: CGFloat = 0.0
        
        for i in 0 ..< self.barViews.count {
            let barView = self.barViews[i]
            barView.image = itemImage
            let barHeight = floor(CGFloat(i + 1) * itemHeight / CGFloat(self.barViews.count))
            barView.frame = CGRect(origin: CGPoint(x: nextX, y: itemHeight - barHeight), size: CGSize(width: itemWidth, height: barHeight))
            nextX += itemSpacing + itemWidth
            self.addSubview(barView)
        }
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    func update(value: Double) {
        for i in 0 ..< self.barViews.count {
            if value >= Double(i + 1) / Double(self.barViews.count) {
                self.barViews[i].alpha = 1.0
            } else {
                self.barViews[i].alpha = 0.5
            }
        }
    }
}

final class StatusView: UIView {
    private struct LayoutState: Equatable {
        var strings: PresentationStrings
        var state: State
        var size: CGSize
        
        init(strings: PresentationStrings, state: State, size: CGSize) {
            self.strings = strings
            self.state = state
            self.size = size
        }
        
        static func ==(lhs: LayoutState, rhs: LayoutState) -> Bool {
            if lhs.strings !== rhs.strings {
                return false
            }
            if lhs.state != rhs.state {
                return false
            }
            if lhs.size != rhs.size {
                return false
            }
            return true
        }
    }
    
    enum WaitingState {
        case requesting
        case ringing
        case connecting
        case reconnecting
    }
    
    struct ActiveState: Equatable {
        var startTimestamp: Double
        var signalStrength: Double
        
        init(startTimestamp: Double, signalStrength: Double) {
            self.startTimestamp = startTimestamp
            self.signalStrength = signalStrength
        }
    }
    
    struct TerminatedState: Equatable {
        var duration: Double
        
        init(duration: Double) {
            self.duration = duration
        }
    }
    
    enum State: Equatable {
        enum Key: Equatable {
            case waiting(WaitingState)
            case active
            case terminated
        }
        
        case waiting(WaitingState)
        case active(ActiveState)
        case terminated(TerminatedState)
        
        var key: Key {
            switch self {
            case let .waiting(waitingState):
                return .waiting(waitingState)
            case .active:
                return .active
            case .terminated:
                return .terminated
            }
        }
    }
    
    private let textView: TextView
    
    private var dotsLayer: AnimatedDotsLayer?
    private var signalStrengthView: SignalStrengthView?
    
    private var activeDurationTimer: Foundation.Timer?
    
    private var layoutState: LayoutState?
    var state: State? {
        return self.layoutState?.state
    }
    
    var requestLayout: (() -> Void)?
    
    override init(frame: CGRect) {
        self.textView = TextView()
        
        super.init(frame: frame)
        
        self.addSubview(self.textView)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    deinit {
        self.activeDurationTimer?.invalidate()
    }
    
    func update(strings: PresentationStrings, state: State, transition: ComponentTransition) -> CGSize {
        if let layoutState = self.layoutState, layoutState.strings === strings, layoutState.state == state {
            return layoutState.size
        }
        let size = self.updateInternal(strings: strings, state: state, transition: transition)
        self.layoutState = LayoutState(strings: strings, state: state, size: size)
        
        self.updateActiveDurationTimer()
        
        return size
    }
    
    private func updateActiveDurationTimer() {
        if let layoutState = self.layoutState, case let .active(activeState) = layoutState.state {
            if self.activeDurationTimer == nil {
                let timestamp = Date().timeIntervalSince1970
                let duration = timestamp - activeState.startTimestamp
                let nextTickDelay = ceil(duration) - duration + 0.05
                
                self.activeDurationTimer = Foundation.Timer.scheduledTimer(withTimeInterval: nextTickDelay, repeats: false, block: { [weak self] _ in
                    guard let self else {
                        return
                    }
                    self.activeDurationTimer?.invalidate()
                    self.activeDurationTimer = nil
                    
                    if let layoutState = self.layoutState {
                        let size = self.updateInternal(strings: layoutState.strings, state: layoutState.state, transition: .immediate)
                        if layoutState.size != size {
                            self.layoutState = nil
                            self.requestLayout?()
                        }
                    }
                    
                    self.updateActiveDurationTimer()
                })
            }
        } else {
            if let activeDurationTimer = self.activeDurationTimer {
                self.activeDurationTimer = nil
                activeDurationTimer.invalidate()
            }
        }
    }
     
    private func updateInternal(strings: PresentationStrings, state: State, transition: ComponentTransition) -> CGSize {
        let textString: String
        var needsDots = false
        var monospacedDigits = false
        var signalStrength: Double?
        switch state {
        case let .waiting(waitingState):
            needsDots = true
            
            switch waitingState {
            case .requesting:
                textString = strings.Call_WaitingStatusRequesting
            case .ringing:
                textString = strings.Call_WaitingStatusRinging
            case .connecting:
                textString = strings.Call_WaitingStatusConnecting
            case .reconnecting:
                textString = strings.Call_WaitingStatusReconnecting
            }
        case let .active(activeState):
            monospacedDigits = true
            
            let timestamp = Date().timeIntervalSince1970
            let duration = timestamp - activeState.startTimestamp
            textString = stringForDuration(Int(duration))
            signalStrength = activeState.signalStrength
        case let .terminated(terminatedState):
            if Int(terminatedState.duration) == 0 {
                textString = " "
            } else {
                textString = stringForDuration(Int(terminatedState.duration))
            }
        }
        
        var contentSize = CGSize()
        
        if let signalStrength {
            let signalStrengthView: SignalStrengthView
            if let current = self.signalStrengthView {
                signalStrengthView = current
            } else {
                signalStrengthView = SignalStrengthView(frame: CGRect())
                self.signalStrengthView = signalStrengthView
                self.addSubview(signalStrengthView)
            }
            signalStrengthView.update(value: signalStrength)
            contentSize.width += signalStrengthView.size.width + 7.0
        } else {
            if let signalStrengthView = self.signalStrengthView {
                self.signalStrengthView = nil
                signalStrengthView.removeFromSuperview()
            }
        }
        
        let textSize = self.textView.update(string: textString, fontSize: 16.0, fontWeight: 0.0, monospacedDigits: monospacedDigits, color: .white, constrainedWidth: 250.0, transition: .immediate)
        let textFrame = CGRect(origin: CGPoint(x: contentSize.width, y: 0.0), size: textSize)
        if self.textView.bounds.isEmpty {
            self.textView.frame = textFrame
        } else {
            transition.setPosition(view: self.textView, position: textFrame.center)
            transition.setBounds(view: self.textView, bounds: CGRect(origin: CGPoint(), size: textFrame.size))
        }
        
        contentSize.width += textSize.width
        contentSize.height = textSize.height
        
        if let signalStrengthView = self.signalStrengthView {
            transition.setFrame(view: signalStrengthView, frame: CGRect(origin: CGPoint(x: 0.0, y: floor((textSize.height - signalStrengthView.size.height) * 0.5)), size: signalStrengthView.size))
        }
        
        if needsDots {
            let dotsLayer: AnimatedDotsLayer
            if let current = self.dotsLayer {
                dotsLayer = current
            } else {
                dotsLayer = AnimatedDotsLayer()
                self.dotsLayer = dotsLayer
                self.layer.addSublayer(dotsLayer)
                transition.animateAlpha(layer: dotsLayer, from: 0.0, to: 1.0)
            }
            
            let dotsSpacing: CGFloat = 6.0
            
            let dotsFrame = CGRect(origin: CGPoint(x: textSize.width + dotsSpacing, y: 1.0 + floor((textSize.height - dotsLayer.size.height) * 0.5)), size: dotsLayer.size)
            transition.setFrame(layer: dotsLayer, frame: dotsFrame)
            contentSize.width += dotsSpacing + dotsFrame.width
        } else if let dotsLayer = self.dotsLayer {
            self.dotsLayer = nil
            transition.setAlpha(layer: dotsLayer, alpha: 0.0, completion: { [weak dotsLayer] _ in
                dotsLayer?.removeFromSuperlayer()
            })
        }
        
        return contentSize
    }
}
