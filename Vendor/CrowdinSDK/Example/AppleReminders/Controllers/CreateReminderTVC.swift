//
//  CreateReminderTVC.swift
//  AppleReminders
//
//  Created by Josh R on 2/28/20.
//  Copyright © 2020 Josh R. All rights reserved.
//

import UIKit
import RealmSwift
import SwiftUI
import ContactsUI

final class CreateReminderTVC: UITableViewController {
    
    let realm = MyRealm.getConfig()
    
    var passedReminder: Reminder?
    var tempReminder: Reminder?  //unmanaged realm object, do not need to place in write transaction when changing values
    
    var isDatePickerVisible = false
    var isSelectedContactCellVisible = false
    
    lazy var navBarDoneBtn: UIBarButtonItem = {
        let button = UIBarButtonItem(barButtonSystemItem: .done, target: self, action: #selector(doneBtnTapped))
        button.tintColor = .systemBlue
        
        return button
    }()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        tempReminder = Reminder(value: passedReminder as Any)
        
        self.view.backgroundColor = .systemGroupedBackground
        tableView.backgroundColor = .systemGroupedBackground
        tableView.tableFooterView = UIView()
        tableView.keyboardDismissMode = .onDrag
        tableView.reloadData()
        
        setupNavBar()
    }
    
    private func setupNavBar() {
        self.navigationItem.title = "Details".localized
        self.navigationItem.rightBarButtonItem = navBarDoneBtn
        self.navigationController?.navigationBar.barTintColor = .systemGray5
    }
    
    @objc func doneBtnTapped() {
        passedReminder?.updateReminder(modifiedReminder: tempReminder)
        self.dismiss(animated: true, completion: nil)
    }
    
    
    // MARK: - Table view data source
    override func numberOfSections(in tableView: UITableView) -> Int {
        return 7
    }
    
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        switch section {
        case 0:
            return 3
        case 1:
            var numberOfRowsToReturn = 0
            numberOfRowsToReturn = tempReminder?.isRemindOnADay ?? false ? 4 : 1
            numberOfRowsToReturn += isDatePickerVisible ? 1 : 0
            
            if tempReminder?.isRepeatable == true {
                numberOfRowsToReturn += 1
            }
            
            return numberOfRowsToReturn
        case 2: //Location section
            return tempReminder?.isLocationReminder ?? false ? 2 : 1
        case 3:  //Contact Section
            return tempReminder!.contactID.count > 0 ? 2 : 1
        case 4:
            return tempReminder!.isSubtask ? 2 : 3
        case 5:
            return tempReminder!.isSubtask ? 0 : 1
        case 6:
            return 1
        default:
            return 0
        }
    }
    
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let toggleCell = ToggleTVCell()
        let cell = UITableViewCell(style: .value1 , reuseIdentifier: nil)
        let subTitleCell = UITableViewCell(style: .subtitle , reuseIdentifier: nil)
        
        //MARK: Assign cells to indexPath
        switch indexPath.section {
        //MARK: Section 0 - Title, Notes, and URL
        case 0:
            switch indexPath.row {
            case 0:
                let reminderNameCell = TextInputTVCell()
                reminderNameCell.setupTextInputTVCell(with: tempReminder?.name ?? "", placeholderText: "Title".localized)
                reminderNameCell.passTextFieldText = { [weak self] textFieldText in
                    self?.tempReminder?.name = textFieldText
                }
                return reminderNameCell
            case 1:
                let noteCell = TextInputTVCell()
                noteCell.setupTextInputTVCell(with: tempReminder?.note ?? "", placeholderText: "Notes".localized)
                noteCell.passTextFieldText = { [weak self] textFieldText in
                    self?.tempReminder?.note = textFieldText
                }
                return noteCell
            case 2:
                let urlCell = TextInputTVCell()
                urlCell.setupTextInputTVCell(with: tempReminder?.url ?? "", placeholderText: "URL".localized)
                urlCell.passTextFieldText = { [weak self] textFieldText in
                    self?.tempReminder?.url = textFieldText
                }
                urlCell.inputTextField.autocapitalizationType = .none
                return urlCell
            default:
                return UITableViewCell()
            }
            
        //MARK: Section 1 - Remind me on a day
        case 1:
            switch indexPath.row {
            case 0:  //Remind me on a day
                let reminderMeCell = CreateReminderCellManager.remindMeOnADay(for: tempReminder) {
                    tableView.performBatchUpdates({tableView.reloadSections(IndexSet(arrayLiteral:1), with: .automatic)})
                }
                return reminderMeCell
            case 1:
                let alarmCell = CreateReminderCellManager.alarmCell(for: tempReminder, isDatePickerVisible: isDatePickerVisible)
                return alarmCell
            case 2: //Remind me at a time
                if isDatePickerVisible {
                    let datePickerCell = CreateReminderCellManager.datePickerCell(for: tempReminder) {
                        tableView.reloadRows(at: [IndexPath(row: 1, section: 1)], with: .none)
                    }
                    return datePickerCell
                } else {
                    let reminderMeAtATimeCell = CreateReminderCellManager.remindMeAtATime(for: tempReminder) {
                        tableView.reloadRows(at: [IndexPath(row: 1, section: 1)], with: .none)
                    }
                    return reminderMeAtATimeCell
                }
            case 3: //Repeat
                if isDatePickerVisible {
                    let toggleCell = CreateReminderCellManager.remindMeAtATime(for: tempReminder) {
                        tableView.performBatchUpdates({
                            tableView.reloadRows(at: [
                                IndexPath(row: 1, section: 1),
                                IndexPath(row: 2, section: 1)], with: .none)
                        }, completion: nil)
                    }
                    return toggleCell
                } else {
                    let repeatCell = CreateReminderCellManager.repeatReminder(for: tempReminder)
                    return repeatCell
                }
            case 4: //Repeat
                if isDatePickerVisible {
                    let repeatCell = CreateReminderCellManager.repeatReminder(for: tempReminder)
                    return repeatCell
                } else {
                    let endRepeatCell = CreateReminderCellManager.endRepeatReminder(for: tempReminder)
                    return endRepeatCell
                }
            case 5: //End Repeat
                let endRepeatCell = CreateReminderCellManager.endRepeatReminder(for: tempReminder)
                return endRepeatCell
            default:
                return UITableViewCell()
            }
            
            
        //MARK: Section 2 - Remind me at a location
        case 2:
            switch indexPath.row {
            case 0:
                let locationCell = CreateReminderCellManager.location(for: tempReminder) {
                    tableView.performBatchUpdates({tableView.reloadSections(IndexSet(arrayLiteral:2), with: .automatic)})
                }
                return locationCell
            case 1:
                subTitleCell.textLabel?.text = "Location".localized
                subTitleCell.accessoryType = .disclosureIndicator
                return subTitleCell
            default:
                return UITableViewCell()
            }
            
        //MARK: Section 3 - Remind me when messaging
        case 3:
            switch indexPath.row {
            case 0:
                let toggleCell = CreateReminderCellManager.messaging(for: tempReminder) { [weak self] in
                    self?.isSelectedContactCellVisible = toggleCell.switchToggle.isOn
                    tableView.performBatchUpdates({tableView.reloadSections(IndexSet(arrayLiteral:3), with: .automatic)})
                }
                return toggleCell
            case 1:
                if let contactCell = CreateReminderCellManager.contact(for: tempReminder) as? ReminderContactTVCell {
                    contactCell.editBtnTappedCallback = { [weak self] _ in
                        let contactPicker = CNContactPickerViewController()
                        contactPicker.delegate = self
                        self?.present(contactPicker, animated: true)
                    }
                    return contactCell
                } else {
                    return CreateReminderCellManager.contact(for: tempReminder)
                }
            default:
                return UITableViewCell()
            }
            
        //MARK: Section 4 - Flagged, Priority, and List
        case 4:
            switch indexPath.row {
            case 0: //Flagged
                toggleCell.setupToggleTVCell(with: "Flagged".localized, isSwitchOn: tempReminder?.isFlagged ?? false)
                toggleCell.switchToggleAction = { [weak self] _ in
                    self?.tempReminder?.isFlagged.toggle()
                }
                return toggleCell
            case 1: //Priority
                cell.textLabel?.text = "Priority".localized
                cell.detailTextLabel?.text = tempReminder?.priority.capitalizeFirstLetter() ?? "None".localized
                cell.accessoryType = .disclosureIndicator
                return cell
            case 2: //List
                cell.textLabel?.text = "List".localized
                cell.detailTextLabel?.text = tempReminder?.inList?.name ?? ""
                cell.accessoryType = .disclosureIndicator
                return cell
            default:
                return UITableViewCell()
            }
            
        //MARK: Section 5 - Subtasks
        case 5:
            cell.textLabel?.text = "Subtasks".localized
            cell.detailTextLabel?.text = String(tempReminder?.subtasks.count ?? 0)
            cell.accessoryType = .disclosureIndicator
            return cell
            
        //MARK: Section 6 - Add image
        case 6:
            cell.textLabel?.text = "Add Image".localized
            cell.textLabel?.textColor = .systemBlue
            return cell
        default:
            return UITableViewCell()
        }
    }
    
    override func tableView(_ tableView: UITableView, willDisplay cell: UITableViewCell, forRowAt indexPath: IndexPath) {
        cell.backgroundColor = .secondarySystemGroupedBackground
    }
    
    override func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        switch section {
        case 0:
            return 20.0
        default:
            return 0.0
        }
    }
    
    override func tableView(_ tableView: UITableView, heightForFooterInSection section: Int) -> CGFloat {
        switch section {
        case 3:
            return 44
        case 5:
            return tempReminder!.isSubtask ? 0 : 30
        default:
            return 30
        }
    }
    
    override func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        switch section {
        case 0:
            return UIView()
        default:
            return nil
        }
    }
    
    override func tableView(_ tableView: UITableView, viewForFooterInSection section: Int) -> UIView? {
        switch section {
        case 0, 1, 2, 4, 5, 6:
            return UIView()
        case 3:
            let footerView = SimpleFooterView()
            footerView.textLbl.text = "Selecting this option will show the reminder notification when chatting with a person in Messages.".localized
            return footerView
        default:
            return nil
        }
    }
    
    override func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        if isDatePickerVisible {
            switch indexPath.section {
            case 1:
                switch indexPath.row {
                case 2:
                    return 150.0
                default:
                    return 44.0
                }
            default:
                return 44.0
            }
            
        } else {
            return 44.0
        }
    }
    
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        switch indexPath.section {
        case 0: //Title, Notes, and URL
            break
        case 1: //Remind me on a day
            switch indexPath.row {
            case 1:
                isDatePickerVisible.toggle()
                tableView.performBatchUpdates({tableView.reloadSections(IndexSet(arrayLiteral:1), with: .automatic)})
            case 3:
                let repeatTVC = RepeatTVC()
                repeatTVC.selectedRepeatPeriod = Reminder.RepeatingPeriod(rawValue: tempReminder?.frequency ?? "")
                repeatTVC.delegate = self
                self.navigationController?.pushViewController(repeatTVC, animated: true)
            case 4:
                let endRepeatTVC = EndRepeatTVC()
                endRepeatTVC.selectedRepeatEndDate = tempReminder?.repeatEndDate
                endRepeatTVC.delegate = self
                self.navigationController?.pushViewController(endRepeatTVC, animated: true)
            default:
                break
            }
        case 2: //Remind me on a location
            break
        case 3: //Remind me when messaging
            switch indexPath.row {
            case 1:
                //If user has already selected a contact, hitting the Edit cell button then launches the CNContactPickerViewController
                if let _ = tempReminder?.retrieveContact {
                    tableView.deselectRow(at: indexPath, animated: true)
                    return
                }
                let contactPicker = CNContactPickerViewController()
                contactPicker.delegate = self
                present(contactPicker, animated: true)
            default:
                break
            }
        case 4:
            switch indexPath.row {
            case 1: //Priority
                let priorityTVC = PriorityTVC()
                priorityTVC.selectedPriority = Reminder.Priority(rawValue: tempReminder?.priority ?? Reminder.Priority.none.rawValue)
                priorityTVC.delegate = self
                self.navigationController?.pushViewController(priorityTVC, animated: true)
            case 2: //tapped on List cell
                let pickListTVC = PickListTVC()
                pickListTVC.vcPurpose = .pick
                pickListTVC.delegate = self
                pickListTVC.passedReminder = tempReminder
                self.navigationController?.pushViewController(pickListTVC, animated: true)
            default:
                break
            }
        case 5:
            let subTaskTVC = SubtaskTVC()
            subTaskTVC.delegate = self
            subTaskTVC.parentReminder = tempReminder
            self.navigationController?.pushViewController(subTaskTVC, animated: true)
        case 6:
            switch indexPath.row {
            case 0:
                //TODO:  Add image VC
                //Ask permissions
                //Bring up photo vc
                break
            default:
                break
            }
        default:
            break
        }
    }
     
}

extension CreateReminderTVC: PriorityDelegate {
    func passPriority(priority: Reminder.Priority?) {
        tempReminder?.priority = priority?.rawValue ?? Reminder.Priority.none.rawValue
        tableView.reloadRows(at: [IndexPath(row: 1, section: 4)], with: .none)
    }
}

extension CreateReminderTVC: PassSelectedListDelegate {
    func pass(selectedList: ReminderList) {
        tempReminder?.inList = selectedList
        
        //Update cell text
        let indexPath = IndexPath(row: 2, section: 4)
        let listcell = tableView.cellForRow(at: indexPath)
        listcell?.detailTextLabel?.text = selectedList.name
    }
}

extension CreateReminderTVC: RepeatDelegate {
    func pass(repeatOption: Reminder.RepeatingPeriod?) {
        tempReminder?.frequency = repeatOption?.rawValue
        tableView.performBatchUpdates({tableView.reloadSections(IndexSet(arrayLiteral: 1), with: .automatic)})
    }
}

extension CreateReminderTVC: EndRepeatDelegate {
    func pass(repeatEndDate: Date?) {
        tempReminder?.repeatEndDate = repeatEndDate
        if isDatePickerVisible {
            tableView.reloadRows(at: [IndexPath(row: 5, section: 1)], with: .none)
        } else {
            tableView.reloadRows(at: [IndexPath(row: 4, section: 1)], with: .none)
        }
    }
    
}

extension CreateReminderTVC: PassSubtasksDelegate {
    func pass(subtasks: [Reminder]) {
        
        try! realm?.write {
            for (index, subtask) in subtasks.enumerated() {
                subtask.sortIndex = index
                subtask.inList = tempReminder?.inList
                if !subtasks.contains(subtask) {
                    tempReminder?.subtasks.append(subtask)
                }
            }
        }
        
        //Reload subtask section cell to update label subtask count
        tableView.performBatchUpdates({tableView.reloadSections(IndexSet(arrayLiteral:5), with: .none)})
    }
}

//MARK: - CNContactPickerDelegate
extension CreateReminderTVC: CNContactPickerDelegate {
    func contactPicker(_ picker: CNContactPickerViewController, didSelect contact: CNContact) {
        print("GivenName: \(contact.givenName), familyName: \(contact.familyName), ID: \(contact.identifier)")
        try! realm?.write { tempReminder?.contactID = contact.identifier }
        tableView.reloadRows(at: [IndexPath(row: 1, section: 3)], with: .none)
    }
}
