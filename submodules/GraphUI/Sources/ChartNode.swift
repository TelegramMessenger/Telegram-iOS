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
    case bars
    case step
    case twoAxisStep
    case hourlyStep
}

public extension ChartTheme {    
    convenience init(presentationTheme: PresentationTheme) {
        let tableBackgroundColor = UIColor(rgb: 0xefeff4)
        let rangeViewTintColor = UIColor(rgb: 0xefeff4)
            
        self.init(chartTitleColor: presentationTheme.list.itemPrimaryTextColor, actionButtonColor: presentationTheme.list.itemAccentColor, tableBackgroundColor: tableBackgroundColor, chartBackgroundColor: presentationTheme.list.itemBlocksBackgroundColor, tableSeparatorColor: presentationTheme.list.itemSecondaryTextColor, chartLabelsColor: presentationTheme.list.itemSecondaryTextColor, chartHelperLinesColor: presentationTheme.list.itemSecondaryTextColor, chartStrongLinesColor: presentationTheme.list.itemSecondaryTextColor, barChartStrongLinesColor: presentationTheme.list.itemSecondaryTextColor, chartDetailsTextColor: presentationTheme.list.itemSecondaryTextColor, chartDetailsArrowColor: presentationTheme.list.itemSecondaryTextColor, chartDetailsViewColor: presentationTheme.list.itemSecondaryTextColor, descriptionActionColor: presentationTheme.list.itemSecondaryTextColor,  rangeViewFrameColor: presentationTheme.list.itemSecondaryTextColor, rangeViewTintColor: rangeViewTintColor, rangeViewMarkerColor: UIColor.white)
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
                    controller = PercentPieChartController(chartsCollection: collection)
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
        
    public func setupTheme(_ theme: ChartTheme) {
        self.chartView.apply(theme: ChartTheme.defaultDayTheme, animated: false)
    }
    
    public func setup(controller: BaseChartController) {
        var displayRange = true
        if let controller = controller as? StepBarsChartController {
            displayRange = !controller.hourly
        }
        self.chartView.setup(controller: controller, displayRange: displayRange)
    }
    
    public override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        return super.hitTest(point, with: event)
    }
    
    required public init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
