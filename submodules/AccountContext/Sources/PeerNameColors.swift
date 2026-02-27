import Foundation
import UIKit
import TelegramCore

private extension PeerNameColors.Colors {
    init?(colors: EngineAvailableColorOptions.MultiColorPack) {
        if colors.colors.isEmpty {
            return nil
        }
        self.main = UIColor(rgb: colors.colors[0])
        if colors.colors.count > 1 {
            self.secondary = UIColor(rgb: colors.colors[1])
        } else {
            self.secondary = nil
        }
        if colors.colors.count > 2 {
            self.tertiary = UIColor(rgb: colors.colors[2])
        } else {
            self.tertiary = nil
        }
    }
}

public class PeerNameColors: Equatable {
    public enum Subject {
        case background
        case palette
        case stories
    }
    
    public struct Colors: Equatable {
        public let main: UIColor
        public let secondary: UIColor?
        public let tertiary: UIColor?
        
        public init(main: UIColor, secondary: UIColor?, tertiary: UIColor?) {
            self.main = main
            self.secondary = secondary
            self.tertiary = tertiary
        }
        
        public init(main: UIColor) {
            self.main = main
            self.secondary = nil
            self.tertiary = nil
        }
        
        public init?(colors: [UIColor]) {
            guard let first = colors.first else {
                return nil
            }
            self.main = first
            if colors.count == 3 {
                self.secondary = colors[1]
                self.tertiary = colors[2]
            } else if colors.count == 2, let second = colors.last {
                self.secondary = second
                self.tertiary = nil
            } else {
                self.secondary = nil
                self.tertiary = nil
            }
        }
    }
    
    public static var defaultSingleColors: [Int32: Colors] {
        return [
            0: Colors(main: UIColor(rgb: 0xcc5049)),
            1: Colors(main: UIColor(rgb: 0xd67722)),
            2: Colors(main: UIColor(rgb: 0x955cdb)),
            3: Colors(main: UIColor(rgb: 0x40a920)),
            4: Colors(main: UIColor(rgb: 0x309eba)),
            5: Colors(main: UIColor(rgb: 0x368ad1)),
            6: Colors(main: UIColor(rgb: 0xc7508b))
        ]
    }
    
    public static var defaultValue: PeerNameColors {
        return PeerNameColors(
            colors: defaultSingleColors,
            darkColors: [:],
            displayOrder: [5, 3, 1, 0, 2, 4, 6],
            chatFolderTagDisplayOrder: [5, 3, 1, 0, 2, 4, 6],
            profileColors: [:],
            profileDarkColors: [:],
            profilePaletteColors: [:],
            profilePaletteDarkColors: [:],
            profileStoryColors: [:],
            profileStoryDarkColors: [:],
            profileDisplayOrder: [],
            nameColorsChannelMinRequiredBoostLevel: [:],
            profileColorsChannelMinRequiredBoostLevel: [:],
            profileColorsGroupMinRequiredBoostLevel: [:]
        )
    }
    
    public let colors: [Int32: Colors]
    public let darkColors: [Int32: Colors]
    public let displayOrder: [Int32]
    
    public let chatFolderTagDisplayOrder: [Int32]
    
    public let profileColors: [Int32: Colors]
    public let profileDarkColors: [Int32: Colors]
    public let profilePaletteColors: [Int32: Colors]
    public let profilePaletteDarkColors: [Int32: Colors]
    public let profileStoryColors: [Int32: Colors]
    public let profileStoryDarkColors: [Int32: Colors]
    public let profileDisplayOrder: [Int32]
    
    public let nameColorsChannelMinRequiredBoostLevel: [Int32: Int32]
    public let profileColorsChannelMinRequiredBoostLevel: [Int32: Int32]
    public let profileColorsGroupMinRequiredBoostLevel: [Int32: Int32]
    
    public func get(_ color: PeerNameColor, dark: Bool = false) -> Colors {
        if dark, let colors = self.darkColors[color.rawValue] {
            return colors
        } else if let colors = self.colors[color.rawValue] {
            return colors
        } else {
            return PeerNameColors.defaultSingleColors[5]!
        }
    }
    
    public func getChatFolderTag(_ color: PeerNameColor, dark: Bool = false) -> Colors {
        if dark, let colors = self.darkColors[color.rawValue] {
            return colors
        } else if let colors = self.colors[color.rawValue] {
            return colors
        } else {
            return PeerNameColors.defaultSingleColors[5]!
        }
    }
    
    public func getProfile(_ color: PeerNameColor, dark: Bool = false, subject: Subject = .background) -> Colors {
        switch subject {
        case .background:
            if dark, let colors = self.profileDarkColors[color.rawValue] {
                return colors
            } else if let colors = self.profileColors[color.rawValue] {
                return colors
            } else {
                return Colors(main: UIColor(rgb: 0xcc5049))
            }
        case .palette:
            if dark, let colors = self.profilePaletteDarkColors[color.rawValue] {
                return colors
            } else if let colors = self.profilePaletteColors[color.rawValue] {
                return colors
            } else {
                return self.getProfile(color, dark: dark, subject: .background)
            }
        case .stories:
            if dark, let colors = self.profileStoryDarkColors[color.rawValue] {
                return colors
            } else if let colors = self.profileStoryColors[color.rawValue] {
                return colors
            } else {
                return self.getProfile(color, dark: dark, subject: .background)
            }
        }
    }
    
    fileprivate init(
        colors: [Int32: Colors],
        darkColors: [Int32: Colors],
        displayOrder: [Int32],
        chatFolderTagDisplayOrder: [Int32],
        profileColors: [Int32: Colors],
        profileDarkColors: [Int32: Colors],
        profilePaletteColors: [Int32: Colors],
        profilePaletteDarkColors: [Int32: Colors],
        profileStoryColors: [Int32: Colors],
        profileStoryDarkColors: [Int32: Colors],
        profileDisplayOrder: [Int32],
        nameColorsChannelMinRequiredBoostLevel: [Int32: Int32],
        profileColorsChannelMinRequiredBoostLevel: [Int32: Int32],
        profileColorsGroupMinRequiredBoostLevel: [Int32: Int32]
    ) {
        self.colors = colors
        self.darkColors = darkColors
        self.displayOrder = displayOrder
        self.chatFolderTagDisplayOrder = chatFolderTagDisplayOrder
        self.profileColors = profileColors
        self.profileDarkColors = profileDarkColors
        self.profilePaletteColors = profilePaletteColors
        self.profilePaletteDarkColors = profilePaletteDarkColors
        self.profileStoryColors = profileStoryColors
        self.profileStoryDarkColors = profileStoryDarkColors
        self.profileDisplayOrder = profileDisplayOrder
        self.nameColorsChannelMinRequiredBoostLevel = nameColorsChannelMinRequiredBoostLevel
        self.profileColorsChannelMinRequiredBoostLevel = profileColorsChannelMinRequiredBoostLevel
        self.profileColorsGroupMinRequiredBoostLevel = profileColorsGroupMinRequiredBoostLevel
    }
    
    public static func with(availableReplyColors: EngineAvailableColorOptions, availableProfileColors: EngineAvailableColorOptions) -> PeerNameColors {
        var colors: [Int32: Colors] = [:]
        var darkColors: [Int32: Colors] = [:]
        var displayOrder: [Int32] = []
        var profileColors: [Int32: Colors] = [:]
        var profileDarkColors: [Int32: Colors] = [:]
        var profilePaletteColors: [Int32: Colors] = [:]
        var profilePaletteDarkColors: [Int32: Colors] = [:]
        var profileStoryColors: [Int32: Colors] = [:]
        var profileStoryDarkColors: [Int32: Colors] = [:]
        var profileDisplayOrder: [Int32] = []
        
        var nameColorsChannelMinRequiredBoostLevel: [Int32: Int32] = [:]
        var profileColorsChannelMinRequiredBoostLevel: [Int32: Int32] = [:]
        var profileColorsGroupMinRequiredBoostLevel: [Int32: Int32] = [:]
        
        if !availableReplyColors.options.isEmpty {
            for option in availableReplyColors.options {
                if let requiredChannelMinBoostLevel = option.value.requiredChannelMinBoostLevel {
                    nameColorsChannelMinRequiredBoostLevel[option.key] = requiredChannelMinBoostLevel
                }
                if let parsedLight = PeerNameColors.Colors(colors: option.value.light.background) {
                    colors[option.key] = parsedLight
                }
                if let parsedDark = (option.value.dark?.background).flatMap(PeerNameColors.Colors.init(colors:)) {
                    darkColors[option.key] = parsedDark
                }
                
                for option in availableReplyColors.options {
                    if !displayOrder.contains(option.key) {
                        displayOrder.append(option.key)
                    }
                }
            }
        } else {
            let defaultValue = PeerNameColors.defaultValue
            colors = defaultValue.colors
            darkColors = defaultValue.darkColors
            displayOrder = defaultValue.displayOrder
        }
            
        if !availableProfileColors.options.isEmpty {
            for option in availableProfileColors.options {
                if let requiredChannelMinBoostLevel = option.value.requiredChannelMinBoostLevel {
                    profileColorsChannelMinRequiredBoostLevel[option.key] = requiredChannelMinBoostLevel
                }
                if let requiredGroupMinBoostLevel = option.value.requiredGroupMinBoostLevel {
                    profileColorsGroupMinRequiredBoostLevel[option.key] = requiredGroupMinBoostLevel
                }
                if let parsedLight = PeerNameColors.Colors(colors: option.value.light.background) {
                    profileColors[option.key] = parsedLight
                }
                if let parsedDark = (option.value.dark?.background).flatMap(PeerNameColors.Colors.init(colors:)) {
                    profileDarkColors[option.key] = parsedDark
                }
                if let parsedPaletteLight = PeerNameColors.Colors(colors: option.value.light.palette) {
                    profilePaletteColors[option.key] = parsedPaletteLight
                }
                if let parsedPaletteDark = (option.value.dark?.palette).flatMap(PeerNameColors.Colors.init(colors:)) {
                    profilePaletteDarkColors[option.key] = parsedPaletteDark
                }
                if let parsedStoryLight = (option.value.light.stories).flatMap(PeerNameColors.Colors.init(colors:)) {
                    profileStoryColors[option.key] = parsedStoryLight
                }
                if let parsedStoryDark = (option.value.dark?.stories).flatMap(PeerNameColors.Colors.init(colors:)) {
                    profileStoryDarkColors[option.key] = parsedStoryDark
                }
                for option in availableProfileColors.options {
                    if !profileDisplayOrder.contains(option.key) {
                        profileDisplayOrder.append(option.key)
                    }
                }
            }
        }
        
        return PeerNameColors(
            colors: colors,
            darkColors: darkColors,
            displayOrder: displayOrder,
            chatFolderTagDisplayOrder: PeerNameColors.defaultValue.chatFolderTagDisplayOrder,
            profileColors: profileColors,
            profileDarkColors: profileDarkColors,
            profilePaletteColors: profilePaletteColors,
            profilePaletteDarkColors: profilePaletteDarkColors,
            profileStoryColors: profileStoryColors,
            profileStoryDarkColors: profileStoryDarkColors,
            profileDisplayOrder: profileDisplayOrder,
            nameColorsChannelMinRequiredBoostLevel: nameColorsChannelMinRequiredBoostLevel,
            profileColorsChannelMinRequiredBoostLevel: profileColorsChannelMinRequiredBoostLevel,
            profileColorsGroupMinRequiredBoostLevel: profileColorsGroupMinRequiredBoostLevel
        )
    }
    
    public static func == (lhs: PeerNameColors, rhs: PeerNameColors) -> Bool {
        if lhs.colors != rhs.colors {
            return false
        }
        if lhs.darkColors != rhs.darkColors {
            return false
        }
        if lhs.displayOrder != rhs.displayOrder {
            return false
        }
        if lhs.chatFolderTagDisplayOrder != rhs.chatFolderTagDisplayOrder {
            return false
        }
        if lhs.profileColors != rhs.profileColors {
            return false
        }
        if lhs.profileDarkColors != rhs.profileDarkColors {
            return false
        }
        if lhs.profilePaletteColors != rhs.profilePaletteColors {
            return false
        }
        if lhs.profilePaletteDarkColors != rhs.profilePaletteDarkColors {
            return false
        }
        if lhs.profileStoryColors != rhs.profileStoryColors {
            return false
        }
        if lhs.profileStoryDarkColors != rhs.profileStoryDarkColors {
            return false
        }
        if lhs.profileDisplayOrder != rhs.profileDisplayOrder {
            return false
        }
        return true
    }
}

public extension PeerCollectibleColor {
    func peerNameColors(dark: Bool) -> PeerNameColors.Colors {
        return PeerNameColors.Colors(
            main: self.mainColor(dark: dark),
            secondary: self.secondaryColor(dark: dark),
            tertiary: self.tertiaryColor(dark: dark)
        )
    }
    
    func mainColor(dark: Bool) -> UIColor {
        if dark, let darkAccentColor = self.darkAccentColor {
            return UIColor(rgb: darkAccentColor)
        } else {
            return UIColor(rgb: self.accentColor)
        }
    }
    
    func secondaryColor(dark: Bool) -> UIColor? {
        if dark, let darkColors = self.darkColors, darkColors.count > 0 {
            return UIColor(rgb: darkColors[0])
        } else if self.colors.count > 0 {
            return UIColor(rgb: self.colors[0])
        } else {
            return nil
        }
    }
    
    func tertiaryColor(dark: Bool) -> UIColor? {
        if dark, let darkColors = self.darkColors, darkColors.count > 1 {
            return UIColor(rgb: darkColors[1])
        } else if self.colors.count > 1 {
            return UIColor(rgb: self.colors[1])
        } else {
            return nil
        }
    }
}
