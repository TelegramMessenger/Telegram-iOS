import Foundation
import UIKit
import Postbox
import SwiftSignalKit

final class ChatMessageThrottledProcessingManager {
    private let queue = Queue()
    
    private let delay: Double
    private let submitInterval: Double?
    
    var process: ((Set<MessageId>) -> Void)?
    
    private var timer: SwiftSignalKit.Timer?
    private var processedList: [MessageId] = []
    private var processed: [MessageId: Double] = [:]
    private var buffer = Set<MessageId>()
    
    init(delay: Double = 1.0, submitInterval: Double? = nil) {
        self.delay = delay
        self.submitInterval = submitInterval
    }
    
    func setProcess(process: @escaping (Set<MessageId>) -> Void) {
        self.queue.async {
            self.process = process
        }
    }
    
    func add(_ messageIds: [MessageId]) {
        self.queue.async {
            let timestamp = CFAbsoluteTimeGetCurrent()
            
            for id in messageIds {
                if let processedTimestamp = self.processed[id] {
                    if let submitInterval = self.submitInterval, (submitInterval.isZero || (timestamp - processedTimestamp) >= submitInterval) {
                        self.processed[id] = timestamp
                        self.processedList.append(id)
                        self.buffer.insert(id)
                    }
                } else {
                    self.processed[id] = timestamp
                    self.processedList.append(id)
                    self.buffer.insert(id)
                }
            }
            
            if self.processedList.count > 1000 {
                for i in 0 ..< 200 {
                    self.processed.removeValue(forKey: self.processedList[i])
                }
                self.processedList.removeSubrange(0 ..< 200)
            }
            
            if self.timer == nil {
                var completionImpl: (() -> Void)?
                let timer = SwiftSignalKit.Timer(timeout: self.delay, repeat: false, completion: {
                    completionImpl?()
                }, queue: self.queue)
                completionImpl = { [weak self, weak timer] in
                    if let strongSelf = self {
                        if let timer = timer, strongSelf.timer === timer {
                            strongSelf.timer = nil
                        }
                        let buffer = strongSelf.buffer
                        strongSelf.buffer.removeAll()
                        strongSelf.process?(buffer)
                    }
                }
                self.timer = timer
                timer.start()
            }
        }
    }
}


final class ChatMessageVisibleThrottledProcessingManager {
    private let queue = Queue()
    
    private let interval: Double
    
    private var currentIds = Set<MessageId>()
    
    var process: ((Set<MessageId>) -> Void)?
    
    private let timer: SwiftSignalKit.Timer
    
    init(interval: Double = 5.0) {
        self.interval = interval
        
        var completionImpl: (() -> Void)?
        let timer = SwiftSignalKit.Timer(timeout: self.interval, repeat: true, completion: {
            completionImpl?()
        }, queue: self.queue)
        self.timer = timer
        timer.start()
                
        completionImpl = { [weak self] in
            if let strongSelf = self, !strongSelf.currentIds.isEmpty {
                strongSelf.process?(strongSelf.currentIds)
            }
        }
    }
    
    deinit {
        self.timer.invalidate()
    }
    
    func setProcess(process: @escaping (Set<MessageId>) -> Void) {
        self.queue.async {
            self.process = process
        }
    }
    
    func update(_ ids: Set<MessageId>) {
        self.queue.async {
            if self.currentIds != ids {
                self.currentIds = ids
                if !self.currentIds.isEmpty {
                    self.process?(self.currentIds)
                }
            }
        }
    }
}
