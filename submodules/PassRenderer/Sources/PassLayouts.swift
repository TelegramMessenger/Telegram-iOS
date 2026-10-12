import Foundation
import CoreGraphics
import CoreText
import Accelerate

private let margin: CGFloat = 12.0
private let headerHeight: CGFloat = 56.0

struct PassDrawingInput {
    var contents: PassContents
    var logoText: String?
    var header: [PassResolvedField]
    var primary: [PassResolvedField]
    var secondary: [PassResolvedField]
    var auxiliary: [PassResolvedField]
    var transitGlyph: CGImage?
    var size: CGSize
}

private let smallRow = PassFieldRowStyle(labelSize: 10.0, valueSize: 14.0, minValueSize: 10.0, valueWeight: 0.0, labelAboveValue: true)

private func blurred(_ image: CGImage) -> CGImage? {
    let width = 64
    let height = min(256, max(1, Int(CGFloat(width) * CGFloat(image.height) / CGFloat(max(1, image.width)))))
    guard let context = CGContext(data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: width * 4, space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue), let data = context.data else {
        return nil
    }
    context.interpolationQuality = .medium
    context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
    guard let temporary = malloc(width * height * 4) else {
        return nil
    }
    defer {
        free(temporary)
    }
    var source = vImage_Buffer(data: data, height: vImagePixelCount(height), width: vImagePixelCount(width), rowBytes: width * 4)
    var destination = vImage_Buffer(data: temporary, height: vImagePixelCount(height), width: vImagePixelCount(width), rowBytes: width * 4)
    for _ in 0 ..< 3 {
        vImageBoxConvolve_ARGB8888(&source, &destination, nil, 0, 0, 7, 7, nil, vImage_Flags(kvImageEdgeExtend))
        memcpy(data, temporary, width * height * 4)
    }
    return context.makeImage()
}

private func drawHeader(_ input: PassDrawingInput, in context: CGContext) {
    let pass = input.contents.pass
    var leftEdge = margin
    if let logo = input.contents.images[.logo] {
        let size = passAspectFit(CGSize(width: logo.width, height: logo.height), in: CGSize(width: 160.0, height: 30.0))
        context.interpolationQuality = .high
        passDrawImage(logo, in: context, rect: CGRect(x: margin, y: floor((headerHeight - size.height) / 2.0), width: size.width, height: size.height))
        leftEdge += size.width + 8.0
    }
    var rightEdge = input.size.width - margin
    if !input.header.isEmpty {
        let style = PassFieldRowStyle(labelSize: 10.0, valueSize: 17.0, minValueSize: 11.0, valueWeight: 0.0, labelAboveValue: true)
        let natural = input.header.reduce(CGFloat(0.0)) { result, field in
            let value = passTextWidth(field.text, fontSize: style.valueSize, weight: style.valueWeight)
            let label = field.label.flatMap { passTextWidth($0.uppercased(), fontSize: style.labelSize, weight: 0.3) } ?? 0.0
            return result + max(value, label)
        } + style.spacing * CGFloat(input.header.count - 1)
        let headerWidth = min(natural, max(60.0, rightEdge - leftEdge - 8.0))
        let fields = input.header.map { PassResolvedField(label: $0.label, text: $0.text, alignment: $0.alignment == .natural ? .right : $0.alignment) }
        passDrawFieldRow(fields, in: context, x: rightEdge - headerWidth, top: 11.0, width: headerWidth, style: style, valueColor: pass.foregroundColor.cgColor, labelColor: pass.labelColor.cgColor)
        rightEdge -= headerWidth + 8.0
    }
    if let logoText = input.logoText, !logoText.isEmpty, rightEdge - leftEdge > 30.0 {
        passDrawText(logoText, in: context, x: leftEdge, top: 18.0, width: rightEdge - leftEdge, fontSize: 17.0, minFontSize: 12.0, weight: 0.0, color: pass.foregroundColor.cgColor, alignment: .left)
    }
}

private func drawBoardingPass(_ input: PassDrawingInput, in context: CGContext) {
    let pass = input.contents.pass
    let width = input.size.width - margin * 2.0
    let glyphSize: CGFloat = 28.0
    let columnWidth = floor((width - glyphSize - 16.0) / 2.0)
    let primaryValueWeight: CGFloat = -0.4
    let primaryValueSize = passCommonFontSize(input.primary.prefix(2).map { $0.text }, fontSize: 42.0, minFontSize: 20.0, weight: primaryValueWeight, maxWidth: columnWidth)
    let primaryLabelSize = passCommonFontSize(input.primary.prefix(2).compactMap { $0.label?.uppercased() }, fontSize: 11.0, minFontSize: 9.0, weight: 0.3, maxWidth: columnWidth)
    let primaryStyle = PassFieldRowStyle(labelSize: primaryLabelSize, valueSize: primaryValueSize, minValueSize: min(primaryValueSize, 20.0), valueWeight: primaryValueWeight, labelAboveValue: true)
    let primaryTop: CGFloat = 60.0
    if let origin = input.primary.first {
        passDrawFieldRow([PassResolvedField(label: origin.label, text: origin.text, alignment: .left)], in: context, x: margin, top: primaryTop, width: columnWidth, style: primaryStyle, valueColor: pass.foregroundColor.cgColor, labelColor: pass.labelColor.cgColor)
    }
    if input.primary.count > 1 {
        let destination = input.primary[1]
        passDrawFieldRow([PassResolvedField(label: destination.label, text: destination.text, alignment: .right)], in: context, x: input.size.width - margin - columnWidth, top: primaryTop, width: columnWidth, style: primaryStyle, valueColor: pass.foregroundColor.cgColor, labelColor: pass.labelColor.cgColor)
    }
    if let glyph = input.transitGlyph {
        let size = passAspectFit(CGSize(width: glyph.width, height: glyph.height), in: CGSize(width: glyphSize, height: glyphSize))
        var valueTop = primaryTop
        if input.primary.prefix(2).contains(where: { !($0.label ?? "").isEmpty }) {
            let labelFont = passFont(size: primaryLabelSize, weight: 0.3)
            valueTop += ceil(CTFontGetAscent(labelFont) + CTFontGetDescent(labelFont)) + 1.0
        }
        let valueFont = passFont(size: primaryValueSize, weight: primaryValueWeight)
        let valueCenter = valueTop + CTFontGetAscent(valueFont) - CTFontGetCapHeight(valueFont) / 2.0
        passDrawTinted(glyph, color: pass.labelColor.cgColor, in: context, rect: CGRect(x: floor((input.size.width - size.width) / 2.0), y: floor(valueCenter - size.height / 2.0), width: size.width, height: size.height))
    }
    passDrawFieldRow(input.auxiliary, in: context, x: margin, top: 136.0, width: width, style: smallRow, valueColor: pass.foregroundColor.cgColor, labelColor: pass.labelColor.cgColor)
    passDrawFieldRow(input.secondary, in: context, x: margin, top: 184.0, width: width, style: smallRow, valueColor: pass.foregroundColor.cgColor, labelColor: pass.labelColor.cgColor)
}

private func drawStripStyle(_ input: PassDrawingInput, in context: CGContext, stripHeight: CGFloat, primaryValueSize: CGFloat, rowsBelow: [[PassResolvedField]]) {
    let pass = input.contents.pass
    let width = input.size.width - margin * 2.0
    let stripRect = CGRect(x: 0.0, y: headerHeight, width: input.size.width, height: stripHeight)
    if let strip = input.contents.images[.strip] {
        context.interpolationQuality = .high
        passDrawImageFilling(strip, in: context, rect: stripRect)
    }
    if let primary = input.primary.first {
        passDrawFieldRow([PassResolvedField(label: primary.label, text: primary.text, alignment: .left)], in: context, x: margin, top: stripRect.minY + 8.0, width: width, style: PassFieldRowStyle(labelSize: 12.0, valueSize: primaryValueSize, minValueSize: 16.0, valueWeight: -0.4, labelAboveValue: false), valueColor: pass.foregroundColor.cgColor, labelColor: pass.foregroundColor.cgColor)
    }
    var top = stripRect.maxY + 8.0
    for row in rowsBelow where !row.isEmpty {
        top += passDrawFieldRow(row, in: context, x: margin, top: top, width: width, style: smallRow, valueColor: pass.foregroundColor.cgColor, labelColor: pass.labelColor.cgColor) + 8.0
    }
}

private func drawThumbnailStyle(_ input: PassDrawingInput, in context: CGContext) {
    let pass = input.contents.pass
    let fullWidth = input.size.width - margin * 2.0
    var textWidth = fullWidth
    let primaryTop: CGFloat = 62.0
    var thumbnailBottom = primaryTop
    if let thumbnail = input.contents.images[.thumbnail] {
        let size = passAspectFit(CGSize(width: thumbnail.width, height: thumbnail.height), in: CGSize(width: 80.0, height: 80.0))
        context.interpolationQuality = .high
        passDrawImage(thumbnail, in: context, rect: CGRect(x: input.size.width - margin - size.width, y: primaryTop, width: size.width, height: size.height))
        textWidth -= size.width + 10.0
        thumbnailBottom = primaryTop + size.height + 6.0
    }
    var top = primaryTop
    if let primary = input.primary.first {
        top += passDrawFieldRow([PassResolvedField(label: primary.label, text: primary.text, alignment: .left)], in: context, x: margin, top: top, width: textWidth, style: PassFieldRowStyle(labelSize: 11.0, valueSize: 24.0, minValueSize: 14.0, valueWeight: 0.0, labelAboveValue: true), valueColor: pass.foregroundColor.cgColor, labelColor: pass.labelColor.cgColor) + 10.0
    }
    if !input.secondary.isEmpty {
        top += passDrawFieldRow(input.secondary, in: context, x: margin, top: top, width: textWidth, style: smallRow, valueColor: pass.foregroundColor.cgColor, labelColor: pass.labelColor.cgColor) + 10.0
    }
    let auxiliaryWidth = top >= thumbnailBottom ? fullWidth : textWidth
    passDrawFieldRow(input.auxiliary, in: context, x: margin, top: top, width: auxiliaryWidth, style: smallRow, valueColor: pass.foregroundColor.cgColor, labelColor: pass.labelColor.cgColor)
}

func drawPass(_ input: PassDrawingInput, in context: CGContext) {
    let pass = input.contents.pass
    let bounds = CGRect(origin: .zero, size: input.size)
    context.setFillColor(pass.backgroundColor.cgColor)
    context.fill(bounds)
    if case .eventTicket = pass.style, input.contents.images[.strip] == nil, let background = input.contents.images[.background], let image = blurred(background) {
        context.interpolationQuality = .high
        passDrawImageFilling(image, in: context, rect: bounds)
        context.setFillColor(CGColor(gray: 0.0, alpha: 0.2))
        context.fill(bounds)
    }
    drawHeader(input, in: context)
    switch pass.style {
    case .boardingPass:
        drawBoardingPass(input, in: context)
    case .storeCard, .coupon:
        drawStripStyle(input, in: context, stripHeight: 123.0, primaryValueSize: 44.0, rowsBelow: [input.secondary + input.auxiliary])
    case .eventTicket:
        if input.contents.images[.strip] != nil {
            drawStripStyle(input, in: context, stripHeight: 84.0, primaryValueSize: 24.0, rowsBelow: [input.secondary, input.auxiliary])
        } else {
            drawThumbnailStyle(input, in: context)
        }
    case .generic:
        drawThumbnailStyle(input, in: context)
    }
}
