//
//  Dates.swift
//  AppleReminders
//
//  Created by Josh R on 2/18/20.
//  Copyright © 2020 Josh R. All rights reserved.
//

import Foundation
import SwiftDate


struct Dates {
    static func generateRandomDate(between startDate: Date?, and endDate: Date?) -> Date? {
        guard let startDate = startDate, let endDate = endDate else { return nil }
        
        let startDateRegion = DateInRegion(startDate, region: .current)
        let endDateRegion = DateInRegion(endDate, region: .current)
        
        let randomDate = DateInRegion.randomDate(between: startDateRegion, and: endDateRegion)
        
        return randomDate.date
    }
}


enum DaysOfTheWeek: String, CaseIterable {
    case sunday = "Sunday"
    case monday = "Monday"
    case tuesday = "Tuesday"
    case wednesday = "Wednesday"
    case thursday = "Thursday"
    case friday = "Friday"
    case saturday = "Saturday"
}


struct DateFormatters {
    static var formatEEEMMMddyyyy: DateFormatter = {
        let dateFormatter = DateFormatter()
        dateFormatter.timeZone = .current
        dateFormatter.calendar = .current
        dateFormatter.dateFormat = "EEE MMM d, yyyy"
        
        return dateFormatter
    }()
}
