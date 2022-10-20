//
//  LogsCollector.swift
//  CrowdinSDK
//
//  Created by Serhii Londar on 11.08.2020.
//

import Foundation

final class AtomicProperty<A> {
    private let queue = DispatchQueue(label: "atomic-serial-queue")
    private var _value: A
    init(_ value: A) {
        self._value = value
    }
    
    var value: A {
        get {
            return queue.sync { self._value }
        }
    }
    
    func mutate(_ transform: (inout A) -> Void) {
        queue.sync {
            transform(&self._value)
        }
    }
}

public final class CrowdinLogsCollector {
    static let shared = CrowdinLogsCollector()
    
    fileprivate var _logs = AtomicProperty<[CrowdinLog]>([])
    
    var logs: [CrowdinLog] {
        return _logs.value
    }
    
    func add(log: CrowdinLog) {
        _logs.mutate { $0.append(log) }
        
        guard let config = CrowdinSDK.config, config.debugEnabled else { return }
        
        print("CrowdinSDK: \(log.message)")
    }
    
    func clear() {
        _logs.mutate { $0.removeAll() }
    }
}
