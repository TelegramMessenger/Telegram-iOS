//
//  ListDatasource.swift
//  AppleReminders
//
//  Created by Josh R on 7/15/20.
//  Copyright © 2020 Josh R. All rights reserved.
//

import Foundation
import RealmSwift
import UIKit

enum ListSection: Int {
    case type
    case list
    
    var sectionTitle: String {
        switch self {
        case .type:
            return ""
        case .list:
            return "My Lists".localized
        }
    }
}

final class ListDiffableDatasource: UITableViewDiffableDataSource<ListSection, ReminderList?> {
    
    //A NotificationToken is passed so the observer on MainVC isn't called when a user moves a list.
    var realmToken: NotificationToken?
    
    func tableView(_ tableView: UITableView, shouldIndentWhileEditingRowAt indexPath: IndexPath) -> Bool {
        return true
    }
    
    // MARK: reordering support
    override func tableView(_ tableView: UITableView, canMoveRowAt indexPath: IndexPath) -> Bool {
        return indexPath.section > 0 ? true : false
    }
    
    override func tableView(_ tableView: UITableView, moveRowAt sourceIndexPath: IndexPath, to destinationIndexPath: IndexPath) {
        var snapshot = self.snapshot()
        let destinationSection = snapshot.sectionIdentifiers[destinationIndexPath.section]
        
        guard destinationSection == .list else {
            apply(snapshot, animatingDifferences: false)
            return
        }
        
        guard let listOrGroupBeingMoved = itemIdentifier(for: sourceIndexPath)! else { return }
        guard let listOrGroupAboveOrBelow = itemIdentifier(for: destinationIndexPath)! else { return }
        guard sourceIndexPath != destinationIndexPath else { return }
        
        guard let sourceIndex = snapshot.indexOfItem(listOrGroupBeingMoved) else { return }
        guard let destinationIndex = snapshot.indexOfItem(listOrGroupAboveOrBelow) else { return }
        let isAfter = destinationIndex > sourceIndex
        
        print("Moving list: \(String(describing: listOrGroupBeingMoved.groupName ?? listOrGroupBeingMoved.name))")
        print("'Destination' list: \(String(describing: listOrGroupAboveOrBelow.groupName ?? listOrGroupAboveOrBelow.name))")
        
        guard let realm = MyRealm.getConfig() else { return }
        
        //1 - If listOrGroupAboveOrBelow is a GROUP and the destination list is inside of a group, reject move
        if listOrGroupBeingMoved.isGroup && listOrGroupAboveOrBelow.isInGroup {
            apply(snapshot, animatingDifferences: false)
            return
        }
        
        //Delete require lists from snapshot
        snapshot.deleteItems([listOrGroupBeingMoved])
        
        try! realm.write(withoutNotifying: [realmToken!]) {
            if listOrGroupBeingMoved.isGroup && listOrGroupBeingMoved.isExpanded {
                listOrGroupBeingMoved.reminderLists.forEach({ snapshot.deleteItems([$0]) })
                listOrGroupBeingMoved.setExpand(to: false)
            }
            
            //Remove list from group if in group
            if let currentGroup = listOrGroupBeingMoved.ownerGroup.first {
                currentGroup.reminderLists.remove(at: currentGroup.reminderLists.index(of: listOrGroupBeingMoved)!)
            }
            
            //Add to group if item above or below
            if listOrGroupAboveOrBelow.isExpanded || listOrGroupAboveOrBelow.isInGroup {
                if let parentGroup = listOrGroupAboveOrBelow.ownerGroup.first {
                    parentGroup.reminderLists.append(listOrGroupBeingMoved)
                }
            }
        }
        
        if isAfter {
            snapshot.insertItems([listOrGroupBeingMoved], afterItem: listOrGroupAboveOrBelow)
        } else {
            snapshot.insertItems([listOrGroupBeingMoved], beforeItem: listOrGroupAboveOrBelow)
        }
        
        try! realm.write(withoutNotifying: [realmToken!]) {
            for (index, list) in snapshot.itemIdentifiers(inSection: .list).enumerated() {
                list?.sortIndex = index
            }
        }
        
        apply(snapshot, animatingDifferences: true)
        
    }
    
    
    // MARK: editing support
    override func tableView(_ tableView: UITableView, canEditRowAt indexPath: IndexPath) -> Bool {
        return indexPath.section > 0 ? true : false
    }
    
}
