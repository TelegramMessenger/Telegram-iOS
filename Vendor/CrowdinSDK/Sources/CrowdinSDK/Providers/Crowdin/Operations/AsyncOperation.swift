//
//  AsyncOperation.swift
//  BaseAPIPackageDescription
//
//  Created by Serhii Londar on 5/19/18.
//
import Foundation

protocol AnyAsyncOperation {
    var failed: Bool { get }
    var state: AsyncOperation.State { get }
    func finish(with fail: Bool)
}

class AsyncOperation: Operation, AnyAsyncOperation {
    var failed: Bool = false
    enum State: String {
        case ready, executing, finished
        fileprivate var keyPath: String {
            return "is" + self.rawValue.capitalized
        }
    }
    var state = State.ready {
        willSet {
            willChangeValue(forKey: newValue.keyPath)
            willChangeValue(forKey: state.keyPath)
        }
        didSet {
            didChangeValue(forKey: oldValue.keyPath)
            didChangeValue(forKey: state.keyPath)
        }
    }
    override var isReady: Bool {
        return super.isReady && state == .ready
    }
    override var isExecuting: Bool {
        return state == .executing
    }
    override var isFinished: Bool {
        return state == .finished
    }
    override var isAsynchronous: Bool {
        return true
    }
    override func start() {
        if isCancelled { state = .finished; return }
        guard !hasCancelledDependencies else{ cancel(); return }
        state = .executing
        main()
    }
    override func main() {
        fatalError("Should be overriden in child class")
    }
    override func cancel() {
        state = .finished
    }
    func finish(with fail: Bool) {
        self.failed = fail
        state = .finished
    }
}

private extension AsyncOperation {
    var hasCancelledDependencies: Bool{
        return dependencies.reduce(false){ $0 || $1.isCancelled }
    }
}
