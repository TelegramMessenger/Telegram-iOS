//
//  ReminderDatasource.swift
//  AppleReminders
//
//  Created by Josh R on 7/2/20.
//  Copyright © 2020 Josh R. All rights reserved.
//

import Foundation
import RealmSwift
import UIKit

final class ReminderDiffableDatasource: UITableViewDiffableDataSource<String, Reminder> {
    
    //A NotificationToken is passed so the observer on MainVC isn't called when a user moves a list.
    var realmToken: NotificationToken?
    
    // MARK: reordering support
    override func tableView(_ tableView: UITableView, canMoveRowAt indexPath: IndexPath) -> Bool {
        return true
    }
    
    override func tableView(_ tableView: UITableView, moveRowAt sourceIndexPath: IndexPath, to destinationIndexPath: IndexPath) {
        var snapshot = self.snapshot()
        
        print("sourceIndexPath: \(sourceIndexPath)")
        print("destinationIndexPath: \(destinationIndexPath)")
        
        let sourceSection = snapshot.sectionIdentifiers[sourceIndexPath.section]
        let destinationSection = snapshot.sectionIdentifiers[destinationIndexPath.section]
        
        //If moving a Reminder DOWN, listOrGroupAboveOrBelow is the Reminder ABOVE
        //If moving a Reminder UP, listOrGroupAboveOrBelow is the Reminder BELOW
        guard let reminderOrSubtaskBeingMoved = itemIdentifier(for: sourceIndexPath) else {
            apply(snapshot, animatingDifferences: false)
            return
        }
        
        guard let reminderOrSubtaskAboveOrBelow = itemIdentifier(for: destinationIndexPath) else {
            apply(snapshot, animatingDifferences: false)
            return
        }
        
        guard let sourceIndex = snapshot.indexOfItem(reminderOrSubtaskBeingMoved) else { return }
        guard let destinationIndex = snapshot.indexOfItem(reminderOrSubtaskAboveOrBelow) else { return }
        let isAfter = destinationIndex > sourceIndex    //moving DOWN the list
        //        let isBefore = destinationIndex < sourceIndex   //moving UP the list
        
        print("Moving reminder: \(String(describing: reminderOrSubtaskBeingMoved.name))")
        print("'Destination' reminder: \(String(describing: reminderOrSubtaskAboveOrBelow.name))")
        
        guard let realm = MyRealm.getConfig() else { return }
        
        
        //---------SCENARIOS---------
        //If a reminder with subtasks is moved to a reminder's subtasks, REJECT
        if reminderOrSubtaskBeingMoved.subtasks.count > 0 && reminderOrSubtaskAboveOrBelow.isSubtask || reminderOrSubtaskAboveOrBelow.subtasks.count > 0 {
            apply(snapshot, animatingDifferences: false)
            return
        }
        
        //7-27-20 as of right now, I am not implementing support to move Reminders on the All and Scheduled VCs
        if destinationSection != sourceSection {
            apply(snapshot, animatingDifferences: false)
            return
        }
        
        //If move APPROVED, delete item from snapshot
        snapshot.deleteItems([reminderOrSubtaskBeingMoved])
        
        try! realm.write(withoutNotifying: [realmToken!]) {
            if reminderOrSubtaskBeingMoved.subtasks.count > 0 && reminderOrSubtaskBeingMoved.isExpanded {
                reminderOrSubtaskBeingMoved.subtasks.forEach({ snapshot.deleteItems([$0]) })
                reminderOrSubtaskBeingMoved.setExpand(to: false)
            }
            
            //Remove subtasks from parent reminder
            if let currentOwnerReminder = reminderOrSubtaskBeingMoved.ownerReminder.first {
                currentOwnerReminder.subtasks.remove(at: currentOwnerReminder.subtasks.index(of: reminderOrSubtaskBeingMoved)!)
            }
            
            //Add to group if item above or below
            if reminderOrSubtaskAboveOrBelow.isExpanded || reminderOrSubtaskAboveOrBelow.isSubtask {
                if let currentOwnerReminder = reminderOrSubtaskAboveOrBelow.ownerReminder.first {
                    currentOwnerReminder.subtasks.append(reminderOrSubtaskBeingMoved)
                }
            }
            
            //NOTE - not implemented right now
            //If moving to a new section (All or Scheduled), either assign new due date (moved in Scheduled) or moved to new list (moved in All)
            if destinationSection != sourceSection {
                //FIXME:  Crashing.  Maybe use a callback to create a new snapshot??
                if let sectionDate = DateFormatters.formatEEEMMMddyyyy.date(from: destinationSection) {
                    reminderOrSubtaskBeingMoved.dueDate = sectionDate
                    snapshot.appendItems([reminderOrSubtaskBeingMoved], toSection: destinationSection)
                    //                    snapshot.deleteItems([reminderOrSubtaskBeingMoved])
                }
                
                //Convert String section to ReminderList
                if let destinationList = ReminderList.getList(by: destinationSection) {
                    //Method already in realm write transaction
                    if let currentList = reminderOrSubtaskBeingMoved.inList {
                        reminderOrSubtaskBeingMoved.inList = destinationList
                        
                        currentList.reminders.append(reminderOrSubtaskBeingMoved)
                    }
                    
                    snapshot.appendItems([reminderOrSubtaskBeingMoved], toSection: destinationSection)
                    //                    snapshot.deleteItems([reminderOrSubtaskBeingMoved])
                }
            }
        }
        
        
        //Modify the snapshot -- don't forget to designate beforeItem or afterItem
        if destinationSection == sourceSection {
            if isAfter {
                snapshot.insertItems([reminderOrSubtaskBeingMoved], afterItem: reminderOrSubtaskAboveOrBelow)
            } else {
                snapshot.insertItems([reminderOrSubtaskBeingMoved], beforeItem: reminderOrSubtaskAboveOrBelow)
            }
        }
        
        
        
        //Write new sortIndex to realm IF destinationSection == sourceSection
        try! realm.write(withoutNotifying: [realmToken!]) {
            for (index, reminder) in snapshot.itemIdentifiers(inSection: destinationSection).enumerated() {
                reminder.sortIndex = index
            }
        }
        
        //Apply snapshot
        apply(snapshot, animatingDifferences: true, completion: nil)
    }
    
    
    // MARK: editing support
    override func tableView(_ tableView: UITableView, canEditRowAt indexPath: IndexPath) -> Bool {
        return true
    }
    
}


class ReminderDatasource: NSObject {
    
    var reminderDiffableDatasource: ReminderDiffableDatasource?
    var reminderFilter: ReminderListTVC.VCType?
    var tableView: UITableView?
    
    //A NotificationToken is passed so the observer on MainVC isn't called when a user moves a list.
    var realmToken: NotificationToken?
    
    //Toggle if the user wants to show completed todos
    var showCompleted = true
    
    private func getSections() -> [String] {
        guard let reminderFilter = reminderFilter else { return [] }
        guard let reminders = getReminders() else { return [] }
        
        switch reminderFilter {
        case .all, .search(_):  //List names titles and color, section will be listID
            var uniqueListIDs: [String] = reminders.map({ $0.inList!.reminderListID })
            uniqueListIDs.removeDuplicates()
            return uniqueListIDs
        case .today, .flagged, .reminderList(_):  //no section titles
            return ["Main".localized]
        case .scheduled:    //date string in the format: Mon Oct 24, 2011
            var sectionDates: [String] = reminders.map({ $0.formatDueDateForSection() })
            sectionDates.removeDuplicates()
            return sectionDates
        }
    }
    
    func getReminders() -> Results<Reminder>? {
        guard let reminderFilter = reminderFilter else { return nil }
        
        switch reminderFilter {
        case .all:  //All, option to chose to show completed/not complete
            return Reminder.allReminders(showCompleted)
        case .reminderList(let list):
            return Reminder.reminders(in: list, showCompleted)
        case .scheduled:    //Scheduled, due date not nil, option to chose to show completed/not complete
            return Reminder.scheduledReminders(showCompleted)
        case .today:  //All, not complete
            return Reminder.todayReminders(showCompleted)
        case .flagged:  //Flagged, not complete
            return Reminder.flaggedReminders(showCompleted)
        case .search(let searchText):
            let filteredReminders = Reminder.searchReminders(with: searchText)
            return filteredReminders
        }
    }
    
    //TODO: Merge load method with createSnapshot method
    func load() {
        guard let tableView = tableView else { return }
        reminderDiffableDatasource = ReminderDiffableDatasource(tableView: tableView, cellProvider: { [weak self] (tableView, indexPath, reminder) -> ReminderTVCell? in
            self?.reminderDiffableDatasource?.realmToken = self?.realmToken
            
            print("Reminder name: \(reminder.name)")
            
            let cell = tableView.dequeueReusableCell(withIdentifier: ReminderTVCell.identifier, for: indexPath) as! ReminderTVCell
            cell.reminderDatasourceFilter = self?.reminderFilter
            cell.reminder = reminder
            
            //User expands cell
            cell.cellExpand = { [weak self] in
                self?.load()
            }
            
            return cell
        })
        
        reminderDiffableDatasource?.apply(createSnapshot(), animatingDifferences: false, completion: nil)
    }
    
    func update() {
        var snapshot = NSDiffableDataSourceSnapshot<String, Reminder>()
        
        //Get filtered Todos depending on typ
        guard let filteredReminders = getReminders() else { return }
        guard let reminderFilter = reminderFilter else { return }
        
        print("Filtered reminders: \(filteredReminders.count)")
        
        //Generate string sections
        let sections = self.getSections()
        snapshot.appendSections(sections)
        
        for section in sections {
            for reminder in filteredReminders {
                switch reminderFilter {
                case .all:  //List names titles and color, section will be listID
                    if reminder.inList?.reminderListID == section && !reminder.isSubtask {
                        snapshot.appendItems([reminder], toSection: section)
                    }
                    
                    //Subtasks
                    //Add/Remove subtasks (Expand/Collapse cell)
                    if reminder.isExpanded && reminder.subtasks.count > 0 && reminder.inList?.reminderListID == section {
                        reminder.subtasks.forEach({ snapshot.appendItems([$0], toSection: section) })
                    }
                case .search(_): //List names titles and color, section will be listID. Treat subtasks as regular reminders
                    if reminder.inList?.reminderListID == section {
                        snapshot.appendItems([reminder], toSection: section)
                    }
                case .today, .flagged: //no section titles, do not show subtasks under parent
                    snapshot.appendItems([reminder], toSection: section)
                case .reminderList(_):  //no section titles
                    if !reminder.isSubtask {
                        snapshot.appendItems([reminder])
                    }
                    
                    //Subtasks
                    //Add/Remove subtasks (Expand/Collapse cell)
                    if reminder.isExpanded && reminder.subtasks.count > 0 {
                        reminder.subtasks.forEach({ snapshot.appendItems([$0]) })
                    }
                case .scheduled:    //date string in the format: Mon Oct 24, 2011
                    if reminder.formatDueDateForSection() == section  && !reminder.isSubtask {
                        snapshot.appendItems([reminder], toSection: section)
                    }
                }
            }
        }
        
        reminderDiffableDatasource?.apply(snapshot, animatingDifferences: true, completion: nil)
    }
    
    private func createSnapshot() -> NSDiffableDataSourceSnapshot<String, Reminder> {
        var snapshot = NSDiffableDataSourceSnapshot<String, Reminder>()
        
        //Get filtered Todos depending on type
        guard let filteredReminders = getReminders() else { return snapshot }
        guard let reminderFilter = reminderFilter else { return snapshot }
        
        print("Filtered reminders: \(filteredReminders.count)")
        
        //Generate string sections
        let sections = self.getSections()
        snapshot.appendSections(sections)
        
        for section in sections {
            for reminder in filteredReminders {
                switch reminderFilter {
                case .all:  //List names titles and color, section will be listID
                    if reminder.inList?.reminderListID == section && !reminder.isSubtask {
                        snapshot.appendItems([reminder], toSection: section)
                    }
                    
                    //Subtasks
                    //Add/Remove subtasks (Expand/Collapse cell)
                    if reminder.isExpanded && reminder.subtasks.count > 0 && reminder.inList?.reminderListID == section {
                        reminder.subtasks.forEach({ snapshot.appendItems([$0], toSection: section) })
                    }
                case .search(_):  //List names titles and color, section will be listID.  Treat subtasks as regular reminders
                    if reminder.inList?.reminderListID == section {
                        snapshot.appendItems([reminder], toSection: section)
                    }
                case .today, .flagged: //no section titles, do not show subtasks under parent
                    snapshot.appendItems([reminder], toSection: section)
                case .reminderList(_):  //no section titles
                    if !reminder.isSubtask {
                        snapshot.appendItems([reminder], toSection: section)
                    }
                    
                    //Subtasks
                    //Add/Remove subtasks (Expand/Collapse cell)
                    if reminder.isExpanded && reminder.subtasks.count > 0 {
                        reminder.subtasks.forEach({ snapshot.appendItems([$0]) })
                    }
                case .scheduled:    //date string in the format: Mon Oct 24, 2011
                    if reminder.formatDueDateForSection() == section  && !reminder.isSubtask {
                        snapshot.appendItems([reminder], toSection: section)
                    }
                }
            }
        }
        
        return snapshot
    }
    
    
}
