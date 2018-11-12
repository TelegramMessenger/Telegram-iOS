import Foundation
import TelegramCore
import Display

enum InstantPageTextStyle {
    case fontSize(CGFloat)
    case lineSpacingFactor(CGFloat)
    case fontSerif(Bool)
    case fontFixed(Bool)
    case bold
    case italic
    case underline
    case strikethrough
    case textColor(UIColor)
    case `subscript`
    case superscript
    case markerColor(UIColor)
    case marker
    case anchor(String)
}

let InstantPageLineSpacingFactorAttribute = "LineSpacingFactorAttribute"
let InstantPageMarkerColorAttribute = "MarkerColorAttribute"
let InstantPageMediaIdAttribute = "MediaIdAttribute"
let InstantPageAnchorAttribute = "AnchorAttribute"

final class InstantPageTextStyleStack {
    private var items: [InstantPageTextStyle] = []
    
    func push(_ item: InstantPageTextStyle) {
        items.append(item)
    }
    
    func pop() {
        if !items.isEmpty {
            items.removeLast()
        }
    }
    
    func textAttributes() -> [NSAttributedStringKey: Any] {
        var fontSize: CGFloat?
        var fontSerif: Bool?
        var fontFixed: Bool?
        var bold: Bool?
        var italic: Bool?
        var strikethrough: Bool?
        var underline: Bool?
        var color: UIColor?
        var lineSpacingFactor: CGFloat?
        var baselineOffset: CGFloat?
        var markerColor: UIColor?
        var marker: Bool?
        var anchor: String?
        
        for item in self.items.reversed() {
            switch item {
                case let .fontSize(value):
                    if fontSize == nil {
                        fontSize = value
                    }
                case let .fontSerif(value):
                    if fontSerif == nil {
                        fontSerif = value
                    }
                case let .fontFixed(value):
                    if fontFixed == nil {
                        fontFixed = value
                    }
                case .bold:
                    if bold == nil {
                        bold = true
                    }
                case .italic:
                    if italic == nil {
                        italic = true
                    }
                case .strikethrough:
                    if strikethrough == nil {
                        strikethrough = true
                    }
                case .underline:
                    if underline == nil {
                        underline = true
                    }
                case let .textColor(value):
                    if color == nil {
                        color = value
                    }
                case let .lineSpacingFactor(value):
                    if lineSpacingFactor == nil {
                        lineSpacingFactor = value
                    }
                case .subscript:
                    if baselineOffset == nil {
                        baselineOffset = 0.35
                        underline = false
                    }
                case .superscript:
                    if baselineOffset == nil {
                        baselineOffset = -0.35
                    }
                case let .markerColor(color):
                    if markerColor == nil {
                        markerColor = color
                    }
                case .marker:
                    if marker == nil {
                        marker = true
                    }
                case let .anchor(name):
                    if anchor == nil {
                        anchor = name
                    }
            }
        }
        
        var attributes: [NSAttributedStringKey: Any] = [:]
        
        var parsedFontSize: CGFloat
        if let fontSize = fontSize {
            parsedFontSize = fontSize
        } else {
            parsedFontSize = 16.0
        }
        
        if let baselineOffset = baselineOffset {
            attributes[NSAttributedStringKey.baselineOffset] = round(parsedFontSize * baselineOffset);
            parsedFontSize = round(parsedFontSize * 0.85)
        }
        
        if (bold != nil && bold!) && (italic != nil && italic!) {
            if fontSerif != nil && fontSerif! {
                attributes[NSAttributedStringKey.font] = UIFont(name: "Georgia-BoldItalic", size: parsedFontSize)
            } else if fontFixed != nil && fontFixed! {
                attributes[NSAttributedStringKey.font] = UIFont(name: "Menlo-BoldItalic", size: parsedFontSize)
            } else {
                attributes[NSAttributedStringKey.font] = Font.bold(parsedFontSize)
            }
        } else if bold != nil && bold! {
            if fontSerif != nil && fontSerif! {
                attributes[NSAttributedStringKey.font] = UIFont(name: "Georgia-Bold", size: parsedFontSize)
            } else if fontFixed != nil && fontFixed! {
                attributes[NSAttributedStringKey.font] = UIFont(name: "Menlo-Bold", size: parsedFontSize)
            } else {
                attributes[NSAttributedStringKey.font] = Font.bold(parsedFontSize)
            }
        } else if italic != nil && italic! {
            if fontSerif != nil && fontSerif! {
                attributes[NSAttributedStringKey.font] = UIFont(name: "Georgia-Italic", size: parsedFontSize)
            } else if fontFixed != nil && fontFixed! {
                attributes[NSAttributedStringKey.font] = UIFont(name: "Menlo-Italic", size: parsedFontSize)
            } else {
                attributes[NSAttributedStringKey.font] = Font.italic(parsedFontSize)
            }
        } else {
            if fontSerif != nil && fontSerif! {
                attributes[NSAttributedStringKey.font] = UIFont(name: "Georgia", size: parsedFontSize)
            } else if fontFixed != nil && fontFixed! {
                attributes[NSAttributedStringKey.font] = UIFont(name: "Menlo", size: parsedFontSize)
            } else {
                attributes[NSAttributedStringKey.font] = Font.regular(parsedFontSize)
            }
        }
        
        if strikethrough != nil && strikethrough! {
            attributes[NSAttributedStringKey.strikethroughStyle] = (NSUnderlineStyle.styleSingle.rawValue | NSUnderlineStyle.patternSolid.rawValue) as NSNumber
        }
        
        if underline != nil && underline! {
            attributes[NSAttributedStringKey.underlineStyle] = NSUnderlineStyle.styleSingle.rawValue as NSNumber
        }
        
        if let color = color {
            attributes[NSAttributedStringKey.foregroundColor] = color
        } else {
            attributes[NSAttributedStringKey.foregroundColor] = UIColor.black
        }
        
        if let lineSpacingFactor = lineSpacingFactor {
            attributes[NSAttributedStringKey(rawValue: InstantPageLineSpacingFactorAttribute)] = lineSpacingFactor as NSNumber
        }
        
        if marker != nil && marker!, let markerColor = markerColor {
            attributes[NSAttributedStringKey(rawValue: InstantPageMarkerColorAttribute)] = markerColor
        }
        
        if let anchor = anchor {
            attributes[NSAttributedStringKey(rawValue: InstantPageAnchorAttribute)] = anchor
        }
        
        return attributes
    }
}
