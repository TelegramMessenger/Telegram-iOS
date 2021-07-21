import Foundation
import Display
import TelegramCore
import AccountContext
import AlertUI
import PresentationDataUtils
import SettingsUI

private func totalDiskSpace() -> Int64 {
    do {
        let systemAttributes = try FileManager.default.attributesOfFileSystem(forPath: NSHomeDirectory() as String)
        return (systemAttributes[FileAttributeKey.systemSize] as? NSNumber)?.int64Value ?? 0
    } catch {
        return 0
    }
}

private func freeDiskSpace() -> Int64 {
    do {
        let systemAttributes = try FileManager.default.attributesOfFileSystem(forPath: NSHomeDirectory() as String)
        return (systemAttributes[FileAttributeKey.systemFreeSize] as? NSNumber)?.int64Value ?? 0
    } catch {
        return 0
    }
}

func checkAvailableDiskSpace(context: AccountContext, threshold: Int64 = 100 * 1024 * 1024, push: @escaping (ViewController) -> Void) -> Bool {
    guard freeDiskSpace() < threshold else {
        return true
    }
    
    let presentationData = context.sharedContext.currentPresentationData.with { $0 }
    let controller = textAlertController(context: context, title: nil, text: presentationData.strings.Cache_LowDiskSpaceText, actions: [TextAlertAction(type: .genericAction, title: presentationData.strings.AccessDenied_Settings, action: {
        push(storageUsageController(context: context, isModal: true))
    }), TextAlertAction(type: .defaultAction, title: presentationData.strings.Common_OK, action: {})])
    push(controller)
    
    return false
}
