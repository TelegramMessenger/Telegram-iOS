import Foundation
import CoreGraphics
import CoreText

extension PassColor {
    var cgColor: CGColor {
        return CGColor(colorSpace: CGColorSpace(name: CGColorSpace.sRGB)!, components: [self.red, self.green, self.blue, 1.0])!
    }
}

func passFont(size: CGFloat, weight: CGFloat) -> CTFont {
    let base = CTFontCreateUIFontForLanguage(.system, size, nil) ?? CTFontCreateWithName("Helvetica" as CFString, size, nil)
    if weight == 0.0 {
        return base
    }
    let traits: [CFString: Any] = [kCTFontWeightTrait: weight]
    let descriptor = CTFontDescriptorCreateCopyWithAttributes(CTFontCopyFontDescriptor(base), [kCTFontTraitsAttribute: traits] as CFDictionary)
    return CTFontCreateWithFontDescriptor(descriptor, size, nil)
}

private func passLine(_ string: String, fontSize: CGFloat, weight: CGFloat, color: CGColor?) -> CTLine {
    var attributes: [NSAttributedString.Key: Any] = [NSAttributedString.Key(kCTFontAttributeName as String): passFont(size: fontSize, weight: weight)]
    if let color = color {
        attributes[NSAttributedString.Key(kCTForegroundColorAttributeName as String)] = color
    }
    return CTLineCreateWithAttributedString(NSAttributedString(string: string, attributes: attributes))
}

func passFittedText(_ string: String, fontSize: CGFloat, minFontSize: CGFloat, weight: CGFloat, maxWidth: CGFloat, color: CGColor? = nil) -> (line: CTLine, width: CGFloat, fontSize: CGFloat) {
    let string = string.replacingOccurrences(of: "\n", with: " ")
    var size = fontSize
    var attempts = 0
    while true {
        attempts += 1
        let line = passLine(string, fontSize: size, weight: weight, color: color)
        let width = CGFloat(CTLineGetTypographicBounds(line, nil, nil, nil))
        if width <= maxWidth {
            return (line, width, size)
        }
        if size <= minFontSize || attempts >= 48 {
            let token = passLine("\u{2026}", fontSize: size, weight: weight, color: color)
            let truncated = CTLineCreateTruncatedLine(line, Double(maxWidth), .end, token) ?? token
            return (truncated, min(maxWidth, CGFloat(CTLineGetTypographicBounds(truncated, nil, nil, nil))), size)
        }
        size = max(minFontSize, size - 1.0)
    }
}

func passCommonFontSize(_ strings: [String], fontSize: CGFloat, minFontSize: CGFloat, weight: CGFloat, maxWidth: CGFloat) -> CGFloat {
    return strings.reduce(fontSize) { result, string in
        return min(result, passFittedText(string, fontSize: fontSize, minFontSize: minFontSize, weight: weight, maxWidth: maxWidth).fontSize)
    }
}

func passTextWidth(_ string: String, fontSize: CGFloat, weight: CGFloat) -> CGFloat {
    return ceil(passFittedText(string, fontSize: fontSize, minFontSize: fontSize, weight: weight, maxWidth: .greatestFiniteMagnitude).width)
}

enum PassHorizontalAlignment {
    case left
    case center
    case right
}

@discardableResult
func passDrawText(_ string: String, in context: CGContext, x: CGFloat, top: CGFloat, width: CGFloat, fontSize: CGFloat, minFontSize: CGFloat, weight: CGFloat, color: CGColor, alignment: PassHorizontalAlignment) -> CGFloat {
    guard !string.isEmpty, width > 1.0 else {
        return 0.0
    }
    let fitted = passFittedText(string, fontSize: fontSize, minFontSize: minFontSize, weight: weight, maxWidth: width, color: color)
    var ascent: CGFloat = 0.0
    var descent: CGFloat = 0.0
    let _ = CTLineGetTypographicBounds(fitted.line, &ascent, &descent, nil)
    let originX: CGFloat
    switch alignment {
    case .left:
        originX = x
    case .center:
        originX = x + floor((width - fitted.width) / 2.0)
    case .right:
        originX = x + width - fitted.width
    }
    context.saveGState()
    context.textMatrix = CGAffineTransform(scaleX: 1.0, y: -1.0)
    context.textPosition = CGPoint(x: originX, y: top + ascent)
    CTLineDraw(fitted.line, context)
    context.restoreGState()
    return ceil(ascent + descent)
}

func passDrawImage(_ image: CGImage, in context: CGContext, rect: CGRect) {
    context.saveGState()
    context.translateBy(x: rect.minX, y: rect.maxY)
    context.scaleBy(x: 1.0, y: -1.0)
    context.draw(image, in: CGRect(origin: .zero, size: rect.size))
    context.restoreGState()
}

func passAspectFit(_ size: CGSize, in bounds: CGSize) -> CGSize {
    guard size.width > 0.0, size.height > 0.0 else {
        return .zero
    }
    let ratio = min(bounds.width / size.width, bounds.height / size.height)
    return CGSize(width: floor(size.width * ratio), height: floor(size.height * ratio))
}

func passDrawImageFilling(_ image: CGImage, in context: CGContext, rect: CGRect) {
    let ratio = max(rect.width / CGFloat(image.width), rect.height / CGFloat(image.height))
    let size = CGSize(width: CGFloat(image.width) * ratio, height: CGFloat(image.height) * ratio)
    context.saveGState()
    context.clip(to: rect)
    passDrawImage(image, in: context, rect: CGRect(x: rect.midX - size.width / 2.0, y: rect.midY - size.height / 2.0, width: size.width, height: size.height))
    context.restoreGState()
}

func passDrawTinted(_ mask: CGImage, color: CGColor, in context: CGContext, rect: CGRect) {
    context.saveGState()
    context.translateBy(x: rect.minX, y: rect.maxY)
    context.scaleBy(x: 1.0, y: -1.0)
    context.clip(to: CGRect(origin: .zero, size: rect.size), mask: mask)
    context.setFillColor(color)
    context.fill(CGRect(origin: .zero, size: rect.size))
    context.restoreGState()
}

struct PassResolvedField {
    var label: String?
    var text: String
    var alignment: PassTextAlignment
}

struct PassFieldRowStyle {
    var labelSize: CGFloat
    var valueSize: CGFloat
    var minValueSize: CGFloat
    var valueWeight: CGFloat
    var labelAboveValue: Bool
    var spacing: CGFloat = 10.0
}

private let passLabelWeight: CGFloat = 0.3

@discardableResult
func passDrawFieldRow(_ fields: [PassResolvedField], in context: CGContext, x: CGFloat, top: CGFloat, width: CGFloat, style: PassFieldRowStyle, valueColor: CGColor, labelColor: CGColor) -> CGFloat {
    guard !fields.isEmpty, width > 1.0 else {
        return 0.0
    }
    let available = max(1.0, width - style.spacing * CGFloat(fields.count - 1))
    let natural = fields.map { field -> CGFloat in
        let value = passTextWidth(field.text.replacingOccurrences(of: "\n", with: " "), fontSize: style.valueSize, weight: style.valueWeight)
        let label = field.label.flatMap { passTextWidth($0.uppercased(), fontSize: style.labelSize, weight: passLabelWeight) } ?? 0.0
        return max(value, label)
    }
    var widths: [CGFloat]
    if fields.count == 1 {
        widths = [width]
    } else if natural.reduce(0.0, +) <= available {
        widths = natural
    } else {
        let share = available / CGFloat(fields.count)
        let smallTotal = natural.filter { $0 <= share }.reduce(0.0, +)
        let largeCount = natural.filter { $0 > share }.count
        let largeShare = largeCount > 0 ? floor((available - smallTotal) / CGFloat(largeCount)) : share
        widths = natural.map { $0 <= share ? $0 : largeShare }
    }
    let gap = fields.count > 1 ? (width - widths.reduce(0.0, +)) / CGFloat(fields.count - 1) : 0.0

    var originX = x
    var height: CGFloat = 0.0
    for (index, field) in fields.enumerated() {
        let alignment: PassHorizontalAlignment
        switch field.alignment {
        case .left:
            alignment = .left
        case .center:
            alignment = .center
        case .right:
            alignment = .right
        case .natural:
            alignment = (index == fields.count - 1 && fields.count > 1) ? .right : .left
        }
        let columnWidth = widths[index]
        var y = top
        if style.labelAboveValue, let label = field.label {
            y += passDrawText(label.uppercased(), in: context, x: originX, top: y, width: columnWidth, fontSize: style.labelSize, minFontSize: style.labelSize - 2.0, weight: passLabelWeight, color: labelColor, alignment: alignment) + 1.0
        }
        y += passDrawText(field.text, in: context, x: originX, top: y, width: columnWidth, fontSize: style.valueSize, minFontSize: style.minValueSize, weight: style.valueWeight, color: valueColor, alignment: alignment)
        if !style.labelAboveValue, let label = field.label {
            y += passDrawText(label.uppercased(), in: context, x: originX, top: y, width: columnWidth, fontSize: style.labelSize, minFontSize: style.labelSize - 2.0, weight: passLabelWeight, color: labelColor, alignment: alignment)
        }
        height = max(height, y - top)
        originX += columnWidth + gap
    }
    return height
}
