import Foundation
import UIKit
import Display
import AsyncDisplayKit
import AudioToolbox

@objc public protocol PickerViewDelegate: AnyObject {
    func pickerViewHeightForRows(_ pickerView: TapeNode) -> CGFloat
    @objc optional func pickerView(_ pickerView: TapeNode, didSelectRow row: Int)
    @objc optional func pickerView(_ pickerView: TapeNode, didTapRow row: Int)
    @objc optional func pickerView(_ pickerView: TapeNode, styleForLabel label: UILabel, highlighted: Bool)
    @objc optional func pickerView(_ pickerView: TapeNode, viewForRow row: Int, highlighted: Bool, reusingView view: UIView?) -> UIView?
}

open class TapeNode: ASDisplayNode {
    fileprivate class Cell: UITableViewCell {
        lazy var titleLabel: UILabel = {
            let titleLabel = UILabel(frame: CGRect(x: 0.0, y: 0.0, width: self.contentView.frame.width, height: self.contentView.frame.height))
            titleLabel.textAlignment = .center
            
            return titleLabel
        }()
        
        var customView: UIView?
    }
            
    var textColor: UIColor = .black {
        didSet {
            for cell in self.tableView.visibleCells {
                if let cell = cell as? Cell {
                    cell.titleLabel.textColor = self.textColor
                }
            }
        }
    }
    
    
    private let hapticFeedback = HapticFeedback()
    private var previousRoundedRow: Int?
    
    var count: (() -> Int)?
    var titleAt: ((Int) -> String)?
    var selected: ((Int) -> Void)?
    var isScrollingUpdated: ((Bool) -> Void)?
    
    var numberOfRows: Int {
        get {
            return self.count?() ?? 0
        }
    }

    private var indexesCount: Int {
        return self.numberOfRows > 0 ? self.numberOfRows - 1 : self.numberOfRows
    }
    
    private var rowHeight: CGFloat {
        return 21.0
    }

    private let cellIdentifier = "tapeCell"
    
    public lazy var tableView: UITableView = {
        return UITableView()
    }()
    
    private var infinityRowsMultiplier: Int {
        return generateInfinityRowsMultiplier()
    }
    
    var currentSelectedRow: Int?
    var currentSelectedIndex: Int {
        get {
            if let currentSelectedRow = self.currentSelectedRow {
                return self.indexForRow(currentSelectedRow)
            } else {
                return 0
            }
        }
    }
    
    private var isScrolling = false
    private var initialized = false
    private var shouldSelectNearbyToMiddleRow = false
    
    open override func didLoad() {
        super.didLoad()
        self.setup()
    }
    
    fileprivate func setup() {
        if #available(iOS 11.0, *) {
            self.tableView.contentInsetAdjustmentBehavior = .never
        }
        self.tableView.estimatedRowHeight = 0
        self.tableView.estimatedSectionFooterHeight = 0
        self.tableView.estimatedSectionHeaderHeight = 0
        self.tableView.backgroundColor = .clear
        self.tableView.separatorStyle = .none
        self.tableView.separatorColor = .none
        self.tableView.allowsSelection = true
        self.tableView.allowsMultipleSelection = false
        self.tableView.showsVerticalScrollIndicator = false
        self.tableView.showsHorizontalScrollIndicator = false
        self.tableView.scrollsToTop = false
        self.tableView.register(Cell.classForCoder(), forCellReuseIdentifier: self.cellIdentifier)
        self.view.addSubview(tableView)
        
        self.tableView.delegate = self
        self.tableView.dataSource = self
        self.tableView.reloadData()
    }

    fileprivate func generateInfinityRowsMultiplier() -> Int {
        if self.numberOfRows > 100 {
            return 100
        } else if self.numberOfRows < 100 && self.numberOfRows > 50 {
            return 200
        } else if self.numberOfRows < 50 && self.numberOfRows > 25 {
            return 400
        } else {
            return 800
        }
    }
    
    open override func layout() {
        super.layout()
        
        self.tableView.frame = self.bounds
        if !self.initialized {
            self.setup()
            self.initialized = true
        }
    }

    fileprivate func indexForRow(_ row: Int) -> Int {
        return row % (self.numberOfRows > 0 ? self.numberOfRows : 1)
    }
        
    fileprivate func selectTappedRow(_ row: Int) {
        self.selectRow(row, animated: true)
        if let currentSelectedRow = self.currentSelectedRow {
            self.selected?(currentSelectedRow)
        }
    }
    
    fileprivate func visibleIndexOfSelectedRow() -> Int {
        let middleMultiplier = (self.infinityRowsMultiplier / 2)
        let middleIndex = self.numberOfRows * middleMultiplier
        let indexForSelectedRow: Int
    
        if let currentSelectedRow = self.currentSelectedRow {
            indexForSelectedRow = middleIndex - (self.numberOfRows - currentSelectedRow)
        } else {
            let middleRow = Int(floor(Float(self.indexesCount) / 2.0))
            indexForSelectedRow = middleIndex - (self.numberOfRows - middleRow)
        }
        
        return indexForSelectedRow
    }
    
    open func selectRow(_ row : Int, animated: Bool) {
        if self.currentSelectedIndex == self.indexForRow(row) {
            return
        }
        
        var finalRow = row
        if row <= self.numberOfRows {
            let middleMultiplier = self.infinityRowsMultiplier / 2
            let middleIndex = self.numberOfRows * middleMultiplier
            finalRow = middleIndex - (self.numberOfRows - finalRow)
        }
        self.currentSelectedRow = finalRow
        
        if let currentSelectedRow = self.currentSelectedRow {
            self.tableView.setContentOffset(CGPoint(x: 0.0, y: CGFloat(currentSelectedRow) * self.rowHeight), animated: animated)
        }
    }
    
    func selectMiddleRow() {
        var finalRow = self.currentSelectedIndex
        let middleMultiplier = self.infinityRowsMultiplier / 2
        let middleIndex = self.numberOfRows * middleMultiplier
        finalRow = middleIndex - (self.numberOfRows - finalRow)
        
        self.currentSelectedRow = finalRow
        
        if let currentSelectedRow = self.currentSelectedRow {
            self.tableView.setContentOffset(CGPoint(x: 0.0, y: CGFloat(currentSelectedRow) * self.rowHeight), animated: false)
        }
    }
    
    open func reloadPickerView() {
        self.tableView.reloadData()
    }
    
    private func hapticTap() {
        self.hapticFeedback.impact(.light)
        AudioServicesPlaySystemSound(1157)
    }
}

extension TapeNode: UITableViewDataSource {
    public func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return self.numberOfRows * self.infinityRowsMultiplier
    }
    
    public func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let pickerViewCell = tableView.dequeueReusableCell(withIdentifier: cellIdentifier, for: indexPath) as! Cell
        
        pickerViewCell.selectionStyle = .none
        
        let centerY = (indexPath as NSIndexPath).row == 0 ? (self.frame.height / 2) - (self.rowHeight / 2) : 0.0
                
        pickerViewCell.backgroundColor = .clear
        pickerViewCell.contentView.backgroundColor = .clear
        pickerViewCell.contentView.addSubview(pickerViewCell.titleLabel)
        pickerViewCell.titleLabel.backgroundColor = .clear
        pickerViewCell.titleLabel.font = Font.with(size: 21.0, design: .regular, weight: .regular, traits: [.monospacedNumbers])
        pickerViewCell.titleLabel.text = self.titleAt?(indexForRow((indexPath as NSIndexPath).row))
        pickerViewCell.titleLabel.textColor = self.textColor
        pickerViewCell.titleLabel.frame = CGRect(x: 0.0, y: centerY, width: frame.width, height: self.rowHeight)
        
        return pickerViewCell
    }
}

extension TapeNode: UITableViewDelegate {
    public func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        self.selectTappedRow((indexPath as NSIndexPath).row)
    }
    
    public func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        let numberOfRows = (self.count?() ?? 0) * self.infinityRowsMultiplier
        if (indexPath as NSIndexPath).row == 0 {
            return (self.frame.height / 2) + (self.rowHeight / 2)
        } else if numberOfRows > 0 && (indexPath as NSIndexPath).row == numberOfRows - 1 {
            return (self.frame.height / 2) + (self.rowHeight / 2)
        }
        return self.rowHeight
    }
}

extension TapeNode: UIScrollViewDelegate {
    public func scrollViewWillBeginDragging(_ scrollView: UIScrollView) {
        self.isScrolling = true
        self.isScrollingUpdated?(true)
    }
    
    public func scrollViewWillEndDragging(_ scrollView: UIScrollView, withVelocity velocity: CGPoint, targetContentOffset: UnsafeMutablePointer<CGPoint>) {
        let partialRow = Float(targetContentOffset.pointee.y / self.rowHeight)
        var roundedRow = Int(lroundf(partialRow))
        
        if roundedRow < 0 {
            roundedRow = 0
        } else {
            targetContentOffset.pointee.y = CGFloat(roundedRow) * self.rowHeight
        }
        
        self.currentSelectedRow = self.indexForRow(roundedRow)
        if let currentSelectedRow = self.currentSelectedRow {
            self.selected?(currentSelectedRow)
        }
    }
    
    public func scrollViewDidEndDragging(_ scrollView: UIScrollView, willDecelerate decelerate: Bool) {
        if !decelerate {
            self.isScrolling = false
            self.isScrollingUpdated?(false)
            
            self.selectMiddleRow()
        }
    }
    
    public func scrollViewDidEndDecelerating(_ scrollView: UIScrollView) {
        self.isScrolling = false
        self.isScrollingUpdated?(false)
        
        self.selectMiddleRow()
    }
    
    public func scrollViewDidScroll(_ scrollView: UIScrollView) {
        let partialRow = Float(scrollView.contentOffset.y / self.rowHeight)
        let roundedRow = Int(lroundf(partialRow))
        
        if self.previousRoundedRow != roundedRow && self.isScrolling {
            self.previousRoundedRow = roundedRow
            
            self.hapticTap()
        }
    }
}
