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
            
            var valueSum: Double = 0.0
            for item in component.chartData.items {
                valueSum += item.value
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
                
                let angleValue: CGFloat = item.value / valueSum * CGFloat.pi * 2.0
                
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
                let labelSize = label.update(transition: .immediate, component: AnyComponent(Text(text: "\(fractionString)%", font: Font.with(size: 15.0, design: .round, weight: .medium), color: component.theme.list.itemCheckColors.foregroundColor)), environment: {}, containerSize: CGSize(width: 100.0, height: 100.0))
                
                let midAngle: CGFloat = (innerStartAngle + innerEndAngle) * 0.5
                let centerDistance: CGFloat = (innerDiameter * 0.5 + (diameter - innerDiameter) * 0.25)
                let labelCenter = CGPoint(
                    x: shapeLayerFrame.midX + cos(midAngle) * centerDistance,
                    y: shapeLayerFrame.midY + sin(midAngle) * centerDistance
                )
                let labelFrame = CGRect(origin: CGPoint(x: labelCenter.x - labelSize.width * 0.5, y: labelCenter.y - labelSize.height * 0.5), size: labelSize)
                
                //x2 + y2 = r2
                //x = sqrt(r2 - y2)
                //y = sqrt(r2 - x2)
                
                /*let localLabelRect = labelFrame.offsetBy(dx: -shapeLayerFrame.midX, dy: -shapeLayerFrame.midY)
                let outerIntersectionX1 = sqrt(pow(diameter * 0.5, 2.0) - pow(localLabelRect.minY, 2.0))
                let outerIntersectionX2 = sqrt(pow(diameter * 0.5, 2.0) - pow(localLabelRect.maxY, 2.0))
                let outerIntersectionY1 = sqrt(pow(diameter * 0.5, 2.0) - pow(localLabelRect.minX, 2.0))
                let outerIntersectionY2 = sqrt(pow(diameter * 0.5, 2.0) - pow(localLabelRect.maxX, 2.0))*/
                
                if let labelView = label.view {
                    if labelView.superview == nil {
                        self.addSubview(labelView)
                    }
                    labelView.bounds = CGRect(origin: CGPoint(), size: labelFrame.size)
                    transition.setPosition(view: labelView, position: labelFrame.center)
                    
                    if let selectedKey = self.selectedKey {
                        if selectedKey == item.id {
                            transition.setAlpha(view: labelView, alpha: 1.0)
                        } else {
                            transition.setAlpha(view: labelView, alpha: 0.0)
                        }
                    } else {
                        transition.setAlpha(view: labelView, alpha: 1.0)
                    }
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
