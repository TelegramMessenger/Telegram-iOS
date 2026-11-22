#if canImport(UIKit)
import UIKit
import RichTextEditorCore

@available(iOS 13.0, *)
public extension RGBAColor {
    var uiColor: UIColor {
        UIColor(red: red, green: green, blue: blue, alpha: alpha)
    }
}

@available(iOS 13.0, *)
public extension UIColor {
    var rgba: RGBAColor {
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        getRed(&r, green: &g, blue: &b, alpha: &a)
        return RGBAColor(red: r, green: g, blue: b, alpha: a)
    }
}

@available(iOS 13.0, *)
public enum FontResolver {
    public static func font(family: String?, size: CGFloat, bold: Bool, italic: Bool, serif: Bool = false) -> UIFont {
        var descriptor: UIFontDescriptor
        if let family, let custom = UIFont(name: family, size: size) {
            descriptor = custom.fontDescriptor
        } else if serif, let serifDesc = UIFont.systemFont(ofSize: size).fontDescriptor.withDesign(.serif) {
            descriptor = serifDesc
        } else {
            descriptor = UIFont.systemFont(ofSize: size).fontDescriptor
        }
        var traits: UIFontDescriptor.SymbolicTraits = []
        if bold { traits.insert(.traitBold) }
        if italic { traits.insert(.traitItalic) }
        if !traits.isEmpty,
           let d = descriptor.withSymbolicTraits(descriptor.symbolicTraits.union(traits)) {
            descriptor = d
        }
        return UIFont(descriptor: descriptor, size: size)
    }

    /// Resolve a `RichTextFontSpec` to the SAME `UIFont` the InstantPage V2 renderer resolves for the
    /// equivalent run — see `InstantPageTextStyleStack.textAttributes`, whose branch table this
    /// mirrors. The families are load-bearing, not stylistic: the V2 line formulas are functions of
    /// `ascender`/`descender`, so resolving a different face silently shifts every line.
    ///
    /// - Georgia ships only Regular and Bold, so a WEIGHTED serif run resolves to the system serif
    ///   design (New York), which has real Medium and Semibold faces; bold/italic stay in that family
    ///   rather than falling through to Georgia and mixing two serif families inside one heading.
    ///   Note bold there is a WEIGHT (`.bold`), not a symbolic trait — matching the renderer.
    /// - Monospace is Menlo, matching the renderer's explicit `UIFont(name:)` arms.
    /// - An explicit user `family` still wins, as in the size-based overload.
    public static func font(spec: RichTextFontSpec, bold: Bool, italic: Bool, family: String?) -> UIFont {
        let size = spec.size
        if let family, let custom = UIFont(name: family, size: size) {
            var descriptor = custom.fontDescriptor
            var traits: UIFontDescriptor.SymbolicTraits = []
            if bold { traits.insert(.traitBold) }
            if italic { traits.insert(.traitItalic) }
            if !traits.isEmpty, let d = descriptor.withSymbolicTraits(descriptor.symbolicTraits.union(traits)) {
                descriptor = d
            }
            return UIFont(descriptor: descriptor, size: size)
        }

        switch spec.style {
        case .monospace:
            let name: String
            switch (bold, italic) {
            case (true, true):   name = "Menlo-BoldItalic"
            case (true, false):  name = "Menlo-Bold"
            case (false, true):  name = "Menlo-Italic"
            case (false, false): name = "Menlo-Regular"
            }
            return UIFont(name: name, size: size) ?? UIFont.monospacedSystemFont(ofSize: size, weight: .regular)

        case .serif:
            if spec.weight == .regular {
                let name: String
                switch (bold, italic) {
                case (true, true):   name = "Georgia-BoldItalic"
                case (true, false):  name = "Georgia-Bold"
                case (false, true):  name = "Georgia-Italic"
                case (false, false): name = "Georgia"
                }
                if let font = UIFont(name: name, size: size) { return font }
            }
            // Weighted serif — reproduce `Display.Font.with(size:design:.serif,weight:traits:)`
            // step for step: base descriptor, italic trait, serif design, then the weight attribute.
            var descriptor = UIFont.systemFont(ofSize: size).fontDescriptor
            var symbolic = descriptor.symbolicTraits
            if italic { symbolic.insert(.traitItalic) }
            var updated: UIFontDescriptor? = descriptor.withSymbolicTraits(symbolic)
            updated = updated?.withDesign(.serif)
            let weight: UIFont.Weight = bold ? .bold : (spec.weight == .semibold ? .semibold : .medium)
            updated = updated?.addingAttributes([
                UIFontDescriptor.AttributeName.traits: [UIFontDescriptor.TraitKey.weight: weight]
            ])
            if let updated { descriptor = updated }
            return UIFont(descriptor: descriptor, size: size)

        case .sans:
            if bold && italic {
                if let d = UIFont.systemFont(ofSize: size).fontDescriptor.withSymbolicTraits([.traitBold, .traitItalic]) {
                    return UIFont(descriptor: d, size: size)
                }
                return UIFont.boldSystemFont(ofSize: size)
            }
            if bold { return UIFont.boldSystemFont(ofSize: size) }
            if italic {
                switch spec.weight {
                case .semibold:
                    if let d = UIFont.systemFont(ofSize: size).fontDescriptor.withSymbolicTraits([.traitBold, .traitItalic]) {
                        return UIFont(descriptor: d, size: size)
                    }
                case .medium:
                    if let d = UIFont.systemFont(ofSize: size, weight: .medium).fontDescriptor.withSymbolicTraits([.traitItalic]) {
                        return UIFont(descriptor: d, size: size)
                    }
                case .regular:
                    break
                }
                return UIFont.italicSystemFont(ofSize: size)
            }
            switch spec.weight {
            case .semibold: return UIFont.systemFont(ofSize: size, weight: .semibold)
            case .medium:   return UIFont.systemFont(ofSize: size, weight: .medium)
            case .regular:  return UIFont.systemFont(ofSize: size)
            }
        }
    }
}
#endif
