import Foundation
import CoreGraphics
import ImageIO

public let passRenderDesignSize = CGSize(width: 320.0, height: 252.0)

public let passRenderLayoutVersion: Int = 5

public struct PassRenderOptions {
    public var language: String
    public var scale: Int
    public var timeZone: TimeZone
    public var transitGlyph: (PassTransitType) -> CGImage?

    public init(language: String, scale: Int, timeZone: TimeZone = .current, transitGlyph: @escaping (PassTransitType) -> CGImage? = { _ in nil }) {
        self.language = language
        self.scale = min(3, max(1, scale))
        self.timeZone = timeZone
        self.transitGlyph = transitGlyph
    }
}

public func renderPass(contents: PassContents, options: PassRenderOptions) -> CGImage? {
    let scale = CGFloat(options.scale)
    let size = passRenderDesignSize
    guard let context = CGContext(data: nil, width: Int(size.width * scale), height: Int(size.height * scale), bitsPerComponent: 8, bytesPerRow: 0, space: CGColorSpace(name: CGColorSpace.sRGB)!, bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue) else {
        return nil
    }
    context.translateBy(x: 0.0, y: size.height * scale)
    context.scaleBy(x: scale, y: -scale)

    let formatting = PassFormattingContext(language: options.language, timeZone: options.timeZone)
    func resolve(_ fields: [PassField], limit: Int) -> [PassResolvedField] {
        return fields.prefix(limit).map { field in
            return PassResolvedField(label: passFieldLabel(field, strings: contents.strings, context: formatting), text: passFieldText(field, strings: contents.strings, context: formatting), alignment: field.textAlignment)
        }
    }
    let pass = contents.pass
    var glyph: CGImage?
    if case let .boardingPass(transitType) = pass.style {
        glyph = options.transitGlyph(transitType)
    }
    let input = PassDrawingInput(
        contents: contents,
        logoText: pass.logoText.flatMap { contents.strings.localized($0, language: options.language) },
        header: resolve(pass.headerFields, limit: 2),
        primary: resolve(pass.primaryFields, limit: 2),
        secondary: resolve(pass.secondaryFields, limit: 4),
        auxiliary: resolve(pass.auxiliaryFields, limit: 5),
        transitGlyph: glyph,
        size: size
    )
    drawPass(input, in: context)
    return context.makeImage()
}

public func renderPass(path: String, options: PassRenderOptions) -> CGImage? {
    guard let contents = loadPassContents(path: path, scale: options.scale) else {
        return nil
    }
    return renderPass(contents: contents, options: options)
}

public func renderPassPNG(path: String, options: PassRenderOptions) -> Data? {
    guard let image = renderPass(path: path, options: options) else {
        return nil
    }
    let data = NSMutableData()
    guard let destination = CGImageDestinationCreateWithData(data, "public.png" as CFString, 1, nil) else {
        return nil
    }
    CGImageDestinationAddImage(destination, image, nil)
    guard CGImageDestinationFinalize(destination) else {
        return nil
    }
    return data as Data
}
