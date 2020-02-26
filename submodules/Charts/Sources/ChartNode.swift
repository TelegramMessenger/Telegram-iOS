import Foundation
import UIKit
import Display
import AsyncDisplayKit
import AppBundle

public enum ChartType {
    case lines
    case twoAxis
    case pie
    case bars
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
    
    public func setup(_ data: String, type: ChartType, getDetailsData: @escaping (Date, (String?) -> Void) -> Void) {
        if let data = data.data(using: .utf8) {
            ChartsDataManager().readChart(data: data, extraCopiesCount: 0, sync: true, success: { [weak self] collection in
                let controller: BaseChartController
                switch type {
                    case .lines:
                        controller = GeneralLinesChartController(chartsCollection: collection)
                        controller.getDetailsData = { date, completion in
                            getDetailsData(date, { detailsData in
                                if let detailsData = detailsData, let data = detailsData.data(using: .utf8) {
                                    ChartsDataManager().readChart(data: data, extraCopiesCount: 0, sync: true, success: { [weak self] collection in
                                        completion(collection)
                                    }) { error in
                                        completion(nil)
                                    }
                                } else {
                                    completion(nil)
                                }
                            })
                        }
                    case .twoAxis:
                        controller = TwoAxisLinesChartController(chartsCollection: collection)
                    case .pie:
                        controller = PercentPieChartController(chartsCollection: collection)
                    case .bars:
                        controller = StackedBarsChartController(chartsCollection: collection)
                }
                if let strongSelf = self {
                    strongSelf.chartView.setup(controller: controller, title: "")
                    strongSelf.chartView.apply(colorMode: .day, animated: false)
                }
            }) { error in
                
            }
        }
    }
    
    required public init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
