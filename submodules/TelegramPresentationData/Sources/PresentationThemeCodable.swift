import Foundation
import UIKit
import Postbox
import TelegramCore
import TelegramUIPreferences

private func decodeColor<Key>(_ values: KeyedDecodingContainer<Key>, _ key: Key, decoder: Decoder? = nil, fallbackKey: String? = nil) throws -> UIColor {
    if let decoder = decoder as? PresentationThemeDecoding, let fallbackKey = fallbackKey {
        var codingPath = decoder.codingPath.map { $0.stringValue }
        codingPath.append(key.stringValue)
        
        let key = codingPath.joined(separator: ".")
        decoder.fallbackKeys[key] = fallbackKey
    }
    
    let value = try values.decode(String.self, forKey: key)
    if value.lowercased() == "clear" {
        return UIColor.clear
    } else if let color = UIColor(hexString: value) {
        return color
    } else {
        throw PresentationThemeDecodingError.generic
    }
}

private func encodeColor<Key>(_ values: inout KeyedEncodingContainer<Key>, _ value: UIColor, _ key: Key) throws {
    if value == UIColor.clear {
        try values.encode("clear", forKey: key)
    } else if value.alpha < 1.0 {
        try values.encode(String(format: "%08x", value.argb), forKey: key)
    } else {
        try values.encode(String(format: "%06x", value.rgb), forKey: key)
    }
}

private func decodeColorList<Key>(_ values: KeyedDecodingContainer<Key>, _ key: Key) throws -> [UIColor] {
    let colorValues = try values.decode([String].self, forKey: key)

    var result: [UIColor] = []
    for value in colorValues {
        if value.lowercased() == "clear" {
            result.append(UIColor.clear)
        } else if let color = UIColor(hexString: value) {
            result.append(color)
        } else {
            throw PresentationThemeDecodingError.generic
        }
    }

    return result
}

private func encodeColorList<Key>(_ values: inout KeyedEncodingContainer<Key>, _ colors: [UIColor], _ key: Key) throws {
    var stringList: [String] = []
    for value in colors {
        if value == UIColor.clear {
            stringList.append("clear")
        } else if value.alpha < 1.0 {
            stringList.append(String(format: "%08x", value.argb))
        } else {
            stringList.append(String(format: "%06x", value.rgb))
        }
    }
    try values.encode(stringList, forKey: key)
}

struct TelegramWallpaperStandardizedCodable: Codable {
    let value: TelegramWallpaper

    init(_ value: TelegramWallpaper) {
        self.value = value
    }

    init(from decoder: Decoder) throws {
        let values = try decoder.singleValueContainer()
        if let value = try? values.decode(String.self) {
            switch value.lowercased() {
                case "builtin":
                    self.value = .builtin(WallpaperSettings())
                default:
                    let optionKeys = ["motion", "blur"]
                    
                    if [6, 8].contains(value.count), let color = UIColor(hexString: value) {
                        self.value = .color(color.argb)
                    } else {
                        let components = value.components(separatedBy: " ")
                        var blur = false
                        var motion = false
                        if components.contains("motion") {
                            motion = true
                        }
                        if components.contains("blur") {
                            blur = true
                        }
                        
                        var slug: String?
                        var colors: [UIColor] = []
                        var intensity: Int32?
                        var rotation: Int32?
                        for i in 0 ..< components.count {
                            let component = components[i]
                            if optionKeys.contains(component) {
                                continue
                            }
                            
                            if i == 0 && component.count > 8 {
                                slug = component
                            } else if [6, 8].contains(component.count), let color = UIColor(hexString: component) {
                                colors.append(color)
                            } else if component.count <= 4, let value = Int32(component) {
                                if intensity == nil {
                                    if value >= -100 && value <= 100 {
                                        intensity = value
                                    } else {
                                        intensity = 50
                                    }
                                } else if rotation == nil {
                                    if value >= 0 && value < 360 {
                                        rotation = value
                                    }
                                }
                            }
                        }
                        
                        if let slug = slug {
                            self.value = .file(TelegramWallpaper.File(id: 0, accessHash: 0, isCreator: false, isDefault: false, isPattern: !colors.isEmpty, isDark: false, slug: slug, file: TelegramMediaFile(fileId: MediaId(namespace: 0, id: 0), partialReference: nil, resource: WallpaperDataResource(slug: slug), previewRepresentations: [], videoThumbnails: [], immediateThumbnailData: nil, mimeType: "", size: nil, attributes: []), settings: WallpaperSettings(blur: blur, motion: motion, colors: colors.map { $0.argb }, intensity: intensity, rotation: rotation)))
                        } else if colors.count > 1 {
                            self.value = .gradient(TelegramWallpaper.Gradient(id: nil, colors: colors.map { $0.argb }, settings: WallpaperSettings(blur: blur, motion: motion, rotation: rotation)))
                        } else {
                            throw PresentationThemeDecodingError.generic
                        }
                    }
            }
        } else {
            throw PresentationThemeDecodingError.generic
        }
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self.value {
            case .builtin:
                try container.encode("builtin")
            case let .color(color):
                try container.encode(String(format: "%06x", color))
            case let .gradient(gradient):
                var components: [String] = []
                for color in gradient.colors {
                    components.append(String(format: "%06x", color))
                }
                if let rotation = gradient.settings.rotation {
                    components.append("\(rotation)")
                }
                if gradient.settings.motion {
                    components.append("motion")
                }
                if gradient.settings.blur {
                    components.append("blur")
                }
                try container.encode(components.joined(separator: " "))
            case let .file(file):
                var components: [String] = []
                components.append(file.slug)
                if self.value.isPattern {
                    if file.settings.colors.count >= 1 {
                        components.append(String(format: "%06x", file.settings.colors[0]))
                    }
                    if let intensity = file.settings.intensity {
                        components.append("\(intensity)")
                    }
                    if file.settings.colors.count >= 2 {
                        components.append(String(format: "%06x", file.settings.colors[1]))
                    }
                    if file.settings.colors.count >= 3 {
                        components.append(String(format: "%06x", file.settings.colors[2]))
                    }
                    if file.settings.colors.count >= 4 {
                        components.append(String(format: "%06x", file.settings.colors[3]))
                    }
                    if let rotation = file.settings.rotation, rotation != 0 {
                        components.append("\(rotation)")
                    }
                }
                if file.settings.motion {
                    components.append("motion")
                }
                if file.settings.blur {
                    components.append("blur")
                }
                try container.encode(components.joined(separator: " "))
            default:
                break
        }
    }
}

extension PresentationThemeStatusBarStyle: Codable {
    public init(from decoder: Decoder) throws {
        let values = try decoder.singleValueContainer()
        if let value = try? values.decode(String.self) {
            switch value.lowercased() {
                case "black":
                    self = .black
                case "white":
                    self = .white
                default:
                    self = .black
            }
        } else {
            self = .black
        }
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
            case .black:
                try container.encode("black")
            case .white:
                try container.encode("white")
        }
    }
}

extension PresentationThemeActionSheetBackgroundType: Codable {
    public init(from decoder: Decoder) throws {
        let values = try decoder.singleValueContainer()
        if let value = try? values.decode(String.self) {
            switch value.lowercased() {
                case "light":
                    self = .light
                case "dark":
                    self = .dark
                default:
                    self = .light
            }
        } else {
            self = .light
        }
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
            case .light:
                try container.encode("light")
            case .dark:
                try container.encode("dark")
        }
    }
}

extension PresentationThemeKeyboardColor: Codable {
    public init(from decoder: Decoder) throws {
        let values = try decoder.singleValueContainer()
        if let value = try? values.decode(String.self) {
            switch value.lowercased() {
                case "light":
                    self = .light
                case "dark":
                    self = .dark
                default:
                    self = .light
            }
        } else {
            self = .light
        }
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
            switch self {
                case .light:
                    try container.encode("light")
                case .dark:
                    try container.encode("dark")
        }
    }
}

extension PresentationThemeExpandedNotificationBackgroundType: Codable {
    public init(from decoder: Decoder) throws {
        let values = try decoder.singleValueContainer()
        if let value = try? values.decode(String.self) {
            switch value.lowercased() {
                case "light":
                    self = .light
                case "dark":
                    self = .dark
                default:
                    self = .light
            }
        } else {
            self = .light
        }
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
            case .light:
                try container.encode("light")
            case .dark:
                try container.encode("dark")
        }
    }
}

extension PresentationThemeGradientColors: Codable {
    enum CodingKeys: String, CodingKey {
        case top
        case bottom
    }
    
    public convenience init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        self.init(topColor: try decodeColor(values, .top),
                  bottomColor: try decodeColor(values, .bottom))
    }
    
    public func encode(to encoder: Encoder) throws {
        var values = encoder.container(keyedBy: CodingKeys.self)
        try encodeColor(&values, self.topColor, .top)
        try encodeColor(&values, self.bottomColor, .bottom)
    }
}

extension PresentationThemeIntro: Codable {
    enum CodingKeys: String, CodingKey {
        case statusBar
        case primaryText
        case accentText
        case disabledText
        case startButton
        case dot
    }
    
    public convenience init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        self.init(statusBarStyle: try values.decode(PresentationThemeStatusBarStyle.self, forKey: .statusBar),
                  primaryTextColor: try decodeColor(values, .primaryText),
                  accentTextColor: try decodeColor(values, .accentText),
                  disabledTextColor: try decodeColor(values, .disabledText),
                  startButtonColor: try decodeColor(values, .startButton),
                  dotColor: try decodeColor(values, .dot))
    }
    
    public func encode(to encoder: Encoder) throws {
        var values = encoder.container(keyedBy: CodingKeys.self)
        try values.encode(self.statusBarStyle, forKey: .statusBar)
        try encodeColor(&values, self.primaryTextColor, .primaryText)
        try encodeColor(&values, self.accentTextColor, .accentText)
        try encodeColor(&values, self.disabledTextColor, .disabledText)
        try encodeColor(&values, self.startButtonColor, .startButton)
        try encodeColor(&values, self.dotColor, .dot)
    }
}

extension PresentationThemePasscode: Codable {
    enum CodingKeys: String, CodingKey {
        case bg
        case button
    }
    
    public convenience init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        self.init(backgroundColors: try values.decode(PresentationThemeGradientColors.self, forKey: .bg),
                  buttonColor: try decodeColor(values, .button))
    }
    
    public func encode(to encoder: Encoder) throws {
        var values = encoder.container(keyedBy: CodingKeys.self)
        try values.encode(self.backgroundColors, forKey: .bg)
        try encodeColor(&values, self.buttonColor, .button)
    }
}

extension PresentationThemeRootTabBar: Codable {
    enum CodingKeys: String, CodingKey {
        case background
        case separator
        case icon
        case selectedIcon
        case text
        case selectedText
        case badgeBackground
        case badgeStroke
        case badgeText
    }
    
    public convenience init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        self.init(backgroundColor: try decodeColor(values, .background),
                  separatorColor: try decodeColor(values, .separator),
                  iconColor: try decodeColor(values, .icon),
                  selectedIconColor: try decodeColor(values, .selectedIcon),
                  textColor: try decodeColor(values, .text),
                  selectedTextColor: try decodeColor(values, .selectedText),
                  badgeBackgroundColor: try decodeColor(values, .badgeBackground),
                  badgeStrokeColor: try decodeColor(values, .badgeStroke),
                  badgeTextColor: try decodeColor(values, .badgeText))
    }
    
    public func encode(to encoder: Encoder) throws {
        var values = encoder.container(keyedBy: CodingKeys.self)
        try encodeColor(&values, self.backgroundColor, .background)
        try encodeColor(&values, self.separatorColor, .separator)
        try encodeColor(&values, self.iconColor, .icon)
        try encodeColor(&values, self.selectedIconColor, .selectedIcon)
        try encodeColor(&values, self.textColor, .text)
        try encodeColor(&values, self.selectedTextColor, .selectedText)
        try encodeColor(&values, self.badgeBackgroundColor, .badgeBackground)
        try encodeColor(&values, self.badgeStrokeColor, .badgeStroke)
        try encodeColor(&values, self.badgeTextColor, .badgeText)
    }
}

extension PresentationThemeRootNavigationBar: Codable {
    enum CodingKeys: String, CodingKey {
        case button
        case disabledButton
        case primaryText
        case secondaryText
        case control
        case accentText
        case background
        case separator
        case badgeFill
        case badgeStroke
        case badgeText
        case segmentedBg
        case segmentedFg
        case segmentedText
        case segmentedDivider
        case clearButtonBackground
        case clearButtonForeground
        case opaqueBackground
    }
    
    public convenience init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        let blurredBackgroundColor = try decodeColor(values, .background)

        let opaqueBackgroundColor: UIColor
        if blurredBackgroundColor.alpha >= 0.99 {
            opaqueBackgroundColor = blurredBackgroundColor
        } else {
            opaqueBackgroundColor = (try? decodeColor(values, .opaqueBackground)) ?? blurredBackgroundColor
        }

        self.init(
            buttonColor: try decodeColor(values, .button),
            disabledButtonColor: try decodeColor(values, .disabledButton),
            primaryTextColor: try decodeColor(values, .primaryText),
            secondaryTextColor: try decodeColor(values, .secondaryText),
            controlColor: try decodeColor(values, .control),
            accentTextColor: try decodeColor(values, .accentText),
            blurredBackgroundColor: blurredBackgroundColor,
            opaqueBackgroundColor: opaqueBackgroundColor,
            separatorColor: try decodeColor(values, .separator),
            badgeBackgroundColor: try decodeColor(values, .badgeFill),
            badgeStrokeColor: try decodeColor(values, .badgeStroke),
            badgeTextColor: try decodeColor(values, .badgeText),
            segmentedBackgroundColor: try decodeColor(values, .segmentedBg, decoder: decoder, fallbackKey: "root.searchBar.inputFill"),
            segmentedForegroundColor: try decodeColor(values, .segmentedFg, decoder: decoder, fallbackKey: "root.navBar.background"),
            segmentedTextColor: try decodeColor(values, .segmentedText, decoder: decoder, fallbackKey: "root.navBar.primaryText"),
            segmentedDividerColor: try decodeColor(values, .segmentedDivider, decoder: decoder, fallbackKey: "list.freeInputField.stroke"),
            clearButtonBackgroundColor: try decodeColor(values, .clearButtonBackground, decoder: decoder, fallbackKey: "list.freeInputField.bg"),
            clearButtonForegroundColor: try decodeColor(values, .clearButtonForeground, decoder: decoder, fallbackKey: "list.freeInputField.primary")
        )
    }
    
    public func encode(to encoder: Encoder) throws {
        var values = encoder.container(keyedBy: CodingKeys.self)
        try encodeColor(&values, self.buttonColor, .button)
        try encodeColor(&values, self.disabledButtonColor, .disabledButton)
        try encodeColor(&values, self.primaryTextColor, .primaryText)
        try encodeColor(&values, self.secondaryTextColor, .secondaryText)
        try encodeColor(&values, self.controlColor, .control)
        try encodeColor(&values, self.accentTextColor, .accentText)
        try encodeColor(&values, self.blurredBackgroundColor, .background)
        try encodeColor(&values, self.opaqueBackgroundColor, .opaqueBackground)
        try encodeColor(&values, self.separatorColor, .separator)
        try encodeColor(&values, self.badgeBackgroundColor, .badgeFill)
        try encodeColor(&values, self.badgeStrokeColor, .badgeStroke)
        try encodeColor(&values, self.badgeTextColor, .badgeText)
        try encodeColor(&values, self.segmentedBackgroundColor, .segmentedBg)
        try encodeColor(&values, self.segmentedForegroundColor, .segmentedFg)
        try encodeColor(&values, self.segmentedTextColor, .segmentedText)
        try encodeColor(&values, self.segmentedDividerColor, .segmentedDivider)
    }
}

extension PresentationThemeNavigationSearchBar: Codable {
    enum CodingKeys: String, CodingKey {
        case background
        case accent
        case inputFill
        case inputText
        case inputPlaceholderText
        case inputIcon
        case inputClearButton
        case separator
    }
    
    public convenience init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        self.init(backgroundColor: try decodeColor(values, .background),
                  accentColor: try decodeColor(values, .accent),
                  inputFillColor: try decodeColor(values, .inputFill),
                  inputTextColor: try decodeColor(values, .inputText),
                  inputPlaceholderTextColor: try decodeColor(values, .inputPlaceholderText),
                  inputIconColor: try decodeColor(values, .inputIcon),
                  inputClearButtonColor: try decodeColor(values, .inputClearButton),
                  separatorColor: try decodeColor(values, .separator))
    }
    
    public func encode(to encoder: Encoder) throws {
        var values = encoder.container(keyedBy: CodingKeys.self)
        try encodeColor(&values, self.backgroundColor, .background)
        try encodeColor(&values, self.accentColor, .accent)
        try encodeColor(&values, self.inputFillColor, .inputFill)
        try encodeColor(&values, self.inputTextColor, .inputText)
        try encodeColor(&values, self.inputPlaceholderTextColor, .inputPlaceholderText)
        try encodeColor(&values, self.inputIconColor, .inputIcon)
        try encodeColor(&values, self.inputClearButtonColor, .inputClearButton)
        try encodeColor(&values, self.separatorColor, .separator)
    }
}

extension PresentationThemeRootController: Codable {
    enum CodingKeys: String, CodingKey {
        case statusBar
        case tabBar
        case navBar
        case searchBar
        case keyboard
    }
    
    public convenience init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        self.init(statusBarStyle: try values.decode(PresentationThemeStatusBarStyle.self, forKey: .statusBar),
                  tabBar: try values.decode(PresentationThemeRootTabBar.self, forKey: .tabBar),
                  navigationBar: try values.decode(PresentationThemeRootNavigationBar.self, forKey: .navBar),
                  navigationSearchBar: try values.decode(PresentationThemeNavigationSearchBar.self, forKey: .searchBar),
                  keyboardColor: try values.decode(PresentationThemeKeyboardColor.self, forKey: .keyboard))
    }
    
    public func encode(to encoder: Encoder) throws {
        var values = encoder.container(keyedBy: CodingKeys.self)
        try values.encode(self.statusBarStyle, forKey: .statusBar)
        try values.encode(self.tabBar, forKey: .tabBar)
        try values.encode(self.navigationBar, forKey: .navBar)
        try values.encode(self.navigationSearchBar, forKey: .searchBar)
        try values.encode(self.keyboardColor, forKey: .keyboard)
    }
}

extension PresentationThemeActionSheet: Codable {
    enum CodingKeys: String, CodingKey {
        case dim
        case bgType
        case opaqueItemBg
        case itemBg
        case opaqueItemHighlightedBg
        case itemHighlightedBg
        case opaqueItemSeparator
        case standardActionText
        case destructiveActionText
        case disabledActionText
        case primaryText
        case secondaryText
        case controlAccent
        case inputBg
        case inputHollowBg
        case inputBorder
        case inputPlaceholder
        case inputText
        case inputClearButton
        case checkContent
    }
    
    public convenience init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        self.init(dimColor: try decodeColor(values, .dim),
                  backgroundType: try values.decode(PresentationThemeActionSheetBackgroundType.self, forKey: .bgType),
                  opaqueItemBackgroundColor: try decodeColor(values, .opaqueItemBg),
                  itemBackgroundColor: try decodeColor(values, .itemBg),
                  opaqueItemHighlightedBackgroundColor: try decodeColor(values, .opaqueItemHighlightedBg),
                  itemHighlightedBackgroundColor: try decodeColor(values, .itemHighlightedBg),
                  opaqueItemSeparatorColor: try decodeColor(values, .opaqueItemSeparator),
                  standardActionTextColor: try decodeColor(values, .standardActionText),
                  destructiveActionTextColor: try decodeColor(values, .destructiveActionText),
                  disabledActionTextColor: try decodeColor(values, .disabledActionText),
                  primaryTextColor: try decodeColor(values, .primaryText),
                  secondaryTextColor: try decodeColor(values, .secondaryText),
                  controlAccentColor: try decodeColor(values, .controlAccent),
                  inputBackgroundColor: try decodeColor(values, .inputBg),
                  inputHollowBackgroundColor: try decodeColor(values, .inputHollowBg),
                  inputBorderColor: try decodeColor(values, .inputBorder),
                  inputPlaceholderColor: try decodeColor(values, .inputPlaceholder),
                  inputTextColor: try decodeColor(values, .inputText),
                  inputClearButtonColor: try decodeColor(values, .inputClearButton),
                  checkContentColor: try decodeColor(values, .checkContent))
    }
    
    public func encode(to encoder: Encoder) throws {
        var values = encoder.container(keyedBy: CodingKeys.self)
        try encodeColor(&values, self.dimColor, .dim)
        try values.encode(self.backgroundType, forKey: .bgType)
        try encodeColor(&values, self.opaqueItemBackgroundColor, .opaqueItemBg)
        try encodeColor(&values, self.itemBackgroundColor, .itemBg)
        try encodeColor(&values, self.opaqueItemHighlightedBackgroundColor, .opaqueItemHighlightedBg)
        try encodeColor(&values, self.itemHighlightedBackgroundColor, .itemHighlightedBg)
        try encodeColor(&values, self.opaqueItemSeparatorColor, .opaqueItemSeparator)
        try encodeColor(&values, self.standardActionTextColor, .standardActionText)
        try encodeColor(&values, self.destructiveActionTextColor, .destructiveActionText)
        try encodeColor(&values, self.disabledActionTextColor, .disabledActionText)
        try encodeColor(&values, self.primaryTextColor, .primaryText)
        try encodeColor(&values, self.secondaryTextColor, .secondaryText)
        try encodeColor(&values, self.controlAccentColor, .controlAccent)
        try encodeColor(&values, self.inputBackgroundColor, .inputBg)
        try encodeColor(&values, self.inputHollowBackgroundColor, .inputHollowBg)
        try encodeColor(&values, self.inputBorderColor, .inputBorder)
        try encodeColor(&values, self.inputPlaceholderColor, .inputPlaceholder)
        try encodeColor(&values, self.inputTextColor, .inputText)
        try encodeColor(&values, self.inputClearButtonColor, .inputClearButton)
        try encodeColor(&values, self.checkContentColor, .checkContent)
    }
}

extension PresentationThemeSwitch: Codable {
    enum CodingKeys: String, CodingKey {
        case frame
        case handle
        case content
        case positive
        case negative
    }
    
    public convenience init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        self.init(frameColor: try decodeColor(values, .frame),
                  handleColor: try decodeColor(values, .handle),
                  contentColor: try decodeColor(values, .content),
                  positiveColor: try decodeColor(values, .positive),
                  negativeColor: try decodeColor(values, .negative))
    }
    
    public func encode(to encoder: Encoder) throws {
        var values = encoder.container(keyedBy: CodingKeys.self)
        try encodeColor(&values, self.frameColor, .frame)
        try encodeColor(&values, self.handleColor, .handle)
        try encodeColor(&values, self.contentColor, .content)
        try encodeColor(&values, self.positiveColor, .positive)
        try encodeColor(&values, self.negativeColor, .negative)
    }
}

extension PresentationThemeFillForeground: Codable {
    enum CodingKeys: String, CodingKey {
        case bg
        case fg
    }
    
    public convenience init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        self.init(fillColor: try decodeColor(values, .bg),
                  foregroundColor: try decodeColor(values, .fg))
    }
    
    public func encode(to encoder: Encoder) throws {
        var values = encoder.container(keyedBy: CodingKeys.self)
        try encodeColor(&values, self.fillColor, .bg)
        try encodeColor(&values, self.foregroundColor, .fg)
    }
}

extension PresentationThemeItemDisclosureActions: Codable {
    enum CodingKeys: String, CodingKey {
        case neutral1
        case neutral2
        case destructive
        case constructive
        case accent
        case warning
        case inactive
    }
    
    public convenience init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        self.init(neutral1: try values.decode(PresentationThemeFillForeground.self, forKey: .neutral1),
                  neutral2: try values.decode(PresentationThemeFillForeground.self, forKey: .neutral2),
                  destructive: try values.decode(PresentationThemeFillForeground.self, forKey: .destructive),
                  constructive: try values.decode(PresentationThemeFillForeground.self, forKey: .constructive),
                  accent: try values.decode(PresentationThemeFillForeground.self, forKey: .accent),
                  warning: try values.decode(PresentationThemeFillForeground.self, forKey: .warning),
                  inactive: try values.decode(PresentationThemeFillForeground.self, forKey: .inactive))
    }
    
    public func encode(to encoder: Encoder) throws {
        var values = encoder.container(keyedBy: CodingKeys.self)
        try values.encode(self.neutral1, forKey: .neutral1)
        try values.encode(self.neutral2, forKey: .neutral2)
        try values.encode(self.destructive, forKey: .destructive)
        try values.encode(self.constructive, forKey: .constructive)
        try values.encode(self.accent, forKey: .accent)
        try values.encode(self.warning, forKey: .warning)
        try values.encode(self.inactive, forKey: .inactive)
    }
}


extension PresentationThemeItemBarChart: Codable {
    enum CodingKeys: String, CodingKey {
        case color1
        case color2
        case color3
    }
    
    public convenience init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        self.init(color1: try decodeColor(values, .color1),
                  color2: try decodeColor(values, .color2),
                  color3: try decodeColor(values, .color3))
    }
    
    public func encode(to encoder: Encoder) throws {
        var values = encoder.container(keyedBy: CodingKeys.self)
         try encodeColor(&values, self.color1, .color1)
         try encodeColor(&values, self.color2, .color2)
         try encodeColor(&values, self.color3, .color3)
    }
}

extension PresentationThemeFillStrokeForeground: Codable {
    enum CodingKeys: String, CodingKey {
        case bg
        case stroke
        case fg
    }
    
    public convenience init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        self.init(fillColor: try decodeColor(values, .bg),
                  strokeColor: try decodeColor(values, .stroke),
                  foregroundColor: try decodeColor(values, .fg))
    }
    
    public func encode(to encoder: Encoder) throws {
        var values = encoder.container(keyedBy: CodingKeys.self)
        try encodeColor(&values, self.fillColor, .bg)
        try encodeColor(&values, self.strokeColor, .stroke)
        try encodeColor(&values, self.foregroundColor, .fg)
    }
}

extension PresentationInputFieldTheme: Codable {
    enum CodingKeys: String, CodingKey {
        case bg
        case stroke
        case placeholder
        case primary
        case control
    }
    
    public convenience init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        self.init(backgroundColor: try decodeColor(values, .bg),
                  strokeColor: try decodeColor(values, .stroke),
                  placeholderColor: try decodeColor(values, .placeholder),
                  primaryColor: try decodeColor(values, .primary),
                  controlColor: try decodeColor(values, .control))
    }
    
    public func encode(to encoder: Encoder) throws {
        var values = encoder.container(keyedBy: CodingKeys.self)
        try encodeColor(&values, self.backgroundColor, .bg)
        try encodeColor(&values, self.strokeColor, .stroke)
        try encodeColor(&values, self.placeholderColor, .placeholder)
        try encodeColor(&values, self.primaryColor, .primary)
        try encodeColor(&values, self.controlColor, .control)
    }
}

extension PresentationThemeList.PaymentOption: Codable {
    enum CodingKeys: String, CodingKey {
        case inactiveFill
        case inactiveForeground
        case activeFill
        case activeForeground
    }

    public convenience init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        self.init(
            inactiveFillColor: try decodeColor(values, .inactiveFill),
            inactiveForegroundColor: try decodeColor(values, .inactiveForeground),
            activeFillColor: try decodeColor(values, .activeFill),
            activeForegroundColor: try decodeColor(values, .activeForeground)
        )
    }

    public func encode(to encoder: Encoder) throws {
        var values = encoder.container(keyedBy: CodingKeys.self)
        try encodeColor(&values, self.activeFillColor, .inactiveFill)
        try encodeColor(&values, self.activeForegroundColor, .inactiveForeground)
        try encodeColor(&values, self.activeFillColor, .activeFill)
        try encodeColor(&values, self.activeForegroundColor, .activeForeground)
    }
}

extension PresentationThemeList: Codable {
    enum CodingKeys: String, CodingKey {
        case blocksBg
        case modalBlocksBg
        case plainBg
        case modalPlainBg
        case primaryText
        case secondaryText
        case disabledText
        case accent
        case highlighted
        case destructive
        case placeholderText
        case itemBlocksBg
        case itemModalBlocksBg
        case itemHighlightedBg
        case blocksSeparator
        case plainSeparator
        case disclosureArrow
        case sectionHeaderText
        case freeText
        case freeTextError
        case freeTextSuccess
        case freeMonoIcon
        case `switch`
        case disclosureActions
        case check
        case controlSecondary
        case freeInputField
        case freePlainInputField
        case mediaPlaceholder
        case scrollIndicator
        case pageIndicatorInactive
        case inputClearButton
        case itemBarChart
        case itemInputField
        case paymentOption
    }
    
    public convenience init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        
        let freePlainInputField: PresentationInputFieldTheme
        if let value = try? values.decode(PresentationInputFieldTheme.self, forKey: .freePlainInputField) {
            freePlainInputField = value
        } else {
            freePlainInputField = try values.decode(PresentationInputFieldTheme.self, forKey: .freeInputField)
        }

        let freeTextSuccessColor = try decodeColor(values, .freeTextSuccess)
        
        self.init(
            blocksBackgroundColor: try decodeColor(values, .blocksBg),
            modalBlocksBackgroundColor: try decodeColor(values, .modalBlocksBg, decoder: decoder, fallbackKey: "list.blocksBg"),
            plainBackgroundColor: try decodeColor(values, .plainBg),
            modalPlainBackgroundColor: try decodeColor(values, .modalPlainBg, decoder: decoder, fallbackKey: "list.plainBg"),
            itemPrimaryTextColor: try decodeColor(values, .primaryText),
            itemSecondaryTextColor: try decodeColor(values, .secondaryText),
            itemDisabledTextColor: try decodeColor(values, .disabledText),
            itemAccentColor: try decodeColor(values, .accent),
            itemHighlightedColor: try decodeColor(values, .highlighted),
            itemDestructiveColor: try decodeColor(values, .destructive),
            itemPlaceholderTextColor: try decodeColor(values, .placeholderText),
            itemBlocksBackgroundColor: try decodeColor(values, .itemBlocksBg),
            itemModalBlocksBackgroundColor: try decodeColor(values, .itemModalBlocksBg, decoder: decoder, fallbackKey: "list.itemBlocksBg"),
            itemHighlightedBackgroundColor: try decodeColor(values, .itemHighlightedBg),
            itemBlocksSeparatorColor: try decodeColor(values, .blocksSeparator),
            itemPlainSeparatorColor: try decodeColor(values, .plainSeparator),
            disclosureArrowColor: try decodeColor(values, .disclosureArrow),
            sectionHeaderTextColor: try decodeColor(values, .sectionHeaderText),
            freeTextColor: try decodeColor(values, .freeText),
            freeTextErrorColor: try decodeColor(values, .freeTextError),
            freeTextSuccessColor: freeTextSuccessColor,
            freeMonoIconColor: try decodeColor(values, .freeMonoIcon),
            itemSwitchColors: try values.decode(PresentationThemeSwitch.self, forKey: .switch),
            itemDisclosureActions: try values.decode(PresentationThemeItemDisclosureActions.self, forKey: .disclosureActions),
            itemCheckColors: try values.decode(PresentationThemeFillStrokeForeground.self, forKey: .check),
            controlSecondaryColor: try decodeColor(values, .controlSecondary),
            freeInputField: try values.decode(PresentationInputFieldTheme.self, forKey: .freeInputField),
            freePlainInputField: freePlainInputField,
            mediaPlaceholderColor: try decodeColor(values, .mediaPlaceholder),
            scrollIndicatorColor: try decodeColor(values, .scrollIndicator),
            pageIndicatorInactiveColor: try decodeColor(values, .pageIndicatorInactive),
            inputClearButtonColor: try decodeColor(values, .inputClearButton),
            itemBarChart: try values.decode(PresentationThemeItemBarChart.self, forKey: .itemBarChart),
            itemInputField: try values.decode(PresentationInputFieldTheme.self, forKey: .itemInputField),
            paymentOption: (try? values.decode(PresentationThemeList.PaymentOption.self, forKey: .paymentOption)) ?? PresentationThemeList.PaymentOption(
                inactiveFillColor: freeTextSuccessColor.withMultipliedAlpha(0.3),
                inactiveForegroundColor: freeTextSuccessColor,
                activeFillColor: freeTextSuccessColor,
                activeForegroundColor: UIColor(rgb: 0xffffff)
            )
        )
    }
    
    public func encode(to encoder: Encoder) throws {
        var values = encoder.container(keyedBy: CodingKeys.self)
        try encodeColor(&values, self.blocksBackgroundColor, .blocksBg)
        try encodeColor(&values, self.plainBackgroundColor, .plainBg)
        try encodeColor(&values, self.itemPrimaryTextColor, .primaryText)
        try encodeColor(&values, self.itemSecondaryTextColor, .secondaryText)
        try encodeColor(&values, self.itemDisabledTextColor, .disabledText)
        try encodeColor(&values, self.itemAccentColor, .accent)
        try encodeColor(&values, self.itemHighlightedColor, .highlighted)
        try encodeColor(&values, self.itemDestructiveColor, .destructive)
        try encodeColor(&values, self.itemPlaceholderTextColor, .placeholderText)
        try encodeColor(&values, self.itemBlocksBackgroundColor, .itemBlocksBg)
        try encodeColor(&values, self.itemHighlightedBackgroundColor, .itemHighlightedBg)
        try encodeColor(&values, self.itemBlocksSeparatorColor, .blocksSeparator)
        try encodeColor(&values, self.itemPlainSeparatorColor, .plainSeparator)
        try encodeColor(&values, self.disclosureArrowColor, .disclosureArrow)
        try encodeColor(&values, self.sectionHeaderTextColor, .sectionHeaderText)
        try encodeColor(&values, self.freeTextColor, .freeText)
        try encodeColor(&values, self.freeTextErrorColor, .freeTextError)
        try encodeColor(&values, self.freeTextSuccessColor, .freeTextSuccess)
        try encodeColor(&values, self.freeMonoIconColor, .freeMonoIcon)
        try values.encode(self.itemSwitchColors, forKey: .`switch`)
        try values.encode(self.itemDisclosureActions, forKey: .disclosureActions)
        try values.encode(self.itemCheckColors, forKey: .check)
        try encodeColor(&values, self.controlSecondaryColor, .controlSecondary)
        try values.encode(self.freeInputField, forKey: .freeInputField)
        try encodeColor(&values, self.mediaPlaceholderColor, .mediaPlaceholder)
        try encodeColor(&values, self.scrollIndicatorColor, .scrollIndicator)
        try encodeColor(&values, self.pageIndicatorInactiveColor, .pageIndicatorInactive)
        try encodeColor(&values, self.inputClearButtonColor, .inputClearButton)
        try values.encode(self.itemBarChart, forKey: .itemBarChart)
        try values.encode(self.itemInputField, forKey: .itemInputField)
    }
}

extension PresentationThemeArchiveAvatarColors: Codable {
    enum CodingKeys: String, CodingKey {
        case background
        case foreground
    }
    
    public convenience init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        self.init(backgroundColors: try values.decode(PresentationThemeGradientColors.self, forKey: .background),
                  foregroundColor: try decodeColor(values, .foreground))
    }
    
    public func encode(to encoder: Encoder) throws {
        var values = encoder.container(keyedBy: CodingKeys.self)
        try values.encode(self.backgroundColors, forKey: .background)
        try encodeColor(&values, self.foregroundColor, .foreground)
    }
}

extension PresentationThemeChatList: Codable {
    enum CodingKeys: String, CodingKey {
        case bg
        case itemSeparator
        case itemBg
        case pinnedItemBg
        case itemHighlightedBg
        case pinnedItemHighlightedBg
        case itemSelectedBg
        case title
        case secretTitle
        case dateText
        case authorName
        case messageText
        case messageHighlightedText
        case messageDraftText
        case checkmark
        case pendingIndicator
        case failedFill
        case failedFg
        case muteIcon
        case unreadBadgeActiveBg
        case unreadBadgeActiveText
        case unreadBadgeInactiveBg
        case unreadBadgeInactiveText
        case reactionBadgeActiveBg
        case pinnedBadge
        case pinnedSearchBar
        case regularSearchBar
        case sectionHeaderBg
        case sectionHeaderText
        case verifiedIconBg
        case verifiedIconFg
        case secretIcon
        case pinnedArchiveAvatar
        case unpinnedArchiveAvatar
        case onlineDot
    }
    
    public convenience init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        let codingPath = decoder.codingPath.map { $0.stringValue }.joined(separator: ".")
        self.init(backgroundColor: try decodeColor(values, .bg),
                  itemSeparatorColor: try decodeColor(values, .itemSeparator),
                  itemBackgroundColor: try decodeColor(values, .itemBg),
                  pinnedItemBackgroundColor: try decodeColor(values, .pinnedItemBg),
                  itemHighlightedBackgroundColor: try decodeColor(values, .itemHighlightedBg),
                  pinnedItemHighlightedBackgroundColor: try decodeColor(values, .pinnedItemHighlightedBg, fallbackKey: "\(codingPath).itemHighlightedBg"),
                  itemSelectedBackgroundColor: try decodeColor(values, .itemSelectedBg),
                  titleColor: try decodeColor(values, .title),
                  secretTitleColor: try decodeColor(values, .secretTitle),
                  dateTextColor: try decodeColor(values, .dateText),
                  authorNameColor: try decodeColor(values, .authorName),
                  messageTextColor: try decodeColor(values, .messageText),
                  messageHighlightedTextColor: try decodeColor(values, .messageHighlightedText),
                  messageDraftTextColor: try decodeColor(values, .messageDraftText),
                  checkmarkColor: try decodeColor(values, .checkmark),
                  pendingIndicatorColor: try decodeColor(values, .pendingIndicator),
                  failedFillColor: try decodeColor(values, .failedFill),
                  failedForegroundColor: try decodeColor(values, .failedFg),
                  muteIconColor: try decodeColor(values, .muteIcon),
                  unreadBadgeActiveBackgroundColor: try decodeColor(values, .unreadBadgeActiveBg),
                  unreadBadgeActiveTextColor: try decodeColor(values, .unreadBadgeActiveText),
                  unreadBadgeInactiveBackgroundColor: try decodeColor(values, .unreadBadgeInactiveBg),
                  unreadBadgeInactiveTextColor: try decodeColor(values, .unreadBadgeInactiveText),
                  reactionBadgeActiveBackgroundColor: try decodeColor(values, .reactionBadgeActiveBg, fallbackKey: "\(codingPath).unreadBadgeActiveBg"),
                  pinnedBadgeColor: try decodeColor(values, .pinnedBadge),
                  pinnedSearchBarColor: try decodeColor(values, .pinnedSearchBar),
                  regularSearchBarColor: try decodeColor(values, .regularSearchBar),
                  sectionHeaderFillColor: try decodeColor(values, .sectionHeaderBg),
                  sectionHeaderTextColor: try decodeColor(values, .sectionHeaderText),
                  verifiedIconFillColor: try decodeColor(values, .verifiedIconBg),
                  verifiedIconForegroundColor: try decodeColor(values, .verifiedIconFg),
                  secretIconColor: try decodeColor(values, .secretIcon),
                  pinnedArchiveAvatarColor: try values.decode(PresentationThemeArchiveAvatarColors.self, forKey: .pinnedArchiveAvatar),
                  unpinnedArchiveAvatarColor: try values.decode(PresentationThemeArchiveAvatarColors.self, forKey: .unpinnedArchiveAvatar),
                  onlineDotColor: try decodeColor(values, .onlineDot))
    }
    
    public func encode(to encoder: Encoder) throws {
        var values = encoder.container(keyedBy: CodingKeys.self)
        try encodeColor(&values, self.backgroundColor, .bg)
        try encodeColor(&values, self.itemSeparatorColor, .itemSeparator)
        try encodeColor(&values, self.itemBackgroundColor, .itemBg)
        try encodeColor(&values, self.pinnedItemBackgroundColor, .pinnedItemBg)
        try encodeColor(&values, self.itemHighlightedBackgroundColor, .itemHighlightedBg)
        try encodeColor(&values, self.pinnedItemHighlightedBackgroundColor, .pinnedItemHighlightedBg)
        try encodeColor(&values, self.itemSelectedBackgroundColor, .itemSelectedBg)
        try encodeColor(&values, self.titleColor, .title)
        try encodeColor(&values, self.secretTitleColor, .secretTitle)
        try encodeColor(&values, self.dateTextColor, .dateText)
        try encodeColor(&values, self.authorNameColor, .authorName)
        try encodeColor(&values, self.messageTextColor, .messageText)
        try encodeColor(&values, self.messageHighlightedTextColor, .messageHighlightedText)
        try encodeColor(&values, self.messageDraftTextColor, .messageDraftText)
        try encodeColor(&values, self.checkmarkColor, .checkmark)
        try encodeColor(&values, self.pendingIndicatorColor, .pendingIndicator)
        try encodeColor(&values, self.failedFillColor, .failedFill)
        try encodeColor(&values, self.failedForegroundColor, .failedFg)
        try encodeColor(&values, self.muteIconColor, .muteIcon)
        try encodeColor(&values, self.unreadBadgeActiveBackgroundColor, .unreadBadgeActiveBg)
        try encodeColor(&values, self.unreadBadgeActiveTextColor, .unreadBadgeActiveText)
        try encodeColor(&values, self.unreadBadgeInactiveBackgroundColor, .unreadBadgeInactiveBg)
        try encodeColor(&values, self.unreadBadgeInactiveTextColor, .unreadBadgeInactiveText)
        try encodeColor(&values, self.reactionBadgeActiveBackgroundColor, .reactionBadgeActiveBg)
        try encodeColor(&values, self.pinnedBadgeColor, .pinnedBadge)
        try encodeColor(&values, self.pinnedSearchBarColor, .pinnedSearchBar)
        try encodeColor(&values, self.regularSearchBarColor, .regularSearchBar)
        try encodeColor(&values, self.sectionHeaderFillColor, .sectionHeaderBg)
        try encodeColor(&values, self.sectionHeaderTextColor, .sectionHeaderText)
        try encodeColor(&values, self.verifiedIconFillColor, .verifiedIconBg)
        try encodeColor(&values, self.verifiedIconForegroundColor, .verifiedIconFg)
        try encodeColor(&values, self.secretIconColor, .secretIcon)
        try values.encode(self.pinnedArchiveAvatarColor, forKey: .pinnedArchiveAvatar)
        try values.encode(self.unpinnedArchiveAvatarColor, forKey: .unpinnedArchiveAvatar)
        try encodeColor(&values, self.onlineDotColor, .onlineDot)
    }
}

extension PresentationThemeBubbleShadow: Codable {
    enum CodingKeys: String, CodingKey {
        case color
        case radius
        case verticalOffset
    }
    
    public init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        self.init(
            color: try decodeColor(values, .color),
            radius: try CGFloat(Double(truncating: values.decode(Decimal.self, forKey: .radius) as NSNumber)),
            verticalOffset: try CGFloat(Double(truncating: values.decode(Decimal.self, forKey: .verticalOffset) as NSNumber))
        )
    }
    
    public func encode(to encoder: Encoder) throws {
        var values = encoder.container(keyedBy: CodingKeys.self)
        try encodeColor(&values, self.color, .color)
        try values.encode(Decimal(Double(self.radius)), forKey: .radius)
        try values.encode(Decimal(Double(self.verticalOffset)), forKey: .verticalOffset)
    }
}

extension PresentationThemeBubbleColorComponents: Codable {
    enum CodingKeys: String, CodingKey {
        case bg
        case gradientBg
        case highlightedBg
        case stroke
        case shadow
        case bgList
        case reactionInactiveBg
        case reactionInactiveFg
        case reactionInactiveMediaPlaceholder
        case reactionActiveMediaPlaceholder
        case reactionActiveBg
        case reactionActiveFg
        case __workaroundNonexistingKey
    }
    
    public convenience init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        let codingPath = decoder.codingPath.map { $0.stringValue }.joined(separator: ".")

        let fill: [UIColor]

        if let bgList = try? decodeColorList(values, .bgList) {
            fill = bgList
        } else {
            var fillColor = try decodeColor(values, .bg)
            var gradientColor = try decodeColor(values, .gradientBg, decoder: decoder, fallbackKey: "\(codingPath).bg")
            if gradientColor.rgb != fillColor.rgb {
                fillColor = fillColor.withAlphaComponent(1.0)
                gradientColor = gradientColor.withAlphaComponent(1.0)
            }

            fill = [fillColor, gradientColor]
        }
        
        let fallbackKeyPrefix: String
        if codingPath.hasPrefix("chat.message.incoming.") {
            fallbackKeyPrefix = "chat.message.incoming."
        } else {
            fallbackKeyPrefix = "chat.message.outgoing."
        }
        
        let reactionInactiveBackground: UIColor
        if let color = try? decodeColor(values, .reactionInactiveBg) {
            reactionInactiveBackground = color
        } else {
            reactionInactiveBackground = (try decodeColor(values, .__workaroundNonexistingKey, fallbackKey: "\(fallbackKeyPrefix).accentControl")).withMultipliedAlpha(0.1)
        }
        
        let reactionInactiveMediaPlaceholder: UIColor
        if let color = try? decodeColor(values, .reactionInactiveMediaPlaceholder) {
            reactionInactiveMediaPlaceholder = color
        } else {
            reactionInactiveMediaPlaceholder = (try decodeColor(values, .__workaroundNonexistingKey, fallbackKey: "\(fallbackKeyPrefix).accentControl")).withMultipliedAlpha(0.1)
        }
        
        let reactionActiveMediaPlaceholder: UIColor
        if let color = try? decodeColor(values, .reactionActiveMediaPlaceholder) {
            reactionActiveMediaPlaceholder = color
        } else {
            reactionActiveMediaPlaceholder = (try decodeColor(values, .__workaroundNonexistingKey, fallbackKey: "\(fallbackKeyPrefix).accentControl")).withMultipliedAlpha(0.1)
        }
        
        let reactionInactiveForeground: UIColor
        if let color = try? decodeColor(values, .reactionInactiveFg) {
            reactionInactiveForeground = color
        } else {
            reactionInactiveForeground = try decodeColor(values, .__workaroundNonexistingKey, fallbackKey: "\(fallbackKeyPrefix).accentControl")
        }
        
        let reactionActiveBackground: UIColor
        if let color = try? decodeColor(values, .reactionActiveBg) {
            reactionActiveBackground = color
        } else {
            reactionActiveBackground = try decodeColor(values, .__workaroundNonexistingKey, fallbackKey: "\(fallbackKeyPrefix).accentControl")
        }
        
        let reactionActiveForeground: UIColor
        if let color = try? decodeColor(values, .reactionActiveFg) {
            reactionActiveForeground = color
        } else {
            reactionActiveForeground = .clear
        }
        
        self.init(
            fill: fill,
            highlightedFill: try decodeColor(values, .highlightedBg),
            stroke: try decodeColor(values, .stroke),
            shadow: try? values.decode(PresentationThemeBubbleShadow.self, forKey: .shadow),
            reactionInactiveBackground: reactionInactiveBackground,
            reactionInactiveForeground: reactionInactiveForeground,
            reactionActiveBackground: reactionActiveBackground,
            reactionActiveForeground: reactionActiveForeground,
            reactionInactiveMediaPlaceholder: reactionInactiveMediaPlaceholder,
            reactionActiveMediaPlaceholder: reactionActiveMediaPlaceholder
        )
    }
    
    public func encode(to encoder: Encoder) throws {
        var values = encoder.container(keyedBy: CodingKeys.self)
        if self.fill.count <= 2 {
            if self.fill.count > 1 {
                try encodeColor(&values, self.fill[0], .bg)
                try encodeColor(&values, self.fill[1], .gradientBg)
            } else {
                try encodeColor(&values, self.fill[0], .bg)
                try encodeColor(&values, self.fill[0], .gradientBg)
            }
        } else {
            try encodeColorList(&values, self.fill, .bgList)
        }
        try encodeColor(&values, self.highlightedFill, .highlightedBg)
        try encodeColor(&values, self.stroke, .stroke)
        try encodeColor(&values, self.reactionInactiveBackground, .reactionInactiveBg)
        try encodeColor(&values, self.reactionInactiveForeground, .reactionInactiveFg)
        try encodeColor(&values, self.reactionActiveBackground, .reactionActiveBg)
        try encodeColor(&values, self.reactionActiveForeground, .reactionActiveFg)
        try encodeColor(&values, self.reactionInactiveMediaPlaceholder, .reactionInactiveMediaPlaceholder)
        try encodeColor(&values, self.reactionActiveMediaPlaceholder, .reactionActiveMediaPlaceholder)
    }
}

extension PresentationThemeBubbleColor: Codable {
    enum CodingKeys: String, CodingKey {
        case withWp
        case withoutWp
    }
    
    public convenience init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        self.init(withWallpaper: try values.decode(PresentationThemeBubbleColorComponents.self, forKey: .withWp),
                  withoutWallpaper: try values.decode(PresentationThemeBubbleColorComponents.self, forKey: .withoutWp))
    }
    
    public func encode(to encoder: Encoder) throws {
        var values = encoder.container(keyedBy: CodingKeys.self)
        try values.encode(self.withWallpaper, forKey: .withWp)
        try values.encode(self.withoutWallpaper, forKey: .withoutWp)
    }
}

extension PresentationThemeVariableColor: Codable {
    enum CodingKeys: String, CodingKey {
        case withWp
        case withoutWp
    }
    
    public convenience init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        self.init(withWallpaper: try decodeColor(values, .withWp),
                  withoutWallpaper: try decodeColor(values, .withoutWp))
    }
    
    public func encode(to encoder: Encoder) throws {
        var values = encoder.container(keyedBy: CodingKeys.self)
        try encodeColor(&values, self.withWallpaper, .withWp)
        try encodeColor(&values, self.withoutWallpaper, .withoutWp)
    }
}

extension PresentationThemeChatBubblePolls: Codable {
    enum CodingKeys: String, CodingKey {
        case radioButton
        case radioProgress
        case highlight
        case separator
        case bar
        case barIconForeground
        case barPositive
        case barNegative
    }
    
    public convenience init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        let bar = try decodeColor(values, .bar)
        self.init(
            radioButton: try decodeColor(values, .radioButton),
            radioProgress: try decodeColor(values, .radioProgress),
            highlight: try decodeColor(values, .highlight),
            separator: try decodeColor(values, .separator),
            bar: bar,
            barIconForeground: (try? decodeColor(values, .barIconForeground)) ?? .clear,
            barPositive: (try? decodeColor(values, .barPositive)) ?? bar,
            barNegative: (try? decodeColor(values, .barNegative)) ?? bar
        )
    }
    
    public func encode(to encoder: Encoder) throws {
        var values = encoder.container(keyedBy: CodingKeys.self)
        try encodeColor(&values, self.radioButton, .radioButton)
        try encodeColor(&values, self.radioProgress, .radioProgress)
        try encodeColor(&values, self.highlight, .highlight)
        try encodeColor(&values, self.separator, .separator)
        try encodeColor(&values, self.bar, .bar)
        try encodeColor(&values, self.barIconForeground, .barIconForeground)
        try encodeColor(&values, self.barPositive, .barPositive)
        try encodeColor(&values, self.barNegative, .barNegative)
    }
}

extension PresentationThemePartedColors: Codable {
    enum CodingKeys: String, CodingKey {
        case bubble
        case primaryText
        case secondaryText
        case linkText
        case linkHighlight
        case scam
        case textHighlight
        case accentText
        case accentControl
        case mediaActiveControl
        case mediaInactiveControl
        case mediaControlInnerBg
        case pendingActivity
        case fileTitle
        case fileDescription
        case fileDuration
        case mediaPlaceholder
        case polls
        case actionButtonsBg
        case actionButtonsStroke
        case actionButtonsText
        case textSelection
        case textSelectionKnob
        case accentControlDisabled
    }
    
    public convenience init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        let codingPath = decoder.codingPath.map { $0.stringValue }.joined(separator: ".")
        let accentControlColor = try decodeColor(values, .accentControl)
        self.init(
            bubble: try values.decode(PresentationThemeBubbleColor.self, forKey: .bubble),
            primaryTextColor: try decodeColor(values, .primaryText),
            secondaryTextColor: try decodeColor(values, .secondaryText),
            linkTextColor: try decodeColor(values, .linkText),
            linkHighlightColor: try decodeColor(values, .linkHighlight),
            scamColor: try decodeColor(values, .scam),
            textHighlightColor: try decodeColor(values, .textHighlight),
            accentTextColor: try decodeColor(values, .accentText),
            accentControlColor: accentControlColor,
            accentControlDisabledColor: (try? decodeColor(values, .accentControlDisabled)) ?? accentControlColor.withAlphaComponent(0.5),
            mediaActiveControlColor: try decodeColor(values, .mediaActiveControl),
            mediaInactiveControlColor: try decodeColor(values, .mediaInactiveControl),
            mediaControlInnerBackgroundColor: try decodeColor(values, .mediaControlInnerBg, decoder: decoder, fallbackKey: "\(codingPath).bubble.withWp.bg"),
            pendingActivityColor: try decodeColor(values, .pendingActivity),
            fileTitleColor: try decodeColor(values, .fileTitle),
            fileDescriptionColor: try decodeColor(values, .fileDescription),
            fileDurationColor: try decodeColor(values, .fileDuration),
            mediaPlaceholderColor: try decodeColor(values, .mediaPlaceholder),
            polls: try values.decode(PresentationThemeChatBubblePolls.self, forKey: .polls),
            actionButtonsFillColor: try values.decode(PresentationThemeVariableColor.self, forKey: .actionButtonsBg),
            actionButtonsStrokeColor: try values.decode(PresentationThemeVariableColor.self, forKey: .actionButtonsStroke),
            actionButtonsTextColor: try values.decode(PresentationThemeVariableColor.self, forKey: .actionButtonsText),
            textSelectionColor: try decodeColor(values, .textSelection),
            textSelectionKnobColor: try decodeColor(values, .textSelectionKnob)
        )
    }
    
    public func encode(to encoder: Encoder) throws {
        var values = encoder.container(keyedBy: CodingKeys.self)
        try values.encode(self.bubble, forKey: .bubble)
        try encodeColor(&values, self.primaryTextColor, .primaryText)
        try encodeColor(&values, self.secondaryTextColor, .secondaryText)
        try encodeColor(&values, self.linkTextColor, .linkText)
        try encodeColor(&values, self.linkHighlightColor, .linkHighlight)
        try encodeColor(&values, self.scamColor, .scam)
        try encodeColor(&values, self.textHighlightColor, .textHighlight)
        try encodeColor(&values, self.accentTextColor, .accentText)
        try encodeColor(&values, self.accentControlColor, .accentControl)
        try encodeColor(&values, self.mediaActiveControlColor, .mediaActiveControl)
        try encodeColor(&values, self.mediaInactiveControlColor, .mediaInactiveControl)
        try encodeColor(&values, self.mediaControlInnerBackgroundColor, .mediaControlInnerBg)
        try encodeColor(&values, self.pendingActivityColor, .pendingActivity)
        try encodeColor(&values, self.fileTitleColor, .fileTitle)
        try encodeColor(&values, self.fileDescriptionColor, .fileDescription)
        try encodeColor(&values, self.fileDurationColor, .fileDuration)
        try encodeColor(&values, self.mediaPlaceholderColor, .mediaPlaceholder)
        try values.encode(self.polls, forKey: .polls)
        try values.encode(self.actionButtonsFillColor, forKey: .actionButtonsBg)
        try values.encode(self.actionButtonsStrokeColor, forKey: .actionButtonsStroke)
        try values.encode(self.actionButtonsTextColor, forKey: .actionButtonsText)
        try encodeColor(&values, self.textSelectionColor, .textSelection)
        try encodeColor(&values, self.textSelectionKnobColor, .textSelectionKnob)
    }
}

extension PresentationThemeChatMessage: Codable {
    enum CodingKeys: String, CodingKey {
        case incoming
        case outgoing
        case freeform
        case infoPrimaryText
        case infoLinkText
        case outgoingCheck
        case mediaDateAndStatusBg
        case mediaDateAndStatusText
        case shareButtonBg
        case shareButtonStroke
        case shareButtonFg
        case mediaOverlayControl
        case selectionControl
        case deliveryFailed
        case mediaHighlightOverlay
        case stickerPlaceholder
        case stickerPlaceholderShimmer
    }
    
    public convenience init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        self.init(incoming: try values.decode(PresentationThemePartedColors.self, forKey: .incoming),
                  outgoing: try values.decode(PresentationThemePartedColors.self, forKey: .outgoing),
                  freeform: try values.decode(PresentationThemeBubbleColor.self, forKey: .freeform),
                  infoPrimaryTextColor: try decodeColor(values, .infoPrimaryText),
                  infoLinkTextColor: try decodeColor(values, .infoLinkText),
                  outgoingCheckColor: try decodeColor(values, .outgoingCheck),
                  mediaDateAndStatusFillColor: try decodeColor(values, .mediaDateAndStatusBg),
                  mediaDateAndStatusTextColor: try decodeColor(values, .mediaDateAndStatusText),
                  shareButtonFillColor: try values.decode(PresentationThemeVariableColor.self, forKey: .shareButtonBg),
                  shareButtonStrokeColor: try values.decode(PresentationThemeVariableColor.self, forKey: .shareButtonStroke),
                  shareButtonForegroundColor: try values.decode(PresentationThemeVariableColor.self, forKey: .shareButtonFg),
                  mediaOverlayControlColors: try values.decode(PresentationThemeFillForeground.self, forKey: .mediaOverlayControl),
                  selectionControlColors: try values.decode(PresentationThemeFillStrokeForeground.self, forKey: .selectionControl),
                  deliveryFailedColors: try values.decode(PresentationThemeFillForeground.self, forKey: .deliveryFailed),
                  mediaHighlightOverlayColor: try decodeColor(values, .mediaHighlightOverlay),
                  stickerPlaceholderColor: try values.decode(PresentationThemeVariableColor.self, forKey: .stickerPlaceholder),
                  stickerPlaceholderShimmerColor: try values.decode(PresentationThemeVariableColor.self, forKey: .stickerPlaceholderShimmer)
        )
    }
    
    public func encode(to encoder: Encoder) throws {
        var values = encoder.container(keyedBy: CodingKeys.self)
        try values.encode(self.incoming, forKey: .incoming)
        try values.encode(self.outgoing, forKey: .outgoing)
        try values.encode(self.freeform, forKey: .freeform)
        try encodeColor(&values, self.infoPrimaryTextColor, .infoPrimaryText)
        try encodeColor(&values, self.infoLinkTextColor, .infoLinkText)
        try encodeColor(&values, self.outgoingCheckColor, .outgoingCheck)
        try encodeColor(&values, self.mediaDateAndStatusFillColor, .mediaDateAndStatusBg)
        try encodeColor(&values, self.mediaDateAndStatusTextColor, .mediaDateAndStatusText)
        try values.encode(self.shareButtonFillColor, forKey: .shareButtonBg)
        try values.encode(self.shareButtonStrokeColor, forKey: .shareButtonStroke)
        try values.encode(self.shareButtonForegroundColor, forKey: .shareButtonFg)
        try values.encode(self.mediaOverlayControlColors, forKey: .mediaOverlayControl)
        try values.encode(self.selectionControlColors, forKey: .selectionControl)
        try values.encode(self.deliveryFailedColors, forKey: .deliveryFailed)
        try encodeColor(&values, self.mediaHighlightOverlayColor, .mediaHighlightOverlay)
        try values.encode(self.stickerPlaceholderColor, forKey: .stickerPlaceholder)
        try values.encode(self.stickerPlaceholderShimmerColor, forKey: .stickerPlaceholderShimmer)
    }
}

extension PresentationThemeServiceMessageColorComponents: Codable {
    enum CodingKeys: String, CodingKey {
        case bg
        case primaryText
        case linkHighlight
        case scam
        case dateFillStatic
        case dateFillFloat
    }
    
    public convenience init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        self.init(fill: try decodeColor(values, .bg),
                  primaryText: try decodeColor(values, .primaryText),
                  linkHighlight: try decodeColor(values, .linkHighlight),
                  scam: try decodeColor(values, .scam),
                  dateFillStatic: try decodeColor(values, .dateFillStatic),
                  dateFillFloating: try decodeColor(values, .dateFillFloat))
    }
    
    public func encode(to encoder: Encoder) throws {
        var values = encoder.container(keyedBy: CodingKeys.self)
        try encodeColor(&values, self.fill, .bg)
        try encodeColor(&values, self.primaryText, .primaryText)
        try encodeColor(&values, self.linkHighlight, .linkHighlight)
        try encodeColor(&values, self.scam, .scam)
        try encodeColor(&values, self.dateFillStatic, .dateFillStatic)
        try encodeColor(&values, self.dateFillFloating, .dateFillFloat)
    }
}

extension PresentationThemeServiceMessageColor: Codable {
    enum CodingKeys: String, CodingKey {
        case withDefaultWp
        case withCustomWp
    }
    
    public convenience init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        self.init(withDefaultWallpaper: try values.decode(PresentationThemeServiceMessageColorComponents.self, forKey: .withDefaultWp),
                  withCustomWallpaper: try values.decode(PresentationThemeServiceMessageColorComponents.self, forKey: .withCustomWp))
    }
    
    public func encode(to encoder: Encoder) throws {
        var values = encoder.container(keyedBy: CodingKeys.self)
        try values.encode(self.withDefaultWallpaper, forKey: .withDefaultWp)
        try values.encode(self.withCustomWallpaper, forKey: .withCustomWp)
    }
}

extension PresentationThemeServiceMessage: Codable {
    enum CodingKeys: String, CodingKey {
        case components
        case unreadBarBg
        case unreadBarStroke
        case unreadBarText
        case dateText
    }
    
    public convenience init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        self.init(components: try values.decode(PresentationThemeServiceMessageColor.self, forKey: .components),
                  unreadBarFillColor: try decodeColor(values, .unreadBarBg),
                  unreadBarStrokeColor: try decodeColor(values, .unreadBarStroke),
                  unreadBarTextColor: try decodeColor(values, .unreadBarText),
                  dateTextColor: try values.decode(PresentationThemeVariableColor.self, forKey: .dateText))
    }
    
    public func encode(to encoder: Encoder) throws {
        var values = encoder.container(keyedBy: CodingKeys.self)
        try values.encode(self.components, forKey: .components)
        try encodeColor(&values, self.unreadBarFillColor, .unreadBarBg)
        try encodeColor(&values, self.unreadBarStrokeColor, .unreadBarStroke)
        try encodeColor(&values, self.unreadBarTextColor, .unreadBarText)
        try values.encode(self.dateTextColor, forKey: .dateText)
    }
}

extension PresentationThemeChatInputPanelMediaRecordingControl: Codable {
    enum CodingKeys: String, CodingKey {
        case button
        case micLevel
        case activeIcon
    }
    
    public convenience init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        self.init(buttonColor: try decodeColor(values, .button),
                  micLevelColor: try decodeColor(values, .micLevel),
                  activeIconColor: try decodeColor(values, .activeIcon))
    }
    
    public func encode(to encoder: Encoder) throws {
        var values = encoder.container(keyedBy: CodingKeys.self)
        try encodeColor(&values, self.buttonColor, .button)
        try encodeColor(&values, self.micLevelColor, .micLevel)
        try encodeColor(&values, self.activeIconColor, .activeIcon)
    }
}

extension PresentationThemeChatInputPanel: Codable {
    enum CodingKeys: String, CodingKey {
        case panelBg
        case panelBgNoWallpaper
        case panelSeparator
        case panelControlAccent
        case panelControl
        case panelControlDisabled
        case panelControlDestructive
        case inputBg
        case inputStroke
        case inputPlaceholder
        case inputText
        case inputControl
        case actionControlBg
        case actionControlFg
        case primaryText
        case secondaryText
        case mediaRecordDot
        case mediaRecordControl
    }
    
    public convenience init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        let codingPath = decoder.codingPath.map { $0.stringValue }.joined(separator: ".")
        self.init(panelBackgroundColor: try decodeColor(values, .panelBg),
                  panelBackgroundColorNoWallpaper: try decodeColor(values, .panelBg, decoder: decoder, fallbackKey: "\(codingPath).panelBgNoWallpaper"),
                  panelSeparatorColor: try decodeColor(values, .panelSeparator),
                  panelControlAccentColor: try decodeColor(values, .panelControlAccent),
                  panelControlColor: try decodeColor(values, .panelControl),
                  panelControlDisabledColor: try decodeColor(values, .panelControlDisabled),
                  panelControlDestructiveColor: try decodeColor(values, .panelControlDestructive),
                  inputBackgroundColor: try decodeColor(values, .inputBg),
                  inputStrokeColor: try decodeColor(values, .inputStroke),
                  inputPlaceholderColor: try decodeColor(values, .inputPlaceholder),
                  inputTextColor: try decodeColor(values, .inputText),
                  inputControlColor: try decodeColor(values, .inputControl),
                  actionControlFillColor: try decodeColor(values, .actionControlBg),
                  actionControlForegroundColor: try decodeColor(values, .actionControlFg),
                  primaryTextColor: try decodeColor(values, .primaryText),
                  secondaryTextColor: try decodeColor(values, .secondaryText),
                  mediaRecordingDotColor: try decodeColor(values, .mediaRecordDot),
                  mediaRecordingControl: try values.decode(PresentationThemeChatInputPanelMediaRecordingControl.self, forKey: .mediaRecordControl))
    }
    
    public func encode(to encoder: Encoder) throws {
        var values = encoder.container(keyedBy: CodingKeys.self)
        try encodeColor(&values, self.panelBackgroundColor, .panelBg)
        try encodeColor(&values, self.panelSeparatorColor, .panelSeparator)
        try encodeColor(&values, self.panelControlAccentColor, .panelControlAccent)
        try encodeColor(&values, self.panelControlColor, .panelControl)
        try encodeColor(&values, self.panelControlDisabledColor, .panelControlDisabled)
        try encodeColor(&values, self.panelControlDestructiveColor, .panelControlDestructive)
        try encodeColor(&values, self.inputBackgroundColor, .inputBg)
        try encodeColor(&values, self.inputStrokeColor, .inputStroke)
        try encodeColor(&values, self.inputPlaceholderColor, .inputPlaceholder)
        try encodeColor(&values, self.inputTextColor, .inputText)
        try encodeColor(&values, self.inputControlColor, .inputControl)
        try encodeColor(&values, self.actionControlFillColor, .actionControlBg)
        try encodeColor(&values, self.actionControlForegroundColor, .actionControlFg)
        try encodeColor(&values, self.primaryTextColor, .primaryText)
        try encodeColor(&values, self.secondaryTextColor, .secondaryText)
        try encodeColor(&values, self.mediaRecordingDotColor, .mediaRecordDot)
        try values.encode(self.mediaRecordingControl, forKey: .mediaRecordControl)
    }
}

extension PresentationThemeInputMediaPanel: Codable {
    enum CodingKeys: String, CodingKey {
        case panelSeparator
        case panelIcon
        case panelHighlightedIconBg
        case panelHighlightedIcon
        case panelContentVibrantOverlay
        case panelContentControlVibrantOverlay
        case panelContentControlVibrantSelection
        case panelContentControlOpaqueOverlay
        case panelContentControlOpaqueSelection
        case stickersBg
        case stickersSectionText
        case stickersSearchBg
        case stickersSearchPlaceholder
        case stickersSearchPrimary
        case stickersSearchControl
        case gifsBg
        case bg
    }
    
    public convenience init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        
        let backgroundColor: UIColor
        if let value = try? decodeColor(values, .bg) {
            backgroundColor = value
        } else {
            backgroundColor = try decodeColor(values, .gifsBg).withMultipliedAlpha(0.75)
        }
        
        let panelHighlightedIconColor: UIColor
        if let value = try? decodeColor(values, .panelHighlightedIcon) {
            panelHighlightedIconColor = value
        } else if let value = try? decodeColor(values, .panelHighlightedIcon, fallbackKey: "chat.inputPanel.inputText") {
            let defaultColor = try decodeColor(values, .panelIcon)
            panelHighlightedIconColor = defaultColor.mixedWith(value, alpha: 0.35)
        } else {
            panelHighlightedIconColor = try decodeColor(values, .panelIcon)
        }
        
        let codingPath = decoder.codingPath.map { $0.stringValue }.joined(separator: ".")
        
        self.init(panelSeparatorColor: try decodeColor(values, .panelSeparator),
                  panelIconColor: try decodeColor(values, .panelIcon),
                  panelHighlightedIconBackgroundColor: try decodeColor(values, .panelHighlightedIconBg),
                  panelHighlightedIconColor: panelHighlightedIconColor,
                  panelContentVibrantOverlayColor: try decodeColor(values, .panelContentVibrantOverlay, fallbackKey: "\(codingPath).stickersSectionText"),
                  panelContentControlVibrantOverlayColor: try decodeColor(values, .panelContentControlVibrantOverlay, fallbackKey: "\(codingPath).stickersSectionText"),
                  panelContentControlVibrantSelectionColor: try decodeColor(values, .panelContentControlVibrantSelection, fallbackKey: "\(codingPath).stickersSectionText"),
                  panelContentControlOpaqueOverlayColor: try decodeColor(values, .panelContentControlOpaqueOverlay, fallbackKey: "\(codingPath).stickersSectionText"),
                  panelContentControlOpaqueSelectionColor: try decodeColor(values, .panelContentControlOpaqueSelection, fallbackKey: "\(codingPath).stickersSectionText"),
                  stickersBackgroundColor: try decodeColor(values, .stickersBg),
                  stickersSectionTextColor: try decodeColor(values, .stickersSectionText),
                  stickersSearchBackgroundColor: try decodeColor(values, .stickersSearchBg),
                  stickersSearchPlaceholderColor: try decodeColor(values, .stickersSearchPlaceholder),
                  stickersSearchPrimaryColor: try decodeColor(values, .stickersSearchPrimary),
                  stickersSearchControlColor: try decodeColor(values, .stickersSearchControl),
                  gifsBackgroundColor: try decodeColor(values, .gifsBg), backgroundColor: backgroundColor)
    }
    
    public func encode(to encoder: Encoder) throws {
        var values = encoder.container(keyedBy: CodingKeys.self)
        try encodeColor(&values, self.panelSeparatorColor, .panelSeparator)
        try encodeColor(&values, self.panelIconColor, .panelIcon)
        try encodeColor(&values, self.panelHighlightedIconBackgroundColor, .panelHighlightedIconBg)
        try encodeColor(&values, self.panelHighlightedIconColor, .panelHighlightedIcon)
        try encodeColor(&values, self.panelContentVibrantOverlayColor, .panelContentVibrantOverlay)
        try encodeColor(&values, self.panelContentControlVibrantOverlayColor, .panelContentControlVibrantOverlay)
        try encodeColor(&values, self.panelContentControlVibrantSelectionColor, .panelContentControlVibrantSelection)
        try encodeColor(&values, self.panelContentControlOpaqueOverlayColor, .panelContentControlOpaqueOverlay)
        try encodeColor(&values, self.panelContentControlOpaqueSelectionColor, .panelContentControlOpaqueSelection)
        try encodeColor(&values, self.stickersBackgroundColor, .stickersBg)
        try encodeColor(&values, self.stickersSectionTextColor, .stickersSectionText)
        try encodeColor(&values, self.stickersSearchBackgroundColor, .stickersSearchBg)
        try encodeColor(&values, self.stickersSearchPlaceholderColor, .stickersSearchPlaceholder)
        try encodeColor(&values, self.stickersSearchPrimaryColor, .stickersSearchPrimary)
        try encodeColor(&values, self.stickersSearchControlColor, .stickersSearchControl)
        try encodeColor(&values, self.gifsBackgroundColor, .gifsBg)
        try encodeColor(&values, self.backgroundColor, .bg)
    }
}

extension PresentationThemeInputButtonPanel: Codable {
    enum CodingKeys: String, CodingKey {
        case panelBg
        case panelSeparator
        case buttonBg
        case buttonStroke
        case buttonHighlightedBg
        case buttonHighlightedStroke
        case buttonText
    }
    
    public convenience init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        self.init(panelSeparatorColor: try decodeColor(values, .panelSeparator),
                  panelBackgroundColor: try decodeColor(values, .panelBg),
                  buttonFillColor: try decodeColor(values, .buttonBg),
                  buttonStrokeColor: try decodeColor(values, .buttonStroke),
                  buttonHighlightedFillColor: try decodeColor(values, .buttonHighlightedBg),
                  buttonHighlightedStrokeColor: try decodeColor(values, .buttonHighlightedStroke),
                  buttonTextColor: try decodeColor(values, .buttonText))
    }
    
    public func encode(to encoder: Encoder) throws {
        var values = encoder.container(keyedBy: CodingKeys.self)
        try encodeColor(&values, self.panelBackgroundColor, .panelBg)
        try encodeColor(&values, self.panelSeparatorColor, .panelSeparator)
        try encodeColor(&values, self.buttonFillColor, .buttonBg)
        try encodeColor(&values, self.buttonStrokeColor, .buttonStroke)
        try encodeColor(&values, self.buttonHighlightedFillColor, .buttonHighlightedBg)
        try encodeColor(&values, self.buttonHighlightedStrokeColor, .buttonHighlightedStroke)
        try encodeColor(&values, self.buttonTextColor, .buttonText)
    }
}

extension PresentationThemeChatHistoryNavigation: Codable {
    enum CodingKeys: String, CodingKey {
        case bg
        case stroke
        case fg
        case badgeBg
        case badgeStroke
        case badgeText
    }
    
    public convenience init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        self.init(fillColor: try decodeColor(values, .bg),
                  strokeColor: try decodeColor(values, .stroke),
                  foregroundColor: try decodeColor(values, .fg),
                  badgeBackgroundColor: try decodeColor(values, .badgeBg),
                  badgeStrokeColor: try decodeColor(values, .badgeStroke),
                  badgeTextColor: try decodeColor(values, .badgeText))
    }
    
    public func encode(to encoder: Encoder) throws {
        var values = encoder.container(keyedBy: CodingKeys.self)
        try encodeColor(&values, self.fillColor, .bg)
        try encodeColor(&values, self.strokeColor, .stroke)
        try encodeColor(&values, self.foregroundColor, .fg)
        try encodeColor(&values, self.badgeBackgroundColor, .badgeBg)
        try encodeColor(&values, self.badgeStrokeColor, .badgeStroke)
        try encodeColor(&values, self.badgeTextColor, .badgeText)
    }
}

extension PresentationThemeChat: Codable {
    enum CodingKeys: String, CodingKey {
        case defaultWallpaper
        case message
        case animateMessageColors
        case serviceMessage
        case inputPanel
        case inputMediaPanel
        case inputButtonPanel
        case historyNav
    }
    
    public convenience init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        
        var wallpaper = (try values.decode(TelegramWallpaperStandardizedCodable.self, forKey: .defaultWallpaper)).value
        if let decoder = decoder as? PresentationThemeDecoding {
            if case .file = wallpaper, let resolvedWallpaper = decoder.resolvedWallpaper {
                wallpaper = resolvedWallpaper
            }
        }
    
        self.init(defaultWallpaper: wallpaper,
                  animateMessageColors: (try? values.decode(Bool.self, forKey: .animateMessageColors)) ?? false,
                  message: try values.decode(PresentationThemeChatMessage.self, forKey: .message),
                  serviceMessage: try values.decode(PresentationThemeServiceMessage.self, forKey: .serviceMessage),
                  inputPanel: try values.decode(PresentationThemeChatInputPanel.self, forKey: .inputPanel),
                  inputMediaPanel: try values.decode(PresentationThemeInputMediaPanel.self, forKey: .inputMediaPanel),
                  inputButtonPanel: try values.decode(PresentationThemeInputButtonPanel.self, forKey: .inputButtonPanel),
                  historyNavigation: try values.decode(PresentationThemeChatHistoryNavigation.self, forKey: .historyNav))
    }
    
    public func encode(to encoder: Encoder) throws {
        var values = encoder.container(keyedBy: CodingKeys.self)
        try values.encode(TelegramWallpaperStandardizedCodable(self.defaultWallpaper), forKey: .defaultWallpaper)
        try values.encode(self.animateMessageColors, forKey: .animateMessageColors)
        try values.encode(self.message, forKey: .message)
        try values.encode(self.serviceMessage, forKey: .serviceMessage)
        try values.encode(self.inputPanel, forKey: .inputPanel)
        try values.encode(self.inputMediaPanel, forKey: .inputMediaPanel)
        try values.encode(self.inputButtonPanel, forKey: .inputButtonPanel)
        try values.encode(self.historyNavigation, forKey: .historyNav)
    }
}

extension PresentationThemeExpandedNotificationNavigationBar: Codable {
    enum CodingKeys: String, CodingKey {
        case background
        case primaryText
        case control
        case separator
    }
    
    public convenience init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        self.init(backgroundColor: try decodeColor(values, .background),
                  primaryTextColor: try decodeColor(values, .primaryText),
                  controlColor: try decodeColor(values, .control),
                  separatorColor: try decodeColor(values, .separator))
    }
    
    public func encode(to encoder: Encoder) throws {
        var values = encoder.container(keyedBy: CodingKeys.self)
        try encodeColor(&values, self.backgroundColor, .background)
        try encodeColor(&values, self.primaryTextColor, .primaryText)
        try encodeColor(&values, self.controlColor, .control)
        try encodeColor(&values, self.separatorColor, .separator)
    }
}

extension PresentationThemeExpandedNotification: Codable {
    enum CodingKeys: String, CodingKey {
        case bgType
        case navBar
    }
    
    public convenience init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        self.init(backgroundType: try values.decode(PresentationThemeExpandedNotificationBackgroundType.self, forKey: .bgType),
                  navigationBar: try values.decode(PresentationThemeExpandedNotificationNavigationBar.self, forKey: .navBar))
    }
    
    public func encode(to encoder: Encoder) throws {
        var values = encoder.container(keyedBy: CodingKeys.self)
        try values.encode(self.backgroundType, forKey: .bgType)
        try values.encode(self.navigationBar, forKey: .navBar)
    }
}

extension PresentationThemeContextMenu: Codable {
    enum CodingKeys: String, CodingKey {
        case dim
        case background
        case itemSeparator
        case sectionSeparator
        case itemBg
        case itemHighlightedBg
        case primary
        case secondary
        case destructive
        case badgeFill
        case badgeForeground
        case badgeInactiveFill
        case badgeInactiveForeground
        case extractedTint
    }
    
    public convenience init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        let destructiveColor = try decodeColor(values, .destructive)
        let backgroundColor = try decodeColor(values, .background)
        self.init(
            dimColor: try decodeColor(values, .dim),
            backgroundColor: backgroundColor,
            itemSeparatorColor: try decodeColor(values, .itemSeparator),
            sectionSeparatorColor: try decodeColor(values, .sectionSeparator),
            itemBackgroundColor: try decodeColor(values, .itemBg),
            itemHighlightedBackgroundColor: try decodeColor(values, .itemHighlightedBg),
            primaryColor: try decodeColor(values, .primary),
            secondaryColor: try decodeColor(values, .secondary),
            destructiveColor: destructiveColor,
            badgeFillColor: (try? decodeColor(values, .badgeFill)) ?? destructiveColor,
            badgeForegroundColor: (try? decodeColor(values, .badgeForeground)) ?? backgroundColor,
            badgeInactiveFillColor: (try? decodeColor(values, .badgeInactiveFill)) ?? destructiveColor,
            badgeInactiveForegroundColor: (try? decodeColor(values, .badgeInactiveForeground)) ?? backgroundColor,
            extractedContentTintColor: (try? decodeColor(values, .extractedTint)) ?? backgroundColor
        )
    }
    
    public func encode(to encoder: Encoder) throws {
        var values = encoder.container(keyedBy: CodingKeys.self)
        try encodeColor(&values, self.dimColor, .dim)
        try encodeColor(&values, self.backgroundColor, .background)
        try encodeColor(&values, self.itemSeparatorColor, .itemSeparator)
        try encodeColor(&values, self.sectionSeparatorColor, .sectionSeparator)
        try encodeColor(&values, self.itemBackgroundColor, .itemBg)
        try encodeColor(&values, self.itemHighlightedBackgroundColor, .itemHighlightedBg)
        try encodeColor(&values, self.primaryColor, .primary)
        try encodeColor(&values, self.secondaryColor, .secondary)
        try encodeColor(&values, self.destructiveColor, .destructive)
    }
}

extension PresentationThemeInAppNotification: Codable {
    enum CodingKeys: String, CodingKey {
        case bg
        case primaryText
        case expanded
    }
    
    public convenience init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        self.init(fillColor: try decodeColor(values, .bg),
                  primaryTextColor: try decodeColor(values, .primaryText),
                  expandedNotification: try values.decode(PresentationThemeExpandedNotification.self, forKey: .expanded))
    }
    
    public func encode(to encoder: Encoder) throws {
        var values = encoder.container(keyedBy: CodingKeys.self)
        try encodeColor(&values, self.fillColor, .bg)
        try encodeColor(&values, self.primaryTextColor, .primaryText)
        try values.encode(self.expandedNotification, forKey: .expanded)
    }
}

extension PresentationThemeChart: Codable {
    enum CodingKeys: String, CodingKey {
        case labels
        case helperLines
        case strongLines
        case barStrongLines
        case detailsText
        case detailsArrow
        case detailsView
        case rangeViewFrame
        case rangeViewMarker
    }
    
    public convenience init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        self.init(labelsColor: try decodeColor(values, .labels), helperLinesColor: try decodeColor(values, .helperLines), strongLinesColor: try decodeColor(values, .strongLines), barStrongLinesColor: try decodeColor(values, .barStrongLines), detailsTextColor: try decodeColor(values, .detailsText), detailsArrowColor: try decodeColor(values, .detailsArrow), detailsViewColor: try decodeColor(values, .detailsView), rangeViewFrameColor: try decodeColor(values, .rangeViewFrame), rangeViewMarkerColor: try decodeColor(values, .rangeViewMarker))
    }
    
    public func encode(to encoder: Encoder) throws {
        var values = encoder.container(keyedBy: CodingKeys.self)
        
        try encodeColor(&values, self.labelsColor, .labels)
        try encodeColor(&values, self.helperLinesColor, .helperLines)
        try encodeColor(&values, self.strongLinesColor, .strongLines)
        try encodeColor(&values, self.barStrongLinesColor, .barStrongLines)
        try encodeColor(&values, self.detailsTextColor, .detailsText)
        try encodeColor(&values, self.detailsArrowColor, .detailsArrow)
        try encodeColor(&values, self.detailsViewColor, .detailsView)
        try encodeColor(&values, self.rangeViewFrameColor, .rangeViewFrame)
        try encodeColor(&values, self.rangeViewMarkerColor, .rangeViewMarker)
    }
}

extension PresentationThemeName: Codable {
    public init(from decoder: Decoder) throws {
        let value = try decoder.singleValueContainer()
        self = .custom(try value.decode(String.self))
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
            case let .builtin(name):
                switch name {
                    case .day:
                        try container.encode("Day")
                    case .dayClassic:
                        try container.encode("Classic")
                    case .nightAccent:
                        try container.encode("Night Tinted")
                    case .night:
                        try container.encode("Night")
                }
            case let .custom(name):
                try container.encode(name)
        }
    }
}

extension PresentationBuiltinThemeReference: Codable {
    public init(from decoder: Decoder) throws {
        let values = try decoder.singleValueContainer()
        if let value = try? values.decode(String.self) {
            switch value.lowercased() {
                case "day":
                    self = .day
                case "classic":
                    self = .dayClassic
                case "nighttinted":
                    self = .nightAccent
                case "night":
                    self = .night
                default:
                    self = .dayClassic
            }
        } else {
            self = .dayClassic
        }
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
            case .day:
                try container.encode("day")
            case .dayClassic:
                try container.encode("classic")
            case .nightAccent:
                try container.encode("nighttinted")
            case .night:
                try container.encode("night")
        }
    }
}

extension PresentationTheme: Codable {
    enum CodingKeys: String, CodingKey {
        case name
        case basedOn
        case dark
        case intro
        case passcode
        case root
        case list
        case chatList
        case chat
        case actionSheet
        case contextMenu
        case notification
        case chart
    }
    
    public convenience init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        let referenceTheme: PresentationBuiltinThemeReference
        if let theme = try? values.decode(PresentationBuiltinThemeReference.self, forKey: .basedOn) {
            referenceTheme = theme
        } else {
            referenceTheme = .dayClassic
        }
        
        let index: Int64
        if let decoder = decoder as? PresentationThemeDecoding {
            let serviceBackgroundColor = decoder.serviceBackgroundColor ?? defaultServiceBackgroundColor
            decoder.referenceTheme = makeDefaultPresentationTheme(reference: referenceTheme, serviceBackgroundColor: serviceBackgroundColor)
            index = decoder.reference?.index ?? Int64.random(in: Int64.min ... Int64.max)
        } else {
            index = Int64.random(in: Int64.min ... Int64.max)
        }
        
        self.init(name: (try? values.decode(PresentationThemeName.self, forKey: .name)) ?? .custom("Untitled"),
                  index: index,
                  referenceTheme: referenceTheme,
                  overallDarkAppearance: (try? values.decode(Bool.self, forKey: .dark)) ?? false,
                  intro: try values.decode(PresentationThemeIntro.self, forKey: .intro),
                  passcode: try values.decode(PresentationThemePasscode.self, forKey: .passcode),
                  rootController: try values.decode(PresentationThemeRootController.self, forKey: .root),
                  list: try values.decode(PresentationThemeList.self, forKey: .list),
                  chatList: try values.decode(PresentationThemeChatList.self, forKey: .chatList),
                  chat: try values.decode(PresentationThemeChat.self, forKey: .chat),
                  actionSheet: try values.decode(PresentationThemeActionSheet.self, forKey: .actionSheet),
                  contextMenu: try values.decode(PresentationThemeContextMenu.self, forKey: .contextMenu),
                  inAppNotification: try values.decode(PresentationThemeInAppNotification.self, forKey: .notification),
                  chart: try values.decode(PresentationThemeChart.self, forKey: .chart)
        )
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(self.name, forKey: .name)
        try container.encode(self.referenceTheme, forKey: .basedOn)
        try container.encode(self.overallDarkAppearance, forKey: .dark)
        try container.encode(self.intro, forKey: .intro)
        try container.encode(self.passcode, forKey: .passcode)
        try container.encode(self.rootController, forKey: .root)
        try container.encode(self.list, forKey: .list)
        try container.encode(self.chatList, forKey: .chatList)
        try container.encode(self.chat, forKey: .chat)
        try container.encode(self.actionSheet, forKey: .actionSheet)
        try container.encode(self.contextMenu, forKey: .contextMenu)
        try container.encode(self.inAppNotification, forKey: .notification)
        try container.encode(self.chart, forKey: .chart)
    }
}
