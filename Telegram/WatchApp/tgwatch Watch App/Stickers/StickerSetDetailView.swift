import SwiftUI

/// One row in the "STICKER SETS" list: cover thumbnail + title. Tapping pushes
/// the set-detail grid (NavigationLink). The cover cell passes no `onTap`, so it
/// never intercepts the row's navigation tap. `onSend` is the picker's
/// send-and-dismiss action, forwarded to the detail grid.
struct StickerSetRow: View {
    let set: PickerSet
    let onSend: (PickerSticker) -> Void

    var body: some View {
        NavigationLink {
            StickerSetDetailView(set: set, onSend: onSend)
        } label: {
            HStack(spacing: 10) {
                if let cover = set.cover {
                    StickerCellView(sticker: cover, edge: 32)
                } else {
                    RoundedRectangle(cornerRadius: 6).fill(Color.gray.opacity(0.15))
                        .frame(width: 32, height: 32)
                }
                Text(set.title).font(.body).lineLimit(1)
                Spacer(minLength: 0)
            }
            .contentShape(Rectangle())
        }
    }
}

/// Grid of one set's stickers. Loads via the store on appear (the store is
/// inherited from the enclosing NavigationStack's environment); tapping a
/// sticker calls `onSend` (send + dismiss the whole picker).
struct StickerSetDetailView: View {
    let set: PickerSet
    let onSend: (PickerSticker) -> Void

    @Environment(StickerPickerStore.self) private var store
    @State private var stickers: [PickerSticker] = []
    @State private var loading = true

    var body: some View {
        ScrollView {
            if loading {
                ProgressView().padding(.top, 20)
            } else {
                StickerSectionGrid(title: nil, stickers: stickers, onTap: onSend)
                    .padding(.horizontal, 4)
            }
        }
        .navigationTitle(set.title)
        .task {
            stickers = await store.loadSet(id: set.setId)
            loading = false
        }
    }
}
