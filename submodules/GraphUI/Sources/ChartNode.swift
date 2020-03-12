import Foundation
import UIKit
import SwiftSignalKit
import Display
import AsyncDisplayKit
import AppBundle
import GraphCore

public enum ChartType {
    case lines
    case twoAxis
    case pie
    case bars
    case step
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
    
    public func setup(_ data: String, type: ChartType, getDetailsData: @escaping (Date, @escaping (String?) -> Void) -> Void) {
        if let data = data.data(using: .utf8) {
            ChartsDataManager.readChart(data: data, extraCopiesCount: 0, sync: true, success: { [weak self] collection in
                let controller: BaseChartController
                switch type {
                    case .lines:
                        controller = GeneralLinesChartController(chartsCollection: collection)
                    case .twoAxis:
                        controller = TwoAxisLinesChartController(chartsCollection: collection)
                    case .pie:
                        controller = PercentPieChartController(chartsCollection: collection)
                    case .bars:
                        controller = StackedBarsChartController(chartsCollection: collection)
                    case .step:
                        controller = StepBarsChartController(chartsCollection: collection)
                }
                controller.getDetailsData = { date, completion in
                    getDetailsData(date, { detailsData in
                        if let detailsData = detailsData, let data = detailsData.data(using: .utf8) {
                            ChartsDataManager.readChart(data: data, extraCopiesCount: 0, sync: true, success: { [weak self] collection in
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
