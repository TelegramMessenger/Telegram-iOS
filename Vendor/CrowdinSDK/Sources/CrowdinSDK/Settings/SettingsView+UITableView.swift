//
//  SettingsView+UITableView.swift
//  BaseAPI
//
//  Created by Serhii Londar on 4/6/19.
//

import UIKit

extension SettingsView {
    func registerCells() {
        let nib = UINib(nibName: "SettingsItemCell", bundle: Bundle.module)
        tableView.register(nib, forCellReuseIdentifier: "SettingsItemCell")
    }
    
    func setupCells() {
        cells = []
        
        if let loginFeature = LoginFeature.shared {
            if let loginCell = tableView.dequeueReusableCell(withIdentifier: "SettingsItemCell") as? SettingsItemCell {
                if !LoginFeature.isLogined {
                    loginCell.titleLabel.text = "Log in"
                    loginCell.action = { [weak self] in
                        loginFeature.login(completion: {
                            DispatchQueue.main.async {
                                self?.reloadData()
                                self?.reloadUI()
                            }
                            let message = "Successfully logined"
                            CrowdinLogsCollector.shared.add(log: CrowdinLog(type: .info, message: message))
                            self?.showToast(message)
                        }, error: { [weak self] error in
                            let message = "Login error - \(error.localizedDescription)"
                            CrowdinLogsCollector.shared.add(log: CrowdinLog(type: .error, message: message))
                            self?.showToast(message)
                        })
                        self?.isHidden = false
                        self?.reloadData()
                    }
                } else {
                    loginCell.titleLabel.text = "Logged in"
                    loginCell.action = { [weak self] in
                        self?.showConfirmationLogoutAlert()
                    }
                }
                loginCell.statusView.backgroundColor = LoginFeature.isLogined ? self.enabledStatusColor : .clear
                loginCell.selectionStyle = .none
                cells.append(loginCell)
            }
        }
        
        if let reloadCell = tableView.dequeueReusableCell(withIdentifier: "SettingsItemCell") as? SettingsItemCell {
            reloadCell.action = { [weak self] in
                RefreshLocalizationFeature.refreshLocalization()
                let message = RealtimeUpdateFeature.shared?.enabled == true ? "Localization fetched from Crowdin project" : "Localization fetched from distribution"
                self?.showToast(message)
            }
            reloadCell.titleLabel.text = "Reload translations"
            reloadCell.selectionStyle = .none
            cells.append(reloadCell)
        }
        /*
        if var feature = IntervalUpdateFeature.shared {
            if let autoreloadCell = tableView.dequeueReusableCell(withIdentifier: "SettingsItemCell") as? SettingsItemCell {
                autoreloadCell.action = {
                    feature.enabled = !feature.enabled
                    autoreloadCell.icon.image = UIImage(named: feature.enabled ? "auto-updates-on" : "auto-updates-off", in: Bundle.resourceBundle, compatibleWith: nil)
                    self.tableView.reloadData()
                    self.open = false
                }
                autoreloadCell.icon.image = UIImage(named: feature.enabled ? "auto-updates-on" : "auto-updates-off", in: Bundle.resourceBundle, compatibleWith: nil)
                autoreloadCell.selectionStyle = .none
                autoreloadCell.contentView.layer.cornerRadius = 30.0
                autoreloadCell.contentView.clipsToBounds = true
                cells.append(autoreloadCell)
            }
        }
        */
        if LoginFeature.isLogined {
            if var feature = RealtimeUpdateFeature.shared {
                if let realtimeUpdateCell = tableView.dequeueReusableCell(withIdentifier: "SettingsItemCell") as? SettingsItemCell {
                    feature.error = { [weak self] error in
                        let message = "Error while starting real-time preview - \(error.localizedDescription)"
                        CrowdinLogsCollector.shared.add(log: CrowdinLog(type: .error, message: message))
                        self?.showToast(message)
                    }
                    
                    feature.success = { [weak self] in
                        let message = "Successfully started real-time preview"
                        CrowdinLogsCollector.shared.add(log: CrowdinLog(type: .info, message: message))
                        self?.reloadData()
                        guard self?.realtimeUpdateFeatureEnabled == false else {
                            self?.realtimeUpdateFeatureEnabled = RealtimeUpdateFeature.shared?.enabled == true
                            return
                        }
                        
                        self?.realtimeUpdateFeatureEnabled = RealtimeUpdateFeature.shared?.enabled == true
                        self?.showToast(message)
                    }
                    feature.disconnect = { [weak self] in
                        let message = "Real-time preview disabled"
                        CrowdinLogsCollector.shared.add(log: CrowdinLog(type: .info, message: message))
                        self?.reloadData()
                        self?.showToast(message)
                    }
                    
                    realtimeUpdateCell.action = {
                        feature.enabled = !feature.enabled
                        realtimeUpdateCell.titleLabel.text = feature.enabled ? "Real-time on" : "Real-time off"
                    }
                    realtimeUpdateCell.titleLabel.text = feature.enabled ? "Real-time on" : "Real-time off"
                    realtimeUpdateCell.statusView.backgroundColor = feature.enabled ? self.enabledStatusColor : .clear
                    realtimeUpdateCell.selectionStyle = .none
                    cells.append(realtimeUpdateCell)
                }
            }
            
            if let feature = ScreenshotFeature.shared {
                if let screenshotCell = tableView.dequeueReusableCell(withIdentifier: "SettingsItemCell") as? SettingsItemCell {
                    screenshotCell.action = { [weak self] in
                        let message = "Successfully captured screenshot"
                        feature.captureScreenshot(name: String(Date().timeIntervalSince1970), success: {
                            CrowdinLogsCollector.shared.add(log: CrowdinLog(type: .info, message: message))
                            self?.showToast(message)
                        }, errorHandler: { (error) in
                            let message = "Error while capturing screenshot - \(error?.localizedDescription ?? "Unknown")"
                            CrowdinLogsCollector.shared.add(log: CrowdinLog(type: .error, message: message))
                            self?.showToast(message)
                        })
                    }
                    screenshotCell.titleLabel.text = "Capture screenshot"
                    screenshotCell.selectionStyle = .none
                    cells.append(screenshotCell)
                }
            }
        }
        
        if let logsCell = tableView.dequeueReusableCell(withIdentifier: "SettingsItemCell") as? SettingsItemCell {
            logsCell.action = {
                let logsVCStoryboard = UIStoryboard(name: "CrowdinLogsVC", bundle: Bundle.module)
                let logsVC = logsVCStoryboard.instantiateViewController(withIdentifier: "CrowdinLogsVC")
                let logsNC = UINavigationController(rootViewController: logsVC)
                logsVC.title = "Logs"
                logsVC.navigationItem.leftBarButtonItem = UIBarButtonItem(title: "Done", style: .done, target: logsNC, action: #selector(UIViewController.cw_dismiss))
                logsVC.navigationItem.rightBarButtonItem = UIBarButtonItem(title: "Clear logs", style: .done, target: logsNC, action: #selector(UIViewController.cw_askToClearLogsAlert))
                logsNC.modalPresentationStyle = .fullScreen
                logsNC.cw_present()
            }
            logsCell.titleLabel.text = "Logs"
            logsCell.selectionStyle = .none
            cells.append(logsCell)
        }
    }
}

extension SettingsView: UITableViewDelegate {
    
}

extension SettingsView: UITableViewDataSource {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return cells.count
    }
    
    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return 60;
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        return cells[indexPath.row]
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        cells[indexPath.row].action?()
    }
}
