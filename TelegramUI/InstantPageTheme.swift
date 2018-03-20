import Foundation
import Postbox

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
    case header
    case subheader
    case paragraph
    case caption
}

struct InstantPageTextCategories {
    let header: InstantPageTextAttributes
    let subheader: InstantPageTextAttributes
    let paragraph: InstantPageTextAttributes
    let caption: InstantPageTextAttributes
    
    func attributes(type: InstantPageTextCategoryType, link: Bool) -> InstantPageTextAttributes {
        switch type {
            case .header:
                return self.header.withUnderline(link)
            case .subheader:
                return self.subheader.withUnderline(link)
            case .paragraph:
                return self.paragraph.withUnderline(link)
            case .caption:
                return self.caption.withUnderline(link)
        }
    }
    
    func withUpdatedFontStyles(sizeMultiplier: CGFloat, forceSerif: Bool) -> InstantPageTextCategories {
        return InstantPageTextCategories(header: self.header.withUpdatedFontStyles(sizeMultiplier: sizeMultiplier, forceSerif: forceSerif), subheader: self.subheader.withUpdatedFontStyles(sizeMultiplier: sizeMultiplier, forceSerif: forceSerif), paragraph: self.paragraph.withUpdatedFontStyles(sizeMultiplier: sizeMultiplier, forceSerif: forceSerif), caption: self.caption.withUpdatedFontStyles(sizeMultiplier: sizeMultiplier, forceSerif: forceSerif))
    }
}

final class InstantPageTheme {
    let pageBackgroundColor: UIColor
    
    let textCategories: InstantPageTextCategories
    
    let codeBlockBackgroundColor: UIColor
    
    let textHighlightColor: UIColor
    let linkHighlightColor: UIColor
    
    let panelBackgroundColor: UIColor
    let panelHighlightedBackgroundColor: UIColor
    let panelPrimaryColor: UIColor
    let panelSecondaryColor: UIColor
    let panelAccentColor: UIColor
    
    init(pageBackgroundColor: UIColor, textCategories: InstantPageTextCategories, codeBlockBackgroundColor: UIColor, textHighlightColor: UIColor, linkHighlightColor: UIColor, panelBackgroundColor: UIColor, panelHighlightedBackgroundColor: UIColor, panelPrimaryColor: UIColor, panelSecondaryColor: UIColor, panelAccentColor: UIColor) {
        self.pageBackgroundColor = pageBackgroundColor
        self.textCategories = textCategories
        self.codeBlockBackgroundColor = codeBlockBackgroundColor
        self.textHighlightColor = textHighlightColor
        self.linkHighlightColor = linkHighlightColor
        self.panelBackgroundColor = panelBackgroundColor
        self.panelHighlightedBackgroundColor = panelHighlightedBackgroundColor
        self.panelPrimaryColor = panelPrimaryColor
        self.panelSecondaryColor = panelSecondaryColor
        self.panelAccentColor = panelAccentColor
    }
    
    func withUpdatedFontStyles(sizeMultiplier: CGFloat, forceSerif: Bool) -> InstantPageTheme {
        return InstantPageTheme(pageBackgroundColor: pageBackgroundColor, textCategories: self.textCategories.withUpdatedFontStyles(sizeMultiplier: sizeMultiplier, forceSerif: forceSerif), codeBlockBackgroundColor: codeBlockBackgroundColor, textHighlightColor: textHighlightColor, linkHighlightColor: linkHighlightColor, panelBackgroundColor: panelBackgroundColor, panelHighlightedBackgroundColor: panelHighlightedBackgroundColor, panelPrimaryColor: panelPrimaryColor, panelSecondaryColor: panelSecondaryColor, panelAccentColor: panelAccentColor)
    }
}

private let lightTheme = InstantPageTheme(
    pageBackgroundColor: .white,
    textCategories: InstantPageTextCategories(
        header: InstantPageTextAttributes(font: InstantPageFont(style: .serif, size: 24.0, lineSpacingFactor: 0.685), color: .black),
        subheader: InstantPageTextAttributes(font: InstantPageFont(style: .serif, size: 19.0, lineSpacingFactor: 0.685), color: .black),
        paragraph: InstantPageTextAttributes(font: InstantPageFont(style: .sans, size: 17.0, lineSpacingFactor: 1.0), color: .black),
        caption: InstantPageTextAttributes(font: InstantPageFont(style: .sans, size: 17.0, lineSpacingFactor: 1.0), color: UIColor(rgb: 0x79828b))
    ),
    codeBlockBackgroundColor: UIColor(rgb: 0xf5f8fc),
    textHighlightColor: UIColor(rgb: 0, alpha: 0.12),
    linkHighlightColor: UIColor(rgb: 0, alpha: 0.12),
    panelBackgroundColor: UIColor(rgb: 0xf3f4f5),
    panelHighlightedBackgroundColor: UIColor(rgb: 0xe7e7e7),
    panelPrimaryColor: .black,
    panelSecondaryColor: UIColor(rgb: 0x79828b),
    panelAccentColor: UIColor(rgb: 0x007ee5)
)

private let sepiaTheme = InstantPageTheme(
    pageBackgroundColor: UIColor(rgb: 0xf8f1e2),
    textCategories: InstantPageTextCategories(
        header: InstantPageTextAttributes(font: InstantPageFont(style: .serif, size: 24.0, lineSpacingFactor: 0.685), color: UIColor(rgb: 0x4f321d)),
        subheader: InstantPageTextAttributes(font: InstantPageFont(style: .serif, size: 19.0, lineSpacingFactor: 0.685), color: UIColor(rgb: 0x4f321d)),
        paragraph: InstantPageTextAttributes(font: InstantPageFont(style: .sans, size: 17.0, lineSpacingFactor: 1.0), color: UIColor(rgb: 0x4f321d)),
        caption: InstantPageTextAttributes(font: InstantPageFont(style: .sans, size: 17.0, lineSpacingFactor: 1.0), color: UIColor(rgb: 0x927e6b))
    ),
    codeBlockBackgroundColor: UIColor(rgb: 0xefe7d6),
    textHighlightColor: UIColor(rgb: 0, alpha: 0.1),
    linkHighlightColor: UIColor(rgb: 0, alpha: 0.1),
    panelBackgroundColor: UIColor(rgb: 0xefe7d6),
    panelHighlightedBackgroundColor: UIColor(rgb: 0xe3dccb),
    panelPrimaryColor: .black,
    panelSecondaryColor: UIColor(rgb: 0x927e6b),
    panelAccentColor: UIColor(rgb: 0xd19601)
)

private let grayTheme = InstantPageTheme(
    pageBackgroundColor: UIColor(rgb: 0x5a5a5c),
    textCategories: InstantPageTextCategories(
        header: InstantPageTextAttributes(font: InstantPageFont(style: .serif, size: 24.0, lineSpacingFactor: 0.685), color: UIColor(rgb: 0xcecece)),
        subheader: InstantPageTextAttributes(font: InstantPageFont(style: .serif, size: 19.0, lineSpacingFactor: 0.685), color: UIColor(rgb: 0xcecece)),
        paragraph: InstantPageTextAttributes(font: InstantPageFont(style: .sans, size: 17.0, lineSpacingFactor: 1.0), color: UIColor(rgb: 0xcecece)),
        caption: InstantPageTextAttributes(font: InstantPageFont(style: .sans, size: 17.0, lineSpacingFactor: 1.0), color: UIColor(rgb: 0xa0a0a0))
    ),
    codeBlockBackgroundColor: UIColor(rgb: 0x555556),
    textHighlightColor: UIColor(rgb: 0, alpha: 0.16),
    linkHighlightColor: UIColor(rgb: 0, alpha: 0.16),
    panelBackgroundColor: UIColor(rgb: 0x555556),
    panelHighlightedBackgroundColor: UIColor(rgb: 0x505051),
    panelPrimaryColor: UIColor(rgb: 0xcecece),
    panelSecondaryColor: UIColor(rgb: 0xa0a0a0),
    panelAccentColor: UIColor(rgb: 0x54b9f8)
)

private let darkTheme = InstantPageTheme(
    pageBackgroundColor: UIColor(rgb: 0x000000),
    textCategories: InstantPageTextCategories(
        header: InstantPageTextAttributes(font: InstantPageFont(style: .serif, size: 24.0, lineSpacingFactor: 0.685), color: UIColor(rgb: 0xb0b0b0)),
        subheader: InstantPageTextAttributes(font: InstantPageFont(style: .serif, size: 19.0, lineSpacingFactor: 0.685), color: UIColor(rgb: 0xb0b0b0)),
        paragraph: InstantPageTextAttributes(font: InstantPageFont(style: .sans, size: 17.0, lineSpacingFactor: 1.0), color: UIColor(rgb: 0xb0b0b0)),
        caption: InstantPageTextAttributes(font: InstantPageFont(style: .sans, size: 17.0, lineSpacingFactor: 1.0), color: UIColor(rgb: 0x6a6a6a))
    ),
    codeBlockBackgroundColor: UIColor(rgb: 0x131313),
    textHighlightColor: UIColor(rgb: 0xffffff, alpha: 0.1),
    linkHighlightColor: UIColor(rgb: 0xffffff, alpha: 0.1),
    panelBackgroundColor: UIColor(rgb: 0x131313),
    panelHighlightedBackgroundColor: UIColor(rgb: 0x1f1f1f),
    panelPrimaryColor: UIColor(rgb: 0xb0b0b0),
    panelSecondaryColor: UIColor(rgb: 0x6a6a6a),
    panelAccentColor: UIColor(rgb: 0x50b6f3)
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

func instantPageThemeForSettingsAndTime(presentationTheme: PresentationTheme, settings: InstantPagePresentationSettings, time: Date) -> InstantPageTheme {
    if settings.autoNightMode {
        switch settings.themeType {
            case .light, .sepia, .gray:
                var useDarkTheme = false
                switch presentationTheme.name {
                    case let .builtin(name):
                        switch name {
                            case .nightAccent, .nightGrayscale:
                                useDarkTheme = true
                            default:
                                break
                        }
                    default:
                        break
                }
                let calendar = Calendar.current
                let hour = calendar.component(.hour, from: time)
                if hour <= 8 || hour >= 22 {
                    useDarkTheme = true
                }
                if useDarkTheme {
                    return darkTheme.withUpdatedFontStyles(sizeMultiplier: fontSizeMultiplierForVariant(settings.fontSize), forceSerif: settings.forceSerif)
                }
            case .dark:
                break
        }
    }
    
    switch settings.themeType {
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
