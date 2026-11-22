//
//  ChardData.swift
//  GraphTest
//
//  Created by Andrei Salavei on 3/11/19.
//  Copyright © 2019 Andrei Salavei. All rights reserved.
//

import Foundation
#if os(macOS)
import Cocoa
#else
import UIKit
#endif
import Foundation
#if os(macOS)
import Cocoa
#else
import UIKit
#endif

public struct ChartsCollection {
    public struct Chart {
        public internal(set) var color: GColor
        public internal(set) var name: String
        public internal(set) var values: [Double]
    }
    
    public internal(set) var axisValues: [Date]
    public internal(set) var chartValues: [Chart]
    
    static let blank = ChartsCollection(axisValues: [], chartValues: [])
    var isBlank: Bool {
        return axisValues.isEmpty || chartValues.isEmpty
    }
}

public extension ChartsCollection {
    init(from decodedData: [String: Any]) throws {
        guard let columns = decodedData["columns"] as? [[Any]] else {
            throw ChartsError.generalConversion("Unable to get columns from: \(decodedData)")
        }
        guard let types = decodedData["types"] as? [String: String] else {
            throw ChartsError.generalConversion("Unable to get types from: \(decodedData)")
        }
        guard let names = decodedData["names"] as? [String: String] else {
            throw ChartsError.generalConversion("Unable to get names from: \(decodedData)")
        }
        guard let colors = decodedData["colors"] as? [String: String] else {
            throw ChartsError.generalConversion("Unable to get colors from: \(decodedData)")
        }
        
//        chart.colors – Color for each variable in 6-hex-digit format (e.g. "#AAAAAA").
//        chart.names – Name for each variable.
//        chart.percentage – true for percentage based values.
//        chart.stacked – true for values stacking on top of each other.
//        chart.y_scaled – true for charts with 2 Y axes.
        
        var axixValuesToSetup: [Date] = []
        var chartToSetup: [Chart] = []
        for column in columns {
            guard let columnId = column.first as? String else {
                throw ChartsError.generalConversion("Unable to get column name from: \(column)")
            }
            guard let typeString = types[columnId], let type = ColumnType(rawValue: typeString) else {
                throw ChartsError.generalConversion("Unable to get column type from: \(types) - \(columnId)")
            }
            switch type {
            case .axix:
                axixValuesToSetup = try column.dropFirst().map { value in
                    let numberValue = try Convert.doubleFrom(value)
                    if numberValue < 24.0 {
                        return Date(timeIntervalSince1970: numberValue)
                    } else {
                        return Date(timeIntervalSince1970: numberValue / 1000)
                    }
                    
                }
            case .chart, .bar, .area, .step:
                guard let colorString = colors[columnId],
                    let color = GColor(hexString: colorString) else {
                        throw ChartsError.generalConversion("Unable to get color name from: \(colors) - \(columnId)")
                }
                guard let name = names[columnId] else {
                    throw ChartsError.generalConversion("Unable to get column name from: \(names) - \(columnId)")
                }
                let values = try column.dropFirst().map { try Convert.doubleFrom($0) }
                chartToSetup.append(Chart(color: color,
                                          name: name,
                                          values: values))
            }
        }
        
        guard axixValuesToSetup.isEmpty == false,
            chartToSetup.isEmpty == false,
            chartToSetup.firstIndex(where: { $0.values.count != axixValuesToSetup.count }) == nil else {
                throw ChartsError.generalConversion("Saniazing: Invalid number of items: \(axixValuesToSetup), \(chartToSetup)")
        }
        self.axisValues = axixValuesToSetup
        self.chartValues = chartToSetup
        
    }
}

private enum ColumnType: String {
    case axix = "x"
    case chart = "line"
    case area = "area"
    case bar = "bar"
    case step = "step"
}
