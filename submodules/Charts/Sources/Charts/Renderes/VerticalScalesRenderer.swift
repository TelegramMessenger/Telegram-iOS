//
//  VerticalScalesRenderer.swift
//  GraphTest
//
//  Created by Andrei Salavei on 4/8/19.
//  Copyright © 2019 Andrei Salavei. All rights reserved.
//

import UIKit

class VerticalScalesRenderer: BaseChartRenderer {
    private var verticalLabelsAndLines: [LinesChartLabel] = []
    private var animatedVerticalLabelsAndLines: [AnimatedLinesChartLabels] = []
    private lazy var horizontalLinesAlphaAnimator: AnimationController<CGFloat> = {
        return AnimationController(current: 1, refreshClosure: self.refreshClosure)
    }()
    
    var drawAxisX: Bool = true
    var axisXColor: UIColor = .black
    var axisXWidth: CGFloat = UIView.oneDevicePixel
    
    var isRightAligned: Bool = false
    
    var horizontalLinesColor: UIColor = .black {
        didSet {
            setNeedsDisplay()
        }
    }
    var horizontalLinesWidth: CGFloat = UIView.oneDevicePixel
    var lavelsAsisOffset: CGFloat = 6
    var labelsColor: UIColor = .black {
        didSet {
            setNeedsDisplay()
        }
    }
    var labelsFont: UIFont = .systemFont(ofSize: 11)

    func setHorizontalLinesVisible(_ visible: Bool, animated: Bool) {
        let destinationValue: CGFloat = visible ? 1 : 0
        guard self.horizontalLinesAlphaAnimator.end != destinationValue else { return }
        if animated {
            self.horizontalLinesAlphaAnimator.animate(to: destinationValue, duration: .defaultDuration)
        } else {
            self.horizontalLinesAlphaAnimator.set(current: destinationValue)
        }
    }

    func setup(verticalLimitsLabels: [LinesChartLabel], animated: Bool) {
        if animated {
            var labelsToKeepVisible: [LinesChartLabel] = []
            let labelsToHide: [LinesChartLabel]
            var labelsToShow: [LinesChartLabel] = []
            
            for label in verticalLimitsLabels {
                if verticalLabelsAndLines.contains(label) {
                    labelsToKeepVisible.append(label)
                } else {
                    labelsToShow.append(label)
                }
            }
            labelsToHide = verticalLabelsAndLines.filter { !verticalLimitsLabels.contains($0) }
            animatedVerticalLabelsAndLines.removeAll(where: { $0.isAppearing })
            verticalLabelsAndLines = labelsToKeepVisible
            
            let showAnimation = AnimatedLinesChartLabels(labels: labelsToShow, alphaAnimator: AnimationController(current: 1.0, refreshClosure: refreshClosure))
            showAnimation.isAppearing = true
            showAnimation.alphaAnimator.set(current: 0)
            showAnimation.alphaAnimator.animate(to: 1, duration: .defaultDuration)
            showAnimation.alphaAnimator.completionClosure = { [weak self, weak showAnimation] in
                guard let self = self, let showAnimation = showAnimation else { return }
                self.animatedVerticalLabelsAndLines.removeAll(where: { $0 === showAnimation })
                self.verticalLabelsAndLines = verticalLimitsLabels
            }
            
            let hideAnimation = AnimatedLinesChartLabels(labels: labelsToHide, alphaAnimator: AnimationController(current: 1.0, refreshClosure: refreshClosure))
            hideAnimation.isAppearing = false
            hideAnimation.alphaAnimator.set(current: 1)
            hideAnimation.alphaAnimator.animate(to: 0, duration: .defaultDuration)
            hideAnimation.alphaAnimator.completionClosure = { [weak self, weak hideAnimation] in
                guard let self = self, let hideAnimation = hideAnimation else { return }
                self.animatedVerticalLabelsAndLines.removeAll(where: { $0 === hideAnimation })
            }
            
            animatedVerticalLabelsAndLines.append(showAnimation)
            animatedVerticalLabelsAndLines.append(hideAnimation)
        } else {
            verticalLabelsAndLines = verticalLimitsLabels
            animatedVerticalLabelsAndLines = []
        }
    }
    
    override func render(context: CGContext, bounds: CGRect, chartFrame: CGRect) {
        guard isEnabled && verticalRange.current.distance > 0 && verticalRange.current.distance > 0 else { return }
        let generalAlpha = chartAlphaAnimator.current
        if generalAlpha == 0 { return }
        let labelColorAlpha = labelsColor.alphaValue
        
        func drawLines(_ labels: [LinesChartLabel], alpha: CGFloat) {
            var lineSegments: [CGPoint] = []
            let x0 = chartFrame.minX
            let x1 = chartFrame.maxX
            
            context.setStrokeColor(horizontalLinesColor.withAlphaComponent(horizontalLinesColor.alphaValue * alpha).cgColor)
            
            for lineInfo in labels {
                let y = transform(toChartCoordinateVertical: lineInfo.value, chartFrame: chartFrame).roundedUpToPixelGrid()
                lineSegments.append(CGPoint(x: x0, y: y))
                lineSegments.append(CGPoint(x: x1, y: y))
            }
            context.strokeLineSegments(between: lineSegments)
        }
        
        func drawVerticalLabels(_ labels: [LinesChartLabel], attributes: [NSAttributedString.Key: Any]) {
            if isRightAligned {
                for label in labels {
                    let y = transform(toChartCoordinateVertical: label.value, chartFrame: chartFrame) - labelsFont.pointSize - lavelsAsisOffset
                    
                    let rect = (label.text as NSString).boundingRect(with: bounds.size,
                                                                     options: .usesLineFragmentOrigin,
                                                                     attributes: attributes,
                                                                     context: nil)
                    
                    (label.text as NSString).draw(at: CGPoint(x:chartFrame.maxX - rect.width, y: y), withAttributes: attributes)
                }
            } else {
                for label in labels {
                    let y = transform(toChartCoordinateVertical: label.value, chartFrame: chartFrame) - labelsFont.pointSize - lavelsAsisOffset
                    
                    (label.text as NSString).draw(at: CGPoint(x:chartFrame.minX, y: y), withAttributes: attributes)
                }
            }
        }
        
        let horizontalLinesAlpha = horizontalLinesAlphaAnimator.current
        if horizontalLinesAlpha > 0 {
            context.setLineWidth(horizontalLinesWidth)
            
            drawLines(verticalLabelsAndLines, alpha: generalAlpha)
            for animatedLabesAndLines in animatedVerticalLabelsAndLines {
                drawLines(animatedLabesAndLines.labels, alpha: animatedLabesAndLines.alphaAnimator.current * generalAlpha * horizontalLinesAlpha)
            }
            
            if drawAxisX {
                context.setLineWidth(axisXWidth)
                context.setStrokeColor(axisXColor.withAlphaComponent(axisXColor.alphaValue * horizontalLinesAlpha * generalAlpha).cgColor)
                
                let lineSegments: [CGPoint] = [CGPoint(x: chartFrame.minX, y: chartFrame.maxY.roundedUpToPixelGrid()),
                                               CGPoint(x: chartFrame.maxX, y: chartFrame.maxY.roundedUpToPixelGrid())]
                
                context.strokeLineSegments(between: lineSegments)
            }
        }
        
        drawVerticalLabels(verticalLabelsAndLines, attributes: [.foregroundColor: labelsColor.withAlphaComponent(labelColorAlpha * generalAlpha),
                                                                .font: labelsFont])
        for animatedLabesAndLines in animatedVerticalLabelsAndLines {
            drawVerticalLabels(animatedLabesAndLines.labels,
                               attributes: [.foregroundColor: labelsColor.withAlphaComponent(animatedLabesAndLines.alphaAnimator.current * labelColorAlpha * generalAlpha),
                                            .font: labelsFont])
        }
    }
}
