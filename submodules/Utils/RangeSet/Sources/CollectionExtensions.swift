//===----------------------------------------------------------*- swift -*-===//
//
// This source file is part of the Swift open source project
//
// Copyright (c) 2020 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// See https://swift.org/LICENSE.txt for license information
//
//===----------------------------------------------------------------------===//

// MARK: Subscripts

extension Collection {
  /// Accesses a view of this collection with the elements at the given
  /// indices.
  ///
  /// - Parameter subranges: The indices of the elements to retrieve from this
  ///   collection.
  /// - Returns: A collection of the elements at the positions in `subranges`.
  ///
  /// - Complexity: O(1)
  public subscript(subranges: RangeSet<Index>) -> DiscontiguousSlice<Self> {
    DiscontiguousSlice(base: self, subranges: subranges)
  }
}

extension MutableCollection {
  /// Accesses a mutable view of this collection with the elements at the
  /// given indices.
  ///
  /// - Parameter subranges: The ranges of the elements to retrieve from this
  ///   collection.
  /// - Returns: A collection of the elements at the positions in `subranges`.
  ///
  /// - Complexity: O(1) to access the elements, O(*m*) to mutate the
  ///   elements at the positions in `subranges`, where *m* is the number of
  ///   elements indicated by `subranges`.
  public subscript(subranges: RangeSet<Index>) -> DiscontiguousSlice<Self> {
    get {
      DiscontiguousSlice(base: self, subranges: subranges)
    }
    set {
      for i in newValue.indices where subranges.contains(i.base) {
        self[i.base] = newValue[i]
      }
    }
  }
}

// MARK: - moveSubranges(_:to:)

extension MutableCollection {
  /// Moves the elements in the given subranges to just before the element at
  /// the specified index.
  ///
  /// This example finds all the uppercase letters in the array and then
  /// moves them to between `"i"` and `"j"`.
  ///
  ///     var letters = Array("ABCdeFGhijkLMNOp")
  ///     let uppercaseRanges = letters.subranges(where: { $0.isUppercase })
  ///     let rangeOfUppercase = letters.moveSubranges(uppercaseRanges, to: 10)
  ///     // String(letters) == "dehiABCFGLMNOjkp"
  ///     // rangeOfUppercase == 4..<13
  ///
  /// - Parameters:
  ///   - subranges: The subranges of the elements to move.
  ///   - insertionPoint: The index to use as the destination of the elements.
  /// - Returns: The new bounds of the moved elements.
  ///
  /// - Complexity: O(*n* log *n*) where *n* is the length of the collection.
  @discardableResult
  public mutating func moveSubranges(
    _ subranges: RangeSet<Index>, to insertionPoint: Index
  ) -> Range<Index> {
    let lowerCount = distance(from: startIndex, to: insertionPoint)
    let upperCount = distance(from: insertionPoint, to: endIndex)
    let start = _indexedStablePartition(
      count: lowerCount,
      range: startIndex..<insertionPoint,
      by: { subranges.contains($0) })
    let end = _indexedStablePartition(
      count: upperCount,
      range: insertionPoint..<endIndex,
      by: { !subranges.contains($0) })
    return start..<end
  }
}

// MARK: - removeSubranges(_:) / removingSubranges(_:)

extension RangeReplaceableCollection {
  /// Removes the elements at the given indices.
  ///
  /// For example, this code sample finds the indices of all the vowel
  /// characters in the string, and then removes those characters.
  ///
  ///     var str = "The rain in Spain stays mainly in the plain."
  ///     let vowels: Set<Character> = ["a", "e", "i", "o", "u"]
  ///     let vowelIndices = str.subranges(where: { vowels.contains($0) })
  ///
  ///     str.removeSubranges(vowelIndices)
  ///     // str == "Th rn n Spn stys mnly n th pln."
  ///
  /// - Parameter subranges: The indices of the elements to remove.
  ///
  /// - Complexity: O(*n*), where *n* is the length of the collection.
  public mutating func removeSubranges(_ subranges: RangeSet<Index>) {
    guard !subranges.isEmpty else {
      return
    }
    
    let inversion = subranges._inverted(within: self)
    var result = Self()
    for range in inversion.ranges {
      result.append(contentsOf: self[range])
    }
    self = result
  }
}

extension MutableCollection where Self: RangeReplaceableCollection {
  /// Removes the elements at the given indices.
  ///
  /// For example, this code sample finds the indices of all the negative
  /// numbers in the array, and then removes those values.
  ///
  ///     var numbers = [5, 7, -3, -8, 11, 2, -1, 6]
  ///     let negativeIndices = numbers.subranges(where: { $0 < 0 })
  ///
  ///     numbers.removeSubranges(negativeIndices)
  ///     // numbers == [5, 7, 11, 2, 6]
  ///
  /// - Parameter subranges: The indices of the elements to remove.
  ///
  /// - Complexity: O(*n*), where *n* is the length of the collection.
  public mutating func removeSubranges(_ subranges: RangeSet<Index>) {
    guard let firstRange = subranges.ranges.first else {
      return
    }
    
    var endOfElementsToKeep = firstRange.lowerBound
    var firstUnprocessed = firstRange.upperBound
    
    // This performs a half-stable partition based on the ranges in
    // `indices`. At all times, the collection is divided into three
    // regions:
    //
    // - `self[..<endOfElementsToKeep]` contains only elements that will
    //   remain in the collection after this method call.
    // - `self[endOfElementsToKeep..<firstUnprocessed]` contains only
    //   elements that will be removed.
    // - `self[firstUnprocessed...]` contains a mix of elements to remain
    //   and elements to be removed.
    //
    // Each iteration of this loop moves the elements that are _between_
    // two ranges to remove from the third region to the first region.
    for range in subranges.ranges.dropFirst() {
      let nextLow = range.lowerBound
      while firstUnprocessed != nextLow {
        swapAt(endOfElementsToKeep, firstUnprocessed)
        formIndex(after: &endOfElementsToKeep)
        formIndex(after: &firstUnprocessed)
      }
      
      firstUnprocessed = range.upperBound
    }
    
    // After dealing with all the ranges in `indices`, move the elements
    // that are still in the third region down to the first.
    while firstUnprocessed != endIndex {
      swapAt(endOfElementsToKeep, firstUnprocessed)
      formIndex(after: &endOfElementsToKeep)
      formIndex(after: &firstUnprocessed)
    }
    
    removeSubrange(endOfElementsToKeep..<endIndex)
  }
}

extension Collection {
  /// Returns a collection of the elements in this collection that are not
  /// represented by the given range set.
  ///
  /// For example, this code sample finds the indices of all the vowel
  /// characters in the string, and then retrieves a collection that omits
  /// those characters.
  ///
  ///     let str = "The rain in Spain stays mainly in the plain."
  ///     let vowels: Set<Character> = ["a", "e", "i", "o", "u"]
  ///     let vowelIndices = str.subranges(where: { vowels.contains($0) })
  ///
  ///     let disemvoweled = str.removingSubranges(vowelIndices)
  ///     print(String(disemvoweled))
  ///     // Prints "Th rn n Spn stys mnly n th pln."
  ///
  /// - Parameter subranges: A range set representing the indices of the
  ///   elements to remove.
  /// - Returns: A collection of the elements that are not in `subranges`.
  ///
  /// - Complexity: O(*n*), where *n* is the length of the collection.
  public func removingSubranges(
    _ subranges: RangeSet<Index>
  ) -> DiscontiguousSlice<Self> {
    let inversion = subranges._inverted(within: self)
    return self[inversion]
  }
}

// MARK: - subranges(where:) / subranges(of:)

extension Collection {
  /// Returns the indices of all the elements that match the given predicate.
  ///
  /// For example, you can use this method to find all the places that a
  /// vowel occurs in a string.
  ///
  ///     let str = "Fresh cheese in a breeze"
  ///     let vowels: Set<Character> = ["a", "e", "i", "o", "u"]
  ///     let allTheVowels = str.subranges(where: { vowels.contains($0) })
  ///     // str[allTheVowels].count == 9
  ///
  /// - Parameter predicate: A closure that takes an element as its argument
  ///   and returns a Boolean value that indicates whether the passed element
  ///   represents a match.
  /// - Returns: A set of the indices of the elements for which `predicate`
  ///   returns `true`.
  ///
  /// - Complexity: O(*n*), where *n* is the length of the collection.
  public func subranges(where predicate: (Element) throws -> Bool) rethrows
    -> RangeSet<Index>
  {
    if isEmpty { return RangeSet() }
    
    var result = RangeSet<Index>()
    var i = startIndex
    while i != endIndex {
      let next = index(after: i)
      if try predicate(self[i]) {
        result._append(i..<next)
      }
      i = next
    }
    
    return result
  }
}

extension Collection where Element: Equatable {
  /// Returns the indices of all the elements that are equal to the given
  /// element.
  ///
  /// For example, you can use this method to find all the places that a
  /// particular letter occurs in a string.
  ///
  ///     let str = "Fresh cheese in a breeze"
  ///     let allTheEs = str.subranges(of: "e")
  ///     // str[allTheEs].count == 7
  ///
  /// - Parameter element: An element to look for in the collection.
  /// - Returns: A set of the indices of the elements that are equal to
  ///   `element`.
  ///
  /// - Complexity: O(*n*), where *n* is the length of the collection.
  public func subranges(of element: Element) -> RangeSet<Index> {
    subranges(where: { $0 == element })
  }
}

