import SwiftUI
import UIKit
import WatchKit
import RLottieKit
import WebPKit
import TDShim

/// One tappable sticker tile. Downloads its render file when visible and decodes
/// it (WebPKit for webp, UIImage for jpeg/png, rlottie frame-0 for tgs) once the
/// local path lands. WEBM (`.none`) shows a neutral placeholder but stays
/// tappable — sending works by remote id regardless.
struct StickerCellView: View {
    let sticker: PickerSticker
    var edge: CGFloat = 72
    var onTap: ((PickerSticker) -> Void)? = nil

    @Environment(StickerPickerStore.self) private var store
    @State private var image: UIImage?

    private var screenScale: CGFloat { WKInterfaceDevice.current().screenScale }

    private var renderFileId: Int? {
        switch sticker.render {
        case .raster(let id, _): return id
        case .lottie(let id): return id
        case .none: return nil
        }
    }

    /// Non-nil only once the render file is fully downloaded with a real path.
    private var localPath: String? {
        guard let id = renderFileId,
              let f = store.fileSnapshot(fileId: id),
              f.local.isDownloadingCompleted,
              !f.local.path.isEmpty else { return nil }
        return f.local.path
    }

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 8).fill(Color.gray.opacity(0.15))
            if let image {
                Image(uiImage: image).resizable().scaledToFit().padding(6)
            }
        }
        .frame(width: edge, height: edge)
        .contentShape(Rectangle())
        .modifier(TapIfPresent(onTap: onTap.map { cb in { cb(sticker) } }))
        .onScrollVisibilityChange(threshold: 0.01) { visible in
            guard let id = renderFileId else { return }
            if visible { store.requestFileDownload(fileId: id, priority: 2) }
            else { store.cancelFileDownload(fileId: id) }
        }
        .task(id: localPath) { decode() }
    }

    private func decode() {
        guard image == nil, let path = localPath else { return }
        let url = URL(fileURLWithPath: path)
        switch sticker.render {
        case .raster(_, let fmt):
            switch fmt {
            case .webp:
                if let cg = WebPDecoder.decode(url: url) { image = UIImage(cgImage: cg) }
            case .jpeg, .png:
                image = UIImage(contentsOfFile: path)
            case .unsupported:
                break
            }
        case .lottie:
            if let anim = LottieAnimation(tgsFileURL: url),
               let cg = anim.renderFrame(index: 0, size: CGSize(width: edge, height: edge), scale: screenScale) {
                image = UIImage(cgImage: cg)
            }
        case .none:
            break
        }
    }
}

/// Applies an `onTapGesture` only when a callback is provided, so a tappable
/// cell never steals taps from an enclosing NavigationLink (cover thumbnails).
private struct TapIfPresent: ViewModifier {
    let onTap: (() -> Void)?
    func body(content: Content) -> some View {
        if let onTap {
            content.onTapGesture { onTap() }
        } else {
            content
        }
    }
}

/// Two-column titled grid of cells. Header omitted when `title` is nil
/// (set-detail uses no header). Lazy so only visible cells download/decode.
struct StickerSectionGrid: View {
    let title: String?
    let stickers: [PickerSticker]
    let onTap: (PickerSticker) -> Void

    private let columns = [GridItem(.flexible(), spacing: 6), GridItem(.flexible(), spacing: 6)]

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            if let title {
                Text(title)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 4)
            }
            LazyVGrid(columns: columns, spacing: 6) {
                ForEach(stickers) { s in
                    StickerCellView(sticker: s, onTap: onTap)
                }
            }
        }
    }
}

#if DEBUG
@MainActor
private func previewPickerStore() -> StickerPickerStore {
    struct NoopPickerLoader: StickerPickerLoader {
        func favoriteStickers() async throws -> [Sticker] { [] }
        func recentStickers() async throws -> [Sticker] { [] }
        func installedStickerSets() async throws -> [StickerSetInfo] { [] }
        func stickerSet(id: TdInt64) async throws -> [Sticker] { [] }
        func downloadFile(fileId: Int, priority: Int) async throws -> File { throw CancellationError() }
        func cancelDownloadFile(fileId: Int) async throws {}
    }
    return StickerPickerStore(loader: NoopPickerLoader())
}

private func previewSticker(_ render: PickerRender) -> PickerSticker {
    PickerSticker(stickerFileId: 1, format: .webp, render: render,
                  remoteFileId: "r", emoji: "✨", width: 512, height: 512)
}

#Preview("Cell — placeholder (downloading)") {
    StickerCellView(sticker: previewSticker(.raster(fileId: 1, format: .webp)), onTap: { _ in })
        .environment(previewPickerStore())
}

#Preview("Cell — webm none") {
    StickerCellView(sticker: previewSticker(.none), onTap: { _ in })
        .environment(previewPickerStore())
}

#Preview("Section grid") {
    StickerSectionGrid(
        title: "FREQUENTLY USED",
        stickers: (1...4).map { PickerSticker(stickerFileId: $0, format: .webp, render: .none, remoteFileId: "r\($0)", emoji: "✨", width: 512, height: 512) },
        onTap: { _ in }
    )
    .environment(previewPickerStore())
}
#endif
