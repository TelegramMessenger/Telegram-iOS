import Foundation
import UIKit
import SwiftSignalKit
import Display
import OverlayStatusController

public enum WalletTimeFormat {
    case regular
    case military
}

public enum WalletDateFormat {
    case monthFirst
    case dayFirst
}

public struct WalletPresentationDateTimeFormat: Equatable {
    public let timeFormat: WalletTimeFormat
    public let dateFormat: WalletDateFormat
    public let dateSeparator: String
    public let decimalSeparator: String
    public let groupingSeparator: String
    
    public init(timeFormat: WalletTimeFormat, dateFormat: WalletDateFormat, dateSeparator: String, decimalSeparator: String, groupingSeparator: String) {
        self.timeFormat = timeFormat
        self.dateFormat = dateFormat
        self.dateSeparator = dateSeparator
        self.decimalSeparator = decimalSeparator
        self.groupingSeparator = groupingSeparator
    }
}

public final class WalletInfoTheme {
    public let buttonBackgroundColor: UIColor
    public let buttonTextColor: UIColor
    public let incomingFundsTitleColor: UIColor
    public let outgoingFundsTitleColor: UIColor
    
    public init(
        buttonBackgroundColor: UIColor,
        buttonTextColor: UIColor,
        incomingFundsTitleColor: UIColor,
        outgoingFundsTitleColor: UIColor
    ) {
        self.buttonBackgroundColor = buttonBackgroundColor
        self.buttonTextColor = buttonTextColor
        self.incomingFundsTitleColor = incomingFundsTitleColor
        self.outgoingFundsTitleColor = outgoingFundsTitleColor
    }
}

public final class WalletTransactionTheme {
    public let descriptionBackgroundColor: UIColor
    public let descriptionTextColor: UIColor
    
    public init(
        descriptionBackgroundColor: UIColor,
        descriptionTextColor: UIColor
    ) {
        self.descriptionBackgroundColor = descriptionBackgroundColor
        self.descriptionTextColor = descriptionTextColor
    }
}

public final class WalletSetupTheme {
    public let buttonFillColor: UIColor
    public let buttonForegroundColor: UIColor
    public let inputBackgroundColor: UIColor
    public let inputPlaceholderColor: UIColor
    public let inputTextColor: UIColor
    public let inputClearButtonColor: UIColor
    
    public init(
        buttonFillColor: UIColor,
        buttonForegroundColor: UIColor,
        inputBackgroundColor: UIColor,
        inputPlaceholderColor: UIColor,
        inputTextColor: UIColor,
        inputClearButtonColor: UIColor
    ) {
        self.buttonFillColor = buttonFillColor
        self.buttonForegroundColor = buttonForegroundColor
        self.inputBackgroundColor = inputBackgroundColor
        self.inputPlaceholderColor = inputPlaceholderColor
        self.inputTextColor = inputTextColor
        self.inputClearButtonColor = inputClearButtonColor
    }
}

public final class WalletListTheme {
    public let itemPrimaryTextColor: UIColor
    public let itemSecondaryTextColor: UIColor
    public let itemPlaceholderTextColor: UIColor
    public let itemDestructiveColor: UIColor
    public let itemAccentColor: UIColor
    public let itemDisabledTextColor: UIColor
    public let plainBackgroundColor: UIColor
    public let blocksBackgroundColor: UIColor
    public let itemPlainSeparatorColor: UIColor
    public let itemBlocksBackgroundColor: UIColor
    public let itemBlocksSeparatorColor: UIColor
    public let itemHighlightedBackgroundColor: UIColor
    public let sectionHeaderTextColor: UIColor
    public let freeTextColor: UIColor
    public let freeTextErrorColor: UIColor
    public let inputClearButtonColor: UIColor
    
    public init(
        itemPrimaryTextColor: UIColor,
        itemSecondaryTextColor: UIColor,
        itemPlaceholderTextColor: UIColor,
        itemDestructiveColor: UIColor,
        itemAccentColor: UIColor,
        itemDisabledTextColor: UIColor,
        plainBackgroundColor: UIColor,
        blocksBackgroundColor: UIColor,
        itemPlainSeparatorColor: UIColor,
        itemBlocksBackgroundColor: UIColor,
        itemBlocksSeparatorColor: UIColor,
        itemHighlightedBackgroundColor: UIColor,
        sectionHeaderTextColor: UIColor,
        freeTextColor: UIColor,
        freeTextErrorColor: UIColor,
        inputClearButtonColor: UIColor
    ) {
        self.itemPrimaryTextColor = itemPrimaryTextColor
        self.itemSecondaryTextColor = itemSecondaryTextColor
        self.itemPlaceholderTextColor = itemPlaceholderTextColor
        self.itemDestructiveColor = itemDestructiveColor
        self.itemAccentColor = itemAccentColor
        self.itemDisabledTextColor = itemDisabledTextColor
        self.plainBackgroundColor = plainBackgroundColor
        self.blocksBackgroundColor = blocksBackgroundColor
        self.itemPlainSeparatorColor = itemPlainSeparatorColor
        self.itemBlocksBackgroundColor = itemBlocksBackgroundColor
        self.itemBlocksSeparatorColor = itemBlocksSeparatorColor
        self.itemHighlightedBackgroundColor = itemHighlightedBackgroundColor
        self.sectionHeaderTextColor = sectionHeaderTextColor
        self.freeTextColor = freeTextColor
        self.freeTextErrorColor = freeTextErrorColor
        self.inputClearButtonColor = inputClearButtonColor
    }
}

public final class WalletTheme: Equatable {
    public let info: WalletInfoTheme
    public let transaction: WalletTransactionTheme
    public let setup: WalletSetupTheme
    public let list: WalletListTheme
    public let statusBarStyle: StatusBarStyle
    public let navigationBar: NavigationBarTheme
    public let keyboardAppearance: UIKeyboardAppearance
    public let alert: AlertControllerTheme
    public let actionSheet: ActionSheetControllerTheme
    
    private let resourceCache = WalletThemeResourceCache()
    
    public init(info: WalletInfoTheme, transaction: WalletTransactionTheme, setup: WalletSetupTheme, list: WalletListTheme, statusBarStyle: StatusBarStyle, navigationBar: NavigationBarTheme, keyboardAppearance: UIKeyboardAppearance, alert: AlertControllerTheme, actionSheet: ActionSheetControllerTheme) {
        self.info = info
        self.transaction = transaction
        self.setup = setup
        self.list = list
        self.statusBarStyle = statusBarStyle
        self.navigationBar = navigationBar
        self.keyboardAppearance = keyboardAppearance
        self.alert = alert
        self.actionSheet = actionSheet
    }
    
    func image(_ key: Int32, _ generate: (WalletTheme) -> UIImage?) -> UIImage? {
        return self.resourceCache.image(key, self, generate)
    }
    
    public static func ==(lhs: WalletTheme, rhs: WalletTheme) -> Bool {
        return lhs === rhs
    }
}

public final class WalletPresentationData {
    public let theme: WalletTheme
    public let strings: WalletStrings
    public let dateTimeFormat: WalletPresentationDateTimeFormat
    
    public init(theme: WalletTheme, strings: WalletStrings, dateTimeFormat: WalletPresentationDateTimeFormat) {
        self.theme = theme
        self.strings = strings
        self.dateTimeFormat = dateTimeFormat
    }
}

private final class WalletThemeResourceCacheHolder {
    var images: [Int32: UIImage] = [:]
}

private final class WalletThemeResourceCache {
    private let imageCache = Atomic<WalletThemeResourceCacheHolder>(value: WalletThemeResourceCacheHolder())
    
    public func image(_ key: Int32, _ theme: WalletTheme, _ generate: (WalletTheme) -> UIImage?) -> UIImage? {
        let result = self.imageCache.with { holder -> UIImage? in
            return holder.images[key]
        }
        if let result = result {
            return result
        } else {
            if let image = generate(theme) {
                self.imageCache.with { holder -> Void in
                    holder.images[key] = image
                }
                return image
            } else {
                return nil
            }
        }
    }
}

enum WalletThemeResourceKey: Int32 {
    case itemListCornersBoth
    case itemListCornersTop
    case itemListCornersBottom
    case itemListClearInputIcon
    case itemListDisclosureArrow
    case navigationShareIcon
    
    case clockMin
    case clockFrame
}

func cornersImage(_ theme: WalletTheme, top: Bool, bottom: Bool) -> UIImage? {
    if !top && !bottom {
        return nil
    }
    let key: WalletThemeResourceKey
    if top && bottom {
        key = .itemListCornersBoth
    } else if top {
        key = .itemListCornersTop
    } else {
        key = .itemListCornersBottom
    }
    return theme.image(key.rawValue, { theme in
        return generateImage(CGSize(width: 50.0, height: 50.0), rotatedContext: { (size, context) in
            let bounds = CGRect(origin: CGPoint(), size: size)
            context.setFillColor(theme.list.blocksBackgroundColor.cgColor)
            context.fill(bounds)
            
            context.setBlendMode(.clear)
            
            var corners: UIRectCorner = []
            if top {
                corners.insert(.topLeft)
                corners.insert(.topRight)
            }
            if bottom {
                corners.insert(.bottomLeft)
                corners.insert(.bottomRight)
            }
            let path = UIBezierPath(roundedRect: bounds, byRoundingCorners: corners, cornerRadii: CGSize(width: 11.0, height: 11.0))
            context.addPath(path.cgPath)
            context.fillPath()
        })?.stretchableImage(withLeftCapWidth: 25, topCapHeight: 25)
    })
}

func itemListClearInputIcon(_ theme: WalletTheme) -> UIImage? {
    return theme.image(WalletThemeResourceKey.itemListClearInputIcon.rawValue, { theme in
        return generateTintedImage(image: UIImage(bundleImageName: "Wallet/ClearInput"), color: theme.list.inputClearButtonColor)
    })
}

func navigationShareIcon(_ theme: WalletTheme) -> UIImage? {
    return theme.image(WalletThemeResourceKey.navigationShareIcon.rawValue, { theme in
        generateTintedImage(image: UIImage(bundleImageName: "Wallet/NavigationShare"), color: theme.navigationBar.buttonColor)
    })
}

func disclosureArrowImage(_ theme: WalletTheme) -> UIImage? {
    return theme.image(WalletThemeResourceKey.itemListDisclosureArrow.rawValue, { theme in
        return generateTintedImage(image: UIImage(bundleImageName: "Wallet/DisclosureArrow"), color: theme.list.itemSecondaryTextColor)
    })
}

func clockFrameImage(_ theme: WalletTheme) -> UIImage? {
    return theme.image(WalletThemeResourceKey.clockFrame.rawValue, { theme in
        let color = theme.list.itemSecondaryTextColor
        return generateImage(CGSize(width: 11.0, height: 11.0), contextGenerator: { size, context in
            context.clear(CGRect(origin: CGPoint(), size: size))
            context.setStrokeColor(color.cgColor)
            context.setFillColor(color.cgColor)
            let strokeWidth: CGFloat = 1.0
            context.setLineWidth(strokeWidth)
            context.strokeEllipse(in: CGRect(x: strokeWidth / 2.0, y: strokeWidth / 2.0, width: size.width - strokeWidth, height: size.height - strokeWidth))
            context.fill(CGRect(x: (11.0 - strokeWidth) / 2.0, y: strokeWidth * 3.0, width: strokeWidth, height: 11.0 / 2.0 - strokeWidth * 3.0))
        })
    })
}

func clockMinImage(_ theme: WalletTheme) -> UIImage? {
    return theme.image(WalletThemeResourceKey.clockMin.rawValue, { theme in
        let color = theme.list.itemSecondaryTextColor
        return generateImage(CGSize(width: 11.0, height: 11.0), contextGenerator: { size, context in
            context.clear(CGRect(origin: CGPoint(), size: size))
            context.setFillColor(color.cgColor)
            let strokeWidth: CGFloat = 1.0
            context.fill(CGRect(x: (11.0 - strokeWidth) / 2.0, y: (11.0 - strokeWidth) / 2.0, width: 11.0 / 2.0 - strokeWidth, height: strokeWidth))
        })
    })
}

func walletStringsFormattedNumber(_ count: Int32, _ groupingSeparator: String = "") -> String {
    let string = "\(count)"
    if groupingSeparator.isEmpty || abs(count) < 1000 {
        return string
    } else {
        var groupedString: String = ""
        for i in 0 ..< Int(ceil(Double(string.count) / 3.0)) {
            let index = string.count - Int(i + 1) * 3
            if !groupedString.isEmpty {
                groupedString = groupingSeparator + groupedString
            }
            groupedString = String(string[string.index(string.startIndex, offsetBy: max(0, index)) ..< string.index(string.startIndex, offsetBy: index + 3)]) + groupedString
        }
        return groupedString
    }
}

public func OverlayStatusController(theme: WalletTheme, type: OverlayStatusControllerType) -> ViewController {
    return OverlayStatusController(style: theme.keyboardAppearance == .dark ? .dark : .light, type: type)
}
