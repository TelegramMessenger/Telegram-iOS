import Foundation
import UIKit
import SwiftSignalKit
import Display
import AsyncDisplayKit
import AppBundle
import GraphCore
import TelegramPresentationData

public enum ChartType {
    case lines
    case twoAxis
    case pie
    case area
    case bars
    case step
    case twoAxisStep
    case hourlyStep
    case twoAxisHourlyStep
    case twoAxis5MinStep
}

public extension ChartTheme {    
    convenience init(presentationTheme: PresentationTheme) {
        let rangeViewFrameColor = presentationTheme.chart.rangeViewFrameColor
        let rangeViewMarkerColor = presentationTheme.chart.rangeViewMarkerColor
        
        let rangeImage = generateImage(CGSize(width: 114.0, height: 42.0), rotatedContext: { size, context in
            let bounds = CGRect(origin: CGPoint(), size: size)
            context.clear(bounds)
            
            context.setFillColor(rangeViewFrameColor.cgColor)
            var path = UIBezierPath.init(roundedRect: CGRect(x: 0.0, y: 0.0, width: 11.0, height: 42.0), byRoundingCorners: [.topLeft, .bottomLeft], cornerRadii: CGSize(width: 6.0, height: 6.0))
            context.addPath(path.cgPath)
            context.fillPath()
            
            path = UIBezierPath.init(roundedRect: CGRect(x: 103.0, y: 0.0, width: 11.0, height: 42.0), byRoundingCorners: [.topRight, .bottomRight], cornerRadii: CGSize(width: 6.0, height: 6.0))
            context.addPath(path.cgPath)
            context.fillPath()
            
            context.setFillColor(rangeViewFrameColor.cgColor)
            context.fill(CGRect(x: 7.0, y: 0.0, width: 4.0, height: 1.0))
            context.fill(CGRect(x: 7.0, y: 41.0, width: 4.0, height: 1.0))
            
            context.fill(CGRect(x: 100.0, y: 0.0, width: 4.0, height: 1.0))
            context.fill(CGRect(x: 100.0, y: 41.0, width: 4.0, height: 1.0))
            
            context.fill(CGRect(x: 11.0, y: 0.0, width: 92.0, height: 1.0))
            context.fill(CGRect(x: 11.0, y: 41.0, width: 92.0, height: 1.0))
            
            context.setLineCap(.round)
            context.setLineWidth(1.5)
            context.setStrokeColor(rangeViewMarkerColor.cgColor)
            context.move(to: CGPoint(x: 7.0, y: 17.0))
            context.addLine(to: CGPoint(x: 4.0, y: 21.0))
            context.addLine(to: CGPoint(x: 7.0, y: 25.0))
            context.strokePath()
            
            context.move(to: CGPoint(x: 107.0, y: 17.0))
            context.addLine(to: CGPoint(x: 110.0, y: 21.0))
            context.addLine(to: CGPoint(x: 107.0, y: 25.0))
            context.strokePath()
        })?.resizableImage(withCapInsets: UIEdgeInsets(top: 15.0, left: 11.0, bottom: 15.0, right: 11.0), resizingMode: .stretch)
        
        self.init(chartTitleColor: presentationTheme.list.itemPrimaryTextColor, actionButtonColor: presentationTheme.list.itemAccentColor, chartBackgroundColor: presentationTheme.list.itemBlocksBackgroundColor, chartLabelsColor: presentationTheme.chart.labelsColor, chartHelperLinesColor: presentationTheme.chart.helperLinesColor, chartStrongLinesColor: presentationTheme.chart.strongLinesColor, barChartStrongLinesColor: presentationTheme.chart.barStrongLinesColor, chartDetailsTextColor: presentationTheme.chart.detailsTextColor, chartDetailsArrowColor: presentationTheme.chart.detailsArrowColor, chartDetailsViewColor: presentationTheme.chart.detailsViewColor, rangeViewFrameColor: rangeViewFrameColor, rangeViewTintColor: presentationTheme.list.blocksBackgroundColor.withAlphaComponent(0.5), rangeViewMarkerColor: rangeViewMarkerColor, rangeCropImage: rangeImage)
    }
}

public func createChartController(_ data: String, type: ChartType, getDetailsData: @escaping (Date, @escaping (String?) -> Void) -> Void) -> BaseChartController? {
    var resultController: BaseChartController?
    if let data = data.data(using: .utf8) {
        ChartsDataManager.readChart(data: data, extraCopiesCount: 0, sync: true, success: { collection in
            let controller: BaseChartController
            switch type {
                case .lines:
                    controller = GeneralLinesChartController(chartsCollection: collection)
                    controller.isZoomable = false
                case .twoAxis:
                    controller = TwoAxisLinesChartController(chartsCollection: collection)
                    controller.isZoomable = false
                case .pie:
                    controller = PercentPieChartController(chartsCollection: collection, initiallyZoomed: true)
                case .area:
                    controller = PercentPieChartController(chartsCollection: collection, initiallyZoomed: false)
                case .bars:
                    controller = StackedBarsChartController(chartsCollection: collection)
                    controller.isZoomable = false
                case .step:
                    controller = StepBarsChartController(chartsCollection: collection)
                case .twoAxisStep:
                    controller = TwoAxisStepBarsChartController(chartsCollection: collection)
                case .hourlyStep:
                    controller = StepBarsChartController(chartsCollection: collection, hourly: true)
                    controller.isZoomable = false
                case .twoAxisHourlyStep:
                    let stepController = TwoAxisStepBarsChartController(chartsCollection: collection)
                    stepController.hourly = true
                    controller = stepController
                    controller.isZoomable = false
                case .twoAxis5MinStep:
                    let stepController = TwoAxisStepBarsChartController(chartsCollection: collection)
                    stepController.min5 = true
                    controller = stepController
                    controller.isZoomable = false
            }
            controller.getDetailsData = { date, completion in
                getDetailsData(date, { detailsData in
                    if let detailsData = detailsData, let data = detailsData.data(using: .utf8) {
                        ChartsDataManager.readChart(data: data, extraCopiesCount: 0, sync: true, success: { collection in
                            Queue.mainQueue().async {
                                completion(collection)
                            }
                        }) { error in
                            completion(nil)
                        }
                    } else {
                        completion(nil)
                    }
                })
            }
            resultController = controller
        }) { error in
            
        }
    }
    return resultController
}

public final class ChartNode: ASDisplayNode {
    private var chartView: ChartStackSection {
        return self.view as! ChartStackSection
    }
    
    public override init() {
        super.init()
        
        self.setViewBlock({
            return ChartStackSection()
        })
    }
        
    required public init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    public func setup(theme: ChartTheme, strings: ChartStrings) {
        self.chartView.apply(theme: theme, strings: strings, animated: false)
    }
    
    public func setup(controller: BaseChartController) {
        var displayRange = true
        if let controller = controller as? StepBarsChartController {
            displayRange = !controller.hourly
        }
        self.chartView.setup(controller: controller, displayRange: displayRange)
    }
    
    public func resetInteraction() {
        self.chartView.resetDetailsView()
    }
}
