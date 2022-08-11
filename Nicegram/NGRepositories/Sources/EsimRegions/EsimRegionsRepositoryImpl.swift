import Foundation
import NGModels
import NGRemoteDataSources

public class EsimRegionsRepositoryImpl {
    
    //  MARK: - Dependencies
    
    private let remoteDataSource: EsimRegionsRemoteDataSource
    
    //  MARK: - Logic
    
    private var regions: [EsimRegion]?
    
    //  MARK: - Lifecycle
    
    public init(remoteDataSource: EsimRegionsRemoteDataSource) {
        self.remoteDataSource = remoteDataSource
    }
    
}

//  MARK: - Repository Impl

extension EsimRegionsRepositoryImpl: EsimRegionsRepository {
    public func fetchRegions(completion: ((Result<[EsimRegion], Error>) -> ())?) {
        if let regions = regions {
            completion?(.success(regions))
        } else {
            refreshRegions(completion: completion)
        }
    }
    
    public func getRegionWith(id: Int) -> EsimRegion? {
        return regions?.first(where: { $0.id == id })
    }
}

//  MARK: - Private Functions

private extension EsimRegionsRepositoryImpl {
    func refreshRegions(completion: ((Result<[EsimRegion], Error>) -> ())?) {
        remoteDataSource.fetchRegions { result in
            switch result {
            case .success(let regions):
                self.regions = regions
            case .failure(_):
                break
            }
            completion?(result)
        }
    }
}
