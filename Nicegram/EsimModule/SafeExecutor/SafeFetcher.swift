public class SafeFetcher<ResultType> {
    
    //  MARK: - Dependencies
    
    private let safeExecutor = SafeExecutor<ResultType>()
    
    //  MARK: - Lifecycle
    
    public init() {}
    
    //  MARK: - Public Functions
    
    public func fetch(id: String, fetchProvider: @escaping (((ResultType) -> ())?) -> (), completion: @escaping (ResultType) -> ()) {
        safeExecutor.execute(id: id, execute: fetchProvider, completion: completion)
    }
    
    public func forceFetch(id: String, fetchProvider: @escaping (((ResultType) -> ())?) -> (), completion: @escaping (ResultType) -> ()) {
        safeExecutor.forceExecute(id: id, execute: fetchProvider, completion: completion)
    }
}
