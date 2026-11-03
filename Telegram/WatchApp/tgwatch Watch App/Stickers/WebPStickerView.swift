import SwiftUI
import UIKit
import WatchKit
import WebPKit

/// Static-image sticker (WEBP). watchOS lacks a native WebP codec in ImageIO,
/// so we use the vendored libwebp via WebPKit. Falls back to the raster thumbnail
/// (which IS decodable via UIImage — JPEG/PNG only) while the main file downloads;
/// falls back to a gray placeholder of the correct aspect ratio if neither is available.
struct WebPStickerView: View {
    let sticker: StickerVisual
    let displaySize: CGSize

    var body: some View {
        Group {
            if let path = sticker.localPath,
               let cgImage = WebPDecoder.decode(url: URL(fileURLWithPath: path)) {
                Image(decorative: cgImage, scale: WKInterfaceDevice.current().screenScale)
                    .resizable()
                    .scaledToFit()
            } else if let thumbPath = sticker.thumbnailLocalPath,
                      let img = decodeThumbnail(thumbPath, format: sticker.thumbnailFormat) {
                Image(uiImage: img).resizable().scaledToFit()
            } else {
                Color.gray.opacity(0.2)
            }
        }
        .frame(width: displaySize.width, height: displaySize.height)
    }

    /// Decodes the raster thumbnail. JPEG/PNG go through UIImage (native); WEBP thumbnails
    /// go through WebPKit. Returns nil if format is unknown or decode fails.
    private func decodeThumbnail(_ path: String, format: ThumbnailFormatKind?) -> UIImage? {
        switch format {
        case .webp:
            guard let cg = WebPDecoder.decode(url: URL(fileURLWithPath: path)) else { return nil }
            return UIImage(cgImage: cg)
        case .jpeg, .png:
            return UIImage(contentsOfFile: path)
        case .unsupported, nil:
            return nil
        }
    }
}
