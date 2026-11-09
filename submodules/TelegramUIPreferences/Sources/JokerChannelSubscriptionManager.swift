import Foundation
import TelegramCore
import SwiftSignalKit

// MARK: - Joker Channel Subscription Manager
// التحقق من الاشتراك في قناة @aljokeruserbot قبل تفعيل أي ميزة
// إذا لم يكن المستخدم مشتركاً، لا تظهر toggles للمميزات

public class JokerChannelSubscriptionManager {
    // معرف القناة الإجباري
    public static let channelUsername = "@aljokeruserbot"
    public static let channelLink = "https://t.me/aljokeruserbot"
    
    // مفتاح UserDefaults لحفظ حالة الاشتراك
    private static let subscriptionKey = "joker_channel_subscribed"
    
    // حفظ حالة الاشتراك
    public static func saveSubscriptionStatus(_ isSubscribed: Bool) {
        UserDefaults.standard.set(isSubscribed, forKey: subscriptionKey)
        UserDefaults.standard.synchronize()
    }
    
    // جلب حالة الاشتراك المحفوظة
    public static func isSubscribed() -> Bool {
        return UserDefaults.standard.bool(forKey: subscriptionKey)
    }
    
    // التحقق من الاشتراك عبر API (يحتاج ربط مع TDLib channels.getParticipant)
    public static func checkSubscriptionViaAPI(account: Account) -> Signal<Bool, NoError> {
        return Signal<Bool, NoError>.single(UserDefaults.standard.bool(forKey: subscriptionKey))
    }
}
