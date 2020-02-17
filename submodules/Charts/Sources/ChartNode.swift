import Foundation
import UIKit
import Display
import AsyncDisplayKit
import AppBundle

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
    
    public func setup(_ data: String, bar: Bool = false) {
        if let data = data.data(using: .utf8) {
            ChartsDataManager().readChart(data: data, extraCopiesCount: 0, sync: true, success: { [weak self] collection in
                let controller: BaseChartController
                if bar {
                    controller = DailyBarsChartController(chartsCollection: collection)
                } else {
                    controller = GeneralLinesChartController(chartsCollection: collection)
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
