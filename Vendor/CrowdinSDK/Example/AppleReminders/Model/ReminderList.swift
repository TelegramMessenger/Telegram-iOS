//
//  ReminderList.swift
//  AppleReminders
//
//  Created by Josh R on 7/1/20.
//  Copyright © 2020 Josh R. All rights reserved.
//

import Foundation
import RealmSwift
import UIKit


class ReminderList: Object, Identifiable {
    @objc dynamic var name: String = ""
    @objc dynamic var groupName: String? = nil
    @objc dynamic var listColor: String = ""   //save as hex string
    @objc dynamic var systemIconName: String = "list.bullet"
    @objc dynamic var sortIndex: Int = 0
    
    let reminders = List<Reminder>()  //one-to-many
    
    //To support grouping
    let reminderLists = List<ReminderList>()  //one-to-many
    let ownerGroup = LinkingObjects(fromType: ReminderList.self, property: "reminderLists")
    
    //Unique ID
    @objc dynamic var reminderListID = UUID().uuidString
    override static func primaryKey() -> String? {
        return "reminderListID"
    }
}


extension ReminderList {
    //Computed properties
    var getListIcon: UIImage {
        if groupName != nil {
            return UIImage(systemName: "rectangle.stack.fill") ?? UIImage()
        } else {
            return UIImage(systemName: self.systemIconName) ?? UIImage(named: self.systemIconName) ?? UIImage(systemName: "list.bullet")!
        }
    }
    
    var reminderCount: Int {
        return reminders.filter("isCompleted == false").count
    }
    
    var listUIColor: UIColor {
        if self.isGroup {
            return .clear
        } else {
            let checkBoxColor: UIColor = CustomColors.systemColorsDict[self.listColor] ?? .systemBlue
            return checkBoxColor
        }
    }
    
    //This method needs to be called INSIDE a realm write transaction
    func deleteList() {
        guard let realm = MyRealm.getConfig() else { return }
        
        //Delete Reminders
        self.reminders.forEach({ reminder in
            realm.delete(reminder)
        })
        
        //Loop through and delete all lists (if group)
        if self.isGroup {
            self.reminderLists.forEach({ list in
                realm.delete(list)
            })
        }
        
        //Delete self
        realm.delete(self)
    }
    
    static func assignMaxSortIndex() -> Int {
        let allLists = ReminderList.getAllLists(isGroupsIncluded: true)
        let maxSortIndex = allLists?.max(by: { $0.sortIndex < $1.sortIndex })?.sortIndex ?? 0
        return maxSortIndex == 0 ? 0 : maxSortIndex + 1
    }
    
    static func getList(by id: String) -> ReminderList? {
        guard let realm = MyRealm.getConfig() else { return nil }
        return realm.objects(ReminderList.self).filter("reminderListID == '\(id)'").first
    }
    
    static func getGeneralList() -> ReminderList {
        let realm = MyRealm.getConfig()!
        let generalList = realm.objects(ReminderList.self).filter("name == %d", "General").first!
        
        return generalList
    }
    
    static func getAllLists(isGroupsIncluded: Bool) -> Results<ReminderList>? {
        guard let realm = MyRealm.getConfig() else { return nil }
        let allLists = realm.objects(ReminderList.self).sorted(byKeyPath: "sortIndex", ascending: true)
        
        if isGroupsIncluded {
            return allLists
        } else {
            //All lists that are not groups
            return allLists.filter("groupName == nil")
        }
    }
    
    static func allListsNotInAGroup() -> Results<ReminderList>? {
        guard let allLists = ReminderList.getAllLists(isGroupsIncluded: false) else { return nil }
        var listIDs = [String]()
        
        for list in allLists {
            if list.isInGroup {
                listIDs.append(list.reminderListID)
            }
        }
        let predicate = NSPredicate(format: "NOT (reminderListID IN %@)", listIDs)
        let filteredList = allLists.filter(predicate)
        
        return filteredList
    }
    
    //Used when a user creates a new group.  A list can only be part of ONE group
    //This method needs to be called INSIDE a realm write transaction
    static func removeFromGroup(_ listToRemove: ReminderList) {
        guard let realm = MyRealm.getConfig() else { return }
        let allGroups = realm.objects(ReminderList.self).filter("groupName != nil")
        
        for group in allGroups {
            if group.reminderLists.contains(listToRemove) {
                if let index = group.reminderLists.index(of: listToRemove) {
                    group.reminderLists.remove(at: index)
                }
            }
        }
    }
    
}

//MARK: Grouping methods and logic
extension ReminderList {
    static let tempGroupKey = "tempGroupKey"
    
    var isGroup: Bool {
        return groupName != nil ? true : false
    }
    
    var isInGroup: Bool {
        return self.ownerGroup.first == nil ? false : true
    }
    
    static var listsInGroup: [String] {
        guard let allLists = ReminderList.getAllLists(isGroupsIncluded: true) else { return [] }
        return allLists.filter({ $0.isInGroup }).map({ $0.reminderListID })
    }
}


//MARK: Handle expand
extension ReminderList {
    func toggleExpand() {
        if self.reminderLists.count > 0 {
            let key = self.reminderListID
            var toggleState = UserDefaults.standard.bool(forKey: key)
            toggleState.toggle()
            UserDefaults.standard.set(toggleState, forKey: key)
        }
    }
    
    func setExpand(to value: Bool) {
        let key = self.reminderListID
        UserDefaults.standard.set(value, forKey: key)
    }
    
    var isExpanded: Bool {
        let key = self.reminderListID
        return UserDefaults.standard.bool(forKey: key)
    }
}
