//
//  AddListToGroupTVC.swift
//  AppleReminders
//
//  Created by Josh R on 7/18/20.
//  Copyright © 2020 Josh R. All rights reserved.
//

import UIKit
import RealmSwift

protocol SendSelectedListsDelegate: class {
    func pass(lists: [ReminderList])
}

final class AddListToGroupTVC: UITableViewController {
    
    var selectedLists = [ReminderList]()
    
    weak var delegate: SendSelectedListsDelegate?
    
    lazy var createGroupDatasource = CreateGroupDatasource()

    override func viewDidLoad() {
        super.viewDidLoad()

        self.title = "Include".localized
        self.tableView.register(UITableViewCell.self, forCellReuseIdentifier: CreateGroupDatasource.cellID)
        self.tableView.register(AddListToGroupHeaderView.self, forHeaderFooterViewReuseIdentifier: AddListToGroupHeaderView.reuseIdentifier)
        tableView.setEditing(true, animated: false)
        tableView.tableFooterView = UIView()
        
        createGroupDatasource.tableView = tableView
        createGroupDatasource.selectedLists = selectedLists
        createGroupDatasource.setupDatasource()
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        
        addSelectedLists()
    }
    
    private func addSelectedLists() {
        guard let snapShot = createGroupDatasource.groupDiffableDatasource?.snapshot() else { return }
        selectedLists.removeAll()
        snapShot.itemIdentifiers(inSection: .include).forEach({ selectedLists.append($0) })
        
        delegate?.pass(lists: selectedLists)
        
        print("Selected lists: \(selectedLists.count)")
    }
        
    override func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        return AddListToGroupHeaderView.height
    }
    
    override func tableView(_ tableView: UITableView, editingStyleForRowAt indexPath: IndexPath) -> UITableViewCell.EditingStyle {
        guard let section = createGroupDatasource.groupDiffableDatasource?.snapshot().sectionIdentifiers[indexPath.section] else { return .none }
        
        switch section {
        case .include:
            return .delete
        case .available:
            return .insert
        }
    }
    
    override func tableView(_ tableView: UITableView, shouldIndentWhileEditingRowAt indexPath: IndexPath) -> Bool {
        return false
    }

}
