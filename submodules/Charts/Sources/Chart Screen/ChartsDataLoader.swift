//
//  ChartsDataLoader.swift
//  GraphTest
//
//  Created by Andrei Salavei on 4/8/19.
//  Copyright © 2019 Andrei Salavei. All rights reserved.
//

import Foundation

enum ChartsDataType: String {
    case generalLines = "1"
    case twoAxisLines = "2"
    case stackedBars = "3"
    case dailyBars = "4"
    case percentPie = "5"
}

private enum Constants {
    static let overviewFilename = "overview.json"
    static let dataDir = "data"
}

class ChartsDataLoader {
    static var documentDirectoryURL: URL {
        let paths = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)
        let documentsDirectory = paths[0]
        return documentsDirectory
    }
    
    static func overviewData(type: ChartsDataType, extraCopiesCount: Int = 0, sync: Bool = false, success: @escaping (ChartsCollection) -> Void) {
        let path = Bundle.main.bundleURL
            .appendingPathComponent(Constants.dataDir)
            .appendingPathComponent(type.rawValue)
            .appendingPathComponent(Constants.overviewFilename)
        ChartsDataManager().readChart(file: path, extraCopiesCount: extraCopiesCount, sync: sync, success: success, failure: { _ in })
    }
    
    static func detaildData(type: ChartsDataType, extraCopiesCount: Int = 0, date: Date, success: @escaping (ChartsCollection) -> Void, failure: @escaping (Error) -> Void) {
        let dateComponents = Calendar.utc.dateComponents([.day, .month, .year], from: date)
        let yearMonth = String(format: "%04d-%02d", dateComponents.year ?? 0, dateComponents.month ?? 0)
        let day = String(format: "%02d.json", dateComponents.day ?? 0)
        
        let path = Bundle.main.bundleURL
            .appendingPathComponent(Constants.dataDir)
            .appendingPathComponent(type.rawValue)
            .appendingPathComponent(yearMonth)
            .appendingPathComponent(day)
        ChartsDataManager().readChart(file: path, extraCopiesCount: extraCopiesCount, sync: false, success: success, failure: failure)
    }
}
