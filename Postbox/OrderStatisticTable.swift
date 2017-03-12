import Foundation

struct MessageOrderKey: Hashable, Comparable {
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
    
    var hashValue: Int {
        return self.timestamp.hashValue
    }
}

enum BTreeNodePosition {
    case left
    case right
}

final class BTreeNode {
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


final class BTreeAccess {
    let order: Int
    
    var memory: [Int32: BTreeNode] = [:]
    
    var rootNodeReference: Int32!
    var nextReference: Int32 = 0
    
    func getNode(_ reference: Int32) -> BTreeNode? {
        return self.memory[reference]
    }
    
    func replaceNode(_ reference: Int32, with node: BTreeNode) {
        self.memory[reference] = node
    }
    
    func allocateNodeReference() -> Int32 {
        let value = self.nextReference
        self.nextReference += 1
        return value
    }
    
    init(order: Int) {
        self.order = order
        let reference = self.allocateNodeReference()
        self.rootNodeReference = reference
        self.replaceNode(reference, with: BTreeNode(reference: reference))
    }
    
    func value(for key: MessageOrderKey) -> Int32? {
        if let rootNode = self.getNode(self.rootNodeReference) {
            if rootNode.numberOfKeys > 0 {
                return value(node: rootNode, key: key)
            } else {
                return nil
            }
        } else {
            assertionFailure()
            return nil
        }
    }
    
    public func insert(_ value: Int32, for key: MessageOrderKey) {
        if let rootNode = self.getNode(self.rootNodeReference) {
            let updatedNode = self.insert(node: rootNode, value: value, key: key)
            if updatedNode.numberOfKeys > self.order * 1 {
                self.splitRoot()
            }
        } else {
            assertionFailure()
        }
    }
    
    private func splitRoot() {
        var updatedRootNode = self.getNode(self.rootNodeReference)!
        let middleIndexOfOldRoot = updatedRootNode.numberOfKeys / 2
        
        var newRoot = BTreeNode(reference: self.allocateNodeReference(), keys: [updatedRootNode.keys[middleIndexOfOldRoot]], values: [updatedRootNode.values[middleIndexOfOldRoot]], childrenReferences: [updatedRootNode.reference])
        
        updatedRootNode = updatedRootNode.removingKeyValueAt(middleIndexOfOldRoot)
        //rootNode.keys.remove(at: middleIndexOfOldRoot)
        //rootNode.values.remove(at: middleIndexOfOldRoot)
        
        var newRightChild = BTreeNode(reference: self.allocateNodeReference(), keys: Array(updatedRootNode.keys[updatedRootNode.keys.indices.suffix(from: middleIndexOfOldRoot)]), values: Array(updatedRootNode.values[updatedRootNode.values.indices.suffix(from: middleIndexOfOldRoot)]))
        updatedRootNode = updatedRootNode.removingKeyValueInRange(updatedRootNode.keys.indices.suffix(from: middleIndexOfOldRoot))
        //rootNode.keys.removeSubrange(rootNode.keys.indices.suffix(from: middleIndexOfOldRoot))
        //rootNode.values.removeSubrange(rootNode.values.indices.suffix(from: middleIndexOfOldRoot))
        
        if updatedRootNode.childrenReferences != nil {
            newRightChild = newRightChild.replacingChildrenReferences(Array(
                updatedRootNode.childrenReferences![updatedRootNode.childrenReferences!.indices.suffix(from: (middleIndexOfOldRoot + 1))]
            ))
            updatedRootNode = updatedRootNode.removingChildrenReferencesInRange(updatedRootNode.childrenReferences!.indices.suffix(from: middleIndexOfOldRoot + 1))
            //rootNode.children!.removeSubrange(
            //    rootNode.children!.indices.suffix(from: (middleIndexOfOldRoot + 1))
            //)
        }
        
        newRoot = newRoot.insertingChildAt(newRoot.childrenReferences!.count, reference: newRightChild.reference)
        //newRoot.children!.append(newRightChild)
        
        self.replaceNode(newRoot.reference, with: newRoot)
        self.replaceNode(newRightChild.reference, with: newRightChild)
        self.replaceNode(updatedRootNode.reference, with: updatedRootNode)
        
        self.rootNodeReference = newRoot.reference
        //rootNode = newRoot
    }
    
    /*public func remove(_ key: MessageOrderKey) {
     guard rootNode.numberOfKeys > 0 else {
     return
     }
     
     rootNode.remove(key)
     
     if rootNode.numberOfKeys == 0 && !rootNode.isLeaf {
     rootNode = rootNode.children!.first!
     }
     }*/

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
            if let childrenReferences = node.childrenReferences {
                if let child = self.getNode(childrenReferences[index + 1]) {
                    return self.value(node: child, key: key)
                } else {
                    assertionFailure()
                    return nil
                }
            } else {
                return nil
            }

            //return children?[(index + 1)].value(for: key)
        }
    }

    func insert(node: BTreeNode, value: Int32, key: MessageOrderKey) -> BTreeNode {
        var index = node.keys.startIndex
        
        while index < node.keys.endIndex && node.keys[index] < key {
            index = index + 1
        }
        
        if index < node.keys.endIndex && node.keys[index] == key {
            let updatedNode = node.replacingValueAt(index, with: value)
            self.replaceNode(node.reference, with: updatedNode)
            //values[index] = value
            return updatedNode
        } else {
            if node.isLeaf {
                let updatedNode = node.insertingKeyValueAt(index, key: key, value: value)
                self.replaceNode(node.reference, with: updatedNode)
                //keys.insert(key, at: index)
                //values.insert(value, at: index)
                return updatedNode
            } else {
                if let child = self.getNode(node.childrenReferences![index]) {
                    let updatedChild = self.insert(node: child, value: value, key: key)
                    
                    if updatedChild.numberOfKeys > self.order * 2 {
                        return self.split(node: node, child: updatedChild, atIndex: index)
                    } else {
                        return node
                    }
                } else {
                    assertionFailure()
                    return node
                }
                //children![index].insert(value, for: key)
                //if children![index].numberOfKeys > self.order * 2 {
                //    split(child: children![index], atIndex: index)
                //}
            }
        }
    }

    private func split(node: BTreeNode, child: BTreeNode, atIndex index: Int) -> BTreeNode {
        let middleIndex = child.numberOfKeys / 2
        
        var updatedNode = node.insertingKeyValueAt(index, key: child.keys[middleIndex], value: child.values[middleIndex])
        //keys.insert(child.keys[middleIndex], at: index)
        //values.insert(child.values[middleIndex], at: index)
        
        var updatedChild = child.removingKeyValueAt(middleIndex)
        //child.keys.remove(at: middleIndex)
        //child.values.remove(at: middleIndex)
        
        var rightSibling = BTreeNode(reference: self.allocateNodeReference(), keys: Array(updatedChild.keys[updatedChild.keys.indices.suffix(from: middleIndex)]), values: Array(updatedChild.values[updatedChild.values.indices.suffix(from: middleIndex)]))
        
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
        
        return updatedNode
    }
    
    private func inorderPredecessor(node: BTreeNode) -> BTreeNode {
        if node.isLeaf {
            return node
        } else {
            return self.inorderPredecessor(node: self.getNode(node.childrenReferences!.last!)!)
        }
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

class MessageOrderStatisticTable: Table {
    static func tableSpec(_ id: Int32) -> ValueBoxTable {
        return ValueBoxTable(id: id, keyType: .binary)
    }
    
}
