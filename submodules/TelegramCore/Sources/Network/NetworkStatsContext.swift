import Foundation
import SwiftSignalKit
import Postbox

final class NetworkStatsContext {
    enum NetworkType: Int32 {
        case wifi = 0
        case cellular = 1
    }
    
    struct DownloadEvent {
        let networkType: NetworkType
        let datacenterId: Int32
        let size: Double
        let networkDuration: Double
        let issueDuration: Double
        
        init(
            networkType: NetworkType,
            datacenterId: Int32,
            size: Double,
            networkDuration: Double,
            issueDuration: Double
        ) {
            self.networkType = networkType
            self.datacenterId = datacenterId
            self.size = size
            self.networkDuration = networkDuration
            self.issueDuration = issueDuration
        }
    }
    
    private struct TargetKey: Hashable {
        let networkType: NetworkType
        let datacenterId: Int32
        
        init(networkType: NetworkType, datacenterId: Int32) {
            self.networkType = networkType
            self.datacenterId = datacenterId
        }
    }
    
    private final class AverageStats {
        var networkBps: Double = 0.0
        var issueDuration: Double = 0.0
        var networkDelay: Double = 0.0
        var count: Int = 0
        var size: Int64 = 0
    }
    
    private final class Impl {
        let queue: Queue
        let postbox: Postbox
        
        var averageTargetStats: [TargetKey: AverageStats] = [:]
        
        init(queue: Queue, postbox: Postbox) {
            self.queue = queue
            self.postbox = postbox
        }
        
        func add(downloadEvents: [DownloadEvent]) {
            for event in downloadEvents {
                if event.networkDuration == 0.0 {
                    continue
                }
                let targetKey = TargetKey(networkType: event.networkType, datacenterId: event.datacenterId)
                let averageStats: AverageStats
                if let current = self.averageTargetStats[targetKey] {
                    averageStats = current
                } else {
                    averageStats = AverageStats()
                    self.averageTargetStats[targetKey] = averageStats
                }
                averageStats.count += 1
                averageStats.issueDuration += event.issueDuration
                averageStats.networkDelay += event.issueDuration - event.networkDuration
                averageStats.networkBps += event.size / event.networkDuration
                averageStats.size += Int64(event.size)
            }
            
            self.maybeFlushStats()
        }
        
        private func maybeFlushStats() {
            var removeKeys: [TargetKey] = []
            for (targetKey, averageStats) in self.averageTargetStats {
                if averageStats.count >= 1000 || averageStats.size >= 4 * 1024 * 1024 {
                    addAppLogEvent(postbox: self.postbox, type: "download", data: .dictionary([
                        "n": .number(Double(targetKey.networkType.rawValue)),
                        "d": .number(Double(targetKey.datacenterId)),
                        "b": .number(averageStats.networkBps / Double(averageStats.count)),
                        "nd": .number(averageStats.networkDelay / Double(averageStats.count))
                    ]))
                    removeKeys.append(targetKey)
                }
            }
            for key in removeKeys {
                self.averageTargetStats.removeValue(forKey: key)
            }
        }
    }
    
    private static let sharedQueue = Queue(name: "NetworkStatsContext")
    
    private let queue: Queue
    private let impl: QueueLocalObject<Impl>
    
    init(postbox: Postbox) {
        let queue = NetworkStatsContext.sharedQueue
        self.queue = queue
        self.impl = QueueLocalObject(queue: queue, generate: {
            return Impl(queue: queue, postbox: postbox)
        })
    }
    
    func add(downloadEvents: [DownloadEvent]) {
        self.impl.with { impl in
            impl.add(downloadEvents: downloadEvents)
        }
    }
}
