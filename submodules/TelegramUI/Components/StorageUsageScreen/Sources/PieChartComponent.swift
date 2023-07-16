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

private final class ChartSelectionTooltip: Component {
    let theme: PresentationTheme
    let fractionText: String
    let title: String
    let sizeText: String
    
    init(
        theme: PresentationTheme,
        fractionText: String,
        title: String,
        sizeText: String
    ) {
        self.theme = theme
        self.fractionText = fractionText
        self.title = title
        self.sizeText = sizeText
    }
    
    static func ==(lhs: ChartSelectionTooltip, rhs: ChartSelectionTooltip) -> Bool {
        return true
    }
    
    final class View: UIView {
        private let backgroundView: BlurredBackgroundView
        private let title = ComponentView<Empty>()
        
        override init(frame: CGRect) {
            self.backgroundView = BlurredBackgroundView(color: .clear, enableBlur: true)
            
            self.backgroundView.layer.shadowOpacity = 0.12
            self.backgroundView.layer.shadowColor = UIColor(white: 0.0, alpha: 1.0).cgColor
            self.backgroundView.layer.shadowOffset = CGSize(width: 0.0, height: 2.0)
            self.backgroundView.layer.shadowRadius = 8.0
            
            super.init(frame: frame)
            
            self.addSubview(self.backgroundView)
        }
        
        required init(coder: NSCoder) {
            preconditionFailure()
        }
        
        func update(component: ChartSelectionTooltip, availableSize: CGSize, state: EmptyComponentState, environment: Environment<Empty>, transition: Transition) -> CGSize {
            let sideInset: CGFloat = 10.0
            let height: CGFloat = 24.0
            
            let text = NSMutableAttributedString()
            text.append(NSAttributedString(string: component.fractionText + "  ", font: Font.semibold(12.0), textColor: component.theme.list.itemPrimaryTextColor))
            text.append(NSAttributedString(string: component.title + "  ", font: Font.regular(12.0), textColor: component.theme.list.itemPrimaryTextColor))
            text.append(NSAttributedString(string: component.sizeText, font: Font.semibold(12.0), textColor: component.theme.list.itemAccentColor))
            
            let titleSize = self.title.update(
                transition: transition,
                component: AnyComponent(MultilineTextComponent(
                    text: .plain(text)
                )),
                environment: {},
                containerSize: CGSize(width: availableSize.width - sideInset * 2.0, height: 100.0)
            )
            let titleFrame = CGRect(origin: CGPoint(x: sideInset, y: floor((height - titleSize.height) / 2.0)), size: titleSize)
            if let titleView = self.title.view {
                if titleView.superview == nil {
                    self.addSubview(titleView)
                }
                transition.setFrame(view: titleView, frame: titleFrame)
            }
            
            let size = CGSize(width: sideInset * 2.0 + titleSize.width, height: height)
            
            transition.setFrame(view: self.backgroundView, frame: CGRect(origin: CGPoint(), size: size))
            self.backgroundView.updateColor(color: component.theme.list.plainBackgroundColor.withMultipliedAlpha(0.88), transition: .immediate)
            self.backgroundView.update(size: size, cornerRadius: 10.0, transition: transition.containedViewLayoutTransition)
            
            self.backgroundView.layer.shadowPath = UIBezierPath(roundedRect: self.backgroundView.bounds, cornerRadius: 10.0).cgPath
            
            return size
        }
    }
    
    func makeView() -> View {
        return View(frame: CGRect())
    }
    
    func update(view: View, availableSize: CGSize, state: EmptyComponentState, environment: Environment<Empty>, transition: Transition) -> CGSize {
        return view.update(component: self, availableSize: availableSize, state: state, environment: environment, transition: transition)
    }
}

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
            var id: AnyHashable
            var displayValue: Double
            var displaySize: Int64
            var value: Double
            var color: UIColor
            var particle: String?
            var title: String
            var mergeable: Bool
            var mergeFactor: CGFloat
            
            init(id: AnyHashable, displayValue: Double, displaySize: Int64, value: Double, color: UIColor, particle: String?, title: String, mergeable: Bool, mergeFactor: CGFloat) {
                self.id = id
                self.displayValue = displayValue
                self.displaySize = displaySize
                self.value = value
                self.color = color
                self.particle = particle
                self.title = title
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
    let strings: PresentationStrings
    let emptyColor: UIColor
    let chartData: ChartData
    
    init(
        theme: PresentationTheme,
        strings: PresentationStrings,
        emptyColor: UIColor,
        chartData: ChartData
    ) {
        self.theme = theme
        self.strings = strings
        self.emptyColor = emptyColor
        self.chartData = chartData
    }
    
    static func ==(lhs: PieChartComponent, rhs: PieChartComponent) -> Bool {
        if lhs.theme !== rhs.theme {
            return false
        }
        if lhs.strings !== rhs.strings {
            return false
        }
        if lhs.emptyColor != rhs.emptyColor {
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
        
        func interpolateTo(_ other: CalculatedLabel, amount: CGFloat) -> CalculatedLabel {
            return CalculatedLabel(
                image: other.image,
                alpha: self.alpha.interpolate(to: other.alpha, amount: amount),
                angle: self.angle.interpolate(to: other.angle, amount: amount),
                radius: self.radius.interpolate(to: other.radius, amount: amount),
                scale: self.scale.interpolate(to: other.scale, amount: amount)
            )
        }
    }
    
    private struct CalculatedSection {
        var id: AnyHashable
        var color: UIColor
        var particle: String?
        var title: String
        var innerAngle: Range<CGFloat>
        var outerAngle: Range<CGFloat>
        var innerRadius: CGFloat
        var outerRadius: CGFloat
        var label: CalculatedLabel?
        
        init(
            id: AnyHashable,
            color: UIColor,
            particle: String?,
            title: String,
            innerAngle: Range<CGFloat>,
            outerAngle: Range<CGFloat>,
            innerRadius: CGFloat,
            outerRadius: CGFloat,
            label: CalculatedLabel?
        ) {
            self.id = id
            self.color = color
            self.particle = particle
            self.title = title
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
        var isEmpty: Bool
        
        init(size: CGSize, sections: [CalculatedSection]) {
            self.size = size
            self.sections = sections
            self.isEmpty = sections.isEmpty
        }
        
        init(interpolating start: CalculatedLayout, to end: CalculatedLayout, progress: CGFloat, size: CGSize) {
            self.size = size
            self.sections = []
            self.isEmpty = end.isEmpty
            
            for i in 0 ..< end.sections.count {
                let right = end.sections[i]
                
                if i < start.sections.count {
                    let left = start.sections[i]
                    let innerAngle: Range<CGFloat> = left.innerAngle.lowerBound.interpolate(to: right.innerAngle.lowerBound, amount: progress) ..< left.innerAngle.upperBound.interpolate(to: right.innerAngle.upperBound, amount: progress)
                    let outerAngle: Range<CGFloat> = left.outerAngle.lowerBound.interpolate(to: right.outerAngle.lowerBound, amount: progress) ..< left.outerAngle.upperBound.interpolate(to: right.outerAngle.upperBound, amount: progress)
                    
                    var label: CalculatedLabel?
                    if let leftLabel = left.label, let rightLabel = right.label {
                        label = leftLabel.interpolateTo(rightLabel, amount: progress)
                    } else {
                        label = right.label
                    }
                    
                    self.sections.append(CalculatedSection(
                        id: right.id,
                        color: left.color.interpolateTo(right.color, fraction: progress) ?? right.color,
                        particle: right.particle,
                        title: right.title,
                        innerAngle: innerAngle,
                        outerAngle: outerAngle,
                        innerRadius: left.innerRadius.interpolate(to: right.innerRadius, amount: progress),
                        outerRadius: left.outerRadius.interpolate(to: right.outerRadius, amount: progress),
                        label: label
                    ))
                } else {
                    self.sections.append(right)
                }
            }
        }
        
        init(size: CGSize, items: [ChartData.Item], selectedKey: AnyHashable?, isEmpty: Bool, emptyColor: UIColor) {
            self.size = size
            self.sections = []
            self.isEmpty = isEmpty
            
            if items.isEmpty {
                return
            }
            
            let innerDiameter: CGFloat = isEmpty ? 90.0 : 100.0
            let spacing: CGFloat = isEmpty ? -0.5 : 2.0
            let innerAngleSpacing: CGFloat = spacing / (innerDiameter * 0.5)
            
            var angles: [Double] = []
            for i in 0 ..< items.count {
                let item = items[i]
                let angle = item.value * CGFloat.pi * 2.0
                angles.append(angle)
            }
            
            let diameter: CGFloat = isEmpty ? (innerDiameter + 6.0 * 2.0) : 200.0
            let reducedDiameter: CGFloat = floor(0.85 * diameter)
            
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
                
                let beforeSpacingFraction: CGFloat = 1.0
                let afterSpacingFraction: CGFloat = 1.0
                
                let itemInnerAngleSpacing: CGFloat
                let itemAngleSpacing: CGFloat
                if abs(angleValue - CGFloat.pi * 2.0) <= 0.0001 {
                    itemInnerAngleSpacing = 0.0
                    itemAngleSpacing = 0.0
                } else {
                    itemInnerAngleSpacing = innerAngleSpacing
                    itemAngleSpacing = angleSpacing
                }
                
                let innerStartAngle = startAngle + itemInnerAngleSpacing * 0.5
                let arcInnerStartAngle = startAngle + itemInnerAngleSpacing * 0.5 * beforeSpacingFraction
                
                var innerEndAngle = startAngle + angleValue - itemInnerAngleSpacing * 0.5
                innerEndAngle = max(innerEndAngle, innerStartAngle)
                var arcInnerEndAngle = startAngle + angleValue - itemInnerAngleSpacing * 0.5 * afterSpacingFraction
                arcInnerEndAngle = max(arcInnerEndAngle, arcInnerStartAngle)
                
                let outerStartAngle = startAngle + itemAngleSpacing * 0.5
                let arcOuterStartAngle = startAngle + itemAngleSpacing * 0.5 * beforeSpacingFraction
                var outerEndAngle = startAngle + angleValue - itemAngleSpacing * 0.5
                outerEndAngle = max(outerEndAngle, outerStartAngle)
                var arcOuterEndAngle = startAngle + angleValue - itemAngleSpacing * 0.5 * afterSpacingFraction
                arcOuterEndAngle = max(arcOuterEndAngle, arcOuterStartAngle)
                
                let itemColor: UIColor = isEmpty ? emptyColor : item.color
                
                self.sections.append(CalculatedSection(
                    id: item.id,
                    color: itemColor,
                    particle: item.particle,
                    title: item.title,
                    innerAngle: arcInnerStartAngle ..< arcInnerEndAngle,
                    outerAngle: arcOuterStartAngle ..< arcOuterEndAngle,
                    innerRadius: innerDiameter * 0.5,
                    outerRadius: itemOuterDiameter * 0.5,
                    label: nil
                ))
                
                startAngle += angleValue
                
                anglesData.append(ItemAngleData(angleValue: angleValue, startAngle: innerStartAngle, endAngle: innerEndAngle))
            }
            
            for i in 0 ..< items.count {
                let item = items[i]
                
                var isDimmedBySelection = false
                if let selectedKey {
                    if selectedKey == AnyHashable(item.id) {
                    } else {
                        isDimmedBySelection = true
                    }
                }
                
                self.updateLabel(
                    index: i,
                    displayValue: item.displayValue,
                    mergeFactor: item.mergeFactor,
                    innerAngle: self.sections[i].innerAngle,
                    outerAngle: self.sections[i].outerAngle,
                    innerRadius: self.sections[i].innerRadius,
                    outerRadius: self.sections[i].outerRadius,
                    isDimmedBySelection: isDimmedBySelection
                )
            }
        }
        
        private mutating func updateLabel(
            index: Int,
            displayValue: Double,
            mergeFactor: CGFloat,
            innerAngle: Range<CGFloat>,
            outerAngle: Range<CGFloat>,
            innerRadius: CGFloat,
            outerRadius: CGFloat,
            isDimmedBySelection: Bool
        ) {
            let normalAlpha: CGFloat = isDimmedBySelection ? 0.0 : 1.0
            
            let fractionValue: Double = floor(displayValue * 100.0 * 10.0) / 10.0
            let fractionString: String
            if displayValue == 0.0 {
                fractionString = ""
            } else if fractionValue < 0.1 {
                fractionString = "<0.1%"
            } else if abs(Double(Int(fractionValue)) - fractionValue) < 0.001 {
                fractionString = "\(Int(fractionValue))%"
            } else {
                fractionString = "\(fractionValue)%"
            }
            
            let labelString = NSAttributedString(string: fractionString, font: chartLabelFont, textColor: .white)
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
                            alpha: 1.0 * normalAlpha,
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
                        alpha: (currentScale >= 0.4 ? 1.0 : 0.0) * normalAlpha,
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
        private let innerRadius: CGFloat
        private let maxRadius: CGFloat
        private(set) var particles: [Particle] = []
        
        init(innerRadius: CGFloat, maxRadius: CGFloat, preAdvance: Bool) {
            self.innerRadius = innerRadius
            self.maxRadius = maxRadius
            
            self.generateParticles(preAdvance: preAdvance)
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
            let radius = size.width * 0.5 + 10.0
            for i in (0 ..< self.particles.count).reversed() {
                self.particles[i].update(deltaTime: deltaTime)
                let position = self.particles[i].position
                
                let distance = sqrt(pow(position.x - size.width * 0.5, 2.0) + pow(position.y - size.height * 0.5, 2.0))
                if distance > radius {
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
        
        init(particle: String?) {
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
            
            if let particle {
                self.particleImage = UIImage(bundleImageName: particle)?.precomposed()
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
        
        func isPointOnGraph(point: CGPoint) -> Bool {
            if let path = self.maskLayer.path {
                return path.contains(point)
            }
            return false
        }
        
        func tooltipLocation() -> CGPoint {
            return self.labelLayer.position
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
        
        func updateParticles(particleSet: ParticleSet, alpha: CGFloat) {
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
                particleLayer.opacity = Float(particle.alpha * alpha)
            }
            if particleSet.particles.count < self.particleLayers.count {
                for i in particleSet.particles.count ..< self.particleLayers.count {
                    self.particleLayers[i].isHidden = true
                }
            }
        }
    }
    
    private final class DoneLayer: SimpleLayer {
        private let particleColor: UIColor
        private let maskShapeLayer: CAShapeLayer
        private var particleImage: UIImage?
        private var particleSet: ParticleSet?
        private var particleLayers: [SimpleLayer] = []
        
        init(particleColor: UIColor) {
            self.particleColor = particleColor
            
            self.maskShapeLayer = CAShapeLayer()
            self.maskShapeLayer.fillColor = UIColor.black.cgColor
            self.maskShapeLayer.fillRule = .evenOdd
            
            super.init()
            
            self.particleImage = UIImage(bundleImageName: "Settings/Storage/ParticleStar")?.precomposed()
            
            let path = CGMutablePath()
            
            path.addRect(CGRect(origin: CGPoint(x: 0.0, y: 0.0), size: CGSize(width: 200.0, height: 200.0)))
            path.addEllipse(in: CGRect(origin: CGPoint(x: floor((200.0 - 102.0) * 0.5), y: floor((200.0 - 102.0) * 0.5)), size: CGSize(width: 102.0, height: 102.0)))
            
            self.maskShapeLayer.path = path
            self.mask = self.maskShapeLayer
            
            self.particleSet = ParticleSet(innerRadius: 45.0, maxRadius: 100.0, preAdvance: true)
        }
        
        override init(layer: Any) {
            self.particleColor = .white
            self.maskShapeLayer = CAShapeLayer()
            
            super.init(layer: layer)
        }
        
        required init(coder: NSCoder) {
            preconditionFailure()
        }
        
        func updateParticles(deltaTime: CGFloat) {
            guard let particleSet = self.particleSet else {
                return
            }
            particleSet.update(deltaTime: deltaTime)
            
            let size = CGSize(width: 200.0, height: 200.0)
            
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
                    self.addSublayer(particleLayer)
                    
                    particleLayer.layerTintColor = self.particleColor.cgColor
                }
                
                particleLayer.position = particle.position
                particleLayer.transform = CATransform3DMakeScale(particle.scale * 1.2, particle.scale * 1.2, 1.0)
                
                let distance = sqrt(pow(particle.position.x - size.width * 0.5, 2.0) + pow(particle.position.y - size.height * 0.5, 2.0))
                var mulAlpha: CGFloat = 1.0
                let outerDistanceNorm: CGFloat = 20.0
                if distance > 100.0 - outerDistanceNorm {
                    let outerDistanceFactor: CGFloat = (100.0 - distance) / outerDistanceNorm
                    let alphaFactor: CGFloat = max(0.0, min(1.0, outerDistanceFactor))
                    mulAlpha = alphaFactor
                }
                
                particleLayer.opacity = Float(particle.alpha * mulAlpha)
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
        private var emptyColor: UIColor?
        private(set) var selectedKey: AnyHashable?
        
        private var currentAnimation: (start: CalculatedLayout, startTime: Double, duration: Double)?
        private var currentLayout: CalculatedLayout?
        private var animator: DisplayLinkAnimator?
        
        private var displayLink: SharedDisplayLinkDriver.Link?
        
        private var sectionLayers: [AnyHashable: SectionLayer] = [:]
        private let particleSet: ParticleSet
        private var doneLayer: DoneLayer?
        
        override init(frame: CGRect) {
            self.particleSet = ParticleSet(innerRadius: 50.0, maxRadius: 100.0, preAdvance: true)
            
            super.init(frame: frame)
            
            self.backgroundColor = nil
            self.isOpaque = false
            
            var previousTimestamp: Double?
            self.displayLink = SharedDisplayLinkDriver.shared.add(needsHighestFramerate: true, { [weak self] in
                let timestamp = CACurrentMediaTime()
                var delta: Double
                if let previousTimestamp {
                    delta = timestamp - previousTimestamp
                } else {
                    delta = 1.0 / 60.0
                }
                previousTimestamp = timestamp
                
                if delta < 0.0 {
                    delta = 1.0 / 60.0
                } else if delta > 0.5 {
                    delta = 1.0 / 60.0
                }
                
                self?.update(deltaTime: CGFloat(delta))
            })
        }
        
        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }
        
        deinit {
            self.animator?.invalidate()
        }
        
        func sectionKey(at point: CGPoint) -> AnyHashable? {
            for (id, itemLayer) in self.sectionLayers {
                if itemLayer.isPointOnGraph(point: point) {
                    return id
                }
            }
            return nil
        }
        
        func tooltipLocation(forKey key: AnyHashable) -> CGPoint? {
            for (id, itemLayer) in self.sectionLayers {
                if id == key {
                    return itemLayer.tooltipLocation()
                }
            }
            return nil
        }
        
        func setItems(theme: PresentationTheme, emptyColor: UIColor, data: ChartData, selectedKey: AnyHashable?, animated: Bool) {
            self.emptyColor = emptyColor
            
            let data = processChartData(data: data)
            
            if self.theme !== theme || self.data != data || self.selectedKey != selectedKey {
                self.theme = theme
                self.selectedKey = selectedKey
                let previousData = self.data
                
                if animated, let previous = self.currentLayout {
                    var initialState = previous
                    if let currentAnimation = self.currentAnimation {
                        let currentProgress: Double = max(0.0, min(1.0, (CACurrentMediaTime() - currentAnimation.startTime) / currentAnimation.duration))
                        let mappedProgress = listViewAnimationCurveSystem(CGFloat(currentProgress))
                        initialState = CalculatedLayout(interpolating: currentAnimation.start, to: previous, progress: mappedProgress, size: previous.size)
                    }
                    
                    let targetLayout: CalculatedLayout
                    if let previousData = previousData, data.items.isEmpty {
                        targetLayout = CalculatedLayout(
                            size: CGSize(width: 200.0, height: 200.0),
                            items: previousData.items,
                            selectedKey: self.selectedKey,
                            isEmpty: true,
                            emptyColor: emptyColor
                        )
                    } else {
                        targetLayout = CalculatedLayout(
                            size: CGSize(width: 200.0, height: 200.0),
                            items: data.items,
                            selectedKey: self.selectedKey,
                            isEmpty: false,
                            emptyColor: emptyColor
                        )
                    }
                    
                    self.currentLayout = targetLayout
                    self.currentAnimation = (initialState, CACurrentMediaTime(), 0.4)
                } else {
                    if data.items.isEmpty {
                        self.currentLayout = CalculatedLayout(
                            size: CGSize(width: 200.0, height: 200.0),
                            items: [.init(id: AnyHashable(StorageUsageScreenComponent.Category.other), displayValue: 0.0, displaySize: 0, value: 1.0, color: .green, particle: "Settings/Storage/ParticleOther", title: "", mergeable: false, mergeFactor: 1.0)],
                            selectedKey: self.selectedKey,
                            isEmpty: true,
                            emptyColor: emptyColor
                        )
                    } else {
                        self.currentLayout = CalculatedLayout(
                            size: CGSize(width: 200.0, height: 200.0),
                            items: data.items,
                            selectedKey: self.selectedKey,
                            isEmpty: data.items.isEmpty,
                            emptyColor: emptyColor
                        )
                    }
                }
                
                self.data = data
                
                self.update(deltaTime: 0.0)
            }
        }
        
        private func update(deltaTime: CGFloat) {
            self.particleSet.update(deltaTime: deltaTime)
            
            var validIds: [AnyHashable] = []
            if let currentLayout = self.currentLayout, let emptyColor = self.emptyColor {
                var effectiveLayout = currentLayout
                var verticalOffset: CGFloat = 0.0
                var particleAlpha: CGFloat = 1.0
                var rotationAngle: CGFloat = 0.0
                let emptyRotationAngle: CGFloat = CGFloat.pi
                let emptyVerticalOffset: CGFloat = (92.0 - 200.0) * 0.5
                if let currentAnimation = self.currentAnimation {
                    let currentProgress: Double = max(0.0, min(1.0, (CACurrentMediaTime() - currentAnimation.startTime) / currentAnimation.duration))
                    let mappedProgress = listViewAnimationCurveSystem(CGFloat(currentProgress))
                    
                    effectiveLayout = CalculatedLayout(interpolating: currentAnimation.start, to: currentLayout, progress: mappedProgress, size: currentLayout.size)
                    
                    let fromVerticalOffset: CGFloat
                    let fromRotationAngle: CGFloat
                    if currentAnimation.start.isEmpty {
                        fromVerticalOffset = emptyVerticalOffset
                        fromRotationAngle = emptyRotationAngle
                    } else {
                        fromVerticalOffset = 0.0
                        fromRotationAngle = 0.0
                    }
                    let toVerticalOffset: CGFloat
                    let toRotationAngle: CGFloat
                    if currentLayout.isEmpty {
                        toVerticalOffset = emptyVerticalOffset
                        toRotationAngle = emptyRotationAngle
                    } else {
                        toVerticalOffset = 0.0
                        toRotationAngle = 0.0
                    }
                    
                    verticalOffset = (1.0 - mappedProgress) * fromVerticalOffset + mappedProgress * toVerticalOffset
                    rotationAngle = (1.0 - mappedProgress) * fromRotationAngle + mappedProgress * toRotationAngle
                    
                    if currentLayout.isEmpty {
                        particleAlpha = 1.0 - mappedProgress
                    }
                    
                    if currentProgress >= 1.0 - CGFloat.ulpOfOne {
                        self.currentAnimation = nil
                    }
                } else {
                    if currentLayout.isEmpty {
                        verticalOffset = emptyVerticalOffset
                        particleAlpha = 0.0
                        rotationAngle = emptyRotationAngle
                    }
                }
                
                if currentLayout.isEmpty {
                    let doneLayer: DoneLayer
                    if let current = self.doneLayer {
                        doneLayer = current
                    } else {
                        doneLayer = DoneLayer(particleColor: emptyColor)
                        self.doneLayer = doneLayer
                        self.layer.insertSublayer(doneLayer, at: 0)
                    }
                    doneLayer.updateParticles(deltaTime: deltaTime)
                    doneLayer.frame = CGRect(origin: CGPoint(x: 0.0, y: verticalOffset), size: CGSize(width: 200.0, height: 200.0))
                    doneLayer.opacity = Float(1.0 - particleAlpha)
                } else {
                    if let doneLayer = self.doneLayer {
                        self.doneLayer = nil
                        doneLayer.removeFromSuperlayer()
                    }
                }
                
                for section in effectiveLayout.sections {
                    validIds.append(section.id)
                    
                    let sectionLayer: SectionLayer
                    if let current = self.sectionLayers[section.id] {
                        sectionLayer = current
                    } else {
                        sectionLayer = SectionLayer(particle: section.particle)
                        self.sectionLayers[section.id] = sectionLayer
                        self.layer.addSublayer(sectionLayer)
                    }
                    
                    let sectionLayerFrame = CGRect(origin: CGPoint(x: 0.0, y: verticalOffset), size: CGSize(width: 200.0, height: 200.0))
                    sectionLayer.position = sectionLayerFrame.center
                    sectionLayer.bounds = CGRect(origin: CGPoint(), size: sectionLayerFrame.size)
                    sectionLayer.transform = CATransform3DMakeRotation(rotationAngle, 0.0, 0.0, 1.0)
                    sectionLayer.update(size: sectionLayer.bounds.size, section: section)
                    sectionLayer.updateParticles(particleSet: self.particleSet, alpha: particleAlpha)
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
    }
    
    class View: UIView {
        private let dataView: ChartDataView
        private var tooltip: (key: AnyHashable, value: ComponentView<Empty>)?
        
        var selectedKey: AnyHashable?
        
        private var component: PieChartComponent?
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
                let point = recognizer.location(in: self.dataView)
                if let key = self.dataView.sectionKey(at: point), key != AnyHashable("empty") {
                    if self.selectedKey == key {
                        self.selectedKey = nil
                    } else {
                        self.selectedKey = key
                    }
                } else {
                    self.selectedKey = nil
                }
                self.state?.updated(transition: Transition(animation: .curve(duration: 0.3, curve: .spring)))
            }
        }
        
        func update(component: PieChartComponent, availableSize: CGSize, state: EmptyComponentState, environment: Environment<Empty>, transition: Transition) -> CGSize {
            let dataUpdated = self.component?.chartData != component.chartData
            
            self.state = state
            self.component = component
            
            if dataUpdated {
                self.selectedKey = nil
            }
            
            transition.setFrame(view: self.dataView, frame: CGRect(origin: CGPoint(x: floor((availableSize.width - 200.0) / 2.0), y: 0.0), size: CGSize(width: 200.0, height: 200.0)))
            self.dataView.setItems(theme: component.theme, emptyColor: component.emptyColor, data: component.chartData, selectedKey: self.selectedKey, animated: !transition.animation.isImmediate)
            
            if let selectedKey = self.selectedKey, let item = component.chartData.items.first(where: { $0.id == selectedKey }) {
                let tooltip: ComponentView<Empty>
                var tooltipTransition = transition
                var animateIn = false
                if let current = self.tooltip, current.key == AnyHashable(selectedKey) {
                    tooltip = current.value
                } else if let current = self.tooltip {
                    if let tooltipView = current.value.view {
                        transition.setAlpha(view: tooltipView, alpha: 0.0, completion: { [weak tooltipView] _ in
                            tooltipView?.removeFromSuperview()
                        })
                    }
                    tooltipTransition = .immediate
                    animateIn = true
                    tooltip = ComponentView()
                    self.tooltip = (selectedKey, tooltip)
                } else {
                    tooltipTransition = .immediate
                    animateIn = true
                    tooltip = ComponentView()
                    self.tooltip = (selectedKey, tooltip)
                }
                
                let fractionValue: Double = floor(item.displayValue * 100.0 * 10.0) / 10.0
                let fractionString: String
                if fractionValue < 0.1 {
                    fractionString = "<0.1%"
                } else if abs(Double(Int(fractionValue)) - fractionValue) < 0.001 {
                    fractionString = "\(Int(fractionValue))%"
                } else {
                    fractionString = "\(fractionValue)%"
                }
                
                let tooltipSize = tooltip.update(
                    transition: tooltipTransition,
                    component: AnyComponent(ChartSelectionTooltip(
                        theme: component.theme,
                        fractionText: fractionString,
                        title: item.title,
                        sizeText: dataSizeString(Int(item.displaySize), formatting: DataSizeStringFormatting(strings: component.strings, decimalSeparator: "."))
                    )),
                    environment: {},
                    containerSize: availableSize
                )
                
                if let relativeTooltipLocation = self.dataView.tooltipLocation(forKey: selectedKey) {
                    let tooltipLocation = relativeTooltipLocation.offsetBy(dx: self.dataView.frame.minX, dy: self.dataView.frame.minY)
                    let tooltipFrame = CGRect(origin: CGPoint(x: floor(tooltipLocation.x - tooltipSize.width / 2.0), y: tooltipLocation.y - 16.0 - tooltipSize.height), size: tooltipSize)
                    
                    if let tooltipView = tooltip.view {
                        if tooltipView.superview == nil {
                            self.addSubview(tooltipView)
                        }
                        tooltipTransition.setFrame(view: tooltipView, frame: tooltipFrame)
                        if animateIn {
                            transition.animateAlpha(view: tooltipView, from: 0.0, to: 1.0)
                            transition.animateScale(view: tooltipView, from: 0.8, to: 1.0)
                        }
                    }
                }
            } else {
                if let tooltip = self.tooltip {
                    self.tooltip = nil
                    if let tooltipView = tooltip.value.view {
                        transition.setAlpha(view: tooltipView, alpha: 0.0, completion: { [weak tooltipView] _ in
                            tooltipView?.removeFromSuperview()
                        })
                        transition.setScale(view: tooltipView, scale: 0.8)
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
