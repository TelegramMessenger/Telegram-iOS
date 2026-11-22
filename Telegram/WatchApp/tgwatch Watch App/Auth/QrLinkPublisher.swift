import Foundation

/// Stale-data-resistant envelope written to `Library/Caches/qr-link.json` (DEBUG only)
/// so the populate CLI can read the QR link without screen-scraping the watch sim.
///
/// Field-name contract is shared with the CLI; do not rename without updating
/// `tools/tgwatch-populate/Sources/tgwatch-populate/QrLogin.swift`.
struct QrLinkEnvelope: Codable, Equatable {
    /// Raw `tg://login?token=…` string from TDLib. Not URL-encoded further.
    let link: String
    /// Mirrors `TDClient.useTestDc` so the CLI can refuse a prod-DC envelope it
    /// cannot confirm (CLI populate accounts are test-DC only).
    let useTestDc: Bool
    /// Per-process UUID generated at `TDClient` init. Lets the CLI detect a
    /// watch restart mid-poll.
    let sessionId: String
    /// Unix epoch seconds (fractional OK). CLI rejects entries older than ~30s.
    let writtenAt: TimeInterval
}

/// Owns the on-disk lifecycle of `qr-link.json`. All I/O is injected so unit
/// tests run without touching the real watch container.
struct QrLinkPublisher {
    /// `nil` → disabled (release builds, or any path where there's no caches dir).
    let writeURL: URL?
    let now: () -> Foundation.Date
    let writeData: (Data, URL) throws -> Void
    let removeItem: (URL) throws -> Void

    /// No-op publisher used by release builds and disabled tests.
    static let disabled = QrLinkPublisher(
        writeURL: nil,
        now: { Foundation.Date() },
        writeData: { _, _ in },
        removeItem: { _ in }
    )

    /// Production wiring: writes to `<caches>/qr-link.json` atomically. Returns a
    /// disabled publisher in release builds so the file never appears in users' caches.
    static func defaultProduction() -> QrLinkPublisher {
#if DEBUG
        guard let cachesURL = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first else {
            return .disabled
        }
        let url = cachesURL.appendingPathComponent("qr-link.json")
        return QrLinkPublisher(
            writeURL: url,
            now: { Foundation.Date() },
            writeData: { data, dest in
                // .atomic writes via a temp + rename, so a partial read is impossible.
                try data.write(to: dest, options: [.atomic])
            },
            removeItem: { url in
                if FileManager.default.fileExists(atPath: url.path) {
                    try FileManager.default.removeItem(at: url)
                }
            }
        )
#else
        return .disabled
#endif
    }

    /// Encodes an envelope and writes it. Silently ignores write errors — the
    /// envelope is best-effort smoke-test plumbing, not load-bearing.
    func publish(link: String, useTestDc: Bool, sessionId: UUID) {
        guard let writeURL else { return }
        let envelope = QrLinkEnvelope(
            link: link,
            useTestDc: useTestDc,
            sessionId: sessionId.uuidString,
            writtenAt: now().timeIntervalSince1970
        )
        guard let data = try? JSONEncoder().encode(envelope) else { return }
        try? writeData(data, writeURL)
    }

    /// Removes the envelope file if present. Safe to call when the file doesn't exist.
    func clear() {
        guard let writeURL else { return }
        try? removeItem(writeURL)
    }
}
