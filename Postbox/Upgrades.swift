import Foundation

enum PostboxUpgradeOperation {
    case inplace((MetadataTable, ValueBox) -> Void)
}

func registeredUpgrades() -> [Int32: PostboxUpgradeOperation] {
    var dict: [Int32: PostboxUpgradeOperation] = [:]
    dict[12] = .inplace(postboxUpgrade_12to13)
    dict[13] = .inplace(postboxUpgrade_13to14)
    dict[14] = .inplace(postboxUpgrade_14to15)
    return dict
}
