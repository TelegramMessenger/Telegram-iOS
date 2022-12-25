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
import TelegramCore
import MultilineTextComponent
import EmojiStatusComponent
import Postbox

private func interpolateChartData(start: PieChartComponent.ChartData, end: PieChartComponent.ChartData, progress: CGFloat) -> PieChartComponent.ChartData {
    if start.items.count != end.items.count {
        return start
    }
    
    var result = end
    for i in 0 ..< result.items.count {
        result.items[i].value = (1.0 - progress) * start.items[i].value + progress * end.items[i].value
        result.items[i].color = start.items[i].color.interpolateTo(end.items[i].color, fraction: progress) ?? end.items[i].color
    }
    
    return result
}

private func processChartData(data: PieChartComponent.ChartData) -> PieChartComponent.ChartData {
    var data = data
    
    let minValue: Double = 0.01
    
    var totalSum: CGFloat = 0.0
    for i in 0 ..< data.items.count {
        if data.items[i].value > 0.00001 {
            data.items[i].value = max(data.items[i].value, minValue)
        }
        totalSum += data.items[i].value
    }
    
    var hasOneItem = false
    for i in 0 ..< data.items.count {
        if data.items[i].value != 0 && totalSum == data.items[i].value {
            data.items[i].value = 1.0
            hasOneItem = true
            break
        }
    }
    
    if !hasOneItem {
        if abs(totalSum - 1.0) > 0.0001 {
            let deltaValue = totalSum - 1.0
            
            var availableSum: Double = 0.0
            for i in 0 ..< data.items.count {
                let itemValue = data.items[i].value
                let availableItemValue = max(0.0, itemValue - minValue)
                if availableItemValue > 0.0 {
                    availableSum += availableItemValue
                }
            }
            totalSum = 0.0
            let itemFraction = deltaValue / availableSum
            for i in 0 ..< data.items.count {
                let itemValue = data.items[i].value
                let availableItemValue = max(0.0, itemValue - minValue)
                if availableItemValue > 0.0 {
                    let itemDelta = availableItemValue * itemFraction
                    data.items[i].value -= itemDelta
                }
                totalSum += data.items[i].value
            }
        }
        
        if totalSum > 0.0 && totalSum < 1.0 - 0.0001 {
            for i in 0 ..< data.items.count {
                data.items[i].value /= totalSum
            }
        }
    }
    
    return data
}

private let chartLabelFont = Font.with(size: 16.0, design: .round, weight: .semibold)

private final class ChartLabel: UIView {
    private let label: ImmediateTextView
    private var currentText: String?
    
    override init(frame: CGRect) {
        self.label = ImmediateTextView()
        
        super.init(frame: frame)
        
        self.addSubview(self.label)
    }
    
    required init(coder: NSCoder) {
        preconditionFailure()
    }
    
    func update(text: String) -> CGSize {
        if self.currentText == text {
            return self.label.bounds.size
        }
        
        var snapshotView: UIView?
        if self.currentText != nil {
            snapshotView = self.label.snapshotView(afterScreenUpdates: false)
            snapshotView?.frame = self.label.frame
        }
        
        self.currentText = text
        self.label.attributedText = NSAttributedString(string: text, font: chartLabelFont, textColor: .white)
        let size = self.label.updateLayout(CGSize(width: 100.0, height: 100.0))
        self.label.frame = CGRect(origin: CGPoint(x: floor(-size.width * 0.5), y: floor(-size.height * 0.5)), size: size)
        
        if let snapshotView {
            self.addSubview(snapshotView)
            snapshotView.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.2, removeOnCompletion: false, completion: { [weak snapshotView] _ in
                snapshotView?.removeFromSuperview()
            })
            snapshotView.layer.animateScale(from: 1.0, to: 0.001, duration: 0.2, removeOnCompletion: false)
            self.label.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.2)
            self.label.layer.animateScale(from: 0.001, to: 1.0, duration: 0.2)
        }
        
        return size
    }
}

final class PieChartComponent: Component {
    struct ChartData: Equatable {
        struct Item: Equatable {
            var id: StorageUsageScreenComponent.Category
            var displayValue: Double
            var value: Double
            var color: UIColor
            
            init(id: StorageUsageScreenComponent.Category, displayValue: Double, value: Double, color: UIColor) {
                self.id = id
                self.displayValue = displayValue
                self.value = value
                self.color = color
            }
        }
        
        var items: [Item]
        
        init(items: [Item]) {
            self.items = items
        }
    }
    
    let theme: PresentationTheme
    let chartData: ChartData
    
    init(
        theme: PresentationTheme,
        chartData: ChartData
    ) {
        self.theme = theme
        self.chartData = chartData
    }
    
    static func ==(lhs: PieChartComponent, rhs: PieChartComponent) -> Bool {
        if lhs.theme !== rhs.theme {
            return false
        }
        if lhs.chartData != rhs.chartData {
            return false
        }
        return true
    }
    
    private final class ChartDataView: UIView {
        private(set) var theme: PresentationTheme?
        private(set) var data: ChartData?
        private(set) var selectedKey: StorageUsageScreenComponent.Category?
        
        private var currentAnimation: (start: ChartData, end: ChartData, current: ChartData, progress: CGFloat)?
        private var animator: DisplayLinkAnimator?
        
        private var labels: [StorageUsageScreenComponent.Category: ChartLabel] = [:]
        
        override init(frame: CGRect) {
            super.init(frame: frame)
            
            self.backgroundColor = nil
            self.isOpaque = false
        }
        
        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }
        
        deinit {
            self.animator?.invalidate()
        }
        
        func setItems(theme: PresentationTheme, data: ChartData, selectedKey: StorageUsageScreenComponent.Category?, animated: Bool) {
            let data = processChartData(data: data)
            
            if self.theme !== theme || self.data != data || self.selectedKey != selectedKey {
                self.theme = theme
                self.selectedKey = selectedKey
                
                if animated, let previous = self.data {
                    var initialState = previous
                    if let currentAnimation = self.currentAnimation {
                        initialState = currentAnimation.current
                    }
                    self.currentAnimation = (initialState, data, initialState, 0.0)
                    self.animator?.invalidate()
                    self.animator = DisplayLinkAnimator(duration: 0.4, from: 0.0, to: 1.0, update: { [weak self] progress in
                        guard let self else {
                            return
                        }
                        let progress = listViewAnimationCurveSystem(progress)
                        if let currentAnimationValue = self.currentAnimation {
                            self.currentAnimation = (currentAnimationValue.start, currentAnimationValue.end, interpolateChartData(start: currentAnimationValue.start, end: currentAnimationValue.end, progress: progress), progress)
                            self.setNeedsDisplay()
                        }
                    }, completion: { [weak self] in
                        guard let self else {
                            return
                        }
                        self.currentAnimation = nil
                        self.setNeedsDisplay()
                    })
                }
                
                self.data = data
                
                self.setNeedsDisplay()
            }
        }
        
        override func draw(_ rect: CGRect) {
            guard let context = UIGraphicsGetCurrentContext() else {
                return
            }
            guard let _ = self.theme, let data = self.currentAnimation?.current ?? self.data else {
                return
            }
            if data.items.isEmpty {
                return
            }
            
            let innerDiameter: CGFloat = 100.0
            let spacing: CGFloat = 2.0
            let innerAngleSpacing: CGFloat = spacing / (innerDiameter * 0.5)
            //let minAngle: CGFloat = innerAngleSpacing * 2.0 + 2.0 / (innerDiameter * 0.5)
            
            var angles: [Double] = []
            for i in 0 ..< data.items.count {
                let item = data.items[i]
                let angle = item.value * CGFloat.pi * 2.0
                angles.append(angle)
            }
            
            let diameter: CGFloat = 200.0
            let reducedDiameter: CGFloat = 170.0
            
            var startAngle: CGFloat = 0.0
            for i in 0 ..< data.items.count {
                let item = data.items[i]
                
                let itemOuterDiameter: CGFloat
                if let selectedKey = self.selectedKey {
                    if selectedKey == item.id {
                        itemOuterDiameter = diameter
                    } else {
                        itemOuterDiameter = reducedDiameter
                    }
                } else {
                    itemOuterDiameter = diameter
                }
                
                let shapeLayerFrame = CGRect(origin: CGPoint(x: 0.0, y: 0.0), size: CGSize(width: diameter, height: diameter))
                
                let angleSpacing: CGFloat = spacing / (itemOuterDiameter * 0.5)
                
                let angleValue: CGFloat = angles[i]
                
                let innerStartAngle = startAngle + innerAngleSpacing * 0.5
                var innerEndAngle = startAngle + angleValue - innerAngleSpacing * 0.5
                innerEndAngle = max(innerEndAngle, innerStartAngle)
                
                let outerStartAngle = startAngle + angleSpacing * 0.5
                var outerEndAngle = startAngle + angleValue - angleSpacing * 0.5
                outerEndAngle = max(outerEndAngle, outerStartAngle)
                
                let path = CGMutablePath()
                
                path.addArc(center: CGPoint(x: diameter * 0.5, y: diameter * 0.5), radius: innerDiameter * 0.5, startAngle: innerEndAngle, endAngle: innerStartAngle, clockwise: true)
                path.addArc(center: CGPoint(x: diameter * 0.5, y: diameter * 0.5), radius: itemOuterDiameter * 0.5, startAngle: outerStartAngle, endAngle: outerEndAngle, clockwise: false)
                
                context.addPath(path)
                context.setFillColor(item.color.cgColor)
                context.fillPath()
                
                startAngle += angleValue
                
                let fractionValue: Double = floor(item.displayValue * 100.0 * 10.0) / 10.0
                let fractionString: String
                if fractionValue < 0.1 {
                    fractionString = "<0.1"
                } else if abs(Double(Int(fractionValue)) - fractionValue) < 0.001 {
                    fractionString = "\(Int(fractionValue))"
                } else {
                    fractionString = "\(fractionValue)"
                }
                
                let label: ChartLabel
                if let current = self.labels[item.id] {
                    label = current
                } else {
                    label = ChartLabel()
                    self.labels[item.id] = label
                }
                let labelSize = label.update(text: "\(fractionString)%")
                
                var labelFrame: CGRect?
                
                if angleValue >= 0.001 {
                    for step in 0 ... 20 {
                        let stepFraction: CGFloat = CGFloat(step) / 20.0
                        let centerOffset: CGFloat = 0.5 * (1.0 - stepFraction) + 0.65 * stepFraction
                        
                        let midAngle: CGFloat = (innerStartAngle + innerEndAngle) * 0.5
                        let centerDistance: CGFloat = (innerDiameter * 0.5 + (diameter * 0.5 - innerDiameter * 0.5) * centerOffset)
                        
                        let relLabelCenter = CGPoint(
                            x: cos(midAngle) * centerDistance,
                            y: sin(midAngle) * centerDistance
                        )
                        
                        let labelCenter = CGPoint(
                            x: shapeLayerFrame.midX + relLabelCenter.x,
                            y: shapeLayerFrame.midY + relLabelCenter.y
                        )
                        
                        func lineCircleIntersection(_ center: CGPoint, _ p1: CGPoint, _ p2: CGPoint, _ r: CGFloat) -> CGFloat {
                            let dx: CGFloat = p2.x - p1.x
                            let dy: CGFloat = p2.y - p1.y
                            let dr: CGFloat = sqrt(dx * dx + dy * dy)
                            let D: CGFloat = p1.x * p2.y - p2.x * p1.y
                            
                            var minDistance: CGFloat = 10000.0
                            
                            for i in 0 ..< 2 {
                                let signFactor: CGFloat = i == 0 ? 1.0 : (-1.0)
                                let dysign: CGFloat = dy < 0.0 ? -1.0 : 1.0
                                let ix: CGFloat = (D * dy + signFactor * dysign * dx * sqrt(r * r * dr * dr - D * D)) / (dr * dr)
                                let iy: CGFloat = (-D * dx + signFactor * abs(dy) * sqrt(r * r * dr * dr - D * D)) / (dr * dr)
                                let distance: CGFloat = sqrt(pow(ix - center.x, 2.0) + pow(iy - center.y, 2.0))
                                minDistance = min(minDistance, distance)
                            }
                            
                            return minDistance
                        }
                        
                        func lineLineIntersection(_ p1: CGPoint, _ p2: CGPoint, _ p3: CGPoint, _ p4: CGPoint) -> CGFloat {
                            let x1 = p1.x
                            let y1 = p1.y
                            let x2 = p2.x
                            let y2 = p2.y
                            let x3 = p3.x
                            let y3 = p3.y
                            let x4 = p4.x
                            let y4 = p4.y
                            
                            let d: CGFloat = (x1 - x2) * (y3 - y4) - (y1 - y2) * (x3 - x4)
                            if abs(d) <= 0.00001 {
                                return 10000.0
                            }
                            
                            let px: CGFloat = ((x1 * y2 - y1 * x2) * (x3 - x4) - (x1 - x2) * (x3 * y4 - y3 * x4)) / d
                            let py: CGFloat = ((x1 * y2 - y1 * x2) * (y3 - y4) - (y1 - y2) * (x3 * y4 - y3 * x4)) / d
                            
                            let distance: CGFloat = sqrt(pow(px - p1.x, 2.0) + pow(py - p1.y, 2.0))
                            return distance
                        }
                        
                        let intersectionOuterTopRight = lineCircleIntersection(relLabelCenter, relLabelCenter, CGPoint(x: relLabelCenter.x + labelSize.width * 0.5, y: relLabelCenter.y + labelSize.height * 0.5), diameter * 0.5)
                        let intersectionInnerTopRight = lineCircleIntersection(relLabelCenter, relLabelCenter, CGPoint(x: relLabelCenter.x + labelSize.width * 0.5, y: relLabelCenter.y + labelSize.height * 0.5), innerDiameter * 0.5)
                        let intersectionOuterBottomRight = lineCircleIntersection(relLabelCenter, relLabelCenter, CGPoint(x: relLabelCenter.x + labelSize.width * 0.5, y: relLabelCenter.y - labelSize.height * 0.5), diameter * 0.5)
                        let intersectionInnerBottomRight = lineCircleIntersection(relLabelCenter, relLabelCenter, CGPoint(x: relLabelCenter.x + labelSize.width * 0.5, y: relLabelCenter.y - labelSize.height * 0.5), innerDiameter * 0.5)
                        
                        let horizontalInset: CGFloat = 2.0
                        let intersectionOuterLeft = lineCircleIntersection(relLabelCenter, relLabelCenter, CGPoint(x: relLabelCenter.x + labelSize.width * 0.5, y: relLabelCenter.y), diameter * 0.5) - horizontalInset
                        let intersectionInnerLeft = lineCircleIntersection(relLabelCenter, relLabelCenter, CGPoint(x: relLabelCenter.x + labelSize.width * 0.5, y: relLabelCenter.y), innerDiameter * 0.5) - horizontalInset
                        
                        let intersectionLine1TopRight = lineLineIntersection(relLabelCenter, CGPoint(x: relLabelCenter.x + labelSize.width * 0.5, y: relLabelCenter.y + labelSize.height * 0.5), CGPoint(), CGPoint(x: cos(innerStartAngle), y: sin(innerStartAngle)))
                        let intersectionLine1BottomRight = lineLineIntersection(relLabelCenter, CGPoint(x: relLabelCenter.x + labelSize.width * 0.5, y: relLabelCenter.y - labelSize.height * 0.5), CGPoint(), CGPoint(x: cos(innerStartAngle), y: sin(innerStartAngle)))
                        let intersectionLine2TopRight = lineLineIntersection(relLabelCenter, CGPoint(x: relLabelCenter.x + labelSize.width * 0.5, y: relLabelCenter.y + labelSize.height * 0.5), CGPoint(), CGPoint(x: cos(innerEndAngle), y: sin(innerEndAngle)))
                        let intersectionLine2BottomRight = lineLineIntersection(relLabelCenter, CGPoint(x: relLabelCenter.x + labelSize.width * 0.5, y: relLabelCenter.y - labelSize.height * 0.5), CGPoint(), CGPoint(x: cos(innerEndAngle), y: sin(innerEndAngle)))
                        
                        var distances: [CGFloat] = [
                            intersectionOuterTopRight,
                            intersectionInnerTopRight,
                            intersectionOuterBottomRight,
                            intersectionInnerBottomRight,
                            intersectionOuterLeft,
                            intersectionInnerLeft
                        ]
                        
                        if angleValue < CGFloat.pi / 2.0 {
                            distances.append(contentsOf: [
                                intersectionLine1TopRight,
                                intersectionLine1BottomRight,
                                intersectionLine2TopRight,
                                intersectionLine2BottomRight
                            ] as [CGFloat])
                        }
                        
                        var minDistance: CGFloat = 1000.0
                        for distance in distances {
                            minDistance = min(minDistance, max(distance, 1.0))
                        }
                        
                        let diagonalAngle = atan2(labelSize.height, labelSize.width)
                        
                        let maxHalfWidth = cos(diagonalAngle) * minDistance
                        let maxHalfHeight = sin(diagonalAngle) * minDistance
                        
                        let maxSize = CGSize(width: maxHalfWidth * 2.0, height: maxHalfHeight * 2.0)
                        let finalSize = CGSize(width: min(labelSize.width, maxSize.width), height: min(labelSize.height, maxSize.height))
                        
                        let currentFrame = CGRect(origin: CGPoint(x: labelCenter.x - finalSize.width * 0.5, y: labelCenter.y - finalSize.height * 0.5), size: finalSize)
                        
                        if finalSize.width >= labelSize.width {
                            labelFrame = currentFrame
                            break
                        }
                        if let labelFrame {
                            if labelFrame.width > finalSize.width {
                                continue
                            }
                        }
                        labelFrame = currentFrame
                    }
                } else {
                    let midAngle: CGFloat = (innerStartAngle + innerEndAngle) * 0.5
                    let centerDistance: CGFloat = (innerDiameter * 0.5 + (diameter * 0.5 - innerDiameter * 0.5) * 0.5)
                    
                    let relLabelCenter = CGPoint(
                        x: cos(midAngle) * centerDistance,
                        y: sin(midAngle) * centerDistance
                    )
                    
                    let labelCenter = CGPoint(
                        x: shapeLayerFrame.midX + relLabelCenter.x,
                        y: shapeLayerFrame.midY + relLabelCenter.y
                    )
                    
                    let minSize = labelSize.aspectFitted(CGSize(width: 4.0, height: 4.0))
                    labelFrame = CGRect(origin: CGPoint(x: labelCenter.x - minSize.width * 0.5, y: labelCenter.y - minSize.height * 0.5), size: minSize)
                }
                
                let labelView = label
                if let labelFrame {
                    var animateIn: Bool = false
                    if labelView.superview == nil {
                        animateIn = true
                        self.addSubview(labelView)
                    }
                    
                    var labelScale = labelFrame.width / labelSize.width
                    
                    let normalAlpha: CGFloat = labelScale < 0.4 ? 0.0 : 1.0
                    
                    var relLabelCenter = CGPoint(
                        x: labelFrame.midX - shapeLayerFrame.midX,
                        y: labelFrame.midY - shapeLayerFrame.midY
                    )
                    
                    let labelAlpha: CGFloat
                    if let selectedKey = self.selectedKey {
                        if selectedKey == item.id {
                            labelAlpha = normalAlpha
                        } else {
                            labelAlpha = 0.0
                            
                            let reducedFactor: CGFloat = (reducedDiameter - innerDiameter) / (diameter - innerDiameter)
                            let reducedDiameterFactor: CGFloat = reducedDiameter / diameter
                            
                            labelScale *= reducedFactor
                            
                            relLabelCenter.x *= reducedDiameterFactor
                            relLabelCenter.y *= reducedDiameterFactor
                        }
                    } else {
                        labelAlpha = normalAlpha
                    }
                    if labelView.alpha != labelAlpha {
                        let transition: Transition
                        if animateIn {
                            transition = .immediate
                        } else {
                            transition = Transition(animation: .curve(duration: 0.18, curve: .easeInOut))
                        }
                        transition.setAlpha(view: labelView, alpha: labelAlpha)
                    }
                    
                    let labelCenter = CGPoint(
                        x: shapeLayerFrame.midX + relLabelCenter.x,
                        y: shapeLayerFrame.midY + relLabelCenter.y
                    )
                    
                    labelView.center = labelCenter
                    labelView.transform = CGAffineTransformMakeScale(labelScale, labelScale)
                }
            }
        }
    }
    
    class View: UIView {
        private let dataView: ChartDataView
        private var labels: [StorageUsageScreenComponent.Category: ComponentView<Empty>] = [:]
        var selectedKey: StorageUsageScreenComponent.Category?
        
        private weak var state: EmptyComponentState?
        
        override init(frame: CGRect) {
            self.dataView = ChartDataView()
            
            super.init(frame: frame)
            
            self.addSubview(self.dataView)
            
            self.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(self.tapGesture(_:))))
        }
        
        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }
        
        @objc private func tapGesture(_ recognizer: UITapGestureRecognizer) {
            if case .ended = recognizer.state {
                let point = recognizer.location(in: self)
                let _ = point
                /*for (key, layer) in self.shapeLayers {
                    if layer.frame.contains(point), let path = layer.path {
                        if path.contains(self.layer.convert(point, to: layer)) {
                            if self.selectedKey == key {
                                self.selectedKey = nil
                            } else {
                                self.selectedKey = key
                            }
                            
                            self.state?.updated(transition: Transition(animation: .curve(duration: 0.3, curve: .spring)))
                            
                            break
                        }
                    }
                }*/
            }
        }
        
        func update(component: PieChartComponent, availableSize: CGSize, state: EmptyComponentState, environment: Environment<Empty>, transition: Transition) -> CGSize {
            self.state = state
            
            transition.setFrame(view: self.dataView, frame: CGRect(origin: CGPoint(x: floor((availableSize.width - 200.0) / 2.0), y: 0.0), size: CGSize(width: 200.0, height: 200.0)))
            self.dataView.setItems(theme: component.theme, data: component.chartData, selectedKey: self.selectedKey, animated: !transition.animation.isImmediate)
            
            return CGSize(width: availableSize.width, height: 200.0)
        }
    }
    
    func makeView() -> View {
        return View(frame: CGRect())
    }
    
    func update(view: View, availableSize: CGSize, state: EmptyComponentState, environment: Environment<Empty>, transition: Transition) -> CGSize {
        return view.update(component: self, availableSize: availableSize, state: state, environment: environment, transition: transition)
    }
}
