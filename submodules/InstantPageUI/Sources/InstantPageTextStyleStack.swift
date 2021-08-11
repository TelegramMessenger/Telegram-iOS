import Foundation
import UIKit
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
    case anchor(String, NSAttributedString?, Bool)
    case linkColor(UIColor)
    case linkMarkerColor(UIColor)
    case link(Bool)
}

let InstantPageLineSpacingFactorAttribute = "LineSpacingFactorAttribute"
let InstantPageMarkerColorAttribute = "MarkerColorAttribute"
let InstantPageMediaIdAttribute = "MediaIdAttribute"
let InstantPageMediaDimensionsAttribute = "MediaDimensionsAttribute"
let InstantPageAnchorAttribute = "AnchorAttribute"

final class InstantPageTextStyleStack {
    private var items: [InstantPageTextStyle] = []
    
    func push(_ item: InstantPageTextStyle) {
        self.items.append(item)
    }
    
    func pop() {
        if !self.items.isEmpty {
            self.items.removeLast()
        }
    }
    
    func textAttributes() -> [NSAttributedString.Key: Any] {
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
        var anchor: Dictionary<String, Any>?
        var linkColor: UIColor?
        var linkMarkerColor: UIColor?
        var link: Bool?
        
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
                case let .anchor(name, anchorText, empty):
                    if anchor == nil {
                        if let anchorText = anchorText {
                            anchor = ["name": name, "text": anchorText, "empty": empty]
                        } else {
                            anchor = ["name": name, "empty": empty]
                        }
                    }
                case let .linkColor(color):
                    if linkColor == nil {
                        linkColor = color
                    }
                case let .linkMarkerColor(color):
                    if linkMarkerColor == nil {
                        linkMarkerColor = color
                    }
                case let .link(instant):
                    if link == nil {
                        link = instant
                    }
            }
        }
        
        var attributes: [NSAttributedString.Key: Any] = [:]
        
        var parsedFontSize: CGFloat
        if let fontSize = fontSize {
            parsedFontSize = fontSize
        } else {
            parsedFontSize = 16.0
        }
        
        if let baselineOffset = baselineOffset {
            attributes[NSAttributedString.Key.baselineOffset] = round(parsedFontSize * baselineOffset);
            parsedFontSize = round(parsedFontSize * 0.85)
        }
        
        if (bold != nil && bold!) && (italic != nil && italic!) {
            if fontSerif != nil && fontSerif! {
                attributes[NSAttributedString.Key.font] = UIFont(name: "Georgia-BoldItalic", size: parsedFontSize)
            } else if fontFixed != nil && fontFixed! {
                attributes[NSAttributedString.Key.font] = UIFont(name: "Menlo-BoldItalic", size: parsedFontSize)
            } else {
                attributes[NSAttributedString.Key.font] = Font.semiboldItalic(parsedFontSize)
            }
        } else if bold != nil && bold! {
            if fontSerif != nil && fontSerif! {
                attributes[NSAttributedString.Key.font] = UIFont(name: "Georgia-Bold", size: parsedFontSize)
            } else if fontFixed != nil && fontFixed! {
                attributes[NSAttributedString.Key.font] = UIFont(name: "Menlo-Bold", size: parsedFontSize)
            } else {
                attributes[NSAttributedString.Key.font] = Font.bold(parsedFontSize)
            }
        } else if italic != nil && italic! {
            if fontSerif != nil && fontSerif! {
                attributes[NSAttributedString.Key.font] = UIFont(name: "Georgia-Italic", size: parsedFontSize)
            } else if fontFixed != nil && fontFixed! {
                attributes[NSAttributedString.Key.font] = UIFont(name: "Menlo-Italic", size: parsedFontSize)
            } else {
                attributes[NSAttributedString.Key.font] = Font.italic(parsedFontSize)
            }
        } else {
            if fontSerif != nil && fontSerif! {
                attributes[NSAttributedString.Key.font] = UIFont(name: "Georgia", size: parsedFontSize)
            } else if fontFixed != nil && fontFixed! {
                attributes[NSAttributedString.Key.font] = UIFont(name: "Menlo", size: parsedFontSize)
            } else {
                attributes[NSAttributedString.Key.font] = Font.regular(parsedFontSize)
            }
        }
        
        if strikethrough != nil && strikethrough! {
            attributes[NSAttributedString.Key.strikethroughStyle] = NSUnderlineStyle.single.rawValue as NSNumber
        }
        
        if underline != nil && underline! {
            attributes[NSAttributedString.Key.underlineStyle] = NSUnderlineStyle.single.rawValue as NSNumber
        }
        
        if let link = link, let linkColor = linkColor {
            attributes[NSAttributedString.Key.foregroundColor] = linkColor
            if link, let linkMarkerColor = linkMarkerColor {
                attributes[NSAttributedString.Key(rawValue: InstantPageMarkerColorAttribute)] = linkMarkerColor
            }
        } else {
            if let color = color {
                attributes[NSAttributedString.Key.foregroundColor] = color
            } else {
                attributes[NSAttributedString.Key.foregroundColor] = UIColor.black
            }
        }
        
        if let lineSpacingFactor = lineSpacingFactor {
            attributes[NSAttributedString.Key(rawValue: InstantPageLineSpacingFactorAttribute)] = lineSpacingFactor as NSNumber
        }
        
        if marker != nil && marker!, let markerColor = markerColor {
            attributes[NSAttributedString.Key(rawValue: InstantPageMarkerColorAttribute)] = markerColor
        }
        
        if let anchor = anchor {
            attributes[NSAttributedString.Key(rawValue: InstantPageAnchorAttribute)] = anchor
        }
        
        return attributes
    }
}
