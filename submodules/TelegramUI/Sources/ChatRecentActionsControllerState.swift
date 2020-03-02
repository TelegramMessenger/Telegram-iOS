import Foundation
import UIKit
import TelegramCore
import SyncCore
import TelegramPresentationData
import TelegramUIPreferences

final class ChatRecentActionsControllerState: Equatable {
    let chatWallpaper: TelegramWallpaper
    let theme: PresentationTheme
    let strings: PresentationStrings
    let fontSize: PresentationFontSize
    
    init(chatWallpaper: TelegramWallpaper, theme: PresentationTheme, strings: PresentationStrings, fontSize: PresentationFontSize) {
        self.chatWallpaper = chatWallpaper
        self.theme = theme
        self.strings = strings
        self.fontSize = fontSize
    }
    
    static func ==(lhs: ChatRecentActionsControllerState, rhs: ChatRecentActionsControllerState) -> Bool {
        if lhs.chatWallpaper != rhs.chatWallpaper {
            return false
        }
        if lhs.theme !== rhs.theme {
            return false
        }
        if lhs.strings !== rhs.strings {
            return false
        }
        if lhs.fontSize != rhs.fontSize {
            return false
        }
        return true
    }
}
