//
//  CreateGroupTVC.swift
//  AppleReminders
//
//  Created by Josh R on 7/17/20.
//  Copyright © 2020 Josh R. All rights reserved.
//

import RealmSwift
import UIKit

final class CreateGroupTVC: UITableViewController {
    
    let realm = MyRealm.getConfig()
    
    var groupToEdit: ReminderList?
    
    var groupName: String = "" {
        didSet {
            navigationItem.rightBarButtonItem?.isEnabled = groupName.isEmpty ? false : true
        }
    }
    
    var selectedLists = [ReminderList]() {
        didSet {
            let includeCell = tableView.cellForRow(at: IndexPath(row: 1, section: 0))!
            includeCell.detailTextLabel?.text = "\(selectedLists.count)"
        }
    }
    
    //Called on MainVC so the datasource can be reloaded
    var groupCreatedAction: (() -> Void)?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        self.title = groupToEdit == nil ? "New Group".localized : "Group Info".localized
        
        self.navigationItem.leftBarButtonItem = UIBarButtonItem(barButtonSystemItem: .cancel, target: self, action: #selector(cancelBtnTapped))
        createRightNavBarBtn()
        
        tableView.tableFooterView = UIView()
        
        loadListIfEditing()
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        
        //TODO:  Delete group if name is empty
    }
    
    private func createRightNavBarBtn() {
        let buttonText = groupToEdit == nil ? "Create".localized : "Done".localized
        let buttonType: UIBarButtonItem.Style = groupToEdit == nil ? .plain : .done
        self.navigationItem.rightBarButtonItem = UIBarButtonItem(title: buttonText, style: buttonType, target: self, action: #selector(createBtnTapped))
    }
    
    private func loadListIfEditing() {
        guard let groupToEdit = groupToEdit else { return }
        groupName = groupToEdit.groupName!
        groupToEdit.reminderLists.forEach({ selectedLists.append($0) })
    }
    
    @objc func createBtnTapped() {
        
        try! realm?.write {
            if let groupPassedToEdit = groupToEdit {
                groupPassedToEdit.groupName = groupName
                
                selectedLists.forEach({
                    ReminderList.removeFromGroup($0)
                    groupPassedToEdit.reminderLists.append($0)
                })
            } else {
                //Create new Group
                let group = ReminderList()
                group.groupName = groupName
                group.sortIndex = ReminderList.assignMaxSortIndex()
                
                //Check to see if list is already in another group. If so, remove it and add it to this new group
                selectedLists.forEach({
                    ReminderList.removeFromGroup($0)
                    group.reminderLists.append($0)
                })
                
                realm?.add(group)
            }
        }
        
        self.dismiss(animated: true, completion: nil)
    }
    
    @objc func cancelBtnTapped() {
        self.dismiss(animated: true, completion: nil)
    }

    // MARK: - Table view data source
    override func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return 2
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        switch indexPath.row {
        case 0:
            let groupNameCell = TextInputTVCell()
            groupNameCell.inputTextField.placeholder = "Untitled".localized
            groupNameCell.inputTextField.text = groupToEdit?.groupName ?? ""
            navigationItem.rightBarButtonItem?.isEnabled = groupNameCell.inputTextField.text!.isEmpty ? false : true
            groupNameCell.passTextFieldText = { [weak self] textFieldText in
                self?.groupName = textFieldText
            }
            return groupNameCell
        case 1:
            let includeCell = UITableViewCell(style: .value1, reuseIdentifier: nil)
            includeCell.backgroundColor = .secondarySystemGroupedBackground
            includeCell.textLabel?.text = "Include".localized
            includeCell.detailTextLabel?.text = "\(selectedLists.count)"
            includeCell.accessoryType = .disclosureIndicator
            return includeCell
        default:
            return UITableViewCell()
        }
    }
    
    override func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return 44
    }
    
    override func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        return 30
    }
    
    override func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        return UIView()
    }
    
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        switch indexPath.row {
        case 1:
            let addListToGroupTVC = AddListToGroupTVC(style: .grouped)
            addListToGroupTVC.delegate = self
            addListToGroupTVC.selectedLists = selectedLists
            self.navigationController?.pushViewController(addListToGroupTVC, animated: true)
        default:
            return
        }
    }
    

}


extension CreateGroupTVC: SendSelectedListsDelegate {
    func pass(lists: [ReminderList]) {
        selectedLists = lists
    }
    
}
