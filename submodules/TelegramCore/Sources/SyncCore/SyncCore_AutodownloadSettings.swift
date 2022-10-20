import Postbox

public enum AutodownloadPreset {
    case low
    case medium
    case high
}

public struct AutodownloadPresetSettings: Codable {
    public let disabled: Bool
    public let photoSizeMax: Int64
    public let videoSizeMax: Int64
    public let fileSizeMax: Int64
    public let preloadLargeVideo: Bool
    public let lessDataForPhoneCalls: Bool
    public let videoUploadMaxbitrate: Int32
    
    public init(disabled: Bool, photoSizeMax: Int64, videoSizeMax: Int64, fileSizeMax: Int64, preloadLargeVideo: Bool, lessDataForPhoneCalls: Bool, videoUploadMaxbitrate: Int32) {
        self.disabled = disabled
        self.photoSizeMax = photoSizeMax
        self.videoSizeMax = videoSizeMax
        self.fileSizeMax = fileSizeMax
        self.preloadLargeVideo = preloadLargeVideo
        self.lessDataForPhoneCalls = lessDataForPhoneCalls
        self.videoUploadMaxbitrate = videoUploadMaxbitrate
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: StringCodingKey.self)

        self.disabled = ((try? container.decode(Int32.self, forKey: "disabled")) ?? 0) != 0
        
        if let photoSizeMax = try? container.decode(Int64.self, forKey: "photoSizeMax64") {
            self.photoSizeMax = photoSizeMax
        } else {
            self.photoSizeMax = Int64((try? container.decode(Int32.self, forKey: "photoSizeMax")) ?? 0)
        }
        if let videoSizeMax = try? container.decode(Int64.self, forKey: "videoSizeMax64") {
            self.videoSizeMax = videoSizeMax
        } else {
            self.videoSizeMax = Int64((try? container.decode(Int32.self, forKey: "videoSizeMax")) ?? 0)
        }
        if let fileSizeMax = try? container.decode(Int64.self, forKey: "fileSizeMax64") {
            self.fileSizeMax = fileSizeMax
        } else {
            self.fileSizeMax = Int64((try? container.decode(Int32.self, forKey: "fileSizeMax")) ?? 0)
        }
        self.preloadLargeVideo = ((try? container.decode(Int32.self, forKey: "preloadLargeVideo")) ?? 0) != 0
        self.lessDataForPhoneCalls = ((try? container.decode(Int32.self, forKey: "lessDataForPhoneCalls")) ?? 0) != 0
        self.videoUploadMaxbitrate = (try? container.decode(Int32.self, forKey: "videoUploadMaxbitrate")) ?? 0
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: StringCodingKey.self)

        try container.encode((self.disabled ? 1 : 0) as Int32, forKey: "disabled")
        try container.encode(self.photoSizeMax, forKey: "photoSizeMax64")
        try container.encode(self.videoSizeMax, forKey: "videoSizeMax64")
        try container.encode(self.fileSizeMax, forKey: "fileSizeMax64")
        try container.encode((self.preloadLargeVideo ? 1 : 0) as Int32, forKey: "preloadLargeVideo")
        try container.encode((self.lessDataForPhoneCalls ? 1 : 0) as Int32, forKey: "lessDataForPhoneCalls")
        try container.encode(self.videoUploadMaxbitrate, forKey: "videoUploadMaxbitrate")
    }
}

public struct AutodownloadSettings: Codable {
    public let lowPreset: AutodownloadPresetSettings
    public let mediumPreset: AutodownloadPresetSettings
    public let highPreset: AutodownloadPresetSettings
    
    public static var defaultSettings: AutodownloadSettings {
        return AutodownloadSettings(
            lowPreset: AutodownloadPresetSettings(disabled: false, photoSizeMax: 1 * 1024 * 1024, videoSizeMax: 0, fileSizeMax: 0, preloadLargeVideo: false, lessDataForPhoneCalls: true, videoUploadMaxbitrate: 0),
            mediumPreset: AutodownloadPresetSettings(disabled: false, photoSizeMax: 1 * 1024 * 1024, videoSizeMax: Int64(2.5 * 1024 * 1024), fileSizeMax: 1 * 1024 * 1024, preloadLargeVideo: false, lessDataForPhoneCalls: false, videoUploadMaxbitrate: 0),
            highPreset: AutodownloadPresetSettings(disabled: false, photoSizeMax: 1 * 1024 * 1024, videoSizeMax: 10 * 1024 * 1024, fileSizeMax: 3 * 1024 * 1024, preloadLargeVideo: false, lessDataForPhoneCalls: false, videoUploadMaxbitrate: 0))
    }
    
    public init(lowPreset: AutodownloadPresetSettings, mediumPreset: AutodownloadPresetSettings, highPreset: AutodownloadPresetSettings) {
        self.lowPreset = lowPreset
        self.mediumPreset = mediumPreset
        self.highPreset = highPreset
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: StringCodingKey.self)

        self.lowPreset = (try? container.decode(AutodownloadPresetSettings.self, forKey: "lowPreset")) ?? AutodownloadSettings.defaultSettings.lowPreset
        self.mediumPreset = (try? container.decode(AutodownloadPresetSettings.self, forKey: "mediumPreset")) ?? AutodownloadSettings.defaultSettings.mediumPreset
        self.highPreset = (try? container.decode(AutodownloadPresetSettings.self, forKey: "highPreset")) ?? AutodownloadSettings.defaultSettings.highPreset
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: StringCodingKey.self)

        try container.encode(self.lowPreset, forKey: "lowPreset")
        try container.encode(self.mediumPreset, forKey: "mediumPreset")
        try container.encode(self.highPreset, forKey: "highPreset")
    }
}
