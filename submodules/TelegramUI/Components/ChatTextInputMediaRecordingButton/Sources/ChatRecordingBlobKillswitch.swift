import Foundation

/// The server switch that brings back the previous recording blob (`AudioBlob.VoiceBlobView`) in case the liquid
/// glass one misbehaves: any value under this app configuration key, as with the app's other killswitches. While it is
/// on, none of the glass blob runs, not even the background compilation of its pipelines.
enum ChatRecordingBlobKillswitch {
    static let appConfigurationKey = "ios_killswitch_disable_glass_recording_blob"

    /// `appConfigurationValue` looks a key up in the app configuration.
    static func isActive(appConfigurationValue: (String) -> Any?) -> Bool {
        return appConfigurationValue(ChatRecordingBlobKillswitch.appConfigurationKey) != nil
    }
}
