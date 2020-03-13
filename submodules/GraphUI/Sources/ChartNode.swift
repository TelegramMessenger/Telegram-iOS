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
}

public extension ChartTheme {    
    convenience init(presentationTheme: PresentationTheme) {
        let tableBackgroundColor = UIColor(rgb: 0xefeff4)
        let rangeViewTintColor = UIColor(rgb: 0xefeff4)
            
        self.init(chartTitleColor: presentationTheme.list.itemPrimaryTextColor, actionButtonColor: presentationTheme.list.itemAccentColor, tableBackgroundColor: tableBackgroundColor, chartBackgroundColor: presentationTheme.list.itemBlocksBackgroundColor, tableSeparatorColor: presentationTheme.list.itemSecondaryTextColor, chartLabelsColor: presentationTheme.list.itemSecondaryTextColor, chartHelperLinesColor: presentationTheme.list.itemSecondaryTextColor, chartStrongLinesColor: presentationTheme.list.itemSecondaryTextColor, barChartStrongLinesColor: presentationTheme.list.itemSecondaryTextColor, chartDetailsTextColor: presentationTheme.list.itemSecondaryTextColor, chartDetailsArrowColor: presentationTheme.list.itemSecondaryTextColor, chartDetailsViewColor: presentationTheme.list.itemSecondaryTextColor, descriptionActionColor: presentationTheme.list.itemSecondaryTextColor,  rangeViewFrameColor: presentationTheme.list.itemSecondaryTextColor, rangeViewTintColor: rangeViewTintColor, rangeViewMarkerColor: UIColor.white)
    }
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
    
    public override func didLoad() {
        super.didLoad()
                
        self.view.disablesInteractiveTransitionGestureRecognizer = true
    }
    
    public func setupTheme(_ theme: ChartTheme) {
        self.chartView.apply(theme: ChartTheme.defaultDayTheme, animated: false)
    }
    
    public override func layout() {
        super.layout()
        
        self.chartView.setNeedsDisplay()
    }
    
    public func setup(_ data: String, type: ChartType, getDetailsData: @escaping (Date, @escaping (String?) -> Void) -> Void) {
        if let data = data.data(using: .utf8) {
            ChartsDataManager.readChart(data: data, extraCopiesCount: 0, sync: true, success: { [weak self] collection in
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
                if let strongSelf = self {
                    strongSelf.chartView.setup(controller: controller, title: "")
                }
            }) { error in
                
            }
        }
    }
    
    required public init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
