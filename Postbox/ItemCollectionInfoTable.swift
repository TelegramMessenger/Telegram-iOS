import Foundation

final class ItemCollectionInfoTable: Table {
    private let sharedKey = ValueBoxKey(length: 4 + 4 + 8)
    
    private var cachedInfos: [ItemCollectionId.Namespace: [(Int, ItemCollectionId, ItemCollectionInfo)]] = [:]
    
    private func key(collectionId: ItemCollectionId, index: Int32) -> ValueBoxKey {
        self.sharedKey.setInt32(0, value: collectionId.namespace)
        self.sharedKey.setInt32(4, value: index)
        self.sharedKey.setInt64(4 + 4, value: collectionId.id)
        return self.sharedKey
    }
    
    private func lowerBound(namespace: ItemCollectionId.Namespace) -> ValueBoxKey {
        let key = ValueBoxKey(length: 4)
        key.setInt32(0, value: namespace)
        return key
    }
    
    private func upperBound(namespace: ItemCollectionId.Namespace) -> ValueBoxKey {
        let key = ValueBoxKey(length: 4)
        key.setInt32(0, value: namespace)
        return key.successor
    }
    
    func getInfos(namespace: ItemCollectionId.Namespace) -> [(Int, ItemCollectionId, ItemCollectionInfo)] {
        if let cachedInfo = self.cachedInfos[namespace] {
            return cachedInfo
        } else {
            var infos: [(Int, ItemCollectionId, ItemCollectionInfo)] = []
            self.valueBox.range(self.tableId, start: self.lowerBound(namespace: namespace), end: self.upperBound(namespace: namespace), values: { key, value in
                if let info = Decoder(buffer: value).decodeRootObject() as? ItemCollectionInfo {
                    infos.append((Int(key.getInt32(4)), ItemCollectionId(namespace: namespace, id: key.getInt64(4 + 4)), info))
                }
                return true
            }, limit: 0)
            self.cachedInfos[namespace] = infos
            return infos
        }
    }
    
    func lowerCollectionId(namespaceList: [ItemCollectionId.Namespace], collectionId: ItemCollectionId, index: Int32) -> (ItemCollectionId, Int32)? {
        var currentNamespace = collectionId.namespace
        var currentKey = self.key(collectionId: collectionId, index: index)
        while true {
            var resultCollectionIdAndIndex: (ItemCollectionId, Int32)?
            self.valueBox.range(self.tableId, start: currentKey, end: self.lowerBound(namespace: currentNamespace), keys: { key in
                resultCollectionIdAndIndex = (ItemCollectionId(namespace: currentNamespace, id: key.getInt64(4 + 4)), key.getInt32(4))
                return true
            }, limit: 1)
            if let resultCollectionIdAndIndex = resultCollectionIdAndIndex {
                return resultCollectionIdAndIndex
            } else {
                let index = namespaceList.index(of: currentNamespace)!
                if index == 0 {
                    return nil
                } else {
                    currentNamespace = namespaceList[index - 1]
                    currentKey = self.upperBound(namespace: currentNamespace)
                }
            }
        }
    }
    
    func higherCollectionId(namespaceList: [ItemCollectionId.Namespace], collectionId: ItemCollectionId, index: Int32) -> (ItemCollectionId, Int32)? {
        var currentNamespace = collectionId.namespace
        var currentKey = self.key(collectionId: collectionId, index: index)
        while true {
            var resultCollectionIdAndIndex: (ItemCollectionId, Int32)?
            self.valueBox.range(self.tableId, start: currentKey, end: self.upperBound(namespace: currentNamespace), keys: { key in
                resultCollectionIdAndIndex = (ItemCollectionId(namespace: currentNamespace, id: key.getInt64(4 + 4)), key.getInt32(4))
                return true
            }, limit: 1)
            if let resultCollectionIdAndIndex = resultCollectionIdAndIndex {
                return resultCollectionIdAndIndex
            } else {
                let index = namespaceList.index(of: currentNamespace)!
                if index == namespaceList.count - 1 {
                    return nil
                } else {
                    currentNamespace = namespaceList[index + 1]
                    currentKey = self.lowerBound(namespace: currentNamespace)
                }
            }
        }
    }
    
    func replaceInfos(namespace: ItemCollectionId.Namespace, infos: [(ItemCollectionId, ItemCollectionInfo)]) {
        self.cachedInfos.removeAll()
        
        var currentCollectionKeys: [ValueBoxKey] = []
        self.valueBox.range(self.tableId, start: self.lowerBound(namespace: namespace), end: self.upperBound(namespace: namespace), keys: { key in
            currentCollectionKeys.append(key)
            return true
        }, limit: 0)
        
        for key in currentCollectionKeys {
            self.valueBox.remove(self.tableId, key: key)
        }
        
        var index: Int32 = 0
        let sharedEncoder = Encoder()
        for (id, info) in infos {
            sharedEncoder.reset()
            sharedEncoder.encodeRootObject(info)
            self.valueBox.set(self.tableId, key: self.key(collectionId: id, index: index), value: sharedEncoder.readBufferNoCopy())
            index += 1
        }
    }
    
    override func clearMemoryCache() {
        self.cachedInfos.removeAll()
    }
    
    override func beforeCommit() {
    }
}
