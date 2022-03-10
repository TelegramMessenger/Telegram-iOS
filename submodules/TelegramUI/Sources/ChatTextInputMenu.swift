import Foundation
import UIKit
import TelegramPresentationData

enum ChatTextInputMenuState {
    case inactive
    case general
    case format
}

final class ChatTextInputMenu {
    private var stringBold: String = "Bold"
    private var stringItalic: String = "Italic"
    private var stringMonospace: String = "Monospace"
    private var stringLink: String = "Link"
    private var stringStrikethrough: String = "Strikethrough"
    private var stringUnderline: String = "Underline"
    private var stringSpoiler: String = "Spoiler"
    
    private let hasSpoilers: Bool
    
    private(set) var state: ChatTextInputMenuState = .inactive {
        didSet {
            if self.state != oldValue {
                switch self.state {
                    case .inactive:
                        UIMenuController.shared.menuItems = []
                    case .general:
                        UIMenuController.shared.menuItems = []
                    case .format:
                        var menuItems: [UIMenuItem] = [
                            UIMenuItem(title: self.stringBold, action: Selector(("formatAttributesBold:"))),
                            UIMenuItem(title: self.stringItalic, action: Selector(("formatAttributesItalic:"))),
                            UIMenuItem(title: self.stringMonospace, action: Selector(("formatAttributesMonospace:"))),
                            UIMenuItem(title: self.stringLink, action: Selector(("formatAttributesLink:"))),
                            UIMenuItem(title: self.stringStrikethrough, action: Selector(("formatAttributesStrikethrough:"))),
                            UIMenuItem(title: self.stringUnderline, action: Selector(("formatAttributesUnderline:")))
                        ]
                        if self.hasSpoilers {
                            menuItems.insert(UIMenuItem(title: self.stringSpoiler, action: Selector(("formatAttributesSpoiler:"))), at: 0)
                        }
                        UIMenuController.shared.menuItems = menuItems
                }
                
            }
        }
    }
    
    private var observer: NSObjectProtocol?
    
    init(hasSpoilers: Bool = false) {
        self.hasSpoilers = hasSpoilers
        self.observer = NotificationCenter.default.addObserver(forName: UIMenuController.didHideMenuNotification, object: nil, queue: nil, using: { [weak self] _ in
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
        self.stringLink = strings.TextFormat_Link
        self.stringStrikethrough = strings.TextFormat_Strikethrough
        self.stringUnderline = strings.TextFormat_Underline
        self.stringSpoiler = strings.TextFormat_Spoiler
    }
    
    func activate() {
        if self.state == .inactive {
            self.state = .general
        }
    }
    
    func deactivate() {
        self.state = .inactive
    }
    
    func format(view: UIView, rect: CGRect) {
        if self.state == .general {
            self.state = .format
            if #available(iOS 13.0, *) {
                UIMenuController.shared.showMenu(from: view, rect: rect)
            } else {
                UIMenuController.shared.isMenuVisible = true
                UIMenuController.shared.update()
            }
        }
    }
    
    func back() {
        if self.state == .format {
            self.state = .general
        }
    }
    
    func hide() {
        self.back()
        if #available(iOS 13.0, *) {
            UIMenuController.shared.hideMenu()
        } else {
            UIMenuController.shared.isMenuVisible = false
        }
        UIMenuController.shared.update()
    }
}
