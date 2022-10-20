//
//  CreateGroupDatasource.swift
//  AppleReminders
//
//  Created by Josh R on 7/19/20.
//  Copyright © 2020 Josh R. All rights reserved.
//

import UIKit


enum Section: String, CaseIterable {
    case include
    case available
    
    var sectionTitles: String {
        switch self {
        case .include:
            return "INCLUDE".localized
        case .available:
            return "MORE LISTS".localized
        }
    }
}

final class GroupDiffableDatasource: UITableViewDiffableDataSource<Section, ReminderList> {
    
    override func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        snapshot().sectionIdentifiers[section].sectionTitles
    }
    
    // MARK: reordering support
    override func tableView(_ tableView: UITableView, canMoveRowAt indexPath: IndexPath) -> Bool {
        return indexPath.section == 0 ? true : false
    }
    
    override func tableView(_ tableView: UITableView, moveRowAt sourceIndexPath: IndexPath, to destinationIndexPath: IndexPath) {
        guard let sourceIdentifier = itemIdentifier(for: sourceIndexPath) else { return }
        guard sourceIndexPath != destinationIndexPath else { return }
        let destinationIdentifier = itemIdentifier(for: destinationIndexPath)
        
        var snapshot = self.snapshot()
        
        if let destinationIdentifier = destinationIdentifier {
            if let sourceIndex = snapshot.indexOfItem(sourceIdentifier),
                let destinationIndex = snapshot.indexOfItem(destinationIdentifier) {
                let isAfter = destinationIndex > sourceIndex &&
                    snapshot.sectionIdentifier(containingItem: sourceIdentifier) ==
                    snapshot.sectionIdentifier(containingItem: destinationIdentifier)
                snapshot.deleteItems([sourceIdentifier])
                if isAfter {
                    snapshot.insertItems([sourceIdentifier], afterItem: destinationIdentifier)
                } else {
                    snapshot.insertItems([sourceIdentifier], beforeItem: destinationIdentifier)
                }
            }
        } else {
            let destinationSectionIdentifier = snapshot.sectionIdentifiers[destinationIndexPath.section]
            snapshot.deleteItems([sourceIdentifier])
            snapshot.appendItems([sourceIdentifier], toSection: destinationSectionIdentifier)
        }
        apply(snapshot, animatingDifferences: false)
    }
    
    
    // MARK: editing support
    override func tableView(_ tableView: UITableView, canEditRowAt indexPath: IndexPath) -> Bool {
        return true
    }
    
    override func tableView(_ tableView: UITableView, commit editingStyle: UITableViewCell.EditingStyle, forRowAt indexPath: IndexPath) {
        
        var snapshot = self.snapshot()
        let section = snapshot.sectionIdentifiers[indexPath.section]
        let item = itemIdentifier(for: indexPath)!
        
        if editingStyle == .delete {
            //MARK: Deleting from snapshot
            snapshot.deleteItems([item])
            snapshot.appendItems([item], toSection: .available)
        } else {
            switch section {
            case .include:
                snapshot.deleteItems([item])
                snapshot.appendItems([item], toSection: .available)
            case .available:
                snapshot.deleteItems([item])
                snapshot.appendItems([item], toSection: .include)
            }
        }
        
        apply(snapshot, animatingDifferences: true)
    }
    
}

class CreateGroupDatasource: NSObject {
    static let cellID = "listcell"
    
    var groupDiffableDatasource: GroupDiffableDatasource?
    var tableView: UITableView?
    
    var selectedLists = [ReminderList]()
    
    func setupDatasource() {
        guard let tableView = tableView else { return }
        groupDiffableDatasource = GroupDiffableDatasource(tableView: tableView, cellProvider: { (tableView, indexPath, list) -> UITableViewCell? in
            let cell = tableView.dequeueReusableCell(withIdentifier: CreateGroupDatasource.cellID, for: indexPath)
            cell.textLabel?.text = list.name
            return cell
        })
        
        update(withAnimation: false)
    }
    
    func update(withAnimation: Bool) {
        var snapshot = NSDiffableDataSourceSnapshot<Section, ReminderList>()
        guard let allLists = ReminderList.allListsNotInAGroup() else { return }
        
        let sections = Section.allCases
        sections.forEach{( snapshot.appendSections([$0]) )}
        
        //Add selected lists to .include secection
        for selectedList in selectedLists {
            snapshot.appendItems([selectedList], toSection: .include)
        }
        
        //Loop through sections
        for list in allLists {
            if selectedLists.contains(list) {
                snapshot.appendItems([list], toSection: .include)
            } else {
                snapshot.appendItems([list], toSection: .available)
            }
        }
        
        groupDiffableDatasource?.apply(snapshot, animatingDifferences: withAnimation, completion: nil)
    }
}

