import Foundation
import XCTest
@testable import Postbox

final class SimpleDictionaryTests: XCTestCase {
    private func makeDictionary(_ pairs: [(Int, String)]) -> SimpleDictionary<Int, String> {
        var dictionary = SimpleDictionary<Int, String>()
        for (key, value) in pairs {
            dictionary[key] = value
        }
        return dictionary
    }

    private func pairs(_ dictionary: SimpleDictionary<Int, String>) -> [(Int, String)] {
        return Array(dictionary)
    }

    func testFilteredOutKeepsEveryEntryWhoseKeyIsNotExcluded() {
        let dictionary = self.makeDictionary([(1, "a"), (2, "b"), (3, "c"), (4, "d")])

        let filtered = dictionary.filteredOut(keysIn: [1])

        XCTAssertNotNil(filtered)
        XCTAssertEqual(filtered?.count, 3)
        XCTAssertEqual(filtered.map(self.pairs)?.map { $0.0 }, [2, 3, 4])
        XCTAssertEqual(filtered.map(self.pairs)?.map { $0.1 }, ["b", "c", "d"])
    }

    func testFilteredOutRemovesEveryExcludedKeyAndPreservesOrder() {
        let dictionary = self.makeDictionary([(1, "a"), (2, "b"), (3, "c"), (4, "d"), (5, "e")])

        let filtered = dictionary.filteredOut(keysIn: [2, 4])

        XCTAssertEqual(filtered.map(self.pairs)?.map { $0.0 }, [1, 3, 5])
    }

    func testFilteredOutReturnsNilWhenNoKeyMatches() {
        let dictionary = self.makeDictionary([(1, "a"), (2, "b")])

        XCTAssertNil(dictionary.filteredOut(keysIn: [7, 8]))
        XCTAssertNil(dictionary.filteredOut(keysIn: []))
    }

    func testFilteredOutReturnsEmptyDictionaryWhenEveryKeyMatches() {
        let dictionary = self.makeDictionary([(1, "a"), (2, "b")])

        let filtered = dictionary.filteredOut(keysIn: [1, 2])

        XCTAssertNotNil(filtered)
        XCTAssertEqual(filtered?.isEmpty, true)
    }
}
