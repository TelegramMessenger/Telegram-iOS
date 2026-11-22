import SwiftUI

/// The "+" attachment menu. A NavigationStack with one row per attachment type.
/// Each row pushes its screen inside THIS stack (avoids the sheet-from-sheet
/// empty-body race; see CLAUDE.md SwiftUI gotchas). `dismiss` here is the
/// sheet's own dismiss, so each screen's `onComplete` collapses the whole sheet
/// after a successful send.
struct AttachmentSheet: View {
    let stickerPickerStore: StickerPickerStore?
    /// Sends a sticker; returns true on success.
    let onSendSticker: (PickerSticker) async -> Bool
    /// Sends a voice note; returns true on success.
    let onSendVoiceNote: (VoiceRecordingDraft) async -> Bool
    /// Stops the chat's voice/audio playback before recording starts.
    let onPrepareVoice: () -> Void
    /// Sends a location; returns true on success.
    let onSendLocation: (_ latitude: Double, _ longitude: Double) async -> Bool

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                if let stickerPickerStore {
                    NavigationLink {
                        StickerPickerView(
                            store: stickerPickerStore,
                            onSend: onSendSticker,
                            onComplete: { dismiss() }
                        )
                    } label: {
                        Label("Sticker", systemImage: "face.smiling")
                    }
                    .accessibilityIdentifier("attachSticker")
                }

                NavigationLink {
                    VoiceRecordView(
                        onSend: onSendVoiceNote,
                        onPrepare: onPrepareVoice,
                        onComplete: { dismiss() }
                    )
                } label: {
                    Label("Voice Message", systemImage: "mic.fill")
                }
                .accessibilityIdentifier("attachVoice")

                NavigationLink {
                    LocationSendView(onSend: onSendLocation, onComplete: { dismiss() })
                } label: {
                    Label("Location", systemImage: "mappin.and.ellipse")
                }
                .accessibilityIdentifier("attachLocation")
            }
            .navigationTitle("Attach")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }
}
