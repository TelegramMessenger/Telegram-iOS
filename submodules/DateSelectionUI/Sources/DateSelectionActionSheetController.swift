import Foundation
import UIKit
import Display
import AsyncDisplayKit
import TelegramPresentationData
import TelegramStringFormatting
import SwiftSignalKit
import AccountContext
import UIKitRuntimeUtils

public final class DateSelectionActionSheetController: ActionSheetController {
    private var presentationDisposable: Disposable?
    
    private let _ready = Promise<Bool>()
    override public var ready: Promise<Bool> {
        return self._ready
    }
    
    public init(context: AccountContext, title: String?, currentValue: Int32, minimumDate: Date? = nil, maximumDate: Date? = nil, emptyTitle: String? = nil, applyValue: @escaping (Int32?) -> Void) {
        let presentationData = context.sharedContext.currentPresentationData.with { $0 }
        let strings = presentationData.strings
        
        super.init(theme: ActionSheetControllerTheme(presentationData: presentationData))
        
        self.presentationDisposable = context.sharedContext.presentationData.start(next: { [weak self] presentationData in
            if let strongSelf = self {
                strongSelf.theme = ActionSheetControllerTheme(presentationData: presentationData)
            }
        })
        
        self._ready.set(.single(true))
        
        var updatedValue = currentValue
        var items: [ActionSheetItem] = []
        if let title = title {
            items.append(ActionSheetTextItem(title: title))
        }
        items.append(DateSelectionActionSheetItem(strings: strings, currentValue: currentValue, minimumDate: minimumDate, maximumDate: maximumDate, valueChanged: { value in
            updatedValue = value
        }))
        if let emptyTitle = emptyTitle {
            items.append(ActionSheetButtonItem(title: emptyTitle, action: { [weak self] in
                self?.dismissAnimated()
                applyValue(nil)
            }))
        }
        items.append(ActionSheetButtonItem(title: strings.Wallpaper_Set, action: { [weak self] in
            self?.dismissAnimated()
            applyValue(updatedValue)
        }))
        self.setItemGroups([
            ActionSheetItemGroup(items: items),
            ActionSheetItemGroup(items: [
                ActionSheetButtonItem(title: strings.Common_Cancel, action: { [weak self] in
                    self?.dismissAnimated()
                }),
            ])
        ])
    }
    
    required public init(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    deinit {
        self.presentationDisposable?.dispose()
    }
}

private final class DateSelectionActionSheetItem: ActionSheetItem {
    let strings: PresentationStrings
    
    let currentValue: Int32
    let minimumDate: Date?
    let maximumDate: Date?
    let valueChanged: (Int32) -> Void

    init(strings: PresentationStrings, currentValue: Int32, minimumDate: Date?, maximumDate: Date?, valueChanged: @escaping (Int32) -> Void) {
        self.strings = strings
        self.currentValue = roundDateToDays(currentValue)
        self.minimumDate = minimumDate
        self.maximumDate = maximumDate
        self.valueChanged = valueChanged
    }
    
    func node(theme: ActionSheetControllerTheme) -> ActionSheetItemNode {
        return DateSelectionActionSheetItemNode(theme: theme, strings: self.strings, currentValue: self.currentValue, minimumDate: self.minimumDate, maximumDate: self.maximumDate, valueChanged: self.valueChanged)
    }
    
    func updateNode(_ node: ActionSheetItemNode) {
    }
}

private final class DateSelectionActionSheetItemNode: ActionSheetItemNode {
    private let theme: ActionSheetControllerTheme
    private let strings: PresentationStrings
    
    private let valueChanged: (Int32) -> Void
    private let pickerView: UIDatePicker
    
    init(theme: ActionSheetControllerTheme, strings: PresentationStrings, currentValue: Int32, minimumDate: Date?, maximumDate: Date?, valueChanged: @escaping (Int32) -> Void) {
        self.theme = theme
        self.strings = strings
        self.valueChanged = valueChanged
        
        UILabel.setDateLabel(theme.primaryTextColor)
        
        self.pickerView = UIDatePicker()
        self.pickerView.timeZone = TimeZone(secondsFromGMT: 0)
        self.pickerView.datePickerMode = .countDownTimer
        self.pickerView.datePickerMode = .date
        self.pickerView.date = Date(timeIntervalSince1970: Double(roundDateToDays(currentValue)))
        self.pickerView.locale = localeWithStrings(strings)
        if #available(iOS 13.4, *) {
            self.pickerView.preferredDatePickerStyle = .wheels
        }
        if let minimumDate = minimumDate {
            self.pickerView.minimumDate = minimumDate
        }
        if let maximumDate = maximumDate {
            self.pickerView.maximumDate = maximumDate
        } else {
            self.pickerView.maximumDate = Date(timeIntervalSince1970: Double(Int32.max - 1))
        }
        self.pickerView.setValue(theme.primaryTextColor, forKey: "textColor")
        
        super.init(theme: theme)
        
        self.view.addSubview(self.pickerView)
        self.pickerView.addTarget(self, action: #selector(self.datePickerUpdated), for: .valueChanged)
    }
    
    public override func updateLayout(constrainedSize: CGSize, transition: ContainedViewLayoutTransition) -> CGSize {
        let size = CGSize(width: constrainedSize.width, height: 216.0)
      
        self.pickerView.frame = CGRect(origin: CGPoint(), size: size)
        
        self.updateInternalLayout(size, constrainedSize: constrainedSize)
        return size
    }
    
    @objc private func datePickerUpdated() {
        self.valueChanged(roundDateToDays(Int32(self.pickerView.date.timeIntervalSince1970)))
    }
}

