//
//  PickListTVC.swift
//  AppleReminders
//
//  Created by Josh R on 3/7/20.
//  Copyright © 2020 Josh R. All rights reserved.
//

import UIKit
import RealmSwift
import SwiftUI

protocol PassSelectedListDelegate: class {
    func pass(selectedList: ReminderList)
}

final class PickListTVC: UIViewController {
    
    let realm = MyRealm.getConfig()
    
    fileprivate let cellID = "PickListCellID"
    
    var vcPurpose: VCPurpose?
    
    let allLists = ReminderList.getAllLists(isGroupsIncluded: false)
    var passedReminder: Reminder?
    var remindersToMove: [Reminder]?
    
    weak var delegate: PassSelectedListDelegate?
    
    let tableView: UITableView = {
        let tv = UITableView()
        tv.backgroundColor = .systemBackground
        tv.translatesAutoresizingMaskIntoConstraints = false
        return tv
    }()
    
    lazy var moveRemindersDetailView: MoveRemindersDetailView = {
        let view = MoveRemindersDetailView()
        return view
    }()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        setupTableView()
        
        navigationItem.title = vcPurpose?.vcTitle ?? ""
        navigationController?.navigationBar.backgroundColor = .systemBackground
        
        createMoveRemindersText()
        
        addViews(views: moveRemindersDetailView, tableView)
        setConstraints()
    }
    
    private func createMoveRemindersText() {
        guard let remindersToMove = remindersToMove, let reminderToMove = remindersToMove.first, let vcPurpose = vcPurpose else { return }
        let firstReminder = reminderToMove.name
        
        if vcPurpose == .moveTo {
            var text = firstReminder
            if remindersToMove.count > 1 {
                text += " and \(remindersToMove.count - 1) others"
            }
            
            moveRemindersDetailView.reminderDescLbl.text = text
        }
    }
    
    //call in ViewDidLoad
    private func setupTableView() {
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: cellID)
        tableView.delegate = self
        tableView.dataSource = self
        tableView.tableFooterView = UIView()
        
        view.addSubview(tableView)
    }
    
    private func addViews(views: UIView...) {
        views.forEach({
            self.view.addSubview($0)
            $0.translatesAutoresizingMaskIntoConstraints = false
        })
    }
    
    private func setConstraints() {
        let moveRemindersDetailViewHeight: CGFloat = vcPurpose! == .pick ? 0 : 48
        NSLayoutConstraint.activate([
            moveRemindersDetailView.topAnchor.constraint(equalTo: self.view.safeAreaLayoutGuide.topAnchor),
            moveRemindersDetailView.rightAnchor.constraint(equalTo: self.view.rightAnchor),
            moveRemindersDetailView.leftAnchor.constraint(equalTo: self.view.leftAnchor),
            moveRemindersDetailView.heightAnchor.constraint(equalToConstant: moveRemindersDetailViewHeight),
            
            tableView.topAnchor.constraint(equalTo: moveRemindersDetailView.bottomAnchor),
            tableView.bottomAnchor.constraint(equalTo: self.view.bottomAnchor),
            tableView.rightAnchor.constraint(equalTo: self.view.rightAnchor),
            tableView.leftAnchor.constraint(equalTo: self.view.leftAnchor)
        ])
    }
    
    
    
}

extension PickListTVC: UITableViewDelegate, UITableViewDataSource {
    
    func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        // #warning Incomplete implementation, return the number of rows
        guard let list = allLists else { return 0 }
        return list.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = UITableViewCell(style: .value1, reuseIdentifier: cellID)
        
        let list = allLists?[indexPath.row]
        cell.textLabel?.text = list?.name ?? ""
        cell.textLabel?.textColor = list?.listUIColor
        
        let listID = remindersToMove?.first?.inList?.reminderListID ?? passedReminder?.inList?.reminderListID ?? ""
        if list?.reminderListID == listID {
            cell.accessoryType = .checkmark
        }
        
        return cell
    }
    
    func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        return "My Lists".localized
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        guard let tappedList = allLists?[indexPath.row] else { return }
        guard let vcPurpose = vcPurpose else { return }
        
        switch vcPurpose {
        case .pick:
            delegate?.pass(selectedList: tappedList)
            self.navigationController?.popViewController(animated: true)
        case .moveTo:
            //Already in a realm write transaction
            guard let remindersToMove = remindersToMove else { return }
            Reminder.assignReminders(to: tappedList, reminders: remindersToMove)
            self.dismiss(animated: true, completion: nil)
        }
    }
}


extension PickListTVC {
    enum VCPurpose {
        case pick
        case moveTo
        
        var vcTitle: String {
            switch self {
            case .pick:
                return "Change List".localized
            case .moveTo:
                return "Select a List".localized
            }
        }
    }
}
