//
//  Atomic.swift
//  BaseAPI
//
//  Created by Serhii Londar on 3/29/19.
//

import Foundation

final class Atomic<A> {
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
