//
//  LogsVC.swift
//  CrowdinSDK
//
//  Created by Serhii Londar on 11.08.2020.
//

import UIKit

protocol CrowdinLogCellPresentation {
    
    var log: CrowdinLog { get }
    var date: String { get }
    var type: String { get }
    var message: String { get }
    var textColor: UIColor { get }
    var isShowArrow: Bool { get }
    var attributedText: NSAttributedString? { get }
}

final class CrowdinLogCellViewModel: CrowdinLogCellPresentation {
    
    private static var dateFormatter: DateFormatter = {
       let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "hh:mm:ss dd/MM/yyyy"
        return dateFormatter
    }()
    
    let log: CrowdinLog
    
    init(log: CrowdinLog) {
        self.log = log
    }
    
    var date: String {
        CrowdinLogCellViewModel.dateFormatter.string(from: log.date)
    }
    
    var type: String {
        log.type.rawValue
    }
    
    var message: String {
        log.message
    }
    
    var textColor: UIColor {
        log.type.color
    }
    
    var isShowArrow: Bool {
        attributedText != nil
    }
    
    var attributedText: NSAttributedString? {
        log.attributedDetails
    }
}

final class CrowdinLogCell: UITableViewCell {
    
    @IBOutlet private weak var dateLabel: UILabel!
    @IBOutlet private weak var typeLabel: UILabel!
    @IBOutlet private weak var messageLabel: UILabel!
    
    func setup(with viewModel: CrowdinLogCellPresentation) {
        self.dateLabel.text = viewModel.date
        self.typeLabel.text = viewModel.type
        self.typeLabel.textColor = viewModel.textColor
        self.messageLabel.text = viewModel.message
        
        selectionStyle = .none
        
        guard viewModel.isShowArrow else {
            return
        }
        
        accessoryType = .disclosureIndicator
    }
}

final class CrowdinLogsVC: UITableViewController {
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        NotificationCenter.default.addObserver(self, selector: #selector(reloadData), name: NSNotification.Name.refreshLogsName, object: nil)
    }
    
    // swiftlint:disable implicitly_unwrapped_optional
    override var tableView: UITableView! {
        didSet {
            self.refreshControl = UIRefreshControl()
            self.refreshControl?.addTarget(self, action: #selector(reloadData), for: .valueChanged)
            if #available(iOS 10.0, *) {
                tableView.refreshControl = refreshControl
            } else {
                // swiftlint:disable force_unwrapping
                tableView.addSubview(refreshControl!)
            }
        }
    }
    
    @objc func reloadData() {
        tableView.reloadData()
        refreshControl?.endRefreshing()
    }
    
    // MARK: - Private
    
    private func didSelect(_ indexPath: IndexPath) {
        let cellViewModel = CrowdinLogCellViewModel(log: CrowdinLogsCollector.shared.logs[indexPath.row])
        
        guard cellViewModel.isShowArrow else {
            return
        }
        
        openLogsDetails(cellViewModel: cellViewModel)
    }
    
    private func openLogsDetails(cellViewModel: CrowdinLogCellViewModel) {
        let logsDetailsVCStoryboard = UIStoryboard(name: "CrowdinLogsVC", bundle: Bundle.module)
        if let logDetailsVC: CrowdinLogDetailsVC = logsDetailsVCStoryboard.instantiateViewController(withIdentifier: "CrowdinLogDetailsVC") as? CrowdinLogDetailsVC {
            logDetailsVC.setup(with: cellViewModel.attributedText)
            navigationController?.pushViewController(logDetailsVC, animated: true)
        }
    }
    
    // MARK: - UITableViewDelegate
    
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        CrowdinLogsCollector.shared.logs.count
    }
    
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        guard let cell = tableView.dequeueReusableCell(withIdentifier: "CrowdinLogCell", for: indexPath) as? CrowdinLogCell else { return UITableViewCell() }
        let cellViewModel = CrowdinLogCellViewModel(log: CrowdinLogsCollector.shared.logs[indexPath.row])
        cell.setup(with: cellViewModel)
        return cell
    }
    
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        didSelect(indexPath)
    }
}
