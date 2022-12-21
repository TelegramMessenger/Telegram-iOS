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

final class PieChartComponent: Component {
    struct ChartData: Equatable {
        struct Item: Equatable {
            var id: AnyHashable
            var value: Double
            var color: UIColor
            
            init(id: AnyHashable, value: Double, color: UIColor) {
                self.id = id
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
    
    class View: UIView {
        private var shapeLayers: [AnyHashable: SimpleShapeLayer] = [:]
        private var labels: [AnyHashable: ComponentView<Empty>] = [:]
        var selectedKey: AnyHashable?
        
        private weak var state: EmptyComponentState?
        
        override init(frame: CGRect) {
            super.init(frame: frame)
            
            self.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(self.tapGesture(_:))))
        }
        
        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }
        
        @objc private func tapGesture(_ recognizer: UITapGestureRecognizer) {
            if case .ended = recognizer.state {
                let point = recognizer.location(in: self)
                for (key, layer) in self.shapeLayers {
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
                }
            }
        }
        
        func update(component: PieChartComponent, availableSize: CGSize, state: EmptyComponentState, environment: Environment<Empty>, transition: Transition) -> CGSize {
            self.state = state
            
            let innerDiameter: CGFloat = 100.0
            let spacing: CGFloat = 2.0
            let innerAngleSpacing: CGFloat = spacing / (innerDiameter * 0.5)
            let minAngle: CGFloat = innerAngleSpacing * 2.0 + 2.0 / (innerDiameter * 0.5)
            
            var valueSum: Double = 0.0
            for item in component.chartData.items {
                valueSum += item.value
            }
            var angles: [Double] = []
            var totalAngle: Double = 0.0
            for i in 0 ..< component.chartData.items.count {
                let item = component.chartData.items[i]
                var angle = item.value / valueSum * CGFloat.pi * 2.0
                if angle > .ulpOfOne {
                    if angle < minAngle {
                        angle = minAngle
                    }
                    totalAngle += angle
                }
                angles.append(angle)
            }
            if totalAngle > CGFloat.pi * 2.0 {
                let deltaAngle = totalAngle - CGFloat.pi * 2.0
                
                var availableAngleSum: Double = 0.0
                for i in 0 ..< angles.count {
                    let itemAngle = angles[i]
                    let availableItemAngle = max(0.0, itemAngle - minAngle)
                    if availableItemAngle > 0.0 {
                        availableAngleSum += availableItemAngle
                    }
                }
                let itemFraction = deltaAngle / availableAngleSum
                for i in 0 ..< angles.count {
                    let availableItemAngle = max(0.0, angles[i] - minAngle)
                    if availableItemAngle > 0.0 {
                        let itemDelta = availableItemAngle * itemFraction
                        angles[i] -= itemDelta
                    }
                }
            }
            
            let diameter: CGFloat = 200.0
            let reducedDiameter: CGFloat = 170.0
            
            var startAngle: CGFloat = 0.0
            for i in 0 ..< component.chartData.items.count {
                let item = component.chartData.items[i]
                
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
                
                let shapeLayerFrame = CGRect(origin: CGPoint(x: floor((availableSize.width - diameter) / 2.0), y: 0.0), size: CGSize(width: diameter, height: diameter))
                
                let angleSpacing: CGFloat = spacing / (itemOuterDiameter * 0.5)
                
                let shapeLayer: SimpleShapeLayer
                if let current = self.shapeLayers[item.id] {
                    shapeLayer = current
                } else {
                    shapeLayer = SimpleShapeLayer()
                    self.shapeLayers[item.id] = shapeLayer
                    self.layer.insertSublayer(shapeLayer, at: 0)
                }
                
                transition.setFrame(layer: shapeLayer, frame: shapeLayerFrame)
                
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
                
                transition.setShapeLayerPath(layer: shapeLayer, path: path)
                
                startAngle += angleValue
                shapeLayer.fillColor = item.color.cgColor
                
                let fractionValue: Double = floor(item.value * 100.0 * 10.0) / 10.0
                let fractionString: String
                if abs(Double(Int(fractionValue)) - fractionValue) < 0.001 {
                    fractionString = "\(Int(fractionValue))"
                } else {
                    fractionString = "\(fractionValue)"
                }
                
                let label: ComponentView<Empty>
                if let current = self.labels[item.id] {
                    label = current
                } else {
                    label = ComponentView<Empty>()
                    self.labels[item.id] = label
                }
                let labelSize = label.update(transition: .immediate, component: AnyComponent(Text(text: "\(fractionString)%", font: Font.with(size: 16.0, design: .round, weight: .semibold), color: component.theme.list.itemCheckColors.foregroundColor)), environment: {}, containerSize: CGSize(width: 100.0, height: 100.0))
                
                var labelFrame: CGRect?
                
                for step in 0 ... 6 {
                    let stepFraction: CGFloat = CGFloat(step) / 6.0
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
                    
                    let intersectionLine1TopRight = lineLineIntersection(relLabelCenter, CGPoint(x: relLabelCenter.x + labelSize.width * 0.5, y: relLabelCenter.y + labelSize.height * 0.5), CGPoint(), CGPoint(x: cos(innerStartAngle), y: sin(innerStartAngle)))
                    let intersectionLine1BottomRight = lineLineIntersection(relLabelCenter, CGPoint(x: relLabelCenter.x + labelSize.width * 0.5, y: relLabelCenter.y - labelSize.height * 0.5), CGPoint(), CGPoint(x: cos(innerStartAngle), y: sin(innerStartAngle)))
                    let intersectionLine2TopRight = lineLineIntersection(relLabelCenter, CGPoint(x: relLabelCenter.x + labelSize.width * 0.5, y: relLabelCenter.y + labelSize.height * 0.5), CGPoint(), CGPoint(x: cos(innerEndAngle), y: sin(innerEndAngle)))
                    let intersectionLine2BottomRight = lineLineIntersection(relLabelCenter, CGPoint(x: relLabelCenter.x + labelSize.width * 0.5, y: relLabelCenter.y - labelSize.height * 0.5), CGPoint(), CGPoint(x: cos(innerEndAngle), y: sin(innerEndAngle)))
                    
                    var distances: [CGFloat] = [
                        intersectionOuterTopRight,
                        intersectionInnerTopRight,
                        intersectionOuterBottomRight,
                        intersectionInnerBottomRight
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
                        minDistance = min(minDistance, distance + 1.0)
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
                
                if let labelView = label.view, let labelFrame {
                    if labelView.superview == nil {
                        self.addSubview(labelView)
                    }
                    
                    labelView.bounds = CGRect(origin: CGPoint(), size: labelSize)
                    var labelScale = labelFrame.width / labelSize.width
                    
                    let normalAlpha: CGFloat = labelScale < 0.4 ? 0.0 : 1.0
                    
                    var relLabelCenter = CGPoint(
                        x: labelFrame.midX - shapeLayerFrame.midX,
                        y: labelFrame.midY - shapeLayerFrame.midY
                    )
                    
                    if let selectedKey = self.selectedKey {
                        if selectedKey == item.id {
                            transition.setAlpha(view: labelView, alpha: normalAlpha)
                        } else {
                            transition.setAlpha(view: labelView, alpha: 0.0)
                            
                            let reducedFactor: CGFloat = (reducedDiameter - innerDiameter) / (diameter - innerDiameter)
                            let reducedDiameterFactor: CGFloat = reducedDiameter / diameter
                            
                            labelScale *= reducedFactor
                            
                            relLabelCenter.x *= reducedDiameterFactor
                            relLabelCenter.y *= reducedDiameterFactor
                        }
                    } else {
                        transition.setAlpha(view: labelView, alpha: normalAlpha)
                    }
                    
                    let labelCenter = CGPoint(
                        x: shapeLayerFrame.midX + relLabelCenter.x,
                        y: shapeLayerFrame.midY + relLabelCenter.y
                    )
                    
                    transition.setPosition(view: labelView, position: labelCenter)
                    transition.setScale(view: labelView, scale: labelScale)
                }
            }
            
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
