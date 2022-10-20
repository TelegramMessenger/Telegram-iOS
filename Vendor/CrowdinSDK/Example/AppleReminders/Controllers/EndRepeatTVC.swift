//
//  EndRepeatTVC.swift
//  AppleReminders
//
//  Created by Josh R on 4/29/20.
//  Copyright © 2020 Josh R. All rights reserved.
//

import UIKit

protocol EndRepeatDelegate: class {
    func pass(repeatEndDate: Date?)
}

final class EndRepeatTVC: UITableViewController {
    
    weak var delegate: EndRepeatDelegate?
    var selectedRepeatEndDate: Date?
    
    var isDatePickerVisible = false
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        tableView.tableFooterView = UIView()
        self.view.backgroundColor = .systemBackground
        tableView.backgroundColor = .systemGray6
        tableView.reloadData()
        
        self.navigationItem.title = "End Repeat".localized
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        delegate?.pass(repeatEndDate: selectedRepeatEndDate)
    }
    
    // MARK: - Table view data source
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return selectedRepeatEndDate == nil ? 2 : 3
    }
    
    
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        
        switch indexPath.row {
        case 0:
            let cell = UITableViewCell(style: .default , reuseIdentifier: nil)
            cell.textLabel?.text = "Repeat Forever".localized
            return cell
        case 1:
            let cell = UITableViewCell(style: .default , reuseIdentifier: nil)
            cell.textLabel?.text = "End Repeat Date".localized
            return cell
        case 2:
            let cell = DatePickerTVCell()
            cell.datePicker.datePickerMode = .date
            cell.datePicker.date = selectedRepeatEndDate ?? Date()
            cell.passDate = { [weak self] date in
                if date < Date() {
                    self?.selectedRepeatEndDate = Date()
                    cell.datePicker.date = Date()
                } else {
                    self?.selectedRepeatEndDate = date
                }
            }
            return cell
        default:
            return UITableViewCell()
        }
    }
    
    override func tableView(_ tableView: UITableView, willDisplay cell: UITableViewCell, forRowAt indexPath: IndexPath) {
        cell.backgroundColor = .systemGray5
        
        switch indexPath.row {
        case 0:
            cell.accessoryType = selectedRepeatEndDate == nil ? .checkmark : .none
        case 1:
            cell.accessoryType = selectedRepeatEndDate != nil ? .checkmark : .none
        default:
            break
        }
    }
    
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        if selectedRepeatEndDate == nil {
            selectedRepeatEndDate = Date()
        }
        
        //clear other selection cell first
        tableView.visibleCells.forEach({ $0.accessoryType = .none })
        
        let cell = tableView.cellForRow(at: indexPath)
        cell?.accessoryType = .checkmark
        
        tableView.deselectRow(at: indexPath, animated: true)
        
        let datePickerIndexPath = IndexPath(row: 2, section: 0)
        
        switch indexPath.row {
        case 0:
            isDatePickerVisible = false
            selectedRepeatEndDate = nil
            if tableView.visibleCells.count > 2 {
                let datePickerIndexPath = IndexPath(row: 2, section: 0)
                tableView.beginUpdates()
                tableView.deleteRows(at: [datePickerIndexPath], with: .top)
                tableView.endUpdates()
            }
        case 1:
            tableView.deselectRow(at: indexPath, animated: true)
            isDatePickerVisible = true
            if tableView.visibleCells.count == 2 {
                tableView.beginUpdates()
                tableView.insertRows(at: [datePickerIndexPath], with: .top)
                tableView.endUpdates()
            }
        default:
            break
        }
    }
    
    override func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        return UIView()
    }
    
    override func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        return 30.0
    }
    
    
}
