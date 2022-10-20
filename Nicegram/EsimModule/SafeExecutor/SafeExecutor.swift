import Foundation
import ThreadSafeDictionary

public class SafeExecutor<ResultType> {
    struct Operation {
        let id: String
        var completions: [(ResultType) -> ()]
    }
    
    //  MARK: - Internal Logic
    
    private var operations = ThreadSafeDictionary<String, Operation>()
    
    //  MARK: - Lifecycle
    
    public init() {}
    
    //  MARK: - Public Functions
    
    public func execute(id: String, execute: @escaping (((ResultType) -> ())?) -> (), completion: @escaping (ResultType) -> ()) {
        if operations[id] != nil {
            operations[id]?.completions.append(completion)
        } else {
            forceExecute(id: id, execute: execute, completion: completion)
        }
    }
    
    public func forceExecute(id: String, execute: @escaping (((ResultType) -> ())?) -> (), completion: @escaping (ResultType) -> ()) {
        operations[id] = Operation(id: id, completions: [completion])
        
        execute { [weak self] result in
            let completions = self?.operations[id]?.completions ?? []
            self?.operations[id] = nil
            completions.forEach({ $0(result) })
        }
    }
}
