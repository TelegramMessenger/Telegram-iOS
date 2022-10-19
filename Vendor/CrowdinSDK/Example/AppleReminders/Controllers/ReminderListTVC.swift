//
//  ReminderListTVC.swift
//  AppleReminders
//
//  Created by Josh R on 1/30/20.
//  Copyright © 2020 Josh R. All rights reserved.
//

import UIKit
import RealmSwift


final class ReminderListTVC: UIViewController {
    
    let realm = MyRealm.getConfig()
    
    var vcType: VCType?

    //set at the beg of ViewDidLoad
    var passedReminderList: ReminderList?
    var reminderListToDelete: ReminderList?
    private var reminderToken: NotificationToken?
    private var reminders: Results<Reminder>?
    
    var selectedReminders = [Reminder]()
    
    var isLastCellActive = false
    
    lazy var reminderDatasource = ReminderDatasource()
    
    let footerView: AddReminderView = {
        let view = AddReminderView()
        view.state = .normal
        view.addReminderBtn.addTarget(self, action: #selector(addReminderBtnTapped), for: .touchUpInside)
        view.moveToBtn.addTarget(self, action: #selector(moveReminderBtnTapped), for: .touchUpInside)
        view.deleteBtn.addTarget(self, action: #selector(deleteReminderBtnTapped), for: .touchUpInside)
        return view
    }()
    
    lazy var navBarEllipsisBtn: EllipsisBtn = {
        let button = EllipsisBtn()
        button.addTarget(self, action: #selector(navBarBtnTapped), for: .touchUpInside)
        
        return button
    }()
    
    lazy var navBarDoneBtn: UIBarButtonItem = {
        let button = UIBarButtonItem(barButtonSystemItem: .done, target: self, action: #selector(doneBtnTapped))
        button.tintColor = .systemBlue
    
        return button
    }()
    
    @objc func doneBtnTapped() {
        //Check if nameTxtBox textField is blank.  If so, delete todo
        for cell in tableView.visibleCells {
            if let cell = cell as? ReminderTVCell {
                if cell.nameTxtBox.isFirstResponder {
                    //Delete realm reminder
                    if cell.nameTxtBox.text == "" {
                        //delete item from snapshot
                        guard let indexPath = tableView.indexPath(for: cell) else { return }
                        guard let reminder = self.reminderDatasource.reminderDiffableDatasource?.itemIdentifier(for: indexPath) else { return }
                        var snapshot = self.reminderDatasource.reminderDiffableDatasource!.snapshot()
                        snapshot.deleteItems([reminder])
                        self.reminderDatasource.reminderDiffableDatasource?.apply(snapshot, animatingDifferences: false, completion: nil)
                        //Delete empty reminder
                        reminder.deleteReminder()
                    } else {
                        cell.nameTxtBox.resignFirstResponder()
                    }
                }
            }
        }
        
        tableView.isEditing = false
        
        setupNavBar()
        footerView.state = .normal
    }
    
    @objc func addReminderBtnTapped() {
        isLastCellActive = true
        //Create new realm todo object with no name
        do {
            try realm?.write {
                let newReminder = Reminder()
                newReminder.inList = passedReminderList
                newReminder.sortIndex = newReminder.assignSortIndex()
                
                passedReminderList?.reminders.append(newReminder)
            }
        } catch {
            fatalError("Could not create new todo")
        }
    }
    
    @objc func moveReminderBtnTapped() {
        if selectedReminders.count > 0 {
            let pickListTVC = PickListTVC()
            pickListTVC.vcPurpose = .moveTo
            pickListTVC.remindersToMove = selectedReminders
            self.present(UINavigationController(rootViewController: pickListTVC), animated: true, completion: nil)
        }
    }
    
    @objc func deleteReminderBtnTapped() {
        for selectedReminder in selectedReminders {
            selectedReminder.deleteReminder()   //already in a realm write transaction
        }
        
        tableView.setEditing(false, animated: true)
    }
    
    private func activateCellForNewReminder() {
        guard let reminders = reminderDatasource.getReminders() else { return }
        if isLastCellActive {
            let indexPath = IndexPath(row: reminders.count - 1, section: 0)
            if let activeCell = tableView.cellForRow(at: indexPath) as? ReminderTVCell {
                activeCell.delegate = self
                activeCell.nameTxtBox.becomeFirstResponder()
            }
            
            isLastCellActive = false
            setupNavBarBtn()
        }
    }
    
    let tableView: UITableView = {
        let tv = UITableView(frame: .zero, style: .grouped)
        tv.backgroundColor = .systemBackground
        tv.separatorStyle = .none
        tv.tableFooterView = UIView()  //removes empty cells from the bottom
        tv.allowsMultipleSelectionDuringEditing = true
        return tv
    }()
    
    override func viewDidLoad() {
        super.viewDidLoad()
       
        RealmHelper.deleteEmptyRealmReminder()
        
        //only used for the notification
        reminders = realm?.objects(Reminder.self)
    
        switch vcType {
        case .reminderList(let list):
            passedReminderList = list
        case .scheduled, .all, .search(_):
            footerView.isHidden = true
        case .none:
            fatalError()
        default:
            break
        }
        
        setupAddBtnColors()
        addViewsToVC(views: tableView, footerView)
        setupViewConstraints()
        
        tableView.register(ReminderTVCell.self, forCellReuseIdentifier: ReminderTVCell.identifier)
        tableView.register(ReminderHeaderView.self, forHeaderFooterViewReuseIdentifier: ReminderHeaderView.reuseIdentifier)
        tableView.register(AddReminderFooterView.self, forHeaderFooterViewReuseIdentifier: AddReminderFooterView.reuseIdentifier) 
        tableView.delegate = self
        
        //setup datasource
        reminderDatasource.reminderFilter = vcType
        reminderDatasource.tableView = tableView
  
        setupNavBar()
        
        self.view.backgroundColor = .systemBackground
        
        NotificationCenter.default.addObserver(self, selector: #selector(keyboardWillShow), name: UIResponder.keyboardWillShowNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(keyboardWillHide), name: UIResponder.keyboardWillHideNotification, object: nil)
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        reminderToken = reminders?.observe { [weak self] changes in
            guard let self = self else { return }
            switch changes {
            case .initial:
                self.reminderDatasource.realmToken = self.reminderToken
                self.reminderDatasource.load()
            case .update:
                self.reminderDatasource.load()
                self.activateCellForNewReminder()
                self.setupNavBarBtn()
            case .error: break
            }
        }
        
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
       
    }
    
    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        setupNavBarBtn()
        RealmHelper.deleteEmptyRealmReminder()
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self, name: UIResponder.keyboardWillShowNotification, object: nil)
        NotificationCenter.default.removeObserver(self, name: UIResponder.keyboardWillHideNotification, object: nil)
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        reminderToken?.invalidate()

        if let _ = reminderListToDelete, let passedReminderList = passedReminderList  {
            try! realm?.write {
                self.realm?.delete(passedReminderList)
            }
        }
    }

    private func setupNavBar() {
        switch vcType! {
        case .search(_):
            return
        default:
            setupNavBarBtn()
            self.configureNavigationBar(largeTitleColor: vcType?.vcTitleColor ?? .label, backgroundColor: .systemBackground, tintColor: .systemBlue, title: vcType?.vcTitle ?? "Reminders".localized, preferredLargeTitle: true)
        }
    }
    
    private func setupNavBarBtn() {
        switch vcType! {
        case .search(_):
            return
        default:
            var isCellEditing = false
            //If any tableView cell is a firstResponder, create donebtn
            for cell in tableView.visibleCells {
                if let reminderCell = cell as? ReminderTVCell {
                    if reminderCell.nameTxtBox.isFirstResponder {
                        isCellEditing = true
                        createDoneNavBarBtn()
                    }
                }
            }
            
            if !isCellEditing {
                createEllipsisNavBarBtn()
            }
        }
    }
    
    private func createEllipsisNavBarBtn() {
        //Bar button item
        let navBtn = UIBarButtonItem()
        navBtn.customView = navBarEllipsisBtn
        self.navigationItem.rightBarButtonItem = navBtn
    }
    
    private func createDoneNavBarBtn() {
        self.navigationItem.rightBarButtonItem = navBarDoneBtn
    }
    
    @objc func navBarBtnTapped() {
        let actionSheet = UIAlertController(title: "Choose Account".localized, message: nil, preferredStyle: .actionSheet)
        
        //Name & Appearance -->  Brings up CreateListVC with passed values
        let nameAndAppearance = UIAlertAction(title: "Name & Appearance".localized, style: .default) { [weak self] _ in
            let createListVC = CreateListVC()
            createListVC.passedListToEdit = self?.passedReminderList
            self?.present(createListVC, animated: true, completion: nil)
        }
        
        //View Participants --> Brings up VC that shows the individuals in this list
        let viewParticipants = UIAlertAction(title: "View Participants".localized, style: .default) { [weak self] _ in
            self?.alert(message: "Feature not implemented.".localized, title: "Feature Unavailable".localized)
        }
        
        //Delete List -->  Ask confirmation to delete the list
        let deleteList = UIAlertAction(title: "Delete List".localized, style: .default) { [weak self, weak passedReminderList] _ in
            //Present confirmation
            let listName = passedReminderList!.name
            let ac = UIAlertController(title: #"Delete "\#(listName)?"#.localized, message: "If you delete this shared list, other people will no longer have access to it and it will be deleted from all of their devices.".localized, preferredStyle: .alert)

            let deleteAction = UIAlertAction(title: "Delete".localized, style: .destructive) { [weak self] action in
                //Delete realm list
                self?.reminderListToDelete = passedReminderList
                self?.navigationController?.popViewController(animated: true)
            }
            
            let cancelAction = UIAlertAction(title: "Cancel".localized, style: .cancel)

            ac.addAction(deleteAction)
            ac.addAction(cancelAction)
            self?.present(ac, animated: true)
        }
        
        //Select Reminders -->  TODO: puts VC in editing mode, adds two buttons to the bottom of the VC, move to and delete
        let selectReminders = UIAlertAction(title: "Select Reminders".localized, style: .default) { [weak self] _ in
            self?.tableView.allowsMultipleSelectionDuringEditing = true
            self?.tableView.isEditing = true
            self?.createDoneNavBarBtn()
            self?.footerView.state = .editing
        }
        
        //Show Completed/Hide Completed --> toggles the vc state
        let showHideText = reminderDatasource.showCompleted ? "Hide Completed".localized : "Show Completed".localized
        let showHideCompleted = UIAlertAction(title: showHideText, style: .default) { [weak self] _ in
            self?.reminderDatasource.showCompleted.toggle()
            self?.reminderDatasource.load()
        }
        
        let cancel = UIAlertAction(title: "Cancel".localized, style: .cancel, handler: nil)
        
        actionSheet.addAction(nameAndAppearance)
        actionSheet.addAction(viewParticipants)
        actionSheet.addAction(deleteList)
        actionSheet.addAction(selectReminders)
        actionSheet.addAction(showHideCompleted)
        actionSheet.addAction(cancel)
        
        present(actionSheet, animated: true, completion: nil)
    }
    
    private func addViewsToVC(views: UIView...) {
        views.forEach({ view in
            if view is NewReminderBtn {
                self.tableView.addSubview(view)
            } else {
                self.view.addSubview(view)
            }
        })
    }
    
    private func setupAddBtnColors() {
        let addReminderBtnColor = vcType?.vcTitleColor
        footerView.addReminderBtn.tintColor = addReminderBtnColor
        footerView.addReminderBtn.setTitleColor(addReminderBtnColor, for: .normal)
    }
    
    private func setupViewConstraints() {
        footerView.translatesAutoresizingMaskIntoConstraints = false
        tableView.translatesAutoresizingMaskIntoConstraints = false
        
        footerView.bottomAnchor.constraint(equalTo: self.view.bottomAnchor, constant: 0).isActive = true
        footerView.leadingAnchor.constraint(equalTo: self.view.safeAreaLayoutGuide.leadingAnchor, constant: 0).isActive = true
        footerView.trailingAnchor.constraint(equalTo: self.view.safeAreaLayoutGuide.trailingAnchor,constant: 0).isActive = true
        footerView.heightAnchor.constraint(equalToConstant: 80).isActive = true
        
        tableView.topAnchor.constraint(equalTo: self.view.safeAreaLayoutGuide.topAnchor, constant: 0).isActive = true
        tableView.bottomAnchor.constraint(equalTo: self.view.bottomAnchor, constant: 0).isActive = true
        tableView.leadingAnchor.constraint(equalTo: self.view.safeAreaLayoutGuide.leadingAnchor, constant: 0).isActive = true
        tableView.trailingAnchor.constraint(equalTo: self.view.safeAreaLayoutGuide.trailingAnchor,constant: 0).isActive = true
    }
    
    
}

extension ReminderListTVC: ReminderTVCellDelegate {
    func cellTapped(reminder: Reminder?) {
        guard let passedReminder = reminder else { return }
        let createReminderTVC = CreateReminderTVC()
        createReminderTVC.passedReminder = passedReminder
        let navController = UINavigationController(rootViewController: createReminderTVC)
        self.present(navController, animated: true, completion: nil)
    }
}

//MARK: Keyboard show/hide methods
//Source: https://stackoverflow.com/questions/24529373/tableview-scroll-content-when-keyboard-shows
extension ReminderListTVC {
    @objc func keyboardWillShow(_ notification: Notification) {
        if let keyboardSize = (notification.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? NSValue)?.cgRectValue {
            tableView.contentInset = UIEdgeInsets(top: 0, left: 0, bottom: keyboardSize.height, right: 0)
        }
    }
   
    @objc func keyboardWillHide(_ notification: Notification) {
        if let _ = (notification.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? NSValue)?.cgRectValue {
            tableView.contentInset = UIEdgeInsets(top: 0, left: 0, bottom: 0, right: 0)
        }
    }
}


extension ReminderListTVC: UITableViewDelegate {
    
    override func setEditing(_ editing: Bool, animated: Bool) {
        super.setEditing(editing, animated: animated)
        // Toggles the actual editing actions appearing on a table view
        tableView.setEditing(editing, animated: true)
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        
        //Activate textField
        let reminderCell = tableView.cellForRow(at: indexPath)
        if let cell = reminderCell as? ReminderTVCell {
            cell.nameTxtBox.becomeFirstResponder()
            cell.delegate = self
            
            if cell.isFirstResponder {
                setupNavBarBtn()
            }
        }
        
        if tableView.isEditing {
            guard let tappedReminder = reminderDatasource.reminderDiffableDatasource?.itemIdentifier(for: indexPath) else { return }
            selectedReminders.append(tappedReminder)
        }
        
//        print("IndexPath.section = \(indexPath.section), IndexPath.row = \(indexPath.row)")
    }
    
    func tableView(_ tableView: UITableView, didDeselectRowAt indexPath: IndexPath) {
        if tableView.isEditing {
            guard let tappedReminder = reminderDatasource.reminderDiffableDatasource?.itemIdentifier(for: indexPath) else { return }
            if selectedReminders.contains(tappedReminder) {
                selectedReminders.removeAll(where: { $0.reminderID == tappedReminder.reminderID })
            }
        }
    }
    
    func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        let headerView = tableView.dequeueReusableHeaderFooterView(withIdentifier: ReminderHeaderView.reuseIdentifier) as! ReminderHeaderView
        let snapShot = reminderDatasource.reminderDiffableDatasource?.snapshot()
        guard let sectionID = snapShot?.sectionIdentifiers[section] else { return nil }
        
        switch vcType! {
        case .scheduled:
            headerView.sectionDate = sectionID
        case .all, .search(_):
            let list = ReminderList.getList(by: sectionID)
            headerView.reminderList = list
        default:
            break
        }
        
        headerView.vcType = vcType

        return headerView
    }

    func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        switch vcType {
        case .scheduled, .all, .search(_):
            return ReminderHeaderView.height
        default:
            return 0
        }
    }
    
    func tableView(_ tableView: UITableView, viewForFooterInSection section: Int) -> UIView? {
        guard let vcType = vcType else { return nil }
        
        let footerView = tableView.dequeueReusableHeaderFooterView(withIdentifier: AddReminderFooterView.reuseIdentifier) as! AddReminderFooterView
        let sectionID = reminderDatasource.reminderDiffableDatasource?.snapshot().sectionIdentifiers[section] ?? ""
        
        switch vcType {
        case .scheduled:
            footerView.passReminderText = { reminderText in
                //Convert section string date to date object
                let dueDate = DateFormatters.formatEEEMMMddyyyy.date(from: sectionID)!
                let generalList = ReminderList.getGeneralList()
                if let reminderText = reminderText, !reminderText.isEmpty {
                    //addTodo method already in realm write transaction
                    Reminder.addReminder(to: generalList, name: reminderText, with: dueDate)
                }
            }
        case .all:
            footerView.passReminderText = { reminderText in
                let list = ReminderList.getList(by: sectionID)!
                if let reminderText = reminderText, !reminderText.isEmpty {
                    //addTodo method already in realm write transaction
                    Reminder.addReminder(to: list, name: reminderText)
                }
            }
        default:
            return nil
        }
        
        return footerView
    }
    
    func tableView(_ tableView: UITableView, heightForFooterInSection section: Int) -> CGFloat {
        guard let vcType = vcType else { return 0 }
        
        switch vcType {
        case .scheduled, .all:
            return AddReminderFooterView.height
        default:
            return 0
        }
    }
    
    //MARK:  Trailing swipe actions
    func tableView(_ tableView: UITableView, trailingSwipeActionsConfigurationForRowAt indexPath: IndexPath) -> UISwipeActionsConfiguration? {
        
        let delete = UIContextualAction(style: .destructive, title: "Delete".localized) { [weak self] (_, _, _)  in
            guard let self = self else { return }
            if let reminderToDelete = self.reminderDatasource.reminderDiffableDatasource?.itemIdentifier(for: indexPath) {
                //MARK: Deleting from snapshot
                var snapshot = self.reminderDatasource.reminderDiffableDatasource?.snapshot()
                snapshot!.deleteItems([reminderToDelete])
                self.reminderDatasource.reminderDiffableDatasource?.apply(snapshot!)
                
                //Delete item from Realm -- also deletes any subtasks.  Already in a realm write block
                reminderToDelete.deleteReminder()
            }
        }
        
        let flag = UIContextualAction(style: .normal, title: "Flag".localized) { [weak self] (_, _, _)  in
            guard let self = self else { return }
            if let identifierToFlag = self.reminderDatasource.reminderDiffableDatasource?.itemIdentifier(for: indexPath) {
                
                //Flag item from Realm
                let realm = MyRealm.getConfig()
                try! realm!.write {
                    identifierToFlag.isFlagged.toggle()
                }
            }
        }
        
        flag.backgroundColor = .systemOrange
        
        return UISwipeActionsConfiguration(actions: [delete, flag])
    }
    
    //MARK:  Leading swipe actions
    func tableView(_ tableView: UITableView, leadingSwipeActionsConfigurationForRowAt indexPath: IndexPath) -> UISwipeActionsConfiguration? {
        
        switch vcType! {
        case .search(_):
            return nil  //not allowed if searching for a reminder
        default:
            if indexPath.row > 0 {
                guard let reminder = reminderDatasource.reminderDiffableDatasource?.itemIdentifier(for: indexPath) else { return nil }
                let actionText = reminder.isSubtask ? "Outdent".localized : "Indent".localized
                
                let indent = UIContextualAction(style: .normal, title: actionText) { [weak self] (_, _, _)  in
                    guard let self = self else { return }
                    if let reminder = self.reminderDatasource.reminderDiffableDatasource?.itemIdentifier(for: indexPath) {
                        if reminder.isSubtask {
                            reminder.outdentReminder()
                        } else {
                            reminder.indentReminder()
                        }
                    }
                }
                
                indent.backgroundColor = .systemGray
                
                return UISwipeActionsConfiguration(actions: [indent])
            }
        }
        
        return nil
    }

    func tableView(_ tableView: UITableView, shouldIndentWhileEditingRowAt indexPath: IndexPath) -> Bool {
        return false
    }
    
}

//MARK: VCType enum
extension ReminderListTVC {
    //this TVC has several purposes
    enum VCType {
        case reminderList(ReminderList)
        case today
        case scheduled
        case all
        case flagged
        case search(String)
        
        fileprivate var vcTitle: String {
            switch self {
            case .reminderList(let list):
                return list.name
            case .today:
                return "Today".localized
            case .scheduled:
                return "Scheduled".localized
            case .all:
                return "All".localized
            case .flagged:
                return "Flagged".localized
            case .search:
                //Not title text needed
                return ""
            }
        }
        
        fileprivate var vcTitleColor: UIColor {
            switch self {
            case .reminderList(let list):
                return CustomColors.systemColorsDict[list.listColor] ?? UIColor.label
            case .today:
                return .systemBlue
            case .scheduled:
                return .systemOrange
            case .all:
                return .darkGray
            case .flagged:
                return .systemRed
            case .search:
                //No title color needed
                return .label
            }
        }
    }
}
