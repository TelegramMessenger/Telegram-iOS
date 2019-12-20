import Postbox

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
    public let lessDataForPhoneCalls: Bool
    public let videoUploadMaxbitrate: Int32
    
    public init(disabled: Bool, photoSizeMax: Int32, videoSizeMax: Int32, fileSizeMax: Int32, preloadLargeVideo: Bool, lessDataForPhoneCalls: Bool, videoUploadMaxbitrate: Int32) {
        self.disabled = disabled
        self.photoSizeMax = photoSizeMax
        self.videoSizeMax = videoSizeMax
        self.fileSizeMax = fileSizeMax
        self.preloadLargeVideo = preloadLargeVideo
        self.lessDataForPhoneCalls = lessDataForPhoneCalls
        self.videoUploadMaxbitrate = videoUploadMaxbitrate
    }
    
    public init(decoder: PostboxDecoder) {
        self.disabled = decoder.decodeInt32ForKey("disabled", orElse: 0) != 0
        self.photoSizeMax = decoder.decodeInt32ForKey("photoSizeMax", orElse: 0)
        self.videoSizeMax = decoder.decodeInt32ForKey("videoSizeMax", orElse: 0)
        self.fileSizeMax = decoder.decodeInt32ForKey("fileSizeMax", orElse: 0)
        self.preloadLargeVideo = decoder.decodeInt32ForKey("preloadLargeVideo", orElse: 0) != 0
        self.lessDataForPhoneCalls = decoder.decodeInt32ForKey("lessDataForPhoneCalls", orElse: 0) != 0
        self.videoUploadMaxbitrate = decoder.decodeInt32ForKey("videoUploadMaxbitrate", orElse: 0)
    }
    
    public func encode(_ encoder: PostboxEncoder) {
        encoder.encodeInt32(self.disabled ? 1 : 0, forKey: "disabled")
        encoder.encodeInt32(self.photoSizeMax, forKey: "photoSizeMax")
        encoder.encodeInt32(self.videoSizeMax, forKey: "videoSizeMax")
        encoder.encodeInt32(self.fileSizeMax, forKey: "fileSizeMax")
        encoder.encodeInt32(self.preloadLargeVideo ? 1 : 0, forKey: "preloadLargeVideo")
        encoder.encodeInt32(self.lessDataForPhoneCalls ? 1 : 0, forKey: "lessDataForPhoneCalls")
        encoder.encodeInt32(self.videoUploadMaxbitrate, forKey: "videoUploadMaxbitrate")
    }
}

public struct AutodownloadSettings: PreferencesEntry, Equatable {
    public let lowPreset: AutodownloadPresetSettings
    public let mediumPreset: AutodownloadPresetSettings
    public let highPreset: AutodownloadPresetSettings
    
    public static var defaultSettings: AutodownloadSettings {
        return AutodownloadSettings(
            lowPreset: AutodownloadPresetSettings(disabled: false, photoSizeMax: 1 * 1024 * 1024, videoSizeMax: 0, fileSizeMax: 0, preloadLargeVideo: false, lessDataForPhoneCalls: true, videoUploadMaxbitrate: 0),
            mediumPreset: AutodownloadPresetSettings(disabled: false, photoSizeMax: 1 * 1024 * 1024, videoSizeMax: Int32(2.5 * 1024 * 1024), fileSizeMax: 1 * 1024 * 1024, preloadLargeVideo: false, lessDataForPhoneCalls: false, videoUploadMaxbitrate: 0),
            highPreset: AutodownloadPresetSettings(disabled: false, photoSizeMax: 1 * 1024 * 1024, videoSizeMax: 10 * 1024 * 1024, fileSizeMax: 3 * 1024 * 1024, preloadLargeVideo: false, lessDataForPhoneCalls: false, videoUploadMaxbitrate: 0))
    }
    
    public init(lowPreset: AutodownloadPresetSettings, mediumPreset: AutodownloadPresetSettings, highPreset: AutodownloadPresetSettings) {
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
