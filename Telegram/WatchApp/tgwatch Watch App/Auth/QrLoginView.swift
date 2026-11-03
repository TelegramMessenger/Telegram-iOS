import CoreGraphics
import QRCodeGenerator
import SwiftUI

struct QrLoginView: View {
    let link: String

    @Environment(TDClient.self) private var client

    var body: some View {
        ScrollView {
            QrLoginContent(
                link: link,
                isTestDc: client.useTestDc,
                errorMessage: client.lastError
            )
        }
        .accountSwitcherSheet(presentation: .sheet, logoutAffordance: .suppressed)
    }
}

/// Pure presentational column for the QR-login screen. Hosted inside a `ScrollView` by
/// `QrLoginView`; rendered directly (at a fixed width) by the previews so it captures in
/// SnapshotPreviews, which does not flatten scroll-container content.
struct QrLoginContent: View {
    let link: String
    let isTestDc: Bool
    let errorMessage: String?

    var body: some View {
        VStack(spacing: 12) {
            Text("Log in to Telegram by QR Code")
                .font(.headline)
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity)

            if isTestDc {
                Text("TEST")
                    .font(.caption2.weight(.semibold))
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color.yellow.opacity(0.25), in: Capsule())
                    .foregroundStyle(.yellow)
                    .accessibilityIdentifier("dcTestBadge")
            }

            instructionSteps

            qrCard

            if let errorMessage {
                Text(errorMessage)
                    .font(.footnote)
                    .foregroundStyle(.red)
                    .multilineTextAlignment(.center)
                    .accessibilityIdentifier("qrError")
            }
        }
        .padding()
    }

    private var instructionSteps: some View {
        VStack(spacing: 4) {
            Text("Settings on your Phone")
            Image(systemName: "chevron.down").font(.caption)
            Text("Devices")
            Image(systemName: "chevron.down").font(.caption)
            Text("Scan QR")
        }
        .foregroundStyle(.secondary)
        .multilineTextAlignment(.center)
        .frame(maxWidth: .infinity)
    }

    @ViewBuilder
    private var qrCard: some View {
        Group {
            if let cg = Self.qrCGImage(for: link) {
                Image(decorative: cg, scale: 1.0, orientation: .up)
                    .resizable()
                    .interpolation(.none)
                    .scaledToFit()
                    .accessibilityIdentifier("qrImage")
                    .id(link)
            } else {
                Text("Could not render QR code")
                    .font(.footnote)
                    .foregroundStyle(.red)
                    .frame(maxWidth: .infinity, minHeight: 120)
            }
        }
        .padding(12)
        .background(Color.white, in: RoundedRectangle(cornerRadius: 16))
    }

    /// Renders the link as a QR matrix via the swift-qrcode-generator package, then builds a
    /// grayscale CGImage with a 4-module white quiet zone (ISO 18004 minimum). Returns nil if
    /// encoding fails.
    static func qrCGImage(for link: String) -> CGImage? {
        guard let qr = try? QRCode.encode(text: link, ecl: .medium) else { return nil }
        let qrSize = qr.size
        let quietZone = 4
        let size = qrSize + 2 * quietZone
        var pixels = [UInt8](repeating: 0xFF, count: size * size)
        for row in 0..<qrSize {
            for col in 0..<qrSize {
                if qr.getModule(x: col, y: row) {
                    pixels[(row + quietZone) * size + (col + quietZone)] = 0x00
                }
            }
        }
        guard let provider = CGDataProvider(data: Data(pixels) as CFData) else { return nil }
        return CGImage(
            width: size,
            height: size,
            bitsPerComponent: 8,
            bitsPerPixel: 8,
            bytesPerRow: size,
            space: CGColorSpaceCreateDeviceGray(),
            bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.none.rawValue),
            provider: provider,
            decode: nil,
            shouldInterpolate: false,
            intent: .defaultIntent
        )
    }
}

#if DEBUG
private let qrPreviewLink = "tg://login?token=AQAAAExampleTokenForPreviewRendering123456"

#Preview("Normal") {
    QrLoginContent(link: qrPreviewLink, isTestDc: false, errorMessage: nil)
        .frame(width: 208)
        .background(Color.black)
        .environment(\.colorScheme, .dark)
}

#Preview("Test DC") {
    QrLoginContent(link: qrPreviewLink, isTestDc: true, errorMessage: nil)
        .frame(width: 208)
        .background(Color.black)
        .environment(\.colorScheme, .dark)
}

#Preview("Error") {
    QrLoginContent(link: qrPreviewLink, isTestDc: false, errorMessage: "Couldn't refresh the QR code. Try again.")
        .frame(width: 208)
        .background(Color.black)
        .environment(\.colorScheme, .dark)
}
#endif
