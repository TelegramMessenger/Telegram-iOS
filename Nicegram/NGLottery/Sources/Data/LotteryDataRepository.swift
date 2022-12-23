import Combine
import Foundation
import NGCore

@available(iOS 13.0, *)
public protocol LotteryDataRepository {
    func lotteryDataPublisher() -> AnyPublisher<LotteryNetworkData?, Never>
    func setLotteryData(_: LotteryNetworkData?)
}

@available(iOS 13.0, *)
public class LotteryDataRepositoryImpl {
    
    //  MARK: - Dependencies
    
    private let baseRepo = BaseRepository<LotteryNetworkData?>(value: nil)
    
    //  MARK: - Lifecycle
    
    public init() {}
}

@available(iOS 13.0, *)
extension LotteryDataRepositoryImpl: LotteryDataRepository {
    public func lotteryDataPublisher() -> AnyPublisher<LotteryNetworkData?, Never> {
        return baseRepo.valuePublisher()
    }
    
    public func setLotteryData(_ data: LotteryNetworkData?) {
        baseRepo.set(data)
    }
}
