import Foundation
import UserNotifications
import NGLocalization

public protocol SpecialOfferScheduleService {
    func schedule(offer: SpecialOffer)
    func cancelSchedule(forOfferWith: String)
    func cancelAllSchedules()
    func getScheduledAtDate(forOfferWith: String) -> Date?
}

public class SpecialOfferScheduleServiceImpl {
    
    //  MARK: - Dependencies
    
    private let userDefaults: UserDefaults
    
    //  MARK: - Lifecycle
    
    public init(userDefaults: UserDefaults = .standard) {
        self.userDefaults = userDefaults
    }
}

extension SpecialOfferScheduleServiceImpl: SpecialOfferScheduleService {
    public func schedule(offer: SpecialOffer) {
        if #available(iOS 10.0, *) {
            schedulePush(offer: offer)
        }
        
        updateScheduledAt(Date(), forOfferWith: offer.id)
    }
    
    public func cancelSchedule(forOfferWith id: String) {
        if #available(iOS 10.0, *) {
            cancelPush(forOfferWith: id)
        }
        
        updateScheduledAt(nil, forOfferWith: id)
    }
    
    public func cancelAllSchedules() {
        if #available(iOS 10.0, *) {
            cancelAllPushes()
        }
        
        saveSchedules([:])
    }
    
    public func getScheduledAtDate(forOfferWith id: String) -> Date? {
        return getSchedules()[id]
    }
}

//  MARK: - UserNotifications

@available(iOS 10.0, *)
private extension SpecialOfferScheduleServiceImpl {
    func schedulePush(offer: SpecialOffer) {
        guard let autoshowTimeInterval = offer.autoshowTimeInterval else {
            return
        }
        
        let id = getNotificationIdentifier(forOfferWith: offer.id)
        
        let content = UNMutableNotificationContent()
        content.body = ngLocalized("NicegramPush.SpecialOffer.Body")
        
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: autoshowTimeInterval, repeats: false)
        
        let request = UNNotificationRequest(
            identifier: id,
            content: content,
            trigger: trigger
        )
        
        UNUserNotificationCenter.current().add(request)
    }
    
    func cancelPush(forOfferWith id: String) {
        let id = getNotificationIdentifier(forOfferWith: id)
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [id])
    }
    
    func cancelAllPushes() {
        UNUserNotificationCenter.current().getPendingNotificationRequests { request in
            let ids = request
                .map(\.identifier)
                .filter({ $0.contains("special_offer") })
            UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: ids)
        }
    }
    
    func getNotificationIdentifier(forOfferWith id: String) -> String {
        return "special_offer_\(id)"
    }
}

//  MARK: - Private Functions

private extension SpecialOfferScheduleServiceImpl {
    func getSchedulesKey() -> String {
        return "special_offer_schedules"
    }
    
    func getSchedules() -> [String: Date] {
        return (userDefaults.dictionary(forKey: getSchedulesKey()) as? [String: Date]) ?? [:]
    }
    
    func saveSchedules(_ dict: [String: Date]) {
        userDefaults.set(dict, forKey: getSchedulesKey())
    }
    
    func updateScheduledAt(_ date: Date?, forOfferWith id: String) {
        var dict = getSchedules()
        dict[id] = date
        saveSchedules(dict)
    }
}
