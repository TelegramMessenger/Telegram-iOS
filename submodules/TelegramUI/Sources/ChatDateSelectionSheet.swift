import Foundation
import UIKit
import Display
import AsyncDisplayKit
import UIKit
import SwiftSignalKit
import Photos
import TelegramPresentationData
import UIKitRuntimeUtils

final class ChatDateSelectionSheet: ActionSheetController {
    private let strings: PresentationStrings
    
    private let _ready = Promise<Bool>()
    override var ready: Promise<Bool> {
        return self._ready
    }
    
    init(presentationData: PresentationData, completion: @escaping (Int32) -> Void) {
        self.strings = presentationData.strings
        
        super.init(theme: ActionSheetControllerTheme(presentationData: presentationData))
        
        self._ready.set(.single(true))
        
        var updatedValue: Int32?
        self.setItemGroups([
            ActionSheetItemGroup(items: [
                ChatDateSelectorItem(strings: self.strings, valueChanged: { value in
                    updatedValue = value
                }),
                ActionSheetButtonItem(title: self.strings.Common_Search, action: { [weak self] in
                    self?.dismissAnimated()
                    if let updatedValue = updatedValue {
                        completion(updatedValue)
                    }
                })
            ]),
            ActionSheetItemGroup(items: [
                ActionSheetButtonItem(title: self.strings.Common_Cancel, action: { [weak self] in
                    self?.dismissAnimated()
                }),
            ])
        ])
    }
    
    required init(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

private final class ChatDateSelectorItem: ActionSheetItem {
    let strings: PresentationStrings
    
    let valueChanged: (Int32) -> Void
    
    init(strings: PresentationStrings, valueChanged: @escaping (Int32) -> Void) {
        self.strings = strings
        self.valueChanged = valueChanged
    }
    
    func node(theme: ActionSheetControllerTheme) -> ActionSheetItemNode {
        return ChatDateSelectorItemNode(theme: theme, strings: self.strings, valueChanged: self.valueChanged)
    }
    
    func updateNode(_ node: ActionSheetItemNode) {
    }
}

private final class ChatDateSelectorItemNode: ActionSheetItemNode {
    private let theme: ActionSheetControllerTheme
    private let strings: PresentationStrings
    
    private let pickerView: UIDatePicker
    
    private let valueChanged: (Int32) -> Void
    
    private var currentValue: Int32 {
        return Int32(self.pickerView.date.timeIntervalSince1970)
    }
    
    init(theme: ActionSheetControllerTheme, strings: PresentationStrings, valueChanged: @escaping (Int32) -> Void) {
        self.theme = theme
        self.strings = strings
        self.valueChanged = valueChanged
        
        UILabel.setDateLabel(theme.primaryTextColor)
        
        self.pickerView = UIDatePicker()
        self.pickerView.datePickerMode = .countDownTimer
        self.pickerView.datePickerMode = .date
        self.pickerView.locale = Locale(identifier: strings.baseLanguageCode)
        
        self.pickerView.minimumDate = Date(timeIntervalSince1970: 1376438400.0)
        self.pickerView.maximumDate = Date(timeIntervalSinceNow: 2.0)
        
        if #available(iOS 13.4, *) {
            self.pickerView.preferredDatePickerStyle = .wheels
        }
        
        self.pickerView.setValue(theme.primaryTextColor, forKey: "textColor")
        self.pickerView.setValue(theme.primaryTextColor, forKey: "highlightColor")
        
        super.init(theme: theme)
        
        self.view.addSubview(self.pickerView)
        self.pickerView.addTarget(self, action: #selector(self.pickerChanged), for: .valueChanged)
    }
    
    public override func updateLayout(constrainedSize: CGSize, transition: ContainedViewLayoutTransition) -> CGSize {
        let size = CGSize(width: constrainedSize.width, height: 157.0)
        
        self.pickerView.frame = CGRect(origin: CGPoint(), size: CGSize(width: size.width, height: 180.0))
       
        self.updateInternalLayout(size, constrainedSize: constrainedSize)
        return size
    }
    
    @objc func pickerChanged() {
        self.valueChanged(self.currentValue)
    }
}
