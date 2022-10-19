//
//  Model.swift
//  AppleReminders
//
//  Created by Josh R on 1/24/20.
//  Copyright © 2020 Josh R. All rights reserved.
//

import Foundation
import Realm
import RealmSwift
import UIKit
import Contacts
import SwiftDate


struct SampleData {
    static func generateCreateListModel() -> [CreateListModel] {
        var createListModel = [CreateListModel]()
        
        //Create color icons
        for colorDict in CustomColors.systemColors {
            let color = CreateListModel(colorHEX: colorDict, iconName: nil, iconType: nil, cellType: .color)
            createListModel.append(color)
        }
        
        //Create icon icons
        for icon in IconsData.icons {
            let iconObject = CreateListModel(colorHEX: "", iconName: icon.iconName, iconType: icon.iconType, cellType: .icon)
            createListModel.append(iconObject)
        }
        
        return createListModel
    }
}


struct SampleRealmData {
    static func createTestRealmData() {
        SampleRealmData.createLists()
    }
    
    static func addRemindersToCurrentModel() {
        let realm = MyRealm.getConfig()
        let reminders = ["Buy milk".localized, "Pick up kid from daycare".localized, "MOA".localized, "Testing".localized, "Go to Store".localized, "Pay milk money".localized]
        
        try! realm?.write {
            for list in realm!.objects(ReminderList.self) {
                for (index, reminder) in reminders.enumerated() {
                    let newReminder = Reminder()
                    newReminder.name = reminder
                    newReminder.inList = list
                    newReminder.sortIndex = index
                    newReminder.dueDate = Dates.generateRandomDate(between: Date() - 60.days, and: Date() + 60.days)
                    
                    list.reminders.append(newReminder)
                }
            }
        }
    }
    
    static func createLists() {
        let realm = MyRealm.getConfig()
        
        let startingLists = ["General".localized, "1/11", "2/11", "MOA".localized, "Vacation".localized, "Birthday".localized, "Christmas".localized, "Reminders".localized]
        
        try! realm?.write {
            for (index, listItem) in startingLists.enumerated() {
                let list = ReminderList()
                list.name = listItem
                list.listColor = CustomColors.generateRandomSystemColor() //Generate a random color from CustomColors.systemColors
                list.sortIndex = index
                
                realm?.add(list)
            }
        }
    }
    
    //Only need if current data doesn't have due dates.  Call in ViewDidLoad from MainVC
    static func generateRandomDueDatesInCurrentRealm() {
        let realm = MyRealm.getConfig()
        
        guard let Reminders = realm?.objects(Reminder.self) else { return }
        
        try! realm?.write {
            for reminder in Reminders {
                reminder.dueDate = Dates.generateRandomDate(between: Date.init(month: 1, day: 1, year: 2020), and: Date.init(month: 5, day: 31, year: 2020))
            }
        }
    }
}

