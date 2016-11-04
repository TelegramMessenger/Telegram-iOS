import Foundation
#if os(macOS)
    import PostboxMac
#else
    import Postbox
#endif

public struct Namespaces {
    public struct Message {
        public static let Cloud: Int32 = 0
        public static let Local: Int32 = 1
    }
    
    public struct Media {
        public static let CloudImage: Int32 = 0
        public static let CloudVideo: Int32 = 1
        public static let CloudAudio: Int32 = 2
        public static let CloudContact: Int32 = 3
        public static let CloudMap: Int32 = 4
        public static let CloudFile: Int32 = 5
        public static let CloudWebpage: Int32 = 6
        public static let LocalImage: Int32 = 7
        public static let LocalFile: Int32 = 8
    }
    
    public struct Peer {
        public static let CloudUser: Int32 = 0
        public static let CloudGroup: Int32 = 1
        public static let CloudChannel: Int32 = 2
        public static let Empty: Int32 = Int32.max
    }
    
    public struct ItemCollection {
        public static let CloudStickerPacks: Int32 = 0
        public static let CloudMaskPacks: Int32 = 1
        public static let CloudRecentGifs: Int32 = 2
        public static let CloudRecentStickers: Int32 = 0
    }
}

public extension MessageTags {
    static let PhotoOrVideo = MessageTags(rawValue: 1 << 0)
    static let File = MessageTags(rawValue: 1 << 1)
    static let Music = MessageTags(rawValue: 1 << 2)
    static let WebPage = MessageTags(rawValue: 1 << 3)
    static let Voice = MessageTags(rawValue: 1 << 4)
}

let allMessageTags: MessageTags = [.PhotoOrVideo, .File, .Music, .WebPage, .Voice]
