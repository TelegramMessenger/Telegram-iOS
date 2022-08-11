import NGEnv

public protocol RemoteConfigService {
    func get<T: Decodable>(_: T.Type, byKey: String) -> T?
    func fetch<T: Decodable>(_: T.Type, byKey: String, completion: ((T?) -> ())?)
}

public class RemoteConfigServiceImpl {
    
    //  MARK: - Dependencies
    
    private let firebaseRemoteConfig: FirebaseRemoteConfigService
    
    //  MARK: - Lifecycle
    
    public static let shared: RemoteConfigServiceImpl = {
        let firebaseRemoteConfig = FirebaseRemoteConfigService(cacheDuration: NGENV.remote_config_cache_duration_seconds)
        return .init(firebaseRemoteConfig: firebaseRemoteConfig)
    }()
    
    private init(firebaseRemoteConfig: FirebaseRemoteConfigService) {
        self.firebaseRemoteConfig = firebaseRemoteConfig
    }
    
    //  MARK: - Public Functions

    public func prefetch() {
        firebaseRemoteConfig.prefetch()
    }
}

extension RemoteConfigServiceImpl: RemoteConfigService {
    public func get<T>(_ type: T.Type, byKey key: String) -> T? where T : Decodable {
        return firebaseRemoteConfig.get(type, byKey: key)
    }
    
    public func fetch<T>(_ type: T.Type, byKey key: String, completion: ((T?) -> ())?) where T : Decodable {
        firebaseRemoteConfig.fetch(type, byKey: key, completion: completion)
    }
}
