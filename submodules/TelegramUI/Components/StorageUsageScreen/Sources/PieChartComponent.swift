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
        result.items[i].mergeFactor = (1.0 - progress) * start.items[i].mergeFactor + progress * end.items[i].mergeFactor
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
            var mergeable: Bool
            var mergeFactor: CGFloat
            
            init(id: StorageUsageScreenComponent.Category, displayValue: Double, value: Double, color: UIColor, mergeable: Bool, mergeFactor: CGFloat) {
                self.id = id
                self.displayValue = displayValue
                self.value = value
                self.color = color
                self.mergeable = mergeable
                self.mergeFactor = mergeFactor
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
    
    private struct CalculatedLabel {
        var image: UIImage
        var alpha: CGFloat
        var angle: CGFloat
        var radius: CGFloat
        var scale: CGFloat
        
        init(
            image: UIImage,
            alpha: CGFloat,
            angle: CGFloat,
            radius: CGFloat,
            scale: CGFloat
        ) {
            self.image = image
            self.alpha = alpha
            self.angle = angle
            self.radius = radius
            self.scale = scale
        }
    }
    
    private struct CalculatedSection {
        var id: StorageUsageScreenComponent.Category
        var color: UIColor
        var innerAngle: Range<CGFloat>
        var outerAngle: Range<CGFloat>
        var innerRadius: CGFloat
        var outerRadius: CGFloat
        var label: CalculatedLabel?
        
        init(
            id: StorageUsageScreenComponent.Category,
            color: UIColor,
            innerAngle: Range<CGFloat>,
            outerAngle: Range<CGFloat>,
            innerRadius: CGFloat,
            outerRadius: CGFloat,
            label: CalculatedLabel?
        ) {
            self.id = id
            self.color = color
            self.innerAngle = innerAngle
            self.outerAngle = outerAngle
            self.innerRadius = innerRadius
            self.outerRadius = outerRadius
            self.label = label
        }
    }
    
    private struct ItemAngleData {
        var angleValue: CGFloat
        var startAngle: CGFloat
        var endAngle: CGFloat
    }
    
    private struct CalculatedLayout {
        var size: CGSize
        var sections: [CalculatedSection]
        
        init(size: CGSize, sections: [CalculatedSection]) {
            self.size = size
            self.sections = sections
        }
        
        init(size: CGSize, items: [ChartData.Item], selectedKey: AnyHashable?) {
            self.size = size
            self.sections = []
            
            if items.isEmpty {
                return
            }
            
            let innerDiameter: CGFloat = 100.0
            let spacing: CGFloat = 2.0
            let innerAngleSpacing: CGFloat = spacing / (innerDiameter * 0.5)
            
            var angles: [Double] = []
            for i in 0 ..< items.count {
                let item = items[i]
                let angle = item.value * CGFloat.pi * 2.0
                angles.append(angle)
            }
            
            let diameter: CGFloat = 200.0
            let reducedDiameter: CGFloat = 170.0
            
            var anglesData: [ItemAngleData] = []
            
            var startAngle: CGFloat = 0.0
            for i in 0 ..< items.count {
                let item = items[i]
                
                let itemOuterDiameter: CGFloat
                if let selectedKey {
                    if selectedKey == AnyHashable(item.id) {
                        itemOuterDiameter = diameter
                    } else {
                        itemOuterDiameter = reducedDiameter
                    }
                } else {
                    itemOuterDiameter = diameter
                }
                
                let angleSpacing: CGFloat = spacing / (itemOuterDiameter * 0.5)
                
                let angleValue: CGFloat = angles[i]
                
                var beforeSpacingFraction: CGFloat = 1.0
                var afterSpacingFraction: CGFloat = 1.0
                if item.mergeable {
                    let previousItem: ChartData.Item
                    if i == 0 {
                        previousItem = items[items.count - 1]
                    } else {
                        previousItem = items[i - 1]
                    }

                    let nextItem: ChartData.Item
                    if i == items.count - 1 {
                        nextItem = items[0]
                    } else {
                        nextItem = items[i + 1]
                    }
                    
                    if previousItem.mergeable {
                        beforeSpacingFraction = item.mergeFactor * 1.0 + (1.0 - item.mergeFactor) * (-0.2)
                    }
                    if nextItem.mergeable {
                        afterSpacingFraction = item.mergeFactor * 1.0 + (1.0 - item.mergeFactor) * (-0.2)
                    }
                }
                
                let innerStartAngle = startAngle + innerAngleSpacing * 0.5
                let arcInnerStartAngle = startAngle + innerAngleSpacing * 0.5 * beforeSpacingFraction
                
                var innerEndAngle = startAngle + angleValue - innerAngleSpacing * 0.5
                innerEndAngle = max(innerEndAngle, innerStartAngle)
                var arcInnerEndAngle = startAngle + angleValue - innerAngleSpacing * 0.5 * afterSpacingFraction
                arcInnerEndAngle = max(arcInnerEndAngle, arcInnerStartAngle)
                
                let outerStartAngle = startAngle + angleSpacing * 0.5
                let arcOuterStartAngle = startAngle + angleSpacing * 0.5 * beforeSpacingFraction
                var outerEndAngle = startAngle + angleValue - angleSpacing * 0.5
                outerEndAngle = max(outerEndAngle, outerStartAngle)
                var arcOuterEndAngle = startAngle + angleValue - angleSpacing * 0.5 * afterSpacingFraction
                arcOuterEndAngle = max(arcOuterEndAngle, arcOuterStartAngle)
                
                self.sections.append(CalculatedSection(
                    id: item.id,
                    color: item.color,
                    innerAngle: arcInnerStartAngle ..< arcInnerEndAngle,
                    outerAngle: arcOuterStartAngle ..< arcOuterEndAngle,
                    innerRadius: innerDiameter * 0.5,
                    outerRadius: itemOuterDiameter * 0.5,
                    label: nil
                ))
                
                startAngle += angleValue
                
                anglesData.append(ItemAngleData(angleValue: angleValue, startAngle: innerStartAngle, endAngle: innerEndAngle))
            }
            
            var mergedItem: (displayValue: Double, angleData: ItemAngleData, mergeFactor: CGFloat)?
            for i in 0 ..< items.count {
                let item = items[i]
                let angleData = anglesData[i]
                self.updateLabel(
                    index: i,
                    displayValue: item.displayValue,
                    mergeFactor: item.mergeFactor,
                    innerAngle: self.sections[i].innerAngle,
                    outerAngle: self.sections[i].outerAngle,
                    innerRadius: self.sections[i].innerRadius,
                    outerRadius: self.sections[i].outerRadius
                )
                
                if item.mergeable {
                    if var currentMergedItem = mergedItem {
                        currentMergedItem.displayValue += item.displayValue
                        currentMergedItem.angleData.startAngle = min(currentMergedItem.angleData.startAngle, angleData.startAngle)
                        currentMergedItem.angleData.endAngle = max(currentMergedItem.angleData.endAngle, angleData.endAngle)
                        mergedItem = currentMergedItem
                    } else {
                        let invertedMergeFactor: CGFloat = 1.0 - max(0.0, item.mergeFactor)
                        mergedItem = (item.displayValue, angleData, invertedMergeFactor)
                    }
                }
            }
            
            /*if let mergedItem {
                updateItemLabel(id: "merged", displayValue: mergedItem.displayValue, mergeFactor: mergedItem.mergeFactor, angleData: mergedItem.angleData)
            } else {
                if let label = self.labels["merged"] {
                    self.labels.removeValue(forKey: "merged")
                    label.removeFromSuperview()
                }
            }*/
        }
        
        private mutating func updateLabel(
            index: Int,
            displayValue: Double,
            mergeFactor: CGFloat,
            innerAngle: Range<CGFloat>,
            outerAngle: Range<CGFloat>,
            innerRadius: CGFloat,
            outerRadius: CGFloat
        ) {
            let fractionValue: Double = floor(displayValue * 100.0 * 10.0) / 10.0
            let fractionString: String
            if fractionValue < 0.1 {
                fractionString = "<0.1"
            } else if abs(Double(Int(fractionValue)) - fractionValue) < 0.001 {
                fractionString = "\(Int(fractionValue))"
            } else {
                fractionString = "\(fractionValue)"
            }
            
            let labelString = NSAttributedString(string: "\(fractionString)%", font: chartLabelFont, textColor: .white)
            let labelBounds = labelString.boundingRect(with: CGSize(width: 100.0, height: 100.0), options: [.usesLineFragmentOrigin], context: nil)
            let labelSize = CGSize(width: ceil(labelBounds.width), height: ceil(labelBounds.height))
            guard let labelImage = generateImage(labelSize, rotatedContext: { size, context in
                context.clear(CGRect(origin: CGPoint(), size: size))
                UIGraphicsPushContext(context)
                labelString.draw(in: labelBounds)
                UIGraphicsPopContext()
            }) else {
                return
            }
            
            var resultLabel: CalculatedLabel?
            
            if innerAngle.upperBound - innerAngle.lowerBound >= 0.001 {
                for step in 0 ... 10 {
                    let stepFraction: CGFloat = CGFloat(step) / 10.0
                    let centerOffset: CGFloat = 0.5 * (1.0 - stepFraction) + 0.65 * stepFraction
                    
                    let midAngle: CGFloat = (innerAngle.lowerBound + innerAngle.upperBound) * 0.5
                    let centerDistance: CGFloat = (innerRadius + (outerRadius - innerRadius) * centerOffset)
                    
                    let relLabelCenter = CGPoint(
                        x: cos(midAngle) * centerDistance,
                        y: sin(midAngle) * centerDistance
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
                    
                    let intersectionOuterTopRight = lineCircleIntersection(relLabelCenter, relLabelCenter, CGPoint(x: relLabelCenter.x + labelSize.width * 0.5, y: relLabelCenter.y + labelSize.height * 0.5), outerRadius)
                    let intersectionInnerTopRight = lineCircleIntersection(relLabelCenter, relLabelCenter, CGPoint(x: relLabelCenter.x + labelSize.width * 0.5, y: relLabelCenter.y + labelSize.height * 0.5), innerRadius)
                    let intersectionOuterBottomRight = lineCircleIntersection(relLabelCenter, relLabelCenter, CGPoint(x: relLabelCenter.x + labelSize.width * 0.5, y: relLabelCenter.y - labelSize.height * 0.5), outerRadius)
                    let intersectionInnerBottomRight = lineCircleIntersection(relLabelCenter, relLabelCenter, CGPoint(x: relLabelCenter.x + labelSize.width * 0.5, y: relLabelCenter.y - labelSize.height * 0.5), innerRadius)
                    
                    let horizontalInset: CGFloat = 2.0
                    let intersectionOuterLeft = lineCircleIntersection(relLabelCenter, relLabelCenter, CGPoint(x: relLabelCenter.x + labelSize.width * 0.5, y: relLabelCenter.y), outerRadius) - horizontalInset
                    let intersectionInnerLeft = lineCircleIntersection(relLabelCenter, relLabelCenter, CGPoint(x: relLabelCenter.x + labelSize.width * 0.5, y: relLabelCenter.y), innerRadius) - horizontalInset
                    
                    let intersectionLine1TopRight = lineLineIntersection(relLabelCenter, CGPoint(x: relLabelCenter.x + labelSize.width * 0.5, y: relLabelCenter.y + labelSize.height * 0.5), CGPoint(), CGPoint(x: cos(innerAngle.lowerBound), y: sin(innerAngle.lowerBound)))
                    let intersectionLine1BottomRight = lineLineIntersection(relLabelCenter, CGPoint(x: relLabelCenter.x + labelSize.width * 0.5, y: relLabelCenter.y - labelSize.height * 0.5), CGPoint(), CGPoint(x: cos(innerAngle.lowerBound), y: sin(innerAngle.lowerBound)))
                    let intersectionLine2TopRight = lineLineIntersection(relLabelCenter, CGPoint(x: relLabelCenter.x + labelSize.width * 0.5, y: relLabelCenter.y + labelSize.height * 0.5), CGPoint(), CGPoint(x: cos(innerAngle.upperBound), y: sin(innerAngle.upperBound)))
                    let intersectionLine2BottomRight = lineLineIntersection(relLabelCenter, CGPoint(x: relLabelCenter.x + labelSize.width * 0.5, y: relLabelCenter.y - labelSize.height * 0.5), CGPoint(), CGPoint(x: cos(innerAngle.upperBound), y: sin(innerAngle.upperBound)))
                    
                    var distances: [CGFloat] = [
                        intersectionOuterTopRight,
                        intersectionInnerTopRight,
                        intersectionOuterBottomRight,
                        intersectionInnerBottomRight,
                        intersectionOuterLeft,
                        intersectionInnerLeft
                    ]
                    
                    if innerAngle.upperBound - innerAngle.lowerBound < CGFloat.pi / 2.0 {
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
                    
                    let currentScale = finalSize.width / labelSize.width
                    
                    if currentScale >= 1.0 - 0.001 {
                        resultLabel = CalculatedLabel(
                            image: labelImage,
                            alpha: 1.0,
                            angle: midAngle,
                            radius: centerDistance,
                            scale: 1.0
                        )
                        break
                    }
                    if let resultLabel {
                        if resultLabel.scale > currentScale {
                            continue
                        }
                    }
                    resultLabel = CalculatedLabel(
                        image: labelImage,
                        alpha: currentScale >= 0.2 ? 1.0 : 0.0,
                        angle: midAngle,
                        radius: centerDistance,
                        scale: currentScale
                    )
                }
            } else {
                let midAngle: CGFloat = (innerAngle.lowerBound + innerAngle.upperBound) * 0.5
                let centerDistance: CGFloat = (innerRadius + (outerRadius - innerRadius) * 0.5)
                
                resultLabel = CalculatedLabel(
                    image: labelImage,
                    alpha: 0.0,
                    angle: midAngle,
                    radius: centerDistance,
                    scale: 0.001
                )
            }
            
            if let resultLabel {
                self.sections[index].label = resultLabel
            }
        }
    }
    
    private struct Particle {
        var trackIndex: Int
        var position: CGPoint
        var scale: CGFloat
        var alpha: CGFloat
        var direction: CGPoint
        var velocity: CGFloat
        
        init(
            trackIndex: Int,
            position: CGPoint,
            scale: CGFloat,
            alpha: CGFloat,
            direction: CGPoint,
            velocity: CGFloat
        ) {
            self.trackIndex = trackIndex
            self.position = position
            self.scale = scale
            self.alpha = alpha
            self.direction = direction
            self.velocity = velocity
        }
        
        mutating func update(deltaTime: CGFloat) {
            var position = self.position
            position.x += self.direction.x * self.velocity * deltaTime
            position.y += self.direction.y * self.velocity * deltaTime
            self.position = position
        }
    }
    
    private final class ParticleSet {
        private(set) var particles: [Particle] = []
        
        init() {
            self.generateParticles(preAdvance: true)
        }
        
        private func generateParticles(preAdvance: Bool) {
            let maxDirections = 24
            
            if self.particles.count < maxDirections {
                var allTrackIndices: [Int] = Array(repeating: 0, count: maxDirections)
                for i in 0 ..< maxDirections {
                    allTrackIndices[i] = i
                }
                var takenIndexCount = 0
                for particle in self.particles {
                    allTrackIndices[particle.trackIndex] = -1
                    takenIndexCount += 1
                }
                var availableTrackIndices: [Int] = []
                availableTrackIndices.reserveCapacity(maxDirections - takenIndexCount)
                for index in allTrackIndices {
                    if index != -1 {
                        availableTrackIndices.append(index)
                    }
                }
                
                if !availableTrackIndices.isEmpty {
                    availableTrackIndices.shuffle()
                    
                    for takeIndex in availableTrackIndices {
                        let directionIndex = takeIndex
                        let angle = (CGFloat(directionIndex % maxDirections) / CGFloat(maxDirections)) * CGFloat.pi * 2.0
                        
                        let direction = CGPoint(x: cos(angle), y: sin(angle))
                        let velocity = CGFloat.random(in: 20.0 ..< 40.0)
                        let alpha = CGFloat.random(in: 0.1 ..< 0.4)
                        let scale = CGFloat.random(in: 0.5 ... 1.0) * 0.22
                        
                        var position = CGPoint(x: 100.0, y: 100.0)
                        var initialOffset: CGFloat = 0.4
                        if preAdvance {
                            initialOffset = CGFloat.random(in: initialOffset ... 1.0)
                        }
                        position.x += direction.x * initialOffset * 105.0
                        position.y += direction.y * initialOffset * 105.0
                        
                        let particle = Particle(
                            trackIndex: directionIndex,
                            position: position,
                            scale: scale,
                            alpha: alpha,
                            direction: direction,
                            velocity: velocity
                        )
                        self.particles.append(particle)
                    }
                }
            }
        }
        
        func update(deltaTime: CGFloat) {
            let size = CGSize(width: 200.0, height: 200.0)
            let radius2 = pow(size.width * 0.5 + 10.0, 2.0)
            for i in (0 ..< self.particles.count).reversed() {
                self.particles[i].update(deltaTime: deltaTime)
                let position = self.particles[i].position
                
                if pow(position.x - size.width * 0.5, 2.0) + pow(position.y - size.height * 0.5, 2.0) > radius2 {
                    self.particles.remove(at: i)
                }
            }
            
            self.generateParticles(preAdvance: false)
        }
    }
    
    private final class SectionLayer: SimpleLayer {
        private let maskLayer: SimpleShapeLayer
        private let gradientLayer: SimpleGradientLayer
        private let labelLayer: SimpleLayer
        
        private var currentLabelImage: UIImage?
        
        private var particleImage: UIImage?
        private var particleLayers: [SimpleLayer] = []
        
        init(category: StorageUsageScreenComponent.Category) {
            self.maskLayer = SimpleShapeLayer()
            self.maskLayer.fillColor = UIColor.white.cgColor
            
            self.gradientLayer = SimpleGradientLayer()
            self.gradientLayer.type = .radial
            self.gradientLayer.startPoint = CGPoint(x: 0.5, y: 0.5)
            self.gradientLayer.endPoint = CGPoint(x: 1.0, y: 1.0)
            
            self.labelLayer = SimpleLayer()
            
            super.init()
            
            self.mask = self.maskLayer
            self.addSublayer(self.gradientLayer)
            self.addSublayer(self.labelLayer)
            
            switch category {
            case .photos:
                self.particleImage = UIImage(bundleImageName: "Settings/Storage/ParticlePhotos")?.precomposed()
            case .videos:
                self.particleImage = UIImage(bundleImageName: "Settings/Storage/ParticleVideos")?.precomposed()
            case .files:
                self.particleImage = UIImage(bundleImageName: "Settings/Storage/ParticleDocuments")?.precomposed()
            case .music:
                self.particleImage = UIImage(bundleImageName: "Settings/Storage/ParticleMusic")?.precomposed()
            case .other:
                self.particleImage = UIImage(bundleImageName: "Settings/Storage/ParticleOther")?.precomposed()
            case .stickers:
                self.particleImage = UIImage(bundleImageName: "Settings/Storage/ParticleStickers")?.precomposed()
            case .avatars:
                self.particleImage = UIImage(bundleImageName: "Settings/Storage/ParticleAvatars")?.precomposed()
            case .misc:
                self.particleImage = UIImage(bundleImageName: "Settings/Storage/ParticleOther")?.precomposed()
            }
        }
        
        override init(layer: Any) {
            self.maskLayer = SimpleShapeLayer()
            self.gradientLayer = SimpleGradientLayer()
            self.labelLayer = SimpleLayer()
            
            super.init(layer: layer)
        }
        
        required init(coder: NSCoder) {
            preconditionFailure()
        }
        
        func update(size: CGSize, section: CalculatedSection) {
            self.maskLayer.frame = CGRect(origin: CGPoint(), size: size)
            self.gradientLayer.frame = CGRect(origin: CGPoint(), size: size)
            
            let normalColor = section.color.cgColor
            let darkerColor = section.color.withMultipliedBrightnessBy(0.96).cgColor
            let colors: [CGColor] = [
                darkerColor,
                normalColor,
                normalColor,
                normalColor,
                darkerColor
            ]
            self.gradientLayer.colors = colors
            
            let locations: [CGFloat] = [
                0.0,
                0.3,
                0.5,
                0.7,
                1.0
            ]
            self.gradientLayer.locations = locations.map { location in
                let location = location * 0.5 + 0.5
                return location as NSNumber
            }
            
            let path = CGMutablePath()
            path.addArc(center: CGPoint(x: size.width * 0.5, y: size.height * 0.5), radius: section.innerRadius, startAngle: section.innerAngle.upperBound, endAngle: section.innerAngle.lowerBound, clockwise: true)
            path.addArc(center: CGPoint(x: size.width * 0.5, y: size.height * 0.5), radius: section.outerRadius, startAngle: section.outerAngle.lowerBound, endAngle: section.outerAngle.upperBound, clockwise: false)
            self.maskLayer.path = path
            
            if let label = section.label {
                if self.currentLabelImage !== label.image {
                    self.currentLabelImage = label.image
                    self.labelLayer.contents = label.image.cgImage
                }
                
                let position = CGPoint(x: size.width * 0.5 + cos(label.angle) * label.radius, y: size.height * 0.5 + sin(label.angle) * label.radius)
                let labelSize = CGSize(width: label.image.size.width * label.scale, height: label.image.size.height * label.scale)
                let labelFrame = CGRect(origin: CGPoint(x: position.x - labelSize.width * 0.5, y: position.y - labelSize.height * 0.5), size: labelSize)
                self.labelLayer.frame = labelFrame
                self.labelLayer.opacity = Float(label.alpha)
            } else {
                self.currentLabelImage = nil
                self.labelLayer.contents = nil
            }
        }
        
        func updateParticles(particleSet: ParticleSet) {
            guard let particleImage = self.particleImage else {
                return
            }
            for i in 0 ..< particleSet.particles.count {
                let particle = particleSet.particles[i]
                
                let particleLayer: SimpleLayer
                if i < self.particleLayers.count {
                    particleLayer = self.particleLayers[i]
                    particleLayer.isHidden = false
                } else {
                    particleLayer = SimpleLayer()
                    particleLayer.contents = particleImage.cgImage
                    particleLayer.bounds = CGRect(origin: CGPoint(), size: particleImage.size)
                    self.particleLayers.append(particleLayer)
                    self.insertSublayer(particleLayer, above: self.gradientLayer)
                }
                
                particleLayer.position = particle.position
                particleLayer.transform = CATransform3DMakeScale(particle.scale, particle.scale, 1.0)
                particleLayer.opacity = Float(particle.alpha)
            }
            if particleSet.particles.count < self.particleLayers.count {
                for i in particleSet.particles.count ..< self.particleLayers.count {
                    self.particleLayers[i].isHidden = true
                }
            }
        }
    }
    
    private final class ChartDataView: UIView {
        private(set) var theme: PresentationTheme?
        private(set) var data: ChartData?
        private(set) var selectedKey: AnyHashable?
        
        private var currentAnimation: (start: ChartData, end: ChartData, current: ChartData, progress: CGFloat)?
        private var currentLayout: CalculatedLayout?
        private var animator: DisplayLinkAnimator?
        
        private var displayLink: SharedDisplayLinkDriver.Link?
        
        private var sectionLayers: [AnyHashable: SectionLayer] = [:]
        private let particleSet: ParticleSet
        private var labels: [AnyHashable: ChartLabel] = [:]
        
        override init(frame: CGRect) {
            self.particleSet = ParticleSet()
            
            super.init(frame: frame)
            
            self.backgroundColor = nil
            self.isOpaque = false
            
            self.displayLink = SharedDisplayLinkDriver.shared.add(needsHighestFramerate: true, { [weak self] in
                self?.update()
            })
        }
        
        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }
        
        deinit {
            self.animator?.invalidate()
        }
        
        func setItems(theme: PresentationTheme, data: ChartData, selectedKey: AnyHashable?, animated: Bool) {
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
                    self.currentLayout = CalculatedLayout(
                        size: CGSize(width: 200.0, height: 200.0),
                        items: initialState.items,
                        selectedKey: self.selectedKey
                    )
                    self.animator?.invalidate()
                    self.animator = DisplayLinkAnimator(duration: 0.4, from: 0.0, to: 1.0, update: { [weak self] progress in
                        guard let self else {
                            return
                        }
                        let progress = listViewAnimationCurveSystem(progress)
                        if let currentAnimationValue = self.currentAnimation {
                            let interpolatedValue = interpolateChartData(start: currentAnimationValue.start, end: currentAnimationValue.end, progress: progress)
                            self.currentAnimation = (currentAnimationValue.start, currentAnimationValue.end, interpolatedValue, progress)
                            self.currentLayout = CalculatedLayout(
                                size: CGSize(width: 200.0, height: 200.0),
                                items: interpolatedValue.items,
                                selectedKey: self.selectedKey
                            )
                            self.update()
                        }
                    }, completion: { [weak self] in
                        guard let self else {
                            return
                        }
                        self.currentAnimation = nil
                        self.update()
                    })
                } else {
                    self.currentLayout = CalculatedLayout(
                        size: CGSize(width: 200.0, height: 200.0),
                        items: data.items,
                        selectedKey: self.selectedKey
                    )
                }
                
                self.data = data
                
                self.update()
            }
        }
        
        private func update() {
            self.particleSet.update(deltaTime: 1.0 / 60.0)
            
            var validIds: [AnyHashable] = []
            if let currentLayout = self.currentLayout {
                for section in currentLayout.sections {
                    validIds.append(section.id)
                    
                    let sectionLayer: SectionLayer
                    if let current = self.sectionLayers[section.id] {
                        sectionLayer = current
                    } else {
                        sectionLayer = SectionLayer(category: section.id)
                        self.sectionLayers[section.id] = sectionLayer
                        self.layer.addSublayer(sectionLayer)
                    }
                    
                    sectionLayer.frame = CGRect(origin: CGPoint(), size: CGSize(width: 200.0, height: 200.0))
                    sectionLayer.update(size: sectionLayer.bounds.size, section: section)
                    sectionLayer.updateParticles(particleSet: self.particleSet)
                }
            }
            
            var removeIds: [AnyHashable] = []
            for (id, sectionLayer) in self.sectionLayers {
                if !validIds.contains(id) {
                    removeIds.append(id)
                    sectionLayer.removeFromSuperlayer()
                }
            }
            for id in removeIds {
                self.sectionLayers.removeValue(forKey: id)
            }
        }
        
        /*override func draw(_ rect: CGRect) {
            guard let context = UIGraphicsGetCurrentContext() else {
                return
            }
            guard let currentLayout = self.currentLayout else {
                return
            }
            
            let size = CGSize(width: rect.width, height: rect.height)
            
            for section in currentLayout.sections {
                if section.innerAngle.lowerBound == section.innerAngle.upperBound {
                    continue
                }
                let path = CGMutablePath()
                path.addArc(center: CGPoint(x: size.width * 0.5, y: size.height * 0.5), radius: section.innerRadius, startAngle: section.innerAngle.upperBound, endAngle: section.innerAngle.lowerBound, clockwise: true)
                path.addArc(center: CGPoint(x: size.width * 0.5, y: size.height * 0.5), radius: section.outerRadius, startAngle: section.outerAngle.lowerBound, endAngle: section.outerAngle.upperBound, clockwise: false)
                
                context.addPath(path)
                context.clip()
                
                let colors: [CGColor] = [
                    section.color.withMultipliedBrightnessBy(0.9).cgColor,
                    section.color.cgColor,
                    section.color.cgColor,
                    section.color.cgColor,
                    section.color.withMultipliedBrightnessBy(0.9).cgColor
                ]
                var locations: [CGFloat] = [
                    1.0,
                    0.9,
                    0.5,
                    0.1,
                    0.0
                ]
                if let gradient = CGGradient(colorsSpace: nil, colors: colors as CFArray, locations: &locations) {
                    context.drawRadialGradient(gradient, startCenter: CGPoint(x: size.width * 0.5, y: size.height * 0.5), startRadius: section.innerRadius, endCenter: CGPoint(x: size.width * 0.5, y: size.height * 0.5), endRadius: section.outerRadius, options: [])
                }
                
                context.resetClip()
                
                //context.setFillColor(section.color.cgColor)
                //context.fillPath()
                
                if let label = section.label {
                    let position = CGPoint(x: size.width * 0.5 + cos(label.angle) * label.radius, y: size.height * 0.5 + sin(label.angle) * label.radius)
                    let labelSize = CGSize(width: label.image.size.width * label.scale, height: label.image.size.height * label.scale)
                    let labelFrame = CGRect(origin: CGPoint(x: position.x - labelSize.width * 0.5, y: position.y - labelSize.height * 0.5), size: labelSize)
                    label.image.draw(in: labelFrame, blendMode: .normal, alpha: label.alpha)
                }
            }
        }*/
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
