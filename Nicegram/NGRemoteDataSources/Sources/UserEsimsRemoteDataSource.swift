import Foundation
import NGModels
import EsimApiClientDefinition
import EsimDTO
import EsimFeatureMyEsims
import SafeExecutor
import NGMappers

public protocol UserEsimsRemoteDataSource: AnyObject {
    func fetchAllEsims(completion: ((Result<[UserEsim], FetchUserEsimsError>) -> ())?)
    func fetchDetails(esimIds: [String], completion: ((Result<[UserEsim], Error>) -> ())?)
}

public class UserEsimsRemoteDataSourceImpl {
    
    //  MARK: - Dependencies
    
    private let apiClient: EsimApiClientProtocol
    private let userEsimMapper: UserEsimMapper
    
    //  MARK: - Lifecycle
    
    public init(apiClient: EsimApiClientProtocol, userEsimMapper: UserEsimMapper = .init()) {
        self.apiClient = apiClient
        self.userEsimMapper = userEsimMapper
    }
}

extension UserEsimsRemoteDataSourceImpl: UserEsimsRemoteDataSource {
    public func fetchAllEsims(completion: ((Result<[UserEsim], FetchUserEsimsError>) -> ())?) {
        apiClient.send(.getAllUserEsims()) { [weak self] result in
            guard let self = self else { return }
            
            switch result {
            case .success(let dto):
                let mappedEsims = dto.profiles.compactMap({ self.mapDto($0) })
                completion?(.success(mappedEsims))
            case .failure(let error):
                completion?(.failure(self.mapToFetchUserEsimsError(error)))
            }
        }
    }
    
    public func fetchDetails(esimIds: [String], completion: ((Result<[UserEsim], Error>) -> ())?) {
        apiClient.send(.getEsimsDetails(esimsIcc: esimIds)) { [weak self] result in
            guard let self = self else { return }
            
            switch result {
            case .success(let dto):
                let esims = self.mapDtos(dto.profiles)
                completion?(.success(esims))
            case .failure(let error):
                completion?(.failure(error))
            }
        }
    }
}

//  MARK: - Mapping

private extension UserEsimsRemoteDataSourceImpl {
    func mapDtos(_ dtos: [UserEsimDTO]) -> [UserEsim] {
        return dtos.compactMap({ self.mapDto($0) })
    }
    
    func mapDto(_ dto: UserEsimDTO) -> UserEsim? {
        return userEsimMapper.map(dto)
    }
    
    func mapToFetchUserEsimsError(_ error: EsimApiError) -> FetchUserEsimsError {
        switch error {
        case .notAuthorized(_):
            return .notAuthorized
        case .connection(_), .someServerError(_), .underlying(_), .unexpected:
            return .underlying(error)
        }
    }
}
