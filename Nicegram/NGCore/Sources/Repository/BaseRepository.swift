import Foundation
import Combine

@available(iOS 13.0, *)
public class BaseRepository<T> {
    
    //  MARK: - Dependencies
    
    private let lockQueue = DispatchQueue(label: "com.denisShilovich.BaseRepositoryLockQueue", attributes: [.concurrent])
    
    //  MARK: - Logic
    
    @Published private var value: T
    
    //  MARK: - Lifecycle
    
    public init(value: T) {
        self.value = value
    }
    
    //  MARK: - Public Functions

    public func get() -> T {
        lockQueue.sync { value }
    }
    
    public func set(_ value: T) {
        lockQueue.async(flags: [.barrier]) {
            self.value = value
        }
    }
    
    public func update(_ block: @escaping (T) -> T) {
        lockQueue.async(flags: [.barrier]) {
            let oldValue = self.value
            let newValue = block(oldValue)
            self.value = newValue
        }
    }
    
    public func valuePublisher() -> AnyPublisher<T, Never> {
        $value.eraseToAnyPublisher()
    }
}
