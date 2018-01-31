import Foundation
import UIKit

enum ChatTextInputMenuState {
    case inactive
    case general
    case format
}

final class ChatTextInputMenu {
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
                            UIMenuItem(title: "Bold", action: Selector(("formatAttributesBold:"))),
                            UIMenuItem(title: "Italic", action: Selector(("formatAttributesItalic:"))),
                            UIMenuItem(title: "Monospace", action: Selector(("formatAttributesMonospace:")))
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
