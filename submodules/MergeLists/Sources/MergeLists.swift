import Foundation

@inlinable
public func mergeListsStableWithUpdates<T>(leftList: [T], rightList: [T], allUpdated: Bool = false) -> ([Int], [(Int, T, Int?)], [(Int, T, Int)]) where T: Comparable, T: Identifiable {
    var removeIndices: [Int] = []
    var insertItems: [(Int, T, Int?)] = []
    var updatedIndices: [(Int, T, Int)] = []
    
    #if DEBUG
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
            if left.stableId == right.stableId && (left != right || allUpdated) {
                updatedIndices.append((i, right, previousIndices[left.stableId]!))
                i += 1
                j += 1
            } else {
                if left == right && !allUpdated {
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
    
    #if DEBUG
    precondition(currentList == rightList, "currentList == rightList")
    #else
    assert(currentList == rightList, "currentList == rightList")
    #endif
    
    return (removeIndices, insertItems, updatedIndices)
}

//@inlinable
public func mergeListsStableWithUpdates<T>(leftList: [T], rightList: [T], isLess: (T, T) -> Bool, isEqual: (T, T) -> Bool, getId: (T) -> AnyHashable, allUpdated: Bool = false) -> ([Int], [(Int, T, Int?)], [(Int, T, Int)]) {
    var removeIndices: [Int] = []
    var insertItems: [(Int, T, Int?)] = []
    var updatedIndices: [(Int, T, Int)] = []
    
    #if DEBUG
    var existingStableIds: [AnyHashable: T] = [:]
    for item in leftList {
        if let _ = existingStableIds[getId(item)] {
            assertionFailure()
        } else {
            existingStableIds[getId(item)] = item
        }
    }
    existingStableIds.removeAll()
    for item in rightList {
        if let other = existingStableIds[getId(item)] {
            print("\(other) has the same stableId as \(item): \(getId(item))")
            assertionFailure()
        } else {
            existingStableIds[getId(item)] = item
        }
    }
    #endif
    
    var leftStableIds: [AnyHashable] = []
    var rightStableIds: [AnyHashable] = []
    for item in leftList {
        leftStableIds.append(getId(item))
    }
    for item in rightList {
        rightStableIds.append(getId(item))
    }
    if false && Set(leftStableIds) == Set(rightStableIds) && leftStableIds != rightStableIds && !allUpdated {
        var updatedItems: [(T, AnyHashable)] = []
        for i in 0 ..< leftList.count {
            if getId(leftList[i]) != getId(rightList[i]) {
                removeIndices.append(i)
            } else {
                updatedItems.append((leftList[i], getId(leftList[i])))
            }
        }
        var i = 0
        while i < rightList.count {
            if updatedItems.count <= i || updatedItems[i].1 != getId(rightList[i]) {
                updatedItems.insert((rightList[i], getId(rightList[i])), at: i)
                var previousIndex: Int?
                for k in 0 ..< leftList.count {
                    if getId(leftList[k]) == getId(rightList[i]) {
                        previousIndex = k
                        break
                    }
                }
                assert(previousIndex != nil)
                insertItems.append((i, rightList[i], previousIndex))
            } else {
                if !isEqual(updatedItems[i].0, rightList[i]) {
                    updatedIndices.append((i, rightList[i], i))
                }
            }
            i += 1
        }
        return (removeIndices, insertItems, updatedIndices)
    }
    
    var currentList = leftList
    
    var i = 0
    var previousIndices: [AnyHashable: Int] = [:]
    for left in leftList {
        previousIndices[getId(left)] = i
        i += 1
    }
    
    i = 0
    var j = 0
    while true {
        let left: T? = i < currentList.count ? currentList[i] : nil
        let right: T? = j < rightList.count ? rightList[j] : nil
        
        if let left = left, let right = right {
            if getId(left) == getId(right) && (!isEqual(left, right) || allUpdated) {
                updatedIndices.append((i, right, previousIndices[getId(left)]!))
                i += 1
                j += 1
            } else {
                if isEqual(left, right) && !allUpdated {
                    i += 1
                    j += 1
                } else if isLess(left, right) {
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
            if isEqual(left, right) {
                //print("\(left.stableId)==\(right.stableId)")
                //print("i++, j++")
                i += 1
                j += 1
            } else if !isLess(left, right) {
                //print("\(left.stableId)>\(right.stableId)")
                //print("insert \(right.stableId) at \(i)")
                //print("i++, j++")
                let previousIndex = previousIndices[getId(right)]
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
            let previousIndex = previousIndices[getId(right)]
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
    
    #if DEBUG
    if currentList.count != rightList.count {
        precondition(false)
    } else {
        for i in 0 ..< currentList.count {
            if !isEqual(currentList[i], rightList[i]) {
                precondition(false)
            }
        }
    }
    #endif
    
    return (removeIndices, insertItems, updatedIndices)
}

@inlinable
public func mergeListsStableWithUpdatesReversed<T>(leftList: [T], rightList: [T], allUpdated: Bool = false) -> ([Int], [(Int, T, Int?)], [(Int, T, Int)]) where T: Comparable, T: Identifiable {
    var removeIndices: [Int] = []
    var insertItems: [(Int, T, Int?)] = []
    var updatedIndices: [(Int, T, Int)] = []
    
    #if targetEnvironment(simulator)
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
            if left.stableId == right.stableId && (left != right || allUpdated) {
                updatedIndices.append((i, right, previousIndices[left.stableId]!))
                i += 1
                j += 1
            } else {
                if left == right && !allUpdated {
                    i += 1
                    j += 1
                } else if left > right {
                    removeIndices.append(i)
                    i += 1
                } else if !(left < right) {
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
    
    i = 0
    j = 0
    var k = 0
    while true {
        let left: T?
        
        if k < updatedIndices.count && updatedIndices[k].0 < i {
            k += 1
        }
        
        if k < updatedIndices.count {
            if updatedIndices[k].0 == i {
                left = updatedIndices[k].1
            } else {
                left = i < currentList.count ? currentList[i] : nil
            }
        } else {
            left = i < currentList.count ? currentList[i] : nil
        }
        
        let right: T? = j < rightList.count ? rightList[j] : nil
        
        if let left = left, let right = right {
            if left == right {
                i += 1
                j += 1
            } else if left < right {
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
                i += 1
            }
        } else if let _ = left {
            i += 1
        } else if let right = right {
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
    
    assert(currentList == rightList, "currentList == rightList")
    
    return (removeIndices, insertItems, updatedIndices)
}

