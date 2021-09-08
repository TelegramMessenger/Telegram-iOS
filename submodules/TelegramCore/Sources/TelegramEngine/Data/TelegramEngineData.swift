import SwiftSignalKit
import Postbox

public protocol TelegramEngineDataItem {
    associatedtype Result
}

protocol AnyPostboxViewDataItem {
    var key: PostboxViewKey { get }

    func _extract(view: PostboxView) -> Any
}

protocol PostboxViewDataItem: TelegramEngineDataItem, AnyPostboxViewDataItem {
    func extract(view: PostboxView) -> Result
}

extension PostboxViewDataItem {
    func _extract(view: PostboxView) -> Any {
        return self.extract(view: view)
    }
}

public extension TelegramEngine {
    final class EngineData {
        public struct Item {
        }

        private let account: Account

        init(account: Account) {
            self.account = account
        }

        private func _subscribe(items: [AnyPostboxViewDataItem]) -> Signal<[Any], NoError> {
            return self.account.postbox.combinedView(keys: Array(Set(items.map(\.key))))
            |> map { views -> [Any] in
                var results: [Any] = []

                for item in items {
                    guard let view = views.views[item.key] else {
                        preconditionFailure()
                    }
                    results.append(item._extract(view: view))
                }

                return results
            }
        }

        public func subscribe<T0: TelegramEngineDataItem>(_ t0: T0) -> Signal<T0.Result, NoError> {
            return self._subscribe(items: [t0 as! AnyPostboxViewDataItem])
            |> map { results -> T0.Result in
                return results[0] as! T0.Result
            }
        }
        public func get<T0: TelegramEngineDataItem>(_ t0: T0) -> Signal<T0.Result, NoError> {
            return self.subscribe(t0)
            |> take(1)
        }

        public func subscribe<
            T0: TelegramEngineDataItem,
            T1: TelegramEngineDataItem
        >(
            _ t0: T0,
            _ t1: T1
        ) -> Signal<
            (
                T0.Result,
                T1.Result
            ),
        NoError> {
            return self._subscribe(items: [t0 as! AnyPostboxViewDataItem])
            |> map { results -> (T0.Result, T1.Result) in
                return (
                    results[0] as! T0.Result,
                    results[1] as! T1.Result
                )
            }
        }
        public func get<
            T0: TelegramEngineDataItem,
            T1: TelegramEngineDataItem
        >(
            _ t0: T0,
            _ t1: T1
        ) -> Signal<
            (
                T0.Result,
                T1.Result
            ),
        NoError> {
            return self.subscribe(t0, t1) |> take(1)
        }
    }
}
