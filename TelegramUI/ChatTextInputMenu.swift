import Foundation
import UIKit

enum ChatTextInputMenuState {
    case inactive
    case general
    case format
}

final class ChatTextInputMenu {
    private var stringBold: String = "Bold"
    private var stringItalic: String = "Italic"
    private var stringMonospace: String = "Monospace"
    
    private(set) var state: ChatTextInputMenuState = .inactive {
        didSet {
            if self.state != oldValue {
                switch self.state {
                    case .inactive:
                        UIMenuController.shared.menuItems = []
                    case .general:
                        UIMenuController.shared.menuItems = []
                        //UIMenuController.shared.menuItems = [UIMenuItem(title: "Format", action: Selector(("_showTextStyleOptions:")))]
                    case .format:
                        UIMenuController.shared.menuItems = [
                            UIMenuItem(title: self.stringBold, action: Selector(("formatAttributesBold:"))),
                            UIMenuItem(title: self.stringItalic, action: Selector(("formatAttributesItalic:"))),
                            UIMenuItem(title: self.stringMonospace, action: Selector(("formatAttributesMonospace:")))
                        ]
                        UIMenuController.shared.isMenuVisible = true
                        UIMenuController.shared.update()
                }
                
            }
        }
    }
    
    private var observer: NSObjectProtocol?
    
    init() {
        self.observer = NotificationCenter.default.addObserver(forName: NSNotification.Name.UIMenuControllerDidHideMenu, object: nil, queue: nil, using: { [weak self] _ in
            self?.back()
        })
    }
    
    deinit {
        if let observer = self.observer {
            NotificationCenter.default.removeObserver(observer)
        }
    }
    
    func updateStrings(_ strings: PresentationStrings) {
        self.stringBold = strings.TextFormat_Bold
        self.stringItalic = strings.TextFormat_Italic
        self.stringMonospace = strings.TextFormat_Monospace
    }
    
    func activate() {
        if self.state == .inactive {
            self.state = .general
        }
    }
    
    func deactivate() {
        self.state = .inactive
    }
    
    func format() {
        if self.state == .general {
            self.state = .format
        }
    }
    
    func back() {
        if self.state == .format {
            self.state = .general
        }
    }
}
