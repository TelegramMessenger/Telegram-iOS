import Foundation
import UIKit
import Display
import AsyncDisplayKit
import UIKit
import TelegramCore
import SwiftSignalKit
import Photos
import TelegramPresentationData
import AccountContext

final class ChatSecretAutoremoveTimerActionSheetController: ActionSheetController {
    private var presentationDisposable: Disposable?
    
    private let _ready = Promise<Bool>()
    override var ready: Promise<Bool> {
        return self._ready
    }
    
    init(context: AccountContext, currentValue: Int32, availableValues: [Int32]? = nil, applyValue: @escaping (Int32) -> Void) {
        let presentationData = context.sharedContext.currentPresentationData.with { $0 }
        let strings = presentationData.strings
        
        super.init(theme: ActionSheetControllerTheme(presentationData: presentationData))
        
        self.presentationDisposable = context.sharedContext.presentationData.start(next: { [weak self] presentationData in
            if let strongSelf = self {
                strongSelf.theme = ActionSheetControllerTheme(presentationData: presentationData)
            }
        })
        
        self._ready.set(.single(true))
        
        var updatedValue: Int32
        if currentValue > 0 {
            updatedValue = currentValue
        } else {
            if let availableValues = availableValues {
                updatedValue = availableValues[0]
            } else {
                updatedValue = 7
            }
        }
        self.setItemGroups([
            ActionSheetItemGroup(items: [
                AutoremoveTimeoutSelectorItem(strings: strings, currentValue: updatedValue, availableValues: availableValues, valueChanged: { value in
                    updatedValue = value
                }),
                ActionSheetButtonItem(title: strings.Common_Done, font: .bold, action: { [weak self] in
                    self?.dismissAnimated()
                    applyValue(updatedValue)
                })
            ]),
        ])
    }
    
    required init(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    deinit {
        self.presentationDisposable?.dispose()
    }
}

private final class AutoremoveTimeoutSelectorItem: ActionSheetItem {
    let strings: PresentationStrings
    
    let currentValue: Int32
    let availableValues: [Int32]?
    let valueChanged: (Int32) -> Void
    
    init(strings: PresentationStrings, currentValue: Int32, availableValues: [Int32]?, valueChanged: @escaping (Int32) -> Void) {
        self.strings = strings
        self.currentValue = currentValue
        self.availableValues = availableValues
        self.valueChanged = valueChanged
    }
    
    func node(theme: ActionSheetControllerTheme) -> ActionSheetItemNode {
        return AutoremoveTimeoutSelectorItemNode(theme: theme, strings: self.strings, currentValue: self.currentValue, availableValues: self.availableValues, valueChanged: self.valueChanged)
    }
    
    func updateNode(_ node: ActionSheetItemNode) {
    }
}

private let defaultTimeoutValues: [Int32] = [
    0,
    1,
    2,
    3,
    4,
    5,
    6,
    7,
    8,
    9,
    10,
    11,
    12,
    13,
    14,
    15,
    30,
    1 * 60,
    1 * 60 * 60,
    24 * 60 * 60,
    7 * 24 * 60 * 60
]

private final class AutoremoveTimeoutSelectorItemNode: ActionSheetItemNode, UIPickerViewDelegate, UIPickerViewDataSource {
    private let theme: ActionSheetControllerTheme
    private let strings: PresentationStrings
    
    private let timeoutValues: [Int32]
    
    private let valueChanged: (Int32) -> Void
    private let pickerView: UIPickerView
    
    init(theme: ActionSheetControllerTheme, strings: PresentationStrings, currentValue: Int32, availableValues: [Int32]?, valueChanged: @escaping (Int32) -> Void) {
        self.theme = theme
        self.strings = strings
        self.valueChanged = valueChanged
        
        self.pickerView = UIPickerView()
        
        if let availableValues = availableValues {
            self.timeoutValues = [0] + availableValues.filter({ $0 > 0 })
        } else {
            self.timeoutValues = defaultTimeoutValues
        }
        
        super.init(theme: theme)
        
        self.pickerView.delegate = self
        self.pickerView.dataSource = self
        self.view.addSubview(self.pickerView)
        
        self.pickerView.reloadAllComponents()
        var index: Int = 0
        for i in 0 ..< self.timeoutValues.count {
            if currentValue <= self.timeoutValues[i] {
                index = i
                break
            }
        }
        self.pickerView.selectRow(index, inComponent: 0, animated: false)
    }
    
    func numberOfComponents(in pickerView: UIPickerView) -> Int {
        return 1
    }
    
    func pickerView(_ pickerView: UIPickerView, numberOfRowsInComponent component: Int) -> Int {
        return self.timeoutValues.count
    }
    
    func pickerView(_ pickerView: UIPickerView, rowHeightForComponent component: Int) -> CGFloat {
        return 40.0
    }
    
    func pickerView(_ pickerView: UIPickerView, attributedTitleForRow row: Int, forComponent component: Int) -> NSAttributedString? {
        if self.timeoutValues[row] == 0 {
            return NSAttributedString(string: self.strings.Profile_MessageLifetimeForever, font: Font.medium(15.0), textColor: self.theme.primaryTextColor)
        } else {
            return NSAttributedString(string: timeIntervalString(strings: self.strings, value: self.timeoutValues[row]), font: Font.medium(15.0), textColor: self.theme.primaryTextColor)
        }
    }
    
    func pickerView(_ pickerView: UIPickerView, didSelectRow row: Int, inComponent component: Int) {
        self.valueChanged(self.timeoutValues[row])
    }
    
    public override func updateLayout(constrainedSize: CGSize, transition: ContainedViewLayoutTransition) -> CGSize {
        let size = CGSize(width: constrainedSize.width, height: 180.0)
        
        self.pickerView.frame = CGRect(origin: CGPoint(), size: CGSize(width: size.width, height: 180.0))
       
        self.updateInternalLayout(size, constrainedSize: constrainedSize)
        return size
    }
}
