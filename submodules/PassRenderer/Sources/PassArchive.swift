import Foundation
import CoreGraphics
import ImageIO

public enum PassImageKind: String, CaseIterable {
    case logo
    case strip
    case background
    case thumbnail
    case footer
    case icon
}

public struct PassContents {
    public var pass: Pass
    public var strings: PassStringTables
    public var images: [PassImageKind: CGImage]

    public init(pass: Pass, strings: PassStringTables, images: [PassImageKind: CGImage]) {
        self.pass = pass
        self.strings = strings
        self.images = images
    }
}

private let passImageMaxDimension = 4096
private let passImageMaxDecodedDimension = 1024
private let passDrawnImageKinds: [PassImageKind] = [.logo, .strip, .background, .thumbnail]

func passImageFileName(kind: PassImageKind, scale: Int, available: Set<String>) -> String? {
    func name(_ scale: Int) -> String {
        return scale == 1 ? "\(kind.rawValue).png" : "\(kind.rawValue)@\(scale)x.png"
    }
    let order = [scale] + [1, 2, 3].filter { $0 > scale } + [1, 2, 3].filter { $0 < scale }.reversed()
    return order.map(name).first(where: { available.contains($0) })
}

private func decodePassImage(_ data: Data) -> CGImage? {
    guard let source = CGImageSourceCreateWithData(data as CFData, nil), let type = CGImageSourceGetType(source), type as String == "public.png" else {
        return nil
    }
    guard let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any], let width = (properties[kCGImagePropertyPixelWidth] as? NSNumber)?.intValue, let height = (properties[kCGImagePropertyPixelHeight] as? NSNumber)?.intValue else {
        return nil
    }
    guard width > 0, height > 0, width <= passImageMaxDimension, height <= passImageMaxDimension else {
        return nil
    }
    let options: [CFString: Any] = [
        kCGImageSourceCreateThumbnailFromImageAlways: true,
        kCGImageSourceCreateThumbnailWithTransform: false,
        kCGImageSourceThumbnailMaxPixelSize: min(passImageMaxDecodedDimension, max(width, height)),
        kCGImageSourceShouldCacheImmediately: true
    ]
    return CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary)
}

public func loadPassContents(path: String, scale: Int) -> PassContents? {
    guard let archive = PassZipReader(path: path) else {
        return nil
    }
    guard let jsonData = archive.contents(of: "pass.json"), let pass = Pass.parse(jsonData: jsonData) else {
        return nil
    }

    let names = archive.names
    var tables: [String: [String: String]] = [:]
    for name in names {
        let components = name.split(separator: "/", omittingEmptySubsequences: false)
        guard components.count == 2, components[1] == "pass.strings", components[0].hasSuffix(".lproj") else {
            continue
        }
        if let data = archive.contents(of: name) {
            tables[String(components[0].dropLast(".lproj".count))] = parsePassStrings(data)
        }
    }

    var images: [PassImageKind: CGImage] = [:]
    for kind in passDrawnImageKinds {
        guard let name = passImageFileName(kind: kind, scale: scale, available: names), let data = archive.contents(of: name), let image = decodePassImage(data) else {
            continue
        }
        images[kind] = image
    }
    return PassContents(pass: pass, strings: PassStringTables(tables: tables), images: images)
}
