import Foundation

enum PostboxUpgradeOperation {
    case inplace((MetadataTable, ValueBox) -> Void)
}

func registeredUpgrades() -> [Int32: PostboxUpgradeOperation] {
    var dict: [Int32: PostboxUpgradeOperation] = [:]
    dict[12] = .inplace(postboxUpgrade_12to13)
    return dict
}
