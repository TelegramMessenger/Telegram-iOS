import Foundation
import NGCore

public protocol LoadLotteryDataUseCase {
    func loadLotteryData(completion: @escaping (Error?) -> Void)
}

@available(iOS 13.0, *)
public class LoadLotteryDataUseCaseImpl {
    
    //  MARK: - Dependencies
    
    private let loadLotteryDataNetworkService: LoadLotteryDataNetworkService
    private let lotteryDataRepository: LotteryDataRepository
    
    //  MARK: - Lifecycle
    
    public init(loadLotteryDataNetworkService: LoadLotteryDataNetworkService, lotteryDataRepository: LotteryDataRepository){
        self.loadLotteryDataNetworkService = loadLotteryDataNetworkService
        self.lotteryDataRepository = lotteryDataRepository
    }
}

@available(iOS 13.0, *)
extension LoadLotteryDataUseCaseImpl: LoadLotteryDataUseCase {
    public func loadLotteryData(completion: @escaping (Error?) -> Void) {
        loadLotteryDataNetworkService.loadLotteryData { result in
            switch result {
            case .success(let success):
                self.lotteryDataRepository.setLotteryData(success)
                
                completion(nil)
            case .failure(let failure):
                completion(failure)
            }
        }
    }
}
