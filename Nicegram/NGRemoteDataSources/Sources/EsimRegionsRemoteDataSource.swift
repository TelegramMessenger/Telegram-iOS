import Foundation
import NGModels

public protocol EsimRegionsRemoteDataSource {
    func fetchRegions(completion: ((Result<[EsimRegion], Error>) -> ())?)
}
