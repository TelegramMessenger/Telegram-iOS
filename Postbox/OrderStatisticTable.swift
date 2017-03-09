import Foundation

private struct MessageOrderKey: Comparable {
    let timestamp: Int32
    let namespace: MessageId.Namespace
    let id: MessageId.Id
    
    static func ==(lhs: MessageOrderKey, rhs: MessageOrderKey) -> Bool {
        return lhs.timestamp == rhs.timestamp && lhs.namespace == rhs.namespace && lhs.id == rhs.id
    }
    
    static func <(lhs: MessageOrderKey, rhs: MessageOrderKey) -> Bool {
        if lhs.timestamp != rhs.timestamp {
            return lhs.timestamp < rhs.timestamp
        }
        
        if lhs.namespace != rhs.namespace {
            return lhs.namespace < rhs.namespace
        }
        
        return lhs.id < rhs.id
    }
}

private enum BTreeNodePosition {
    case left
    case right
}

private final class BTreeNode {
    let reference: Int32
    let keys: [MessageOrderKey]
    let values: [Int32]
    let childrenReferences: [Int32]?
    
    var isLeaf: Bool {
        return self.childrenReferences == nil
    }
    
    var numberOfKeys: Int {
        return self.keys.count
    }
    
    init(reference: Int32) {
        self.reference = reference
        self.keys = []
        self.values = []
        self.childrenReferences = nil
    }
    
    init(reference: Int32, keys: [MessageOrderKey], values: [Int32], childrenReferences: [Int32]? = nil) {
        self.reference = reference
        self.keys = keys
        self.values = values
        self.childrenReferences = childrenReferences
    }
    
    func replacingValueAt(_ index: Int, with value: Int32) -> BTreeNode {
        var values = self.values
        values[index] = value
        return BTreeNode(reference: self.reference, keys: self.keys, values: values, childrenReferences: self.childrenReferences)
    }
    
    func insertingKeyValueAt(_ index: Int, key: MessageOrderKey, value: Int32) -> BTreeNode {
        var keys = self.keys
        var values = self.values
        keys.insert(key, at: index)
        values.insert(value, at: index)
        return BTreeNode(reference: self.reference, keys: keys, values: values, childrenReferences: self.childrenReferences)
    }
    
    func removingKeyValueAt(_ index: Int) -> BTreeNode {
        var keys = self.keys
        var values = self.values
        keys.remove(at: index)
        values.remove(at: index)
        return BTreeNode(reference: self.reference, keys: keys, values: values, childrenReferences: self.childrenReferences)
    }
    
    func removingKeyValueInRange(_ range: CountableRange<Int>) -> BTreeNode {
        var keys = self.keys
        var values = self.values
        keys.removeSubrange(range)
        values.removeSubrange(range)
        return BTreeNode(reference: self.reference, keys: keys, values: values, childrenReferences: self.childrenReferences)
    }
    
    func insertingChildAt(_ index: Int, reference: Int32) -> BTreeNode {
        var childrenReferences = self.childrenReferences!
        childrenReferences.insert(reference, at: index)
        return BTreeNode(reference: self.reference, keys: self.keys, values: self.values, childrenReferences: childrenReferences)
    }
    
    func replacingChildrenReferences(_ childrenReferences: [Int32]?) -> BTreeNode {
        return BTreeNode(reference: self.reference, keys: self.keys, values: self.values, childrenReferences: childrenReferences)
    }
    
    func removingChildrenReferencesInRange(_ range: CountableRange<Int>) -> BTreeNode {
        var childrenReferences = self.childrenReferences
        childrenReferences?.removeSubrange(range)
        return BTreeNode(reference: self.reference, keys: self.keys, values: self.values, childrenReferences: childrenReferences)
    }
}


private final class BTreeAccess {
    let order: Int = 2
    
    func getNode(_ reference: Int32) -> BTreeNode? {
        return nil
    }
    
    func replaceNode(_ reference: Int32, with: BTreeNode) {
    }
    
    func allocateNodeReference() -> Int32 {
        return 0
    }

    func value(node: BTreeNode, key: MessageOrderKey) -> Int32? {
        var index = node.keys.startIndex
        
        while (index + 1) < node.keys.endIndex && node.keys[index] < key {
            index = index + 1
        }
        
        if key == node.keys[index] {
            return node.values[index]
        } else if key < node.keys[index] {
            if let childrenReferences = node.childrenReferences {
                if let child = self.getNode(childrenReferences[index]) {
                    return self.value(node: child, key: key)
                } else {
                    assertionFailure()
                    return nil
                }
            } else {
                return nil
            }
            //return children?[index].value(for: key)
        } else {
            if let child = self.getNode(index + 1) {
                return self.value(node: child, key: key)
            } else {
                assertionFailure()
                return nil
            }
            //return children?[(index + 1)].value(for: key)
        }
    }

    func insert(node: BTreeNode, value: Int32, key: MessageOrderKey) {
        var index = node.keys.startIndex
        
        while index < node.keys.endIndex && node.keys[index] < key {
            index = index + 1
        }
        
        if index < node.keys.endIndex && node.keys[index] == key {
            self.replaceNode(node.reference, with: node.replacingValueAt(index, with: value))
            //values[index] = value
            return
        }
        
        if node.isLeaf {
            self.replaceNode(node.reference, with: node.insertingKeyValueAt(index, key: key, value: value))
            //keys.insert(key, at: index)
            //values.insert(value, at: index)
        } else {
            if let child = self.getNode(node.childrenReferences![index]) {
                self.insert(node: child, value: value, key: key)
                if child.numberOfKeys > self.order * 2 {
                    self.split(node: node, child: child, atIndex: index)
                }
            } else {
                assertionFailure()
            }
            //children![index].insert(value, for: key)
            //if children![index].numberOfKeys > self.order * 2 {
            //    split(child: children![index], atIndex: index)
            //}
        }
    }

    private func split(node: BTreeNode, child: BTreeNode, atIndex index: Int) {
        let middleIndex = child.numberOfKeys / 2
        
        var updatedNode = node.insertingKeyValueAt(index, key: child.keys[middleIndex], value: child.values[middleIndex])
        //keys.insert(child.keys[middleIndex], at: index)
        //values.insert(child.values[middleIndex], at: index)
        
        var updatedChild = child.removingKeyValueAt(middleIndex)
        //child.keys.remove(at: middleIndex)
        //child.values.remove(at: middleIndex)
        
        var rightSibling = BTreeNode(reference: self.allocateNodeReference(), keys: Array(child.keys[updatedChild.keys.indices.suffix(from: middleIndex)]), values: Array(child.values[updatedChild.values.indices.suffix(from: middleIndex)]))
        
        updatedChild = updatedChild.removingKeyValueInRange(updatedChild.keys.indices.suffix(from: middleIndex))
        //child.keys.removeSubrange(child.keys.indices.suffix(from: middleIndex))
        //child.values.removeSubrange(child.values.indices.suffix(from: middleIndex))
        
        updatedNode = updatedNode.insertingChildAt(index + 1, reference: rightSibling.reference)
        //children!.insert(rightSibling, at: (index + 1))
        
        self.replaceNode(node.reference, with: updatedNode)
        
        if updatedChild.childrenReferences != nil {
            rightSibling = rightSibling.replacingChildrenReferences(Array(updatedChild.childrenReferences![updatedChild.childrenReferences!.indices.suffix(from: (middleIndex + 1))]))
            updatedChild = updatedChild.removingChildrenReferencesInRange(updatedChild.childrenReferences!.indices.suffix(from: (middleIndex + 1)))
        }
        
        self.replaceNode(child.reference, with: updatedChild)
        self.replaceNode(rightSibling.reference, with: rightSibling)
    }

    /*private var inorderPredecessor: BTreeNode {
        if isLeaf {
            return self
        } else {
            return children!.last!.inorderPredecessor
        }
    }

    func remove(_ key: MessageOrderKey) {
        var index = keys.startIndex
        
        while (index + 1) < keys.endIndex && keys[index] < key {
            index = (index + 1)
        }
        
        if keys[index] == key {
            if isLeaf {
                keys.remove(at: index)
                values.remove(at: index)
            } else {
                let predecessor = children![index].inorderPredecessor
                keys[index] = predecessor.keys.last!
                values[index] = predecessor.values.last!
                children![index].remove(keys[index])
                if children![index].numberOfKeys < self.order {
                    fix(childWithTooFewKeys: children![index], atIndex: index)
                }
            }
        } else if key < keys[index] {
            if let leftChild = children?[index] {
                leftChild.remove(key)
                if leftChild.numberOfKeys < self.order {
                    fix(childWithTooFewKeys: leftChild, atIndex: index)
                }
            } else {
                // key is not present
            }
        } else {
            if let rightChild = children?[(index + 1)] {
                rightChild.remove(key)
                if rightChild.numberOfKeys < self.order {
                    fix(childWithTooFewKeys: rightChild, atIndex: (index + 1))
                }
            } else {
                // key is not present
            }
        }
    }
    
    private func fix(childWithTooFewKeys child: BTreeNode, atIndex index: Int) {
        if (index - 1) >= 0 && children![(index - 1)].numberOfKeys > self.order {
            move(keyAtIndex: (index - 1), to: child, from: children![(index - 1)], at: .left)
        } else if (index + 1) < children!.count && children![(index + 1)].numberOfKeys > self.order {
            move(keyAtIndex: index, to: child, from: children![(index + 1)], at: .right)
        } else if (index - 1) >= 0 {
            merge(child: child, atIndex: index, to: .left)
        } else {
            merge(child: child, atIndex: index, to: .right)
        }
    }
    
    private func move(keyAtIndex index: Int, to targetNode: BTreeNode,
                      from node: BTreeNode, at position: BTreeNodePosition) {
        switch position {
            case .left:
                targetNode.keys.insert(keys[index], at: targetNode.keys.startIndex)
                targetNode.values.insert(values[index], at: targetNode.values.startIndex)
                keys[index] = node.keys.last!
                values[index] = node.values.last!
                node.keys.removeLast()
                node.values.removeLast()
                if !targetNode.isLeaf {
                    targetNode.children!.insert(node.children!.last!,
                                                at: targetNode.children!.startIndex)
                    node.children!.removeLast()
                }
                
            case .right:
                targetNode.keys.insert(keys[index], at: targetNode.keys.endIndex)
                targetNode.values.insert(values[index], at: targetNode.values.endIndex)
                keys[index] = node.keys.first!
                values[index] = node.values.first!
                node.keys.removeFirst()
                node.values.removeFirst()
                if !targetNode.isLeaf {
                    targetNode.children!.insert(node.children!.first!,
                                                at: targetNode.children!.endIndex)
                    node.children!.removeFirst()
                }
        }
    }
    
    private func merge(child: BTreeNode, atIndex index: Int, to position: BTreeNodePosition) {
        switch position {
        case .left:
            // We can merge to the left sibling
            
            children![(index - 1)].keys = children![(index - 1)].keys +
                [keys[(index - 1)]] + child.keys
            
            children![(index - 1)].values = children![(index - 1)].values +
                [values[(index - 1)]] + child.values
            
            keys.remove(at: (index - 1))
            values.remove(at: (index - 1))
            
            if !child.isLeaf {
                children![(index - 1)].children =
                    children![(index - 1)].children! + child.children!
            }
            
        case .right:
            // We should merge to the right sibling
            
            children![(index + 1)].keys = child.keys + [keys[index]] +
                children![(index + 1)].keys
            
            children![(index + 1)].values = child.values + [values[index]] +
                children![(index + 1)].values
            
            keys.remove(at: index)
            values.remove(at: index)
            
            if !child.isLeaf {
                children![(index + 1)].children =
                    child.children! + children![(index + 1)].children!
            }
        }
        children!.remove(at: index)
    }*/
}

/*private class BTree {
    public let order: Int

    var rootNode: BTreeNode!
    
    public init?(order: Int) {
        guard order > 0 else {
            assertionFailure()
            return nil
        }
        self.order = order
        rootNode = BTreeNode(order: self.order)
    }

    public func value(for key: MessageOrderKey) -> Int32? {
        guard rootNode.numberOfKeys > 0 else {
            return nil
        }
        
        return rootNode.value(for: key)
    }

    public func insert(_ value: Int32, for key: MessageOrderKey) {
        rootNode.insert(value, for: key)
        
        if rootNode.numberOfKeys > order * 2 {
            splitRoot()
        }
    }

    private func splitRoot() {
        let middleIndexOfOldRoot = rootNode.numberOfKeys / 2
        
        let newRoot = BTreeNode(
            order: self.order,
            keys: [rootNode.keys[middleIndexOfOldRoot]],
            values: [rootNode.values[middleIndexOfOldRoot]],
            children: [rootNode]
        )
        rootNode.keys.remove(at: middleIndexOfOldRoot)
        rootNode.values.remove(at: middleIndexOfOldRoot)
        
        let newRightChild = BTreeNode(
            order: self.order,
            keys: Array(rootNode.keys[rootNode.keys.indices.suffix(from: middleIndexOfOldRoot)]),
            values: Array(rootNode.values[rootNode.values.indices.suffix(from: middleIndexOfOldRoot)])
        )
        rootNode.keys.removeSubrange(rootNode.keys.indices.suffix(from: middleIndexOfOldRoot))
        rootNode.values.removeSubrange(rootNode.values.indices.suffix(from: middleIndexOfOldRoot))
        
        if rootNode.children != nil {
            newRightChild.children = Array(
                rootNode.children![rootNode.children!.indices.suffix(from: (middleIndexOfOldRoot + 1))]
            )
            rootNode.children!.removeSubrange(
                rootNode.children!.indices.suffix(from: (middleIndexOfOldRoot + 1))
            )
        }
        
        newRoot.children!.append(newRightChild)
        rootNode = newRoot
    }

    public func remove(_ key: MessageOrderKey) {
        guard rootNode.numberOfKeys > 0 else {
            return
        }
        
        rootNode.remove(key)
        
        if rootNode.numberOfKeys == 0 && !rootNode.isLeaf {
            rootNode = rootNode.children!.first!
        }
    }
}*/

class MessageOrderStatisticTable: Table {
    static func tableSpec(_ id: Int32) -> ValueBoxTable {
        return ValueBoxTable(id: id, keyType: .binary)
    }
    
}
