import XCTest
@testable import TabBarComponent

/// A `TabBarComponent` cannot be built in a test process (it takes `PresentationStrings`), so the decision which items
/// VoiceOver reaches is a free function.
final class TabBarAccessibilityTests: XCTestCase {
    func testAllItemsAreReachableWithoutSearch() {
        XCTAssertEqual(tabBarAccessibleItemIds(ids: [1, 2, 3], selectedId: 2, isSearchActive: false), [1, 2, 3])
    }
    
    func testActiveSearchHidesTheFadedItems() {
        XCTAssertEqual(tabBarAccessibleItemIds(ids: [1, 2, 3], selectedId: 2, isSearchActive: true), [2])
        XCTAssertEqual(tabBarAccessibleItemIds(ids: [1, 2, 3], selectedId: nil, isSearchActive: true), [])
    }
}
