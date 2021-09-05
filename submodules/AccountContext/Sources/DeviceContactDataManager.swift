import Foundation
import Postbox
import TelegramCore
import TelegramUIPreferences
import SwiftSignalKit

public typealias DeviceContactStableId = String

public protocol DeviceContactDataManager: AnyObject {
    func personNameDisplayOrder() -> Signal<PresentationPersonNameOrder, NoError>
    func basicData() -> Signal<[DeviceContactStableId: DeviceContactBasicData], NoError>
    func basicDataForNormalizedPhoneNumber(_ normalizedNumber: DeviceContactNormalizedPhoneNumber) -> Signal<[(DeviceContactStableId, DeviceContactBasicData)], NoError>
    func extendedData(stableId: DeviceContactStableId) -> Signal<DeviceContactExtendedData?, NoError>
    func importable() -> Signal<[DeviceContactNormalizedPhoneNumber: ImportableDeviceContactData], NoError>
    func appSpecificReferences() -> Signal<[PeerId: DeviceContactBasicDataWithReference], NoError>
    func search(query: String) -> Signal<[DeviceContactStableId: (DeviceContactBasicData, PeerId?)], NoError>
    func appendContactData(_ contactData: DeviceContactExtendedData, to stableId: DeviceContactStableId) -> Signal<DeviceContactExtendedData?, NoError>
    func appendPhoneNumber(_ phoneNumber: DeviceContactPhoneNumberData, to stableId: DeviceContactStableId) -> Signal<DeviceContactExtendedData?, NoError>
    func createContactWithData(_ contactData: DeviceContactExtendedData) -> Signal<(DeviceContactStableId, DeviceContactExtendedData)?, NoError>
    func deleteContactWithAppSpecificReference(peerId: PeerId) -> Signal<Never, NoError>
}
