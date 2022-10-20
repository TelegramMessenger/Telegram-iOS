//
//  SettingsVC.swift
//  AppleReminders
//
//  Created by Serhii Londar on 25.12.2020.
//  Copyright © 2020 Josh R. All rights reserved.
//

import UIKit
import CrowdinSDK

class SettingsVC: UITableViewController {
    var localizations = CrowdinSDK.allAvailableLocalizations
    
    enum Strings: String {
        case settings
        case language
        case auto
        case done
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        localizations.insert(Strings.auto.rawValue.capitalized.localized, at: 0)
        
        self.title = Strings.settings.rawValue.capitalized.localized
        self.navigationItem.rightBarButtonItem = UIBarButtonItem(title: Strings.done.rawValue.capitalized.localized, style: .done, target: self, action: #selector(cancelBtnTapped))
        self.tableView.register(UITableViewCell.self, forCellReuseIdentifier: "SettingsCell")
        self.tableView.reloadData()
    }
    
    @objc func cancelBtnTapped() {
        dismiss(animated: true, completion: nil)
    }
    
    override func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        Strings.language.rawValue.capitalized.localized
    }
    
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        localizations.count
    }
    
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "SettingsCell")!
        cell.textLabel?.text = localizations[indexPath.row]
        let localization = CrowdinSDK.currentLocalization
        cell.accessoryType = .none
        if localization == nil && indexPath.row == 0 {
            cell.accessoryType = .checkmark
        } else if localization == localizations[indexPath.row] {
            cell.accessoryType = .checkmark
        }
        return cell
    }
    
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let localization = localizations[indexPath.row]
        if localization == Strings.auto.rawValue.capitalized.localized {
            CrowdinSDK.currentLocalization = nil
        } else {
            CrowdinSDK.currentLocalization = localization
        }
        self.tableView.reloadData()
    }
}
