import Foundation

func binarySearch<T: Comparable>(_ inputArr: [T], searchItem: T) -> Int? {
    var lowerIndex = 0;
    var upperIndex = inputArr.count - 1
    
    if lowerIndex > upperIndex {
        return nil
    }
    
    while (true) {
        let currentIndex = (lowerIndex + upperIndex) / 2
        if (inputArr[currentIndex] == searchItem) {
            return currentIndex
        } else if (lowerIndex > upperIndex) {
            return nil
        } else {
            if (inputArr[currentIndex] > searchItem) {
                upperIndex = currentIndex - 1
            } else {
                lowerIndex = currentIndex + 1
            }
        }
    }
}

func binaryInsertionIndex<T: Comparable>(_ inputArr: [T], searchItem: T) -> Int {
    var lo = 0
    var hi = inputArr.count - 1
    while lo <= hi {
        let mid = (lo + hi)/2
        if inputArr[mid] < searchItem {
            lo = mid + 1
        } else if searchItem < inputArr[mid] {
            hi = mid - 1
        } else {
            return mid
        }
    }
    return lo
}

func binaryInsertionIndexReverse<T: Comparable>(_ inputArr: [T], searchItem: T) -> Int {
    var lo = 0
    var hi = inputArr.count - 1
    while lo <= hi {
        let mid = (lo + hi)/2
        if inputArr[mid] > searchItem {
            lo = mid + 1
        } else if searchItem > inputArr[mid] {
            hi = mid - 1
        } else {
            return mid
        }
    }
    return lo
}
