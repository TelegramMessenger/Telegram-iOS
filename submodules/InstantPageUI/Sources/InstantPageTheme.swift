import Foundation
import UIKit
import Display
import TelegramPresentationData
import TelegramUIPreferences
import UnsupportedContentPill

public enum InstantPageFontStyle {
    case sans
    case serif
    case monospace
}

public struct InstantPageFont {
    /// Deliberately narrow rather than a re-export of `Font.Weight`: every case here has a real
    /// resolution path. A weight enum whose cases are silently ignored type-checks, reads as
    /// working, and does nothing. Widen it only when a new weight actually gets resolved.
    ///
    /// `.medium` and `.semibold` both resolve serif runs to the system serif design (New York),
    /// which ships real Medium and Semibold faces — neither is a synthesised weight.
    public enum Weight {
        case regular
        case medium
        case semibold
    }

    let style: InstantPageFontStyle
    let size: CGFloat
    let lineSpacingFactor: CGFloat
    let weight: Weight

    public init(style: InstantPageFontStyle, size: CGFloat, lineSpacingFactor: CGFloat, weight: Weight = .regular) {
        self.style = style
        self.size = size
        self.lineSpacingFactor = lineSpacingFactor
        self.weight = weight
    }
}

public struct InstantPageTextAttributes {
    let font: InstantPageFont
    let color: UIColor
    let underline: Bool
    
    public init(font: InstantPageFont, color: UIColor, underline: Bool = false) {
        self.font = font
        self.color = color
        self.underline = underline
    }
    
    func withUnderline(_ underline: Bool) -> InstantPageTextAttributes {
        return InstantPageTextAttributes(font: self.font, color: self.color, underline: underline)
    }
    
    func withUpdatedFontStyles(sizeMultiplier: CGFloat, lineSpacingFactor: CGFloat, forceSerif: Bool) -> InstantPageTextAttributes {
        return InstantPageTextAttributes(font: InstantPageFont(style: forceSerif ? .serif : self.font.style, size: floor(self.font.size * sizeMultiplier), lineSpacingFactor: self.font.lineSpacingFactor * lineSpacingFactor, weight: self.font.weight), color: self.color, underline: self.underline)
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
    case codeBlock
}

public struct InstantPageTextCategories {
    let kicker: InstantPageTextAttributes
    let header: InstantPageTextAttributes
    let subheader: InstantPageTextAttributes
    let paragraph: InstantPageTextAttributes
    let caption: InstantPageTextAttributes
    let credit: InstantPageTextAttributes
    let table: InstantPageTextAttributes
    let article: InstantPageTextAttributes
    let codeBlock: InstantPageTextAttributes
    
    public init(kicker: InstantPageTextAttributes, header: InstantPageTextAttributes, subheader: InstantPageTextAttributes, paragraph: InstantPageTextAttributes, caption: InstantPageTextAttributes, credit: InstantPageTextAttributes, table: InstantPageTextAttributes, article: InstantPageTextAttributes, codeBlock: InstantPageTextAttributes) {
        self.kicker = kicker
        self.header = header
        self.subheader = subheader
        self.paragraph = paragraph
        self.caption = caption
        self.credit = credit
        self.table = table
        self.article = article
        self.codeBlock = codeBlock
    }
    
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
        case .codeBlock:
            return self.codeBlock.withUnderline(link)
        }
    }
    
    func withUpdatedFontStyles(sizeMultiplier: CGFloat, lineSpacingFactor: CGFloat, forceSerif: Bool) -> InstantPageTextCategories {
        return InstantPageTextCategories(
            kicker: self.kicker.withUpdatedFontStyles(sizeMultiplier: sizeMultiplier, lineSpacingFactor: lineSpacingFactor, forceSerif: forceSerif),
            header: self.header.withUpdatedFontStyles(sizeMultiplier: sizeMultiplier, lineSpacingFactor: lineSpacingFactor, forceSerif: forceSerif),
            subheader: self.subheader.withUpdatedFontStyles(sizeMultiplier: sizeMultiplier, lineSpacingFactor: lineSpacingFactor, forceSerif: forceSerif),
            paragraph: self.paragraph.withUpdatedFontStyles(sizeMultiplier: sizeMultiplier, lineSpacingFactor: lineSpacingFactor, forceSerif: forceSerif),
            caption: self.caption.withUpdatedFontStyles(sizeMultiplier: sizeMultiplier, lineSpacingFactor: lineSpacingFactor, forceSerif: forceSerif),
            credit: self.credit.withUpdatedFontStyles(sizeMultiplier: sizeMultiplier, lineSpacingFactor: lineSpacingFactor, forceSerif: forceSerif),
            table: self.table.withUpdatedFontStyles(sizeMultiplier: sizeMultiplier, lineSpacingFactor: lineSpacingFactor, forceSerif: forceSerif),
            article: self.article.withUpdatedFontStyles(sizeMultiplier: sizeMultiplier, lineSpacingFactor: lineSpacingFactor, forceSerif: forceSerif),
            codeBlock: self.codeBlock.withUpdatedFontStyles(sizeMultiplier: sizeMultiplier, lineSpacingFactor: lineSpacingFactor, forceSerif: forceSerif)
        )
    }
}

/// The nominal `subheader` size every `InstantPageTextCategories` declares.
///
/// The H1–H6 ladder in `InstantPageTheme.headingTextAttributes` is authored against a 22pt subheader
/// (H2 = 20 sits one step below it), and scales by the theme's `fontSizeMultiplier` — NOT by a ratio
/// recovered from the live subheader size, which is already floored and so drifts by a point at some
/// steps. Reference this at the category construction sites rather than repeating `22.0`, so a
/// subheader that moves off the ladder's baseline is a deliberate opt-out, not an accident.
public let instantPageNominalSubheaderFontSize: CGFloat = 22.0

public final class InstantPageTheme {
    public let type: InstantPageThemeType
    public let pageBackgroundColor: UIColor
    
    public let textCategories: InstantPageTextCategories
    public let serif: Bool
    /// The product of every `sizeMultiplier` applied to this theme's categories through
    /// `withUpdatedFontStyles` — exactly 1.0 for a theme built straight from its table. The heading
    /// ladder scales by THIS rather than by a ratio recovered from the already-floored subheader:
    /// at the chat `.large` step the recovered 24/22 (1.091) put H2 on 21 where floor(20 × 19/17) is 22.
    public let fontSizeMultiplier: CGFloat
    
    public let codeBlockBackgroundColor: UIColor
    
    public let linkColor: UIColor
    public let textHighlightColor: UIColor
    public let linkHighlightColor: UIColor
    public let markerColor: UIColor
    
    public let panelBackgroundColor: UIColor
    public let panelHighlightedBackgroundColor: UIColor
    public let panelPrimaryColor: UIColor
    public let panelSecondaryColor: UIColor
    public let panelAccentColor: UIColor
    
    public let tableBorderColor: UIColor
    public let tableHeaderColor: UIColor
    public let controlColor: UIColor
    public let imageTintColor: UIColor?
    public let overlayPanelColor: UIColor
    public let separatorColor: UIColor
    public let secondaryControlColor: UIColor
    public let quoteAccentColor: UIColor

    /// Pill fill and label for `richButtonStyle` bg_danger / bg_success on InstantPage buttons.
    /// `InstantPageTheme` has no destructive/success colour of its own; the chat bubble passes
    /// PresentationTheme-derived values, and the standalone Instant View themes fall back to these
    /// defaults (a 15% tint with a full-strength label). The pair is split because a tint only reads
    /// on a neutral page: over a saturated bubble (e.g. an outgoing Day Blue bubble) a translucent
    /// red fill mixes into the bubble colour and the red label loses contrast.
    public let buttonDangerBackgroundColor: UIColor
    public let buttonDangerForegroundColor: UIColor
    public let buttonSuccessBackgroundColor: UIColor
    public let buttonSuccessForegroundColor: UIColor

    /// Task-list checkbox colours (`InstantPageListItem` checkboxes): `checkboxFill` is the box fill
    /// when checked, `checkboxForeground` the checkmark drawn on it. Same arrangement as the button
    /// colours above — the chat bubble passes theme-derived values, standalone Instant View themes take
    /// these defaults.
    public let checkboxFill: UIColor
    public let checkboxForeground: UIColor

    /// The un-styled InstantPage button — a `pageButton` with no `richButtonStyle`, i.e. neither
    /// primary, danger nor success. Read by the **block-level** `pageBlockButtonRow` pill
    /// (`instantPageButtonColors(isInline: false)`), which previously borrowed `tableHeaderColor` /
    /// `panelPrimaryColor`. An inline neutral pill still takes `panelBackgroundColor` /
    /// `panelAccentColor` — the two are deliberately different, so changing these does not affect it.
    public let neutralButtonBackgroundColor: UIColor
    public let neutralButtonForegroundColor: UIColor

    /// Fill for the unsupported-content pill when the host supplies no wallpaper node, and the
    /// colour of its title, badge glyph and button label. Hosts inside a chat pass the
    /// service-message colours so the pill matches the standalone unsupported bubble.
    public let unsupportedPillFillColor: UIColor
    public let unsupportedPillPrimaryColor: UIColor

    /// The pill's colour pack. `isDark` is derived rather than stored — one source of truth.
    var unsupportedPillColors: UnsupportedContentPillColors {
        return UnsupportedContentPillColors(
            fill: self.unsupportedPillFillColor,
            primaryText: self.unsupportedPillPrimaryColor,
            isDark: self.type == .dark
        )
    }

    public init(type: InstantPageThemeType, pageBackgroundColor: UIColor, textCategories: InstantPageTextCategories, serif: Bool, codeBlockBackgroundColor: UIColor, linkColor: UIColor, textHighlightColor: UIColor, linkHighlightColor: UIColor, markerColor: UIColor, panelBackgroundColor: UIColor, panelHighlightedBackgroundColor: UIColor, panelPrimaryColor: UIColor, panelSecondaryColor: UIColor, panelAccentColor: UIColor, tableBorderColor: UIColor, tableHeaderColor: UIColor, controlColor: UIColor, imageTintColor: UIColor?, overlayPanelColor: UIColor, separatorColor: UIColor, secondaryControlColor: UIColor, quoteAccentColor: UIColor, buttonDangerBackgroundColor: UIColor = UIColor(rgb: 0xff3b30).withMultipliedAlpha(0.15), buttonDangerForegroundColor: UIColor = UIColor(rgb: 0xff3b30), buttonSuccessBackgroundColor: UIColor = UIColor(rgb: 0x34c759).withMultipliedAlpha(0.15), buttonSuccessForegroundColor: UIColor = UIColor(rgb: 0x34c759), checkboxFill: UIColor = UIColor(rgb: 0x007aff), checkboxForeground: UIColor = .white, neutralButtonBackgroundColor: UIColor = UIColor(rgb: 0xf3f4f5), neutralButtonForegroundColor: UIColor = .black, unsupportedPillFillColor: UIColor = UIColor(white: 0.0, alpha: 0.1), unsupportedPillPrimaryColor: UIColor = .white, fontSizeMultiplier: CGFloat = 1.0) {
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
        self.separatorColor = separatorColor
        self.secondaryControlColor = secondaryControlColor
        self.quoteAccentColor = quoteAccentColor
        self.buttonDangerBackgroundColor = buttonDangerBackgroundColor
        self.buttonDangerForegroundColor = buttonDangerForegroundColor
        self.buttonSuccessBackgroundColor = buttonSuccessBackgroundColor
        self.buttonSuccessForegroundColor = buttonSuccessForegroundColor
        self.checkboxFill = checkboxFill
        self.checkboxForeground = checkboxForeground
        self.neutralButtonBackgroundColor = neutralButtonBackgroundColor
        self.neutralButtonForegroundColor = neutralButtonForegroundColor
        self.unsupportedPillFillColor = unsupportedPillFillColor
        self.unsupportedPillPrimaryColor = unsupportedPillPrimaryColor
        self.fontSizeMultiplier = fontSizeMultiplier
    }

    public func withUpdatedFontStyles(sizeMultiplier: CGFloat, lineSpacingFactor: CGFloat, forceSerif: Bool) -> InstantPageTheme {
        // NOTE: this reconstructs the whole struct field by field. Any field omitted here silently
        // reverts to its `init` default — for the button danger/success colours that would reset a
        // chat bubble's theme-derived button colours the moment the user changes Instant View font
        // size or forces serif. Nothing warns; it compiles. Keep this list exhaustive.
        return InstantPageTheme(type: type, pageBackgroundColor: pageBackgroundColor, textCategories: self.textCategories.withUpdatedFontStyles(sizeMultiplier: sizeMultiplier, lineSpacingFactor: lineSpacingFactor, forceSerif: forceSerif), serif: forceSerif, codeBlockBackgroundColor: codeBlockBackgroundColor, linkColor: linkColor, textHighlightColor: textHighlightColor, linkHighlightColor: linkHighlightColor, markerColor: markerColor, panelBackgroundColor: panelBackgroundColor, panelHighlightedBackgroundColor: panelHighlightedBackgroundColor, panelPrimaryColor: panelPrimaryColor, panelSecondaryColor: panelSecondaryColor, panelAccentColor: panelAccentColor, tableBorderColor: tableBorderColor, tableHeaderColor: tableHeaderColor, controlColor: controlColor, imageTintColor: imageTintColor, overlayPanelColor: overlayPanelColor, separatorColor: separatorColor, secondaryControlColor: secondaryControlColor, quoteAccentColor: quoteAccentColor, buttonDangerBackgroundColor: buttonDangerBackgroundColor, buttonDangerForegroundColor: buttonDangerForegroundColor, buttonSuccessBackgroundColor: buttonSuccessBackgroundColor, buttonSuccessForegroundColor: buttonSuccessForegroundColor, checkboxFill: checkboxFill, checkboxForeground: checkboxForeground, neutralButtonBackgroundColor: neutralButtonBackgroundColor, neutralButtonForegroundColor: neutralButtonForegroundColor, unsupportedPillFillColor: unsupportedPillFillColor, unsupportedPillPrimaryColor: unsupportedPillPrimaryColor, fontSizeMultiplier: self.fontSizeMultiplier * sizeMultiplier)
    }

    /// The H1–H6 ladder: **22 / 20 / 18 / 17 / 16 / 15**, serif medium.
    ///
    /// Every level carries its own base size here. H1 and H2 deliberately do NOT reuse the `header` /
    /// `subheader` categories — those stay at 24 / 22 for what they actually style: the page title and
    /// subtitle, and the `pageBlockHeader` / `pageBlockSubheader` blocks. A heading is a different
    /// thing from a page header, and while the two shared a size, resizing the heading ladder also
    /// resized the title. Colour, line spacing and underline still come from `subheader`, so a heading
    /// keeps the theme's big-text look and only its size is its own.
    ///
    /// `fontSizeMultiplier` is exactly 1.0 in the default case, so the base sizes below ARE the rendered
    /// default sizes; it departs from 1.0 only when the reader's font-size slider or the chat's Text Size
    /// has scaled the categories, and then the whole ladder scales proportionally — by the multiplier
    /// that was applied, floored once, so it agrees with `withUpdatedFontStyles` at every step.
    func headingTextAttributes(level: Int32, link: Bool) -> InstantPageTextAttributes {
        let clampedLevel = max(Int32(1), min(level, Int32(6)))

        let subheaderAttributes = self.textCategories.subheader
        let baseSize: CGFloat
        switch clampedLevel {
        case 1:
            baseSize = 22.0
        case 2:
            baseSize = 20.0
        case 3:
            baseSize = 18.0
        case 4:
            baseSize = 17.0
        case 5:
            baseSize = 16.0
        default:
            baseSize = 15.0
        }

        let sizeMultiplier = self.fontSizeMultiplier
        let attributes = InstantPageTextAttributes(
            font: InstantPageFont(style: .serif, size: floor(baseSize * sizeMultiplier), lineSpacingFactor: subheaderAttributes.font.lineSpacingFactor, weight: .medium),
            color: subheaderAttributes.color,
            underline: subheaderAttributes.underline
        )
        return attributes.withUnderline(link)
    }
}

private let lightTheme = InstantPageTheme(
    type: .light,
    pageBackgroundColor: .white,
    textCategories: InstantPageTextCategories(
        kicker: InstantPageTextAttributes(font: InstantPageFont(style: .sans, size: 15.0, lineSpacingFactor: 0.685), color: .black),
        header: InstantPageTextAttributes(font: InstantPageFont(style: .serif, size: 24.0, lineSpacingFactor: 0.685, weight: .medium), color: .black),
        subheader: InstantPageTextAttributes(font: InstantPageFont(style: .serif, size: instantPageNominalSubheaderFontSize, lineSpacingFactor: 0.685, weight: .medium), color: .black),
        paragraph: InstantPageTextAttributes(font: InstantPageFont(style: .sans, size: 17.0, lineSpacingFactor: 1.0), color: .black),
        caption: InstantPageTextAttributes(font: InstantPageFont(style: .sans, size: 15.0, lineSpacingFactor: 1.0), color: UIColor(rgb: 0x79828b)),
        credit: InstantPageTextAttributes(font: InstantPageFont(style: .sans, size: 13.0, lineSpacingFactor: 1.0), color: UIColor(rgb: 0x79828b)),
        table: InstantPageTextAttributes(font: InstantPageFont(style: .sans, size: 15.0, lineSpacingFactor: 1.0), color: .black),
        article: InstantPageTextAttributes(font: InstantPageFont(style: .serif, size: 18.0, lineSpacingFactor: 1.0), color: .black),
        codeBlock: InstantPageTextAttributes(font: InstantPageFont(style: .monospace, size: 14.0, lineSpacingFactor: 1.0), color: .black)
    ),
    serif: false,
    codeBlockBackgroundColor: UIColor(rgb: 0xf5f8fc),
    linkColor: UIColor(rgb: 0x0088ff),
    textHighlightColor: UIColor(rgb: 0, alpha: 0.12),
    linkHighlightColor: UIColor(rgb: 0x0088ff, alpha: 0.07),
    markerColor: UIColor(rgb: 0xfef3bc),
    panelBackgroundColor: UIColor(rgb: 0xf3f4f5),
    panelHighlightedBackgroundColor: UIColor(rgb: 0xe7e7e7),
    panelPrimaryColor: .black,
    panelSecondaryColor: UIColor(rgb: 0x79828b),
    panelAccentColor: UIColor(rgb: 0x0088ff),
    tableBorderColor: UIColor(rgb: 0xe2e2e2),
    tableHeaderColor: UIColor(rgb: 0xf4f4f4),
    controlColor: UIColor(rgb: 0xc7c7cd),
    imageTintColor: nil,
    overlayPanelColor: .white,
    separatorColor: UIColor(rgb: 0xe2e2e2),
    secondaryControlColor: .black,
    quoteAccentColor: .black,
    neutralButtonBackgroundColor: UIColor(rgb: 0xf3f4f5),
    neutralButtonForegroundColor: .black
)

private let sepiaTheme = InstantPageTheme(
    type: .sepia,
    pageBackgroundColor: UIColor(rgb: 0xf8f1e2),
    textCategories: InstantPageTextCategories(
        kicker: InstantPageTextAttributes(font: InstantPageFont(style: .sans, size: 15.0, lineSpacingFactor: 0.685), color: UIColor(rgb: 0x4f321d)),
        header: InstantPageTextAttributes(font: InstantPageFont(style: .serif, size: 24.0, lineSpacingFactor: 0.685, weight: .medium), color: UIColor(rgb: 0x4f321d)),
        subheader: InstantPageTextAttributes(font: InstantPageFont(style: .serif, size: instantPageNominalSubheaderFontSize, lineSpacingFactor: 0.685, weight: .medium), color: UIColor(rgb: 0x4f321d)),
        paragraph: InstantPageTextAttributes(font: InstantPageFont(style: .sans, size: 17.0, lineSpacingFactor: 1.0), color: UIColor(rgb: 0x4f321d)),
        caption: InstantPageTextAttributes(font: InstantPageFont(style: .sans, size: 15.0, lineSpacingFactor: 1.0), color: UIColor(rgb: 0x927e6b)),
        credit: InstantPageTextAttributes(font: InstantPageFont(style: .sans, size: 13.0, lineSpacingFactor: 1.0), color: UIColor(rgb: 0x927e6b)),
        table: InstantPageTextAttributes(font: InstantPageFont(style: .sans, size: 15.0, lineSpacingFactor: 1.0), color: UIColor(rgb: 0x4f321d)),
        article: InstantPageTextAttributes(font: InstantPageFont(style: .serif, size: 18.0, lineSpacingFactor: 1.0), color: UIColor(rgb: 0x4f321d)),
        codeBlock: InstantPageTextAttributes(font: InstantPageFont(style: .monospace, size: 14.0, lineSpacingFactor: 1.0), color: UIColor(rgb: 0x4f321d))
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
    overlayPanelColor: UIColor(rgb: 0xf8f1e2),
    separatorColor: UIColor(rgb: 0xe2e2e2),
    secondaryControlColor: .black,
    quoteAccentColor: UIColor(rgb: 0x4f321d),
    neutralButtonBackgroundColor: UIColor(rgb: 0xefe7d6),
    neutralButtonForegroundColor: UIColor(rgb: 0x4f321d)
)

private let grayTheme = InstantPageTheme(
    type: .gray,
    pageBackgroundColor: UIColor(rgb: 0x5a5a5c),
    textCategories: InstantPageTextCategories(
        kicker: InstantPageTextAttributes(font: InstantPageFont(style: .sans, size: 15.0, lineSpacingFactor: 0.685), color: UIColor(rgb: 0xcecece)),
        header: InstantPageTextAttributes(font: InstantPageFont(style: .serif, size: 24.0, lineSpacingFactor: 0.685, weight: .medium), color: UIColor(rgb: 0xcecece)),
        subheader: InstantPageTextAttributes(font: InstantPageFont(style: .serif, size: instantPageNominalSubheaderFontSize, lineSpacingFactor: 0.685, weight: .medium), color: UIColor(rgb: 0xcecece)),
        paragraph: InstantPageTextAttributes(font: InstantPageFont(style: .sans, size: 17.0, lineSpacingFactor: 1.0), color: UIColor(rgb: 0xcecece)),
        caption: InstantPageTextAttributes(font: InstantPageFont(style: .sans, size: 15.0, lineSpacingFactor: 1.0), color: UIColor(rgb: 0xa0a0a0)),
        credit: InstantPageTextAttributes(font: InstantPageFont(style: .sans, size: 13.0, lineSpacingFactor: 1.0), color: UIColor(rgb: 0xa0a0a0)),
        table: InstantPageTextAttributes(font: InstantPageFont(style: .sans, size: 15.0, lineSpacingFactor: 1.0), color: UIColor(rgb: 0xcecece)),
        article: InstantPageTextAttributes(font: InstantPageFont(style: .serif, size: 18.0, lineSpacingFactor: 1.0), color: UIColor(rgb: 0xcecece)),
        codeBlock: InstantPageTextAttributes(font: InstantPageFont(style: .monospace, size: 14.0, lineSpacingFactor: 1.0), color: UIColor(rgb: 0xcecece))
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
    overlayPanelColor: UIColor(rgb: 0x5a5a5c),
    separatorColor: UIColor(rgb: 0x484848),
    secondaryControlColor: .black,
    quoteAccentColor: UIColor(rgb: 0xcecece),
    neutralButtonBackgroundColor: UIColor(rgb: 0x555556),
    neutralButtonForegroundColor: UIColor(rgb: 0xcecece)
)

private let darkTheme = InstantPageTheme(
    type: .dark,
    pageBackgroundColor: UIColor(rgb: 0x000000),
    textCategories: InstantPageTextCategories(
        kicker: InstantPageTextAttributes(font: InstantPageFont(style: .sans, size: 15.0, lineSpacingFactor: 0.685), color: UIColor(rgb: 0xb0b0b0)),
        header: InstantPageTextAttributes(font: InstantPageFont(style: .serif, size: 24.0, lineSpacingFactor: 0.685, weight: .medium), color: UIColor(rgb: 0xb0b0b0)),
        subheader: InstantPageTextAttributes(font: InstantPageFont(style: .serif, size: instantPageNominalSubheaderFontSize, lineSpacingFactor: 0.685, weight: .medium), color: UIColor(rgb: 0xb0b0b0)),
        paragraph: InstantPageTextAttributes(font: InstantPageFont(style: .sans, size: 17.0, lineSpacingFactor: 1.0), color: UIColor(rgb: 0xb0b0b0)),
        caption: InstantPageTextAttributes(font: InstantPageFont(style: .sans, size: 15.0, lineSpacingFactor: 1.0), color: UIColor(rgb: 0x6a6a6a)),
        credit: InstantPageTextAttributes(font: InstantPageFont(style: .sans, size: 13.0, lineSpacingFactor: 1.0), color: UIColor(rgb: 0x6a6a6a)),
        table: InstantPageTextAttributes(font: InstantPageFont(style: .sans, size: 15.0, lineSpacingFactor: 1.0), color: UIColor(rgb: 0xb0b0b0)),
        article: InstantPageTextAttributes(font: InstantPageFont(style: .serif, size: 18.0, lineSpacingFactor: 1.0), color: UIColor(rgb: 0xb0b0b0)),
        codeBlock: InstantPageTextAttributes(font: InstantPageFont(style: .monospace, size: 14.0, lineSpacingFactor: 1.0), color: UIColor(rgb: 0xb0b0b0))
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
    overlayPanelColor: UIColor(rgb: 0x232323),
    separatorColor: UIColor(rgb: 0x303030),
    secondaryControlColor: UIColor(rgb: 0xb0b0b0),
    quoteAccentColor: UIColor(rgb: 0xb0b0b0),
    neutralButtonBackgroundColor: UIColor(rgb: 0x131313),
    neutralButtonForegroundColor: UIColor(rgb: 0xb0b0b0)
)

private func fontSizeMultiplierForVariant(_ variant: InstantPagePresentationFontSize) -> CGFloat {
    switch variant {
        case .xxsmall:
            return 0.5
        case .xsmall:
            return 0.75
        case .small:
            return 0.85
        case .standard:
            return 1.0
        case .large:
            return 1.15
        case .xlarge:
            return 1.25
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

public func instantPageThemeForType(_ type: InstantPageThemeType, settings: InstantPagePresentationSettings) -> InstantPageTheme {
    switch type {
    case .light:
        return lightTheme.withUpdatedFontStyles(sizeMultiplier: fontSizeMultiplierForVariant(settings.fontSize), lineSpacingFactor: settings.lineSpacingFactor, forceSerif: settings.forceSerif)
    case .sepia:
        return sepiaTheme.withUpdatedFontStyles(sizeMultiplier: fontSizeMultiplierForVariant(settings.fontSize), lineSpacingFactor: settings.lineSpacingFactor, forceSerif: settings.forceSerif)
    case .gray:
        return grayTheme.withUpdatedFontStyles(sizeMultiplier: fontSizeMultiplierForVariant(settings.fontSize), lineSpacingFactor: settings.lineSpacingFactor, forceSerif: settings.forceSerif)
    case .dark:
        return darkTheme.withUpdatedFontStyles(sizeMultiplier: fontSizeMultiplierForVariant(settings.fontSize), lineSpacingFactor: settings.lineSpacingFactor, forceSerif: settings.forceSerif)
    }
}

extension ActionSheetControllerTheme {
    convenience init(instantPageTheme: InstantPageTheme) {
        self.init(dimColor: UIColor(white: 0.0, alpha: 0.4), backgroundType: instantPageTheme.type != .dark ? .light : .dark, itemBackgroundColor: instantPageTheme.overlayPanelColor, itemHighlightedBackgroundColor: instantPageTheme.panelHighlightedBackgroundColor, standardActionTextColor: instantPageTheme.panelAccentColor, destructiveActionTextColor: instantPageTheme.panelAccentColor, disabledActionTextColor: instantPageTheme.panelAccentColor, primaryTextColor: instantPageTheme.textCategories.paragraph.color, secondaryTextColor: instantPageTheme.textCategories.caption.color, controlAccentColor: instantPageTheme.panelAccentColor, controlColor: instantPageTheme.tableBorderColor, switchFrameColor: .white, switchContentColor: .white, switchHandleColor: .white, baseFontSize: 17.0)
    }
}

public extension ActionSheetController {
    convenience init(instantPageTheme: InstantPageTheme) {
        self.init(theme: ActionSheetControllerTheme(instantPageTheme: instantPageTheme), allowInputInset: false)
    }
}
