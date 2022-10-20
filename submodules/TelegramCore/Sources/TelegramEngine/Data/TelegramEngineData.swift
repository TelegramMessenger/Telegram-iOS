import SwiftSignalKit
import Postbox

public protocol TelegramEngineDataItem {
    associatedtype Result
}

public protocol TelegramEngineMapKeyDataItem {
    associatedtype Key: Hashable

    var mapKey: Key { get }
}

protocol AnyPostboxViewDataItem {
    var keys: [PostboxViewKey] { get }

    func _extract(views: [PostboxViewKey: PostboxView]) -> Any
}

protocol PostboxViewDataItem: TelegramEngineDataItem, AnyPostboxViewDataItem {
    var key: PostboxViewKey { get }

    func extract(view: PostboxView) -> Result
}

extension PostboxViewDataItem {
    var keys: [PostboxViewKey] {
        return [self.key]
    }

    func _extract(views: [PostboxViewKey: PostboxView]) -> Any {
        return self.extract(view: views[self.key]!)
    }
}

public final class EngineDataMap<Item: TelegramEngineDataItem & TelegramEngineMapKeyDataItem>: TelegramEngineDataItem, AnyPostboxViewDataItem {
    public typealias Result = [Item.Key: Item.Result]

    private let items: [Item]

    public init(_ items: [Item]) {
        self.items = items
    }

    var keys: [PostboxViewKey] {
        var keys = Set<PostboxViewKey>()
        for item in self.items {
            for key in (item as! AnyPostboxViewDataItem).keys {
                keys.insert(key)
            }
        }
        return Array(keys)
    }

    func _extract(views: [PostboxViewKey: PostboxView]) -> Any {
        var result: [Item.Key: Item.Result] = [:]

        for item in self.items {
            let itemResult = (item as! AnyPostboxViewDataItem)._extract(views: views)
            result[item.mapKey] = (itemResult as! Item.Result)
        }

        return result
    }
}

public final class EngineDataList<Item: TelegramEngineDataItem & TelegramEngineMapKeyDataItem>: TelegramEngineDataItem, AnyPostboxViewDataItem {
    public typealias Result = [Item.Result]

    private let items: [Item]

    public init(_ items: [Item]) {
        self.items = items
    }

    var keys: [PostboxViewKey] {
        var keys = Set<PostboxViewKey>()
        for item in self.items {
            for key in (item as! AnyPostboxViewDataItem).keys {
                keys.insert(key)
            }
        }
        return Array(keys)
    }

    func _extract(views: [PostboxViewKey: PostboxView]) -> Any {
        var result: [Item.Result] = []

        for item in self.items {
            let itemResult = (item as! AnyPostboxViewDataItem)._extract(views: views)
            result.append(itemResult as! Item.Result)
        }

        return result
    }
}

public final class EngineDataOptional<Item: TelegramEngineDataItem>: TelegramEngineDataItem, AnyPostboxViewDataItem {
    public typealias Result = Item.Result?

    private let item: Item?

    public init(_ item: Item?) {
        self.item = item
    }

    var keys: [PostboxViewKey] {
        var keys = Set<PostboxViewKey>()
        if let item = self.item {
            for key in (item as! AnyPostboxViewDataItem).keys {
                keys.insert(key)
            }
        }
        return Array(keys)
    }

    func _extract(views: [PostboxViewKey: PostboxView]) -> Any {
        var result: [Item.Result] = []

        if let item = self.item {
            let itemResult = (item as! AnyPostboxViewDataItem)._extract(views: views)
            result.append(itemResult as! Item.Result)
        }

        return result
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
            var keys = Set<PostboxViewKey>()
            for item in items {
                for key in item.keys {
                    keys.insert(key)
                }
            }
            return self.account.postbox.combinedView(keys: Array(keys))
            |> map { views -> [Any] in
                var results: [Any] = []

                for item in items {
                    results.append(item._extract(views: views.views))
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
            return self._subscribe(items: [
                t0 as! AnyPostboxViewDataItem,
                t1 as! AnyPostboxViewDataItem
            ])
            |> map { results -> (T0.Result, T1.Result) in
                return (
                    results[0] as! T0.Result,
                    results[1] as! T1.Result
                )
            }
        }
        
        public func subscribe<
            T0: TelegramEngineDataItem,
            T1: TelegramEngineDataItem,
            T2: TelegramEngineDataItem
        >(
            _ t0: T0,
            _ t1: T1,
            _ t2: T2
        ) -> Signal<
            (
                T0.Result,
                T1.Result,
                T2.Result
            ),
        NoError> {
            return self._subscribe(items: [
                t0 as! AnyPostboxViewDataItem,
                t1 as! AnyPostboxViewDataItem,
                t2 as! AnyPostboxViewDataItem
            ])
            |> map { results -> (T0.Result, T1.Result, T2.Result) in
                return (
                    results[0] as! T0.Result,
                    results[1] as! T1.Result,
                    results[2] as! T2.Result
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
        
        public func get<
            T0: TelegramEngineDataItem,
            T1: TelegramEngineDataItem,
            T2: TelegramEngineDataItem
        >(
            _ t0: T0,
            _ t1: T1,
            _ t2: T2
        ) -> Signal<
            (
                T0.Result,
                T1.Result,
                T2.Result
            ),
        NoError> {
            return self.subscribe(t0, t1, t2) |> take(1)
        }
    }
}
