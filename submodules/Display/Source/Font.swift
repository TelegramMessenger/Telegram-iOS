import Foundation
import UIKit

public struct Font {
    public enum Design {
        case regular
        case serif
        case monospace
        case round
        case camera
    }
    
    public struct Traits: OptionSet {
        public var rawValue: Int32
        
        public init(rawValue: Int32) {
            self.rawValue = rawValue
        }
        
        public init() {
            self.rawValue = 0
        }
        
        public static let italic = Traits(rawValue: 1 << 0)
        public static let monospacedNumbers = Traits(rawValue: 1 << 1)
    }
    
    public enum Weight {
        case regular
        case light
        case medium
        case semibold
        case bold
        case heavy
        
        var isBold: Bool {
            switch self {
                case .medium, .semibold, .bold, .heavy:
                    return true
                default:
                    return false
            }
        }
        
        var weight: UIFont.Weight {
            switch self {
                case .light:
                    return .light
                case .medium:
                    return .medium
                case .semibold:
                    return .semibold
                case .bold:
                    return .bold
                case .heavy:
                    return .heavy
                default:
                    return .regular
            }
        }
    }
    
    public static func with(size: CGFloat, design: Design = .regular, weight: Weight = .regular, traits: Traits = []) -> UIFont {
        if #available(iOS 13.0, *), design != .camera {
            let descriptor: UIFontDescriptor
            if #available(iOS 14.0, *) {
                descriptor = UIFont.systemFont(ofSize: size).fontDescriptor
            } else {
                descriptor = UIFont.systemFont(ofSize: size, weight: weight.weight).fontDescriptor
            }

            var symbolicTraits = descriptor.symbolicTraits
            if traits.contains(.italic) {
                symbolicTraits.insert(.traitItalic)
            }
            var updatedDescriptor: UIFontDescriptor? = descriptor.withSymbolicTraits(symbolicTraits)
            if traits.contains(.monospacedNumbers) {
                updatedDescriptor = updatedDescriptor?.addingAttributes([
                UIFontDescriptor.AttributeName.featureSettings: [
                  [UIFontDescriptor.FeatureKey.featureIdentifier:
                   kNumberSpacingType,
                   UIFontDescriptor.FeatureKey.typeIdentifier:
                   kMonospacedNumbersSelector]
                ]])
            }
            switch design {
                case .serif:
                    updatedDescriptor = updatedDescriptor?.withDesign(.serif)
                case .monospace:
                    updatedDescriptor = updatedDescriptor?.withDesign(.monospaced)
                case .round:
                    updatedDescriptor = updatedDescriptor?.withDesign(.rounded)
                default:
                    updatedDescriptor = updatedDescriptor?.withDesign(.default)
            }
            if #available(iOS 14.0, *) {
                if weight != .regular {
                    updatedDescriptor = updatedDescriptor?.addingAttributes([
                        UIFontDescriptor.AttributeName.traits: [UIFontDescriptor.TraitKey.weight: weight.weight]
                    ])
                }
            }
         
            if let updatedDescriptor = updatedDescriptor {
                return UIFont(descriptor: updatedDescriptor, size: size)
            } else {
                return UIFont(descriptor: descriptor, size: size)
            }
        } else {
            switch design {
                case .regular:
                    if traits.contains(.italic) {
                        if let descriptor = UIFont.systemFont(ofSize: size, weight: weight.weight).fontDescriptor.withSymbolicTraits([.traitItalic]) {
                            return UIFont(descriptor: descriptor, size: size)
                        } else {
                            return UIFont.italicSystemFont(ofSize: size)
                        }
                    } else {
                        return UIFont.systemFont(ofSize: size, weight: weight.weight)
                    }
                case .serif:
                    if weight.isBold && traits.contains(.italic) {
                        return UIFont(name: "Georgia-BoldItalic", size: size - 1.0) ?? UIFont.systemFont(ofSize: size)
                    } else if weight.isBold {
                        return UIFont(name: "Georgia-Bold", size: size - 1.0) ?? UIFont.systemFont(ofSize: size)
                    } else if traits.contains(.italic) {
                        return UIFont(name: "Georgia-Italic", size: size - 1.0) ?? UIFont.systemFont(ofSize: size)
                    } else {
                        return UIFont(name: "Georgia", size: size - 1.0) ?? UIFont.systemFont(ofSize: size)
                    }
                case .monospace:
                    if weight.isBold && traits.contains(.italic) {
                        return UIFont(name: "Menlo-BoldItalic", size: size - 1.0) ?? UIFont.systemFont(ofSize: size)
                    } else if weight.isBold {
                        return UIFont(name: "Menlo-Bold", size: size - 1.0) ?? UIFont.systemFont(ofSize: size)
                    } else if traits.contains(.italic) {
                        return UIFont(name: "Menlo-Italic", size: size - 1.0) ?? UIFont.systemFont(ofSize: size)
                    } else {
                        return UIFont(name: "Menlo", size: size - 1.0) ?? UIFont.systemFont(ofSize: size)
                    }
                case .round:
                    return UIFont(name: ".SFCompactRounded-Semibold", size: size) ?? UIFont.systemFont(ofSize: size)
                case .camera:
                    func encodeText(string: String, key: Int16) -> String {
                        let nsString = string as NSString
                        let result = NSMutableString()
                        for i in 0 ..< nsString.length {
                            var c: unichar = nsString.character(at: i)
                            c = unichar(Int16(c) + key)
                            result.append(NSString(characters: &c, length: 1) as String)
                        }
                        return result as String
                    }
                    if case .semibold = weight {
                        return UIFont(name: encodeText(string: "TGDbnfsb.Tfnjcpme", key: -1), size: size) ?? UIFont.systemFont(ofSize: size, weight: weight.weight)
                    } else {
                        return UIFont(name: encodeText(string: "TGDbnfsb.Sfhvmbs", key: -1), size: size) ?? UIFont.systemFont(ofSize: size, weight: weight.weight)
                    }
            }
        }
    }
    
    public static func regular(_ size: CGFloat) -> UIFont {
        return UIFont.systemFont(ofSize: size)
    }
    
    public static func medium(_ size: CGFloat) -> UIFont {
        if #available(iOS 8.2, *) {
            return UIFont.systemFont(ofSize: size, weight: UIFont.Weight.medium)
        } else {
            return CTFontCreateWithName("HelveticaNeue-Medium" as CFString, size, nil)
        }
    }
    
    public static func semibold(_ size: CGFloat) -> UIFont {
        if #available(iOS 8.2, *) {
            return UIFont.systemFont(ofSize: size, weight: UIFont.Weight.semibold)
        } else {
            return CTFontCreateWithName("HelveticaNeue-Medium" as CFString, size, nil)
        }
    }
    
    public static func bold(_ size: CGFloat) -> UIFont {
        if #available(iOS 8.2, *) {
            return UIFont.boldSystemFont(ofSize: size)
        } else {
            return CTFontCreateWithName("HelveticaNeue-Bold" as CFString, size, nil)
        }
    }
    
    
    public static func heavy(_ size: CGFloat) -> UIFont {
        return self.with(size: size, design: .regular, weight: .heavy, traits: [])
    }
    
    public static func light(_ size: CGFloat) -> UIFont {
        if #available(iOS 8.2, *) {
            return UIFont.systemFont(ofSize: size, weight: UIFont.Weight.light)
        } else {
            return CTFontCreateWithName("HelveticaNeue-Light" as CFString, size, nil)
        }
    }
    
    public static func semiboldItalic(_ size: CGFloat) -> UIFont {
        if let descriptor = UIFont.systemFont(ofSize: size).fontDescriptor.withSymbolicTraits([.traitBold, .traitItalic]) {
            return UIFont(descriptor: descriptor, size: size)
        } else {
            return UIFont.italicSystemFont(ofSize: size)
        }
    }
    
    public static func monospace(_ size: CGFloat) -> UIFont {
        return UIFont(name: "Menlo-Regular", size: size - 1.0) ?? UIFont.systemFont(ofSize: size)
    }
    
    public static func semiboldMonospace(_ size: CGFloat) -> UIFont {
        return UIFont(name: "Menlo-Bold", size: size - 1.0) ?? UIFont.systemFont(ofSize: size)
    }
    
    public static func italicMonospace(_ size: CGFloat) -> UIFont {
        return UIFont(name: "Menlo-Italic", size: size - 1.0) ?? UIFont.systemFont(ofSize: size)
    }
    
    public static func semiboldItalicMonospace(_ size: CGFloat) -> UIFont {
        return UIFont(name: "Menlo-BoldItalic", size: size - 1.0) ?? UIFont.systemFont(ofSize: size)
    }
    
    public static func italic(_ size: CGFloat) -> UIFont {
        return UIFont.italicSystemFont(ofSize: size)
    }
}

public extension NSAttributedString {
    convenience init(string: String, font: UIFont? = nil, textColor: UIColor = UIColor.black, paragraphAlignment: NSTextAlignment? = nil) {
        var attributes: [NSAttributedString.Key: AnyObject] = [:]
        if let font = font {
            attributes[NSAttributedString.Key.font] = font
        }
        attributes[NSAttributedString.Key.foregroundColor] = textColor
        if let paragraphAlignment = paragraphAlignment {
            let paragraphStyle = NSMutableParagraphStyle()
            paragraphStyle.alignment = paragraphAlignment
            attributes[NSAttributedString.Key.paragraphStyle] = paragraphStyle
        }
        self.init(string: string, attributes: attributes)
    }
}
