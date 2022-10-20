//
//  Reminder.swift
//  AppleReminders
//
//  Created by Josh R on 7/1/20.
//  Copyright © 2020 Josh R. All rights reserved.
//

import Foundation
import RealmSwift
import Contacts
import UIKit

enum ReminderType: String, CaseIterable {
    case today
    case scheduled
    case all
    case flagged
}


class Reminder: Object, Identifiable {
    @objc dynamic var name: String = ""
    @objc dynamic var inList: ReminderList?
    @objc dynamic var isCompleted: Bool = false
    @objc dynamic var dateCompleted: Date?
    @objc dynamic var isFlagged: Bool = false
    @objc dynamic var dueDate: Date?
    @objc dynamic var isTimeDueDate: Bool = false
    let atLocationLat = RealmOptional<Double>()
    let atLocationLong = RealmOptional<Double>()
    @objc dynamic var locationName: String? = nil  //set if user searches for location and selects a business
    @objc dynamic var locationVehicleAction: String? = nil
    @objc dynamic var priority: String = Reminder.Priority.none.rawValue
    @objc dynamic var url: String? = nil
    @objc dynamic var note: String? = nil
    @objc dynamic var sortIndex: Int = 0  //computed prop to find max index
    
    @objc dynamic var customFrequencyPeriod: String?
    @objc dynamic var customFrequencyTime: String?
    @objc dynamic var contactID: String = ""
    
    //MARK: Unique ID
    @objc dynamic var reminderID = UUID().uuidString
    override static func primaryKey() -> String? {
        return "reminderID"
    }
    
    //REPEATING Properties
    @objc dynamic var repeatEndDate: Date?  //use dueDate for start date
    @objc dynamic var frequency: String?
    
    var isRepeatable: Bool {
        return self.frequency == nil || self.frequency == Reminder.RepeatingPeriod.never.rawValue ? false : true
    }
    
    //Subtasks
    let subtasks = List<Reminder>()
    let ownerReminder = LinkingObjects(fromType: Reminder.self, property: "subtasks")
    
    
    //Location assist
    enum LocationVehicleAction: String {
        case gettingIn
        case gettingOut
        
        var description: String {
            switch self {
            case .gettingIn:
                return "Getting in Car".localized
            case .gettingOut:
                return "Getting out of Car".localized
            }
        }
    }
    
    
    enum RepeatingPeriod: String, CaseIterable {
        case never = "Never"
        case daily = "Daily"
        case weekly = "Weekly"
        case biweekly = "Biweekly"
        case monthly = "Monthly"
        case everyThreeMonths = "Every 3 Months"
        case everySixMonths = "Every 6 Months"
        case yearly = "Yearly"
        case custom = "Custom"
    }
    
    
    //Inverse relationship to List
    let ownerList = LinkingObjects(fromType: ReminderList.self, property: "reminders")
    
    
    //use rawValue when setting property
    enum Priority: String, CaseIterable {
        case none
        case low
        case medium
        case high
        
        var description: String {
            switch self {
            case .low:
                return "!"
            case .medium:
                return "!!"
            case .high:
                return "!!!"
            case .none:
                return ""
            }
        }
    }
    
    
}

extension Reminder {
    //When a user swipes left to right to "indent" the cell
    func indentReminder() {
        guard let realm = MyRealm.getConfig() else { return }
        
        //Retrieve previous reminder
        if !self.isSubtask {
            var previousReminder: Reminder!
            for reminder in inList!.reminders.filter({ $0.isSubtask == false }) {
                if reminder.reminderID != self.reminderID {
                    previousReminder = reminder
                    continue
                } else {
                    break
                }
            }
            
            try! realm.write {
                previousReminder.subtasks.append(self)
                previousReminder.setExpand(to: true)
                
                if self.subtasks.count > 0 {
                    //Add to new parent
                    self.subtasks.forEach({ previousReminder.subtasks.append($0) })
                    
                    //Remove from self subtasks
                    self.subtasks.removeAll()
                }
            }
        }
    }
    
    //When a user swipes left to right to "outdent" the cell
    func outdentReminder() {
        guard let realm = MyRealm.getConfig() else { return }
        guard let subTasksAfter = ownerReminder.first?.subtasks.filter("sortIndex > \(self.sortIndex)") else { return }
        
        print("Subtasks after: \(subTasksAfter.count)")
        
        try! realm.write {
            //Add subtasks that are below this to this reminder
            subTasksAfter.forEach({ self.subtasks.append($0) })
            
            self.setExpand(to: true)
            
            //remove this reminder from its parent
            if let parentReminder = ownerReminder.first {
                parentReminder.subtasks.remove(at: parentReminder.subtasks.index(of: self)!)
                
                for subTask in subTasksAfter {
                    parentReminder.subtasks.remove(at: parentReminder.subtasks.index(of: subTask)!)
                }
            }
        }
    }
    
    
    //Remind when messaging properties
    //Apple's Contact Framework: https://developer.apple.com/documentation/contacts
    var retrieveContact: CNContact? {
        let contactStore = CNContactStore()
        let idPredicate: NSPredicate = CNContact.predicateForContacts(withIdentifiers: [self.contactID])
        let keys = [CNContactGivenNameKey, CNContactFamilyNameKey, CNContactImageDataKey, CNContactThumbnailImageDataKey, CNContactImageDataAvailableKey]
        let savedContact = try! contactStore.unifiedContacts(matching: idPredicate, keysToFetch: keys as [CNKeyDescriptor])
        return savedContact.first
    }
    
    var isContactAssigned: Bool {
        return contactID.count > 4 && self.contactID != "" ? true : false
    }
    
    //Check if reminder is past due AND not completed
    var isReminderPastDue: Bool {
        guard let dueDate = self.dueDate else { return false }
        
        return dueDate < Date() ? true : false
    }
    
    var isDueDateToday: Bool {
        guard let dueDate = dueDate else { return false }
        
        return dueDate.isToday ? true : false
    }
    
    var isScheduled: Bool {
        return self.dueDate != nil ? true : false
    }
    
    func removeDueDate() {
        self.dueDate = nil
        self.isTimeDueDate = false
    }
    
    var toggleReminderCompletion: Void {
        self.isCompleted.toggle()
        
        if self.subtasks.count > 0 {
            self.subtasks.forEach({
                $0.isCompleted = self.isCompleted
            })
        }
    }
    
    func formatDueDateForSection() -> String {
        guard let dueDate = self.dueDate else {
            return ""
        }
        
        return DateFormatters.formatEEEMMMddyyyy.string(from: dueDate)
    }
    
    
    //Check if reminder is set to alarm at a specific location
    var isLocationReminder: Bool {
        guard self.atLocationLat.value != nil, self.atLocationLong.value != nil else { return false }
        return true
    }
    
    //Either "Getting in Car" or "Getting out of Car"
    var isVehicleAction: Bool {
        guard self.locationVehicleAction != nil else { return false }
        return true
    }
    
    //MARK: Find max sort index and assign
    func assignSortIndex() -> Int {
        if ownerList.first?.reminders.count == 0 { return 0 }
        
        let reminders = self.isSubtask ? self.subtasks : inList?.reminders
        let maxSortIndex = reminders?.max(by: { $0.sortIndex < $1.sortIndex })?.sortIndex ?? 0
        return maxSortIndex + 1
    }
    
    //To determine if reminder is set to remind on a specific day
    var isRemindOnADay: Bool {
        return self.dueDate != nil ? true : false
    }
    
    
}



//MARK: Retrieve reminders by criteria
extension Reminder {
    //Due today, not complete
    static func todayReminders(_ showCompleted: Bool) -> Results<Reminder>? {
        guard let realm = MyRealm.getConfig() else { return nil }
        let startOfTheDay = Date().toLocalTime().dateAtStartOf(.day).toGlobalTime()
        let endOfTheDay = Date().toLocalTime().dateAtEndOf(.day).toGlobalTime()
        
        let todayReminders = realm.objects(Reminder.self)
            .filter("dueDate BETWEEN {%d, %d}", startOfTheDay, endOfTheDay)
        
        return showCompleted ? todayReminders : todayReminders.filter("isCompleted == false")
    }
    
    static var numberOfTodayReminders: Int {
        return todayReminders(false)?.count ?? 0
    }
    
    
    //Scheduled, due date not nil, option to chose to show completed/not complete, sort oldest to newest
    static func scheduledReminders(_ showCompleted: Bool) -> Results<Reminder>? {
        guard let realm = MyRealm.getConfig() else { return nil }
        let scheduledReminders = realm.objects(Reminder.self)
            .filter("dueDate != nil")
            .sorted(byKeyPath: "dueDate", ascending: true)
        
        return showCompleted ? scheduledReminders : scheduledReminders.filter("isCompleted == %d", showCompleted)
    }
    
    static var numberOfScheduledReminders: Int {
        return scheduledReminders(false)?.count ?? 0
    }
    
    //All, option to chose to show completed/not complete
    static func allReminders(_ showCompleted: Bool) -> Results<Reminder>? {
        guard let realm = MyRealm.getConfig() else { return nil }
        let allReminders = realm.objects(Reminder.self).sorted(byKeyPath: "sortIndex", ascending: true)
        
        return showCompleted ? allReminders : allReminders.filter("isCompleted == %d", showCompleted)
    }
    
    static var numberOfAllReminders: Int {
        return allReminders(false)?.count ?? 0
    }
    
    
    //Flagged, not complete, include subtasks but doesn't show as a subtask
    static func flaggedReminders(_ showCompleted: Bool) -> Results<Reminder>? {
        guard let realm = MyRealm.getConfig() else { return nil }
        let flaggedReminders = realm.objects(Reminder.self)
            .filter("isFlagged == true")
        
        return showCompleted ? flaggedReminders : flaggedReminders.filter("isCompleted == \(showCompleted)")
    }
    
    static var numberOfFlaggedReminders: Int {
        return flaggedReminders(false)?.count ?? 0
    }
    
    //Search for Reminders
    static func searchReminders(with searchText: String) -> Results<Reminder>? {
        guard let realm = MyRealm.getConfig() else { return nil }
        let searchPredicate = NSPredicate(format: "name CONTAINS[c] %@", searchText)        //CONTAINS[c] for case-insensitive matching
        let filteredReminders = realm.objects(Reminder.self)
            .filter(searchPredicate)
        
        return filteredReminders
    }
    
    
    //By list
    static func reminders(in list: ReminderList, _ showCompleted: Bool) -> Results<Reminder>? {
        guard let realm = MyRealm.getConfig() else { return nil }
        let reminders = realm.objects(Reminder.self)
            .filter("inList.reminderListID == %d", list.reminderListID)
            .sorted(byKeyPath: "sortIndex", ascending: true)
        
        return showCompleted ? reminders : reminders.filter("isCompleted == \(showCompleted)")
    }
    
    
    func formatDueDateAsString() -> String {
        if let reminderDueDate = self.dueDate {
            return self.isTimeDueDate ? reminderDueDate.formatDateMMMMddyyyyWithTime() : reminderDueDate.formatDateDayEMddYYTime()
        } else {
            return self.isTimeDueDate ? Date().formatDateMMMMddyyyyWithTime() : Date().formatDateDayEMddYYTime()
        }
    }
    
    
    //Get list color
    var listColor: UIColor {
        let listColor = self.ownerReminder.first?.inList?.listColor ?? self.inList?.listColor ?? "systemBlue"
        let checkBoxColor: UIColor = CustomColors.systemColorsDict[listColor] ?? .systemBlue
        return checkBoxColor
    }
    
    static func addReminder(to list: ReminderList, name: String) {
        guard let realm = MyRealm.getConfig() else { return }
        
        try! realm.write {
            let reminder = Reminder()
            reminder.name = name
            reminder.inList = list
            reminder.sortIndex = reminder.assignSortIndex()
            
            list.reminders.append(reminder)
        }
    }
    
    static func addReminder(to list: ReminderList, name: String, with dueDate: Date) {
        guard let realm = MyRealm.getConfig() else { return }
        
        try! realm.write {
            let reminder = Reminder()
            reminder.name = name
            reminder.inList = list
            reminder.sortIndex = reminder.assignSortIndex()
            reminder.dueDate = dueDate
            
            list.reminders.append(reminder)
        }
    }
    
    static func assignReminders(to newList: ReminderList, reminders: [Reminder]) {
        guard let realm = MyRealm.getConfig() else { return }
        
        try! realm.write {
            for reminder in reminders {
                guard let oldList = reminder.ownerList.first else { continue }
                oldList.reminders.remove(at: oldList.reminders.index(of: reminder)!)
                
                //Add to new list
                newList.reminders.append(reminder)
                reminder.inList = newList
                reminder.sortIndex = reminder.assignSortIndex()
            }
        }
    }
    
    
    var isSubtask: Bool {
        if ownerReminder.first != nil {
            return true
        }
        
        //Because a Reminder can be "copied" as a unmanaged Realm object, the unmanaged object does not carry over it's parent.
        guard let realm = MyRealm.getConfig() else { return false }
        let remindersWithSubtasks = realm.objects(Reminder.self).filter("subtasks.@count > 0")
        
        for reminder in remindersWithSubtasks {
            for subtask in reminder.subtasks {
                if subtask.reminderID == self.reminderID {
                    return true
                }
            }
        }
        
        return false
    }
    
    
    func updateReminder(modifiedReminder: Reminder?) {
        let realm = MyRealm.getConfig()
        
        //Note:  Attempting to add the modifiedTodo to the origTodo's list, then deleting the origTodo also deletes the modified reminder
        guard let modifiedReminder = modifiedReminder else { return }
        
        try! realm?.write {
            self.name = modifiedReminder.name
            self.note = modifiedReminder.note
            self.url = modifiedReminder.url
            
            self.priority = modifiedReminder.priority
            self.contactID = modifiedReminder.contactID
            self.isFlagged = modifiedReminder.isFlagged
            self.dueDate = modifiedReminder.dueDate
            self.isCompleted = modifiedReminder.isCompleted
            self.dateCompleted = modifiedReminder.dateCompleted
            self.repeatEndDate = modifiedReminder.repeatEndDate
            self.isTimeDueDate = modifiedReminder.isTimeDueDate
            self.atLocationLat.value = modifiedReminder.atLocationLat.value
            self.atLocationLong.value = modifiedReminder.atLocationLong.value
            self.locationName = modifiedReminder.locationName
            self.locationVehicleAction = modifiedReminder.locationVehicleAction
            self.frequency = modifiedReminder.frequency
            self.customFrequencyPeriod = modifiedReminder.customFrequencyPeriod
            self.customFrequencyTime = modifiedReminder.customFrequencyTime
            
            self.contactID = modifiedReminder.contactID
            
            //Update list
            if self.ownerList.first?.reminderListID != modifiedReminder.inList?.reminderListID {
                //remove from old list
                if let oldList = self.ownerList.first {
                    if let index = oldList.reminders.index(of: self) {
                        oldList.reminders.remove(at: index)
                    }
                }
                
                //Add to new list, update to one property
                self.inList = modifiedReminder.inList
                modifiedReminder.inList?.reminders.append(self)
            }
            
            //Update subtasks
            for subtask in modifiedReminder.subtasks {
                if !self.subtasks.contains(subtask) {
                    self.subtasks.append(subtask)
                }
            }
            
            for subtask in self.subtasks {
                if !modifiedReminder.subtasks.contains(subtask) {
                    realm?.delete(subtask)
                }
            }
        }
    }
    
    func deleteReminder() {
        let realm = MyRealm.getConfig()
        
        try! realm?.write {
            for subtask in self.subtasks {
                realm?.delete(subtask)
            }
            
            realm?.delete(self)
        }
    }
}

//MARK: Logic to handle expanding
extension Reminder {
    func toggleExpand() {
        if self.subtasks.count > 0 {
            let key = self.reminderID
            var toggleState = UserDefaults.standard.bool(forKey: key)
            toggleState.toggle()
            UserDefaults.standard.set(toggleState, forKey: key)
        }
    }
    
    func setExpand(to value: Bool) {
        let key = self.reminderID
        UserDefaults.standard.set(value, forKey: key)
    }
    
    var isExpanded: Bool {
        let key = self.reminderID
        return UserDefaults.standard.bool(forKey: key)
    }
    
    
}
