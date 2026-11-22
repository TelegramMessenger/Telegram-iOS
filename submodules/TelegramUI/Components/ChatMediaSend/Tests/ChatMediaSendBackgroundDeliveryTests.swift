import Foundation
import XCTest
import SwiftSignalKit
@testable import ChatMediaSend

final class ChatMediaSendBackgroundDeliveryTests: XCTestCase {
    func testValueAlwaysArrivesBeforeCompletion() {
        let iterations = 3000
        let group = DispatchGroup()
        let lostValues = Atomic<Int>(value: 0)
        var disposables: [Disposable] = []
        for _ in 0 ..< iterations {
            group.enter()
            let received = Atomic<Bool>(value: false)
            let signal: Signal<Int, NoError> = .single(1)
            disposables.append((signal |> chatMediaSendDeliverOnBackground).start(next: { _ in
                let _ = received.swap(true)
            }, completed: {
                if !received.with({ $0 }) {
                    let _ = lostValues.modify { $0 + 1 }
                }
                group.leave()
            }))
        }
        XCTAssertEqual(group.wait(timeout: .now() + 30.0), .success)
        XCTAssertEqual(lostValues.with { $0 }, 0)
        disposables.forEach { $0.dispose() }
    }

    func testMappedSignalStillProducesItsValue() {
        let iterations = 1000
        let group = DispatchGroup()
        let missing = Atomic<Int>(value: 0)
        var disposables: [Disposable] = []
        for index in 0 ..< iterations {
            group.enter()
            let received = Atomic<Int?>(value: nil)
            let signal: Signal<Int, NoError> = .single(index)
            |> chatMediaSendDeliverOnBackground
            |> mapToSignal { value -> Signal<Int, NoError> in
                return .single(value * 2)
            }
            disposables.append(signal.start(next: { value in
                let _ = received.swap(value)
            }, completed: {
                if received.with({ $0 }) != index * 2 {
                    let _ = missing.modify { $0 + 1 }
                }
                group.leave()
            }))
        }
        XCTAssertEqual(group.wait(timeout: .now() + 30.0), .success)
        XCTAssertEqual(missing.with { $0 }, 0)
        disposables.forEach { $0.dispose() }
    }
}
