import Foundation
import Display
import AsyncDisplayKit
import UIKit
import SwiftSignalKit
import Photos

final class ChatDateSelectionSheet: ActionSheetController {
    private let strings: PresentationStrings
    
    private let _ready = Promise<Bool>()
    override var ready: Promise<Bool> {
        return self._ready
    }
    
    init(theme: PresentationTheme, strings: PresentationStrings, completion: @escaping (Int32) -> Void) {
        self.strings = strings
        
        super.init(theme: ActionSheetControllerTheme(presentationTheme: theme))
        
        self._ready.set(.single(true))
        
        var updatedValue: Int32?
        self.setItemGroups([
            ActionSheetItemGroup(items: [
                ChatDateSelectorItem(strings: strings, valueChanged: { value in
                    updatedValue = value
                }),
                ActionSheetButtonItem(title: strings.Common_Search, action: { [weak self] in
                    self?.dismissAnimated()
                    if let updatedValue = updatedValue {
                        completion(updatedValue)
                    }
                })
            ]),
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
        
        self.pickerView = UIDatePicker()
        self.pickerView.datePickerMode = .date
        self.pickerView.locale = Locale(identifier: strings.baseLanguageCode)
        self.pickerView.setValue(theme.primaryTextColor, forKey: "textColor")
        
        self.pickerView.minimumDate = Date(timeIntervalSince1970: 1376438400.0)
        self.pickerView.maximumDate = Date(timeIntervalSinceNow: 2.0)
        
        
        super.init(theme: theme)
        
        self.view.addSubview(self.pickerView)
        self.pickerView.addTarget(self, action: #selector(self.pickerChanged), for: .valueChanged)
    }
    
    override func calculateSizeThatFits(_ constrainedSize: CGSize) -> CGSize {
        return CGSize(width: constrainedSize.width, height: 157.0)
    }
    
    override func layout() {
        super.layout()
        
        self.pickerView.frame = CGRect(origin: CGPoint(), size: CGSize(width: self.bounds.size.width, height: 180.0))
    }
    
    @objc func pickerChanged() {
        self.valueChanged(self.currentValue)
    }
}
