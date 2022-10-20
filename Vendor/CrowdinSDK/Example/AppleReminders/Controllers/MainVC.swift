//
//  ViewController.swift
//  AppleReminders
//
//  Created by Josh R on 1/24/20.
//  Copyright © 2020 Josh R. All rights reserved.
//

import RealmSwift
import SwiftUI
import UIKit

final class MainVC: UIViewController {
    
    let realm = MyRealm.getConfig()
    
    var listDiffableDatasource: ListDiffableDatasource?
    
    //Used to show Today, Scheduled, All, and Flagged.  Section 0 row 0, "type" section, inside tv cell
    lazy var childVC = MainChildCollectionVC()
    
    let tableView: UITableView = {
        let tv = UITableView(frame: .zero, style: .insetGrouped)
        tv.separatorStyle = .none
        tv.backgroundColor = .systemGroupedBackground
        tv.contentInset = UIEdgeInsets(top: 0, left: 0, bottom: 50, right: 0)
        return tv
    }()
    
    var searchController: UISearchController?
    var searchControllerVC: ReminderListTVC?
    
    private var realmListToken: NotificationToken?
    
    
    let footerView: AddListView = {
        let view = AddListView()
        return view
    }()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        print("Default realm location: \(String(describing: realm?.configuration.fileURL))")
        
        self.view.backgroundColor = .systemGroupedBackground
        
        //Uncomment if you want to start over
//        try! realm?.write {
//            realm?.deleteAll()
//        }
        
        //Generates new Realm data
        if realm?.objects(ReminderList.self).count == 0 {
            // Uncomment if you don't want to have default Reminder list
//            SampleRealmData.createTestRealmData()
//            SampleRealmData.addRemindersToCurrentModel()
        }
        
        setupTableView()
        addListView()
        footerView.addListBtn.addTarget(self, action: #selector(addListBtnTapped), for: .touchUpInside)
        footerView.settingsBtn.addTarget(self, action: #selector(settingsBtnTapped), for: .touchUpInside)
        footerView.addGroupBtn.addTarget(self, action: #selector(addGroupBtnTapped), for: .touchUpInside)
        
        childVC.didTapCell = { type in
            let reminderTVC = ReminderListTVC()
            switch type {
            case .today:
                reminderTVC.vcType = .today
            case .scheduled:
                reminderTVC.vcType = .scheduled
            case .all:
                reminderTVC.vcType = .all
            case .flagged:
                reminderTVC.vcType = .flagged
            }
            
            guard let allLists = ReminderList.getAllLists(isGroupsIncluded: true), allLists.count > 0 else { return }
            self.navigationController?.pushViewController(reminderTVC, animated: true)
        }
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        realmListToken = realm?.objects(ReminderList.self).observe { [weak self] changes in
            guard let self = self else { return }
            switch changes {
            case .initial:
                self.setupDatasource()
            case .update:
                self.updateDatasource()
                
                for cell in self.tableView.visibleCells {
                    cell.layoutSubviews()
                }
            case .error: break
            }
        }
        
        setupNavBar()
        setupSearch()
    }
    
    deinit {
        realmListToken?.invalidate()
        print("MainVC deinit")
    }
    
    private func setupTableView() {
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: "BlankTVCell")
        tableView.register(ReminderListTVCell.self, forCellReuseIdentifier: ReminderListTVCell.reuseIdentifier)
        tableView.register(ListSectionHeaderView.self, forHeaderFooterViewReuseIdentifier: ListSectionHeaderView.reuseIdentifier)
        view.addSubview(tableView)
        tableView.delegate = self
        
        tableView.separatorStyle = .singleLine
        tableView.separatorInset = UIEdgeInsets(top: 0, left: 50, bottom: 0, right: 0)
        
        tableView.translatesAutoresizingMaskIntoConstraints = false
        
        NSLayoutConstraint.activate([
            tableView.leadingAnchor.constraint(equalTo: self.view.leadingAnchor, constant: 2),
            tableView.trailingAnchor.constraint(equalTo: self.view.trailingAnchor, constant: -2),
            tableView.bottomAnchor.constraint(equalTo: self.view.safeAreaLayoutGuide.bottomAnchor, constant: 0),
            tableView.topAnchor.constraint(equalTo: self.view.safeAreaLayoutGuide.topAnchor, constant: 0)
        ])
    }
    
    @objc func addListBtnTapped() {
        let createListVC = CreateListVC()
        present(createListVC, animated: true, completion: nil)
    }
    
    @objc func settingsBtnTapped() {
        let settingsVC = SettingsVC()
        let settingsNC = UINavigationController(rootViewController: settingsVC)
        present(settingsNC, animated: true, completion: nil)
    }
    
    @objc func addGroupBtnTapped() {
        let createGroupVC = UINavigationController(rootViewController: CreateGroupTVC())
        present(createGroupVC, animated: true, completion: nil)
    }
    
    // MARK: -Privates
    
    private func addViews(views: UIView...) {
        views.forEach({ self.view.addSubview($0) })
    }
    
    private func addListView() {
        addViews(views: footerView)
        
        footerView.translatesAutoresizingMaskIntoConstraints = false
        footerView.bottomAnchor.constraint(equalTo: self.view.bottomAnchor, constant: 0).isActive = true
        footerView.leadingAnchor.constraint(equalTo: self.view.safeAreaLayoutGuide.leadingAnchor, constant: 0).isActive = true
        footerView.trailingAnchor.constraint(equalTo: self.view.safeAreaLayoutGuide.trailingAnchor,constant: 0).isActive = true
        footerView.heightAnchor.constraint(equalToConstant: 75).isActive = true
    }
    
    private func setupNavBar() {
        navigationItem.rightBarButtonItem = editButtonItem
        navigationController?.navigationBar.prefersLargeTitles = false
        navigationController?.navigationBar.isTranslucent = true
        
        let navBarAppearance = UINavigationBarAppearance()
        navBarAppearance.configureWithOpaqueBackground()
        navBarAppearance.backgroundColor = .systemGroupedBackground
        navBarAppearance.shadowColor = .clear
        
        navigationController?.navigationBar.standardAppearance = navBarAppearance
        navigationController?.navigationBar.compactAppearance = navBarAppearance
        navigationController?.navigationBar.scrollEdgeAppearance = navBarAppearance
        
        //Change the back button text
        let backItem = UIBarButtonItem()
        backItem.title = "Lists".localized
        navigationItem.backBarButtonItem = backItem
    }
    
    private func setupSearch() {
        searchControllerVC = ReminderListTVC()
        searchControllerVC?.vcType = .search("")
        searchController = UISearchController(searchResultsController: searchControllerVC)
        searchController?.searchResultsUpdater = self
        searchController?.obscuresBackgroundDuringPresentation = false
        searchController?.searchBar.placeholder = "Search".localized
        navigationItem.searchController = searchController
    }
}

//MARK: Datasource
extension MainVC {
    func setupDatasource() {
        listDiffableDatasource = ListDiffableDatasource(tableView: tableView, cellProvider: { [weak self] (tableView, indexPath, list) -> UITableViewCell? in
            guard let self = self else { return nil }
            self.listDiffableDatasource?.realmToken = self.realmListToken
            
            let section = ListSection(rawValue: indexPath.section)!
            
            switch section {
            case .type:
                let blankCell = tableView.dequeueReusableCell(withIdentifier: "BlankTVCell", for: indexPath)
                let height = blankCell.frame.height
                let width = blankCell.frame.width
                self.addChild(self.childVC)
                self.childVC.view.frame = CGRect(x: 0, y: 0, width: width, height: height)
                blankCell.contentView.addSubview(self.childVC.view)
                return blankCell
            case .list:
                let cell = tableView.dequeueReusableCell(withIdentifier: ReminderListTVCell.reuseIdentifier, for: indexPath) as! ReminderListTVCell
                cell.list = list
                cell.delegate = self
                return cell
            }
        })
        
        updateDatasource()
    }
    
    func updateDatasource() {
        var snapshot = NSDiffableDataSourceSnapshot<ListSection, ReminderList?>()
        snapshot.appendSections([.type])
        snapshot.appendSections([.list])
        
        snapshot.appendItems([ReminderList()], toSection: .type)
        
        tableView.hidePlaceholder()
        guard let allLists = ReminderList.getAllLists(isGroupsIncluded: true) else { return }
        
        for list in allLists {
            print("Name: \(list.groupName ?? list.name), isGroup: \(list.isGroup), isInGroup: \(list.isInGroup), in group: \(String(describing: list.ownerGroup.first?.groupName))")
        }
        
        let listsInGroups = ReminderList.listsInGroup
        
        for list in allLists {
            if !listsInGroups.contains(list.reminderListID) {
                snapshot.appendItems([list], toSection: .list)
            }
            
            if list.isGroup && list.isExpanded {
                list.reminderLists.sorted(byKeyPath: "sortIndex", ascending: true).forEach({ snapshot.appendItems([$0], toSection: .list) })
            }
        }
        
        listDiffableDatasource?.apply(snapshot, animatingDifferences: false, completion: nil)
        
        if allLists.isEmpty {
            tableView.showPlaceholder()
        }
    }
}


extension MainVC: UITableViewDelegate {
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        if indexPath.section > 0 {
            guard let list = self.listDiffableDatasource?.itemIdentifier(for: indexPath) else { return }
            
            if list!.isGroup  {
                list!.toggleExpand()
                setupDatasource()
            } else {
                let reminderListTVC = ReminderListTVC()
                reminderListTVC.vcType = .reminderList(list!)
                self.navigationController?.pushViewController(reminderListTVC, animated: true)
            }
        }
    }
    
    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        switch indexPath.section {
        case 0:
            return 200
        case 1:
            return 44
        default:
            return 0
        }
    }
    
    func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        switch section {
        case 0:
            return 5
        case 1:
            return ListSectionHeaderView.height
        default:
            return 0
        }
    }
    
    func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        let headerView = tableView.dequeueReusableHeaderFooterView(withIdentifier: ListSectionHeaderView.reuseIdentifier) as! ListSectionHeaderView
        let sectionTitle = listDiffableDatasource?.snapshot().sectionIdentifiers[section]
        headerView.sectionLbl.text = sectionTitle?.sectionTitle
        return headerView
    }
    
    func tableView(_ tableView: UITableView, shouldIndentWhileEditingRowAt indexPath: IndexPath) -> Bool {
        return true
    }
    
    override func setEditing(_ editing: Bool, animated: Bool) {
        super.setEditing(editing, animated: animated)
        // Toggles the actual editing actions appearing on a table view
        tableView.setEditing(editing, animated: true)
        footerView.addGroupBtn.isHidden = tableView.isEditing ? false : true
    }
    
    //MARK:  Trailing swipe actions
    func tableView(_ tableView: UITableView, trailingSwipeActionsConfigurationForRowAt indexPath: IndexPath) -> UISwipeActionsConfiguration? {
        
        let deleteAction = UIContextualAction(style: .destructive, title: nil) { [weak self] (_, _, _)  in
            guard let self = self else { return }
            if let listToDelete = self.listDiffableDatasource?.itemIdentifier(for: indexPath) {
                //MARK: Deleting from snapshot
                var snapshot = self.listDiffableDatasource?.snapshot()
                snapshot!.deleteItems([listToDelete])
                self.listDiffableDatasource?.apply(snapshot!)
                
                guard let realm = MyRealm.getConfig() else { return }
                try! realm.write(withoutNotifying: [self.realmListToken!]) {
                    listToDelete?.deleteList()
                }
                
                self.childVC.collectionView.reloadData()
                
                guard let allLists = ReminderList.getAllLists(isGroupsIncluded: true) else { return }
                
                if allLists.isEmpty {
                    tableView.showPlaceholder()
                }
            }
        }
        
        deleteAction.image = UIImage(systemName: "trash.fill")
        
        let editAction = UIContextualAction(style: .normal, title: nil) { [weak self] (_, _, _)  in
            guard let self = self else { return }
            if let listToEdit = self.listDiffableDatasource?.itemIdentifier(for: indexPath)! {
                
                //Edit List or Group
                if listToEdit.isGroup {
                    let createGroupTVC = CreateGroupTVC()
                    createGroupTVC.groupToEdit = listToEdit
                    self.present(UINavigationController(rootViewController: createGroupTVC), animated: true, completion: nil)
                } else {
                    let createListVC = CreateListVC()
                    createListVC.passedListToEdit = listToEdit
                    self.present(createListVC, animated: true, completion: nil)
                }
            }
        }
        
        editAction.backgroundColor = .systemGray
        editAction.image = UIImage(systemName: "info.circle.fill")
        
        return UISwipeActionsConfiguration(actions: [deleteAction, editAction])
    }
    
}

extension MainVC: ReminderListCellDelegate {
    func pass(list: ReminderList) {
        if list.isGroup {
            let createGroupTVC = CreateGroupTVC()
            createGroupTVC.groupToEdit = list
            self.present(UINavigationController(rootViewController: createGroupTVC), animated: true, completion: nil)
        } else {
            let createListVC = CreateListVC()
            createListVC.passedListToEdit = list
            self.present(createListVC, animated: true, completion: nil)
        }
        
    }
    
}




//MARK: Search implementation
//extension MainVC: UISearchBarDelegate {}
extension MainVC: UISearchResultsUpdating {
    func updateSearchResults(for searchController: UISearchController) {
        searchControllerVC?.vcType = .search(searchController.searchBar.text!)
        searchControllerVC?.reminderDatasource.reminderFilter = .search(searchController.searchBar.text!)
        searchControllerVC?.tableView.contentInset = UIEdgeInsets(top: -36, left: 0, bottom: 0, right: 0)  //tableView requires adjust when searching
        searchControllerVC?.reminderDatasource.load()
    }
}








//MARK: SwitfUI's live preview
fileprivate typealias ThisViewController = MainVC //update to this file's VC
fileprivate struct IntegratedController: UIViewControllerRepresentable {
    func makeUIViewController(context: UIViewControllerRepresentableContext<IntegratedController>) -> ThisViewController {
        return ThisViewController()
    }
    
    func updateUIViewController(_ uiViewController: ThisViewController, context: UIViewControllerRepresentableContext<IntegratedController>) {
    }
}

fileprivate struct CustomContentView: View {
    var body: some View {
        IntegratedController().edgesIgnoringSafeArea(.bottom)
        
        //IF Navigation title is needed for the preview, used the following:
        //        NavigationView {
        //            IntegratedController().edgesIgnoringSafeArea(.all)
        //                .navigationBarTitle(Text("Navigation Title Text"), displayMode: .inline)  //inline sets a small navigation bar height
        //        }
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        CustomContentView()  //if preview isn't changing, change this struct to the struct conforming to View
    }
}
