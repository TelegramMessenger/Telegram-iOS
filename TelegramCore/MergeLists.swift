import Foundation

public protocol Identifiable {
    associatedtype T: Hashable, Equatable
    var stableId: T { get }
}

public func mergeListsStable<T>(leftList: [T], rightList: [T]) -> ([Int], [(Int, T, Int?)]) where T: Comparable, T: Equatable, T: Identifiable {
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

public func mergeListsStableWithUpdates<T>(leftList: [T], rightList: [T]) -> ([Int], [(Int, T, Int?)], [(Int, T, Int)]) where T: Comparable, T: Equatable, T: Identifiable {
    var removeIndices: [Int] = []
    var insertItems: [(Int, T, Int?)] = []
    var updatedIndices: [(Int, T, Int)] = []
    
    #if (arch(i386) || arch(x86_64)) && os(iOS)
    var existingStableIds: [T.T: T] = [:]
    for item in leftList {
        if let _ = existingStableIds[item.stableId] {
            assertionFailure()
        } else {
            existingStableIds[item.stableId] = item
        }
    }
    existingStableIds.removeAll()
    for item in rightList {
        if let other = existingStableIds[item.stableId] {
            print("\(other) has the same stableId as \(item): \(item.stableId)")
            assertionFailure()
        } else {
            existingStableIds[item.stableId] = item
        }
    }
    #endif
    
    var currentList = leftList
    
    /*print("-----------")
    let newline = "\n"
    print("left:\n")
    var m = 0
    for left in leftList {
        print("\(m): \(left.stableId)")
        m += 1
    }
    m = 0
    print("\nright:\n")
    for right in rightList {
        print("\(m): \(right.stableId)")
        m += 1
    }*/
    
    var i = 0
    var previousIndices: [T.T: Int] = [:]
    for left in leftList {
        previousIndices[left.stableId] = i
        i += 1
    }
    
    i = 0
    var j = 0
    while true {
        let left: T? = i < currentList.count ? currentList[i] : nil
        let right: T? = j < rightList.count ? rightList[j] : nil
        
        if let left = left, let right = right {
            if left.stableId == right.stableId && left != right {
                updatedIndices.append((i, right, previousIndices[left.stableId]!))
                i += 1
                j += 1
            } else {
                if left == right {
                    i += 1
                    j += 1
                } else if left < right {
                    removeIndices.append(i)
                    i += 1
                } else if !(left > right) {
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
    
    //print("remove:\n\(removeIndices)")
    
    for index in removeIndices.reversed() {
        currentList.remove(at: index)
        for i in 0 ..< updatedIndices.count {
            if updatedIndices[i].0 >= index {
                updatedIndices[i].0 -= 1
            }
        }
    }
    
    /*print("\n current after removes:\n")
    m = 0
    for right in currentList {
        print("\(m): \(right.stableId)")
        m += 1
    }
    
    print("update:\n\(updatedIndices.map({ "\($0.0), \($0.1.stableId) (was \($0.2)))" }))")*/
    
    i = 0
    j = 0
    var k = 0
    while true {
        let left: T?
        
        //print("i=\(i), j=\(j), k=\(k)")
        
        if k < updatedIndices.count && updatedIndices[k].0 < i {
            //print("updated[k=\(k)]=\(updatedIndices[k].0)<i=\(i), k++")
            k += 1
        }
        
        if k < updatedIndices.count {
            if updatedIndices[k].0 == i {
                left = updatedIndices[k].1
                //print("override left = \(updatedIndices[k].1.stableId)")
            } else {
                left = i < currentList.count ? currentList[i] : nil
            }
        } else {
            left = i < currentList.count ? currentList[i] : nil
        }
        
        let right: T? = j < rightList.count ? rightList[j] : nil
        
        if let left = left, let right = right {
            if left == right {
                //print("\(left.stableId)==\(right.stableId)")
                //print("i++, j++")
                i += 1
                j += 1
            } else if left > right {
                //print("\(left.stableId)>\(right.stableId)")
                //print("insert \(right.stableId) at \(i)")
                //print("i++, j++")
                let previousIndex = previousIndices[right.stableId]
                insertItems.append((i, right, previousIndex))
                currentList.insert(right, at: i)
                if k < updatedIndices.count {
                    for l in k ..< updatedIndices.count {
                        updatedIndices[l] = (updatedIndices[l].0 + 1, updatedIndices[l].1, updatedIndices[l].2)
                    }
                }
                
                i += 1
                j += 1
            } else {
                //print("\(left.stableId)<\(right.stableId)")
                //print("i++")
                i += 1
            }
        } else if let _ = left {
            //print("\(left!.stableId)>nil")
            //print("i++")
            i += 1
        } else if let right = right {
            //print("nil<\(right.stableId)")
            //print("insert \(right.stableId) at \(i)")
            //print("i++")
            //print("j++")
            let previousIndex = previousIndices[right.stableId]
            insertItems.append((i, right, previousIndex))
            currentList.insert(right, at: i)
            
            if k < updatedIndices.count {
                for l in k ..< updatedIndices.count {
                    updatedIndices[l] = (updatedIndices[l].0 + 1, updatedIndices[l].1, updatedIndices[l].2)
                }
            }
            
            i += 1
            j += 1
        } else {
            break
        }
    }
    
    for (index, item, _) in updatedIndices {
        currentList[index] = item
    }
    
    //print("update after inserts:\n\(updatedIndices.map({ "\($0.0), \($0.1.stableId) (was \($0.2)))" }))")
    
    /*if currentList != rightList {
        for l in 0 ..< currentList.count {
            if currentList[l] != rightList[l] {
                print("here \(currentList[l]) != \(rightList[l])")
            }
        }
    }*/
    assert(currentList == rightList, "currentList == rightList")
    
    return (removeIndices, insertItems, updatedIndices)
}
