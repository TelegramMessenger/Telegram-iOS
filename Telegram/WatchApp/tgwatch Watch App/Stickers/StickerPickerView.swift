import SwiftUI

/// Pushable sticker picker. Sections: Favorites, Frequently Used, and a Sticker
/// Sets list (each row pushes a set-detail grid onto the enclosing stack).
/// Pushed inside AttachmentSheet's NavigationStack — it has no stack of its own.
/// Tapping any sticker sends it and, on success, calls `onComplete` to collapse
/// the whole attachment sheet. Registers itself as TDClient's active picker on
/// appear so `updateFile` reaches the store; clears on disappear.
struct StickerPickerView: View {
    let store: StickerPickerStore
    /// Returns true on a successful send.
    let onSend: (PickerSticker) async -> Bool
    /// Collapses the whole attachment sheet after a successful send.
    let onComplete: () -> Void

    @Environment(TDClient.self) private var client
    @Environment(\.dismiss) private var dismiss
    @State private var sending = false

    var body: some View {
        content
            .navigationTitle("")
            .navigationBarBackButtonHidden(true)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
            .environment(store)
            .task {
                client.setActiveStickerPicker(store)
                await store.load()
            }
            .onDisappear { client.setActiveStickerPicker(nil) }
    }

    @ViewBuilder
    private var content: some View {
        switch store.loadState {
        case .loading:
            ProgressView()
        case .failed(let message):
            VStack(spacing: 6) {
                Text(message).font(.caption2).multilineTextAlignment(.center)
                Button("Retry") { Task { await store.load() } }
                    .buttonStyle(.borderedProminent)
            }
            .padding()
        case .loaded:
            loadedBody
        }
    }

    private var loadedBody: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                if !store.favorites.isEmpty {
                    StickerSectionGrid(title: "FAVORITES", stickers: store.favorites, onTap: sendAndComplete)
                }
                if !store.recents.isEmpty {
                    StickerSectionGrid(title: "FREQUENTLY USED", stickers: store.recents, onTap: sendAndComplete)
                }
                if !store.sets.isEmpty {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("STICKER SETS").font(.caption2).foregroundStyle(.secondary).padding(.horizontal, 4)
                        ForEach(store.sets) { set in
                            StickerSetRow(set: set, onSend: sendAndComplete)
                        }
                    }
                }
                if store.favorites.isEmpty && store.recents.isEmpty && store.sets.isEmpty {
                    Text("No stickers yet").font(.caption).foregroundStyle(.secondary).padding(.top, 20)
                }
            }
            .padding(.horizontal, 4)
            .padding(.vertical, 4)
        }
    }

    /// Kicks the async send + collapses the sheet on success. `sending` guards a
    /// rapid double-tap from sending the sticker twice.
    private func sendAndComplete(_ sticker: PickerSticker) {
        guard !sending else { return }
        sending = true
        Task {
            if await onSend(sticker) {
                onComplete()
            } else {
                sending = false
            }
        }
    }
}
