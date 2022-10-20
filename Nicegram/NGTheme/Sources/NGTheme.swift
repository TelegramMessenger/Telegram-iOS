import UIKit
import NGExtensions
import TelegramPresentationData
import Display

public enum NGTheme {
    case dark
    case white
}

public struct NGThemeColors {
    public let theme: NGTheme
    
    public init(telegramTheme: PresentationThemeStatusBarStyle, statusBarStyle: StatusBarStyle) {
        switch statusBarStyle {
        case .White:
            self.theme = .dark
        case .Black:
            self.theme = .white
        case .Hide, .Ignore:
            if telegramTheme == .black {
                self.theme = .white
            } else {
                self.theme = .dark
            }        }
    }
    
    public var backgroundColor: UIColor {
        switch theme {
        case .dark:
            return .ngBackground
        case .white:
            return .ngWhiteBackground
        }
    }
    
    public var titleColor: UIColor {
        switch theme {
        case .dark:
            return .black
        case .white:
            return .white
        }
    }
    
    public var subtitleColor: UIColor {
        return .ngSubtitle
    }
    
    public var cardColor: UIColor {
        switch theme {
        case .dark:
            return .ngCardBackground
        case .white:
            return .white
        }
    }
    
    public var incativeButtonColor: UIColor {
        switch theme {
        case .dark:
            return .ngInactiveButton
        case .white:
            return .ngWhiteIncativeButton
        }
    }
    
    public var reverseTitleColor: UIColor {
        switch theme {
        case .dark:
            return .white
        case .white:
            return .black
        }
    }
    
    public var separatorColor: UIColor {
        switch theme {
        case .dark:
            return UIColor(red: 0.333, green: 0.333, blue: 0.345, alpha: 1)
        case .white:
            return UIColor(red: 0.235, green: 0.235, blue: 0.263, alpha: 0.29)
        }
    }
    
    public var navigationBarTintColor: UIColor {
        switch theme {
        case .dark:
            return .white
        case .white:
            return .ngActiveButton
        }
    }
    
    public var keyboardAppearance: UIKeyboardAppearance {
        switch theme {
        case .dark:
            return .dark
        case .white:
            return .light
        }
    }
    
    public var blurStyle: UIBlurEffect.Style {
        switch theme {
        case .dark:
            return .dark
        case .white:
            return .light
        }
    }
}


