import Foundation

public class KeywordsSearch {
    
    //  MARK: - Lifecycle
    
    public init() {}
    
    //  MARK: - Public Functions

    public func filter<Item>(items: [Item], by searchText: String, keywordsProvider: (Item) -> [String]) -> [Item] {
        let searchText = modifyForSearch(searchText)
        return items.filter { item in
            let keywords = keywordsProvider(item).map({ modifyForSearch($0) })
            return keywords.contains(where: { $0.hasPrefix(searchText) })
        }
    }
}

private extension KeywordsSearch {
    func modifyForSearch(_ string: String) -> String {
        return string.lowercased().replacingOccurrences(of: " ", with: "")
    }
}
