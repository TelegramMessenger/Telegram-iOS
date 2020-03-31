//
//  theme.swift
//  GraphTest
//
//  Created by Andrew Solovey on 15/03/2019.
//  Copyright © 2019 Andrei Salavei. All rights reserved.
//

import Foundation
#if os(macOS)
import Cocoa
#else
import UIKit
#endif

#if os(iOS)
public typealias GColor = UIColor
#else
public typealias GColor = NSColor
#endif

#if os(iOS)
typealias NSEdgeInsets = UIEdgeInsets
#endif

public protocol ChartThemeContainer {
    func apply(theme: ChartTheme, strings: ChartStrings, animated: Bool)
}

public class ChartStrings {
    public let zoomOut: String
    public let total: String
    
    public init(zoomOut: String, total: String) {
        self.zoomOut = zoomOut
        self.total = total
    }
    
    public static var defaultStrings = ChartStrings(zoomOut: "Zoom Out", total: "Total")
}

public class ChartTheme {    
    public let chartTitleColor: GColor
    public let actionButtonColor: GColor
    public let chartBackgroundColor: GColor
    public let chartLabelsColor: GColor
    public let chartHelperLinesColor: GColor
    public let chartStrongLinesColor: GColor
    public let barChartStrongLinesColor: GColor
    public let chartDetailsTextColor: GColor
    public let chartDetailsArrowColor: GColor
    public let chartDetailsViewColor: GColor
    public let rangeViewTintColor: GColor
    public let rangeViewFrameColor: GColor
    public let rangeViewMarkerColor: GColor
    public let rangeCropImage: GImage?
    
    public init(chartTitleColor: GColor, actionButtonColor: GColor, chartBackgroundColor: GColor, chartLabelsColor: GColor, chartHelperLinesColor: GColor, chartStrongLinesColor: GColor, barChartStrongLinesColor: GColor, chartDetailsTextColor: GColor, chartDetailsArrowColor: GColor, chartDetailsViewColor: GColor, rangeViewFrameColor: GColor, rangeViewTintColor: GColor, rangeViewMarkerColor: GColor, rangeCropImage: GImage?) {
        self.chartTitleColor = chartTitleColor
        self.actionButtonColor = actionButtonColor
        self.chartBackgroundColor = chartBackgroundColor
        self.chartLabelsColor = chartLabelsColor
        self.chartHelperLinesColor = chartHelperLinesColor
        self.chartStrongLinesColor = chartStrongLinesColor
        self.barChartStrongLinesColor = barChartStrongLinesColor
        self.chartDetailsTextColor = chartDetailsTextColor
        self.chartDetailsArrowColor = chartDetailsArrowColor
        self.chartDetailsViewColor = chartDetailsViewColor
        self.rangeViewFrameColor = rangeViewFrameColor
        self.rangeViewTintColor = rangeViewTintColor
        self.rangeViewMarkerColor = rangeViewMarkerColor
        self.rangeCropImage = rangeCropImage
    }
    
    public static var defaultDayTheme = ChartTheme(chartTitleColor: GColor.black, actionButtonColor: GColor(red: 53/255.0, green: 120/255.0, blue: 246/255.0, alpha: 1.0), chartBackgroundColor: GColor(red: 254/255.0, green: 254/255.0, blue: 254/255.0, alpha: 1.0), chartLabelsColor: GColor(red: 37/255.0, green: 37/255.0, blue: 41/255.0, alpha: 0.5), chartHelperLinesColor: GColor(red: 24/255.0, green: 45/255.0, blue: 59/255.0, alpha: 0.1), chartStrongLinesColor: GColor(red: 24/255.0, green: 45/255.0, blue: 59/255.0, alpha: 0.35), barChartStrongLinesColor: GColor(red: 37/255.0, green: 37/255.0, blue: 41/255.0, alpha: 0.2), chartDetailsTextColor: GColor(red: 109/255.0, green: 109/255.0, blue: 114/255.0, alpha: 1.0), chartDetailsArrowColor: GColor(red: 197/255.0, green: 199/255.0, blue: 205/255.0, alpha: 1.0), chartDetailsViewColor: GColor(red: 245/255.0, green: 245/255.0, blue: 251/255.0, alpha: 1.0), rangeViewFrameColor: GColor(red: 202/255.0, green: 212/255.0, blue: 222/255.0, alpha: 1.0), rangeViewTintColor: GColor(red: 239/255.0, green: 239/255.0, blue: 244/255.0, alpha: 0.5), rangeViewMarkerColor: GColor.white, rangeCropImage: GImage(named: "selection_frame_light"))

    
    public static var defaultNightTheme = ChartTheme(chartTitleColor: GColor.white, actionButtonColor: GColor(red: 84/255.0, green: 164/255.0, blue: 247/255.0, alpha: 1.0), chartBackgroundColor: GColor(red: 34/255.0, green: 47/255.0, blue: 63/255.0, alpha: 1.0), chartLabelsColor: GColor(red: 186/255.0, green: 204/255.0, blue: 225/255.0, alpha: 0.6), chartHelperLinesColor: GColor(red: 133/255.0, green: 150/255.0, blue: 171/255.0, alpha: 0.20), chartStrongLinesColor: GColor(red: 186/255.0, green: 204/255.0, blue: 225/255.0, alpha: 0.45), barChartStrongLinesColor: GColor(red: 186/255.0, green: 204/255.0, blue: 225/255.0, alpha: 0.45), chartDetailsTextColor: GColor(red: 254/255.0, green: 254/255.0, blue: 254/255.0, alpha: 1.0), chartDetailsArrowColor: GColor(red: 76/255.0, green: 84/255.0, blue: 96/255.0, alpha: 1.0), chartDetailsViewColor: GColor(red: 25/255.0, green: 35/255.0, blue: 47/255.0, alpha: 1.0), rangeViewFrameColor: GColor(red: 53/255.0, green: 70/255.0, blue: 89/255.0, alpha: 1.0), rangeViewTintColor: GColor(red: 24/255.0, green: 34/255.0, blue: 45/255.0, alpha: 0.5), rangeViewMarkerColor: GColor.white, rangeCropImage: GImage(named: "selection_frame_dark"))
}
