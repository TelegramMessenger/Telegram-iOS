import Foundation
import NGLocalDataSources
import NGModels
import NGRemoteDataSources

public protocol UserEsimsRepository {
    func getUserEsims() -> [UserEsim]?
    func fetchAllEsims(completion: ((Result<[UserEsim], FetchUserEsimsError>) -> ())?)
    func refreshEsims(ids: [String], completion: ((Result<[UserEsim], Error>) -> ())?)
    func getEsim(with: String) -> UserEsim?
    func addEsim(_: UserEsim)
    func updateEsim(_: UserEsim)
    func clear()
}

public class UserEsimsRepositoryImpl {
    
    //  MARK: - Dependencies
    
    private let localDataSource: UserEsimsLocalDataSource
    private let remoteDataSource: UserEsimsRemoteDataSource
    
    //  MARK: - Logic
    
    private var esims: [UserEsim]?
    
    //  MARK: - Lifecycle
    
    public init(localDataSource: UserEsimsLocalDataSource, remoteDataSource: UserEsimsRemoteDataSource) {
        self.localDataSource = localDataSource
        self.remoteDataSource = remoteDataSource
    }
}

//  MARK: - Repository Impl

extension UserEsimsRepositoryImpl: UserEsimsRepository {
    public func getUserEsims() -> [UserEsim]? {
        if let esims = esims {
            return esims
        } else {
            return getAllEsimsFromLocalDataSource()
        }
    }
    
    public func fetchAllEsims(completion: ((Result<[UserEsim], FetchUserEsimsError>) -> ())?) {
        if let esims = esims {
            completion?(.success(esims))
        } else {
            fetchAllEsimsFromRemoteDataSource(completion: completion)
        }
    }
    
    public func refreshEsims(ids: [String], completion: ((Result<[UserEsim], Error>) -> ())?) {
        guard !ids.isEmpty else {
            completion?(.success([]))
            return
        }
        remoteDataSource.fetchDetails(esimIds: ids) { [weak self] result in
            guard let self = self else { return }
            
            switch result {
            case .success(let esims):
                esims.forEach({ self.updateEsim($0) })
            case .failure(_):
                break
            }
            
            completion?(result)
        }
    }
    
    public func getEsim(with id: String) -> UserEsim? {
        return esims?.first(where: { $0.id ==  id})
    }
    
    public func addEsim(_ esim: UserEsim) {
        self.esims?.append(esim)
        updateLocalCache()
    }
    
    public func updateEsim(_ esim: UserEsim) {
        guard let hitIndex = esims?.firstIndex(where: { $0.id == esim.id }) else { return }
        esims?[hitIndex] = esim
        updateLocalCache()
    }
    
    public func clear() {
        self.esims = nil
        self.localDataSource.save([])
    }
}

//  MARK: - Private Functions

private extension UserEsimsRepositoryImpl {
    func fetchAllEsimsFromRemoteDataSource(completion: ((Result<[UserEsim], FetchUserEsimsError>) -> ())?) {
        remoteDataSource.fetchAllEsims { [weak self] result in
            guard let self =  self else { return }
            
            switch result {
            case .success(let esims):
                self.esims = esims
                self.saveEsimsToLocalCache(esims: esims)
            case .failure(_):
                break
            }
            completion?(result)
        }
    }
    
    func getAllEsimsFromLocalDataSource() -> [UserEsim]? {
        let esims = localDataSource.getCachedUserEsims()
        return esims
    }
    
    func saveEsimsToLocalCache(esims: [UserEsim]) {
        localDataSource.save(esims)
    }
    
    func updateLocalCache() {
        if let esims = esims {
            saveEsimsToLocalCache(esims: esims)
        }
    }
}
