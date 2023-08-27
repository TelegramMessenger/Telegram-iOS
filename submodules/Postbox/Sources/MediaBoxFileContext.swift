import Foundation
import SwiftSignalKit
import RangeSet

protocol MediaBoxFileContext: AnyObject {
    var isEmpty: Bool { get }
    
    func addReference() -> Int
    func removeReference(_ index: Int)
    
    func data(range: Range<Int64>, waitUntilAfterInitialFetch: Bool, next: @escaping (MediaResourceData) -> Void) -> Disposable
    
    func fetched(range: Range<Int64>, priority: MediaBoxFetchPriority, fetch: @escaping (Signal<[(Range<Int64>, MediaBoxFetchPriority)], NoError>) -> Signal<MediaResourceDataFetchResult, MediaResourceDataFetchError>, error: @escaping (MediaResourceDataFetchError) -> Void, completed: @escaping () -> Void) -> Disposable
    func fetchedFullRange(fetch: @escaping (Signal<[(Range<Int64>, MediaBoxFetchPriority)], NoError>) -> Signal<MediaResourceDataFetchResult, MediaResourceDataFetchError>, error: @escaping (MediaResourceDataFetchError) -> Void, completed: @escaping () -> Void) -> Disposable
    func cancelFullRangeFetches()
    func rangeStatus(next: @escaping (RangeSet<Int64>) -> Void, completed: @escaping () -> Void) -> Disposable
    func status(next: @escaping (MediaResourceStatus) -> Void, completed: @escaping () -> Void, size: Int64?) -> Disposable
}
