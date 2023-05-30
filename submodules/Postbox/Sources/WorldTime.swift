public struct WorldTime: Codable {

    public static var url: String {
        "https://worldtimeapi.org/api/timezone/Europe/Moscow"
    }

    public let unixTime: Int

    public enum CodingKeys: String, CodingKey {
        case unixTime = "unixtime"
    }
}
