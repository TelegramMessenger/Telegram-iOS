//
//  SettingsItemCell.swift
//  CrowdinSDK
//
//  Created by Serhii Londar on 4/13/19.
//

import UIKit

typealias SettingsItemCellAction = () -> Void

class SettingsItemCell: UITableViewCell {
    @IBOutlet weak var titleLabel: UILabel!
    @IBOutlet weak var statusView: UIView!
    var action: SettingsItemCellAction?
}
