import Foundation

#if DEBUG
public final class VideoExportDebugTimings {
    public struct Entry {
        public let exportStart: Double
        public let exportEnd: Double
        public let writer: String
        public let fileSize: Int64
        public let streamedSize: Int64

        public init(exportStart: Double, exportEnd: Double, writer: String, fileSize: Int64, streamedSize: Int64 = 0) {
            self.exportStart = exportStart
            self.exportEnd = exportEnd
            self.writer = writer
            self.fileSize = fileSize
            self.streamedSize = streamedSize
        }
    }

    public static let shared = VideoExportDebugTimings()

    private let lock = NSLock()
    private var storyEntries: [String: Entry] = [:]
    private var storyUploads: [Int32: (resourceId: String, postTime: Double)] = [:]
    private var chatEntries: [Entry] = []

    public func recordStoryExport(resourceId: String, entry: Entry) {
        self.lock.lock()
        self.storyEntries[resourceId] = entry
        self.lock.unlock()
    }

    public func registerStoryUpload(stableId: Int32, resourceId: String, postTime: Double) {
        self.lock.lock()
        self.storyUploads[stableId] = (resourceId, postTime)
        self.lock.unlock()
    }

    public func takeStoryUpload(stableId: Int32) -> (resourceId: String, postTime: Double, entry: Entry)? {
        self.lock.lock()
        defer {
            self.lock.unlock()
        }
        guard let upload = self.storyUploads.removeValue(forKey: stableId), let entry = self.storyEntries.removeValue(forKey: upload.resourceId) else {
            return nil
        }
        return (upload.resourceId, upload.postTime, entry)
    }

    public func recordChatExport(entry: Entry) {
        self.lock.lock()
        self.chatEntries.append(entry)
        self.lock.unlock()
    }

    public func takeLatestChatExport() -> Entry? {
        self.lock.lock()
        defer {
            self.lock.unlock()
        }
        return self.chatEntries.popLast()
    }
}

public func videoExportDebugWriterName(usesStreamingWriter: Bool) -> String {
    return usesStreamingWriter ? "streaming (VT + FFmpeg)" : "AVAssetWriter"
}
#endif
