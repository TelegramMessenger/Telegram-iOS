import Foundation
import UIKit
import TelegramCore
import SwiftSignalKit
import AsyncDisplayKit

// MARK: - Joker Ghost Mode (وضع الشبح)
// هذه الميزة تخفي قراء الرسائل من المرسل، مع وضع أيقونة عين فوق الرسالة
// عند ضغط العين، يتم إرسال إشارة القراءة لتلك الرسالة فقط

public class JokerGhostModeManager {
    // التحقق إذا كان وضع الشبح مفعلاً
    public static func isGhostModeEnabled(settings: JokerSettings) -> Bool {
        return settings.ghostMode
    }
    
    // إيقاف إرسال إشارات القراءة التلقائية عند وضع الشبح
    public static func shouldSuppressReadReceipts(settings: JokerSettings) -> Bool {
        return settings.ghostMode
    }
    
    // إرسال إشارة قراءة لرسالة محددة (عند ضغط العين)
    public static func markMessageAsRead(context: AccountContext, messageId: EngineMessage.Id) {
        let _ = context.engine.messages.readMessages(ids: [messageId])
    }
    
    // أيقونة العين التي توضع فوق الرسائل الواردة
    public static func createEyeIcon() -> UIImage? {
        // يمكن استبدالها بصورة eye.png من الموارد
        return nil
    }
}

// مثال على التنفيذ في واجهة الدردشة:
// 1. في ChatControllerNode أو MessageViewHolder، عند عرض رسالة واردة:
//    إذا كان ghostMode مفعلاً، لا ترسل إشعار قراءة تلقائياً
//    أضف أيقونة عين فوق الرسالة
// 2. عند ضغط العين:
//    JokerGhostModeManager.markMessageAsRead(context: context, messageId: message.id)
/*
 مثال الكود:
 
 if jokerSettings.ghostMode && message.isIncoming {
     // لا ترسل إشعار قراءة تلقائي
     // أضف أيقونة eyeButton فوق الرسالة
     eyeButton.addTarget(self, action: #selector(eyeTapped(_:)), for: .touchUpInside)
 }
 
 @objc func eyeTapped(_ sender: UIButton) {
     guard let messageId = sender.tag as message ID else { return }
     JokerGhostModeManager.markMessageAsRead(context: context, messageId: messageId)
     // إخفاء العين بعد الضغط
     sender.isHidden = true
 }
*/
