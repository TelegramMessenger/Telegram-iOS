import Foundation

protocol Identifiable {
    associatedtype T: Hashable, Equatable
    var stableId: T { get }
}

func mergeListsStable<T where T: Comparable, T: Equatable, T: Identifiable>(leftList: [T], rightList: [T]) -> ([Int], [(Int, T, Int?)]) {
    var removeIndices: [Int] = []
    var insertItems: [(Int, T, Int?)] = []
    
    var currentList = leftList
    
    var i = 0
    var j = 0
    while true {
        let left: T? = i < currentList.count ? currentList[i] : nil
        let right: T? = j < rightList.count ? rightList[j] : nil
        
        if let left = left, let right = right {
            if left == right {
                i += 1
                j += 1
            } else if left < right {
                removeIndices.append(i)
                i += 1
            } else {
                j += 1
            }
        } else if let _ = left {
            removeIndices.append(i)
            i += 1
        } else if let _ = right {
            j += 1
        } else {
            break
        }
    }
    
    for index in removeIndices.reversed() {
        currentList.remove(at: index)
    }
    
    var previousIndices: [T.T: Int] = [:]
    i = 0
    for left in leftList {
        previousIndices[left.stableId] = i
        i += 1
    }
    
    i = 0
    j = 0
    while true {
        let left: T? = i < currentList.count ? currentList[i] : nil
        let right: T? = j < rightList.count ? rightList[j] : nil
        
        if let left = left, let right = right {
            if left == right {
                i += 1
                j += 1
            } else if left > right {
                let previousIndex = previousIndices[right.stableId]
                insertItems.append((i, right, previousIndex))
                currentList.insert(right, at: i)
                i += 1
                j += 1
            } else {
                i += 1
            }
        } else if let _ = left {
            i += 1
        } else if let right = right {
            let previousIndex = previousIndices[right.stableId]
            insertItems.append((i, right, previousIndex))
            currentList.insert(right, at: i)
            i += 1
            j += 1
        } else {
            break
        }
    }
    
    assert(currentList == rightList, "currentList == rightList")
    
    return (removeIndices, insertItems)
}

func mergeListsStableWithUpdates<T where T: Comparable, T: Equatable, T: Identifiable>(leftList: [T], rightList: [T]) -> ([Int], [(Int, T, Int?)], [(Int, T)]) {
    var removeIndices: [Int] = []
    var insertItems: [(Int, T, Int?)] = []
    var updatedIndices: [(Int, T)] = []
    
    var currentList = leftList
    
    var i = 0
    var j = 0
    while true {
        let left: T? = i < currentList.count ? currentList[i] : nil
        let right: T? = j < rightList.count ? rightList[j] : nil
        
        if let left = left, let right = right {
            if left.stableId == right.stableId && left != right {
                updatedIndices.append((i, right))
                i += 1
                j += 1
            } else {
                if left == right {
                    i += 1
                    j += 1
                } else if left < right {
                    removeIndices.append(i)
                    i += 1
                } else {
                    j += 1
                }
            }
        } else if let _ = left {
            removeIndices.append(i)
            i += 1
        } else if let _ = right {
            j += 1
        } else {
            break
        }
    }
    
    for index in removeIndices.reversed() {
        currentList.remove(at: index)
        for i in 0 ..< updatedIndices.count {
            if updatedIndices[i].0 >= index {
                updatedIndices[i].0 -= 1
            }
        }
    }
    
    for (index, item) in updatedIndices {
        currentList[index] = item
    }
    
    var previousIndices: [T.T: Int] = [:]
    i = 0
    for left in leftList {
        previousIndices[left.stableId] = i
        i += 1
    }
    
    i = 0
    j = 0
    while true {
        let left: T? = i < currentList.count ? currentList[i] : nil
        let right: T? = j < rightList.count ? rightList[j] : nil
        
        if let left = left, let right = right {
            if left == right {
                i += 1
                j += 1
            } else if left > right {
                let previousIndex = previousIndices[right.stableId]
                insertItems.append((i, right, previousIndex))
                currentList.insert(right, at: i)
                
                for j in 0 ..< updatedIndices.count {
                    if updatedIndices[j].0 >= i {
                        updatedIndices[j].0 += 1
                    }
                }
                
                i += 1
                j += 1
            } else {
                i += 1
            }
        } else if let _ = left {
            i += 1
        } else if let right = right {
            let previousIndex = previousIndices[right.stableId]
            insertItems.append((i, right, previousIndex))
            currentList.insert(right, at: i)
            
            for j in 0 ..< updatedIndices.count {
                if updatedIndices[j].0 >= i {
                    updatedIndices[j].0 += 1
                }
            }
            
            i += 1
            j += 1
        } else {
            break
        }
    }
    
    assert(currentList == rightList, "currentList == rightList")
    
    return (removeIndices, insertItems, updatedIndices)
}
