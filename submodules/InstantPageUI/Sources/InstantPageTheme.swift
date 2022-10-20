import Foundation
import UIKit
import Postbox
import Display
import TelegramPresentationData
import TelegramUIPreferences

enum InstantPageFontStyle {
    case sans
    case serif
}

struct InstantPageFont {
    let style: InstantPageFontStyle
    let size: CGFloat
    let lineSpacingFactor: CGFloat
}

struct InstantPageTextAttributes {
    let font: InstantPageFont
    let color: UIColor
    let underline: Bool
    
    init(font: InstantPageFont, color: UIColor, underline: Bool = false) {
        self.font = font
        self.color = color
        self.underline = underline
    }
    
    func withUnderline(_ underline: Bool) -> InstantPageTextAttributes {
        return InstantPageTextAttributes(font: self.font, color: self.color, underline: underline)
    }
    
    func withUpdatedFontStyles(sizeMultiplier: CGFloat, forceSerif: Bool) -> InstantPageTextAttributes {
        return InstantPageTextAttributes(font: InstantPageFont(style: forceSerif ? .serif : self.font.style, size: floor(self.font.size * sizeMultiplier), lineSpacingFactor: self.font.lineSpacingFactor), color: self.color, underline: self.underline)
    }
}

enum InstantPageTextCategoryType {
    case kicker
    case header
    case subheader
    case paragraph
    case caption
    case credit
    case table
    case article
}

struct InstantPageTextCategories {
    let kicker: InstantPageTextAttributes
    let header: InstantPageTextAttributes
    let subheader: InstantPageTextAttributes
    let paragraph: InstantPageTextAttributes
    let caption: InstantPageTextAttributes
    let credit: InstantPageTextAttributes
    let table: InstantPageTextAttributes
    let article: InstantPageTextAttributes
    
    func attributes(type: InstantPageTextCategoryType, link: Bool) -> InstantPageTextAttributes {
        switch type {
            case .kicker:
                return self.kicker.withUnderline(link)
            case .header:
                return self.header.withUnderline(link)
            case .subheader:
                return self.subheader.withUnderline(link)
            case .paragraph:
                return self.paragraph.withUnderline(link)
            case .caption:
                return self.caption.withUnderline(link)
            case .credit:
                return self.credit.withUnderline(link)
            case .table:
                return self.table.withUnderline(link)
            case .article:
                return self.article.withUnderline(link)
        }
    }
    
    func withUpdatedFontStyles(sizeMultiplier: CGFloat, forceSerif: Bool) -> InstantPageTextCategories {
        return InstantPageTextCategories(kicker: self.kicker.withUpdatedFontStyles(sizeMultiplier: sizeMultiplier, forceSerif: forceSerif), header: self.header.withUpdatedFontStyles(sizeMultiplier: sizeMultiplier, forceSerif: forceSerif), subheader: self.subheader.withUpdatedFontStyles(sizeMultiplier: sizeMultiplier, forceSerif: forceSerif), paragraph: self.paragraph.withUpdatedFontStyles(sizeMultiplier: sizeMultiplier, forceSerif: forceSerif), caption: self.caption.withUpdatedFontStyles(sizeMultiplier: sizeMultiplier, forceSerif: forceSerif), credit: self.credit.withUpdatedFontStyles(sizeMultiplier: sizeMultiplier, forceSerif: forceSerif), table: self.table.withUpdatedFontStyles(sizeMultiplier: sizeMultiplier, forceSerif: forceSerif), article: self.article.withUpdatedFontStyles(sizeMultiplier: sizeMultiplier, forceSerif: forceSerif))
    }
}

final class InstantPageTheme {
    let type: InstantPageThemeType
    let pageBackgroundColor: UIColor
    
    let textCategories: InstantPageTextCategories
    let serif: Bool
    
    let codeBlockBackgroundColor: UIColor
    
    let linkColor: UIColor
    let textHighlightColor: UIColor
    let linkHighlightColor: UIColor
    let markerColor: UIColor
    
    let panelBackgroundColor: UIColor
    let panelHighlightedBackgroundColor: UIColor
    let panelPrimaryColor: UIColor
    let panelSecondaryColor: UIColor
    let panelAccentColor: UIColor
    
    let tableBorderColor: UIColor
    let tableHeaderColor: UIColor
    let controlColor: UIColor
    
    let imageTintColor: UIColor?
    
    let overlayPanelColor: UIColor
    
    init(type: InstantPageThemeType, pageBackgroundColor: UIColor, textCategories: InstantPageTextCategories, serif: Bool, codeBlockBackgroundColor: UIColor, linkColor: UIColor, textHighlightColor: UIColor, linkHighlightColor: UIColor, markerColor: UIColor, panelBackgroundColor: UIColor, panelHighlightedBackgroundColor: UIColor, panelPrimaryColor: UIColor, panelSecondaryColor: UIColor, panelAccentColor: UIColor, tableBorderColor: UIColor, tableHeaderColor: UIColor, controlColor: UIColor, imageTintColor: UIColor?, overlayPanelColor: UIColor) {
        self.type = type
        self.pageBackgroundColor = pageBackgroundColor
        self.textCategories = textCategories
        self.serif = serif
        self.codeBlockBackgroundColor = codeBlockBackgroundColor
        self.linkColor = linkColor
        self.textHighlightColor = textHighlightColor
        self.linkHighlightColor = linkHighlightColor
        self.markerColor = markerColor
        self.panelBackgroundColor = panelBackgroundColor
        self.panelHighlightedBackgroundColor = panelHighlightedBackgroundColor
        self.panelPrimaryColor = panelPrimaryColor
        self.panelSecondaryColor = panelSecondaryColor
        self.panelAccentColor = panelAccentColor
        self.tableBorderColor = tableBorderColor
        self.tableHeaderColor = tableHeaderColor
        self.controlColor = controlColor
        self.imageTintColor = imageTintColor
        self.overlayPanelColor = overlayPanelColor
    }
    
    func withUpdatedFontStyles(sizeMultiplier: CGFloat, forceSerif: Bool) -> InstantPageTheme {
        return InstantPageTheme(type: type, pageBackgroundColor: pageBackgroundColor, textCategories: self.textCategories.withUpdatedFontStyles(sizeMultiplier: sizeMultiplier, forceSerif: forceSerif), serif: forceSerif, codeBlockBackgroundColor: codeBlockBackgroundColor, linkColor: linkColor, textHighlightColor: textHighlightColor, linkHighlightColor: linkHighlightColor, markerColor: markerColor, panelBackgroundColor: panelBackgroundColor, panelHighlightedBackgroundColor: panelHighlightedBackgroundColor, panelPrimaryColor: panelPrimaryColor, panelSecondaryColor: panelSecondaryColor, panelAccentColor: panelAccentColor, tableBorderColor: tableBorderColor, tableHeaderColor: tableHeaderColor, controlColor: controlColor, imageTintColor: imageTintColor, overlayPanelColor: overlayPanelColor)
    }
}

private let lightTheme = InstantPageTheme(
    type: .light,
    pageBackgroundColor: .white,
    textCategories: InstantPageTextCategories(
        kicker: InstantPageTextAttributes(font: InstantPageFont(style: .sans, size: 15.0, lineSpacingFactor: 0.685), color: .black),
        header: InstantPageTextAttributes(font: InstantPageFont(style: .serif, size: 24.0, lineSpacingFactor: 0.685), color: .black),
        subheader: InstantPageTextAttributes(font: InstantPageFont(style: .serif, size: 19.0, lineSpacingFactor: 0.685), color: .black),
        paragraph: InstantPageTextAttributes(font: InstantPageFont(style: .sans, size: 17.0, lineSpacingFactor: 1.0), color: .black),
        caption: InstantPageTextAttributes(font: InstantPageFont(style: .sans, size: 15.0, lineSpacingFactor: 1.0), color: UIColor(rgb: 0x79828b)),
        credit: InstantPageTextAttributes(font: InstantPageFont(style: .sans, size: 13.0, lineSpacingFactor: 1.0), color: UIColor(rgb: 0x79828b)),
        table: InstantPageTextAttributes(font: InstantPageFont(style: .sans, size: 15.0, lineSpacingFactor: 1.0), color: .black),
        article: InstantPageTextAttributes(font: InstantPageFont(style: .serif, size: 18.0, lineSpacingFactor: 1.0), color: .black)
    ),
    serif: false,
    codeBlockBackgroundColor: UIColor(rgb: 0xf5f8fc),
    linkColor: UIColor(rgb: 0x007aff),
    textHighlightColor: UIColor(rgb: 0, alpha: 0.12),
    linkHighlightColor: UIColor(rgb: 0x007aff, alpha: 0.07),
    markerColor: UIColor(rgb: 0xfef3bc),
    panelBackgroundColor: UIColor(rgb: 0xf3f4f5),
    panelHighlightedBackgroundColor: UIColor(rgb: 0xe7e7e7),
    panelPrimaryColor: .black,
    panelSecondaryColor: UIColor(rgb: 0x79828b),
    panelAccentColor: UIColor(rgb: 0x007aff),
    tableBorderColor: UIColor(rgb: 0xe2e2e2),
    tableHeaderColor: UIColor(rgb: 0xf4f4f4),
    controlColor: UIColor(rgb: 0xc7c7cd),
    imageTintColor: nil,
    overlayPanelColor: .white
)

private let sepiaTheme = InstantPageTheme(
    type: .sepia,
    pageBackgroundColor: UIColor(rgb: 0xf8f1e2),
    textCategories: InstantPageTextCategories(
        kicker: InstantPageTextAttributes(font: InstantPageFont(style: .sans, size: 15.0, lineSpacingFactor: 0.685), color: UIColor(rgb: 0x4f321d)),
        header: InstantPageTextAttributes(font: InstantPageFont(style: .serif, size: 24.0, lineSpacingFactor: 0.685), color: UIColor(rgb: 0x4f321d)),
        subheader: InstantPageTextAttributes(font: InstantPageFont(style: .serif, size: 19.0, lineSpacingFactor: 0.685), color: UIColor(rgb: 0x4f321d)),
        paragraph: InstantPageTextAttributes(font: InstantPageFont(style: .sans, size: 17.0, lineSpacingFactor: 1.0), color: UIColor(rgb: 0x4f321d)),
        caption: InstantPageTextAttributes(font: InstantPageFont(style: .sans, size: 15.0, lineSpacingFactor: 1.0), color: UIColor(rgb: 0x927e6b)),
        credit: InstantPageTextAttributes(font: InstantPageFont(style: .sans, size: 13.0, lineSpacingFactor: 1.0), color: UIColor(rgb: 0x927e6b)),
        table: InstantPageTextAttributes(font: InstantPageFont(style: .sans, size: 15.0, lineSpacingFactor: 1.0), color: UIColor(rgb: 0x4f321d)),
        article: InstantPageTextAttributes(font: InstantPageFont(style: .serif, size: 18.0, lineSpacingFactor: 1.0), color: UIColor(rgb: 0x4f321d))
    ),
    serif: false,
    codeBlockBackgroundColor: UIColor(rgb: 0xefe7d6),
    linkColor: UIColor(rgb: 0xd19600),
    textHighlightColor: UIColor(rgb: 0, alpha: 0.1),
    linkHighlightColor: UIColor(rgb: 0xd19600, alpha: 0.1),
    markerColor: UIColor(rgb: 0xe5ddcd),
    panelBackgroundColor: UIColor(rgb: 0xefe7d6),
    panelHighlightedBackgroundColor: UIColor(rgb: 0xe3dccb),
    panelPrimaryColor: .black,
    panelSecondaryColor: UIColor(rgb: 0x927e6b),
    panelAccentColor: UIColor(rgb: 0xd19601),
    tableBorderColor: UIColor(rgb: 0xddd1b8),
    tableHeaderColor: UIColor(rgb: 0xf0e7d4),
    controlColor: UIColor(rgb: 0xddd1b8),
    imageTintColor: nil,
    overlayPanelColor: UIColor(rgb: 0xf8f1e2)
)

private let grayTheme = InstantPageTheme(
    type: .gray,
    pageBackgroundColor: UIColor(rgb: 0x5a5a5c),
    textCategories: InstantPageTextCategories(
        kicker: InstantPageTextAttributes(font: InstantPageFont(style: .sans, size: 15.0, lineSpacingFactor: 0.685), color: UIColor(rgb: 0xcecece)),
        header: InstantPageTextAttributes(font: InstantPageFont(style: .serif, size: 24.0, lineSpacingFactor: 0.685), color: UIColor(rgb: 0xcecece)),
        subheader: InstantPageTextAttributes(font: InstantPageFont(style: .serif, size: 19.0, lineSpacingFactor: 0.685), color: UIColor(rgb: 0xcecece)),
        paragraph: InstantPageTextAttributes(font: InstantPageFont(style: .sans, size: 17.0, lineSpacingFactor: 1.0), color: UIColor(rgb: 0xcecece)),
        caption: InstantPageTextAttributes(font: InstantPageFont(style: .sans, size: 15.0, lineSpacingFactor: 1.0), color: UIColor(rgb: 0xa0a0a0)),
        credit: InstantPageTextAttributes(font: InstantPageFont(style: .sans, size: 13.0, lineSpacingFactor: 1.0), color: UIColor(rgb: 0xa0a0a0)),
        table: InstantPageTextAttributes(font: InstantPageFont(style: .sans, size: 15.0, lineSpacingFactor: 1.0), color: UIColor(rgb: 0xcecece)),
        article: InstantPageTextAttributes(font: InstantPageFont(style: .serif, size: 18.0, lineSpacingFactor: 1.0), color: UIColor(rgb: 0xcecece))
    ),
    serif: false,
    codeBlockBackgroundColor: UIColor(rgb: 0x555556),
    linkColor: UIColor(rgb: 0x5ac8fa),
    textHighlightColor: UIColor(rgb: 0, alpha: 0.16),
    linkHighlightColor: UIColor(rgb: 0x5ac8fa, alpha: 0.13),
    markerColor: UIColor(rgb: 0x4b4b4b),
    panelBackgroundColor: UIColor(rgb: 0x555556),
    panelHighlightedBackgroundColor: UIColor(rgb: 0x505051),
    panelPrimaryColor: UIColor(rgb: 0xcecece),
    panelSecondaryColor: UIColor(rgb: 0xa0a0a0),
    panelAccentColor: UIColor(rgb: 0x54b9f8),
    tableBorderColor: UIColor(rgb: 0x484848),
    tableHeaderColor: UIColor(rgb: 0x555556),
    controlColor: UIColor(rgb: 0x484848),
    imageTintColor: UIColor(rgb: 0xcecece),
    overlayPanelColor: UIColor(rgb: 0x5a5a5c)
)

private let darkTheme = InstantPageTheme(
    type: .dark,
    pageBackgroundColor: UIColor(rgb: 0x000000),
    textCategories: InstantPageTextCategories(
        kicker: InstantPageTextAttributes(font: InstantPageFont(style: .sans, size: 15.0, lineSpacingFactor: 0.685), color: UIColor(rgb: 0xb0b0b0)),
        header: InstantPageTextAttributes(font: InstantPageFont(style: .serif, size: 24.0, lineSpacingFactor: 0.685), color: UIColor(rgb: 0xb0b0b0)),
        subheader: InstantPageTextAttributes(font: InstantPageFont(style: .serif, size: 19.0, lineSpacingFactor: 0.685), color: UIColor(rgb: 0xb0b0b0)),
        paragraph: InstantPageTextAttributes(font: InstantPageFont(style: .sans, size: 17.0, lineSpacingFactor: 1.0), color: UIColor(rgb: 0xb0b0b0)),
        caption: InstantPageTextAttributes(font: InstantPageFont(style: .sans, size: 15.0, lineSpacingFactor: 1.0), color: UIColor(rgb: 0x6a6a6a)),
        credit: InstantPageTextAttributes(font: InstantPageFont(style: .sans, size: 13.0, lineSpacingFactor: 1.0), color: UIColor(rgb: 0x6a6a6a)),
        table: InstantPageTextAttributes(font: InstantPageFont(style: .sans, size: 15.0, lineSpacingFactor: 1.0), color: UIColor(rgb: 0xb0b0b0)),
        article: InstantPageTextAttributes(font: InstantPageFont(style: .serif, size: 18.0, lineSpacingFactor: 1.0), color: UIColor(rgb: 0xb0b0b0))
    ),
    serif: false,
    codeBlockBackgroundColor: UIColor(rgb: 0x131313),
    linkColor: UIColor(rgb: 0x5ac8fa),
    textHighlightColor: UIColor(rgb: 0xffffff, alpha: 0.1),
    linkHighlightColor: UIColor(rgb: 0x5ac8fa, alpha: 0.2),
    markerColor: UIColor(rgb: 0x313131),
    panelBackgroundColor: UIColor(rgb: 0x131313),
    panelHighlightedBackgroundColor: UIColor(rgb: 0x1f1f1f),
    panelPrimaryColor: UIColor(rgb: 0xb0b0b0),
    panelSecondaryColor: UIColor(rgb: 0x6a6a6a),
    panelAccentColor: UIColor(rgb: 0x50b6f3),
    tableBorderColor: UIColor(rgb: 0x303030),
    tableHeaderColor: UIColor(rgb: 0x131313),
    controlColor: UIColor(rgb: 0x303030),
    imageTintColor: UIColor(rgb: 0xb0b0b0),
    overlayPanelColor: UIColor(rgb: 0x232323)
)

private func fontSizeMultiplierForVariant(_ variant: InstantPagePresentationFontSize) -> CGFloat {
    switch variant {
        case .small:
            return 0.85
        case .standard:
            return 1.0
        case .large:
            return 1.15
        case .xlarge:
            return 1.3
        case .xxlarge:
            return 1.5
    }
}

func instantPageThemeTypeForSettingsAndTime(themeSettings: PresentationThemeSettings?, settings: InstantPagePresentationSettings, time: Date?, forceDarkTheme: Bool) -> (InstantPageThemeType, Bool) {
    if settings.autoNightMode {
        switch settings.themeType {
            case .light, .sepia, .gray:
                var useDarkTheme = false
                
                var fallback = true
                if let themeSettings = themeSettings {
                    if case .explicitNone = themeSettings.automaticThemeSwitchSetting.trigger {
                    } else {
                        fallback = false
                        useDarkTheme = forceDarkTheme
                    }
                }
                if fallback, let time = time {
                    let hour = Calendar.current.component(.hour, from: time)
                    if hour <= 8 || hour >= 22 {
                        useDarkTheme = true
                    }
                }
                if useDarkTheme {
                    return (.dark, true)
                }
            case .dark:
                break
        }
    }
    
    return (settings.themeType, false)
}

func instantPageThemeForType(_ type: InstantPageThemeType, settings: InstantPagePresentationSettings) -> InstantPageTheme {
    switch type {
        case .light:
            return lightTheme.withUpdatedFontStyles(sizeMultiplier: fontSizeMultiplierForVariant(settings.fontSize), forceSerif: settings.forceSerif)
        case .sepia:
            return sepiaTheme.withUpdatedFontStyles(sizeMultiplier: fontSizeMultiplierForVariant(settings.fontSize), forceSerif: settings.forceSerif)
        case .gray:
            return grayTheme.withUpdatedFontStyles(sizeMultiplier: fontSizeMultiplierForVariant(settings.fontSize), forceSerif: settings.forceSerif)
        case .dark:
            return darkTheme.withUpdatedFontStyles(sizeMultiplier: fontSizeMultiplierForVariant(settings.fontSize), forceSerif: settings.forceSerif)
    }
}

extension ActionSheetControllerTheme {
    convenience init(instantPageTheme: InstantPageTheme) {
        self.init(dimColor: UIColor(white: 0.0, alpha: 0.4), backgroundType: instantPageTheme.type != .dark ? .light : .dark, itemBackgroundColor: instantPageTheme.overlayPanelColor, itemHighlightedBackgroundColor: instantPageTheme.panelHighlightedBackgroundColor, standardActionTextColor: instantPageTheme.panelAccentColor, destructiveActionTextColor: instantPageTheme.panelAccentColor, disabledActionTextColor: instantPageTheme.panelAccentColor, primaryTextColor: instantPageTheme.textCategories.paragraph.color, secondaryTextColor: instantPageTheme.textCategories.caption.color, controlAccentColor: instantPageTheme.panelAccentColor, controlColor: instantPageTheme.tableBorderColor, switchFrameColor: .white, switchContentColor: .white, switchHandleColor: .white, baseFontSize: 17.0)
    }
}

extension ActionSheetController {
    convenience init(instantPageTheme: InstantPageTheme) {
        self.init(theme: ActionSheetControllerTheme(instantPageTheme: instantPageTheme), allowInputInset: false)
    }
}
