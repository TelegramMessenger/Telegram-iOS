import Foundation
import Display
import AsyncDisplayKit
import UIKit
import SwiftSignalKit
import Photos

final class DateSelectionActionSheetController: ActionSheetController {
    private let theme: PresentationTheme
    private let strings: PresentationStrings
    
    private let _ready = Promise<Bool>()
    override var ready: Promise<Bool> {
        return self._ready
    }
    
    init(theme: PresentationTheme, strings: PresentationStrings, currentValue: Int32, minimumDate: Date? = nil, maximumDate: Date? = nil, emptyTitle: String? = nil, applyValue: @escaping (Int32?) -> Void) {
        self.theme = theme
        self.strings = strings
        
        super.init(theme: ActionSheetControllerTheme(presentationTheme: theme))
        
        self._ready.set(.single(true))
        
        var updatedValue = currentValue
        var items: [ActionSheetItem] = []
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
    
    required init(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
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
        
        self.pickerView = UIDatePicker()
        self.pickerView.timeZone = TimeZone(secondsFromGMT: 0)
        self.pickerView.datePickerMode = .date
        self.pickerView.date = Date(timeIntervalSince1970: Double(roundDateToDays(currentValue)))
        self.pickerView.locale = localeWithStrings(strings)
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
    
    override func calculateSizeThatFits(_ constrainedSize: CGSize) -> CGSize {
        return CGSize(width: constrainedSize.width, height: 216.0)
    }
    
    override func layout() {
        super.layout()
        
        self.pickerView.frame = CGRect(origin: CGPoint(), size: CGSize(width: self.bounds.size.width, height: 216.0))
    }
    
    @objc private func datePickerUpdated() {
        self.valueChanged(roundDateToDays(Int32(self.pickerView.date.timeIntervalSince1970)))
    }
}

