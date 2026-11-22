import Foundation

/// Display model for a `messageDocument` (generic file). Display-only on watch in milestone #4.
struct DocumentVisual: Equatable, Hashable {
    let documentFileId: Int
    let fileName: String
    let sizeBytes: Int64
    let localPath: String?
    let caption: String
}

/// Human-readable byte count, e.g. "50 MB".
func formatFileSize(_ bytes: Int64) -> String {
    let f = ByteCountFormatter()
    f.countStyle = .file
    f.allowsNonnumericFormatting = false
    return f.string(fromByteCount: bytes)
}
