//
//  PriorityTVC.swift
//  AppleReminders
//
//  Created by Josh R on 3/5/20.
//  Copyright © 2020 Josh R. All rights reserved.
//

import UIKit

protocol PriorityDelegate: class {
    func passPriority(priority: Reminder.Priority?)
}

final class PriorityTVC: UITableViewController {
    
    weak var delegate: PriorityDelegate?
    var selectedPriority: Reminder.Priority?
    
    let reminderPriorities = Reminder.Priority.allCases
    
    fileprivate let cellID = "priorityCell"
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: cellID)
        tableView.tableFooterView = UIView()
        self.view.backgroundColor = .systemBackground
        tableView.backgroundColor = .systemGray6
        tableView.reloadData()
        
        self.navigationItem.title = "Priority".localized
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        delegate?.passPriority(priority: selectedPriority)
    }
    
    override func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }
    
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return reminderPriorities.count
    }
    
    
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = UITableViewCell(style: .value1 , reuseIdentifier: cellID)
        let priority = reminderPriorities[indexPath.row]
        cell.textLabel?.text = priority.rawValue.capitalizeFirstLetter()
        
        if selectedPriority == priority {
            cell.accessoryType = .checkmark
        }
        cell.selectionStyle = .none
        
        return cell
    }
    
    override func tableView(_ tableView: UITableView, willDisplay cell: UITableViewCell, forRowAt indexPath: IndexPath) {
        cell.backgroundColor = .systemGray5
    }
    
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        //clear other selection cell first
        tableView.visibleCells.forEach({ $0.accessoryType = .none })
        
        let cell = tableView.cellForRow(at: indexPath)
        cell?.accessoryType = .checkmark
        
        let tappedPriority = reminderPriorities[indexPath.row]
        selectedPriority = tappedPriority
    }
    
    override func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        return UIView()
    }
    
    override func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        return 30.0
    }
    
    
}
