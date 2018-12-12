import Foundation
import UIKit
import Display

public final class AuthorizationTheme {
    let statusBarStyle: StatusBarStyle
    let navigationBarBackgroundColor: UIColor
    let navigationBarTextColor: UIColor
    let navigationBarSeparatorColor: UIColor
    let searchBarBackgroundColor: UIColor
    let searchBarFillColor: UIColor
    let searchBarPlaceholderColor: UIColor
    let searchBarTextColor: UIColor
    let keyboard: PresentationThemeKeyboardColor
    let backgroundColor: UIColor
    let primaryColor: UIColor
    let separatorColor: UIColor
    let itemHighlightedBackgroundColor: UIColor
    let dotColor: UIColor
    let startButtonColor: UIColor
    let accentColor: UIColor
    let destructiveColor: UIColor
    let disclosureControlColor: UIColor
    let textPlaceholderColor: UIColor
    let alertBackgroundColor: UIColor
    let listBackgroundColor: UIColor
    
    init(statusBarStyle: StatusBarStyle, navigationBarBackgroundColor: UIColor, navigationBarTextColor: UIColor, navigationBarSeparatorColor: UIColor, searchBarBackgroundColor: UIColor, searchBarFillColor: UIColor, searchBarPlaceholderColor: UIColor, searchBarTextColor: UIColor, keyboard: PresentationThemeKeyboardColor, backgroundColor: UIColor, primaryColor: UIColor, separatorColor: UIColor, itemHighlightedBackgroundColor: UIColor, dotColor: UIColor, startButtonColor: UIColor, accentColor: UIColor, destructiveColor: UIColor, disclosureControlColor: UIColor, textPlaceholderColor: UIColor, alertBackgroundColor: UIColor, listBackgroundColor: UIColor) {
        self.statusBarStyle = statusBarStyle
        self.navigationBarBackgroundColor = navigationBarBackgroundColor
        self.navigationBarTextColor = navigationBarTextColor
        self.navigationBarSeparatorColor = navigationBarSeparatorColor
        self.searchBarBackgroundColor = searchBarBackgroundColor
        self.searchBarFillColor = searchBarFillColor
        self.searchBarPlaceholderColor = searchBarPlaceholderColor
        self.searchBarTextColor = searchBarTextColor
        self.keyboard = keyboard
        self.backgroundColor = backgroundColor
        self.primaryColor = primaryColor
        self.separatorColor = separatorColor
        self.itemHighlightedBackgroundColor = itemHighlightedBackgroundColor
        self.dotColor = dotColor
        self.startButtonColor = startButtonColor
        self.accentColor = accentColor
        self.destructiveColor = destructiveColor
        self.disclosureControlColor = disclosureControlColor
        self.textPlaceholderColor = textPlaceholderColor
        self.alertBackgroundColor = alertBackgroundColor
        self.listBackgroundColor = listBackgroundColor
    }
}

let defaultLightAuthorizationTheme = AuthorizationTheme(
    statusBarStyle: .Black,
    navigationBarBackgroundColor: UIColor(red: 0.968626451, green: 0.968626451, blue: 0.968626451, alpha: 1.0),
    navigationBarTextColor: .black,
    navigationBarSeparatorColor: UIColor(red: 0.6953125, green: 0.6953125, blue: 0.6953125, alpha: 1.0),
    searchBarBackgroundColor: .white,
    searchBarFillColor: UIColor(rgb: 0xe9e9e9),
    searchBarPlaceholderColor: UIColor(rgb: 0x8e8e93),
    searchBarTextColor: .black,
    keyboard: .light,
    backgroundColor: .white,
    primaryColor: .black,
    separatorColor: UIColor(red: 0.6953125, green: 0.6953125, blue: 0.6953125, alpha: 1.0),
    itemHighlightedBackgroundColor: UIColor(rgb: 0xd9d9d9),
    dotColor: UIColor(rgb: 0xd9d9d9),
    startButtonColor: UIColor(rgb: 0x2ca5e0),
    accentColor: UIColor(rgb: 0x007ee5),
    destructiveColor: UIColor(rgb: 0xff3b30),
    disclosureControlColor: UIColor(rgb: 0xbab9be),
    textPlaceholderColor: UIColor(rgb: 0x8e8e93),
    alertBackgroundColor: .white,
    listBackgroundColor: UIColor(rgb: 0xefeff4)
)

let defaultAuthorizationTheme = AuthorizationTheme(
    statusBarStyle: .White,
    navigationBarBackgroundColor: .black,
    navigationBarTextColor: .white,
    navigationBarSeparatorColor: UIColor(rgb: 0x252525),
    searchBarBackgroundColor: .black,
    searchBarFillColor: UIColor(rgb: 0x272728),
    searchBarPlaceholderColor: UIColor(rgb: 0x5e5e5e),
    searchBarTextColor: .white,
    keyboard: .dark,
    backgroundColor: .black,
    primaryColor: .white,
    separatorColor: UIColor(rgb: 0x252525),
    itemHighlightedBackgroundColor: UIColor(rgb: 0x1b1b1b),
    dotColor: UIColor(rgb: 0x717171),
    startButtonColor: .white,
    accentColor: .white,
    destructiveColor: UIColor(rgb: 0xFF736B),
    disclosureControlColor: UIColor(rgb: 0x717171),
    textPlaceholderColor: UIColor(rgb: 0x4d4d4d),
    alertBackgroundColor: UIColor(rgb: 0x1c1c1c),
    listBackgroundColor: UIColor(rgb: 0xefeff4)
)

