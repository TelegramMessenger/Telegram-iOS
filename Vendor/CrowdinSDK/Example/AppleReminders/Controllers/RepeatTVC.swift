//
//  RepeatTVC.swift
//  AppleReminders
//
//  Created by Josh R on 4/27/20.
//  Copyright © 2020 Josh R. All rights reserved.
//

import UIKit
import RealmSwift

protocol RepeatDelegate: class {
    func pass(repeatOption: Reminder.RepeatingPeriod?)
}


final class RepeatTVC: UITableViewController {
    
    weak var delegate: RepeatDelegate?
    var selectedRepeatPeriod: Reminder.RepeatingPeriod?
    
    let repeatOptions = Reminder.RepeatingPeriod.allCases
    
    let cellID = "repeatCell"
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: cellID)
        tableView.tableFooterView = UIView()
        self.view.backgroundColor = .systemBackground
        tableView.backgroundColor = .systemGray6
        tableView.reloadData()
        
        self.navigationItem.title = "Repeat".localized
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        delegate?.pass(repeatOption: selectedRepeatPeriod)
    }
    
    // MARK: - Table view data source
    override func numberOfSections(in tableView: UITableView) -> Int {
        return 2
    }
    
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        switch section {
        case 0:
            return repeatOptions.count - 1  //minus one to removed Custom option
        case 1:
            return 1
        default:
            return 0
        }
    }
    
    
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = UITableViewCell(style: .value1 , reuseIdentifier: cellID)
        
        var repeatText = ""
        
        switch indexPath.section {
        case 0:
            repeatText = repeatOptions[indexPath.row].rawValue
        case 1:
            repeatText = repeatOptions.last?.rawValue ?? ""
        default:
            break
        }
        
        cell.textLabel?.text = repeatText
        
        if selectedRepeatPeriod == Reminder.RepeatingPeriod(rawValue: repeatText) {
            cell.accessoryType = .checkmark
        }
        cell.selectionStyle = .none
        
        return cell
    }
    
    override func tableView(_ tableView: UITableView, willDisplay cell: UITableViewCell, forRowAt indexPath: IndexPath) {
        cell.backgroundColor = .systemGray5
        
        if indexPath.section == 1 {
            cell.accessoryType = .disclosureIndicator
        }
    }
    
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        //clear other selection cell first
        tableView.visibleCells.forEach({ $0.accessoryType = .none })
        
        let cell = tableView.cellForRow(at: indexPath)
        cell?.accessoryType = .checkmark
        
        let tappedRepeatOption = indexPath.section == 1 ? repeatOptions.last : repeatOptions[indexPath.row]
        selectedRepeatPeriod = tappedRepeatOption
        
        self.navigationController?.popViewController(animated: true)
    }
    
    override func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        return UIView()
    }
    
    override func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        return 30.0
    }
    
    
}
