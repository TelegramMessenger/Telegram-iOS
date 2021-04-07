//
//  ChartsDataManager.swift
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

public class ChartsDataManager {
    public static func readChart(item: [String: Any], extraCopiesCount: Int = 0, sync: Bool, success: @escaping (ChartsCollection) -> Void, failure: @escaping (Error) -> Void) {
        let workItem: (() -> Void) = {
            do {
                var collection = try ChartsCollection(from: item)
                for _ in 0..<extraCopiesCount {
                    for valueIndex in collection.chartValues.indices {
                        collection.chartValues[valueIndex] .values += collection.chartValues[valueIndex].values
                    }
                    guard let firstValue = collection.axisValues.first,
                        let lastValule =  collection.axisValues.last else {
                            throw ChartsError.invalidJson
                    }
                    let startItem = lastValule.addingTimeInterval(.day)
                    for valueIndex in collection.axisValues.indices {
                        let intervalToAdd = collection.axisValues[valueIndex].timeIntervalSince(firstValue)
                        let newDate = startItem.addingTimeInterval(intervalToAdd)
                        collection.axisValues.append(newDate)
                    }
                }
                if sync {
                    success(collection)
                } else {
                    DispatchQueue.main.async {
                        success(collection)
                    }
                }
            } catch {
                DispatchQueue.main.async {
                    assertionFailure("Error occure: \(error)")
                    failure(error)
                }
            }
        }
        
        if sync {
            workItem()
        } else {
            DispatchQueue.global().async(execute: workItem)
        }
    }
    
    public static func readChart(data: Data, extraCopiesCount: Int = 0, sync: Bool, success: @escaping (ChartsCollection) -> Void, failure: @escaping (Error) -> Void) {
        let workItem: (() -> Void) = {
            do {
                let decoded = try JSONSerialization.jsonObject(with: data, options: [])
                guard let item = decoded as? [String: Any] else {
                    throw ChartsError.invalidJson
                }
                var collection = try ChartsCollection(from: item)
                for _ in 0..<extraCopiesCount {
                    for valueIndex in collection.chartValues.indices {
                        collection.chartValues[valueIndex] .values += collection.chartValues[valueIndex].values
                    }
                    guard let firstValue = collection.axisValues.first,
                        let lastValule =  collection.axisValues.last else {
                            throw ChartsError.invalidJson
                    }
                    let startItem = lastValule.addingTimeInterval(.day)
                    for valueIndex in collection.axisValues.indices {
                        let intervalToAdd = collection.axisValues[valueIndex].timeIntervalSince(firstValue)
                        let newDate = startItem.addingTimeInterval(intervalToAdd)
                        collection.axisValues.append(newDate)
                    }
                }
                if sync {
                    success(collection)
                } else {
                    DispatchQueue.main.async {
                        success(collection)
                    }
                }
            } catch {
                DispatchQueue.main.async {
                    assertionFailure("Error occure: \(error)")
                    failure(error)
                }
            }
        }
        
        if sync {
            workItem()
        } else {
            DispatchQueue.global().async(execute: workItem)
        }
    }
    
    public static func readChart(file: URL, extraCopiesCount: Int = 0, sync: Bool, success: @escaping (ChartsCollection) -> Void, failure: @escaping (Error) -> Void) {
        let workItem: (() -> Void) = {
            do {
                let data = try Data(contentsOf: file)
                let decoded = try JSONSerialization.jsonObject(with: data, options: [])
                guard let item = decoded as? [String: Any] else {
                    throw ChartsError.invalidJson
                }
                var collection = try ChartsCollection(from: item)
                for _ in 0..<extraCopiesCount {
                    for valueIndex in collection.chartValues.indices {
                        collection.chartValues[valueIndex] .values += collection.chartValues[valueIndex].values
                    }
                    guard let firstValue = collection.axisValues.first,
                        let lastValule =  collection.axisValues.last else {
                            throw ChartsError.invalidJson
                    }
                    let startItem = lastValule.addingTimeInterval(.day)
                    for valueIndex in collection.axisValues.indices {
                        let intervalToAdd = collection.axisValues[valueIndex].timeIntervalSince(firstValue)
                        let newDate = startItem.addingTimeInterval(intervalToAdd)
                        collection.axisValues.append(newDate)
                    }
                }
                if sync {
                    success(collection)
                } else {
                    DispatchQueue.main.async {
                        success(collection)
                    }
                }
            } catch {
                DispatchQueue.main.async {
                    assertionFailure("Error occure: \(error)")
                    failure(error)
                }
            }
        }
        
        if sync {
            workItem()
        } else {
            DispatchQueue.global().async(execute: workItem)
        }
    }
    
    public static func readCharts(file: URL, extraCopiesCount: Int = 0, sync: Bool, success: @escaping ([ChartsCollection]) -> Void, failure: @escaping (Error) -> Void) {
        let workItem: (() -> Void) = {
            do {
                let data = try Data(contentsOf: file)
                let decoded = try JSONSerialization.jsonObject(with: data, options: [])
                guard let items = decoded as? [[String: Any]] else {
                    throw ChartsError.invalidJson
                }
                var collections = try items.map { try ChartsCollection(from: $0) }
                for _ in 0..<extraCopiesCount {
                    for collrctionIndex in collections.indices {
                        for valueIndex in collections[collrctionIndex].chartValues.indices {
                            collections[collrctionIndex].chartValues[valueIndex] .values += collections[collrctionIndex].chartValues[valueIndex].values
                        }
                        guard let firstValue = collections[collrctionIndex].axisValues.first,
                            let lastValule =  collections[collrctionIndex].axisValues.last else {
                                return
                        }
                        let startItem = lastValule.addingTimeInterval(.day)
                        for valueIndex in collections[collrctionIndex].axisValues.indices {
                            let intervalToAdd = collections[collrctionIndex].axisValues[valueIndex].timeIntervalSince(firstValue)
                            let newDate = startItem.addingTimeInterval(intervalToAdd)
                            collections[collrctionIndex].axisValues.append(newDate)
                        }
                    }
                }
                if sync {
                    success(collections)
                } else {
                    DispatchQueue.main.async {
                        success(collections)
                    }
                }
            } catch {
                DispatchQueue.main.async {
                    assertionFailure("Error occure: \(error)")
                    failure(error)
                }
            }
        }
        if sync {
            workItem()
        } else {
            DispatchQueue.global().async(execute: workItem)
        }
        
    }
}
