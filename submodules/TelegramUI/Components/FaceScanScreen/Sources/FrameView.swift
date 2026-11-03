import UIKit
import Display
import ComponentFlow

final class FrameView: UIView {
    enum State: Equatable {
        case viewFinder
        case segments(Set<Int>)
        case success
        case failure
    }
    
    private let viewFinderLayer = ViewFinderLayer()
    private let transitionLayer = TransitionLayer()
    private let segmentsLayer = SegmentsLayer()
    
    private var currentState: State = .viewFinder
    private var scheduledState: State?
    private var isTransitioning = false
    
    private var currentLayout: CGSize?
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        
        self.backgroundColor = .clear
                
        self.transitionLayer.isHidden = true
        self.segmentsLayer.isHidden = true
                
        self.layer.addSublayer(self.viewFinderLayer)
        self.layer.addSublayer(self.transitionLayer)
        self.layer.addSublayer(self.segmentsLayer)
    }
    
    required init?(coder: NSCoder) {
        preconditionFailure()
    }
    
    func update(state: State, intermediateCompletion: (() -> Void)? = nil, transition: ComponentTransition) {
        guard !self.isTransitioning else {
            self.scheduledState = state
            return
        }
        
        let previousState = self.currentState
        self.currentState = state
        
        switch state {
        case .viewFinder:
            switch previousState {
            case .viewFinder:
                break
            case .segments:
                self.isTransitioning = true
                self.segmentsLayer.animateOut(transition: transition) {
                    self.segmentsLayer.isHidden = true
                    self.transitionLayer.isHidden = false
                    self.transitionLayer.animateOut(transition: transition) {
                        self.transitionLayer.isHidden = true
                        self.viewFinderLayer.isHidden = false
                        intermediateCompletion?()
                        self.viewFinderLayer.animateIn(transition: transition) {
                            self.isTransitioning = false
                            self.maybeApplyScheduledState()
                        }
                    }
                }
            case .success:
                break
            case .failure:
                break
            }
        case let .segments(segments):
            switch previousState {
            case .viewFinder:
                self.isTransitioning = true
                self.viewFinderLayer.animateOut(transition: transition) {
                    self.viewFinderLayer.isHidden = true
                    self.transitionLayer.isHidden = false
                    self.transitionLayer.animateIn(transition: transition) {
                        self.transitionLayer.isHidden = true
                        self.segmentsLayer.isHidden = false
                        self.segmentsLayer.animateIn (transition: transition) {
                            self.isTransitioning = false
                            self.maybeApplyScheduledState()
                        }
                    }
                }
            case .segments:
                self.segmentsLayer.update(segments: segments, transition: transition)
            case .success:
                break
            case .failure:
                break
            }
        case .success:
            self.isTransitioning = true
            self.segmentsLayer.animateOut(transition: transition) {
                self.segmentsLayer.isHidden = true
                self.transitionLayer.isHidden = false
                self.transitionLayer.update(color: UIColor(rgb: 0x65c466))
                self.transitionLayer.animateOut(transition: transition) {
                    self.isTransitioning = false
                    self.maybeApplyScheduledState()
                }
            }
        case .failure:
            break
        }
    }
    
    func maybeApplyScheduledState() {
        if !self.isTransitioning, let state = self.scheduledState {
            self.scheduledState = nil
            self.update(state: state, transition: .spring(duration: 0.3))
        }
    }

    func update(size: CGSize) {
        guard self.currentLayout != size else {
            return
        }
        self.currentLayout = size
        
        let bounds = CGRect(origin: .zero, size: size)
        
        //let center = CGPoint(x: size.width / 2.0, y: size.height / 2.0)
        //let viewFinderWidth = bounds.width - 34.0
        //let viewFinderSize = CGSize(width: viewFinderWidth, height: floor(viewFinderWidth * 1.17778))
        
        let viewFinderFrame = bounds.insetBy(dx: 29.0, dy: 29.0) //viewFinderSize.centered(around: center)
        self.viewFinderLayer.update(size: viewFinderFrame.size, closed: self.currentState != .viewFinder, transition: .immediate)
        self.viewFinderLayer.frame = viewFinderFrame
        
        let transitionFrame = bounds.insetBy(dx: 29.0, dy: 29.0) //viewFinderSize.centered(around: center)
        self.transitionLayer.update(size: transitionFrame.size)
        self.transitionLayer.frame = transitionFrame
        
        let segmentsFrame = bounds.insetBy(dx: 15.0, dy: 15.0)
        self.segmentsLayer.update(size: segmentsFrame.size)
        self.segmentsLayer.frame = segmentsFrame
    }
}

private let numberOfSegments = 64
private let lineWidth: CGFloat = 4.0

final class ViewFinderLayer: SimpleLayer {
    private let viewFinderTopLeftLine = SimpleShapeLayer()
    private let viewFinderTopRightLine = SimpleShapeLayer()
    private let viewFinderBottomLeftLine = SimpleShapeLayer()
    private let viewFinderBottomRightLine = SimpleShapeLayer()
    
    private var viewFinderLines: [SimpleShapeLayer] {
        return [
            self.viewFinderTopLeftLine,
            self.viewFinderTopRightLine,
            self.viewFinderBottomLeftLine,
            self.viewFinderBottomRightLine
        ]
    }
    
    override init() {
        super.init()
        
        for line in self.viewFinderLines {
            line.strokeColor = UIColor.white.cgColor
            line.fillColor = UIColor.clear.cgColor
            line.lineWidth = lineWidth
            line.lineCap = .round
            self.addSublayer(line)
        }
    }
    
    required init?(coder: NSCoder) {
        preconditionFailure()
    }
    
    private var validLayout: CGSize?
    
    func animateOut(transition: ComponentTransition, completion: @escaping () -> Void) {
        guard let size = self.validLayout else {
            return
        }
        self.update(size: size, closed: true, transition: transition, completion: completion)
    }
    
    func animateIn(transition: ComponentTransition, completion: @escaping () -> Void) {
        guard let size = self.validLayout else {
            return
        }
        self.update(size: size, closed: false, transition: transition, completion: completion)
    }
    
    func update(size: CGSize, closed: Bool, transition: ComponentTransition, completion: (() -> Void)? = nil) {
        self.validLayout = size
        
        let cornerRadius = closed ? size.width / 2.0 : 18.0
        
        let lineLength = size.width / 2.0 - cornerRadius
        let targetLineLength = 34.0
        let fraction = targetLineLength / lineLength
        let strokeFraction = (1.0 - fraction) / 2.0
        let strokeStart = closed ? 0.0 : strokeFraction
        let strokeEnd = closed ? 1.0 : 1.0 - strokeFraction
            
        let topLeftPath = CGMutablePath()
        topLeftPath.move(to: CGPoint(x: 0.0, y: size.height / 2.0))
        topLeftPath.addArc(center: CGPoint(x: cornerRadius, y: cornerRadius), radius: cornerRadius, startAngle: -.pi, endAngle: -.pi / 2.0, clockwise: false)
        topLeftPath.addLine(to: CGPoint(x: size.width / 2.0, y: 0.0))
        
        transition.setShapeLayerPath(layer: self.viewFinderTopLeftLine, path: topLeftPath, completion: { _ in
            completion?()
        })
        transition.setShapeLayerStrokeStart(layer: self.viewFinderTopLeftLine, strokeStart: strokeStart)
        transition.setShapeLayerStrokeEnd(layer: self.viewFinderTopLeftLine, strokeEnd: strokeEnd)
        
        let topRightPath = CGMutablePath()
        topRightPath.move(to: CGPoint(x: size.width / 2.0, y: 0.0))
        topRightPath.addArc(center: CGPoint(x: size.width - cornerRadius, y: cornerRadius), radius: cornerRadius, startAngle: -.pi / 2.0, endAngle: 0.0, clockwise: false)
        topRightPath.addLine(to: CGPoint(x: size.width, y: size.height / 2.0))
        
        transition.setShapeLayerPath(layer: self.viewFinderTopRightLine, path: topRightPath)
        transition.setShapeLayerStrokeStart(layer: self.viewFinderTopRightLine, strokeStart: strokeStart)
        transition.setShapeLayerStrokeEnd(layer: self.viewFinderTopRightLine, strokeEnd: strokeEnd)
        
        let bottomRightPath = CGMutablePath()
        bottomRightPath.move(to: CGPoint(x: size.width, y: size.height / 2.0))
        bottomRightPath.addArc(center: CGPoint(x: size.width - cornerRadius, y: size.height - cornerRadius), radius: cornerRadius, startAngle: 0.0, endAngle: .pi / 2.0, clockwise: false)
        bottomRightPath.addLine(to: CGPoint(x: size.width / 2.0, y: size.height))

        transition.setShapeLayerPath(layer: self.viewFinderBottomRightLine, path: bottomRightPath)
        transition.setShapeLayerStrokeStart(layer: self.viewFinderBottomRightLine, strokeStart: strokeStart)
        transition.setShapeLayerStrokeEnd(layer: self.viewFinderBottomRightLine, strokeEnd: strokeEnd)
        
        let bottomLeftPath = CGMutablePath()
        bottomLeftPath.move(to: CGPoint(x: size.width / 2.0, y: size.height))
        bottomLeftPath.addArc(center: CGPoint(x: cornerRadius, y: size.height - cornerRadius), radius: cornerRadius, startAngle: .pi / 2.0, endAngle: .pi, clockwise: false)
        bottomLeftPath.addLine(to: CGPoint(x: 0.0, y: size.height / 2.0))
        
        transition.setShapeLayerPath(layer: self.viewFinderBottomLeftLine, path: bottomLeftPath)
        transition.setShapeLayerStrokeStart(layer: self.viewFinderBottomLeftLine, strokeStart: strokeStart)
        transition.setShapeLayerStrokeEnd(layer: self.viewFinderBottomLeftLine, strokeEnd: strokeEnd)
        
        for line in self.viewFinderLines {
            line.frame = CGRect(origin: .zero, size: size)
        }
    }
}



final class TransitionLayer: SimpleLayer {
    private var segmentLayers: [SimpleShapeLayer] = []
    
    func animateIn(transition: ComponentTransition, completion: @escaping () -> Void) {
        var i = 0
        for layer in self.segmentLayers {
            transition.setShapeLayerStrokeStart(layer: layer, strokeStart: 0.499)
            transition.setShapeLayerStrokeEnd(layer: layer, strokeEnd: 0.501, completion: i == 0 ? { _ in completion() } : nil)
            i += 1
        }
    }
    
    func animateOut(transition: ComponentTransition, completion: @escaping () -> Void) {
        var i = 0
        for layer in self.segmentLayers {
            transition.setShapeLayerStrokeStart(layer: layer, strokeStart: 0.0)
            transition.setShapeLayerStrokeEnd(layer: layer, strokeEnd: 1.0, completion: i == 0 ? { _ in completion() } : nil)
            i += 1
        }
    }
        
    func setupIfNeeded(size: CGSize) {
        guard self.segmentLayers.isEmpty else {
            return
        }
        
        let center = CGPoint(x: size.width / 2.0, y: size.height / 2.0)
        let radius: CGFloat = size.width / 2.0
        let gapInDegrees: CGFloat = 0.0
        let gapInRadians: CGFloat = gapInDegrees * .pi / 180.0
        
        let totalGapAngle = CGFloat(numberOfSegments) * gapInRadians
        let totalSegmentAngle = 2 * .pi - totalGapAngle
        let segmentAngle = totalSegmentAngle / CGFloat(numberOfSegments)
        
        for i in 0 ..< numberOfSegments {
            let startAngle = -segmentAngle * 0.5 + (CGFloat(i) * (segmentAngle + gapInRadians)) - .pi / 2
            let endAngle = startAngle + segmentAngle
            
            let path = UIBezierPath(arcCenter: center,
                                    radius: radius,
                                    startAngle: startAngle,
                                    endAngle: endAngle,
                                    clockwise: true)
            
            let stripeLayer = SimpleShapeLayer()
            stripeLayer.path = path.cgPath
            stripeLayer.strokeColor = UIColor(rgb: 0xaaaaaa).cgColor
            stripeLayer.lineWidth = lineWidth
            stripeLayer.fillColor = UIColor.clear.cgColor
            stripeLayer.lineCap = .round
            
            self.addSublayer(stripeLayer)
            self.segmentLayers.append(stripeLayer)
        }
    }
    
    func update(color: UIColor) {
        for layer in self.segmentLayers {
            layer.strokeColor = color.cgColor
        }
    }
    
    func update(size: CGSize) {
        self.setupIfNeeded(size: size)
    }
}

final class SegmentsLayer: SimpleLayer {
    private var segmentLayers: [SimpleShapeLayer] = []
    
    func animateIn(transition: ComponentTransition, completion: @escaping () -> Void) {
        var i = 0
        for layer in self.segmentLayers {
            transition.setShapeLayerStrokeStart(layer: layer, strokeStart: 0.0)
            transition.setShapeLayerStrokeEnd(layer: layer, strokeEnd: 0.32, completion: i == 0 ? { _ in completion() } : nil)
            i += 1
        }
    }
    
    func animateOut(transition: ComponentTransition, completion: @escaping () -> Void) {
        var i = 0
        for layer in self.segmentLayers {
            transition.setShapeLayerStrokeStart(layer: layer, strokeStart: 0.0)
            transition.setShapeLayerStrokeEnd(layer: layer, strokeEnd: 0.001, completion: i == 0 ? { _ in completion() } : nil)
            i += 1
        }
    }
    
    func setupIfNeeded(size: CGSize) {
        guard self.segmentLayers.isEmpty else {
            return
        }
        
        let center = CGPoint(x: size.width / 2.0, y: size.height / 2.0)
        let innerRadius: CGFloat = size.width / 2.0 - 13.0
        let outerRadius: CGFloat = size.width / 2.0 + 13.0
        let gapInDegrees: CGFloat = 2.0
        let gapInRadians: CGFloat = gapInDegrees * .pi / 180.0
        
        let totalGapAngle = CGFloat(numberOfSegments) * gapInRadians
        let totalSegmentAngle = 2 * .pi - totalGapAngle
        let segmentAngle = totalSegmentAngle / CGFloat(numberOfSegments)
        
        for i in 0 ..< numberOfSegments {
            let angle = (CGFloat(i) * (segmentAngle + gapInRadians)) - .pi / 2
            
            let startPoint = CGPoint(
                x: center.x + innerRadius * cos(angle),
                y: center.y + innerRadius * sin(angle)
            )
            
            let endPoint = CGPoint(
                x: center.x + outerRadius * cos(angle),
                y: center.y + outerRadius * sin(angle)
            )
            
            let path = UIBezierPath()
            path.move(to: startPoint)
            path.addLine(to: endPoint)
            
            let stripeLayer = SimpleShapeLayer()
            stripeLayer.path = path.cgPath
            stripeLayer.strokeColor = UIColor(rgb: 0xaaaaaa).cgColor
            stripeLayer.lineWidth = lineWidth
            stripeLayer.fillColor = UIColor.clear.cgColor
            stripeLayer.lineCap = .round
            stripeLayer.strokeStart = 0.0
            stripeLayer.strokeEnd = 0.001
                        
            self.addSublayer(stripeLayer)
            self.segmentLayers.append(stripeLayer)
        }
    }
    
    func update(segments: Set<Int>, transition: ComponentTransition) {
        var mappedSegments = Set<Int>()
        for value in segments {
            for i in 0 ..< 4 {
                mappedSegments.insert(value * 4 + i)
            }
        }
        
        for i in 0 ..< numberOfSegments {
            let stripeLayer = self.segmentLayers[i]
            if mappedSegments.contains(i) {
                transition.setShapeLayerStrokeEnd(layer: stripeLayer, strokeEnd: 1.0)
                transition.setShapeLayerStrokeColor(layer: stripeLayer, color: UIColor(rgb: 0x00ca48))
            } else {
                transition.setShapeLayerStrokeEnd(layer: stripeLayer, strokeEnd: 0.32)
                transition.setShapeLayerStrokeColor(layer: stripeLayer, color: UIColor(rgb: 0xaaaaaa))
            }
        }
    }
    
    func update(size: CGSize) {
        self.setupIfNeeded(size: size)
    }
}
