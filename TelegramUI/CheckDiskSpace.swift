import Foundation
import Display
import TelegramCore

func totalDiskSpace() -> Int64 {
    do {
        let systemAttributes = try FileManager.default.attributesOfFileSystem(forPath: NSHomeDirectory() as String)
        return (systemAttributes[FileAttributeKey.systemSize] as? NSNumber)?.int64Value ?? 0
    } catch {
        return 0
    }
}

func freeDiskSpace() -> Int64 {
    do {
        let systemAttributes = try FileManager.default.attributesOfFileSystem(forPath: NSHomeDirectory() as String)
        return (systemAttributes[FileAttributeKey.systemFreeSize] as? NSNumber)?.int64Value ?? 0
    } catch {
        return 0
    }
}

func checkAvailableDiskSpace(account: Account, threshold: Int64 = 100 * 1024 * 1024, present: @escaping (ViewController, Any?) -> Void) -> Bool {
    guard freeDiskSpace() < threshold else {
        return true
    }
    
    let presentationData = account.telegramApplicationContext.currentPresentationData.with { $0 }
    let controller = textAlertController(account: account, title: nil, text: presentationData.strings.Cache_LowDiskSpaceText, actions: [TextAlertAction(type: .genericAction, title: presentationData.strings.AccessDenied_Settings, action: {
        let controller = storageUsageController(account: account, isModal: true)
        present(controller, ViewControllerPresentationArguments(presentationAnimation: .modalSheet))
        
    }), TextAlertAction(type: .defaultAction, title: presentationData.strings.Common_OK, action: {})])
    present(controller, nil)
    
    return false
}
