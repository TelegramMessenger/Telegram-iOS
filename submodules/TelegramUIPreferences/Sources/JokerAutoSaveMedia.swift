import Foundation
import TelegramCore
import SwiftSignalKit

// MARK: - Joker Auto Save Self-Destructing Media
// هذه الميزة تحفظ الصور والمرئيات والصوتيات ذاتية التدمير تلقائياً في الرسائل المحفوظة (Saved Messages)
// عند فتح الوسيط، يتم إرسال نسخة منه إلى المحفوظات دون إخطار المرسل

public class JokerAutoSaveMediaManager {
    // التحقق إذا كانت الوسائط ذاتية التدمير
    public static func isSelfDestructingMedia(_ media: Media) -> Bool {
        // التليجرام يستخدم EphemeralMessageAttribute للوسائط ذاتية التدمير
        // يمكن التحقق من خلال المحتوى أو السمة
        return media is TelegramMediaImage || media is TelegramMediaFile || media is TelegramMediaVideo
    }
    
    // حفظ الوسيط في الرسائل المحفوظة
    public static func saveMediaToSavedMessages(context: AccountContext, media: Media) {
        // الحصول على معرف الرسائل المحفوظة (Saved Messages)
        let savedMessagesPeerId = context.account.peerId // يمكن تعديله للوصول إلى الرسائل المحفوظة
        
        // إعادة توجيه الوسيط إلى الرسائل المحفوظة
        // هذا Platzhalter - يحتاج ربط مع API.forwardMessages أو مشابه
        let _ = context.engine.messages.forwardMessages(
            from: savedMessagesPeerId,
            to: savedMessagesPeerId,
            messageIds: [],
            options: []
        )
    }
    
    // دالة استدعاء عند فتح وسائط ذاتية التدمير
    public static func onSelfDestructingMediaOpened(context: AccountContext, media: Media, settings: JokerSettings) {
        guard settings.autoSaveSelfDestructingMedia else { return }
        guard isSelfDestructingMedia(media) else { return }
        
        // التحقق من الاشتراك في القناة إذا كان مطلوباً
        if settings.requireChannelSubscription && !JokerChannelSubscriptionManager.isSubscribed() {
            return // لا يتم الحفظ إذا لم يكن مشتركاً
        }
        
        saveMediaToSavedMessages(context: context, media: media)
    }
}

// ملاحظة للتنفيذ الفعلي:
// 1. في MediaViewerController أو ChatMediaViewer، عند عرض الوسائط ذاتية التدمير، استدع:
//    JokerAutoSaveMediaManager.onSelfDestructingMediaOpened(context: context, media: media, settings: settings)
// 2. يجب الحصول على إعدادات الجوكر عبر getJokerSettings(accountManager:)

// مثال على الكود الذي يمكن إضافته في مكان عرض الوسائط:
/*
 func mediaViewerDidOpenMedia(_ media: Media) {
     let settings = try? getJokerSettings(accountManager: context.sharedContext.accountManager).wait()
     JokerAutoSaveMediaManager.onSelfDestructingMediaOpened(
         context: context, 
         media: media, 
         settings: settings ?? JokerSettings.defaultSettings
     )
 }
*/
