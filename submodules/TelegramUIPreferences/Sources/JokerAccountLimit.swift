import Foundation
import TelegramCore
import SwiftSignalKit

// MARK: - Joker Allow 100 Accounts
// هذه الميزة تسمح بإضافة حتى 100 حساب في التطبيق
// بدلاً من الحد الافتراضي في التليجرام الرسمي

public class JokerAccountLimitManager {
    // الحد الأقصى الجديد للحسابات
    public static let maxAccountsAllowed = 100
    
    // التحقق إذا كانت الميزة مفعلة
    public static func isEnabled(settings: JokerSettings) -> Bool {
        return settings.allow100Accounts
    }
    
    // الحصول على الحد الأقصى للحسابات
    public static func getMaxAccountsCount(settings: JokerSettings) -> Int {
        if settings.allow100Accounts {
            return maxAccountsAllowed
        }
        // إرجاع الحد الافتراضي من التليجرام (عادة 3-5 حسابات)
        return 3
    }
    
    // التحقق إذا يمكن إضافة حساب جديد
    public static func canAddAccount(currentCount: Int, settings: JokerSettings) -> Bool {
        let maxCount = getMaxAccountsCount(settings: settings)
        return currentCount < maxCount
    }
}

// مثال على التنفيذ:
// 1. في AccountManager أو حيث يتم التحقق من الحد الأقصى للحسابات:
//    إذا كان allow100Accounts مفعلاً، اسمح بإضافة حتى 100 حساب
// 2. في واجهة إضافة الحسابات، أزل أو زيد限制 número de cuentas
/*
 مثال الكود:
 
 func addNewAccount() {
     let currentCount = accountManager.accounts.count
     let maxCount = JokerAccountLimitManager.getMaxAccountsCount(settings: jokerSettings)
     
     if currentCount >= maxCount {
         // عرض تنبيه بأن الحد الأقصى قد وصل
         return
     }
     
     // متابعة إضافة الحساب
 }
 
 // أو تعديل الثابت في الكود الأصلي:
 // const int MAX_ACCOUNTS = jokerSettings.allow100Accounts ? 100 : 3;
*/
