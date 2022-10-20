import Postbox

public struct LocalizationInfo: PostboxCoding, Codable, Equatable {
    public let languageCode: String
    public let baseLanguageCode: String?
    public let customPluralizationCode: String?
    public let title: String
    public let localizedTitle: String
    public let isOfficial: Bool
    public let totalStringCount: Int32
    public let translatedStringCount: Int32
    public let platformUrl: String
    
    public init(languageCode: String, baseLanguageCode: String?, customPluralizationCode: String?, title: String, localizedTitle: String, isOfficial: Bool, totalStringCount: Int32, translatedStringCount: Int32, platformUrl: String) {
        self.languageCode = languageCode
        self.baseLanguageCode = baseLanguageCode
        self.customPluralizationCode = customPluralizationCode
        self.title = title
        self.localizedTitle = localizedTitle
        self.isOfficial = isOfficial
        self.totalStringCount = totalStringCount
        self.translatedStringCount = translatedStringCount
        self.platformUrl = platformUrl
    }
    
    public init(decoder: PostboxDecoder) {
        self.languageCode = decoder.decodeStringForKey("lc", orElse: "")
        self.baseLanguageCode = decoder.decodeOptionalStringForKey("nlc")
        self.customPluralizationCode = decoder.decodeOptionalStringForKey("cpc")
        self.title = decoder.decodeStringForKey("t", orElse: "")
        self.localizedTitle = decoder.decodeStringForKey("lt", orElse: "")
        self.isOfficial = decoder.decodeInt32ForKey("of", orElse: 0) != 0
        self.totalStringCount = decoder.decodeInt32ForKey("tsc", orElse: 0)
        self.translatedStringCount = decoder.decodeInt32ForKey("lsc", orElse: 0)
        self.platformUrl = decoder.decodeStringForKey("platformUrl", orElse: "")
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: StringCodingKey.self)

        self.languageCode = (try? container.decode(String.self, forKey: "lc")) ?? ""
        self.baseLanguageCode = try? container.decodeIfPresent(String.self, forKey: "nlc")
        self.customPluralizationCode = try? container.decodeIfPresent(String.self, forKey: "cpc")
        self.title = (try? container.decode(String.self, forKey: "t")) ?? ""
        self.localizedTitle = (try? container.decode(String.self, forKey: "lt")) ?? ""
        self.isOfficial = ((try? container.decode(Int32.self, forKey: "of")) ?? 0) != 0
        self.totalStringCount = (try? container.decode(Int32.self, forKey: "tsc")) ?? 0
        self.translatedStringCount = (try? container.decode(Int32.self, forKey: "lsc")) ?? 0
        self.platformUrl = (try? container.decode(String.self, forKey: "platformUrl")) ?? ""
    }
    
    public func encode(_ encoder: PostboxEncoder) {
        encoder.encodeString(self.languageCode, forKey: "lc")
        if let baseLanguageCode = self.baseLanguageCode {
            encoder.encodeString(baseLanguageCode, forKey: "nlc")
        } else {
            encoder.encodeNil(forKey: "nlc")
        }
        if let customPluralizationCode = self.customPluralizationCode {
            encoder.encodeString(customPluralizationCode, forKey: "cpc")
        } else {
            encoder.encodeNil(forKey: "cpc")
        }
        encoder.encodeString(self.title, forKey: "t")
        encoder.encodeString(self.localizedTitle, forKey: "lt")
        encoder.encodeInt32(self.isOfficial ? 1 : 0, forKey: "of")
        encoder.encodeInt32(self.totalStringCount, forKey: "tsc")
        encoder.encodeInt32(self.translatedStringCount, forKey: "lsc")
        encoder.encodeString(self.platformUrl, forKey: "platformUrl")
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: StringCodingKey.self)

        try container.encode(self.languageCode, forKey: "lc")
        try container.encodeIfPresent(self.baseLanguageCode, forKey: "nlc")
        try container.encodeIfPresent(self.customPluralizationCode, forKey: "cpc")
        try container.encode(self.title, forKey: "t")
        try container.encode(self.localizedTitle, forKey: "lt")
        try container.encode((self.isOfficial ? 1 : 0) as Int32, forKey: "of")
        try container.encode(self.totalStringCount, forKey: "tsc")
        try container.encode(self.translatedStringCount, forKey: "lsc")
        try container.encode(self.platformUrl, forKey: "platformUrl")
    }
}
