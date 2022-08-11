import Foundation
import ThreadSafeDictionary

public class SafeFetcher<ResultType> {
    struct Operation {
        let id: String
        var completions: [(ResultType) -> ()]
    }
    
    //  MARK: - Internal Logic
    
    private var operations = ThreadSafeDictionary<String, Operation>()
    
    //  MARK: - Lifecycle
    
    public init() {}
    
    //  MARK: - Public Functions
    
    public func fetch(id: String, fetchProvider: @escaping (((ResultType) -> ())?) -> (), completion: @escaping (ResultType) -> ()) {
        if operations[id] != nil {
            operations[id]?.completions.append(completion)
        } else {
            forceFetch(id: id, fetchProvider: fetchProvider, completion: completion)
        }
    }
    
    public func forceFetch(id: String, fetchProvider: @escaping (((ResultType) -> ())?) -> (), completion: @escaping (ResultType) -> ()) {
        operations[id] = Operation(id: id, completions: [completion])
        
        fetchProvider { [weak self] result in
            let completions = self?.operations[id]?.completions ?? []
            self?.operations[id] = nil
            completions.forEach({ $0(result) })
        }
    }
}
