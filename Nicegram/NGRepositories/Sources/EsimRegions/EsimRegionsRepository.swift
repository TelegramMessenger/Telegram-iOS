import Foundation
import NGModels

public protocol EsimRegionsRepository {
    func fetchRegions(completion: ((Result<[EsimRegion], Error>) -> ())?)
    func getRegionWith(id: Int) -> EsimRegion?
}
