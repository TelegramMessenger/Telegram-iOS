import Foundation
import UIKit
import Display
import TelegramPresentationData
import TelegramUIPreferences

final class InstantPageSettingsItemTheme: Equatable {
    let listBackgroundColor: UIColor
    let itemBackgroundColor: UIColor
    let itemHighlightedBackgroundColor: UIColor
    let separatorColor: UIColor
    let primaryColor: UIColor
    let secondaryColor: UIColor
    let accentColor: UIColor
    
    init(listBackgroundColor: UIColor, itemBackgroundColor: UIColor, itemHighlightedBackgroundColor: UIColor, separatorColor: UIColor, primaryColor: UIColor, secondaryColor: UIColor, accentColor: UIColor) {
        self.listBackgroundColor = listBackgroundColor
        self.itemBackgroundColor = itemBackgroundColor
        self.itemHighlightedBackgroundColor = itemHighlightedBackgroundColor
        self.separatorColor = separatorColor
        self.primaryColor = primaryColor
        self.secondaryColor = secondaryColor
        self.accentColor = accentColor
    }
    
    static func ==(lhs: InstantPageSettingsItemTheme, rhs: InstantPageSettingsItemTheme) -> Bool {
        if !lhs.listBackgroundColor.isEqual(rhs.listBackgroundColor) {
            return false
        }
        if !lhs.itemBackgroundColor.isEqual(rhs.itemBackgroundColor) {
            return false
        }
        if !lhs.itemHighlightedBackgroundColor.isEqual(rhs.itemHighlightedBackgroundColor) {
            return false
        }
        if !lhs.separatorColor.isEqual(rhs.separatorColor) {
            return false
        }
        if !lhs.primaryColor.isEqual(rhs.primaryColor) {
            return false
        }
        if !lhs.secondaryColor.isEqual(rhs.secondaryColor) {
            return false
        }
        if !lhs.accentColor.isEqual(rhs.accentColor) {
            return false
        }
        return true
    }
    
    static func themeFor(_ type: InstantPageThemeType) -> InstantPageSettingsItemTheme {
        switch type {
            case .light:
                return lightTheme
            case .sepia:
                return sepiaTheme
            case .gray:
                return grayTheme
            case .dark:
                return darkTheme
        }
    }
}

private let lightTheme = InstantPageSettingsItemTheme(
    listBackgroundColor: UIColor(rgb: 0xefeff4),
    itemBackgroundColor: .white,
    itemHighlightedBackgroundColor: UIColor(rgb: 0xd9d9d9),
    separatorColor: UIColor(rgb: 0xc8c7cc),
    primaryColor: .black,
    secondaryColor: UIColor(rgb: 0xa8a8a8),
    accentColor: UIColor(rgb: 0x007aff)
)

private let sepiaTheme = InstantPageSettingsItemTheme(
    listBackgroundColor: UIColor(rgb: 0xefeff4),
    itemBackgroundColor: .white,
    itemHighlightedBackgroundColor: UIColor(rgb: 0xd9d9d9),
    separatorColor: UIColor(rgb: 0xc8c7cc),
    primaryColor: .black,
    secondaryColor: UIColor(rgb: 0xb7b7b7),
    accentColor: UIColor(rgb: 0xb06900)
)

private let grayTheme = InstantPageSettingsItemTheme(
    listBackgroundColor: UIColor(rgb: 0xefeff4),
    itemBackgroundColor: .white,
    itemHighlightedBackgroundColor: UIColor(rgb: 0xd9d9d9),
    separatorColor: UIColor(rgb: 0xc8c7cc),
    primaryColor: .black,
    secondaryColor: UIColor(rgb: 0xb6b6b6),
    accentColor: UIColor(rgb: 0xc7c7c7)
)

private let darkTheme = InstantPageSettingsItemTheme(
    listBackgroundColor: UIColor(rgb: 0x232323),
    itemBackgroundColor: UIColor(rgb: 0x1a1a1a),
    itemHighlightedBackgroundColor: UIColor(rgb: 0x4c4c4c),
    separatorColor: UIColor(rgb: 0x151515),
    primaryColor: UIColor(rgb: 0x878787),
    secondaryColor: UIColor(rgb: 0xa6a6a6),
    accentColor: UIColor(rgb: 0xbfc0c2)
)
