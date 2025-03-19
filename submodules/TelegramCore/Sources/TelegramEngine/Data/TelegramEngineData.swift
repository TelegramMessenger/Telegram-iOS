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
    func keys(data: TelegramEngine.EngineData) -> [PostboxViewKey]

    func _extract(data: TelegramEngine.EngineData, views: [PostboxViewKey: PostboxView]) -> Any
}

protocol PostboxViewDataItem: TelegramEngineDataItem, AnyPostboxViewDataItem {
    var key: PostboxViewKey { get }

    func extract(view: PostboxView) -> Result
}

extension PostboxViewDataItem {
    func keys(data: TelegramEngine.EngineData) -> [PostboxViewKey] {
        return [self.key]
    }

    func _extract(data: TelegramEngine.EngineData, views: [PostboxViewKey: PostboxView]) -> Any {
        return self.extract(view: views[self.key]!)
    }
}

public final class EngineDataMap<Item: TelegramEngineDataItem & TelegramEngineMapKeyDataItem>: TelegramEngineDataItem, AnyPostboxViewDataItem {
    public typealias Result = [Item.Key: Item.Result]

    private let items: [Item]

    public init(_ items: [Item]) {
        self.items = items
    }

    func keys(data: TelegramEngine.EngineData) -> [PostboxViewKey] {
        var keys = Set<PostboxViewKey>()
        for item in self.items {
            for key in (item as! AnyPostboxViewDataItem).keys(data: data) {
                keys.insert(key)
            }
        }
        return Array(keys)
    }

    func _extract(data: TelegramEngine.EngineData, views: [PostboxViewKey: PostboxView]) -> Any {
        var result: [Item.Key: Item.Result] = [:]

        for item in self.items {
            let itemResult = (item as! AnyPostboxViewDataItem)._extract(data: data, views: views)
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

    func keys(data: TelegramEngine.EngineData) -> [PostboxViewKey] {
        var keys = Set<PostboxViewKey>()
        for item in self.items {
            for key in (item as! AnyPostboxViewDataItem).keys(data: data) {
                keys.insert(key)
            }
        }
        return Array(keys)
    }

    func _extract(data: TelegramEngine.EngineData, views: [PostboxViewKey: PostboxView]) -> Any {
        var result: [Item.Result] = []

        for item in self.items {
            let itemResult = (item as! AnyPostboxViewDataItem)._extract(data: data, views: views)
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

    func keys(data: TelegramEngine.EngineData) -> [PostboxViewKey] {
        var keys = Set<PostboxViewKey>()
        if let item = self.item {
            for key in (item as! AnyPostboxViewDataItem).keys(data: data) {
                keys.insert(key)
            }
        }
        return Array(keys)
    }

    func _extract(data: TelegramEngine.EngineData, views: [PostboxViewKey: PostboxView]) -> Any {
        var result: Item.Result?

        if let item = self.item {
            let itemResult = (item as! AnyPostboxViewDataItem)._extract(data: data, views: views)
            result = (itemResult as! Item.Result)
        }

        return result as Any
    }
}

public extension TelegramEngine {
    final class EngineData {
        public struct Item {
        }

        let accountPeerId: PeerId
        private let postbox: Postbox

        public init(accountPeerId: PeerId, postbox: Postbox) {
            self.accountPeerId = accountPeerId
            self.postbox = postbox
        }

        private func _subscribe(items: [AnyPostboxViewDataItem]) -> Signal<[Any], NoError> {
            var keys = Set<PostboxViewKey>()
            for item in items {
                for key in item.keys(data: self) {
                    keys.insert(key)
                }
            }
            return self.postbox.combinedView(keys: Array(keys))
            |> map { views -> [Any] in
                var results: [Any] = []

                for item in items {
                    results.append(item._extract(data: self, views: views.views))
                }

                return results
            }
        }
        
        /*public func subscribe<each T: TelegramEngineDataItem>(_ ts: repeat each T) -> Signal<repeat each T, NoError> {
        }*/

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
        
        public func subscribe<
            T0: TelegramEngineDataItem,
            T1: TelegramEngineDataItem,
            T2: TelegramEngineDataItem,
            T3: TelegramEngineDataItem
        >(
            _ t0: T0,
            _ t1: T1,
            _ t2: T2,
            _ t3: T3
        ) -> Signal<
            (
                T0.Result,
                T1.Result,
                T2.Result,
                T3.Result
            ),
        NoError> {
            return self._subscribe(items: [
                t0 as! AnyPostboxViewDataItem,
                t1 as! AnyPostboxViewDataItem,
                t2 as! AnyPostboxViewDataItem,
                t3 as! AnyPostboxViewDataItem
            ])
            |> map { results -> (T0.Result, T1.Result, T2.Result, T3.Result) in
                return (
                    results[0] as! T0.Result,
                    results[1] as! T1.Result,
                    results[2] as! T2.Result,
                    results[3] as! T3.Result
                )
            }
        }
        
        public func subscribe<
            T0: TelegramEngineDataItem,
            T1: TelegramEngineDataItem,
            T2: TelegramEngineDataItem,
            T3: TelegramEngineDataItem,
            T4: TelegramEngineDataItem
        >(
            _ t0: T0,
            _ t1: T1,
            _ t2: T2,
            _ t3: T3,
            _ t4: T4
        ) -> Signal<
            (
                T0.Result,
                T1.Result,
                T2.Result,
                T3.Result,
                T4.Result
            ),
        NoError> {
            return self._subscribe(items: [
                t0 as! AnyPostboxViewDataItem,
                t1 as! AnyPostboxViewDataItem,
                t2 as! AnyPostboxViewDataItem,
                t3 as! AnyPostboxViewDataItem,
                t4 as! AnyPostboxViewDataItem
            ])
            |> map { results -> (T0.Result, T1.Result, T2.Result, T3.Result, T4.Result) in
                return (
                    results[0] as! T0.Result,
                    results[1] as! T1.Result,
                    results[2] as! T2.Result,
                    results[3] as! T3.Result,
                    results[4] as! T4.Result
                )
            }
        }
        
        public func subscribe<
            T0: TelegramEngineDataItem,
            T1: TelegramEngineDataItem,
            T2: TelegramEngineDataItem,
            T3: TelegramEngineDataItem,
            T4: TelegramEngineDataItem,
            T5: TelegramEngineDataItem
        >(
            _ t0: T0,
            _ t1: T1,
            _ t2: T2,
            _ t3: T3,
            _ t4: T4,
            _ t5: T5
        ) -> Signal<
            (
                T0.Result,
                T1.Result,
                T2.Result,
                T3.Result,
                T4.Result,
                T5.Result
            ),
        NoError> {
            return self._subscribe(items: [
                t0 as! AnyPostboxViewDataItem,
                t1 as! AnyPostboxViewDataItem,
                t2 as! AnyPostboxViewDataItem,
                t3 as! AnyPostboxViewDataItem,
                t4 as! AnyPostboxViewDataItem,
                t5 as! AnyPostboxViewDataItem
            ])
            |> map { results -> (T0.Result, T1.Result, T2.Result, T3.Result, T4.Result, T5.Result) in
                return (
                    results[0] as! T0.Result,
                    results[1] as! T1.Result,
                    results[2] as! T2.Result,
                    results[3] as! T3.Result,
                    results[4] as! T4.Result,
                    results[5] as! T5.Result
                )
            }
        }
        
        public func subscribe<
            T0: TelegramEngineDataItem,
            T1: TelegramEngineDataItem,
            T2: TelegramEngineDataItem,
            T3: TelegramEngineDataItem,
            T4: TelegramEngineDataItem,
            T5: TelegramEngineDataItem,
            T6: TelegramEngineDataItem
        >(
            _ t0: T0,
            _ t1: T1,
            _ t2: T2,
            _ t3: T3,
            _ t4: T4,
            _ t5: T5,
            _ t6: T6
        ) -> Signal<
            (
                T0.Result,
                T1.Result,
                T2.Result,
                T3.Result,
                T4.Result,
                T5.Result,
                T6.Result
            ),
        NoError> {
            return self._subscribe(items: [
                t0 as! AnyPostboxViewDataItem,
                t1 as! AnyPostboxViewDataItem,
                t2 as! AnyPostboxViewDataItem,
                t3 as! AnyPostboxViewDataItem,
                t4 as! AnyPostboxViewDataItem,
                t5 as! AnyPostboxViewDataItem,
                t6 as! AnyPostboxViewDataItem
            ])
            |> map { results -> (T0.Result, T1.Result, T2.Result, T3.Result, T4.Result, T5.Result, T6.Result) in
                return (
                    results[0] as! T0.Result,
                    results[1] as! T1.Result,
                    results[2] as! T2.Result,
                    results[3] as! T3.Result,
                    results[4] as! T4.Result,
                    results[5] as! T5.Result,
                    results[6] as! T6.Result
                )
            }
        }
        
        public func subscribe<
            T0: TelegramEngineDataItem,
            T1: TelegramEngineDataItem,
            T2: TelegramEngineDataItem,
            T3: TelegramEngineDataItem,
            T4: TelegramEngineDataItem,
            T5: TelegramEngineDataItem,
            T6: TelegramEngineDataItem,
            T7: TelegramEngineDataItem
        >(
            _ t0: T0,
            _ t1: T1,
            _ t2: T2,
            _ t3: T3,
            _ t4: T4,
            _ t5: T5,
            _ t6: T6,
            _ t7: T7
        ) -> Signal<
            (
                T0.Result,
                T1.Result,
                T2.Result,
                T3.Result,
                T4.Result,
                T5.Result,
                T6.Result,
                T7.Result

            ),
        NoError> {
            return self._subscribe(items: [
                t0 as! AnyPostboxViewDataItem,
                t1 as! AnyPostboxViewDataItem,
                t2 as! AnyPostboxViewDataItem,
                t3 as! AnyPostboxViewDataItem,
                t4 as! AnyPostboxViewDataItem,
                t5 as! AnyPostboxViewDataItem,
                t6 as! AnyPostboxViewDataItem,
                t7 as! AnyPostboxViewDataItem
            ])
            |> map { results -> (T0.Result, T1.Result, T2.Result, T3.Result, T4.Result, T5.Result, T6.Result, T7.Result) in
                return (
                    results[0] as! T0.Result,
                    results[1] as! T1.Result,
                    results[2] as! T2.Result,
                    results[3] as! T3.Result,
                    results[4] as! T4.Result,
                    results[5] as! T5.Result,
                    results[6] as! T6.Result,
                    results[7] as! T7.Result
                )
            }
        }
        
        public func subscribe<
            T0: TelegramEngineDataItem,
            T1: TelegramEngineDataItem,
            T2: TelegramEngineDataItem,
            T3: TelegramEngineDataItem,
            T4: TelegramEngineDataItem,
            T5: TelegramEngineDataItem,
            T6: TelegramEngineDataItem,
            T7: TelegramEngineDataItem,
            T8: TelegramEngineDataItem
        >(
            _ t0: T0,
            _ t1: T1,
            _ t2: T2,
            _ t3: T3,
            _ t4: T4,
            _ t5: T5,
            _ t6: T6,
            _ t7: T7,
            _ t8: T8
        ) -> Signal<
            (
                T0.Result,
                T1.Result,
                T2.Result,
                T3.Result,
                T4.Result,
                T5.Result,
                T6.Result,
                T7.Result,
                T8.Result
            ),
        NoError> {
            return self._subscribe(items: [
                t0 as! AnyPostboxViewDataItem,
                t1 as! AnyPostboxViewDataItem,
                t2 as! AnyPostboxViewDataItem,
                t3 as! AnyPostboxViewDataItem,
                t4 as! AnyPostboxViewDataItem,
                t5 as! AnyPostboxViewDataItem,
                t6 as! AnyPostboxViewDataItem,
                t7 as! AnyPostboxViewDataItem,
                t8 as! AnyPostboxViewDataItem
            ])
            |> map { results -> (T0.Result, T1.Result, T2.Result, T3.Result, T4.Result, T5.Result, T6.Result, T7.Result, T8.Result) in
                return (
                    results[0] as! T0.Result,
                    results[1] as! T1.Result,
                    results[2] as! T2.Result,
                    results[3] as! T3.Result,
                    results[4] as! T4.Result,
                    results[5] as! T5.Result,
                    results[6] as! T6.Result,
                    results[7] as! T7.Result,
                    results[8] as! T8.Result
                )
            }
        }
        public func subscribe<
            T0: TelegramEngineDataItem,
            T1: TelegramEngineDataItem,
            T2: TelegramEngineDataItem,
            T3: TelegramEngineDataItem,
            T4: TelegramEngineDataItem,
            T5: TelegramEngineDataItem,
            T6: TelegramEngineDataItem,
            T7: TelegramEngineDataItem,
            T8: TelegramEngineDataItem,
            T9: TelegramEngineDataItem

        >(
            _ t0: T0,
            _ t1: T1,
            _ t2: T2,
            _ t3: T3,
            _ t4: T4,
            _ t5: T5,
            _ t6: T6,
            _ t7: T7,
            _ t8: T8,
            _ t9: T9

        ) -> Signal<
            (
                T0.Result,
                T1.Result,
                T2.Result,
                T3.Result,
                T4.Result,
                T5.Result,
                T6.Result,
                T7.Result,
                T8.Result,
                T9.Result
            ),
        NoError> {
            return self._subscribe(items: [
                t0 as! AnyPostboxViewDataItem,
                t1 as! AnyPostboxViewDataItem,
                t2 as! AnyPostboxViewDataItem,
                t3 as! AnyPostboxViewDataItem,
                t4 as! AnyPostboxViewDataItem,
                t5 as! AnyPostboxViewDataItem,
                t6 as! AnyPostboxViewDataItem,
                t7 as! AnyPostboxViewDataItem,
                t8 as! AnyPostboxViewDataItem,
                t9 as! AnyPostboxViewDataItem
            ])
            |> map { results -> (T0.Result, T1.Result, T2.Result, T3.Result, T4.Result, T5.Result, T6.Result, T7.Result, T8.Result, T9.Result) in
                return (
                    results[0] as! T0.Result,
                    results[1] as! T1.Result,
                    results[2] as! T2.Result,
                    results[3] as! T3.Result,
                    results[4] as! T4.Result,
                    results[5] as! T5.Result,
                    results[6] as! T6.Result,
                    results[7] as! T7.Result,
                    results[8] as! T8.Result,
                    results[9] as! T9.Result
                )
            }
        }
        
        public func subscribe<
            T0: TelegramEngineDataItem,
            T1: TelegramEngineDataItem,
            T2: TelegramEngineDataItem,
            T3: TelegramEngineDataItem,
            T4: TelegramEngineDataItem,
            T5: TelegramEngineDataItem,
            T6: TelegramEngineDataItem,
            T7: TelegramEngineDataItem,
            T8: TelegramEngineDataItem,
            T9: TelegramEngineDataItem,
            T10: TelegramEngineDataItem
        >(
            _ t0: T0,
            _ t1: T1,
            _ t2: T2,
            _ t3: T3,
            _ t4: T4,
            _ t5: T5,
            _ t6: T6,
            _ t7: T7,
            _ t8: T8,
            _ t9: T9,
            _ t10: T10
        ) -> Signal<
            (
                T0.Result,
                T1.Result,
                T2.Result,
                T3.Result,
                T4.Result,
                T5.Result,
                T6.Result,
                T7.Result,
                T8.Result,
                T9.Result,
                T10.Result
            ),
        NoError> {
            return self._subscribe(items: [
                t0 as! AnyPostboxViewDataItem,
                t1 as! AnyPostboxViewDataItem,
                t2 as! AnyPostboxViewDataItem,
                t3 as! AnyPostboxViewDataItem,
                t4 as! AnyPostboxViewDataItem,
                t5 as! AnyPostboxViewDataItem,
                t6 as! AnyPostboxViewDataItem,
                t7 as! AnyPostboxViewDataItem,
                t8 as! AnyPostboxViewDataItem,
                t9 as! AnyPostboxViewDataItem,
                t10 as! AnyPostboxViewDataItem
            ])
            |> map { results -> (T0.Result, T1.Result, T2.Result, T3.Result, T4.Result, T5.Result, T6.Result, T7.Result, T8.Result, T9.Result, T10.Result) in
                return (
                    results[0] as! T0.Result,
                    results[1] as! T1.Result,
                    results[2] as! T2.Result,
                    results[3] as! T3.Result,
                    results[4] as! T4.Result,
                    results[5] as! T5.Result,
                    results[6] as! T6.Result,
                    results[7] as! T7.Result,
                    results[8] as! T8.Result,
                    results[9] as! T9.Result,
                    results[10] as! T10.Result
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
        
        public func get<
            T0: TelegramEngineDataItem,
            T1: TelegramEngineDataItem,
            T2: TelegramEngineDataItem,
            T3: TelegramEngineDataItem
        >(
            _ t0: T0,
            _ t1: T1,
            _ t2: T2,
            _ t3: T3
        ) -> Signal<
            (
                T0.Result,
                T1.Result,
                T2.Result,
                T3.Result
            ),
        NoError> {
            return self.subscribe(t0, t1, t2, t3) |> take(1)
        }
        
        public func get<
            T0: TelegramEngineDataItem,
            T1: TelegramEngineDataItem,
            T2: TelegramEngineDataItem,
            T3: TelegramEngineDataItem,
            T4: TelegramEngineDataItem
        >(
            _ t0: T0,
            _ t1: T1,
            _ t2: T2,
            _ t3: T3,
            _ t4: T4
        ) -> Signal<
            (
                T0.Result,
                T1.Result,
                T2.Result,
                T3.Result,
                T4.Result
            ),
        NoError> {
            return self.subscribe(t0, t1, t2, t3, t4) |> take(1)
        }
        
        public func get<
            T0: TelegramEngineDataItem,
            T1: TelegramEngineDataItem,
            T2: TelegramEngineDataItem,
            T3: TelegramEngineDataItem,
            T4: TelegramEngineDataItem,
            T5: TelegramEngineDataItem
        >(
            _ t0: T0,
            _ t1: T1,
            _ t2: T2,
            _ t3: T3,
            _ t4: T4,
            _ t5: T5
        ) -> Signal<
            (
                T0.Result,
                T1.Result,
                T2.Result,
                T3.Result,
                T4.Result,
                T5.Result
            ),
        NoError> {
            return self.subscribe(t0, t1, t2, t3, t4, t5) |> take(1)
        }
    }
}
