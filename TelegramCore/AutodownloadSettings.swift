import Foundation
#if os(macOS)
    import PostboxMac
    import SwiftSignalKitMac
#else
    import Postbox
    import SwiftSignalKit
#endif

public enum AutodownloadPreset {
    case low
    case medium
    case high
}

public struct AutodownloadPresetSettings: PostboxCoding, Equatable {
    public let disabled: Bool
    public let photoSizeMax: Int32
    public let videoSizeMax: Int32
    public let fileSizeMax: Int32
    public let preloadLargeVideo: Bool
    
    init(disabled: Bool, photoSizeMax: Int32, videoSizeMax: Int32, fileSizeMax: Int32, preloadLargeVideo: Bool) {
        self.disabled = disabled
        self.photoSizeMax = photoSizeMax
        self.videoSizeMax = videoSizeMax
        self.fileSizeMax = fileSizeMax
        self.preloadLargeVideo = preloadLargeVideo
    }
    
    public init(decoder: PostboxDecoder) {
        self.disabled = decoder.decodeInt32ForKey("disabled", orElse: 0) != 0
        self.photoSizeMax = decoder.decodeInt32ForKey("photoSizeMax", orElse: 0)
        self.videoSizeMax = decoder.decodeInt32ForKey("videoSizeMax", orElse: 0)
        self.fileSizeMax = decoder.decodeInt32ForKey("fileSizeMax", orElse: 0)
        self.preloadLargeVideo = decoder.decodeInt32ForKey("preloadLargeVideo", orElse: 0) != 0
    }
    
    public func encode(_ encoder: PostboxEncoder) {
        encoder.encodeInt32(self.disabled ? 1 : 0, forKey: "disabled")
        encoder.encodeInt32(self.photoSizeMax, forKey: "photoSizeMax")
        encoder.encodeInt32(self.videoSizeMax, forKey: "videoSizeMax")
        encoder.encodeInt32(self.fileSizeMax, forKey: "fileSizeMax")
        encoder.encodeInt32(self.preloadLargeVideo ? 1 : 0, forKey: "preloadLargeVideo")
    }
}

public struct AutodownloadSettings: PreferencesEntry, Equatable {
    public let lowPreset: AutodownloadPresetSettings
    public let mediumPreset: AutodownloadPresetSettings
    public let highPreset: AutodownloadPresetSettings
    
    public static var defaultSettings: AutodownloadSettings {
        return AutodownloadSettings(lowPreset: AutodownloadPresetSettings(disabled: false, photoSizeMax: 1 * 1024 * 1024, videoSizeMax: 0, fileSizeMax: 0, preloadLargeVideo: false),
                                    mediumPreset: AutodownloadPresetSettings(disabled: false, photoSizeMax: 1 * 1024 * 1024, videoSizeMax: Int32(2.5 * 1024 * 1024), fileSizeMax: 1 * 1024 * 1024, preloadLargeVideo: false),
                                    highPreset: AutodownloadPresetSettings(disabled: false, photoSizeMax: 1 * 1024 * 1024, videoSizeMax: 10 * 1024 * 1024, fileSizeMax: 3 * 1024 * 1024, preloadLargeVideo: false))
    }
    
    init(lowPreset: AutodownloadPresetSettings, mediumPreset: AutodownloadPresetSettings, highPreset: AutodownloadPresetSettings) {
        self.lowPreset = lowPreset
        self.mediumPreset = mediumPreset
        self.highPreset = highPreset
    }
    
    public init(decoder: PostboxDecoder) {
        self.lowPreset = decoder.decodeObjectForKey("lowPreset", decoder: AutodownloadPresetSettings.init(decoder:)) as! AutodownloadPresetSettings
        self.mediumPreset = decoder.decodeObjectForKey("mediumPreset", decoder: AutodownloadPresetSettings.init(decoder:)) as! AutodownloadPresetSettings
        self.highPreset = decoder.decodeObjectForKey("highPreset", decoder: AutodownloadPresetSettings.init(decoder:)) as! AutodownloadPresetSettings
    }
    
    public func encode(_ encoder: PostboxEncoder) {
        encoder.encodeObject(self.lowPreset, forKey: "lowPreset")
        encoder.encodeObject(self.mediumPreset, forKey: "mediumPreset")
        encoder.encodeObject(self.highPreset, forKey: "highPreset")
    }
    
    public func isEqual(to: PreferencesEntry) -> Bool {
        if let to = to as? AutodownloadSettings {
            return self == to
        } else {
            return false
        }
    }
    
    public static func ==(lhs: AutodownloadSettings, rhs: AutodownloadSettings) -> Bool {
        return lhs.lowPreset == rhs.lowPreset && lhs.mediumPreset == rhs.mediumPreset && lhs.highPreset == rhs.highPreset
    }
}

public func updateAutodownloadSettingsInteractively(accountManager: AccountManager, _ f: @escaping (AutodownloadSettings) -> AutodownloadSettings) -> Signal<Void, NoError> {
    return accountManager.transaction { transaction -> Void in
        transaction.updateSharedData(SharedDataKeys.autodownloadSettings, { entry in
            let currentSettings: AutodownloadSettings
            if let entry = entry as? AutodownloadSettings {
                currentSettings = entry
            } else {
                currentSettings = AutodownloadSettings.defaultSettings
            }
            return f(currentSettings)
        })
    }
}

extension AutodownloadPresetSettings {
    init(apiAutodownloadSettings: Api.AutoDownloadSettings) {
        switch apiAutodownloadSettings {
            case let .autoDownloadSettings(flags, photoSizeMax, videoSizeMax, fileSizeMax):
                self.init(disabled: (flags & (1 << 0)) != 0, photoSizeMax: photoSizeMax, videoSizeMax: videoSizeMax, fileSizeMax: fileSizeMax, preloadLargeVideo: (flags & (1 << 1)) != 0)
        }
    }
}

extension AutodownloadSettings {
    init(apiAutodownloadSettings: Api.account.AutoDownloadSettings) {
        switch apiAutodownloadSettings {
            case let .autoDownloadSettings(low, medium, high):
                self.init(lowPreset: AutodownloadPresetSettings(apiAutodownloadSettings: low), mediumPreset: AutodownloadPresetSettings(apiAutodownloadSettings: medium), highPreset: AutodownloadPresetSettings(apiAutodownloadSettings: high))
        }
    }
}

func apiAutodownloadPresetSettings(_ autodownloadPresetSettings: AutodownloadPresetSettings) -> Api.AutoDownloadSettings {
    var flags: Int32 = 0
    if autodownloadPresetSettings.disabled {
        flags |= (1 << 0)
    }
    if autodownloadPresetSettings.preloadLargeVideo {
        flags |= (1 << 1)
    }
    return .autoDownloadSettings(flags: 0, photoSizeMax: autodownloadPresetSettings.photoSizeMax, videoSizeMax: autodownloadPresetSettings.videoSizeMax, fileSizeMax: autodownloadPresetSettings.fileSizeMax)
}

