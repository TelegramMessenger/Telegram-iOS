import Foundation
import Display
import AsyncDisplayKit
import UIKit
import SwiftSignalKit
import Photos

final class ChatSecretAutoremoveTimerActionSheetController: ActionSheetController {
    private let _ready = Promise<Bool>()
    override var ready: Promise<Bool> {
        return self._ready
    }
    
    init(currentValue: Int32, applyValue: @escaping (Int32) -> Void) {
        super.init()
        
        self._ready.set(.single(true))
        
        var updatedValue = currentValue
        self.setItemGroups([
            ActionSheetItemGroup(items: [
                AutoremoveTimeoutSelectorItem(currentValue: currentValue, valueChanged: { value in
                    updatedValue = value
                }),
                ActionSheetButtonItem(title: "Set", action: { [weak self] in
                    if let strongSelf = self {
                        self?.dismissAnimated()
                    }
                    applyValue(updatedValue)
                })
            ]),
            ActionSheetItemGroup(items: [
                ActionSheetButtonItem(title: "Cancel", action: { [weak self] in
                    self?.dismissAnimated()
                }),
            ])
        ])
    }
    
    required init(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

private final class AutoremoveTimeoutSelectorItem: ActionSheetItem {
    let currentValue: Int32
    let valueChanged: (Int32) -> Void
    
    init(currentValue: Int32, valueChanged: @escaping (Int32) -> Void) {
        self.currentValue = currentValue
        self.valueChanged = valueChanged
    }
    
    func node() -> ActionSheetItemNode {
        return AutoremoveTimeoutSelectorItemNode(currentValue: self.currentValue, valueChanged: self.valueChanged)
    }
    
    func updateNode(_ node: ActionSheetItemNode) {
    }
}

private let timeoutValues: [(Int32, String)] = [
    (0, "Off"),
    (1, "1 second"),
    (2, "2 seconds"),
    (3, "3 seconds"),
    (4, "4 seconds"),
    (5, "5 seconds"),
    (6, "6 seconds"),
    (7, "7 seconds"),
    (8, "8 seconds"),
    (9, "9 seconds"),
    (10, "10 seconds"),
    (11, "11 seconds"),
    (12, "12 seconds"),
    (13, "13 seconds"),
    (14, "14 seconds"),
    (15, "15 seconds"),
    (30, "30 seconds"),
    (1 * 60, "1 minute"),
    (1 * 60 * 60, "1 hour"),
    (24 * 60 * 60, "1 day"),
    (7 * 24 * 60 * 60, "1 week"),
]

private final class AutoremoveTimeoutSelectorItemNode: ActionSheetItemNode, UIPickerViewDelegate, UIPickerViewDataSource {
    private let valueChanged: (Int32) -> Void
    private let pickerView: UIPickerView
    
    init(currentValue: Int32, valueChanged: @escaping (Int32) -> Void) {
        self.valueChanged = valueChanged
        
        self.pickerView = UIPickerView()
        
        super.init()
        
        self.pickerView.delegate = self
        self.pickerView.dataSource = self
        self.view.addSubview(self.pickerView)
        
        self.pickerView.reloadAllComponents()
        var index: Int = 0
        for i in 0 ..< timeoutValues.count {
            if currentValue <= timeoutValues[i].0 {
                index = i
                break
            }
        }
        self.pickerView.selectRow(index, inComponent: 0, animated: false)
    }
    
    override func calculateSizeThatFits(_ constrainedSize: CGSize) -> CGSize {
        return CGSize(width: constrainedSize.width, height: 157.0)
    }
    
    func numberOfComponents(in pickerView: UIPickerView) -> Int {
        return 1
    }
    
    func pickerView(_ pickerView: UIPickerView, numberOfRowsInComponent component: Int) -> Int {
        return timeoutValues.count
    }
    
    func pickerView(_ pickerView: UIPickerView, attributedTitleForRow row: Int, forComponent component: Int) -> NSAttributedString? {
        return NSAttributedString(string: timeoutValues[row].1, font: Font.medium(15.0), textColor: UIColor.black)
    }
    
    func pickerView(_ pickerView: UIPickerView, didSelectRow row: Int, inComponent component: Int) {
        self.valueChanged(timeoutValues[row].0)
    }
    
    override func layout() {
        super.layout()
        
        self.pickerView.frame = CGRect(origin: CGPoint(), size: CGSize(width: self.bounds.size.width, height: 180.0))
    }
}
