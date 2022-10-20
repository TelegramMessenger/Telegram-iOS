//
//  SettingsView.swift
//  CrowdinSDK
//
//  Created by Serhii Londar on 4/4/19.
//

import UIKit

final class SettingsView: UIView {
    static let shared: SettingsView? = SettingsView.loadFromNib()
    
    var settingsWindow = SettingsWindow() {
        didSet {
            settingsWindow.settingsView = self
        }
    }
    
    var cells = [SettingsItemCell]()
    
    @IBOutlet weak var blurView: UIVisualEffectView!
    
    @IBOutlet weak var settingsButton: UIButton! {
        didSet {
            settingsButton.setImage(UIImage(named: "settings-button", in: Bundle.module, compatibleWith: nil), for: .normal)
        }
    }
    
    @IBOutlet weak var tableView: UITableView! {
        didSet {
            tableView.delegate = self
            tableView.dataSource = self
            registerCells()
            reloadData()
        }
    }
    
    @IBOutlet weak var closeButton: UIButton!
    
    fileprivate let closedWidth: CGFloat = 60.0
    fileprivate let openedWidth: CGFloat = 200.0
    fileprivate let defaultItemHeight: CGFloat = 60.0
    let enabledStatusColor = UIColor(red: 60.0 / 255.0, green: 130.0 / 255.0, blue: 130.0 / 255.0, alpha: 1.0)
    
    var realtimeUpdateFeatureEnabled: Bool = false
    
    var open: Bool = false {
        didSet {
            reloadData()
            self.blurView.isHidden = open
            self.backgroundColor = open ? UIColor(red: 45.0 / 255.0, green: 49.0 / 255.0, blue: 49.0 / 255.0, alpha: 1.0) : .clear
            reloadUI()
            closeButtonHidden(isHidden: open == false)
        }
    }
    
    func reloadData() {
        setupCells()
        tableView.reloadData()
    }
    
    var logsVC: UIViewController? = nil
    
    func dismissLogsVC() {
        logsVC?.cw_dismiss()
        logsVC = nil
    }
    
    func reloadUI() {
        if open == true {
            self.frame.size.height = CGFloat(defaultItemHeight + CGFloat(cells.count) * defaultItemHeight)
            self.frame.size.width = openedWidth
        } else {
            self.frame.size.height = defaultItemHeight
            self.frame.size.width = closedWidth
        }
    }
    
    class func loadFromNib() -> SettingsView? {
        return UINib(nibName: "SettingsView", bundle: Bundle.module).instantiate(withOwner: self, options: nil).first as? SettingsView
    }
    
    override func awakeFromNib() {
        super.awakeFromNib()
        let gesture = UIPanGestureRecognizer(target: self, action: #selector(wasDragged(gestureRecognizer:)))
        self.addGestureRecognizer(gesture)
        self.isUserInteractionEnabled = true
        gesture.delegate = self
    }
    
    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        let gesture = UIPanGestureRecognizer(target: self, action: #selector(wasDragged(gestureRecognizer:)))
        self.addGestureRecognizer(gesture)
        self.isUserInteractionEnabled = true
        gesture.delegate = self
    }
    
    // MARK: - IBActions
    
    @IBAction func settingsButtonPressed() {
        self.open = !self.open
        self.fixPositionIfNeeded()
    }
    
    @IBAction func closeButtonPressed() {
        open = false
    }
    
    // MARK: - Private
    
    func closeButtonHidden(isHidden: Bool) {
        closeButton.isHidden = isHidden
    }
    
    func fixPositionIfNeeded() {
        let x = validateXCoordinate(value: self.center.x)
        let y = validateYCoordinate(value: self.center.y)
        
        UIView.animate(withDuration: 0.3) {
            self.center = CGPoint(x: x, y: y)
        }
    }
    
    func validateXCoordinate(value: CGFloat) -> CGFloat {
        guard let window = window else { return 0 }
        let minX = self.frame.size.width / 2.0
        let maxX = window.frame.size.width - self.frame.size.width / 2.0
        var x = value
        x = x < minX ? minX : x
        x = x > maxX ? maxX : x
        return x
    }
    
    func validateYCoordinate(value: CGFloat) -> CGFloat {
        guard let window = window else { return 0 }
        let minY = self.frame.size.height / 2.0
        let maxY = window.frame.size.height - self.frame.size.height / 2.0
        var y = value
        y = y < minY ? minY : y
        y = y > maxY ? maxY : y
        return y
    }
    
    func showConfirmationLogoutAlert() {
        let alert = UIAlertController(title: "CrowdinSDK", message: "Are you sure you want to log out?", preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default, handler: { [weak self]_ in
            alert.cw_dismiss()
            self?.logout()
            self?.reloadUI()
        }))
        alert.addAction(UIAlertAction(title: "Cancel", style: .destructive, handler: { _ in
            alert.cw_dismiss()
        }))
        alert.cw_present()
    }
    
    func logout() {
        if let realtimeUpdateFeature = RealtimeUpdateFeature.shared, realtimeUpdateFeature.enabled {
            realtimeUpdateFeature.stop()
        }
        LoginFeature.shared.flatMap {
            $0.logout()
        }
        reloadData()
        let message = "Successfully logout"
        CrowdinLogsCollector.shared.add(log: .info(with: message))
        showToast(message)
    }
    
    func showToast(_ message: String) {
        DispatchQueue.main.async { [weak self] in
            self?.makeToast(message)
        }
        
        // Notify all subscribers about new log record is created
        LogMessageObserver.shared.notifyAll(message)
    }
}
