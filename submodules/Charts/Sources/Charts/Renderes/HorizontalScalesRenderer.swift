//
//  HorizontalScalesRenderer.swift
//  GraphTest
//
//  Created by Andrei Salavei on 4/8/19.
//  Copyright © 2019 Andrei Salavei. All rights reserved.
//

import UIKit

class HorizontalScalesRenderer: BaseChartRenderer {
    private var horizontalLabels: [LinesChartLabel] = []
    private var animatedHorizontalLabels: [AnimatedLinesChartLabels] = []
    
    var labelsVerticalOffset: CGFloat = 8
    var labelsFont: UIFont = .systemFont(ofSize: 11)
    var labelsColor: UIColor = .gray
    
    func setup(labels: [LinesChartLabel], animated: Bool) {
        if animated {
            var labelsToKeepVisible: [LinesChartLabel] = []
            let labelsToHide: [LinesChartLabel]
            var labelsToShow: [LinesChartLabel] = []
            
            for label in labels {
                if horizontalLabels.contains(label) {
                    labelsToKeepVisible.append(label)
                } else {
                    labelsToShow.append(label)
                }
            }
            labelsToHide = horizontalLabels.filter { !labels.contains($0) }
            animatedHorizontalLabels.removeAll()
            horizontalLabels = labelsToKeepVisible
            
            let showAnimation = AnimatedLinesChartLabels(labels: labelsToShow, alphaAnimator: AnimationController(current: 1.0, refreshClosure: refreshClosure))
            showAnimation.isAppearing = true
            showAnimation.alphaAnimator.set(current: 0)
            showAnimation.alphaAnimator.animate(to: 1, duration: .defaultDuration)
            showAnimation.alphaAnimator.completionClosure = { [weak self, weak showAnimation] in
                guard let self = self, let showAnimation = showAnimation else { return }
                self.animatedHorizontalLabels.removeAll(where: { $0 === showAnimation })
                self.horizontalLabels = labels
            }
            
            let hideAnimation = AnimatedLinesChartLabels(labels: labelsToHide, alphaAnimator: AnimationController(current: 1.0, refreshClosure: refreshClosure))
            hideAnimation.isAppearing = false
            hideAnimation.alphaAnimator.set(current: 1)
            hideAnimation.alphaAnimator.animate(to: 0, duration: .defaultDuration)
            hideAnimation.alphaAnimator.completionClosure = { [weak self, weak hideAnimation] in
                guard let self = self, let hideAnimation = hideAnimation else { return }
                self.animatedHorizontalLabels.removeAll(where: { $0 === hideAnimation })
            }
            
            animatedHorizontalLabels.append(showAnimation)
            animatedHorizontalLabels.append(hideAnimation)
        } else {
            horizontalLabels = labels
            animatedHorizontalLabels = []
        }
    }
    
    override func render(context: CGContext, bounds: CGRect, chartFrame: CGRect) {
        guard isEnabled && verticalRange.current.distance > 0 && verticalRange.current.distance > 0 else { return }
        let itemsAlpha = chartAlphaAnimator.current
        guard itemsAlpha > 0 else { return }

        let range = renderRange(bounds: bounds, chartFrame: chartFrame)

        func drawHorizontalLabels(_ labels: [LinesChartLabel], color: UIColor) {
            let attributes: [NSAttributedString.Key : Any] = [.foregroundColor: color,
                                                              .font: labelsFont]
            let y = chartFrame.origin.y + chartFrame.height + labelsVerticalOffset
            
            if let start = labels.firstIndex(where: { $0.value > range.lowerBound }) {
                for index in start..<labels.count {
                    let label = labels[index]
                    
                    let x = transform(toChartCoordinateHorizontal: label.value, chartFrame: chartFrame)
                    
                    let rect = (label.text as NSString).boundingRect(with: bounds.size,
                                                                     options: .usesLineFragmentOrigin,
                                                                     attributes: attributes,
                                                                     context: nil)
                    (label.text as NSString).draw(at: CGPoint(x: x - rect.width, y: y), withAttributes: attributes)
                    if label.value > range.upperBound {
                        break
                    }
                }
            }
        }
        let labelColorAlpha = labelsColor.alphaValue * itemsAlpha
        drawHorizontalLabels(horizontalLabels, color: labelsColor.withAlphaComponent(labelColorAlpha * itemsAlpha))
        for animation in animatedHorizontalLabels {
            let color = labelsColor.withAlphaComponent(animation.alphaAnimator.current * labelColorAlpha)
            drawHorizontalLabels(animation.labels, color: color)
        }
    }
}
