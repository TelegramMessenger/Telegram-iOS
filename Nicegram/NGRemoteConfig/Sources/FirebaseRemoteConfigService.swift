import FirebaseRemoteConfig
import SafeFetcher

public class FirebaseRemoteConfigService {
    
    //  MARK: - Dependencies
    
    private let remoteConfig: RemoteConfig
    private let safeFetcher: SafeFetcher<()>
    
    //  MARK: - Logic
    
    private let cacheDuration: TimeInterval
    
    //  MARK: - Lifecycle
    
    public init(remoteConfig: RemoteConfig = .remoteConfig(), safeFetcher: SafeFetcher<()> = .init(), cacheDuration: TimeInterval) {
        self.remoteConfig = remoteConfig
        self.safeFetcher = safeFetcher
        self.cacheDuration = cacheDuration
        
        let settings = RemoteConfigSettings()
        settings.minimumFetchInterval = cacheDuration
        remoteConfig.configSettings = settings
    }
    
    //  MARK: - Public Functions
    
    public func prefetch() {
        fetchRemoteConfig(completion: nil)
    }
}

extension FirebaseRemoteConfigService: RemoteConfigService {
    public func get<T>(_: T.Type, byKey key: String) -> T? where T : Decodable {
        let data = remoteConfig.configValue(forKey: key).dataValue
        
        let jsonDecoder = JSONDecoder()
        
        return (try? jsonDecoder.decode(T.self, from: data))
    }
    
    public func fetch<T>(_: T.Type, byKey key: String, completion: ((T?) -> ())?) where T : Decodable {
        fetchRemoteConfig { [weak self] in
            completion?(self?.get(T.self, byKey: key))
        }
    }
}

private extension FirebaseRemoteConfigService {
    func fetchRemoteConfig(completion: (() -> ())?) {
        safeFetcher.fetch(id: "fetchRemoteConfig") { [weak self] completion in
            guard let self = self else { return }
            
            guard self.isCacheExpired() else {
                completion?(())
                return
            }
            
            self.remoteConfig.fetchAndActivate(completionHandler: { _, _ in
                completion?(())
            })
        } completion: { _ in
            completion?()
        }
    }
    
    func isCacheExpired() -> Bool {
        guard let lastSuccessFetchDate = remoteConfig.lastFetchTime else {
            return true
        }
        return (lastSuccessFetchDate.addingTimeInterval(cacheDuration) < Date())
    }
}
