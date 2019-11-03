import Foundation
import SwiftSignalKit

enum PostboxUpgradeOperation {
    case inplace((MetadataTable, ValueBox, (Float) -> Void) -> Void)
    case standalone((Queue, String, ValueBox, ValueBoxEncryptionParameters, (Float) -> Void) -> String?)
}

func registeredUpgrades() -> [Int32: PostboxUpgradeOperation] {
    var dict: [Int32: PostboxUpgradeOperation] = [:]
    dict[12] = .inplace(postboxUpgrade_12to13)
    dict[13] = .inplace(postboxUpgrade_13to14)
    dict[14] = .inplace(postboxUpgrade_14to15)
    dict[15] = .inplace(postboxUpgrade_15to16)
    dict[16] = .inplace(postboxUpgrade_16to17)
    dict[17] = .inplace(postboxUpgrade_17to18)
    dict[18] = .inplace(postboxUpgrade_18to19)
    dict[19] = .inplace(postboxUpgrade_19to20)
    dict[20] = .inplace(postboxUpgrade_20to21)
    dict[21] = .standalone(postboxUpgrade_21to22)
    dict[22] = .inplace(postboxUpgrade_22to23)
    dict[23] = .inplace(postboxUpgrade_23to24)
    dict[24] = .inplace(postboxUpgrade_24to25)
    return dict
}
